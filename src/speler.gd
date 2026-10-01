class_name Speler
extends CharacterBody3D

# Het klimmertje. Lopen met WASD of de pijltjes, springen met spatie.
# Loop je tegen een touw, net of klimhaken aan, dan klim je vanzelf: omhoog
# met W/pijl omhoog, omlaag met S/pijl omlaag, eraf springen met spatie.
# Bij het begin van een tokkelbaan druk je op E.
#
# De camera hangt achter de speler. Rondkijken doe je door met de linker
# muisknop in de wereld te slepen (de muis blijft vrij om te klikken).

signal melding(tekst: String)

const SNELHEID := 5.5
const SPRONG := 7.2
const ZWAARTE := 17.0
const KLIM_SNELHEID := 2.6
const START := Vector3(0, 0.1, 3.0)

var bos: Bos
var bouw: Bouw
var camera: Camera3D
var arm: SpringArm3D
var draaipunt: Node3D
var yaw := 0.0
var pitch := -0.32
var afstand := 5.5

var model: Poppetje

var staat := "lopen"   # lopen, klimmen, tokkelen
var _klim: Dictionary
var _klim_kant := Vector3.ZERO
var _klim_langs := 0.0
var _tokkel: Dictionary
var _tok_s := 0.0
var _tok_v := 0.0
var _klim_pauze := 0.0
var bevroren := true


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 2 | 4 | 8
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)
	var vorm := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.3
	vorm.shape = cap
	vorm.position = Vector3(0, 0.65, 0)
	add_child(vorm)
	position = START
	_maak_model()
	_maak_camera()


func _maak_camera() -> void:
	draaipunt = Node3D.new()
	draaipunt.top_level = true
	add_child(draaipunt)
	arm = SpringArm3D.new()
	arm.collision_mask = 1 | 4
	arm.margin = 0.25
	var bol := SphereShape3D.new()
	bol.radius = 0.2
	arm.shape = bol
	arm.add_excluded_object(get_rid())
	draaipunt.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 68
	camera.far = 150
	arm.add_child(camera)
	draaipunt.global_position = global_position + Vector3(0, 1.2, 0)


# ------------------------------------------------------------------ uiterlijk

func _maak_model() -> void:
	model = Poppetje.new()
	add_child(model)


func _kijk_naar(r: Vector3, delta: float, snel := 12.0) -> void:
	model.kijk_naar(r, delta, snel)


func _animeer(delta: float, soort: String, tempo: float) -> void:
	model.animeer(delta, soort, tempo)



# Na het openen van een opgeslagen spel: gewoon weer staan op de bewaarde plek.
func zet_terug(pos: Vector3, nieuwe_yaw: float, nieuwe_pitch: float) -> void:
	staat = "lopen"
	_klim = {}
	_tokkel = {}
	_br = {}
	_stuur_doel = {}
	velocity = Vector3.ZERO
	model.stoeltje.visible = false
	global_position = pos
	yaw = nieuwe_yaw
	pitch = nieuwe_pitch
	draaipunt.global_position = pos + Vector3(0, 1.25, 0)


# ------------------------------------------------------------------ besturing

func vooruit() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func rechts() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


func _physics_process(delta: float) -> void:
	if bevroren:
		_camera_volgen(delta)
		return
	_klim_pauze = maxf(_klim_pauze - delta, 0.0)
	match staat:
		"lopen":
			_lopen(delta)
		"klimmen":
			_klimmen(delta)
		"tokkelen":
			_tokkelen(delta)
		"brug":
			_brug(delta)
	var p := bos.binnen(global_position)
	if p.x != global_position.x or p.z != global_position.z:
		global_position = p
	if global_position.y < -8.0:
		global_position = START
		velocity = Vector3.ZERO
	_camera_volgen(delta)


func _invoer() -> Vector3:
	var ix := Input.get_axis("links", "rechts")
	var iy := Input.get_axis("achter", "voor")
	var r := vooruit() * iy + rechts() * ix
	return r.normalized() if r.length() > 1.0 else r


