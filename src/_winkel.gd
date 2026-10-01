extends Node

# Maakt de plaatjes voor de Play Store (alleen om te draaien met --write-movie).
# "banner" als argument = feature graphic (1024x500), anders schermafbeeldingen.

var main: Node3D
var f := 0
var keten: Array = []
var banner := false
var shots := {}   # frame -> naam
var sv: SubViewport

func _ready() -> void:
	banner = OS.get_cmdline_user_args().has("banner")
	main = load("res://scenes/main.tscn").instantiate()
	# Renderen in een eigen beeld van precies de goede maat (het venster mag
	# niet groter worden dan het scherm van de laptop).
	sv = SubViewport.new()
	sv.size = Vector2i(1024, 500) if banner else Vector2i(1920, 1080)
	sv.size_2d_override = Vector2i(1024, 500) if banner else Vector2i(1280, 720)
	sv.size_2d_override_stretch = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	sv.add_child(main)


func _bewaar(naam: String) -> void:
	await RenderingServer.frame_post_draw
	var map := ProjectSettings.globalize_path("res://winkel/") 
	var pad := map + ("feature_graphic_1024x500.png" if banner else "schermafbeeldingen/" + naam + ".png")
	sv.get_texture().get_image().save_png(pad)
	print("bewaard ", pad)

func _keten() -> Array:
	var bos: Bos = main.bos
	var a := bos.dichtste_boom(Vector3(9, 0, -4), 20)
	var k := [a]
	for n in 5:
		var laatste: Vector3 = bos.boom_pos(k[k.size() - 1])
		var beste := -1
		var bx := -INF
		for i in bos.bomen.size():
			var p: Vector3 = bos.boom_pos(i)
			var d := Vector2(p.x - laatste.x, p.z - laatste.z).length()
			if d > 5.5 and d < 10.0 and p.x > laatste.x + 2.0 and absf(p.z - laatste.z) < 7 and not k.has(i):
				if p.x - absf(p.z + 4) > bx:
					bx = p.x - absf(p.z + 4)
					beste = i
		if beste < 0:
			break
		k.append(beste)
	return k

func _teken_plan() -> void:
	var bos: Bos = main.bos
	var schets: Schets = main.schets
	var pts := PackedVector2Array()
	for i in keten.size() - 1:
		pts.append(Schets.wereld_naar_papier(bos.boom_pos(keten[i])))
	schets.lijnen.append({"k": 1, "d": 9.0, "p": pts})
	schets.lijnen.append({"k": 7, "d": 9.0, "p": PackedVector2Array([Schets.wereld_naar_papier(bos.boom_pos(keten[keten.size() - 2])), Schets.wereld_naar_papier(bos.boom_pos(keten[keten.size() - 1]))])})
	for i in keten.size():
		var c := Schets.wereld_naar_papier(bos.boom_pos(keten[i]))
		schets.lijnen.append({"k": 2, "d": 4.0, "p": PackedVector2Array([c + Vector2(-12, -12), c + Vector2(12, 12)])})
		schets.lijnen.append({"k": 2, "d": 4.0, "p": PackedVector2Array([c + Vector2(12, -12), c + Vector2(-12, 12)])})
	# een tweede, rode lus en een paar sterretjes erbij
	var s0 := Schets.wereld_naar_papier(Vector3(-20, 0, 10))
	var lus := PackedVector2Array()
	for i in 40:
		var h := TAU * i / 39.0
		lus.append(s0 + Vector2(cos(h) * 120, sin(h) * 60))
	schets.lijnen.append({"k": 9, "d": 9.0, "p": lus})
	schets.lijnen.append({"k": 6, "d": 18.0, "p": PackedVector2Array([Schets.wereld_naar_papier(Vector3(-40, 0, -20)), Schets.wereld_naar_papier(Vector3(-28, 0, -26)), Schets.wereld_naar_papier(Vector3(-15, 0, -20))])})
	schets._ververs()

