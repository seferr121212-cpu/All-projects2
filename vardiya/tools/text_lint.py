#!/usr/bin/env python3
"""Text lint for the TR/EN locale files (stage 9): things a proof-reader would flag.

  python3 tools/text_lint.py            # report
  python3 tools/text_lint.py --strict   # exit 1 on any finding

Checks: subtitle and choice length (fits the dialogue box at the default text
size), whitespace, space before punctuation, unbalanced quotes/brackets,
placeholder mismatch between languages, missing final punctuation on
dialogue lines, repeated words and a list of common Turkish spelling slips.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# The subtitle box is 1520 px wide; at the default 30 px font that is ~90
# characters a line and the box comfortably shows 3 lines (it grows upwards).
MAX_LINE = 270
# Choice buttons are 560 px wide (~33 chars a line), 2-3 lines still read well.
MAX_CHOICE = 95
TR_SLIPS = {
    r"\bher ?şey\b": None, r"\bherşey\b": "her şey", r"\bbirşey\b": "bir şey", r"\byada\b": "ya da",
    r"\bkağıt": "kâğıt", r"\bkağıd": "kâğıd", r"\bhala\b": "hâlâ (still) / hala (aunt)",
    r"\bdeyil\b": "değil", r"\bşuan\b": "şu an", r"\bherkez\b": "herkes", r"\byanlız": "yalnız",
    r"\bsanki\s+de\b": None, r"\bpekçok\b": "pek çok", r"\bhiçbir zaman\b": None, r"\bbirkaç\b": None,
}
DIALOGUE_KEY = re.compile(r"^(ch\d\d|ep\d\d)\.[^.]+$")  # line nodes (not prompts/options/items)
PLACEHOLDER = re.compile(r"\{[a-z_]+\}")
PAIRS = [("(", ")"), ("[", "]")]
# Glyphs the built-in Godot font is assumed to have: Latin-1, Latin Extended-A (Turkish) and common punctuation.
SAFE_EXTRA = set("…—–’‘“”·«»•→←↑↓×°€")


def unsafe_glyphs(v: str) -> list[str]:
    return sorted({ch for ch in v if ord(ch) > 0x17F and ch not in SAFE_EXTRA})


def load(lang: str) -> dict:
    d = json.loads((ROOT / f"data/locale/{lang}.json").read_text(encoding="utf-8"))
    return {k: v for k, v in d.items() if not k.startswith("_") and isinstance(v, str)}


def kind(key: str) -> str:
    """line (subtitle), option (choice button), prompt, label (item label / title) or ui."""
    parts = key.split(".")
    if not re.match(r"^(ch|ep)\d\d$", parts[0]):
        return "ui"
    if ".prompt" in key or key.endswith(".objective"):
        return "prompt"
    if parts[1] == "title" or (parts[1] == "it" and len(parts) == 3) or key.endswith(".locked"):
        return "label"
    if parts[1] == "it":
        return "line"
    if len(parts) == 3:
        return "option"
    return "line" if DIALOGUE_KEY.match(key) else "label"


def lint(tr: dict, en: dict) -> list[str]:
    out = []
    for lang, d in (("tr", tr), ("en", en)):
        for k, v in d.items():
            w = f"{lang}:{k}"
            kd = kind(k)
            if kd in ("line",) and len(v) > MAX_LINE:
                out.append(f"{w}: {len(v)} chars, longer than the subtitle box ({MAX_LINE})")
            if kd == "option" and len(v) > MAX_CHOICE:
                out.append(f"{w}: choice text {len(v)} chars (> {MAX_CHOICE})")
            bad = unsafe_glyphs(v)
            if bad:
                out.append(f"{w}: glyphs the default font may not have: {' '.join(bad)}")
            if v != v.strip():
                out.append(f"{w}: leading/trailing whitespace")
            if "  " in v and kd != "ui":  # UI hints use wide gaps on purpose
                out.append(f"{w}: double space")
            if kd != "ui" and re.search(r" [,.;:!?](?!\.)", v):
                out.append(f"{w}: space before punctuation")
            for a, b in PAIRS:
                if v.count(a) != v.count(b):
                    out.append(f"{w}: unbalanced {a}{b}")
            if v.count('"') % 2:
                out.append(f'{w}: odd number of "')
            m = re.search(r"\b(\w+) \1\b", v, re.IGNORECASE)
            if m and not m.group(1).isdigit():
                rep = m.group(1)
                if rep.lower() not in ("bip", "beep", "abi", "şaka", "uzun", "damla", "yer", "birer", "de", "da", "in", "çok", "yavaş", "yavas", "sıra", "yan", "teker", "tek", "ha", "very", "far"):
                    out.append(f"{w}: repeated word '{rep}'")
            if kd == "line" and v and v[-1] not in ".!?…'\")»:" and not v.endswith("—"):
                out.append(f"{w}: no final punctuation")
            if lang == "tr":
                for pat, fix in TR_SLIPS.items():
                    if fix and re.search(pat, v, re.IGNORECASE):
                        out.append(f"{w}: spelling '{re.search(pat, v, re.IGNORECASE).group(0)}' -> {fix}")
    for k in tr.keys() & en.keys():
        if sorted(PLACEHOLDER.findall(tr[k])) != sorted(PLACEHOLDER.findall(en[k])):
            out.append(f"{k}: placeholders differ between tr and en")
    for k in sorted(tr.keys() ^ en.keys()):
        out.append(f"{k}: missing in {'en' if k in tr else 'tr'}")
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--strict", action="store_true")
    a = ap.parse_args(argv)
    found = lint(load("tr"), load("en"))
    for f in found:
        print(f)
    print(f"{len(found)} finding(s)")
    return 1 if (a.strict and found) else 0


if __name__ == "__main__":
    sys.exit(main())
