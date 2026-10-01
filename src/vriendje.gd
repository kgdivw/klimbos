class_name Vriendje
extends Node3D

# Een vriendje dat meeklimt op jouw parcours.
#
# Op de grond zoekt het een ingang (klimhaken, een net of touw dat naar een
# platform gaat) en klimt omhoog. Op een platform kiest het een uitgang: een
# brug oversteken, tokkelen, of weer naar beneden klimmen. Het liefst niet
# meteen terug waar het vandaan kwam. Is er (nog) niets gebouwd, dan speelt
# het een beetje in jouw buurt en zwaait het af en toe.
#
# Geen physics: net als de speler op een brug volgt een vriendje de vorm van
# het parcours zelf, dus het valt er nooit per ongeluk af.

const SNEL := 3.0
const KLIM_SNEL := 1.9

var bos: Bos
var bouw: Bouw
var speler: Speler
var model: Poppetje
var naam := ""
var staat := "grond"   # grond, klim_op, klim_af, platform, brug, tokkel, val

var _rng := RandomNumberGenerator.new()
var _doel := Vector3.ZERO
var _naar_klim: Dictionary = {}
var _wacht := 0.0
var _zwaait := false
var _klim: Dictionary = {}
var _kant := Vector3.ZERO
var _langs := 0.0
var _pl: Node3D
var _uitgang: Dictionary = {}
var _vorige: Node3D
var _br: Dictionary = {}
var _br_t := 0.0
var _br_richting := 1.0
var _tok: Dictionary = {}
var _tok_s := 0.0
var _tok_v := 0.0
var _vy := 0.0
var _val_r := Vector3.ZERO
# Vangnet tegen vastzitten: waar stond ik een tijdje geleden?
var _check_pos := Vector3.ZERO
var _check_tijd := 0.0


func _init(n: String, kleuren: Dictionary, kapsel: int, zaad: int) -> void:
	naam = n
	_rng.seed = zaad
	model = Poppetje.new(kleuren, kapsel)
	add_child(model)
	var label := Label3D.new()
	label.text = n
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.78, 0)
	label.font_size = 44
	label.outline_size = 12
	# Altijd even groot op het scherm, of het vriendje nu dichtbij of ver weg is.
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.modulate = Color(1, 1, 1)
	label.outline_modulate = (kleuren.get("shirt", Color(0.4, 0.3, 0.2)) as Color).darkened(0.35)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Comic Sans MS", "Arial Rounded MT Bold", "Segoe UI"])
	font.font_weight = 700
	label.font = font
	add_child(label)


func zet_op(p: Vector3) -> void:
	global_position = Vector3(p.x, 0, p.z)
	staat = "grond"
	_doel = global_position
	_wacht = _rng.randf_range(0.3, 1.5)
	_naar_klim = {}
	_klim = {}
	_br = {}
	_tok = {}
	_pl = null
	model.stoeltje.visible = false


func _process(delta: float) -> void:
	if bouw == null:
		return
	match staat:
		"grond":
			_grond(delta)
		"klim_op":
			_klim_op(delta)
		"klim_af":
			_klim_af(delta)
		"platform":
			_platform(delta)
		"brug":
			_brug(delta)
		"tokkel":
			_tokkel(delta)
		"val":
			_val(delta)
	global_position = bos.binnen(global_position)


# ------------------------------------------------------------------ hulpjes

static func _vlak(v: Vector3) -> Vector3:
	v.y = 0
	return v.normalized() if v.length() > 0.0001 else Vector3.ZERO


func _geldig(stuk) -> bool:
	return stuk != null and is_instance_valid(stuk) and not stuk.is_queued_for_deletion()


func _platform_bij(p: Vector3, marge := 0.5) -> Node3D:
	for pl in bouw.platforms:
		if not _geldig(pl):
			continue
		var c: Vector3 = pl.get_meta("midden")
		if absf(c.y - p.y) < 0.7 and Vector2(p.x - c.x, p.z - c.z).length() <= float(pl.get_meta("straal")) + marge:
			return pl
	return null


