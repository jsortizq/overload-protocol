class_name Shooter
extends Enemy
## Keeps its distance and fires slow, predictable shots.
##
##   REPOSITION ──fire timer done──▶ AIMING (stands still, telegraph line,
##   target point LOCKED) ──0.45 s──▶ fires one bullet at the locked point
##   ──▶ REPOSITION
##
## Locking the target at the start of the telegraph is what makes the shot
## readable and dodgeable: it never tracks the player mid-wind-up.

const MIN_RANGE := 210.0
const MAX_RANGE := 330.0
const AIM_TIME := 0.45
const BULLET_SPEED := 250.0

var fire_timer := 1.2
var aim_left := 0.0
var aim_point := Vector2.ZERO
var strafe_sign := 1.0
var strafe_timer := 0.0


func _init() -> void:
	kind = "shooter"
	max_hp = 4.0
	radius = 14.0
	speed = 105.0
	knock_resist = 0.8


func finish_spawning() -> void:
	super.finish_spawning()
	fire_timer = 1.0 + game.rng.randf() * 0.6
	strafe_sign = 1.0 if game.rng.randf() < 0.5 else -1.0


func _think() -> void:
	var to_p := to_player()
	var dist := to_p.length()
	facing = to_p / maxf(dist, 0.001)
	if aim_left > 0.0:
		behavior = "aiming"
		aim_left -= Game.DT
		if aim_left <= 0.0:
			_fire()
		return
	fire_timer -= Game.DT
	if fire_timer <= 0.0:
		aim_left = AIM_TIME
		aim_point = game.player.global_position
		return
	strafe_timer -= Game.DT
	if strafe_timer <= 0.0:
		strafe_timer = 1.5 + game.rng.randf()
		strafe_sign = -strafe_sign
	if dist < MIN_RANGE:
		behavior = "retreat"
		desired_velocity = -facing * speed
	elif dist > MAX_RANGE:
		behavior = "approach"
		desired_velocity = seek_dir(game.player.global_position) * speed
	else:
		behavior = "strafe"
		desired_velocity = facing.orthogonal() * strafe_sign * speed * 0.8


func _fire() -> void:
	var dir := (aim_point - global_position).normalized()
	var p = game.projectiles.spawn(global_position + dir * (radius + 6), dir * BULLET_SPEED, true, 1.0, Color("ffd166"))
	if p != null:
		p.radius = 6.0
	fire_timer = 1.5 + game.rng.randf() * 0.5


func body_color() -> Color:
	return Color("ffd166")


func _draw_body(col: Color) -> void:
	draw_rect(Rect2(-radius, -radius, radius * 2, radius * 2), col)
	draw_line(Vector2.ZERO, facing * (radius + 8), col.darkened(0.3), 4.0)
	if aim_left > 0.0:
		var a := 1.0 - aim_left / AIM_TIME
		draw_line(Vector2.ZERO, to_local(aim_point), Color(1, 0.82, 0.4, 0.25 + 0.5 * a), 1.0 + 2.0 * a)
