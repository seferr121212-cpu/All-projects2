# -*- coding: utf-8 -*-
"""Dekor kütüphanesi: seviyeleri gerçek bir yer gibi dolduran objeler (oyunda 2x)."""
import math
from common import *


def finish(img, rim_side=0, rim_c="n4"):
    rim(img, P[rim_c] if isinstance(rim_c, str) else rim_c, rim_side)
    outline(img)
    return img


def barrel():
    img = new(18, 24)
    for y in range(24):
        bulge = 1 + round(math.sin(y / 23 * math.pi) * 1.5)
        for x in range(2 - bulge + 1, 16 + bulge - 1):
            t = (x - 1) / 16
            px(img, x, y, ramp(["wood2", "wood", "wood3", "wood"], t, x, y))
    for y in (3, 11, 20):
        line(img, 1, y, 16, y, "iron")
        line(img, 2, y - 1, 15, y - 1, "iron2")
    return finish(img)


def fence(n=0):
    img = new(48, 30)
    for x in (2, 23, 44):
        h = 26 + (n * 3 + x) % 4
        rect(img, x, 30 - h, x + 3, 29, "wood2")
        px(img, x + 1, 30 - h, "wood3")
    for y in (10, 20):
        line(img, 0, y + (n % 2), 47, y, "wood")
        line(img, 0, y - 1 + (n % 2), 47, y - 1, "wood3")
    if n == 1:  # kırık
        for x in range(30, 48):
            for y in range(0, 30):
                if x > 30 + (30 - y) * 0.6:
                    img.putpixel((x, y), (0, 0, 0, 0))
    return finish(img)


def lamppost():
    img = new(16, 70)
    rect(img, 7, 10, 8, 69, "iron")
    rect(img, 5, 64, 10, 69, "iron")
    line(img, 8, 12, 13, 12, "iron")
    rect(img, 11, 13, 15, 20, "glass", 90)
    line(img, 11, 13, 15, 13, "iron2")
    line(img, 11, 21, 15, 21, "iron")
    return finish(img)


def net():
    img = new(40, 36)
    line(img, 0, 2, 39, 2, "wood2", 2)
    for i in range(9):
        x0 = i * 5
        line(img, x0, 3, x0 + 3 + math.sin(i) * 2, 34 - abs(i - 4) * 2, "n4")
    for j in range(6):
        y = 6 + j * 5
        for x in range(0, 40):
            if (x + j) % 2 == 0 and y < 34 - abs(x / 5 - 4) * 2:
                px(img, x, y + round(math.sin(x / 6) * 1), "n4")
    rect(img, 30, 26, 34, 30, "brass")       # şamandıra
    return finish(img, 0, "n5")


def rope_coil():
    img = new(18, 8)
    for i in range(3):
        ellipse(img, 9, 5 - i * 1.4, 8 - i * 1.6, 2.4, "paper2" if i % 2 else (140, 120, 90))
    return finish(img)


def rock(seed, w=20, h=12):
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            dx = (x - w / 2) / (w / 2)
            dy = (y - h) / h
            n = vnoise(x / 4, y / 4, seed)
            if dx * dx + dy * dy * 1.1 < 0.8 + n * 0.3:
                t = (h - y) / h * 0.6 + (x / w) * 0.4
                px(img, x, y, ramp(["n1", "n2", "n3", "n4"], t, x, y))
    return finish(img)


