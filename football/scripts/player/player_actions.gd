class_name PlayerActions
extends RefCounted
## Pas/orta/şut vuruş hızlarını hesaplayan saf fonksiyonlar (test edilebilir).

const GRAVITY := 9.81
## Yerde yavaşlama (yuvarlanma direnci + yaklaşık hava direnci)
const ROLL_DECEL := 0.15 * 9.81 + 0.25


static func horizontal(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Yer pası: hedefe arrive_speed hızla varacak şekilde.
static func ground_pass_velocity(from: Vector3, to: Vector3, arrive_speed := 4.0) -> Vector3:
	var d := horizontal(to - from)
	var speed := sqrt(arrive_speed * arrive_speed + 2.0 * ROLL_DECEL * d.length())
	return d.normalized() * clampf(speed, 5.0, 24.0)


## Havadan pas/orta: verilen yükseliş açısıyla hedefe düşecek balistik hız (+ sürtünme payı).
static func lob_velocity(from: Vector3, to: Vector3, elevation_deg := 35.0) -> Vector3:
	var d := horizontal(to - from)
	var dist := d.length()
	var th := deg_to_rad(elevation_deg)
	var speed := sqrt(dist * GRAVITY / sin(2.0 * th)) * (1.0 + dist * 0.004)
	speed = minf(speed, 30.0)
	return d.normalized() * cos(th) * speed + Vector3.UP * sin(th) * speed


## Şut: power 0..1. Aşırı güç topu yükseltir.
static func shot_velocity(from: Vector3, target: Vector3, power: float, shooting: int) -> Vector3:
	var speed := lerpf(14.0, 31.0, power) * (0.85 + 0.15 * PlayerStats.ratio(shooting))
	var dist := horizontal(target - from).length()
	var elev := lerpf(5.0, 11.0, power) + maxf(0.0, power - 0.9) * 80.0 + maxf(0.0, dist - 25.0) * 0.12
	var th := deg_to_rad(elev)
	var dir := horizontal(target - from).normalized()
	return dir * cos(th) * speed + Vector3.UP * sin(th) * speed


## Beceriye bağlı yatay sapma (derece). power yüksekse hata büyür.
static func apply_error(v: Vector3, skill: int, power: float, rng: RandomNumberGenerator) -> Vector3:
	var max_err := (1.0 - PlayerStats.ratio(skill)) * 8.0 * (0.5 + power)
	return v.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-max_err, max_err)))


## Koşan oyuncunun önüne atılacak nokta.
static func lead_target(from: Vector3, mate_pos: Vector3, mate_vel: Vector3, ball_speed: float, extra: Vector3) -> Vector3:
	var t := horizontal(mate_pos - from).length() / maxf(ball_speed, 1.0)
	return mate_pos + horizontal(mate_vel) * t + extra
