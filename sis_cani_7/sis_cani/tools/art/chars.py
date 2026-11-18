# -*- coding: utf-8 -*-
"""Karakterler: Kerem (tüm animasyonlar), Yankılar, Büyük Yankı, Rıza, Yusuf."""
import math
from common import *

KW, KH = 24, 40


def _leg(img, hx, hy, fx, fy, col, knee_fwd=1.5):
    kx = (hx + fx) / 2 + knee_fwd
    ky = (hy + fy) / 2
    line(img, hx, hy, kx, ky, col, 3)
    line(img, kx, ky, fx, fy - 1, col, 3)
    rect(img, fx - 1, fy - 1, fx + 2, fy, "boot")


def kerem(pose="idle", t=0.0, carry=False):
    img = new(KW, KH)
    ph = t * math.tau
    lean, bob, stride, lift = 0, 0, 0, 0
    crouch = pose.startswith("crouch")
    if pose == "idle":
        bob = 1 if t >= 0.5 else 0
    elif pose in ("walk", "carry"):
        stride, lift = 4, 2
        bob = round(abs(math.sin(ph)) * 1)
    elif pose == "run":
        stride, lift, lean = 6, 3, 1
        bob = round(abs(math.sin(ph)) * 1.4)
    elif pose == "crouch_walk":
        stride, lift = 3, 1
    oy = (9 if crouch else 0) + bob
    hx, hy = 11, 25 + oy
    # --- sırttaki Yusuf (Son B)
    if carry:
        yc = "n2"
        poly(img, [(3, 8 + oy), (9, 6 + oy), (12, 12 + oy), (10, 24 + oy), (4, 26 + oy), (2, 18 + oy)], yc)
        ellipse(img, 6, 5 + oy, 3, 3, yc)
        line(img, 9, 12 + oy, 16, 15 + oy, yc, 2)  # omzun üstünden uzanan kol
    # --- arka bacak + arka kol
    if pose == "jump_up":
        _leg(img, hx - 1, hy, hx - 3, 39, "n2")
    elif pose == "jump_fall":
        _leg(img, hx - 1, hy, hx - 4, 38, "n2", 1)
    elif crouch:
        fx = hx - 3 + (round(math.sin(ph + math.pi) * stride) if pose == "crouch_walk" else 0)
        _leg(img, hx - 1, hy, fx, 39, "n2", 4)
    else:
        fx = hx - 1 + math.sin(ph + math.pi) * stride
        fy = 39 - max(0.0, math.cos(ph + math.pi)) * lift
        _leg(img, hx - 1, hy, fx, fy, "n2")
    sw = math.sin(ph) * (3 if pose == "run" else 2) if stride else 0
    line(img, 9 + lean, 16 + oy, 8 + lean - sw, 23 + oy, "coat2", 2)
    # --- alet çantası
    rect(img, 4 + lean, 18 + oy, 6 + lean, 24 + oy, "wood2")
    line(img, 6 + lean, 16 + oy, 13 + lean, 22 + oy, "wood2")
    # --- palto
    top = 14 + oy
    bot = 26 + oy
    poly(img, [(8 + lean, top), (15 + lean, top), (16, bot), (7, bot)], "coat")
    for y in range(top, bot + 1):
        px(img, 8 + (lean if y < top + 4 else 0) - (1 if y > bot - 4 else 0), y, "coat2")
    # ışık tarafı (lamba önde): sağ kenar açık ton, dithering ile geçiş
    for y in range(top + 2, bot + 1):
        for x in range(11 + lean, 17):
            if img.getpixel((x, y))[3] and dither(x, y, (x - 11 - lean) / 6.0):
                px(img, x, y, "coat3")
    line(img, 12 + lean, top + 2, 13, bot, "coat2")      # önlük katı
    for y in range(top + 3, bot - 4, 3):
        px(img, 13 + (lean if y < top + 4 else 0), y, "brass")   # düğmeler
    rect(img, 8 + lean, top, 14 + lean, top + 1, "coat2")  # yaka
    # atkı (rüzgarda dalgalanan uç)
    sc = (120, 44, 38)
    sc2 = (86, 30, 28)
    rect(img, 9 + lean, top - 1, 14 + lean, top + 1, sc)
    flap = 4 + (3 if pose in ("run", "jump_up", "jump_fall") else (1 if stride else 0))
    for i in range(flap):
        yy = top + 1 + round(math.sin(ph * 2 + i * 0.9) * (0.5 + i * 0.2)) + (i // 3)
        px(img, 8 + lean - i, yy, sc if i % 2 == 0 else sc2)
        px(img, 8 + lean - i, yy + 1, sc2)
    line(img, 8, bot - 3, 15, bot - 3, "coat2")          # kemer
    # --- kafa + kasket
    hx2 = 9 + lean
    hy2 = 6 + oy
    rect(img, hx2 + 1, hy2 + 1, hx2 + 5, hy2 + 7, "skin")
    rect(img, hx2, hy2 + 2, hx2, hy2 + 6, "n1")           # ense saçı
    px(img, hx2 + 2, hy2 + 4, "skin2")                    # kulak
    px(img, hx2 + 4, hy2 + 4, "k")                        # göz
    px(img, hx2 + 4, hy2 + 3, "skin2")                    # kaş
    px(img, hx2 + 5, hy2 + 3, "skin2")
    rect(img, hx2 + 5, hy2 + 2, hx2 + 5, hy2 + 6, (226, 180, 146))   # lambadan aydınlanan yanak
    px(img, hx2 + 6, hy2 + 5, "skin")                     # burun
    rect(img, hx2 + 2, hy2 + 7, hx2 + 5, hy2 + 7, "skin2")  # sakal gölgesi
    rect(img, hx2, hy2 - 1, hx2 + 5, hy2 + 1, "cap")
    rect(img, hx2 + 4, hy2 + 1, hx2 + 7, hy2 + 1, "cap")  # siper
    px(img, hx2 + 1, hy2 - 1, "n3")
    line(img, hx2 + 2, hy2 - 1, hx2 + 5, hy2 - 1, "n2")     # kasket parıltısı
    # --- ön bacak
    if pose == "jump_up":
        _leg(img, hx + 1, hy, hx + 4, 35, "pants", 2)
    elif pose == "jump_fall":
        _leg(img, hx + 1, hy, hx + 3, 39, "pants", 1)
    elif crouch:
        fx = hx + 4 + (round(math.sin(ph) * stride) if pose == "crouch_walk" else 0)
        _leg(img, hx + 1, hy, fx, 39, "pants", 4)
    else:
        fx = hx + 1 + math.sin(ph) * stride
        fy = 39 - max(0.0, math.cos(ph)) * lift
        _leg(img, hx + 1, hy, fx, fy, "pants")
    # --- ön kol (lambayı tutan el ileride)
    line(img, 14 + lean, 16 + oy, 17, 21 + oy, "coat3", 2)
    rect(img, 17, 21 + oy, 18, 22 + oy, "skin")
    # cep + bot parıltısı + lamba sapı
    rect(img, 13, bot - 7, 15, bot - 6, "coat2")
    px(img, hx + 2, 38, "n4")
    outline(img)
    _lamp_rim(img, 17, 21 + oy)
    return img


def _lamp_rim(img, lx, ly):
    """Lambaya yakın kenarlar sıcak ışık alır; uzaklaştıkça söner (tüm gövdeyi turuncu çizmez)."""
    w, h = img.size
    src = img.copy().load()
    dp = img.load()
    warm = (232, 150, 92)
    for y in range(h):
        for x in range(w):
            p = src[x, y]
            if p[3] < 200 or p[:3] == P["k"]:
                continue
            edge = False
            for nx, ny in ((x + 1, y), (x, y - 1), (x + 1, y - 1)):
                if not (0 <= nx < w and 0 <= ny < h) or src[nx, ny][3] == 0 or src[nx, ny][:3] == P["k"]:
                    edge = True
            if not edge:
                continue
            d = math.hypot(x - lx, (y - ly) * 0.8)
            k = max(0.0, 1.0 - d / 15.0) * 0.75
            if k > 0.05:
                dp[x, y] = (int(p[0] + (warm[0] - p[0]) * k), int(p[1] + (warm[1] - p[1]) * k), int(p[2] + (warm[2] - p[2]) * k), p[3])


def kerem_sheet():
    rows = []
    rows.append([kerem("idle", i / 4) for i in range(4)])
    rows.append([kerem("walk", i / 8) for i in range(8)])
    rows.append([kerem("run", i / 8) for i in range(8)])
    rows.append([kerem("jump_up"), kerem("jump_fall")])
    rows.append([kerem("crouch", 0), kerem("crouch", 0.5)] + [kerem("crouch_walk", i / 4) for i in range(4)])
    rows.append([kerem("carry", i / 8, carry=True) for i in range(8)])
    rows.append([kerem("idle", i / 4, carry=True) for i in range(4)])
    save(grid(rows), "chars/kerem.png")


# ---------------------------------------------------------------- Yankılar
def _wisp_fill(img, cx, cy, rx, ry, seed, t, base="n0", inner="n1", edge_amp=0.35, rim_c="n3", bottom_fade=True):
    w, h = img.size
    for y in range(h):
        for x in range(w):
            dx = (x - cx) / rx
            dy = (y - cy) / ry
            ang = math.atan2(dy, dx)
            r = math.hypot(dx, dy)
            edge = 1.0 + edge_amp * (vnoise(ang * 2.2 + t * 3.0, t * 2.0 + seed, seed) - 0.5) * 2
            if r <= edge:
                c = inner if (r < edge * 0.55 and dither(x, y, 0.5)) else base
                if bottom_fade and dy > 0.3 and not dither(x, y, 1.2 - dy):
                    continue
                px(img, x, y, c)
    rim(img, P[rim_c], 0)


def crawler(t):
    img = new(36, 18)
    _wisp_fill(img, 18, 11, 14, 6, 3, t, edge_amp=0.3)
    # zemin dokunaçları
    for i in range(5):
        a = t * math.tau + i
        x0 = 6 + i * 6
        line(img, x0, 15, x0 + math.sin(a) * 3, 17, "n0")
    return img


def mimic(t):
    img = new(20, 44)
    sway = math.sin(t * math.tau) * 1.0
    ellipse(img, 10 + sway, 6, 3.6, 4.2, "n0")
    poly(img, [(6 + sway, 10), (14 + sway, 10), (15, 30), (5, 30)], "n0")
    # uzun kollar
    line(img, 6 + sway, 12, 3, 30 + math.sin(t * math.tau) * 2, "n0", 2)
    line(img, 14 + sway, 12, 17, 30 - math.sin(t * math.tau) * 2, "n0", 2)
    # dağılan bacaklar
    for y in range(30, 44):
        for x in range(4, 17):
            if dither(x, y + int(t * 8), 1.0 - (y - 30) / 14) and abs(x - 10) < 6 - (y - 30) * 0.25:
                px(img, x, y, "n0")
    for y in range(10, 30):
        for x in range(6, 15):
            if img.getpixel((x, y))[3] and dither(x, y, 0.35):
                px(img, x, y, "n1")
    rim(img, P["n3"], 0)
    return img


def watcher(t):
    img = new(28, 36)
    fl = math.sin(t * math.tau) * 1
    # başlık
    poly(img, [(14, 2 + fl), (22, 10 + fl), (21, 24), (7, 24), (6, 10 + fl)], "n0")
    for y in range(2, 25):
        for x in range(6, 23):
            if img.getpixel((x, y))[3] and dither(x, y, 0.3):
                px(img, x, y, "n1")
    # kuyruk
    for y in range(24, 36):
        for x in range(4, 24):
            k = (y - 24) / 12
            cx = 14 + math.sin(y * 0.5 + t * math.tau) * 3 * k
            if abs(x - cx) < 7 * (1 - k) + 1 and dither(x, y, 1.0 - k * 0.8):
                px(img, x, y, "n0")
    # sarkan kollar
    line(img, 8, 14, 3, 30 + fl, "n0", 1)
    line(img, 20, 14, 25, 30 - fl, "n0", 1)
    rim(img, P["n3"], 0)
    return img


def great(t):
    img = new(150, 180)
    _wisp_fill(img, 80, 82, 58, 74, 9, t, base="n0", inner="k", edge_amp=0.28)
    # kollar
    for i in range(6):
        a = -0.9 + i * 0.35 + math.sin(t * math.tau + i) * 0.12
        x0, y0 = 110, 50 + i * 14
        x1 = x0 + math.cos(a) * 38
        y1 = y0 + math.sin(a) * 38 + 20
        line(img, x0, y0, x1, y1, "n0", 3)
        line(img, x1, y1, x1 + 8, y1 + 10, "n0", 2)
    # fener şapkası (eski bekçi)
    poly(img, [(62, 10), (98, 10), (92, 2), (68, 2)], "n1")
    rect(img, 56, 10, 104, 13, "n1")
    rim(img, P["n3"], 0)
    return img


def eyes():
    img = new(13, 7)
    for cx in (3, 9):
        for y in range(7):
            for x in range(13):
                d = math.hypot(x - cx, (y - 3) * 1.4)
                if d < 3.2:
                    a = int(max(0, 1 - d / 3.2) ** 1.5 * 120)
                    if a > 0:
                        px(img, x, y, "glass", a)
        rect(img, cx - 1, 3, cx + 1, 3, "f3")
        px(img, cx, 2, "w0")
        px(img, cx, 4, "glass")
    return img


def echo_sheets():
    save(sheet([crawler(i / 6) for i in range(6)]), "chars/echo_crawler.png")
    save(sheet([mimic(i / 6) for i in range(6)]), "chars/echo_mimic.png")
    save(sheet([watcher(i / 6) for i in range(6)]), "chars/echo_watcher.png")
    save(sheet([great(i / 4) for i in range(4)]), "chars/great_echo.png")
    save(eyes(), "chars/eyes.png")


# ---------------------------------------------------------------- NPC'ler
def riza():
    img = new(20, 38)
    rect(img, 6, 12, 14, 30, "n2")             # muşamba
    rect(img, 6, 30, 13, 37, "pants")
    rect(img, 7, 4, 12, 11, "skin2")
    rect(img, 7, 8, 12, 11, "n4")              # gür sakal
    rect(img, 5, 2, 14, 5, "n1")               # bere
    px(img, 11, 6, "k")
    line(img, 13, 9, 17, 8, "wood2")           # pipo
    px(img, 17, 7, "w2")
    line(img, 14, 14, 17, 22, "n2", 2)
    outline(img)
    return img


def yusuf_lying():
    img = new(64, 18)
    rect(img, 6, 9, 40, 15, "n3")              # kazak
    rect(img, 40, 10, 52, 15, "pants")
    rect(img, 0, 8, 7, 15, "skin2")            # kafa
    rect(img, 0, 6, 6, 9, "n1")
    rect(img, 1, 12, 6, 15, "n2")              # sakal
    outline(img)
    # sise dönen kol/bacak
    for y in range(0, 18):
        for x in range(44, 64):
            k = (x - 44) / 20
            if dither(x, y, 0.7 - k * 0.7) and 6 + math.sin(x * 0.6) * 3 < y < 16:
                px(img, x, y, "f1", 170)
    return img


def npc_sheets():
    save(riza(), "chars/riza.png")
    save(yusuf_lying(), "chars/yusuf_lying.png")


if __name__ == "__main__":
    kerem_sheet()
    echo_sheets()
    npc_sheets()