func _lopen(delta: float) -> void:
	var r := _stuur(_invoer())
	var op_grond := is_on_floor()
	var versnel := 14.0 if op_grond else 5.0
	# In de lucht houd je je vaart als je niets indrukt (anders zweef je terug).
	if op_grond or r.length() > 0.1:
		velocity.x = move_toward(velocity.x, r.x * SNELHEID, versnel * SNELHEID * delta)
		velocity.z = move_toward(velocity.z, r.z * SNELHEID, versnel * SNELHEID * delta)
	if not op_grond:
		velocity.y -= ZWAARTE * delta
	elif Input.is_action_just_pressed("springen"):
		velocity.y = SPRONG
		if _aan_rand > 0.0:
			# Tegen de rand + spatie = bewust naar beneden springen.
			_vrij = 1.2
			velocity.x = _rand_uit.x * 3.5
			velocity.z = _rand_uit.z * 3.5
	_aan_rand = maxf(_aan_rand - delta, 0.0)
	_vrij = maxf(_vrij - delta, 0.0)
	move_and_slide()
	_houd_op_platform()
	if _probeer_brug(r):
		return

	if r.length() > 0.1:
		_kijk_naar(r, delta)
	var vlak := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() and velocity.y < -4.0:
		_animeer(delta, "vallen", 1.0)
	elif vlak > 0.5:
		_animeer(delta, "lopen", 4.0 + vlak * 1.6)
	else:
		_animeer(delta, "stil", 0.0)

	if r.length() > 0.1 and _klim_pauze <= 0.0:
		_probeer_klimmen(r)


# Het dichtstbijzijnde punt op een klimding (touw = lijn, net = breed vlak).
func _dichtbij(k: Dictionary) -> Vector3:
	var pos: Vector3 = k["pos"]
	var zij: Vector3 = k["zij"]
	var rel := global_position - pos
	rel.y = 0
	var langs := 0.0
	if zij != Vector3.ZERO:
		langs = clampf(rel.dot(zij), -float(k["breed"]), float(k["breed"]))
	var p := pos + zij * langs
	p.y = 0
	return p


func _probeer_klimmen(r: Vector3) -> void:
	var voet := global_position
	for k in bouw.klimdingen:
		if voet.y < float(k["onder"]) - 0.4 or voet.y > float(k["boven"]) - 0.4:
			continue
		var p := _dichtbij(k)
		var naar := p - Vector3(voet.x, 0, voet.z)
		var d := naar.length()
		if d > 0.8:
			continue
		var kant: Vector3 = k["kant"]
		var van_ding := -naar.normalized() if d > 0.01 else -r
		if kant != Vector3.ZERO:
			if van_ding.dot(kant) < 0.1:
				continue
			van_ding = kant
		if d > 0.05 and r.dot(naar / d) < 0.3:
			continue
		_begin_klimmen(k, van_ding)
		return


func _begin_klimmen(k: Dictionary, kant: Vector3) -> void:
	staat = "klimmen"
	_klim = k
	_klim_kant = Vector3(kant.x, 0, kant.z).normalized()
	var zij: Vector3 = k["zij"]
	_klim_langs = 0.0
	if zij != Vector3.ZERO:
		var rel := global_position - (k["pos"] as Vector3)
		_klim_langs = clampf(Vector3(rel.x, 0, rel.z).dot(zij), -float(k["breed"]) + 0.2, float(k["breed"]) - 0.2)
	velocity = Vector3.ZERO


# Vanaf een platform naar beneden: E bij de bovenkant van een touw of net.
func klim_omlaag_mogelijk() -> Dictionary:
	if staat != "lopen" or not is_on_floor():
		return {}
	for k in bouw.klimdingen:
		var boven: float = k["boven"]
		if absf(global_position.y - boven) > 0.9 or boven - float(k["onder"]) < 1.2:
			continue
		var p := _dichtbij(k)
		var d := Vector2(global_position.x - p.x, global_position.z - p.z).length()
		if d < 1.6:
			return k
	return {}


func klim_omlaag(k: Dictionary) -> void:
	var kant: Vector3 = k["kant"]
	if kant == Vector3.ZERO:
		var over: Vector3 = k["over"]
		kant = -over.normalized() if over != Vector3.ZERO else -vooruit()
	_begin_klimmen(k, kant)
	global_position.y = float(k["boven"]) - 0.3


