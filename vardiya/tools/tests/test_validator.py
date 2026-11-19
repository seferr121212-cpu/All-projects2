"""Unit tests for tools/validate_data.py.  Run: python3 -m unittest discover tools/tests"""
import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import validate_data as vd  # noqa: E402


def _write(base: Path, rel: str, data) -> None:
    p = base / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")


def _copy_project(dst: Path) -> None:
    for rel in ["data/locale/tr.json", "data/locale/en.json", "data/story_flags.json",
                "data/endings.json", "data/chapters/index.json", "data/chapters/ch00_test.json",
                "tools/validator_config.json"]:
        _write(dst, rel, json.loads((ROOT / rel).read_text(encoding="utf-8")))


def _choice(did, options, major=True):
    return {"type": "choice", "decision_id": did, "major": major, "timer": 8, "prompt": "ch00.c01.prompt",
            "options": options, "timeout": {"id": "silence", "text": "dialogue.silence", "next": "end"}}


def _opt(oid, effects, nxt="end"):
    return {"id": oid, "text": "ch00.c01.truth", "next": nxt, "effects": effects}


class ValidatorTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        _copy_project(self.root)
        self.cfg = json.loads((self.root / "tools/validator_config.json").read_text())

    def tearDown(self):
        self._tmp.cleanup()

    def load(self, rel):
        return json.loads((self.root / rel).read_text(encoding="utf-8"))

    def save(self, rel, data):
        _write(self.root, rel, data)

    def strict(self):
        self.cfg["ending_reachability"] = "error"
        self.save("tools/validator_config.json", self.cfg)

    def test_real_project_has_no_errors(self):
        rep, _ = vd.validate(ROOT)
        self.assertEqual(rep.errors, [])

    def test_missing_translation_is_reported(self):
        en = self.load("data/locale/en.json")
        del en["ch00.l03"]
        self.save("data/locale/en.json", en)
        rep, _ = vd.validate(self.root)
        self.assertTrue(any("ch00.l03" in e and "en.json" in e for e in rep.errors), rep.errors)

    def test_placeholder_mismatch_is_reported(self):
        en = self.load("data/locale/en.json")
        en["slot.label"] = "Slot"
        self.save("data/locale/en.json", en)
        rep, _ = vd.validate(self.root)
        self.assertTrue(any("placeholder mismatch" in e for e in rep.errors), rep.errors)

    def test_broken_branch_is_reported(self):
        ch = self.load("data/chapters/ch00_test.json")
        ch["nodes"]["l02"]["next"] = "does_not_exist"
        self.save("data/chapters/ch00_test.json", ch)
        rep, _ = vd.validate(self.root)
        self.assertTrue(any("broken link" in e for e in rep.errors), rep.errors)

    def test_unreachable_node_and_trap_loop(self):
        ch = self.load("data/chapters/ch00_test.json")
        ch["nodes"]["orphan"] = {"type": "line", "speaker": "kemal", "text": "ch00.l03", "next": "end"}
        ch["nodes"]["l09_cold"]["next"] = "loop_a"
        ch["nodes"]["loop_a"] = {"type": "line", "speaker": "kemal", "text": "ch00.l03", "next": "loop_b"}
        ch["nodes"]["loop_b"] = {"type": "line", "speaker": "kemal", "text": "ch00.l03", "next": "loop_a"}
        self.save("data/chapters/ch00_test.json", ch)
        rep, _ = vd.validate(self.root)
        self.assertTrue(any("orphan: unreachable" in e for e in rep.errors), rep.errors)
        self.assertTrue(any("loop_a: can never reach" in e for e in rep.errors), rep.errors)

    def test_undeclared_flag_and_bad_option_count(self):
        ch = self.load("data/chapters/ch00_test.json")
        ch["nodes"]["c01"]["options"][0]["effects"].append({"set_flag": "no_such_flag", "value": True})
        ch["nodes"]["c02"]["options"] = ch["nodes"]["c02"]["options"][:1]
        self.save("data/chapters/ch00_test.json", ch)
        rep, _ = vd.validate(self.root)
        self.assertTrue(any("no_such_flag" in e for e in rep.errors), rep.errors)
        self.assertTrue(any("2-4 options" in e for e in rep.errors), rep.errors)

    def test_too_few_major_decisions(self):
        ch = self.load("data/chapters/ch00_test.json")
        ch["nodes"]["c02"]["major"] = False
        self.save("data/chapters/ch00_test.json", ch)
        rep, _ = vd.validate(self.root)
        self.assertTrue(any("major decision" in e for e in rep.errors), rep.errors)

    def test_unreachable_endings_caught_in_strict_mode(self):
        self.strict()
        rep, _ = vd.validate(self.root)
        unreachable = sorted(e for e in rep.errors if "unreachable with" in e)
        self.assertEqual(len(unreachable), 4, unreachable)
        self.assertFalse(any("'separation'" in e for e in unreachable))

    def _add_full_story_chapter(self):
        """A synthetic chapter whose effects can produce every ending."""
        nodes = {
            "c_a": _choice("t_trust", [
                _opt("up", [{"trust_mutual": ["kemal", "defne"], "delta": 5},
                            {"trust_mutual": ["kemal", "riza"], "delta": 5},
                            {"trust_mutual": ["defne", "riza"], "delta": 5}], "c_b"),
                _opt("down", [{"trust_mutual": ["kemal", "defne"], "delta": -5},
                              {"trust_mutual": ["kemal", "riza"], "delta": -5},
                              {"trust_mutual": ["defne", "riza"], "delta": -5}], "c_b")]),
            "c_b": _choice("t_fate", [
                _opt("inform", [{"set_flag": "informer", "value": "riza"}]),
                _opt("die", [{"status": "kemal", "value": "dead"}, {"status": "defne", "value": "dead"},
                             {"status": "riza", "value": "dead"}]),
                _opt("hush", [{"set_flag": "final_silence", "value": True}, {"add_counter": "silence", "delta": 6}])]),
            "end": {"type": "end", "next_chapter": None},
        }
        nodes["c_a"]["timeout"]["next"] = "c_b"
        ch = {"id": "ch99_fixture", "title": "ch00.title", "characters": vd.CHARACTERS, "start": "c_a", "nodes": nodes}
        self.save("data/chapters/ch99_fixture.json", ch)
        idx = self.load("data/chapters/index.json")
        idx["chapters"].append({"id": "ch99_fixture", "title": "ch00.title"})
        self.save("data/chapters/index.json", idx)

    def test_all_endings_reachable_with_full_story(self):
        self.strict()
        self._add_full_story_chapter()
        rep, witness = vd.validate(self.root)
        self.assertEqual([e for e in rep.errors if "unreachable with" in e], [])
        self.assertEqual(set(witness), {"solidarity", "separation", "bitter_reckoning", "betrayal", "secret"})

    def test_shadowed_ending_is_caught(self):
        """A rule that can never win because a higher-priority rule always wins first."""
        self.strict()
        self._add_full_story_chapter()
        endings = self.load("data/endings.json")
        for r in endings["endings"]:
            if r["id"] == "r_secret":
                r["priority"] = 95  # after the always-matching separation rule set below
            if r["id"] == "r_separation":
                r["condition"] = {}
        self.save("data/endings.json", endings)
        rep, _ = vd.validate(self.root)
        self.assertTrue(any("'secret' is unreachable" in e for e in rep.errors), rep.errors)

    def test_evaluator_semantics(self):
        s = vd.State({"informer": "", "harm_done": False})
        s.trust[("kemal", "defne")] = 4
        self.assertTrue(vd.evaluate({"trust": ["kemal", "defne"], "gte": 4}, s))
        self.assertTrue(vd.evaluate({"flag": "informer", "eq": ""}, s))
        self.assertFalse(vd.evaluate({"flag": "harm_done"}, s))
        self.assertTrue(vd.evaluate({"not": {"flag": "harm_done"}}, s))
        s.status["riza"] = "dead"
        self.assertTrue(vd.evaluate({"all": [{"alive_count": True, "eq": 2}, {"dead_count": True, "gte": 1}]}, s))
        # avg trust only over living pairs: kemal->defne=4, defne->kemal=0
        self.assertAlmostEqual(s.avg_trust(), 2.0)
        self.assertTrue(vd.evaluate({"decision": "x", "in": ["", "a"]}, s))


if __name__ == "__main__":
    unittest.main()
