extends SceneTree
## Prüft das Alltagsverhalten der Fußgänger (Schedule 1, P5-8) und die Frauenfiguren (P5-9) in der
## Neon City:
##   - Sitzplätze: zwei je Bank (70 Bänke, 1,1 m lang, Sitzfläche 0,40 m hoch),
##   - Hinsetzen: Fußgänger geht zur Bank, sitzt mit dem Becken über der Sitzfläche, Füße am Boden,
##     steht nach der Sitzzeit wieder auf, der Platz wird frei,
##   - Reden: zwei stehende Fußgänger nebeneinander wenden sich zu und spielen Idle_Talking,
##   - Gewohnheiten: Handy am Ohr bzw. Kiste vor der Brust (Oberkörper-Ebene), auch im Gehen,
##   - Frauen: kommen unter den Fußgängern vor und tragen die Frauen-Bibliothek (ual_mw.res).
## Zugriff auf Civilian und CrowdDirector ohne Typ-Verweis (beide brauchen das Autoload WorldSync,
## das beim Kompilieren dieses Skripts noch nicht da ist).
##
## Aufruf (Projektordner), headless reicht:
##   godot --headless --path . -s res://tools/tests/test_civilian_life.gd
## Letzte Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const MAP := "res://scenes/neon_city/neon_city.tscn"
const CIVILIAN := "res://scenes/civilians/civilian.gd"
const CROWD := "res://scenes/civilians/crowd_director.gd"
## Zustände und Detailstufe aus civilian.gd.
const IDLE := 1
const FLEE := 3
const SIT := 7
const LOD_FULL := 0

var _checks := 0
var _fails := 0
var _crowd: Node3D
var _player: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	var left := s
	while left > 0.0:
		await physics_frame
		left -= root.get_physics_process_delta_time()


func _run() -> void:
	change_scene_to_file(MAP)
	for i in 10:
		await physics_frame
	var director := get_first_node_in_group(&"enemy_director")
	var waited := 0
	while director != null and not director.get("is_nav_ready") and waited < 1200:
		await physics_frame
		waited += 1
	await _frames(20)
	_crowd = get_first_node_in_group(&"crowd_director") as Node3D
	_player = get_first_node_in_group(&"player") as Node3D
	_check(_crowd != null and _civs().size() > 10, "Fußgänger da (%d)" % _civs().size())
	if _crowd == null or _player == null:
		_finish()
		return
	await _test_seats()
	await _test_talk()
	await _test_habits()
	_test_women()
	_finish()


func _civs() -> Array:
	return _crowd.get("civilians") if _crowd != null else []


func _state(civ: Node) -> int:
	return int(civ.get("state"))


## Fußgänger, der gerade nichts Besonderes tut.
func _pick(skip: Array, habit := 0) -> Node3D:
	for civ: Node3D in _civs():
		if is_instance_valid(civ) and not bool(civ.call("is_dead")) and not skip.has(civ) \
				and int(civ.get("habit")) == habit and _state(civ) != FLEE and _state(civ) != SIT:
			return civ
	return null


func _keep_awake(civ: Node3D) -> void:
	civ.set("lod", LOD_FULL)


func _test_seats() -> void:
	print("Sitzen auf Bänken")
	var count := int(_crowd.call("seat_count"))
	_check(count == 140, "Zwei Sitzplätze je Bank (%d)" % count)
	var civ := _pick([])
	if civ == null or count == 0:
		_check(false, "Fußgänger und Bank zum Sitzen gefunden")
		return
	var seat: Vector3 = _crowd.call("seat_point", 0)
	var face: Vector3 = _crowd.call("seat_face", 0)
	var bench_seat: Vector3 = (load(CROWD) as GDScript).get_script_constant_map()["BENCH_SEAT"]
	var ground := seat.y - bench_seat.y * 0.55
	# Spieler daneben, sonst legt der CrowdDirector den Fußgänger schlafen oder verlegt ihn.
	_player.global_position = Vector3(seat.x, ground + 0.1, seat.z) + face * 6.0
	await _frames(5)
	_keep_awake(civ)
	civ.global_position = Vector3(seat.x, ground + 0.05, seat.z) + face * 3.0
	civ.reset_physics_interpolation()
	await _frames(3)
	var ok := bool(civ.call("_try_seat"))
	_check(ok and int(civ.get("_seat")) >= 0, "Freien Sitzplatz in der Nähe belegt")
	var sat := false
	for i in 900:
		if _state(civ) == SIT:
			sat = true
			break
		_keep_awake(civ)
		await physics_frame
	_check(sat, "Geht zur Bank und setzt sich")
	if not sat:
		return
	for i in 120:
		_keep_awake(civ)
		await physics_frame
	var model := civ.get("model") as CharacterModel
	_check(model != null and model.is_seated(), "Spielt Sitzen (%s)" % (model._anim.current_animation if model != null else "-"))
	var sk := model.ragdoll_skeleton
	var hips := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin
	var used: Vector3 = _crowd.call("seat_point", int(civ.get("_seat")))
	var side := Vector2(hips.x - used.x, hips.z - used.z).length()
	_check(side < 0.2 and hips.y - used.y > 0.0 and hips.y - used.y < 0.15,
		"Becken über der Sitzfläche (%.2f m daneben, %.2f m darüber)" % [side, hips.y - used.y])
	var feet := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot.L"))).origin
	_check(feet.y - ground > -0.04 and feet.y - ground < 0.1, "Füße am Boden (%.2f m darüber)" % (feet.y - ground))
	_check(int(_crowd.call("claim_seat", used, 0.05, null)) < 0, "Platz ist belegt")
	civ.set("_wait_left", 0.0)
	for i in 150:
		_keep_awake(civ)
		await physics_frame
	_check(_state(civ) != SIT and not model.is_seated(), "Steht nach der Sitzzeit wieder auf (Zustand %d)" % _state(civ))
	var again := int(_crowd.call("claim_seat", used, 0.05, null))
	_check(again >= 0, "Platz wieder frei")
	_crowd.call("release_seat", again)


