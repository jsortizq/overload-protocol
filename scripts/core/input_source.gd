class_name InputSource
extends RefCounted
## Produces one InputFrame per simulation tick.
## LiveInput reads the keyboard/mouse; ScriptedInput replays frames or runs a
## callable (used by tests and by the replay tool).


func next_frame(_game: Node) -> InputFrame:
	return InputFrame.new()


class LiveInput:
	extends InputSource
	var queued_choice := 0 ## set by clicking an upgrade card in the HUD

	func next_frame(game: Node) -> InputFrame:
		var f := InputFrame.new()
		f.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		f.aim = (game as Node2D).get_global_mouse_position()
		f.fire = Input.is_action_pressed("fire")
		f.dash = Input.is_action_just_pressed("dash")
		if Input.is_action_just_pressed("pick_1"):
			f.choice = 1
		elif Input.is_action_just_pressed("pick_2"):
			f.choice = 2
		elif queued_choice != 0:
			f.choice = queued_choice
		queued_choice = 0
		return f


class ScriptedInput:
	extends InputSource
	## Either a list of frames (replay) or a Callable(tick: int, game) -> InputFrame.
	var frames: Array = []
	var script_fn: Callable
	var _index := 0

	func next_frame(game: Node) -> InputFrame:
		if script_fn.is_valid():
			_index += 1
			return script_fn.call(_index, game)
		if _index < frames.size():
			_index += 1
			return frames[_index - 1]
		return InputFrame.new()