func _klimmen(delta: float) -> void:
	if not is_instance_valid(_klim["stuk"]) or not bouw.klimdingen.has(_klim):
		_stop_klimmen(Vector3.ZERO)
		return
	var op := Input.get_axis("achter", "voor")
	var opzij := Input.get_axis("links", "rechts")
	var zij: Vector3 = _klim["zij"]
	var y := global_position.y + op * KLIM_SNELHEID * delta
	if zij != Vector3.ZERO:
		# Op een net kun je ook opzij klimmen. Rechts op het scherm is, als je
		# naar het net kijkt, de kant van -zij of +zij afhankelijk van de kijkrichting.
		var teken := signf(rechts().dot(zij))
		_klim_langs = clampf(_klim_langs + opzij * teken * 1.8 * delta, -float(_klim["breed"]) + 0.15, float(_klim["breed"]) - 0.15)
	var pos: Vector3 = _klim["pos"]
	var p := pos + zij * _klim_langs + _klim_kant * 0.38
	var onder: float = _klim["onder"]
	var boven: float = _klim["boven"]
	if y <= onder and op < 0:
		global_position = Vector3(p.x, onder, p.z)
		_stop_klimmen(_klim_kant * 1.0)
		return
	if y >= boven + 0.3:
		# Bovenaan: kijk of er iets is om op te staan (platform, plank...).
		var over: Vector3 = _klim["over"]
		var doel := Vector3(p.x, boven + 0.3, p.z) + over
		var q := PhysicsRayQueryParameters3D.create(doel + Vector3(0, 0.8, 0), doel + Vector3(0, -1.6, 0), 1 | 4)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			global_position = (hit["position"] as Vector3) + Vector3(0, 0.05, 0)
			_stop_klimmen(Vector3.ZERO)
			melding.emit("Boven!")
			return
		y = boven + 0.3
	global_position = Vector3(p.x, maxf(y, onder), p.z)
	_kijk_naar(-_klim_kant, delta, 20.0)
	if absf(op) > 0.1 or absf(opzij) > 0.1:
		_animeer(delta, "klimmen", 7.0)
	if Input.is_action_just_pressed("springen"):
		_stop_klimmen(_klim_kant * 4.0 + Vector3(0, 4.0, 0))


func _stop_klimmen(snelheid: Vector3) -> void:
	staat = "lopen"
	velocity = snelheid
	_klim = {}
	_klim_pauze = 0.5


# ------------------------------------------------------------------ parcours
#
# Vrij rondlopen op een smal parcours in de lucht is lastig: één stapje mis en
# je valt. Daarom helpt het spel je:
#  - van een platform val je niet af; je blijft binnen de rand, behalve waar
#    een brug begint;
#  - druk je ongeveer richting een brug, dan stuur je er vanzelf naartoe;
#  - op een brug loop je als op een rail: vooruit of achteruit, en de camera
#    draait rustig mee in je looprichting.

var _br: Dictionary
var _br_t := 0.0
var _br_zij := 0.0
var _hop := 0.0
var _hop_v := 0.0
var _aan_rand := 0.0      # > 0: je staat net tegen de rand van een platform
var _rand_uit := Vector3.ZERO
var _vrij := 0.0          # > 0: je sprong bewust van het platform af


static func _vlak(v: Vector3) -> Vector3:
	v.y = 0
	return v.normalized() if v.length() > 0.0001 else Vector3.ZERO


func _platform_onder() -> Node3D:
	var pos := global_position
	for pl in bouw.platforms:
		var c: Vector3 = pl.get_meta("midden")
		if pos.y < c.y - 0.25 or pos.y > c.y + 2.5:
			continue
		if Vector2(pos.x - c.x, pos.z - c.z).length() <= float(pl.get_meta("straal")) + 0.05:
			return pl
	return null


# Alle uiteinden van bruggen: waar ze liggen en welke kant "de brug op" is.
func _brug_einden() -> Array:
	var uit := []
	for br in bouw.bruggen:
		var a: Vector3 = br["a"]
		var b: Vector3 = br["b"]
		uit.append({"br": br, "t": 0.0, "p": a, "op": _vlak(b - a)})
		uit.append({"br": br, "t": 1.0, "p": b, "op": _vlak(a - b)})
	return uit


var _stuur_doel: Dictionary = {}


