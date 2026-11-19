extends Node
## Loads every player-facing string from data/locale/<lang>.json.
## Strings are also registered with TranslationServer, so Controls whose
## text is a locale key re-translate automatically when the language changes.

signal locale_changed(locale: String)

const LOCALE_DIR := "res://data/locale/"
const SUPPORTED: PackedStringArray = ["tr", "en"]
const DEFAULT_LOCALE := "tr"

var current_locale: String = DEFAULT_LOCALE
var _tables: Dictionary = {}


func _ready() -> void:
	for loc in SUPPORTED:
		var table := _load_table(loc)
		_tables[loc] = table
		var translation := Translation.new()
		translation.locale = loc
		for key: String in table:
			translation.add_message(key, table[key])
		TranslationServer.add_translation(translation)
	TranslationServer.set_locale(DEFAULT_LOCALE)


func _load_table(loc: String) -> Dictionary:
	var path := LOCALE_DIR + loc + ".json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Localization: cannot open %s" % path)
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Localization: invalid JSON in %s" % path)
		return {}
	var out := {}
	for key: String in data:
		if not key.begins_with("_"):
			out[key] = str(data[key])
	return out


func set_locale(loc: String) -> void:
	if not loc in SUPPORTED:
		loc = DEFAULT_LOCALE
	if loc == current_locale and TranslationServer.get_locale() == loc:
		return
	current_locale = loc
	TranslationServer.set_locale(loc)
	locale_changed.emit(loc)


func next_locale() -> String:
	var i := SUPPORTED.find(current_locale)
	return SUPPORTED[(i + 1) % SUPPORTED.size()]


func has_key(key: String) -> bool:
	return (_tables.get(current_locale, {}) as Dictionary).has(key)


func keys(loc: String) -> Array:
	return (_tables.get(loc, {}) as Dictionary).keys()


## Translate a key; missing keys fall back to the default locale and are
## shown bracketed so they are obvious in play-tests.
func t(key: String, params: Dictionary = {}) -> String:
	var table: Dictionary = _tables.get(current_locale, {})
	var text: String
	if table.has(key):
		text = table[key]
	else:
		var fallback: Dictionary = _tables.get(DEFAULT_LOCALE, {})
		text = fallback.get(key, "[" + key + "]")
	if not params.is_empty():
		text = text.format(params)
	return text
