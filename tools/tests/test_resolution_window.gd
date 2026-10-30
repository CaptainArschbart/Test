extends SceneTree
## Fenstergrößen 1080p / 1440p / 4K, Randlos-Vollbild und GI-Umschalten.
##
## Aufruf mit Fenster (nicht --headless):
##   godot --path . -s res://tools/tests/test_resolution_window.gd
## Headless prüft die reine Skalierungsrechnung und das Environment, überspringt das Fenster.
## Letzte Zeile: "CHECKS n FAILS m". apply() speichert nicht.

const TARGETS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var _checks := 0
var _fails := 0
var _settings: Node
var _saved: Dictionary


func _initialize() -> void:
	_run()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  FAIL " + what)
	else:
		print("  ok   " + what)


func _run() -> void:
	await process_frame
	_settings = root.get_node("Settings")
	_saved = _settings.call("get_values")
	_formula()
	await _graphics_live()
	if DisplayServer.get_name() == "headless":
		print("  skip Fenster: DisplayServer headless")
	else:
		await _window_modes()
	_restore()
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(_fails)


func _formula() -> void:
	for size: Vector2i in TARGETS:
		var scale: float = _settings.call("scale_for_window", 1.0, size)
		var expect := 1.0 if maxi(size.x, size.y) <= 1920 else 1920.0 / float(maxi(size.x, size.y))
		_check(is_equal_approx(scale, expect), "3D-Faktor %s = %.4f" % [size, scale])
	var quality: Dictionary = _settings.call("upscale_for", 1)
	var off: Dictionary = _settings.call("upscale_for", 0)
	_check(float(off["scale"]) == 1.0 and int(off["mode"]) == Viewport.SCALING_3D_MODE_BILINEAR, "Upscale aus bleibt bilinear")
	_check(is_equal_approx(float(quality["scale"]), 0.77), "DLSS-Qualität ist ein Faktor, kein zweites Seitenverhältnis")


func _graphics_live() -> void:
	var host := Node3D.new()
	host.name = "GfxProbe"
	root.add_child(host)
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	env.fog_density = 0.009
	world.environment = env
	host.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Moon"
	host.add_child(sun)
	var atmosphere: Node = load("res://scenes/world/world_atmosphere.gd").new()
	host.add_child(atmosphere)
	var live := world.environment
	var env_id := live.get_instance_id()
	var broken := false
	var counts: Array[int] = []
	for cycle in 8:
		for mode: int in [0, 1, 2]:
			_settings.set("gi_mode", mode)
			_settings.call("apply")
			var high: bool = mode == 2
			var normal: bool = mode >= 1
			if live.sdfgi_enabled != high or live.ssr_enabled != normal or live.get_instance_id() != env_id:
				broken = true
				_check(false, "GI %d Zyklus %d sdfgi=%s ssr=%s" % [mode, cycle, live.sdfgi_enabled, live.ssr_enabled])
		counts.append(int(Performance.get_monitor(Performance.OBJECT_COUNT)))
	_check(not broken, "8 Zyklen: GI sofort, dasselbe Environment %d" % env_id)
	for _i in 10:
		await process_frame
	_check(live.sdfgi_enabled == (int(_settings.get("gi_mode")) == 2), "SDFGI bleibt nach 10 Frames stabil")
	var tail := counts[counts.size() - 1] - counts[0]
	_check(tail < 25, "Objektzahl vom 1. zum 8. GI-Zyklus %+d (%s)" % [tail, counts])
	host.queue_free()


