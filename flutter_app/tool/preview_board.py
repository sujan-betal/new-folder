"""Offline preview renderer for the Ludo board.

The Flutter toolchain is blocked on this machine (Smart App Control refuses to
run impellerc.exe), so this draws the board with the exact geometry and palette
from BoardGeometry / BoardPainter and writes a PNG. It exists to eyeball the
layout, colours, arrows, stars and token placement without a Flutter build.

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

COLORS = {
    "red": (0xE5, 0x39, 0x35),
    "green": (0x43, 0xA0, 0x47),
    "yellow": (0xFD, 0xD8, 0x35),
    "blue": (0x1E, 0x88, 0xE5),
}
GOLD = (0xFF, 0xC9, 0x3C)
GOLD_DARK = (0xF5, 0xA6, 0x23)
OUTLINE = (0x1A, 0x1A, 0x1A)
LINE = (0x37, 0x47, 0x4F)
WHITE = (0xFF, 0xFF, 0xFF)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def light_of(c):
    return lerp(c, WHITE, 0.34)


def dark_of(c):
    return lerp(c, (0, 0, 0), 0.24)


# ------------------------------------------------------------------ canvas
class Canvas:
    def __init__(self, w, h, bg=WHITE):
        self.w = w
        self.h = h
        self.px = bytearray(w * h * 3)
        for i in range(0, len(self.px), 3):
            self.px[i:i + 3] = bytes(bg)

    def _row(self, y):
        return y * self.w * 3

    def blend(self, y, x0, x1, color, cov):
        """Blend coverage `cov` (0..1) of `color` across [x0, x1) on row y."""
        if y < 0 or y >= self.h or cov <= 0:
            return
        x0 = max(0, int(math.floor(x0)))
        x1 = min(self.w, int(math.ceil(x1)))
        if x1 <= x0:
            return
        if cov >= 0.999:
            c = bytes((int(color[0]), int(color[1]), int(color[2])))
            start = self._row(y) + x0 * 3
            self.px[start:start + (x1 - x0) * 3] = c * (x1 - x0)
            return
        a = cov
        ia = 1.0 - a
        px = self.px
        base = self._row(y)
        for x in range(x0, x1):
            i = base + x * 3
            px[i] = int(px[i] * ia + color[0] * a)
            px[i + 1] = int(px[i + 1] * ia + color[1] * a)
            px[i + 2] = int(px[i + 2] * ia + color[2] * a)

    def fill_polys(self, polys, color, alpha=1.0, ss=4):
        """Even-odd fill of a list of polygons with anti-aliasing.

        Passing an outer + inner polygon yields a ring/stroke for free.
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
        y_start = max(0, int(math.floor(ymin)))
        y_end = min(self.h, int(math.ceil(ymax)) + 1)
        for y in range(y_start, y_end):
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
                    ia, ib = int(math.floor(xa)), int(math.ceil(xb))
                    for x in range(max(0, ia), min(self.w, ib)):
                        left = max(xa, x)
                        right = min(xb, x + 1)
                        if right > left:
                            cov[x] = cov.get(x, 0.0) + (right - left) / ss
            for x, c in cov.items():
                self.blend(y, x, x + 1, color, min(1.0, c) * alpha)

    def fill_rect(self, x, y, w, h, color, alpha=1.0):
        self.fill_polys([[(x, y), (x + w, y), (x + w, y + h), (x, y + h)]],
                         color, alpha)

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
            out = struct.pack(">I", len(data)) + tag + data
            return out + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)


    def vgrad(self, x, y, w, h, stops, alpha=1.0):
        """Smooth vertical gradient.

        stops = [(t, (r, g, b)), ...] with t ascending over 0..1. The Dart
        side paints with a real LinearGradient shader, so the preview has to
        interpolate as well - flat bands would invent problems the app does
        not have, and hide ones it does.
        """
        x0 = max(0, int(math.floor(x)))
        x1 = min(self.w, int(math.ceil(x + w)))
        y0 = max(0, int(math.floor(y)))
        y1 = min(self.h, int(math.ceil(y + h)))
        span = max(1.0, h - 1)
        for yy in range(y0, y1):
            t = min(1.0, max(0.0, (yy + 0.5 - y) / span))
            c = stops[-1][1]
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t0 <= t <= t1:
                    k = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
                    c = lerp(c0, c1, k)
                    break
            self.blend(yy, x0, x1, c, alpha)


