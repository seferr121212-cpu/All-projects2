"""Steam mağaza görselleri: python3 tools/store/make_store.py
Çıktı: store/ (Godot içe aktarmaz, .gdignore var)."""
import os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "store")
os.makedirs(OUT, exist_ok=True)
open(os.path.join(OUT, ".gdignore"), "w").close()
FONT = os.path.join(ROOT, "fonts", "Lora.ttf")

def art(p):
    return Image.open(os.path.join(ROOT, "art", p)).convert("RGBA")

def cover(img, w, h, focus=(0.5, 0.5)):
    """Pixel art'ı tam sayı katıyla büyütüp (nearest) kırp."""
    s = max(w / img.width, h / img.height)
    k = max(1, int(s + 0.999))
    big = img.resize((img.width * k, img.height * k), Image.NEAREST)
    x = int((big.width - w) * focus[0]); y = int((big.height - h) * focus[1])
    return big.crop((x, y, x + w, y + h))

def logo(w):
    lg = art("ui/logo.png")
    k = max(1, w // lg.width)
    return lg.resize((lg.width * k, lg.height * k), Image.NEAREST)

def vignette(img, strength=0.65):
    w, h = img.size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((-w * 0.25, -h * 0.35, w * 1.25, h * 1.35), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(min(w, h) * 0.18))
    dark = Image.new("RGBA", (w, h), (4, 5, 9, int(255 * strength)))
    dark.putalpha(Image.eval(m, lambda v: int((255 - v) * strength)))
    return Image.alpha_composite(img, dark)

def capsule(name, w, h, bg="story/end_a.png", focus=(0.5, 0.5), logo_w=None, pos="center", sub=None):
    img = vignette(cover(art(bg), w, h, focus))
    if logo_w:
        lg = logo(logo_w)
        if pos == "center":
            xy = ((w - lg.width) // 2, (h - lg.height) // 2)
        elif pos == "bottom":
            xy = ((w - lg.width) // 2, h - lg.height - h // 10)
        else:
            xy = (w // 20, (h - lg.height) // 2)
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sh.paste((0, 0, 0, 180), (xy[0] + 4, xy[1] + 4), lg)
        img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(6)))
        img.alpha_composite(lg, xy)
    if sub:
        d = ImageDraw.Draw(img)
        f = ImageFont.truetype(FONT, max(14, h // 22))
        tw = d.textlength(sub, font=f)
        d.text(((w - tw) / 2, h - h // 12 - f.size), sub, font=f, fill=(230, 200, 160, 230))
    img.convert("RGB").save(os.path.join(OUT, name))
    print("store/" + name, img.size)

capsule("header_460x215.png", 460, 215, "story/ch3.png", (0.5, 0.4), 300)
capsule("small_231x87.png", 231, 87, "story/ch3.png", (0.5, 0.4), 200)
capsule("main_616x353.png", 616, 353, "story/end_a.png", (0.5, 0.5), 600, "bottom", "Kırlangıç Adası, 1977")
capsule("library_hero_3840x1240.png", 3840, 1240, "story/intro_1.png", (0.5, 0.45))
capsule("library_600x900.png", 600, 900, "story/ch1.png", (0.35, 0.5), 600, "bottom", "Fog Bell")
capsule("page_bg_1438x810.png", 1438, 810, "story/intro_3.png", (0.5, 0.5))
# logo (saydam)
logo(1200).save(os.path.join(OUT, "logo_transparent.png")); print("store/logo_transparent.png")
# ekran görüntüleri (önizleme çizicisinden)
for key in ["c1_village", "c2_cave"]:
    out = os.path.join(OUT, "screenshot_%s.png" % key)
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "preview", "render.py"), key, out], capture_output=True, text=True)
    if r.returncode == 0 and os.path.exists(out):
        im = Image.open(out)
        if im.size != (1920, 1080):
            im = im.resize((1920, 1080), Image.NEAREST); im.save(out)
        print("store/" + os.path.basename(out), im.size)
    else:
        print("önizleme atlandı:", key, r.stderr[-200:])
