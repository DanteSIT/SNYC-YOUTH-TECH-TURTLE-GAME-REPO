#!/usr/bin/env python3
"""Quick statistics for a PNG, so a capture can be sanity-checked without an eye.

The model cannot look at images, so every screenshot claim has to be backed by a
number. This reports the size, the fraction of pure-black pixels (a blank or
failed render), the mean colour, and the brightest 1% of pixels (whether anything
lit is present at all).

Usage:
    python3 tools/png_stats.py screenshots/*.png
"""
import struct
import sys
import zlib


def read_png(path):
    """Decode a PNG to (width, height, rows of RGB bytes).

    Supports the 8-bit colour types Godot writes: 2 (RGB) and 6 (RGBA).
    Handles all five filter types, which is the fiddly part.
    """
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG: %s" % path)
    pos, idat, ihdr = 8, b"", None
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            w, h, depth, colour = struct.unpack(">IIBB", chunk[:10])
            if depth != 8 or colour not in (2, 6):
                raise ValueError("unsupported %dx%d depth=%d colourtype=%d"
                                 % (w, h, depth, colour))
            ihdr = (w, h, colour)
        elif kind == b"IDAT":
            idat += chunk
        pos += 12 + length

    w, h, colour = ihdr
    bpp = 3 if colour == 2 else 4
    stride = w * bpp
    raw = zlib.decompress(idat)
    out = bytearray()
    prev = bytearray(stride)
    i = 0
    for _ in range(h):
        ftype = raw[i]
        i += 1
        line = bytearray(raw[i:i + stride])
        i += stride
        if ftype == 1:
            for x in range(bpp, stride):
                line[x] = (line[x] + line[x - bpp]) & 255
        elif ftype == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 255
        elif ftype == 3:
            for x in range(stride):
                left = line[x - bpp] if x >= bpp else 0
                line[x] = (line[x] + (left + prev[x]) // 2) & 255
        elif ftype == 4:
            for x in range(stride):
                a = line[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pred) & 255
        out += line
        prev = line
    return w, h, bpp, out


def stats(path):
    w, h, bpp, px = read_png(path)
    n = w * h
    black = 0
    sr = sg = sb = 0
    lums = []
    for k in range(0, n * bpp, bpp):
        r, g, b = px[k], px[k + 1], px[k + 2]
        sr += r
        sg += g
        sb += b
        if r < 8 and g < 8 and b < 8:
            black += 1
        lums.append((r * 299 + g * 587 + b * 114) // 1000)
    lums.sort()
    bright = lums[int(n * 0.99)]
    return w, h, n, 100.0 * black / n, (sr / n, sg / n, sb / n), bright, lums[-1]


for path in sys.argv[1:]:
    try:
        w, h, n, blackpct, mean, p99, peak = stats(path)
        print("%-34s %dx%d  black %5.2f%%  mean rgb %5.1f %5.1f %5.1f"
              "  R-B %+6.1f  p99 luma %3d  peak %3d"
              % (path.split("/")[-1], w, h, blackpct, mean[0], mean[1], mean[2],
                 mean[0] - mean[2], p99, peak))
    except Exception as exc:
        print("%-34s ERROR %s" % (path.split("/")[-1], exc))
