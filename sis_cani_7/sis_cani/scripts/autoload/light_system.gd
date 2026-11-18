extends Node
## Işık sistemi. Hem görüntüyü (karanlık shader'ı) hem oyun kurallarını (Yankı donması)
## aynı verilerden besler; oyuncunun gördüğü ışık ile oyunun "ışık" saydığı alan hep aynıdır.
##
## Kaynak arayüzü (her ışık kaynağı düğümü):
##   is_light_on() -> bool
##   get_light_circles() -> Array[Vector4]   # (x, y, yarıçap, şiddet) dünya koordinatı
##   is_static_light() -> bool               # kandil gibi kalıcı ışık mı

var sources: Array = []
var lamp = null   # oyuncunun lambası (koni + huzme verisi için)


func register(n: Node) -> void:
	if not n in sources:
		sources.append(n)


func unregister(n: Node) -> void:
	sources.erase(n)


func clear() -> void:
	sources.clear()
	lamp = null


func _valid_sources() -> Array:
	var out: Array = []
	for s in sources:
		if is_instance_valid(s) and s.is_inside_tree():
			out.append(s)
	sources = out
	return out


## Bir noktanın ışıkta olup olmadığı. core: görsel yarıçapın ne kadarı "güvenli" sayılır.
func is_lit(p: Vector2, margin := 0.0, static_only := false) -> bool:
	for s in _valid_sources():
		if not s.is_light_on():
			continue
		if static_only and not s.is_static_light():
			continue
		for c in s.get_light_circles():
			var v: Vector4 = c
			if v.w < 0.3:
				continue
			if p.distance_to(Vector2(v.x, v.y)) < v.z * 0.8 + margin:
				return true
	if not static_only and lamp and is_instance_valid(lamp) and lamp.has_method("lights_extra"):
		if lamp.lights_extra(p, margin):
			return true
	return false


func is_lit_static(p: Vector2) -> bool:
	return is_lit(p, 0.0, true)


func gather_circles() -> Array:
	var out: Array = []
	for s in _valid_sources():
		if s.is_light_on():
			out.append_array(s.get_light_circles())
	return out
