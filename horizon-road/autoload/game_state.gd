extends Node
## Global, save-relevant game state. Other systems listen to its signals
## instead of reaching into each other.

signal money_changed(new_amount: int)
signal player_mode_changed(mode: PlayerMode)
signal region_changed(region_id: StringName)

enum PlayerMode { DRIVING, ON_FOOT }

var player_name: String = "Gezgin"
var money: int = 0
var current_region_id: StringName = &""
var player_mode: PlayerMode = PlayerMode.DRIVING:
	set = set_player_mode
## Runtime only (not saved): the active region root, so systems can query terrain.
var current_region: Region = null


func _ready() -> void:
	InputSetup.register_default_actions()
	if DevCli.is_requested():
		add_child(DevCli.new())


func set_player_mode(mode: PlayerMode) -> void:
	if mode == player_mode:
		return
	player_mode = mode
	player_mode_changed.emit(mode)


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
	}


func from_dict(data: Dictionary) -> void:
	player_name = data.get("player_name", player_name)
	money = int(data.get("money", 0))
	current_region_id = StringName(data.get("region", ""))
	money_changed.emit(money)
