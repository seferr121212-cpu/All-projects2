class_name AssetLibrary
extends RefCounted
## Swaps procedural placeholder meshes for real model packs when they are
## present. data/assets/asset_overrides.json maps a key ("spruce", "rock"...)
## to candidate model files; the first that exists wins, otherwise the
## procedural mesh is used. Imported res:// models load through Godot's
## importer; user:// .glb/.gltf files (player mods) load at runtime.

const MAP_PATH: String = "res://data/assets/asset_overrides.json"

static var _map: Dictionary = {}
static var _cache: Dictionary = {}
static var _loaded: bool = false


## Meshes for `key`, or `fallback` when no model file is installed.
static func meshes(key: String, fallback: Array[Mesh]) -> Array[Mesh]:
	if _cache.has(key):
		return _cache[key]
	var found: Array[Mesh] = []
	for entry: Dictionary in _entries(key):
		var mesh: ArrayMesh = load_model(String(entry.get("path", "")), float(entry.get("scale", 1.0)))
		if mesh:
			_apply_material(mesh, String(entry.get("material", "")))
			found.append(mesh)
	var result: Array[Mesh] = found if not found.is_empty() else fallback
	_cache[key] = result
	return result


## "foliage:<sway>,<sway height>,<backlight>" or "vertex:<roughness>" replaces
## every surface material (models are exported with vertex colours only).
static func _apply_material(mesh: ArrayMesh, spec: String) -> void:
	if spec == "":
		return
	var parts: PackedStringArray = spec.split(":")
	var args: PackedFloat64Array = parts[1].split_floats(",") if parts.size() > 1 else PackedFloat64Array()
	var mat: Material
	match parts[0]:
		"foliage":
			mat = LowPolyMeshes.foliage_material(args[0] if args.size() > 0 else 0.1, args[1] if args.size() > 1 else 6.0, args[2] if args.size() > 2 else 0.3)
		"grass":
			mat = LowPolyMeshes.grass_material()
		_:
			mat = LowPolyMeshes.vertex_color_material(args[0] if args.size() > 0 else 0.8)
	for s: int in mesh.get_surface_count():
		mesh.surface_set_material(s, mat)


## The rigged, animated scene for "<key>_rig", or null.
static func rig_scene(key: String) -> PackedScene:
	for entry: Dictionary in _entries(key + "_rig"):
		var p: String = String(entry.get("path", ""))
		if ResourceLoader.exists(p):
			return load(p) as PackedScene
	return null


static func has_override(key: String) -> bool:
	for entry: Dictionary in _entries(key):
		var p: String = String(entry.get("path", ""))
		if ResourceLoader.exists(p) or (p.begins_with("user://") and FileAccess.file_exists(p)):
			return true
	return false


static func clear_cache() -> void:
	_cache.clear()
	_loaded = false


static func _entries(key: String) -> Array:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(MAP_PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			_map = parsed if parsed is Dictionary else {}
	return _map.get(key, [])


## Flattens every MeshInstance3D of a model into one ArrayMesh (one surface
## per source surface, materials kept), scaled and with its base at y = 0.
static func load_model(path: String, scale: float = 1.0) -> ArrayMesh:
	var root: Node
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is PackedScene:
			root = (res as PackedScene).instantiate()
		elif res is ArrayMesh:
			return res
	elif FileAccess.file_exists(path) and (path.ends_with(".glb") or path.ends_with(".gltf")):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(path, state) == OK:
			root = doc.generate_scene(state)
	if root == null:
		return null
	var out := ArrayMesh.new()
	_collect(root, Transform3D.IDENTITY.scaled(Vector3.ONE * scale), out)
	root.free()
	return out if out.get_surface_count() > 0 else null


static func _collect(node: Node, parent_xf: Transform3D, out: ArrayMesh) -> void:
	var xf: Transform3D = parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mi := node as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i: int in verts.size():
				verts[i] = xf * verts[i]
			arrays[Mesh.ARRAY_VERTEX] = verts
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i: int in normals.size():
					normals[i] = (xf.basis * normals[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat: Material = mi.get_active_material(s)
			if mat:
				out.surface_set_material(out.get_surface_count() - 1, mat)
	for c: Node in node.get_children():
		_collect(c, xf, out)
