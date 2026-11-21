class_name Game
extends Node2D
## Composition root and simulation clock.
##
## Every gameplay system is ticked from HERE, in a fixed order, at a fixed
## step (1/60 s). Nodes never run gameplay in their own _physics_process.
## Combined with a seeded RNG and InputFrames this makes a run fully
## reproducible: same seed + same inputs = same outcome.
##
## Tick order:
##   1. read one InputFrame (always, even during hitstop -> replays stay aligned)
##   2. hitstop: if frozen, skip the simulation this tick
##   3. player     (movement, dash, firing)
##   4. director   (telegraphs, spawns)
##   5. enemies    (AI + movement) in spawn order
##   6. projectiles (swept-ray collision, bounces, pierce, chain)
##   7. contacts   (enemy body vs player)
##   8. wave flow  (clear -> upgrade -> next wave / victory)

enum State { COMBAT, UPGRADE, INTERMISSION, WON, DEAD }
const STATE_NAMES: Array[String] = ["COMBAT", "UPGRADE", "INTERMISSION", "WON", "DEAD"]
const DT := 1.0 / 60.0
const INTERMISSION_TICKS := 75

const ENEMY_SCENES := {
	"chaser": preload("res://scenes/enemies/chaser.tscn"),
	"shooter": preload("res://scenes/enemies/shooter.tscn"),
	"shield": preload("res://scenes/enemies/shield.tscn"),
	"boss": preload("res://scenes/enemies/warden.tscn"),
}
const PLAYER_SCENE := preload("res://scenes/player.tscn")

signal event_logged(text: String)

## Set before adding to the tree. sandbox = no waves (used by tests).
var seed_value := 1337
var sandbox := false
## QA cheat: the player takes no damage (toggle with F3 while debugging).
var god_mode := false
## -1 = run freely every physics frame. >= 0 = run only this many more ticks
## (tests and tools use it to advance an exact number of ticks).
var step_budget := -1
var input_source: InputSource

## Independent random streams. Upgrade cards have their own stream so the
## cards offered depend only on the seed and the cards already picked, not
## on how the player moved (which changes how many gameplay rolls happened).
var rng := RandomNumberGenerator.new()          # gameplay (spawns, AI)
var upgrade_rng := RandomNumberGenerator.new()  # upgrade cards
var fx_rng := RandomNumberGenerator.new()       # cosmetic (shake, sparks)
## Module ids installed at start (QA: --modules=pierce,ricochet).
var start_modules: PackedStringArray = []
var tick := 0
var state: int = State.COMBAT
var hitstop := 0
var player: Player
var enemies: Array[Enemy] = []
var director: WaveDirector
var projectiles: ProjectileSystem
var fx: FxLayer
var camera: Camera2D
var upgrade_choices: Array[WeaponModule] = []
var recording: Array = []
var events := PackedStringArray()
var stats := {"kills": 0, "shots": 0, "hits": 0, "ricochets": 0, "damage_taken": 0}

var _entities: Node2D
var _intermission := 0
var _shake := 0.0


func _ready() -> void:
	rng.seed = seed_value
	upgrade_rng.seed = seed_value * 31 + 7
	fx_rng.seed = seed_value ^ 0x5f3759df
	if input_source == null:
		input_source = InputSource.LiveInput.new()
	add_child(Arena.new())
	_entities = Node2D.new()
	_entities.name = "Entities"
	add_child(_entities)
	projectiles = ProjectileSystem.new()
	projectiles.game = self
	add_child(projectiles)
	fx = FxLayer.new()
	fx.game = self
	add_child(fx)
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)
	camera.make_current()
	player = PLAYER_SCENE.instantiate()
	player.game = self
	player.position = Arena.BOUNDS.get_center() + Vector2(0, 160)
	_entities.add_child(player)
	for id in start_modules:
		var m := ModuleLibrary.by_id(id)
		if m != null:
			player.add_module(m)
	director = WaveDirector.new(self)
	if not sandbox:
		director.start_wave(0)


## The simulation only advances INSIDE a physics frame: Godot updates the
## physics broadphase when the frame's physics step runs, so ticking outside
## of it would cast rays against stale body positions.
func _physics_process(_delta: float) -> void:
	if step_budget == 0:
		return
	if step_budget > 0:
		step_budget -= 1
	step()


## One simulation tick.
func step() -> void:
	var frame := input_source.next_frame(self)
	recording.append(frame.to_array())
	if frame.dash:
		player.buffer_dash()
	if hitstop > 0:
		hitstop -= 1
		return
	tick += 1
	match state:
		State.COMBAT:
			_combat_tick(frame)
		State.UPGRADE:
			player.tick(frame, false)
			if frame.choice in [1, 2] and frame.choice <= upgrade_choices.size():
				_apply_upgrade(upgrade_choices[frame.choice - 1])
		State.INTERMISSION:
			player.tick(frame, false)
			_intermission -= 1
			if _intermission <= 0:
				_set_state(State.COMBAT)
				director.start_wave(director.wave_index + 1)
		_:
			pass


