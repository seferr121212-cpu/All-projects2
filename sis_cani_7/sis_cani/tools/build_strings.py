# -*- coding: utf-8 -*-
"""strings_source.py -> localization/*.csv + scripts/data/strings_db.gd"""
import csv, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from strings_source import DIALOGUE, UI

keys = set()
for row in DIALOGUE:
    assert row[0] not in keys, "duplicate " + row[0]
    keys.add(row[0])
for row in UI:
    assert row[0] not in keys, "duplicate " + row[0]
    keys.add(row[0])

os.makedirs(os.path.join(ROOT, "localization"), exist_ok=True)
with open(os.path.join(ROOT, "localization", "dialogue.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["keys", "speaker", "filter", "tr", "en"])
    for r in DIALOGUE:
        w.writerow(r)
with open(os.path.join(ROOT, "localization", "ui.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["keys", "tr", "en"])
    for r in UI:
        w.writerow(r)

def s(x):
    return json.dumps(x, ensure_ascii=False)

lines = ["# OTOMATİK ÜRETİLDİ - elle düzenleme. Kaynak: tools/strings_source.py",
         "# AUTO-GENERATED - do not edit. Source: tools/strings_source.py",
         "class_name StringsDB", "extends RefCounted", "",
         "# key -> [speaker, filter, tr, en]", "const LINES := {"]
for k, spk, flt, tr, en in DIALOGUE:
    lines.append("\t%s: [%s, %s, %s, %s]," % (s(k), s(spk), s(flt), s(tr), s(en)))
lines.append("}")
lines.append("")
lines.append("# key -> [tr, en]")
lines.append("const UI := {")
for k, tr, en in UI:
    lines.append("\t%s: [%s, %s]," % (s(k), s(tr), s(en)))
lines.append("}")
with open(os.path.join(ROOT, "scripts", "data", "strings_db.gd"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print("dialogue:", len(DIALOGUE), "ui:", len(UI))