def _mid(a, b):
    return lerp(a, b, 0.5)


def _circle_poly(cx, cy, r, seg=64):
    return [(cx + r * math.cos(2 * math.pi * i / seg),
             cy + r * math.sin(2 * math.pi * i / seg)) for i in range(seg)]


def rrect(x, y, w, h, r, seg=8):
    """Rounded rectangle as a polygon."""
    pts = []
    corners = [(x + w - r, y + h - r, 0), (x + r, y + h - r, 90),
               (x + r, y + r, 180), (x + w - r, y + r, 270)]
    for cx, cy, a0 in corners:
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def star(cx, cy, r, points=5, inner=0.45):
    pts = []
    for i in range(points * 2):
        a = -math.pi / 2 + i * math.pi / points
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def rot(pts, deg):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return [(x * ca - y * sa, x * sa + y * ca) for x, y in pts]


# ------------------------------------------------------------------- board
ARROW_ANGLE = {"red": 0, "green": 90, "yellow": 180, "blue": -90}

# One token per colour in its yard, plus a spread of positions on the track so
# the preview shows how pieces sit on start squares, safe squares, lanes and
# the centre.
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


def draw_board(cell, cv, ox=0, oy=0, tokens=None):
    """Draw one board; `tokens` = [(colour, token_index, rel_pos), ...]."""
    def X(v):
        return ox + v * cell

    def Y(v):
        return oy + v * cell

    # --- track ---------------------------------------------------------
    for i, (r, c) in enumerate(RING):
        x, y = X(c), Y(r)
        is_start = i in START.values()
        colour = next(k for k, v in START.items() if v == i) if is_start else None
        if is_start:
            col = COLORS[colour]
            cv.vgrad(x, y, cell, cell, [(0.0, light_of(col)), (0.5, col),
                                        (1.0, dark_of(col))])
            # chunky white arrowhead
            r0 = cell * 0.32
            cx, cy = X(c + 0.5), Y(r + 0.5)
            arrow = [(-r0, 0), (-r0 * 0.55, -r0 * 0.85), (-r0 * 0.22, 0),
                     (-r0 * 0.55, r0 * 0.85)]
            arrow = [(a, b) for a, b in arrow]
            arrow = [(a + r0, b) for a, b in arrow]
            p = rot(arrow, ARROW_ANGLE[colour])
            cv.fill_polys([[(cx + a, cy + b) for a, b in p]], WHITE)
        else:
            cv.fill_rect(x, y, cell, cell, WHITE)
            n = cell * 0.14
            cv.fill_rect(x + n, y + n, cell - 2 * n, cell - 2 * n, WHITE)
            cv.fill_polys([rrect(x + n, y + n, cell - 2 * n, cell - 2 * n, n * 0.7)],
                          (0, 0, 0), 0.0)
            if i in SAFE:
                cv.fill_polys([star(X(c + 0.5), Y(r + 0.5), cell * 0.27)], GOLD)
                cv.fill_polys([star(X(c + 0.5), Y(r + 0.5), cell * 0.30),
                               star(X(c + 0.5), Y(r + 0.5), cell * 0.22)],
                              GOLD_DARK)
        cv.fill_polys([[(x, y), (x + cell, y), (x + cell, y + cell), (x, y + cell),
                        (x, y)],
                       rrect(x + cell * 0.035, y + cell * 0.035,
                             cell - cell * 0.07, cell - cell * 0.07, 1)],
                      OUTLINE, 0.9, ss=3)

    # --- home lanes ----------------------------------------------------
    lane_angle = {"red": 0, "green": 90, "yellow": 180, "blue": -90}
    for name, cells in LANE.items():
        col = COLORS[name]
        for idx, (r, c) in enumerate(cells):
            x, y = X(c), Y(r)
            cv.vgrad(x, y, cell, cell, [(0.0, light_of(col)), (0.5, col),
                                        (1.0, dark_of(col))])
            cx, cy = X(c + 0.5), Y(r + 0.5)
            if idx == len(cells) - 1:
                cv.fill_polys([star(cx, cy, cell * 0.32)], WHITE)
            else:
                rr = cell * 0.26
                chev = [(-rr * 0.55, -rr * 0.9), (rr * 0.6, 0), (-rr * 0.55, rr * 0.9)]
                p = rot(chev, lane_angle[name])
                cv.fill_polys([[(cx + a, cy + b) for a, b in p]], WHITE)
            cv.fill_polys([[(x, y), (x + cell, y), (x + cell, y + cell), (x, y + cell),
                            (x, y)],
                           rrect(x + cell * 0.035, y + cell * 0.035,
                                 cell - cell * 0.07, cell - cell * 0.07, 1)],
                          OUTLINE, 0.85, ss=3)

    # --- bases ---------------------------------------------------------
    for name, (r0, c0) in BASE_ORIGIN.items():
        col = COLORS[name]
        bx, by = X(c0), Y(r0)
        bw = bh = cell * 6
        cv.vgrad(bx, by, bw, bh, [(0.0, light_of(col)), (0.55, col),
                                   (1.0, dark_of(col))], 0.0)
        _grad_rrect(cv, rrect(bx, by, bw, bh, cell * 0.30), by, bh,
                    [(0.0, light_of(col)), (0.55, col), (1.0, dark_of(col))])
        cv.fill_polys([rrect(bx, by, bw, bh, cell * 0.30),
                       rrect(bx + cell * 0.07, by + cell * 0.07,
                             bw - cell * 0.14, bh - cell * 0.14, cell * 0.24)],
                      OUTLINE)

        yx, yy = X(c0 + 1), Y(r0 + 1)
        ys = cell * 4
        cv.fill_polys([rrect(yx, yy, ys, ys, cell * 0.40)], WHITE)
        cv.fill_polys([rrect(yx, yy, ys, ys, cell * 0.40),
                       rrect(yx - cell * 0.11, yy - cell * 0.11,
                             ys + cell * 0.22, ys + cell * 0.22, cell * 0.46)],
                      col)

        for s in ((2, 2), (2, 4), (4, 2), (4, 4)):
            cx, cy = X(c0 + s[0]), Y(r0 + s[1])
            r = cell * 0.56
            cv.circle(cx, cy, r, WHITE)
            cv.circle(cx, cy, r * 0.88, col)
            cv.circle(cx, cy, r * 0.60, lerp(col, WHITE, 0.35))
            cv.ring(cx, cy, r * 0.88, cell * 0.09, OUTLINE)

    # --- centre --------------------------------------------------------
    cxy = (X(7.5), Y(7.5))
    tris = {
        "red": [(6, 6), (6, 9)],
        "green": [(6, 6), (9, 6)],
        "yellow": [(9, 6), (9, 9)],
        "blue": [(6, 9), (9, 9)],
    }
    for name, (a, b) in tris.items():
        col = COLORS[name]
        pts = [(X(a[0]), Y(a[1])), (X(b[0]), Y(b[1])), cxy]
        cv.fill_polys([pts], light_of(col))
        cv.fill_polys([pts], col, 0.55)
    # white cross
    cv.fill_polys([[(X(6), Y(6)), (X(9), Y(9)), (X(6) + cell * 0.09, Y(6) + cell * 0.09),
                    (X(6), Y(6) + cell * 0.18)],
                   [(X(9) - cell * 0.09, Y(9) - cell * 0.09), (X(9), Y(9) - cell * 0.18),
                    (X(9), Y(9)), (X(9) - cell * 0.18, Y(9))]], WHITE)
    cv.fill_polys([[(X(9), Y(6)), (X(6), Y(9)), (X(9) - cell * 0.09, Y(6) + cell * 0.09),
                    (X(9), Y(6) + cell * 0.18)],
                   [(X(6) + cell * 0.09, Y(9) - cell * 0.09), (X(6) + cell * 0.18, Y(9)),
                    (X(6), Y(9)), (X(6), Y(9) - cell * 0.18)]], WHITE)
    cv.fill_polys([[(X(6), Y(6)), (X(9), Y(6)), (X(9), Y(9)), (X(6), Y(9)), (X(6), Y(6))],
                   rrect(X(6) + cell * 0.045, Y(6) + cell * 0.045,
                         cell * 3 - cell * 0.09, cell * 3 - cell * 0.09, 1)],
                  OUTLINE)

    mr = cell * 0.78
    cv.circle(cxy[0], cxy[1], mr * 1.14, lerp(OUTLINE, WHITE, 0.55))
    cv.circle(cxy[0], cxy[1], mr, WHITE)
    cv.ring(cxy[0], cxy[1], mr * 0.84, cell * 0.09, GOLD)
    cv.fill_polys([star(cxy[0], cxy[1], mr * 0.60)], GOLD)
    cv.fill_polys([star(cxy[0], cxy[1], mr * 0.66),
                   star(cxy[0], cxy[1], mr * 0.50)], GOLD_DARK)

    # --- tokens --------------------------------------------------------
    for (colour, index, pos) in (tokens or []):
        cx, cy = token_center(colour, pos, index, X, Y)
        draw_token(cv, cx, cy, cell * 0.86, COLORS[colour], glow=pos == 0)


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
        nudge = {"red": (-0.62, 0), "green": (0, -0.62),
                 "yellow": (0.62, 0), "blue": (0, 0.62)}[colour]
        return X(7.5 + nudge[0]), Y(7.5 + nudge[1])
    r, c = RING[(START[colour] + pos) % 52]
    return X(c + 0.5), Y(r + 0.5)


