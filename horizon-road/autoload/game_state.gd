extends Node
## Global, save-relevant game state. Other systems listen to its signals
## instead of reaching into each other.

signal money_changed(new_amount: int)
signal player_mode_changed(mode: PlayerMode)
signal region_changed(region_id: StringName)
signal context_changed(context: Context)
signal relationship_changed(npc_id: StringName, points: int, level: int)
signal flags_changed
signal upgrades_changed
signal fuel_changed(liters: float)
## Short on-screen message for the HUD (already translated text).
signal notified(text: String)

enum PlayerMode { DRIVING, ON_FOOT, INTERIOR }
## Who owns player input right now. Gameplay systems ignore input outside GAMEPLAY.
enum Context { GAMEPLAY, PHOTO, JOURNAL, DIALOGUE, MENU, SKETCH }

static var ECONOMY: EconomyConfig = load("res://data/economy/economy_config.tres")

## All regions of the journey: id -> definition resource.
const REGIONS: Dictionary = {
	&"blacksea_highland": "res://data/regions/blacksea_highland.tres",
	&"aegean_village": "res://data/regions/aegean_village.tres",
	&"cappadocia": "res://data/regions/cappadocia.tres",
	&"eastern_plateau": "res://data/regions/eastern_plateau.tres",
}
const TRAVEL_FUEL_SHARE: float = 0.6

var qa: QaReport
var player_name: String = ""
var money: int = ECONOMY.starting_money
## npc id -> relationship points
var relationships: Dictionary = {}
## Story/world flags, e.g. "fadime.met". Namespaced by NPC or system.
var flags: Dictionary = {}
## upgrade id -> level (0 = stock)
var upgrades: Dictionary = {}
var fuel: float = ECONOMY.base_tank_capacity
## People met: npc id -> {name_key, role_key, note_key, region}
var people: Dictionary = {}
## Small numeric counters, e.g. "fadime.harvests" or "photo_sales.day".
var counters: Dictionary = {}
var current_region_id: StringName = &""
var player_mode: PlayerMode = PlayerMode.DRIVING:
	set = set_player_mode
var context: Context = Context.GAMEPLAY
## Camera lens upgrade level (0 = kit lens). Upgrades arrive in stage 4.
var lens_level: int = 0
## Photo album persists itself under user://photos, independent of save slots.
var album := PhotoAlbum.new()
## Sketchbook, also independent of save slots.
var drawings := DrawingBook.new()
## Set while travelling: the next region spawns the camper at its road gate.
var arrival_pending: bool = false
## False until the first region has loaded (start-of-game time setup).
var journey_started: bool = false
var _loading_screen: LoadingScreen
## The title screen has been dealt with this session (continue / new game).
var title_done: bool = false
var _title: TitleMenu
## Runtime only (not saved): the active region root, so systems can query terrain.
var current_region: Region = null


func _ready() -> void:
	InputSetup.register_default_actions()
	# After every autoload exists (audio buses, clock), apply saved settings.
	Settings.apply_all.call_deferred()
	album.load_index()
	drawings.load_index()
	add_child(QuestLog.new())
	qa = QaReport.new()
	qa.name = "QaReport"
	add_child(qa)
	if DevCli.is_requested():
		add_child(DevCli.new())


func set_player_mode(mode: PlayerMode) -> void:
	if mode == player_mode:
		return
	player_mode = mode
	player_mode_changed.emit(mode)


# --- Regions & travel ---------------------------------------------------------

func get_region_def(id: StringName) -> RegionDefinition:
	return load(REGIONS[id]) if REGIONS.has(id) else null


## Hours on the road between two regions (straight line on the country map, 70 km/h).
func travel_hours(from_id: StringName, to_id: StringName) -> float:
	var a: RegionDefinition = get_region_def(from_id)
	var b: RegionDefinition = get_region_def(to_id)
	return roundf(a.map_position.distance_to(b.map_position) / 70.0 * 2.0) / 2.0


func travel_km(from_id: StringName, to_id: StringName) -> int:
	return roundi(get_region_def(from_id).map_position.distance_to(get_region_def(to_id).map_position) / 10.0) * 10


