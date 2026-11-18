# -*- coding: utf-8 -*-
"""Objeler: kandil + alev, lamba, toplanabilirler, sandık, ayna, mercek, mühür, telsiz, makara,
mekanizma, büyük çan, iskele çanı, tekne, ev parçaları, mobilya, ışık parıltısı."""
import math
from common import *


def brazier():
    img = new(24, 28)
    rect(img, 11, 12, 12, 27, "iron")                 # ayak
    line(img, 11, 18, 4, 27, "iron", 1)
    line(img, 12, 18, 19, 27, "iron", 1)
    poly(img, [(2, 6), (21, 6), (17, 13), (6, 13)], "iron")   # kase
    line(img, 2, 6, 21, 6, "iron2")
    for x in range(4, 20, 3):
        px(img, x, 9, "k")
    rect(img, 5, 4, 18, 5, "n1")                      # kömür
    outline(img)
    return img


def flame(t):
    img = new(16, 22)
    for y in range(22):
        for x in range(16):
            k = y / 21.0
            wob = math.sin(y * 0.55 + t * math.tau * 2) * 2.0 * (1 - k)
            w = (2 + 5.5 * k ** 0.7) * (0.85 + 0.15 * math.sin(t * math.tau + y))
            d = abs(x - 8 - wob)
            if d < w:
                r = d / w
                n = vnoise(x * 0.5, y * 0.4 - t * 6, 5)
                v = (1 - r) * (0.4 + 0.8 * k) + n * 0.3
                if v > 0.85:
                    c = "w0"
                elif v > 0.6:
                    c = "w1"
                elif v > 0.38:
                    c = "w2"
                elif v > 0.2:
                    c = "w3"
                else:
                    continue
                px(img, x, y, c)
    return img


def lamp_held():
    img = new(9, 12)
    line(img, 2, 0, 6, 0, "iron2")
    px(img, 1, 1, "iron2")
    px(img, 7, 1, "iron2")
    rect(img, 2, 2, 6, 3, "iron")
    rect(img, 1, 4, 7, 9, "glass", 120)
    line(img, 1, 4, 1, 9, "iron")
    line(img, 7, 4, 7, 9, "iron")
    rect(img, 2, 10, 6, 11, "iron")
    return img


def lamp_flame(t):
    img = new(5, 6)
    h = 4 + round(math.sin(t * math.tau) * 1)
    for y in range(6 - h, 6):
        k = (y - (6 - h)) / max(h - 1, 1)
        w = 0.6 + k * 1.4
        for x in range(5):
            if abs(x - 2) <= w:
                px(img, x, y, "w0" if abs(x - 2) < 0.6 and k > 0.3 else "w1")
    return img


