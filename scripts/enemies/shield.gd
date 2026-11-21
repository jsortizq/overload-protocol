class_name ShieldBearer
extends Enemy
## Slow tank with a frontal energy shield (120° arc) that blocks bullets.
## It turns toward the player at a LIMITED rate, so circling or dashing past
## it exposes its back. Ricochet shots bounce off the shield like a wall.

const SHIELD_HALF_ANGLE := deg_to_rad(60.0)
const TURN_RATE := 1.7 # rad/s


func _init() -> void:
	kind = "shield"
	max_hp = 7.0
	radius = 17.0
	speed = 72.0
	knock_resist = 0.25


func finish_spawning() -> void:
	super.finish_spawning()
	facing = to_player().normalized()


func _think() -> void:
	behavior = "advance"
	var want := to_player().angle()
	var cur := facing.angle()
	var diff := wrapf(want - cur, -PI, PI)
	cur += clampf(diff, -TURN_RATE * Game.DT, TURN_RATE * Game.DT)
	facing = Vector2.from_angle(cur)
	if absf(diff) > SHIELD_HALF_ANGLE:
		behavior = "turning (exposed)"
	desired_velocity = seek_dir(game.player.global_position) * speed if facing.dot(to_player().normalized()) > 0.5 else facing * speed * 0.5


func blocks_hit(point: Vector2) -> bool:
	var to_point := (point - global_position).normalized()
	return facing.dot(to_point) >= cos(SHIELD_HALF_ANGLE)


func body_color() -> Color:
	return Color("9fb4ff")


func _draw_body(col: Color) -> void:
	draw_circle(Vector2.ZERO, radius, col.darkened(0.35))
	draw_circle(Vector2.ZERO, radius * 0.55, col)
	var a := facing.angle()
	draw_arc(Vector2.ZERO, radius + 5, a - SHIELD_HALF_ANGLE, a + SHIELD_HALF_ANGLE, 20, Color("4de1ff"), 5.0)
