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
	if OS.get_cmdline_user_args().size() > 1:
		await _structures(root, OS.get_cmdline_user_args()[1])
		return
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


## Second user arg: "houses" or "props" lays out structure models instead.
func _structures(root: Node3D, which: String) -> void:
	var keys: Array = ["house_yayla", "house_ege", "house_tuff", "house_plateau"] if which == "houses" else ["fairy_chimney", "nomad_tent", "boat"]
	var x: float = 0.0
	var z: float = 0.0
	for k: String in keys:
		for m: Mesh in AssetLibrary.meshes(k, [BoxMesh.new()]):
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.position = Vector3(x, 0, z)
			root.add_child(mi)
			if AssetLibrary.has_override(k + "_win"):
				var w := MeshInstance3D.new()
				w.mesh = AssetLibrary.meshes(k + "_win", [])[AssetLibrary.meshes(k, []).find(m)]
				w.position = mi.position
				root.add_child(w)
			x += m.get_aabb().size.x + 3.0
		if which == "houses" and x > 30.0:
			x = 0.0
			z -= 14.0
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(x * 0.5 if which != "houses" else 18.0, 9.0, 26.0) if which != "houses" else Vector3(16, 14, 24)
	cam.look_at(Vector3(cam.position.x - (0.0 if which != "houses" else 4.0), 2.5, -5.0 if which == "houses" else 0.0))
	cam.current = true
	for i: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
