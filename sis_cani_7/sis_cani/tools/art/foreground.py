# -*- coding: utf-8 -*-
"""Ön plan silüetleri (oyuncunun önünde, daha hızlı kayan katman) - 960x540, oyunda 2x."""
import math
from common import *
W, H = 960, 540


def grass_band(img, base, seed, tall=60):
    rng = random.Random(seed)
    for x in range(W):
        top = H - 26 - int(fbm_wrap(x / 30.0, 0, W / 30.0, seed, 3) * 34)
        for y in range(top, H):
            px(img, x, y, "k")
    for i in range(420):
        x = rng.randint(0, W - 1)
        h = rng.randint(10, tall)
        bend = rng.uniform(-8, 8)
        line(img, x, H - 20, x + bend, H - 20 - h, "k")



def rocks_bottom(img, seed, height=50):
    for x in range(W):
        top = H - 18 - int(fbm_wrap(x / 45.0, 0, W / 45.0, seed, 4) * height)
        for y in range(top, H):
            px(img, x, y, "k")


def stalactites(img, seed):
    rng = random.Random(seed)
    for x in range(W):
        bot = 20 + int(fbm_wrap(x / 40.0, 0, W / 40.0, seed, 3) * 30)
        for y in range(0, bot):
            px(img, x, y, "k")
    for i in range(18):
        x = rng.randint(0, W - 1)
        l = rng.randint(40, 120)
        w = rng.randint(5, 14)
        for y in range(0, l):
            k = 1 - y / l
            for xx in range(int(x - w * k), int(x + w * k) + 1):
                px(img, xx % W, y, "k")


def fog_soft(seed, alpha=90, color="f2"):
    img = new(W, H)
    for y in range(H):
        env = math.sin(y / H * math.pi) ** 0.6
        for x in range(W):
            n = fbm_wrap(x / 110.0, y / 40.0, W / 110.0, seed, 4)
            a = env * max(0.0, n - 0.42) * 2.6
            if a > 0.02:
                px(img, x, y, color, int(min(1.0, a) * alpha))
    return img


def generate():
    img = new(W, H)
    grass_band(img, H, 3)
    save(img, "fg/c1_front.png")
    img = new(W, H)
    stalactites(img, 9)
    rocks_bottom(img, 10, 26)
    save(img, "fg/c2_front.png")
    img = new(W, H)
    rocks_bottom(img, 21, 40)
    grass_band(img, H, 22, 35)
    save(img, "fg/c3_front.png")
    save(fog_soft(5), "fg/fog_drift.png")


if __name__ == "__main__":
    generate()
