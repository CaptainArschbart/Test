extends SceneTree
## Prüft die vergrößerte Sektor-7-Map mit Fußgängern und Autos (PR #35).
## Startet wie ein Spieler: Hauptmenü -> Mapauswahl "SEKTOR 7".
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_sector7_city.gd
## Letzte Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne die Klassennamen TrafficCar/Civilian usw. (ein -s-Skript wird vor den Autoloads kompiliert).

const SLUM := "res://scenes/slum/slum.tscn"
const STATE_FLEE := 3
const STATE_COWER := 4
const STATE_DEAD := 6

var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	await _wait(10)
	current_scene.call("_start_game", SLUM)
	for i in 300:
		if current_scene != null and current_scene.scene_file_path == SLUM:
			break
		await physics_frame
	var slum := current_scene
	_check(slum != null and slum.scene_file_path == SLUM, "Sektor 7 über das Menü gestartet")
	var nav: Node = get_first_node_in_group(&"enemy_director")
	for i in 900:
		if nav.get("is_nav_ready"):
			break
		await physics_frame
	_check(nav.get("is_nav_ready"), "Navmesh gebacken")
	await _map_checks(slum)
	await _traffic_checks()
	await _civilian_checks()
	_finish()


# --- Map ----------------------------------------------------------------------------------

func _map_checks(slum: Node) -> void:
	var north := slum.get_node_or_null("Bounds/North") as Node3D
	_check(north != null and is_equal_approx(north.position.z, -136.0), "Kartengrenze bei 136 m")
	for part in ["Ring", "OuterNorth", "OuterEast", "OuterSouth", "OuterWest", "OuterCorners"]:
		var n := slum.get_node_or_null(part)
		_check(n != null and n.get_child_count() > 10, "Bereich %s gebaut (%d Teile)" % [part, n.get_child_count() if n else 0])
	var nav := get_first_node_in_group(&"enemy_director") as Node3D
	var map: RID = nav.get_world_3d().navigation_map
	var player := get_first_node_in_group("player") as Node3D
	var start: Vector3 = NavigationServer3D.map_get_closest_point(map, player.global_position)
	# Navmesh reicht in jedes Außenviertel und ist vom Spawn aus erreichbar.
	for target: Vector3 in [Vector3(0, 0, -104), Vector3(104, 0, 0), Vector3(-30, 0, 106), Vector3(-104, 0, 0),
			Vector3(112, 0, 103), Vector3(-110, 0, -106)]:
		var goal: Vector3 = NavigationServer3D.map_get_closest_point(map, target)
		# In zwei Abschnitten über die Ringstraße (eine einzelne Wegsuche über die ganze Map bricht
		# bei sehr vielen Polygonen vorher ab).
		var via: Vector3 = NavigationServer3D.map_get_closest_point(map, Vector3(clampf(target.x, -90.5, 90.5), 0.2,
				clampf(target.z, -90.5, 90.5)))
		var reached := _path_reaches(map, start, via) and _path_reaches(map, via, goal)
		_check(Vector2(goal.x - target.x, goal.z - target.z).length() < 2.0 and reached,
				"Navmesh erreicht %s vom Spawn" % target)
	# Spawn auf dem Gehweg, nicht auf der Fahrbahn.
	_check(absf(player.global_position.x) > 4.6, "Spawn liegt auf dem Gehweg (x = %.1f)" % player.global_position.x)


func _path_reaches(map: RID, from: Vector3, to: Vector3) -> bool:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	return not path.is_empty() and Vector2(path[path.size() - 1].x - to.x, path[path.size() - 1].z - to.z).length() < 1.0


# --- Autos --------------------------------------------------------------------------------

func _traffic_checks() -> void:
	var traffic: Node = get_first_node_in_group(&"traffic_director")
	_check(traffic != null, "TrafficDirector vorhanden")
	if traffic == null:
		return
	var cars: Array = traffic.get("cars")
	_check(cars.size() >= 14, "mindestens 14 Autos (%d)" % cars.size())
	var kinds := {}
	for car in cars:
		kinds[car.get("model").get("kind")] = true
	_check(kinds.size() >= 4, "mindestens 4 Fahrzeugmodelle (%d)" % kinds.size())
	_check(cars.all(func(c): return not c.is_in_group(&"enemy") and c.find_children("*", "MeshInstance3D", true, false).size() > 2),
			"Autos haben Modelle und sind keine Gegner")
	# Spieler weit weg von der Straße parken, damit er den Verkehr nicht stört.
	var player := get_first_node_in_group("player") as CharacterBody3D
	var stats: Node = player.get("stats")
	stats.set("invulnerable", true)
	player.global_position = Vector3(30, 0.1, 37)
	var start := {}
	var travelled := {}
	var junctions := {}
	for car in cars:
		start[car] = car.global_position
		travelled[car] = 0.0
		junctions[car] = 0
	var min_gap := INF
	var last := {}
	for car in cars:
		last[car] = car.global_position
	for i in 60 * 45:
		await physics_frame
		if i % 10 != 0:
			continue
		for car in cars:
			travelled[car] += Vector2(car.global_position.x - last[car].x, car.global_position.z - last[car].z).length()
			last[car] = car.global_position
			if car.call("piece").is_turn:
				junctions[car] += 1
		for a in range(cars.size()):
			for b in range(a + 1, cars.size()):
				min_gap = minf(min_gap, _car_gap(cars[a], cars[b]))
	var slow := []
	for car in cars:
		if travelled[car] < 60.0:
			slow.append("%s %.0f m" % [car.name, travelled[car]])
	_check(slow.is_empty(), "alle Autos fahren in 45 s mehr als 60 m %s" % [slow])
	var through := 0
	for car in cars:
		if junctions[car] > 0:
			through += 1
	_check(through >= cars.size() - 2, "Autos fahren durch Kreuzungen (%d von %d)" % [through, cars.size()])
	_check(min_gap > 0.0, "keine zwei Autos ineinander (kleinster Abstand %.2f m)" % min_gap)
	await _stop_for_player(traffic, player, stats)


