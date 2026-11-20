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

import json
import sys
from pathlib import Path

MAX_STATES = 120_000
CARRY_CAP = 2500  # distinct end states carried into the next chapter (diversity-preserving)
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


def _key(node_id: str, s, extra="", rel=None) -> str:
    if rel is None:
        return json.dumps([node_id, extra, s.status, s.mood, sorted(s.trust.items()), s.flags,
                           s.counters, s.decisions, sorted(s.found)], sort_keys=True, default=str)
    return json.dumps([node_id, extra, s.status, {c: m for c, m in s.mood.items() if c in rel["moods"]},
                       sorted(s.trust.items()), {k: v for k, v in s.flags.items() if k in rel["flags"]},
                       {k: min(v, rel["counters"].get(k, 0)) for k, v in s.counters.items() if k in rel["counters"]},
                       {k: v for k, v in s.decisions.items() if k in rel["decisions"]},
                       sorted(f for f in s.found if f in rel["found"])], sort_keys=True, default=str)


def relevance(chapters: list, endings: dict) -> dict:
    """Which parts of the state can influence any condition (others are ignored when memoising)."""
    rel = {"moods": set(), "counters": {}, "decisions": set(), "found": set(), "flags": set()}

    def walk(c):
        if isinstance(c, list):
            for x in c:
                walk(x)
        elif isinstance(c, dict):
            if "mood" in c and any(op in c for op in ("eq", "ne", "in")):
                rel["moods"].add(c["mood"])
            if "counter" in c:
                th = max([v for k, v in c.items() if k in ("eq", "gt", "gte", "lt", "lte") and isinstance(v, (int, float))] or [0])
                rel["counters"][c["counter"]] = max(rel["counters"].get(c["counter"], 0), int(th) + 1)
            if "decision" in c:
                rel["decisions"].add(c["decision"])
            if "found" in c:
                rel["found"].add(c["found"])
            if "flag" in c and isinstance(c["flag"], str):
                rel["flags"].add(c["flag"])
            for k, v in c.items():
                if k in ("if", "all", "any", "not", "requires", "condition", "cases", "variants", "options",
                         "items", "effects", "timeout", "success", "fail", "nodes", "endings") or isinstance(v, (dict, list)):
                    walk(v)
    for ch in chapters:
        walk(ch.get("nodes", {}))
    walk(endings.get("endings", []))
    return rel


def simulate(chapter: dict, flags: dict, start_state=None, rel=None, start_states=None) -> dict:
    vd = _vd()
    nodes = chapter.get("nodes", {})
    if rel is None:
        # Memoise on what this chapter's own conditions can see: exact for its reachability,
        # and keeps exploration orders / unrelated side-story flags from multiplying states.
        rel = relevance([chapter], {})
    seen_nodes: set[str] = set()
    seen_options: set[tuple] = set()
    seen_items: set[tuple] = set()
    ends: dict[str, list] = {}
    memo: set[str] = set()
    if start_states is None:
        start_states = [(start_state or vd.State(flags), [])]
    pending = list(reversed(start_states))  # first start states are the most diverse ones
    stack: list = []
    truncated = False
    skipped_starts = 0
    end_states: dict[str, tuple] = {}
    pov_errors: set[str] = set()

    while stack or pending:
        if not stack:
            # Explore each start state completely, or not at all (budget).
            if len(memo) > MAX_STATES:
                skipped_starts = len(pending)
                truncated = True
                break
            st, p = pending.pop()
            stack.append((chapter.get("start"), st, list(p)))
        node_id, s, path = stack.pop()
        k = _key(node_id, s, rel=rel)
        if k in memo:
            continue
        memo.add(k)
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
                if t == "location" and n.get("player") and s.status.get(n["player"]) != "alive":
                    pov_errors.add(f"location '{node_id}' puts dead/missing '{n['player']}' in control")
                node_id = n["next"]
            else:
                break
        n = nodes.get(node_id, {})
        t = n.get("type")
        if t == "end":
            ends.setdefault(node_id, path)
            ek = _key("", s, rel=rel)
            if ek not in end_states:
                end_states[ek] = (s, path)
            continue
        if t == "choice":
            did = n.get("decision_id", node_id)
            branches = [o for o in n.get("options", []) if "if" not in o or vd.evaluate(o["if"], s)]
            if n.get("timeout"):
                branches.append({**n["timeout"], "id": n["timeout"].get("id", "silence"), "_timeout": True})
            for o in branches:
                seen_options.add((node_id, o["id"]))
                s2 = s.clone()
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
                s2 = s.clone()
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
                if rel is not None and "next" not in it and not it.get("effects") and iid not in rel["found"]:
                    continue  # examining it cannot change the story: no need to branch
                s2 = s.clone()
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

    unreachable = sorted(pov_errors)
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
    if truncated and len(start_states) <= 1:
        unreachable.append(f"state space truncated at {MAX_STATES} states")
    return {"paths": len(memo), "ends": ends, "unreachable": unreachable, "end_states": list(end_states.values()),
            "seen": (seen_nodes, seen_options, seen_items), "pov_errors": sorted(pov_errors), "truncated": truncated,
            "starts_explored": len(start_states) - skipped_starts}


