class_name Schets
extends Control

# Het schetspapier. Het vult het hele scherm; links boven zit een vierkantje
# met je kleur (klik erop voor meer kleuren), daarnaast drie potloden (dun,
# gewoon, dik), een gum en "alles weg". Rechts onder: Klaar!
#
# Op het papier staat heel licht een kaartje van het bos (elke boom een
# rondje), zodat je kruisjes, nummers en lijnen precies tussen de bomen kunt
# zetten. De tekening wordt in een SubViewport getekend; dezelfde afbeelding
# hangt later in de lucht boven het bos en kan de Express-knop lezen.

signal klaar
signal opslaan_gedrukt
signal openen_gedrukt

const BREED := 1600
const HOOG := 900
const KLEUREN := [
	["zwart", Color(0.15, 0.13, 0.13)],
	["bruin", Color(0.55, 0.33, 0.18)],
	["rood", Color(0.9, 0.18, 0.18)],
	["oranje", Color(1.0, 0.55, 0.1)],
	["geel", Color(1.0, 0.82, 0.1)],
	["lichtgroen", Color(0.55, 0.85, 0.25)],
	["groen", Color(0.12, 0.6, 0.25)],
	["blauw", Color(0.15, 0.45, 0.95)],
	["paars", Color(0.6, 0.3, 0.85)],
	["roze", Color(1.0, 0.45, 0.7)],
]
const DIKTES := [4.0, 9.0, 18.0]
const PAPIER := Color(0.99, 0.96, 0.88)

var bos: Bos
# Elke lijn: {"k": kleurnummer, "d": dikte, "p": PackedVector2Array in papierpixels}
var lijnen: Array = []
var kleur := 0
var dikte := 1
var gum := false
var bekijken := false
var speler_pos := Vector3.ZERO
var speler_kijk := 0.0

var viewport: SubViewport
var _tekenaar: Tekenaar
var _bezig := -1
var _werkbalk: Control
var _kleurknop: Button
var _palet: PanelContainer
var _penknoppen: Array[Button] = []
var _gumknop: Button
var _wisknop: Button
var _wis_zeker := false
var _titel: Label
var _uitleg: Label
var _klaarknop: Button
var _kaart_tekst: Label


class Tekenaar extends Node2D:
	var schets: Schets

	func _draw() -> void:
		for l in schets.lijnen:
			var k: Color = Schets.KLEUREN[l["k"]][1]
			var d: float = l["d"]
			var p: PackedVector2Array = l["p"]
			# Eerst een lichte rand, zodat de lijn ook op de donkere bosgrond
			# goed te zien is (op het papier valt die rand bijna weg).
			_lijn(p, Color(1.0, 0.97, 0.85, 0.85), d + 7.0)
			_lijn(p, k, d)

	func _lijn(p: PackedVector2Array, k: Color, d: float) -> void:
		if p.size() > 1:
			draw_polyline(p, k, d, true)
		for q in p:
			draw_circle(q, d * 0.5, k, true, -1.0, true)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	viewport = SubViewport.new()
	viewport.size = Vector2i(BREED, HOOG)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	_tekenaar = Tekenaar.new()
	_tekenaar.schets = self
	viewport.add_child(_tekenaar)

	_maak_werkbalk()
	resized.connect(queue_redraw)


func textuur() -> Texture2D:
	return viewport.get_texture()


func toon_tekenen() -> void:
	bekijken = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_werkbalk.visible = true
	_kaart_tekst.visible = false
	visible = true
	queue_redraw()


func toon_bekijken() -> void:
	bekijken = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_werkbalk.visible = false
	_kaart_tekst.visible = true
	_palet.visible = false
	visible = true
	queue_redraw()


# ------------------------------------------------------------------ werkbalk

