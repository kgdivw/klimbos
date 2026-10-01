class_name Bos
extends Node3D

# Het megabos. Binnen de muren staan de bomen waar je in kunt bouwen; daarbuiten
# staat een dichte rand van extra bomen zodat je nergens "het einde" ziet.
# Uit het bos gaan kan niet: er staan onzichtbare muren en de speler wordt ook
# nog eens binnen de grenzen gehouden.

const HALF_X := 80.0          # het speelveld loopt van -80 tot 80 (x)
const HALF_Z := 45.0          # en van -45 tot 45 (z) -- precies 16:9, net als het schetspapier
const GRENS := 1.2            # zo ver blijft de speler van de muur
const STUK := 50.0            # bomen worden per stuk van 40 m getekend (zicht-afsnijding)

const LAAG_GROND := 1
const LAAG_BOOM := 2
const LAAG_MUUR := 8

# Elke boom: {"p": Vector3 voet, "r": stamstraal, "h": hoogte van de kruin}
var bomen: Array = []
var _rng := RandomNumberGenerator.new()
var zon: DirectionalLight3D
var deuren: Array = []   # [plek, richting] van de elfendeurtjes (handig om te testen)


func _ready() -> void:
	_rng.seed = 20261001
	_omgeving()
	_grond()
	_plaats_bomen()
	_teken_bomen()
	_versiering()
	_muren()
	_open_plek()


# ------------------------------------------------------------------ licht

func _omgeving() -> void:
	var lucht := ProceduralSkyMaterial.new()
	lucht.sky_top_color = Color(0.36, 0.6, 0.88)
	lucht.sky_horizon_color = Color(1.0, 0.82, 0.62)
	lucht.sky_curve = 0.14
	lucht.ground_horizon_color = Color(0.95, 0.78, 0.56)
	lucht.ground_bottom_color = Color(0.4, 0.34, 0.22)
	lucht.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = lucht

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = false   # kost ~12% op deze laptop en zie je amper
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(1.0, 0.86, 0.68)
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 125.0
	env.fog_depth_curve = 1.4
	env.fog_density = 0.85
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Een lage, warme middagzon: lange zachte schaduwen tussen de bomen.
	zon = DirectionalLight3D.new()
	zon.light_color = Color(1.0, 0.86, 0.66)
	zon.light_energy = 1.45
	zon.rotation_degrees = Vector3(-38, -35, 0)
	zon.shadow_enabled = true
	zon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	zon.directional_shadow_max_distance = 48.0
	zon.shadow_bias = 0.04
	zon.shadow_normal_bias = 0.8
	zon.shadow_blur = 1.5
	add_child(zon)

	# Zacht, koeler tegenlicht zodat schaduwkanten niet grauw worden.
	var vul := DirectionalLight3D.new()
	vul.light_color = Color(0.75, 0.85, 1.0)
	vul.light_energy = 0.22
	vul.rotation_degrees = Vector3(-50, 145, 0)
	vul.shadow_enabled = false
	add_child(vul)


func _grond() -> void:
	var vlak := PlaneMesh.new()
	vlak.size = Vector2(420, 300)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert;
