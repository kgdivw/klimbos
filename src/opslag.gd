class_name Opslag
extends RefCounted

# Opgeslagen spellen staan in user://opslag (op Windows:
# %APPDATA%\Godot\app_userdata\Het Klimbos\opslag). Elk spel bestaat uit twee
# bestanden met dezelfde naam: <naam>.dat (de tekening, alles wat je gebouwd
# hebt en waar je stond) en <naam>.png (het kleine plaatje).
#
# Het bos zelf hoeft niet bewaard te worden: dat wordt altijd precies
# hetzelfde opgebouwd, dus boomnummers in de bouwplannen blijven kloppen.

const MAP := "user://opslag"
const MAANDEN := ["jan", "feb", "mrt", "apr", "mei", "jun", "jul", "aug", "sep", "okt", "nov", "dec"]


static func bewaar(data: Dictionary, plaatje: Image) -> String:
	DirAccess.make_dir_recursive_absolute(MAP)
	var naam := "spel_%d" % int(Time.get_unix_time_from_system() * 1000.0)
	var f := FileAccess.open(MAP + "/" + naam + ".dat", FileAccess.WRITE)
	if f == null:
		return ""
	f.store_var(data)
	f.close()
	if plaatje != null:
		plaatje.save_png(MAP + "/" + naam + ".png")
	return naam


static func laad(naam: String) -> Dictionary:
	var f := FileAccess.open(MAP + "/" + naam + ".dat", FileAccess.READ)
	if f == null:
		return {}
	var data = f.get_var()
	f.close()
	return data if data is Dictionary else {}


# Nieuwste eerst: [{naam, tijd, plaatje (Texture2D of null)}]
static func lijst() -> Array:
	var uit := []
	var dir := DirAccess.open(MAP)
	if dir == null:
		return uit
	for bestand in dir.get_files():
		if not bestand.ends_with(".dat"):
			continue
		var naam := bestand.get_basename()
		var data := laad(naam)
		if data.is_empty():
			continue
		var plaatje: Texture2D = null
		var img := Image.load_from_file(ProjectSettings.globalize_path(MAP + "/" + naam + ".png"))
		if img != null and not img.is_empty():
			plaatje = ImageTexture.create_from_image(img)
		uit.append({"naam": naam, "tijd": float(data.get("tijd", 0.0)), "plaatje": plaatje, "stukken": (data.get("stukken", []) as Array).size()})
	uit.sort_custom(func(a, b): return a["tijd"] > b["tijd"])
	return uit


static func wis(naam: String) -> void:
	DirAccess.remove_absolute(MAP + "/" + naam + ".dat")
	DirAccess.remove_absolute(MAP + "/" + naam + ".png")


# "1 okt 2026  om 14:32" in de tijd van de computer.
static func tijd_tekst(unix: float) -> String:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(int(unix) + bias * 60)
	return "%d %s %d  om %02d:%02d" % [d["day"], MAANDEN[int(d["month"]) - 1], d["year"], d["hour"], d["minute"]]