def draw_token(cv, cx, cy, s, col, glow=False):
    """Squat ludo counter: wide foot, short stem, domed head, two stripes.

    Drawn back-to-front rather than as one even-odd path: overlapping
    sub-shapes would XOR into holes under the even-odd rule.
    """
    head_r = s * 0.26
    head_cy = cy - s * 0.62 + head_r
    neck_y = head_cy + head_r * 0.45
    foot_rx = s * 0.36
    foot_ry = s * 0.112
    foot_cy = cy - foot_ry
    stem_hw = s * 0.175
    edge = s * 0.030

    def silhouette(dx, dy_head, dy_foot, scale=1.0):
        """Head + stem + foot as three stacked fills (bottom-up order)."""
        hr = head_r + dx
        hcy = head_cy + dy_head
        fcx = foot_cy + dy_foot
        return (hr, hcy, fcx)

    # 1) outline pass - fattened silhouette
    for colr in (GOLD if glow else OUTLINE,):
        hr, hcy, fcy = silhouette(edge, 0, 0)
        cv.circle(cx, hcy, hr, colr)
        cv.fill_polys([rrect(cx - stem_hw - edge, hcy,
                             (stem_hw + edge) * 2, fcy - hcy + foot_ry + edge,
                             s * 0.09)], colr)
        cv.fill_polys([_ellipse(cx, fcy, foot_rx + edge, foot_ry + edge)], colr)

    # 2) body pass
    cv.circle(cx, head_cy, head_r, col)
    cv.fill_polys([rrect(cx - stem_hw, head_cy, stem_hw * 2,
                         foot_cy - head_cy + foot_ry, s * 0.08)], col)
    cv.fill_polys([_ellipse(cx, foot_cy, foot_rx, foot_ry)], col)

    # 3) shading - light from the upper left
    cv.circle(cx - s * 0.06, head_cy - s * 0.06, head_r * 0.55,
              light_of(col), 0.55)
    cv.fill_polys([_ellipse(cx, foot_cy, foot_rx, foot_ry),
                   _ellipse(cx, foot_cy - s * 0.035, foot_rx * 0.8,
                            foot_ry * 0.55)], light_of(col), 0.35)

    # 4) white collar under the head + thin ring at the foot
    cv.fill_polys([rrect(cx - stem_hw * 1.12, neck_y,
                         stem_hw * 2.24, s * 0.085, s * 0.03)], WHITE)
    cv.fill_polys([rrect(cx - stem_hw * 1.2, neck_y + s * 0.085,
                         stem_hw * 2.4, s * 0.022, s * 0.01)],
                  (0, 0, 0), 0.16)
    cv.fill_polys([rrect(cx - foot_rx * 0.92, foot_cy + foot_ry * 0.35,
                         foot_rx * 1.84, s * 0.032, s * 0.014)], WHITE, 0.6)


