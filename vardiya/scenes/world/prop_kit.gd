extends RefCounted
## Stylised low-poly props built from boxes and prisms. A prop always fits
## inside the data box (pos, size, rot) it replaces, so collision and the
## validator's walkability grid stay exactly as authored. Local frame: box
## centre, +z = front, +y = up. Geometry goes into per-material MeshBatches.

const MeshBatch = preload("res://scenes/world/mesh_batch.gd")

## kind -> default material id (see ArtKit.MATERIAL_IDS)
const KINDS := {
	"block": "paint", "crate": "wood", "container": "metal", "locker": "paint", "table": "wood",
	"desk": "wood", "bench": "wood", "machine": "paint", "cylinder": "metal", "barrel": "metal",
	"rail": "paint", "pillar": "concrete", "beam": "metal", "truck": "paint", "booth": "plaster",
	"person": "fabric", "sofa": "fabric", "shelf": "wood", "cabinet": "wood", "board": "wood",
	"paper": "plain", "window": "glow", "door": "glow", "banner": "fabric", "crane": "metal",
	"lamp": "metal", "pipe": "metal", "conveyor": "metal", "screen": "glow", "pallet": "wood",
	"hazard": "paint", "kitchen": "wood", "fire": "glow", "lamp_post": "metal", "bed": "fabric",
	"fence": "metal", "panel": "glow",
}
const DARK := 0.55


static func batch(batches: Dictionary, id: String) -> MeshBatch:
	if not batches.has(id):
		batches[id] = MeshBatch.new()
	return batches[id]


static func _box(bt: MeshBatch, xf: Transform3D, center: Vector3, size: Vector3, col: Color, rot: Basis = Basis.IDENTITY) -> void:
	bt.add_box(xf * Transform3D(rot, center), size, col)


static func _prism(bt: MeshBatch, xf: Transform3D, center: Vector3, r: float, h: float, col: Color,
		axis: Basis = Basis.IDENTITY, seg: int = 8) -> void:
	bt.add_prism(xf * Transform3D(axis, center), r, h, col, seg)


## (along, up, across) -> local vector for a prop whose long axis is x or z.
static func _ax(long_x: bool, a: float, y: float, w: float) -> Vector3:
	return Vector3(a, y, w) if long_x else Vector3(w, y, a)


static func _dark(c: Color, f: float = DARK) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


static func _hash01(seed_value: int, salt: int) -> float:
	return float(hash(seed_value * 7919 + salt) % 1000) / 1000.0


