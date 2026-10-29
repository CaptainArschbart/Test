extends SceneTree
## Hunger-Schwelle, Death-Screen, Tür, Fahndung, Upscaling, Modelle.
##
## Aufruf: godot --headless --path . -s res://tools/tests/test_content_update.gd
## Letzte Zeile: "CHECKS n FAILS m".

var _checks := 0
var _fails := 0


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
	_stats()
	_death()
	_door_and_loot()
	_wanted_and_upscale()
	_models()
	_graphics()
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(_fails)


func _stats() -> void:
	var stats: Node = load("res://scenes/survival/player_stats.gd").new()
	root.add_child(stats)
	_check(is_equal_approx(float(stats.get("hunger_drain_rate")), 0.08), "Hunger-Rate 0.08")
	_check(is_equal_approx(float(stats.get("thirst_drain_rate")), 0.12), "Durst-Rate 0.12")
	stats.set("hunger", 20.0)
	stats.set("thirst", 100.0)
	stats.set("hp", 100.0)
	stats.call("advance", 3.0)
	_check(is_equal_approx(float(stats.get("hp")), 100.0), "20 %% Hunger: kein Schaden")
	stats.set("hunger", 10.0)
	stats.call("advance", 3.0)
	_check(is_equal_approx(float(stats.get("hp")), 99.0), "10 %% Hunger: 1 Schaden")
	stats.set("hunger", 0.0)
	stats.set("thirst", 0.0)
	stats.set("hp", 100.0)
	stats.call("advance", 3.0)
	_check(is_equal_approx(float(stats.get("hp")), 97.0), "beide auf 0: 3 Schaden")
	stats.set("hunger", 100.0)
	stats.set("thirst", 100.0)
	stats.call("advance", 10.0)
	var hunger := float(stats.get("hunger"))
	_check(hunger < 99.3 and hunger > 99.0, "10 s Hunger bleibt bei %.3f" % hunger)
	stats.free()


