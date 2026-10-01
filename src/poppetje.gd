class_name Poppetje
extends Node3D

# Een klimmertje met een helmpje: de speler en de vriendjes zien er zo uit,
# elk met hun eigen kleuren en kapsel. Lijf en hoofd zijn één mesh; armen en
# benen zijn los zodat ze kunnen zwaaien. Het gezicht kijkt naar +Z.

var lijf: Node3D
var benen: Array[Node3D] = []
var armen: Array[Node3D] = []
var stoeltje: MeshInstance3D
var _anim := 0.0


# kleuren: shirt, broek, helm, haar, huid (alles mag ontbreken); kapsel: 0 kort,
# 1 twee staartjes, 2 paardenstaart.
func _init(kleuren := {}, kapsel := 0) -> void:
	var huid: Color = kleuren.get("huid", Color(1.0, 0.8, 0.66))
	var shirt: Color = kleuren.get("shirt", Color(0.98, 0.45, 0.32))
	var broek: Color = kleuren.get("broek", Color(0.3, 0.5, 0.85))
	var helm: Color = kleuren.get("helm", Color(1.0, 0.8, 0.2))
	var haar: Color = kleuren.get("haar", Color(0.45, 0.28, 0.15))

	lijf = Node3D.new()
	add_child(lijf)
	var b := Vorm.Bouwer.new()
	# Lijf met tuigje
	b.bol(0.24, Vector3(0, 0.72, 0), shirt, Vector3(1, 1.15, 0.85), true)
	b.cil(0.22, 0.22, 0.08, Vector3(0, 0.5, 0), Color(0.25, 0.25, 0.3), 12)
	b.blok(Vector3(0.06, 0.3, 0.02), Vector3(0.1, 0.7, 0.2), Color(0.25, 0.25, 0.3), Basis(Vector3.FORWARD, 0.2))
	b.blok(Vector3(0.06, 0.3, 0.02), Vector3(-0.1, 0.7, 0.2), Color(0.25, 0.25, 0.3), Basis(Vector3.FORWARD, -0.2))
	b.bol(0.05, Vector3(0, 0.52, 0.22), Color(0.95, 0.6, 0.15))  # karabiner
	# Groot rond hoofd
	var hoofd := Vector3(0, 1.12, 0)
	b.bol(0.27, hoofd, huid, Vector3.ONE, true)
	b.bol(0.07, hoofd + Vector3(-0.27, -0.01, 0), huid)
	b.bol(0.07, hoofd + Vector3(0.27, -0.01, 0), huid)
	# Ogen met lichtpuntje, blosjes, neusje en een lachje
	for s: float in [-1.0, 1.0]:
		b.bol(0.058, hoofd + Vector3(0.1 * s, 0.03, 0.238), Color(0.12, 0.1, 0.1), Vector3(0.85, 1.15, 0.7))
		b.bol(0.02, hoofd + Vector3(0.1 * s + 0.017, 0.06, 0.276), Color(1, 1, 1))
		b.bol(0.05, hoofd + Vector3(0.17 * s, -0.07, 0.2), Color(1.0, 0.55, 0.55), Vector3(1, 0.6, 0.4))
	b.bol(0.035, hoofd + Vector3(0, -0.03, 0.27), huid.darkened(0.08))
	b.blok(Vector3(0.09, 0.022, 0.02), hoofd + Vector3(0, -0.11, 0.25), Color(0.6, 0.25, 0.2))
	# Haar en klimhelmpje
	b.bol(0.28, hoofd + Vector3(0, 0.04, -0.03), haar, Vector3(1.02, 0.95, 1.0))
	match kapsel:
		1:
			for s: float in [-1.0, 1.0]:
				b.bol(0.11, hoofd + Vector3(0.3 * s, -0.08, -0.05), haar, Vector3(0.8, 1.2, 0.8))
				b.bol(0.035, hoofd + Vector3(0.27 * s, 0.02, -0.04), Color(1.0, 0.4, 0.6))
		2:
			b.bol(0.1, hoofd + Vector3(0, -0.06, -0.3), haar, Vector3(0.8, 1.6, 0.8))
			b.bol(0.04, hoofd + Vector3(0, 0.07, -0.29), Color(0.4, 0.75, 1.0))
	b.bol(0.3, hoofd + Vector3(0, 0.08, 0), helm, Vector3(1.0, 0.82, 1.02), true)
	b.cil(0.31, 0.31, 0.04, hoofd + Vector3(0, 0.05, 0.01), helm.darkened(0.15), 16)
	b.bol(0.05, hoofd + Vector3(0, 0.12, 0.27), Color(1, 1, 1), Vector3(1.4, 0.8, 0.5))  # lampje
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	lijf.add_child(mi)

	# Losse benen en armen, zodat ze kunnen zwaaien.
	for s: float in [-1.0, 1.0]:
		var been := Node3D.new()
		been.position = Vector3(0.11 * s, 0.5, 0)
		add_child(been)
		var bb := Vorm.Bouwer.new()
		bb.cil(0.085, 0.08, 0.4, Vector3(0, -0.2, 0), broek, 8)
		bb.bol(0.11, Vector3(0, -0.45, 0.04), Color(0.55, 0.3, 0.2), Vector3(1, 0.7, 1.4))
		var bm := MeshInstance3D.new()
		bm.mesh = bb.mesh()
		been.add_child(bm)
		benen.append(been)

		var arm_n := Node3D.new()
		arm_n.position = Vector3(0.25 * s, 0.86, 0)
		add_child(arm_n)
		var ab := Vorm.Bouwer.new()
		ab.cil(0.065, 0.06, 0.32, Vector3(0, -0.16, 0), shirt, 8)
		ab.bol(0.075, Vector3(0, -0.36, 0), huid)
		var am := MeshInstance3D.new()
		am.mesh = ab.mesh()
		arm_n.add_child(am)
		armen.append(arm_n)

	# Het touwzadeltje dat alleen zichtbaar is tijdens het tokkelen.
	var zb := Vorm.Bouwer.new()
	zb.cil(0.24, 0.24, 0.07, Vector3(0, 0.42, 0), Bouw.ROOD, 12)
	zb.cil(0.2, 0.2, 0.08, Vector3(0, 0.47, 0), Color(1.0, 0.82, 0.3), 12)
	zb.staaf(Vector3(0, 0.45, 0), Vector3(0, 2.15, 0), 0.025, Bouw.TOUW)
	zb.bol(0.11, Vector3(0, 2.2, 0), Bouw.ROOD)
	stoeltje = MeshInstance3D.new()
	stoeltje.mesh = zb.mesh()
	stoeltje.visible = false
	add_child(stoeltje)