def _grad_rrect(cv, poly, top, height, stops):
    """Vertical gradient clipped to a rounded-rect polygon."""
    xs = [p[0] for p in poly]
    x0, x1 = int(min(xs)), int(max(xs)) + 1
    for yy in range(int(top), int(top + height)):
        t = min(1.0, max(0.0, (yy + 0.5 - top) / max(1.0, height - 1)))
        c = stops[-1][1]
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1:
                k = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
                c = lerp(c0, c1, k)
                break
        cv.fill_polys([poly], c, 0.0)
        # re-fill only this scanline by intersecting: cheap approach is to
        # fill the row via the polygon clipper at a 1px band
        _fill_poly_row(cv, poly, yy, c)


def _fill_poly_row(cv, poly, y, color):
    """Fill a single scanline of a polygon (non-zero, single contour)."""
    xs = []
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        if (y0 <= y < y1) or (y1 <= y < y0):
            t = (y - y0) / (y1 - y0)
            xs.append(x0 + (x1 - x0) * t)
    xs.sort()
    for i in range(0, len(xs) - 1, 2):
        cv.blend(y, xs[i], xs[i + 1], color, 1.0)


def _ellipse(cx, cy, rx, ry, seg=48):
    return [(cx + rx * math.cos(2 * math.pi * i / seg),
             cy + ry * math.sin(2 * math.pi * i / seg)) for i in range(seg)]


