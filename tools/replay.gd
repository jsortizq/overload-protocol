extends SceneTree
## Replays a run saved with F2 and checks it reproduces the same final state.
##   godot --headless --fixed-fps 60 --path . --script res://tools/replay.gd -- <run.json> [--trace N]
## <run.json> defaults to user://last_run.json. --trace N prints the summary
## every N ticks, which is how a bug report becomes a precise repro.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := "user://last_run.json"
	var trace := 0
	for i in args.size():
		if args[i] == "--trace" and i + 1 < args.size():
			trace = int(args[i + 1])
		elif not args[i].begins_with("--") and (i == 0 or args[i - 1] != "--trace"):
			path = args[i]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var frames: Array = []
	for a in data["frames"]:
		frames.append(InputFrame.from_array(a))
	var game := Game.new()
	game.seed_value = int(data["seed"])
	var src := InputSource.ScriptedInput.new()
	src.frames = frames
	game.input_source = src
	game.step_budget = frames.size()
	root.add_child(game)
	while game.step_budget > 0:
		await physics_frame
		if trace > 0 and game.recording.size() % trace == 0:
			print(game.summary())
	await physics_frame
	var expected: String = data.get("summary", "")
	print("replayed %d frames (seed %d)" % [frames.size(), game.seed_value])
	print("expected: ", expected)
	print("actual:   ", game.summary())
	var ok := expected == "" or expected == game.summary()
	print("MATCH" if ok else "MISMATCH")
	quit(0 if ok else 1)
