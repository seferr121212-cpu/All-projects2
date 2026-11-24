class_name Dribble
extends RefCounted
## Top sürme: top ayağa yapışık değildir; oyuncunun önündeki hedef noktaya
## küçük dokunuşlarla itilir. Hızlı koşuda top daha öne gider.


static func lead_distance(speed: float, dribbling: int) -> float:
	return 0.55 + speed * 0.12 * (1.3 - PlayerStats.ratio(dribbling))


## Dokunuş gerekiyorsa {"need": true, "velocity": Vector3} döner.
static func compute_touch(player_pos: Vector3, player_vel: Vector3, facing: Vector3, ball_pos: Vector3, dribbling: int) -> Dictionary:
	var pv := Vector3(player_vel.x, 0.0, player_vel.z)
	var lead := lead_distance(pv.length(), dribbling)
	var target := player_pos + facing * lead
	var to := Vector3(target.x - ball_pos.x, 0.0, target.z - ball_pos.z)
	var ahead := Vector3(ball_pos.x - player_pos.x, 0.0, ball_pos.z - player_pos.z).dot(facing)
	# Top geride/yanda kaldıysa ya da fazla öne kaçtıysa dokun
	var need := ahead < lead * 0.7 or ahead > lead * 1.6 or to.length() > 0.35
	var v := pv + to * 2.2
	# Top, oyuncunun hızından fazla kaçmasın (sprintte topu kaybetmeyi önler)
	return {"need": need, "velocity": v.limit_length(pv.length() + 1.8)}


static func touch_cooldown(dribbling: int) -> float:
	return lerpf(0.35, 0.18, PlayerStats.ratio(dribbling))
