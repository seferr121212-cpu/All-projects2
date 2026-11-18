# -*- coding: utf-8 -*-
"""Parallax arka planlar (960x540, yatayda döşenebilir; oyunda 2x ölçeklenir)."""
import math
from common import *

W, H = 960, 540


def wrapx(x):
    return x % W


def sky(top, mid, bottom, moon=True, stars=True, storm=False, seed=1):
    img = new(W, H)
    pxs = img.load()
    for y in range(H):
        t = y / H
        for x in range(W):
            if t < 0.55:
                c = ramp([top, mid], t / 0.55, x, y)
            else:
                c = ramp([mid, bottom], (t - 0.55) / 0.45, x, y)
            pxs[x, y] = rgba(c)
    if stars:
        rng = random.Random(seed)
        for i in range(140):
            x, y = rng.randint(0, W - 1), rng.randint(0, int(H * 0.4))
            px(img, x, y, "f2" if rng.random() < 0.2 else "n5", rng.randint(80, 200))
    if moon:
        mx, my = 700, 110
        for y in range(my - 90, my + 90):
            for x in range(mx - 90, mx + 90):
                d = math.hypot(x - mx, y - my)
                if d < 22:
                    c = "f3" if d < 20 else "f2"
                    if math.hypot(x - mx - 6, y - my + 4) < 6 or math.hypot(x - mx + 7, y - my - 6) < 4:
                        c = "f2"
                    px(img, x, y, c)
                elif d < 90 and dither(x, y, (1 - d / 90) ** 2 * 0.55):
                    o = img.getpixel((x, y))
                    img.putpixel((x, y), rgba(lerp_c(o[:3], "f1", 0.35)))
    # bulut bantları
    for y in range(int(H * 0.05), int(H * 0.62)):
        for x in range(W):
            n = fbm_wrap(x / 90.0, y / 22.0, W / 90.0, seed + 5, 5)
            thr = 0.56 if not storm else 0.48
            if n > thr:
                k = (n - thr) / (1 - thr)
                o = img.getpixel((x, y))
                c = lerp_c(o[:3], "n2" if storm else "n3", min(1, k * 2.2))
                if n > thr + 0.08 and dither(x, y, 0.5):
                    c = lerp_c(c, "n4", 0.4)
                img.putpixel((x, y), rgba(c))
    return img


def sky2(top, mid, bottom, moon=(700, 110), storm=False, seed=1, bands=14):
    """Temiz, bantlı gökyüzü + katmanlı bulutlar (gürültü lekesi yok)."""
    img = new(W, H)
    pxs = img.load()
    cols = []
    for i in range(bands):
        t = i / (bands - 1)
        cols.append(lerp_c(top, mid, t / 0.6) if t < 0.6 else lerp_c(mid, bottom, (t - 0.6) / 0.4))
    for y in range(H):
        f = y / H * (bands - 1)
        i = int(f)
        frac = f - i
        for x in range(W):
            c = cols[min(bands - 1, i + 1)] if (frac > 0.75 and dither(x, y, (frac - 0.75) * 4)) else cols[i]
            pxs[x, y] = rgba(c)
    rng = random.Random(seed)
    if not storm:
        for i in range(70):
            x, y = rng.randint(0, W - 1), rng.randint(0, int(H * 0.38))
            px(img, x, y, "f2" if rng.random() < 0.25 else "n5")
            if rng.random() < 0.1:
                px(img, x + 1, y, "n4"); px(img, x - 1, y, "n4"); px(img, x, y + 1, "n4"); px(img, x, y - 1, "n4")
    if moon:
        mx, my = moon
        R = 96
        for y in range(max(0, my - R), min(H, my + R)):
            for x in range(mx - R, mx + R):
                d = math.hypot(x - mx, y - my) / R
                if d < 1.0:
                    k = (1.0 - d) ** 2.0 * 0.8
                    # 4 kademeye indir + dither: bantlar yerine yumuşak pixel-art geçişi
                    q = int(k * 8)
                    if dither(x, y, k * 8 - q):
                        q += 1
                    if q > 0:
                        o = img.getpixel((x % W, y))
                        img.putpixel((x % W, y), rgba(lerp_c(o[:3], "f2", q / 8.0)))
        ellipse(img, mx, my, 18, 18, "f3")
        ellipse(img, mx + 5, my - 4, 5, 4, "f2")
        ellipse(img, mx - 6, my + 6, 3, 3, "f2")
        ellipse(img, mx - 2, my - 8, 2, 2, "f2")
    # bulutlar: 3 ton, üst kenarlar ay ışığıyla aydınlık
    for layer, (y0, y1, sc, thr, base, lit) in enumerate([
            (60, 260, 140.0, 0.55, "n2", "n4"),
            (180, 380, 100.0, 0.58 if not storm else 0.5, "n1" if storm else "n3", "n5")]):
        for y in range(y0, y1):
            env = math.sin((y - y0) / (y1 - y0) * math.pi)
            for x in range(W):
                n = fbm_wrap(x / sc, y / (sc * 0.28), W / sc, seed + layer * 7, 4) * env
                if n > thr * env + (1 - env) * 0.5 and n > 0.22:
                    above = fbm_wrap(x / sc, (y - 3) / (sc * 0.28), W / sc, seed + layer * 7, 4) * math.sin((y - 3 - y0) / (y1 - y0) * math.pi)
                    edge = above <= thr * env + (1 - env) * 0.5
                    c = lit if edge else base
                    if not edge and n > thr + 0.12:
                        c = lerp_c(base, "n1", 0.5)
                    px(img, x, y, c)
    return img


