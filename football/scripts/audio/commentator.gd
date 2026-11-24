class_name Commentator
extends Node
## Spiker altyapısı: olaylar öncelikli bir kuyruğa girer, aynı olay için bekleme süresi uygulanır.
## Ses dosyaları data/commentary.json'da (şimdilik boş); yoksa yalnızca altyazı metni yayınlanır.

signal line(event: String, text: String)

const DATA_PATH := "res://data/commentary.json"
const MAX_QUEUE := 3

var lines := {} # olay -> [{"audio": yol, "tr": metin, "en": metin}, ...]
var priorities := {}
var cooldowns := {}
var player: AudioStreamPlayer

var _queue: Array = [] # [{event, priority}]
var _busy := 0.0
var _last := {} # olay -> kalan bekleme
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	load_data()
	player = AudioStreamPlayer.new()
	player.bus = &"SFX"
	add_child(player)


func load_data(path := DATA_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	for ev in data.get("events", {}):
		var e: Dictionary = data.events[ev]
		priorities[ev] = int(e.get("priority", 1))
		cooldowns[ev] = float(e.get("cooldown", 5.0))
		lines[ev] = e.get("lines", [])


## Olayı kuyruğa ekler. Bekleme süresindeyse yok sayılır. Kabul edilirse true.
func say(event: String) -> bool:
	if _last.get(event, 0.0) > 0.0:
		return false
	_last[event] = cooldowns.get(event, 5.0)
	_queue.append({"event": event, "priority": priorities.get(event, 1)})
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.priority > b.priority)
	if _queue.size() > MAX_QUEUE:
		_queue.resize(MAX_QUEUE) # düşük öncelikliler düşer
	return true


func queue_events() -> Array:
	return _queue.map(func(q: Dictionary) -> String: return q.event)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	for k in _last.keys():
		_last[k] -= delta
	_busy -= delta
	if _busy > 0.0 or _queue.is_empty():
		return
	var item: Dictionary = _queue.pop_front()
	var options: Array = lines.get(item.event, [])
	var text := ""
	_busy = 1.5
	if not options.is_empty():
		var pick: Dictionary = options[_rng.randi_range(0, options.size() - 1)]
		text = str(pick.get(TranslationServer.get_locale().substr(0, 2), pick.get("tr", "")))
		var audio_path := str(pick.get("audio", ""))
		if audio_path != "" and ResourceLoader.exists(audio_path):
			var stream: AudioStream = load(audio_path)
			player.stream = stream
			player.play()
			_busy = stream.get_length() + 0.3
	line.emit(item.event, text)
