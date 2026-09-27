"""Offline preview renderer for the Ludo board.

The Flutter toolchain is blocked on this machine (Smart App Control refuses to
run impellerc.exe), so this draws the board with the exact geometry and palette
from BoardGeometry / BoardPainter and writes a PNG. It exists to eyeball the
layout, colours, arrows, stars and token placement without a Flutter build.

Keep in step with:
  lib/presentation/widgets/board_painter.dart
  lib/presentation/widgets/pawn_token.dart
  lib/presentation/widgets/dice_widget.dart

    python tool/preview_board.py
"""

import math
import os
import struct
import zlib

# ---------------------------------------------------------------- geometry
GRID = 15

RING = [
    (6, 1), (6, 2), (6, 3), (6, 4), (6, 5),
    (5, 6), (4, 6), (3, 6), (2, 6), (1, 6), (0, 6),
    (0, 7), (0, 8),
    (1, 8), (2, 8), (3, 8), (4, 8), (5, 8),
    (6, 9), (6, 10), (6, 11), (6, 12), (6, 13), (6, 14),
    (7, 14), (8, 14),
    (8, 13), (8, 12), (8, 11), (8, 10), (8, 9),
    (9, 8), (10, 8), (11, 8), (12, 8), (13, 8),
    (14, 8), (14, 7), (14, 6),
    (13, 6), (12, 6), (11, 6), (10, 6), (9, 6),
    (8, 5), (8, 4), (8, 3), (8, 2), (8, 1), (8, 0),
    (7, 0), (6, 0),
]

START = {"red": 0, "green": 13, "yellow": 26, "blue": 39}
SAFE = {0, 8, 13, 21, 26, 34, 39, 47}
BASE_ORIGIN = {"red": (0, 0), "green": (9, 0), "yellow": (9, 9), "blue": (0, 9)}
LANE = {
    "red": [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
    "green": [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)],
    "yellow": [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9)],
    "blue": [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
}

# Bright, flat Ludo King colours.
COLORS = {
    "red": (0xF0, 0x3A, 0x33),
    "green": (0x43, 0xA0, 0x47),
    "yellow": (0xFD, 0xDD, 0x24),
    "blue": (0x27, 0xAE, 0xE8),
}

LINE = (0x6B, 0x6B, 0x6B)
STAR_INK = (0x3A, 0x3A, 0x3A)
TRACK = (0xFD, 0xFD, 0xFD)
WHITE = (0xFF, 0xFF, 0xFF)
INK = (0x2B, 0x2B, 0x2B)

HAIRLINE = 0.045          # cell fraction, matches _lineWidthRatio
ARROW_ANGLE = {"red": 0, "green": 90, "yellow": 180, "blue": -90}


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def light_of(c):
    return lerp(c, WHITE, 0.28)


def dark_of(c):
    return lerp(c, (0, 0, 0), 0.22)