uniform sampler2D ruis : repeat_enable, filter_linear_mipmap;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }
void fragment() {
	float n1 = texture(ruis, wp.xz * 0.013).r;
	float n2 = texture(ruis, wp.xz * 0.07 + vec2(0.3, 0.7)).r;
	float n3 = texture(ruis, wp.xz * 0.31).r;
	vec3 gras1 = vec3(0.34, 0.52, 0.19);
	vec3 gras2 = vec3(0.58, 0.64, 0.28);
	vec3 mos = vec3(0.27, 0.44, 0.2);
	vec3 strooi = vec3(0.62, 0.5, 0.3);
	vec3 aarde = vec3(0.62, 0.45, 0.28);
	vec3 c = mix(gras1, gras2, smoothstep(0.35, 0.7, n1));
	c = mix(c, mos, smoothstep(0.55, 0.75, n2) * 0.6);
	c = mix(c, strooi, smoothstep(0.3, 0.12, n2) * 0.45);
	c *= 0.9 + n3 * 0.2;
	// Zandpaadjes en de open plek in het midden.
	float plek = 1.0 - smoothstep(5.5, 8.5, length(wp.xz) + (n3 - 0.5) * 2.0);
	c = mix(c, aarde * (0.9 + n3 * 0.2), plek * 0.85);
	ALBEDO = lin(c);
	ROUGHNESS = 0.97;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var ruis := NoiseTexture2D.new()
	ruis.width = 256
	ruis.height = 256
	ruis.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 3
	ruis.noise = fn
	mat.set_shader_parameter("ruis", ruis)
	vlak.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = vlak
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var body := StaticBody3D.new()
	body.collision_layer = LAAG_GROND
	body.collision_mask = 0
	var vorm := CollisionShape3D.new()
	vorm.shape = WorldBoundaryShape3D.new()
	body.add_child(vorm)
	add_child(body)


# ------------------------------------------------------------------ bomen

func _plaats_bomen() -> void:
	# "Darts gooien" met een minimale afstand: mooi verspreid, nooit op elkaar.
	var raster := {}
	var cel := 6.0
	var pogingen := 0
	while pogingen < 9000:
		pogingen += 1
		var p := Vector3(_rng.randf_range(-HALF_X + 2.5, HALF_X - 2.5), 0, _rng.randf_range(-HALF_Z + 2.5, HALF_Z - 2.5))
		if Vector2(p.x, p.z).length() < 9.0:
			continue  # de open plek waar je begint
		var min_afstand := _rng.randf_range(5.6, 7.5)
		var c := Vector2i(floori(p.x / cel), floori(p.z / cel))
		var te_dicht := false
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				for q in raster.get(c + Vector2i(dx, dz), []):
					if Vector2(p.x - q.x, p.z - q.z).length() < min_afstand:
						te_dicht = true
		if te_dicht:
			continue
		if not raster.has(c):
			raster[c] = []
		raster[c].append(p)
		bomen.append(_nieuwe_boom(p, _rng.randf_range(0.42, 0.6), _rng.randf_range(12.0, 15.5)))


func stam_straal(i: int, y: float) -> float:
	var b: Dictionary = bomen[i]
	return float(b["r"]) * (1.0 - 0.18 * clampf(y / float(b["h"]), 0.0, 1.0))


func boom_pos(i: int) -> Vector3:
	return bomen[i]["p"]


func dichtste_boom(p: Vector3, max_afstand: float) -> int:
	var beste := -1
	var best_d := max_afstand
	for i in bomen.size():
		var q: Vector3 = bomen[i]["p"]
		var d := Vector2(p.x - q.x, p.z - q.z).length()
		if d < best_d:
			best_d = d
			beste = i
	return beste


func _nieuwe_boom(p: Vector3, r: float, h: float) -> Dictionary:
	return {"p": p, "r": r, "h": h, "berk": _rng.randf() < 0.22, "draai": _rng.randf() * TAU, "vorm": _rng.randi() % 6}


func _teken_bomen() -> void:
	var stammen_m := [Boomvorm.stam(false, 0.3), Boomvorm.stam(false, 2.1), Boomvorm.stam(true, 1.2)]
	var kruinen_m := [Boomvorm.kruin(0, false), Boomvorm.kruin(1, false), Boomvorm.kruin(2, false), Boomvorm.kruin(0, true), Boomvorm.kruin(1, true)]
	var takken_m := [Boomvorm.zijtak(0), Boomvorm.zijtak(1)]
	var groen := [Color(0.42, 0.68, 0.25), Color(0.34, 0.6, 0.22), Color(0.52, 0.74, 0.27), Color(0.4, 0.66, 0.34), Color(0.3, 0.57, 0.3)]
	var berkgroen := [Color(0.62, 0.8, 0.3), Color(0.7, 0.82, 0.32), Color(0.56, 0.76, 0.3)]
	var lijsten := {}  # "stam/kruin + stuk" -> [plekken, kleuren, mesh]

	var voeg := func(sleutel: String, mesh: Mesh, t: Transform3D, k: Color) -> void:
		if not lijsten.has(sleutel):
			lijsten[sleutel] = [[], [], mesh]
		lijsten[sleutel][0].append(t)
		lijsten[sleutel][1].append(k)

	var alle := bomen.duplicate()
	# De rand buiten de muren: dichter en groter, zodat het bos "eindeloos" lijkt.
	var r2 := RandomNumberGenerator.new()
	r2.seed = 5
	for i in 560:
		var p := Vector3(r2.randf_range(-HALF_X - 26, HALF_X + 26), 0, r2.randf_range(-HALF_Z - 26, HALF_Z + 26))
		if absf(p.x) < HALF_X + 2.0 and absf(p.z) < HALF_Z + 2.0:
			continue
		alle.append(_nieuwe_boom(p, r2.randf_range(0.55, 0.8), r2.randf_range(13.0, 17.0)))

	for b in alle:
		var p: Vector3 = b["p"]
		var r: float = b["r"]
		var h: float = b["h"]
		var berk: bool = b["berk"]
		var stuk := Vector2i(floori(p.x / STUK), floori(p.z / STUK))
		var achter := "|%d|%d" % [stuk.x, stuk.y]
		var s := r / 0.5
		var draai := Basis(Vector3.UP, float(b["draai"]))
		var stam_nr := 2 if berk else int(b["vorm"]) % 2
		var tint := Color(0.98, 0.97, 0.95) if berk else Vorm.kleur_rond(Color(0.6, 0.4, 0.26), 0.09, _rng)
		voeg.call("stam%d%s" % [stam_nr, achter], stammen_m[stam_nr], Transform3D(draai * Basis.from_scale(Vector3(s, h / 13.0, s)), p), tint)

		var kruin_nr := (3 + int(b["vorm"]) % 2) if berk else int(b["vorm"]) % 3
		var k_schaal := _rng.randf_range(0.95, 1.25) * (0.85 if berk else 1.0)
		var kleur: Color
		if berk:
			kleur = berkgroen[_rng.randi() % berkgroen.size()]
			if _rng.randf() < 0.18:
				kleur = Color(0.98, 0.82, 0.3)   # goudgele berk
		else:
			kleur = groen[_rng.randi() % groen.size()]
			var lot := _rng.randf()
			if lot < 0.07:
				kleur = Color(0.97, 0.6, 0.24)    # herfstoranje
			elif lot < 0.11:
				kleur = Color(0.92, 0.42, 0.25)   # rood-oranje
			elif lot < 0.14:
				kleur = Color(0.99, 0.74, 0.82)   # roze bloesem
		var kruin_t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * k_schaal), Vector3(p.x, h + (0.6 if berk else 0.0), p.z))
		voeg.call("kruin%d%s" % [kruin_nr, achter], kruinen_m[kruin_nr], kruin_t, Vorm.kleur_rond(kleur, 0.05, _rng))

		# Lage zijtakjes met bladerplukjes aan een deel van de loofbomen.
		if not berk:
			for k in (int(b["vorm"]) % 3):
				var hoek := _rng.randf() * TAU
				var y := _rng.randf_range(6.3, 9.0)
				var plek := _op_stam(b, y, hoek, -0.06)
				var d := Vector3(cos(hoek), 0, sin(hoek))
				var t := Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)).scaled(Vector3.ONE * _rng.randf_range(0.85, 1.15)), plek)
				var tak_nr := _rng.randi() % 2
				voeg.call("tak%d%s" % [tak_nr, achter], takken_m[tak_nr], t, Color.WHITE)

	for sleutel in lijsten:
		var d: Array = lijsten[sleutel]
		Vorm.multimesh(self, d[2], d[0], [] if sleutel.begins_with("tak") else d[1])

	_boomversiering()

	# Botsing alleen voor de bomen waar je bij kunt.
	for i in bomen.size():
		var body := StaticBody3D.new()
		body.collision_layer = LAAG_BOOM
		body.collision_mask = 0
		body.set_meta("boom", i)
		var vorm := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = float(bomen[i]["r"]) * 0.97
		cyl.height = float(bomen[i]["h"]) + 1.0
		vorm.shape = cyl
		vorm.position = Vector3(0, cyl.height * 0.5, 0)
		body.add_child(vorm)
		body.position = bomen[i]["p"]
		add_child(body)