## Drive to another region: autosave, loading curtain, time and fuel pass,
## then the new region scene loads with the camper at its road gate.
func travel_to(id: StringName) -> void:
	var target: RegionDefinition = get_region_def(id)
	if target == null or id == current_region_id:
		return
	for node: Node in get_tree().get_nodes_in_group(&"activity"):
		(node as Activity).cancel()
	SaveManager.autosave()
	var from_id: StringName = current_region_id
	var hours: float = travel_hours(from_id, id)
	set_context(Context.MENU)
	if _loading_screen == null:
		_loading_screen = LoadingScreen.new()
		add_child(_loading_screen)
	await _loading_screen.show_journey(from_id, id, hours, travel_km(from_id, id))
	TimeManager.advance_hours(hours)
	use_fuel(get_tank_capacity() * TRAVEL_FUEL_SHARE)
	arrival_pending = true
	current_region = null
	set_context(Context.GAMEPLAY)
	get_tree().paused = false
	get_tree().change_scene_to_file(target.scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	_loading_screen.hide_curtain()


# --- Title & new game ---------------------------------------------------------

func show_title() -> void:
	if _title == null:
		_title = TitleMenu.new()
		add_child(_title)
	get_tree().paused = false
	_title.open()


## Fresh journey: wipe progress (the album and sketchbook stay -- they are the
## player's own pictures) and restart in the first region.
func new_game() -> void:
	SaveManager.delete_all_saves()
	player_name = ""
	money = ECONOMY.starting_money
	relationships = {}
	flags = {}
	counters = {}
	people = {}
	upgrades = {}
	lens_level = 0
	fuel = ECONOMY.base_tank_capacity
	TimeManager.day = 1
	TimeManager.forced_season = -1
	journey_started = false
	arrival_pending = false
	title_done = true
	WeatherManager.auto_change = true
	player_mode = PlayerMode.DRIVING
	current_region = null
	current_region_id = &""
	money_changed.emit(money)
	set_context(Context.GAMEPLAY)
	get_tree().paused = false
	get_tree().change_scene_to_file(get_region_def(REGIONS.keys()[0]).scene_path)


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



func get_display_name() -> String:
	return player_name if player_name != "" else tr(&"PLAYER_DEFAULT_NAME")


# --- Relationships & flags --------------------------------------------------

func get_relationship(npc_id: StringName) -> int:
	return int(relationships.get(String(npc_id), 0))


func add_relationship(npc_id: StringName, points: int) -> void:
	var value: int = maxi(get_relationship(npc_id) + points, 0)
	relationships[String(npc_id)] = value
	relationship_changed.emit(npc_id, value, get_relationship_level(npc_id))


## 0 stranger, 1 acquaintance, 2 friend, 3 close friend.
func get_relationship_level(npc_id: StringName) -> int:
	var points: int = get_relationship(npc_id)
	var level: int = 0
	for i: int in ECONOMY.level_thresholds.size():
		if points >= ECONOMY.level_thresholds[i]:
			level = i
	return level


# --- Upgrades & fuel ---------------------------------------------------------

func get_upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func upgrade_effect(id: String, key: String, default: float) -> float:
	return UpgradeCatalog.effect(id, get_upgrade_level(id), key, default)


## Price after the friendship discount of the seller (if any).
func upgrade_price(id: String, seller: StringName = &"") -> int:
	var base: int = UpgradeCatalog.next_price(id, get_upgrade_level(id))
	if base < 0:
		return -1
	var discount: float = 0.0
	if seller != &"":
		discount = ECONOMY.friend_discount_per_level * get_relationship_level(seller)
	return roundi(base * (1.0 - discount))


func buy_upgrade(id: String, seller: StringName = &"") -> bool:
	var price: int = upgrade_price(id, seller)
	if price < 0 or not spend_money(price):
		return false
	upgrades[id] = get_upgrade_level(id) + 1
	lens_level = int(upgrade_effect("lens", "lens_level", 0.0))
	upgrades_changed.emit()
	return true


func get_tank_capacity() -> float:
	return upgrade_effect("fuel_tank", "tank_capacity", ECONOMY.base_tank_capacity)


func use_fuel(liters: float) -> void:
	fuel = maxf(fuel - liters, 0.0)
	fuel_changed.emit(fuel)


## Fills up as far as the wallet allows. Returns liters bought.
func refuel() -> float:
	var missing: float = get_tank_capacity() - fuel
	var affordable: float = money / ECONOMY.fuel_price_per_liter
	var liters: float = floorf(minf(missing, affordable))
	if liters <= 0.0:
		return 0.0
	spend_money(ceili(liters * ECONOMY.fuel_price_per_liter))
	fuel += liters
	fuel_changed.emit(fuel)
	return liters


func register_person(npc_id: StringName, name_key: String, role_key: String, note_key: String) -> void:
	people[String(npc_id)] = {"name_key": name_key, "role_key": role_key, "note_key": note_key, "region": String(current_region_id)}


func notify(text: String) -> void:
	notified.emit(text)


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func set_flag(flag: String, value: bool = true) -> void:
	if value:
		flags[flag] = true
	else:
		flags.erase(flag)
	flags_changed.emit()


func get_counter(key: String) -> int:
	return int(counters.get(key, 0))


func set_counter(key: String, value: int) -> void:
	counters[key] = value
	flags_changed.emit()


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
		"relationships": relationships,
		"flags": flags,
		"counters": counters,
		"people": people,
		"upgrades": upgrades,
		"fuel": fuel,
	}


func from_dict(data: Dictionary) -> void:
	player_name = data.get("player_name", player_name)
	money = int(data.get("money", ECONOMY.starting_money))
	current_region_id = StringName(data.get("region", ""))
	lens_level = int(data.get("lens_level", 0))
	relationships = data.get("relationships", {})
	flags = data.get("flags", {})
	counters = data.get("counters", {})
	people = data.get("people", {})
	upgrades = data.get("upgrades", {})
	lens_level = int(upgrade_effect("lens", "lens_level", 0.0))
	fuel = float(data.get("fuel", get_tank_capacity()))
	upgrades_changed.emit()
	fuel_changed.emit(fuel)
	flags_changed.emit()
	money_changed.emit(money)
