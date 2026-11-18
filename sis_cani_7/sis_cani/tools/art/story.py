# -*- coding: utf-8 -*-
"""Açılış hikaye panelleri (480x270, oyunda 4x)."""
import math
from common import *

W, H = 480, 270


def grad(img, colors, y0=0, y1=H):
    for y in range(y0, y1):
        t = (y - y0) / max(1, (y1 - y0 - 1))
        for x in range(W):
            px(img, x, y, ramp(colors, t, x, y))


def sea(img, y0, colors=("n2", "sea1", "sea0"), seed=1, sparkle="n4"):
    for y in range(y0, H):
        t = (y - y0) / (H - y0)
        for x in range(W):
            c = ramp(list(colors), t, x, y)
            if vnoise(x / 9.0, y / 1.5, seed) > 0.74 - t * 0.1:
                c = lerp_c(c, sparkle, 0.5)
            px(img, x, y, c)


def fog(img, y0, y1, color="f1", amt=1.0, seed=3, alpha=150):
    for y in range(y0, y1):
        env = math.sin((y - y0) / (y1 - y0) * math.pi)
        for x in range(W):
            n = fbm(x / 40.0, y / 10.0, seed)
            if dither(x, y, min(1, env * max(0, n - 0.3) * 2.5 * amt)):
                px(img, x, y, color, alpha)


def pier(img, x0, x1, y, col="k"):
    rect(img, x0, y, x1, y + 4, col)
    for x in range(x0 + 4, x1, 18):
        rect(img, x, y + 4, x + 2, H, col)


def bell_frame(img, x, y, col="k", rope=True):
    rect(img, x, y - 50, x + 2, y, col)
    rect(img, x + 24, y - 50, x + 26, y, col)
    poly(img, [(x - 4, y - 49), (x + 13, y - 58), (x + 30, y - 49)], col)
    poly(img, [(x + 8, y - 44), (x + 18, y - 44), (x + 20, y - 34), (x + 6, y - 34)], col)
    if rope:
        line(img, x + 13, y - 34, x + 13, y - 14, col)