func _val_neer(r := Vector3.ZERO) -> void:
	staat = "val"
	_vy = 0.0
	_val_r = r
	_klim = {}
	_br = {}
	_tok = {}
	_pl = null
	model.stoeltje.visible = false


func _wachten(delta: float) -> bool:
	if _wacht <= 0.0:
		return false
	_wacht -= delta
	var naar_speler := speler.global_position - global_position
	if _zwaait and naar_speler.length() < 9.0:
		model.kijk_naar(naar_speler, delta, 6.0)
		model.animeer(delta, "zwaaien", 9.0)
	else:
		model.animeer(delta, "stil", 0.0)
	return true


func _begin_wachten(min_t: float, max_t: float) -> void:
	_wacht = _rng.randf_range(min_t, max_t)
	_zwaait = _rng.randf() < 0.35


# ------------------------------------------------------------------ op de grond

func _grond(delta: float) -> void:
	global_position.y = 0.0
	if _wachten(delta):
		return
	var naar := _doel - global_position
	naar.y = 0
	if naar.length() < 0.25:
		if not _naar_klim.is_empty() and bouw.klimdingen.has(_naar_klim):
			_klim = _naar_klim
			_naar_klim = {}
			staat = "klim_op"
			return
		_kies_grond_doel()
		return
	var r := _ontwijk(naar.normalized())
	global_position += r * SNEL * delta
	model.kijk_naar(r, delta)
	model.animeer(delta, "lopen", 9.0)
	_vangnet(delta)


# Kom je 1,2 seconde lang nauwelijks vooruit, dan kies je iets anders om te
# doen (in plaats van eeuwig op de plaats te blijven lopen).
func _vangnet(delta: float) -> void:
	_check_tijd += delta
	if _check_tijd < 1.2:
		return
	var vooruit := global_position.distance_to(_check_pos)
	_check_tijd = 0.0
	_check_pos = global_position
	if vooruit > 0.6:
		return
	if staat == "grond":
		_kies_grond_doel(true)
	elif staat == "platform":
		_uitgang = {}


func _nieuw_doel(d: Vector3) -> void:
	_doel = d
	_check_tijd = 0.0
	_check_pos = global_position


func _kies_grond_doel(was_vast := false) -> void:
	var vorige_klim := _naar_klim
	_naar_klim = {}
	var ingangen := []
	for k in bouw.klimdingen:
		var pos: Vector3 = k["pos"]
		if float(k["onder"]) < 0.4 and _platform_bij(Vector3(pos.x, k["boven"], pos.z), 0.8) != null:
			ingangen.append(k)
	# Zat je vast op weg naar een ingang, probeer dan liever een andere.
	if was_vast and ingangen.size() > 1:
		ingangen.erase(vorige_klim)
	if not ingangen.is_empty() and _rng.randf() < 0.8:
		var k: Dictionary = ingangen[_rng.randi() % ingangen.size()]
		var pos: Vector3 = k["pos"]
		_kant = k["kant"]
		if _kant == Vector3.ZERO:
			# Een los touw: ga aan de kant staan die van de dichtstbijzijnde
			# stam af ligt, niet ertegenaan.
			var boom := bos.dichtste_boom(pos, 2.5)
			if boom >= 0:
				_kant = _vlak(pos - bos.boom_pos(boom))
			if _kant == Vector3.ZERO:
				var hoek := _rng.randf() * TAU
				_kant = Vector3(cos(hoek), 0, sin(hoek))
		_langs = _rng.randf_range(-0.6, 0.6) * float(k["breed"])
		_naar_klim = k
		_nieuw_doel(Vector3(pos.x, 0, pos.z) + (k["zij"] as Vector3) * _langs + _kant * 0.38)
		return
	# Niets om te klimmen: spelen in de buurt van de speler, op een vrij plekje.
	var s := speler.global_position
	var d := global_position
	for poging in 12:
		var hoek := _rng.randf() * TAU
		d = bos.binnen(Vector3(s.x, 0, s.z) + Vector3(cos(hoek), 0, sin(hoek)) * _rng.randf_range(2.5, 6.0))
		if bos.dichtste_boom(d, 1.6) < 0:
			break
	_nieuw_doel(d)
	_begin_wachten(0.5, 2.5)


