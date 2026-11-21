# Bug report: the Ricochet module does nothing

**Reported by:** playtester (itch.io comments)
**Build:** branch `bug/01-ricochet-shots-vanish`
**Severity:** high (an upgrade players pay a wave for has no effect)

> "Picked Ricochet after wave 1 because the card says shots bounce twice. They don't.
> Every bullet just pops on the wall, same as before. Sometimes I THINK I see a tiny
> spark, but nothing ever comes back. Ricochet + Pierce was supposed to be my build :("

## Steps to reproduce

1. Run `godot --path . -- --seed=24 --modules=ricochet` (or take Ricochet from the
   first set of cards on seed 24; it's card 1).
2. Open the debug overlay with **F1**.
3. Hold fire toward the right-hand wall.

## Expected

Bullets hit the wall, reflect, and keep flying until their 2 bounces or their lifetime run
out. In the overlay, the `ricochets` counter goes up and reflected bullets are visible
flying back.

## Actual

Bullets disappear on the wall. A small spark appears and the `ricochets` counter does go
up, but no bullet ever travels away from the wall.

## Constraints

- Shots fired from inside a wall (the player hugging a wall) must still be destroyed
  instead of bouncing around inside it.
- Bullets must never escape the arena.