## Abstand zwischen den Umrissen zweier Autos (Rechtecke, grob über Eckpunkte), < 0 = Überlappung.
func _car_gap(a: Node3D, b: Node3D) -> float:
	var d := a.global_position.distance_to(b.global_position)
	if d > 8.0:
		return d
	var best := INF
	for car_pair in [[a, b], [b, a]]:
		var me: Node3D = car_pair[0]
		var other: Node3D = car_pair[1]
		var m: Node = other.get("model")
		var hl: float = m.get("half_length")
		var hw: float = m.get("half_width")
		var mm: Node = me.get("model")
		var inv := other.global_transform.affine_inverse()
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner: Vector3 = me.global_transform * Vector3(sx * float(mm.get("half_width")), 0.5, sz * float(mm.get("half_length")))
				var l := inv * corner
				var dx := absf(l.x) - hw
				var dz := absf(l.z) - hl
				best = minf(best, maxf(dx, dz))
	return best


## Spieler steht auf der Spur: Auto hält an, hupt, fährt dann vorbei. Springt er knapp davor,
## wird er weggestoßen und verletzt (moderat).
func _stop_for_player(traffic: Node, player: CharacterBody3D, stats: Node) -> void:
	var car: Node3D = null
	for c in traffic.get("cars"):
		var p = c.call("piece")
		if not p.is_turn and p.length - float(c.get("s")) > 45.0 and float(c.get("speed")) > 5.0:
			car = c
			break
	_check(car != null, "Auto für den Bremstest gefunden")
	if car == null:
		return
	var piece = car.call("piece")
	var spot: Vector3 = piece.point_at(float(car.get("s")) + 28.0)
	player.global_position = spot + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	var hp_before: float = stats.get("hp") if stats.get("hp") != null else 100.0
	var stopped := false
	var honked := false
	var min_dist := INF
	var horn: AudioStreamPlayer3D = null
	for child in car.get_children():
		if child is AudioStreamPlayer3D and child.stream == load("res://scenes/traffic/vehicle_sounds.gd").horn():
			horn = child
	var passed := false
	for i in 60 * 20:
		player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
		player.velocity = Vector3.ZERO
		await physics_frame
		var local: Vector3 = car.global_transform.affine_inverse() * player.global_position
		if absf(float(car.get("offset"))) < 0.2 and absf(local.x) < 1.5:
			min_dist = minf(min_dist, -local.z - float(car.get("model").get("half_length")))
		if float(car.get("speed")) < 0.1 and -local.z > 0.0:
			stopped = true
		if horn != null and horn.playing:
			honked = true
		if local.z > 1.0:
			passed = true
			break
	_check(stopped, "Auto hält vor dem Spieler")
	_check(min_dist > 0.5, "hält mit Abstand (%.1f m vor der Stoßstange)" % min_dist)
	_check(honked, "Auto hupt")
	_check(passed, "Auto fährt seitlich vorbei, wenn der Spieler stehen bleibt")
	_check(stats.get("hp") == null or is_equal_approx(float(stats.get("hp")), hp_before), "kein Schaden beim Anhalten")
	# Jetzt knapp vor ein schnelles Auto springen.
	stats.set("invulnerable", false)
	player.global_position = Vector3(30, 0.1, 37)
	var fast: Node3D = null
	for i in 60 * 10:
		for c in traffic.get("cars"):
			var p = c.call("piece")
			if not p.is_turn and float(c.get("speed")) > 7.0 and p.length - float(c.get("s")) > 12.0:
				fast = c
				break
		if fast != null:
			break
		await physics_frame
	_check(fast != null, "schnelles Auto für den Unfalltest gefunden")
	if fast == null:
		return
	var hp0: float = stats.get("hp")
	var p2 = fast.call("piece")
	var front: Vector3 = p2.point_at(float(fast.get("s")) + float(fast.get("model").get("half_length")) + 0.6)
	player.global_position = front + Vector3.UP * 0.1
	var pushed := 0.0
	for i in 30:
		await physics_frame
		pushed = maxf(pushed, player.velocity.length())
	var lost := hp0 - float(stats.get("hp"))
	_check(lost >= 3.0 and lost <= 30.0, "angefahren: moderater Schaden (%.1f HP)" % lost)
	_check(pushed > 3.0, "angefahren: Spieler wird weggestoßen (%.1f m/s)" % pushed)
	stats.call("restore_all")
	stats.set("invulnerable", true)
	player.global_position = Vector3(30, 0.1, 37)