# ------------------------------------------------------------------ canvas
class Canvas:
    def __init__(self, w, h, bg=WHITE):
        self.w = w
        self.h = h
        self.px = bytearray(w * h * 3)
        for i in range(0, len(self.px), 3):
            self.px[i:i + 3] = bytes(bg)

    def blend(self, y, x0, x1, color, cov):
        if y < 0 or y >= self.h or cov <= 0:
            return
        x0 = max(0, int(math.floor(x0)))
        x1 = min(self.w, int(math.ceil(x1)))
        if x1 <= x0:
            return
        if cov >= 0.999:
            c = bytes((int(color[0]), int(color[1]), int(color[2])))
            start = y * self.w * 3 + x0 * 3
            self.px[start:start + (x1 - x0) * 3] = c * (x1 - x0)
            return
        a, ia = cov, 1.0 - cov
        px, base = self.px, y * self.w * 3
        for x in range(x0, x1):
            i = base + x * 3
            px[i] = int(px[i] * ia + color[0] * a)
            px[i + 1] = int(px[i + 1] * ia + color[1] * a)
            px[i + 2] = int(px[i + 2] * ia + color[2] * a)

    def fill_polys(self, polys, color, alpha=1.0, ss=4):
        """Even-odd fill of several contours.

        Overlapping contours XOR into holes, so pass one contour per call
        unless a ring is genuinely wanted.
        """
        edges = []
        ymin, ymax = 1e9, -1e9
        for poly in polys:
            n = len(poly)
            for i in range(n):
                x0, y0 = poly[i]
                x1, y1 = poly[(i + 1) % n]
                if y0 == y1:
                    continue
                edges.append((y0, y1, x0, (x1 - x0) / (y1 - y0)))
                ymin = min(ymin, y0, y1)
                ymax = max(ymax, y0, y1)
        if not edges:
            return
        for y in range(max(0, int(math.floor(ymin))),
                       min(self.h, int(math.ceil(ymax)) + 1)):
            cov = {}
            for s in range(ss):
                sy = y + (s + 0.5) / ss
                xs = []
                for (ey0, ey1, ex, slope) in edges:
                    lo, hi = (ey0, ey1) if ey0 < ey1 else (ey1, ey0)
                    if lo <= sy < hi:
                        xs.append(ex + (sy - ey0) * slope)
                if not xs:
                    continue
                xs.sort()
                for i in range(0, len(xs) - 1, 2):
                    xa, xb = xs[i], xs[i + 1]
                    if xb <= xa:
                        continue
                    for x in range(max(0, int(math.floor(xa))),
                                   min(self.w, int(math.ceil(xb)))):
                        left, right = max(xa, x), min(xb, x + 1)
                        if right > left:
                            cov[x] = cov.get(x, 0.0) + (right - left) / ss
            for x, c in cov.items():
                self.blend(y, x, x + 1, color, min(1.0, c) * alpha)

    def fill_rect(self, x, y, w, h, color, alpha=1.0):
        self.fill_polys([[(x, y), (x + w, y), (x + w, y + h), (x, y + h)]],
                        color, alpha)

    def ring_rect(self, x, y, w, h, t, color, alpha=1.0):
        self.fill_polys([[(x, y), (x + w, y), (x + w, y + h), (x, y + h), (x, y)],
                         [(x + t, y + t), (x + t, y + h - t),
                          (x + w - t, y + h - t), (x + w - t, y + t),
                          (x + t, y + t)]], color, alpha, ss=3)

    def circle(self, cx, cy, r, color, alpha=1.0):
        self.fill_polys([_circle_poly(cx, cy, r)], color, alpha)

    def ring(self, cx, cy, r, w, color, alpha=1.0):
        self.fill_polys([_circle_poly(cx, cy, r + w / 2),
                         _circle_poly(cx, cy, max(0.0, r - w / 2))],
                        color, alpha)

    def to_png(self, path):
        raw = bytearray()
        stride = self.w * 3
        for y in range(self.h):
            raw.append(0)
            raw += self.px[y * stride:(y + 1) * stride]

        def chunk(tag, data):
            return (struct.pack(">I", len(data)) + tag + data
                    + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)


def _circle_poly(cx, cy, r, seg=56):
    return [(cx + r * math.cos(2 * math.pi * i / seg),
             cy + r * math.sin(2 * math.pi * i / seg)) for i in range(seg)]


def _ellipse_poly(cx, cy, rx, ry, seg=48):
    return [(cx + rx * math.cos(2 * math.pi * i / seg),
             cy + ry * math.sin(2 * math.pi * i / seg)) for i in range(seg)]


def star_poly(cx, cy, r, points=5, inner=0.45, phase=-math.pi / 2):
    pts = []
    for i in range(points * 2):
        a = phase + i * math.pi / points
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def rot(pts, deg):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return [(x * ca - y * sa, x * sa + y * ca) for x, y in pts]


# ------------------------------------------------------------------ board
def arrow_poly(cx, cy, cell, name):
    """Outlined arrowhead: tip at +1.0r, barbs at -0.55r, concave back."""
    r = cell * 0.34
    pts = [(cx + r, cy), (cx - r * 0.55, cy - r * 0.85),
           (cx - r * 0.22, cy), (cx - r * 0.55, cy + r * 0.85)]
    return rot(pts, ARROW_ANGLE[name])


def draw_arrow_outline(cv, cx, cy, cell, name):
    cv.fill_polys([arrow_poly(cx, cy, cell, name)], WHITE, 0.0)
    _stroke_poly(cv, arrow_poly(cx, cy, cell, name),
                 COLORS[name], cell * 0.085)


