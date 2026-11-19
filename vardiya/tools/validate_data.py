#!/usr/bin/env python3
"""VARDIYA data validator.

Checks, without needing Godot:
  * locale: tr/en key parity, empty strings, {placeholder} parity
  * chapters: schema, broken `next` links, unreachable nodes, dead ends,
    unknown node types / characters / flags / moods, duplicate decision ids,
    missing translation keys, minimum major decisions per chapter,
    choices with 2-4 options, loops that can never reach an `end`
  * endings: rule schema, exactly one fallback, ending reachability
    (an ending is reported unreachable when no state that the chapter data
    can produce makes any of its rules win, given rule priority)

Usage:
  python3 tools/validate_data.py [--root PATH] [--json]
Exit code 0 = no errors (warnings allowed), 1 = errors.
"""
from __future__ import annotations

import argparse
import itertools
import json
import random
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import story_sim  # noqa: E402

CHARACTERS = ["kemal", "defne", "riza"]
STATUSES = ["alive", "dead", "missing"]
MOODS = ["calm", "anxious", "angry", "hopeful", "broken", "guilty"]
NODE_TYPES = {"line", "choice", "branch", "effect", "checkpoint", "location", "end", "explore", "qte"}
SUBJECTS = ["flag", "counter", "decision", "status", "mood", "trust",
            "avg_trust", "alive_count", "dead_count", "found"]
QTE_MODES = {"press", "mash", "hold"}
OPS = ["eq", "ne", "gt", "gte", "lt", "lte", "in"]
EFFECT_KEYS = ["set_flag", "add_counter", "trust", "trust_mutual", "status", "mood", "journal"]
TRUST_MIN, TRUST_MAX = -5, 5
PLACEHOLDER = re.compile(r"\{(\w+)\}")
SAMPLES = 40000


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.info: list[str] = []

    def error(self, msg: str) -> None:
        self.errors.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    def add(self, severity: str, msg: str) -> None:
        (self.error if severity == "error" else self.warn)(msg)


def load_json(path: Path, rep: Report):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        rep.error(f"{path}: file missing")
    except json.JSONDecodeError as e:
        rep.error(f"{path}: invalid JSON ({e})")
    return None


# --------------------------------------------------------------------------- #
# Condition evaluation (mirrors autoload/decision_manager.gd)
# --------------------------------------------------------------------------- #

class State:
    def __init__(self, flags: dict) -> None:
        self.status = {c: "alive" for c in CHARACTERS}
        self.mood = {c: "calm" for c in CHARACTERS}
        self.trust = {(a, b): 0 for a in CHARACTERS for b in CHARACTERS if a != b}
        self.flags = dict(flags)
        self.counters: dict[str, int] = {}
        self.decisions: dict[str, str] = {}
        self.found: set[str] = set()

    def alive_count(self) -> int:
        return sum(1 for c in CHARACTERS if self.status[c] == "alive")

    def dead_count(self) -> int:
        return sum(1 for c in CHARACTERS if self.status[c] == "dead")

    def avg_trust(self) -> float:
        vals = [v for (a, b), v in self.trust.items()
                if self.status[a] == "alive" and self.status[b] == "alive"]
        return sum(vals) / len(vals) if vals else 0.0


def _num(v) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _equal(a, b) -> bool:
    if _num(a) and _num(b):
        return abs(float(a) - float(b)) < 1e-6
    if type(a) is not type(b):
        return False
    return a == b


def _truthy(v) -> bool:
    if v is None:
        return False
    if isinstance(v, bool):
        return v
    if _num(v):
        return v != 0
    if isinstance(v, str):
        return v != ""
    return True


def subject_value(s: State, subject: str, arg):
    if subject == "flag":
        return s.flags.get(arg)
    if subject == "counter":
        return s.counters.get(arg, 0)
    if subject == "decision":
        return s.decisions.get(arg, "")
    if subject == "status":
        return s.status.get(arg, "alive")
    if subject == "mood":
        return s.mood.get(arg, "calm")
    if subject == "trust":
        return s.trust.get((arg[0], arg[1]), 0)
    if subject == "avg_trust":
        return s.avg_trust()
    if subject == "alive_count":
        return s.alive_count()
    if subject == "dead_count":
        return s.dead_count()
    if subject == "found":
        return arg in s.found
    return None


