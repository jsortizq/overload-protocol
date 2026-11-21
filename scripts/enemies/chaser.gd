class_name Chaser
extends Enemy
## Runs straight at the player. Light, fast, pushed around by knockback.


func _init() -> void:
	kind = "chaser"
	max_hp = 3.0
	radius = 13.0
	speed = 135.0
	knock_resist = 1.0


func _think() -> void:
	behavior = "chase"
	var dir := seek_dir(game.player.global_position)
	facing = facing.lerp(dir, 0.3).normalized()
	desired_velocity = dir * speed


func body_color() -> Color:
	return Color("ff4d6d")


func _draw_body(col: Color) -> void:
	var side := facing.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		facing * radius * 1.3, side * radius - facing * radius * 0.7, -side * radius - facing * radius * 0.7,
	]), col)
