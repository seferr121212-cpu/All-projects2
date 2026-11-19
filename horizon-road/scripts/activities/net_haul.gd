class_name NetHaulActivity
extends Activity
## Hauling Hasan's net from the pier head: a gentle rhythm game. Pull when
## the marker sits in the green zone for a strong pull; a mistimed pull still
## helps a little. No timer, no failure. The catch is paid on delivery.

const FISH_COLORS: Dictionary = {
	"FISH_ISTAVRIT": Color(0.55, 0.62, 0.72), "FISH_BARBUN": Color(0.92, 0.45, 0.42),
	"FISH_CIPURA": Color(0.78, 0.78, 0.68), "FISH_LEVREK": Color(0.62, 0.66, 0.72),
	"FISH_LAGOS": Color(0.6, 0.42, 0.3),
}

@export var npc_id: StringName = &"hasan"
@export var buoy_start: Vector3 = Vector3(0, 0, 30)
@export var buoy_count: int = 8

var progress: float = 0.0
var hauling: bool = false
var catch: Array[String] = []
var _buoys: Array[Node3D] = []
var _spot := Interactable.new()
var _ui: CanvasLayer
var _bar: Control
var _marker: float = 0.0
var _zone_center: float = 0.5
var _zone_width: float = 0.22
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _splash: AudioStreamPlayer
var _label: Label


func _ready() -> void:
	super._ready()
	add_to_group(&"save_participant")
	activity_id = &"net_haul"
	_rng.randomize()
	_spot.prompt_key = "ACT_HAUL_NET"
	_spot.distance = 3.0
	_spot.enabled = false
	_spot.position = Vector3(0, 1.4, 0)
	_spot.interacted.connect(func(_by: Node3D) -> void: _start_hauling())
	add_child(_spot)
	_splash = AudioStreamPlayer.new()
	_splash.stream = ProceduralAudio.splash()
	_splash.bus = AudioManager.BUS_SFX
	add_child(_splash)
	_build_ui()


func begin() -> void:
	if active:
		return
	super.begin()
	progress = 0.0
	catch.clear()
	GameState.set_flag("%s.hauling" % npc_id)
	GameState.set_flag("%s.net_full" % npc_id, false)
	_spot.enabled = true
	_spawn_buoys()
	if not SaveManager.is_loading:
		GameState.notify(tr(&"ACT_NET_STARTED"))


func complete() -> int:
	var pay: int = 0
	for f: String in catch:
		pay += int(ECONOMY.fish_table[f][0])
	var full: bool = GameState.has_flag("%s.net_full" % npc_id)
	if full:
		pay += ECONOMY.net_completion_bonus
	if pay > 0:
		GameState.add_money(pay)
		GameState.add_relationship(npc_id, ECONOMY.points_job_done if full else ECONOMY.points_job_done / 2)
	GameState.set_counter("%s.hauls" % npc_id, GameState.get_counter("%s.hauls" % npc_id) + 1)
	GameState.set_flag("%s.hauling" % npc_id, false)
	GameState.set_flag("%s.net_full" % npc_id, false)
	_clear_buoys()
	_spot.enabled = false
	active = false
	finished.emit(pay)
	return pay


func get_status_text() -> String:
	if not active:
		return ""
	if GameState.has_flag("%s.net_full" % npc_id):
		return tr(&"ACT_NET_DONE") % catch.size()
	return tr(&"ACT_NET_PROGRESS") % [roundi(progress), ECONOMY.net_pulls]


## Strength of a pull at marker position m (0..1): strong inside the zone.
func pull_strength(m: float) -> float:
	return 1.0 if absf(m - _zone_center) <= _zone_width * 0.5 else 0.35


func pull() -> void:
	if not hauling:
		return
	var strength: float = pull_strength(_marker)
	progress = minf(progress + strength, float(ECONOMY.net_pulls))
	_splash.pitch_scale = _rng.randf_range(0.85, 1.15)
	_splash.play()
	_label.text = tr(&"ACT_NET_GOOD") if strength >= 1.0 else tr(&"ACT_NET_SOFT")
	# Next zone somewhere else, a little narrower as the net gets heavy.
	_zone_center = _rng.randf_range(0.2, 0.8)
	_zone_width = lerpf(0.24, 0.15, progress / ECONOMY.net_pulls)
	_update_buoys()
	if progress >= ECONOMY.net_pulls:
		_finish_haul()


func _start_hauling() -> void:
	if not active or GameState.has_flag("%s.net_full" % npc_id) or not GameState.is_gameplay():
		return
	hauling = true
	GameState.set_context(GameState.Context.MENU)
	var travel := get_tree().get_first_node_in_group(&"travel") as TravelController
	if travel:
		travel.suspend_control()
	_ui.visible = true
	_label.text = tr(&"ACT_NET_HELP")


func _stop_hauling() -> void:
	hauling = false
	_ui.visible = false
	GameState.set_context(GameState.Context.GAMEPLAY)
	var travel := get_tree().get_first_node_in_group(&"travel") as TravelController
	if travel:
		travel.restore_control()


