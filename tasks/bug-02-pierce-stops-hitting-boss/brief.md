# Bug report: Pierce shots stop hitting the Warden after a few seconds

**Reported by:** QA (boss balance pass)
**Build:** branch `bug/02-pierce-stops-hitting-boss`
**Severity:** critical (the boss becomes nearly unkillable with one specific module)

> "With Pierce installed, the Warden fight takes forever. The first few shots show
> damage numbers, then most of my bullets fly straight through the boss with no
> number and no hit flash. They're visibly overlapping its body. Without Pierce
> everything is fine. Accuracy on the end screen drops to ~10%. I also saw it
> once on a Shield Bearer's back."

## Steps to reproduce

1. Run `godot --path . -- --modules=pierce`.
2. Open the debug overlay with **F1**, then press **F5** to jump to the boss.
3. Hold fire at the Warden for ~5 seconds. You can turn on god mode with **F3**.

## Expected

Every bullet that touches the boss damages it once, then carries on (pierce). The
overlay's `hits` counter keeps up with `shots`.

## Actual

After the first handful of shots, `hits` stops increasing even though bullets visibly
pass through the boss.

## Constraints

- A pierced enemy must still be hit only **once** by the same bullet.
- No allocations per shot: keep the pool.
