#!/usr/bin/env python3
"""Top-down PNG of a grey-box location (walls, boxes, spawns, points, actors)
for layout review without the engine.  python3 tools/render_map.py factory_floor"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import validate_data as vd  # noqa: E402

PX = 40


def render(lid: str, out: Path) -> None:
    loc = json.loads((ROOT / f"data/locations/{lid}.json").read_text(encoding="utf-8"))
    sx, _, sz = loc["size"]
    im = Image.new("RGB", (int(sx * PX), int(sz * PX)), (20, 22, 25))
    d = ImageDraw.Draw(im)
    blocked, nx, nz, _, _ = vd.walk_grid(loc)
    c = vd.CELL * PX
    for i in range(nx):
        for j in range(nz):
            if blocked[i][j]:
                d.rectangle([i * c, j * c, (i + 1) * c, (j + 1) * c], fill=(45, 30, 30))

    def xy(p):
        return ((p[0] + sx / 2) * PX, (p[2] + sz / 2) * PX)
    for b in loc.get("boxes", []):
        bx, _, bz = b["size"]
        x, y = xy(b["pos"])
        col = b.get("color", "#888888").lstrip("#")
        rgb = tuple(int(col[k:k + 2], 16) for k in (0, 2, 4))
        d.rectangle([x - bx * PX / 2, y - bz * PX / 2, x + bx * PX / 2, y + bz * PX / 2],
                    fill=rgb, outline=(200, 200, 200) if b.get("collide", True) else None)
    for pid, pt in loc.get("points", {}).items():
        x, y = xy(pt["pos"])
        r = pt.get("radius", 1.4) * PX
        d.ellipse([x - r, y - r, x + r, y + r], outline=(245, 168, 56), width=2)
        d.text((x + 6, y - 6), pid.replace("ch01_", ""), fill=(245, 168, 56))
    for a in loc.get("actors", []):
        x, y = xy(a["pos"])
        d.ellipse([x - 10, y - 10, x + 10, y + 10], fill=(200, 160, 230))
        d.text((x + 12, y - 6), a["id"], fill=(220, 200, 240))
    for sid, sp in loc.get("spawns", {}).items():
        x, y = xy(sp["pos"])
        d.ellipse([x - 9, y - 9, x + 9, y + 9], fill=(90, 210, 110))
        d.text((x + 12, y + 4), "spawn:" + sid, fill=(140, 230, 150))
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)


if __name__ == "__main__":
    for lid in sys.argv[1:] or [p.stem for p in (ROOT / "data/locations").glob("*.json")]:
        render(lid, ROOT / "docs" / "maps" / f"{lid}.png")
        print("docs/maps/%s.png" % lid)
