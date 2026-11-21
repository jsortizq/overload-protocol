class_name ModuleLibrary
extends RefCounted
## Every module available in the game.
## Listed explicitly with preload() instead of scanning the folder: in an
## exported build .tres files are remapped (*.tres.remap), so DirAccess
## listings differ between editor and export.

const ALL: Array[WeaponModule] = [
	preload("res://resources/modules/ricochet.tres"),
	preload("res://resources/modules/overcharge.tres"),
	preload("res://resources/modules/split.tres"),
	preload("res://resources/modules/pierce.tres"),
	preload("res://resources/modules/rapid.tres"),
	preload("res://resources/modules/heavy.tres"),
]


static func by_id(id: String) -> WeaponModule:
	for m in ALL:
		if m.id == id:
			return m
	return null


## `count` distinct modules the player doesn't own yet, chosen with the
## gameplay RNG so the same seed offers the same cards.
static func roll_choices(rng: RandomNumberGenerator, owned: Array[WeaponModule], count: int) -> Array[WeaponModule]:
	var pool: Array[WeaponModule] = []
	for m in ALL:
		if not owned.has(m):
			pool.append(m)
	var out: Array[WeaponModule] = []
	while out.size() < count and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out