static func stijl(kleur: Color, rand := Color(1, 1, 1, 0.0), rond := 14, randdikte := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = kleur
	s.set_corner_radius_all(rond)
	s.border_color = rand
	s.set_border_width_all(randdikte)
	s.shadow_color = Color(0, 0, 0, 0.18)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


# Zet een control vast aan een hoek of rand van het scherm: `pos` is de
# linkerbovenhoek ten opzichte van dat ankerpunt.
static func zet(c: Control, preset: int, pos: Vector2, maat: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + maat.x
	c.offset_bottom = pos.y + maat.y


static func knop_stijlen(knop: Button, kleur: Color, rand := Color(1, 1, 1, 0), randdikte := 0) -> void:
	knop.add_theme_stylebox_override("normal", stijl(kleur, rand, 14, randdikte))
	knop.add_theme_stylebox_override("hover", stijl(kleur.lightened(0.12), rand, 14, randdikte))
	knop.add_theme_stylebox_override("pressed", stijl(kleur.darkened(0.12), rand, 14, randdikte))
	knop.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _maak_werkbalk() -> void:
	_werkbalk = Control.new()
	_werkbalk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_werkbalk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_werkbalk)

	# Het vierkantje in de hoek met je kleur.
	_kleurknop = Button.new()
	_kleurknop.position = Vector2(24, 24)
	_kleurknop.custom_minimum_size = Vector2(70, 70)
	_kleurknop.size = Vector2(70, 70)
	_kleurknop.tooltip_text = "Kies een kleur"
	_kleurknop.pressed.connect(func(): _palet.visible = not _palet.visible)
	_werkbalk.add_child(_kleurknop)

	_palet = PanelContainer.new()
	_palet.position = Vector2(24, 104)
	_palet.add_theme_stylebox_override("panel", stijl(Color(1, 1, 1, 0.97), Color(0.85, 0.75, 0.6), 18, 3))
	_palet.visible = false
	var raster := GridContainer.new()
	raster.columns = 5
	raster.add_theme_constant_override("h_separation", 8)
	raster.add_theme_constant_override("v_separation", 8)
	_palet.add_child(raster)
	for i in KLEUREN.size():
		var kk := Button.new()
		kk.custom_minimum_size = Vector2(54, 54)
		knop_stijlen(kk, KLEUREN[i][1], Color(1, 1, 1), 3)
		kk.tooltip_text = KLEUREN[i][0]
		var nr := i
		kk.pressed.connect(func():
			kleur = nr
			gum = false
			_palet.visible = false
			_werk_knoppen_bij())
		raster.add_child(kk)
	_werkbalk.add_child(_palet)

	# Drie potloden: dun, gewoon, dik.
	var namen := ["dun", "gewoon", "dik"]
	for i in 3:
		var pk := PenKnop.new()
		pk.schets = self
		pk.nr = i
		pk.position = Vector2(110 + i * 92, 24)
		pk.custom_minimum_size = Vector2(84, 70)
		pk.size = Vector2(84, 70)
		pk.text = namen[i]
		pk.vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM
		pk.alignment = HORIZONTAL_ALIGNMENT_CENTER
		pk.add_theme_font_size_override("font_size", 15)
		var nr := i
		pk.pressed.connect(func():
			dikte = nr
			gum = false
			_werk_knoppen_bij())
		_werkbalk.add_child(pk)
		_penknoppen.append(pk)

	_gumknop = Button.new()
	_gumknop.text = "gum"
	_gumknop.position = Vector2(110 + 3 * 92 + 12, 24)
	_gumknop.custom_minimum_size = Vector2(84, 70)
	_gumknop.size = Vector2(84, 70)
	_gumknop.pressed.connect(func():
		gum = not gum
		_werk_knoppen_bij())
	_werkbalk.add_child(_gumknop)

	_wisknop = Button.new()
	_wisknop.text = "alles weg"
	_wisknop.position = Vector2(110 + 4 * 92 + 12, 24)
	_wisknop.custom_minimum_size = Vector2(110, 70)
	_wisknop.size = Vector2(110, 70)
	_wisknop.pressed.connect(_wis_alles)
	_werkbalk.add_child(_wisknop)

	_titel = Label.new()
	_titel.text = "Teken je plan voor het klimparcours!"
	_titel.add_theme_font_size_override("font_size", 30)
	_titel.add_theme_color_override("font_color", Color(0.45, 0.3, 0.18))
	_titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zet(_titel, Control.PRESET_TOP_RIGHT, Vector2(-640, 34), Vector2(610, 50))
	_werkbalk.add_child(_titel)

	_uitleg = Label.new()
	_uitleg.text = "Elk groen rondje is een boom. Zet kruisjes en nummers en trek lijnen van boom naar boom.\nMet Express bouwt het spel je lijn later vanzelf: blauw = tokkelbaan, rood/oranje/roze = touwbrug, andere kleuren = brug."
	_uitleg.add_theme_font_size_override("font_size", 16)
	_uitleg.add_theme_color_override("font_color", Color(0.45, 0.33, 0.22))
	zet(_uitleg, Control.PRESET_BOTTOM_LEFT, Vector2(26, -72), Vector2(900, 50))
	_werkbalk.add_child(_uitleg)

	_klaarknop = Button.new()
	_klaarknop.text = "  Klaar!  "
	_klaarknop.add_theme_font_size_override("font_size", 36)
	_klaarknop.add_theme_color_override("font_color", Color(1, 1, 1))
	_klaarknop.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	knop_stijlen(_klaarknop, Color(0.32, 0.72, 0.3), Color(1, 1, 1), 4)
	zet(_klaarknop, Control.PRESET_BOTTOM_RIGHT, Vector2(-230, -112), Vector2(200, 84))
	_klaarknop.pressed.connect(func(): klaar.emit())
	_werkbalk.add_child(_klaarknop)

	var opslaan := Button.new()
	opslaan.text = "Opslaan"
	var openen := Button.new()
	openen.text = "Openen"
	for k: Button in [opslaan, openen]:
		k.focus_mode = Control.FOCUS_NONE
		k.add_theme_font_size_override("font_size", 20)
		k.add_theme_color_override("font_color", Color(0.4, 0.28, 0.16))
		k.add_theme_color_override("font_hover_color", Color(0.4, 0.28, 0.16))
		knop_stijlen(k, Color(1, 1, 1, 0.95), Color(0.85, 0.72, 0.52), 3)
		_werkbalk.add_child(k)
	zet(opslaan, Control.PRESET_TOP_RIGHT, Vector2(-380, 92), Vector2(165, 52))
	zet(openen, Control.PRESET_TOP_RIGHT, Vector2(-200, 92), Vector2(165, 52))
	opslaan.pressed.connect(func(): opslaan_gedrukt.emit())
	openen.pressed.connect(func(): openen_gedrukt.emit())

	_kaart_tekst = Label.new()
	_kaart_tekst.text = "Jouw plan   (Tab = sluiten)"
	_kaart_tekst.add_theme_font_size_override("font_size", 22)
	_kaart_tekst.add_theme_color_override("font_color", Color(1, 1, 1))
	_kaart_tekst.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.1))
	_kaart_tekst.add_theme_constant_override("outline_size", 6)
	_kaart_tekst.position = Vector2(70, 18)
	_kaart_tekst.visible = false
	add_child(_kaart_tekst)

	_werk_knoppen_bij()
	resized.connect(_titel_plaats)
	_titel_plaats()


