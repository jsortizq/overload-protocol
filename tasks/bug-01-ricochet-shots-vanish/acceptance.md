# Acceptance criteria: bug-01

## A. Scripted scenario (must change)

```bash
godot --headless --fixed-fps 60 --path . --script res://tools/scenario.gd -- ricochet_wall
```

Setup: sandbox arena, Ricochet installed, 3 s (180 ticks) of continuous fire at the right wall.

| Measurement | Bugged | Expected after the fix |
|-------------|--------|------------------------|
| shots | 19 | 19 |
| wall contacts (`stats.ricochets`) | 15 | 15 |
| bullet-ticks spent flying back (vx < 0) | **0** | **≥ 10 × wall contacts** (reference: 347) |
| bullets outside the arena | 0 | 0 |
| exit code | 1 (FAIL) | 0 (PASS) |

## B. On screen

With `--modules=ricochet` and F1 open, firing at any wall produces a visible return
trail: bullets travel back toward the player at the mirrored angle. When a wall is hit
at 45°, the bullet leaves at 45°.

## C. Regression (must NOT change)

| Behaviour | Check |
|-----------|-------|
| Fast bullets never tunnel | `test_fast_projectile_never_tunnels_through_thin_wall` |
| No bullet escapes after many bounces in corners | `test_ricochet_never_escapes_the_arena` |
| Point-blank hits still work | `test_point_blank_shot_hits_enemy_overlapping_muzzle` |
| Shots fired from inside a wall are destroyed | `BLOCKED` with a zero normal → released |
| Full runs still finish | `tools/soak.gd -- 7 30000 god` exits 0 |

## D. Automated

`tests/run_tests.gd` must report 0 failed. Before the fix it fails
`test_ricochet_reflects_off_wall`.
