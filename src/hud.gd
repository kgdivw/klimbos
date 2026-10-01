class_name Hud
extends Control

# Alles wat over het bos heen ligt: de inventaris onderaan (linkermuis =
# kiezen), de knoppen rechtsboven (Express, Plan, Schets), een uitlegregel en
# korte meldingen.

signal gekozen(nr: int)
signal express_gedrukt
signal plan_gedrukt
signal schets_gedrukt
signal opslaan_gedrukt
signal openen_gedrukt

var gekozen_nr := -1
var express_aan := false
var aanraak := false     # tablet: teksten zeggen "tik" in plaats van "rechtsklik"
var _help: Label
var _vakjes: Array[Vakje] = []
var _hint: Label
var _hint_paneel: PanelContainer
var _melding: Label
var _melding_tijd := 0.0
var _vraag: Label
var _express: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- Inventaris
	var balk := PanelContainer.new()
	balk.add_theme_stylebox_override("panel", Schets.stijl(Color(0.98, 0.93, 0.8, 0.92), Color(0.75, 0.55, 0.35), 20, 3))
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 6)
	balk.add_child(rij)
	for i in Bouw.SOORTEN.size():
		var v := Vakje.new()
		v.nr = i
		v.soort = Bouw.SOORTEN[i]
		v.naam = Bouw.NAMEN[i]
		v.custom_minimum_size = Vector2(82, 86)
		v.focus_mode = Control.FOCUS_NONE
		v.pressed.connect(func(): kies(i if gekozen_nr != i else -1))
		rij.add_child(v)
		_vakjes.append(v)
	add_child(balk)
	var maat := balk.get_combined_minimum_size()
	Schets.zet(balk, Control.PRESET_CENTER_BOTTOM, Vector2(-maat.x * 0.5, -maat.y - 14), maat)

	# --- Uitleg boven de balk
	_hint_paneel = PanelContainer.new()
	_hint_paneel.add_theme_stylebox_override("panel", Schets.stijl(Color(0.25, 0.18, 0.1, 0.72), Color(0, 0, 0, 0), 14, 0))
	_hint_paneel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_paneel.add_child(_hint)
	add_child(_hint_paneel)

	# --- Vraag in het midden (E: tokkelen)
	_vraag = Label.new()
	_vraag.add_theme_font_size_override("font_size", 26)
	_vraag.add_theme_color_override("font_color", Color(1, 1, 1))
	_vraag.add_theme_color_override("font_outline_color", Color(0.35, 0.2, 0.05))
	_vraag.add_theme_constant_override("outline_size", 8)
	_vraag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Schets.zet(_vraag, Control.PRESET_CENTER, Vector2(-300, 60), Vector2(600, 40))
	add_child(_vraag)

	# --- Meldingen bovenin
	_melding = Label.new()
	_melding.add_theme_font_size_override("font_size", 34)
	_melding.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	_melding.add_theme_color_override("font_outline_color", Color(0.45, 0.25, 0.05))
	_melding.add_theme_constant_override("outline_size", 10)
	_melding.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Schets.zet(_melding, Control.PRESET_CENTER_TOP, Vector2(-400, 70), Vector2(800, 50))
	add_child(_melding)

	# --- Knoppen rechtsboven
	var knoppen := VBoxContainer.new()
	knoppen.add_theme_constant_override("separation", 10)
	Schets.zet(knoppen, Control.PRESET_TOP_RIGHT, Vector2(-190, 16), Vector2(174, 310))
	add_child(knoppen)
	_express = _knop(knoppen, "Express", Color(1.0, 0.78, 0.2))
	_express.pressed.connect(func(): express_gedrukt.emit())
	_express.icon = _bliksem()
	var plan := _knop(knoppen, "Plan  [Tab]", Color(0.55, 0.75, 1.0))
	plan.pressed.connect(func(): plan_gedrukt.emit())
	var schets := _knop(knoppen, "Schets", Color(0.98, 0.95, 0.85))
	schets.pressed.connect(func(): schets_gedrukt.emit())
	var opslaan := _knop(knoppen, "Opslaan", Color(0.7, 0.9, 0.65))
	opslaan.pressed.connect(func(): opslaan_gedrukt.emit())
	var openen := _knop(knoppen, "Openen", Color(0.98, 0.95, 0.85))
	openen.pressed.connect(func(): openen_gedrukt.emit())

	# --- Besturing linksboven
	var help := Label.new()
	_help = help
	help.text = HELP_PC
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	help.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.05, 0.8))
	help.add_theme_constant_override("outline_size", 5)
	help.position = Vector2(16, 12)
	add_child(help)

	kies(-1)


