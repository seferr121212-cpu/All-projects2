#!/usr/bin/env python3
"""Play-time estimate for VARDİYA without the engine.

Plays the whole game many times at random (mirrors the node semantics of
story_sim.py / dialogue_runner.gd: variants, branches, conditional options,
silence timeouts, QTE success / failure, exploration, endings + epilogues)
and times what a player reads and does, for two player profiles:

  quick    reads subtitles at 230 words/min, examines ~half of the optional items
  careful  reads at 160 words/min, examines every item and reads every journal note

Timing model (seconds): line = max(1.6, words / wps) + 0.5 advance; choice =
reading the prompt and options + 4; QTE = 6; location change = 4; exploration =
20 base + 8 walking per item; chapter card 4, chapter flowchart 35; ending card
25; credits 90 (once).  It is an estimate, not a measurement: real players
pause, re-read and get lost.

  python3 tools/playtime.py            # summary
  python3 tools/playtime.py --runs 500 --json
"""
from __future__ import annotations

import argparse
import json
import random
import re
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import story_sim  # noqa: E402
import validate_data as vd  # noqa: E402

PROFILES = {
    "quick": {"wpm": 230, "optional": 0.5, "journal": False},
    "careful": {"wpm": 160, "optional": 1.0, "journal": True},
}
WORD = re.compile(r"\w+", re.UNICODE)


class Clock:
    def __init__(self, texts: dict, profile: dict) -> None:
        self.texts = texts
        self.wps = profile["wpm"] / 60.0
        self.sec = 0.0
        self.words = 0

    def read(self, key, minimum: float = 1.6, extra: float = 0.5) -> None:
        n = len(WORD.findall(self.texts.get(key, ""))) if isinstance(key, str) else 0
        self.words += n
        self.sec += max(minimum, n / self.wps) + extra

    def add(self, sec: float) -> None:
        self.sec += sec


def _line_key(n: dict, s) -> str:
    for v in n.get("variants", []):
        if vd.evaluate(v.get("if"), s):
            return v.get("text", n.get("text"))
    return n.get("text")


def play_chapter(ch: dict, s, clock: Clock, profile: dict, rng: random.Random) -> str:
    """Plays one chapter from state `s` (mutated). Returns next_chapter."""
    nodes = ch["nodes"]
    node_id = ch["start"]
    clock.add(4.0)  # chapter card
    for _ in range(5000):
        n = nodes.get(node_id)
        if n is None:
            return ""
        t = n.get("type")
        if t == "line":
            if "if" not in n or vd.evaluate(n["if"], s):  # the runner skips lines whose "if" fails
                clock.read(_line_key(n, s))
            node_id = n["next"]
        elif t == "branch":
            nxt = n["else"]
            for c in n.get("cases", []):
                if vd.evaluate(c.get("if"), s):
                    nxt = c["next"]
                    break
            node_id = nxt
        elif t == "effect":
            story_sim.apply_effects(s, n.get("effects"))
            node_id = n["next"]
        elif t == "checkpoint":
            node_id = n["next"]
        elif t == "location":
            clock.add(4.0)
            node_id = n["next"]
        elif t == "choice":
            did = n.get("decision_id", node_id)
            opts = [o for o in n.get("options", []) if "if" not in o or vd.evaluate(o["if"], s)]
            clock.read(n.get("prompt"), minimum=0.0, extra=0.0)
            for o in opts:
                clock.read(o.get("text"), minimum=0.0, extra=0.0)
            clock.add(4.0)
            if n.get("timeout") and (not opts or rng.random() < 0.1):
                o = {**n["timeout"], "id": n["timeout"].get("id", "silence")}
                s.counters["silence"] = s.counters.get("silence", 0) + 1
                clock.read(o.get("text"), minimum=0.0, extra=0.0)
            else:
                o = rng.choice(opts)
            s.decisions[did] = o["id"]
            story_sim.apply_effects(s, o.get("effects"))
            node_id = o["next"]
        elif t == "qte":
            did = n.get("decision_id", node_id)
            res = "success" if rng.random() < 0.7 else "fail"
            if not isinstance(n.get(res), dict):
                res = "fail" if res == "success" else "success"
            clock.add(6.0)
            s.decisions[did] = res
            story_sim.apply_effects(s, n[res].get("effects"))
            node_id = n[res]["next"]
        elif t == "explore":
            clock.add(20.0)
            node_id = _explore(n, s, clock, profile, rng)
        elif t == "end":
            clock.add(35.0)  # chapter flowchart
            return n.get("next_chapter") or ""
        else:
            return ""
    return ""