def tuft(seed, h=12, col=("moss", "moss2")):
    rng = random.Random(seed)
    img = new(16, h + 1)
    for i in range(9):
        x0 = rng.randint(3, 12)
        hh = rng.randint(h // 2, h)
        bend = rng.uniform(-4, 4)
        line(img, x0, h, x0 + bend, h - hh, col[i % 2])
    return img


def bush(seed):
    img = new(30, 18)
    rng = random.Random(seed)
    for i in range(16):
        ellipse(img, rng.randint(6, 24), rng.randint(6, 16), rng.uniform(3, 6), rng.uniform(3, 5), rng.choice(["moss", (40, 50, 42), "moss2"]))
    return finish(img, 0, (90, 104, 84))


def dead_tree():
    img = new(70, 110)
    def branch(x, y, a, l, w, d):
        if d == 0 or l < 4:
            return
        x2 = x + math.cos(a) * l
        y2 = y + math.sin(a) * l
        line(img, x, y, x2, y2, "n1", max(1, w))
        branch(x2, y2, a - 0.45 + math.sin(d * 3.1) * 0.2, l * 0.72, w - 1, d - 1)
        branch(x2, y2, a + 0.5, l * 0.62, w - 1, d - 1)
    branch(35, 109, -math.pi / 2, 34, 5, 6)
    return finish(img, 0, "n3")


def signpost():
    img = new(40, 44)
    rect(img, 18, 8, 20, 43, "wood2")
    poly(img, [(4, 6), (32, 4), (38, 9), (32, 14), (4, 14)], "wood")
    line(img, 4, 6, 32, 4, "wood3")
    for x in range(8, 28, 4):            # yazı izi
        rect(img, x, 8, x + 2, 10, "wood2")
    poly(img, [(2, 20), (26, 21), (26, 28), (2, 27)], "wood")
    return finish(img)


def anchor():
    img = new(22, 26)
    ellipse(img, 11, 3, 3, 3, "iron")
    ellipse(img, 11, 3, 1.5, 1.5, (0, 0, 0, 0))
    rect(img, 10, 5, 12, 22, "iron")
    line(img, 5, 9, 17, 9, "iron", 2)
    for s in (-1, 1):
        for i in range(10):
            a = math.pi / 2 + s * (i / 9) * 1.3
            px(img, 11 + math.cos(a) * 9 * s * -1 if False else 11 + math.sin(i / 9 * 1.4) * 9 * s, 21 + math.cos(i / 9 * 1.4) * 0 - (i / 9) ** 2 * 6, "iron")
    line(img, 2, 15, 11, 23, "iron", 2)
    line(img, 20, 15, 11, 23, "iron", 2)
    return finish(img)


def wreck():
    img = new(90, 34)
    poly(img, [(0, 14), (60, 10), (88, 4), (80, 26), (12, 33)], "wood2")
    for x in range(10, 80, 9):
        line(img, x, 12, x + 4, 30, "wood")
    line(img, 46, 12, 30, 0, "wood2", 2)
    return finish(img)


def gravestone(n):
    img = new(16, 22)
    if n == 0:
        rect(img, 2, 6, 13, 21, "n3")
        ellipse(img, 7.5, 6, 5.5, 5, "n3")
        line(img, 5, 10, 10, 10, "n1")
        line(img, 7, 8, 7, 14, "n1")
    else:
        rect(img, 6, 2, 8, 21, "n3")
        rect(img, 2, 6, 12, 8, "n3")
    return finish(img, 0, "n5")


def lantern_hang():
    img = new(12, 30)
    line(img, 6, 0, 6, 14, "iron")
    rect(img, 3, 14, 9, 15, "iron")
    rect(img, 2, 16, 10, 25, "glass", 70)
    line(img, 2, 16, 2, 25, "iron")
    line(img, 10, 16, 10, 25, "iron")
    rect(img, 3, 26, 9, 27, "iron")
    return finish(img)


def stalagmite(seed):
    rng = random.Random(seed)
    w, h = 26, rng.randint(30, 52)
    img = new(w, h)
    for y in range(h):
        k = y / h
        hw = 1 + k * (w / 2 - 1)
        for x in range(w):
            if abs(x - w / 2 + math.sin(y * 0.3) * 1.5) < hw:
                px(img, x, y, ramp(["n0", "n1", "n2"], x / w, x, y))
    return finish(img, 1, "n3")


def mushrooms():
    img = new(18, 12)
    for x, h, r in ((4, 7, 3), (10, 10, 4), (15, 5, 2)):
        line(img, x, 11, x, 11 - h, "paper2")
        ellipse(img, x, 11 - h, r, r * 0.6, (110, 150, 140))
    return finish(img, 0, (170, 220, 200))


def roots():
    img = new(60, 40)
    rng = random.Random(4)
    for i in range(7):
        x = rng.randint(4, 56)
        y = 0
        for s in range(14):
            x2 = x + rng.uniform(-3, 3)
            y2 = y + rng.uniform(2, 3.5)
            line(img, x, y, x2, y2, "wood2", 2 if s < 6 else 1)
            x, y = x2, y2
    return finish(img)


def chain():
    img = new(6, 80)
    for y in range(0, 80, 5):
        if (y // 5) % 2:
            rect(img, 2, y, 3, y + 4, "iron2")
        else:
            rect(img, 1, y, 4, y + 1, "iron2")
            rect(img, 1, y + 3, 4, y + 4, "iron2")
            px(img, 1, y + 2, "iron2")
            px(img, 4, y + 2, "iron2")
    return img


def cobweb():
    img = new(30, 30)
    for i in range(6):
        a = i / 5 * math.pi / 2
        line(img, 0, 0, math.cos(a) * 29, math.sin(a) * 29, "f2")
    for r in (8, 15, 22):
        for i in range(30):
            a = i / 29 * math.pi / 2
            px(img, math.cos(a) * r, math.sin(a) * r + math.sin(i) * 0.6, "f2", 160)
    return img


def candles():
    img = new(16, 14)
    for x, h in ((3, 8), (8, 11), (12, 6)):
        rect(img, x - 1, 13 - h, x + 1, 13, "paper")
        px(img, x, 12 - h, "w1")
    rect(img, 0, 13, 15, 13, "wood2")
    return img


def crates_stack():
    img = new(46, 44)
    def c(x, y, s):
        rect(img, x, y, x + s, y + s, "wood2")
        rect(img, x + 1, y + 1, x + s - 1, y + s - 1, "wood")
        line(img, x + 1, y + 1, x + s - 1, y + s - 1, "wood2")
        line(img, x + 1, y + 1, x + s - 1, y + 1, "wood3")
    c(0, 22, 21)
    c(23, 24, 19)
    c(10, 2, 19)
    return finish(img)


def sacks():
    img = new(30, 18)
    for x, w in ((8, 8), (20, 9)):
        ellipse(img, x, 11, w, 6.5, (120, 100, 74))
        line(img, x - 2, 5, x + 2, 5, "wood2")
    ellipse(img, 14, 6, 7, 5, (138, 116, 86))
    return finish(img)


def lighthouse_window():
    img = new(20, 30)
    ellipse(img, 10, 10, 9, 10, "n1")
    rect(img, 1, 10, 19, 29, "n1")
    rect(img, 4, 8, 16, 27, "n3")
    line(img, 10, 4, 10, 27, "n1")
    return img


def generate():
    out = {
        "barrel": barrel(), "fence": fence(0), "fence_broken": fence(1), "lamppost": lamppost(),
        "net": net(), "rope": rope_coil(), "rock_a": rock(1), "rock_b": rock(2, 28, 14), "rock_c": rock(3, 14, 9),
        "tuft_a": tuft(1), "tuft_b": tuft(2, 9), "tuft_c": tuft(3, 15), "tuft_cave": tuft(4, 8, ((40, 54, 48), (60, 80, 70))),
        "bush": bush(5), "dead_tree": dead_tree(), "signpost": signpost(), "anchor": anchor(), "wreck": wreck(),
        "grave_a": gravestone(0), "grave_b": gravestone(1), "lantern_hang": lantern_hang(),
        "stalagmite_a": stalagmite(1), "stalagmite_b": stalagmite(2), "mushrooms": mushrooms(), "roots": roots(),
        "chain": chain(), "cobweb": cobweb(), "candles": candles(), "crates": crates_stack(), "sacks": sacks(),
        "tower_window": lighthouse_window(),
    }
    for k, v in out.items():
        save(v, "decor/%s.png" % k)
    # önizleme
    W = 0
    for v in out.values():
        W += v.width * 3 + 6
    sheet_img = Image.new("RGBA", (W, 340), (100, 110, 130, 255))
    x = 0
    for v in out.values():
        b = v.resize((v.width * 3, v.height * 3), Image.NEAREST)
        sheet_img.alpha_composite(b, (x, 335 - b.height))
        x += b.width + 6
    sheet_img.save("/tmp/decor_preview.png")


if __name__ == "__main__":
    generate()