# Om bomen heen lopen. Niet "weg van de stam duwen" (dan blijf je op de
# plaats lopen als je doel vlak naast een stam ligt), maar er opzij langs
# sturen. De boom waar je naartoe gaat (klimhaken!) ontwijk je niet, en een
# boom die verder weg staat dan je doel ook niet.
func _ontwijk(r: Vector3) -> Vector3:
	var p := global_position
	var naar_doel := Vector2(_doel.x - p.x, _doel.z - p.z).length()
	var uit := r
	for b in bos.bomen:
		var q: Vector3 = b["p"]
		var rb: float = b["r"]
		if Vector2(_doel.x - q.x, _doel.z - q.z).length() < rb + 1.2:
			continue
		var w := Vector3(p.x - q.x, 0, p.z - q.z)
		var d := w.length()
		var ruimte := rb + 0.9
		if d >= ruimte or d < 0.01 or d > naar_doel + rb:
			continue
		var weg := w / d
		var zij := Vector3(-weg.z, 0, weg.x)
		if zij.dot(r) < 0:
			zij = -zij
		var sterkte := (ruimte - d) / 0.9
		uit += zij * sterkte * 1.6
		if d < rb + 0.35:
			uit += weg * 1.5
	var v := _vlak(uit)
	return v if v != Vector3.ZERO else r


# ------------------------------------------------------------------ klimmen

func _klim_punt() -> Vector3:
	var pos: Vector3 = _klim["pos"]
	return pos + (_klim["zij"] as Vector3) * _langs + _kant * 0.38


func _klim_op(delta: float) -> void:
	if not bouw.klimdingen.has(_klim):
		_val_neer()
		return
	var p := _klim_punt()
	var y := global_position.y + KLIM_SNEL * delta
	global_position = Vector3(p.x, y, p.z)
	model.kijk_naar(-_kant, delta, 20.0)
	model.animeer(delta, "klimmen", 7.0)
	var boven: float = _klim["boven"]
	if y < boven + 0.05:
		return
	var top := Vector3(p.x, boven, p.z)
	var pl := _platform_bij(top, 0.8)
	if pl == null:
		staat = "klim_af"
		return
	var c: Vector3 = pl.get_meta("midden")
	var straal: float = pl.get_meta("straal")
	var r := _vlak(top - c)
	var afstand := clampf(Vector2(top.x - c.x, top.z - c.z).length(), 0.0, straal - 0.5)
	global_position = c + r * afstand
	_vorige = _klim["stuk"]
	_klim = {}
	_kom_op_platform(pl)


func _klim_af(delta: float) -> void:
	if not bouw.klimdingen.has(_klim):
		_val_neer()
		return
	var p := _klim_punt()
	var onder: float = _klim["onder"]
	var y := global_position.y - KLIM_SNEL * delta
	global_position = Vector3(p.x, maxf(y, onder), p.z)
	model.kijk_naar(-_kant, delta, 20.0)
	model.animeer(delta, "klimmen", 7.0)
	if y > onder:
		return
	_vorige = _klim["stuk"]
	_klim = {}
	var pl := _platform_bij(global_position, 0.3)
	if pl != null and onder > 0.3:
		_kom_op_platform(pl)
		return
	staat = "grond"
	_nieuw_doel(Vector3(global_position.x, 0, global_position.z) + _kant * 1.3)
	_begin_wachten(0.5, 2.0)


# ------------------------------------------------------------------ op een platform

func _kom_op_platform(pl: Node3D) -> void:
	staat = "platform"
	_pl = pl
	_uitgang = {}
	global_position.y = (pl.get_meta("midden") as Vector3).y
	_begin_wachten(0.3, 1.6)


