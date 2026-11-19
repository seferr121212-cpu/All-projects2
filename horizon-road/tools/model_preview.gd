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
	var keys: Array = ["villager_woman", "villager_man", "fisherman", "shepherd", "traveller"]
	var anims: Array = ["talk", "idle", "walk", "talk", "walk"]
	var x: float = -1.0
	for i: int in keys.size():
		var rig := CharacterRig.build(keys[i], BoxMesh.new())
		rig.position = Vector3(x, 0, 0)
		rig.rotation.y = 0.5 if i % 2 == 0 else -0.4
		root.add_child(rig)
		if rig.anim:
			rig.anim.play(StringName(anims[i]), 0.0)
			rig.anim.advance(0.3)
			rig.anim.pause()
		x += 0.9
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
	if which == "animals":
		var ax: float = 0.0
		for k: String in ["cow", "sheep", "cat", "dog"]:
			for v: int in 3:
				var r := CharacterRig.build(k, BoxMesh.new(), v)
				r.position = Vector3(ax, 0, 0)
				r.rotation.y = 2.2
				root.add_child(r)
				if r.anim:
					r.anim.play([&"walk", &"work", &"idle"][v], 0.0)
					r.anim.advance(0.3)
					r.anim.pause()
				ax += 1.6 if k == "cow" else 0.9
		var c2 := Camera3D.new()
		root.add_child(c2)
		c2.position = Vector3(ax * 0.5, 2.2, 5.5)
		c2.look_at(Vector3(ax * 0.5, 0.5, 0))
		c2.current = true
		for i: int in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		get_tree().quit()
		return
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