# Op een smal (staand) scherm past de titel niet naast de potloden: dan eronder.
func _titel_plaats() -> void:
	if size.x < 1150:
		zet(_titel, Control.PRESET_TOP_RIGHT, Vector2(-640, 154), Vector2(610, 50))
	else:
		zet(_titel, Control.PRESET_TOP_RIGHT, Vector2(-640, 34), Vector2(610, 50))


func _werk_knoppen_bij() -> void:
	knop_stijlen(_kleurknop, KLEUREN[kleur][1], Color(1, 1, 1), 5)
	for i in 3:
		var aan := i == dikte and not gum
		knop_stijlen(_penknoppen[i], Color(1.0, 0.93, 0.7) if aan else Color(1, 1, 1, 0.92), Color(0.95, 0.6, 0.2) if aan else Color(0.85, 0.78, 0.65), 4 if aan else 2)
		_penknoppen[i].add_theme_color_override("font_color", Color(0.4, 0.3, 0.2))
		_penknoppen[i].queue_redraw()
	knop_stijlen(_gumknop, Color(1.0, 0.8, 0.85) if gum else Color(1, 1, 1, 0.92), Color(0.95, 0.4, 0.55) if gum else Color(0.85, 0.78, 0.65), 4 if gum else 2)
	_gumknop.add_theme_color_override("font_color", Color(0.45, 0.3, 0.3))
	knop_stijlen(_wisknop, Color(1.0, 0.55, 0.5) if _wis_zeker else Color(1, 1, 1, 0.92), Color(0.85, 0.78, 0.65), 2)
	_wisknop.text = "zeker?" if _wis_zeker else "alles weg"
	_wisknop.add_theme_color_override("font_color", Color(0.45, 0.3, 0.3))