func _test_talk() -> void:
	print("Reden")
	var a := _pick([])
	var b := _pick([a])
	if a == null or b == null:
		_check(false, "Zwei Fußgänger zum Reden gefunden")
		return
	var spot := _player.global_position + Vector3(2.0, -0.05, 0.0)
	a.global_position = spot
	b.global_position = spot + Vector3(1.4, 0.0, 0.0)
	for civ: Node3D in [a, b]:
		civ.reset_physics_interpolation()
		_keep_awake(civ)
		civ.call("_set_state", IDLE)
		civ.set("_wait_left", 30.0)
	for i in 180:
		_keep_awake(a)
		_keep_awake(b)
		await physics_frame
	var ma := a.get("model") as CharacterModel
	var mb := b.get("model") as CharacterModel
	_check(ma.talk and mb.talk, "Beide reden (%s, %s)" % [ma.talk, mb.talk])
	_check(ma._anim.current_animation == CharacterModel.TALK, "Spielt Idle_Talking (%s)" % ma._anim.current_animation)
	var fa := -a.global_basis.z
	var to_b := b.global_position - a.global_position
	_check(Vector2(fa.x, fa.z).normalized().dot(Vector2(to_b.x, to_b.z).normalized()) > 0.8, "Schaut den anderen an")
	for civ: Node3D in [a, b]:
		civ.set("_wait_left", 0.0)


func _test_habits() -> void:
	print("Gewohnheiten")
	for habit in [1, 2]:
		var civ := _pick([], habit)
		if civ == null:
			# Keiner mit dieser Gewohnheit unterwegs: einen neuen mit passendem Seed erzeugen.
			civ = _spawn_with_habit(habit)
			await _frames(5)
		else:
			civ.global_position = _player.global_position + Vector3(-2.0, 0.0, 1.0)
			civ.reset_physics_interpolation()
		var model := civ.get("model") as CharacterModel
		var label := "Handy" if habit == 1 else "Kiste"
		_check(model._overlay != null and model._prop != null, "%s: Oberkörper-Ebene und Gegenstand" % label)
		if model._overlay == null:
			continue
		if _state(civ) == IDLE:
			civ.set("_wait_left", 0.0)
		for i in 90:
			_keep_awake(civ)
			await physics_frame
		_check(model._overlay.pose_weight > 0.9 and model._prop.visible,
			"%s: aktiv im Alltag (Gewicht %.2f, Tempo %.1f)" % [label, model._overlay.pose_weight, model.speed])
		var sk := model.ragdoll_skeleton
		var seen := [Vector3.INF, Vector3.INF, Vector3.INF]
		sk.skeleton_updated.connect(func() -> void:
			seen[0] = model._prop.global_position
			seen[1] = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin
			seen[2] = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Chest"))).origin, CONNECT_ONE_SHOT)
		await _frames(3)
		if habit == 1:
			_check(seen[0].distance_to(seen[1]) < 0.25, "Handy am Kopf (%.2f m)" % seen[0].distance_to(seen[1]))
		else:
			var d: float = seen[0].distance_to(seen[2])
			_check(d < 0.5 and seen[0].y < seen[2].y + 0.1, "Kiste vor der Brust (%.2f m)" % d)


func _spawn_with_habit(habit: int) -> Node3D:
	var consts := (load(CIVILIAN) as GDScript).get_script_constant_map()
	var phone: int = consts["PHONE_SHARE"]
	var carry: int = consts["CARRY_SHARE"]
	for s in 400:
		var roll := posmod(s * 7919 + 13, 100)
		var h := 1 if roll < phone else (2 if roll < phone + carry else 0)
		if h == habit:
			var fresh: Node3D = (load(CIVILIAN) as GDScript).new()
			fresh.call("setup", _crowd, int(_crowd.call("nearest_node", _player.global_position)), s)
			fresh.position = _player.global_position + Vector3(-2.0, 0.05, 1.0)
			_crowd.add_child(fresh)
			(_crowd.get("civilians") as Array).append(fresh)
			return fresh
	return null


func _test_women() -> void:
	print("Frauen")
	var women := 0
	var library_ok := true
	for civ: Node3D in _civs():
		var model := civ.get("model") as CharacterModel
		if model == null or model._anim == null or not model.is_woman():
			continue
		women += 1
		var lib := model._anim.get_animation_library(UalLibrary.NAME)
		library_ok = library_ok and lib != null and lib.resource_path == UalLibrary.PATH_WOMAN
	_check(women > 0, "Frauen unter den Fußgängern (%d von %d)" % [women, _civs().size()])
	_check(library_ok, "Frauen tragen die eigene UAL-Bibliothek")


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
