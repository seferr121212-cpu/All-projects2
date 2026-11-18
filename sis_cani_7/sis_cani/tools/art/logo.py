# -*- coding: utf-8 -*-
"""SİS ÇANI başlık logosu (art/ui/logo.png, 300x80 pixel art).
Ay ışığından lamba ışığına geçen harfler, koyu çerçeve + gölge, harflerin arasından geçen sis,
ışıldayan bronz çan ve süslü alt çizgi."""
import math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from common import *

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 300, 80


def _font(size):
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/google-fonts/Lora-Variable.ttf", size)
        f.set_variation_by_name("Bold")
        return f
    except Exception:
        return ImageFont.truetype(os.path.join(ROOT, "fonts", "Lora.ttf"), size)


def _text_mask(text, size, tracking):
    f = _font(size)
    m = Image.new("L", (W * 2, H), 0)
    d = ImageDraw.Draw(m)
    x = 0
    for ch in text:
        d.text((x, 4), ch, font=f, fill=255)
        x += f.getlength(ch) + (tracking if ch != " " else tracking * 0.4)
    m = m.point(lambda v: 255 if v > 120 else 0)
    return m.crop(m.getbbox())


def _bell():
    b = new(34, 40)
    # taç ve askı
    rect(b, 15, 0, 18, 2, "iron2")
    rect(b, 13, 3, 20, 5, "iron")
    # gövde: aşağı doğru genişleyen çan profili
    for y in range(6, 31):
        if y < 11:                                     # yuvarlak omuz
            hw = 4.0 + 4.0 * math.sqrt(max(0.0, 1 - ((11 - y) / 5.0) ** 2))
        elif y < 24:                                   # bel
            hw = 8.0 + (y - 11) * 0.12
        else:                                          # açılan ağız
            hw = 9.6 + ((y - 24) / 6.0) ** 1.8 * 6.4
        hw = min(hw, 16.0)
        for x in range(int(round(17 - hw)), int(round(17 + hw)) + 1):
            s = (x - (17 - hw)) / (2 * hw)             # ışık soldan (lamba)
            c = ramp(["brass", "w3", "brass", "brass", "brass2", "wood2"], s, x, y)
            if 0.12 < s < 0.22 and 8 < y < 29:
                c = "w2"                               # dikey parlama şeridi
            px(b, x, y, c)
    # dudak (alt halka) ve süs bantları
    for x in range(1, 33):
        px(b, x, 31, "brass2"); px(b, x, 32, "wood2")
    for x in range(10, 25):
        px(b, x, 10, "brass2")
    for x in range(5, 30):
        px(b, x, 26, "brass2")
    # dil (tokmak)
    rect(b, 16, 33, 17, 35, "iron")
    rect(b, 15, 36, 18, 38, "iron2")
    outline(b)
    return b


