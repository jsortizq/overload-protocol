extends TestCase


func _mods(ids: Array) -> Array[WeaponModule]:
	var out: Array[WeaponModule] = []
	for id in ids:
		out.append(ModuleLibrary.by_id(id))
	return out


func test_base_spec_without_modules() -> void:
	var s := WeaponSpec.compose([])
	assert_eq(s.count, 1)
	assert_eq(s.bounces, 0)
	assert_near(s.damage, WeaponSpec.BASE_DAMAGE, 0.0001)
	assert_near(s.fire_interval, WeaponSpec.BASE_INTERVAL, 0.0001)


func test_additive_fields_stack() -> void:
	var s := WeaponSpec.compose(_mods(["ricochet", "pierce", "overcharge"]))
	assert_eq(s.bounces, 2)
	assert_eq(s.pierce, 2)
	assert_eq(s.chain, 2)


func test_multipliers_multiply() -> void:
	var s := WeaponSpec.compose(_mods(["rapid", "heavy"]))
	assert_near(s.damage, 1.0 * 0.8 * 1.8, 0.0001, "damage")
	assert_near(s.fire_interval, WeaponSpec.BASE_INTERVAL / (1.6 * 0.8), 0.0001, "interval")


func test_composition_is_order_independent() -> void:
	var a := WeaponSpec.compose(_mods(["split", "heavy", "rapid", "ricochet"])).summary()
	var b := WeaponSpec.compose(_mods(["ricochet", "rapid", "heavy", "split"])).summary()
	var c := WeaponSpec.compose(_mods(["heavy", "split", "ricochet", "rapid"])).summary()
	assert_eq(a, b)
	assert_eq(b, c)


func test_auto_spread_when_module_adds_projectiles_only() -> void:
	var m := WeaponModule.new()
	m.extra_projectiles = 2
	var mods: Array[WeaponModule] = [m]
	var s := WeaponSpec.compose(mods)
	assert_eq(s.count, 3)
	assert_near(s.spread_deg, WeaponSpec.AUTO_SPREAD_DEG * 2, 0.001)


func test_volley_is_symmetric_around_aim() -> void:
	var s := WeaponSpec.compose(_mods(["split"]))
	var dirs := s.volley_directions(Vector2.RIGHT)
	assert_eq(dirs.size(), 3)
	assert_near(dirs[1].angle(), 0.0, 0.0001, "middle shot on aim")
	assert_near(dirs[0].angle(), -dirs[2].angle(), 0.0001, "outer shots mirrored")
	assert_near(rad_to_deg(dirs[2].angle() - dirs[0].angle()), s.spread_deg, 0.01)


func test_upgrade_roll_is_seeded_distinct_and_skips_owned() -> void:
	var owned := _mods(["ricochet", "split"])
	var r1 := RandomNumberGenerator.new()
	r1.seed = 42
	var r2 := RandomNumberGenerator.new()
	r2.seed = 42
	var a := ModuleLibrary.roll_choices(r1, owned, 2)
	var b := ModuleLibrary.roll_choices(r2, owned, 2)
	assert_eq(a, b, "same seed, same cards")
	assert_eq(a.size(), 2)
	assert_true(a[0] != a[1], "distinct")
	for m in a:
		assert_false(owned.has(m), "offered a module already owned: %s" % m.id)


func test_every_module_resource_loads() -> void:
	assert_eq(ModuleLibrary.ALL.size(), 6)
	var ids := {}
	for m in ModuleLibrary.ALL:
		assert_true(m.id != "", "module without id")
		assert_false(ids.has(m.id), "duplicate id %s" % m.id)
		ids[m.id] = true
