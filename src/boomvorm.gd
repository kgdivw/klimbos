class_name Boomvorm
extends RefCounted

# De bomen zijn het belangrijkste wat je ziet, dus die krijgen extra zorg.
#
# STAM: geen cilinder maar een draaivorm: ring na ring rond een licht kromme
# ruggengraat. Onderaan waaieren vijf wortels als een ster uit, de schors
# heeft ribbels (in vorm én kleur) en er groeit mos op de voet. Een berk is
# wit met zwarte streepjes.
#
# KRUIN: een wolk van bollen. Elk hoekpunt krijgt een kleur die afhangt van
# waar het zit: onderkant koel en donker, bovenkant warm en zonnig, binnenin
# wat donkerder. Daarbovenop doet de bladershader een bladerpatroon, licht
# dat door de bladeren schijnt en een zacht wiegen in de wind.

const STAM_HOOG := 14.5
const ZIJDEN := 14
const RINGEN := [-0.2, 0.0, 0.1, 0.25, 0.45, 0.75, 1.15, 1.7, 2.5, 3.5, 4.8, 6.2, 7.6, 9.0, 10.4, 11.8, 13.2, 14.5]
const WORTELS := 5
const WORTEL_FASE := 0.6

static var _blad_mat: ShaderMaterial
static var _stam_mat := {}


# Straal van de stam (vóór schalen) op hoogte y en hoek `hoek` (lokaal).
static func straal(y: float, hoek: float) -> float:
	var r := lerpf(0.5, 0.4, clampf(y / STAM_HOOG, 0.0, 1.0))
	var voet := exp(-maxf(y, 0.0) * 1.5)
	var lob := pow(maxf(0.0, cos(hoek * WORTELS + WORTEL_FASE)), 2.0)
	r *= 1.0 + voet * (0.32 + 1.15 * lob)
	r *= 1.0 + 0.035 * sin(hoek * 9.0 + y * 0.6)
	return r


# Een hoek tussen twee wortels in: daar past een elfendeurtje.
static func hoek_tussen_wortels(nr: int) -> float:
	return (PI - WORTEL_FASE + TAU * nr) / WORTELS


static func _ruggengraat(y: float, fase: float) -> Vector3:
	var t := clampf(y / STAM_HOOG, 0.0, 1.0)
	return Vector3(sin(y * 0.23 + fase) * 0.09, 0, cos(y * 0.19 + fase * 1.7) * 0.09) * t


static func _stam_kleur(berk: bool, y: float, hoek: float, op: float) -> Color:
	if berk:
		var c := Color(0.97, 0.95, 0.9)
		var voet := clampf(1.0 - y / 1.4, 0.0, 1.0)
		c = c.lerp(Color(0.45, 0.4, 0.36), voet * 0.8)
		return c
	var c := Color(1, 1, 1)
	# Mos op de bovenkant van de wortels en onderaan de stam.
	var mos := clampf(exp(-maxf(y, 0.0) * 1.1) * (0.4 + op * 0.8), 0.0, 0.85)
	c = c.lerp(Color(0.62, 0.95, 0.42), mos)
	return c