func _zet_cam(pos: Vector3, yaw_graden: float, pitch: float, afstand: float) -> void:
	var sp: Speler = main.speler
	sp.global_position = pos
	sp.yaw = deg_to_rad(yaw_graden)
	sp.pitch = pitch
	sp.afstand = afstand
	sp.draaipunt.global_position = pos + Vector3(0, 1.25, 0)

# Zoek rond `doel` een camerastandpunt waar geen stam tussen zit.
func _vrij_zicht(doel: Vector3, afstand: float, hoogte: float) -> Dictionary:
	var ruimte := main.get_world_3d().direct_space_state
	for i in 36:
		var hoek := deg_to_rad(200.0 + i * 10.0)
		var plek := doel + Vector3(cos(hoek), 0, sin(hoek)) * afstand
		plek.y = hoogte
		var q := PhysicsRayQueryParameters3D.create(plek, doel, 2 | 4)
		var vrij := ruimte.intersect_ray(q).is_empty()
		# ook een beetje breedte: links en rechts van de kijklijn
		var zij := Vector3(-sin(hoek), 0, cos(hoek)) * 1.2
		for z in [zij, -zij]:
			if not ruimte.intersect_ray(PhysicsRayQueryParameters3D.create(plek + z, doel + z * 0.3, 2)).is_empty():
				vrij = false
		if vrij:
			var naar := doel - plek
			return {"plek": plek, "yaw": rad_to_deg(atan2(-naar.x, -naar.z)), "pitch": -atan2(plek.y - doel.y, Vector2(naar.x, naar.z).length())}
	return {}


func _camera_op(doel: Vector3, afstand: float, hoogte: float) -> void:
	var z := _vrij_zicht(doel, afstand, hoogte)
	if z.is_empty():
		return
	var sp: Speler = main.speler
	_zet_cam(z["plek"] - Vector3(0, 1.25, 0), z["yaw"], z["pitch"], 0.3)
	sp.verstopt = true


