class_name Pad
extends RefCounted

# De Express-knop: zoekt in je schets de getekende weg tussen twee punten en
# maakt daar een rij bomen van. Elke lijn wordt in stapjes van ongeveer een
# meter opgeknipt; stapjes van dezelfde lijn zijn verbonden, en stapjes van
# verschillende lijnen die vlak bij elkaar liggen ook (zo mag je lijn uit
# losse streepjes bestaan). Daarna gewoon de kortste weg zoeken.

const STAP := 1.0
const SPRONG := 2.2
const ZOEK := 9.0


static func soort_voor(kleur: int) -> String:
	if kleur < 0:
		return "brug"
	var naam: String = Schets.KLEUREN[kleur][0]
	if naam in ["blauw", "paars"]:
		return "tokkelbaan"
	if naam in ["rood", "oranje", "roze"]:
		return "touwbrug"
	return "brug"


# Geeft [{boom, soort}] terug: de eerste boom heeft geen verbinding nodig.
static func bomen_rij(lijnen: Array, bos: Bos, a: Vector3, b: Vector3, boom_a: int, boom_b: int) -> Array:
	var route := _route(lijnen, a, b)
	var volgens_schets := not route.is_empty()
	if route.is_empty():
		route = [{"p": Vector2(a.x, a.z), "k": -1}, {"p": Vector2(b.x, b.z), "k": -1}]

	var rij := [{"boom": boom_a, "soort": ""}]
	for i in range(route.size() - 1):
		var p0: Vector2 = route[i]["p"]
		var p1: Vector2 = route[i + 1]["p"]
		var n := maxi(1, int(p0.distance_to(p1) / 0.7))
		for j in n:
			var q := p0.lerp(p1, float(j + 1) / n)
			var boom := bos.dichtste_boom(Vector3(q.x, 0, q.y), 4.2)
			if boom < 0 or boom == rij[rij.size() - 1]["boom"]:
				continue
			_voeg_toe(rij, boom, soort_voor(int(route[i + 1]["k"])))
	if rij[rij.size() - 1]["boom"] != boom_b:
		var k := int(route[route.size() - 1]["k"])
		_voeg_toe(rij, boom_b, soort_voor(k))
	return [rij, volgens_schets]


static func _voeg_toe(rij: Array, boom: int, soort: String) -> void:
	# Kom je een boom voor de tweede keer tegen (een lusje), knip de lus eruit.
	for i in rij.size():
		if rij[i]["boom"] == boom:
			rij.resize(i + 1)
			return
	rij.append({"boom": boom, "soort": soort})


static func _route(lijnen: Array, a: Vector3, b: Vector3) -> Array:
	var punten: Array[Vector2] = []
	var kleur: Array[int] = []
	var buren: Array = []
	for l in lijnen:
		var pts: PackedVector2Array = l["p"]
		var vorige := -1
		var laatste := Vector2.INF
		for i in pts.size():
			var w := Schets.papier_naar_wereld(pts[i])
			var q := Vector2(w.x, w.z)
			if laatste != Vector2.INF and q.distance_to(laatste) < STAP and i < pts.size() - 1:
				continue
			punten.append(q)
			kleur.append(int(l["k"]))
			buren.append([])
			var nu := punten.size() - 1
			if vorige >= 0:
				buren[nu].append([vorige, q.distance_to(punten[vorige])])
				buren[vorige].append([nu, q.distance_to(punten[vorige])])
			vorige = nu
			laatste = q
	if punten.is_empty():
		return []

	# Losse lijnen die elkaar (bijna) raken, ook verbinden.
	var raster := {}
	for i in punten.size():
		var c := Vector2i(floori(punten[i].x / SPRONG), floori(punten[i].y / SPRONG))
		if not raster.has(c):
			raster[c] = []
		raster[c].append(i)
	for i in punten.size():
		var c := Vector2i(floori(punten[i].x / SPRONG), floori(punten[i].y / SPRONG))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for j in raster.get(c + Vector2i(dx, dz), []):
					if j <= i:
						continue
					var d := punten[i].distance_to(punten[j])
					if d < SPRONG:
						buren[i].append([j, d * 1.3 + 0.3])
						buren[j].append([i, d * 1.3 + 0.3])

	var start := _dichtste(punten, Vector2(a.x, a.z))
	var eind := _dichtste(punten, Vector2(b.x, b.z))
	if start < 0 or eind < 0:
		return []

	# Dijkstra met een eenvoudige hoop.
	var afstand := PackedFloat64Array()
	afstand.resize(punten.size())
	afstand.fill(INF)
	var vorig := PackedInt32Array()
	vorig.resize(punten.size())
	vorig.fill(-1)
	afstand[start] = 0.0
	var hoop := [[0.0, start]]
	while not hoop.is_empty():
		var top: Array = _pak(hoop)
		var u: int = top[1]
		if top[0] > afstand[u]:
			continue
		if u == eind:
			break
		for buur in buren[u]:
			var v: int = buur[0]
			var nd: float = afstand[u] + float(buur[1])
			if nd < afstand[v]:
				afstand[v] = nd
				vorig[v] = u
				_duw(hoop, [nd, v])
	if afstand[eind] == INF:
		return []
	var weg := []
	var u := eind
	while u >= 0:
		weg.push_front({"p": punten[u], "k": kleur[u]})
		u = vorig[u]
	weg.push_front({"p": Vector2(a.x, a.z), "k": kleur[start]})
	weg.append({"p": Vector2(b.x, b.z), "k": kleur[eind]})
	return weg


static func _dichtste(punten: Array[Vector2], p: Vector2) -> int:
	var beste := -1
	var best_d := ZOEK
	for i in punten.size():
		var d := punten[i].distance_to(p)
		if d < best_d:
			best_d = d
			beste = i
	return beste


static func _duw(hoop: Array, item: Array) -> void:
	hoop.append(item)
	var i := hoop.size() - 1
	while i > 0:
		var ouder := (i - 1) / 2
		if hoop[ouder][0] <= hoop[i][0]:
			break
		var t = hoop[ouder]
		hoop[ouder] = hoop[i]
		hoop[i] = t
		i = ouder


static func _pak(hoop: Array) -> Array:
	var top: Array = hoop[0]
	var laatste: Array = hoop.pop_back()
	if hoop.is_empty():
		return top
	hoop[0] = laatste
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var k := i
		if l < hoop.size() and hoop[l][0] < hoop[k][0]:
			k = l
		if r < hoop.size() and hoop[r][0] < hoop[k][0]:
			k = r
		if k == i:
			break
		var t = hoop[k]
		hoop[k] = hoop[i]
		hoop[i] = t
		i = k
	return top