static func stam(berk: bool, fase: float) -> ArrayMesh:
	var b := Vorm.Bouwer.new()
	var st := b.st
	var n := ZIJDEN
	var ringen: Array = RINGEN
	var punt := func(y: float, j: int) -> Vector3:
		var hoek := TAU * j / n
		var r := straal(y, hoek)
		return _ruggengraat(y, fase) + Vector3(cos(hoek) * r, y, sin(hoek) * r)
	# Hoekpunten en normalen (uit de buurpunten berekend).
	var pos := []
	var nor := []
	var kol := []
	for i in ringen.size():
		var y: float = ringen[i]
		var rij_p := []
		var rij_n := []
		var rij_k := []
		for j in n + 1:
			var p: Vector3 = punt.call(y, j)
			var langs: Vector3 = punt.call(y, j + 1) - punt.call(y, j - 1)
			var y0: float = ringen[maxi(i - 1, 0)]
			var y1: float = ringen[mini(i + 1, ringen.size() - 1)]
			var op: Vector3 = punt.call(y1, j) - punt.call(y0, j)
			var nn := langs.cross(op).normalized()
			var buiten := Vector3(p.x, 0, p.z)
			if nn.dot(buiten) < 0:
				nn = -nn
			rij_p.append(p)
			rij_n.append(nn)
			rij_k.append(_stam_kleur(berk, y, TAU * j / n, maxf(nn.y, 0.0)).srgb_to_linear())
		pos.append(rij_p)
		nor.append(rij_n)
		kol.append(rij_k)
	for i in ringen.size() - 1:
		for j in n:
			var quad := [[i, j], [i, j + 1], [i + 1, j + 1], [i + 1, j]]
			for driehoek in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
				var drie: Array = driehoek
				var a: Vector3 = pos[drie[0][0]][drie[0][1]]
				var bb: Vector3 = pos[drie[1][0]][drie[1][1]]
				var c: Vector3 = pos[drie[2][0]][drie[2][1]]
				var midden_n: Vector3 = nor[drie[0][0]][drie[0][1]]
				# Godot tekent de voorkant met de klok mee: (b-a)x(c-a) moet van de
				# buitenkant af wijzen. Zo niet, dan draaien we de volgorde om.
				if (bb - a).cross(c - a).dot(midden_n) > 0:
					drie = [drie[0], drie[2], drie[1]]
				for hp in drie:
					st.set_color(kol[hp[0]][hp[1]])
					st.set_normal(nor[hp[0]][hp[1]])
					st.add_vertex(pos[hp[0]][hp[1]])
	b.aantal += 1

	# Takken die de kruin in gaan (alleen het begin is zichtbaar onder de bladeren).
	var r := RandomNumberGenerator.new()
	r.seed = int(fase * 1000.0) + (7 if berk else 0)
	var tak_kleur := Color(0.9, 0.9, 0.9) if not berk else Color(0.85, 0.83, 0.8)
	var takken := 4 if not berk else 5
	for k in takken:
		var hoek := TAU * k / takken + r.randf_range(-0.4, 0.4)
		var y := r.randf_range(8.3, 11.0)
		var van := _ruggengraat(y, fase) + Vector3(0, y, 0)
		var richting := Vector3(cos(hoek), r.randf_range(0.6, 1.1), sin(hoek)).normalized()
		var lengte := r.randf_range(2.4, 3.4)
		var dik := 0.17 if not berk else 0.11
		b.cil(dik, dik * 0.4, lengte, van + richting * lengte * 0.5, tak_kleur, 7, Vorm.langs(richting))
		# Een zijtakje
		var zij := richting.rotated(Vector3.UP, 0.9).lerp(Vector3.UP, 0.3).normalized()
		var midden := van + richting * lengte * 0.55
		b.cil(dik * 0.45, dik * 0.2, 1.3, midden + zij * 0.65, tak_kleur, 5, Vorm.langs(zij))
	var m := b.mesh()
	m.surface_set_material(0, stam_materiaal(berk))
	return Vorm.met_lod(m)


static func _blob(b: Vorm.Bouwer, middelpunt: Vector3, r: float, schaal := Vector3(1, 0.86, 1)) -> void:
	b.bol(r, middelpunt, Color(1, 1, 1), schaal, true)


