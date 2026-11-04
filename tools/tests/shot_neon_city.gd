extends SceneTree
## Screenshots der Neon City aus festen Blickwinkeln (Straße, Skywalk, Bezirke, Luftbild).
##
## Aufruf (Projektordner, mit Fenster bzw. Xvfb):
##   SHOT_OUT=/pfad godot --path . -s res://tools/tests/shot_neon_city.gd
## SHOT_ONLY = nur ein Blickwinkel (Name), SHOT_TIME = Tageszeit 0..1 (Standard Nacht). Pro Blickwinkel entsteht <name>.png (halbe Auflösung).

var OUT := OS.get_environment("SHOT_OUT")
## Name: [Kamera, Blickziel]. Alle Kameras stehen auf Gehwegen oder dem Skywalk (fest, unabhängig vom Seed).
const VIEWS := {
	"start": [Vector3(9.0, 1.7, 44.0), Vector3(0.0, 6.0, 0.0)],
	"skywalk": [Vector3(19.0, 8.7, 6.0), Vector3(-10.0, 9.0, -19.0)],
	"overview": [Vector3(40.0, 190.0, 150.0), Vector3(0.0, 0.0, -10.0)],
	"neonmeile": [Vector3(78.6, 1.7, -14.0), Vector3(80.0, 4.0, -60.0)],
	"harbor": [Vector3(-36.0, 1.7, -72.0), Vector3(-36.0, 3.0, -120.0)],
	"under": [Vector3(-80.0, 1.7, 36.0), Vector3(-110.0, 3.0, 36.0)],
	"blocks": [Vector3(40.0, 1.7, 65.5), Vector3(110.0, 14.0, 80.0)],
	"ring": [Vector3(-150.0, 1.7, 100.0), Vector3(-150.0, 10.0, 20.0)],
	"kernhof": [Vector3(26.0, 9.0, -26.0), Vector3(32.5, 0.0, -36.5)],
	"ganghof": [Vector3(-92.0, 10.0, -38.0), Vector3(-103.0, 0.0, -49.0)],
	"ampel": [Vector3(-60.0, 1.7, -58.0), Vector3(-72.0, 3.0, -72.0)],
	"fassade": [Vector3(40.0, 1.7, 66.0), Vector3(52.0, 14.0, 84.0)],
	"unterstadt": [Vector3(-80.0, 1.7, -20.0), Vector3(-80.0, 6.0, 20.0)],
	"dach": [Vector3(100.0, 40.0, 30.0), Vector3(110.0, 10.0, 0.0)],
	"galerie": [Vector3(100.0, 1.7, -38.0), Vector3(114.0, 6.0, -50.0)],
	"gasse_neon": [Vector3(82.0, 1.7, -37.8), Vector3(95.0, 4.0, -37.8)],
	"gasse_unter": [Vector3(-82.0, 1.7, -36.5), Vector3(-95.0, 4.0, -36.5)],
	"galerie_oben": [Vector3(112.0, 7.7, -50.0), Vector3(96.0, 5.0, -30.0)],
}


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://scenes/neon_city/neon_city.tscn")
	await _frames(30)
	# Eigene Kamera ohne Spieler-HUD.
	for layer in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	# SHOT_TIME: Tageszeit 0..1 (0 = Mitternacht, 0,5 = Mittag), Standard Nacht.
	var atmosphere := current_scene.get_node_or_null("WorldAtmosphere")
	if atmosphere != null:
		atmosphere.set("time_of_day", float(OS.get_environment("SHOT_TIME")) if OS.get_environment("SHOT_TIME") != "" else 0.02)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 900.0
	current_scene.add_child(cam)
	cam.make_current()
	var only := OS.get_environment("SHOT_ONLY")
	for name: String in VIEWS:
		if only != "" and only != name:
			continue
		cam.global_position = VIEWS[name][0]
		cam.look_at(VIEWS[name][1])
		await _frames(25)
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		img.save_png(OUT.path_join(name + ".png"))
		print("shot ", name)
	quit()