def evaluate(cond, s: State) -> bool:
    if cond is None:
        return True
    if isinstance(cond, list):
        return all(evaluate(c, s) for c in cond)
    if not cond:
        return True
    if "all" in cond:
        return evaluate(cond["all"], s)
    if "any" in cond:
        return any(evaluate(c, s) for c in cond["any"])
    if "not" in cond:
        return not evaluate(cond["not"], s)
    for subject in SUBJECTS:
        if subject in cond:
            value = subject_value(s, subject, cond[subject])
            any_op = False
            for op in OPS:
                if op not in cond:
                    continue
                any_op = True
                t = cond[op]
                if op == "eq" and not _equal(value, t):
                    return False
                if op == "ne" and _equal(value, t):
                    return False
                if op in ("gt", "gte", "lt", "lte"):
                    if not (_num(value) and _num(t)):
                        return False
                    if op == "gt" and not value > t:
                        return False
                    if op == "gte" and not value >= t:
                        return False
                    if op == "lt" and not value < t:
                        return False
                    if op == "lte" and not value <= t:
                        return False
                if op == "in" and not any(_equal(value, x) for x in t):
                    return False
            return True if any_op else _truthy(value)
    return False


# --------------------------------------------------------------------------- #
# Schema checks
# --------------------------------------------------------------------------- #

class Context:
    def __init__(self, rep: Report, locales: dict, flags: dict, speakers: set | None = None,
                 locations: dict | None = None) -> None:
        self.rep = rep
        self.locales = locales
        self.flags = flags
        self.speakers = speakers if speakers is not None else set(CHARACTERS)
        self.locations = locations or {}
        self.used_keys: set[str] = set()
        self.item_ids: dict[str, str] = {}

    def key(self, where: str, key) -> None:
        if not isinstance(key, str) or not key:
            self.rep.error(f"{where}: missing text key")
            return
        self.used_keys.add(key)
        for loc, table in self.locales.items():
            if key not in table:
                self.rep.error(f"{where}: missing translation '{key}' in {loc}.json")


def check_condition(ctx: Context, where: str, cond) -> None:
    rep = ctx.rep
    if cond is None:
        return
    if isinstance(cond, list):
        for i, c in enumerate(cond):
            check_condition(ctx, f"{where}[{i}]", c)
        return
    if not isinstance(cond, dict):
        rep.error(f"{where}: condition must be an object")
        return
    if not cond:
        return
    for comb in ("all", "any"):
        if comb in cond:
            if not isinstance(cond[comb], list):
                rep.error(f"{where}.{comb}: must be a list")
                return
            for i, c in enumerate(cond[comb]):
                check_condition(ctx, f"{where}.{comb}[{i}]", c)
            return
    if "not" in cond:
        check_condition(ctx, f"{where}.not", cond["not"])
        return
    subjects = [s for s in SUBJECTS if s in cond]
    if len(subjects) != 1:
        rep.error(f"{where}: condition needs exactly one subject of {SUBJECTS}, got {list(cond)}")
        return
    subject = subjects[0]
    arg = cond[subject]
    unknown = [k for k in cond if k not in OPS and k != subject]
    if unknown:
        rep.error(f"{where}: unknown condition keys {unknown}")
    if subject == "flag" and arg not in ctx.flags:
        rep.error(f"{where}: undeclared flag '{arg}' (add it to data/story_flags.json)")
    if subject == "found" and not isinstance(arg, str):
        rep.error(f"{where}: found needs an item id")
    if subject in ("status", "mood") and arg not in CHARACTERS:
        rep.error(f"{where}: unknown character '{arg}'")
    if subject == "trust" and not _valid_pair(arg):
        rep.error(f"{where}: trust needs [from, to] character pair, got {arg}")
    if subject == "status":
        for op in ("eq", "ne"):
            if op in cond and cond[op] not in STATUSES:
                rep.error(f"{where}: unknown status '{cond[op]}'")
    if "in" in cond and not isinstance(cond["in"], list):
        rep.error(f"{where}: 'in' needs a list")


def _valid_pair(arg) -> bool:
    return (isinstance(arg, list) and len(arg) == 2 and arg[0] in CHARACTERS
            and arg[1] in CHARACTERS and arg[0] != arg[1])


