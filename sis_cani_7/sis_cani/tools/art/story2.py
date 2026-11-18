# -*- coding: utf-8 -*-
"""Bölüm kartları, son panelleri ve logo."""
import math
from common import *
from story import grad, sea, fog, pier, bell_frame, person, boat, glow_dot, W, H
from PIL import ImageFont, ImageDraw, ImageFilter


def ch1_card():
    img = new(W, H)
    grad(img, ["n0", "n1", "n3"], 0, 170)
    ellipse(img, 380, 50, 12, 12, "f3")
    sea(img, 168, ("n2", "sea1", "sea0"), 2)
    # uzakta ada ve sönük fener
    poly(img, [(250, 168), (300, 150), (360, 146), (420, 168)], "n1")
    rect(img, 338, 104, 344, 148, "n1")
    rect(img, 336, 100, 346, 104, "n1")
    pier(img, 0, 200, 205)
    boat(img, 40, 210, 110, lantern=True)
    person(img, 170, 205, 30, "k")
    fog(img, 180, 225, "f1", 0.35, 3, 80)
    return img


def ch2_card():
    img = new(W, H)
    for y in range(H):
        for x in range(W):
            d = math.hypot((x - 240) / 1.6, y - 150)
            c = ramp(["n2", "n1", "n0", "k"], min(0.99, d / 220), x, y)
            px(img, x, y, c)
    rng = random.Random(3)
    for i in range(30):
        x = rng.randint(0, W)
        l = rng.randint(20, 90)
        for y in range(l):
            k = 1 - y / l
            for xx in range(int(x - 6 * k), int(x + 6 * k) + 1):
                px(img, xx % W, y, "k")
    rect(img, 0, 220, W - 1, H - 1, "k")
    glow_dot(img, 236, 196, 40)
    person(img, 236, 220, 28, "k")
    # tebeşir oklar
    for x in (120, 330, 400):
        line(img, x, 180, x + 14, 180, "f2")
        line(img, x + 10, 176, x + 14, 180, "f2")
        line(img, x + 10, 184, x + 14, 180, "f2")
    return img


def ch3_card():
    img = new(W, H)
    grad(img, ["k", "n1", "n2"], 0, H)
    # fırtına bulutu + şimşek
    for y in range(0, 90):
        for x in range(W):
            if fbm(x / 50.0, y / 18.0, 4) > 0.5 - y / 400:
                px(img, x, y, "n2")
    line(img, 90, 0, 100, 40, "f3"); line(img, 100, 40, 88, 70, "f3"); line(img, 88, 70, 98, 110, "f3")
    sea(img, 210, ("n2", "n1", "k"), 9, "n3")
    # kayalık + kule
    poly(img, [(200, 270), (220, 210), (300, 200), (360, 215), (380, 270)], "k")
    for y in range(40, 205):
        k = (y - 40) / 165
        hw = 10 + k * 14
        for x in range(int(290 - hw), int(290 + hw)):
            px(img, x, y, "n0" if x < 290 else "n1")
        if (y // 12) % 2 == 0:
            line(img, int(290 - hw), y, int(290 + hw), y, "k")
    rect(img, 276, 30, 304, 40, "k")
    rect(img, 282, 18, 298, 30, "n1")
    poly(img, [(280, 18), (290, 8), (300, 18)], "k")
    fog(img, 225, 270, "f1", 0.35, 5, 80)
    return img


def end_a():
    """Fener yeniden yanıyor: denizin üstünden dönen huzme, tekne uzaklaşıyor."""
    img = new(W, H)
    grad(img, ["n0", "n2", "f1"], 0, 175)
    sea(img, 175, ("n3", "sea1", "sea0"), 4, "f1")
    rect(img, 100, 60, 112, 175, "k")
    rect(img, 96, 50, 116, 60, "k")
    glow_dot(img, 106, 44, 30)
    # huzme
    for y in range(0, 120):
        for x in range(106, W):
            t = (x - 106) / (W - 106)
            top = 44 - t * 40
            bot = 44 + t * 50
            if top <= y <= bot and dither(x, y, (1 - t) * 0.55):
                o = img.getpixel((x, y))
                img.putpixel((x, y), rgba(lerp_c(o[:3], "w0", 0.5)))
    boat(img, 330, 182, 70, lantern=True)
    person(img, 108, 50, 10, "k", cap=True)
    return img


def end_b():
    """Bir yıl sonra İstanbul: Boğaz sisli, pencerede lamba."""
    img = new(W, H)
    grad(img, ["n1", "n3", "f1"], 0, 170)
    # Galata + minareler
    rect(img, 300, 70, 320, 170, "n2")
    poly(img, [(296, 70), (310, 46), (324, 70)], "n2")
    for x in (80, 140, 400):
        rect(img, x, 80, x + 4, 170, "n2")
        poly(img, [(x - 1, 80), (x + 2, 66), (x + 5, 80)], "n2")
    ellipse(img, 110, 160, 40, 26, "n2")
    sea(img, 170, ("n3", "n2", "n1"), 6, "f1")
    fog(img, 150, 230, "f2", 0.4, 8, 90)
    # pencere çerçevesi + lamba
    rect(img, 0, 0, 30, H - 1, "k"); rect(img, W - 31, 0, W - 1, H - 1, "k")
    rect(img, 0, 0, W - 1, 18, "k"); rect(img, 0, 230, W - 1, H - 1, "k")
    rect(img, 238, 18, 242, 230, "k")
    glow_dot(img, 400, 214, 30)
    rect(img, 394, 214, 406, 230, "iron")
    return img


def logo():
    """Başlık logosu: SİS ÇANI + çan ikonu (pixel)."""
    font_path = os.path.join(ROOT, "fonts", "Lora.ttf")
    big = ImageFont.truetype(font_path, 44)
    img = Image.new("RGBA", (300, 80), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.text((58, 8), "SİS ÇANI", font=big, fill=(232, 236, 242, 255))
    # pikselleştir (keskin kenar)
    a = img.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    img.putalpha(a)
    # çan
    bell = new(40, 44)
    rect(bell, 18, 0, 21, 5, "iron")
    poly(bell, [(11, 6), (28, 6), (33, 26), (38, 33), (1, 33), (6, 26)], "brass")
    for y in range(7, 33):
        px(bell, 11 + int((y - 7) * 0.2), y, "w4")
    line(bell, 1, 34, 38, 34, "brass2")
    rect(bell, 18, 35, 21, 40, "iron")
    rim(bell, P["brass2"], 1)
    outline(bell)
    img.alpha_composite(bell, (8, 14))
    outline(img)
    # ince turuncu alt çizgi
    rect(img, 60, 64, 268, 65, "w2")
    return img


def generate():
    for n, f in (("ch1", ch1_card), ("ch2", ch2_card), ("ch3", ch3_card), ("end_a", end_a), ("end_b", end_b)):
        save(f(), "story/%s.png" % n)
    import logo as _logo
    _logo.generate()


if __name__ == "__main__":
    generate()
