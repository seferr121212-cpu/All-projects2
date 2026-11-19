class_name TeaBrewingActivity
extends MiniGameActivity
## Fadime's second job: brew tea the Rize way in a çaydanlık. Three taps:
## catch the kettle at the boil, steep the pot to a deep "tavşan kanı" red,
## then pour the brew to the line before topping up with water.

enum Step { BOIL, STEEP, POUR, WATER }

var step: Step = Step.BOIL
var temp: float = 0.0
var steep: float = 0.0
var brew: float = 0.0
var fill: float = 0.0
var pouring: bool = false
var marks: Array[float] = []
var _t: float = 0.0


func _ready() -> void:
	activity_id = &"tea_brew"
	npc_id = &"fadime"
	prompt_key = "ACT_BREW_SIT"
	title_key = "ACT_BREW_TITLE"
	help_key = "ACT_BREW_HELP_BOIL"
	base_pay = ECONOMY.brewing_pay
	super._ready()


func _game_start() -> void:
	step = Step.BOIL
	temp = 60.0
	steep = 0.0
	brew = 0.0
	fill = 0.0
	marks.clear()
	_t = 0.0


func _game_input(event: InputEvent) -> bool:
	if step == Step.POUR or step == Step.WATER:
		if is_press(event):
			pouring = true
			return true
		if is_release(event) and pouring:
			pouring = false
			_next_pour()
			return true
		return false
	if not is_press(event):
		return false
	match step:
		Step.BOIL:
			# Best right at a rolling boil (98-100), poor if early.
			marks.append(clampf(1.0 - absf(temp - 99.0) / 14.0, 0.0, 1.0))
			step = Step.STEEP
			hint.text = tr(&"ACT_BREW_HELP_STEEP")
		Step.STEEP:
			marks.append(clampf(1.0 - absf(steep - 0.72) / 0.35, 0.0, 1.0))
			step = Step.POUR
			hint.text = tr(&"ACT_BREW_HELP_POUR")
	return true


func _next_pour() -> void:
	if step == Step.POUR:
		marks.append(clampf(1.0 - absf(brew - 0.4) / 0.3, 0.0, 1.0))
		step = Step.WATER
		hint.text = tr(&"ACT_BREW_HELP_WATER")
	else:
		marks.append(clampf(1.0 - absf(fill - 0.9) / 0.25, 0.0, 1.0) * (0.0 if fill > 1.0 else 1.0))
		var total: float = 0.0
		for m: float in marks:
			total += m
		finish_game(total / marks.size())


func _game_process(delta: float) -> void:
	_t += delta
	match step:
		Step.BOIL:
			temp = minf(temp + delta * 9.0, 104.0)
			if temp >= 104.0:
				temp = 92.0  # boiled over: the lid rattles, it settles back
		Step.STEEP:
			steep = minf(steep + delta * 0.09, 1.2)
		Step.POUR:
			if pouring:
				brew = minf(brew + delta * 0.35, 1.1)
				fill = brew
		Step.WATER:
			if pouring:
				fill = minf(fill + delta * 0.4, 1.15)


func tea_color() -> Color:
	var strength: float = brew / maxf(fill, 0.01) * steep
	return Color(0.95, 0.75, 0.4).lerp(Color(0.62, 0.12, 0.05), clampf(strength * 1.6, 0.0, 1.0)).lerp(Color(0.25, 0.06, 0.03), clampf(strength * 1.6 - 1.0, 0.0, 1.0))


func _game_draw(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.9, 0.85, 0.76))
	# Double teapot: kettle below, brew pot on top.
	var kx: float = 170.0
	c.draw_rect(Rect2(Vector2(kx - 90, 190), Vector2(180, 130)), Color(0.75, 0.76, 0.78))
	c.draw_rect(Rect2(Vector2(kx - 60, 110), Vector2(120, 80)), Color(0.82, 0.83, 0.85))
	c.draw_rect(Rect2(Vector2(kx - 50, 120), Vector2(100, 60)), Color(0.95, 0.75, 0.4).lerp(Color(0.45, 0.08, 0.04), steep))
	if step == Step.BOIL:
		for i: int in int(clampf((temp - 80.0) / 3.0, 0.0, 8.0)):
			var bx: float = kx - 70 + fmod(i * 37.0 + _t * 40.0, 140.0)
			c.draw_circle(Vector2(bx, 230 - fmod(_t * 60.0 + i * 13.0, 40.0)), 4, Color(1, 1, 1, 0.7))
		c.draw_string(ThemeDB.fallback_font, Vector2(kx - 40, 350), "%d °C" % roundi(temp), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 0.2, 0.15))
	if step == Step.STEEP:
		c.draw_rect(Rect2(Vector2(kx + 110, 120), Vector2(40, 200)), Color(0.4, 0.35, 0.3))
		var target := Rect2(Vector2(kx + 110, 320 - 200 * 0.85), Vector2(40, 200 * 0.25))
		c.draw_rect(target, Color(0.65, 0.15, 0.08, 0.6))
		c.draw_rect(Rect2(Vector2(kx + 104, 320 - 200 * minf(steep / 1.2, 1.0) - 3), Vector2(52, 6)), Color(1, 0.95, 0.85))
	# Tulip glass on a saucer.
	var gx: float = 470.0
	c.draw_rect(Rect2(Vector2(gx - 70, 320), Vector2(140, 10)), Color(0.85, 0.3, 0.25))
	var glass := Rect2(Vector2(gx - 40, 120), Vector2(80, 195))
	var level: float = clampf(fill, 0.0, 1.0)
	c.draw_rect(Rect2(Vector2(glass.position.x, glass.end.y - glass.size.y * level), Vector2(glass.size.x, glass.size.y * level)), tea_color())
	c.draw_rect(glass, Color(0.6, 0.6, 0.62), false, 3.0)
	if step == Step.POUR:
		c.draw_line(Vector2(gx - 55, glass.end.y - glass.size.y * 0.4), Vector2(gx + 55, glass.end.y - glass.size.y * 0.4), Color(0.5, 0.2, 0.1), 2.0)
	if step == Step.WATER:
		c.draw_line(Vector2(gx - 55, glass.end.y - glass.size.y * 0.9), Vector2(gx + 55, glass.end.y - glass.size.y * 0.9), Color(0.2, 0.35, 0.55), 2.0)
	if pouring:
		c.draw_line(Vector2(gx + 10, 60), Vector2(gx + 5, glass.end.y - glass.size.y * level), Color(0.5, 0.15, 0.05) if step == Step.POUR else Color(0.75, 0.85, 0.95), 5.0)