def check_effects(ctx: Context, where: str, effects) -> None:
    rep = ctx.rep
    if effects is None:
        return
    if not isinstance(effects, list):
        rep.error(f"{where}: effects must be a list")
        return
    for i, e in enumerate(effects):
        w = f"{where}[{i}]"
        if not isinstance(e, dict):
            rep.error(f"{w}: effect must be an object")
            continue
        kinds = [k for k in EFFECT_KEYS if k in e]
        if len(kinds) != 1:
            rep.error(f"{w}: effect needs exactly one of {EFFECT_KEYS}")
            continue
        kind = kinds[0]
        if "if" in e:
            check_condition(ctx, f"{w}.if", e["if"])
        if kind == "set_flag" and e["set_flag"] not in ctx.flags:
            rep.error(f"{w}: undeclared flag '{e['set_flag']}'")
        if kind in ("trust", "trust_mutual"):
            if not _valid_pair(e[kind]):
                rep.error(f"{w}: {kind} needs [a, b] character pair")
            if not isinstance(e.get("delta"), int):
                rep.error(f"{w}: {kind} needs integer 'delta'")
        if kind == "status":
            if e["status"] not in CHARACTERS:
                rep.error(f"{w}: unknown character '{e['status']}'")
            if e.get("value") not in STATUSES:
                rep.error(f"{w}: unknown status '{e.get('value')}'")
        if kind == "mood":
            if e["mood"] not in CHARACTERS:
                rep.error(f"{w}: unknown character '{e['mood']}'")
            if e.get("value") not in MOODS:
                rep.error(f"{w}: unknown mood '{e.get('value')}'")
        if kind == "journal":
            ctx.key(w, e["journal"])


def check_explore(ctx: Context, w: str, n: dict) -> None:
    rep = ctx.rep
    scene = n.get("scene")
    loc = ctx.locations.get(scene)
    if loc is None:
        rep.error(f"{w}: explore needs a known 'scene', got '{scene}'")
        loc = {}
    if "objective" in n:
        ctx.key(f"{w}.objective", n["objective"])
    items = n.get("items", [])
    if not items:
        rep.error(f"{w}: explore has no items")
    if not any("next" in it for it in items):
        rep.error(f"{w}: explore has no exit item (an item with 'next')")
    actor_ids = {a.get("id") for a in loc.get("actors", [])}
    for it in items:
        iid = it.get("id")
        iw = f"{w}.{iid}"
        if not iid:
            rep.error(f"{w}: item without id")
            continue
        if iid in ctx.item_ids:
            rep.error(f"{iw}: duplicate item id (also {ctx.item_ids[iid]})")
        ctx.item_ids[iid] = iw
        ctx.key(iw, it.get("label"))
        if "actor" in it:
            if it["actor"] not in actor_ids:
                rep.error(f"{iw}: actor '{it['actor']}' not placed in scene '{scene}'")
        elif it.get("point", iid) not in loc.get("points", {}):
            rep.error(f"{iw}: no point '{it.get('point', iid)}' in scene '{scene}'")
        for key in ("if", "requires"):
            check_condition(ctx, f"{iw}.{key}", it.get(key))
        if "requires" in it:
            ctx.key(f"{iw}.locked_text", it.get("locked_text"))
        if "journal" in it:
            ctx.key(f"{iw}.journal", it["journal"])
        check_effects(ctx, f"{iw}.effects", it.get("effects"))
        for i, l in enumerate(it.get("lines", []) + it.get("repeat_lines", [])):
            sp = l.get("speaker", "narrator")
            if sp != "narrator" and sp not in ctx.speakers:
                rep.error(f"{iw}.lines[{i}]: unknown speaker '{sp}'")
            ctx.key(f"{iw}.lines[{i}]", l.get("text"))


def check_location(rep: Report, lid: str, loc: dict, speakers: set) -> None:
    w = f"location {lid}"
    if loc.get("id") != lid:
        rep.error(f"{w}: id must match file name")
    if "default" not in loc.get("spawns", {}) and not loc.get("spawns"):
        rep.error(f"{w}: no spawns")
    for a in loc.get("actors", []):
        if a.get("id") not in speakers:
            rep.error(f"{w}: unknown actor '{a.get('id')}'")
    size = loc.get("size", [12, 4, 10])
    def inside(p, what):
        if abs(p[0]) > size[0] / 2 or abs(p[2]) > size[2] / 2:
            rep.error(f"{w}: {what} at {p} is outside the room {size}")
    for sid, sp in loc.get("spawns", {}).items():
        inside(sp.get("pos", [0, 0, 0]), f"spawn '{sid}'")
    for pid, pt in loc.get("points", {}).items():
        inside(pt.get("pos", [0, 0, 0]), f"point '{pid}'")
    for a in loc.get("actors", []):
        inside(a.get("pos", [0, 0, 0]), f"actor '{a.get('id')}'")
    check_walkable(rep, w, loc)
    tex = loc.get("textures", [])
    for tx in tex:
        if tx.get("size", 512) > 1024:
            rep.error(f"{w}: texture {tx.get('path')} exceeds 1024 px budget")


