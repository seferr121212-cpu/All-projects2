extends CanvasLayer
## Maç HUD'u: skor tablosu + süre (üst orta) ve kısa olay bildirimleri (orta).

var flow: MatchFlow
var _score: Label
var _banner: Label
var _banner_time := 0.0
var _prompt: Label


func _ready() -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-180, 10)
	top.custom_minimum_size = Vector2(360, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	top.add_theme_stylebox_override("panel", sb)
	add_child(top)
	_score = Label.new()
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.add_theme_font_size_override("font_size", 22)
	top.add_child(_score)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-300, -120)
	_banner.custom_minimum_size = Vector2(600, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 8)
	add_child(_banner)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-400, -90)
	_prompt.custom_minimum_size = Vector2(800, 0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)
	add_child(_prompt)
	if flow:
		flow.message.connect(show_message)


## İnsan oyuncunun yapacağı duran top / başlama vuruşu için ipucu.
func _prompt_text() -> String:
	if flow.state != MatchFlow.MatchState.KICKOFF and flow.state != MatchFlow.MatchState.SET_PIECE:
		return ""
	var t: Team = flow.teams[flow.restart_team]
	if not t.human or flow.taker == null or flow.taker.is_goalkeeper or t.controlled != flow.taker:
		return ""
	return tr("HUD_KICKOFF_PROMPT") if flow.state == MatchFlow.MatchState.KICKOFF else tr("HUD_KICK_PROMPT")


func show_message(text: String, color: Color) -> void:
	_banner.text = text
	_banner.modulate = color
	_banner_time = 2.5


func _process(delta: float) -> void:
	if flow == null:
		return
	_score.text = "%s  %d - %d  %s     %d'" % [flow.teams[0].name, flow.score[0], flow.score[1], flow.teams[1].name, flow.game_minute()]
	_prompt.text = _prompt_text()
	_banner_time -= delta
	_banner.modulate.a = clampf(_banner_time, 0.0, 1.0)