def _stroke_poly(cv, pts, color, width, closed=True):
    """Approximate a stroke by filling a fattened copy then the original."""
    n = len(pts)
    cx = sum(p[0] for p in pts) / n
    cy = sum(p[1] for p in pts) / n
    fat = [(cx + (x - cx) * 1.0 + 0, cy + (y - cy) * 1.0) for x, y in pts]
    # offset each vertex along the angle bisector
    out = []
    for i in range(n):
        px, py = pts[i]
        ax, ay = pts[i - 1]
        bx, by = pts[(i + 1) % n]
        v1 = (px - ax, py - ay)
        v2 = (bx - px, by - py)
        n1 = _norm(v1)
        n2 = _norm(v2)
        d = _norm((n1[0] + n2[0], n1[1] + n2[1]))
        scale = (width / 2) / max(0.35, (d[0] * n1[0] + d[1] * n1[1]))
        out.append((px + d[0] * scale, py + d[1] * scale))
    _ = fat
    cv.fill_polys([out, pts], color)


def _vgrad_clip(cv, poly, top, height, stops):
    """Vertical gradient clipped to a polygon, one scanline at a time."""
    for y in range(int(top), int(top + height) + 1):
        t = min(1.0, max(0.0, (y + 0.5 - top) / max(1.0, height)))
        c = stops[-1][1]
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1:
                k = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
                c = lerp(c0, c1, k)
                break
        _span_poly_row(cv, poly, y, c)


def _span_poly_row(cv, poly, y, color):
    xs = []
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        if (y0 <= y < y1) or (y1 <= y < y0):
            xs.append(x0 + (x1 - x0) * ((y - y0) / (y1 - y0)))
    xs.sort()
    for i in range(0, len(xs) - 1, 2):
        cv.blend(y, xs[i], xs[i + 1], color, 1.0)


def _norm(v):
    d = math.hypot(v[0], v[1]) or 1.0
    return (v[0] / d, v[1] / d)


def draw_safe_star(cv, cx, cy, cell):
    """Outlined star, like the print on a real board."""
    outer = star_poly(cx, cy, cell * 0.30)
    inner = star_poly(cx, cy, cell * 0.30 - cell * 0.055, inner=0.45)
    cv.fill_polys([outer, inner], TRACK, 1.0, ss=3)
    _stroke_poly(cv, star_poly(cx, cy, cell * 0.30), STAR_INK, cell * 0.055)


def draw_surface(cv, ox, oy, size, cell):
    cv.fill_rect(ox, oy, size, size, TRACK)
    t = cell * 0.04
    cv.ring_rect(ox + t, oy + t, size - 2 * t, size - 2 * t, t, LINE)


def cell_box(x, y, cell):
    t = cell * HAIRLINE / 2
    return t


def draw_track(cv, cell, X, Y):
    for i, (r, c) in enumerate(RING):
        x, y = X(c), Y(r)
        cv.fill_rect(x, y, cell, cell, TRACK)
        name = next((k for k, v in START.items() if v == i), None)
        if name is not None:
            draw_arrow_outline(cv, X(c + 0.5), Y(r + 0.5), cell, name)
        elif i in SAFE:
            draw_safe_star(cv, X(c + 0.5), Y(r + 0.5), cell)
        t = cell_box(x, y, cell)
        cv.ring_rect(x + t, y + t, cell - 2 * t, cell - 2 * t, t, LINE, 0.9)


def draw_lanes(cv, cell, X, Y):
    for name, cells in LANE.items():
        col = COLORS[name]
        for r, c in cells:
            x, y = X(c), Y(r)
            cv.fill_rect(x, y, cell, cell, col)
            t = cell_box(x, y, cell)
            cv.ring_rect(x + t, y + t, cell - 2 * t, cell - 2 * t, t, LINE, 0.9)


def draw_bases(cv, cell, X, Y, active=None):
    t = cell * HAIRLINE / 2
    for name, (r0, c0) in BASE_ORIGIN.items():
        col = COLORS[name]
        bx, by = X(c0), Y(r0)
        s6 = cell * 6
        cv.fill_rect(bx, by, s6, s6, col)
        if name == active:
            e = cell * 0.12
            cv.ring_rect(bx - e, by - e, s6 + 2 * e, s6 + 2 * e,
                         cell * 0.14, (0xFF, 0xC9, 0x3C))
        cv.ring_rect(bx + t, by + t, s6 - 2 * t, s6 - 2 * t, t, LINE, 0.9)
        yx, yy = X(c0 + 1), Y(r0 + 1)
        ys = cell * 4
        cv.fill_rect(yx, yy, ys, ys, TRACK)
        cv.ring_rect(yx + t, yy + t, ys - 2 * t, ys - 2 * t, t, LINE, 0.9)
        for s in ((2, 2), (2, 4), (4, 2), (4, 4)):
            cv.circle(X(c0 + s[0]), Y(r0 + s[1]), cell * 0.30, col)


