extends TestCase


func _shot_at(game: Game, from: Vector2, to: Vector2) -> ProjectileSystem.Projectile:
	return game.projectiles.spawn(from, (to - from).normalized() * 900.0, false, 1.0, Color.WHITE)


func test_shield_blocks_frontal_shot() -> void:
	var game := await make_game()
	var s := game.spawn_enemy("shield", Vector2(640, 250), true)
	s.speed = 0.0
	s.facing = Vector2.DOWN
	_shot_at(game, Vector2(640, 340), s.global_position)
	await steps(game, 1)
	s.facing = Vector2.DOWN
	await steps(game, 10)
	assert_near(s.hp, s.max_hp, 0.001, "front hit must be blocked")


func test_shield_takes_damage_from_behind() -> void:
	var game := await make_game()
	var s := game.spawn_enemy("shield", Vector2(640, 250), true)
	s.speed = 0.0
	s.set("facing", Vector2.DOWN)
	# Player is below, shield faces it; we shoot from above (its back).
	_shot_at(game, Vector2(640, 140), s.global_position)
	await steps(game, 10)
	assert_true(s.hp < s.max_hp, "rear hit must land")


func test_shield_turn_rate_is_limited() -> void:
	var game := await make_game()
	var s := game.spawn_enemy("shield", Vector2(640, 250), true)
	s.speed = 0.0
	s.facing = Vector2.UP # facing away from the player below
	await steps(game, 30) # 0.5 s
	var turned := absf(Vector2.UP.angle_to(s.facing))
	assert_near(turned, ShieldBearer.TURN_RATE * 0.5, 0.05)


func test_shooter_locks_its_aim_point() -> void:
	var game := await make_game(func(t, g):
		return InputFrame.make(Vector2.RIGHT if t > 1 else Vector2.ZERO, g.player.global_position + Vector2.UP * 100))
	var sh: Shooter = game.spawn_enemy("shooter", Vector2(640, 300), true)
	sh.fire_timer = Game.DT # start aiming next tick
	await steps(game, 2)
	assert_true(sh.aim_left > 0.0, "should be aiming")
	var locked := sh.aim_point
	await steps(game, 10) # the player keeps moving right
	assert_eq(sh.aim_point, locked, "aim point must not track the player")


func test_spawn_is_telegraphed_and_harmless() -> void:
	var game := await make_game()
	game.director.request_spawn("chaser", game.player.global_position)
	await steps(game, WaveDirector.TELEGRAPH_TICKS - 1)
	assert_eq(game.enemies.size(), 0, "no enemy before the telegraph ends")
	await steps(game, 1)
	assert_eq(game.enemies.size(), 1)
	assert_eq(game.enemies[0].state, Enemy.State.SPAWNING)
	assert_eq(game.player.hp, Player.MAX_HP, "spawning enemy must not deal contact damage")


func test_warden_phases_follow_hp_thresholds() -> void:
	var game := await make_game()
	game.god_mode = true
	var w: Warden = game.spawn_enemy("boss", Vector2(640, 250), true)
	w.take_damage(w.max_hp * 0.40, Vector2.ZERO, 0.0)
	await steps(game, 1)
	assert_eq(w.phase, Warden.Phase.TWO)
	assert_false(w.is_hittable(), "invulnerable during the phase shift")
	# hitstop ticks freeze the simulation, so they don't count toward the shift
	await steps(game, game.hitstop + ceili(Warden.SHIFT_TIME / Game.DT) + 1)
	assert_true(w.is_hittable(), "shift over")
	w.take_damage(w.max_hp * 0.40, Vector2.ZERO, 0.0)
	await steps(game, 1)
	assert_eq(w.phase, Warden.Phase.THREE)


func test_warden_phase_shift_clears_hostile_bullets() -> void:
	var game := await make_game()
	var w: Warden = game.spawn_enemy("boss", Vector2(640, 250), true)
	var b := game.projectiles.spawn(Vector2(200, 200), Vector2(10, 0), true, 1.0, Color.ORANGE)
	w.take_damage(w.max_hp * 0.5, Vector2.ZERO, 0.0)
	await steps(game, 2)
	assert_false(b.active)
