# -*- coding: utf-8 -*-
"""Detaylı ev sprite'ları. Bölüm dosyalarındaki house(...) çağrılarını okuyup her boyut için
ayrı bir bina çizer. Karadeniz tarzı: ahşap iskelet + taş dolgu, kiremit çatı, kepenkler, baca.
Oyunda: sprite sol-alt köşesi (x - 16, zemin), 2x ölçek. Pencereler house() ışıklarıyla aynı yerde."""
import os, re, glob, math
from common import *

PAD = 8          # sanat pikseli (her iki yanda saçak payı)
CHIM = 22        # baca payı (üstte)


def calls():
    out = set()
    for f in glob.glob(os.path.join(ROOT, "scripts", "levels", "*.gd")):
        for m in re.finditer(r"^\s*house\(([^)]*)\)", open(f, encoding="utf-8").read(), re.M):
            a = [s.strip() for s in m.group(1).split(",")]
            w, h = int(float(a[2])), int(float(a[3]))
            roof = int(float(a[4])) if len(a) > 4 else 60
            window = (a[5] == "true") if len(a) > 5 else True
            lit = (a[6] == "true") if len(a) > 6 else False
            stone = (a[7] == "true") if len(a) > 7 else False
            out.add((w, h, roof, window, lit, stone))
    return sorted(out)


def name(w, h, roof, window, lit, stone):
    return "houses/house_%dx%d_%d_%d%d%d.png" % (w, h, roof, int(window), int(lit), int(stone))


def stone_fill(img, x0, y0, x1, y1, seed, base=("n2", "n3", "n4")):
    rng = random.Random(seed)
    y = y0
    row = 0
    while y <= y1:
        rh = rng.randint(3, 5)
        x = x0 - (rng.randint(0, 6) if row % 2 else 0)
        while x <= x1:
            bw = rng.randint(5, 10)
            shade = rng.random()
            for yy in range(y, min(y + rh - 1, y1 + 1)):
                for xx in range(max(x, x0), min(x + bw - 1, x1 + 1)):
                    t = shade * 0.6 + (1 - (yy - y) / rh) * 0.4
                    px(img, xx, yy, ramp(list(base), t, xx, yy))
            # harç
            for xx in range(max(x, x0), min(x + bw, x1 + 1)):
                if y + rh - 1 <= y1:
                    px(img, xx, y + rh - 1, "n1")
            if x + bw - 1 <= x1 and x + bw - 1 >= x0:
                for yy in range(y, min(y + rh, y1 + 1)):
                    px(img, x + bw - 1, yy, "n1")
            x += bw
        y += rh
        row += 1


def plaster_fill(img, x0, y0, x1, y1, seed):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            n = fbm(x / 7.0, y / 7.0, seed)
            c = ramp([(70, 68, 70), (86, 84, 84), (102, 98, 94)], n, x, y)
            if n < 0.32 and dither(x, y, 0.5):
                c = (58, 56, 60)      # dökülmüş sıva
            px(img, x, y, c)


def beam(img, x0, y0, x1, y1, w=2):
    line(img, x0, y0, x1, y1, "wood2", w)
    line(img, x0, y0 - 1 if y0 == y1 else y0, x1, y1 - 1 if y0 == y1 else y1, "wood", 1)


