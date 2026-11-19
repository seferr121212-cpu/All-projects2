class_name TravellingCafe
extends Node3D
## Gezici kafe: with the café kit, park the camper, open the awning at its
## back and serve locals who wander over. Each customer asks for something
## from the region's menu; pick it from the counter menu. Quick service earns
## a tip. No failure: a wrong pick just gets a smile and a second try.

signal session_ended(earned: int)

const WALK_SPEED: float = 1.3

var open: bool = false
var served: int = 0
var earned: int = 0
var customers: Array[Dictionary] = []
var _to_spawn: int = 0
var _spawn_t: float = 0.0
var _travel: TravelController
var _open_spot := Interactable.new()
var _counter := Interactable.new()
var _props: Node3D
var _ui: CanvasLayer
var _menu_box: VBoxContainer
var _menu_title: Label
var _rng := RandomNumberGenerator.new()
var _kettle: AudioStreamPlayer3D
var _man_mesh: Mesh
var _woman_mesh: Mesh

static var ECONOMY: EconomyConfig = load("res://data/economy/economy_config.tres")


func _ready() -> void:
	add_to_group(&"cafe")
	_rng.randomize()
	_travel = get_tree().get_first_node_in_group(&"travel") as TravelController
	_open_spot.prompt_key = "CAFE_OPEN"
	_open_spot.distance = 3.0
	_open_spot.interacted.connect(func(_by: Node3D) -> void: toggle())
	add_child(_open_spot)
	_counter.prompt_key = "CAFE_SERVE"
	_counter.distance = 3.2
	_counter.enabled = false
	_counter.interacted.connect(func(_by: Node3D) -> void: open_menu())
	add_child(_counter)
	_kettle = AudioStreamPlayer3D.new()
	_kettle.stream = ProceduralAudio.kettle()
	_kettle.bus = AudioManager.BUS_SFX
	add_child(_kettle)
	_man_mesh = AssetLibrary.meshes("villager_man", [LowPolyMeshes.villager_man(31)])[0]
	_woman_mesh = AssetLibrary.meshes("villager_woman", [LowPolyMeshes.villager_woman(32)])[0]
	_build_props()
	_build_ui()


func has_kit() -> bool:
	return GameState.get_upgrade_level("cafe_kit") > 0


func can_open() -> bool:
	var hour: float = TimeManager.time_of_day
	return has_kit() and hour >= 7.0 and hour < 20.0 and WeatherManager.current.rain < 0.5 \
			and _travel != null and _travel.camper.get_speed_kmh() < 1.0 and not GameState.has_flag("cafe.open")


func region_menu() -> Array:
	return ECONOMY.cafe_region_menu.get(String(GameState.current_region_id), ["CAFE_TEA", "CAFE_COFFEE"])


func session_size() -> int:
	return ECONOMY.cafe_customers + int(GameState.upgrade_effect("cafe_kit", "cafe_customers", 0.0))


func _process(delta: float) -> void:
	if _travel == null:
		return
	# The café hangs off the camper's back door.
	var cam: Transform3D = _travel.camper.global_transform
	global_transform = Transform3D(cam.basis.orthonormalized(), cam.origin + cam.basis.z.normalized() * 3.4)
	global_position.y = _travel.camper.global_position.y - 0.3
	_open_spot.enabled = has_kit() and GameState.player_mode == GameState.PlayerMode.ON_FOOT and (open or can_open())
	_open_spot.prompt_key = "CAFE_CLOSE" if open else "CAFE_OPEN"
	if not open:
		return
	if TimeManager.time_of_day >= 20.5 or _travel.camper.get_speed_kmh() > 3.0:
		close()
		return
	_spawn_t -= delta
	if _to_spawn > 0 and _spawn_t <= 0.0 and customers.size() < 2:
		_spawn_customer()
		_spawn_t = _rng.randf_range(6.0, 14.0)
	_update_customers(delta)
	_counter.enabled = _waiting_customer() != null
	if _to_spawn == 0 and customers.is_empty():
		close()


func toggle() -> void:
	if open:
		close()
	elif can_open():
		open_cafe()


func open_cafe() -> void:
	open = true
	served = 0
	earned = 0
	_to_spawn = session_size()
	_spawn_t = 3.0
	_props.visible = true
	GameState.set_flag("cafe.open")
	GameState.notify(tr(&"CAFE_OPENED"))


