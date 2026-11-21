extends Node
## Owns the current Game instance plus UI that survives restarts.
## R restarts with a new seed; F2 saves the run (seed + every InputFrame) to
## user://last_run.json, which tools/replay.gd can play back headless.
## Command line (after `--`): --seed=N fixes the seed, --modules=a,b starts
## with modules installed. With F1 open: F3 god mode, F4 kill all, F5 boss.

var game: Game
var _hud: Hud
var _debug: DebugOverlay
var _world_debug: DebugOverlay.WorldDebug
var _ui: CanvasLayer
var _next_seed := 0
var _start_modules: PackedStringArray = []


func _ready() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_hud = Hud.new()
	_ui.add_child(_hud)
	_debug = DebugOverlay.new()
	_ui.add_child(_debug)
	var seed_arg := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_arg = int(a.substr(7))
		elif a.begins_with("--modules="):
			_start_modules = a.substr(10).split(",", false)
	_next_seed = seed_arg if seed_arg != 0 else int(Time.get_unix_time_from_system()) % 100000
	start_game(_next_seed)


func start_game(seed_value: int, source: InputSource = null) -> void:
	if game != null:
		game.queue_free()
	game = Game.new()
	game.seed_value = seed_value
	game.input_source = source
	game.start_modules = _start_modules
	add_child(game)
	move_child(game, 0)
	_world_debug = DebugOverlay.WorldDebug.new()
	_world_debug.game = game
	_world_debug.visible = _debug.visible
	game.add_child(_world_debug)
	_hud.game = game
	_debug.game = game


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug.visible = not _debug.visible
		_world_debug.visible = _debug.visible
	elif event.is_action_pressed("restart"):
		start_game(int(Time.get_unix_time_from_system() + game.tick) % 100000)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_F2:
		_save_replay()
	elif event is InputEventKey and event.pressed and _debug.visible:
		# QA cheats, only while the debug overlay is open
		match event.physical_keycode:
			KEY_F3:
				game.god_mode = not game.god_mode
				game.log_event("DEBUG: god mode %s" % ("ON" if game.god_mode else "OFF"))
			KEY_F4:
				game.debug_kill_all()
			KEY_F5:
				game.debug_skip_to_wave(game.director.wave_count() - 1)


func _save_replay() -> void:
	var path := "user://last_run.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"seed": game.seed_value, "frames": game.recording, "summary": game.summary()}))
	f.close()
	game.log_event("Replay saved: %s (%d frames)" % [ProjectSettings.globalize_path(path), game.recording.size()])
