#!/usr/bin/env python3
"""Exhaustive chapter path simulator (mirrors autoload/dialogue_runner.gd).

Explores every play state of a chapter from a given starting state:
every visible choice option and the silence timeout, QTE success and failure,
and in exploration rooms every order of examining items before leaving.
States are memoised, so permutations collapse.

Used by validate_data.py to report options, items, nodes and end nodes that
no playthrough can reach, and to print a concrete test path to each end:

  python3 tools/story_sim.py ch01_last_check        # list paths to each end
"""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

MAX_STATES = 200_000
TRUST_MIN, TRUST_MAX = -5, 5


def _vd():
    import validate_data  # lazy: validate_data imports this module
    return validate_data


def apply_effects(s, effects) -> None:
    vd = _vd()
    for e in effects or []:
        if "if" in e and not vd.evaluate(e["if"], s):
            continue
        if "set_flag" in e:
            s.flags[e["set_flag"]] = e.get("value", True)
        elif "add_counter" in e:
            s.counters[e["add_counter"]] = s.counters.get(e["add_counter"], 0) + int(e.get("delta", 1))
        elif "trust" in e or "trust_mutual" in e:
            pair = e.get("trust") or e.get("trust_mutual")
            pairs = [tuple(pair)] + ([(pair[1], pair[0])] if "trust_mutual" in e else [])
            for p in pairs:
                s.trust[p] = max(TRUST_MIN, min(TRUST_MAX, s.trust.get(p, 0) + int(e.get("delta", 0))))
        elif "status" in e:
            s.status[e["status"]] = e.get("value", "alive")
        elif "mood" in e:
            s.mood[e["mood"]] = e.get("value", "calm")


def _key(node_id: str, s, extra="") -> str:
    return json.dumps([node_id, extra, s.status, s.mood, sorted(s.trust.items()), s.flags,
                       s.counters, s.decisions, sorted(s.found)], sort_keys=True, default=str)


def simulate(chapter: dict, flags: dict, start_state=None) -> dict:
    vd = _vd()
    nodes = chapter.get("nodes", {})
    seen_nodes: set[str] = set()
    seen_options: set[tuple] = set()
    seen_items: set[tuple] = set()
    ends: dict[str, list] = {}
    memo: set[str] = set()
    s0 = start_state or vd.State(flags)
    stack = [(chapter.get("start"), s0, [])]
    truncated = False

    while stack:
        node_id, s, path = stack.pop()
        k = _key(node_id, s)
        if k in memo:
            continue
        memo.add(k)
        if len(memo) > MAX_STATES:
            truncated = True
            break
        # Run instant nodes.
        steps = 0
        while steps < 1000:
            steps += 1
            n = nodes.get(node_id)
            if n is None:
                break
            seen_nodes.add(node_id)
            t = n.get("type")
            if t == "line":
                for v in n.get("variants", []):
                    vd.evaluate(v.get("if"), s)
                node_id = n["next"]
            elif t == "branch":
                nxt = n["else"]
                for c in n.get("cases", []):
                    if vd.evaluate(c.get("if"), s):
                        nxt = c["next"]
                        break
                node_id = nxt
            elif t == "effect":
                apply_effects(s, n.get("effects"))
                node_id = n["next"]
            elif t in ("checkpoint", "location"):
                node_id = n["next"]
            else:
                break
        n = nodes.get(node_id, {})
        t = n.get("type")
        if t == "end":
            ends.setdefault(node_id, path)
            continue
        if t == "choice":
            did = n.get("decision_id", node_id)
            branches = [o for o in n.get("options", []) if "if" not in o or vd.evaluate(o["if"], s)]
            if n.get("timeout"):
                branches.append({**n["timeout"], "id": n["timeout"].get("id", "silence"), "_timeout": True})
            for o in branches:
                seen_options.add((node_id, o["id"]))
                s2 = copy.deepcopy(s)
                s2.decisions[did] = o["id"]
                if o.get("_timeout"):
                    s2.counters["silence"] = s2.counters.get("silence", 0) + 1
                apply_effects(s2, o.get("effects"))
                stack.append((o["next"], s2, path + [f"{did}={o['id']}"]))
        elif t == "qte":
            did = n.get("decision_id", node_id)
            for res in ("success", "fail"):
                if not isinstance(n.get(res), dict) or "next" not in n[res]:
                    continue
                seen_options.add((node_id, res))
                s2 = copy.deepcopy(s)
                s2.decisions[did] = res
                apply_effects(s2, n[res].get("effects"))
                stack.append((n[res]["next"], s2, path + [f"{did}={res}"]))
        elif t == "explore":
            for it in n.get("items", []):
                if "if" in it and not vd.evaluate(it["if"], s):
                    continue
                iid = it["id"]
                if "requires" in it and not vd.evaluate(it["requires"], s):
                    continue  # locked: only plays a line, state unchanged
                seen_items.add((node_id, iid))
                s2 = copy.deepcopy(s)
                first = iid not in s2.found
                s2.found.add(iid)
                if first:
                    apply_effects(s2, it.get("effects"))
                if "next" in it:
                    stack.append((it["next"], s2, path + [f"exit:{iid}"]))
                elif first:
                    stack.append((node_id, s2, path + [f"examine:{iid}"]))
        elif node_id not in nodes:
            continue

    unreachable = []
    for nid, n in nodes.items():
        if nid not in seen_nodes:
            unreachable.append(f"node '{nid}' is never reached in any playthrough")
        if n.get("type") == "choice":
            for o in n.get("options", []):
                if (nid, o["id"]) not in seen_options:
                    unreachable.append(f"option '{nid}.{o['id']}' can never be offered")
        if n.get("type") == "explore":
            for it in n.get("items", []):
                if (nid, it["id"]) not in seen_items:
                    unreachable.append(f"item '{nid}.{it['id']}' can never be used")
    if truncated:
        unreachable.append(f"state space truncated at {MAX_STATES} states")
    return {"paths": len(memo), "ends": ends, "unreachable": unreachable}


def main(argv=None) -> int:
    argv = argv or sys.argv[1:]
    root = Path(__file__).resolve().parent.parent
    vd = _vd()
    flags_raw = json.loads((root / "data/story_flags.json").read_text(encoding="utf-8"))
    flags = {k: (v.get("default") if isinstance(v, dict) else v) for k, v in flags_raw.items() if not k.startswith("_")}
    for cid in argv or ["ch01_last_check"]:
        ch = json.loads((root / f"data/chapters/{cid}.json").read_text(encoding="utf-8"))
        r = simulate(ch, flags, vd.State(flags))
        print(f"{cid}: {r['paths']} states")
        for end, path in r["ends"].items():
            print(f"  -> {end}: {' > '.join(path)}")
        for m in r["unreachable"]:
            print(f"  ! {m}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
