extends Node3D

# Het Klimbos.
#
# Je begint met een schetspapier over het hele scherm. Teken je plan, druk op
# Klaar! en je staat in het bos. Je tekening staat dan als een reuzenkaart op
# de bosgrond, precies tussen de bomen waar je hem getekend hebt.
# Drie vriendjes klimmen mee op alles wat je bouwt. Met Opslaan bewaar je je
# spel (met een plaatje en de datum), met Openen haal je het weer terug.
#
# Muis: linkermuis = iets kiezen in de inventaris (of slepen om rond te
# kijken), rechtermuis = het gekozen ding in de wereld zetten.
# Express: duid met de rechtermuis twee bomen aan; het spel bouwt dan zelf het
# parcours zoals je het op je schets getekend hebt.

const PLAN_HOOGTE := 0.035
const VRIENDJES := [
	["Lotte", {"shirt": Color(0.6, 0.42, 0.92), "broek": Color(0.95, 0.6, 0.72), "helm": Color(0.45, 0.8, 1.0), "haar": Color(0.95, 0.76, 0.36)}, 1],
	["Sem", {"shirt": Color(0.32, 0.75, 0.45), "broek": Color(0.4, 0.33, 0.27), "helm": Color(1.0, 0.45, 0.35), "haar": Color(0.18, 0.11, 0.07), "huid": Color(0.76, 0.53, 0.38)}, 0],
	["Noor", {"shirt": Color(1.0, 0.76, 0.25), "broek": Color(0.26, 0.45, 0.72), "helm": Color(0.96, 0.52, 0.8), "haar": Color(0.62, 0.3, 0.14)}, 2],
	["Daan", {"shirt": Color(0.3, 0.6, 0.95), "broek": Color(0.95, 0.75, 0.3), "helm": Color(0.55, 0.9, 0.4), "haar": Color(0.95, 0.85, 0.55)}, 0],
	["Fien", {"shirt": Color(0.98, 0.45, 0.55), "broek": Color(0.4, 0.3, 0.55), "helm": Color(1.0, 0.95, 0.9), "haar": Color(0.12, 0.08, 0.06), "huid": Color(0.6, 0.4, 0.28)}, 1],
	["Milan", {"shirt": Color(0.95, 0.55, 0.2), "broek": Color(0.25, 0.55, 0.45), "helm": Color(0.3, 0.45, 0.95), "haar": Color(0.55, 0.32, 0.18), "huid": Color(0.9, 0.7, 0.55)}, 0],
]

var bos: Bos
var bouw: Bouw
var speler: Speler
var schets: Schets
var hud: Hud
var grond_plan: MeshInstance3D
var vriendjes: Array[Vriendje] = []
var opslagmenu: Opslagmenu
var aanraak: Aanraak
var aanraak_modus := false
var _vingers := {}         # vinger-nummer -> {"pos", "weg"} voor vingers in het bos
var _knijp_afstand := 0.0
var _toast: Label
var _bezig_met_opslaan := false

var modus := "schets"
var item := -1
var express := false
var eerste := {}
var _plan_open := false

var _spook: Node3D
var _spook_sleutel := ""
var _merk: MeshInstance3D
var _merk_eerste: MeshInstance3D
var _ring: MeshInstance3D
var _ring_eerste: MeshInstance3D

var _slepen := false
var _gesleept := 0.0
var _muis_terug := Vector2.ZERO

var _bouwrij: Array = []
var _bouw_tijd := 0.0