func close() -> void:
	if not open:
		return
	open = false
	_props.visible = false
	_counter.enabled = false
	_close_menu()
	for c: Dictionary in customers:
		(c.node as Node3D).queue_free()
	customers.clear()
	GameState.set_flag("cafe.open", false)
	var key: String = "cafe.%s.served" % GameState.current_region_id
	GameState.set_counter(key, GameState.get_counter(key) + served)
	GameState.set_counter("cafe.total_served", GameState.get_counter("cafe.total_served") + served)
	GameState.notify(tr(&"CAFE_CLOSED") % [served, earned])
	session_ended.emit(earned)


func get_status_text() -> String:
	return tr(&"CAFE_STATUS") % [served, session_size(), earned] if open else ""


# --- Customers -----------------------------------------------------------

func _spawn_customer() -> void:
	_to_spawn -= 1
	var node := Node3D.new()
	var man: bool = _rng.randf() < 0.5
	node.add_child(CharacterRig.build("villager_man" if man else "villager_woman", _man_mesh if man else _woman_mesh))
	var bubble := Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 44
	bubble.pixel_size = 0.006
	bubble.outline_size = 10
	bubble.modulate = Color(0.2, 0.15, 0.1)
	bubble.outline_modulate = Color(1, 0.97, 0.9)
	bubble.position = Vector3(0, 2.25, 0)
	bubble.visible = false
	node.add_child(bubble)
	get_parent().add_child(node)
	var a: float = _rng.randf_range(-1.2, 1.2)
	var from: Vector3 = global_position + global_transform.basis.z.normalized().rotated(Vector3.UP, a) * 26.0
	node.global_position = _on_ground(from)
	var menu: Array = region_menu()
	var order: String = menu[_rng.randi() % menu.size()]
	var seat: Vector3 = global_position + global_transform.basis.z.normalized() * 2.2 + global_transform.basis.x.normalized() * (_rng.randf_range(-1.2, 1.2))
	customers.append({"node": node, "bubble": bubble, "order": order, "state": "arrive", "target": seat, "from": from, "wait": 0.0})


func _on_ground(p: Vector3) -> Vector3:
	if GameState.current_region:
		p.y = GameState.current_region.get_ground_height(p.x, p.z)
	return p


func _update_customers(delta: float) -> void:
	for c: Dictionary in customers.duplicate():
		var node: Node3D = c.node
		match c.state:
			"arrive", "leave":
				var target: Vector3 = c.target if c.state == "arrive" else c.from
				var to: Vector3 = (target - node.global_position) * Vector3(1, 0, 1)
				if to.length() < 0.3:
					if c.state == "arrive":
						c.state = "wait"
						(c.bubble as Label3D).text = tr(StringName(c.order))
						(c.bubble as Label3D).visible = true
					else:
						node.queue_free()
						customers.erase(c)
					continue
				var step: Vector3 = to.normalized() * WALK_SPEED * delta
				node.global_position = _on_ground(node.global_position + step)
				node.rotation.y = atan2(-to.x, -to.z)
				var body := node.get_child(0) as CharacterRig
				body.set_motion(WALK_SPEED)
				if not body.is_animated():
					body.position.y = absf(sin(Time.get_ticks_msec() * 0.008)) * 0.05
			"wait":
				c.wait = float(c.wait) + delta
				(node.get_child(0) as CharacterRig).play(&"idle")
				var look: Vector3 = global_position - node.global_position
				node.rotation.y = lerp_angle(node.rotation.y, atan2(-look.x, -look.z), delta * 3.0)


func _waiting_customer() -> Variant:
	for c: Dictionary in customers:
		if c.state == "wait":
			return c
	return null


## Serves `item` to the first waiting customer. Returns the money earned
## (0 for a wrong pick, which costs nothing and lets the player try again).
func serve(item: String) -> int:
	var c: Variant = _waiting_customer()
	if c == null:
		return 0
	var prices: Array = ECONOMY.cafe_menu.get(item, [0, 0])
	if item != c.order:
		(c.bubble as Label3D).text = tr(&"CAFE_WRONG") % tr(StringName(c.order))
		return 0
	var price: int = int(prices[1])
	var cost: int = int(prices[0])
	var quick: float = clampf(1.0 - float(c.wait) / ECONOMY.cafe_patience, 0.0, 1.0)
	var tip: int = roundi(price * ECONOMY.cafe_tip_share * quick * GameState.upgrade_effect("cafe_kit", "cafe_tip_mult", 1.0))
	var gain: int = price + tip - cost
	GameState.add_money(gain)
	earned += gain
	served += 1
	GameState.set_counter("cafe.served", GameState.get_counter("cafe.served") + 1)
	_kettle.play()
	(c.bubble as Label3D).text = tr(&"CAFE_THANKS")
	c.state = "leave"
	return gain


