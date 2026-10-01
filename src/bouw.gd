class_name Bouw
extends Node3D

# Alles wat je in de bomen kunt bouwen. Elk gebouwd ding is een "stuk": een
# Node3D met één samengevoegde mesh, botsvormen om op te lopen en (voor dingen
# waar je niet op loopt, zoals touwen) een onzichtbaar klik-lichaam zodat je
# het met de sloophamer weer kunt weghalen.
#
# Een bouwplan is een Dictionary. `plan()` maakt er een uit waar je met de muis
# naar wijst; `maak()` bouwt het. Het spookbeeld (de doorzichtige voorvertoning)
# gebruikt precies dezelfde bouwcode, zodat wat je ziet ook is wat je krijgt.

const LAAG_STUK := 4
const LAAG_KLIK := 32

const SOORTEN := ["plank", "platform", "brug", "touwbrug", "klimtouw", "klimhaken", "klimnet", "tokkelbaan", "sloop"]
const NAMEN := ["Plank", "Platform", "Brug", "Touwbrug", "Klimtouw", "Klimhaken", "Klimnet", "Tokkelbaan", "Afbreken"]
const TWEE_KLIKKEN := ["brug", "touwbrug", "tokkelbaan"]
const KABEL_HOOGTE := 2.4
const EXPRESS_HOOGTE := 4.5

const HOUT := Color(0.9, 0.66, 0.42)
const HOUT_DONKER := Color(0.68, 0.45, 0.28)
const TOUW := Color(0.96, 0.87, 0.66)
const ROOD := Color(0.94, 0.34, 0.3)
const STAAL := Color(0.5, 0.53, 0.6)
const GREEP_KLEUREN := [Color(1.0, 0.45, 0.62), Color(1.0, 0.82, 0.25), Color(0.35, 0.7, 1.0), Color(0.45, 0.86, 0.42), Color(0.76, 0.52, 1.0), Color(1.0, 0.56, 0.25)]

var bos: Bos
# Dingen waar je in kunt klimmen. Elk: {stuk, pos, boven, onder, zij, breed, kant, over}
var klimdingen: Array = []
# Tokkelbanen: {stuk, a, b} (a en b zijn de kabelpunten)
var tokkels: Array = []
# Bruggen om over te lopen: {stuk, a, b, zak, l}. De speler loopt erover als
# over een rail (zie Speler._brug), dus je kunt er nooit naast stappen.
var bruggen: Array = []
var platforms: Array = []

var _spook_goed: StandardMaterial3D
var _spook_fout: StandardMaterial3D
var _rood_mat: StandardMaterial3D


func _ready() -> void:
	_spook_goed = _spook_mat(Color(0.55, 1.0, 0.6, 0.45))
	_spook_fout = _spook_mat(Color(1.0, 0.4, 0.38, 0.4))
	_rood_mat = _spook_mat(Color(1.0, 0.3, 0.25, 0.6))