func _finish_haul() -> void:
	var count: int = _rng.randi_range(ECONOMY.net_fish_min, ECONOMY.net_fish_max)
	for i: int in count:
		catch.append(_roll_fish())
	GameState.set_flag("%s.net_full" % npc_id)
	_stop_hauling()
	_show_catch()
	var names: PackedStringArray = []
	for f: String in catch:
		names.append(tr(StringName(f)))
	GameState.notify(tr(&"ACT_NET_CAUGHT") % ", ".join(names))


func _roll_fish() -> String:
	var total: float = 0.0
	for f: String in ECONOMY.fish_table:
		total += float(ECONOMY.fish_table[f][1])
	var roll: float = _rng.randf() * total
	for f: String in ECONOMY.fish_table:
		roll -= float(ECONOMY.fish_table[f][1])
		if roll <= 0.0:
			return f
	return "FISH_ISTAVRIT"


func _unhandled_input(event: InputEvent) -> void:
	if not hauling:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"handbrake") or event.is_action_pressed(&"ui_accept") \
			or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		pull()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		_stop_hauling()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	if hauling:
		# Marker sways back and forth; a little faster as the haul goes on.
		_marker = 0.5 + 0.5 * sin(_t * (2.2 + progress * 0.08))
		_bar.queue_redraw()
	for i: int in _buoys.size():
		_buoys[i].position.y = sin(_t * 1.3 + i) * 0.06


func _spawn_buoys() -> void:
	_clear_buoys()
	var mesh: Mesh = LowPolyMeshes.buoy()
	for i: int in buoy_count:
		var b := MeshInstance3D.new()
		b.mesh = mesh
		add_child(b)
		_buoys.append(b)
	_update_buoys()


func _update_buoys() -> void:
	# The float line curves in towards the pier as the net comes up.
	var k: float = progress / maxf(ECONOMY.net_pulls, 1)
	for i: int in _buoys.size():
		var a: float = (float(i) / maxf(_buoys.size() - 1, 1) - 0.5) * PI
		var radius: float = lerpf(14.0, 3.0, k)
		var center: Vector3 = buoy_start.lerp(Vector3(0, 0, 4), k)
		_buoys[i].position = center + Vector3(sin(a) * radius, 0, cos(a) * radius * 0.5)
		_buoys[i].visible = k < 0.98


func _show_catch() -> void:
	for i: int in catch.size():
		var f := MeshInstance3D.new()
		f.mesh = LowPolyMeshes.fish(FISH_COLORS.get(catch[i], Color.GRAY))
		f.position = Vector3(-0.8 + (i % 4) * 0.5, 1.15, -1.5 - (i / 4) * 0.4)
		f.rotation.y = _rng.randf_range(-0.4, 0.4)
		f.set_meta(&"catch", true)
		add_child(f)


func _clear_buoys() -> void:
	for b: Node3D in _buoys:
		b.queue_free()
	_buoys.clear()
	for c: Node in get_children():
		if c.has_meta(&"catch"):
			c.queue_free()


func save_key() -> String:
	return "net_haul"


func to_save() -> Dictionary:
	return {"active": active, "progress": progress, "catch": catch}


func from_save(data: Dictionary) -> void:
	_clear_buoys()
	active = false
	_spot.enabled = false
	if data.get("active", false):
		begin()
		progress = float(data.get("progress", 0.0))
		for f: Variant in data.get("catch", []):
			catch.append(String(f))
		if not catch.is_empty():
			GameState.set_flag("%s.net_full" % npc_id)
			_show_catch()
		_update_buoys()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 14
	_ui.visible = false
	add_child(_ui)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.97, 0.94, 0.88, 0.95)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(18)
	panel.add_theme_stylebox_override(&"panel", st)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_top = -190
	panel.offset_bottom = -60
	panel.offset_left = -360
	panel.offset_right = 360
	var col := VBoxContainer.new()
	var title := Label.new()
	title.text = "ACT_NET_TITLE"
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", Color(0.15, 0.3, 0.5))
	col.add_child(title)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(680, 34)
	_bar.draw.connect(_draw_bar)
	col.add_child(_bar)
	_label = Label.new()
	_label.add_theme_color_override(&"font_color", Color(0.3, 0.25, 0.2))
	col.add_child(_label)
	panel.add_child(col)
	_ui.add_child(panel)


func _draw_bar() -> void:
	var r := Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(r, Color(0.2, 0.45, 0.6))
	var zr := Rect2(Vector2((_zone_center - _zone_width * 0.5) * r.size.x, 0), Vector2(_zone_width * r.size.x, r.size.y))
	_bar.draw_rect(zr, Color(0.4, 0.8, 0.45))
	var x: float = _marker * r.size.x
	_bar.draw_rect(Rect2(Vector2(x - 4, -6), Vector2(8, r.size.y + 12)), Color(0.98, 0.95, 0.85))
	var k: float = progress / maxf(ECONOMY.net_pulls, 1)
	_bar.draw_rect(Rect2(Vector2(0, r.size.y - 5), Vector2(r.size.x * k, 5)), Color(0.95, 0.65, 0.2))
