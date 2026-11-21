class_name Hud
extends Control
## Top bar (HP, dash, wave, modules), center banners, upgrade cards and the
## end-of-run panel. Reads Game state every frame; never mutates gameplay
## except by queueing an upgrade choice through the LiveInput.

var game: Game
var _font: Font
var _card_rects: Array[Rect2] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if game == null or game.state != Game.State.UPGRADE:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _card_rects.size():
			if _card_rects[i].has_point(event.position) and game.input_source is InputSource.LiveInput:
				(game.input_source as InputSource.LiveInput).queued_choice = i + 1
				accept_event()


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_font, pos, s, align, width, size, col)


func _draw() -> void:
	if game == null or game.player == null:
		return
	var p := game.player
	# --- top bar
	draw_rect(Rect2(0, 0, 1280, 60), Color(0.03, 0.035, 0.05, 0.9))
	_text(Vector2(24, 38), "OVERLOAD PROTOCOL", 22, Color("4de1ff"))
	for i in Player.MAX_HP:
		var c := Color("ff4d6d") if i < p.hp else Color("2b3044")
		draw_rect(Rect2(290 + i * 22, 20, 16, 20), c)
	# dash
	var dash_frac := 1.0 - p.dash_cooldown / Player.DASH_COOLDOWN
	_text(Vector2(440, 26), "DASH", 12, Color("8a94a8"))
	draw_rect(Rect2(440, 32, 90, 8), Color("2b3044"))
	draw_rect(Rect2(440, 32, 90 * dash_frac, 8), Color("4de1ff") if dash_frac >= 1.0 else Color("2a7f99"))
	# wave
	var wave_txt := "WAVE %d/%d" % [game.director.wave_index + 1, game.director.wave_count()]
	if game.director.is_boss_wave():
		wave_txt = "BOSS"
	_text(Vector2(560, 38), wave_txt, 20, Color.WHITE)
	_text(Vector2(680, 38), "hostiles %d" % (game.enemies.size() + game.director.markers.size()), 14, Color("8a94a8"))
	# modules
	var x := 800.0
	for m in p.modules:
		draw_rect(Rect2(x, 18, 110, 24), Color(m.color, 0.18))
		draw_rect(Rect2(x, 18, 110, 24), m.color, false, 1.0)
		_text(Vector2(x, 35), m.display_name, 13, m.color, HORIZONTAL_ALIGNMENT_CENTER, 110)
		x += 118
	# --- boss bar
	for e in game.enemies:
		if e.kind == "boss":
			var w := 600.0
			draw_rect(Rect2(340, 690, w, 10), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(340, 690, w * clampf(e.hp / e.max_hp, 0, 1), 10), Color("ff8c42"))
			_text(Vector2(340, 684), "WARDEN — %s" % e.behavior, 13, Color("ff8c42"))
	# --- state panels
	_card_rects.clear()
	match game.state:
		Game.State.UPGRADE:
			_draw_upgrade_cards()
		Game.State.INTERMISSION:
			_banner("WAVE %d INCOMING" % (game.director.wave_index + 2) if game.director.wave_index + 1 < game.director.wave_count() - 1 else "WARNING: WARDEN APPROACHING", Color("ffd166"))
		Game.State.WON:
			_end_panel("PROTOCOL COMPLETE", Color("4dff9a"))
		Game.State.DEAD:
			_end_panel("SYSTEM FAILURE", Color("ff4d6d"))
		_:
			pass


func _banner(text: String, col: Color) -> void:
	draw_rect(Rect2(0, 300, 1280, 70), Color(0, 0, 0, 0.55))
	_text(Vector2(0, 347), text, 32, col, HORIZONTAL_ALIGNMENT_CENTER, 1280)


func _draw_upgrade_cards() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.45))
	_text(Vector2(0, 210), "WAVE CLEARED — INSTALL A MODULE", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1280)
	var choices := game.upgrade_choices
	for i in choices.size():
		var m := choices[i]
		var r := Rect2(640 - 300 + i * 320, 250, 280, 200) if choices.size() > 1 else Rect2(500, 250, 280, 200)
		_card_rects.append(r)
		draw_rect(r, Color(0.06, 0.07, 0.1, 0.95))
		draw_rect(r, m.color, false, 2.0)
		_text(r.position + Vector2(16, 30), "[%d]" % (i + 1), 16, Color("8a94a8"))
		_text(r.position + Vector2(0, 74), m.display_name, 26, m.color, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		_wrap(m.description, r.position + Vector2(18, 110), r.size.x - 36, 15)
	var preview := "Current: " + game.player.spec.summary()
	_text(Vector2(0, 500), preview, 14, Color("8a94a8"), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	_text(Vector2(0, 530), "Press 1 / 2 or click a card", 14, Color("8a94a8"), HORIZONTAL_ALIGNMENT_CENTER, 1280)


func _wrap(text: String, pos: Vector2, width: float, size: int) -> void:
	var line := ""
	var y := pos.y
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if _font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			_text(Vector2(pos.x, y), line, size, Color("d7deea"))
			y += size + 6
			line = word
		else:
			line = test
	_text(Vector2(pos.x, y), line, size, Color("d7deea"))


func _end_panel(title: String, col: Color) -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))
	_text(Vector2(0, 280), title, 44, col, HORIZONTAL_ALIGNMENT_CENTER, 1280)
	var s := game.stats
	var acc: float = 0.0 if s["shots"] == 0 else 100.0 * s["hits"] / s["shots"]
	var lines := [
		"Time %.1f s   ·   Kills %d   ·   Accuracy %d%%   ·   Damage taken %d" % [game.tick * Game.DT, s["kills"], roundi(acc), s["damage_taken"]],
		"Seed %d   ·   R to restart   ·   F2 save replay" % game.seed_value,
	]
	for i in lines.size():
		_text(Vector2(0, 340 + i * 30), lines[i], 16, Color("d7deea"), HORIZONTAL_ALIGNMENT_CENTER, 1280)