func _ready() -> void:
	_invoer()
	bos = Bos.new()
	add_child(bos)
	bouw = Bouw.new()
	bouw.bos = bos
	add_child(bouw)
	speler = Speler.new()
	speler.bos = bos
	speler.bouw = bouw
	add_child(speler)

	var laag := CanvasLayer.new()
	add_child(laag)
	var wortel := Control.new()
	wortel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wortel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wortel.theme = _thema()
	laag.add_child(wortel)
	hud = Hud.new()
	wortel.add_child(hud)
	hud.visible = false
	aanraak = Aanraak.new()
	aanraak.visible = false
	wortel.add_child(aanraak)
	schets = Schets.new()
	schets.bos = bos
	wortel.add_child(schets)
	opslagmenu = Opslagmenu.new()
	wortel.add_child(opslagmenu)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 34)
	_toast.add_theme_color_override("font_color", Color(1, 0.97, 0.75))
	_toast.add_theme_color_override("font_outline_color", Color(0.4, 0.25, 0.08))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Schets.zet(_toast, Control.PRESET_CENTER_TOP, Vector2(-400, 12), Vector2(800, 60))
	_toast.modulate.a = 0.0
	wortel.add_child(_toast)

	schets.klaar.connect(_naar_bos)
	hud.gekozen.connect(_kies)
	hud.express_gedrukt.connect(_wissel_express)
	hud.plan_gedrukt.connect(_wissel_plan)
	hud.schets_gedrukt.connect(_naar_schets)
	speler.melding.connect(func(t: String): hud.meld(t))
	schets.opslaan_gedrukt.connect(_opslaan)
	schets.openen_gedrukt.connect(opslagmenu.toon)
	hud.opslaan_gedrukt.connect(_opslaan)
	hud.openen_gedrukt.connect(opslagmenu.toon)
	opslagmenu.openen.connect(_open_spel)

	for i in VRIENDJES.size():
		var d: Array = VRIENDJES[i]
		var vr := Vriendje.new(d[0], d[1], d[2], 31 + i * 17)
		vr.bos = bos
		vr.bouw = bouw
		vr.speler = speler
		add_child(vr)
		vr.zet_op(Speler.START + _startplek(i))
		vriendjes.append(vr)

	_maak_grond_plan()
	_maak_merktekens()
	_naar_schets()
	# Staand scherm (tablet rechtop): alles wat groter, anders worden de knoppen
	# piepklein.
	get_window().size_changed.connect(_schaal_ui)
	_schaal_ui()
	# Op een tablet of telefoon meteen de aanraakknoppen.
	for f in ["web_android", "web_ios", "android", "ios"]:
		if OS.has_feature(f):
			_zet_aanraak(true)


# De vriendjes staan bij het begin in een boogje voor je.
func _startplek(i: int) -> Vector3:
	var hoek := -PI * 0.5 + (i - (VRIENDJES.size() - 1) * 0.5) * 0.42
	return Vector3(cos(hoek), 0, sin(hoek)) * 2.8


func _invoer() -> void:
	var acties := {
		"voor": [KEY_W, KEY_UP], "achter": [KEY_S, KEY_DOWN],
		"links": [KEY_A, KEY_LEFT], "rechts": [KEY_D, KEY_RIGHT],
		"springen": [KEY_SPACE], "doe": [KEY_E], "plan": [KEY_TAB],
	}
	for naam in acties:
		if not InputMap.has_action(naam):
			InputMap.add_action(naam)
		for k in acties[naam]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(naam, ev)


func _thema() -> Theme:
	var t := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Comic Sans MS", "Arial Rounded MT Bold", "Segoe UI"])
	f.font_weight = 700
	t.default_font = f
	t.default_font_size = 18
	return t


# Je tekening, als een reuzenkaart op de bosgrond: elke lijn ligt precies op
# de plek waar je hem tussen de boomrondjes tekende, alsof je met krijt op de
# grond hebt getekend. Het gras steekt er hier en daar doorheen.
func _maak_grond_plan() -> void:
	var vlak := PlaneMesh.new()
	vlak.size = Vector2(Bos.HALF_X * 2.0, Bos.HALF_Z * 2.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = schets.textuur()
	m.albedo_color = Color(1, 1, 1, 0.95)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	vlak.material = m
	grond_plan = MeshInstance3D.new()
	grond_plan.mesh = vlak
	grond_plan.position = Vector3(0, PLAN_HOOGTE, 0)
	grond_plan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grond_plan)