# Punt op het oppervlak van boom b, op hoogte y en wereldhoek `hoek`.
func _op_stam(b: Dictionary, y: float, hoek: float, uit := 0.0) -> Vector3:
	var s: float = float(b["r"]) / 0.5
	# Basis(UP, draai) draait een lokale hoek h naar wereldhoek h - draai.
	var lokale_hoek := hoek + float(b["draai"])
	var mesh_y := y * 13.0 / float(b["h"])
	var r := Boomvorm.straal(mesh_y, lokale_hoek) * s
	var p: Vector3 = b["p"]
	return p + Vector3(cos(hoek) * (r + uit), y, sin(hoek) * (r + uit))


# Kleine verrassingen op de stammen: zwammetjes, vogelhuisjes en hier en daar
# een elfendeurtje tussen de wortels. Alles samen één mesh.
func _boomversiering() -> void:
	var b := Vorm.Bouwer.new()
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var deurkleuren := [Color(0.9, 0.3, 0.3), Color(0.3, 0.55, 0.9), Color(0.35, 0.7, 0.4), Color(0.95, 0.75, 0.25), Color(0.75, 0.45, 0.85)]
	for b_nr in bomen.size():
		var boom: Dictionary = bomen[b_nr]
		var lot := r.randf()
		if lot < 0.28:
			# Zwammetjes in een trapje boven elkaar.
			var hoek := r.randf() * TAU
			var y := r.randf_range(0.7, 2.6)
			var kleur := Color(0.98, 0.78, 0.45) if r.randf() < 0.6 else Color(0.97, 0.93, 0.85)
			for k in r.randi_range(2, 4):
				var hk := hoek + r.randf_range(-0.35, 0.35)
				var pos := _op_stam(boom, y, hk, 0.0)
				var d := Vector3(cos(hk), 0, sin(hk))
				var grootte := r.randf_range(0.15, 0.24)
				var stand := Basis(Vector3.UP, atan2(d.x, d.z))
				b.bol(grootte, pos + d * grootte * 0.35, kleur, Vector3(0.75, 0.3, 1.0), true, stand)
				b.bol(grootte * 0.8, pos + d * grootte * 0.3 + Vector3(0, 0.035, 0), kleur.lightened(0.25), Vector3(0.7, 0.25, 1.0), false, stand)
				y += r.randf_range(0.22, 0.4)
		elif lot < 0.36:
			_vogelhuisje(b, boom, r)
		elif lot < 0.43 and not boom["berk"]:
			_elfendeur(b, boom, r, deurkleuren[r.randi() % deurkleuren.size()])
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	add_child(mi)