func _stuur(r: Vector3) -> Vector3:
	var pl := _platform_onder()
	if r.length() < 0.1 or pl == null:
		_stuur_doel = {}
		return r
	var c: Vector3 = pl.get_meta("midden")
	var straal: float = pl.get_meta("straal")
	var richting := r.normalized()
	# Houd een gekozen brug vast zolang je ongeveer die kant op blijft lopen,
	# anders gaat het poppetje heen en weer twijfelen.
	if not _stuur_doel.is_empty() and bouw.bruggen.has(_stuur_doel["br"]):
		if richting.dot(_vlak((_stuur_doel["p"] as Vector3) - global_position)) < -0.1:
			_stuur_doel = {}
	else:
		_stuur_doel = {}
	if _stuur_doel.is_empty():
		var beste := 0.55
		for e in _brug_einden():
			var p: Vector3 = e["p"]
			if absf(p.y - c.y) > 0.4 or absf(Vector2(p.x - c.x, p.z - c.z).length() - straal) > 0.4:
				continue
			# Kijk naar de richting vanaf het midden: zo telt waar de brug zit,
			# niet waar je toevallig staat.
			var dot := richting.dot(_vlak(p - c))
			if dot > beste:
				beste = dot
				_stuur_doel = e
	if _stuur_doel.is_empty():
		return r
	var doel: Vector3 = _stuur_doel["p"]
	var naar := doel - global_position
	naar.y = 0
	if naar.length() < 0.3:
		return (_stuur_doel["op"] as Vector3) * r.length()
	var mik := naar.normalized()
	# Staat de stam in de weg? Loop er dan omheen.
	var boom: int = pl.get_meta("boom")
	var rs := bos.stam_straal(boom, c.y) + 0.55
	var w := Vector3(c.x - global_position.x, 0, c.z - global_position.z)
	var proj := clampf(w.dot(naar) / naar.length_squared(), 0.0, 1.0)
	var dichtst := Vector3(global_position.x, 0, global_position.z) + naar * proj
	if proj > 0.0 and proj < 1.0 and dichtst.distance_to(Vector3(c.x, 0, c.z)) < rs:
		var weg := _vlak(global_position - c)
		var om := Vector3(-weg.z, 0, weg.x)
		if om.dot(mik) < 0:
			om = -om
		mik = (om + weg * 0.3).normalized()
	return mik * r.length()


func aan_de_rand() -> bool:
	return _aan_rand > 0.0 and staat == "lopen"


func _houd_op_platform() -> void:
	var pl := _platform_onder()
	if pl == null or _vrij > 0.0:
		return
	var c: Vector3 = pl.get_meta("midden")
	var rel := global_position - c
	rel.y = 0
	var max_r: float = float(pl.get_meta("straal")) - 0.3
	if rel.length() <= max_r:
		return
	# Vlak bij het begin van een brug mag je wel naar de rand.
	for e in _brug_einden():
		var p: Vector3 = e["p"]
		if Vector2(global_position.x - p.x, global_position.z - p.z).length() < 1.0 and absf(p.y - c.y) < 0.4:
			return
	var n := rel.normalized()
	global_position = Vector3(c.x, global_position.y, c.z) + n * max_r
	_aan_rand = 0.35
	_rand_uit = n
	var naar_buiten := velocity.x * n.x + velocity.z * n.z
	if naar_buiten > 0:
		velocity.x -= n.x * naar_buiten
		velocity.z -= n.z * naar_buiten


func _probeer_brug(r: Vector3) -> bool:
	if r.length() < 0.1:
		return false
	var richting := r.normalized()
	for e in _brug_einden():
		var p: Vector3 = e["p"]
		if Vector2(global_position.x - p.x, global_position.z - p.z).length() > 0.8 or absf(global_position.y - p.y) > 0.7:
			continue
		if richting.dot(e["op"]) < 0.3:
			continue
		staat = "brug"
		_br = e["br"]
		_br_t = 0.02 if float(e["t"]) == 0.0 else 0.98
		_br_zij = 0.0
		_hop = 0.0
		_hop_v = 0.0
		velocity = Vector3.ZERO
		return true
	return false