def pickups():
    out = {}
    # gazyağı tenekesi
    img = new(12, 16)
    rect(img, 1, 3, 10, 15, "red2")
    rect(img, 2, 4, 9, 14, "red")
    rect(img, 7, 0, 9, 2, "iron")
    line(img, 2, 8, 9, 8, "red2")
    rect(img, 3, 10, 6, 12, "paper2")
    outline(img)
    out["oil"] = img
    small = new(8, 11)
    rect(small, 2, 0, 5, 1, "iron")
    rect(small, 1, 2, 6, 10, "glass", 170)
    rect(small, 2, 5, 5, 9, "w3")
    outline(small)
    out["oil_small"] = small
    # günlük sayfası
    img = new(13, 15)
    poly(img, [(1, 1), (11, 0), (12, 14), (0, 13)], "paper")
    for y in (4, 6, 8, 10):
        line(img, 3, y, 9, y, "paper2")
    outline(img)
    out["page"] = img
    # bant
    img = new(16, 10)
    rect(img, 0, 0, 15, 9, "n2")
    rect(img, 2, 2, 13, 6, "paper2")
    ellipse(img, 5, 4, 1.5, 1.5, "k")
    ellipse(img, 10, 4, 1.5, 1.5, "k")
    outline(img)
    out["tape"] = img
    # dişli
    img = new(16, 16)
    for i in range(16):
        a = math.tau * i / 16
        r = 7.5 if i % 2 == 0 else 6
        line(img, 8, 8, 8 + math.cos(a) * r, 8 + math.sin(a) * r, "brass")
    ellipse(img, 8, 8, 5, 5, "brass")
    ellipse(img, 8, 8, 2, 2, "k")
    rim(img, P["brass2"], 0)
    outline(img)
    out["gear"] = img
    # el çanı
    img = new(12, 15)
    rect(img, 5, 0, 6, 3, "wood")
    poly(img, [(3, 4), (8, 4), (10, 11), (1, 11)], "brass")
    line(img, 0, 12, 11, 12, "brass2")
    px(img, 5, 13, "iron")
    rim(img, P["brass2"], 1)
    outline(img)
    out["bell"] = img
    # kırmızı cam
    img = new(11, 12)
    rect(img, 1, 1, 9, 10, "red", 200)
    line(img, 2, 2, 4, 2, (240, 140, 130))
    outline(img)
    out["red"] = img
    # lamba (yerde)
    img = new(11, 15)
    l = lamp_held()
    img.paste(l, (1, 2), l)
    outline(img)
    out["lamp"] = img
    # telsiz
    img = new(22, 16)
    rect(img, 0, 3, 21, 15, "wood2")
    rect(img, 2, 5, 12, 13, "n2")
    for y in range(6, 13, 2):
        line(img, 3, y, 11, y, "n3")
    ellipse(img, 16, 8, 2.5, 2.5, "paper2")
    rect(img, 14, 12, 19, 13, "iron2")
    line(img, 18, 3, 21, 0, "iron2")
    outline(img)
    out["radio"] = img
    for k, v in out.items():
        save(v, "props/%s.png" % k)


def crate():
    img = new(30, 30)
    rect(img, 0, 0, 29, 29, "wood2")
    for y in range(1, 29, 7):
        rect(img, 1, y, 28, y + 5, "wood")
        line(img, 1, y, 28, y, "wood3")
    line(img, 2, 2, 27, 27, "wood2", 2)
    rect(img, 0, 0, 2, 29, "wood2")
    rect(img, 27, 0, 29, 29, "wood2")
    outline(img)
    save(img, "props/crate.png")


def mirror_stand():
    img = new(20, 32)
    rect(img, 9, 0, 10, 28, "iron")
    rect(img, 3, 28, 16, 31, "iron")
    line(img, 3, 28, 16, 28, "iron2")
    outline(img)
    save(img, "props/mirror_stand.png")


def lens_seal():
    img = new(14, 52)
    ellipse(img, 7, 13, 5, 12, "glass", 140)
    for y in range(2, 25):
        px(img, 4, y, "f3", 120)
    rect(img, 6, 26, 7, 49, "iron")
    rect(img, 2, 49, 11, 51, "iron")
    save(img, "props/lens.png")
    img = new(18, 20)
    ellipse(img, 9, 10, 8, 9, "red2")
    ellipse(img, 8, 9, 5, 6, "red")
    px(img, 6, 7, (230, 120, 110))
    outline(img)
    save(img, "props/seal.png")


def winch():
    img = new(26, 30)
    poly(img, [(3, 29), (22, 29), (18, 10), (7, 10)], "wood2")
    line(img, 7, 10, 18, 10, "wood")
    for i in range(10):
        a = math.tau * i / 10
        line(img, 12, 8, 12 + math.cos(a) * 8, 8 + math.sin(a) * 8, "wood3")
    ellipse(img, 12, 8, 2, 2, "iron")
    line(img, 12, 8, 24, 2, "wood3")
    outline(img)
    save(img, "props/winch.png")