func kijk_naar(r: Vector3, delta: float, snel := 12.0) -> void:
	if Vector2(r.x, r.z).length() < 0.01:
		return
	var doel := atan2(r.x, r.z)
	rotation.y = lerp_angle(rotation.y, doel, clampf(delta * snel, 0, 1))


func animeer(delta: float, soort: String, tempo: float) -> void:
	_anim += delta * tempo
	var z := sin(_anim)
	match soort:
		"lopen":
			benen[0].rotation.x = z * 0.7
			benen[1].rotation.x = -z * 0.7
			armen[0].rotation.x = -z * 0.6
			armen[1].rotation.x = z * 0.6
			armen[0].rotation.z = 0
			armen[1].rotation.z = 0
			lijf.position.y = absf(z) * 0.05
		"stil":
			for d in benen + armen:
				d.rotation.x = lerpf(d.rotation.x, 0, clampf(delta * 10, 0, 1))
			armen[0].rotation.z = 0
			armen[1].rotation.z = 0
			lijf.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.012
		"zwaaien":
			for d in benen:
				d.rotation.x = lerpf(d.rotation.x, 0, clampf(delta * 10, 0, 1))
			armen[0].rotation.x = 0
			armen[1].rotation.x = -2.8
			armen[1].rotation.z = 0.35 + z * 0.4
			lijf.position.y = absf(z) * 0.02
		"klimmen":
			armen[0].rotation.x = -2.6 + z * 0.45
			armen[1].rotation.x = -2.6 - z * 0.45
			benen[0].rotation.x = -0.5 - z * 0.45
			benen[1].rotation.x = -0.5 + z * 0.45
			lijf.position.y = 0
		"tokkelen":
			armen[0].rotation.x = -2.9
			armen[1].rotation.x = -2.9
			armen[0].rotation.z = -0.15
			armen[1].rotation.z = 0.15
			benen[0].rotation.x = -1.3 + z * 0.15
			benen[1].rotation.x = -1.3 - z * 0.15
			lijf.position.y = 0
		"vallen":
			armen[0].rotation.x = -2.2
			armen[1].rotation.x = -2.2
			benen[0].rotation.x = 0.3
			benen[1].rotation.x = -0.3
