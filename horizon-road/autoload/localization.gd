extends Node
## Thin wrapper around TranslationServer: picks a supported language,
## remembers the player's choice and notifies UI built in code.

signal locale_changed(locale: String)

const SUPPORTED: Array[String] = ["tr", "en"]


func _ready() -> void:
	var saved: String = SaveManager.get_setting("general", "locale", "")
	if saved in SUPPORTED:
		TranslationServer.set_locale(saved)
	else:
		var system_lang: String = OS.get_locale_language()
		TranslationServer.set_locale(system_lang if system_lang in SUPPORTED else "en")


func get_locale() -> String:
	return TranslationServer.get_locale().substr(0, 2)


func set_locale(locale: String) -> void:
	if locale not in SUPPORTED:
		return
	TranslationServer.set_locale(locale)
	SaveManager.set_setting("general", "locale", locale)
	locale_changed.emit(locale)


func cycle_locale() -> void:
	var index: int = SUPPORTED.find(get_locale())
	set_locale(SUPPORTED[(index + 1) % SUPPORTED.size()])