## Builds `kind` into `batches`. `mat` is the main material id.
static func build(kind: String, batches: Dictionary, xf: Transform3D, s: Vector3, col: Color, mat: String,
		seed_value: int = 0) -> void:
	var m := batch(batches, mat)
	var metal := batch(batches, "metal")
	var glow := batch(batches, "glow")
	var h := s * 0.5
	var long_x := s.x >= s.z
	var along := Basis.IDENTITY if long_x else Basis(Vector3.UP, PI / 2)
	var length := maxf(s.x, s.z)
	var depth := minf(s.x, s.z)
	match kind:
		"crate":
			_box(m, xf, Vector3.ZERO, s * Vector3(0.94, 0.94, 0.94), col)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(m, xf, Vector3(sx * (h.x - 0.04), 0, sz * (h.z - 0.04)), Vector3(0.08, s.y, 0.08), _dark(col, 0.75))
			for sy in [-1, 1]:
				_box(m, xf, Vector3(0, sy * (h.y - 0.04), 0), Vector3(s.x, 0.08, s.z), _dark(col, 0.8))
		"pallet":
			for i in 3:
				_box(m, xf, Vector3(0, -h.y + s.y * 0.25, (i - 1) * (h.z - 0.06)), Vector3(s.x, s.y * 0.5, 0.1), _dark(col, 0.8))
			for i in 5:
				_box(m, xf, Vector3((i - 2) * (s.x - 0.12) / 4.0, h.y - 0.02, 0), Vector3(0.1, 0.04, s.z), col)
		"container":
			m.add_box_tiled(xf, s * Vector3(0.98, 0.96, 0.98), col, 1.3)
			var ribs := int(length / 0.32)
			for i in ribs:
				var t := -length * 0.5 + (i + 0.5) * length / ribs
				for side in [-1, 1]:
					var c := Vector3(t, 0, side * depth * 0.5) if long_x else Vector3(side * depth * 0.5, 0, t)
					var rs := Vector3(0.1, s.y * 0.86, 0.04) if long_x else Vector3(0.04, s.y * 0.86, 0.1)
					_box(m, xf, c, rs, _dark(col, 0.85))
			_box(m, xf, Vector3(0, h.y - 0.05, 0), Vector3(s.x, 0.1, s.z), _dark(col, 0.7))
			_box(m, xf, Vector3(0, -h.y + 0.06, 0), Vector3(s.x, 0.12, s.z), _dark(col, 0.5))
			for end_side in [-1, 1]:
				for bar in [-1, 1]:
					var c := Vector3(end_side * h.x, 0, bar * depth * 0.18) if long_x else Vector3(bar * depth * 0.18, 0, end_side * h.z)
					_box(metal, xf, c, Vector3(0.05, s.y * 0.9, 0.05), Color(0.55, 0.55, 0.55))
		"locker":
			_box(m, xf, Vector3(0, 0, -0.02), s - Vector3(0.02, 0, 0.04), col)
			_box(m, xf, Vector3(0, 0.02, h.z - 0.03), Vector3(s.x - 0.08, s.y - 0.12, 0.04), col.lightened(0.06))
			for i in 3:
				_box(m, xf, Vector3(0, h.y - 0.18 - i * 0.06, h.z), Vector3(s.x * 0.5, 0.02, 0.02), _dark(col, 0.45))
			_box(metal, xf, Vector3(s.x * 0.3, 0, h.z + 0.01), Vector3(0.03, 0.14, 0.03), Color(0.75, 0.75, 0.72))
			_box(m, xf, Vector3(0, -h.y + 0.04, 0), Vector3(s.x, 0.08, s.z), _dark(col, 0.4))
		"table", "desk":
			var top := 0.05
			_box(m, xf, Vector3(0, h.y - top * 0.5, 0), Vector3(s.x, top, s.z), col)
			var leg := 0.06
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(m if kind == "table" else metal, xf, Vector3(sx * (h.x - 0.08), -top * 0.5, sz * (h.z - 0.08)),
						Vector3(leg, s.y - top, leg), _dark(col, 0.6))
			if kind == "desk":
				_box(m, xf, Vector3(h.x - s.x * 0.18, 0.0, 0), Vector3(s.x * 0.32, s.y - top, s.z * 0.9), _dark(col, 0.85))
				for i in 3:
					_box(metal, xf, Vector3(h.x - s.x * 0.18, h.y - 0.2 - i * (s.y - 0.1) / 3.0, h.z * 0.9 + 0.01),
						Vector3(0.1, 0.02, 0.02), Color(0.7, 0.7, 0.68))
		"bench":
			_box(m, xf, Vector3(0, h.y - 0.03, 0), Vector3(s.x, 0.06, s.z), col)
			var legs := maxi(2, int(length / 1.2) + 1)
			for i in legs:
				var t := -length * 0.5 + 0.1 + i * (length - 0.2) / (legs - 1)
				var c := Vector3(t, -0.03, 0) if long_x else Vector3(0, -0.03, t)
				_box(metal, xf, c, Vector3(0.05, s.y - 0.06, depth * 0.8) if long_x else Vector3(depth * 0.8, s.y - 0.06, 0.05),
					Color(0.35, 0.37, 0.4))
		"machine":
			_box(m, xf, Vector3(0, -h.y + 0.08, 0), Vector3(s.x, 0.16, s.z), _dark(col, 0.45))
			_box(m, xf, Vector3(0, 0.08, 0), s - Vector3(0.08, 0.16, 0.08), col)
			_box(m, xf, Vector3(0, h.y * 0.35, h.z - 0.02), Vector3(s.x * 0.6, s.y * 0.3, 0.04), _dark(col, 0.7))
			_box(glow, xf, Vector3(-s.x * 0.18, h.y * 0.42, h.z + 0.005), Vector3(0.06, 0.06, 0.02), Color(0.35, 0.95, 0.4))
			_box(glow, xf, Vector3(-s.x * 0.08, h.y * 0.42, h.z + 0.005), Vector3(0.06, 0.06, 0.02), Color(1.0, 0.6, 0.2))
			_hazard_band(batches, xf, Vector3(0, -h.y + 0.2, 0), Vector3(s.x + 0.01, 0.08, s.z + 0.01))
		"cylinder", "pipe":
			var axis_len := maxf(s.y, length)
			var r := minf(minf(s.x, s.z), s.y) * 0.5 if s.y < length else minf(s.x, s.z) * 0.5
			var basis := Basis.IDENTITY
			if s.y < length:
				basis = Basis(Vector3.FORWARD, PI / 2) if long_x else Basis(Vector3.RIGHT, PI / 2)
			_prism(m, xf, Vector3.ZERO, r * 0.92, axis_len, col, basis)
			_prism(m, xf, Vector3.ZERO, r, axis_len * 0.08, _dark(col, 0.7), basis)
			if kind == "pipe":
				var brackets := maxi(2, int(axis_len / 2.0))
				for i in brackets:
					var t := -axis_len * 0.5 + (i + 0.5) * axis_len / brackets
					var c := Vector3(t, 0, 0) if long_x else Vector3(0, 0, t)
					_box(metal, xf, c, Vector3(0.06, r * 2.4, r * 2.4) if long_x else Vector3(r * 2.4, r * 2.4, 0.06), Color(0.3, 0.32, 0.35))
		"barrel":
			var r := minf(s.x, s.z) * 0.5
			_prism(m, xf, Vector3.ZERO, r * 0.95, s.y, col, Basis.IDENTITY, 10)
			for y in [-0.3, 0.3]:
				_prism(m, xf, Vector3(0, y * s.y, 0), r, 0.05, _dark(col, 0.7), Basis.IDENTITY, 10)
		"rail", "fence":
			var posts := maxi(2, int(length / 1.1) + 1)
			for i in posts:
				var t := -length * 0.5 + 0.03 + i * (length - 0.06) / (posts - 1)
				var c := Vector3(t, 0, 0) if long_x else Vector3(0, 0, t)
				_box(m, xf, c, Vector3(0.06, s.y, 0.06), col)
			var bars := [0.92, 0.5] if kind == "rail" else [0.95, 0.65, 0.35, 0.08]
			for f: float in bars:
				var bs := Vector3(length, 0.05, 0.04) if long_x else Vector3(0.04, 0.05, length)
				_box(m, xf, Vector3(0, -h.y + f * s.y, 0), bs, col if kind == "rail" else _dark(col, 0.8))
			if kind == "rail":
				var ks := Vector3(length, 0.12, 0.02) if long_x else Vector3(0.02, 0.12, length)
				_box(m, xf, Vector3(0, -h.y + 0.06, 0), ks, _dark(col, 0.8))
		"pillar":
			_box(m, xf, Vector3.ZERO, s * Vector3(0.86, 1, 0.86), col)
			_box(m, xf, Vector3(0, -h.y + 0.12, 0), Vector3(s.x, 0.24, s.z), _dark(col, 0.8))
			_box(m, xf, Vector3(0, h.y - 0.1, 0), Vector3(s.x, 0.2, s.z), col.lightened(0.05))
		"beam":
			# Steel I-beam column: two flanges and a web.
			_box(m, xf, Vector3(0, 0, -h.z + 0.04), Vector3(s.x, s.y, 0.08), col)
			_box(m, xf, Vector3(0, 0, h.z - 0.04), Vector3(s.x, s.y, 0.08), col)
			_box(m, xf, Vector3.ZERO, Vector3(0.08, s.y, s.z), _dark(col, 0.8))
			_box(m, xf, Vector3(0, -h.y + 0.04, 0), Vector3(s.x + 0.1, 0.08, s.z + 0.1), _dark(col, 0.6))
		"crane":
			# Lattice leg: four corner posts and cross braces.
			var inset := Vector2(h.x - 0.05, h.z - 0.05)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(m, xf, Vector3(sx * inset.x, 0, sz * inset.y), Vector3(0.1, s.y, 0.1), col)
			var rungs := int(s.y / 0.9)
			for i in rungs:
				var y := -h.y + (i + 0.5) * s.y / rungs
				var tilt := 0.7 if i % 2 == 0 else -0.7
				for sz in [-1, 1]:
					_box(m, xf, Vector3(0, y, sz * inset.y), Vector3(s.x * 1.15, 0.05, 0.05), _dark(col, 0.8), Basis(Vector3.BACK, tilt))
				for sx in [-1, 1]:
					_box(m, xf, Vector3(sx * inset.x, y, 0), Vector3(0.05, 0.05, s.z * 1.15), _dark(col, 0.8), Basis(Vector3.RIGHT, tilt))
		"truck":
			var tire := Color(0.08, 0.08, 0.09)
			var wheel_r := minf(0.45, s.y * 0.16)
			var body_y := wheel_r * 2.0
			var cab := length * 0.26
			var cargo := length - cab - 0.1
			var front := -1.0  # cab towards -long axis
			var cargo_c: float = -front * (length * 0.5 - cargo * 0.5)
			_box(m, xf, _ax(long_x, cargo_c, -h.y + body_y + (s.y - body_y) * 0.5, 0.0), _ax(long_x, cargo, s.y - body_y, depth), col)
			var cab_h := (s.y - body_y) * 0.75
			var cab_c: float = front * (length * 0.5 - cab * 0.5)
			_box(m, xf, _ax(long_x, cab_c, -h.y + body_y + cab_h * 0.5, 0.0), _ax(long_x, cab, cab_h, depth * 0.96), col.lightened(0.08))
			_box(glow, xf, _ax(long_x, front * (length * 0.5 - 0.02), -h.y + body_y + cab_h * 0.7, 0.0),
				_ax(long_x, 0.04, cab_h * 0.35, depth * 0.8), Color(0.22, 0.3, 0.38))
			_box(metal, xf, _ax(long_x, 0.0, -h.y + body_y * 0.6, 0.0), _ax(long_x, length * 0.96, 0.18, depth * 0.7),
				Color(0.2, 0.2, 0.22))
			for a: float in [front * (length * 0.5 - cab * 0.5), -front * (length * 0.5 - 0.8), -front * (length * 0.5 - 1.8)]:
				for w in [-1, 1]:
					var wb := Basis(Vector3.FORWARD, PI / 2) if not long_x else Basis(Vector3.RIGHT, PI / 2)
					_prism(metal, xf, _ax(long_x, a, -h.y + wheel_r, w * (depth * 0.5 - 0.15)), wheel_r, 0.3, tire, wb, 8)
			for w in [-1, 1]:
				_box(glow, xf, _ax(long_x, front * length * 0.5, -h.y + body_y + 0.1, w * depth * 0.35),
					_ax(long_x, 0.03, 0.12, 0.2), Color(1, 0.92, 0.7))
		"booth":
			var band := s.y * 0.3
			_box(m, xf, Vector3(0, -h.y + (s.y * 0.55) * 0.5, 0), Vector3(s.x, s.y * 0.55, s.z), col)
			_box(glow, xf, Vector3(0, -h.y + s.y * 0.55 + band * 0.5, 0), Vector3(s.x * 0.96, band, s.z * 0.96), Color(0.55, 0.62, 0.5))
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_box(m, xf, Vector3(sx * (h.x - 0.05), -h.y + s.y * 0.55 + band * 0.5, sz * (h.z - 0.05)), Vector3(0.1, band, 0.1), col)
			_box(m, xf, Vector3(0, h.y - s.y * 0.075, 0), Vector3(s.x + 0.3, s.y * 0.15, s.z + 0.3), _dark(col, 0.7))
		"person":
			_person(batches, xf, s, col, seed_value)
		"sofa", "bed":
			var seat := s.y * (0.45 if kind == "sofa" else 0.6)
			_box(m, xf, Vector3(0, -h.y + seat * 0.5, 0), Vector3(s.x, seat, s.z), col)
			if kind == "sofa":
				_box(m, xf, Vector3(0, 0, -h.z + 0.12), Vector3(s.x, s.y, 0.24), _dark(col, 0.85))
				for sx in [-1, 1]:
					_box(m, xf, Vector3(sx * (h.x - 0.1), -h.y + s.y * 0.35, 0), Vector3(0.2, s.y * 0.7, s.z), _dark(col, 0.9))
				for i in 2:
					_box(m, xf, Vector3((i - 0.5) * s.x * 0.45, -h.y + seat + 0.06, 0.05),
						Vector3(s.x * 0.42, 0.12, s.z * 0.65), col.lightened(0.06))
			else:
				_box(m, xf, Vector3(0, -h.y + seat + 0.05, h.z * 0.6), Vector3(s.x * 0.8, 0.12, s.z * 0.25), Color(0.85, 0.84, 0.8))
				_box(m, xf, Vector3(0, -h.y + seat + 0.02, -h.z * 0.2), Vector3(s.x, 0.06, s.z * 0.65), _dark(col, 0.9))
		"shelf":
			for sx in [-1, 1]:
				_box(m, xf, Vector3(sx * (h.x - 0.03), 0, 0), Vector3(0.06, s.y, s.z), _dark(col, 0.8))
			var levels := maxi(2, int(s.y / 0.45))
			for i in levels:
				var y := -h.y + 0.05 + i * (s.y - 0.1) / (levels - 1)
				_box(m, xf, Vector3(0, y, 0), Vector3(s.x, 0.04, s.z), col)
				if i < levels - 1:
					for k in 3:
						var r := _hash01(seed_value, i * 10 + k)
						if r > 0.35:
							var bw := 0.12 + r * 0.25
							_box(batch(batches, "paint"), xf, Vector3(-h.x + 0.2 + k * (s.x - 0.3) / 3.0, y + 0.02 + 0.13, 0),
								Vector3(bw, 0.26, s.z * 0.7), Color.from_hsv(r, 0.35, 0.55))
		"cabinet", "kitchen":
			_box(m, xf, Vector3(0, -0.02, -0.01), s - Vector3(0, 0.04, 0.02), col)
			var doors := maxi(1, int(s.x / 0.6))
			for i in doors:
				var x := -h.x + (i + 0.5) * s.x / doors
				_box(m, xf, Vector3(x, -0.02, h.z - 0.01), Vector3(s.x / doors - 0.04, s.y - 0.12, 0.02), col.lightened(0.05))
				_box(metal, xf, Vector3(x + s.x / doors * 0.3, h.y * 0.4, h.z + 0.01), Vector3(0.02, 0.12, 0.02), Color(0.7, 0.7, 0.7))
			if kind == "kitchen":
				_box(batch(batches, "plaster"), xf, Vector3(0, h.y - 0.02, 0), Vector3(s.x + 0.04, 0.04, s.z + 0.04), Color(0.78, 0.76, 0.7))
				_box(metal, xf, Vector3(-s.x * 0.2, h.y, 0), Vector3(0.5, 0.02, s.z * 0.6), Color(0.6, 0.62, 0.64))
		"board":
			_box(m, xf, Vector3.ZERO, s, _dark(col, 0.7))
			var face_axis := 0 if s.x < s.z else 2
			var inner := s * 0.88
			inner[face_axis] = s[face_axis] + 0.01
			_box(m, xf, Vector3.ZERO, inner, col)
			for k in 4:
				var r := _hash01(seed_value, k)
				var off := Vector3((r - 0.5) * s.x * 0.6, (_hash01(seed_value, k + 9) - 0.5) * s.y * 0.6, (r - 0.5) * s.z * 0.6)
				off[face_axis] = 0.0
				var ps := Vector3(0.16, 0.22, 0.16)
				ps[face_axis] = s[face_axis] + 0.02
				_box(batch(batches, "plain"), xf, off, ps, Color(0.88, 0.86, 0.8).darkened(r * 0.15))
		"window", "door", "screen", "panel":
			var face_axis := 0 if s.x < s.z else 2
			if s.y < minf(s.x, s.z):
				face_axis = 1
			var frame := s
			frame[face_axis] = s[face_axis] * 0.6
			_box(metal, xf, Vector3.ZERO, frame, Color(0.22, 0.24, 0.26))
			var inner := s * 0.86
			inner[face_axis] = s[face_axis] + 0.01
			_box(glow, xf, Vector3.ZERO, inner, col)
			if kind == "window":
				var bar := s
				bar[face_axis] = s[face_axis] + 0.02
				bar.y = 0.05
				_box(metal, xf, Vector3.ZERO, bar, Color(0.22, 0.24, 0.26))
		"banner":
			_box(m, xf, Vector3.ZERO, s, col)
			var face_axis := 0 if s.x < s.z else 2
			var letters := int(maxf(s.x, s.z) / 0.5)
			for i in letters:
				if _hash01(seed_value, i) < 0.2:
					continue
				var t := -maxf(s.x, s.z) * 0.42 + i * maxf(s.x, s.z) * 0.84 / maxi(1, letters - 1)
				var dy := (_hash01(seed_value, i + 50) - 0.5) * 0.08
				var c := Vector3(0, dy, t) if face_axis == 0 else Vector3(t, dy, 0)
				var ls := Vector3(s.x + 0.01, s.y * 0.45, 0.26) if face_axis == 0 else Vector3(0.26, s.y * 0.45, s.z + 0.01)
				_box(batch(batches, "plain"), xf, c, ls, Color(0.92, 0.9, 0.84))
		"lamp":
			# Hanging shade: cord from the top of the box, glowing bulb at the bottom.
			_box(metal, xf, Vector3(0, 0.1, 0), Vector3(0.02, s.y - 0.2, 0.02), Color(0.1, 0.1, 0.1))
			_prism(metal, xf, Vector3(0, -h.y + 0.12, 0), minf(s.x, s.z) * 0.5, 0.16, col, Basis.IDENTITY, 8)
			_prism(glow, xf, Vector3(0, -h.y + 0.02, 0), minf(s.x, s.z) * 0.35, 0.04, Color(1, 0.92, 0.75), Basis.IDENTITY, 8)
		"lamp_post":
			_prism(m, xf, Vector3(0, 0, 0), 0.07, s.y, col, Basis.IDENTITY, 6)
			_box(m, xf, Vector3(0, h.y - 0.05, s.z * 0.25), Vector3(0.08, 0.08, s.z * 0.5), col)
			_box(glow, xf, Vector3(0, h.y - 0.12, s.z * 0.45), Vector3(0.3, 0.06, 0.18), Color(1, 0.85, 0.55))
		"conveyor":
			var legs := maxi(2, int(length / 1.6) + 1)
			var bh := 0.18
			var bs := Vector3(length, bh, depth) if long_x else Vector3(depth, bh, length)
			_box(m, xf, Vector3(0, h.y - bh * 0.5, 0), bs, col)
			var belt := Vector3(length, 0.02, depth * 0.84) if long_x else Vector3(depth * 0.84, 0.02, length)
			_box(batch(batches, "fabric"), xf, Vector3(0, h.y + 0.01, 0), belt, Color(0.12, 0.12, 0.13))
			for i in legs:
				var t := -length * 0.5 + 0.1 + i * (length - 0.2) / (legs - 1)
				for w in [-1, 1]:
					var c := Vector3(t, -bh * 0.5, w * depth * 0.4) if long_x else Vector3(w * depth * 0.4, -bh * 0.5, t)
					_box(metal, xf, c, Vector3(0.07, s.y - bh, 0.07), Color(0.32, 0.34, 0.37))
			_hazard_band(batches, xf, Vector3(0, h.y - bh - 0.02, 0), Vector3(bs.x + 0.01, 0.04, bs.z + 0.01))
		"hazard":
			_hazard_band(batches, xf, Vector3.ZERO, s)
		"fire":
			pass  # animated separately by the builder (Ambience)
		_:
			m.add_box_tiled(xf, s, col, 1.5)