def logo():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = _text_mask("SİS ÇANI", 46, 4)
    tx, ty = 66, (H - mask.height) // 2 - 6
    mw, mh = mask.size

    # 1) sıcak hale (harflerin arkasında, yumuşak, dither'lı)
    halo = Image.new("L", (W, H), 0)
    halo.paste(mask, (tx, ty))
    halo = halo.filter(ImageFilter.GaussianBlur(5))
    for y in range(H):
        for x in range(W):
            a = halo.getpixel((x, y)) / 255.0 * 0.5
            if a > 0.02:
                img.putpixel((x, y), (255, 170, 90, int(a * 110)))

    # 2) gölge (sağ-alt, koyu lacivert)
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh.paste((6, 8, 16, 255), (tx + 2, ty + 3), mask)
    img.alpha_composite(sh)

    # 3) harfler: üstte ay ışığı (soğuk beyaz) → altta lamba ışığı (sıcak amber), dither'lı geçiş
    top_c = [(236, 242, 250), (214, 224, 238), (232, 210, 176), (244, 170, 92), (214, 118, 58)]
    letters = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lp = letters.load()
    for y in range(mh):
        t = y / max(1, mh - 1)
        for x in range(mw):
            if mask.getpixel((x, y)) == 0:
                continue
            f = t * (len(top_c) - 1)
            i = int(f)
            if dither(x + tx, y + ty, f - i) and i < len(top_c) - 1:
                i += 1
            c = top_c[min(i, len(top_c) - 1)]
            lp[x + tx, y + ty] = (c[0], c[1], c[2], 255)
    # üst kenar parlaması (ay ışığı vuruyor)
    for x in range(mw):
        for y in range(mh):
            if mask.getpixel((x, y)):
                if y == 0 or mask.getpixel((x, y - 1)) == 0:
                    lp[x + tx, y + ty] = (255, 255, 255, 255)
    # iç gölge: sağ kenarlar bir ton koyu (hacim)
    for y in range(mh):
        for x in range(mw):
            if mask.getpixel((x, y)) and (x + 1 >= mw or mask.getpixel((x + 1, y)) == 0):
                r, g, b, a = lp[x + tx, y + ty]
                lp[x + tx, y + ty] = (int(r * 0.72), int(g * 0.72), int(b * 0.8), 255)
    outline(letters)
    img.alpha_composite(letters)

    # 4) sis: harflerin alt yarısından geçen kırık, yarı saydam şeritler
    rng = random.Random(9)
    fog = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fp = fog.load()
    for band, (yc, amp, thick, a0) in enumerate([(ty + mh * 0.58, 1.6, 4, 85)]):
        ph = rng.uniform(0, 6)
        for x in range(tx - 20, min(W, tx + mw + 24)):
            y0 = yc + amp * math.sin(x / 11.0 + ph) + 0.8 * math.sin(x / 4.3 + ph * 2)
            # uçlara doğru kırılarak sönen şerit
            edge = min(x - (tx - 20), (tx + mw + 24) - x) / 30.0
            dens = vnoise(x / 9.0, band * 3.0, 4) * min(1.0, edge)
            if dens < 0.35:
                continue
            for k in range(thick):
                yy = int(y0) + k
                if 0 <= yy < H and 0 <= x < W:
                    a = int(a0 * (1 - k / (thick + 0.5)) * min(1.0, (dens - 0.35) * 3))
                    if a > 6:
                        fp[x, yy] = (226, 234, 244, a)
    img.alpha_composite(fog)

    # 5) çan + ışıltı + ses halkaları
    bell = _bell()
    bx, by = 14, (H - bell.height) // 2 - 6
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = glow.load()
    cx, cy = bx + 17, by + 20
    for y in range(max(0, cy - 26), min(H, cy + 26)):
        for x in range(max(0, cx - 26), cx + 26):
            d = math.hypot(x - cx, (y - cy) * 1.1) / 26.0
            if d < 1:
                k = (1 - d) ** 2 * 0.6
                gd[x, y] = (255, 196, 110, int(k * 150))
    img.alpha_composite(glow)
    # ses dalgaları (iki yanda yay)
    for r, a in ((22, 150), (28, 90)):
        for ang in range(-35, 36, 3):
            for side in (-1, 1):
                rad = math.radians(ang)
                x = int(cx + side * r * math.cos(rad))
                y = int(cy + 6 + r * math.sin(rad) * 0.9)
                if 0 <= x < W and 0 <= y < H and abs(ang) < 32:
                    img.putpixel((x, y), (255, 200, 130, a))
    img.alpha_composite(bell, (bx, by))

    # 6) süslü alt çizgi: ortada baklava, uçlara doğru sönen ince çizgi
    ly = ty + mh + 7
    x0, x1 = tx - 2, tx + mw + 2
    mid = (x0 + x1) // 2
    for x in range(x0, x1 + 1):
        d = abs(x - mid) / ((x1 - x0) / 2)
        a = int(255 * (1 - d ** 2.2))
        if a > 20 and (d < 0.75 or dither(x, ly, 1 - d)):
            img.putpixel((x, ly), (240, 150, 70, a))
            if d < 0.5:
                img.putpixel((x, ly + 1), (150, 80, 40, int(a * 0.7)))
    for dx, dy in ((0, -2), (-1, -1), (0, -1), (1, -1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)):
        img.putpixel((mid + dx, ly + dy), (255, 214, 150, 255) if (dx, dy) != (0, 0) else (255, 250, 230, 255))
    for side in (-1, 1):
        sx = mid + side * 10
        img.putpixel((sx, ly), (255, 214, 150, 255))
        img.putpixel((sx + side, ly), (255, 214, 150, 255))
    return img


def generate():
    save(logo(), "ui/logo.png")


if __name__ == "__main__":
    generate()