func _brug(delta: float) -> void:
	if not is_instance_valid(_br["stuk"]) or not bouw.bruggen.has(_br):
		staat = "lopen"
		return
	var a: Vector3 = _br["a"]
	var b: Vector3 = _br["b"]
	var zak: float = _br["zak"]
	var l: float = _br["l"]
	var t := clampf(_br_t, 0.0, 1.0)
	var langs := _vlak(Bouw.boog(a, b, zak, minf(t + 0.01, 1.0)) - Bouw.boog(a, b, zak, maxf(t - 0.01, 0.0)))
	var zij := Vector3.UP.cross(langs).normalized()
	var r := _invoer()
	var v := r.dot(langs)
	var stap := 0.0
	if absf(v) > 0.2:
		stap = signf(v) * SNELHEID * 0.85 * minf(1.0, absf(v) * 1.4) * delta
	_br_t += stap / maxf(l, 0.1)
	var opzij := r.dot(zij)
	if absf(opzij) > 0.2:
		_br_zij = clampf(_br_zij + opzij * delta * 1.2, -0.25, 0.25)
	else:
		_br_zij = move_toward(_br_zij, 0.0, delta * 0.3)
	if Input.is_action_just_pressed("springen") and _hop <= 0.0:
		_hop_v = 4.5
	_hop_v -= ZWAARTE * delta
	_hop = maxf(_hop + _hop_v * delta, 0.0)
	if _hop <= 0.0:
		_hop_v = 0.0

	if _br_t < 0.0 or _br_t > 1.0:
		# Van de brug af, het platform (of de grond) op.
		var eind := a if _br_t < 0.0 else b
		var verder := _vlak(a - b) if _br_t < 0.0 else _vlak(b - a)
		global_position = eind + verder * 0.55 + Vector3(0, 0.05, 0)
		velocity = verder * 2.0
		staat = "lopen"
		_br = {}
		return

	var wiebel := 0.0
	if zak > l * 0.04 and stap != 0.0:
		wiebel = sin(Time.get_ticks_msec() * 0.012) * 0.025
	global_position = Bouw.boog(a, b, zak, _br_t) + zij * _br_zij + Vector3(0, 0.02 + _hop + wiebel, 0)
	velocity = Vector3.ZERO
	if stap != 0.0:
		var looprichting := langs * signf(stap)
		_kijk_naar(looprichting, delta)
		_animeer(delta, "lopen", 8.0)
		# De camera draait rustig mee als je vooruit loopt.
		if Input.is_action_pressed("voor") and not Input.is_action_pressed("achter"):
			yaw = lerp_angle(yaw, atan2(-looprichting.x, -looprichting.z), clampf(delta * 2.2, 0.0, 1.0))
	else:
		_animeer(delta, "stil", 0.0)


# ------------------------------------------------------------------ tokkelen

func tokkel_mogelijk() -> Dictionary:
	if staat != "lopen":
		return {}
	for t in bouw.tokkels:
		var a: Vector3 = t["a"]
		var voet := a - Vector3(0, Bouw.KABEL_HOOGTE, 0)
		if absf(global_position.y - voet.y) < 1.3 and Vector2(global_position.x - a.x, global_position.z - a.z).length() < 2.0:
			return t
	return {}


func begin_tokkelen(t: Dictionary) -> void:
	staat = "tokkelen"
	_tokkel = t
	_tok_s = 0.3
	_tok_v = 2.5
	model.stoeltje.visible = true
	melding.emit("Wiiiiee!")


func _tokkelen(delta: float) -> void:
	if not is_instance_valid(_tokkel["stuk"]):
		_stop_tokkelen()
		return
	var a: Vector3 = _tokkel["a"]
	var b: Vector3 = _tokkel["b"]
	var l := a.distance_to(b)
	var helling := (a.y - b.y) / maxf(l, 0.1)
	_tok_v = clampf(_tok_v + (9.8 * helling + 2.0) * delta, 3.5, 14.0)
	_tok_s += _tok_v * delta
	var t := clampf(_tok_s / l, 0.0, 1.0)
	var kabel := Bouw.boog(a, b, l * 0.02, t)
	global_position = kabel - Vector3(0, 2.15, 0)
	var r := (b - a)
	_kijk_naar(r, delta, 20.0)
	_animeer(delta, "tokkelen", 3.0)
	if _tok_s >= l - 0.35:
		var r2 := Vector3(r.x, 0, r.z).normalized()
		global_position = b - Vector3(0, Bouw.KABEL_HOOGTE - 0.15, 0) + r2 * 0.7
		velocity = r2 * 2.5
		_stop_tokkelen()
		melding.emit("Geland!")
	elif Input.is_action_just_pressed("springen"):
		velocity = (b - a).normalized() * _tok_v * 0.5
		_stop_tokkelen()


func _stop_tokkelen() -> void:
	staat = "lopen"
	_tokkel = {}
	model.stoeltje.visible = false


# ------------------------------------------------------------------ camera

func draai_camera(dx: float, dy: float) -> void:
	yaw -= dx * 0.006
	pitch = clampf(pitch - dy * 0.005, -1.25, 1.2)


func zoom(stap: float) -> void:
	afstand = clampf(afstand + stap, 2.2, 11.0)


func _camera_volgen(delta: float) -> void:
	var doel := global_position + Vector3(0, 1.25, 0)
	draaipunt.global_position = draaipunt.global_position.lerp(doel, clampf(delta * 14.0, 0, 1))
	draaipunt.rotation = Vector3(pitch, yaw, 0)
	arm.spring_length = afstand
	# Kijk je omhoog (naar je plan in de lucht), dan zakt de camera tot bij de
	# grond en zou je tegen de achterkant van het poppetje aankijken.
	model.visible = pitch < 0.45 or staat != "lopen"