def draw_center(cv, cell, X, Y):
    cx, cy = X(7.5), Y(7.5)
    tris = {
        "red": [(6, 6), (6, 9)],
        "yellow": [(9, 6), (9, 9)],
        "green": [(6, 6), (9, 6)],
        "blue": [(6, 9), (9, 9)],
    }
    for name, pts in tris.items():
        cv.fill_polys([[(X(pts[0][0]), Y(pts[0][1])),
                        (X(pts[1][0]), Y(pts[1][1])), (cx, cy)]],
                      COLORS[name])
    t = cell * HAIRLINE / 2
    cv.ring_rect(X(6) + t, Y(6) + t, cell * 3 - 2 * t, cell * 3 - 2 * t, t, LINE, 0.9)
    d = cell * 0.34
    dia = [(cx, cy - d), (cx + d, cy), (cx, cy + d), (cx - d, cy), (cx, cy - d)]
    cv.fill_polys([dia], (0x7F, 0xD4, 0xF5))
    _stroke_poly(cv, dia, LINE, cell * 0.05)


def token_center(colour, pos, index, X, Y):
    if pos < 0:
        r0, c0 = BASE_ORIGIN[colour]
        slots = ((2, 2), (2, 4), (4, 2), (4, 4))
        s = slots[min(index, 3)]
        return X(c0 + s[0]), Y(r0 + s[1])
    if 52 <= pos < 57:
        r, c = LANE[colour][pos - 52]
        return X(c + 0.5), Y(r + 0.5)
    if pos >= 57:
        n = {"red": (-0.62, 0), "green": (0, -0.62),
             "yellow": (0.62, 0), "blue": (0, 0.62)}[colour]
        return X(7.5 + n[0]), Y(7.5 + n[1])
    r, c = RING[(START[colour] + pos) % 52]
    return X(c + 0.5), Y(r + 0.5)


def draw_token(cv, cx, cy, w, col, glow=False):
    """Map-pin drop: round head, white ring, tapered point."""
    h = w * 0.80
    top = cy - h
    head_r = w * 0.38
    head_cy = top + head_r

    cv.fill_ellipse_row = None
    # shadow
    cv.fill_polys([_ellipse_poly(cx, cy, w * 0.26, w * 0.16)], (0, 0, 0), 0.20)
    if glow:
        cv.circle(cx, cy - h * 0.42, w * 0.55, (0xFF, 0xC9, 0x3C), 0.35)

    body = drop_poly(cx, top, w, cy)
    _vgrad_clip(cv, body, top, h,
                [(0.0, lerp(col, WHITE, 0.18)), (0.55, col),
                 (1.0, lerp(col, (0, 0, 0), 0.10))])

    # white ring punched through the head
    cv.circle(cx, head_cy, w * 0.20, WHITE)
    cv.ring(cx, head_cy, w * 0.20, w * 0.022, dark_of(col))
    # gloss
    cv.circle(cx - w * 0.22, head_cy - w * 0.10, w * 0.07, WHITE, 0.5)

    _stroke_poly(cv, body, (0xFF, 0xC9, 0x3C) if glow else INK, w * 0.055)


def body_shift_frac(pts, cx, cy, k):
    """Shrink a contour toward (cx, cy) - a cheap stand-in for a gradient."""
    return [(cx + (x - cx) * (1.0 - k * 0.35), cy + (y - cy) * (1.0 - k * 0.35))
            for x, y in pts]


