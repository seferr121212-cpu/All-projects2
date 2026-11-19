extends Node3D
## Dev tool: lines up the character models and saves a screenshot (path = first user arg).
func _ready() -> void:
	var root := Node3D.new()
	add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.6, 0.7, 0.8)
	e.ambient_light_color = Color(0.7, 0.75, 0.8)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	root.add_child(sun)
	var keys: Array = ["villager_woman", "villager_man", "fisherman", "shepherd"]
	var x: float = -1.5
	for k: String in keys:
		var mi := MeshInstance3D.new()
		mi.mesh = AssetLibrary.meshes(k, [BoxMesh.new()])[0]
		mi.position = Vector3(x, 0, 0)
		root.add_child(mi)
		x += 1.0
	var parts: Dictionary = {}
	for k: String in ["body", "leg", "arm"]:
		parts[k] = AssetLibrary.meshes("traveller_" + k, [BoxMesh.new()])[0]
	var t := Node3D.new(); t.position = Vector3(2.5, 0, 0); root.add_child(t)
	var b := MeshInstance3D.new(); b.mesh = parts.body; t.add_child(b)
	for sx: float in [-0.11, 0.11]:
		var l := MeshInstance3D.new(); l.mesh = parts.leg; l.position = Vector3(sx, 0.86, 0); t.add_child(l)
	for sx: float in [-0.27, 0.27]:
		var a := MeshInstance3D.new(); a.mesh = parts.arm; a.position = Vector3(sx, 1.42, 0); t.add_child(a)
	var cam := Camera3D.new()
	cam.position = Vector3(1.0, 1.5, -2.6)
	root.add_child(cam)
	cam.look_at(Vector3(1.0, 1.25, 0))
	cam.current = true
	for i: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