PLAYER_RADIUS = 0.3
CELL = 0.2


def walk_grid(loc: dict):
    """Occupancy grid (True = blocked) of a location, boxes inflated by the player radius."""
    sx, _, sz = loc.get("size", [12, 4, 10])
    nx, nz = int(sx / CELL), int(sz / CELL)
    blocked = [[False] * nz for _ in range(nx)]
    for b in loc.get("boxes", []):
        if not b.get("collide", True):
            continue
        px, py, pz = b["pos"]
        bx, by, bz = b.get("size", [1, 1, 1])
        if py - by / 2 > 1.8 or py + by / 2 < 0.05:
            continue  # above head height or a floor decal
        if int(round(b.get("rot", 0))) % 180 == 90:
            bx, bz = bz, bx
        x0, x1 = px - bx / 2 - PLAYER_RADIUS, px + bx / 2 + PLAYER_RADIUS
        z0, z1 = pz - bz / 2 - PLAYER_RADIUS, pz + bz / 2 + PLAYER_RADIUS
        for i in range(nx):
            cx = -sx / 2 + (i + 0.5) * CELL
            if x0 <= cx <= x1:
                for j in range(nz):
                    cz = -sz / 2 + (j + 0.5) * CELL
                    if z0 <= cz <= z1:
                        blocked[i][j] = True
    # Perimeter walls.
    for i in range(nx):
        for j in range(nz):
            cx, cz = -sx / 2 + (i + 0.5) * CELL, -sz / 2 + (j + 0.5) * CELL
            if abs(cx) > sx / 2 - PLAYER_RADIUS - 0.1 or abs(cz) > sz / 2 - PLAYER_RADIUS - 0.1:
                blocked[i][j] = True
    return blocked, nx, nz, sx, sz


def check_walkable(rep: Report, w: str, loc: dict) -> None:
    blocked, nx, nz, sx, sz = walk_grid(loc)

    def cell(p):
        return (min(nx - 1, max(0, int((p[0] + sx / 2) / CELL))), min(nz - 1, max(0, int((p[2] + sz / 2) / CELL))))

    for sid, sp in loc.get("spawns", {}).items():
        i, j = cell(sp["pos"])
        if blocked[i][j]:
            rep.error(f"{w}: spawn '{sid}' is inside geometry")
            continue
        seen = {(i, j)}
        stack = [(i, j)]
        while stack:
            a, b = stack.pop()
            for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                c = (a + da, b + db)
                if 0 <= c[0] < nx and 0 <= c[1] < nz and c not in seen and not blocked[c[0]][c[1]]:
                    seen.add(c)
                    stack.append(c)
        targets = {f"point '{k}'": (v["pos"], v.get("radius", 1.4)) for k, v in loc.get("points", {}).items()}
        targets.update({f"actor '{a['id']}'": (a["pos"], 1.6) for a in loc.get("actors", [])})
        for name, (pos, radius) in targets.items():
            ok = any(((-sx / 2 + (a + 0.5) * CELL - pos[0]) ** 2 + (-sz / 2 + (b + 0.5) * CELL - pos[2]) ** 2)
                     <= (radius * 0.9) ** 2 for a, b in seen)
            if not ok:
                rep.error(f"{w}: {name} cannot be reached on foot from spawn '{sid}'")


def next_ids(node: dict) -> list[str]:
    out = []
    if node.get("next") is not None:
        out.append(node["next"])
    for o in node.get("options", []):
        if "next" in o:
            out.append(o["next"])
    if isinstance(node.get("timeout"), dict) and "next" in node["timeout"]:
        out.append(node["timeout"]["next"])
    for c in node.get("cases", []):
        if "next" in c:
            out.append(c["next"])
    if "else" in node:
        out.append(node["else"])
    for item in node.get("items", []):
        if "next" in item:
            out.append(item["next"])
    for key in ("success", "fail"):
        if isinstance(node.get(key), dict) and "next" in node[key]:
            out.append(node[key]["next"])
    return out


