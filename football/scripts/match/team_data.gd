class_name TeamData
extends RefCounted
## Kurgusal takım ve oyuncu verisi: data/teams.json + data/players.json.
## İsim, renk ve formasyon bu dosyalardan düzenlenebilir.

const TEAMS_PATH := "res://data/teams.json"
const PLAYERS_PATH := "res://data/players.json"
const STAT_KEYS := ["pace", "shooting", "passing", "dribbling", "defending", "physical", "goalkeeping"]

var id := ""
var display_name := ""
var short_name := ""
var color := Color.RED
var away_color := Color.WHITE
var goalkeeper_color := Color.YELLOW
var formation_id := "4-4-2"
var players: Array[PlayerStats] = []


static func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else null


static func team_ids() -> Array[String]:
	var out: Array[String] = []
	var data = _read_json(TEAMS_PATH)
	if typeof(data) == TYPE_DICTIONARY:
		for t in data.teams:
			out.append(t.id)
	return out


static func load_team(team_id: String) -> TeamData:
	var td := TeamData.new()
	td.id = team_id
	var data = _read_json(TEAMS_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("teams.json okunamadı")
		return td
	for t in data.teams:
		if t.id == team_id:
			td.display_name = t.name
			td.short_name = t.short
			td.color = Color.html(t.color)
			td.away_color = Color.html(t.away_color)
			td.goalkeeper_color = Color.html(t.goalkeeper_color)
			td.formation_id = t.formation
	var pdata = _read_json(PLAYERS_PATH)
	if typeof(pdata) == TYPE_DICTIONARY and pdata.has(team_id):
		for entry in pdata[team_id]:
			var st := PlayerStats.new()
			st.player_name = entry.name
			st.number = int(entry.number)
			st.position = entry.position
			for k in STAT_KEYS:
				st.set(k, int(entry[k]))
			td.players.append(st)
	if td.display_name == "":
		push_error("Takım bulunamadı: %s" % team_id)
	return td


## Formasyon slotlarına mevkiye göre oyuncu atar (önce aynı mevki, sonra en uygun kalan).
## Sonuç slot sırasıyla PlayerStats listesidir.
static func assign_to_formation(squad: Array[PlayerStats], roles: Array[String]) -> Array[PlayerStats]:
	var out: Array[PlayerStats] = []
	var used := {}
	for role in roles:
		var pick: PlayerStats = null
		for st in squad:
			if not used.has(st) and st.position == role:
				pick = st
				break
		if pick == null:
			for st in squad:
				if not used.has(st) and (st.position != "GK") == (role != "GK"):
					pick = st
					break
		if pick == null:
			for st in squad:
				if not used.has(st):
					pick = st
					break
		if pick == null:
			pick = PlayerStats.new()
		used[pick] = true
		out.append(pick)
	return out


## Renk çakışması: iki forma rengi çok yakınsa deplasman takımı ikinci formayı giyer.
static func kits_clash(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.35
