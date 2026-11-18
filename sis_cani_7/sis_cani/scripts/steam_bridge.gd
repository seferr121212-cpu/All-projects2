class_name SteamBridge
extends RefCounted
## Steam başarımları için ince katman. GodotSteam eklentisi kuruluysa çalışır, yoksa sessizce geçer.
## Steamworks'te başarım API adları: ACH_NO_DARK, ACH_POSTMAN, ACH_BELL, ACH_SILENCE, ACH_DARK

static func available() -> bool:
	return Engine.has_singleton("Steam")


static func unlock(id: String) -> void:
	if not available():
		return
	var steam = Engine.get_singleton("Steam")
	steam.call("setAchievement", "ACH_" + id)
	steam.call("storeStats")