func _vogelhuisje(b: Vorm.Bouwer, boom: Dictionary, r: RandomNumberGenerator) -> void:
	var hoek := r.randf() * TAU
	var y := r.randf_range(5.8, 7.5)
	var d := Vector3(cos(hoek), 0, sin(hoek))
	var draai := Basis(Vector3.UP, atan2(d.x, d.z))
	var p := _op_stam(boom, y, hoek, 0.2)
	var hout := Color(0.85, 0.65, 0.42) if r.randf() < 0.5 else Color(0.55, 0.78, 0.88)
	var dak := Color(0.9, 0.35, 0.3) if r.randf() < 0.6 else Color(0.35, 0.6, 0.85)
	b.blok(Vector3(0.36, 0.42, 0.34), p, hout, draai)
	b.blok(Vector3(0.3, 0.05, 0.46), p + draai * Vector3(0.11, 0.27, 0.0), dak, draai * Basis(Vector3.FORWARD, -0.75))
	b.blok(Vector3(0.3, 0.05, 0.46), p + draai * Vector3(-0.11, 0.27, 0.0), dak, draai * Basis(Vector3.FORWARD, 0.75))
	b.cil(0.065, 0.065, 0.03, p + draai * Vector3(0, 0.05, 0.172), Color(0.2, 0.15, 0.12), 10, draai * Basis(Vector3.RIGHT, PI / 2))
	b.staaf(p + draai * Vector3(0, -0.08, 0.17), p + draai * Vector3(0, -0.08, 0.3), 0.015, Color(0.5, 0.35, 0.22))
	b.blok(Vector3(0.08, 0.3, 0.12), p + draai * Vector3(0, -0.05, -0.2), Color(0.5, 0.35, 0.22), draai)


