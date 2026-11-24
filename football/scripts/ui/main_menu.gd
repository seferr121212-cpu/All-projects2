extends Control
## Ana menü: Hızlı Maç, Penaltı Atışları, Antrenman, Ayarlar, Çıkış.

var _first: Button


func _ready() -> void:
	UIUtil.full_rect(self)
	UIUtil.background(self)
	var col := UIUtil.centered_column(self, 16)
	col.add_child(UIUtil.title(tr("MENU_TITLE"), 72))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	col.add_child(spacer)
	_first = UIUtil.button(tr("MENU_QUICK_MATCH"), func() -> void: Game.open_team_select(Game.Mode.QUICK_MATCH))
	col.add_child(_first)
	col.add_child(UIUtil.button(tr("MENU_PENALTIES"), func() -> void: Game.open_team_select(Game.Mode.PENALTIES)))
	col.add_child(UIUtil.button(tr("MENU_TRAINING"), func() -> void: Game.open_team_select(Game.Mode.TRAINING)))
	col.add_child(UIUtil.button(tr("MENU_SETTINGS"), func() -> void: Game.open_settings()))
	col.add_child(UIUtil.button(tr("MENU_QUIT"), func() -> void: get_tree().quit()))
	_first.grab_focus.call_deferred() # gamepad ile gezinme