static func kruin(soort: int, berk: bool) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = 911 + soort * 37 + (500 if berk else 0)
	var b := Vorm.Bouwer.new()
	var hoogte := 0.0
	if berk:
		# Luchtig en wat hoger: veel kleine bolletjes in een eivorm.
		_blob(b, Vector3(0, 0.6, 0), 1.9, Vector3(1, 1.15, 1))
		for i in 11:
			var hoek := r.randf() * TAU
			var y := r.randf_range(-1.5, 2.8)
			var breed := 2.1 * sqrt(maxf(0.2, 1.0 - pow((y - 0.6) / 3.0, 2.0)))
			_blob(b, Vector3(cos(hoek) * breed, y, sin(hoek) * breed), r.randf_range(1.0, 1.45))
		hoogte = 3.6
	else:
		_blob(b, Vector3(0, 0.2, 0), 3.0, Vector3(1, 0.82, 1))
		var n := 7 + soort
		for i in n:
			var hoek := TAU * i / n + r.randf_range(-0.25, 0.25)
			var afstand := r.randf_range(2.3, 2.8)
			_blob(b, Vector3(cos(hoek) * afstand, r.randf_range(-0.8, 0.2), sin(hoek) * afstand), r.randf_range(1.75, 2.25))
		for i in 4:
			var hoek := TAU * i / 4.0 + r.randf() + 0.4
			_blob(b, Vector3(cos(hoek) * 1.4, r.randf_range(1.2, 1.7), sin(hoek) * 1.4), r.randf_range(1.6, 1.95))
		_blob(b, Vector3(r.randf_range(-0.4, 0.4), 2.4, r.randf_range(-0.4, 0.4)), 1.5)
		# Een paar losse plukjes onderaan, zodat de rand niet te glad is.
		for i in 3 + soort:
			var hoek := r.randf() * TAU
			_blob(b, Vector3(cos(hoek) * 3.6, r.randf_range(-1.2, -0.6), sin(hoek) * 3.6), r.randf_range(0.9, 1.25))
		hoogte = 3.8
	var mesh := b.mesh()
	return _kleurverloop(mesh, hoogte)


static func _kleurverloop(mesh: ArrayMesh, hoogte: float, basis := Color(1, 1, 1)) -> ArrayMesh:
	var arr := mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nor: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var kol := PackedColorArray()
	kol.resize(pos.size())
	var zon := Vector3(0.45, 0.8, 0.35).normalized()
	for i in pos.size():
		var p := pos[i]
		var nn := nor[i]
		var t := clampf(0.5 + nn.y * 0.3 + p.y / hoogte * 0.32 + nn.dot(zon) * 0.12, 0.0, 1.0)
		var licht := lerpf(0.5, 1.12, t)
		var warm := smoothstep(0.62, 1.0, t)
		var binnen := clampf(Vector2(p.x, p.z).length() / 3.2 + 0.2 + maxf(p.y, 0.0) * 0.15, 0.62, 1.0)
		var v := licht * binnen
		var c := Color(v * (1.0 + warm * 0.1), v * (1.0 + warm * 0.05), v * (1.0 - warm * 0.12) * (1.04 - t * 0.04))
		kol[i] = c.srgb_to_linear() * basis
	arr[Mesh.ARRAY_COLOR] = kol
	var uit := ArrayMesh.new()
	uit.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	uit.surface_set_material(0, blad_materiaal())
	return Vorm.met_lod(uit)