const HELP_PC := "WASD / pijltjes: lopen    Spatie: springen\nLinkermuis slepen: rondkijken    Wiel: zoomen\nTegen touw/net/haken lopen: klimmen\nE: tokkelen of naar beneden klimmen"
const HELP_TABLET := "Joystick: lopen    Spring-knop: springen\nVeeg met je vinger: rondkijken    Knijp met twee vingers: zoomen\nTegen touw/net/haken lopen: klimmen\nE-knop: tokkelen of naar beneden klimmen"


func zet_aanraak(aan: bool) -> void:
	aanraak = aan
	_help.text = HELP_TABLET if aan else HELP_PC
	zet_hint(_hint.text)


# Teksten die over muis en toetsen gaan, omzetten voor een tablet.
func vertaal(t: String) -> String:
	if not aanraak:
		return t
	var paren := [
		["Kies iets uit je inventaris met de linkermuis (of 1-9), en zet het met de rechtermuis in de bomen.", "Tik op iets uit je inventaris, en tik dan in de bomen om het te plaatsen."],
		["W = omhoog   S = omlaag   Spatie = loslaten", "Joystick omhoog = klimmen, omlaag = zakken, Spring = loslaten"],
		["Druk op E", "Tik op E"],
		["Spatie = eraf springen", "Spring-knop = eraf springen"],
		["Klik met rechts op", "Tik op"],
		["Klik op", "Tik op"],
		["Rechtsklik", "Tik"],
		["rechtsklik", "tik"],
		["(Esc = opnieuw)", "(kies het ding opnieuw om opnieuw te beginnen)"],
		["(Esc = stoppen)", "(tik op Express om te stoppen)"],
	]
	for p in paren:
		t = t.replace(p[0], p[1])
	return t


func _knop(ouder: Control, tekst: String, kleur: Color) -> Button:
	var k := Button.new()
	k.text = tekst
	k.focus_mode = Control.FOCUS_NONE
	k.custom_minimum_size = Vector2(174, 52)
	k.add_theme_font_size_override("font_size", 22)
	k.add_theme_color_override("font_color", Color(0.3, 0.2, 0.1))
	k.add_theme_color_override("font_hover_color", Color(0.3, 0.2, 0.1))
	k.add_theme_color_override("font_pressed_color", Color(0.3, 0.2, 0.1))
	Schets.knop_stijlen(k, kleur, Color(1, 1, 1), 3)
	ouder.add_child(k)
	return k


func _bliksem() -> Texture2D:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	var punten := PackedVector2Array([Vector2(16, 1), Vector2(5, 16), Vector2(13, 16), Vector2(10, 27), Vector2(23, 10), Vector2(15, 10), Vector2(19, 1)])
	for y in 28:
		for x in 28:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), punten):
				img.set_pixel(x, y, Color(0.85, 0.35, 0.05))
	return ImageTexture.create_from_image(img)


func kies(nr: int) -> void:
	gekozen_nr = nr
	for v in _vakjes:
		v.aan = v.nr == nr
		v.queue_redraw()
	gekozen.emit(nr)


func zet_express(aan: bool) -> void:
	express_aan = aan
	Schets.knop_stijlen(_express, Color(1.0, 0.55, 0.15) if aan else Color(1.0, 0.78, 0.2), Color(1, 1, 1) if not aan else Color(1, 0.95, 0.5), 5 if aan else 3)


func zet_hint(tekst: String) -> void:
	_hint.text = vertaal(tekst)
	_hint_paneel.visible = tekst != ""
	var maat := _hint_paneel.get_combined_minimum_size()
	Schets.zet(_hint_paneel, Control.PRESET_CENTER_BOTTOM, Vector2(-maat.x * 0.5, -maat.y - 132), maat)


func zet_vraag(tekst: String) -> void:
	_vraag.text = vertaal(tekst)


func meld(tekst: String) -> void:
	_melding.text = vertaal(tekst)
	_melding_tijd = 2.2
	_melding.modulate.a = 1.0


func _process(delta: float) -> void:
	if _melding_tijd > 0.0:
		_melding_tijd -= delta
		_melding.modulate.a = clampf(_melding_tijd / 0.6, 0.0, 1.0)