func _spook_mat(k: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = k
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_receive_shadows = true
	return m


# ================================================================== plannen

func plan(soort: String, hit: Dictionary, cam_pos: Vector3, eerste: Dictionary) -> Dictionary:
	if hit.is_empty():
		return _fout("")
	match soort:
		"plank":
			return _plan_plank(hit, cam_pos)
		"platform":
			return _plan_platform(hit)
		"klimhaken":
			return _plan_haken(hit)
		"klimtouw", "klimnet":
			return _plan_hang(soort, hit, cam_pos)
		"brug", "touwbrug", "tokkelbaan":
			return _plan_twee(soort, hit, eerste)
		"sloop":
			if hit["stuk"] != null:
				return {"ok": true, "soort": "sloop", "stuk": hit["stuk"]}
			return _fout("Klik met rechts op iets wat je gebouwd hebt om het af te breken.")
	return _fout("")


func _fout(reden: String) -> Dictionary:
	return {"ok": false, "reden": reden}


func _vlak(v: Vector3) -> Vector3:
	v.y = 0
	if v.length() < 0.001:
		return Vector3(0, 0, 1)
	return v.normalized()


func _plan_plank(hit: Dictionary, cam_pos: Vector3) -> Dictionary:
	var p: Vector3 = hit["punt"]
	var n: Vector3 = hit["normaal"]
	if n.y > 0.6:
		var kijk := _vlak(p - cam_pos)
		var hoek := snappedf(atan2(kijk.x, kijk.z), PI / 4.0)
		var r := Vector3(sin(hoek), 0, cos(hoek))
		return {"ok": true, "soort": "plank", "pos": p + Vector3(0, -0.045, 0), "richting": r}
	if absf(n.y) <= 0.6:
		var r := _vlak(n)
		return {"ok": true, "soort": "plank", "pos": p + r * 1.1 + Vector3(0, -0.045, 0), "richting": r}
	return _fout("Een plank leg je óp iets, of je zet hem tegen een boomstam.")


func platform_bij(boom: int, h: float, marge: float) -> Node3D:
	var beste: Node3D = null
	var best_d := marge
	for pl in platforms:
		if int(pl.get_meta("boom")) == boom:
			var d := absf(float(pl.get_meta("hoogte")) - h)
			if d < best_d:
				best_d = d
				beste = pl
	return beste


func _plan_platform(hit: Dictionary) -> Dictionary:
	var i: int = hit["boom"]
	if i < 0:
		return _fout("Klik met rechts op een boomstam om er een platform omheen te bouwen.")
	var h: float = hit["punt"].y
	if h < 0.8:
		return _fout("Klik wat hoger op de stam.")
	if h > float(bos.bomen[i]["h"]) - 2.6:
		return _fout("Zo hoog kan niet: daar zitten de bladeren.")
	if platform_bij(i, h, 1.8) != null:
		return _fout("Hier zit al een platform.")
	return {"ok": true, "soort": "platform", "boom": i, "h": h}


func _plan_haken(hit: Dictionary) -> Dictionary:
	var i: int = hit["boom"]
	if i < 0:
		return _fout("Klimhaken zet je op een boomstam. Klik op de hoogte waar je naartoe wilt klimmen.")
	var p: Vector3 = hit["punt"]
	var c := bos.boom_pos(i)
	var h := p.y
	# Zit er een platform in de buurt, dan gaan de haken precies tot daar.
	var pl := platform_bij(i, h, 2.0)
	if pl != null:
		h = float(pl.get_meta("hoogte"))
	if h < 1.0:
		return _fout("Klik wat hoger op de stam.")
	if h > float(bos.bomen[i]["h"]) - 2.6:
		return _fout("Zo hoog kan niet: daar zitten de bladeren.")
	return {"ok": true, "soort": "klimhaken", "boom": i, "h": h, "d": _vlak(p - c)}


func _plan_hang(soort: String, hit: Dictionary, cam_pos: Vector3) -> Dictionary:
	var p: Vector3 = hit["punt"]
	var n: Vector3 = hit["normaal"]
	var stuk: Node3D = hit["stuk"]
	var top: Vector3
	var kant: Vector3
	var over := Vector3.ZERO
	if hit["boom"] >= 0:
		var i: int = hit["boom"]
		var c := bos.boom_pos(i)
		kant = _vlak(p - c)
		top = c + kant * (bos.stam_straal(i, p.y) + 0.1)
		top.y = p.y
	elif stuk != null and stuk.get_meta("soort") == "platform":
		var c: Vector3 = stuk.get_meta("midden")
		kant = _vlak(cam_pos - c)
		top = c + kant * (float(stuk.get_meta("straal")) + 0.08) + Vector3(0, -0.1, 0)
		over = -kant * 1.1
	elif stuk != null:
		if absf(n.y) <= 0.6:
			kant = _vlak(n)
			top = p + kant * 0.08
			over = -kant * 0.9
		else:
			kant = _vlak(cam_pos - p)
			top = p + Vector3(0, -0.1 if n.y > 0 else 0.0, 0)
	else:
		return _fout("Hang het aan een boomstam, of aan iets wat je gebouwd hebt.")
	if top.y < 1.3:
		return _fout("Hang het wat hoger op.")
	var onder := _grond_onder(top + kant * 0.35 + Vector3(0, -0.3, 0))
	if top.y - onder < 1.0:
		return _fout("Er is hier te weinig ruimte onder.")
	return {"ok": true, "soort": soort, "top": top, "onder": onder, "kant": kant, "over": over, "boom": hit["boom"]}


func _grond_onder(van: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(van, van + Vector3(0, -40, 0), 1 | LAAG_STUK)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return 0.0
	return (r["position"] as Vector3).y


# Wat er precies aangeklikt is, voor dingen die je met twee klikken bouwt.
func klik_van(hit: Dictionary) -> Dictionary:
	var stuk: Node3D = hit["stuk"]
	var p: Vector3 = hit["punt"]
	if stuk != null and stuk.get_meta("soort") == "platform":
		return {"boom": int(stuk.get_meta("boom")), "platform": stuk, "punt": p}
	if hit["boom"] >= 0:
		var i: int = hit["boom"]
		return {"boom": i, "platform": platform_bij(i, p.y, 1.5), "punt": p}
	return {"boom": -1, "platform": null, "punt": p}


func anker(k: Dictionary, ander: Vector3) -> Vector3:
	var pl: Node3D = k["platform"]
	if pl != null and is_instance_valid(pl):
		var c: Vector3 = pl.get_meta("midden")
		return c + _vlak(ander - c) * float(pl.get_meta("straal"))
	if k["boom"] >= 0:
		var i: int = k["boom"]
		var p: Vector3 = k["punt"]
		var c := bos.boom_pos(i)
		c.y = p.y
		return c + _vlak(ander - c) * (bos.stam_straal(i, p.y) + 0.05)
	return k["punt"]


func _plan_twee(soort: String, hit: Dictionary, eerste: Dictionary) -> Dictionary:
	var k := klik_van(hit)
	if eerste.is_empty():
		return {"ok": true, "soort": soort, "stap": 1, "klik": k, "punt": k["punt"]}
	var b := anker(k, eerste["punt"])
	var a := anker(eerste, b)
	b = anker(k, a)
	var l := a.distance_to(b)
	if eerste["boom"] >= 0 and eerste["boom"] == k["boom"]:
		return _fout("Kies voor het eindpunt een andere boom.")
	if l < 1.5:
		return _fout("Dat is te kort. Kies een punt verder weg.")
	if l > (45.0 if soort == "tokkelbaan" else 30.0):
		return _fout("Dat is te ver. Kies een punt dichterbij.")
	if soort != "tokkelbaan" and absf(a.y - b.y) > l * 0.6:
		return _fout("Te steil om over te lopen.")
	return {"ok": true, "soort": soort, "stap": 2, "a": a, "b": b}


# ================================================================== bouwen

func maak(p: Dictionary, spook := false, goed := true, pop := true) -> Node3D:
	var soort: String = p["soort"]
	if soort == "sloop":
		sloop(p["stuk"])
		return null
	var stuk := Node3D.new()
	var b := Vorm.Bouwer.new()
	var vormen := []      # [Shape3D, Transform3D] om op te lopen
	var klikvormen := []  # alleen om aan te klikken
	var o := Vector3.ZERO
	var klim := {}
	match soort:
		"plank":
			o = _bouw_plank(b, vormen, p)
		"platform":
			o = _bouw_platform(b, vormen, p, stuk)
		"brug":
			o = _bouw_brug(b, vormen, p, false)
		"touwbrug":
			o = _bouw_brug(b, vormen, p, true)
		"tokkelbaan":
			o = _bouw_tokkel(b, vormen, klikvormen, p)
		"klimtouw":
			o = p["top"]
			klim = _bouw_touw(b, klikvormen, p)
		"klimnet":
			o = p["top"]
			klim = _bouw_net(b, klikvormen, p)
		"klimhaken":
			klim = _bouw_haken(b, klikvormen, p)
			o = klim["pos"]
			stuk.set_meta("boom", p["boom"])

	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.position = -o
	stuk.add_child(mi)
	stuk.position = o
	stuk.set_meta("soort", soort)
	if spook:
		mi.material_override = _spook_goed if goed else _spook_fout
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stuk)
		return stuk

	# Het bouwplan bewaren we bij het stuk: zo kan het spel later opgeslagen
	# en precies zo weer opgebouwd worden.
	stuk.set_meta("plan", p.duplicate(true))
	_lichaam(stuk, vormen, LAAG_STUK, o)
	_lichaam(stuk, klikvormen, LAAG_KLIK, o)
	add_child(stuk)
	if soort == "platform":
		platforms.append(stuk)
	if not klim.is_empty():
		klim["stuk"] = stuk
		klimdingen.append(klim)
	if soort == "brug" or soort == "touwbrug":
		var a: Vector3 = p["a"]
		var e: Vector3 = p["b"]
		var l := a.distance_to(e)
		bruggen.append({"stuk": stuk, "a": a, "b": e, "zak": brug_zak(l, soort == "touwbrug"), "l": l})
	if soort == "tokkelbaan":
		var a: Vector3 = p["a"]
		var e: Vector3 = p["b"]
		tokkels.append({"stuk": stuk, "a": a + Vector3.UP * KABEL_HOOGTE, "b": e + Vector3.UP * KABEL_HOOGTE})
	if pop:
		stuk.scale = Vector3.ONE * 0.05
		var tw := stuk.create_tween()
		tw.tween_property(stuk, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return stuk


func _lichaam(stuk: Node3D, vormen: Array, laag: int, o: Vector3) -> void:
	if vormen.is_empty():
		return
	var body := StaticBody3D.new()
	body.collision_layer = laag
	body.collision_mask = 0
	body.set_meta("stuk", stuk)
	body.position = -o
	for v in vormen:
		var cs := CollisionShape3D.new()
		cs.shape = v[0]
		cs.transform = v[1]
		body.add_child(cs)
	stuk.add_child(body)


func _doos(maat: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = maat
	return s


func _bouw_plank(b: Vorm.Bouwer, vormen: Array, p: Dictionary) -> Vector3:
	var pos: Vector3 = p["pos"]
	var bas := Vorm.plankstand(p["richting"])
	var maat := Vector3(0.5, 0.09, 2.2)
	b.blok(maat, pos, Vorm.kleur_rond(HOUT, 0.07), bas)
	b.blok(Vector3(0.52, 0.02, 0.06), pos + bas.z * 0.7 + bas.y * 0.046, HOUT_DONKER, bas)
	b.blok(Vector3(0.52, 0.02, 0.06), pos - bas.z * 0.7 + bas.y * 0.046, HOUT_DONKER, bas)
	for e in [-0.95, 0.95]:
		for s in [-0.15, 0.15]:
			b.bol(0.03, pos + bas.z * e + bas.x * s + bas.y * 0.045, STAAL, Vector3(1, 0.5, 1))
	vormen.append([_doos(maat), Transform3D(bas, pos)])
	return pos


func _bouw_platform(b: Vorm.Bouwer, vormen: Array, p: Dictionary, stuk: Node3D) -> Vector3:
	var i: int = p["boom"]
	var h: float = p["h"]
	var c := bos.boom_pos(i)
	var midden := Vector3(c.x, h, c.z)
	var rs := bos.stam_straal(i, h)
	var straal := rs + 1.9
	var draai := Basis(Vector3.UP, fmod(i * 1.7, TAU))
	var rng := RandomNumberGenerator.new()
	rng.seed = i
	# Ronde vloer van planken naast elkaar.
	var z := -straal + 0.21
	while z < straal - 0.1:
		var half := sqrt(maxf(straal * straal - z * z, 0.0))
		if half > 0.2:
			b.blok(Vector3(half * 2.0 - 0.05, 0.1, 0.38), midden + draai * Vector3(0, -0.05, z), Vorm.kleur_rond(HOUT, 0.08, rng), draai)
		z += 0.42
	# Dikke touwrand rondom.
	var n := 20
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		b.staaf(midden + Vector3(cos(a0), 0, sin(a0)) * straal + Vector3(0, -0.06, 0), midden + Vector3(cos(a1), 0, sin(a1)) * straal + Vector3(0, -0.06, 0), 0.065, TOUW)
	# Schoren onder het platform en een rode band om de stam.
	for k in 4:
		var hoek := TAU * k / 4.0 + 0.4
		var d := Vector3(cos(hoek), 0, sin(hoek))
		b.staaf(c + d * rs + Vector3(0, h - 1.7, 0), c + d * straal * 0.72 + Vector3(0, h - 0.12, 0), 0.075, HOUT_DONKER)
		b.blok(Vector3(0.2, 0.22, 0.1), c + d * (rs + 0.03) + Vector3(0, h - 1.7, 0), ROOD, Basis(Vector3.UP, -hoek + PI / 2))
	b.cil(rs + 0.04, rs + 0.04, 0.18, Vector3(c.x, h - 0.22, c.z), ROOD, 14)
	# Vier paaltjes met een bolletje, voor de gezelligheid (je loopt erlangs).
	for k in 4:
		var hoek := TAU * k / 4.0 + fmod(i * 1.7, TAU) + PI / 4.0
		var d := Vector3(cos(hoek), 0, sin(hoek))
		var paal := midden + d * (straal - 0.12)
		b.cil(0.06, 0.05, 0.55, paal + Vector3(0, 0.22, 0), HOUT_DONKER, 6)
		b.bol(0.09, paal + Vector3(0, 0.52, 0), GREEP_KLEUREN[(i + k) % GREEP_KLEUREN.size()])

	var cyl := CylinderShape3D.new()
	cyl.radius = straal
	cyl.height = 0.12
	vormen.append([cyl, Transform3D(Basis(), midden + Vector3(0, -0.06, 0))])
	stuk.set_meta("boom", i)
	stuk.set_meta("hoogte", h)
	stuk.set_meta("straal", straal)
	stuk.set_meta("midden", midden)
	return midden


static func brug_zak(l: float, wiebel: bool) -> float:
	return l * (0.06 if wiebel else 0.025)


static func boog(a: Vector3, e: Vector3, zak: float, t: float) -> Vector3:
	return a.lerp(e, t) - Vector3(0, zak * 4.0 * t * (1.0 - t), 0)


func _bouw_brug(b: Vorm.Bouwer, vormen: Array, p: Dictionary, wiebel: bool) -> Vector3:
	var a: Vector3 = p["a"]
	var e: Vector3 = p["b"]
	var l := a.distance_to(e)
	var zak := brug_zak(l, wiebel)
	var zij := Vector3.UP.cross(_vlak(e - a)).normalized()
	var stap := 0.52 if wiebel else 0.34
	var n := maxi(2, int(l / stap))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(a.x * 13 + a.z * 7)
	for i in n:
		var t := (i + 0.5) / n
		var q := boog(a, e, zak, t)
		var raak := boog(a, e, zak, t + 0.01) - boog(a, e, zak, t - 0.01)
		var bas := Vorm.plankstand(raak)
		var lengte := (l / n) * (0.6 if wiebel else 0.9)
		var scheef := Basis(Vector3.UP, rng.randf_range(-0.05, 0.05)) if wiebel else Basis()
		b.blok(Vector3(1.0, 0.08, lengte), q - bas.y * 0.04, Vorm.kleur_rond(HOUT, 0.09, rng), bas * scheef)
	var segs := clampi(int(l / 0.8), 4, 30)
	for s: float in [-1.0, 1.0]:
		for j in segs:
			var t0 := float(j) / segs
			var t1 := float(j + 1) / segs
			var d0 := boog(a, e, zak, t0)
			var d1 := boog(a, e, zak, t1)
			b.staaf(d0 + zij * s * 0.45 + Vector3(0, -0.08, 0), d1 + zij * s * 0.45 + Vector3(0, -0.08, 0), 0.035, TOUW)
			var l0 := boog(a, e, zak * 0.6, t0) + zij * s * 0.52 + Vector3(0, 0.95, 0)
			var l1 := boog(a, e, zak * 0.6, t1) + zij * s * 0.52 + Vector3(0, 0.95, 0)
			b.staaf(l0, l1, 0.045, TOUW)
			if j > 0:
				b.staaf(l0, d0 + zij * s * 0.48, 0.02, TOUW, 4)
				if wiebel:
					# Kruislings netje aan de zijkant van een touwbrug.
					var m1 := boog(a, e, zak, (t0 + t1) * 0.5) + zij * s * 0.5
					b.staaf(l0 + Vector3(0, -0.3, 0), m1 + Vector3(0, 0.15, 0), 0.015, TOUW, 4)
	# Palen aan beide kanten.
	for q: Vector3 in [a, e]:
		for s: float in [-1.0, 1.0]:
			var paal: Vector3 = q + zij * s * 0.53
			b.cil(0.075, 0.065, 1.15, paal + Vector3(0, 0.5, 0), HOUT_DONKER, 7)
			b.bol(0.1, paal + Vector3(0, 1.1, 0), ROOD)
	# Om op te lopen: per stukje een vloertje plus twee lage wandjes, zodat je
	# er niet zomaar af valt.
	for j in segs:
		var d0 := boog(a, e, zak, float(j) / segs)
		var d1 := boog(a, e, zak, float(j + 1) / segs)
		var mid := (d0 + d1) * 0.5
		var bas := Vorm.plankstand(d1 - d0)
		var sl := d0.distance_to(d1)
		vormen.append([_doos(Vector3(1.0, 0.1, sl + 0.06)), Transform3D(bas, mid - bas.y * 0.05)])
		for s: float in [-1.0, 1.0]:
			vormen.append([_doos(Vector3(0.08, 1.0, sl + 0.02)), Transform3D(bas, mid + zij * s * 0.54 + Vector3(0, 0.5, 0))])
	return a


func _bouw_tokkel(b: Vorm.Bouwer, vormen: Array, klikvormen: Array, p: Dictionary) -> Vector3:
	var a: Vector3 = p["a"]
	var e: Vector3 = p["b"]
	var omhoog := Vector3.UP * KABEL_HOOGTE
	var ka := a + omhoog
	var ke := e + omhoog
	for q: Vector3 in [a, e]:
		var hoogte := KABEL_HOOGTE + 0.3
		b.cil(0.11, 0.09, hoogte, q + Vector3(0, hoogte * 0.5, 0), HOUT_DONKER, 8)
		b.bol(0.15, q + Vector3(0, hoogte + 0.02, 0), ROOD)
		b.blok(Vector3(0.24, 0.12, 0.24), q + Vector3(0, KABEL_HOOGTE, 0), STAAL)
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.1
		cyl.height = hoogte
		vormen.append([cyl, Transform3D(Basis(), q + Vector3(0, hoogte * 0.5, 0))])
	var l := ka.distance_to(ke)
	var zak := l * 0.02
	var segs := clampi(int(l / 1.5), 4, 24)
	for j in segs:
		b.staaf(boog(ka, ke, zak, float(j) / segs), boog(ka, ke, zak, float(j + 1) / segs), 0.028, STAAL, 5)
	# Het touwzadeltje dat bij het begin klaarhangt.
	var r := (ke - ka).normalized()
	var katrol := ka + r * 0.7
	b.bol(0.11, katrol, ROOD, Vector3(1, 1, 0.6), false, Vorm.plankstand(r))
	b.staaf(katrol, katrol + Vector3(0, -1.55, 0), 0.025, TOUW)
	b.cil(0.24, 0.24, 0.07, katrol + Vector3(0, -1.6, 0), ROOD, 12)
	b.cil(0.2, 0.2, 0.08, katrol + Vector3(0, -1.55, 0), Color(1.0, 0.82, 0.3), 12)
	# Onzichtbaar klikvlak langs de kabel.
	var mid := (ka + ke) * 0.5
	klikvormen.append([_doos(Vector3(0.4, 0.4, l)), Transform3D(Vorm.plankstand(ke - ka), mid)])
	return a


func _bouw_touw(b: Vorm.Bouwer, klikvormen: Array, p: Dictionary) -> Dictionary:
	var top: Vector3 = p["top"]
	var onder: float = p["onder"]
	var voet := Vector3(top.x, onder + 0.05, top.z)
	b.staaf(top, voet, 0.045, TOUW, 7)
	var y := top.y - 0.5
	while y > onder + 0.3:
		b.bol(0.09, Vector3(top.x, y, top.z), TOUW, Vector3(1, 0.75, 1))
		y -= 0.55
	b.blok(Vector3(0.18, 0.14, 0.18), top + Vector3(0, 0.02, 0), ROOD)
	klikvormen.append([_doos(Vector3(0.35, top.y - onder, 0.35)), Transform3D(Basis(), (top + voet) * 0.5)])
	return {"pos": top, "boven": top.y, "onder": onder, "zij": Vector3.ZERO, "breed": 0.0, "kant": Vector3.ZERO, "over": p["over"]}


func _bouw_net(b: Vorm.Bouwer, klikvormen: Array, p: Dictionary) -> Dictionary:
	var top: Vector3 = p["top"]
	var onder: float = p["onder"]
	var kant: Vector3 = p["kant"]
	var zij := Vector3.UP.cross(kant).normalized()
	var w := 1.0
	var hoogte := top.y - onder
	b.staaf(top - zij * (w + 0.12), top + zij * (w + 0.12), 0.07, HOUT_DONKER, 7)
	b.blok(Vector3(0.16, 0.16, 0.16), top - zij * (w + 0.12), ROOD)
	b.blok(Vector3(0.16, 0.16, 0.16), top + zij * (w + 0.12), ROOD)
	var kol := 7
	for c in kol + 1:
		var x := -w + 2.0 * w * c / kol
		b.staaf(top + zij * x, Vector3(top.x, onder + 0.05, top.z) + zij * x, 0.025, TOUW, 4)
	var y := top.y - 0.36
	while y > onder + 0.1:
		var m := Vector3(top.x, y, top.z)
		b.staaf(m - zij * w, m + zij * w, 0.025, TOUW, 4)
		y -= 0.36
	klikvormen.append([_doos(Vector3(2.0 * w, hoogte, 0.25)), Transform3D(Basis(zij, Vector3.UP, kant), Vector3(top.x, onder + hoogte * 0.5, top.z))])
	return {"pos": top, "boven": top.y, "onder": onder, "zij": zij, "breed": w, "kant": kant, "over": p["over"]}


func _bouw_haken(b: Vorm.Bouwer, klikvormen: Array, p: Dictionary) -> Dictionary:
	var i: int = p["boom"]
	var h: float = p["h"]
	var d: Vector3 = p["d"]
	var c := bos.boom_pos(i)
	var y := 0.45
	var k := 0
	while y <= h + 0.05:
		var dd := d.rotated(Vector3.UP, 0.24 if k % 2 == 0 else -0.24)
		var rs := bos.stam_straal(i, y)
		var plek := c + dd * (rs + 0.02) + Vector3(0, y, 0)
		b.bol(0.11, plek + dd * 0.03, GREEP_KLEUREN[(k + i) % GREEP_KLEUREN.size()], Vector3(1.25, 0.8, 0.85), false, Basis(Vector3.UP, atan2(dd.x, dd.z)))
		b.bol(0.035, plek + dd * 0.12, STAAL)
		y += 0.42
		k += 1
	var r0 := bos.stam_straal(i, 0.0)
	var zij := Vector3.UP.cross(d).normalized()
	var pos := c + d * (r0 + 0.03)
	klikvormen.append([_doos(Vector3(0.6, h, 0.35)), Transform3D(Basis(zij, Vector3.UP, d), pos + d * 0.1 + Vector3(0, h * 0.5, 0))])
	return {"pos": pos, "boven": h, "onder": 0.0, "zij": zij, "breed": 0.2, "kant": d, "over": Vector3.ZERO, "boom": i}


# ================================================================== opslaan

# Alle bouwplannen, in de volgorde waarin ze gebouwd zijn.
func plannen() -> Array:
	var uit := []
	for kind in get_children():
		if kind.has_meta("plan") and not kind.is_queued_for_deletion():
			uit.append(kind.get_meta("plan"))
	return uit


func wis_alles() -> void:
	markeer(null)
	for kind in get_children():
		if kind.has_meta("soort"):
			remove_child(kind)
			kind.free()
	platforms.clear()
	klimdingen.clear()
	tokkels.clear()
	bruggen.clear()


# ================================================================== afbreken

func sloop(stuk: Node3D) -> void:
	if stuk == null or not is_instance_valid(stuk):
		return
	platforms.erase(stuk)
	klimdingen = klimdingen.filter(func(k): return k["stuk"] != stuk)
	tokkels = tokkels.filter(func(t): return t["stuk"] != stuk)
	bruggen = bruggen.filter(func(b): return b["stuk"] != stuk)
	for kind in stuk.get_children():
		if kind is StaticBody3D:
			kind.queue_free()
	var tw := stuk.create_tween()
	tw.tween_property(stuk, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(stuk.queue_free)


# Laat zien wat de sloophamer zou weghalen.
var _gemarkeerd: Node3D

func markeer(stuk: Node3D) -> void:
	if _gemarkeerd == stuk:
		return
	if _gemarkeerd != null and is_instance_valid(_gemarkeerd):
		for kind in _gemarkeerd.get_children():
			if kind is MeshInstance3D:
				kind.material_overlay = null
	_gemarkeerd = stuk
	if stuk != null:
		for kind in stuk.get_children():
			if kind is MeshInstance3D:
				kind.material_overlay = _rood_mat


# ================================================================== express

# Zet een rij bomen om in een lijst bouwplannen: platforms in elke boom,
# klimhaken omhoog bij de eerste, de juiste verbinding tussen elk paar en een
# klimnet om weer naar beneden te gaan bij de laatste.
func express_plannen(rij: Array, van: Vector3) -> Array:
	var plannen := []
	var info := []
	for j in rij.size():
		var i: int = rij[j]["boom"]
		var c := bos.boom_pos(i)
		var pl := platform_bij(i, EXPRESS_HOOGTE, 1.8)
		var h := EXPRESS_HOOGTE
		var straal := bos.stam_straal(i, h) + 1.9
		if pl != null:
			h = float(pl.get_meta("hoogte"))
			straal = float(pl.get_meta("straal"))
		else:
			plannen.append({"ok": true, "soort": "platform", "boom": i, "h": h})
		var midden := Vector3(c.x, h, c.z)
		info.append({"c": midden, "R": straal})
		if j == 0:
			var d := _vlak(van - c)
			plannen.append({"ok": true, "soort": "klimhaken", "boom": i, "h": h, "d": d})
		else:
			var vorige: Dictionary = info[j - 1]
			var pc: Vector3 = vorige["c"]
			var r := _vlak(midden - pc)
			var a: Vector3 = pc + r * float(vorige["R"])
			var e: Vector3 = midden - r * straal
			if _vlak(e - a).dot(r) > 0.0 and a.distance_to(e) > 0.6:
				plannen.append({"ok": true, "soort": rij[j]["soort"], "a": a, "b": e})
	if info.size() > 0:
		var laatste: Dictionary = info[info.size() - 1]
		var lc: Vector3 = laatste["c"]
		var uit := Vector3(0, 0, 1)
		if info.size() > 1:
			uit = _vlak(lc - (info[info.size() - 2]["c"] as Vector3))
		var top: Vector3 = lc + uit * (float(laatste["R"]) + 0.08) + Vector3(0, -0.1, 0)
		plannen.append({"ok": true, "soort": "klimnet", "top": top, "onder": 0.0, "kant": uit, "over": -uit * 1.1, "boom": -1})
	return plannen