def drop_poly(cx, top, w, bottom):
    head_r = w * 0.38
    head_cy = top + head_r
    pts = []
    seg = 40
    start, sweep = math.pi * 0.62, math.pi * 1.76
    for i in range(seg + 1):
        a = start + sweep * i / seg
        pts.append((cx + head_r * math.cos(a), head_cy + head_r * math.sin(a)))
    waist_y = top + head_r * 1.55
    tip_y = bottom - w * 0.03
    for i in range(1, 12):
        t = i / 12
        x = cx + w * 0.30 * (1 - t) ** 1.4
        y = waist_y + (tip_y - waist_y) * t
        pts.append((x, y))
    for i in range(1, 12):
        t = i / 12
        x = cx - w * 0.30 * (1 - t) ** 1.4
        y = tip_y + (waist_y - tip_y) * t
        pts.append((x, y))
    return pts


def draw_dice(cv, cx, cy, size, tray_col=(0xF7, 0xB8, 0xC4), pips=5):
    """Rounded-square tray with the die inside, matching DiceWidget."""
    tray = size * 0.5
    cv.fill_polys([rrect(cx - tray, cy - tray, tray * 2, tray * 2, size * 0.20)],
                  light_of(tray_col))
    cv.fill_polys([rrect(cx - tray, cy - tray, tray * 2, tray * 2, size * 0.20),
                   rrect(cx - tray, cy - tray + size * 0.16,
                         tray * 2 - size * 0.32, tray * 2 - size * 0.32,
                         size * 0.13)], tray_col, 0.55)
    cv.ring_rect(cx - tray, cy - tray, tray * 2, tray * 2, size * 0.05, tray_col)

    h = size * 0.33
    cv.fill_polys([rrect(cx - h, cy - h, h * 2, h * 2, h * 0.30)], (0xD8, 0xD8, 0xD8))
    cv.fill_polys([rrect(cx - h, cy - h, h * 2, h * 2, h * 0.30)], WHITE, 0.9)
    cv.ring_rect(cx - h, cy - h, h * 2, h * 2, h * 0.10, INK)

    layout = {
        1: [(.5, .5)],
        2: [(.26, .26), (.74, .74)],
        3: [(.25, .25), (.5, .5), (.75, .75)],
        4: [(.26, .26), (.74, .26), (.26, .74), (.74, .74)],
        5: [(.25, .25), (.75, .25), (.5, .5), (.25, .75), (.75, .75)],
        6: [(.25, .20), (.75, .20), (.25, .5), (.75, .5), (.25, .80), (.75, .80)],
    }
    face = h * 1.6
    fx, fy = cx - face / 2, cy - face / 2
    pr = face * 0.145
    for (u, v) in layout[pips]:
        px, py = fx + u * face, fy + v * face
        cv.circle(px, py, pr, (0x14, 0x14, 0x14))
        cv.circle(px - pr * 0.3, py - pr * 0.32, pr * 0.3, (0xC8, 0xC8, 0xC8), 0.55)


def rrect(x, y, w, h, r, seg=6):
    pts = []
    for cx, cy, a0 in ((x + w - r, y + h - r, 0), (x + r, y + h - r, 90),
                       (x + r, y + r, 180), (x + w - r, y + r, 270)):
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# ------------------------------------------------------------------- main
DEMO_TOKENS = [
    ("red", 0, -1), ("red", 1, -1), ("red", 2, -1), ("red", 3, -1),
    ("green", 0, -1), ("green", 1, -1), ("green", 2, -1), ("green", 3, -1),
    ("yellow", 0, -1), ("yellow", 1, -1), ("yellow", 2, -1), ("yellow", 3, -1),
    ("blue", 0, -1), ("blue", 1, -1), ("blue", 2, -1), ("blue", 3, -1),
    ("red", 0, 0), ("green", 0, 1), ("yellow", 0, 14), ("blue", 0, 27),
    ("red", 1, 5), ("green", 1, 8), ("yellow", 1, 21), ("blue", 1, 34),
    ("red", 2, 39), ("green", 2, 47), ("yellow", 2, 30), ("blue", 2, 44),
    ("red", 3, 52), ("green", 3, 55), ("yellow", 3, 56), ("blue", 3, 57),
]


