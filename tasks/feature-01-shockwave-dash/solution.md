# Reference solution: feature-01

> Status: **design notes only, implementation pending** (branch `feature/01-shockwave-dash`).

## Touch points

| System | Change |
|--------|--------|
| `WeaponModule` | `@export_group("Dash")`: `shockwave_radius`, `shockwave_stun`, `shockwave_knockback` |
| `WeaponSpec.compose` | sum the three fields (additive group) |
| `resources/modules/shockwave.tres` + `ModuleLibrary.ALL` | new entry |
| `Player.tick` | on the `DASHING → NORMAL` transition: `if spec.shockwave_radius > 0: game.shockwave(global_position, spec)` |
| `Game.shockwave()` | destroy hostile projectiles in the radius (`projectiles.active_projectiles()` + `life = 0`, or a `release_where()` helper), call `e.stun(t, dir * kb)` on enemies in range, add hitstop and FX |
| `Enemy` | `stun_left`; `tick()` skips `_think()` while stunned and sets `behavior = "stunned"`; `stun()` is virtual |
| `Shooter.stun` | also sets `aim_left = 0` |
| `Warden.stun` | override: immune (only the bullets are cleared) |
| `FxLayer` | `ring(pos, radius)` effect |

## Edge cases to cover

- The dash ends on the same tick hitstop starts: the dash transition happens inside
  `player.tick`, so it's never skipped (hitstop only skips whole ticks).
- An enemy inside the radius that is still SPAWNING isn't hittable, so it isn't stunned.
- Bullets destroyed by the shockwave go back to the pool through the normal release path
  (no double release).