def check_chapter(ctx: Context, path: Path, data: dict, decision_ids: dict, cfg: dict) -> None:
    rep = ctx.rep
    cid = data.get("id", path.stem)
    if data.get("id") != path.stem:
        rep.error(f"{path.name}: id '{data.get('id')}' must match file name")
    ctx.key(f"{cid}.title", data.get("title"))
    nodes = data.get("nodes")
    if not isinstance(nodes, dict) or not nodes:
        rep.error(f"{cid}: no nodes")
        return
    start = data.get("start")
    if start not in nodes:
        rep.error(f"{cid}: start node '{start}' does not exist")
    for ch in data.get("characters", []):
        if ch not in CHARACTERS:
            rep.error(f"{cid}: unknown character '{ch}'")

    major = 0
    has_end = False
    for nid, n in nodes.items():
        w = f"{cid}.{nid}"
        t = n.get("type")
        if t not in NODE_TYPES:
            rep.error(f"{w}: unknown node type '{t}'")
            continue
        if t not in ("end", "choice", "branch", "explore", "qte") and "next" not in n:
            rep.error(f"{w}: '{t}' node has no 'next' (dead end)")
        for nxt in next_ids(n):
            if nxt not in nodes:
                rep.error(f"{w}: broken link -> '{nxt}'")
        if "if" in n:
            check_condition(ctx, f"{w}.if", n["if"])
        if t == "line":
            speaker = n.get("speaker", "narrator")
            if speaker != "narrator" and speaker not in ctx.speakers:
                rep.error(f"{w}: unknown speaker '{speaker}'")
            ctx.key(w, n.get("text"))
            ctx.key(w, f"char.{speaker}")
            for i, v in enumerate(n.get("variants", [])):
                check_condition(ctx, f"{w}.variants[{i}].if", v.get("if"))
                ctx.key(f"{w}.variants[{i}]", v.get("text"))
        elif t == "choice":
            did = n.get("decision_id")
            if not did:
                rep.error(f"{w}: choice needs 'decision_id'")
            elif did in decision_ids:
                rep.error(f"{w}: duplicate decision id '{did}' (also in {decision_ids[did]})")
            else:
                decision_ids[did] = w
            if "prompt" in n:
                ctx.key(f"{w}.prompt", n["prompt"])
            opts = n.get("options", [])
            if not 2 <= len(opts) <= 4:
                rep.error(f"{w}: choice must have 2-4 options, has {len(opts)}")
            ids = [o.get("id") for o in opts]
            if len(set(ids)) != len(ids) or None in ids:
                rep.error(f"{w}: option ids must be unique and present")
            unconditional = 0
            for o in opts:
                ow = f"{w}.{o.get('id')}"
                ctx.key(ow, o.get("text"))
                if "next" not in o:
                    rep.error(f"{ow}: option has no 'next'")
                check_condition(ctx, f"{ow}.if", o.get("if"))
                check_effects(ctx, f"{ow}.effects", o.get("effects"))
                if "if" not in o:
                    unconditional += 1
            if unconditional < 2:
                rep.warn(f"{w}: fewer than 2 unconditional options; the choice may collapse")
            timer = n.get("timer", 8)
            if not _num(timer) or timer < 0:
                rep.error(f"{w}: invalid timer {timer}")
            if timer and timer > 0:
                to = n.get("timeout")
                if not isinstance(to, dict) or "next" not in to:
                    rep.error(f"{w}: timed choice needs a 'timeout' (silence) option with 'next'")
                else:
                    ctx.key(f"{w}.timeout", to.get("text", "dialogue.silence"))
                    check_effects(ctx, f"{w}.timeout.effects", to.get("effects"))
            if n.get("major"):
                major += 1
        elif t == "branch":
            if "else" not in n:
                rep.error(f"{w}: branch needs 'else'")
            for i, c in enumerate(n.get("cases", [])):
                check_condition(ctx, f"{w}.cases[{i}].if", c.get("if"))
        elif t == "effect":
            check_effects(ctx, f"{w}.effects", n.get("effects"))
        elif t == "location":
            ctx.key(w, n.get("location"))
            scene = n.get("scene", "")
            if scene:
                if scene not in ctx.locations:
                    rep.error(f"{w}: unknown location scene '{scene}' (data/locations/{scene}.json)")
                elif n.get("spawn", "default") not in ctx.locations[scene].get("spawns", {}):
                    rep.error(f"{w}: scene '{scene}' has no spawn '{n.get('spawn', 'default')}'")
                if n.get("player") not in CHARACTERS:
                    rep.error(f"{w}: 3D location needs a playable 'player', got {n.get('player')}")
        elif t == "explore":
            check_explore(ctx, w, n)
        elif t == "qte":
            if n.get("mode", "press") not in QTE_MODES:
                rep.error(f"{w}: unknown QTE mode '{n.get('mode')}'")
            if "prompt" in n:
                ctx.key(f"{w}.prompt", n["prompt"])
            if not _num(n.get("time", 2.0)) or n.get("time", 2.0) <= 0:
                rep.error(f"{w}: QTE needs positive 'time'")
            did = n.get("decision_id")
            if did:
                if did in decision_ids:
                    rep.error(f"{w}: duplicate decision id '{did}' (also in {decision_ids[did]})")
                decision_ids[did] = w
            for key in ("success", "fail"):
                b = n.get(key)
                if not isinstance(b, dict) or "next" not in b:
                    rep.error(f"{w}: QTE needs '{key}' with 'next'")
                else:
                    check_effects(ctx, f"{w}.{key}.effects", b.get("effects"))
        elif t == "end":
            has_end = True

    if not has_end:
        rep.error(f"{cid}: no 'end' node")
    if major < cfg.get("min_major_decisions_per_chapter", 2):
        rep.error(f"{cid}: only {major} major decision(s); need {cfg.get('min_major_decisions_per_chapter', 2)}")

    # Reachability from start.
    seen, stack = set(), [start]
    while stack:
        nid = stack.pop()
        if nid in seen or nid not in nodes:
            continue
        seen.add(nid)
        stack.extend(next_ids(nodes[nid]))
    for nid in nodes:
        if nid not in seen:
            rep.error(f"{cid}.{nid}: unreachable from start")
    # Every reachable node must be able to reach an end (no trap loops).
    can_end = {nid for nid, n in nodes.items() if n.get("type") == "end"}
    changed = True
    while changed:
        changed = False
        for nid, n in nodes.items():
            if nid not in can_end and any(x in can_end for x in next_ids(n)):
                can_end.add(nid)
                changed = True
    for nid in seen:
        if nid not in can_end:
            rep.error(f"{cid}.{nid}: can never reach an 'end' node")


