class_name Pickup
extends Area2D
## Toplanabilir: oil, oil_small, page, tape, gear, bell, red, lamp, radio.

var kind := "oil"
var id := ""
var keys: Array = []
var _vis: Node2D
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 30.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body)
	if id != "" and GameState.flag("pick_" + id):
		queue_free()
		return
	LightSystem.register(self)
	_vis = Node2D.new()
	add_child(_vis)
	var spr := Art.sprite_c("props/%s.png" % kind)
	# uzaktan fark edilsin: yumuşak ışık sütunu + kıvılcım
	var shaft := Sprite2D.new()
	shaft.texture = Art.tex("fx/glow.png")
	shaft.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shaft.material = Art.glow_material()
	shaft.scale = Vector2(0.22, 1.5)
	shaft.position = Vector2(0, -60)
	shaft.modulate = Color(1.0, 0.85, 0.55, 0.28)
	add_child(shaft)
	var tw := shaft.create_tween().set_loops()
	tw.tween_property(shaft, "modulate:a", 0.1, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(shaft, "modulate:a", 0.3, 1.1).set_trans(Tween.TRANS_SINE)
	var spk := CPUParticles2D.new()
	spk.texture = Art.tex("fx/mote.png")
	spk.material = Art.glow_material()
	spk.amount = 5
	spk.lifetime = 1.4
	spk.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	spk.emission_sphere_radius = 14.0
	spk.direction = Vector2(0, -1)
	spk.spread = 20.0
	spk.gravity = Vector2.ZERO
	spk.initial_velocity_min = 12.0
	spk.initial_velocity_max = 30.0
	spk.color = Color(1.0, 0.9, 0.6, 0.7)
	add_child(spk)
	_vis.add_child(spr)


func _exit_tree() -> void:
	LightSystem.unregister(self)


func is_light_on() -> bool:
	return true


func is_static_light() -> bool:
	return false


func get_light_circles() -> Array:
	return [Vector4(global_position.x, global_position.y - 14.0, 70.0, 0.25 + 0.05 * sin(_t * 3.0))]


func _process(delta: float) -> void:
	_t += delta
	if _vis:
		_vis.position.y = sin(_t * 2.5) * 3.0


func _on_body(b: Node) -> void:
	if b is Kerem:
		collect()


func collect() -> void:
	if id != "":
		GameState.set_flag("pick_" + id)
	AudioManager.play_sfx("page" if kind == "page" else "pickup")
	if kind in ["page", "tape", "gear", "bell", "red", "lamp", "letter", "wick"]:
		AudioManager.play_sfx("discover", -8.0)
	var hud = GameState.hud
	match kind:
		"oil":
			GameState.add_fuel(40.0)
			if hud: hud.toast(Loc.t("PICKUP_OIL"))
		"oil_small":
			GameState.add_fuel(15.0)
			if hud: hud.toast(Loc.t("PICKUP_OIL_SMALL"))
		"page":
			GameState.add_page(id)
			if hud:
				hud.toast(Loc.t("PICKUP_PAGE") + " (%d/12)" % GameState.pages.size())
				if GameState.pages.size() == 1:
					hud.hint(Loc.t("HINT_JOURNAL"))
			Dialogue.play([id])
		"letter":
			GameState.add_letter(id)
			if hud: hud.toast(Loc.t("PICKUP_LETTER") + " (%d/6)" % GameState.letters.size())
			Dialogue.play([id])
		"wick":
			GameState.wicks += 1
			if GameState.wicks >= 3:
				GameState.unlock("WICKS")
			if hud: hud.toast(Loc.t("PICKUP_WICK") + " (%d/3)" % GameState.wicks)
		"tape":
			GameState.add_tape(id)
			if hud: hud.toast(Loc.t("PICKUP_TAPE"))
			Dialogue.play(keys)
		"gear":
			GameState.gears += 1
			if hud: hud.toast(Loc.t("PICKUP_GEAR") + " %d/3" % GameState.gears)
		"bell":
			GameState.has_bell = true
			if hud:
				hud.toast(Loc.t("PICKUP_BELL"))
				hud.hint(Loc.t("HINT_BELL"))
			Dialogue.play(["C2_033"])
		"red":
			GameState.has_red = true
			if hud:
				hud.toast(Loc.t("PICKUP_RED"))
				hud.hint(Loc.t("HINT_RED"))
			Dialogue.play(["C2_034"])
		"lamp":
			GameState.has_lamp = true
			GameState.fuel = maxf(GameState.fuel, 70.0)
			if hud:
				hud.toast(Loc.t("PICKUP_LAMP"))
				hud.hint(Loc.t("HINT_LAMP") + "\n" + Loc.t("HINT_DIM"))
			Dialogue.play(["C1_030"])
		"radio":
			GameState.has_radio = true
			if hud: hud.toast(Loc.t("PICKUP_RADIO"))
	GameState.inventory_changed.emit()
	queue_free()