func _wis_alles() -> void:
	if not _wis_zeker:
		_wis_zeker = true
		_werk_knoppen_bij()
		get_tree().create_timer(2.5).timeout.connect(func():
			_wis_zeker = false
			_werk_knoppen_bij())
		return
	lijnen.clear()
	_wis_zeker = false
	_werk_knoppen_bij()
	_ververs()


class PenKnop extends Button:
	var schets: Schets
	var nr := 0

	func _draw() -> void:
		var k: Color = Schets.KLEUREN[schets.kleur][1]
		var d: float = Schets.DIKTES[nr] * 0.55 + 1.0
		var y := 22.0
		draw_line(Vector2(16, y + 6), Vector2(size.x - 16, y - 6), k, d, true)
		draw_circle(Vector2(16, y + 6), d * 0.5, k, true, -1.0, true)
		draw_circle(Vector2(size.x - 16, y - 6), d * 0.5, k, true, -1.0, true)


# ------------------------------------------------------------------ tekenen

func papier_rect() -> Rect2:
	var marge := 70.0 if bekijken else 0.0
	var ruimte := size - Vector2(marge, marge) * 2.0
	# De hele boskaart past altijd op het scherm (ook op een 4:3-tablet);
	# wat er overblijft is gewoon papier.
	var s := minf(ruimte.x / BREED, ruimte.y / HOOG)
	var maat := Vector2(BREED, HOOG) * s
	return Rect2((size - maat) * 0.5, maat)


func naar_papier(scherm: Vector2) -> Vector2:
	var r := papier_rect()
	return (scherm - r.position) / r.size * Vector2(BREED, HOOG)


func naar_scherm(papier: Vector2) -> Vector2:
	var r := papier_rect()
	return r.position + papier / Vector2(BREED, HOOG) * r.size


static func papier_naar_wereld(p: Vector2) -> Vector3:
	return Vector3((p.x / BREED - 0.5) * Bos.HALF_X * 2.0, 0, (p.y / HOOG - 0.5) * Bos.HALF_Z * 2.0)


static func wereld_naar_papier(w: Vector3) -> Vector2:
	return Vector2((w.x / (Bos.HALF_X * 2.0) + 0.5) * BREED, (w.z / (Bos.HALF_Z * 2.0) + 0.5) * HOOG)