# --------------------------------------------------------------------------- #
# Ending reachability
# --------------------------------------------------------------------------- #

def collect_domain(chapters: list[dict], flags: dict) -> dict:
    """Value domains each state variable can take, from all effects."""
    flag_vals = {k: {json.dumps(v)} for k, v in flags.items()}
    statuses = {c: {"alive"} for c in CHARACTERS}
    moods = {c: {"calm"} for c in CHARACTERS}
    trust_pos = {(a, b): 0 for a in CHARACTERS for b in CHARACTERS if a != b}
    trust_neg = dict(trust_pos)
    counter_max: dict[str, int] = {}
    decisions: dict[str, set] = {}

    def eat(effects):
        for e in effects or []:
            if "set_flag" in e and e["set_flag"] in flag_vals:
                flag_vals[e["set_flag"]].add(json.dumps(e.get("value", True)))
            elif "status" in e and e["status"] in statuses:
                statuses[e["status"]].add(e.get("value", "alive"))
            elif "mood" in e and e["mood"] in moods:
                moods[e["mood"]].add(e.get("value", "calm"))
            elif "add_counter" in e:
                counter_max[e["add_counter"]] = counter_max.get(e["add_counter"], 0) + max(0, int(e.get("delta", 1)))
            elif "trust" in e or "trust_mutual" in e:
                pair = e.get("trust") or e.get("trust_mutual")
                if not _valid_pair(pair):
                    continue
                d = int(e.get("delta", 0))
                pairs = [tuple(pair)] + ([(pair[1], pair[0])] if "trust_mutual" in e else [])
                for p in pairs:
                    if d > 0:
                        trust_pos[p] += d
                    else:
                        trust_neg[p] += d

    for ch in chapters:
        for n in ch.get("nodes", {}).values():
            eat(n.get("effects"))
            for it in n.get("items", []):
                eat(it.get("effects"))
            if n.get("type") == "qte":
                vals = decisions.setdefault(n.get("decision_id", ""), {""})
                vals.update({"success", "fail"})
                for key in ("success", "fail"):
                    eat((n.get(key) or {}).get("effects"))
            if n.get("type") == "choice":
                did = n.get("decision_id")
                vals = decisions.setdefault(did, {""})
                for o in n.get("options", []):
                    vals.add(o.get("id"))
                    eat(o.get("effects"))
                to = n.get("timeout")
                if isinstance(to, dict):
                    vals.add(to.get("id", "silence"))
                    counter_max["silence"] = counter_max.get("silence", 0) + 1
                    eat(to.get("effects"))
    trust_range = {p: (max(TRUST_MIN, trust_neg[p]), min(TRUST_MAX, trust_pos[p])) for p in trust_pos}
    return {
        "flags": {k: [json.loads(v) for v in sorted(vs)] for k, vs in flag_vals.items()},
        "statuses": {c: sorted(v) for c, v in statuses.items()},
        "moods": {c: sorted(v) for c, v in moods.items()},
        "trust": trust_range,
        "counters": counter_max,
        "decisions": {k: sorted(v) for k, v in decisions.items()},
    }


