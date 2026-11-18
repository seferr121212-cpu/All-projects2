# -*- coding: utf-8 -*-
"""Açılış introsu için büyük fener silueti (art/story/title_lighthouse.png)."""
import math, random
from common import *


def lighthouse():
    W, H = 220, 300
    img = new(W, H)
    rng = random.Random(77)
    # kayalık
    for x in range(W):
        top = int(232 + 18 * math.sin(x / 17.0) + 10 * math.sin(x / 7.0 + 1.0) + (abs(x - 110) / 110.0) ** 2 * 40)
        for y in range(top, H):
            c = "k" if y > top + 3 else ("n2" if x > 110 else "n1")
            if y > top + 3 and dither(x, y, 0.08):
                c = "n0"
            px(img, x, y, c)
    # kule (aşağıda geniş, yukarıda dar)
    base_y, top_y = 246, 66
    for y in range(top_y, base_y):
        t = (y - top_y) / (base_y - top_y)
        hw = 16 + t * 14
        band = int((y - top_y) / 22) % 2 == 0
        for x in range(int(110 - hw), int(110 + hw) + 1):
            side = (x - (110 - hw)) / (2 * hw)
            if band:
                c = ramp(["red2", "red2", "w4"], side, x, y)
            else:
                c = ramp(["n1", "n2", "n3"], side, x, y)
            px(img, x, y, c)
        px(img, int(110 - hw), y, "k"); px(img, int(110 + hw), y, "k")
    # pencereler (biri sıcak ışıklı)
    for wy in (120, 168, 212):
        rect(img, 107, wy, 112, wy + 7, "k")
    rect(img, 108, 169, 111, 174, "w2")
    # galeri + korkuluk
    rect(img, 86, 60, 134, 66, "n0")
    for x in range(86, 135, 4):
        line(img, x, 52, x, 60, "n1")
    line(img, 86, 52, 134, 52, "n2")
    # fener odası (ışıklı cam)
    for y in range(30, 52):
        for x in range(96, 125):
            t = abs(x - 110) / 15.0
            c = ramp(["w0", "w1", "w2"], t + (y - 30) / 60.0, x, y)
            px(img, x, y, c)
    for x in (96, 103, 110, 117, 124):
        line(img, x, 30, x, 51, "k")
    # kubbe + paratoner
    for y in range(16, 30):
        hw = int(16 * math.sqrt(max(0.0, 1 - ((30 - y) / 14.0) ** 2)))
        for x in range(110 - hw, 110 + hw + 1):
            px(img, x, y, "n1" if x < 112 else "n2")
    line(img, 110, 4, 110, 16, "n2")
    px(img, 110, 3, "w1")
    outline(img)
    return img


def generate():
    save(lighthouse(), "story/title_lighthouse.png")


if __name__ == "__main__":
    generate()
