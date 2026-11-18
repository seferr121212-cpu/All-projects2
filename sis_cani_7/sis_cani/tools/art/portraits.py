# -*- coding: utf-8 -*-
"""Diyalog portreleri (40x40, oyunda 3x) + Fısıltı düşmanı + yeni toplanabilirler."""
import math
from common import *

PW = 40


def bg(img, c1, c2):
    for y in range(PW):
        for x in range(PW):
            px(img, x, y, ramp([c1, c2], y / PW, x, y))


def face(img, skin, skin2, cx=20, top=10, w=14, h=17):
    for y in range(top, top + h):
        k = (y - top) / h
        hw = w / 2 * (1 - max(0, k - 0.7) * 1.4)
        for x in range(int(cx - hw), int(cx + hw) + 1):
            c = skin if x > cx - hw * 0.35 else skin2
            px(img, x, y, c)
    # gözler
    for ex in (cx - 3, cx + 3):
        px(img, ex, top + 7, "k")
        px(img, ex, top + 6, skin2)
        px(img, ex - 1, top + 5, skin2); px(img, ex + 1, top + 5, skin2)
    # burun + ağız
    line(img, cx, top + 8, cx + 1, top + 11, skin2)
    line(img, cx - 2, top + 14, cx + 2, top + 14, skin2)
    # lambadan sıcak yan ışık
    for y in range(top + 2, top + h - 2):
        px(img, int(cx + w / 2 - 1), y, (230, 186, 150))


def shoulders(img, col, col2):
    for y in range(28, PW):
        k = (y - 28) / 12
        hw = 8 + k * 12
        for x in range(int(20 - hw), int(20 + hw) + 1):
            px(img, x, y, col if x > 18 else col2)


def kerem():
    img = new(PW, PW)
    bg(img, "n1", "n0")
    shoulders(img, "coat", "coat2")
    rect(img, 14, 26, 26, 29, (120, 44, 38))       # atkı
    face(img, "skin", "skin2")
    rect(img, 12, 7, 27, 11, "cap")                 # kasket
    rect(img, 24, 11, 30, 12, "cap")
    rect(img, 12, 12, 13, 18, "n1")                 # saç
    rect(img, 16, 24, 24, 26, "skin2")              # sakal gölgesi
    outline(img)
    return img


def yusuf():
    img = new(PW, PW)
    bg(img, "n1", "n0")
    shoulders(img, "n3", "n2")                      # kalın kazak
    for x in range(10, 31, 3):
        line(img, x, 30, x, 39, "n2")
    face(img, "skin", "skin2", h=16)
    rect(img, 12, 7, 28, 11, "n1")                  # dağınık saç
    for x in (13, 17, 22, 26):
        px(img, x, 6, "n1")
    rect(img, 14, 21, 26, 27, "n2")                 # sakal
    rect(img, 16, 22, 24, 23, "n1")
    # sise karışan kenar
    for y in range(PW):
        for x in range(30, PW):
            if dither(x, y, (x - 30) / 10) and img.getpixel((x, y))[3]:
                px(img, x, y, "f1", 150)
    outline(img)
    return img


def riza():
    img = new(PW, PW)
    bg(img, "n1", "n0")
    shoulders(img, (60, 66, 58), (44, 48, 44))      # muşamba
    face(img, "skin2", (120, 82, 68), w=16)
    rect(img, 11, 5, 29, 11, "n1")                  # bere
    rect(img, 10, 10, 30, 11, "n2")
    rect(img, 12, 19, 28, 28, "n4")                 # gür beyaz sakal
    rect(img, 14, 18, 26, 19, "n5")
    line(img, 25, 22, 33, 20, "wood2", 2)           # pipo
    px(img, 33, 19, "w2")
    outline(img)
    return img