def winning_ending(rules: list[dict], s: State):
    fallback = None
    for r in rules:
        if r.get("fallback"):
            fallback = r
            continue
        if evaluate(r.get("condition"), s):
            return r
    return fallback


def check_endings(ctx: Context, endings: dict, chapters: list[dict], cfg: dict, seed: int = 7) -> dict:
    rep = ctx.rep
    rules = endings.get("endings", [])
    info = endings.get("ending_info", {})
    if not rules:
        rep.error("endings.json: no rules")
        return {}
    for r in rules:
        w = f"endings.{r.get('id')}"
        if r.get("ending") not in info:
            rep.error(f"{w}: ending '{r.get('ending')}' has no ending_info entry")
        check_condition(ctx, f"{w}.condition", r.get("condition"))
    fallbacks = [r for r in rules if r.get("fallback")]
    if len(fallbacks) != 1:
        rep.error(f"endings.json: need exactly one fallback rule, found {len(fallbacks)}")
    for eid, e in info.items():
        ctx.key(f"ending_info.{eid}.title", e.get("title"))
        ctx.key(f"ending_info.{eid}.description", e.get("description"))
    rules = sorted(rules, key=lambda r: r.get("priority", 0))

    dom = collect_domain(chapters, ctx.flags)
    rng = random.Random(seed)
    reached: dict[str, int] = {r.get("ending"): 0 for r in rules}
    witness: dict[str, dict] = {}

    def make_state(mode: str) -> State:
        s = State(ctx.flags)
        for c in CHARACTERS:
            s.status[c] = rng.choice(dom["statuses"][c])
            s.mood[c] = rng.choice(dom["moods"][c])
        for p, (lo, hi) in dom["trust"].items():
            s.trust[p] = hi if mode == "max" else lo if mode == "min" else rng.randint(lo, hi)
        for k, vals in dom["flags"].items():
            s.flags[k] = rng.choice(vals)
        for k, hi in dom["counters"].items():
            s.counters[k] = hi if mode == "max" else rng.randint(0, hi)
        for k, vals in dom["decisions"].items():
            s.decisions[k] = rng.choice(vals)
        return s

    for i in range(SAMPLES):
        mode = "max" if i % 10 == 0 else "min" if i % 10 == 1 else "rand"
        s = make_state(mode)
        r = winning_ending(rules, s)
        if r is None:
            continue
        e = r.get("ending")
        reached[e] = reached.get(e, 0) + 1
        if e not in witness:
            witness[e] = {"rule": r.get("id"), "alive": s.alive_count(), "avg_trust": round(s.avg_trust(), 2),
                          "flags": {k: v for k, v in s.flags.items() if v != ctx.flags.get(k)}}
    severity = cfg.get("ending_reachability", "error")
    for eid in info:
        if reached.get(eid, 0) == 0:
            rep.add(severity, f"ending '{eid}' is unreachable with the current chapter data")
    rep.info.append("ending reachability samples: " + ", ".join(f"{k}={v}" for k, v in sorted(reached.items())))
    return witness


# --------------------------------------------------------------------------- #

def check_locales(rep: Report, locales: dict) -> None:
    langs = list(locales)
    base = langs[0]
    for other in langs[1:]:
        for k in sorted(set(locales[base]) - set(locales[other])):
            rep.error(f"locale: key '{k}' missing in {other}.json")
        for k in sorted(set(locales[other]) - set(locales[base])):
            rep.error(f"locale: key '{k}' missing in {base}.json")
    for lang, table in locales.items():
        for k, v in table.items():
            if not isinstance(v, str) or (v.strip() == "" and k != "char.narrator"):
                rep.error(f"locale {lang}: empty text for '{k}'")
    for k in locales[base]:
        ph = {lang: set(PLACEHOLDER.findall(t.get(k, ""))) for lang, t in locales.items()}
        if len({frozenset(v) for v in ph.values()}) > 1:
            rep.error(f"locale: placeholder mismatch for '{k}': {ph}")