func _window_modes() -> void:
	var screen := DisplayServer.screen_get_size()
	print("  SCREEN %s stretch=%s aspect=%s" % [screen, root.content_scale_mode, root.content_scale_aspect])
	_check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "UI-Stretch ist canvas_items")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "UI-Aspekt ist expand")
	var probe := ColorRect.new()
	probe.name = "AspectProbe"
	probe.custom_minimum_size = Vector2(200, 100)
	probe.size = Vector2(200, 100)
	probe.position = Vector2(48, 36)
	probe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(probe)
	var menu := load("res://scenes/options/options_menu.tscn").instantiate() as Control
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	await process_frame
	_settings.set("fullscreen", false)
	_settings.set("render_scale", 1.0)
	_settings.set("upscale_mode", 0)
	var sizes: Array[Vector2i] = TARGETS.duplicate()
	sizes.append(Vector2i(1280, 800))
	for target: Vector2i in sizes:
		var fit := Vector2i(mini(target.x, screen.x), mini(target.y, screen.y))
		if screen.x < 640 or fit.x < 640 or fit.y < 360:
			print("  skip Fenster %s, Monitor %s" % [target, screen])
			continue
		_settings.set("resolution", Vector2i(800, 600))
		_settings.call("apply")
		await process_frame
		_settings.set("resolution", fit)
		_settings.call("apply")
		await process_frame
		await process_frame
		var win := DisplayServer.window_get_size()
		var mode := DisplayServer.window_get_mode()
		_check(mode == DisplayServer.WINDOW_MODE_WINDOWED, "%s Fenstermodus, ist %s" % [fit, mode])
		_check(win == fit, "Fenster %s, bekommen %s" % [fit, win])
		var canvas := probe.get_global_transform_with_canvas()
		var sx := canvas.x.length()
		var sy := canvas.y.length()
		_check(sx > 0.01 and is_equal_approx(sx, sy), "UI-Skalierung uniform x=%.4f y=%.4f bei %s" % [sx, sy, win])
		_check(is_equal_approx(probe.size.x / probe.size.y, 2.0), "Probe bleibt 2:1, ist %.3f" % (probe.size.x / probe.size.y))
		var viewport := root.get_viewport()
		var expect: float = _settings.call("scale_for_window", 1.0, win)
		_check(is_equal_approx(viewport.scaling_3d_scale, expect), "scaling_3d_scale %.4f erwartet %.4f" % [viewport.scaling_3d_scale, expect])
		_check(viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR, "ohne Upscale bilinear")
		var title := menu.find_child("Header", true, false) as Control
		if title != null:
			var title_scale := title.get_global_transform_with_canvas()
			_check(is_equal_approx(title_scale.x.length(), title_scale.y.length()), "Menü-Titel uniform bei %s" % win)
	_settings.set("upscale_mode", 1)
	_settings.call("apply")
	await process_frame
	var win_now := DisplayServer.window_get_size()
	var quality_scale: float = float((_settings.call("upscale_for", 1) as Dictionary)["scale"])
	var expect_up: float = _settings.call("scale_for_window", quality_scale, win_now)
	expect_up = clampf(expect_up, 0.25, 1.0)
	var canvas_after := probe.get_global_transform_with_canvas()
	_check(is_equal_approx(root.get_viewport().scaling_3d_scale, expect_up), "FSR2-Faktor %.4f erwartet %.4f" % [root.get_viewport().scaling_3d_scale, expect_up])
	_check(root.get_viewport().scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2, "Upscale-Modus ist FSR2")
	_check(is_equal_approx(canvas_after.x.length(), canvas_after.y.length()), "UI bleibt uniform, wenn nur scaling_3d_scale sinkt")
	_settings.set("fullscreen", true)
	_settings.set("upscale_mode", 0)
	_settings.call("apply")
	await process_frame
	await process_frame
	var full_mode := DisplayServer.window_get_mode()
	_check(full_mode == DisplayServer.WINDOW_MODE_FULLSCREEN, "Vollbild ist randlos (WINDOW_MODE_FULLSCREEN), ist %s" % full_mode)
	var full_canvas := probe.get_global_transform_with_canvas()
	_check(is_equal_approx(full_canvas.x.length(), full_canvas.y.length()), "Randlos: UI uniform x=%.4f y=%.4f" % [full_canvas.x.length(), full_canvas.y.length()])
	probe.queue_free()
	menu.queue_free()


func _restore() -> void:
	_settings.set("fullscreen", _saved["fullscreen"])
	_settings.set("vsync", _saved["vsync"])
	_settings.set("resolution", _saved["resolution"])
	_settings.set("fullscreen_resolution", _saved["fullscreen_resolution"])
	_settings.set("msaa", _saved["msaa"])
	_settings.set("render_scale", _saved["render_scale"])
	_settings.set("gi_mode", _saved["gi_mode"])
	_settings.set("upscale_mode", _saved["upscale_mode"])
	_settings.set("draw_distance", _saved["draw_distance"])
	_settings.set("shadow_quality", _saved["shadow_quality"])
	_settings.set("ssao_enabled", _saved["ssao_enabled"])
	_settings.set("glow_enabled", _saved["glow_enabled"])
	_settings.set("volumetric_fog", _saved["volumetric_fog"])
	_settings.call("apply")
