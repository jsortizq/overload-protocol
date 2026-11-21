class_name ProjectileSystem
extends Node2D
## Data-oriented projectile pool with continuous (swept-ray) collision.
##
## * Pool: CAPACITY Projectile objects are allocated once; spawning takes a
##   slot from the free list, despawning returns it. No nodes, no
##   allocations during combat, one _draw() call for all bullets.
## * Collision: each tick a projectile casts a ray from where it is to where
##   it will be (PhysicsDirectSpaceState2D.intersect_ray). Fast bullets
##   therefore never tunnel through thin walls, no matter the speed.
## * Bounce / pierce / chain are resolved inside the same tick, so a bullet
##   can hit an enemy, pierce it and ricochet off a wall in one step.

enum Hit { HIT, BLOCKED, IGNORED }

const CAPACITY := 600
const MAX_SUBSTEPS := 6
const CHAIN_RADIUS := 170.0
const CHAIN_DAMAGE := 0.5
const MASK_PLAYER_SHOTS := 1 | 4  # world + enemies
const MASK_ENEMY_SHOTS := 1 | 2   # world + player


class Projectile:
	var active := false
	var hostile := false
	var pos := Vector2.ZERO
	var prev := Vector2.ZERO
	var vel := Vector2.ZERO
	var radius := 4.0
	var damage := 1.0
	var knockback := 0.0
	var bounces := 0
	var pierce := 0
	var chain := 0
	var life := 0.0
	var color := Color.WHITE
	## RIDs this bullet must ignore (enemies already pierced, player during i-frames).
	var exclude: Array[RID] = []

	## Every field must be reset here, or a recycled slot inherits state
	## from its previous life (see tasks/bug-02).
	func reset() -> void:
		active = false
		hostile = false
		pos = Vector2.ZERO
		prev = Vector2.ZERO
		vel = Vector2.ZERO
		radius = 4.0
		damage = 1.0
		knockback = 0.0
		bounces = 0
		pierce = 0
		chain = 0
		life = 0.0
		color = Color.WHITE
		exclude.clear()


var game: Game
var _pool: Array[Projectile] = []
var _free: Array[int] = []
var _active: Array[int] = []
var stats := {"spawned": 0, "peak": 0, "dropped": 0}


func _ready() -> void:
	for i in CAPACITY:
		_pool.append(Projectile.new())
		_free.append(CAPACITY - 1 - i)


func active_count() -> int:
	return _active.size()


func free_count() -> int:
	return _free.size()


func active_projectiles() -> Array[Projectile]:
	var out: Array[Projectile] = []
	for i in _active:
		out.append(_pool[i])
	return out


## Takes a slot from the pool. Returns null (and counts a drop) if full.
func spawn(pos: Vector2, vel: Vector2, hostile: bool, damage: float, color: Color) -> Projectile:
	if _free.is_empty():
		stats["dropped"] += 1
		return null
	var index: int = _free.pop_back()
	var p := _pool[index]
	p.reset()
	p.active = true
	p.hostile = hostile
	p.pos = pos
	p.prev = pos
	p.vel = vel
	p.damage = damage
	p.color = color
	p.life = 4.0
	_active.append(index)
	stats["spawned"] += 1
	stats["peak"] = maxi(stats["peak"], _active.size())
	return p


func spawn_from_spec(pos: Vector2, dir: Vector2, spec: WeaponSpec, color: Color) -> Projectile:
	var p := spawn(pos, dir * spec.speed, false, spec.damage, color)
	if p != null:
		p.radius = spec.radius
		p.knockback = spec.knockback
		p.bounces = spec.bounces
		p.pierce = spec.pierce
		p.chain = spec.chain
		p.life = spec.lifetime
	return p


func clear_all() -> void:
	for i in _active.duplicate():
		_release_index(i)


func tick() -> void:
	var space := get_world_2d().direct_space_state
	for index in _active.duplicate():
		var p := _pool[index]
		if not p.active:
			continue
		p.life -= Game.DT
		if p.life <= 0.0:
			_release(p)
			continue
		p.prev = p.pos
		_advance(p, space)


func _advance(p: Projectile, space: PhysicsDirectSpaceState2D) -> void:
	var speed := p.vel.length()
	var dir := p.vel / speed
	var remaining := speed * Game.DT
	var substeps := 0
	while remaining > 0.01 and p.active and substeps < MAX_SUBSTEPS:
		substeps += 1
		var target := p.pos + dir * remaining
		var query := PhysicsRayQueryParameters2D.create(p.pos, target, MASK_ENEMY_SHOTS if p.hostile else MASK_PLAYER_SHOTS, p.exclude)
		# Point-blank: the muzzle can already be INSIDE an enemy that is
		# hugging the player. Without this the ray would ignore that enemy.
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			p.pos = target
			return
		remaining -= p.pos.distance_to(hit["position"])
		p.pos = hit["position"]
		var collider: Object = hit["collider"]
		var result := Hit.BLOCKED
		if collider.has_method("receive_projectile"):
			result = collider.receive_projectile(p, dir, p.pos)
		match result:
			Hit.HIT:
				if not p.hostile:
					game.stats["hits"] += 1
					_chain_from(p, collider as Enemy)
				if p.pierce > 0:
					p.pierce -= 1
					p.exclude.append(hit["rid"])
				else:
					_release(p)
			Hit.IGNORED:
				p.exclude.append(hit["rid"])
			Hit.BLOCKED:
				var inside: bool = hit["normal"] == Vector2.ZERO # started inside a wall
				if p.bounces > 0 and not inside:
					p.bounces -= 1
					dir = dir.bounce(hit["normal"]).normalized()
					p.vel = dir * speed
					# A ricochet may hit enemies it already pierced.
					p.exclude.clear()
					game.stats["ricochets"] += 1
					game.fx.spark(p.pos, p.color, 4)
				else:
					game.fx.spark(p.pos, p.color, 6)
					_release(p)


func _chain_from(p: Projectile, source: Enemy) -> void:
	if p.chain <= 0 or source == null:
		return
	var targets := game.enemies_near(source.global_position, CHAIN_RADIUS, source)
	for i in mini(p.chain, targets.size()):
		var t: Enemy = targets[i]
		game.fx.lightning(source.global_position, t.global_position)
		t.take_damage(p.damage * CHAIN_DAMAGE, (t.global_position - source.global_position).normalized(), p.knockback * 0.3)


func _release(p: Projectile) -> void:
	_release_index(_pool.find(p))


func _release_index(index: int) -> void:
	if index < 0 or not _pool[index].active:
		return
	_pool[index].active = false
	_active.erase(index)
	_free.append(index)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for index in _active:
		var p := _pool[index]
		draw_line(p.prev, p.pos, Color(p.color, 0.45), p.radius * 1.2)
		draw_circle(p.pos, p.radius, p.color)
		if p.hostile:
			draw_arc(p.pos, p.radius + 2.0, 0, TAU, 12, Color(1, 1, 1, 0.5), 1.0)
