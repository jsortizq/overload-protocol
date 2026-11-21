class_name WeaponSpec
extends RefCounted
## The resolved stats of the player's gun after applying every module.
##
## Composition rule (order independent, covered by tests):
##   1. start from the base stats
##   2. add all additive fields (projectiles, spread, bounces, pierce, chain)
##   3. multiply by the PRODUCT of all multipliers
## Sums and products commute, so [Split, Heavy] == [Heavy, Split].

const BASE_DAMAGE := 1.0
const BASE_SPEED := 820.0
const BASE_INTERVAL := 0.16
const BASE_KNOCKBACK := 120.0
const AUTO_SPREAD_DEG := 12.0 ## used when several projectiles but no spread

var damage := BASE_DAMAGE
var speed := BASE_SPEED
var fire_interval := BASE_INTERVAL
var count := 1
var spread_deg := 0.0
var bounces := 0
var pierce := 0
var chain := 0
var knockback := BASE_KNOCKBACK
var radius := 4.0
var lifetime := 1.1


static func compose(modules: Array[WeaponModule]) -> WeaponSpec:
	var s := WeaponSpec.new()
	var dmg := 1.0
	var rate := 1.0
	var spd := 1.0
	var kb := 1.0
	for m in modules:
		s.count += m.extra_projectiles
		s.spread_deg += m.spread_deg
		s.bounces += m.add_bounces
		s.pierce += m.add_pierce
		s.chain += m.add_chain
		dmg *= m.damage_mult
		rate *= m.fire_rate_mult
		spd *= m.speed_mult
		kb *= m.knockback_mult
	if s.count > 1 and is_zero_approx(s.spread_deg):
		s.spread_deg = AUTO_SPREAD_DEG * (s.count - 1)
	s.damage *= dmg
	s.fire_interval /= rate
	s.speed *= spd
	s.knockback *= kb
	return s


## Direction of each projectile in one volley, evenly spread around `aim`.
func volley_directions(aim: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if count <= 1:
		out.append(aim)
		return out
	var total := deg_to_rad(spread_deg)
	var step := total / float(count - 1)
	for i in count:
		out.append(aim.rotated(-total * 0.5 + step * i))
	return out


func summary() -> String:
	return "dmg %.2f  spd %d  rate %.1f/s  x%d  spread %d°  bounce %d  pierce %d  chain %d" % [
		damage, roundi(speed), 1.0 / fire_interval, count, roundi(spread_deg), bounces, pierce, chain]
