# Reference solution: bug-01

## Root cause

Projectiles use swept rays (`PhysicsDirectSpaceState2D.intersect_ray`). After a bounce,
the next ray starts **exactly at the contact point**, on the surface of the wall.

The query is created with `hit_from_inside = true`. That's needed so point-blank shots
hit an enemy whose body already contains the ray origin. With that flag, a ray whose
origin lies on or inside a shape reports a hit **at the origin with a zero normal**.

So on the next substep:

1. The ray reports the same wall again, at distance 0, with `normal == Vector2.ZERO`.
2. `ProjectileSystem._advance` reads a zero normal as "this bullet started inside a wall"
   (the legitimate case of a player hugging a wall) and releases it.

On this branch the line that steps the bullet off the surface was removed in a
"cleanup" commit (it looked like a magic number):

```diff
 			Hit.BLOCKED:
 				var inside: bool = hit["normal"] == Vector2.ZERO
 				if p.bounces > 0 and not inside:
 					p.bounces -= 1
 					dir = dir.bounce(hit["normal"]).normalized()
 					p.vel = dir * speed
+					# Step off the surface, otherwise the next ray starts inside
+					# the wall and reports the same contact again.
+					p.pos += hit["normal"] * 0.5
 					p.exclude.clear()
```

## Why this fix

- 0.5 px along the normal is far below any wall thickness (24 px walls, 28 px pillars), so it
  can't push a bullet through geometry. It's enough to move the ray origin out of the
  shape so the next ray starts in free space.
- It keeps `hit_from_inside = true`, so point-blank shots still work.
- It doesn't change what happens to bullets that really were fired from inside a wall.

## Alternatives considered

| Alternative | Problem |
|-------------|---------|
| Set `hit_from_inside = false` | Ricochet works again, but point-blank shots pass through enemies hugging the player (`test_point_blank_shot_hits...` fails), and a bullet whose origin is inside a wall can fly *out through it*. |
| Add the wall's RID to `exclude` after a bounce | A bullet bouncing in a corner needs to hit the same wall twice, and the excluded wall would let it escape the arena (`test_ricochet_never_escapes_the_arena`). |
| Ignore hits with distance 0 | Same escape problem when the ray really starts inside geometry. |

## Verification done

- `scenario ricochet_wall`: 347 bullet-ticks flying back, 0 escaped → PASS.
- Test suite: 39 / 39. Soak with seeds 7, 8, 9: all reach victory.
