extends Control
## Takım seçimi + maç ayarları. Gösterilen alanlar moda göre değişir.

const FORMATIONS := ["", "4-4-2", "4-3-3", "4-2-3-1", "3-5-2", "5v5_2-1-1"]
const DIFFICULTIES := ["easy", "medium", "hard"]

var _team_ids: Array[String] = []
var _home: OptionButton
var _away: OptionButton
var _formation: OptionButton
var _control: OptionButton
var _half: SpinBox
var _difficulty: OptionButton
var _replay: CheckBox
var _time: OptionButton


func _ready() -> void:
	UIUtil.full_rect(self)
	UIUtil.background(self)
	var cfg := Game.default_config()
	cfg.merge(Game.match_config, true)
	_team_ids = TeamData.team_ids()
	var names := _team_ids.map(func(id: String) -> String: return TeamData.load_team(id).display_name)

	var col := UIUtil.centered_column(self, 12)
	col.add_child(UIUtil.title(tr("SELECT_TITLE"), 44))
	var panel := PanelContainer.new()
	col.add_child(panel)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 12)
	panel.add_child(form)

	var mode: int = Game.mode
	_home = UIUtil.option(names, _team_ids.find(cfg.home))
	form.add_child(UIUtil.row(tr("SELECT_HOME"), _home))
	_away = UIUtil.option(names, _team_ids.find(cfg.away))
	if mode != Game.Mode.TRAINING:
		form.add_child(UIUtil.row(tr("SELECT_AWAY"), _away))
	var form_names := FORMATIONS.map(func(f: String) -> String: return tr("SELECT_FORMATION_DEFAULT") if f == "" else f)
	_formation = UIUtil.option(form_names, FORMATIONS.find(cfg.formation))
	if mode == Game.Mode.QUICK_MATCH:
		form.add_child(UIUtil.row(tr("SELECT_FORMATION"), _formation))
	_control = UIUtil.option([tr("SELECT_CONTROL_HOME"), tr("SELECT_CONTROL_AWAY"), tr("SELECT_CONTROL_WATCH")], 2 if int(cfg.human_team) < 0 else int(cfg.human_team))
	if mode != Game.Mode.TRAINING:
		form.add_child(UIUtil.row(tr("SELECT_CONTROL"), _control))
	_half = SpinBox.new()
	_half.min_value = 2
	_half.max_value = 10
	_half.step = 1
	_half.value = float(cfg.half_minutes)
	if mode == Game.Mode.QUICK_MATCH:
		form.add_child(UIUtil.row(tr("SELECT_HALF_LENGTH"), _half))
	_difficulty = UIUtil.option([tr("DIFF_EASY"), tr("DIFF_MEDIUM"), tr("DIFF_HARD")], DIFFICULTIES.find(cfg.difficulty))
	form.add_child(UIUtil.row(tr("SELECT_DIFFICULTY"), _difficulty))
	_replay = CheckBox.new()
	_replay.button_pressed = bool(cfg.replay)
	if mode == Game.Mode.QUICK_MATCH:
		form.add_child(UIUtil.row(tr("SELECT_REPLAY"), _replay))

	_time = UIUtil.option([tr("TIME_DAY"), tr("TIME_NIGHT")], 1 if cfg.get("night", false) else 0)
	form.add_child(UIUtil.row(tr("SELECT_TIME"), _time))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(UIUtil.button(tr("MENU_BACK"), func() -> void: Game.go_main_menu(), 200))
	var start := UIUtil.button(tr("MENU_START"), _start, 200)
	buttons.add_child(start)
	col.add_child(buttons)
	start.grab_focus.call_deferred()


func config() -> Dictionary:
	var c := Game.default_config()
	c.home = _team_ids[maxi(_home.selected, 0)]
	c.away = _team_ids[maxi(_away.selected, 0)]
	c.formation = FORMATIONS[maxi(_formation.selected, 0)]
	c.human_team = -1 if _control.selected == 2 else _control.selected
	c.half_minutes = _half.value
	c.difficulty = DIFFICULTIES[maxi(_difficulty.selected, 0)]
	c.replay = _replay.button_pressed
	c.night = _time.selected == 1
	if Game.mode == Game.Mode.TRAINING:
		c.human_team = 0
	return c


func _start() -> void:
	Game.start(Game.mode, config())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.go_main_menu()
