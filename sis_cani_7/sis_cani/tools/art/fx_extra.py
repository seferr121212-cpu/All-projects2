# -*- coding: utf-8 -*-
"""Ek efekt sprite'ları: su birikintisi, güve, martı, yaprak, ayak gölgesi, buhar, kıvılcım."""
import math
from common import *


def puddle():
    img = new(48, 8)
    for y in range(8):
        for x in range(48):
            if ((x - 24) / 24) ** 2 + ((y - 4) / 3.6) ** 2 <= 1:
                c = ramp(["n1", "n2", "n3"], 1 - abs(y - 3) / 4, x, y)
                px(img, x, y, c)
    line(img, 8, 2, 30, 2, "n4")
    return img


def moth(t):
    img = new(7, 5)
    up = t < 0.5
    rect(img, 3, 1, 3, 3, "n1")
    if up:
        rect(img, 0, 0, 2, 1, "paper2"); rect(img, 4, 0, 6, 1, "paper2")
    else:
        rect(img, 0, 2, 2, 3, "paper2"); rect(img, 4, 2, 6, 3, "paper2")
    return img


def gull(t):
    img = new(15, 7)
    a = math.sin(t * math.tau) * 2.5
    line(img, 7, 3, 1, 3 - a, "n1")
    line(img, 7, 3, 13, 3 - a, "n1")
    rect(img, 6, 3, 8, 4, "n1")
    return img


def leaf():
    img = new(5, 4)
    rect(img, 1, 1, 3, 2, (110, 80, 44))
    px(img, 0, 1, (90, 64, 36)); px(img, 4, 2, (90, 64, 36))
    return img


def blob():
    img = new(24, 6)
    for y in range(6):
        for x in range(24):
            d = ((x - 11.5) / 12) ** 2 + ((y - 2.5) / 3) ** 2
            if d < 1:
                px(img, x, y, "k", int((1 - d) * 150))
    return img


def generate():
    save(puddle(), "decor/puddle.png")
    save(sheet([moth(i / 2) for i in range(2)]), "fx/moth.png")
    save(sheet([gull(i / 4) for i in range(4)]), "fx/gull.png")
    save(leaf(), "fx/leaf.png")
    save(blob(), "fx/blob.png")


if __name__ == "__main__":
    generate()