static func blad_materiaal() -> ShaderMaterial:
	if _blad_mat != null:
		return _blad_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform sampler2D blad_ruis : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	vec3 boom = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = TIME * 0.85 + boom.x * 0.21 + boom.z * 0.17;
	float hoog = smoothstep(-3.0, 3.5, VERTEX.y);
	VERTEX.x += sin(t + VERTEX.y * 0.45) * 0.1 * hoog;
	VERTEX.z += cos(t * 0.83 + VERTEX.x * 0.3) * 0.08 * hoog;
	VERTEX.y += sin(t * 1.3 + VERTEX.x * 0.5) * 0.03 * hoog;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 bl = pow(abs(wnorm), vec3(4.0));
	bl /= (bl.x + bl.y + bl.z);
	float s = 0.32;
	float n = texture(blad_ruis, wpos.zy * s).r * bl.x
			+ texture(blad_ruis, wpos.xz * s).r * bl.y
			+ texture(blad_ruis, wpos.xy * s).r * bl.z;
	float blad = mix(0.74, 1.1, smoothstep(0.15, 0.7, n));
	ALBEDO = COLOR.rgb * blad;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	BACKLIGHT = COLOR.rgb * vec3(0.55, 0.6, 0.35);
	RIM = 0.35;
	RIM_TINT = 0.7;
}
"""
	_blad_mat = ShaderMaterial.new()
	_blad_mat.shader = sh
	var ruis := NoiseTexture2D.new()
	ruis.width = 256
	ruis.height = 256
	ruis.seamless = true
	var fn := FastNoiseLite.new()
	fn.noise_type = FastNoiseLite.TYPE_CELLULAR
	fn.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	fn.frequency = 0.035
	ruis.noise = fn
	_blad_mat.set_shader_parameter("blad_ruis", ruis)
	return _blad_mat


# Een lage zijtak met een paar bladerplukjes: zo zijn de stammen niet zo kaal.
# Twee oppervlakken: hout (gewoon materiaal) en blad (de bladershader).
# Oorsprong = waar de tak uit de stam komt, +Z wijst van de stam af.
static func zijtak(soort: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = 4242 + soort * 17
	var hout := Vorm.Bouwer.new()
	var bruin := Color(0.5, 0.33, 0.21)
	var lengte := 1.9 + soort * 0.4
	var eind := Vector3(r.randf_range(-0.3, 0.3), 0.9 + soort * 0.2, lengte)
	hout.cil(0.13, 0.06, eind.length(), eind * 0.5 + Vector3(0, 0, -0.1), bruin, 7, Vorm.langs(eind))
	var zij := Vector3(0.7, 0.8, 0.6).normalized()
	hout.cil(0.06, 0.03, 0.9, eind * 0.6 + zij * 0.4, bruin, 5, Vorm.langs(zij))
	var blad := Vorm.Bouwer.new()
	_blob(blad, eind + Vector3(0, 0.25, 0.1), 0.95)
	for i in 4 + soort:
		var hoek := TAU * i / (4 + soort) + r.randf()
		_blob(blad, eind + Vector3(cos(hoek) * 0.75, r.randf_range(-0.1, 0.45), sin(hoek) * 0.6 + 0.1), r.randf_range(0.55, 0.75))
	_blob(blad, eind * 0.6 + zij * 0.85, 0.5)
	var m := hout.mesh()
	var groen: Color = [Color(0.42, 0.68, 0.25), Color(0.5, 0.72, 0.27)][soort % 2]
	var bl := _kleurverloop(blad.mesh(), 1.2, groen.srgb_to_linear())
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bl.surface_get_arrays(0))
	m.surface_set_material(1, blad_materiaal())
	return Vorm.met_lod(m)


static func stam_materiaal(berk: bool) -> ShaderMaterial:
	if _stam_mat.has(berk):
		return _stam_mat[berk]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform bool berk = false;
uniform sampler2D ruis : filter_linear_mipmap, repeat_enable;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	float hoek = atan(lp.z, lp.x) / 6.2831853;
	float n = texture(ruis, vec2(hoek * 3.0, lp.y * 0.2)).r;
	vec3 c = COLOR.rgb;
	if (berk) {
		// Zwarte, liggende vlekjes en streepjes zoals op een echte berk.
		float d = texture(ruis, vec2(hoek * 1.0 + 0.37, lp.y * 0.9)).r;
		float d2 = texture(ruis, vec2(hoek * 2.0 + 0.11, lp.y * 2.3)).r;
		float vlek = smoothstep(0.66, 0.7, d) + smoothstep(0.72, 0.75, d2) * 0.8;
		c *= 0.9 + n * 0.14;
		c = mix(c, vec3(0.05, 0.045, 0.045), clamp(vlek, 0.0, 0.92));
		ROUGHNESS = 0.7;
	} else {
		// Diepe verticale groeven in de schors.
		float groef = sin(hoek * 6.2831853 * 11.0 + n * 6.0 + lp.y * 0.25);
		c *= mix(0.6, 1.07, smoothstep(-0.55, 0.65, groef));
		c *= 0.86 + n * 0.26;
		ROUGHNESS = 0.92;
	}
	ALBEDO = c;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("berk", berk)
	var ruis := NoiseTexture2D.new()
	ruis.width = 256
	ruis.height = 256
	ruis.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.022
	fn.fractal_octaves = 3
	ruis.noise = fn
	m.set_shader_parameter("ruis", ruis)
	_stam_mat[berk] = m
	return m
