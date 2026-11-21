# Acceptance criteria: feature-01

All checks run in the sandbox (`TestCase.make_game`), with `--modules=shockwave` or
`player.add_module(ModuleLibrary.by_id("shockwave"))`.

| # | Setup | Input | Expected state | Expected on screen |
|---|-------|-------|----------------|--------------------|
| 1 | 5 hostile bullets within 100 px of where the dash ends, 1 at 200 px | dash (tick 1) | after the dash ends: the 5 are inactive, the far one is still active | expanding ring, sparks where the bullets were |
| 2 | Chaser 80 px from the end point | dash | chaser `behavior == "stunned"` for 30 ticks (0.5 s); its position changes only by knockback; `hp` unchanged | chaser knocked back, not chasing |
| 3 | Shooter mid-aim (`aim_left > 0`) inside the radius | dash | `aim_left == 0`, no bullet fired in the next 30 ticks | telegraph line disappears |
| 4 | Warden inside the radius | dash | Warden NOT stunned; its hostile bullets inside the radius destroyed | ring, boss keeps moving |
| 5 | Shockwave **not** owned | dash next to bullets | bullets unaffected | no ring |
| 6 | Module data | — | `WeaponSpec.compose([shockwave]).shockwave_radius == 110` and order independence still holds | upgrade card shows the description |
| 7 | Determinism | `test_recorded_inputs_replay_exactly`, soak runs | unchanged | — |

## Automated

Add `tests/test_shockwave.gd` covering rows 1, 2, 3, 4 and 5, register it in
`tests/run_tests.gd`, and add `"shockwave"` to `ModuleLibrary.ALL`
(`test_every_module_resource_loads` must expect 7). The suite must report 0 failed, and
`tools/soak.gd -- 7 30000 god` must still exit 0.