def person(img, x, y, h, col="k", wave=False, cap=True):
    """y = ayak; h = boy"""
    hw = max(2, h // 7)
    rect(img, x - hw, y - int(h * 0.55), x + hw, y - int(h * 0.12), col)        # gövde
    rect(img, x - hw + 1, y - int(h * 0.12), x - 1, y, col)                     # bacaklar
    rect(img, x + 1, y - int(h * 0.12), x + hw - 1, y, col)
    ellipse(img, x, y - int(h * 0.67), max(2, h // 9), max(2, h // 8), col)       # kafa
    if cap:
        rect(img, x - h // 9, y - int(h * 0.8), x + h // 9 + 1, y - int(h * 0.74), col)
    if wave:
        line(img, x + hw, y - int(h * 0.5), x + hw + h // 4, y - int(h * 0.85), col, 2)


def boat(img, x, y, w, col="k", lantern=True):
    poly(img, [(x, y), (x + w, y), (x + w - 8, y + 9), (x + 8, y + 9)], col)
    rect(img, x + w // 2, y - 40, x + w // 2 + 1, y, col)
    if lantern:
        glow_dot(img, x + w - 10, y - 8, 14)


def glow_dot(img, x, y, r, c="w1"):
    for yy in range(y - r, y + r + 1):
        for xx in range(x - r, x + r + 1):
            d = math.hypot(xx - x, yy - y) / r
            if d < 1 and dither(xx, yy, (1 - d) ** 2 * 0.9):
                o = img.getpixel((xx, yy)) if 0 <= xx < W and 0 <= yy < H else (0, 0, 0, 0)
                px(img, xx, yy, lerp_c(o[:3], c, 0.6))
    rect(img, x - 1, y - 1, x + 1, y + 1, "w0")


def panel1():
    """Sinop, 1965: baba teknede el sallıyor, iki çocuk iskelede."""
    img = new(W, H)
    grad(img, [(40, 44, 66), (96, 74, 76), (176, 118, 84)], 0, 170)
    # güneş
    ellipse(img, 360, 150, 22, 22, (230, 170, 110))
    sea(img, 168, ((120, 92, 84), (60, 58, 72), "sea0"), 4, (200, 140, 100))
    # şehir silueti
    for i, (x, w, h) in enumerate([(10, 40, 40), (52, 30, 56), (86, 50, 34), (140, 24, 70), (168, 46, 44)]):
        rect(img, x, 168 - h, x + w, 168, "n1")
        poly(img, [(x - 3, 168 - h), (x + w / 2, 168 - h - 12), (x + w + 3, 168 - h)], "n1")
    pier(img, 0, 220, 196)
    bell_frame(img, 40, 196)
    person(img, 150, 196, 34)              # Yusuf (21)
    person(img, 170, 196, 25)              # Kerem (14)
    boat(img, 290, 200, 90, lantern=False)
    person(img, 330, 200, 30, wave=True)   # baba
    return img


def panel2():
    """Sisli gece: çan çalınmıyor, uzakta teknenin feneri."""
    img = new(W, H)
    grad(img, ["n0", "n2", "n3"], 0, 180)
    sea(img, 178, ("n2", "n1", "k"), 6)
    glow_dot(img, 380, 170, 10)
    rect(img, 378, 172, 386, 175, "n1")
    fog(img, 120, 200, "f1", 0.7, 5, 110)
    pier(img, 0, 260, 206)
    bell_frame(img, 120, 206, "k")
    fog(img, 215, 270, "f2", 0.6, 9, 90)
    return img


def panel3():
    """Kahvehane: içeride gülen gençler, dışarıda sis."""
    img = new(W, H)
    grad(img, ["n0", "n1", "n2"])
    rect(img, 90, 60, 420, 250, "n1")
    poly(img, [(80, 60), (255, 20), (430, 60)], "n0")
    for wx in (120, 230, 340):
        rect(img, wx, 100, wx + 70, 170, "w2")
        rect(img, wx + 2, 102, wx + 68, 168, "w1")
        rect(img, wx + 34, 100, wx + 36, 170, "w3")
        rect(img, wx, 134, wx + 70, 136, "w3")
    # içerideki siluetler
    person(img, 150, 170, 40, "w4", cap=False)
    person(img, 170, 170, 44, "w4", cap=False)    # genç Yusuf
    person(img, 262, 170, 40, "w4")
    rect(img, 240, 150, 300, 154, "w4")           # masa
    rect(img, 90, 250, 420, 270, "k")
    fog(img, 200, 270, "f1", 0.8, 13, 120)
    # soldaki karanlık çan
    bell_frame(img, 20, 250, "k")
    return img


def panel4():
    """Ertesi sabah: boş deniz, iskelenin ucunda küçük Kerem."""
    img = new(W, H)
    grad(img, ["n3", "n4", "f1"], 0, 160)
    sea(img, 158, ("n4", "n3", "n2"), 8, "f1")
    fog(img, 120, 190, "f2", 0.7, 17, 110)
    pier(img, 140, 480, 200, "n1")
    bell_frame(img, 420, 200, "n1")
    person(img, 160, 200, 25, "n0")
    return img


def panel5():
    """İstanbul atölyesi: raflarda radyolar, masada açılmamış mektuplar."""
    img = new(W, H)
    grad(img, ["k", "n0", "n1"])
    # pencere: Galata
    rect(img, 30, 30, 150, 160, "n2")
    grad_part = [(30, 40, 60), (54, 62, 86)]
    for y in range(32, 158):
        for x in range(32, 148):
            px(img, x, y, ramp(grad_part, (y - 32) / 126, x, y))
    rect(img, 82, 70, 98, 158, "k")
    poly(img, [(80, 70), (90, 48), (100, 70)], "k")
    for x0 in range(32, 148, 20):
        rect(img, x0, 130 - (x0 % 30), x0 + 14, 158, "k")
    rect(img, 30, 94, 150, 96, "n2")
    rect(img, 89, 30, 91, 160, "n2")
    # raflar ve radyolar
    for sy in (60, 110):
        rect(img, 190, sy, 460, sy + 3, "wood2")
        for rx in range(200, 450, 50):
            rect(img, rx, sy - 26, rx + 36, sy - 1, "wood2")
            rect(img, rx + 3, sy - 22, rx + 18, sy - 5, "n2")
            ellipse(img, rx + 27, sy - 13, 4, 4, "paper2")
    # masa + lamba
    rect(img, 170, 200, 470, 206, "wood")
    rect(img, 180, 206, 186, 270, "wood2")
    rect(img, 450, 206, 456, 270, "wood2")
    glow_dot(img, 420, 168, 50)
    rect(img, 414, 168, 426, 198, "iron")
    # mektup yığını
    for i in range(9):
        rect(img, 250 + (i % 3), 196 - i * 4, 320 + (i % 2) * 2, 199 - i * 4, "paper" if i % 2 else "paper2")
        line(img, 252, 197 - i * 4, 318, 197 - i * 4, "paper2")
    rect(img, 280, 160, 290, 165, "red2")     # mühür
    return img


def panel6():
    """Sonuncu mektup açılıyor."""
    img = new(W, H)
    grad(img, ["k", "n0"])
    glow_dot(img, 400, 50, 120)
    poly(img, [(110, 40), (370, 30), (380, 250), (100, 260)], "paper")
    for y in range(70, 230, 14):
        x = 130
        while x < 340:
            w = random.Random(y * 7 + x).randint(8, 30)
            line(img, x, y + (x // 50) % 2, x + w, y, "n2")
            x += w + 6
    # eller
    poly(img, [(70, 200), (110, 180), (130, 230), (80, 270), (40, 270)], "skin2")
    poly(img, [(410, 190), (370, 175), (355, 230), (400, 270), (450, 270)], "skin2")
    rect(img, 0, 240, 60, 270, "coat2")
    rect(img, 430, 240, 480, 270, "coat2")
    return img


def generate():
    for i, f in enumerate([panel1, panel2, panel3, panel4, panel5, panel6], 1):
        save(f(), "story/intro_%d.png" % i)


if __name__ == "__main__":
    generate()