# --- Menu UI -------------------------------------------------------------

func open_menu() -> void:
	var c: Variant = _waiting_customer()
	if c == null or not GameState.is_gameplay():
		return
	GameState.set_context(GameState.Context.MENU)
	_travel.suspend_control()
	for child: Node in _menu_box.get_children():
		child.queue_free()
	_menu_title.text = tr(&"CAFE_MENU_TITLE")
	var first: Button
	for item: String in region_menu():
		var prices: Array = ECONOMY.cafe_menu.get(item, [0, 0])
		var b: Button = UIStyle.make_button("%s  ·  %d ₺" % [tr(StringName(item)), int(prices[1])], func() -> void:
			serve(item)
			_close_menu())
		_menu_box.add_child(b)
		if first == null:
			first = b
	_menu_box.add_child(UIStyle.make_button(tr(&"JOURNAL_BACK"), _close_menu))
	_ui.visible = true
	if first:
		first.grab_focus.call_deferred()


func _close_menu() -> void:
	if not _ui.visible:
		return
	_ui.visible = false
	GameState.set_context(GameState.Context.GAMEPLAY)
	_travel.restore_control()


func _unhandled_input(event: InputEvent) -> void:
	if _ui.visible and event.is_action_pressed(&"pause"):
		_close_menu()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 14
	_ui.visible = false
	add_child(_ui)
	var panel := PanelContainer.new()
	UIStyle.panel(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -420
	panel.offset_right = -40
	panel.offset_top = -200
	panel.offset_bottom = 200
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	_menu_title = UIStyle.label("", 24)
	col.add_child(_menu_title)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override(&"separation", 6)
	col.add_child(_menu_box)
	panel.add_child(col)
	_ui.add_child(panel)


## Awning, counter, two stools and a chalkboard behind the camper.
func _build_props() -> void:
	_props = Node3D.new()
	_props.visible = false
	add_child(_props)
	var b := LowPolyMeshes.Builder.new(800)
	var wood := Color(0.55, 0.38, 0.24)
	var stripe_a := Color(0.85, 0.3, 0.25)
	var stripe_b := Color(0.96, 0.92, 0.84)
	for i: int in 8:
		var x: float = -1.75 + i * 0.5
		b.add(LowPolyMeshes._box(Vector3(0.5, 0.05, 2.2)), Transform3D(Basis(Vector3.RIGHT, -0.22), Vector3(x + 0.25, 2.55, 0.9)), stripe_a if i % 2 == 0 else stripe_b)
	for x: float in [-1.9, 1.9]:
		b.add(LowPolyMeshes._box(Vector3(0.07, 2.4, 0.07)), LowPolyMeshes._at(Vector3(x, 1.2, 1.9)), wood)
	b.add(LowPolyMeshes._box(Vector3(2.2, 0.95, 0.6)), LowPolyMeshes._at(Vector3(0, 0.48, 0.4)), wood)
	b.add(LowPolyMeshes._box(Vector3(2.3, 0.06, 0.7)), LowPolyMeshes._at(Vector3(0, 0.98, 0.4)), wood.lightened(0.15))
	b.add(LowPolyMeshes._cone(0.12, 0.14, 0.32, 8), LowPolyMeshes._at(Vector3(-0.6, 1.17, 0.4)), Color(0.75, 0.76, 0.78))
	for i: int in 4:
		b.add(LowPolyMeshes._cone(0.035, 0.03, 0.09, 6), LowPolyMeshes._at(Vector3(0.1 + i * 0.14, 1.06, 0.45)), Color(0.75, 0.25, 0.12))
	for x: float in [-1.0, 1.0]:
		b.add(LowPolyMeshes._cone(0.22, 0.22, 0.05, 10), LowPolyMeshes._at(Vector3(x, 0.5, 2.3)), wood.darkened(0.1))
		b.add(LowPolyMeshes._cone(0.04, 0.04, 0.5, 5), LowPolyMeshes._at(Vector3(x, 0.25, 2.3)), wood.darkened(0.2))
	b.add(LowPolyMeshes._box(Vector3(0.7, 0.9, 0.05)), Transform3D(Basis(Vector3.RIGHT, 0.15), Vector3(1.6, 0.55, 1.6)), Color(0.15, 0.18, 0.16))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(LowPolyMeshes.vertex_color_material(0.8))
	_props.add_child(mi)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 0.8
	lamp.omni_range = 6.0
	lamp.position = Vector3(0, 2.3, 0.8)
	_props.add_child(lamp)
	_counter.position = Vector3(0, 1.0, 0.4)
	_open_spot.position = Vector3(0, 1.2, -0.6)
