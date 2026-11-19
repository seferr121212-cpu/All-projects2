class_name CharacterRig
extends Node3D
## A character body: the rigged Blender model (skeleton + idle / walk / work /
## talk animations) when "<key>_rig" is in asset_overrides.json, otherwise the
## static fallback mesh. Callers just ask for an animation or a ground speed.

const WALK_REF_SPEED: float = 1.3

var anim: AnimationPlayer
var _current: StringName = &""


static func build(key: String, fallback: Mesh) -> CharacterRig:
	var rig := CharacterRig.new()
	rig.name = "Body"
	var scene: PackedScene = AssetLibrary.rig_scene(key)
	if scene:
		var inst: Node = scene.instantiate()
		rig.add_child(inst)
		rig.anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var mat: Material = LowPolyMeshes.vertex_color_material(0.75)
		for mi: Node in inst.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
		if rig.anim:
			for n: StringName in rig.anim.get_animation_list():
				rig.anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			rig.play(&"idle")
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = fallback
		rig.add_child(mi)
	return rig


func is_animated() -> bool:
	return anim != null


func play(anim_name: StringName, speed: float = 1.0, blend: float = 0.3) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	anim.speed_scale = speed
	if _current != anim_name:
		_current = anim_name
		anim.play(anim_name, blend)


## Walk while moving (playback rate follows speed in m/s), idle when still.
func set_motion(speed: float) -> void:
	if speed > 0.15:
		play(&"walk", clampf(speed / WALK_REF_SPEED, 0.5, 2.6))
	else:
		play(&"idle")
