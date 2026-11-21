extends SceneTree
## Plays N ticks with the AutoPilot (god mode) and saves a screenshot.
##   godot --fixed-fps 60 --path . --script res://tools/capture.gd -- <seed> <ticks> <out.png> [debug] [boss]
## Needs a renderer (not --headless). On Linux CI: xvfb-run.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0])
	var ticks := int(args[1])
	var out: String = args[2]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game(seed_value, AutoPilot.new())
	main.game.god_mode = true
	await physics_frame
	if args.has("boss"):
		main.game.debug_skip_to_wave(3)
		for id in ["ricochet", "overcharge", "pierce"]:
			main.game.player.add_module(ModuleLibrary.by_id(id))
	if args.has("debug"):
		main._debug.visible = true
		main._world_debug.visible = true
	var stop_at_upgrade := args.has("upgrade")
	if stop_at_upgrade:
		(main.game.input_source as AutoPilot).choice_pref = 0 # never pick
	while main.game.tick < ticks and main.game.state != Game.State.WON:
		await physics_frame
		if stop_at_upgrade and main.game.state == Game.State.UPGRADE:
			break
	main.game.step_budget = 0
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out, "  ", main.game.summary())
	quit()
