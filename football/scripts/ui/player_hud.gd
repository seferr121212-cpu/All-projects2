extends CanvasLayer
## Basit oyuncu HUD'u: kontrol edilen oyuncu, stamina ve şut güç barı.

@export var team_path: NodePath

var team: Team
var _info: Label
var _stamina: ProgressBar
var _power: ProgressBar


func _ready() -> void:
	if team == null and not team_path.is_empty():
		team = get_node_or_null(team_path) as Team
	var box := VBoxContainer.new()
	box.position = Vector2(12, 12)
	box.custom_minimum_size = Vector2(260, 0)
	add_child(box)
	_info = Label.new()
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 4)
	box.add_child(_info)
	_stamina = _make_bar(box, tr("HUD_STAMINA"), Color(0.2, 0.8, 0.3))
	_power = _make_bar(box, tr("HUD_SHOT_POWER"), Color(0.95, 0.6, 0.1))


func _make_bar(parent: Control, title: String, color: Color) -> ProgressBar:
	var l := Label.new()
	l.text = title
	parent.add_child(l)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240, 14)
	bar.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	bar.add_theme_stylebox_override("fill", sb)
	parent.add_child(bar)
	return bar


func _process(_delta: float) -> void:
	if team == null or team.controlled == null:
		return
	var p := team.controlled
	var owner_name := "-"
	if p.possession and p.possession.owner_player:
		owner_name = p.possession.owner_player.stats.player_name
	_info.text = (tr("HUD_CONTROL") % [p.stats.player_name, p.stats.number]) + "\n" + (tr("HUD_BALL") % owner_name)
	_stamina.value = p.stamina / p.stats.max_stamina * 100.0
	_power.value = maxf(p.shot_charge, 0.0) * 100.0
