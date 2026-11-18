# -*- coding: utf-8 -*-
"""Godot olmadan oyun karesinin önizlemesi: aynı sprite'lar, normal haritaları, nokta ışıklar,
ay ışığı, gölge hacimleri, karanlık+sis katmanı, additive parıltı ve son işleme.
Kullanım: python3 tools/preview/render.py c1_village out.png"""
import math, os, sys, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "art")
OUT_W, OUT_H = 1280, 720
ZOOM = 1.75
VIEW_W, VIEW_H = OUT_W / ZOOM / (1280 / 1920), OUT_H / ZOOM / (720 / 1080)  # dünya pikseli (1920 tabanlı)
S = OUT_W / 1920.0 * ZOOM  # dünya pikseli -> çıktı pikseli


def load(p):
    return Image.open(os.path.join(ART, p)).convert("RGBA")


class Scene:
    def __init__(self, cam_x, cam_y):
        self.cx, self.cy = cam_x, cam_y          # ekran ortasının dünya konumu
        self.alb = Image.new("RGBA", (OUT_W, OUT_H), (0, 0, 0, 0))
        self.nrm = Image.new("RGBA", (OUT_W, OUT_H), (128, 128, 255, 0))
        self.unlit = Image.new("RGBA", (OUT_W, OUT_H), (0, 0, 0, 0))   # parlayan şeyler (göz, alev)
        self.occ = []
        self.lights = []

    def w2s(self, x, y):
        return ((x - self.cx) * S + OUT_W / 2, (y - self.cy) * S + OUT_H / 2)

    def _scaled(self, img, art_scale=2.0, flip=False, tint=None):
        f = art_scale * S
        im = img.resize((max(1, round(img.width * f)), max(1, round(img.height * f))), Image.NEAREST)
        if flip:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        if tint:
            a = np.asarray(im).astype(np.float32)
            a[..., :3] *= np.array(tint[:3], dtype=np.float32)
            a[..., 3] *= tint[3] if len(tint) > 3 else 1
            im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
        return im

    def sprite(self, path, x, y, anchor="bottom", flip=False, crop=None, tint=None, unlit=False, art_scale=2.0):
        img = load(path)
        npath = path[:-4] + "_n.png"
        nimg = load(npath) if os.path.exists(os.path.join(ART, npath)) else None
        if crop:
            img = img.crop(crop)
            if nimg:
                nimg = nimg.crop(crop)
        im = self._scaled(img, art_scale, flip, tint)
        sx, sy = self.w2s(x, y)
        if anchor == "bottom":
            px, py = round(sx - im.width / 2), round(sy - im.height)
        elif anchor == "top":
            px, py = round(sx - im.width / 2), round(sy)
        else:
            px, py = round(sx - im.width / 2), round(sy - im.height / 2)
        if unlit:
            self.unlit.alpha_composite(im, (px, py))
            return
        self.alb.alpha_composite(im, (px, py))
        if nimg:
            n = self._scaled(nimg, art_scale, flip)
            if flip:
                na = np.asarray(n).copy()
                na[..., 0] = 255 - na[..., 0]
                n = Image.fromarray(na, "RGBA")
            n.putalpha(im.getchannel("A"))
            self.nrm.alpha_composite(n, (px, py))

    def tiled(self, path, x, y, w, h, tint=None, occluder=True, top=None, shade=True):
        img = load(path)
        nimg = load(path[:-4] + "_n.png") if os.path.exists(os.path.join(ART, path[:-4] + "_n.png")) else None
        t = self._scaled(img, 2.0, False, tint)
        tn = self._scaled(nimg, 2.0) if nimg else None
        sx, sy = self.w2s(x, y)
        ex, ey = self.w2s(x + w, y + h)
        sx, sy, ex, ey = round(sx), round(sy), round(ex), round(ey)
        W, H = ex - sx, ey - sy
        if W <= 0 or H <= 0:
            return
        tile = Image.new("RGBA", (W, H))
        ntile = Image.new("RGBA", (W, H))
        ox = int((x * S) % t.width)
        oy = int((y * S) % t.height)
        for yy in range(-oy, H, t.height):
            for xx in range(-ox, W, t.width):
                tile.alpha_composite(t, (xx, yy)) if xx >= 0 and yy >= 0 else tile.paste(t, (xx, yy), t)
                if tn:
                    ntile.paste(tn, (xx, yy))
        if shade and h > 90:
            a = np.asarray(tile).astype(np.float32)
            ys = np.arange(H)[:, None] / S
            k = np.clip((ys - 14) / 206.0, 0, 1) * 0.85
            a[..., :3] *= (1 - k)[..., None]
            tile = Image.fromarray(a.astype(np.uint8), "RGBA")
        self.alb.alpha_composite(tile, (sx, sy))
        if tn:
            ntile.putalpha(255)
            self.nrm.paste(ntile, (sx, sy))
        if top:
            self.tiled(top, x, y - 12, w, 20, occluder=False, shade=False)
        if occluder:
            self.occ.append((x, y, w, h))

    def rect(self, x, y, w, h, color):
        sx, sy = self.w2s(x, y)
        ex, ey = self.w2s(x + w, y + h)
        d = ImageDraw.Draw(self.alb)
        d.rectangle([sx, sy, ex, ey], fill=color)

    def poly(self, pts, color, tex=None):
        sp = [self.w2s(*p) for p in pts]
        if tex:
            t = self._scaled(load(tex), 2.0)
            xs = [p[0] for p in sp]; ys = [p[1] for p in sp]
            x0, y0, x1, y1 = int(min(xs)), int(min(ys)), int(max(xs)) + 1, int(max(ys)) + 1
            fill = Image.new("RGBA", (x1 - x0, y1 - y0))
            for yy in range(0, fill.height, t.height):
                for xx in range(0, fill.width, t.width):
                    fill.paste(t, (xx, yy))
            mask = Image.new("L", fill.size, 0)
            ImageDraw.Draw(mask).polygon([(p[0] - x0, p[1] - y0) for p in sp], fill=255)
            fill.putalpha(mask)
            self.alb.alpha_composite(fill, (x0, y0))
        else:
            ImageDraw.Draw(self.alb).polygon(sp, fill=color)

    def light(self, x, y, radius, color, energy=1.0, height=60.0, shadows=True):
        self.lights.append((x, y, radius, color, energy, height, shadows))

    # ------------------------------------------------------------- lighting
    def shadow_mask(self, lx, ly):
        m = Image.new("L", (OUT_W, OUT_H), 255)
        d = ImageDraw.Draw(m)
        for (x, y, w, h) in self.occ:
            corners = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
            for i in range(4):
                a, b = corners[i], corners[(i + 1) % 4]
                far = []
                for p in (b, a):
                    vx, vy = p[0] - lx, p[1] - ly
                    l = math.hypot(vx, vy) + 1e-6
                    far.append((p[0] + vx / l * 6000, p[1] + vy / l * 6000))
                quad = [self.w2s(*a), self.w2s(*b), self.w2s(*far[0]), self.w2s(*far[1])]
                d.polygon(quad, fill=0)
        # occluder içi aydınlık kalsın (Godot davranışı)
        for (x, y, w, h) in self.occ:
            d.rectangle([*self.w2s(x, y), *self.w2s(x + w, y + h)], fill=255)
        m = m.filter(ImageFilter.GaussianBlur(3))
        return np.asarray(m).astype(np.float32) / 255.0

    def render(self, bg_layers, ambient, moon=None, dark=0.26, fog=0.2, glow=True):
        H, W = OUT_H, OUT_W
        alb = np.asarray(self.alb).astype(np.float32) / 255.0
        nrm = np.asarray(self.nrm).astype(np.float32) / 255.0
        N = np.stack([nrm[..., 0] * 2 - 1, -(nrm[..., 1] * 2 - 1), nrm[..., 2] * 2 - 1], -1)
        N /= np.linalg.norm(N, axis=-1, keepdims=True) + 1e-6
        light = np.ones((H, W, 3), np.float32) * np.array(ambient, np.float32)
        if moon:
            mdir = np.array(moon[0], np.float32)
            mdir /= np.linalg.norm(mdir)
            ndl = np.clip((N * mdir).sum(-1), 0, 1)
            light += ndl[..., None] * np.array(moon[1], np.float32) * moon[2]
        ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)
        lit_amount = np.zeros((H, W), np.float32)
        for (lx, ly, r, col, en, hgt, sh) in self.lights:
            sx, sy = self.w2s(lx, ly)
            rr = r * S
            dx, dy = xs - sx, ys - sy
            dist = np.sqrt(dx * dx + dy * dy) / rr
            att = np.interp(dist, [0, 0.35, 1.0], [1.0, 0.75, 0.0])
            L = np.stack([-dx, dy, np.full_like(dx, hgt * S)], -1)
            L /= np.linalg.norm(L, axis=-1, keepdims=True) + 1e-6
            ndl = np.clip((N * L).sum(-1), 0, 1) * 0.75 + 0.25
            a = att * ndl * en
            if sh:
                a *= self.shadow_mask(lx, ly)
            light += a[..., None] * np.array(col, np.float32)
            lit_amount = np.maximum(lit_amount, att)
        world = alb[..., :3] * light
        world_a = alb[..., 3:4]
        # arka plan
        bg = Image.new("RGBA", (W, H), (0, 0, 0, 255))
        for (path, par) in bg_layers:
            im = load(path)
            im = im.resize((round(im.width * 2 * W / 1920), round(im.height * 2 * H / 1080)), Image.NEAREST)
            off = int(self.cx * par * W / 1920) % im.width
            for xx in range(-off, W, im.width):
                bg.alpha_composite(im, (xx, 0)) if xx >= 0 else bg.paste(im, (xx, 0), im)
        bgf = np.asarray(bg).astype(np.float32)[..., :3] / 255.0
        img = bgf * (1 - world_a) + np.clip(world, 0, 1.5) * world_a
        # karanlık + sis katmanı
        rng = np.random.default_rng(3)
        fogn = np.asarray(Image.fromarray((rng.random((H // 30 + 2, W // 120 + 2)) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(np.float32) / 255
        sy = ys / H
        band = np.clip((sy - 0.35) / 0.4, 0, 1) * (1 - np.clip((sy - 0.92) / 0.08, 0, 1)) + 0.25
        fogv = np.clip((fogn - 0.4) * 2.2, 0, 1) * fog * band * 1.3 * (1 - lit_amount * 0.75)
        da = dark * (1 - lit_amount)
        img = img * (1 - da[..., None]) + np.array([0.01, 0.012, 0.02]) * da[..., None]
        img = img * (1 - fogv[..., None]) + np.array([0.52, 0.57, 0.64]) * fogv[..., None]
        # parlayanlar (gözler, alev) + additive parıltı
        un = np.asarray(self.unlit).astype(np.float32) / 255.0
        img = img * (1 - un[..., 3:4]) + un[..., :3] * un[..., 3:4]
        if glow:
            for (lx, ly, r, col, en, hgt, sh) in self.lights:
                sx, sy = self.w2s(lx, ly)
                d = np.sqrt((xs - sx) ** 2 + (ys - sy) ** 2) / (r * S * 0.9)
                g = np.clip(1 - d, 0, 1) ** 2.2 * 0.22 * min(en, 1.2)
                img += g[..., None] * np.array([1.0, 0.62, 0.3]) * np.array(col)
        # son işleme
        img = np.clip(img, 0, 4)
        pim = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
        blur = np.asarray(pim.filter(ImageFilter.GaussianBlur(14))).astype(np.float32) / 255.0
        img = img + np.clip(blur - 0.35, 0, 1) * 1.8 * 0.55
        l = (img * np.array([0.299, 0.587, 0.114])).sum(-1, keepdims=True)
        img = l + (img - l) * 0.88
        img = (img - 0.5) * 1.1 + 0.5
        t = np.clip((l - 0.08) / 0.52, 0, 1)
        img *= np.array([0.86, 0.93, 1.1]) * (1 - t) + np.array([1.1, 1.0, 0.88]) * t
        u = (xs / W - 0.5) * 1.3
        v = ys / H - 0.5
        img *= np.clip(1 - (u * u + v * v) * 0.55 * 2.2, 0, 1)[..., None]
        img += (rng.random((H, W, 1)) - 0.5) * 0.045
        return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


def kerem(sc, x, y, frame=(48, 40, 72, 80), lamp=True, raised=False, aim=(1, 0), facing=1):
    sc.sprite("chars/kerem.png", x, y, crop=frame, flip=facing < 0)
    if lamp:
        lx, ly = x + 11 * facing, y - 23
        sc.sprite("props/lamp_held.png", lx, ly, anchor="center", flip=facing < 0)
        sc.sprite("props/lamp_flame.png", lx, ly + 1, anchor="center", crop=(0, 0, 5, 6), unlit=True)
        sc.light(lx, ly, 220 * 1.35, (1.0, 0.78, 0.5), 1.25, 80)
        return lx, ly


def echo(sc, path, fw, fh, x, y, eye, frame=1, flip=False):
    sc.sprite(path, x, y, crop=(fw * frame, 0, fw * (frame + 1), fh), flip=flip)
    sc.sprite("chars/eyes.png", x + (eye[0] * (-1 if flip else 1)), y + eye[1], anchor="center", unlit=True)


def scene_village():
    UP = -150
    sc = Scene(4300, UP - 90 - 30)
    # evler (duvar + çatı + pencere)
    def house(x, g, w, h, roof, lit, stone=True):
        path = "houses/house_%dx%d_%d_%d%d%d.png" % (w, h, roof, 1, int(lit), int(stone))
        im = load(path)
        sc.sprite(path, x - 16 + im.width, g, anchor="bottom")
        if lit:
            n = max(1, int(w / 140))
            for i in range(n):
                sc.light(x + w * (i + 0.5) / n, g - h + h * 0.25 + 26, 150 * 1.2, (1.0, 0.72, 0.42), 0.6 + 0.29 * 0.9, 60, False)
    house(3350, UP, 260, 200, 70, False, True)
    house(3700, UP, 200, 170, 60, True, False)
    house(4620, UP, 1080, 280, 70, True, True)
    sc.sprite("decor/dead_tree.png", 3500, UP, tint=(0.75, 0.75, 0.8))
    sc.tiled("tiles/cobble.png", 3200, UP, 700, 900, top="tiles/top_stone.png")
    sc.tiled("tiles/planks.png", 3900, UP, 100, 16, tint=(0.85, 0.75, 0.7))
    sc.tiled("tiles/planks.png", 4000, UP, 100, 16, tint=(0.85, 0.75, 0.7))
    sc.tiled("tiles/cobble.png", 4100, UP, 1500, 900, top="tiles/top_stone.png")
    sc.sprite("decor/lamppost.png", 3560, UP)
    sc.sprite("decor/fence_broken.png", 3820, UP)
    sc.sprite("decor/bush.png", 4200, UP, tint=(0.8, 0.85, 0.9))
    sc.sprite("decor/fence.png", 4460, UP)
    sc.sprite("decor/barrel.png", 4720, UP)
    sc.sprite("decor/crates.png", 3700, UP)
    for x in (3260, 3420, 3610, 4160, 4330, 4540, 4900):
        sc.sprite("decor/tuft_%s.png" % "abc"[x % 3], x, UP + 2, tint=(0.75, 0.78, 0.85))
    sc.sprite("decor/rock_a.png", 3980 + 120, UP + 2)
    # kandil
    sc.sprite("props/brazier.png", 4800, UP)
    sc.sprite("props/flame.png", 4800, UP - 52, crop=(16, 0, 32, 22), unlit=True)
    sc.light(4800, UP - 70, 290 * 1.3, (1.0, 0.66, 0.36), 1.25, 60)
    # Kerem + Yankılar
    kerem(sc, 4280, UP, frame=(24 * 2, 40, 24 * 3, 80))
    echo(sc, "chars/echo_crawler.png", 36, 18, 3720 + 200, UP, (14, -24), 2, True)
    echo(sc, "chars/echo_mimic.png", 20, 44, 3600, UP, (3, -76), 1)
    # su birikintileri (ışık yansımalı), ayak gölgesi, baca dumanı, güveler
    for px_ in (4060, 4560, 4900):
        sc.sprite("decor/puddle.png", px_, UP + 4, anchor="center")
        refl = load("fx/glow.png").resize((round(60 * S), round(8 * S)))
        a = np.asarray(refl).astype(np.float32)
        a[..., 0] *= 1.0; a[..., 1] *= 0.7; a[..., 2] *= 0.4
        a[..., 3] *= 0.9 if px_ != 4060 else 0.4
        sx, sy = sc.w2s(px_, UP + 4)
        sc.unlit.alpha_composite(Image.fromarray(a.astype(np.uint8), "RGBA"), (round(sx - a.shape[1] / 2), round(sy - a.shape[0] / 2)))
    sc.sprite("fx/blob.png", 4280, UP, anchor="center", tint=(1, 1, 1, 1))
    rng_ = random.Random(4)
    for i in range(14):
        k = i / 13
        sc.sprite("fx/mote.png", 4620 - 16 + (8 + 540 * 0.75) * 2 + 6 - k * 50 + rng_.uniform(-6, 6), UP - 280 - 35 - 70 - k * 120, anchor="center",
                  tint=(0.6, 0.62, 0.7, 0.35 * (1 - k)), art_scale=2 + k * 4)
    for (mx, my) in ((4300, UP - 40), (4282, UP - 14), (4305, UP - 8)):
        sc.sprite("fx/moth.png", mx, my, anchor="center", crop=(0, 0, 7, 5), unlit=True, tint=(0.8, 0.75, 0.65, 1))
    # ön plan otları
    for x in (3950, 4380, 4640):
        sc.sprite("decor/tuft_c.png", x, UP + 8, tint=(0.4, 0.42, 0.5))
    img = sc.render([("bg/c1_sky.png", 0.02), ("bg/c1_sea.png", 0.06), ("bg/c1_village.png", 0.18), ("bg/c1_fog.png", 0.35), ("bg/c1_reeds.png", 0.55)],
                    ambient=(0.4, 0.45, 0.6), moon=((0.35, 0.94, 0.6), (0.55, 0.65, 0.9), 0.35), dark=0.26, fog=0.22)
    fg = load("fg/c1_front.png").resize((OUT_W, OUT_H), Image.NEAREST)
    out = img.convert("RGBA")
    fa = np.asarray(fg).astype(np.float32)
    fa[..., :3] *= 0.15
    out.alpha_composite(Image.fromarray(fa.astype(np.uint8), "RGBA"))
    return out.convert("RGB")


def scene_cave():
    sc = Scene(2400, -150)
    sc.tiled("tiles/rock.png", 1400, -1000, 1800, 300, occluder=True, shade=False)
    sc.tiled("tiles/rock.png", 1400, 0, 1800, 900, top="tiles/top_moss.png")
    sc.tiled("tiles/stone_wall.png", 3100, -360, 300, 40, top="tiles/top_stone.png")
    for x in (1560, 1990, 2420, 2850):
        sc.sprite("decor/roots.png", x, -700, anchor="top")
    sc.sprite("decor/stalagmite_a.png", 1720, 0, tint=(0.7, 0.72, 0.8))
    sc.sprite("decor/stalagmite_b.png", 2660, 0, tint=(0.7, 0.72, 0.8))
    for x in (1650, 1900, 2350, 2580):
        sc.sprite("decor/tuft_cave.png", x, 2)
    sc.sprite("decor/mushrooms.png", 2480, 2)
    # aynalar + huzme
    sc.sprite("props/mirror_stand.png", 2200, 0)
    d = ImageDraw.Draw(sc.alb)
    def seg(a, b, col, w):
        d.line([sc.w2s(*a), sc.w2s(*b)], fill=col, width=w)
    seg((2158, -18), (2242, -102), (40, 32, 26, 255), 11)
    seg((2158, -18), (2242, -102), (190, 215, 235, 255), 7)
    seg((2200, -700), (2200, -440), (60, 60, 64, 255), 3)
    seg((2158, -358), (2242, -442), (40, 32, 26, 255), 11)
    seg((2158, -358), (2242, -442), (190, 215, 235, 255), 7)
    sc.sprite("props/brazier.png", 3250, -360)
    sc.sprite("props/flame.png", 3250, -412, crop=(32, 0, 48, 22), unlit=True)
    sc.light(3250, -430, 290 * 1.3, (1.0, 0.66, 0.36), 1.25, 60)
    lx, ly = kerem(sc, 2090, 0, frame=(0, 0, 24, 40))
    # huzme (additive)
    beam = Image.new("RGBA", (OUT_W, OUT_H))
    bd = ImageDraw.Draw(beam)
    pts = [(lx, ly), (2177, ly), (2177, -381), (3250, -381)]
    for i in range(3):
        bd.line([sc.w2s(*pts[i]), sc.w2s(*pts[i + 1])], fill=(255, 210, 140, 200), width=5)
    sc.unlit.alpha_composite(beam.filter(ImageFilter.GaussianBlur(1.5)))
    for i in range(3):
        a, b = pts[i], pts[i + 1]
        for k in range(6):
            t = k / 5
            sc.light(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, 120, (1.0, 0.8, 0.55), 0.35, 30, False)
    echo(sc, "chars/echo_watcher.png", 28, 36, 2780, -240, (2, -54), 2, True)
    img = sc.render([("bg/c2_back.png", 0.1), ("bg/c2_mid.png", 0.3), ("bg/c2_fog.png", 0.5)],
                    ambient=(0.34, 0.37, 0.48), moon=None, dark=0.3, fog=0.14)
    fg = load("fg/c2_front.png").resize((OUT_W, OUT_H), Image.NEAREST)
    out = img.convert("RGBA")
    fa = np.asarray(fg).astype(np.float32)
    fa[..., :3] *= 0.15
    out.alpha_composite(Image.fromarray(fa.astype(np.uint8), "RGBA"))
    return out.convert("RGB")


def scene_boiler():
    sc = Scene(5850, -200)
    sc.tiled("tiles/brick.png", 5200, -1200, 1300, 680, occluder=True, shade=False)
    sc.tiled("tiles/brick.png", 5200, -520, 1300, 520, tint=(0.34, 0.36, 0.42), occluder=False, shade=False)
    sc.tiled("tiles/planks.png", 5200, 0, 1300, 900, top="tiles/top_plank.png")
    sc.sprite("decor/chain.png", 5600, -520, anchor="top")
    sc.sprite("decor/lantern_hang.png", 6000, -520, anchor="top")
    sc.sprite("decor/barrel.png", 5560, 0)
    sc.sprite("decor/crates.png", 6260, 0)
    sc.sprite("props/boiler.png", 5800, 0)
    sc.sprite("props/valve.png", 6120, 0)
    sc.tiled("tiles/stone_wall.png", 6380, -520, 40, 520)
    sc.sprite("props/brazier.png", 5400, 0)
    sc.sprite("props/flame.png", 5400, -52, crop=(32, 0, 48, 22), unlit=True)
    sc.light(5400, -70, 290 * 1.3, (1.0, 0.66, 0.36), 1.2, 60)
    sc.light(5800, -40, 230 * 1.2, (1.0, 0.6, 0.3), 1.0, 30)
    kerem(sc, 5950, 0, frame=(0, 0, 24, 40))
    echo(sc, "chars/echo_crawler.png", 30, 14, 6280, 0, (8, -10), 1, True)
    img = sc.render([("bg/c3_sky.png", 0.02), ("bg/c3_sea.png", 0.05), ("bg/c5_factory.png", 0.12)],
                    ambient=(0.36, 0.4, 0.52), moon=None, dark=0.3, fog=0.16)
    return img.convert("RGB")


def scene_breakwater():
    sc = Scene(7350, -230)
    for a, b in [(6420, 7050), (7170, 7650), (7770, 8150)]:
        sc.tiled("tiles/stone_wall.png", a, 0, b - a, 140, top="tiles/top_stone.png")
    sc.rect(6420, 40, 2000, 700, (22, 32, 46, 230))
    sc.sprite("props/brazier.png", 7420, 0)
    sc.sprite("props/flame.png", 7420, -52, crop=(32, 0, 48, 22), unlit=True)
    sc.light(7420, -70, 290 * 1.3, (1.0, 0.66, 0.36), 1.2, 60)
    kerem(sc, 7250, 0, frame=(48, 40, 72, 80))
    echo(sc, "chars/echo_whisper.png", 24, 30, 7850, -170, (6, -20), 1, True)
    img = sc.render([("bg/c3_sky.png", 0.02), ("bg/c3_sea.png", 0.05), ("bg/c5_factory.png", 0.12), ("bg/c3_fog.png", 0.3)],
                    ambient=(0.36, 0.4, 0.52), moon=None, dark=0.3, fog=0.18)
    return img.convert("RGB")


if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "c1_village"
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp/preview_%s.png" % name
    img = {"c1_village": scene_village, "c2_cave": scene_cave, "c5_boiler": scene_boiler, "c5_breakwater": scene_breakwater}[name]()
    img.save(out)
    print(out)
