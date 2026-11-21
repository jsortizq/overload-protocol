# Feature request: "Shockwave" module

**From:** game designer
**Target build:** `main`

> "The dash is our best mechanic, but no module touches it. I want a seventh module,
> **Shockwave**: every dash ends with a pulse around the player that wipes out
> enemy bullets nearby and briefly staggers enemies. It should reward dashing INTO
> danger, so the pulse goes off where the dash ENDS, not where it starts."

## Requirements

1. **New module** `shockwave.tres` with `id = "shockwave"`, offered in the upgrade pool
   like the others. Its data lives in the resource: `shockwave_radius = 110`,
   `shockwave_stun = 0.5` s, `shockwave_knockback = 260`. These are new exported fields
   on `WeaponModule`, folded into `WeaponSpec` (additive; 0 when not owned).
2. **Trigger:** on the tick the dash ends (`DASHING → NORMAL`), if `spec.shockwave_radius > 0`.
3. **Effect:** within the radius, centred on the player:
   - every **hostile** projectile is destroyed (with a spark);
   - every hittable enemy takes **0 damage**, is knocked away from the player, and is
     **stunned**: no movement and no attacks for `shockwave_stun` seconds. A Shooter mid-aim
     cancels its shot; a Warden charge stops.
   - The Warden is immune to the stun but still loses its bullets.
4. **Feedback:** an expanding ring (FX), a small hitstop (3 ticks), and `stunned` shown as
   the enemy behaviour in F1.
5. **Determinism:** no new randomness. Existing replays with no Shockwave still match.

## Out of scope

Damage on the shockwave, upgrades that stack radius beyond a single copy.