def mechanism():
    img = new(46, 48)
    rect(img, 2, 8, 43, 47, "iron")
    rect(img, 4, 10, 41, 45, "n2")
    for cx, cy, r in [(14, 22, 8), (28, 32, 7), (34, 18, 5)]:
        for i in range(12):
            a = math.tau * i / 12
            line(img, cx, cy, cx + math.cos(a) * r, cy + math.sin(a) * r, "brass")
        ellipse(img, cx, cy, r - 2, r - 2, "brass")
        ellipse(img, cx, cy, 1.5, 1.5, "k")
    line(img, 23, 0, 23, 8, "iron2", 2)
    outline(img)
    save(img, "props/mechanism.png")


def big_bell():
    img = new(52, 50)
    rect(img, 24, 0, 27, 6, "iron")
    poly(img, [(14, 7), (37, 7), (42, 30), (48, 40), (3, 40), (9, 30)], "brass")
    for y in range(8, 40):
        px(img, 14 + int((y - 8) * 0.2), y, "w4")
    line(img, 3, 41, 48, 41, "brass2")
    line(img, 6, 30, 45, 30, "w4")
    rect(img, 24, 41, 27, 46, "iron")
    rim(img, P["brass2"], 1)
    outline(img)
    save(img, "props/big_bell.png")
    # iskele çanı (çatısıyla)
    img = new(44, 92)
    rect(img, 4, 8, 6, 91, "wood2")
    rect(img, 37, 8, 39, 91, "wood2")
    poly(img, [(0, 9), (22, 0), (43, 9)], "wood")
    rect(img, 1, 9, 42, 10, "wood2")
    bell = new(20, 22)
    poly(bell, [(6, 0), (13, 0), (16, 13), (19, 18), (0, 18), (3, 13)], "brass")
    rim(bell, P["brass2"], 1)
    img.paste(bell, (12, 14), bell)
    line(img, 22, 32, 22, 70, "paper2")   # çürük ip
    line(img, 22, 71, 23, 74, "paper2")
    outline(img)
    save(img, "props/pier_bell.png")


def boat():
    img = new(230, 70)
    poly(img, [(0, 40), (229, 40), (212, 66), (16, 66)], "wood2")
    line(img, 0, 40, 229, 40, "wood3")
    line(img, 8, 52, 222, 52, "wood")
    rect(img, 108, 0, 110, 40, "wood2")              # direk
    rect(img, 150, 18, 196, 40, "wood")              # kamara
    rect(img, 156, 22, 166, 30, "w2")                # pencere ışığı
    rect(img, 176, 22, 186, 30, "w2")
    rect(img, 146, 14, 200, 17, "wood2")
    line(img, 110, 2, 228, 38, "n3")                 # halat
    line(img, 110, 2, 2, 38, "n3")
    outline(img)
    save(img, "props/boat.png")


