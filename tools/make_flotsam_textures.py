#!/usr/bin/env python3
"""
make_flotsam_textures.py — generates the small alpha sprites used by the
ocean-drift particle field (scenes/effects/ocean_particles.tscn).

The drift field used to be man-made litter (a plastic bag plane, a tin can, a
cork, a wood plank, a metal chip). At 0.5 m across and 40 per pocket those read
as visual garbage, so they were replaced with natural flotsam drawn as soft
alpha sprites plus a couple of tiny primitives.

Everything is drawn at SS times the final size and downsampled with LANCZOS for
clean edges, and every sprite is fully transparent outside its silhouette so it
can be dropped straight into a billboarded particle pass.

Usage:
    python3 tools/make_flotsam_textures.py            # write PNGs
    python3 tools/make_flotsam_textures.py --preview  # also dump a contact sheet
"""
import math
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT_DIR = os.path.join(ROOT, "assets", "textures", "flotsam")
SS = 4  # supersample factor


def canvas(w, h):
    """Supersampled transparent canvas; all drawing uses W/H (== w*SS, h*SS)."""
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def save(img, w, h, name):
    img = img.resize((w, h), Image.LANCZOS)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    img.save(path)
    print("wrote %s (%dx%d)" % (os.path.relpath(path, ROOT), w, h))
    return img


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def tint_mask(layer, mask):
    """Keep only the pixels of `layer` selected by `mask`."""
    layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", layer.size, 0), mask))


# ---------------------------------------------------------------- kelp frond