func _death() -> void:
	var screen: Node = load("res://scenes/survival/death_screen.gd").new()
	root.add_child(screen)
	var names := ""
	for child in _all(screen):
		if child is Button:
			names += (child as Button).text + "|"
	_check(names.contains("RESPAWN") and names.contains("HAUPTMENÜ"), "Knöpfe: " + names)
	_check(not names.contains("MISSION"), "kein Missions-Knopf")
	var tone := screen.get_node("Flatline") as AudioStreamPlayer
	var wav := tone.stream as AudioStreamWAV
	_check(wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Deathsound loopt nicht")
	screen.call("show_death", &"fall", 65.0)
	var content: Control = null
	for child in _all(screen):
		if child.name == "Content" and child is Control:
			content = child
	_check(content != null and screen.visible and is_equal_approx(content.modulate.a, 1.0), "Deathscreen sofort sichtbar")
	screen.free()


func _door_and_loot() -> void:
	var door: Node = load("res://scenes/crime/locked_door.gd").new()
	door.set("key_id", "apt_a")
	root.add_child(door)
	_check(bool(door.get("locked")), "Tür startet zu")
	door.call("break_open", null)
	_check(not bool(door.get("locked")) and bool(door.call("is_open")), "Brechstange öffnet")
	var again: Node = load("res://scenes/crime/locked_door.gd").new()
	again.set("key_id", "apt_b")
	root.add_child(again)
	var wanted: Node = root.get_node("WantedManager")
	var before := int(wanted.call("star_count"))
	again.call("break_open", null)
	_check(int(wanted.call("star_count")) == mini(5, before + 1), "Einbruch +1 Stern (%d -> %d)" % [before, int(wanted.call("star_count"))])
	wanted.call("set_stars", 0)
	door.free()
	again.free()


func _wanted_and_upscale() -> void:
	var settings: Node = root.get_node("Settings")
	var off: Dictionary = settings.call("upscale_for", 0)
	var quality: Dictionary = settings.call("upscale_for", 1)
	var hybrid: Dictionary = settings.call("upscale_for", 4)
	_check(int(off["mode"]) == Viewport.SCALING_3D_MODE_BILINEAR and is_equal_approx(float(off["scale"]), 1.0), "Upscale aus = bilinear")
	_check(int(quality["mode"]) == Viewport.SCALING_3D_MODE_FSR2 and is_equal_approx(float(quality["scale"]), 0.77), "DLSS Qualität = FSR2 0.77")
	_check(int(hybrid["mode"]) == Viewport.SCALING_3D_MODE_FSR2 and float(hybrid["scale"]) < 0.5, "Hybrid senkt die Auflösung")
	var bar: Resource = load("res://scenes/items/data/crowbar.tres")
	_check(bool(bar.get("breaks_locks")) and str(bar.get("id")) == "crowbar", "Eddy bricht Schlösser")
	var m4: Resource = load("res://scenes/items/data/m4.tres")
	var ak: Resource = load("res://scenes/items/data/ak47.tres")
	_check(str(m4.get("id")) == "m4" and int(m4.get("magazine_size")) == 30 and bool(m4.get("automatic")), "M4 Magazin 30 automatisch")
	_check(str(ak.get("id")) == "ak47" and float(ak.get("damage")) > float(m4.get("damage")), "AK trifft härter als M4")


func _models() -> void:
	var model: Script = load("res://scenes/items/consumable_model.gd")
	for kind: StringName in [&"crowbar", &"jewelry", &"jewels", &"cash", &"tv", &"painting", &"computer", &"cuffs", &"ties", &"keycard"]:
		_check(bool(model.call("has_model", kind)), "Modell %s" % kind)
		var node: Node = model.call("build", kind, Color.WHITE, false)
		_check(node is Node3D and node.get_child_count() > 0, "Mesh %s" % kind)
		node.free()


func _graphics() -> void:
	var script: Script = load("res://autoload/wanted_manager.gd")
	_check(float(script.get("HIDE_SECONDS")) == 18.0, "Fahndung fällt nach 18 s einen Stern")
	var settings: Node = root.get_node("Settings")
	var saved_gi := int(settings.get("gi_mode"))
	var saved_fog := bool(settings.get("volumetric_fog"))
	var saved_far := float(settings.get("draw_distance"))
	var host := Node3D.new()
	root.add_child(host)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.fog_density = 0.009
	world.environment = env
	world.name = "WorldEnvironment"
	host.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Moon"
	host.add_child(sun)
	var atmosphere: Node = load("res://scenes/world/world_atmosphere.gd").new()
	host.add_child(atmosphere)
	env = world.environment
	settings.set("gi_mode", 0)
	settings.set("volumetric_fog", false)
	atmosphere.call("_apply_graphics")
	_check(env.fog_enabled and not env.sdfgi_enabled and not env.ssr_enabled, "GI aus: Nebel an, SDFGI und SSR aus")
	_check(not env.volumetric_fog_enabled, "volumetrischer Nebel aus")
	settings.set("gi_mode", 1)
	settings.set("volumetric_fog", true)
	atmosphere.call("_apply_graphics")
	_check(env.ssr_enabled and not env.sdfgi_enabled and env.volumetric_fog_enabled, "GI normal: SSR an, SDFGI aus")
	settings.set("gi_mode", 2)
	atmosphere.call("_apply_graphics")
	_check(env.sdfgi_enabled and env.ssr_enabled and env.ssr_max_steps == 96, "Raytraced High: SDFGI und SSR 96")
	_check(is_equal_approx(saved_far, 500.0) or saved_far >= 80.0, "Renderdistanz im erlaubten Bereich %.0f" % saved_far)
	var quality: Dictionary = settings.call("upscale_for", 1)
	var performance: Dictionary = settings.call("upscale_for", 3)
	_check(float(quality["scale"]) > float(performance["scale"]), "Qualität rendert feiner als Leistung")
	settings.set("gi_mode", saved_gi)
	settings.set("volumetric_fog", saved_fog)
	host.free()


func _all(node: Node) -> Array[Node]:
	var list: Array[Node] = []
	for child in node.get_children():
		list.append(child)
		list.append_array(_all(child))
	return list
