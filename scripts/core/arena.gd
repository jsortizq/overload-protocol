class_name Arena
extends Node2D
## Builds the static level geometry (outer walls + cover pillars) as
## StaticBody2D nodes on the "world" physics layer and draws it.

const BOUNDS := Rect2(80, 96, 1120, 584)
const WALL := 24.0
const PILLARS: Array[Rect2] = [
	Rect2(330, 250, 56, 56),
	Rect2(894, 250, 56, 56),
	Rect2(330, 470, 56, 56),
	Rect2(894, 470, 56, 56),
	Rect2(610, 372, 60, 28),
]

var _rects: Array[Rect2] = []


func _ready() -> void:
	var b := BOUNDS
	_add(Rect2(b.position.x - WALL, b.position.y - WALL, b.size.x + WALL * 2, WALL)) # top
	_add(Rect2(b.position.x - WALL, b.end.y, b.size.x + WALL * 2, WALL))              # bottom
	_add(Rect2(b.position.x - WALL, b.position.y, WALL, b.size.y))                    # left
	_add(Rect2(b.end.x, b.position.y, WALL, b.size.y))                                # right
	for p in PILLARS:
		_add(p)


func _add(r: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	body.position = r.get_center()
	body.add_child(shape)
	add_child(body)
	_rects.append(r)


## Spawn positions on a ring just inside the walls, away from cover.
static func spawn_points() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var b := BOUNDS.grow(-40)
	for i in 6:
		var t := (i + 0.5) / 6.0
		pts.append(Vector2(b.position.x + b.size.x * t, b.position.y))
		pts.append(Vector2(b.position.x + b.size.x * t, b.end.y))
	for i in 3:
		var t := (i + 0.5) / 3.0
		pts.append(Vector2(b.position.x, b.position.y + b.size.y * t))
		pts.append(Vector2(b.end.x, b.position.y + b.size.y * t))
	return pts


func _draw() -> void:
	draw_rect(BOUNDS, Color("12141d"))
	var step := 40.0
	var x := BOUNDS.position.x
	while x < BOUNDS.end.x:
		draw_line(Vector2(x, BOUNDS.position.y), Vector2(x, BOUNDS.end.y), Color("171a25"), 1.0)
		x += step
	var y := BOUNDS.position.y
	while y < BOUNDS.end.y:
		draw_line(Vector2(BOUNDS.position.x, y), Vector2(BOUNDS.end.x, y), Color("171a25"), 1.0)
		y += step
	for r in _rects:
		draw_rect(r, Color("2b3044"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color("3d4460"))
		draw_rect(r, Color("4de1ff", 0.18), false, 1.0)