# Een vakje in de inventaris met een zelf getekend plaatje.
class Vakje extends Button:
	var nr := 0
	var soort := ""
	var naam := ""
	var aan := false

	func _ready() -> void:
		flat = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var s := size
		var achter := Color(1.0, 0.86, 0.45) if aan else Color(1, 1, 1, 0.7)
		var rand := Color(0.95, 0.5, 0.15) if aan else Color(0.8, 0.68, 0.5)
		var box := Schets.stijl(achter, rand, 14, 4 if aan else 2)
		box.shadow_size = 0
		draw_style_box(box, Rect2(Vector2.ZERO, s))
		var font := get_theme_default_font()
		draw_string(font, Vector2(7, 18), str(nr + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.38, 0.25))
		draw_string(font, Vector2(0, s.y - 8), naam, HORIZONTAL_ALIGNMENT_CENTER, s.x, 14, Color(0.35, 0.24, 0.14))
		var m := Vector2(s.x * 0.5, 36)
		_icoon(m)

	func _icoon(m: Vector2) -> void:
		var hout := Color(0.85, 0.6, 0.35)
		var donker := Color(0.55, 0.35, 0.2)
		var touw := Color(0.85, 0.72, 0.45)
		var rood := Color(0.92, 0.3, 0.28)
		match soort:
			"plank":
				draw_set_transform(m, -0.35, Vector2.ONE)
				draw_rect(Rect2(-26, -6, 52, 12), hout)
				draw_rect(Rect2(-26, -6, 52, 12), donker, false, 2.0)
				draw_circle(Vector2(-20, 0), 2, donker)
				draw_circle(Vector2(20, 0), 2, donker)
				draw_set_transform(Vector2.ZERO)
			"platform":
				draw_rect(Rect2(m.x - 5, m.y - 22, 10, 40), donker)
				_ellips(m + Vector2(0, 2), Vector2(28, 9), hout)
				_ellips(m + Vector2(0, 2), Vector2(28, 9), donker, false)
				draw_rect(Rect2(m.x - 5, m.y - 22, 10, 18), donker)
			"brug", "touwbrug":
				var n := 7 if soort == "brug" else 5
				for i in n:
					var t := (i + 0.5) / n
					var x := lerpf(-28, 28, t)
					var y := 8.0 * 4.0 * t * (1.0 - t) * (1.6 if soort == "touwbrug" else 1.0)
					draw_rect(Rect2(m.x + x - 3, m.y + y - 2, 6, 7), hout)
				var vorige := Vector2.ZERO
				for i in 11:
					var t := i / 10.0
					var p := m + Vector2(lerpf(-30, 30, t), -12 + 6.0 * 4.0 * t * (1.0 - t))
					if i > 0:
						draw_line(vorige, p, touw, 2.5, true)
					vorige = p
				draw_line(m + Vector2(-30, -14), m + Vector2(-30, 6), donker, 4)
				draw_line(m + Vector2(30, -14), m + Vector2(30, 6), donker, 4)
			"klimtouw":
				draw_rect(Rect2(m.x - 10, m.y - 24, 20, 6), rood)
				draw_line(m + Vector2(0, -20), m + Vector2(0, 24), touw, 4, true)
				for i in 4:
					draw_circle(m + Vector2(0, -12 + i * 11), 4.5, Color(0.78, 0.62, 0.38))
			"klimhaken":
				draw_rect(Rect2(m.x - 9, m.y - 25, 18, 50), donker)
				var kleuren := [Color(1, 0.45, 0.6), Color(1, 0.82, 0.25), Color(0.35, 0.7, 1), Color(0.45, 0.85, 0.4)]
				for i in 4:
					draw_circle(m + Vector2(-5 + (i % 2) * 10, 18 - i * 12), 5.5, kleuren[i])
			"klimnet":
				draw_line(m + Vector2(-26, -22), m + Vector2(26, -22), donker, 5)
				for i in 6:
					var x := -22 + i * 9
					draw_line(m + Vector2(x, -20), m + Vector2(x, 24), touw, 2)
				for j in 5:
					var y := -14 + j * 9
					draw_line(m + Vector2(-22, y), m + Vector2(23, y), touw, 2)
			"tokkelbaan":
				draw_line(m + Vector2(-30, -22), m + Vector2(30, 4), Color(0.45, 0.48, 0.55), 3, true)
				var k := m + Vector2(-4, -10)
				draw_circle(k, 4, rood)
				draw_line(k, k + Vector2(0, 22), touw, 2)
				_ellips(k + Vector2(0, 23), Vector2(9, 3.5), rood)
			"sloop":
				draw_set_transform(m, 0.5, Vector2.ONE)
				draw_rect(Rect2(-3, -6, 6, 32), donker)
				draw_rect(Rect2(-14, -20, 28, 13), Color(0.55, 0.58, 0.65))
				draw_set_transform(Vector2.ZERO)

	func _ellips(m: Vector2, r: Vector2, k: Color, vol := true) -> void:
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(m + Vector2(cos(a) * r.x, sin(a) * r.y))
		if vol:
			draw_colored_polygon(pts, k)
		else:
			draw_polyline(pts, k, 2.0, true)