func _maak_merktekens() -> void:
	var geel := StandardMaterial3D.new()
	geel.albedo_color = Color(1.0, 0.85, 0.2, 0.85)
	geel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	geel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	geel.no_depth_test = true
	var oranje := geel.duplicate() as StandardMaterial3D
	oranje.albedo_color = Color(1.0, 0.45, 0.15, 0.9)

	var bol := SphereMesh.new()
	bol.radius = 0.16
	bol.height = 0.32
	bol.material = geel
	_merk = MeshInstance3D.new()
	_merk.mesh = bol
	add_child(_merk)
	var bol2 := bol.duplicate() as SphereMesh
	bol2.material = oranje
	_merk_eerste = MeshInstance3D.new()
	_merk_eerste.mesh = bol2
	add_child(_merk_eerste)

	var ring := TorusMesh.new()
	ring.inner_radius = 1.1
	ring.outer_radius = 1.35
	ring.material = geel
	_ring = MeshInstance3D.new()
	_ring.mesh = ring
	add_child(_ring)
	var ring2 := ring.duplicate() as TorusMesh
	ring2.material = oranje
	_ring_eerste = MeshInstance3D.new()
	_ring_eerste.mesh = ring2
	add_child(_ring_eerste)
	_verberg_merken()


func _verberg_merken() -> void:
	_merk.visible = false
	_merk_eerste.visible = false
	_ring.visible = false
	_ring_eerste.visible = false


# ------------------------------------------------------------------ modi

func _schaal_ui() -> void:
	var w := get_window().size
	get_window().content_scale_factor = 1.5 if w.y > w.x else 1.0


func _zet_aanraak(aan: bool) -> void:
	if aan == aanraak_modus:
		return
	aanraak_modus = aan
	hud.zet_aanraak(aan)
	aanraak.visible = aan and modus == "bos"
	if not aan:
		aanraak.los()


func _naar_bos() -> void:
	modus = "bos"
	aanraak.visible = aanraak_modus
	_plan_open = false
	schets.visible = false
	hud.visible = true
	speler.bevroren = false
	hud.meld("Kijk eens naar de grond: daar staat je plan!")


func _naar_schets() -> void:
	modus = "schets"
	aanraak.visible = false
	aanraak.los()
	_plan_open = false
	_annuleer()
	hud.visible = false
	speler.bevroren = true
	schets.toon_tekenen()


func _wissel_plan() -> void:
	if modus != "bos":
		return
	_plan_open = not _plan_open
	if _plan_open:
		schets.toon_bekijken()
	else:
		schets.visible = false


func _kies(nr: int) -> void:
	item = nr
	eerste = {}
	bouw.markeer(null)
	if nr >= 0 and express:
		express = false
		hud.zet_express(false)


func _wissel_express() -> void:
	express = not express
	eerste = {}
	hud.zet_express(express)
	if express:
		hud.kies(-1)
		express = true
		hud.zet_express(true)
		hud.meld("Express: kies twee bomen")


func _annuleer() -> void:
	eerste = {}
	_ruim_spook()
	_verberg_merken()


# ------------------------------------------------------------------ opslaan en openen

func toon_melding(tekst: String) -> void:
	_toast.text = tekst
	_toast.modulate.a = 1.0
	var tw := _toast.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func spel_gegevens() -> Dictionary:
	return {
		"versie": 1,
		"tijd": Time.get_unix_time_from_system(),
		"modus": modus,
		"lijnen": schets.lijnen.duplicate(true),
		"stukken": bouw.plannen(),
		"speler": {"pos": speler.global_position, "yaw": speler.yaw, "pitch": speler.pitch},
	}


func _opslaan() -> void:
	if _bezig_met_opslaan:
		return
	_bezig_met_opslaan = true
	# Voor het plaatje: even zonder knoppen en uitleg in beeld.
	var hud_aan := hud.visible
	hud.visible = false
	schets.toon_werkbalk(false)
	var spook_aan := _spook != null and is_instance_valid(_spook)
	if spook_aan:
		_spook.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	hud.visible = hud_aan
	schets.toon_werkbalk(true)
	if spook_aan and is_instance_valid(_spook):
		_spook.visible = true
	img.resize(320, 180, Image.INTERPOLATE_BILINEAR)
	var naam := Opslag.bewaar(spel_gegevens(), img)
	toon_melding("Opgeslagen!" if naam != "" else "Opslaan is niet gelukt")
	_bezig_met_opslaan = false


