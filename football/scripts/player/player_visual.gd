extends Node3D
## Oyuncu görseli (şimdilik kapsül). Mesh/animasyon değişince bu sahne değiştirilir.

@onready var body: MeshInstance3D = $Body
@onready var indicator: Node3D = $Indicator


func set_team_color(color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	body.material_override = mat


func set_indicator(on: bool) -> void:
	indicator.visible = on


## Basit duruş: kayarken yatık, sendelerken hafif eğik.
func set_pose(state: int) -> void:
	match state:
		FootballPlayer.State.SLIDING:
			rotation = Vector3(deg_to_rad(-70.0), 0.0, 0.0)
			position.y = 0.3
		FootballPlayer.State.STUMBLE:
			rotation = Vector3(deg_to_rad(-15.0), 0.0, 0.0)
			position.y = 0.0
		_:
			rotation = Vector3.ZERO
			position.y = 0.0
