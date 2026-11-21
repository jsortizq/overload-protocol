class_name WaveDirector
extends RefCounted
## Turns wave definitions into a deterministic spawn schedule.
## Every spawn is telegraphed by a marker for TELEGRAPH_TICKS before the
## enemy appears, so nothing ever pops into existence on top of the player.

const TELEGRAPH_TICKS := 48       # 0.8 s warning
const MIN_SPAWN_DISTANCE := 240.0 # from the player

const WAVES := [
	[{"kind": "chaser", "count": 8, "interval": 0.55}],
	[{"kind": "chaser", "count": 6, "interval": 0.8}, {"kind": "shooter", "count": 4, "interval": 1.4}],
	[{"kind": "shield", "count": 4, "interval": 1.6}, {"kind": "shooter", "count": 3, "interval": 1.8}, {"kind": "chaser", "count": 6, "interval": 0.9}],
	[{"kind": "boss", "count": 1, "interval": 0.0}],
]

var game: Game
var wave_index := -1
var _schedule: Array = []  # [{ "tick": int, "kind": String }], sorted by tick
var markers: Array = []    # [{ "pos": Vector2, "kind": String, "ticks": int }]
var _wave_tick := 0


func _init(g: Game) -> void:
	game = g


func wave_count() -> int:
	return WAVES.size()


func is_boss_wave() -> bool:
	return wave_index == WAVES.size() - 1


func start_wave(index: int) -> void:
	wave_index = index
	_wave_tick = 0
	_schedule.clear()
	markers.clear()
	for group in WAVES[index]:
		for i in group["count"]:
			_schedule.append({"tick": int(round(i * group["interval"] * 60.0)) + 30, "kind": group["kind"]})
	_schedule.sort_custom(func(a, b): return a["tick"] < b["tick"])
	game.log_event("Wave %d started (%d hostiles)" % [index + 1, _schedule.size()])


## Extra spawn requested by gameplay (e.g. the boss summoning adds).
func request_spawn(kind: String, pos: Vector2) -> void:
	var safe := Arena.BOUNDS.grow(-30.0)
	pos = pos.clamp(safe.position, safe.end)
	markers.append({"pos": pos, "kind": kind, "ticks": TELEGRAPH_TICKS})


func tick() -> void:
	_wave_tick += 1
	while not _schedule.is_empty() and _schedule[0]["tick"] <= _wave_tick:
		var entry: Dictionary = _schedule.pop_front()
		var pos := _pick_spawn_point(entry["kind"])
		markers.append({"pos": pos, "kind": entry["kind"], "ticks": TELEGRAPH_TICKS})
	for m in markers:
		m["ticks"] -= 1
	for m in markers.filter(func(m): return m["ticks"] <= 0):
		game.spawn_enemy(m["kind"], m["pos"])
		markers.erase(m)


## Drops everything not spawned yet (QA "kill all" cheat).
func clear_pending() -> void:
	_schedule.clear()
	markers.clear()


func is_wave_finished() -> bool:
	return _schedule.is_empty() and markers.is_empty() and game.enemies.is_empty()


## Two bodies spawned on the same point overlap; the physics solver then
## pushes one of them out — sometimes straight through a wall.
func _occupied(p: Vector2) -> bool:
	for m in markers:
		if (m["pos"] as Vector2).distance_to(p) < 48.0:
			return true
	for e in game.enemies:
		if e.global_position.distance_to(p) < 48.0:
			return true
	return false


func _pick_spawn_point(kind: String) -> Vector2:
	if kind == "boss":
		return Arena.BOUNDS.get_center() + Vector2(0, -160)
	var options := Arena.spawn_points().filter(
		func(p: Vector2) -> bool: return p.distance_to(game.player.global_position) >= MIN_SPAWN_DISTANCE and not _occupied(p))
	if options.is_empty():
		options = Arena.spawn_points().filter(func(p: Vector2) -> bool: return not _occupied(p))
	if options.is_empty():
		options = Arena.spawn_points()
	return options[game.rng.randi_range(0, options.size() - 1)]
