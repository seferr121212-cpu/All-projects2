# -*- coding: utf-8 -*-
"""Bölüm 5 (Fabrika ve Dalgakıran) sanatı: arka plan katmanı, bölüm kartı, kazan/vana/saat."""
import math, random
from common import *
from story import grad, sea, fog, person, glow_dot, W as SW, H as SH
import backgrounds as bgm

BW, BH = 960, 540


def factory_layer(seed=51):
    """Uzakta fabrika silueti: şedler, bacalar, vinç, dalgakıran ve fener."""
    img = new(BW, BH)
    rng = random.Random(seed)
    base = 392
    # şed çatılı binalar (testere dişi)
    x = 0
    while x < BW:
        w = rng.randint(90, 170)
        h = rng.randint(50, 110)
        top = base - h
        rect(img, x, top, x + w, base, "n2")
        line(img, x, top, x + w, top, "n3")
        teeth = max(2, w // 34)
        tw = w / teeth
        for t in range(teeth):
            x0 = int(x + t * tw)
            xm = int(x0 + tw * 0.75)
            poly(img, [(x0, top), (xm, top - 26), (xm, top)], "n2")
            line(img, x0, top, xm, top - 26, "n3")
            # şed camı (dikey yüz) hafif ışık alır
            for yy in range(top - 24, top):
                px(img, xm, yy, "n3" if rng.random() < 0.7 else "n2")
                px(img, xm + 1, yy, "n0")
        # üstte tek sıra kırık pencere, altta büyük yükleme kapısı
        wy = top + 12
        for wx in range(x + 10, x + w - 12, 26):
            c = "k" if rng.random() < 0.8 else "w4"
            rect(img, wx, wy, wx + 12, wy + 8, c)
            line(img, wx + 6, wy, wx + 6, wy + 8, "n1")
        dx = x + w // 2 - 14
        rect(img, dx, base - 40, dx + 28, base, "k")
        for yy in range(base - 40, base, 4):
            line(img, dx, yy, dx + 28, yy, "n0")
        # yazı tabelası
        if w > 130 and rng.random() < 0.6:
            rect(img, x + 14, top + 26, x + 64, top + 32, "n2")
        # baca
        if rng.random() < 0.55:
            cx = x + rng.randint(15, w - 25)
            ch = rng.randint(80, 150)
            rect(img, cx, top - ch, cx + 12, top, "n2")
            rect(img, cx - 2, top - ch, cx + 14, top - ch + 4, "n2")
            for b in range(top - ch + 10, top, 14):
                line(img, cx, b, cx + 12, b, "n0")
        x += w + rng.randint(10, 40)
    # liman vinci
    for vx in (300, 760):
        line(img, vx, base, vx + 10, base - 160, "n2", 2)
        line(img, vx + 20, base, vx + 10, base - 160, "n2", 2)
        line(img, vx + 10, base - 160, vx - 70, base - 150, "n2", 2)
        line(img, vx - 60, base - 151, vx - 60, base - 90, "n0")
    # zemin
    rect(img, 0, base, BW - 1, base + 8, "n1")   # rıhtım; altı saydam (deniz görünsün)
    for xx in range(BW):
        if dither(xx, base, 0.5):
            px(img, xx, base, "n2")
    return img


def ch5_card():
    img = new(SW, SH)
    grad(img, ["k", "n1", "n2"], 0, SH)
    sea(img, 200, ("n2", "n1", "k"), 7, "n3")
    # fabrika silueti solda
    rect(img, 0, 120, 190, 210, "k")
    for t in range(5):
        x0 = t * 38
        poly(img, [(x0, 120), (x0 + 30, 100), (x0 + 30, 120)], "k")
    rect(img, 60, 30, 72, 120, "k")
    rect(img, 120, 50, 130, 120, "k")
    for wy in (140, 165):
        for wx in range(10, 180, 22):
            rect(img, wx, wy, wx + 8, wy + 10, "w3" if (wx // 22 + wy) % 5 == 0 else "n0")
    # duman/buhar (düdük)
    rng = random.Random(9)
    for i in range(14):
        a = i / 14.0
        cx, cy = 66 + a * 90 + rng.uniform(-4, 4), 26 - a * 20 + rng.uniform(-3, 3)
        r = 6 + a * 14
        for yy in range(int(cy - r), int(cy + r)):
            for xx in range(int(cx - r * 1.3), int(cx + r * 1.3)):
                d = ((xx - cx) / (r * 1.3)) ** 2 + ((yy - cy) / r) ** 2
                if d < 1:
                    blend(img, xx, yy, "f2", (1 - d) * 0.35 * (1 - a * 0.7))
    # dalgakıran ve uzakta fener
    for x in range(180, 420):
        y = 214 - (x - 180) // 30
        rect(img, x, y, x, 222, "n3" if x % 14 else "n1")
        px(img, x, y, "f1")
    rect(img, 404, 120, 412, 196, "n1")
    rect(img, 401, 112, 415, 120, "w1")
    glow_dot(img, 408, 116, 18)
    person(img, 250, 212, 22, "k")
    fog(img, 200, 270, "f1", 0.35, 6, 80)
    return img


def boiler():
    img = new(44, 56)
    # gövde (silindir)
    for y in range(8, 50):
        for x in range(4, 40):
            t = (x - 4) / 36
            px(img, x, y, ramp(["iron", "iron2", "n4", "iron2", "iron"], t, x, y))
    for y in (14, 30, 46):
        line(img, 4, y, 39, y, "k")
        for x in range(6, 39, 5):
            px(img, x, y - 1, "n5")
    ellipse(img, 22, 8, 18, 5, "iron2")
    ellipse(img, 22, 8, 14, 3, "iron")
    # ocak kapağı
    rect(img, 14, 34, 30, 46, "k")
    rect(img, 16, 36, 28, 44, "w4")
    # basınç göstergesi
    ellipse(img, 33, 20, 5, 5, "paper2")
    ellipse(img, 33, 20, 4, 4, "paper")
    line(img, 33, 20, 30, 17, "red")
    # boru ve ayaklar
    rect(img, 19, 0, 24, 6, "iron2")
    rect(img, 6, 50, 10, 55, "k"); rect(img, 34, 50, 38, 55, "k")
    outline(img)
    save(img, "props/boiler.png")


def valve():
    img = new(30, 46)
    rect(img, 13, 14, 17, 45, "iron")       # boru
    rect(img, 9, 38, 21, 45, "iron2")
    # düdük
    rect(img, 11, 0, 19, 10, "brass")
    rect(img, 12, 1, 14, 9, "brass2")
    rect(img, 10, 10, 20, 12, "iron2")
    # çark
    for i in range(8):
        a = math.tau * i / 8
        line(img, 15, 24, 15 + math.cos(a) * 9, 24 + math.sin(a) * 9, "red2")
    ellipse(img, 15, 24, 9, 9, "red")
    ellipse(img, 15, 24, 7, 7, "red2")
    for i in range(4):
        a = math.tau * i / 4 + 0.4
        line(img, 15, 24, 15 + math.cos(a) * 7, 24 + math.sin(a) * 7, "red")
    ellipse(img, 15, 24, 2, 2, "iron2")
    outline(img)
    save(img, "props/valve.png")


def timeclock():
    img = new(18, 30)
    rect(img, 1, 0, 16, 22, "wood2")
    rect(img, 3, 2, 14, 12, "paper2")
    ellipse(img, 8.5, 7, 4, 4, "paper")
    line(img, 8, 7, 8, 4, "k"); line(img, 8, 7, 11, 7, "k")
    rect(img, 4, 14, 13, 20, "k")
    for i in range(4):
        rect(img, 5 + i * 2, 15, 5 + i * 2, 19, "paper")
    rect(img, 7, 22, 10, 29, "wood")
    outline(img)
    save(img, "props/timeclock.png")


def conveyor():
    img = new(80, 22)
    rect(img, 0, 2, 79, 7, "n2")
    for x in range(0, 80, 6):
        line(img, x, 2, x + 3, 7, "n3")
    for x in (6, 40, 72):
        rect(img, x, 8, x + 3, 21, "iron")
    ellipse(img, 4, 5, 4, 4, "iron2"); ellipse(img, 75, 5, 4, 4, "iron2")
    # üstünde konserve kutuları
    for x in (18, 26, 50):
        rect(img, x, -4 + 2, x + 5, 1, "iron2")
    outline(img)
    save(img, "decor/conveyor.png")


def hook():
    img = new(16, 30)
    line(img, 8, 0, 8, 16, "iron2")
    for y in range(16, 28):
        a = (y - 16) / 12 * math.pi
        px(img, int(8 + math.sin(a) * 5), y, "iron2")
        px(img, int(8 + math.sin(a) * 5) + 1, y, "iron")
    outline(img)
    save(img, "decor/hook.png")


def generate():
    save(factory_layer(), "bg/c5_factory.png")
    save(ch5_card(), "story/ch5.png")
    boiler(); valve(); timeclock(); conveyor(); hook()


if __name__ == "__main__":
    generate()
