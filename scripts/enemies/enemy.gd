class_name Enemy
extends CharacterBody2D
## Base class for every hostile. Subclasses implement _think() (set
## `desired_velocity` and do attacks) and _draw_body().
##
## Lifecycle: SPAWNING (visible, harmless, untargetable) -> ACTIVE -> DEAD.

signal died(enemy: Enemy)

enum State { SPAWNING, ACTIVE, DEAD }

const SPAWN_TIME := 0.35
const KNOCKBACK_DECAY := 1400.0

var game: Game
var kind := "enemy"
var max_hp := 3.0
var hp := 3.0
var radius := 13.0
var speed := 100.0
var contact_damage := 1
var knock_resist := 1.0 ## 0 = immovable, 1 = full knockback
var state: int = State.SPAWNING
## Free-form sub-state for the AI, shown in the debug overlay.
var behavior := "spawning"
var desired_velocity := Vector2.ZERO
var knock := Vector2.ZERO
var facing := Vector2.DOWN
var _spawn_left := SPAWN_TIME
var _flash := 0.0
var _hp_bar_time := 0.0


func _ready() -> void:
	hp = max_hp


func finish_spawning() -> void:
	_spawn_left = 0.0
	state = State.ACTIVE
	behavior = "active"


func tick() -> void:
	_flash = maxf(_flash - Game.DT, 0.0)
	_hp_bar_time = maxf(_hp_bar_time - Game.DT, 0.0)
	if state == State.SPAWNING:
		_spawn_left -= Game.DT
		if _spawn_left <= 0.0:
			finish_spawning()
		queue_redraw()
		return
	desired_velocity = Vector2.ZERO
	_think()
	velocity = desired_velocity + knock * knock_resist
	move_and_slide()
	knock = knock.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * Game.DT)
	_keep_in_arena()
	queue_redraw()


## Safety net: an enemy outside the arena can never be killed, which would
## soft-lock the wave. If depenetration ever pushes one out, put it back
## and log it so QA can see it happened.
func _keep_in_arena() -> void:
	var inner := Arena.BOUNDS.grow(-radius)
	if inner.has_point(global_position):
		return
	global_position = global_position.clamp(inner.position, inner.end)
	game.log_event("WARN: %s pushed out of bounds, corrected" % kind)


func _think() -> void:
	pass


func can_touch() -> bool:
	return state == State.ACTIVE


func is_hittable() -> bool:
	return state == State.ACTIVE


func to_player() -> Vector2:
	return game.player.global_position - global_position


## Direction toward `target` that steers around cover. Enemies don't path-
## find (the arena is open), but a straight seek gets stuck on the flat face
## of a pillar forever. If the straight line is blocked we follow the
## obstacle's surface, picking the side that leads toward the target.
func seek_dir(target: Vector2) -> Vector2:
	var to_target := target - global_position
	var dir := to_target.normalized()
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * minf(to_target.length(), radius + 48.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return dir
	var tangent: Vector2 = (hit["normal"] as Vector2).orthogonal()
	if tangent.dot(dir) < 0.0:
		tangent = -tangent
	return (tangent + dir * 0.25).normalized()


## Called by ProjectileSystem when a player bullet's ray reaches this body.
func receive_projectile(p, dir: Vector2, point: Vector2) -> int:
	if p.hostile or not is_hittable():
		return ProjectileSystem.Hit.IGNORED
	if blocks_hit(point):
		game.fx.spark(point, Color("9fb4ff"), 5)
		return ProjectileSystem.Hit.BLOCKED
	take_damage(p.damage, dir, p.knockback)
	return ProjectileSystem.Hit.HIT


## Override for shields / armour. `point` is the world-space impact point.
func blocks_hit(_point: Vector2) -> bool:
	return false


func take_damage(amount: float, dir: Vector2, knockback: float) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	_flash = 0.07
	_hp_bar_time = 2.0
	knock += dir * knockback
	game.fx.damage_number(global_position + Vector2(0, -radius - 6), amount)
	if hp <= 0.0:
		die()


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	behavior = "dead"
	$Collision.set_deferred("disabled", true)
	died.emit(self)
	queue_free()


func body_color() -> Color:
	return Color("ff4d6d")


func _draw() -> void:
	if state == State.SPAWNING:
		var t := 1.0 - _spawn_left / SPAWN_TIME
		draw_arc(Vector2.ZERO, radius * (0.4 + 0.6 * t), 0, TAU, 24, Color(body_color(), 0.8), 2.0)
		return
	_draw_body(Color.WHITE if _flash > 0.0 else body_color())
	if hp < max_hp and (_hp_bar_time > 0.0 or kind == "boss"):
		_draw_hp_bar()


func _draw_body(col: Color) -> void:
	draw_circle(Vector2.ZERO, radius, col)


func _draw_hp_bar() -> void:
	var w := radius * 2.4
	var top := Vector2(-w / 2, -radius - 12)
	draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(w * clampf(hp / max_hp, 0, 1), 4)), Color("ff4d6d"))
