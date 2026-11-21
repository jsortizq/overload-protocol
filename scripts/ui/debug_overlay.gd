class_name DebugOverlay
extends Control
## F1 QA panel: FPS, tick, seed, pool stats, player timers, per-enemy FSM
## table, weapon spec and the event log. WorldDebug (below) draws hitboxes,
## shield arcs, aim lines and velocities in world space.

var game: Game
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	visible = false


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var p := game.player
	var ps := game.projectiles.stats
	var lines := PackedStringArray([
		"DEBUG  FPS %d  tick %d  seed %d  state %s  hitstop %d" % [Engine.get_frames_per_second(), game.tick, game.seed_value, game.state_name(), game.hitstop],
		"player %s hp %d pos (%d,%d) vel (%d,%d) dash_cd %.2f iframes %.2f" % [p.state_name(), p.hp, p.global_position.x, p.global_position.y, p.velocity.x, p.velocity.y, p.dash_cooldown, p.iframes],
		"weapon %s" % p.spec.summary(),
		"pool active %d / free %d / cap %d  peak %d  spawned %d  dropped %d" % [game.projectiles.active_count(), game.projectiles.free_count(), ProjectileSystem.CAPACITY, ps["peak"], ps["spawned"], ps["dropped"]],
		"shots %d  hits %d  ricochets %d  kills %d   markers %d  enemies %d" % [game.stats["shots"], game.stats["hits"], game.stats["ricochets"], game.stats["kills"], game.director.markers.size(), game.enemies.size()],
	])
	for e in game.enemies:
		lines.append("  %-7s %-22s hp %5.1f/%-5.1f (%d,%d)" % [e.kind, e.behavior, e.hp, e.max_hp, e.global_position.x, e.global_position.y])
	for ev in game.events:
		lines.append("  " + ev)
	var h := 16.0 * lines.size() + 12.0
	draw_rect(Rect2(8, 66, 640, h), Color(0.02, 0.03, 0.05, 0.85))
	draw_rect(Rect2(8, 66, 640, h), Color("4de1ff"), false, 1.0)
	for i in lines.size():
		draw_string(_font, Vector2(16, 82 + i * 16), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 620, 12, Color("d7deea"))


class WorldDebug:
	extends Node2D
	var game: Game

	func _ready() -> void:
		z_index = 20
		visible = false

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		var p := game.player
		var col := Color(1, 1, 0, 0.9) if p.is_invulnerable() else Color(0, 1, 0.5, 0.9)
		draw_arc(p.global_position, Player.RADIUS, 0, TAU, 24, col, 1.0)
		draw_line(p.global_position, p.global_position + p.velocity * 0.2, Color.WHITE, 1.0)
		for e in game.enemies:
			draw_arc(e.global_position, e.radius, 0, TAU, 24, Color(1, 0.3, 0.3, 0.9), 1.0)
			draw_line(e.global_position, e.global_position + e.velocity * 0.3, Color(1, 0.5, 0.5, 0.8), 1.0)
			if e is ShieldBearer:
				var a: float = e.facing.angle()
				for s in [-1.0, 1.0]:
					draw_line(e.global_position, e.global_position + Vector2.from_angle(a + s * ShieldBearer.SHIELD_HALF_ANGLE) * 60.0, Color(0.3, 0.9, 1, 0.8), 1.0)
		for pr in game.projectiles.active_projectiles():
			draw_arc(pr.pos, pr.radius, 0, TAU, 8, Color(1, 1, 1, 0.8), 1.0)
		draw_rect(Arena.BOUNDS, Color(0.3, 0.9, 1, 0.4), false, 1.0)