func _open_spel(naam: String) -> void:
	var d := Opslag.laad(naam)
	if d.is_empty():
		toon_melding("Dit spel kon niet geopend worden")
		return
	_annuleer()
	_bouwrij.clear()
	express = false
	hud.zet_express(false)
	bouw.wis_alles()
	schets.lijnen = d.get("lijnen", [])
	schets._ververs()
	for p in d.get("stukken", []):
		bouw.maak(p, false, true, false)
	var sp: Dictionary = d.get("speler", {})
	speler.zet_terug(sp.get("pos", Speler.START), sp.get("yaw", 0.0), sp.get("pitch", -0.32))
	for i in vriendjes.size():
		vriendjes[i].zet_op(speler.global_position + _startplek(i))
	if d.get("modus", "bos") == "schets":
		_naar_schets()
	else:
		_naar_bos()
	toon_melding("Spel geopend!")


# ------------------------------------------------------------------ invoer

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and e.pressed:
		_zet_aanraak(true)
	elif e is InputEventMouseButton and e.pressed and e.device != InputEvent.DEVICE_ID_EMULATION:
		_zet_aanraak(false)
	if e.is_action_pressed("plan") and not e.is_echo():
		_wissel_plan()
		get_viewport().set_input_as_handled()


func _unhandled_input(e: InputEvent) -> void:
	if modus != "bos":
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode >= KEY_1 and e.keycode <= KEY_9:
			var nr: int = e.keycode - KEY_1
			hud.kies(nr if hud.gekozen_nr != nr else -1)
		elif e.keycode == KEY_ESCAPE:
			if not eerste.is_empty():
				eerste = {}
			elif express:
				_wissel_express()
			else:
				hud.kies(-1)
	elif e is InputEventScreenTouch or e is InputEventScreenDrag:
		_vinger(e)
	elif e is InputEventMouse and e.device == InputEvent.DEVICE_ID_EMULATION:
		# Nagebootste muis van een vinger: die vingers doen we hierboven al zelf.
		return
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_slepen = true
				_gesleept = 0.0
				_muis_terug = e.position
			else:
				_slepen = false
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					Input.warp_mouse(_muis_terug)
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			_rechtsklik()
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			speler.zoom(-0.6)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			speler.zoom(0.6)
	elif e is InputEventMouseMotion and _slepen:
		_gesleept += e.relative.length()
		if _gesleept > 4.0 and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		speler.draai_camera(e.relative.x, e.relative.y)