func _elfendeur(b: Vorm.Bouwer, boom: Dictionary, r: RandomNumberGenerator, kleur: Color) -> void:
	# Tussen twee wortels in, waar de stam het smalst is.
	var lokaal := Boomvorm.hoek_tussen_wortels(r.randi() % Boomvorm.WORTELS)
	var hoek := lokaal - float(boom["draai"])
	var d := Vector3(cos(hoek), 0, sin(hoek))
	var draai := Basis(Vector3.UP, atan2(d.x, d.z))
	var plat := draai * Basis(Vector3.RIGHT, PI / 2)
	var p := _op_stam(boom, 0.25, hoek, -0.04)
	deuren.append([p, d])
	p.y = 0.0
	b.blok(Vector3(0.36, 0.4, 0.06), p + Vector3(0, 0.2, 0), kleur, draai)
	b.cil(0.18, 0.18, 0.06, p + Vector3(0, 0.4, 0), kleur, 14, plat)
	b.cil(0.22, 0.22, 0.04, p + Vector3(0, 0.4, 0) - d * 0.012, Color(0.55, 0.38, 0.25), 14, plat)
	b.blok(Vector3(0.44, 0.44, 0.04), p + Vector3(0, 0.2, 0) - d * 0.012, Color(0.55, 0.38, 0.25), draai)
	b.bol(0.03, p + draai * Vector3(0.1, 0.2, 0.04), Color(1.0, 0.85, 0.3))
	b.cil(0.055, 0.055, 0.02, p + draai * Vector3(0, 0.42, 0.035), Color(1.0, 0.92, 0.6), 10, plat)
	# Twee steentjes als stoepje.
	b.bol(0.07, p + d * 0.14 + Vector3(-0.07, 0.01, 0), Color(0.75, 0.72, 0.68), Vector3(1, 0.4, 1))
	b.bol(0.06, p + d * 0.24 + Vector3(0.06, 0.01, 0), Color(0.75, 0.72, 0.68), Vector3(1, 0.4, 1))


# ------------------------------------------------------------------ versiering

func _grassprieten() -> ArrayMesh:
	# Elk blaadje twee keer (beide kanten op) met de normaal recht omhoog,
	# anders wordt het gras van één kant pikzwart.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var onder := Color(0.55, 0.55, 0.55).srgb_to_linear()
	var top := Color(1, 1, 1)
	for i in 5:
		var hoek := TAU * i / 5.0 + 0.3
		var r := Vector3(cos(hoek), 0, sin(hoek))
		var zij := Vector3(-r.z, 0, r.x) * 0.06
		var h := 0.32 + 0.1 * (i % 2)
		var punt := r * 0.12 + Vector3(0, h, 0)
		var a := -zij + r * 0.03
		var b := zij + r * 0.03
		for drie in [[a, b, punt], [punt, b, a]]:
			for j in 3:
				st.set_normal(Vector3.UP)
				st.set_color(top if drie[j] == punt else onder)
				st.add_vertex(drie[j])
	var m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	m.surface_set_material(0, mat)
	return m


func _bloem() -> ArrayMesh:
	var b := Vorm.Bouwer.new()
	b.staaf(Vector3.ZERO, Vector3(0, 0.22, 0), 0.015, Color(0.5, 0.75, 0.4), 4)
	for i in 5:
		var hoek := TAU * i / 5.0
		b.bol(0.055, Vector3(cos(hoek) * 0.06, 0.24, sin(hoek) * 0.06), Color(1, 1, 1), Vector3(1, 0.45, 1), 0)
	b.bol(0.04, Vector3(0, 0.255, 0), Color(1.0, 0.88, 0.5), Vector3(1, 0.6, 1), 0)
	return b.mesh()


func _paddenstoel() -> ArrayMesh:
	var b := Vorm.Bouwer.new()
	b.cil(0.07, 0.06, 0.22, Vector3(0, 0.11, 0), Color(0.98, 0.94, 0.85), 8)
	b.bol(0.17, Vector3(0, 0.22, 0), Color(0.93, 0.2, 0.17), Vector3(1, 0.62, 1))
	for i in 6:
		var hoek := TAU * i / 6.0 + 0.4
		var d := Vector3(cos(hoek), 0, sin(hoek))
		b.bol(0.03, d * 0.11 + Vector3(0, 0.29, 0), Color(1, 1, 0.97), Vector3(1, 0.5, 1), 0)
	b.bol(0.03, Vector3(0, 0.326, 0), Color(1, 1, 0.97), Vector3(1, 0.5, 1), 0)
	return b.mesh()