func _op_rand(p: Vector3, c: Vector3, straal: float) -> bool:
	return absf(p.y - c.y) < 0.5 and absf(Vector2(p.x - c.x, p.z - c.z).length() - straal) < 0.5


func _kies_uitgang() -> void:
	var c: Vector3 = _pl.get_meta("midden")
	var straal: float = _pl.get_meta("straal")
	var opties := []
	var gewichten := []
	for br in bouw.bruggen:
		for t: float in [0.0, 1.0]:
			var p: Vector3 = br["a"] if t == 0.0 else br["b"]
			if _op_rand(p, c, straal):
				opties.append({"soort": "brug", "br": br, "t": t, "p": p, "stuk": br["stuk"]})
				gewichten.append(3.0)
	for tk in bouw.tokkels:
		var g: Vector3 = (tk["a"] as Vector3) - Vector3.UP * Bouw.KABEL_HOOGTE
		if _op_rand(g, c, straal):
			opties.append({"soort": "tokkel", "tk": tk, "p": c + _vlak(g - c) * (straal - 0.3), "stuk": tk["stuk"]})
			gewichten.append(3.0)
	for k in bouw.klimdingen:
		var kp: Vector3 = k["pos"]
		var top := Vector3(kp.x, k["boven"], kp.z)
		var d := Vector2(top.x - c.x, top.z - c.z).length()
		if absf(top.y - c.y) > 0.7 or d > straal + 0.6 or float(k["boven"]) - float(k["onder"]) < 1.0:
			continue
		var kant: Vector3 = k["kant"]
		if kant == Vector3.ZERO:
			kant = _vlak(top - c) if d > 0.3 else Vector3(1, 0, 0)
		var p := top + kant * 0.38 if k.has("boom") else c + _vlak(top - c) * minf(d, straal - 0.25)
		opties.append({"soort": "klim", "k": k, "p": p, "kant": kant, "stuk": k["stuk"]})
		gewichten.append(1.0)
	# Liever niet meteen terug waar je vandaan kwam.
	var nieuw := []
	var nieuw_g := []
	for i in opties.size():
		if opties[i]["stuk"] != _vorige:
			nieuw.append(opties[i])
			nieuw_g.append(gewichten[i])
	if not nieuw.is_empty():
		opties = nieuw
		gewichten = nieuw_g
	if opties.is_empty():
		# Doodlopend platform zonder trap: dan maar springen (zachte landing).
		var hoek := _rng.randf() * TAU
		_uitgang = {"soort": "spring", "p": c + Vector3(cos(hoek), 0, sin(hoek)) * (straal - 0.3)}
		return
	var totaal := 0.0
	for g in gewichten:
		totaal += g
	var lot := _rng.randf() * totaal
	for i in opties.size():
		lot -= gewichten[i]
		if lot <= 0.0:
			_uitgang = opties[i]
			return
	_uitgang = opties[opties.size() - 1]


func _platform(delta: float) -> void:
	if not _geldig(_pl) or not bouw.platforms.has(_pl):
		_val_neer()
		return
	var c: Vector3 = _pl.get_meta("midden")
	var straal: float = _pl.get_meta("straal")
	global_position.y = c.y
	if _wachten(delta):
		return
	if _uitgang.is_empty() or (_uitgang.has("stuk") and not _geldig(_uitgang["stuk"])):
		_kies_uitgang()
	# Lopen in "poolcoördinaten" rond de stam: eerst eromheen, dan naar de rand.
	var doel: Vector3 = _uitgang["p"]
	var rel := global_position - c
	var rho := Vector2(rel.x, rel.z).length()
	var th := atan2(rel.z, rel.x)
	var trel := doel - c
	var trho := minf(Vector2(trel.x, trel.z).length(), straal - 0.15)
	var tth := atan2(trel.z, trel.x)
	var dth := wrapf(tth - th, -PI, PI)
	var min_r := bos.stam_straal(int(_pl.get_meta("boom")), c.y) + 0.6
	if absf(dth) > 0.06:
		rho = move_toward(rho, clampf(rho, min_r, straal - 0.5), SNEL * delta)
		th += signf(dth) * minf(absf(dth), SNEL * delta / maxf(rho, 0.5))
	else:
		rho = move_toward(rho, trho, SNEL * delta)
	var nieuw := c + Vector3(cos(th), 0, sin(th)) * rho
	var r := nieuw - global_position
	global_position = nieuw
	model.kijk_naar(r, delta)
	model.animeer(delta, "lopen", 9.0)
	_vangnet(delta)
	if absf(dth) <= 0.06 and absf(rho - trho) < 0.05:
		_neem_uitgang(c)


