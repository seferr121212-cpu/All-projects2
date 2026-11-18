# -*- coding: utf-8 -*-
"""Döşenebilir yüzey dokuları (32x32) ve üst kenar şeritleri (32x10)."""
import math
from common import *

S = 32


def tex(fn, seed):
    img = new(S, S)
    for y in range(S):
        for x in range(S):
            c = fn(x, y, seed)
            if c is not None:
                px(img, x, y, c)
    return img


def planks():
    def f(x, y, s):
        row = y // 8
        off = (row * 13) % S
        xx = (x + off) % S
        if y % 8 == 7:
            return "k"
        if xx in (0, 16):
            return "n0"
        n = fbm_wrap(x / 6.0, y / 2.0, S / 6.0, s)
        base = ["wood2", "wood", "wood3"][0 if n < 0.42 else (1 if n < 0.62 else 2)]
        if (xx in (2, 14, 18, 30)) and y % 8 == 3:
            return "iron2"
        return lerp_c(base, "n2", 0.35)
    return tex(f, 4)


def earth(dark=0.0, seed=7):
    def f(x, y, s):
        n = fbm_wrap(x / 7.0, y / 7.0, S / 7.0, s)
        c = ramp(["n0", "n1", "n2"], n * 1.1 - 0.05, x, y)
        if noise2(x, y, s) > 0.985:
            return "n3"
        return lerp_c(c, "k", dark)
    return tex(f, seed)


def cobble():
    """Sıkı dizilmiş, ıslak parlayan arnavut kaldırımı (döşenebilir)."""
    img = new(S, S)
    rect(img, 0, 0, S - 1, S - 1, "k")
    rng = random.Random(5)
    rows = 4
    rh = S // rows
    for r in range(rows):
        off = (r % 2) * 4 + rng.randint(-1, 1)
        x = off
        while x < S + off:
            w = rng.choice([6, 7, 8, 9])
            tone = rng.choice(["n2", "n2", "n3", "n1"])
            hi = {"n1": "n2", "n2": "n3", "n3": "n4"}[tone]
            for yy in range(rh - 1):
                for xx in range(w - 1):
                    # köşeleri yuvarla
                    if (xx in (0, w - 2)) and (yy in (0, rh - 2)):
                        continue
                    c = tone
                    if yy == 0 or (yy == 1 and xx < w - 3 and xx > 0):
                        c = hi                       # üst kenar ışık alır
                    elif yy == rh - 2:
                        c = "n0" if tone != "n1" else "k"   # alt kenar gölge
                    elif rng.random() < 0.12:
                        c = "n1" if tone != "n1" else "n0"  # doku
                    px(img, (x + xx) % S, r * rh + yy, c)
            # ıslak parıltı: bazı taşlarda tek piksellik soğuk yansıma
            if rng.random() < 0.35:
                px(img, (x + 2) % S, r * rh + 1, "n5")
                px(img, (x + 3) % S, r * rh + 1, "n4")
            # derzde yosun
            if rng.random() < 0.2:
                px(img, (x + w - 1) % S, r * rh + rng.randint(2, rh - 2), "moss")
            x += w
    return img


def rock():
    def f(x, y, s):
        n = fbm_wrap(x / 9.0, y / 5.0, S / 9.0, s)
        crack = abs(fbm_wrap(x / 5.0, y / 11.0, S / 5.0, s + 3) - 0.5) < 0.03
        if crack:
            return "k"
        return ramp(["k", "n0", "n1", "n2"], n * 1.2 - 0.1, x, y)
    return tex(f, 21)


def brick():
    def f(x, y, s):
        row = y // 8
        off = 8 if row % 2 else 0
        xx = (x + off) % 16
        if y % 8 == 7 or xx == 15:
            return "n0"
        n = fbm_wrap(x / 4.0, y / 4.0, S / 4.0, s + row)
        c = ramp(["n1", "n2", "n3"], n, x, y)
        if y % 8 == 0:
            c = lerp_c(c, "n4", 0.3)
        return c
    return tex(f, 31)


def wood_wall():
    def f(x, y, s):
        if x % 8 == 7:
            return "k"
        n = fbm_wrap(x / 3.0, y / 12.0, S / 3.0, s + x // 8)
        return lerp_c(ramp(["wood2", "wood"], n, x, y), "n2", 0.45)
    return tex(f, 41)


def stone_wall():
    def f(x, y, s):
        n = fbm_wrap(x / 6.0, y / 6.0, S / 6.0, s)
        if abs(n - 0.5) < 0.025:
            return "n0"
        return ramp(["n1", "n2", "n3"], n * 1.1 - 0.05, x, y)
    return tex(f, 51)


def roof():
    def f(x, y, s):
        row = y // 6
        off = 4 if row % 2 else 0
        xx = (x + off) % 8
        if y % 6 == 5:
            return "k"
        if xx == 7:
            return "n0"
        t = (y % 6) / 5
        return lerp_c((92, 52, 42), (54, 30, 28), t * 0.8)
    return tex(f, 61)


def top_strip(kind):
    img = new(S, 10)
    for x in range(S):
        if kind == "grass":
            h = 3 + round(vnoise_wrap(x / 3.0, 0, S / 3.0, 2) * 4)
            for y in range(h):
                px(img, x, 9 - y - 1 + 1 - 1, "moss" if y < h - 1 else "moss2")
            rect(img, x, 8, x, 9, "moss")
        elif kind == "moss":
            h = 2 + round(vnoise_wrap(x / 2.0, 0, S / 2.0, 6) * 3)
            for y in range(h):
                px(img, x, 9 - y, "moss" if y else (40, 52, 46))
        elif kind == "plank":
            rect(img, x, 6, x, 9, "wood3" if x % 16 else "wood2")
            px(img, x, 6, (130, 104, 76))
        elif kind == "stone":
            rect(img, x, 7, x, 9, "n4" if x % 16 else "n2")
            px(img, x, 7, "n5")
    return img


def generate():
    save(planks(), "tiles/planks.png")
    save(earth(), "tiles/earth.png")
    save(earth(0.35, 13), "tiles/earth_dark.png")
    save(cobble(), "tiles/cobble.png")
    save(rock(), "tiles/rock.png")
    save(brick(), "tiles/brick.png")
    save(wood_wall(), "tiles/wood_wall.png")
    save(stone_wall(), "tiles/stone_wall.png")
    save(roof(), "tiles/roof.png")
    for k in ("grass", "moss", "plank", "stone"):
        save(top_strip(k), "tiles/top_%s.png" % k)


if __name__ == "__main__":
    import random
    generate()