func _process(_d: float) -> void:
	f += 1
	var bos: Bos = main.bos
	var sp: Speler = main.speler
	if f == 3:
		keten = _keten()
		_teken_plan()
		if not banner:
			main._zet_aanraak(true)
	if f == 12 and not banner:
		_bewaar("1_schets")  #
	if f == 14:
		main._naar_bos()
		sp.bevroren = true
		main._express_bouw(keten[0], keten[keten.size() - 1])
		Engine.time_scale = 8.0
		if banner:
			main.hud.visible = false
	if f == 120:
		Engine.time_scale = 1.0
	var mid: Vector3 = bos.boom_pos(keten[2]) if keten.size() > 2 else Vector3.ZERO
	if banner:
		if f == 121:
			_zet_cam(mid + Vector3(-9, 2.5, 9), -40, -0.12, 6)
			var titel := Label.new()
			titel.text = "Het Klimbos"
			titel.add_theme_font_size_override("font_size", 120)
			titel.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
			titel.add_theme_color_override("font_outline_color", Color(0.38, 0.22, 0.08))
			titel.add_theme_constant_override("outline_size", 28)
			titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			Schets.zet(titel, Control.PRESET_CENTER_TOP, Vector2(-600, 30), Vector2(1200, 170))
			main.hud.get_parent().add_child(titel)
			main._toast.visible = false
		if f == 131:
			_bewaar("banner")
		if f == 134:
			get_tree().quit()
		return
	if f == 121:
		main._toast.modulate.a = 0.0
		# Uitzicht vanaf het eerste platform, over het parcours heen.
		var p0: Node3D = main.bouw.platforms[0]
		var c0: Vector3 = p0.get_meta("midden")
		var c2: Vector3 = bos.boom_pos(keten[2])
		var r := Vector3(c2.x - c0.x, 0, c2.z - c0.z).normalized()
		var plek := c0 + r.rotated(Vector3.UP, 0.5) * (float(p0.get_meta("straal")) - 0.6) + Vector3(0, 0.45, 0)
		var naar := Vector3(c2.x, c0.y, c2.z) - plek
		_zet_cam(plek, rad_to_deg(atan2(-naar.x, -naar.z)) + 8.0, -0.12, 0.3)
		sp.verstopt = true
	if f == 128:
		_bewaar("2_parcours")  #
		# volg een vriendje dat op een brug of platform staat
		var doel: Vriendje = main.vriendjes[0]
		for v: Vriendje in main.vriendjes:
			if v.staat == "brug":
				doel = v
		set_meta("volg", doel)
	if f >= 129 and f < 140:
		var v: Vriendje = get_meta("volg")
		if f == 129:
			set_meta("vriend_cam", _vrij_zicht(v.global_position + Vector3(0, 0.8, 0), 4.5, v.global_position.y + 1.8))
		var z: Dictionary = get_meta("vriend_cam")
		if not z.is_empty():
			var naar := v.global_position + Vector3(0, 0.8, 0) - (z["plek"] as Vector3)
			_zet_cam(z["plek"] - Vector3(0, 1.25, 0), rad_to_deg(atan2(-naar.x, -naar.z)), -atan2(-naar.y, Vector2(naar.x, naar.z).length()), 0.3)
		sp.verstopt = true
	if f == 139:
		_bewaar("3_vriendjes")  #
	if f == 141:
		sp.verstopt = false
		main.hud.kies(1)
		# Een boom vlak naast het parcours, met een groen voorbeeld-platform erop.
		var a: Vector3 = bos.boom_pos(keten[0])
		var beste := -1
		for i in bos.bomen.size():
			var d := Vector2(bos.boom_pos(i).x - a.x, bos.boom_pos(i).z - a.z).length()
			if d > 6.0 and d < 9.0 and not keten.has(i):
				beste = i
				break
		set_meta("doelboom", beste)
		var b: Vector3 = bos.boom_pos(beste)
		var z := _vrij_zicht(b + Vector3(0, 2.5, 0), 6.5, 2.2)
		var plek: Vector3 = z.get("plek", b + Vector3(5, 2.2, 5))
		var naar := b + Vector3(0, 2.8, 0) - plek
		_zet_cam(plek - Vector3(0, 1.25, 0), rad_to_deg(atan2(-naar.x, -naar.z)) - 18.0, -0.02, 2.8)
	if f >= 142 and f < 150:
		var doelboom: int = get_meta("doelboom")
		var hp := bos.boom_pos(doelboom) + Vector3(0, 3.6, 0)
		var naar := sp.camera.global_position - hp
		naar.y = 0
		var n := naar.normalized()
		var r: float = float(bos.bomen[doelboom]["r"])
		# Na het spel-frame, anders zet de echte muis het spookbeeld weer ergens anders.
		main.call_deferred("_werk_spook", {"punt": hp + n * r, "normaal": n, "boom": doelboom, "stuk": null, "grond": false})
	if f == 149:
		_bewaar("4_bouwen")  #
	if f == 151:
		sp.verstopt = false
		sp.afstand = 4
		main._annuleer()
		main.hud.kies(-1)
		for t in main.bouw.tokkels:
			var a: Vector3 = t["a"]
			_zet_cam(a - Vector3(0, Bouw.KABEL_HOOGTE - 0.1, 0), 0, -0.1, 4)
			sp.bevroren = false
			sp.begin_tokkelen(t)
			break
	if f > 151 and f < 175 and sp.staat == "tokkelen":
		var t: Dictionary = main.bouw.tokkels[0]
		var r: Vector3 = (t["b"] as Vector3) - (t["a"] as Vector3)
		sp.yaw = atan2(-r.x, -r.z) + 0.5
		sp.pitch = -0.1
	if f == 157:
		_bewaar("5_tokkelen")  #
	if f == 176:
		sp.bevroren = true
		_zet_cam(Vector3(2, 0.1, 6), -20, -0.2, 6)
		main.opslagmenu.toon()
	if f == 182:
		_bewaar("6_opslaan")  #
	if f == 186:
		get_tree().quit()