def kelp(w=96, h=384):
    """A single long kelp blade: wavy tapered ribbon with a lighter midrib."""
    W, H = w * SS, h * SS
    img = canvas(w, h)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    root_dark = (26, 70, 38, 255)
    tip_bright = (146, 200, 78, 255)
    steps = 120
    left, right = [], []
    for i in range(steps + 1):
        t = i / steps
        # centreline: gentle S-curve, drifting sideways as it rises
        cx = W * (0.5 + 0.19 * math.sin(t * 2.3 * math.pi) * (0.35 + t))
        cy = H * (0.985 - 0.965 * t)
        # half width: stalk at the holdfast, fattest around 40%, pointed tip
        hw = W * 0.27 * (t ** 0.28) * ((1.0 - t) ** 0.48) * 2.1
        if t < 0.07:
            hw *= (t / 0.07) * 0.6
        left.append((cx - hw, cy))
        right.append((cx + hw, cy))

    d = ImageDraw.Draw(layer)
    d.polygon(left + list(reversed(right)), fill=root_dark)

    # per-segment gradient toward a brighter tip
    for i in range(steps):
        t = i / steps
        d.polygon(
            [left[i], right[i], right[i + 1], left[i + 1]],
            fill=mix(root_dark, tip_bright, t ** 1.3),
        )

    # midrib
    for i in range(steps):
        t = i / steps
        d.line(
            [left[i], right[i]],
            fill=(214, 242, 158, int(95 * (1.0 - t * 0.8))),
            width=max(1, SS // 2),
        )

    # alternating leaflets
    for k, t in enumerate((0.14, 0.28, 0.42, 0.56, 0.68, 0.78)):
        i = int(t * steps)
        side = 1 if k % 2 == 0 else -1
        cx, cy = left[i]
        lw = W * 0.15 * (1.0 - t * 0.45)
        lh = H * 0.030 * (1.0 - t * 0.4)
        x0, x1 = cx - lw * 0.45, cx + side * lw
        d.ellipse(
            [min(x0, x1), cy - lh, max(x0, x1), cy + lh],
            fill=mix((44, 108, 50, 235), (128, 184, 72, 225), t),
        )

    # soften the silhouette a touch and fade the very tip
    alpha = layer.getchannel("A")
    px = alpha.load()
    for y in range(H):
        for x in range(W):
            if px[x, y] and y < H * 0.045:
                px[x, y] = int(px[x, y] * (y / (H * 0.045)))
    img.alpha_composite(layer)
    return save(img, w, h, "kelp_frond.png")


# -------------------------------------------------------------- seagrass tuft

def seagrass(w=192, h=192):
    """A fan of tapered blades springing from a single holdfast."""
    W, H = w * SS, h * SS
    img = canvas(w, h)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    base = (W * 0.5, H * 0.99)
    # (spread angle deg, length fraction, sideways bend, width)
    blades = [
        (-58, 0.72, 0.34, 5.0),
        (-36, 0.86, 0.24, 4.2),
        (-16, 0.97, 0.15, 3.6),
        (5, 1.00, 0.16, 3.8),
        (26, 0.94, 0.24, 4.4),
        (47, 0.83, 0.32, 5.2),
        (70, 0.63, 0.40, 4.6),
    ]
    root_dark = (20, 74, 50, 255)
    tip_light = (154, 214, 100, 255)

    for ang, length, bend, width in blades:
        rad = math.radians(ang - 90.0)
        L = H * length * 0.90
        ctrl = (base[0] + math.cos(rad) * L * 0.55,
                base[1] + math.sin(rad) * L * 0.55)
        tip = (base[0] + math.cos(rad) * L + bend * W * 0.42,
               base[1] + math.sin(rad) * L)
        steps = 48
        pts = []
        for i in range(steps + 1):
            t = i / steps
            mt = 1.0 - t
            pts.append((
                mt * mt * base[0] + 2 * mt * t * ctrl[0] + t * t * tip[0],
                mt * mt * base[1] + 2 * mt * t * ctrl[1] + t * t * tip[1],
            ))
        left, right = [], []
        for i, (px_, py_) in enumerate(pts):
            t = i / steps
            hw = width * SS * (0.40 + 0.60 * math.sin(math.pi * min(t * 1.1, 1.0)) ** 0.55)
            hw *= 1.0 - t ** 4  # pointed tip
            if i < steps:
                tx, ty = pts[i + 1][0] - px_, pts[i + 1][1] - py_
            else:
                tx, ty = px_ - pts[i - 1][0], py_ - pts[i - 1][1]
            ln = math.hypot(tx, ty) or 1.0
            nx, ny = -ty / ln, tx / ln
            left.append((px_ + nx * hw, py_ + ny * hw))
            right.append((px_ - nx * hw, py_ - ny * hw))
        d.polygon(left + list(reversed(right)), fill=root_dark)
        for i in range(steps):
            t = i / steps
            d.polygon(
                [left[i], right[i], right[i + 1], left[i + 1]],
                fill=mix(root_dark, tip_light, t ** 1.2),
            )
        d.line([base, ctrl, tip], fill=(196, 232, 148, 60), width=max(1, SS // 2))

    img.alpha_composite(layer)
    return save(img, w, h, "seagrass_tuft.png")


# -------------------------------------------------------------------- shell

def shell(w=128, h=128):
    """A scallop shell seen face-on: ribbed fan, warm cream, two small ears."""
    W, H = w * SS, h * SS
    img = canvas(w, h)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = W * 0.5, H * 0.76
    R = W * 0.44

    shell_dark = (206, 176, 142, 255)
    shell_light = (253, 244, 229, 255)

    fan = []
    for i in range(41):
        a = math.radians(202.0 + 136.0 * i / 40.0)
        fan.append((cx + math.cos(a) * R, cy + math.sin(a) * R))
    hinge = (cx - R * 0.14, cy + R * 0.12)
    d.polygon(fan + [hinge], fill=shell_dark)

    # soft vertical shading, clipped to the fan
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(fan + [hinge], fill=255)
    grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grad)
    for y in range(H):
        t = max(0.0, min(1.0, 1.0 - abs((y - cy) / R)))
        gd.line([(0, y), (W, y)], fill=mix(shell_dark, shell_light, t * 0.9))
    layer.alpha_composite(Image.composite(grad, Image.new("RGBA", (W, H), (0, 0, 0, 0)), mask))

    # radial ribs + growth arcs
    detail = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(detail)
    for k in range(9):
        a = math.radians(205.0 + 130.0 * k / 8.0)
        dd.line([(cx, cy), (cx + math.cos(a) * R, cy + math.sin(a) * R)],
                fill=(170, 138, 110, 120), width=max(1, int(SS * 1.1)))
    for k in range(1, 4):
        rr = R * (0.34 + 0.2 * k)
        dd.arc([cx - rr, cy - rr, cx + rr, cy + rr], start=202, end=338,
               fill=(184, 152, 124, 85), width=max(1, SS))
    tint_mask(detail, mask)
    layer.alpha_composite(detail)

    # hinge ears sit behind the fan
    ears = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ed = ImageDraw.Draw(ears)
    for sgn in (-1, 1):
        ex = cx + sgn * R * 0.36
        ed.ellipse([ex - R * 0.20, cy - R * 0.17, ex + R * 0.20, cy + R * 0.15],
                   fill=mix(shell_dark, (0, 0, 0, 255), 0.12))
    layer.alpha_composite(ears)

    # bright rim
    rim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(rim).line(fan, fill=(255, 253, 246, 210), width=max(1, int(SS * 1.4)))
    layer.alpha_composite(rim)

    img.alpha_composite(layer)
    return save(img, w, h, "shell.png")


def atlas(images, cols=3):
    """Contact sheet for eyeballing every sprite at once.

    Written to /tmp so a --preview run never leaves a stray image in the game's
    texture folder for Godot to import.
    """
    rows = (len(images) + cols - 1) // cols
    cw = max(i.width for i in images) + 16
    ch = max(i.height for i in images) + 16
    sheet = Image.new("RGBA", (cw * cols, ch * rows), (26, 44, 56, 255))
    for k, im in enumerate(images):
        r, c = divmod(k, cols)
        sheet.alpha_composite(im, (c * cw + 8, r * ch + 8))
    path = "/tmp/opencode/flotsam_atlas.png"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    print("wrote %s" % path)


if __name__ == "__main__":
    made = [kelp(), seagrass(), shell()]
    if "--preview" in sys.argv:
        atlas(made)
