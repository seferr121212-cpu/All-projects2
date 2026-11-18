# -*- coding: utf-8 -*-
"""Her sprite/doku için normal haritası (<ad>_n.png) üretir. Godot 2D ışıkları bunları kullanır.
Yükseklik = kenardan uzaklık (yuvarlak hacim) + parlaklık (detay). Dokular yatay/dikey döşenebilir."""
import os, glob, math
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "art")
DIRS = ["chars", "props", "decor", "tiles", "houses"]


def dist_inside(alpha, iters=6):
    """opak bölgede kenara yaklaşık uzaklık (0..iters)"""
    a = (alpha > 0.5).astype(np.float32)
    d = a.copy()
    cur = a.copy()
    for _ in range(iters):
        n = np.minimum.reduce([cur, np.roll(cur, 1, 0), np.roll(cur, -1, 0), np.roll(cur, 1, 1), np.roll(cur, -1, 1)])
        # kenarlarda roll sarmasın
        n[0, :] = 0; n[-1, :] = 0; n[:, 0] = 0; n[:, -1] = 0
        n = n * a
        d += n
        cur = n
    return d


def normal_map(img, tile=False, frame_w=None):
    arr = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
    rgb, alpha = arr[..., :3], arr[..., 3]
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    if tile:
        h = lum * 2.0
        # tuğla/tahta derzleri: koyu çizgiler çukur
        h = h + np.where(lum < 0.08, -0.6, 0.0)
        gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
        gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
        strength = 2.5
    else:
        d = dist_inside(alpha)
        if frame_w:
            # kareler arası sınırda kesinti olmasın diye kareleri ayrı ayrı işlemek gerekmez:
            # alpha boşlukları zaten kareleri ayırıyor
            pass
        hgt = np.sqrt(np.clip(d / 6.0, 0, 1)) * 2.0 + lum * 0.8
        hp = np.pad(hgt, 1, mode="edge")
        gx = (hp[1:-1, 2:] - hp[1:-1, :-2]) * 0.5
        gy = (hp[2:, 1:-1] - hp[:-2, 1:-1]) * 0.5
        strength = 1.6
    nx = -gx * strength
    ny = -gy * strength
    nz = np.ones_like(nx)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / ln, ny / ln, nz / ln
    out = np.zeros(arr.shape, dtype=np.uint8)
    out[..., 0] = ((nx * 0.5 + 0.5) * 255).astype(np.uint8)
    # Godot 2D: yeşil kanal yukarı (+Y aşağı ekran koordinatında olduğu için ters)
    out[..., 1] = ((-ny * 0.5 + 0.5) * 255).astype(np.uint8)
    out[..., 2] = ((nz * 0.5 + 0.5) * 255).astype(np.uint8)
    out[..., 3] = 255
    return Image.fromarray(out, "RGBA")


def generate():
    n = 0
    for d in DIRS:
        for path in glob.glob(os.path.join(ART, d, "*.png")):
            if path.endswith("_n.png"):
                continue
            img = Image.open(path)
            nm = normal_map(img, tile=(d == "tiles"))
            nm.save(path[:-4] + "_n.png")
            n += 1
    print("normal haritaları:", n)


if __name__ == "__main__":
    generate()
