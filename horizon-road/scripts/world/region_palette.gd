class_name RegionPalette
extends Resource
## Time-of-day colour curves for one region + season. Gradients are sampled
## at hour / 24, so offset 0.25 = 06:00, 0.5 = 12:00, 0.8333 = 20:00.

@export var sun_color: Gradient
@export var sky_zenith: Gradient
@export var sky_horizon: Gradient
@export var fog_color: Gradient
@export var ground_color: Color = Color(0.18, 0.22, 0.14)
## Colour of the faint ambient fill at night (moonlit blue).
@export var night_ambient: Color = Color(0.25, 0.32, 0.5)
@export_range(0.0, 2.0) var saturation: float = 1.0
@export_range(0.5, 1.5) var contrast: float = 1.0
## Region's baseline distance fog, before weather is added.
@export_range(0.0, 0.02, 0.0001) var base_fog_density: float = 0.0015
@export_range(0.0, 1.0) var fog_sun_scatter: float = 0.25