def draw_dice(cv, cx, cy, size, tray_col, pips=5):
    """Coloured tray + white die, matching DiceWidget."""
    tray_r = size * 0.85
    cv.circle(cx, cy, tray_r, light_of(tray_col))
    cv.circle(cx, cy, tray_r * 0.94, tray_col)
    cv.circle(cx + tray_r * 0.12, cy + tray_r * 0.14, tray_r * 0.8, dark_of(tray_col), 0.45)
    cv.ring(cx, cy, tray_r * 0.95, size * 0.09, WHITE)

    h = size * 0.33
    cv.fill_polys([rrect(cx - h, cy - h, size, size, size * 0.24)], (0xE4, 0xE4, 0xE4))
    cv.fill_polys([rrect(cx - h, cy - h, size, size, size * 0.24),
                   rrect(cx - h, cy + h * 0.1, size, size * 0.9, size * 0.24)],
                  (0xD2, 0xD2, 0xD2), 0.7)
    cv.fill_polys([rrect(cx - h, cy - h, size, size, size * 0.24)], WHITE, 0.75)
    cv.fill_polys([rrect(cx - h, cy - h, size, size, size * 0.24),
                   rrect(cx - h + size * 0.03, cy - h + size * 0.03,
                         size - size * 0.06, size - size * 0.06, size * 0.21)],
                  OUTLINE)

    layout = {
        1: [(.5, .5)],
        2: [(.26, .26), (.74, .74)],
        3: [(.25, .25), (.5, .5), (.75, .75)],
        4: [(.26, .26), (.74, .26), (.26, .74), (.74, .74)],
        5: [(.25, .25), (.75, .25), (.5, .5), (.25, .75), (.75, .75)],
        6: [(.25, .20), (.75, .20), (.25, .5), (.75, .5), (.25, .80), (.75, .80)],
    }
    face = size * 0.80
    fx, fy = cx - face / 2, cy - face / 2
    pr = face * 0.145
    for (u, v) in layout[pips]:
        px, py = fx + u * face, fy + v * face
        cv.circle(px, py, pr, (0x1A, 0x1A, 0x1A))
        cv.circle(px - pr * 0.3, py - pr * 0.32, pr * 0.3, (0xBB, 0xBB, 0xBB), 0.6)