def _reduce(states: list, rel: dict, cap: int, seed: int = 11) -> list:
    """Order and trim carried states so a limited budget still sees every kind of story.
    1) one random state per coarse group (life status + relevant flags),
    2) lowest/highest-trust state of every fine group (+ counters, decisions),
    3) everything else; each tier shuffled, the whole list cut at `cap`."""
    import random
    rng = random.Random(seed)

    def fl(st):
        return {k: v for k, v in st.flags.items() if k in rel["flags"]}
    coarse: dict[str, list] = {}
    fine: dict[str, list] = {}
    for sp in states:
        st = sp[0]
        ck = json.dumps([st.status, fl(st)], sort_keys=True, default=str)
        fk = json.dumps([ck, {k: min(v, rel["counters"].get(k, 0)) for k, v in st.counters.items() if k in rel["counters"]},
                         {k: v for k, v in st.decisions.items() if k in rel["decisions"]}], sort_keys=True, default=str)
        coarse.setdefault(ck, []).append(sp)
        fine.setdefault(fk, []).append(sp)
    chosen, seen = [], set()

    def take(tier):
        rng.shuffle(tier)
        for sp in tier:
            if id(sp) not in seen:
                seen.add(id(sp))
                chosen.append(sp)
    take([rng.choice(m) for m in coarse.values()])
    ext = []
    for m in fine.values():
        m.sort(key=lambda sp: sp[0].avg_trust())
        ext += [m[0], m[-1]]
    take(ext)
    take(list(states))
    return chosen[:cap]


def simulate_game(chapters: list, flags: dict, endings: dict, epilogues: dict | None = None) -> dict:
    """Play every chapter in order, carrying each distinct end state into the next chapter.
    Then resolve the ending of every final state and play that ending's epilogue from those states.
    Returns per-chapter unreachable lists, per-ending example paths and state counts."""
    vd = _vd()
    epilogues = epilogues or {}
    rel = relevance(chapters + list(epilogues.values()), endings)
    states = [(vd.State(flags), [])]
    report = {"chapters": {}, "endings": {}, "ending_counts": {}, "pov_errors": [], "truncated": False, "sampled": False}
    for ch in chapters:
        r = simulate(ch, flags, rel=rel, start_states=states)
        report["chapters"][ch["id"]] = {"unreachable": r["unreachable"], "states": r["paths"], "ends": len(r["end_states"]),
                                        "starts": len(states), "starts_explored": r["starts_explored"]}
        report["pov_errors"] += [f"{ch['id']}: {e}" for e in r["pov_errors"]]
        report["truncated"] |= r["truncated"]
        report["sampled"] |= r["starts_explored"] < len(states)
        states = [(st, p + [f"[{ch['id']} end]"]) for st, p in r["end_states"]]
        report["chapters"][ch["id"]]["carried"] = min(len(states), CARRY_CAP)
        if len(states) > CARRY_CAP:
            report["sampled"] = True
        states = _reduce(states, rel, CARRY_CAP)
        if not states:
            break
    rules = sorted(endings.get("endings", []), key=lambda e: e.get("priority", 0))
    per_ending: dict = {}
    for st, path in states:
        rule = vd.winning_ending(rules, st)
        if rule is None:
            continue
        e = rule.get("ending")
        final = st.clone()
        final.flags["ending"] = e
        per_ending.setdefault(e, []).append((final, path))
        report["ending_counts"][e] = report["ending_counts"].get(e, 0) + 1
        if e not in report["endings"] or len(path) < len(report["endings"][e]["path"]):
            report["endings"][e] = {"rule": rule.get("id"), "path": path,
                                    "alive": [c for c in vd.CHARACTERS if st.status[c] == "alive"],
                                    "avg_trust": round(st.avg_trust(), 2)}
    report["final_states"] = len(states)
    report["epilogues"] = {}
    info = endings.get("ending_info", {})
    for e, starts in sorted(per_ending.items()):
        ep_id = info.get(e, {}).get("epilogue")
        ep = epilogues.get(ep_id)
        if ep is None:
            continue
        r = simulate(ep, flags, rel=rel, start_states=starts)
        report["epilogues"][ep_id] = {"ending": e, "unreachable": r["unreachable"], "states": r["paths"],
                                      "starts": len(starts), "ends": len(r["end_states"])}
        report["pov_errors"] += [f"{ep_id}: {x}" for x in r["pov_errors"]]
    return report


def main(argv=None) -> int:
    argv = argv or sys.argv[1:]
    root = Path(__file__).resolve().parent.parent
    vd = _vd()
    flags_raw = json.loads((root / "data/story_flags.json").read_text(encoding="utf-8"))
    flags = {k: (v.get("default") if isinstance(v, dict) else v) for k, v in flags_raw.items() if not k.startswith("_")}
    if argv and argv[0] == "--game":
        index = json.loads((root / "data/chapters/index.json").read_text(encoding="utf-8"))
        chapters = [json.loads((root / f"data/chapters/{e['id']}.json").read_text(encoding="utf-8")) for e in index["chapters"]]
        endings = json.loads((root / "data/endings.json").read_text(encoding="utf-8"))
        eps = {e["id"]: json.loads((root / f"data/chapters/{e['id']}.json").read_text(encoding="utf-8"))
               for e in index.get("epilogues", [])}
        r = simulate_game(chapters, flags, endings, eps)
        for cid, info in r["chapters"].items():
            print(f"{cid}: {info['starts_explored']}/{info['starts']} start states fully explored, "
                  f"{info['states']} states, {info['ends']} distinct end states")
            for m in info["unreachable"]:
                print(f"  ! {m}")
        print(f"final states: {r['final_states']}")
        for eid, info in r["epilogues"].items():
            print(f"{eid} ({info['ending']}): {info['starts']} start states, {info['states']} states")
            for m in info["unreachable"]:
                print(f"  ! {m}")
        for m in r["pov_errors"]:
            print(f"  POV ERROR {m}")
        for e, info in sorted(r["endings"].items()):
            print(f"\nENDING {e} ({r['ending_counts'][e]} final states) via {info['rule']}, alive={info['alive']}, avg_trust={info['avg_trust']}")
            print("  " + " > ".join(x for x in info["path"] if not x.startswith("examine:")))
        return 0
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