def _explore(n: dict, s, clock: Clock, profile: dict, rng: random.Random) -> str:
    items = [it for it in n.get("items", []) if "if" not in it or vd.evaluate(it["if"], s)]
    exits = [it for it in items if "next" in it]
    optional = [it for it in items if "next" not in it]
    rng.shuffle(optional)
    for it in optional:
        if rng.random() > profile["optional"]:
            continue
        clock.add(8.0)
        if "requires" in it and not vd.evaluate(it["requires"], s):
            clock.read(it.get("locked_text"))
            continue
        first = it["id"] not in s.found
        s.found.add(it["id"])
        for line in it.get("lines", []):
            clock.read(line.get("text"))
        if first:
            story_sim.apply_effects(s, it.get("effects"))
        if profile["journal"] and it.get("journal"):
            clock.read(it["journal"], minimum=0.0, extra=0.0)
    it = rng.choice(exits)
    clock.add(8.0)
    s.found.add(it["id"])
    for line in it.get("lines", []):
        clock.read(line.get("text"))
    story_sim.apply_effects(s, it.get("effects"))
    return it["next"]


def load(root: Path):
    data = lambda rel: json.loads((root / rel).read_text(encoding="utf-8"))  # noqa: E731
    texts = {k: v for k, v in data("data/locale/tr.json").items() if not k.startswith("_")}
    flags_raw = data("data/story_flags.json")
    flags = {k: (v.get("default") if isinstance(v, dict) else v) for k, v in flags_raw.items() if not k.startswith("_")}
    index = data("data/chapters/index.json")
    chapters = {e["id"]: data(f"data/chapters/{e['id']}.json") for e in index["chapters"] + index.get("epilogues", [])}
    endings = data("data/endings.json")
    return texts, flags, index, chapters, endings


def play_game(root_data, profile: dict, rng: random.Random) -> dict:
    texts, flags, index, chapters, endings = root_data
    clock = Clock(texts, profile)
    s = vd.State(flags)
    per: dict[str, float] = {}
    cid = index["chapters"][0]["id"]
    while cid:
        start = clock.sec
        nxt = play_chapter(chapters[cid], s, clock, profile, rng)
        per[cid] = clock.sec - start
        if nxt == "@ending":
            rules = sorted(endings.get("endings", []), key=lambda r: r.get("priority", 0))
            ending_id = (vd.winning_ending(rules, s) or {}).get("ending", "")
            info = endings.get("ending_info", {}).get(ending_id, {})
            s.flags["ending"] = ending_id
            nxt = info.get("epilogue", "")
            if nxt:
                start = clock.sec
                play_chapter(chapters[nxt], s, clock, profile, rng)
                per["epilogue"] = clock.sec - start
            clock.add(25.0 + 90.0)
            per["ending+credits"] = 115.0
            break
        cid = nxt
    return {"total": clock.sec, "words": clock.words, "per": per}


def estimate(root: Path, runs: int = 300, seed: int = 3) -> dict:
    root_data = load(root)
    out = {}
    for name, prof in PROFILES.items():
        rng = random.Random(seed)
        games = [play_game(root_data, prof, rng) for _ in range(runs)]
        per: dict[str, list] = {}
        for g in games:
            for k, v in g["per"].items():
                per.setdefault(k, []).append(v)
        out[name] = {
            "minutes_mean": statistics.mean(g["total"] for g in games) / 60.0,
            "minutes_min": min(g["total"] for g in games) / 60.0,
            "minutes_max": max(g["total"] for g in games) / 60.0,
            "words_mean": statistics.mean(g["words"] for g in games),
            "chapters": {k: statistics.mean(v) / 60.0 for k, v in per.items()},
        }
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", type=Path, default=ROOT)
    ap.add_argument("--runs", type=int, default=300)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    res = estimate(a.root, a.runs)
    if a.json:
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return 0
    for name, r in res.items():
        print(f"{name:8s} one playthrough: {r['minutes_mean']:.0f} min (range {r['minutes_min']:.0f}-{r['minutes_max']:.0f}), "
              f"~{r['words_mean']:.0f} words read")
        for k, v in r["chapters"].items():
            print(f"    {k:22s} {v:5.1f} min")
    return 0


if __name__ == "__main__":
    sys.exit(main())
