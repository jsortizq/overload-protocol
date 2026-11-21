# Acceptance criteria: bug-02

## A. Scripted scenario (must change)

```bash
godot --headless --fixed-fps 60 --path . --script res://tools/scenario.gd -- pierce_boss
```

Setup: Pierce installed, a stationary Warden (attacks disabled, very high HP) with a clear
line of fire, 6 s (360 ticks) of continuous fire aimed at it.

| Measurement | Bugged | Expected after the fix |
|-------------|--------|------------------------|
| shots | 38 | 38 |
| hits | **4** | **≥ shots − in flight − 1** (reference: 36) |
| damage dealt | 4.0 | 36.0 |
| exit code | 1 (FAIL) | 0 (PASS) |

## B. On screen

During the reproduction steps, every bullet that overlaps the Warden shows a damage number
and a white hit flash, and the boss HP bar goes down steadily. The `hits` counter in F1
tracks `shots`.

## C. Regression (must NOT change)

| Behaviour | Check |
|-----------|-------|
| One bullet damages each enemy only once | `test_pierce_hits_each_enemy_once` |
| A bullet that ricochets may hit an enemy it already pierced | covered by `p.exclude.clear()` on bounce |
| Pool capacity, drop counting, recovery | `test_pool_capacity_drops_and_recovers` |
| A dashing player still lets enemy bullets through | `test_dash_iframes_let_bullets_pass_through` |

## D. Automated

`tests/run_tests.gd` must report 0 failed. Before the fix it fails
`test_pool_slot_is_fully_reset_on_reuse` and `test_piercing_shots_keep_hitting_the_same_target`.
