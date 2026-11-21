class_name Warden
extends Enemy
## Mini-boss with three phases chosen by remaining HP.
##
##  Phase 1 (100-66%): drifts toward the player, fires rotating bullet rings.
##  Phase 2 (66-33%):  aimed 3-shot fans + summons two Chasers every 7 s.
##  Phase 3 (<33%):    telegraphed charges; slamming a wall fires a ring.
##
## Phase changes trigger a short invulnerable "shift" (with hitstop and
## shake) and clear its own bullets, so the player gets a beat to reposition.

enum Phase { ONE, TWO, THREE }

const RING_COUNT := 14
const SHIFT_TIME := 0.8
const CHARGE_TELEGRAPH := 0.65
const CHARGE_SPEED := 560.0
const CHARGE_TIME := 0.55

var phase: int = Phase.ONE
var attack_timer := 1.5
var summon_timer := 4.0
var ring_offset := 0.0
var shift_left := 0.0
var charge_state := "idle" # idle | telegraph | charging | recover
var charge_left := 0.0
var charge_dir := Vector2.ZERO


func _init() -> void:
	kind = "boss"
	max_hp = 220.0
	radius = 34.0
	speed = 55.0
	knock_resist = 0.0
	contact_damage = 1


func is_hittable() -> bool:
	return super.is_hittable() and shift_left <= 0.0


func _think() -> void:
	_check_phase()
	if shift_left > 0.0:
		shift_left -= Game.DT
		behavior = "phase shift"
		return
	match phase:
		Phase.ONE:
			behavior = "P1 rings"
			desired_velocity = to_player().normalized() * speed
			attack_timer -= Game.DT
			if attack_timer <= 0.0:
				_ring(RING_COUNT, ring_offset, 190.0)
				ring_offset += 0.22
				attack_timer = 2.0
		Phase.TWO:
			behavior = "P2 fans"
			desired_velocity = to_player().normalized().orthogonal() * speed * 1.4
			attack_timer -= Game.DT
			summon_timer -= Game.DT
			if attack_timer <= 0.0:
				_fan(3, deg_to_rad(16.0), 260.0)
				attack_timer = 1.3
			if summon_timer <= 0.0:
				game.director.request_spawn("chaser", global_position + Vector2(-90, 0))
				game.director.request_spawn("chaser", global_position + Vector2(90, 0))
				summon_timer = 7.0
		Phase.THREE:
			_charge_ai()


func _check_phase() -> void:
	var frac := hp / max_hp
	var target := Phase.ONE
	if frac <= 0.33:
		target = Phase.THREE
	elif frac <= 0.66:
		target = Phase.TWO
	if target != phase:
		phase = target
		shift_left = SHIFT_TIME
		attack_timer = 0.8
		charge_state = "idle"
		charge_left = 0.6
		for p in game.projectiles.active_projectiles():
			if p.hostile:
				p.life = 0.0
		game.add_hitstop(12)
		game.add_shake(16.0)
		game.log_event("Warden entered phase %d" % (phase + 1))


func _charge_ai() -> void:
	charge_left -= Game.DT
	match charge_state:
		"idle":
			behavior = "P3 stalking"
			desired_velocity = to_player().normalized() * speed
			if charge_left <= 0.0:
				charge_state = "telegraph"
				charge_left = CHARGE_TELEGRAPH
				charge_dir = to_player().normalized()
		"telegraph":
			behavior = "P3 telegraph"
			if charge_left <= 0.0:
				charge_state = "charging"
				charge_left = CHARGE_TIME
		"charging":
			behavior = "P3 charging"
			desired_velocity = charge_dir * CHARGE_SPEED
			if get_slide_collision_count() > 0 or charge_left <= 0.0:
				if get_slide_collision_count() > 0:
					_ring(10, 0.0, 210.0)
					game.add_shake(12.0)
				charge_state = "recover"
				charge_left = 1.0
		"recover":
			behavior = "P3 recover (vulnerable)"
			if charge_left <= 0.0:
				charge_state = "idle"
				charge_left = 0.9


func _ring(count: int, offset: float, bullet_speed: float) -> void:
	for i in count:
		var dir := Vector2.from_angle(offset + TAU * i / count)
		_shoot(dir, bullet_speed)


func _fan(count: int, step: float, bullet_speed: float) -> void:
	var base := to_player().normalized()
	for i in count:
		_shoot(base.rotated((i - (count - 1) / 2.0) * step), bullet_speed)


func _shoot(dir: Vector2, bullet_speed: float) -> void:
	var p = game.projectiles.spawn(global_position + dir * (radius + 8), dir * bullet_speed, true, 1.0, Color("ff8c42"))
	if p != null:
		p.radius = 6.0


func body_color() -> Color:
	return Color("ff8c42")


func _draw_body(col: Color) -> void:
	if shift_left > 0.0:
		col = col.lerp(Color.WHITE, 0.5 + 0.5 * sin(shift_left * 40.0))
	draw_circle(Vector2.ZERO, radius, col.darkened(0.45))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 40, col, 4.0)
	draw_circle(Vector2.ZERO, radius * 0.4, col)
	for i in phase + 1:
		draw_circle(Vector2.from_angle(TAU * i / 3.0 - PI / 2) * radius * 0.7, 4.0, Color.WHITE)
	if charge_state == "telegraph":
		draw_line(Vector2.ZERO, charge_dir * 600.0, Color(1, 0.3, 0.3, 0.5), 3.0)