def draw_zoom(cv, cell, ox, oy, region, tokens):
    """Render one region of the board at a larger cell size."""
    r0, r1, c0, c1 = region
    w = (c1 - c0) * cell
    h = (r1 - r0) * cell

    def X(v):
        return ox + (v - c0) * cell

    def Y(v):
        return oy + (v - r0) * cell

    def token_center(colour, pos, index):
        if pos < 0:
            br, bc = BASE_ORIGIN[colour]
            slots = ((2, 2), (2, 4), (4, 2), (4, 4))
            s = slots[min(index, 3)]
            return X(bc + s[0]), Y(br + s[1])
        if 52 <= pos < 57:
            r, c = LANE[colour][pos - 52]
            return X(c + 0.5), Y(r + 0.5)
        if pos >= 57:
            n = {"red": (-0.62, 0), "green": (0, -0.62),
                 "yellow": (0.62, 0), "blue": (0, 0.62)}[colour]
            return X(7.5 + n[0]), Y(7.5 + n[1])
        r, c = RING[(START[colour] + pos) % 52]
        return X(c + 0.5), Y(r + 0.5)

    # Background board surface.
    cv.fill_rect(ox - cell * 0.5, oy - cell * 0.5, w + cell, h + cell, WHITE)

    # Bases clipped to the region.
    for name, (br, bc) in BASE_ORIGIN.items():
        if br + 6 <= r0 or br >= r1 or bc + 6 <= c0 or bc >= c1:
            continue
        col = COLORS[name]
        bx, by = X(bc), Y(br)
        s6 = cell * 6
        cv.fill_polys([rrect(bx, by, s6, s6, cell * 0.30)], light_of(col))
        cv.fill_polys([rrect(bx, by, s6, s6, cell * 0.30),
                       rrect(bx, by + s6 * 0.28, s6, s6 * 0.72, cell * 0.30)], col)
        cv.fill_polys([rrect(bx, by, s6, s6, cell * 0.30),
                       rrect(bx, by + s6 * 0.62, s6, s6 * 0.38, cell * 0.30)],
                      dark_of(col))
        cv.fill_polys([rrect(bx, by, s6, s6, cell * 0.30),
                       rrect(bx + cell * 0.07, by + cell * 0.07,
                             s6 - cell * 0.14, s6 - cell * 0.14, cell * 0.24)],
                      OUTLINE)
        yx, yy = X(bc + 1), Y(br + 1)
        ys = cell * 4
        cv.fill_polys([rrect(yx, yy, ys, ys, cell * 0.40)], WHITE)
        cv.fill_polys([rrect(yx, yy, ys, ys, cell * 0.40),
                       rrect(yx - cell * 0.11, yy - cell * 0.11,
                             ys + cell * 0.22, ys + cell * 0.22, cell * 0.46)], col)
        for s in ((2, 2), (2, 4), (4, 2), (4, 4)):
            cx, cy = X(bc + s[0]), Y(br + s[1])
            r = cell * 0.56
            cv.circle(cx, cy, r, WHITE)
            cv.circle(cx, cy, r * 0.88, col)
            cv.circle(cx, cy, r * 0.60, lerp(col, WHITE, 0.35))
            cv.ring(cx, cy, r * 0.88, cell * 0.09, OUTLINE)

    # Ring cells.
    for i, (r, c) in enumerate(RING):
        if r < r0 or r >= r1 or c < c0 or c >= c1:
            continue
        x, y = X(c), Y(r)
        is_start = i in START.values()
        if is_start:
            name = next(k for k, v in START.items() if v == i)
            col = COLORS[name]
            cv.vgrad(x, y, cell, cell, [(0.0, light_of(col)), (0.5, col),
                                        (1.0, dark_of(col))])
            r0a = cell * 0.32
            cx, cy = X(c + 0.5), Y(r + 0.5)
            # Same polygon as BoardPainter._drawArrow: tip at +1.0r, tail
            # corners at -0.55r, concave back at -0.22r.
            pts = [(r0a, 0.0), (-r0a * 0.55, -r0a * 0.85), (-r0a * 0.22, 0.0),
                   (-r0a * 0.55, r0a * 0.85)]
            p = rot(pts, ARROW_ANGLE[name])
            cv.fill_polys([[(cx + a, cy + b) for a, b in p]], WHITE)
        else:
            cv.fill_rect(x, y, cell, cell, WHITE)
            if i in SAFE:
                cv.fill_polys([star(X(c + 0.5), Y(r + 0.5), cell * 0.27)], GOLD)
                cv.fill_polys([star(X(c + 0.5), Y(r + 0.5), cell * 0.30),
                               star(X(c + 0.5), Y(r + 0.5), cell * 0.22)], GOLD_DARK)
        cv.fill_polys([[(x, y), (x + cell, y), (x + cell, y + cell), (x, y + cell),
                        (x, y)],
                       rrect(x + cell * 0.026, y + cell * 0.026,
                             cell - cell * 0.052, cell - cell * 0.052, 1)],
                      OUTLINE, 0.85, ss=3)

    # Lanes.
    for name, cells in LANE.items():
        col = COLORS[name]
        for idx, (r, c) in enumerate(cells):
            if r < r0 or r >= r1 or c < c0 or c >= c1:
                continue
            x, y = X(c), Y(r)
            cv.vgrad(x, y, cell, cell, [(0.0, light_of(col)), (0.5, col),
                                        (1.0, dark_of(col))])
            cx, cy = X(c + 0.5), Y(r + 0.5)
            if idx == len(cells) - 1:
                cv.fill_polys([star(cx, cy, cell * 0.30)], WHITE)
            else:
                rr = cell * 0.26
                chev = [(-rr * 0.55, -rr * 0.9), (rr * 0.6, 0), (-rr * 0.55, rr * 0.9)]
                p = rot(chev, ARROW_ANGLE[name])
                cv.fill_polys([[(cx + a, cy + b) for a, b in p]], WHITE)
            cv.fill_polys([[(x, y), (x + cell, y), (x + cell, y + cell),
                            (x, y + cell), (x, y)],
                           rrect(x + cell * 0.026, y + cell * 0.026,
                                 cell - cell * 0.052, cell - cell * 0.052, 1)],
                          OUTLINE, 0.85, ss=3)

    # Tokens.
    for (colour, index, pos) in tokens:
        cx, cy = token_center(colour, pos, index)
        if not (ox - cell <= cx <= ox + w + cell and oy - cell <= cy <= oy + h + cell):
            continue
        draw_token(cv, cx, cy, cell * 0.86, COLORS[colour], glow=False)
    return w, h