# --- Fußgänger ----------------------------------------------------------------------------

func _civilian_checks() -> void:
	var crowd: Node = get_first_node_in_group(&"crowd_director")
	_check(crowd != null, "CrowdDirector vorhanden")
	if crowd == null:
		return
	var civs: Array = crowd.get("civilians")
	_check(civs.size() >= 35, "mindestens 35 Fußgänger (%d)" % civs.size())
	_check(civs.all(func(c): return c.is_in_group(&"civilian") and not c.is_in_group(&"enemy")), "Fußgänger sind keine Gegner")
	var player := get_first_node_in_group("player") as CharacterBody3D
	# Zur Hauptkreuzung, dort ist am meisten los; Fußgänger im Umkreis beobachten.
	player.global_position = Vector3(6.5, 0.3, 14.0)
	# Fußgänger weit weg werden nach und nach in die Nähe der Kamera verlegt.
	await _wait(60 * 25)
	var watch: Array = []
	for c in civs:
		if is_instance_valid(c) and c.global_position.distance_to(player.global_position) < 50.0:
			watch.append(c)
	_check(watch.size() >= 5, "Fußgänger in der Nähe der Kreuzung (%d)" % watch.size())
	var start := {}
	for c in watch:
		start[c] = c.global_position
	var on_road := 0
	var samples := 0
	var crossed := false
	var fell := false
	for i in 60 * 40:
		await physics_frame
		if i % 15 != 0:
			continue
		for c in civs:
			if not is_instance_valid(c):
				continue
			if c.global_position.y < -1.0:
				fell = true
			if int(c.get("lod")) == 2:
				continue
			samples += 1
			var crossing: bool = c.get("_crossing") or int(c.get("state")) >= STATE_FLEE
			if _on_roadway(c.global_position):
				if crossing:
					crossed = true
				else:
					on_road += 1
	var moving := 0
	for c in watch:
		if is_instance_valid(c) and Vector2(c.global_position.x - start[c].x, c.global_position.z - start[c].z).length() > 4.0:
			moving += 1
	_check(moving >= int(watch.size() * 0.7), "Fußgänger laufen herum (%d von %d mehr als 4 m)" % [moving, watch.size()])
	_check(float(on_road) / maxf(samples, 1) < 0.04, "Fußgänger bleiben auf Gehwegen (%d von %d Proben auf der Fahrbahn)" % [on_road, samples])
	_check(crossed, "Fußgänger benutzen Zebrastreifen")
	_check(not fell, "kein Fußgänger fällt durch den Boden")
	# Schuss in der Nähe: Panik.
	# Der nächste wache Fußgänger (Schuss wird direkt neben ihm abgegeben).
	var near: Node3D = null
	var best := 60.0
	for c in civs:
		if is_instance_valid(c) and int(c.get("state")) < STATE_FLEE and int(c.get("lod")) != 2:
			var d: float = c.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				near = c
	_check(near != null, "Fußgänger für den Schuss-Test gefunden")
	if near != null:
		var shot_at := near.global_position + Vector3(3, 0, 0)
		var noise := load("res://scenes/stealth/stealth_noise.gd")
		noise.emit(self, shot_at, 35.0, player, &"shot")
		await _wait(10)
		var st := int(near.get("state"))
		_check(st == STATE_FLEE or st == STATE_COWER, "Schuss: Fußgänger flieht oder duckt sich (Zustand %d)" % st)
		await _wait(60 * 6)
		_check(near.global_position.distance_to(shot_at) > 8.0, "Schuss: Fußgänger ist weggelaufen (%.1f m)" % near.global_position.distance_to(shot_at))
		# Tödlicher Treffer.
		near.call("take_hit", 200.0, near.global_position + Vector3.UP, Vector3.FORWARD)
		await _wait(5)
		_check(int(near.get("state")) == STATE_DEAD, "Treffer: Fußgänger stirbt")


## Liegt der Punkt auf einer Fahrbahn (Hauptstraßen und Ringstraße, 4,5 m halbe Breite)?
func _on_roadway(p: Vector3) -> bool:
	if p.y > 0.1:
		return false  # Gehweg liegt 0,15 m höher
	var on_x := absf(p.x) < 4.3 and absf(p.z) < 88.0
	var on_z := absf(p.z) < 4.3 and absf(p.x) < 88.0
	var ring := (absf(absf(p.x) - 84.0) < 4.3 and absf(p.z) < 88.5) or (absf(absf(p.z) - 84.0) < 4.3 and absf(p.x) < 88.5)
	return on_x or on_z or ring


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
