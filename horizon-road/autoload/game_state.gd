extends Node
## Global, save-relevant game state. Other systems listen to its signals
## instead of reaching into each other.

signal money_changed(new_amount: int)
signal player_mode_changed(mode: PlayerMode)
signal region_changed(region_id: StringName)
signal context_changed(context: Context)

enum PlayerMode { DRIVING, ON_FOOT }
## Who owns player input right now. Gameplay systems ignore input outside GAMEPLAY.
enum Context { GAMEPLAY, PHOTO, JOURNAL }

var player_name: String = "Gezgin"
var money: int = 0
var current_region_id: StringName = &""
var player_mode: PlayerMode = PlayerMode.DRIVING:
	set = set_player_mode
var context: Context = Context.GAMEPLAY
## Camera lens upgrade level (0 = kit lens). Upgrades arrive in stage 4.
var lens_level: int = 0
## Photo album persists itself under user://photos, independent of save slots.
var album := PhotoAlbum.new()
## Runtime only (not saved): the active region root, so systems can query terrain.
var current_region: Region = null


func _ready() -> void:
	InputSetup.register_default_actions()
	album.load_index()
	if DevCli.is_requested():
		add_child(DevCli.new())


func set_player_mode(mode: PlayerMode) -> void:
	if mode == player_mode:
		return
	player_mode = mode
	player_mode_changed.emit(mode)


func set_context(value: Context) -> void:
	if value == context:
		return
	context = value
	context_changed.emit(value)


func is_gameplay() -> bool:
	return context == Context.GAMEPLAY


func register_region(region: Region) -> void:
	current_region = region
	if region.definition and region.definition.id != current_region_id:
		current_region_id = region.definition.id
		region_changed.emit(current_region_id)


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	money_changed.emit(money)
	return true


func to_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"money": money,
		"region": String(current_region_id),
		"lens_level": lens_level,
	}


func from_dict(data: Dictionary) -> void:
	player_name = data.get("player_name", player_name)
	money = int(data.get("money", 0))
	current_region_id = StringName(data.get("region", ""))
	lens_level = int(data.get("lens_level", 0))
	money_changed.emit(money)
