class_name PhotoConfig
extends Resource
## All photo tuning in one place: camera ranges, scoring weights, rewards.

@export_group("Camera")
## Narrowest field of view per lens level (index = GameState.lens_level).
@export var lens_min_fov: PackedFloat32Array = PackedFloat32Array([30.0, 18.0, 9.0])
@export var max_fov: float = 80.0
@export var apertures: PackedFloat32Array = PackedFloat32Array([1.8, 2.8, 4.0, 5.6, 8.0, 16.0])
## Godot DOF blur amount per aperture above.
@export var aperture_blur: PackedFloat32Array = PackedFloat32Array([0.22, 0.15, 0.1, 0.06, 0.03, 0.0])
@export var exposure_range: float = 2.0
@export var move_radius: float = 8.0
@export var move_speed: float = 3.0

@export_group("Scoring")
@export_range(0.0, 1.0) var weight_content: float = 0.45
@export_range(0.0, 1.0) var weight_composition: float = 0.3
@export_range(0.0, 1.0) var weight_focus: float = 0.1
@export_range(0.0, 1.0) var weight_exposure: float = 0.15
## Points added per special moment captured (max two count).
@export var moment_bonus: float = 10.0
## Fraction of frame height a subject should fill to score fully.
@export var ideal_size_min: float = 0.1
@export var ideal_size_max: float = 0.75
@export var min_score: int = 8
@export var three_star_score: int = 75
@export var two_star_score: int = 50

@export_group("Economy")
## Sale value = base + score * per_point (+ bonus for a newly discovered subject).
@export var value_base: int = 5
@export var value_per_point: float = 0.3
@export var value_new_subject_bonus: int = 10