def scan_code_keys(root: Path) -> set[str]:
    """Locale keys referenced from GDScript (string literals that look like keys)."""
    keys = set()
    pat = re.compile(r'"((?:menu|slot|settings|pause|dialogue|summary|ui|confirm|game|lang|input|char|hud|journal|qte|flow)\.[a-z0-9_.]+)"')
    for f in root.rglob("*.gd"):
        keys.update(pat.findall(f.read_text(encoding="utf-8")))
    return keys


def validate(root: Path) -> tuple[Report, dict]:
    rep = Report()
    cfg = load_json(root / "tools" / "validator_config.json", Report()) or {}
    locales = {}
    for lang in cfg.get("locales", ["tr", "en"]):
        t = load_json(root / "data" / "locale" / f"{lang}.json", rep)
        if t is not None:
            locales[lang] = {k: v for k, v in t.items() if not k.startswith("_")}
    if len(locales) < 1:
        return rep, {}
    check_locales(rep, locales)
    flags_raw = load_json(root / "data" / "story_flags.json", rep) or {}
    flags = {k: (v.get("default") if isinstance(v, dict) else v) for k, v in flags_raw.items() if not k.startswith("_")}
    chars = load_json(root / "data" / "characters.json", rep) or {}
    speakers = set(chars.get("playable", {})) | set(chars.get("npc", {}))
    for c in CHARACTERS:
        if c not in chars.get("playable", {}):
            rep.error(f"characters.json: playable '{c}' missing")
    locations = {}
    for path in sorted((root / "data" / "locations").glob("*.json")):
        loc = load_json(path, rep)
        if loc is not None:
            locations[path.stem] = loc
            check_location(rep, path.stem, loc, speakers)
    ctx = Context(rep, locales, flags, speakers, locations)
    for cid, info in {**chars.get("playable", {}), **chars.get("npc", {})}.items():
        ctx.key(f"characters.{cid}", info.get("name"))

    index = load_json(root / "data" / "chapters" / "index.json", rep) or {}
    chapters = []
    decision_ids: dict[str, str] = {}
    listed = set()
    story_ids = {e.get("id") for e in index.get("chapters", [])}
    for entry in index.get("chapters", []) + index.get("test_chapters", []):
        cid = entry.get("id")
        listed.add(cid)
        ctx.key(f"index.{cid}.title", entry.get("title"))
        path = root / "data" / "chapters" / f"{cid}.json"
        data = load_json(path, rep)
        if data is None:
            continue
        check_chapter(ctx, path, data, decision_ids, cfg)
        if cid in story_ids:
            chapters.append(data)
        try:
            sim_report = story_sim.simulate(data, flags)
        except (KeyError, TypeError, AttributeError) as e:
            rep.error(f"{cid}: path simulation failed on malformed data ({e!r})")
            continue
        for msg in sim_report["unreachable"]:
            rep.add(cfg.get("path_reachability", "warning"), f"{cid}: {msg}")
        rep.info.append(f"{cid}: {sim_report['paths']} distinct play states explored, "
                        f"{len(sim_report['ends'])} reachable end node(s)")
    for path in sorted((root / "data" / "chapters").glob("*.json")):
        if path.stem != "index" and path.stem not in listed:
            rep.warn(f"{path.name}: chapter file not listed in index.json")

    for k in sorted(scan_code_keys(root)):
        ctx.key("code", k)

    endings = load_json(root / "data" / "endings.json", rep) or {}
    witness = check_endings(ctx, endings, chapters, cfg)

    unused = sorted(k for k in locales.get("tr", {}) if k not in ctx.used_keys
                    and not k.startswith(("input.", "lang.", "settings.", "menu.", "slot.", "confirm.",
                                          "pause.", "summary.", "ui.", "dialogue.", "game.", "char.",
                                          "hud.", "qte.", "flow.")))
    for k in unused:
        rep.warn(f"locale: key '{k}' is never referenced by data")
    rep.info.append(f"chapters: {len(chapters)}, decisions: {len(decision_ids)}, locale keys: {len(locales.get('tr', {}))}")
    return rep, witness


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    rep, witness = validate(Path(args.root))
    if args.json:
        print(json.dumps({"errors": rep.errors, "warnings": rep.warnings, "info": rep.info,
                          "ending_witness": witness}, ensure_ascii=False, indent=2))
    else:
        for m in rep.errors:
            print(f"ERROR   {m}")
        for m in rep.warnings:
            print(f"WARNING {m}")
        for m in rep.info:
            print(f"INFO    {m}")
        print(f"\n{len(rep.errors)} error(s), {len(rep.warnings)} warning(s)")
    return 1 if rep.errors else 0


if __name__ == "__main__":
    sys.exit(main())