func _struik() -> ArrayMesh:
	var b := Vorm.Bouwer.new()
	b.bol(0.7, Vector3(0, 0.45, 0), Color(0.95, 0.95, 0.95), Vector3(1, 0.8, 1))
	b.bol(0.5, Vector3(0.55, 0.35, 0.2), Color(0.88, 0.88, 0.88), Vector3(1, 0.85, 1))
	b.bol(0.48, Vector3(-0.5, 0.33, -0.15), Color(0.86, 0.86, 0.86), Vector3(1, 0.85, 1))
	return b.mesh()


func _steen() -> ArrayMesh:
	var b := Vorm.Bouwer.new()
	b.bol(0.4, Vector3(0, 0.08, 0), Color(1, 1, 1), Vector3(1.3, 0.6, 1.0))
	b.bol(0.22, Vector3(0.4, 0.04, 0.2), Color(0.92, 0.92, 0.92), Vector3(1.2, 0.6, 1.0))
	return b.mesh()


func _vrij(p: Vector3, afstand: float) -> bool:
	var i := dichtste_boom(p, afstand)
	return i < 0


func _versiering() -> void:
	var lijsten := {}  # "soort/stuk" -> [plekken, kleuren]
	var maak := func(soort: String, p: Vector3, t: Transform3D, k: Color) -> void:
		var stuk := Vector2i(floori(p.x / STUK), floori(p.z / STUK))
		var sleutel := "%s/%d/%d" % [soort, stuk.x, stuk.y]
		if not lijsten.has(sleutel):
			lijsten[sleutel] = [[], [], soort]
		lijsten[sleutel][0].append(t)
		lijsten[sleutel][1].append(k)

	var rx := HALF_X + 24.0
	var rz := HALF_Z + 24.0
	# Gras
	for i in 9000:
		var p := Vector3(_rng.randf_range(-rx, rx), 0, _rng.randf_range(-rz, rz))
		var s := _rng.randf_range(0.8, 1.5)
		var k := Vorm.kleur_rond(Color(0.5, 0.68, 0.28), 0.12, _rng)
		maak.call("gras", p, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.3), s)), p), k)
	# Bloemen in plukjes
	var bloemkleuren := [Color(1.0, 0.62, 0.75), Color(1.0, 0.92, 0.45), Color(1, 1, 1), Color(0.78, 0.65, 1.0), Color(1.0, 0.55, 0.4)]
	for i in 170:
		var midden := Vector3(_rng.randf_range(-rx, rx), 0, _rng.randf_range(-rz, rz))
		var k: Color = bloemkleuren[_rng.randi() % bloemkleuren.size()]
		for j in 7:
			var p := midden + Vector3(_rng.randf_range(-1.3, 1.3), 0, _rng.randf_range(-1.3, 1.3))
			var s := _rng.randf_range(0.9, 1.4)
			maak.call("bloem", p, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p), k)
	# Paddenstoelen: vaak bij de voet van een boom
	for i in 260:
		var bi := _rng.randi() % bomen.size()
		var hoek := _rng.randf() * TAU
		var p: Vector3 = bomen[bi]["p"] + Vector3(cos(hoek), 0, sin(hoek)) * _rng.randf_range(1.0, 2.2)
		var s := _rng.randf_range(0.6, 1.15)
		maak.call("paddenstoel", p, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p), Color.WHITE)
	# Struiken
	for i in 420:
		var p := Vector3(_rng.randf_range(-rx, rx), 0, _rng.randf_range(-rz, rz))
		if Vector2(p.x, p.z).length() < 9.0:
			continue
		var s := _rng.randf_range(0.8, 1.6)
		var k := Vorm.kleur_rond(Color(0.36, 0.62, 0.24), 0.15, _rng)
		maak.call("struik", p, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p), k)
	# Stenen
	for i in 160:
		var p := Vector3(_rng.randf_range(-rx, rx), 0, _rng.randf_range(-rz, rz))
		var s := _rng.randf_range(0.6, 1.8)
		var k := Vorm.kleur_rond(Color(0.72, 0.68, 0.62), 0.08, _rng)
		maak.call("steen", p, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), p), k)

	var meshes := {"gras": _grassprieten(), "bloem": _bloem(), "paddenstoel": _paddenstoel(), "struik": _struik(), "steen": _steen()}
	for sleutel in lijsten:
		var d: Array = lijsten[sleutel]
		var soort: String = d[2]
		var kleuren: Array = [] if soort == "paddenstoel" else d[1]
		Vorm.multimesh(self, meshes[soort], d[0], kleuren, soort == "struik" or soort == "steen")


