"""Unit tests for tools/validate_data.py.  Run: python3 -m unittest discover tools/tests"""
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import validate_data as vd  # noqa: E402
import story_sim  # noqa: E402


def _write(base: Path, rel: str, data) -> None:
    p = base / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")


def _copy_project(dst: Path) -> None:
    shutil.copytree(ROOT / "data", dst / "data")
    _write(dst, "tools/validator_config.json", json.loads((ROOT / "tools/validator_config.json").read_text()))


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
        rep, _ = vd.validate(ROOT, game_sim=False)
        self.assertEqual(rep.errors, [])

    def test_missing_translation_is_reported(self):
        en = self.load("data/locale/en.json")
        del en["ch00.l03"]
        self.save("data/locale/en.json", en)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("ch00.l03" in e and "en.json" in e for e in rep.errors), rep.errors)

    def test_placeholder_mismatch_is_reported(self):
        en = self.load("data/locale/en.json")
        en["slot.label"] = "Slot"
        self.save("data/locale/en.json", en)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("placeholder mismatch" in e for e in rep.errors), rep.errors)

    def test_broken_branch_is_reported(self):
        ch = self.load("data/chapters/ch00_test.json")
        ch["nodes"]["l02"]["next"] = "does_not_exist"
        self.save("data/chapters/ch00_test.json", ch)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("broken link" in e for e in rep.errors), rep.errors)

    def test_unreachable_node_and_trap_loop(self):
        ch = self.load("data/chapters/ch00_test.json")
        ch["nodes"]["orphan"] = {"type": "line", "speaker": "kemal", "text": "ch00.l03", "next": "end"}
        ch["nodes"]["l09_cold"]["next"] = "loop_a"
        ch["nodes"]["loop_a"] = {"type": "line", "speaker": "kemal", "text": "ch00.l03", "next": "loop_b"}
        ch["nodes"]["loop_b"] = {"type": "line", "speaker": "kemal", "text": "ch00.l03", "next": "loop_a"}
        self.save("data/chapters/ch00_test.json", ch)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("orphan: unreachable" in e for e in rep.errors), rep.errors)
        self.assertTrue(any("loop_a: can never reach" in e for e in rep.errors), rep.errors)

    def test_undeclared_flag_and_bad_option_count(self):
        ch = self.load("data/chapters/ch00_test.json")
        ch["nodes"]["c01"]["options"][0]["effects"].append({"set_flag": "no_such_flag", "value": True})
        ch["nodes"]["c02"]["options"] = ch["nodes"]["c02"]["options"][:1]
        self.save("data/chapters/ch00_test.json", ch)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("no_such_flag" in e for e in rep.errors), rep.errors)
        self.assertTrue(any("2-4 options" in e for e in rep.errors), rep.errors)

    def test_too_few_major_decisions(self):
        ch = self.load("data/chapters/ch00_test.json")
        ch["nodes"]["c02"]["major"] = False
        self.save("data/chapters/ch00_test.json", ch)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("major decision" in e for e in rep.errors), rep.errors)

    def test_unreachable_endings_caught_in_strict_mode(self):
        self.strict()
        ch = self.load("data/chapters/ch06_informant.json")
        ch["nodes"]["c01"]["options"] = [o for o in ch["nodes"]["c01"]["options"] if o["id"] != "inform"]
        self.save("data/chapters/ch06_informant.json", ch)
        rep, _ = vd.validate(self.root, game_sim=False)
        unreachable = [e for e in rep.errors if "unreachable" in e and "ending" in e]
        self.assertEqual(len(unreachable), 1, unreachable)
        self.assertIn("'betrayal'", unreachable[0])

    def test_death_without_later_impact_is_an_error(self):
        for cid in ["ch06_informant", "ch07_reckoning", "ch08_last_shift"]:
            ch = self.load(f"data/chapters/{cid}.json")
            text = json.dumps(ch).replace('"status": "riza"', '"status": "kemal"')
            self.save(f"data/chapters/{cid}.json", json.loads(text))
        ch = self.load("data/chapters/ch05_night_shift.json")
        text = json.dumps(ch).replace('"status": "riza", "eq"', '"status": "kemal", "eq"')
        self.save("data/chapters/ch05_night_shift.json", json.loads(text))
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("'riza' can die" in e for e in rep.errors), rep.errors)

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
        rep, witness = vd.validate(self.root, game_sim=False)
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
        rep, _ = vd.validate(self.root, game_sim=False)
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


    def test_copied_project_is_clean(self):
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertEqual(rep.errors, [])

    def test_explore_item_without_point_or_actor(self):
        ch = self.load("data/chapters/ch01_last_check.json")
        ch["nodes"]["x02"]["items"][0]["id"] = "ch01_nowhere"
        ch["nodes"]["x02"]["items"][3]["actor"] = "ghost"
        self.save("data/chapters/ch01_last_check.json", ch)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("no point 'ch01_nowhere'" in e for e in rep.errors), rep.errors)
        self.assertTrue(any("actor 'ghost'" in e for e in rep.errors), rep.errors)

    def test_unknown_scene_and_spawn(self):
        ch = self.load("data/chapters/ch01_last_check.json")
        ch["nodes"]["loc_floor"]["spawn"] = "nope"
        ch["nodes"]["loc_cell"]["scene"] = "moon_base"
        self.save("data/chapters/ch01_last_check.json", ch)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("no spawn 'nope'" in e for e in rep.errors), rep.errors)
        self.assertTrue(any("unknown location scene 'moon_base'" in e for e in rep.errors), rep.errors)

    def test_qte_needs_both_branches(self):
        ch = self.load("data/chapters/ch01_last_check.json")
        del ch["nodes"]["q01"]["fail"]
        self.save("data/chapters/ch01_last_check.json", ch)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("QTE needs 'fail'" in e for e in rep.errors), rep.errors)

    def test_simulator_flags_option_that_can_never_appear(self):
        ch = self.load("data/chapters/ch01_last_check.json")
        ch["nodes"]["c01"]["options"][0]["if"] = {"found": "ch01_item_that_does_not_exist"}
        self.save("data/chapters/ch01_last_check.json", ch)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("c01.warn' can never be offered" in w for w in rep.warnings), rep.warnings)

    def test_simulator_covers_every_chapter1_branch(self):
        flags = {k: (v["default"] if isinstance(v, dict) else v)
                 for k, v in json.loads((ROOT / "data/story_flags.json").read_text()).items() if not k.startswith("_")}
        ch = json.loads((ROOT / "data/chapters/ch01_last_check.json").read_text())
        r = story_sim.simulate(ch, flags)
        self.assertEqual(r["unreachable"], [])
        self.assertIn("end", r["ends"])

    def test_simulator_conditional_option_needs_exploration(self):
        """'warn' Selim is only offered if the layoff list was examined."""
        flags = {"selim_warned": False}
        ch = json.loads((ROOT / "data/chapters/ch01_last_check.json").read_text())
        for it in ch["nodes"]["x02"]["items"]:
            if it["id"] == "ch01_layoff_list":
                it["if"] = {"flag": "selim_warned"}  # make the list impossible to find
        r = story_sim.simulate(ch, flags)
        self.assertTrue(any("c01.warn" in m for m in r["unreachable"]))
        self.assertTrue(any("c01.hint" in m for m in r["unreachable"]))


    def test_walkability_catches_blocked_spawn_and_point(self):
        loc = self.load("data/locations/factory_locker.json")
        loc["boxes"].append({"pos": [0, 1.0, 2.2], "size": [10, 2.0, 0.4], "color": "#000000"})
        loc["spawns"]["default"]["pos"] = [-3.6, 0, -3.2]
        self.save("data/locations/factory_locker.json", loc)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("spawn 'default' is inside geometry" in e for e in rep.errors), rep.errors)
        loc["spawns"]["default"]["pos"] = [-3.2, 0, 1.0]
        self.save("data/locations/factory_locker.json", loc)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("ch01_locker_door' cannot be reached" in e for e in rep.errors), rep.errors)


    def test_game_simulation_reaches_every_ending(self):
        """Full playthrough simulation of chapters 1-8 (slow: about a minute)."""
        rep, witness = vd.validate(ROOT, game_sim=True)
        self.assertEqual(rep.errors, [])
        self.assertEqual(set(witness), {"solidarity", "separation", "bitter_reckoning", "betrayal", "secret"})
        for e, w in witness.items():
            self.assertTrue(w["path"][-1].startswith("[ch08"), (e, w["path"][-3:]))
        played = [m for m in rep.info if m.startswith("ep0") and "played from" in m]
        self.assertEqual(len(played), 5, played)

    def test_every_ending_needs_an_epilogue(self):
        endings = self.load("data/endings.json")
        endings["ending_info"]["secret"]["epilogue"] = "ep99_nowhere"
        self.save("data/endings.json", endings)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("ending_info.secret: epilogue 'ep99_nowhere'" in e for e in rep.errors), rep.errors)
        self.assertTrue(any("epilogue 'ep05_secret' belongs to no ending" in w for w in rep.warnings), rep.warnings)

    def test_ending_link_only_in_last_story_chapter(self):
        ch = self.load("data/chapters/ch07_reckoning.json")
        ch["nodes"]["end"]["next_chapter"] = "@ending"
        self.save("data/chapters/ch07_reckoning.json", ch)
        ch8 = self.load("data/chapters/ch08_last_shift.json")
        ch8["nodes"]["end"]["next_chapter"] = None
        self.save("data/chapters/ch08_last_shift.json", ch8)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("ch07_reckoning.end: next_chapter '@ending' should be" in e for e in rep.errors), rep.errors)
        self.assertTrue(any("ch08_last_shift.end: the last story chapter must end" in e for e in rep.errors), rep.errors)

    def test_epilogue_must_end_the_game(self):
        ep = self.load("data/chapters/ep01_solidarity.json")
        ep["nodes"]["end"]["next_chapter"] = "ch01_last_check"
        self.save("data/chapters/ep01_solidarity.json", ep)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("ep01_solidarity.end: an epilogue must end the game" in e for e in rep.errors), rep.errors)

    def test_epilogues_are_exempt_from_major_rule_but_story_is_not(self):
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertFalse(any(e.startswith("ep0") and "major decision" in e for e in rep.errors))

    def test_epilogue_pov_on_dead_character_is_caught(self):
        """Epilogues are played from the final game states; a POV given to the dead must be reported."""
        flags = {"pov": "", "ending": ""}
        ep = {"id": "ep_t", "start": "a", "nodes": {
            "a": {"type": "location", "location": "x", "scene": "s", "spawn": "default", "player": "kemal", "next": "e"},
            "e": {"type": "end", "next_chapter": None}}}
        st = story_sim._vd().State(flags)
        st.status["kemal"] = "dead"
        r = story_sim.simulate(ep, flags, start_states=[(st, [])])
        self.assertTrue(r["pov_errors"] or any("dead/missing 'kemal'" in m for m in r["unreachable"]), r)

    def test_simulator_reports_dead_pov(self):
        flags = {"pov": ""}
        ch = {"id": "t", "start": "a", "nodes": {
            "a": {"type": "effect", "effects": [{"status": "riza", "value": "dead"}], "next": "b"},
            "b": {"type": "location", "location": "x", "scene": "s", "spawn": "default", "player": "riza", "next": "e"},
            "e": {"type": "end", "next_chapter": None}}}
        r = story_sim.simulate(ch, flags)
        self.assertTrue(any("dead/missing 'riza' in control" in m for m in r["unreachable"]))


    # --- Stage 6: art schema -------------------------------------------------------

    def _loc_errors(self, name, mutate):
        loc = self.load(f"data/locations/{name}.json")
        mutate(loc)
        self.save(f"data/locations/{name}.json", loc)
        rep, _ = vd.validate(self.root, game_sim=False)
        return rep.errors

    def test_unknown_prop_kind_and_material(self):
        def m(loc):
            loc["boxes"][0]["kind"] = "spaceship"
            loc["boxes"][1]["mat"] = "gold"
        errs = self._loc_errors("police_room", m)
        self.assertTrue(any("unknown prop kind 'spaceship'" in e for e in errs), errs)
        self.assertTrue(any("unknown material 'gold'" in e for e in errs), errs)

    def test_light_and_particle_budgets(self):
        def m(loc):
            loc["lights"] = [dict(loc["lights"][0]) for _ in range(5)]
            loc["particles"] = [{"type": "dust", "pos": [0, 1, 0], "extent": [1, 1, 1]}] * 5
        errs = self._loc_errors("police_room", m)
        self.assertTrue(any("exceed the budget of 4" in e and "omni lights" in e for e in errs), errs)
        self.assertTrue(any("particle systems exceed" in e for e in errs), errs)

    def test_variant_checks_condition_and_keys(self):
        def m(loc):
            loc["variants"] = [{"if": {"flag": "no_such_flag"}, "set": {"boxes": [], "particles": [{"type": "rain"}]}}]
        errs = self._loc_errors("police_room", m)
        self.assertTrue(any("undeclared flag 'no_such_flag'" in e for e in errs), errs)
        self.assertTrue(any("cannot be changed by a variant" in e for e in errs), errs)
        self.assertTrue(any("unknown particle type 'rain'" in e for e in errs), errs)

    def test_fire_must_not_collide_and_box_inside_room(self):
        def m(loc):
            loc["boxes"].append({"kind": "fire", "pos": [0, 1, 0], "size": [1, 1, 0.2], "color": "#ff6a1a"})
            loc["boxes"].append({"pos": [40, 1, 0], "size": [1, 1, 1], "color": "#808080", "collide": False})
        errs = self._loc_errors("police_room", m)
        self.assertTrue(any("fire must not collide" in e for e in errs), errs)
        self.assertTrue(any("outside the room" in e for e in errs), errs)

    def test_character_look_is_checked(self):
        chars = self.load("data/characters.json")
        chars["playable"]["kemal"]["look"]["hair_style"] = "mohawk"
        chars["npc"]["selim"]["look"]["height"] = 2.5
        self.save("data/characters.json", chars)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("unknown 'mohawk'" in e for e in rep.errors), rep.errors)
        self.assertTrue(any("selim.look.height" in e for e in rep.errors), rep.errors)

    # --- Stage 7: audio ids, play time ------------------------------------------------

    def test_unknown_ambience_and_music_are_reported(self):
        def m(loc):
            loc["ambience"] = "jungle"
        errs = self._loc_errors("police_room", m)
        self.assertTrue(any("unknown ambience 'jungle'" in e for e in errs), errs)
        idx = self.load("data/chapters/index.json")
        idx["chapters"][0]["music"] = "disco"
        self.save("data/chapters/index.json", idx)
        rep, _ = vd.validate(self.root, game_sim=False)
        self.assertTrue(any("unknown music 'disco'" in e for e in rep.errors), rep.errors)

    def test_audio_file_counts_as_known_id(self):
        (self.root / "assets/audio/ambience").mkdir(parents=True)
        (self.root / "assets/audio/ambience/jungle.ogg").write_bytes(b"")

        def m(loc):
            loc["ambience"] = "jungle"
        errs = self._loc_errors("police_room", m)
        self.assertFalse(any("jungle" in e for e in errs), errs)

    def test_playtime_estimate_covers_every_chapter(self):
        import playtime
        res = playtime.estimate(ROOT, runs=20)
        idx = json.loads((ROOT / "data/chapters/index.json").read_text(encoding="utf-8"))
        for prof in ("quick", "careful"):
            chapters = res[prof]["chapters"]
            for e in idx["chapters"]:
                self.assertGreater(chapters[e["id"]], 0.5, (prof, e["id"]))
            self.assertIn("epilogue", chapters)
        self.assertGreater(res["careful"]["minutes_mean"], res["quick"]["minutes_mean"])

    def test_playtime_skips_lines_whose_condition_fails(self):
        import playtime
        texts = {"k.a": "bir iki üç dört beş altı yedi sekiz dokuz on", "k.b": "x"}
        ch = {"start": "a", "nodes": {
            "a": {"type": "line", "speaker": "narrator", "text": "k.a", "next": "b", "if": {"flag": "never", "eq": True}},
            "b": {"type": "line", "speaker": "narrator", "text": "k.b", "next": "end"},
            "end": {"type": "end", "next_chapter": ""}}}
        clock = playtime.Clock(texts, playtime.PROFILES["careful"])
        playtime.play_chapter(ch, vd.State({"never": False}), clock, playtime.PROFILES["careful"], __import__("random").Random(1))
        self.assertEqual(clock.words, 1)

    def test_sampler_keeps_every_life_status(self):
        import story_sim
        rel = {"moods": set(), "counters": {}, "decisions": set(), "found": set(), "flags": {f"f{i}" for i in range(50)}}
        states = []
        for i in range(400):
            st = vd.State({f"f{j}": False for j in range(50)})
            for j in range(50):
                st.flags[f"f{j}"] = bool((i >> (j % 9)) & 1)
            states.append((st, []))
        lone = vd.State({f"f{j}": False for j in range(50)})
        lone.status = {"kemal": "dead", "defne": "dead", "riza": "dead"}
        states.append((lone, []))
        kept = story_sim._reduce(states, rel, cap=5)
        self.assertTrue(any(st.status["kemal"] == "dead" for st, _ in kept))

    def test_locale_passes_text_lint(self):
        import text_lint
        found = text_lint.lint(text_lint.load("tr"), text_lint.load("en"))
        self.assertEqual(found, [], found[:10])

    def test_text_lint_catches_emoji_and_long_lines(self):
        import text_lint
        tr = {"ch09.l01": "Merhaba ❤", "ch09.l02": "a" * 400 + "."}
        en = {"ch09.l01": "Hello ❤", "ch09.l02": "b."}
        found = text_lint.lint(tr, en)
        self.assertTrue(any("glyphs" in f for f in found), found)
        self.assertTrue(any("longer than the subtitle box" in f for f in found), found)


if __name__ == "__main__":
    unittest.main()
