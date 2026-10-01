class_name Vorm
extends RefCounted

# Gereedschap om figuren in code te bouwen. Alles wordt samengevoegd tot ÉÉN
# mesh met een kleur per hoekpunt en één gedeeld materiaal: op deze laptop is
# het aantal tekenopdrachten de grootste rem, niet het aantal driehoekjes.
#
# Let op: kleuren per hoekpunt gaan niet vanzelf van sRGB naar lineair, dat
# doen we hier dus zelf (anders wordt alles bleek).

static var _mat: StandardMaterial3D
static var _cache := {}


static func materiaal() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 0.82
	return _mat


# --- Basisvormen van maat 1, één keer gemaakt en daarna hergebruikt ---

static func doos() -> Array:
	if not _cache.has("doos"):
		var m := BoxMesh.new()
		_cache["doos"] = m.surface_get_arrays(0)
	return _cache["doos"]


# fijn: 0 = heel grof (voor piepkleine dingen), false/1 = gewoon, true/2 = fijn.
static func bolvorm(fijn = false) -> Array:
	var stand: int = 2 if fijn is bool and fijn else (1 if fijn is bool else int(fijn))
	var sleutel := "bol%d" % stand
	if not _cache.has(sleutel):
		var m := SphereMesh.new()
		m.radius = 1.0
		m.height = 2.0
		m.radial_segments = [6, 9, 12][stand]
		m.rings = [3, 5, 7][stand]
		_cache[sleutel] = m.surface_get_arrays(0)
	return _cache[sleutel]


static func cilvorm(boven: float, zijden: int) -> Array:
	var sleutel := "cil%.2f_%d" % [boven, zijden]
	if not _cache.has(sleutel):
		var m := CylinderMesh.new()
		m.top_radius = boven
		m.bottom_radius = 1.0
		m.height = 1.0
		m.radial_segments = zijden
		m.rings = 1
		_cache[sleutel] = m.surface_get_arrays(0)
	return _cache[sleutel]


# Een draaiing waarbij de Y-as langs `y` wijst (voor staven, touwen, kabels).
static func langs(y: Vector3) -> Basis:
	y = y.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


# Een draaiing waarbij Z langs `vooruit` wijst en Y zo veel mogelijk omhoog.
# Handig voor planken op een schuine brug.
static func plankstand(vooruit: Vector3) -> Basis:
	var z := vooruit.normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x)
	return Basis(x, y, z)


static func kleur_rond(k: Color, variatie: float, rng: RandomNumberGenerator = null) -> Color:
	var f := 1.0 + (rng.randf_range(-variatie, variatie) if rng else randf_range(-variatie, variatie))
	return Color(clampf(k.r * f, 0, 1), clampf(k.g * f, 0, 1), clampf(k.b * f, 0, 1), k.a)


class Bouwer:
	var st := SurfaceTool.new()
	var aantal := 0

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func voeg(arr: Array, xf: Transform3D, kleur: Color) -> void:
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var nb := xf.basis.inverse().transposed()
		var c := kleur.srgb_to_linear()
		if idx.is_empty():
			for i in v.size():
				st.set_color(c)
				st.set_normal((nb * nm[i]).normalized())
				st.add_vertex(xf * v[i])
		else:
			for i in idx:
				st.set_color(c)
				st.set_normal((nb * nm[i]).normalized())
				st.add_vertex(xf * v[i])
		aantal += 1

	func blok(maat: Vector3, pos: Vector3, kleur: Color, b := Basis()) -> void:
		voeg(Vorm.doos(), Transform3D(b * Basis.from_scale(maat), pos), kleur)

	func bol(straal: float, pos: Vector3, kleur: Color, schaal := Vector3.ONE, fijn = false, b := Basis()) -> void:
		voeg(Vorm.bolvorm(fijn), Transform3D(b * Basis.from_scale(schaal * straal), pos), kleur)

	# Cilinder met `pos` als midden. `boven`/`onder` zijn stralen.
	func cil(onder: float, boven: float, hoogte: float, pos: Vector3, kleur: Color, zijden := 8, b := Basis()) -> void:
		var verhouding := snappedf(boven / maxf(onder, 0.001), 0.01)
		voeg(Vorm.cilvorm(verhouding, zijden), Transform3D(b * Basis.from_scale(Vector3(onder, hoogte, onder)), pos), kleur)

	# Ronde staaf van a naar b (touw, kabel, balk).
	func staaf(a: Vector3, b: Vector3, dikte: float, kleur: Color, zijden := 6) -> void:
		var d := b - a
		var l := d.length()
		if l < 0.001:
			return
		var bas := Vorm.langs(d / l)
		voeg(Vorm.cilvorm(1.0, zijden), Transform3D(bas * Basis.from_scale(Vector3(dikte, l, dikte)), (a + b) * 0.5), kleur)

	func mesh() -> ArrayMesh:
		if aantal == 0:
			return ArrayMesh.new()
		st.index()
		var m := st.commit()
		m.surface_set_material(0, Vorm.materiaal())
		return m


# Maakt automatisch eenvoudigere versies (LOD) van een mesh: van ver weg
# tekent Godot dan veel minder driehoekjes.
static func met_lod(m: ArrayMesh) -> ArrayMesh:
	var im := ImporterMesh.new()
	for s in m.get_surface_count():
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(s), [], {}, m.surface_get_material(s))
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


static func multimesh(ouder: Node, mesh: Mesh, plekken: Array, kleuren: Array = [], schaduw := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not kleuren.is_empty()
	mm.mesh = mesh
	mm.instance_count = plekken.size()
	for i in plekken.size():
		mm.set_instance_transform(i, plekken[i])
		if mm.use_colors:
			mm.set_instance_color(i, (kleuren[i] as Color).srgb_to_linear())
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not schaduw:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ouder.add_child(mmi)
	return mmi