def husnu(young=False):
    img = new(PW, PW)
    bg(img, "n1", "n0")
    shoulders(img, (40, 46, 66), (30, 34, 50))      # bekçi ceketi
    for y in (31, 35):
        px(img, 20, y, "brass")
    face(img, "skin" if young else "skin2", "skin2" if young else (120, 82, 68), h=17)
    rect(img, 11, 6, 29, 10, (30, 34, 50))          # bekçi şapkası
    rect(img, 9, 10, 31, 11, "k")
    px(img, 20, 8, "brass")
    if not young:
        rect(img, 13, 20, 27, 25, "f1")             # beyaz bıyık/sakal
        for y in range(PW):
            for x in range(PW):
                if img.getpixel((x, y))[3] and dither(x, y, 0.25):
                    o = img.getpixel((x, y))
                    img.putpixel((x, y), rgba(lerp_c(o[:3], "f1", 0.35)))
    else:
        rect(img, 15, 22, 25, 23, "n1")             # bıyık
    outline(img)
    return img


def kerem_child():
    img = new(PW, PW)
    bg(img, "n0", "k")
    shoulders(img, "n3", "n2")                      # pijama
    face(img, "skin", "skin2", top=12, w=13, h=15)
    rect(img, 13, 9, 27, 13, "n1")                  # saç
    for x in (14, 18, 23):
        px(img, x, 8, "n1")
    outline(img)
    return img


def whisper(t):
    img = new(26, 46)
    sw = math.sin(t * math.tau)
    # ince uzun gövde, yüzsüz kafa, uzun saç telleri
    ellipse(img, 13 + sw, 7, 4, 5, "n0")
    for y in range(11, 40):
        k = (y - 11) / 29
        hw = 3 + math.sin(k * math.pi) * 3
        for x in range(int(13 - hw + sw * (1 - k)), int(13 + hw + sw * (1 - k)) + 1):
            if dither(x, y, 1.0 - k * 0.7):
                px(img, x, y, "n0")
    for i in range(6):
        x0 = 9 + i * 1.6
        for y in range(4, 30):
            xx = x0 + math.sin(y * 0.3 + t * math.tau + i) * 1.5
            if (y + i) % 3:
                px(img, xx + sw, y, "k")
    for y in range(36, 46):
        for x in range(4, 22):
            if dither(x, y + int(t * 6), 0.35 - (y - 36) / 30):
                px(img, x, y, "n1")
    rim(img, (120, 150, 170), 0)
    return img


def wick():
    img = new(12, 14)
    rect(img, 4, 2, 7, 12, "paper")
    line(img, 5, 1, 6, 0, "k")
    px(img, 6, 0, "w1")
    rect(img, 2, 12, 9, 13, "brass")
    outline(img)
    return img


def letter():
    img = new(16, 12)
    rect(img, 0, 0, 15, 11, "paper2")
    line(img, 0, 0, 8, 6, "paper")
    line(img, 15, 0, 8, 6, "paper")
    rect(img, 6, 5, 9, 7, "red2")
    outline(img)
    return img


def small_bell(c):
    img = new(16, 18)
    rect(img, 7, 0, 8, 3, "iron")
    poly(img, [(4, 4), (11, 4), (13, 12), (15, 15), (0, 15), (2, 12)], c)
    line(img, 0, 15, 15, 15, "brass2")
    px(img, 7, 16, "iron"); px(img, 8, 16, "iron")
    rim(img, P["brass2"], 1)
    outline(img)
    return img


def generate():
    for n, f in (("kerem", kerem), ("yusuf", yusuf), ("riza", riza), ("husnu", lambda: husnu(False)),
                 ("husnu_young", lambda: husnu(True)), ("kerem_child", kerem_child)):
        save(f(), "portraits/%s.png" % n)
    save(sheet([whisper(i / 6) for i in range(6)]), "chars/echo_whisper.png")
    save(wick(), "props/wick.png")
    save(letter(), "props/letter.png")
    for i, c in enumerate(("brass", (160, 120, 70), (130, 100, 60))):
        save(small_bell(c), "props/bell_%d.png" % (i + 1))


if __name__ == "__main__":
    generate()
