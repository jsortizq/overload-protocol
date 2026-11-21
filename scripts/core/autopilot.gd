class_name AutoPilot
extends InputSource
## A simple deterministic bot that produces InputFrames from the game state.
## Used for soak tests ("can a full run complete without errors?"), the
## determinism test, and to generate screenshots. It is intentionally
## simple: aim at the closest enemy, keep distance, dash through bullets.

var choice_pref := 1


func next_frame(game_node: Node) -> InputFrame:
	var game := game_node as Game
	var f := InputFrame.new()
	var me := game.player.global_position
	var target: Enemy = null
	var best := INF
	for e in game.enemies:
		if e.is_hittable():
			var d := me.distance_squared_to(e.global_position)
			if d < best:
				best = d
				target = e
	if target != null:
		# lead the target
		var t := me.distance_to(target.global_position) / game.player.spec.speed
		f.aim = target.global_position + target.velocity * t
		f.fire = true
		var away := (me - target.global_position)
		var dist := away.length()
		var tangent := away.orthogonal().normalized()
		var want := tangent
		# Shields turn at a limited rate: orbit them tightly to get behind.
		var near_r := 100.0 if target is ShieldBearer else 170.0
		var far_r := 140.0 if target is ShieldBearer else 320.0
		if dist < near_r:
			want += away.normalized()
		elif dist > far_r:
			want -= away.normalized() * 0.8
		# stay away from walls
		var center := Arena.BOUNDS.get_center()
		if not Arena.BOUNDS.grow(-90).has_point(me):
			want += (center - me).normalized() * 1.5
		f.move = want.normalized()
		# Dash THROUGH a shield bearer to land behind its shield.
		if target is ShieldBearer and dist < 120.0 and game.player.dash_cooldown <= 0.0:
			f.move = -away.normalized()
			f.dash = true
	else:
		f.aim = me + Vector2.UP * 100
		f.move = (Arena.BOUNDS.get_center() + Vector2(0, 120) - me).limit_length(1.0) * 0.5
	# dash through incoming bullets
	for p in game.projectiles.active_projectiles():
		if p.hostile and p.pos.distance_to(me) < 60.0 and p.vel.dot(me - p.pos) > 0.0:
			f.dash = true
			break
	if game.state == Game.State.UPGRADE:
		f.choice = choice_pref
	return f
