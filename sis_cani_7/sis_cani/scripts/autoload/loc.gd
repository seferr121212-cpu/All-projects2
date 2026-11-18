extends Node
## Yerelleştirme. Tüm metinler scripts/data/strings_db.gd içinde (tools/strings_source.py'den üretilir).

signal language_changed

var lang: String = "tr"        # altyazı / arayüz dili
var voice_lang: String = "tr"  # seslendirme dili


func _idx() -> int:
	return 0 if lang == "tr" else 1


func t(key: String) -> String:
	var i := _idx()
	if StringsDB.UI.has(key):
		return str(StringsDB.UI[key][i])
	if StringsDB.LINES.has(key):
		return str(StringsDB.LINES[key][2 + i])
	return key


func has_line(key: String) -> bool:
	return StringsDB.LINES.has(key)


func speaker(key: String) -> String:
	if StringsDB.LINES.has(key):
		return str(StringsDB.LINES[key][0])
	return ""


func speaker_name(key: String) -> String:
	return t("SPK_" + speaker(key))


func filter(key: String) -> String:
	if StringsDB.LINES.has(key):
		return str(StringsDB.LINES[key][1])
	return "none"


func set_language(l: String) -> void:
	lang = l
	language_changed.emit()
