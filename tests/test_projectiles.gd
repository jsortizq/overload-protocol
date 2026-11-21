extends TestCase
## Arena reference: inner walls at x=80/1200, y=96/680.
## Centre pillar spans x 610..670, y 372..400 (28 px thick).


func _shot(game: Game, pos: Vector2, vel: Vector2, bounces := 0, pierce := 0, chain := 0) -> ProjectileSystem.Projectile:
	var p := game.projectiles.spawn(pos, vel, false, 1.0, Color.WHITE)
	p.bounces = bounces
	p.pierce = pierce
	p.chain = chain
	return p


func _dummy(game: Game, kind: String, pos: Vector2, hp := 50.0) -> Enemy:
	var e := game.spawn_enemy(kind, pos, true)
	e.speed = 0.0
	e.knock_resist = 0.0
	e.max_hp = hp
	e.hp = hp
	return e


func test_fast_projectile_never_tunnels_through_thin_wall() -> void:
	var game := await make_game()
	# 9000 px/s = 150 px per tick, far more than the pillar's 28 px.
	var p := _shot(game, Vector2(640, 250), Vector2(0, 9000))
	for i in 10:
		await steps(game, 1)
		if p.active:
			assert_true(p.pos.y <= 372.5, "tick %d: projectile at y=%.1f is past the pillar" % [i, p.pos.y])
	assert_false(p.active, "projectile should be destroyed by the pillar")


func test_ricochet_reflects_off_wall() -> void:
	var game := await make_game()
	var p := _shot(game, Vector2(1150, 200), Vector2(800, 0), 1)
	await steps(game, 10)
	assert_true(p.active, "one bounce left -> still alive")
	assert_true(p.vel.x < 0.0, "velocity reflected (vx=%.1f)" % p.vel.x)
	assert_eq(p.bounces, 0)


func test_ricochet_never_escapes_the_arena() -> void:
	# Shots fired into corners and at shallow angles bounce many times.
	var game := await make_game()
	var inner := Arena.BOUNDS.grow(1.0)
	var shots: Array = []
	var starts := [Vector2(1170, 130), Vector2(110, 130), Vector2(1170, 650), Vector2(110, 650), Vector2(640, 160)]
	for s in starts:
		for deg in range(0, 360, 15):
			shots.append(_shot(game, s, Vector2.from_angle(deg_to_rad(deg + 0.5)) * 1400.0, 8))
	for i in 90:
		await steps(game, 1)
		for p in shots:
			if p.active and not inner.has_point(p.pos):
				failures.append("tick %d: projectile escaped to (%.1f, %.1f)" % [i, p.pos.x, p.pos.y])
				return


func test_pierce_hits_each_enemy_once() -> void:
	var game := await make_game()
	var a := _dummy(game, "chaser", Vector2(500, 300))
	var b := _dummy(game, "chaser", Vector2(500, 220))
	_shot(game, Vector2(500, 420), Vector2(0, -900), 0, 1)
	await steps(game, 30)
	assert_near(a.hp, 49.0, 0.001, "first enemy hit once")
	assert_near(b.hp, 49.0, 0.001, "second enemy hit once")


func test_point_blank_shot_hits_enemy_overlapping_muzzle() -> void:
	var fired := [false]
	var game := await make_game(func(_t, g):
		var f := InputFrame.make(Vector2.ZERO, g.player.global_position + Vector2.UP * 100, not fired[0])
		fired[0] = true
		return f)
	game.god_mode = true
	var e := _dummy(game, "chaser", game.player.global_position + Vector2(0, -6)) # muzzle is inside its body
	await steps(game, 3)
	assert_true(e.hp < 50.0, "enemy touching the muzzle must be hit (hp %.1f)" % e.hp)


func test_chain_arcs_to_nearby_enemies() -> void:
	var game := await make_game()
	var a := _dummy(game, "chaser", Vector2(400, 200))
	var b := _dummy(game, "chaser", Vector2(480, 200))
	var c := _dummy(game, "chaser", Vector2(400, 290))
	var far := _dummy(game, "chaser", Vector2(900, 600))
	_shot(game, Vector2(400, 320 + 80), Vector2(0, -900), 0, 0, 2) # passes c first
	await steps(game, 30)
	assert_near(c.hp, 49.0, 0.001, "direct hit")
	assert_near(a.hp, 49.5, 0.001, "chained 50%")
	assert_near(b.hp, 49.5, 0.001, "chained 50%")
	assert_near(far.hp, 50.0, 0.001, "out of chain range")


func test_pool_slot_is_fully_reset_on_reuse() -> void:
	var game := await make_game()
	var p := _shot(game, Vector2(300, 300), Vector2(100, 0), 3, 2, 1)
	p.exclude.append(game.player.get_rid())
	game.projectiles.clear_all()
	var q := _shot(game, Vector2(300, 300), Vector2(100, 0))
	assert_true(q == p, "LIFO free list should hand back the same slot")
	assert_eq(q.exclude.size(), 0, "exclude list leaked from the previous bullet")
	assert_eq(q.chain, 0)


func test_piercing_shots_keep_hitting_the_same_target() -> void:
	# Gameplay-level version of the reset test: with Pierce installed every
	# shot at a stationary target must connect, not only the first ones.
	var game := await make_game(func(_t, g): return InputFrame.make(Vector2.ZERO, Vector2(500, 250), true))
	game.god_mode = true
	game.player.add_module(ModuleLibrary.by_id("pierce"))
	var target := _dummy(game, "chaser", Vector2(500, 250), 10000.0)
	await steps(game, 180)
	var shots: int = game.stats["shots"]
	var hits: int = game.stats["hits"]
	assert_true(shots >= 15, "precondition: fired %d" % shots)
	assert_true(hits >= shots - game.projectiles.active_count(), "hits %d / shots %d (in flight %d)" % [hits, shots, game.projectiles.active_count()])
	assert_true(target.hp < 10000.0 - (shots - 5), "target hp %.1f" % target.hp)


func test_pool_capacity_drops_and_recovers() -> void:
	var game := await make_game()
	for i in ProjectileSystem.CAPACITY + 10:
		var p := game.projectiles.spawn(Vector2(640, 200), Vector2.ZERO + Vector2(1, 0), false, 1.0, Color.WHITE)
		if p != null:
			p.life = 0.05
	assert_eq(game.projectiles.stats["dropped"], 10)
	await steps(game, 6)
	assert_eq(game.projectiles.active_count(), 0)
	assert_eq(game.projectiles.free_count(), ProjectileSystem.CAPACITY)
