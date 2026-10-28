extends SceneTree
## Prüft, ob Sektor 7 beim echten Spielstart Gegner hat, die man sieht und die sich bewegen.
## Startet wie ein Spieler: Hauptmenü -> Mapauswahl "SEKTOR 7" (MainMenu._start_game).
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_sector7_enemies.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Absichtlich ohne die Klassennamen Enemy/EnemyDirector: Ein -s-Skript wird vor den Autoloads
## kompiliert, typisierte Verweise würden dann Skripte laden, die `Settings` noch nicht kennen.

const SLUM := "res://scenes/slum/slum.tscn"
## Gegner, die man vom Spawn aus sehen soll.
const NEAR_SPAWN := [&"S_StreetGunner", &"S_CornerThug"]
const LOD_FULL := 0

var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _wait_frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	await _wait_frames(10)
	var menu := current_scene
	_check(menu != null and menu.has_method("_start_game"), "Hauptmenü geladen")
	_check(SLUM in menu.get("maps").values(), "Sektor 7 steht in der Mapauswahl")
	menu.call("_start_game", SLUM)
	var slum := current_scene
	for i in 300:
		if current_scene != null and current_scene.scene_file_path == SLUM:
			break
		await physics_frame
	slum = current_scene
	_check(slum != null and slum.scene_file_path == SLUM, "Sektor 7 über das Menü gestartet")

	var director: Node = get_first_node_in_group(&"enemy_director")
	_check(director != null, "EnemyDirector in der Spielszene")
	for i in 600:
		if director != null and director.get("is_nav_ready"):
			break
		await physics_frame
	_check(director != null and director.get("is_nav_ready"), "Navmesh gebacken")

	var enemies: Array[Node3D] = []
	for node: Node in get_nodes_in_group(&"enemy"):
		if node is CharacterBody3D and slum.is_ancestor_of(node):
			enemies.append(node)
	_check(enemies.size() >= 18, "mindestens 18 Gegner in der Szene (%d)" % enemies.size())

	var player := get_first_node_in_group("player") as Node3D
	_check(player != null, "Spielerfigur vorhanden")
	if player == null or enemies.is_empty():
		_finish()
		return

	var all_visible := true
	for e in enemies:
		var meshes := e.find_children("*", "MeshInstance3D", true, false)
		if not e.is_visible_in_tree() or meshes.is_empty():
			all_visible = false
			print("    unsichtbar: ", e.name)
	_check(all_visible, "alle Gegner sichtbar und mit Modell")

	# Vom Spawn aus: Gegner in Sichtweite, im Bild und ohne Wand dazwischen.
	await _wait_frames(30)
	var cam := slum.get_viewport().get_camera_3d()
	var space := player.get_world_3d().direct_space_state
	for enemy_name in NEAR_SPAWN:
		var e := slum.find_child(enemy_name, true, false) as Node3D
		_check(e != null, "%s vorhanden" % enemy_name)
		if e == null or cam == null:
			continue
		var head := e.global_position + Vector3.UP * 1.5
		var dist := cam.global_position.distance_to(head)
		var query := PhysicsRayQueryParameters3D.create(cam.global_position, head, 1, [player.get_rid()])
		var hit := space.intersect_ray(query)
		var free_line: bool = hit.is_empty() or hit.collider == e or e.is_ancestor_of(hit.collider)
		_check(dist < 45.0 and cam.is_position_in_frustum(head) and free_line,
			"%s vom Spawn aus zu sehen (%.0f m)" % [enemy_name, dist])

	# Streifen bewegen sich, auch weit weg (LOD LOW). Schlafende hinter sleep_distance zählen nicht.
	# Weg aufsummieren (Rundkurse können nach 20 s wieder nah am Start sein).
	var walked := {}
	var last := {}
	for e in enemies:
		walked[e] = 0.0
		last[e] = e.global_position
	for i in 40:
		await _wait_frames(30)
		for e in enemies:
			walked[e] += (last[e] as Vector3).distance_to(e.global_position)
			last[e] = e.global_position
	var moved_near := 0
	var moved_far := 0
	var stuck: Array[String] = []
	for e in enemies:
		if (e.get("route") as NodePath).is_empty():
			continue
		var dist := e.global_position.distance_to(player.global_position)
		var d: float = walked[e]
		if dist > float(director.get("sleep_distance")):
			continue
		if d > 3.0:
			if e.get("lod") == LOD_FULL:
				moved_near += 1
			else:
				moved_far += 1
		else:
			stuck.append("%s %.1f m" % [e.name, d])
	_check(stuck.is_empty(), "alle wachen Streifen laufen in 20 s mehr als 3 m %s" % [stuck])
	_check(moved_far >= 2, "auch entfernte Streifen (LOD LOW) laufen (%d)" % moved_far)
	_check(moved_near >= 1, "Streife nahe am Spawn läuft (%d)" % moved_near)
	for e in enemies:
		print("    %s weg %.1f m, Zustand %d, LOD %d" % [e.name, walked[e], e.get("state"), e.get("lod")])
	_finish()


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
