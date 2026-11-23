class_name Ball
extends RigidBody3D
## Futbol topu: hava direnci, Magnus etkisi (falso), çimde yuvarlanma direnci,
## file içinde sönümleme. Vuruşlar kick() ile verilir.

signal kicked(team: int)

const GRAVITY := 9.81

@export var params: BallPhysicsParams

## Topa son dokunan takım (-1: yok). Korner/aut/taç kararında kullanılır.
var last_touch_team := -1
var grounded := false

var _net_count := 0
var _net_damping := 0.0
var _reset_pending := false
var _reset_position := Vector3.ZERO


func _ready() -> void:
	if params == null:
		params = BallPhysicsParams.new()
	mass = params.mass
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	can_sleep = false


## velocity: m/s, spin: rad/s (açısal hız vektörü), team: vuran takım.
func kick(velocity: Vector3, spin: Vector3, team := -1) -> void:
	linear_velocity = velocity
	angular_velocity = spin
	last_touch_team = team
	kicked.emit(team)


## Topu durdurup verilen konuma ışınlar (fizik adımında uygulanır).
func reset_to(pos: Vector3) -> void:
	_reset_position = pos
	_reset_pending = true
	last_touch_team = -1


func set_in_net(inside: bool, damping: float) -> void:
	_net_count = maxi(0, _net_count + (1 if inside else -1))
	_net_damping = damping


func is_in_net() -> bool:
	return _net_count > 0


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _reset_pending:
		_reset_pending = false
		var t := state.transform
		t.origin = _reset_position
		state.transform = t
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return

	var dt := state.step
	var v := state.linear_velocity
	var w := state.angular_velocity
	grounded = state.transform.origin.y < params.radius + 0.02 and v.y < 0.5

	if grounded:
		state.apply_central_force(compute_drag(v, params))
		_apply_rolling_resistance(state, dt)
	else:
		state.apply_central_force(compute_aero_force(v, w, params))
		state.angular_velocity = w * maxf(0.0, 1.0 - params.spin_decay * dt)

	if _net_count > 0:
		var k := exp(-_net_damping * dt)
		state.linear_velocity *= k
		state.angular_velocity *= k


func _apply_rolling_resistance(state: PhysicsDirectBodyState3D, dt: float) -> void:
	var v := state.linear_velocity
	var vh := Vector3(v.x, 0.0, v.z)
	var speed := vh.length()
	var decel := params.rolling_resistance * GRAVITY
	if speed <= decel * dt:
		# Top durdu: kalan kaymayı ve dönüşü sıfırla
		state.linear_velocity = Vector3(0.0, v.y, 0.0)
		state.angular_velocity = Vector3.ZERO
	else:
		state.apply_central_force(-vh / speed * decel * params.mass)


## Yalnızca hava direnci: F = -0.5·ρ·Cd·A·|v|·v
static func compute_drag(v: Vector3, p: BallPhysicsParams) -> Vector3:
	var area := PI * p.radius * p.radius
	return -v * v.length() * 0.5 * p.air_density * area * p.drag_coefficient


## Hava direnci + Magnus kuvveti (N).
static func compute_aero_force(v: Vector3, w: Vector3, p: BallPhysicsParams) -> Vector3:
	var speed := v.length()
	if speed < 0.001:
		return Vector3.ZERO
	var q := 0.5 * p.air_density * PI * p.radius * p.radius
	var magnus := w.cross(v) * q * p.radius * p.magnus_coefficient
	var max_magnus := q * speed * speed * p.max_lift_coefficient
	if magnus.length() > max_magnus:
		magnus = magnus.normalized() * max_magnus
	return compute_drag(v, p) + magnus