# Een vinger in het bos: vegen = rondkijken, twee vingers knijpen = zoomen,
# kort tikken = plaatsen (zoals de rechtermuisknop op de computer).
func _vinger(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_vingers[e.index] = {"pos": e.position, "weg": 0.0}
			_knijp_afstand = 0.0
		else:
			var v: Dictionary = _vingers.get(e.index, {})
			_vingers.erase(e.index)
			_knijp_afstand = 0.0
			if not v.is_empty() and float(v["weg"]) < 14.0 and _vingers.is_empty():
				_tik(e.position)
		return
	if not _vingers.has(e.index):
		return
	var v: Dictionary = _vingers[e.index]
	v["pos"] = e.position
	v["weg"] = float(v["weg"]) + e.relative.length()
	if _vingers.size() == 1:
		if float(v["weg"]) > 8.0:
			speler.draai_camera(e.relative.x * 0.9, e.relative.y * 0.9)
	elif _vingers.size() == 2:
		var p: Array = _vingers.values()
		var d := (p[0]["pos"] as Vector2).distance_to(p[1]["pos"])
		if _knijp_afstand > 0.0:
			speler.zoom(-(d - _knijp_afstand) * 0.02)
		_knijp_afstand = d
		for w in _vingers.values():
			w["weg"] = 99.0   # knijpen is geen tik


func _tik(pos: Vector2) -> void:
	if item < 0 and not express:
		return
	_rechtsklik(pos)


func _straal(scherm := Vector2(-1, -1)) -> Dictionary:
	var cam := speler.camera
	var m := scherm if scherm.x >= 0.0 else get_viewport().get_mouse_position()
	var van := cam.project_ray_origin(m)
	var naar := van + cam.project_ray_normal(m) * 90.0
	var q := PhysicsRayQueryParameters3D.create(van, naar, 1 | 2 | Bouw.LAAG_STUK | Bouw.LAAG_KLIK)
	q.exclude = [speler.get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {}
	var c: Object = r["collider"]
	var hit := {"punt": r["position"], "normaal": r["normal"], "boom": -1, "stuk": null, "grond": false}
	if c.has_meta("boom"):
		hit["boom"] = int(c.get_meta("boom"))
	if c.has_meta("stuk"):
		var stuk: Node3D = c.get_meta("stuk")
		if is_instance_valid(stuk):
			hit["stuk"] = stuk
			if stuk.get_meta("soort") == "klimhaken":
				hit["boom"] = int(stuk.get_meta("boom"))
	if c is StaticBody3D and (c as StaticBody3D).collision_layer == Bos.LAAG_GROND:
		hit["grond"] = true
	return hit


func _boom_uit(hit: Dictionary) -> int:
	if hit.is_empty():
		return -1
	if hit["boom"] >= 0:
		return hit["boom"]
	var stuk: Node3D = hit["stuk"]
	if stuk != null and stuk.has_meta("boom"):
		return int(stuk.get_meta("boom"))
	return bos.dichtste_boom(hit["punt"], 3.5)


func _rechtsklik(scherm := Vector2(-1, -1)) -> void:
	var hit := _straal(scherm)
	if express:
		var boom := _boom_uit(hit)
		if boom < 0:
			hud.meld("Klik op een boom")
			return
		if eerste.is_empty():
			eerste = {"boom": boom}
			hud.meld("Start gekozen! Nu de eindboom.")
			return
		if boom == eerste["boom"]:
			hud.meld("Kies een andere boom")
			return
		_express_bouw(eerste["boom"], boom)
		eerste = {}
		express = false
		hud.zet_express(false)
		return
	if item < 0:
		hud.meld("Kies eerst iets uit je inventaris")
		return
	var soort: String = Bouw.SOORTEN[item]
	var p := bouw.plan(soort, hit, speler.camera.global_position, eerste)
	if not p["ok"]:
		if p["reden"] != "":
			hud.meld(p["reden"])
		return
	if p.get("stap", 0) == 1:
		eerste = p["klik"]
		return
	bouw.maak(p)
	eerste = {}
	_spook_sleutel = ""
	if soort == "sloop":
		hud.meld("Weg!")


# E (of de E-knop op de tablet): tokkelen of naar beneden klimmen.
func _doe() -> void:
	var t := speler.tokkel_mogelijk()
	if not t.is_empty():
		speler.begin_tokkelen(t)
		return
	var k := speler.klim_omlaag_mogelijk()
	if not k.is_empty():
		speler.klim_omlaag(k)


func _express_bouw(a: int, b: int) -> void:
	var uit := Pad.bomen_rij(schets.lijnen, bos, bos.boom_pos(a), bos.boom_pos(b), a, b)
	var rij: Array = uit[0]
	var plannen := bouw.express_plannen(rij, speler.global_position)
	_bouwrij.append_array(plannen)
	if uit[1]:
		hud.meld("Express bouwt je schets na!  (%d bomen)" % rij.size())
	else:
		hud.meld("Geen lijn op je schets: Express bouwt een rechte route")


# ------------------------------------------------------------------ elke frame

func _process(delta: float) -> void:
	if modus != "bos":
		return
	if _plan_open:
		schets.speler_pos = speler.global_position
		schets.speler_kijk = speler.yaw

	if Input.is_action_just_pressed("doe"):
		_doe()

	if not _bouwrij.is_empty():
		_bouw_tijd -= delta
		if _bouw_tijd <= 0.0:
			bouw.maak(_bouwrij.pop_front())
			_bouw_tijd = 0.3

	if speler.staat == "brug":
		hud.zet_vraag("")
	elif speler.staat == "klimmen":
		hud.zet_vraag("W = omhoog   S = omlaag   Spatie = loslaten")
	elif speler.staat == "tokkelen":
		hud.zet_vraag("")
	elif not speler.tokkel_mogelijk().is_empty():
		hud.zet_vraag("Druk op E om te tokkelen!")
	elif not speler.klim_omlaag_mogelijk().is_empty():
		hud.zet_vraag("Druk op E om naar beneden te klimmen")
	elif speler.aan_de_rand():
		hud.zet_vraag("Spatie = eraf springen")
	else:
		hud.zet_vraag("")

	if _slepen and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	_werk_spook(_straal())


func _ruim_spook() -> void:
	if _spook != null and is_instance_valid(_spook):
		_spook.queue_free()
	_spook = null
	_spook_sleutel = ""


func _werk_spook(hit: Dictionary) -> void:
	_verberg_merken()
	if express:
		_ruim_spook()
		var boom := _boom_uit(hit)
		if boom >= 0:
			_ring.visible = true
			_ring.position = bos.boom_pos(boom) + Vector3(0, 0.15, 0)
		if not eerste.is_empty():
			_ring_eerste.visible = true
			_ring_eerste.position = bos.boom_pos(eerste["boom"]) + Vector3(0, 0.15, 0)
			hud.zet_hint("EXPRESS: rechtsklik op de boom waar het parcours moet eindigen.   (Esc = stoppen)")
		else:
			hud.zet_hint("EXPRESS: rechtsklik op de boom waar het parcours moet beginnen.")
		return
	if item < 0:
		_ruim_spook()
		hud.zet_hint("Kies iets uit je inventaris met de linkermuis (of 1-9), en zet het met de rechtermuis in de bomen.")
		return
	var soort: String = Bouw.SOORTEN[item]
	if soort == "sloop":
		_ruim_spook()
		bouw.markeer(hit["stuk"] if not hit.is_empty() else null)
		hud.zet_hint("Afbreken: rechtsklik op iets wat je gebouwd hebt.")
		return
	var p := bouw.plan(soort, hit, speler.camera.global_position, eerste)
	if not eerste.is_empty():
		_merk_eerste.visible = true
		_merk_eerste.position = eerste["punt"]
	var sleutel := ""
	if not hit.is_empty():
		var hp: Vector3 = hit["punt"]
		var hn: Vector3 = hit["normaal"]
		sleutel = "%s|%s|%s|%s|%d" % [soort, hp.snapped(Vector3.ONE * 0.12), hn.snapped(Vector3.ONE * 0.3), p["ok"], eerste.size()]
		sleutel += "|%.0f" % rad_to_deg(speler.yaw) if soort == "plank" else ""
	if sleutel != _spook_sleutel:
		_ruim_spook()
		_spook_sleutel = sleutel
		if p["ok"] and p.get("stap", 0) != 1:
			_spook = bouw.maak(p, true)
	if p["ok"] and p.get("stap", 0) == 1:
		_merk.visible = true
		_merk.position = p["punt"]
	var uitleg := {
		"plank": "Plank: rechtsklik op de grond, op een platform, of tegen een stam (dan steekt hij eruit als een trede).",
		"platform": "Platform: rechtsklik op een boomstam, op de hoogte waar je het wilt.",
		"brug": "Brug: rechtsklik waar hij begint (een platform of stam).",
		"touwbrug": "Touwbrug: rechtsklik waar hij begint (een platform of stam).",
		"tokkelbaan": "Tokkelbaan: rechtsklik waar je vertrekt (een platform).",
		"klimtouw": "Klimtouw: rechtsklik op een stam of op de rand van een platform. Het touw hangt tot de grond.",
		"klimhaken": "Klimhaken: rechtsklik op een stam, zo hoog als je wilt klimmen.",
		"klimnet": "Klimnet: rechtsklik op de rand van een platform of op een stam.",
	}
	var tekst: String = uitleg[soort]
	if not eerste.is_empty():
		tekst = "Rechtsklik nu waar hij moet eindigen.   (Esc = opnieuw)"
	if not p["ok"] and p["reden"] != "":
		tekst = p["reden"]
	hud.zet_hint(tekst)