def main():
    cell = 78
    pad = 34
    size = GRID * cell
    here = os.path.dirname(os.path.abspath(__file__))
    outdir = os.path.normpath(os.path.join(here, "..", "build_preview"))
    os.makedirs(outdir, exist_ok=True)

    # 1) full board
    cv = Canvas(size + pad * 2, size + pad * 2, (0x12, 0x1B, 0x3C))
    draw_board(cell, cv, pad, pad, tokens=DEMO_TOKENS)
    p = os.path.join(outdir, "board.png")
    cv.to_png(p)
    print("wrote", p)

    # 2) dice detail
    cv2 = Canvas(560, 300, (0x12, 0x1B, 0x3C))
    tray = [COLORS[k] for k in ("red", "green", "yellow", "blue", "red", "green")]
    for i, v in enumerate((1, 2, 3, 4, 5, 6)):
        draw_dice(cv2, 95 + (i % 3) * 180, 90 + (i // 3) * 140, 96, tray[i], pips=v)
    p2 = os.path.join(outdir, "dice.png")
    cv2.to_png(p2)
    print("wrote", p2)

    # 3) zoom on the top-right corner: green start + green home lane + centre
    zc = 150
    zpad = 20
    region = (0, 9, 5, 10)
    cvz = Canvas((region[3] - region[2]) * zc + zpad * 2,
                 (region[1] - region[0]) * zc + zpad * 2, (0x12, 0x1B, 0x3C))
    draw_zoom(cvz, zc, zpad, zpad, region,
              [("green", 0, 0), ("green", 1, 3), ("red", 0, 1), ("yellow", 0, 12),
               ("blue", 0, 24), ("green", 2, 4), ("green", 3, 5)])
    p3 = os.path.join(outdir, "zoom_green.png")
    cvz.to_png(p3)
    print("wrote", p3)


if __name__ == "__main__":
    main()
