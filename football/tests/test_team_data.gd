extends "res://tests/test_case.gd"
## Faz 6: formasyonlar, takım/oyuncu verisi, 11'e 11 dizilişi.

const ELEVEN := ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2"]


func test_all_formations_have_eleven() -> void:
	for id in ELEVEN:
		var f := Formation.load_formation(id)
		check(f.slots.size() == 11, "%s 11 slot olmalı (%d)" % [id, f.slots.size()])
		check(f.roles.count("GK") == 1 and f.roles[0] == "GK", "%s tek kaleci, ilk slot" % id)
		for s in f.slots:
			check(absf(s.x) <= 1.0 and absf(s.y) <= 1.0, "%s slotlar normalize aralıkta" % id)


func test_teams_and_players_load() -> void:
	var ids := TeamData.team_ids()
	check(ids.size() >= 4, "En az 4 kurgusal takım (%d)" % ids.size())
	var names := {}
	for id in ids:
		var td := TeamData.load_team(id)
		check(td.display_name != "" and td.players.size() >= 11, "%s: ad ve en az 11 oyuncu" % id)
		check(Formation.load_formation(td.formation_id).slots.size() == 11, "%s: geçerli formasyon" % id)
		for st in td.players:
			check(not names.has(st.player_name), "Oyuncu adı tekrar etmemeli: %s" % st.player_name)
			names[st.player_name] = true
			for k in TeamData.STAT_KEYS:
				var v: int = st.get(k)
				check(v >= 1 and v <= 99, "%s %s 1-99 aralığında" % [st.player_name, k])


func test_lineup_respects_positions() -> void:
	var td := TeamData.load_team("kuzey")
	for id in ELEVEN:
		var f := Formation.load_formation(id)
		var lineup := TeamData.assign_to_formation(td.players, f.roles)
		check(lineup.size() == 11, "%s: 11 oyuncu" % id)
		check(lineup[0].position == "GK", "%s: ilk slot kaleci" % id)
		var unique := {}
		for i in lineup.size():
			unique[lineup[i]] = true
			if f.roles[i] != "GK":
				check(lineup[i].position != "GK", "%s: saha slotuna kaleci konmamalı" % id)
		check(unique.size() == 11, "%s: aynı oyuncu iki kez seçilmemeli" % id)


func test_kit_clash() -> void:
	check(TeamData.kits_clash(Color(0.8, 0.1, 0.1), Color(0.85, 0.15, 0.12)), "Benzer kırmızılar çakışır")
	check(not TeamData.kits_clash(Color(0.8, 0.1, 0.1), Color(0.1, 0.3, 0.8)), "Kırmızı-mavi çakışmaz")


func test_eleven_a_side_match_setup() -> void:
	var m = preload("res://scenes/match.tscn").instantiate()
	m.human_team = -1
	m.replay_enabled = false
	add_child(m)
	check(m.home.players.size() == 11 and m.away.players.size() == 11, "İki takım da 11 kişi")
	check(m.home.team_name == "Kuzey Yıldızları", "Takım adı veriden gelmeli")
	await step_physics(120 * 8)
	var flow: MatchFlow = m.flow
	check(flow.state != MatchFlow.MatchState.KICKOFF, "11'e 11 maç başlamalı (durum %d)" % flow.state)
	# Savunmada savunma hattı aynı hizada
	var ai: TeamAI = m.home_ai if flow.possession.owner_player and flow.possession.owner_player.team_id == 1 else m.away_ai
	ai.phase = Formation.Phase.DEFENSE
	ai._update_defensive_line()
	var xs := []
	for p in ai.team.players:
		if ai.ais[p].position_role == "DEF":
			xs.append(ai._formation_point(p).x)
	check(xs.size() >= 3 and absf(xs.max() - xs.min()) < 0.01, "Savunmacılar aynı hizada olmalı %s" % str(xs))
	await clear_children()