func _gui_input(e: InputEvent) -> void:
	if bekijken:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_palet.visible = false
			var p := naar_papier(e.position)
			if gum:
				_gum(p)
			else:
				lijnen.append({"k": kleur, "d": DIKTES[dikte], "p": PackedVector2Array([p])})
				_bezig = lijnen.size() - 1
			_ververs()
		else:
			_bezig = -1
		accept_event()
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var p := naar_papier(e.position)
		if gum:
			_gum(p)
			_ververs()
		elif _bezig >= 0:
			var lijn: Dictionary = lijnen[_bezig]
			var pts: PackedVector2Array = lijn["p"]
			if pts[pts.size() - 1].distance_to(p) > 2.5:
				pts.append(p)
				lijn["p"] = pts
				_ververs()
		accept_event()


func _gum(p: Vector2) -> void:
	# De gum haalt hele lijnen weg die je aanraakt (lekker makkelijk).
	var straal := 22.0
	lijnen = lijnen.filter(func(l):
		for q in l["p"]:
			if q.distance_to(p) < straal + float(l["d"]) * 0.5:
				return false
		return true)
	_bezig = -1


func _ververs() -> void:
	_tekenaar.queue_redraw()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()


func _process(_delta: float) -> void:
	if visible and bekijken:
		queue_redraw()


# Het werkbalkje even verbergen (voor het plaatje bij opslaan).
func toon_werkbalk(aan: bool) -> void:
	_werkbalk.visible = aan and not bekijken


func _draw() -> void:
	var r := papier_rect()
	if bekijken:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.08, 0.05, 0.45))
		draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(Vector2.ZERO, size) if not bekijken else r, PAPIER)
	# Heel lichte lijntjes, zoals op echt schetspapier.
	var stap := r.size.x / 40.0
	var x := r.position.x
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.55, 0.7, 0.85, 0.08), 1.0)
		x += stap
	var y := r.position.y
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.55, 0.7, 0.85, 0.08), 1.0)
		y += stap

	# Het kaartje van het bos.
	var schaal := r.size.x / (Bos.HALF_X * 2.0)
	if bos != null:
		for b in bos.bomen:
			var s := naar_scherm(wereld_naar_papier(b["p"]))
			draw_circle(s, 2.6 * schaal, Color(0.45, 0.68, 0.35, 0.16), true, -1.0, true)
			draw_circle(s, 2.6 * schaal, Color(0.4, 0.6, 0.3, 0.3), false, 1.5, true)
			draw_circle(s, maxf(0.55 * schaal, 2.0), Color(0.55, 0.38, 0.25, 0.55), true, -1.0, true)
	# De open plek waar je begint: een vlaggetje.
	var start := naar_scherm(wereld_naar_papier(Vector3.ZERO))
	draw_circle(start, 8.0 * schaal, Color(0.85, 0.65, 0.4, 0.2), true, -1.0, true)
	draw_line(start + Vector2(0, 14), start + Vector2(0, -22), Color(0.45, 0.3, 0.2), 3.0, true)
	draw_colored_polygon(PackedVector2Array([start + Vector2(0, -22), start + Vector2(20, -15), start + Vector2(0, -8)]), Color(0.95, 0.35, 0.3))
	var font := get_theme_default_font()
	draw_string(font, start + Vector2(-24, 34), "start", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 0.35, 0.22, 0.85))

	# Het randje van het bos.
	draw_rect(r.grow(-4), Color(0.4, 0.55, 0.3, 0.35), false, 3.0)

	# De tekening zelf.
	draw_texture_rect(viewport.get_texture(), r, false)

	if bekijken:
		var s := naar_scherm(wereld_naar_papier(speler_pos))
		var kijk := Vector2(-sin(speler_kijk), -cos(speler_kijk))
		var zij := Vector2(-kijk.y, kijk.x)
		var puls := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.15
		draw_circle(s, 13.0 * puls, Color(1, 1, 1, 0.9), true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([s + kijk * 14, s - kijk * 8 + zij * 9, s - kijk * 4, s - kijk * 8 - zij * 9]), Color(0.95, 0.35, 0.25))
		draw_string(font, s + Vector2(16, -12), "jij", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.25, 0.2))
