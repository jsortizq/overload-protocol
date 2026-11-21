class_name FxLayer
extends Node2D
## Cosmetic feedback only: sparks, bursts, damage numbers, lightning arcs,
## dash trails and spawn telegraphs. Uses Game.fx_rng, never the gameplay
## RNG, so turning effects on/off can't change the outcome of a run.

const MAX_PARTICLES := 400

var game: Game
var _particles: Array = []  # {pos, vel, life, max, color, size}
var _numbers: Array = []    # {pos, text, life}
var _arcs: Array = []       # {a, b, life}
var _trails: Array = []     # {pos, dir, life}
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	z_index = 10


func spark(pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		_emit(pos, Vector2.from_angle(game.fx_rng.randf() * TAU) * game.fx_rng.randf_range(60, 220), color, 0.25, 2.0)


func burst(pos: Vector2, color: Color, count: int) -> void:
	for i in count:
		_emit(pos, Vector2.from_angle(game.fx_rng.randf() * TAU) * game.fx_rng.randf_range(80, 380), color, 0.5, 3.0)


func damage_number(pos: Vector2, amount: float) -> void:
	var text := str(snappedf(amount, 0.1)).trim_suffix(".0")
	_numbers.append({"pos": pos + Vector2(game.fx_rng.randf_range(-6, 6), 0), "text": text, "life": 0.6})


func lightning(a: Vector2, b: Vector2) -> void:
	_arcs.append({"a": a, "b": b, "life": 0.15})


func dash_trail(pos: Vector2, dir: Vector2) -> void:
	_trails.append({"pos": pos, "dir": dir, "life": 0.25})


func _emit(pos: Vector2, vel: Vector2, color: Color, life: float, size: float) -> void:
	if _particles.size() >= MAX_PARTICLES:
		_particles.pop_front()
	_particles.append({"pos": pos, "vel": vel, "life": life, "max": life, "color": color, "size": size})


func _process(delta: float) -> void:
	for p in _particles:
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.9
		p["life"] -= delta
	_particles = _particles.filter(func(p): return p["life"] > 0.0)
	for n in _numbers:
		n["pos"].y -= 40.0 * delta
		n["life"] -= delta
	_numbers = _numbers.filter(func(n): return n["life"] > 0.0)
	for a in _arcs:
		a["life"] -= delta
	_arcs = _arcs.filter(func(a): return a["life"] > 0.0)
	for t in _trails:
		t["life"] -= delta
	_trails = _trails.filter(func(t): return t["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	# spawn telegraphs
	if game.director != null:
		for m in game.director.markers:
			var t: float = 1.0 - m["ticks"] / float(WaveDirector.TELEGRAPH_TICKS)
			var col := Color("ff4d6d") if m["kind"] != "boss" else Color("ff8c42")
			var r := 26.0 if m["kind"] != "boss" else 48.0
			draw_arc(m["pos"], r * (1.0 - t * 0.6), 0, TAU, 28, Color(col, 0.35 + 0.5 * t), 2.0)
			draw_line(m["pos"] - Vector2(6, 0), m["pos"] + Vector2(6, 0), col, 2.0)
			draw_line(m["pos"] - Vector2(0, 6), m["pos"] + Vector2(0, 6), col, 2.0)
	for t in _trails:
		var a: float = t["life"] / 0.25
		draw_line(t["pos"], t["pos"] + t["dir"] * 110.0, Color(0.3, 0.88, 1.0, 0.5 * a), 10.0 * a)
	for p in _particles:
		var a: float = p["life"] / p["max"]
		draw_circle(p["pos"], p["size"] * a + 0.5, Color(p["color"], a))
	for arc in _arcs:
		_draw_bolt(arc["a"], arc["b"], arc["life"] / 0.15)
	for n in _numbers:
		var a: float = clampf(n["life"] / 0.3, 0.0, 1.0)
		draw_string(_font, n["pos"] - Vector2(20, 0), n["text"], HORIZONTAL_ALIGNMENT_CENTER, 40, 14, Color(1, 1, 1, a))


func _draw_bolt(a: Vector2, b: Vector2, alpha: float) -> void:
	var pts := PackedVector2Array([a])
	var segs := 6
	for i in range(1, segs):
		var p := a.lerp(b, float(i) / segs)
		pts.append(p + (b - a).orthogonal().normalized() * game.fx_rng.randf_range(-10, 10))
	pts.append(b)
	draw_polyline(pts, Color(1, 0.9, 0.3, alpha), 2.5)