def render_board(cell, pad, tokens, active=None, labels=False):
    size = GRID * cell
    cv = Canvas(size + pad * 2, size + pad * 2, (0x14, 0x1B, 0x3A))

    def X(v):
        return pad + v * cell

    def Y(v):
        return pad + v * cell

    draw_surface(cv, pad, pad, size, cell)
    draw_track(cv, cell, X, Y)
    draw_lanes(cv, cell, X, Y)
    draw_bases(cv, cell, X, Y, active=active)
    draw_center(cv, cell, X, Y)

    for (colour, index, pos) in tokens:
        cx, cy = token_center(colour, pos, index, X, Y)
        draw_token(cv, cx, cy, cell * 0.65, COLORS[colour],
                   glow=(pos >= 0 and pos < 4 and colour == active))

    if labels:
        for name, (r0, c0) in BASE_ORIGIN.items():
            top_row = r0 < 4
            cy = Y(r0 + 0.52) if top_row else Y(r0 + 5.48)
            _text(cv, name.upper(), X(c0 + 3), cy, cell * 0.34, WHITE, (0, 0, 0))
    return cv


_GLYPH_RECTS = []


def _text(cv, s, cx, cy, size, color, outline):
    """Tiny 5x7 bitmap font - enough for a label or two."""
    _GLYPH_RECTS.clear()
    FONT = {
        'A': ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        'B': ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
        'C': ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
        'D': ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
        'E': ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
        'G': ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
        'L': ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        'N': ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
        'O': ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        'R': ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
        'T': ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
        'U': ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
        'W': ["10001", "10001", "10001", "10101", "10101", "11011", "10001"],
        'Y': ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
        ' ': ["00000"] * 7,
    }
    px = size / 5.0
    total = len(s) * 6 * px - px
    x0 = cx - total / 2
    for i, ch in enumerate(s):
        glyph = FONT.get(ch.upper(), FONT[' '])
        for row, bits in enumerate(glyph):
            for col, bit in enumerate(bits):
                if bit != '1':
                    continue
                gx = x0 + i * 6 * px + col * px
                gy = cy - size / 2 + row * px
                if outline:
                    for dx in (-px, 0, px):
                        for dy in (-px, 0, px):
                            if dx or dy:
                                cv.fill_rect(gx + dx, gy + dy, px, px, outline)
                _GLYPH_RECTS.append((gx, gy, px, color))
    for (gx, gy, gp, gc) in _GLYPH_RECTS:
        cv.fill_rect(gx, gy, gp, gp, gc)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    outdir = os.path.normpath(os.path.join(here, "..", "build_preview"))
    os.makedirs(outdir, exist_ok=True)

    cell, pad = 76, 10
    cv = render_board(cell, pad, DEMO_TOKENS, active="green", labels=True)
    p = os.path.join(outdir, "board.png")
    cv.to_png(p)
    print("wrote", p)

    # zoom on the centre + red base corner
    zc, zpad = 150, 18
    cvz = Canvas(7 * zc + zpad * 2, 7 * zc + zpad * 2, (0x14, 0x1B, 0x3A))
    r0, c0 = 4, 4
    zoom_tokens = [("red", 0, 0), ("green", 0, 5), ("yellow", 0, 14),
                   ("blue", 0, 40), ("red", 1, 8), ("green", 1, 1),
                   ("red", 2, 39), ("yellow", 2, 30)]
    X = lambda v: zpad + (v - c0) * zc
    Y = lambda v: zpad + (v - r0) * zc
    cvz.fill_rect(zpad - zc * 0.5, zpad - zc * 0.5, 7 * zc + zc, 7 * zc + zc, TRACK)
    draw_track(cvz, zc, X, Y)
    draw_lanes(cvz, zc, X, Y)
    draw_bases(cvz, zc, X, Y, active="red")
    draw_center(cvz, zc, X, Y)
    for (colour, index, pos) in zoom_tokens:
        cx, cy = token_center(colour, pos, index, X, Y)
        draw_token(cvz, cx, cy, zc * 0.65, COLORS[colour],
                   glow=(colour == "red"))
    p3 = os.path.join(outdir, "zoom_centre.png")
    cvz.to_png(p3)
    print("wrote", p3)

    # dice detail
    cv2 = Canvas(560, 300, (0x14, 0x1B, 0x3A))
    for i, v in enumerate((1, 2, 3, 4, 5, 6)):
        draw_dice(cv2, 95 + (i % 3) * 180, 90 + (i // 3) * 140, 96, pips=v)
    p2 = os.path.join(outdir, "dice.png")
    cv2.to_png(p2)
    print("wrote", p2)


if __name__ == "__main__":
    main()
