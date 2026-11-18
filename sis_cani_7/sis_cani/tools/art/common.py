# -*- coding: utf-8 -*-
"""SİS ÇANI pixel art ortak araçları: palet, kontur, gürültü, dithering, kayıt."""
import math, os, random
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art")

# --- Palet: gece mavisi + sis grisi + tek sıcak vurgu (lamba turuncusu)
P = {
    "k":      (9, 11, 17),
    "n0":     (16, 19, 28),
    "n1":     (24, 29, 41),
    "n2":     (35, 42, 58),
    "n3":     (50, 60, 80),
    "n4":     (70, 82, 104),
    "n5":     (96, 108, 130),
    "f1":     (122, 134, 152),
    "f2":     (152, 162, 178),
    "f3":     (186, 194, 205),
    "w0":     (255, 236, 180),
    "w1":     (255, 200, 112),
    "w2":     (240, 142, 62),
    "w3":     (176, 82, 42),
    "w4":     (104, 48, 32),
    "skin":   (204, 152, 118),
    "skin2":  (150, 102, 84),
    "coat":   (64, 54, 46),
    "coat2":  (44, 37, 33),
    "coat3":  (94, 80, 64),
    "cap":    (40, 41, 48),
    "pants":  (36, 39, 50),
    "boot":   (22, 21, 24),
    "wood":   (78, 58, 42),
    "wood2":  (56, 41, 31),
    "wood3":  (104, 80, 58),
    "iron":   (46, 48, 54),
    "iron2":  (70, 73, 80),
    "brass":  (150, 112, 52),
    "brass2": (196, 154, 76),
    "red":    (190, 38, 30),
    "red2":   (120, 20, 18),
    "paper":  (214, 202, 176),
    "paper2": (170, 156, 130),
    "glass":  (150, 186, 204),
    "sea0":   (20, 28, 40),
    "sea1":   (30, 42, 58),
    "moss":   (50, 62, 50),
    "moss2":  (70, 84, 64),
    "t0":     (18, 34, 40),
    "t1":     (26, 58, 64),
    "t2":     (52, 122, 122),
    "t3":     (120, 210, 196),
}


def rgba(c, a=255):
    if isinstance(c, str):
        c = P[c]
    return (c[0], c[1], c[2], a)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def px(img, x, y, c, a=255):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), rgba(c, a))


def blend(img, x, y, c, k):
    """Mevcut pikselin üstüne k (0..1) oranında renk karıştır (saydamlık açmaz)."""
    x, y = int(x), int(y)
    if 0 <= x < img.width and 0 <= y < img.height:
        o = img.getpixel((x, y))
        t = P[c] if isinstance(c, str) else c
        img.putpixel((x, y), (int(o[0] + (t[0] - o[0]) * k), int(o[1] + (t[1] - o[1]) * k), int(o[2] + (t[2] - o[2]) * k), max(o[3], int(255 * k))))


def rect(img, x0, y0, x1, y1, c, a=255):
    """dahil x0..x1, y0..y1"""
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            px(img, x, y, c, a)


def line(img, x0, y0, x1, y1, c, w=1):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(n, 1)
        x = round(x0 + (x1 - x0) * t)
        y = round(y0 + (y1 - y0) * t)
        for dx in range(w):
            for dy in range(w):
                px(img, x + dx - w // 2, y + dy - w // 2, c)


def ellipse(img, cx, cy, rx, ry, c, a=255):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / max(ry, 0.5)) ** 2 <= 1.0:
                px(img, x, y, c, a)


def poly(img, pts, c):
    d = ImageDraw.Draw(img)
    d.polygon([(round(x), round(y)) for x, y in pts], fill=rgba(c))


def outline(img, c="k", diag=False):
    """Opak piksellerin çevresine 1 px kontur."""
    w, h = img.size
    src = img.copy()
    sp = src.load()
    dp = img.load()
    offs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diag:
        offs += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] != 0:
                continue
            for dx, dy in offs:
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and sp[xx, yy][3] > 128:
                    dp[x, y] = rgba(c)
                    break
    return img


def rim(img, c, side=1, alpha_min=200):
    """Işık tarafına (side=1 sağ, -1 sol, 0 üst) ince kenar ışığı."""
    w, h = img.size
    src = img.copy().load()
    dp = img.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] < alpha_min or src[x, y][:3] == P["k"]:
                continue
            if side == 0:
                nx, ny = x, y - 1
            else:
                nx, ny = x + side, y
            if not (0 <= nx < w and 0 <= ny < h) or src[nx, ny][3] == 0 or src[nx, ny][:3] == P["k"]:
                dp[x, y] = rgba(c, src[x, y][3])
    return img


_rng = random.Random(1977)


def noise2(x, y, seed=0):
    n = int(x) * 374761393 + int(y) * 668265263 + seed * 2147483647
    n = (n ^ (n >> 13)) * 1274126177
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, y, seed=0):
    xi, yi = math.floor(x), math.floor(y)
    xf, yf = x - xi, y - yi
    u, v = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    a = noise2(xi, yi, seed)
    b = noise2(xi + 1, yi, seed)
    c = noise2(xi, yi + 1, seed)
    d = noise2(xi + 1, yi + 1, seed)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def fbm(x, y, seed=0, oct=4):
    v, a, f = 0.0, 0.5, 1.0
    for i in range(oct):
        v += a * vnoise(x * f, y * f, seed + i * 31)
        a *= 0.5
        f *= 2.0
    return v


def vnoise_wrap(x, y, period, seed=0):
    """x ekseninde period ile döşenebilir gürültü"""
    xi, yi = math.floor(x), math.floor(y)
    xf, yf = x - xi, y - yi
    u, v = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    def n(a, b):
        return noise2(a % period, b, seed)
    a, b, c, d = n(xi, yi), n(xi + 1, yi), n(xi, yi + 1), n(xi + 1, yi + 1)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def fbm_wrap(x, y, period, seed=0, oct=4):
    v, a, f = 0.0, 0.5, 1
    for i in range(oct):
        v += a * vnoise_wrap(x * f, y * f, period * f, seed + i * 31)
        a *= 0.5
        f *= 2
    return v


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dither(x, y, t):
    """t: 0..1 -> bu pikselde 'açık' renk mi"""
    return t * 16 > BAYER[y % 4][x % 4] + 0.5


def lerp_c(a, b, t):
    if isinstance(a, str):
        a = P[a]
    if isinstance(b, str):
        b = P[b]
    t = max(0.0, min(1.0, t))
    return (round(a[0] + (b[0] - a[0]) * t), round(a[1] + (b[1] - a[1]) * t), round(a[2] + (b[2] - a[2]) * t))


def ramp(colors, t, x=0, y=0, dith=True):
    """renk dizisi boyunca t (0..1), bantlar arası Bayer dithering"""
    t = max(0.0, min(0.9999, t))
    f = t * (len(colors) - 1)
    i = int(f)
    frac = f - i
    if dith:
        return colors[i + 1] if dither(x, y, frac) else colors[i]
    return lerp_c(colors[i], colors[i + 1], frac)


def save(img, name):
    path = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    return path


def sheet(frames):
    w, h = frames[0].size
    s = new(w * len(frames), h)
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0), f)
    return s


def grid(rows):
    """rows: [[frame,...], ...] -> tek sayfa; tüm kareler aynı boyut"""
    w, h = rows[0][0].size
    cols = max(len(r) for r in rows)
    s = new(w * cols, h * len(rows))
    for j, r in enumerate(rows):
        for i, f in enumerate(r):
            s.paste(f, (i * w, j * h), f)
    return s
