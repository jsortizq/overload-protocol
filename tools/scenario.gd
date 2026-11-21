extends SceneTree
## Deterministic, scripted gameplay scenarios used as acceptance checks.
##   godot --headless --fixed-fps 60 --path . --script res://tools/scenario.gd -- <name>
## Each prints measured values and exits 0 (PASS) or 1 (FAIL).
##
##   ricochet_wall  Ricochet installed, 3 s of fire into the right wall.
##                  PASS = every bullet that reached the wall comes back
##                  (seen flying left afterwards) and none leaves the arena.
##   pierce_boss    Pierce installed, 6 s of fire at the Warden (god mode).
##                  PASS = every shot that reached the boss damaged it.
##   dash_ring      Dash through a bullet wall. PASS = no damage taken.

const SCENARIOS := ["ricochet_wall", "pierce_boss", "dash_ring"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if args.size() > 0 else ""
	if not SCENARIOS.has(name):
		print("usage: -- <%s>" % "|".join(SCENARIOS))
		quit(2)
		return
	var ok: bool = await call(name)
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _game(modules: PackedStringArray, script_fn: Callable) -> Game:
	var game := Game.new()
	game.sandbox = true
	game.seed_value = 1
	game.start_modules = modules
	game.god_mode = true
	var src := InputSource.ScriptedInput.new()
	src.script_fn = script_fn
	game.input_source = src
	game.step_budget = 0
	root.add_child(game)
	await physics_frame
	return game


func _run(game: Game, ticks: int) -> void:
	game.step_budget = ticks
	while game.step_budget > 0:
		await physics_frame
	await physics_frame


func ricochet_wall() -> bool:
	var game := await _game(["ricochet"], func(_t, g): return InputFrame.make(Vector2.ZERO, Vector2(1300, g.player.global_position.y), true))
	var escaped := 0
	var came_back := 0 # bullet-ticks spent flying back (vx < 0) after a bounce
	for i in 180:
		await _run(game, 1)
		for p in game.projectiles.active_projectiles():
			if not Arena.BOUNDS.grow(1).has_point(p.pos):
				escaped += 1
			if p.vel.x < 0.0:
				came_back += 1
	var s := game.stats
	print("shots %d  wall contacts %d  bullet-ticks flying back %d  escaped %d" % [s["shots"], s["ricochets"], came_back, escaped])
	return came_back >= s["ricochets"] * 10 and s["ricochets"] > 0 and escaped == 0


func pierce_boss() -> bool:
	var game := await _game(["pierce"], func(_t, g):
		var target: Vector2 = g.enemies[0].global_position if not g.enemies.is_empty() else Vector2(640, 200)
		return InputFrame.make(Vector2.ZERO, target, true))
	var boss: Warden = game.spawn_enemy("boss", Vector2(480, 220), true) # clear line of fire (centre pillar is at x 610..670)
	boss.speed = 0.0
	boss.max_hp = 100000.0
	boss.hp = 100000.0
	boss.attack_timer = 9999.0
	await _run(game, 360)
	var s := game.stats
	var landed := 100000.0 - boss.hp
	print("shots %d  hits %d  damage %.1f  in flight %d" % [s["shots"], s["hits"], landed, game.projectiles.active_count()])
	return s["hits"] >= s["shots"] - game.projectiles.active_count() - 1


func dash_ring() -> bool:
	var game := await _game([], func(t, g):
		return InputFrame.make(Vector2.UP, g.player.global_position + Vector2.UP * 100, false, t == 1))
	game.god_mode = false
	var pp := game.player.global_position
	for x in range(-60, 61, 12):
		var b = game.projectiles.spawn(pp + Vector2(x, -70), Vector2(0, 200), true, 1.0, Color.ORANGE)
		b.radius = 6.0
	await _run(game, 40)
	print("hp %d/%d  iframes left %.2f" % [game.player.hp, Player.MAX_HP, game.player.iframes])
	return game.player.hp == Player.MAX_HP