def furniture():
    out = {}
    img = new(80, 22)                                 # yatak
    rect(img, 0, 8, 79, 17, "wood2")
    rect(img, 2, 5, 77, 10, "paper2")
    rect(img, 2, 3, 14, 8, "paper")
    rect(img, 0, 2, 2, 21, "wood")
    rect(img, 77, 6, 79, 21, "wood")
    outline(img)
    out["bed"] = img
    img = new(26, 40)                                 # soba
    rect(img, 2, 10, 23, 37, "iron")
    rect(img, 6, 20, 19, 30, "k")
    rect(img, 8, 24, 17, 29, "w2")
    rect(img, 10, 0, 14, 10, "iron")
    rect(img, 3, 37, 6, 39, "iron")
    rect(img, 19, 37, 22, 39, "iron")
    outline(img)
    out["stove"] = img
    img = new(70, 30)                                 # masa
    rect(img, 0, 0, 69, 4, "wood")
    rect(img, 3, 5, 6, 29, "wood2")
    rect(img, 63, 5, 66, 29, "wood2")
    outline(img)
    out["desk"] = img
    img = new(12, 15)                                 # fotoğraf
    rect(img, 0, 0, 11, 14, "wood2")
    rect(img, 2, 2, 9, 12, "paper2")
    ellipse(img, 5.5, 6, 2, 2.5, "n3")
    rect(img, 3, 9, 8, 12, "n3")
    outline(img)
    out["photo"] = img
    img = new(30, 14)                                 # mektup yığını
    for i in range(5):
        rect(img, 1 + i, 9 - i * 2, 24 + i, 12 - i * 2, "paper" if i % 2 else "paper2")
        line(img, 1 + i, 9 - i * 2, 24 + i, 12 - i * 2, "paper2")
    outline(img)
    out["letters"] = img
    img = new(12, 90)                                 # bant rafı
    rect(img, 0, 0, 11, 89, "wood2")
    for y in range(3, 88, 6):
        for x in range(1, 11, 3):
            rect(img, x, y, x + 1, y + 4, "n2" if (x + y) % 2 else "n3")
    outline(img)
    out["shelf"] = img
    img = new(60, 40)                                 # okul tahtası
    rect(img, 0, 0, 59, 39, "wood2")
    rect(img, 3, 3, 56, 34, (34, 48, 40))
    out["board"] = img
    img = new(30, 20)                                 # sıra
    rect(img, 0, 6, 29, 9, "wood")
    rect(img, 2, 10, 4, 19, "wood2")
    rect(img, 25, 10, 27, 19, "wood2")
    rect(img, 0, 0, 2, 9, "wood2")
    outline(img)
    out["school_desk"] = img
    img = new(124, 180)                               # büyük mercek
    for y in range(180):
        for x in range(124):
            dx, dy = (x - 62) / 60, (y - 90) / 88
            if dx * dx + dy * dy <= 1:
                band = int((y + x * 0.2) / 9) % 2
                px(img, x, y, "glass" if band else (120, 150, 170), 150 if band else 120)
    for y in range(0, 180, 9):
        line(img, 4, y, 120, y, "iron")
    out["lens_big"] = img
    for k, v in out.items():
        save(v, "props/%s.png" % k)


def glow():
    """Additive ışık parıltısı (yumuşak, pixel değil)"""
    s = 128
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    for y in range(s):
        for x in range(s):
            d = math.hypot(x - s / 2 + 0.5, y - s / 2 + 0.5) / (s / 2)
            a = max(0.0, 1 - d) ** 2.2
            img.putpixel((x, y), (255, 255, 255, int(a * 255)))
    save(img, "fx/glow.png")
    img = new(4, 4)
    rect(img, 1, 0, 2, 3, "f3")
    rect(img, 0, 1, 3, 2, "f3")
    save(img, "fx/mote.png")
    img = new(1, 6)
    for y in range(6):
        px(img, 0, y, "f2", 60 + y * 25)
    save(img, "fx/rain.png")


def ui_icons():
    img = new(16, 16)                                  # hedef oku
    poly(img, [(2, 2), (14, 8), (2, 14), (5, 8)], "w1")
    outline(img)
    save(img, "ui/arrow.png")
    img = new(12, 16)
    l = lamp_held()
    img.paste(l, (1, 2), l)
    rect(img, 4, 7, 5, 9, "w1")
    outline(img)
    save(img, "ui/lamp_icon.png")
    save(pickups_bell_icon(), "ui/bell_icon.png")


def pickups_bell_icon():
    img = new(12, 15)
    rect(img, 5, 0, 6, 3, "wood")
    poly(img, [(3, 4), (8, 4), (10, 11), (1, 11)], "brass")
    line(img, 0, 12, 11, 12, "brass2")
    outline(img)
    return img


if __name__ == "__main__":
    save(brazier(), "props/brazier.png")
    save(sheet([flame(i / 8) for i in range(8)]), "props/flame.png")
    save(lamp_held(), "props/lamp_held.png")
    save(sheet([lamp_flame(i / 4) for i in range(4)]), "props/lamp_flame.png")
    pickups()
    crate()
    mirror_stand()
    lens_seal()
    winch()
    mechanism()
    big_bell()
    boat()
    furniture()
    glow()
    ui_icons()