func _combat_tick(frame: InputFrame) -> void:
	player.tick(frame, true)
	director.tick()
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.state != Enemy.State.DEAD:
			e.tick()
	projectiles.tick()
	_resolve_contacts()
	if state == State.COMBAT and not sandbox and director.is_wave_finished():
		_on_wave_cleared()


func _resolve_contacts() -> void:
	if player.state == Player.State.DEAD:
		return
	for e in enemies:
		if not e.can_touch():
			continue
		var d := player.global_position.distance_to(e.global_position)
		if d < Player.RADIUS + e.radius:
			var dir := (player.global_position - e.global_position).normalized()
			player.hurt(e.contact_damage, dir)
			# Contact recoil: the enemy bounces off even if the player is
			# invulnerable, so enemies can't stack on top of the player.
			e.knock -= dir * 260.0


# ------------------------------------------------------------------ waves

func _on_wave_cleared() -> void:
	log_event("Wave %d cleared" % (director.wave_index + 1))
	if director.is_boss_wave():
		_set_state(State.WON)
		return
	upgrade_choices = ModuleLibrary.roll_choices(upgrade_rng, player.modules, 2)
	if upgrade_choices.is_empty():
		_start_intermission()
	else:
		_set_state(State.UPGRADE)


func _apply_upgrade(m: WeaponModule) -> void:
	player.add_module(m)
	log_event("Installed module: %s" % m.display_name)
	upgrade_choices.clear()
	_start_intermission()


func _start_intermission() -> void:
	_intermission = INTERMISSION_TICKS
	_set_state(State.INTERMISSION)


func _set_state(s: int) -> void:
	state = s
	if s == State.DEAD:
		log_event("Player down")


func on_player_died() -> void:
	_set_state(State.DEAD)


# ---------------------------------------------------------------- entities

func spawn_enemy(kind: String, pos: Vector2, skip_spawn_anim := false) -> Enemy:
	var e: Enemy = ENEMY_SCENES[kind].instantiate()
	e.game = self
	e.position = pos
	_entities.add_child(e)
	if skip_spawn_anim:
		e.finish_spawning()
	enemies.append(e)
	e.died.connect(_on_enemy_died)
	return e


func _on_enemy_died(e: Enemy) -> void:
	enemies.erase(e)
	stats["kills"] += 1
	add_hitstop(4 if e.kind != "boss" else 30)
	add_shake(6.0 if e.kind != "boss" else 22.0)
	fx.burst(e.global_position, e.body_color(), 18 if e.kind != "boss" else 60)


## Living enemies within `radius` of `pos`, nearest first.
func enemies_near(pos: Vector2, radius: float, exclude: Enemy = null) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies:
		if e != exclude and e.is_hittable() and e.global_position.distance_to(pos) <= radius:
			out.append(e)
	out.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	return out


# -------------------------------------------------------------- QA cheats

func debug_kill_all() -> void:
	director.clear_pending()
	for e in enemies.duplicate():
		e.die()
	log_event("DEBUG: killed all enemies")


func debug_skip_to_wave(index: int) -> void:
	debug_kill_all()
	projectiles.clear_all()
	_set_state(State.COMBAT)
	director.start_wave(clampi(index, 0, director.wave_count() - 1))
	log_event("DEBUG: skipped to wave %d" % (index + 1))


# -------------------------------------------------------------------- juice

func add_hitstop(ticks: int) -> void:
	hitstop = maxi(hitstop, ticks)


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 28.0)


func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, 60.0 * delta)
	camera.offset = Vector2(fx_rng.randf_range(-1, 1), fx_rng.randf_range(-1, 1)) * _shake


func log_event(text: String) -> void:
	events.append("[%05d] %s" % [tick, text])
	if events.size() > 8:
		events.remove_at(0)
	event_logged.emit(text)


# -------------------------------------------------------------- inspection

func state_name() -> String:
	return STATE_NAMES[state]


## Deterministic one-line summary used by tests and the debug overlay.
func summary() -> String:
	var hp_sum := 0
	for e in enemies:
		hp_sum += ceili(e.hp)
	return "t=%d %s wave=%d p=(%d,%d) hp=%d enemies=%d ehp=%d proj=%d mods=%s kills=%d" % [
		tick, state_name(), director.wave_index + 1,
		roundi(player.global_position.x), roundi(player.global_position.y), player.hp,
		enemies.size(), hp_sum, projectiles.active_count(),
		",".join(player.modules.map(func(m: WeaponModule) -> String: return m.id)), stats["kills"],
	]
