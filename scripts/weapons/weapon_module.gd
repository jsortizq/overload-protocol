class_name WeaponModule
extends Resource
## Data-only weapon upgrade (Godot's equivalent of a Unity ScriptableObject).
## Modules never contain logic: WeaponSpec.compose() folds any combination of
## them into one ProjectileSpec, so adding a module is a new .tres file, not
## a new branch in the weapon code.

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var color := Color.WHITE

@export_group("Additive")
@export var extra_projectiles := 0
@export var spread_deg := 0.0
@export var add_bounces := 0
@export var add_pierce := 0
@export var add_chain := 0

@export_group("Multipliers")
@export var damage_mult := 1.0
@export var fire_rate_mult := 1.0  ## > 1 fires faster
@export var speed_mult := 1.0
@export var knockback_mult := 1.0
