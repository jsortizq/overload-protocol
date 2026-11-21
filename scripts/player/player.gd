class_name Player
extends CharacterBody2D
## Player avatar. Driven by Game.step() through tick(); never reads Input.

enum State { NORMAL, DASHING, DEAD }
const STATE_NAMES: Array[String] = ["NORMAL", "DASHING", "DEAD"]

const RADIUS := 12.0
const MAX_HP := 6
const SPEED := 270.0
const ACCEL := 2400.0
const DASH_SPEED := 780.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.7
## Invulnerability starts with the dash and lasts a little LONGER than the
## dash itself, so ending a dash inside a bullet stream is still safe.
const DASH_IFRAMES := 0.24
const HURT_IFRAMES := 0.9
const DASH_BUFFER := 0.1
const KNOCKBACK_DECAY := 1800.0

var game: Game
var hp := MAX_HP
var state: int = State.NORMAL
var aim_dir := Vector2.UP
var move_velocity := Vector2.ZERO
var knock := Vector2.ZERO
var dash_dir := Vector2.UP
var dash_left := 0.0
var dash_cooldown := 0.0
var iframes := 0.0
var fire_cooldown := 0.0
var modules: Array[WeaponModule] = []
var spec := WeaponSpec.compose([])
var _dash_buffer := 0.0
var _hurt_flash := 0.0


func buffer_dash() -> void:
	_dash_buffer = DASH_BUFFER


## `can_fire` is false between waves (movement still allowed).
func tick(frame: InputFrame, can_fire: bool) -> void:
	if state == State.DEAD:
		return
	dash_cooldown = maxf(dash_cooldown - Game.DT, 0.0)
	iframes = maxf(iframes - Game.DT, 0.0)
	_dash_buffer = maxf(_dash_buffer - Game.DT, 0.0)
	_hurt_flash = maxf(_hurt_flash - Game.DT, 0.0)

	var to_aim := frame.aim - global_position
	if to_aim.length() > 4.0:
		aim_dir = to_aim.normalized()

	var wish := frame.move.limit_length(1.0)
	match state:
		State.NORMAL:
			if _dash_buffer > 0.0 and dash_cooldown <= 0.0:
				_start_dash(wish)
			else:
				move_velocity = move_velocity.move_toward(wish * SPEED, ACCEL * Game.DT)
		State.DASHING:
			dash_left -= Game.DT
			move_velocity = dash_dir * DASH_SPEED
			if dash_left <= 0.0:
				state = State.NORMAL
				move_velocity = dash_dir * SPEED

	velocity = move_velocity + knock
	move_and_slide()
	knock = knock.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * Game.DT)

	fire_cooldown -= Game.DT
	if can_fire and frame.fire and state != State.DASHING:
		while fire_cooldown <= 0.0:
			_fire()
			fire_cooldown += spec.fire_interval
	else:
		fire_cooldown = maxf(fire_cooldown, 0.0)
	queue_redraw()


func _start_dash(wish: Vector2) -> void:
	state = State.DASHING
	dash_dir = wish.normalized() if wish.length() > 0.1 else aim_dir
	dash_left = DASH_TIME
	dash_cooldown = DASH_COOLDOWN
	iframes = maxf(iframes, DASH_IFRAMES)
	_dash_buffer = 0.0
	game.fx.dash_trail(global_position, dash_dir)


func _fire() -> void:
	# Rays start at the body centre: an enemy overlapping the player is still
	# inside the first ray (ProjectileSystem casts with hit_from_inside).
	var muzzle := global_position + aim_dir * 4.0
	for d in spec.volley_directions(aim_dir):
		game.projectiles.spawn_from_spec(muzzle, d, spec, Color("4de1ff"))
		game.stats["shots"] += 1


func add_module(m: WeaponModule) -> void:
	modules.append(m)
	spec = WeaponSpec.compose(modules)


func is_invulnerable() -> bool:
	return iframes > 0.0


## Returns true if damage was applied.
func hurt(amount: int, dir: Vector2) -> bool:
	if state == State.DEAD or is_invulnerable():
		return false
	if game.god_mode:
		iframes = HURT_IFRAMES
		return false
	hp -= amount
	game.stats["damage_taken"] += amount
	iframes = HURT_IFRAMES
	_hurt_flash = 0.15
	knock = dir.normalized() * 340.0
	game.add_hitstop(6)
	game.add_shake(10.0)
	game.fx.burst(global_position, Color("ff4d6d"), 10)
	game.log_event("Player hit (%d HP left)" % hp)
	if hp <= 0:
		hp = 0
		state = State.DEAD
		game.on_player_died()
	return true


## Called by ProjectileSystem when an enemy bullet's ray reaches us.
func receive_projectile(p, dir: Vector2, _point: Vector2) -> int:
	if not p.hostile:
		return ProjectileSystem.Hit.IGNORED
	if is_invulnerable() or state == State.DEAD:
		return ProjectileSystem.Hit.IGNORED # bullets pass through a dashing player
	hurt(int(p.damage), dir)
	return ProjectileSystem.Hit.HIT


func state_name() -> String:
	return STATE_NAMES[state]


func _draw() -> void:
	if state == State.DEAD:
		draw_circle(Vector2.ZERO, RADIUS, Color("3a3f55"))
		return
	var blink := is_invulnerable() and state != State.DASHING and int(iframes * 20) % 2 == 0
	var body := Color("ff4d6d") if _hurt_flash > 0.0 else Color("e8f6ff")
	if blink:
		body.a = 0.35
	if state == State.DASHING:
		body = Color("4de1ff")
	var side := aim_dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		aim_dir * (RADIUS + 6), side * RADIUS * 0.85 - aim_dir * RADIUS * 0.6, -aim_dir * RADIUS * 0.2,
		-side * RADIUS * 0.85 - aim_dir * RADIUS * 0.6,
	]), body)
	draw_circle(Vector2.ZERO, 4.0, Color("4de1ff"))
	# dash cooldown ring
	if dash_cooldown > 0.0:
		var frac := 1.0 - dash_cooldown / DASH_COOLDOWN
		draw_arc(Vector2.ZERO, RADIUS + 9, -PI / 2, -PI / 2 + TAU * frac, 24, Color("4de1ff", 0.5), 2.0)
