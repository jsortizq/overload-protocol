extends SceneTree
## Runs a full game with the AutoPilot, headless and as fast as possible.
##   godot --headless --fixed-fps 60 --path . --script res://tools/soak.gd -- [seed] [max_ticks] [god]
## --fixed-fps 60 makes every frame exactly one tick and removes the
## real-time wait, so a 2-minute run takes well under a second.
## With `god`, exits 1 unless the run reaches victory (soft-lock detector).


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 7
	var max_ticks := int(args[1]) if args.size() > 1 else 60 * 60 * 6
	var game := Game.new()
	game.seed_value = seed_value
	game.input_source = AutoPilot.new()
	game.god_mode = args.has("god")
	root.add_child(game)
	var t0 := Time.get_ticks_msec()
	while game.tick < max_ticks:
		await physics_frame
		if game.tick % 600 == 0:
			print(game.summary())
		if game.state in [Game.State.WON, Game.State.DEAD]:
			break
	print("FINAL ", game.summary())
	for e in game.enemies:
		print("  enemy %s %s hp %.1f at %s" % [e.kind, e.behavior, e.hp, e.global_position.round()])
	print("events: ", " | ".join(game.events))
	print("stats: ", game.stats)
	print("pool: ", game.projectiles.stats, "  wall time %d ms" % (Time.get_ticks_msec() - t0))
	# In god mode the run MUST finish: anything else is a soft-lock.
	quit(1 if game.god_mode and game.state != Game.State.WON else 0)
