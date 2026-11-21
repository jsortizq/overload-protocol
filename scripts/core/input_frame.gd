class_name InputFrame
extends RefCounted
## Everything the player can do during ONE simulation tick.
## The simulation never reads Input directly; it only sees InputFrames.
## That is what makes runs recordable, replayable and testable headless.

var move := Vector2.ZERO   ## -1..1 on each axis
var aim := Vector2.ZERO    ## world-space point the player aims at
var fire := false          ## held
var dash := false          ## pressed this tick (edge)
var choice := 0            ## 0 = none, 1/2 = upgrade card picked this tick


static func make(move_v := Vector2.ZERO, aim_v := Vector2.ZERO, fire_v := false, dash_v := false, choice_v := 0) -> InputFrame:
	var f := InputFrame.new()
	f.move = move_v
	f.aim = aim_v
	f.fire = fire_v
	f.dash = dash_v
	f.choice = choice_v
	return f


## Lossless: rounding here would make replays drift from the original run.
func to_array() -> Array:
	return [move.x, move.y, aim.x, aim.y, int(fire), int(dash), choice]


static func from_array(a: Array) -> InputFrame:
	return make(Vector2(a[0], a[1]), Vector2(a[2], a[3]), a[4] == 1, a[5] == 1, int(a[6]))
