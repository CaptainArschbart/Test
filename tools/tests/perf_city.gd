extends SceneTree
## Misst die Bildrate in Sektor 7 an festen Punkten (mit Fenster, nicht headless).
##
## Aufruf (Projektordner):
##   godot --path . -s res://tools/tests/perf_city.gd
## Nimmt die gespeicherten Einstellungen (auch Vollbild/Auflösung), schaltet VSync und
## FPS-Grenze nur für die Messung ab und speichert nichts. Danach werden einzelne Effekte
## abgeschaltet, um ihre Kosten zu sehen.

const SLUM := "res://scenes/slum/slum.tscn"
const POINTS: Array[Vector3] = [
	Vector3(0, 1.7, 0), Vector3(5.8, 1.7, 62), Vector3(40, 1.7, 30), Vector3(-30, 1.7, -40),
]
const FRAMES := 90

var _settings: Node
var _cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_settings = root.get_node("Settings")
	_settings.set("vsync", false)
	_settings.call("apply")
	Engine.max_fps = 0
	change_scene_to_file(SLUM)
	await _wait(5)
	var nav: Node = get_first_node_in_group(&"enemy_director")
	for i in 900:
		if nav == null or nav.get("is_nav_ready"):
			break
		await process_frame
	await _wait(120)
	_cam = Camera3D.new()
	current_scene.add_child(_cam)
	_cam.current = true
	_cam.fov = 75.0
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	print("Fenster ", DisplayServer.window_get_size(), " scale3d ", root.scaling_3d_scale,
		" msaa ", root.msaa_3d)

	await _measure("gespeichert")
	var base := _snapshot()
	if "--nur-logik" in OS.get_cmdline_user_args():
		await _logic_measures()
		quit(0)
		return
	_settings.set("volumetric_fog", false)
	_settings.call("apply")
	await _measure("ohne Vol.-Nebel")
	_restore(base)
	_settings.set("ssao_enabled", false)
	_settings.call("apply")
	await _measure("ohne SSAO")
	_restore(base)
	_settings.set("gi_mode", 0)
	_settings.call("apply")
	await _measure("ohne SSR/GI")
	_restore(base)
	_settings.set("glow_enabled", false)
	_settings.call("apply")
	await _measure("ohne Glow")
	_restore(base)
	_settings.set("render_scale", 0.5)
	_settings.call("apply")
	await _measure("3D 50 %")
	_restore(base)
	await _logic_measures()
	quit(0)


func _logic_measures() -> void:
	_print_processing()
	if "--basis" in OS.get_cmdline_user_args():
		current_scene.process_mode = Node.PROCESS_MODE_DISABLED
		await _measure("Map angehalten")
		current_scene.process_mode = Node.PROCESS_MODE_INHERIT
		return
	for script in ["slum_flicker.gd", "shop_interior.gd", "pickup.gd", "civilian_crime.gd", "enemy.gd"]:
		var nodes := _nodes_with_script(script)
		for n in nodes:
			n.set_process(false)
			n.set_physics_process(false)
		await _measure("ohne " + script)
		for n in nodes:
			n.set_process(true)
			n.set_physics_process(true)
	for path in ["SlumLife/Traffic", "SlumLife/Crowd", "SlumEnemies"]:
		var n := current_scene.get_node_or_null(path)
		if n == null:
			print("fehlt: ", path)
			continue
		n.process_mode = Node.PROCESS_MODE_DISABLED
		await _measure("ohne " + path)
		n.process_mode = Node.PROCESS_MODE_INHERIT


func _nodes_with_script(file: String) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var s: Script = n.get_script()
		if s != null and s.resource_path.ends_with("/" + file):
			out.append(n)
	return out


## Zählt Knoten mit _process/_physics_process je Skript bzw. Typ.
func _print_processing() -> void:
	var counts := {}
	var stack: Array[Node] = [root]
	var total := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		total += 1
		for c in n.get_children():
			stack.append(c)
		if not (n.is_processing() or n.is_physics_processing()):
			continue
		var s: Script = n.get_script()
		var key: String = s.resource_path if s != null else n.get_class()
		key += (" P" if n.is_processing() else "") + (" F" if n.is_physics_processing() else "")
		counts[key] = int(counts.get(key, 0)) + 1
	print("Knoten gesamt ", total)
	for k in counts:
		if counts[k] >= 3:
			print("  %4d  %s" % [counts[k], k])


func _snapshot() -> Dictionary:
	var d := {}
	for k in ["volumetric_fog", "ssao_enabled", "gi_mode", "glow_enabled", "render_scale", "shadow_quality"]:
		d[k] = _settings.get(k)
	return d


func _restore(d: Dictionary) -> void:
	for k in d:
		_settings.set(k, d[k])
	_settings.call("apply")


func _measure(label: String) -> void:
	var vp := root.get_viewport_rid()
	var total_ms := 0.0
	var gpu_ms := 0.0
	var cpu_ms := 0.0
	var n := 0
	var worst := 0.0
	var draws := 0
	var objs := 0
	var prims := 0
	for p in POINTS:
		for yaw in [0.0, 90.0, 180.0, 270.0]:
			_cam.global_position = p
			_cam.rotation_degrees = Vector3(-4, yaw, 0)
			await _wait(8)
			var t0 := Time.get_ticks_usec()
			for f in FRAMES:
				await process_frame
				gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(vp)
				cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(vp) \
					+ RenderingServer.get_frame_setup_time_cpu()
			var view_ms := float(Time.get_ticks_usec() - t0) / 1000.0 / FRAMES
			worst = maxf(worst, view_ms)
			total_ms += view_ms
			n += 1
			draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			objs = maxi(objs, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
			prims = maxi(prims, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	var avg := total_ms / n
	var frames := float(n * FRAMES)
	print("%-16s  %5.1f fps (schlechteste Sicht %5.1f)  GPU %5.1f ms  Render-CPU %5.1f ms  Process %5.1f ms  Physik %5.1f ms  Draws %d  Objekte %d  Dreiecke %d" % [
		label, 1000.0 / avg, 1000.0 / worst, gpu_ms / frames, cpu_ms / frames,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, draws, objs, prims])
	print("   Navigation %.1f ms  Knoten %d  Physik-Paare %d  aktive Koerper %d" % [Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
