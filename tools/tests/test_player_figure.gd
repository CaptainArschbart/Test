extends SceneTree
## Prüft die Spielerfigur in der Außenansicht (Schedule 1, P5-7): Ein PlayerBody als fremde Figur
## (external_drive) zeigt eine Modular-Men-Figur mit UAL-Animationen statt der Grundformen.
##   - Stehen, Gehen, Joggen, Sprinten, Hocken, Springen und Landen spielen die passenden Animationen,
##   - ohne Zielen dreht sich die Figur in die Laufrichtung, beim Zielen bleibt sie in Blickrichtung
##     und läuft seitlich bzw. rückwärts mit eigenen Laufbildern,
##   - Schusswaffe in der rechten Hand, Zielen/Schuss/Nachladen als Oberkörper-Ebene,
##   - Tod (Ragdoll oder Death01) und Wiederbeleben.
##
## Aufruf (Projektordner), headless reicht:
##   godot --headless --path . -s res://tools/tests/test_player_figure.gd
## Letzte Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const TESTMAP := "res://scenes/testmap/testmap.tscn"
const PISTOL := "res://scenes/items/data/pistol.tres"
const ARENA := Vector3(-400.0, 300.0, 400.0)

var _checks := 0
var _fails := 0
var _body: Node3D
var _figure: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## `seconds` lang fremd steuern: Weltgeschwindigkeit, Boden.
func _drive(velocity: Vector3, on_floor := true, seconds := 0.6) -> void:
	var t := 0.0
	while t < seconds:
		_body.call("animate_remote", 1.0 / 60.0, velocity, on_floor)
		t += 1.0 / 60.0
		await process_frame


func _anim() -> String:
	return (_figure.get("_anim") as AnimationPlayer).current_animation


func _run() -> void:
	change_scene_to_file(TESTMAP)
	for i in 300:
		if current_scene != null and current_scene.scene_file_path == TESTMAP:
			break
		await process_frame
	await _frames(10)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor.add_child(shape)
	current_scene.add_child(floor)
	floor.global_position = ARENA + Vector3(0, -0.5, 0)
	var host := Node3D.new()
	current_scene.add_child(host)
	host.global_position = ARENA
	_body = (load("res://scenes/player/player_body.gd") as GDScript).new()
	host.add_child(_body)
	await _frames(2)
	_body.set("first_person", false)
	_body.set("external_drive", true)
	_body.call("use_figure", 3)
	# Lädt im Hintergrund: warten, bis die Figur da ist.
	for i in 600:
		_body.call("animate_remote", 1.0 / 60.0, Vector3.ZERO, true)
		_figure = _body.call("get_figure")
		if _figure != null:
			break
		await process_frame
	_check(_figure != null and _figure.get("_anim") != null, "Fremde Figur als Modular-Men-Figur (%s)" % (_figure.get("look_name") if _figure != null else "-"))
	if _figure == null:
		_finish()
		return
	_check(not (_body.get("_hips") as Node3D).visible, "Grundformen ausgeblendet")
	await _test_moves()
	await _test_weapon()
	await _test_death()
	_finish()


func _test_moves() -> void:
	print("Laufen")
	await _drive(Vector3.ZERO)
	_check(_anim() == "ual/Idle", "Steht: %s" % _anim())
	await _drive(Vector3(0, 0, -1.5))
	_check(_anim() == "ual/Walk", "1,5 m/s: %s" % _anim())
	await _drive(Vector3(0, 0, -5.0))
	_check(_anim() == "ual/Jog_Fwd", "5 m/s (Gehtempo des Spielers): %s" % _anim())
	await _drive(Vector3(0, 0, -8.0))
	_check(_anim() == "ual/Sprint", "8 m/s (Sprint): %s" % _anim())
	await _drive(Vector3(5.0, 0, 0))
	_check(absf(wrapf(_figure.rotation.y + PI * 0.5, -PI, PI)) < 0.2, "Läuft nach rechts: Figur dreht sich dorthin (%.0f°)" % rad_to_deg(_figure.rotation.y))
	_body.set("crouch", 1.0)
	await _drive(Vector3(0, 0, -2.0))
	_check(_anim() == "ual/Crouch_Fwd", "Geduckt: %s" % _anim())
	_body.set("crouch", 0.0)
	await _drive(Vector3(0, 3, 0), false, 0.5)
	_check(_anim() == "ual/Jump", "In der Luft: %s" % _anim())
	await _drive(Vector3.ZERO, true, 0.1)
	_check(_anim() == "ual/Jump_Land", "Landung: %s" % _anim())


func _test_weapon() -> void:
	print("Waffe")
	_body.call("set_held_item", load(PISTOL))
	await _frames(2)
	var view := _figure.get("_held") as Node3D
	_check(view != null and view.get_parent() != null, "Pistole in der rechten Hand")
	_body.set("aim", 1.0)
	_body.set("look_pitch", 0.3)
	await _drive(Vector3(-3.0, 0, 0))
	var overlay := _figure.get("_overlay") as AnimOverlay
	_check(overlay.aim_weight > 0.9 and absf(overlay.aim_pitch - 0.3) < 0.01, "Zielt (Ebene %.2f, Blick %.2f)" % [overlay.aim_weight, overlay.aim_pitch])
	_check(absf(_figure.rotation.y) < 0.1 and _anim().ends_with("Run_Left"), "Zielend seitlich: Blick bleibt vorn, %s" % _anim())
	await _drive(Vector3(0, 0, 3.0))
	_check(_anim().ends_with("Run_Back"), "Zielend rückwärts: %s" % _anim())
	_body.call("trigger_fire")
	_check(str(overlay.get("_action")) == AnimOverlay.SHOOT, "Schuss: Pistol_Shoot")
	await _drive(Vector3.ZERO, true, 0.4)
	_body.set("reload", 0.0)
	await _drive(Vector3.ZERO, true, 0.1)
	_check(str(overlay.get("_action")) == AnimOverlay.RELOAD, "Nachladen: Pistol_Reload")
	_body.set("reload", -1.0)
	_body.set("aim", 0.0)


func _test_death() -> void:
	print("Tod")
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.global_position = ARENA + Vector3(0, 2, 5)
	cam.current = true
	await _frames(2)
	_body.set("dead", true)
	await _drive(Vector3.ZERO, true, 0.3)
	var rag: Ragdoll = _figure.get("ragdoll")
	_check(bool(_figure.call("is_fallen")) and ((rag != null and rag.running) or _anim() == "ual/Death01"), "Tot: Ragdoll bzw. Death01")
	_body.set("dead", false)
	await _drive(Vector3.ZERO, true, 0.3)
	_check(not bool(_figure.call("is_fallen")) and _anim() == "ual/Idle" and (rag == null or not rag.running), "Wiederbelebt: steht wieder (%s)" % _anim())


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
