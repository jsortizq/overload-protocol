# Tasks

Bug-fix and feature challenges built on Overload Protocol, written in the format used
for AI-evaluation tasks: a brief in the voice of a player, designer or producer, a
reproducible setup, a reference solution and verifiable success criteria.

| Task | Type | Systems involved | Branch with the problem |
|------|------|------------------|-------------------------|
| [bug-01](bug-01-ricochet-shots-vanish/) | Bug fix | Physics ray queries, projectile pool, weapon modules | `bug/01-ricochet-shots-vanish` |
| [bug-02](bug-02-pierce-stops-hitting-boss/) | Bug fix | Object pooling, pierce exclusion, boss fight | `bug/02-pierce-stops-hitting-boss` |
| [feature-01](feature-01-shockwave-dash/) | Feature | Modules (Resources), player dash, projectiles, enemy FSM, FX, HUD | `main` |

Each folder contains:

```
brief.md        what the solver receives (symptoms only)
acceptance.md   setup, input, expected visuals, measurable state, automated checks
solution.md     root cause + reference fix (hidden from the solver)
```

## Reproducing

The simulation runs on a fixed tick with a seeded RNG, so every check is deterministic:

```bash
git checkout <branch>
godot --headless --path . --import
godot --headless --fixed-fps 60 --path . --script res://tools/scenario.gd -- <scenario>
godot --headless --fixed-fps 60 --path . --script res://tests/run_tests.gd
# Or play it: godot --path . -- --seed=24 --modules=ricochet   (F1 shows the counters)
```

## Authoring checklist (applied to every task)

- [x] Visible on screen during normal play, not only in logs.
- [x] Reproducible from a fixed setup (seed, modules, scripted scenario).
- [x] The brief describes symptoms, never the cause.
- [x] Success is measured on game state (counters, HP, positions), not by matching code.
- [x] The reference fix passes all tests, all scenarios and a 3-seed soak run.
- [x] Played end to end on the bugged branch and on the fixed branch.
