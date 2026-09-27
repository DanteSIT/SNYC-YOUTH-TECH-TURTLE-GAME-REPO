#!/usr/bin/env python3
"""
make_sand_textures.py — generates the seabed albedo and its matching normal map.

The sand was a single flat JPEG ("OIP (1) 1.jpg", 474x430, mean RGB 216/199/181,
standard deviation ~15) fed straight into a triplanar shader. Almost no tonal
range means the seabed reads as a sheet of pale card: it catches the caustics
overlay as one flat value, has no grain at any distance, and its 1.09 aspect
ratio cannot tile without a visible seam every four metres.

This builds a proper pair of seamless 1024x1024 maps from a shared height field:

    sand_albedo.png   warm dry sand: broad dune drifts, fine grain, shell grit
    sand_normal.png   the same height field as a tangent-space normal map

Both are generated from one periodic fractal value-noise lattice, so they tile
infinitely in every direction and the lighting in the normal map agrees with
the colour in the albedo (raised grains are lit, hollows are shaded).

Usage:
    python3 tools/make_sand_textures.py            # write PNGs
    python3 tools/make_sand_textures.py --preview  # also dump a 2x2 tile check
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT_DIR = os.path.join(ROOT, "assets", "textures")
SIZE = 1024


# --------------------------------------------------------------- tileable noise

def _value_noise(size: int, period: int, seed: int) -> np.ndarray:
    """Value noise on a `period`x`period` lattice, sampled over `size`x`size`.

    Wrapping the integer lattice modulo `period` is what makes the result tile
    seamlessly: sample (x, y) and sample (x + size, y) land on the same lattice
    cell, so the edges match exactly. Smoothstep interpolation keeps the lattice
    from showing up as grid creases.
    """
    rng = np.random.default_rng(seed)
    lattice = rng.random((period, period), dtype=np.float64)

    # Sample coordinates in lattice space, scaled so the image spans `period` cells.
    step = period / size
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64) * step
    x0 = np.floor(xs).astype(np.int64)
    y0 = np.floor(ys).astype(np.int64)
    fx = xs - x0
    fy = ys - y0

    # Smoothstep (3x^2 - 2x^3) fade, the classic Perlin fade curve.
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)

    x0 %= period
    y0 %= period
    x1 = (x0 + 1) % period
    y1 = (y0 + 1) % period

    v00 = lattice[y0, x0]
    v10 = lattice[y0, x1]
    v01 = lattice[y1, x0]
    v11 = lattice[y1, x1]

    top = v00 + (v10 - v00) * ux
    bot = v01 + (v11 - v01) * ux
    return top + (bot - top) * uy


def fractal_noise(size: int, base_period: int, octaves: int, seed: int,
                  gain: float = 0.5, lacunarity: int = 2) -> np.ndarray:
    """Sum `octaves` of tileable value noise, each at twice the previous period.

    Returns a field normalised to roughly 0..1 with a mean near 0.5.
    """
    total = np.zeros((size, size), dtype=np.float64)
    amp = 1.0
    amp_sum = 0.0
    period = base_period
    for o in range(octaves):
        total += amp * _value_noise(size, period, seed + o * 7919)
        amp_sum += amp
        amp *= gain
        period *= lacunarity
    total /= amp_sum
    lo, hi = total.min(), total.max()
    return (total - lo) / (hi - lo)


def normalise(field: np.ndarray) -> np.ndarray:
    lo, hi = float(field.min()), float(field.max())
    return (field - lo) / (hi - lo)


def smoothstep(field: np.ndarray, lo: float, hi: float) -> np.ndarray:
    t = np.clip((field - lo) / (hi - lo), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ----------------------------------------------------------------- the seabed

def height_field(size: int = SIZE) -> np.ndarray:
    """The single height field both maps are derived from.

    Three layers, coarse to fine:
      drifts  broad, low-frequency undulation (the shapes currents leave)
      grain   medium mottling (how the sand actually breaks up under light)
      grit    per-pixel speckle (the sand grains themselves, plus shell chips)
    """
    drifts = fractal_noise(size, base_period=4, octaves=4, seed=1201, gain=0.55)
    grain = fractal_noise(size, base_period=16, octaves=4, seed=5507, gain=0.5)
    grit = fractal_noise(size, base_period=128, octaves=2, seed=9311, gain=0.5)

    h = 0.50 * drifts + 0.34 * grain + 0.16 * grit

    # Ripples: the corrugation a tide leaves in the bed. Three crossing wave
    # trains at different angles, faded out where the dune drifts dominate so the
    # pattern never reads as a regular grid.
    #
    # The wave numbers must be INTEGERS. xx runs 0..(size-1)/size, so the wrap
    # boundary falls between the last column and a hypothetical column N, and only
    # an integer k gives sin(2*pi*(k*1.0 + ...)) == sin(2*pi*(0 + ...)). With a
    # fractional k such as 0.55 the phase lands a fraction of a cycle off at the
    # seam and the bed grows a hard vertical edge every time it tiles.
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64) / size
    warp = 0.09 * (grain - 0.5)
    ripple = (
        np.sin((xx * 3.0 + yy * 1.0) * 2.0 * np.pi + warp * 9.0) * 0.50
        + np.sin((xx * -1.0 + yy * 2.0) * 2.0 * np.pi + warp * 6.0) * 0.32
        + np.sin((xx * 2.0 + yy * -3.0) * 2.0 * np.pi + warp * 4.0) * 0.18
    )
    ripple *= 0.5 + 0.5 * (drifts - 0.5) * 1.4
    h += 0.085 * ripple

    return normalise(h)


def albedo(height: np.ndarray, size: int = SIZE) -> np.ndarray:
    """Tint the height field as dry seabed sand.

    Three stops, chosen so the bed sits well below the pale caustic overlay in
    brightness: the earlier JPEG averaged 216/199/181, which is why the whole
    corridor read as washed out.
    """
    shadow = np.array([96, 78, 58], dtype=np.float64)     # hollows, packed and wet
    mid = np.array([168, 143, 105], dtype=np.float64)     # the body of the sand
    light = np.array([214, 194, 156], dtype=np.float64)   # crests catching light

    t = np.clip((height - 0.22) / 0.56, 0.0, 1.0)
    t = t * t * (3.0 - 2.0 * t)

    rgb = np.where(
        (t < 0.5)[..., None],
        shadow + (mid - shadow) * (t / 0.5)[..., None],
        mid + (light - mid) * ((t - 0.5) / 0.5)[..., None],
    )

    # Shell grit: sparse bright chips and a few dark mineral flecks, so the bed
    # has something for a specular highlight to catch at close range.
    #
    # These are thresholded out of tileable noise rather than raw random, because
    # random speckle does not wrap: a plain `rng.random() > 0.9975` mask puts a
    # few chips on the last column and none on the first, which shows up as a
    # hard vertical seam every time the texture repeats.
    chips = smoothstep(fractal_noise(size, 256, 1, 8123), 0.90, 0.99)
    rgb += chips[..., None] * np.array([62.0, 58.0, 50.0]) * (0.55 + 0.45 * height[..., None])

    flecks = smoothstep(fractal_noise(size, 192, 1, 2731), 0.93, 1.0)
    rgb -= flecks[..., None] * np.array([40.0, 39.0, 34.0])

    # Very low-frequency albedo drift that is *not* tied to the height field, so
    # the colour variation does not read as a bump map from a distance.
    patchy = fractal_noise(size, base_period=3, octaves=3, seed=3301)
    rgb *= 0.92 + 0.16 * patchy[..., None]

    return np.clip(rgb, 0.0, 255.0).astype(np.uint8)


def normal_map(height: np.ndarray, strength: float = 2.6,
               size: int = SIZE) -> np.ndarray:
    """Tangent-space normal map from the height field, wrapping at the edges.

    The gradients use np.roll so the seam is periodic: the derivative at x = 0 is
    computed against the last column, which is what keeps the lighting continuous
    across the tile boundary.
    """
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5

    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    nx *= inv
    ny *= inv
    nz *= inv

    out = np.empty((size, size, 3), dtype=np.uint8)
    out[..., 0] = np.clip((nx * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    out[..., 1] = np.clip((ny * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    out[..., 2] = np.clip((nz * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)
    return out


def save(arr: np.ndarray, name: str) -> Image.Image:
    img = Image.fromarray(arr, "RGB")
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    img.save(path)
    print("wrote %s (%dx%d, mean RGB %s)" % (
        os.path.relpath(path, ROOT), img.width, img.height,
        "/".join(str(int(arr[..., i].mean())) for i in range(3))))
    return img


def preview(alb: Image.Image, nrm: Image.Image) -> None:
    """2x2 tile check, written to /tmp so the game's texture folder stays clean.

    If the map is not seamless these four copies show hard edges at the seams; a
    seamless map shows continuous grain across all of them.
    """
    h = 256
    sheet = Image.new("RGB", (h * 4, h * 2), (20, 20, 24))
    for i, src in enumerate((alb, nrm)):
        small = src.resize((h * 2, h * 2), Image.LANCZOS)
        tile = Image.new("RGB", (h * 2, h * 2))
        for ty in range(2):
            for tx in range(2):
                tile.paste(small, (-tx * h, -ty * h))
        sheet.paste(tile, (i * h * 2, 0))
    path = "/tmp/opencode/sand_tiles.png"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    print("wrote %s (albedo then normal, each tiled 2x2)" % path)


if __name__ == "__main__":
    hfield = height_field(SIZE)
    alb = save(albedo(hfield, SIZE), "sand_albedo.png")
    nrm = save(normal_map(hfield, 2.6, SIZE), "sand_normal.png")
    if "--preview" in sys.argv:
        preview(alb, nrm)
