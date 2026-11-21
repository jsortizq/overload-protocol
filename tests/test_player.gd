extends TestCase


func _enemy_bullet_at_player(game: Game, distance: float, speed := 600.0) -> ProjectileSystem.Projectile:
	var pp := game.player.global_position
	var p := game.projectiles.spawn(pp + Vector2(distance, 0), Vector2(-speed, 0), true, 1.0, Color.ORANGE)
	p.radius = 6.0
	return p


func test_bullet_hits_idle_player() -> void:
	var game := await make_game()
	_enemy_bullet_at_player(game, 60.0)
	await steps(game, 15)
	assert_eq(game.player.hp, Player.MAX_HP - 1)


func test_dash_iframes_let_bullets_pass_through() -> void:
	# Dash on tick 1 (straight up), bullet arrives a few ticks later.
	var game := await make_game(func(t, g):
		return InputFrame.make(Vector2.UP if t == 1 else Vector2.ZERO, g.player.global_position + Vector2.UP * 100, false, t == 1))
	var p := _enemy_bullet_at_player(game, 40.0, 900.0)
	await steps(game, 5)
	assert_eq(game.player.hp, Player.MAX_HP, "dashing player was hit")
	assert_true(p.active, "bullet should pass through and keep flying")


func test_iframes_outlast_the_dash() -> void:
	var game := await make_game(func(t, g):
		return InputFrame.make(Vector2.ZERO, g.player.global_position + Vector2.UP * 100, false, t == 1))
	var dash_ticks := ceili(Player.DASH_TIME / Game.DT)
	await steps(game, dash_ticks + 2)
	assert_eq(game.player.state, Player.State.NORMAL, "dash finished")
	assert_true(game.player.is_invulnerable(), "grace i-frames after the dash (iframes=%.3f)" % game.player.iframes)
	await steps(game, ceili((Player.DASH_IFRAMES - Player.DASH_TIME) / Game.DT) + 1)
	assert_false(game.player.is_invulnerable(), "grace window should be over")


func test_hurt_iframes_prevent_double_hits() -> void:
	var game := await make_game()
	_enemy_bullet_at_player(game, 50.0)
	_enemy_bullet_at_player(game, 80.0)
	await steps(game, 20)
	assert_eq(game.player.hp, Player.MAX_HP - 1, "second bullet inside hurt i-frames")


func test_fire_rate_matches_spec() -> void:
	var game := await make_game(func(_t, g): return InputFrame.make(Vector2.ZERO, g.player.global_position + Vector2.UP * 100, true))
	await steps(game, 120)
	var expected := 120.0 * Game.DT / game.player.spec.fire_interval
	assert_near(float(game.stats["shots"]), expected, 1.0)


func test_rapid_module_increases_fire_rate() -> void:
	var game := await make_game(func(_t, g): return InputFrame.make(Vector2.ZERO, g.player.global_position + Vector2.UP * 100, true))
	game.player.add_module(ModuleLibrary.by_id("rapid"))
	await steps(game, 120)
	var expected := 120.0 * Game.DT / (WeaponSpec.BASE_INTERVAL / 1.6)
	assert_near(float(game.stats["shots"]), expected, 1.0)


func test_cannot_fire_while_dashing() -> void:
	var game := await make_game(func(t, g):
		return InputFrame.make(Vector2.RIGHT, g.player.global_position + Vector2.UP * 100, t > 1, t == 1))
	await steps(game, 1)
	assert_eq(game.player.state, Player.State.DASHING)
	var before: int = game.stats["shots"]
	await steps(game, 3)
	assert_eq(game.stats["shots"], before)


func test_dash_input_is_buffered() -> void:
	# Second dash pressed slightly before the cooldown ends still triggers.
	var cd_ticks := ceili(Player.DASH_COOLDOWN / Game.DT)
	var game := await make_game(func(t, g):
		return InputFrame.make(Vector2.RIGHT, g.player.global_position + Vector2.UP * 100, false, t == 1 or t == cd_ticks - 3))
	await steps(game, cd_ticks + 2)
	assert_eq(game.player.state, Player.State.DASHING, "buffered dash should fire when the cooldown ends")


func test_dash_blocked_by_walls() -> void:
	var game := await make_game(func(t, g):
		return InputFrame.make(Vector2.DOWN, g.player.global_position + Vector2.UP * 100, false, t % 50 == 1))
	await steps(game, 240)
	assert_true(game.player.global_position.y <= Arena.BOUNDS.end.y - Player.RADIUS + 1.0, "player left the arena: %s" % game.player.global_position)