def window(img, cx, top, lit, seed):
    ww, wh = 22, 26
    x0 = cx - ww // 2
    # kepenkler (açık)
    for sx in (x0 - 9, x0 + ww + 1):
        rect(img, sx, top - 1, sx + 7, top + wh, "wood2")
        for yy in range(top, top + wh, 3):
            line(img, sx + 1, yy, sx + 6, yy, "wood")
        px(img, sx + (7 if sx < x0 else 0), top + 4, "iron2")
        px(img, sx + (7 if sx < x0 else 0), top + wh - 4, "iron2")
    rect(img, x0 - 2, top - 2, x0 + ww + 1, top + wh + 1, "wood2")
    for y in range(top, top + wh):
        for x in range(x0, x0 + ww):
            if lit:
                d = math.hypot((x - cx) / ww, (y - top - wh * 0.55) / wh)
                c = ramp(["w0", "w1", "w2", "w3"], min(0.99, d * 1.6), x, y)
            else:
                c = ramp(["n1", "n2", "n1"], (x - x0 + (top + wh - y)) / (ww + wh), x, y)
                if (x - x0) - (y - top) in (3, 4) and not lit:
                    c = "n3"   # cam yansıması
            px(img, x, y, c)
    # kayıt (haç)
    rect(img, cx - 1, top, cx, top + wh - 1, "wood2")
    rect(img, x0, top + wh // 2 - 1, x0 + ww - 1, top + wh // 2, "wood2")
    if lit:
        # içeride perde silüeti
        rng = random.Random(seed)
        if rng.random() < 0.6:
            for y in range(top, top + wh):
                k = (y - top) / wh
                px(img, x0 + 1 + int(math.sin(k * 6) * 1), y, "w3")
                px(img, x0 + ww - 2 - int(math.sin(k * 6) * 1), y, "w3")
    # pervaz + saksı
    rect(img, x0 - 3, top + wh + 1, x0 + ww + 2, top + wh + 2, "n3")
    if seed % 2 == 0:
        rect(img, x0 + 3, top + wh - 3, x0 + 9, top + wh, (104, 58, 44))
        for i in range(5):
            px(img, x0 + 4 + i, top + wh - 4 - (i % 2), "moss2")


def house(w, h, roof, window_on, lit, stone):
    W = w // 2 + PAD * 2
    WH = h // 2
    RH = roof // 2
    H = WH + RH + CHIM + 2
    img = new(W, H)
    x0, x1 = PAD, PAD + w // 2 - 1
    y0 = H - WH
    y1 = H - 1
    seed = w * 7 + h * 3
    # --- duvar
    if stone:
        stone_fill(img, x0, y0, x1, y1, seed)
        # köşe taşları
        for y in range(y0, y1, 6):
            for cx in (x0, x1 - 4):
                rect(img, cx, y, cx + 4, y + 4, "n4")
                line(img, cx, y + 5, cx + 4, y + 5, "n1")
    else:
        plaster_fill(img, x0, y0, x1, y1, seed)
        # ahşap iskelet (çantı / göz dolma)
        bw = max(18, (x1 - x0) // max(2, (x1 - x0) // 26))
        for x in range(x0, x1 + 1, bw):
            beam(img, x, y0, x, y1)
        beam(img, x1 - 1, y0, x1 - 1, y1)
        for yy in (y0 + 1, y0 + WH // 2, y1 - 1):
            beam(img, x0, yy, x1, yy)
        for x in range(x0, x1 - bw + 1, bw * 2):
            line(img, x + 1, y0 + WH // 2, x + bw - 1, y0 + 2, "wood2", 1)
        # taş temel
        stone_fill(img, x0, y1 - 5, x1, y1, seed + 1)
    # alt kısım nem / yosun
    for y in range(y1 - 8, y1 + 1):
        for x in range(x0, x1 + 1):
            if dither(x, y, (y - (y1 - 8)) / 8 * 0.5):
                o = img.getpixel((x, y))
                img.putpixel((x, y), rgba(lerp_c(o[:3], "moss", 0.5)))
    # --- çatı (saçaklı, kiremit sıraları)
    rt = y0 - RH
    for y in range(rt, y0 + 2):
        k = (y - rt) / max(1, RH)
        half = (x1 - x0) / 2 * k + (PAD - 1) * k
        cx = (x0 + x1) / 2
        for x in range(int(cx - half), int(cx + half) + 1):
            row = (y - rt) // 3
            c = (96, 54, 42) if (x + row * 2) % 6 else (66, 36, 30)
            if (y - rt) % 3 == 2:
                c = (54, 30, 26)
            if x > cx:
                c = lerp_c(c, "k", 0.18)
            px(img, x, y, c)
    line(img, x0 - PAD + 1, y0 + 1, x1 + PAD - 1, y0 + 1, (44, 26, 22))
    line(img, (x0 + x1) // 2 - 2, rt, (x0 + x1) // 2 + 2, rt, (120, 70, 56))
    # saçak gölgesi
    for x in range(x0, x1 + 1):
        for y in range(y0 + 2, y0 + 5):
            if dither(x, y, 0.7 - (y - y0) * 0.2):
                o = img.getpixel((x, y))
                img.putpixel((x, y), rgba(lerp_c(o[:3], "k", 0.6)))
    # baca
    if w >= 200:
        cx = x1 - (x1 - x0) // 4
        k = (cx - x0) / max(1, (x1 - x0))
        top_at = int(rt + RH * abs(k - 0.5) * 2) - 2
        rect(img, cx, top_at - 14, cx + 6, top_at + 4, "n2")
        for yy in range(top_at - 14, top_at + 4, 3):
            line(img, cx, yy, cx + 6, yy, "n1")
        rect(img, cx - 1, top_at - 16, cx + 7, top_at - 14, "n3")
    # --- pencereler (house() içindeki ışıklarla aynı konum)
    if window_on:
        n = max(1, int(w / 140.0))
        for i in range(n):
            cx = x0 + int(w * (i + 0.5) / n / 2)
            top = y0 + int(h * 0.25 / 2)
            window(img, cx, top, lit, seed + i)
    # --- kapı
    dx0 = x0 + (w - 70) // 2
    dy0 = y0 + (h - 90) // 2
    rect(img, dx0 - 2, dy0 - 2, dx0 + 24, y1, "wood2")
    for x in range(dx0, dx0 + 23, 4):
        rect(img, x, dy0, x + 3, y1, "wood")
        line(img, x + 3, dy0, x + 3, y1, "wood2")
    rect(img, dx0 + 18, dy0 + 22, dx0 + 19, dy0 + 23, "brass")
    rect(img, dx0 - 4, y1 - 1, dx0 + 26, y1, "n3")
    outline(img)
    return img


def generate():
    cs = calls()
    for c in cs:
        save(house(*c), name(*c))
    print("evler:", len(cs))


if __name__ == "__main__":
    generate()
