# Reference solution: bug-02

## Root cause

Projectiles are pooled. Each `Projectile` keeps an `exclude: Array[RID]`, the bodies its
ray must ignore. When a piercing bullet hits an enemy, that enemy's RID is appended, so
the next substep doesn't hit the same enemy again.

When a bullet dies, its slot returns to the free list. `spawn()` takes the most recently
freed slot (LIFO) and calls `reset()`. On this branch `reset()` resets every field
**except** `exclude`:

```diff
 	func reset() -> void:
 		...
 		color = Color.WHITE
+		exclude.clear()
```

So:

1. Bullet A pierces the Warden: `exclude = [warden_rid]`. It flies on, hits the back wall and is released.
2. Bullet B gets A's slot (LIFO) and inherits `exclude = [warden_rid]`.
3. B's rays ignore the Warden entirely, and so does every later bullet using that slot.

Enemy RIDs stay valid while the enemy is alive, so the longest-lived enemy (the boss)
shows the bug the most. Short-lived enemies hide it because their RIDs vanish when they die.

## Why it took Pierce to show up

Without Pierce, a bullet that hits an enemy is released immediately and `exclude` stays
empty. The only other thing that writes to it is a hostile bullet passing a dashing player,
and that player RID is never in a player bullet's mask anyway.

## Fix

Clear the list in `reset()`, as in the diff above. `Array.clear()` keeps the allocated
capacity, so there are still no allocations per shot.

Diff between the branches: `git diff bug/02-pierce-stops-hitting-boss main -- scripts/weapons/projectile_system.gd`

## Hardening done on main

- `test_pool_slot_is_fully_reset_on_reuse` takes a slot, sets its bounces, pierce, chain
  and exclude list, releases it, takes it again and checks they're back to defaults.
- A comment on `reset()` warns that every new field must be reset there.

## Verification done

- `scenario pierce_boss`: 36 hits out of 38 shots (4 in flight) → PASS.
- Test suite: 39 / 39. Soak with seeds 7, 8, 9: all reach victory.
