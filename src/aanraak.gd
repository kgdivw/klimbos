class_name Aanraak
extends Control

# Bediening voor tablets: een joystick linksonder om te lopen (en te klimmen)
# en twee knoppen rechtsonder: Spring en E. Alles werkt met meerdere vingers
# tegelijk: je kunt lopen met de joystick en ondertussen springen.
#
# Rondkijken (één vinger vegen), zoomen (twee vingers knijpen) en tikken om iets
# te plaatsen gebeurt in main.gd, met de vingers die niet op deze knoppen zitten.

var joystick: Joystick


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick = Joystick.new()
	add_child(joystick)
	Schets.zet(joystick, Control.PRESET_BOTTOM_LEFT, Vector2(30, -350), Vector2(230, 230))
	var spring := TikKnop.new("springen", "Spring", Color(0.45, 0.8, 1.0), 62.0)
	add_child(spring)
	Schets.zet(spring, Control.PRESET_BOTTOM_RIGHT, Vector2(-170, -300), Vector2(140, 140))
	var doe := TikKnop.new("doe", "E", Color(1.0, 0.8, 0.3), 46.0)
	add_child(doe)
	Schets.zet(doe, Control.PRESET_BOTTOM_RIGHT, Vector2(-290, -230), Vector2(110, 110))


# Laat alle acties los (bijvoorbeeld als de knoppen verdwijnen).
func los() -> void:
	joystick.los()
	for k in get_children():
		if k is TikKnop:
			k.los()


class Joystick extends Control:
	const STRAAL := 90.0
	var vinger := -1
	var knop := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP   # de nagebootste muisklik hier niet doorgeven

	func _midden() -> Vector2:
		return get_global_rect().get_center()

	func _input(e: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		if e is InputEventScreenTouch:
			if e.pressed and vinger < 0 and get_global_rect().grow(30).has_point(e.position):
				vinger = e.index
				_zet(e.position)
				get_viewport().set_input_as_handled()
			elif not e.pressed and e.index == vinger:
				los()
				get_viewport().set_input_as_handled()
		elif e is InputEventScreenDrag and e.index == vinger:
			_zet(e.position)
			get_viewport().set_input_as_handled()

	func _zet(p: Vector2) -> void:
		knop = (p - _midden()).limit_length(STRAAL)
		_stuur()
		queue_redraw()

	func los() -> void:
		vinger = -1
		knop = Vector2.ZERO
		_stuur()
		queue_redraw()

	func _stuur() -> void:
		var v := knop / STRAAL
		_actie("rechts", maxf(v.x, 0.0))
		_actie("links", maxf(-v.x, 0.0))
		_actie("achter", maxf(v.y, 0.0))
		_actie("voor", maxf(-v.y, 0.0))

	func _actie(naam: String, sterkte: float) -> void:
		if sterkte > 0.15:
			Input.action_press(naam, sterkte)
		else:
			Input.action_release(naam)

	func _draw() -> void:
		var m := size * 0.5
		draw_circle(m, STRAAL + 12.0, Color(1, 1, 1, 0.18), true, -1.0, true)
		draw_circle(m, STRAAL + 12.0, Color(1, 1, 1, 0.55), false, 4.0, true)
		for i in 4:
			var r := Vector2.from_angle(i * PI * 0.5) * (STRAAL - 8.0)
			var z := Vector2(-r.y, r.x).normalized() * 9.0
			draw_colored_polygon(PackedVector2Array([m + r * 1.05, m + r * 0.85 + z, m + r * 0.85 - z]), Color(1, 1, 1, 0.6))
		draw_circle(m + knop, 42.0, Color(1.0, 0.95, 0.85, 0.85 if vinger >= 0 else 0.6), true, -1.0, true)
		draw_circle(m + knop, 42.0, Color(0.6, 0.42, 0.25, 0.8), false, 4.0, true)


class TikKnop extends Control:
	var actie := ""
	var tekst := ""
	var kleur := Color.WHITE
	var straal := 50.0
	var vinger := -1

	func _init(a: String, t: String, k: Color, r: float) -> void:
		actie = a
		tekst = t
		kleur = k
		straal = r

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _input(e: InputEvent) -> void:
		if not is_visible_in_tree():
			return
		if e is InputEventScreenTouch:
			var binnen: bool = (e.position - get_global_rect().get_center()).length() < straal + 14.0
			if e.pressed and vinger < 0 and binnen:
				vinger = e.index
				Input.action_press(actie)
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif not e.pressed and e.index == vinger:
				los()
				get_viewport().set_input_as_handled()
		elif e is InputEventScreenDrag and e.index == vinger:
			get_viewport().set_input_as_handled()

	func los() -> void:
		if vinger >= 0:
			Input.action_release(actie)
		vinger = -1
		queue_redraw()

	func _draw() -> void:
		var m := size * 0.5
		var k := kleur.darkened(0.15) if vinger >= 0 else kleur
		draw_circle(m + Vector2(0, 4), straal, Color(0, 0, 0, 0.2), true, -1.0, true)
		draw_circle(m, straal, Color(k.r, k.g, k.b, 0.88), true, -1.0, true)
		draw_circle(m, straal, Color(1, 1, 1, 0.9), false, 4.0, true)
		var font := get_theme_default_font()
		var grootte := 26 if tekst.length() > 2 else 40
		var maat := font.get_string_size(tekst, HORIZONTAL_ALIGNMENT_CENTER, -1, grootte)
		draw_string(font, m + Vector2(-maat.x * 0.5, maat.y * 0.3), tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, grootte, Color(0.3, 0.2, 0.1))
