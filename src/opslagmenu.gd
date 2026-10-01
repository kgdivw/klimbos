class_name Opslagmenu
extends Control

# Het lijstje opgeslagen spellen: per spel een kaartje met een klein plaatje,
# de datum en tijd, een knop Openen en een klein knopje om het weg te gooien.

signal openen(naam: String)

var _raster: GridContainer
var _leeg: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var achter := ColorRect.new()
	achter.color = Color(0.12, 0.08, 0.04, 0.6)
	achter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(achter)

	var paneel := PanelContainer.new()
	paneel.add_theme_stylebox_override("panel", Schets.stijl(Color(0.99, 0.95, 0.85), Color(0.8, 0.6, 0.38), 24, 4))
	Schets.zet(paneel, Control.PRESET_CENTER, Vector2(-470, -300), Vector2(940, 600))
	add_child(paneel)
	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 12)
	paneel.add_child(kolom)

	var kop := HBoxContainer.new()
	kolom.add_child(kop)
	var titel := Label.new()
	titel.text = "Opgeslagen spellen"
	titel.add_theme_font_size_override("font_size", 32)
	titel.add_theme_color_override("font_color", Color(0.45, 0.3, 0.18))
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kop.add_child(titel)
	var terug := Button.new()
	terug.text = "  Terug  "
	terug.focus_mode = Control.FOCUS_NONE
	terug.add_theme_font_size_override("font_size", 22)
	terug.add_theme_color_override("font_color", Color(0.35, 0.25, 0.15))
	Schets.knop_stijlen(terug, Color(1, 1, 1), Color(0.8, 0.65, 0.45), 3)
	terug.pressed.connect(func(): visible = false)
	kop.add_child(terug)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kolom.add_child(scroll)
	_raster = GridContainer.new()
	_raster.columns = 3
	_raster.add_theme_constant_override("h_separation", 16)
	_raster.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_raster)

	_leeg = Label.new()
	_leeg.text = "Je hebt nog niets opgeslagen.\nDruk op Opslaan om je spel te bewaren!"
	_leeg.add_theme_font_size_override("font_size", 22)
	_leeg.add_theme_color_override("font_color", Color(0.5, 0.38, 0.25))
	kolom.add_child(_leeg)


func toon() -> void:
	for kind in _raster.get_children():
		kind.queue_free()
	var spellen := Opslag.lijst()
	_leeg.visible = spellen.is_empty()
	for s in spellen:
		_raster.add_child(_kaartje(s))
	visible = true


func _kaartje(s: Dictionary) -> Control:
	var kaart := PanelContainer.new()
	var stijl := Schets.stijl(Color(1, 1, 1), Color(0.85, 0.72, 0.52), 16, 3)
	stijl.content_margin_left = 10
	stijl.content_margin_right = 10
	stijl.content_margin_top = 10
	stijl.content_margin_bottom = 10
	kaart.add_theme_stylebox_override("panel", stijl)
	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 6)
	kaart.add_child(kolom)

	var plaatje := TextureRect.new()
	plaatje.custom_minimum_size = Vector2(260, 146)
	plaatje.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plaatje.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	plaatje.texture = s["plaatje"]
	kolom.add_child(plaatje)

	var datum := Label.new()
	datum.text = Opslag.tijd_tekst(s["tijd"])
	datum.add_theme_font_size_override("font_size", 18)
	datum.add_theme_color_override("font_color", Color(0.4, 0.28, 0.16))
	kolom.add_child(datum)
	var info := Label.new()
	var n: int = s["stukken"]
	info.text = "%d %s gebouwd" % [n, "ding" if n == 1 else "dingen"]
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(0.55, 0.45, 0.35))
	kolom.add_child(info)

	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 8)
	kolom.add_child(rij)
	var open := Button.new()
	open.text = "Openen"
	open.focus_mode = Control.FOCUS_NONE
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open.add_theme_font_size_override("font_size", 20)
	open.add_theme_color_override("font_color", Color(1, 1, 1))
	open.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	Schets.knop_stijlen(open, Color(0.32, 0.72, 0.3), Color(1, 1, 1), 2)
	var naam: String = s["naam"]
	open.pressed.connect(func():
		visible = false
		openen.emit(naam))
	rij.add_child(open)
	var weg := Button.new()
	weg.text = "weg"
	weg.focus_mode = Control.FOCUS_NONE
	weg.add_theme_font_size_override("font_size", 15)
	weg.add_theme_color_override("font_color", Color(0.55, 0.3, 0.3))
	Schets.knop_stijlen(weg, Color(1, 0.92, 0.9), Color(0.9, 0.6, 0.55), 2)
	weg.pressed.connect(func():
		if weg.text != "zeker?":
			weg.text = "zeker?"
			Schets.knop_stijlen(weg, Color(1, 0.6, 0.55), Color(0.9, 0.4, 0.35), 2)
			return
		Opslag.wis(naam)
		toon())
	rij.add_child(weg)
	return kaart
