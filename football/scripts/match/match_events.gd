class_name MatchEvents
extends Node
## Gol, taç, korner ve aut algılama. Kural: topun TAMAMI çizgiyi geçmeli.
## Karar topun merkez konumu + yarıçapı ile matematiksel verilir (tünelleme yok).
## Takımlar: HOME (0) -X kalesini savunur, AWAY (1) +X kalesini savunur.

signal event_detected(event: Dictionary)

enum EventType { NONE, GOAL, THROW_IN, CORNER, GOAL_KICK }

const HOME := 0
const AWAY := 1
const PD = PitchDimensions

@export var ball_path: NodePath

var ball: Ball
var ball_in_play := true


func _ready() -> void:
	if ball == null and not ball_path.is_empty():
		ball = get_node_or_null(ball_path) as Ball


func _physics_process(_delta: float) -> void:
	if ball == null or not ball_in_play:
		return
	var ev := classify(ball.global_position, PD.BALL_RADIUS, ball.last_touch_team)
	if ev.type != EventType.NONE:
		ball_in_play = false
		event_detected.emit(ev)


func restart_play() -> void:
	ball_in_play = true


## Saf fonksiyon: konuma göre olay döndürür. team = olayla hak kazanan takım.
static func classify(pos: Vector3, r: float, last_touch: int) -> Dictionary:
	if absf(pos.x) > PD.HALF_LENGTH + r:
		var s := 1 if pos.x > 0.0 else -1
		var defending := AWAY if s > 0 else HOME
		var attacking := 1 - defending
		if absf(pos.z) < PD.GOAL_WIDTH * 0.5 and pos.y < PD.GOAL_HEIGHT:
			return _event(EventType.GOAL, attacking, pos, s)
		if last_touch == defending:
			return _event(EventType.CORNER, attacking, pos, s)
		return _event(EventType.GOAL_KICK, defending, pos, s)
	if absf(pos.z) > PD.HALF_WIDTH + r:
		var team := HOME if last_touch == AWAY else AWAY
		if last_touch < 0:
			team = HOME
		return _event(EventType.THROW_IN, team, pos, 1 if pos.z > 0.0 else -1)
	return _event(EventType.NONE, -1, pos, 0)


static func _event(type: EventType, team: int, pos: Vector3, side: int) -> Dictionary:
	return {"type": type, "team": team, "position": pos, "side": side}


static func describe(ev: Dictionary) -> String:
	var names := {
		EventType.NONE: "-",
		EventType.GOAL: "GOL",
		EventType.THROW_IN: "TAÇ",
		EventType.CORNER: "KORNER",
		EventType.GOAL_KICK: "AUT",
	}
	var team_name := "Ev sahibi" if ev.team == HOME else "Deplasman"
	return "%s (%s)" % [names[ev.type], team_name]