## Yellow / black stripes along the longer horizontal axis of `s`.
static func _hazard_band(batches: Dictionary, xf: Transform3D, center: Vector3, s: Vector3) -> void:
	var bt := batch(batches, "paint")
	var long_x := s.x >= s.z
	var length := maxf(s.x, s.z)
	var n := maxi(2, int(length / 0.3))
	for i in n:
		var t := -length * 0.5 + (i + 0.5) * length / n
		var c := center + (Vector3(t, 0, 0) if long_x else Vector3(0, 0, t))
		var seg := Vector3(length / n, s.y, s.z) if long_x else Vector3(s.x, s.y, length / n)
		bt.add_box(xf * Transform3D(Basis.IDENTITY, c), seg, Color(0.85, 0.66, 0.12) if i % 2 == 0 else Color(0.08, 0.08, 0.08))


## Crowd stand-in (strikers at the gate): simple figure, varied clothes, some
## holding a placard. Fits the 0.45 x 1.7 collision box.
static func _person(batches: Dictionary, xf: Transform3D, s: Vector3, col: Color, seed_value: int) -> void:
	var cloth := batch(batches, "fabric")
	var skin := batch(batches, "skin")
	var h := s * 0.5
	var r1 := _hash01(seed_value, 1)
	var r2 := _hash01(seed_value, 2)
	var top := Color.from_hsv(fmod(0.55 + r1 * 0.5, 1.0), 0.25 + r2 * 0.3, 0.3 + r1 * 0.25)
	var legs := col.darkened(0.3)
	var height := s.y
	var hip := -h.y + height * 0.5
	for sx in [-1, 1]:
		_box(cloth, xf, Vector3(sx * 0.07, -h.y + height * 0.25, 0), Vector3(0.12, height * 0.5, 0.14), legs)
	_box(cloth, xf, Vector3(0, hip + height * 0.16, 0), Vector3(0.36, height * 0.34, 0.22), top)
	for sx in [-1, 1]:
		_box(cloth, xf, Vector3(sx * 0.22, hip + height * 0.12, 0), Vector3(0.09, height * 0.36, 0.1), top.darkened(0.1))
	var skin_col := Color(0.78, 0.6, 0.47).darkened(r2 * 0.3)
	_prism(skin, xf, Vector3(0, h.y - 0.13, 0), 0.1, 0.22, skin_col, Basis.IDENTITY, 6)
	_prism(cloth, xf, Vector3(0, h.y - 0.03, -0.01), 0.105, 0.06, Color(0.12, 0.1, 0.09), Basis.IDENTITY, 6)
	if r1 > 0.55:
		_box(batch(batches, "wood"), xf, Vector3(0.22, h.y + 0.15, 0.05), Vector3(0.03, 0.9, 0.03), Color(0.45, 0.35, 0.25))
		_box(batch(batches, "plain"), xf, Vector3(0.22, h.y + 0.45, 0.07), Vector3(0.5, 0.32, 0.02), Color(0.9, 0.88, 0.82))
		_box(batch(batches, "plain"), xf, Vector3(0.22, h.y + 0.45, 0.085), Vector3(0.36, 0.06, 0.01), Color(0.7, 0.18, 0.15))
