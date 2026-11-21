class_name TestCase
extends RefCounted
## Minimal async-capable test base. Methods starting with `test_` are run by
## tests/run_tests.gd; they may `await`. Physics tests build a sandbox Game
## (no waves), wait one physics frame so bodies are registered, then drive
## the simulation tick by tick with game.step().

var failures := PackedStringArray()
var tree: SceneTree
var _games: Array[Game] = []


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		failures.append("expected true. " + msg)


func assert_false(cond: bool, msg := "") -> void:
	if cond:
		failures.append("expected false. " + msg)


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("expected <%s> but got <%s>. %s" % [str(expected), str(actual), msg])


func assert_near(actual: float, expected: float, tolerance: float, msg := "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("expected %f ± %f but got %f. %s" % [expected, tolerance, actual, msg])


## Builds a Game inside its own SubViewport (= its own World2D and physics
## space, so several games never collide with each other) and freezes it.
## `script_fn(tick, game) -> InputFrame` drives the player; null = idle.
## Pass an InputSource (e.g. AutoPilot) instead of a callable to use it directly.
func make_game(script_fn: Variant = null, sandbox := true, seed_value := 1) -> Game:
	var game := Game.new()
	game.sandbox = sandbox
	game.seed_value = seed_value
	if script_fn is InputSource:
		game.input_source = script_fn
	else:
		var src := InputSource.ScriptedInput.new()
		if script_fn is Callable:
			src.script_fn = script_fn
		else:
			src.script_fn = func(_t, g): return InputFrame.make(Vector2.ZERO, g.player.global_position + Vector2.UP * 100)
		game.input_source = src
	game.step_budget = 0
	add_isolated(game)
	await tree.physics_frame
	return game


func add_isolated(game: Game) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(vp)
	vp.add_child(game)
	_games.append(game)


## Advances exactly `n` simulation ticks, each inside a real physics frame.
func steps(game: Game, n: int) -> void:
	game.step_budget = n
	while game.step_budget > 0:
		await tree.physics_frame
	await tree.physics_frame # let the physics server finish the last step


func cleanup() -> void:
	for g in _games:
		if is_instance_valid(g):
			g.get_parent().queue_free()
	_games.clear()
	await tree.process_frame
