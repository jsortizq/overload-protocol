extends TestCase


func _bot_game(seed_value: int, god := true) -> Game:
	var game := await make_game(AutoPilot.new(), false, seed_value)
	game.god_mode = god
	return game


func test_wave_clear_offers_upgrade_then_next_wave() -> void:
	var picked := [false]
	var game := await make_game(func(_t, g):
		var f := InputFrame.make(Vector2.ZERO, g.player.global_position + Vector2.UP * 100)
		if g.state == Game.State.UPGRADE and not picked[0]:
			f.choice = 2
			picked[0] = true
		return f
	, false)
	game.god_mode = true
	await steps(game, 1)
	game.debug_kill_all()
	await steps(game, 1)
	assert_eq(game.state, Game.State.UPGRADE)
	assert_eq(game.upgrade_choices.size(), 2)
	var expected := game.upgrade_choices[1]
	await steps(game, 1)
	assert_eq(game.state, Game.State.INTERMISSION)
	assert_true(game.player.modules.has(expected), "picked card 2")
	await steps(game, Game.INTERMISSION_TICKS)
	assert_eq(game.state, Game.State.COMBAT)
	assert_eq(game.director.wave_index, 1)


func test_same_seed_same_run() -> void:
	var a := await _bot_game(99)
	await steps(a, 1500)
	var first := a.summary()
	var b := await _bot_game(99)
	await steps(b, 1500)
	assert_eq(b.summary(), first)


func test_different_seed_different_run() -> void:
	var a := await _bot_game(1)
	await steps(a, 900)
	var first := a.summary()
	var b := await _bot_game(2)
	await steps(b, 900)
	assert_true(b.summary() != first, "seeds 1 and 2 produced identical runs")


func test_recorded_inputs_replay_exactly() -> void:
	var live := await _bot_game(5)
	await steps(live, 1200)
	var frames: Array = []
	for arr in live.recording:
		frames.append(InputFrame.from_array(arr))
	var expected := live.summary()
	var replay := Game.new()
	replay.sandbox = false
	replay.seed_value = 5
	replay.god_mode = true
	var src := InputSource.ScriptedInput.new()
	src.frames = frames
	replay.input_source = src
	replay.step_budget = 0
	add_isolated(replay)
	await tree.physics_frame
	await steps(replay, frames.size())
	assert_eq(replay.summary(), expected)


func test_full_run_reaches_victory() -> void:
	var game := await _bot_game(7)
	for i in 100:
		await steps(game, 200)
		if game.state == Game.State.WON:
			break
	assert_eq(game.state, Game.State.WON, game.summary())
	assert_eq(game.player.modules.size(), 3, "one module per cleared wave")
	assert_eq(game.projectiles.stats["dropped"], 0, "pool never ran out")


func test_cosmetic_rng_does_not_affect_gameplay() -> void:
	var a := await _bot_game(11)
	await steps(a, 900)
	var first := a.summary()
	var b := await _bot_game(11)
	b.fx_rng.seed = 123456 # different sparks / shake
	await steps(b, 900)
	assert_eq(b.summary(), first)