def moon_rays(im, mx=700, my=110):
    for y in range(my, H):
        for x in range(W):
            dx, dy = x - mx, y - my
            ang = math.atan2(dy, dx)
            band = (math.sin(ang * 38.0) + math.sin(ang * 17.0 + 1.3)) * 0.5
            if band > 0.55:
                d = math.hypot(dx, dy)
                k = (band - 0.55) / 0.45 * max(0, 1 - d / 420) * 0.22
                if dither(x, y, k):
                    o = im.getpixel((x, y))
                    im.putpixel((x, y), rgba(lerp_c(o[:3], "f1", 0.28)))
    return im


def sea_layer(horizon=372, lighthouse_x=None, islands=True, seed=3):
    img = new(W, H)
    # uzak adalar
    if islands:
        for y in range(horizon - 70, horizon):
            for x in range(W):
                h = fbm_wrap(x / 70.0, 0, W / 70.0, seed, 4)
                top = horizon - 18 - h * 60 * (0.5 + 0.5 * math.sin(x / W * math.tau * 2 + 1))
                if y >= top:
                    px(img, x, y, "n2" if y > top + 2 else "n3")
    if lighthouse_x is not None:
        lx = lighthouse_x
        base = horizon - 22
        # ada kayası
        for y in range(base - 6, horizon):
            k = (y - (base - 6)) / (horizon - base + 6)
            for x in range(int(lx - 14 - k * 30), int(lx + 14 + k * 34)):
                px(img, wrapx(x), y, "n2")
        for y in range(base - 62, base - 4):
            k = (y - (base - 62)) / 58
            hw = 2 + k * 3
            for x in range(int(lx - hw), int(lx + hw) + 1):
                px(img, wrapx(x), y, "n2" if x < lx else "n3")
            if (y // 6) % 2 == 0:
                px(img, lx, y, "n1")
        rect(img, lx - 4, base - 66, lx + 4, base - 62, "n2")     # balkon
        rect(img, lx - 2, base - 72, lx + 2, base - 67, "n1")     # sönük mercek odası
        poly(img, [(lx - 3, base - 72), (lx, base - 77), (lx + 3, base - 72)], "n2")
    # deniz
    for y in range(horizon, H):
        for x in range(W):
            t = (y - horizon) / (H - horizon)
            c = ramp(["n2", "sea1", "sea0"], t, x, y)
            n = vnoise_wrap(x / 18.0, y / 2.0, W / 18.0, seed + 9)
            if n > 0.72 - t * 0.1:
                c = lerp_c(c, "n4", 0.5)
            px(img, x, y, c)
    # ay yansıması
    for y in range(horizon + 2, H, 3):
        for x in range(680, 720):
            if vnoise(x / 6.0, y / 2.0, 77) > 0.55:
                px(img, x, y, "f1", 150)
    return img


def hills_village(seed=4):
    img = new(W, H)
    base = 500
    for x in range(W):
        h = fbm_wrap(x / 120.0, 0, W / 120.0, seed, 4)
        top = int(base - 40 - h * 80)
        for y in range(top, H):
            px(img, x, y, "n1" if y > top + 1 else "n2")
    # evler
    rng = random.Random(seed)
    x = 30
    while x < W - 80:
        w = rng.randint(34, 70)
        h = rng.randint(30, 60)
        g = base - 40 - int(fbm_wrap((x + w / 2) / 120.0, 0, W / 120.0, seed, 4) * 80) + 6
        rect(img, x, g - h, x + w, g + 10, "n1")
        poly(img, [(x - 4, g - h), (x + w / 2, g - h - rng.randint(14, 26)), (x + w + 4, g - h)], "n1")
        if rng.random() < 0.6:
            rect(img, x + w - 12, g - h - 22, x + w - 8, g - h - 8, "n1")   # baca
        for wx in range(x + 6, x + w - 6, 14):
            if rng.random() < 0.55:
                rect(img, wx, g - h + 10, wx + 4, g - h + 16, "n0")
        x += w + rng.randint(30, 110)
    # ağaçlar / direkler
    for i in range(10):
        tx = rng.randint(0, W - 1)
        g = base - 40 - int(fbm_wrap(tx / 120.0, 0, W / 120.0, seed, 4) * 80) + 4
        if rng.random() < 0.5:
            line(img, tx, g, tx, g - 70, "n1", 2)
            line(img, tx - 10, g - 60, tx + 10, g - 60, "n1")
        else:
            for y in range(g - 60, g):
                k = (y - (g - 60)) / 60
                for xx in range(int(tx - k * 14), int(tx + k * 14) + 1):
                    if dither(xx, y, 0.9):
                        px(img, wrapx(xx), y, "n1")
    return img


def fog_band(y0, y1, color="f1", seed=8, alpha=110):
    img = new(W, H)
    for y in range(y0, y1):
        for x in range(W):
            t = (y - y0) / (y1 - y0)
            env = math.sin(t * math.pi)
            n = fbm_wrap(x / 60.0, y / 14.0, W / 60.0, seed, 4)
            a = env * max(0.0, n - 0.35) * 2.2
            if dither(x, y, min(1.0, a)):
                px(img, x, y, color, alpha)
    return img


def reeds(seed=12):
    img = new(W, H)
    rng = random.Random(seed)
    for i in range(160):
        x = rng.randint(0, W - 1)
        h = rng.randint(20, 70)
        bend = rng.uniform(-6, 6)
        line(img, x, H - 1, x + bend, H - 1 - h, "k")
    for x in range(W):
        top = H - 18 - int(fbm_wrap(x / 40.0, 0, W / 40.0, seed, 3) * 30)
        for y in range(top, H):
            px(img, x, y, "k")
    return img


def cave_back(seed=20):
    img = new(W, H)
    for y in range(H):
        for x in range(W):
            n = fbm_wrap(x / 50.0, y / 30.0, W / 50.0, seed, 5)
            # kaya katmanları: yatay tabakalanma + mineral (deniz yeşili) damarlar
            strata = 0.08 * math.sin(y / 9.0 + n * 6.0)
            c = ramp(["k", "n0", "n1", "n2", "n3"], n * 1.2 - 0.12 + strata, x, y)
            m = fbm_wrap(x / 22.0, y / 14.0, W / 22.0, seed + 7, 3)
            if m > 0.7 and n > 0.45 and dither(x, y, min(1.0, (m - 0.7) * 12)):
                c = "t1"
            # aşağısı daha karanlık (derinlik)
            if y > H * 0.7 and dither(x, y, (y - H * 0.7) / (H * 0.3) * 0.6):
                c = "k"
            px(img, x, y, c)
    # parlayan kristal kümeleri
    rng0 = random.Random(seed + 3)
    for i in range(26):
        cx, cy = rng0.randint(0, W - 1), rng0.randint(140, H - 120)
        # yumuşak, açık renkli hale (koyu leke değil)
        for yy in range(cy - 22, cy + 8):
            for xx in range(cx - 26, cx + 27):
                d = ((xx - cx) / 26.0) ** 2 + ((yy - cy + 4) / 15.0) ** 2
                if d < 1.0 and 0 <= yy < H:
                    k = (1.0 - d) * 0.22
                    o = img.getpixel((wrapx(xx), yy))
                    t = P["t2"]
                    img.putpixel((wrapx(xx), yy), (int(o[0] + (t[0] - o[0]) * k), int(o[1] + (t[1] - o[1]) * k), int(o[2] + (t[2] - o[2]) * k), 255))
        for k in range(rng0.randint(3, 6)):
            h = rng0.randint(5, 13); dx = rng0.randint(-7, 7); lean = rng0.choice([-1, 0, 1])
            for yy in range(h):
                xx = cx + dx + (lean * yy) // 4
                wdt = 1 if yy > h * 0.6 else 2
                for q in range(wdt):
                    px(img, wrapx(xx + q), cy - yy, "t3" if (q == 0 and yy > 1) else "t2")
    # sarkıtlar ve dikitler
    rng = random.Random(seed)
    for i in range(40):
        x = rng.randint(0, W - 1)
        l = rng.randint(30, 140)
        w = rng.randint(4, 14)
        for y in range(0, l):
            k = 1 - y / l
            for xx in range(int(x - w * k), int(x + w * k) + 1):
                px(img, wrapx(xx), y, "k")
        l = rng.randint(20, 90)
        x2 = rng.randint(0, W - 1)
        for y in range(H - l, H):
            k = (y - (H - l)) / l
            for xx in range(int(x2 - w * k), int(x2 + w * k) + 1):
                px(img, wrapx(xx), y, "k")
    return img


def cave_mid(seed=24):
    img = new(W, H)
    rng = random.Random(seed)
    for i in range(7):
        x = rng.randint(0, W - 1)
        w = rng.randint(30, 70)
        for y in range(H):
            wob = math.sin(y / 40.0 + i) * 6
            for xx in range(int(x - w / 2 + wob), int(x + w / 2 + wob)):
                if dither(xx, y, 0.95):
                    px(img, wrapx(xx), y, "n1")
    # damla parıltıları
    for i in range(60):
        px(img, rng.randint(0, W - 1), rng.randint(0, H - 1), "n4", 140)
    return img


def cliff_layer(seed=30):
    img = new(W, H)
    for x in range(W):
        h = fbm_wrap(x / 80.0, 0, W / 80.0, seed, 5)
        top = int(300 + h * 160)
        for y in range(top, H):
            c = "n0" if y > top + 2 else "n2"
            if dither(x, y, 0.06):
                c = "n1"
            px(img, x, y, c)
    return img


def generate():
    # Bölüm 1: ay ışığında sisli liman + köy
    save(moon_rays(sky2(P["n0"], P["n2"], P["n4"], seed=1)), "bg/c1_sky.png")
    save(sea_layer(lighthouse_x=520), "bg/c1_sea.png")
    save(hills_village(), "bg/c1_village.png")
    save(fog_band(330, 520, "f1", 8, 120), "bg/c1_fog.png")
    save(reeds(), "bg/c1_reeds.png")
    # Bölüm 2: mağara
    save(cave_back(), "bg/c2_back.png")
    save(cave_mid(), "bg/c2_mid.png")
    save(fog_band(250, 540, "n3", 18, 90), "bg/c2_fog.png")
    # Bölüm 3: fırtınalı gece, deniz, kayalık
    save(sky2(P["k"], P["n1"], P["n3"], moon=None, storm=True, seed=7), "bg/c3_sky.png")
    save(sea_layer(horizon=400, islands=False, seed=5), "bg/c3_sea.png")
    save(cliff_layer(), "bg/c3_cliff.png")
    save(fog_band(380, 540, "f1", 31, 90), "bg/c3_fog.png")


if __name__ == "__main__":
    generate()