# ------------------------------------------------------------------ grenzen

func _muren() -> void:
	var maten := [
		[Vector3(2, 120, HALF_Z * 2 + 10), Vector3(HALF_X + 1, 60, 0)],
		[Vector3(2, 120, HALF_Z * 2 + 10), Vector3(-HALF_X - 1, 60, 0)],
		[Vector3(HALF_X * 2 + 10, 120, 2), Vector3(0, 60, HALF_Z + 1)],
		[Vector3(HALF_X * 2 + 10, 120, 2), Vector3(0, 60, -HALF_Z - 1)],
	]
	for m in maten:
		var body := StaticBody3D.new()
		body.collision_layer = LAAG_MUUR
		body.collision_mask = 0
		var vorm := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = m[0]
		vorm.shape = box
		body.add_child(vorm)
		body.position = m[1]
		add_child(body)


func binnen(p: Vector3) -> Vector3:
	p.x = clampf(p.x, -HALF_X + GRENS, HALF_X - GRENS)
	p.z = clampf(p.z, -HALF_Z + GRENS, HALF_Z - GRENS)
	return p


# ------------------------------------------------------------------ startplek

func _open_plek() -> void:
	# Een vrolijk bordje en een bouwkist op de open plek waar je begint.
	var b := Vorm.Bouwer.new()
	var hout := Color(0.82, 0.58, 0.36)
	var donker := Color(0.6, 0.4, 0.25)
	b.cil(0.08, 0.08, 2.2, Vector3(-1.1, 1.1, -4.5), donker)
	b.cil(0.08, 0.08, 2.2, Vector3(1.1, 1.1, -4.5), donker)
	b.blok(Vector3(2.8, 0.9, 0.12), Vector3(0, 1.75, -4.5), hout)
	b.blok(Vector3(3.0, 0.12, 0.2), Vector3(0, 2.25, -4.5), Color(0.9, 0.35, 0.3))
	# Bouwkist
	var kist := Vector3(3.2, 0, -2.0)
	b.blok(Vector3(1.4, 0.8, 0.9), kist + Vector3(0, 0.4, 0), hout)
	b.blok(Vector3(1.5, 0.12, 1.0), kist + Vector3(0, 0.84, 0), Color(0.9, 0.35, 0.3))
	b.blok(Vector3(0.14, 0.82, 0.92), kist + Vector3(-0.5, 0.41, 0), donker)
	b.blok(Vector3(0.14, 0.82, 0.92), kist + Vector3(0.5, 0.41, 0), donker)
	# Er liggen al wat planken en een rol touw naast.
	for i in 3:
		b.blok(Vector3(2.0, 0.08, 0.36), kist + Vector3(-0.2, 0.04 + i * 0.09, 1.1), Vorm.kleur_rond(Color(0.88, 0.66, 0.42), 0.06), Basis(Vector3.UP, 0.1 * i))
	for i in 10:
		var hoek := TAU * i / 10.0
		b.staaf(kist + Vector3(1.2 + cos(hoek) * 0.3, 0.08, -0.9 + sin(hoek) * 0.3), kist + Vector3(1.2 + cos(hoek + 0.63) * 0.3, 0.08, -0.9 + sin(hoek + 0.63) * 0.3), 0.07, Color(0.95, 0.86, 0.66))
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	add_child(mi)

	var tekst := Label3D.new()
	tekst.text = "Het Klimbos"
	tekst.font_size = 72
	tekst.outline_size = 10
	tekst.modulate = Color(0.45, 0.25, 0.12)
	tekst.outline_modulate = Color(1, 0.95, 0.8)
	tekst.position = Vector3(0, 1.78, -4.42)
	tekst.pixel_size = 0.005
	tekst.double_sided = false
	tekst.rotation.y = 0
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Comic Sans MS", "Arial Rounded MT Bold", "Segoe UI"])
	font.font_weight = 700
	tekst.font = font
	add_child(tekst)