func _neem_uitgang(c: Vector3) -> void:
	var u := _uitgang
	_uitgang = {}
	match u["soort"]:
		"brug":
			staat = "brug"
			_br = u["br"]
			_br_t = 0.02 if float(u["t"]) == 0.0 else 0.98
			_br_richting = 1.0 if float(u["t"]) == 0.0 else -1.0
		"tokkel":
			staat = "tokkel"
			_tok = u["tk"]
			_tok_s = 0.3
			_tok_v = 2.5
			model.stoeltje.visible = true
		"klim":
			staat = "klim_af"
			_klim = u["k"]
			_kant = u["kant"]
			_langs = 0.0
			global_position.y = float(_klim["boven"]) - 0.1
		"spring":
			_val_neer(_vlak(global_position - c) * 2.5)


# ------------------------------------------------------------------ brug en tokkelbaan

func _brug(delta: float) -> void:
	if not bouw.bruggen.has(_br):
		_val_neer()
		return
	var a: Vector3 = _br["a"]
	var b: Vector3 = _br["b"]
	var l: float = _br["l"]
	_br_t += _br_richting * SNEL * 0.9 * delta / maxf(l, 0.1)
	var richting := _vlak(b - a) * _br_richting
	if _br_t < 0.0 or _br_t > 1.0:
		var eind := b if _br_t > 1.0 else a
		_vorige = _br["stuk"]
		_br = {}
		var pl := _platform_bij(eind, 0.6)
		global_position = eind + richting * 0.6
		if pl != null:
			_kom_op_platform(pl)
		else:
			_val_neer(richting * 1.5)
		return
	global_position = Bouw.boog(a, b, _br["zak"], _br_t) + Vector3(0, 0.02, 0)
	model.kijk_naar(richting, delta)
	model.animeer(delta, "lopen", 8.0)


func _tokkel(delta: float) -> void:
	if not bouw.tokkels.has(_tok):
		_val_neer()
		return
	var a: Vector3 = _tok["a"]
	var b: Vector3 = _tok["b"]
	var l := a.distance_to(b)
	var helling := (a.y - b.y) / maxf(l, 0.1)
	_tok_v = clampf(_tok_v + (9.8 * helling + 2.0) * delta, 3.5, 12.0)
	_tok_s += _tok_v * delta
	global_position = Bouw.boog(a, b, l * 0.02, clampf(_tok_s / l, 0.0, 1.0)) - Vector3(0, 2.15, 0)
	model.kijk_naar(b - a, delta, 20.0)
	model.animeer(delta, "tokkelen", 3.0)
	if _tok_s >= l - 0.35:
		var r := _vlak(b - a)
		_vorige = _tok["stuk"]
		_tok = {}
		model.stoeltje.visible = false
		global_position = b - Vector3(0, Bouw.KABEL_HOOGTE - 0.15, 0) + r * 0.7
		var pl := _platform_bij(global_position, 0.3)
		if pl != null:
			_kom_op_platform(pl)
		else:
			_val_neer(r * 2.0)


func _val(delta: float) -> void:
	_vy -= 17.0 * delta
	global_position += (_val_r + Vector3(0, _vy, 0)) * delta
	model.animeer(delta, "vallen", 1.0)
	if global_position.y <= 0.0:
		global_position.y = 0.0
		staat = "grond"
		_nieuw_doel(global_position)
		_begin_wachten(0.4, 1.2)
