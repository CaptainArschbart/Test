extends SceneTree
## Prüft neutrale Gegner, die Pfeil-Markierung, XP für Kills und die XP-Leiste oben mittig.
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_enemy_xp.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne typisierte Verweise auf Spielklassen (-s-Skripte werden vor den Autoloads kompiliert).

const TESTMAP := "res://scenes/testmap/testmap.tscn"
const ENEMY_SCENE := "res://scenes/enemies/enemy.tscn"
const NOISE := "res://scenes/stealth/stealth_noise.gd"

var _checks := 0
var _fails := 0
var _player: Node3D
var _xp: Node


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


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	change_scene_to_file(TESTMAP)
	await _frames(20)
	_player = get_first_node_in_group("player")
	_check(_player != null, "Testmap mit Spielerfigur geladen")
	if _player == null:
		_finish()
		return
	_xp = _player.get("xp")
	_check(_xp != null, "Player hat PlayerXp")
	_check_curve()
	_check_hud()
	await _check_enemies()
	_finish()


func _check_curve() -> void:
	_check(int(_xp.get("level")) == 1 and int(_xp.get("xp")) == 0, "Start: Stufe 1, 0 XP")
	_check(int(_xp.call("needed")) == 100, "Stufe 1 → 2 braucht 100 XP")
	_xp.call("add_xp", 130)
	_check(int(_xp.get("level")) == 2 and int(_xp.get("xp")) == 30,
		"130 XP → Stufe 2 mit 30 XP (%d, %d)" % [_xp.get("level"), _xp.get("xp")])
	_xp.call("add_xp", 400)
	# Stufe 2 braucht 160, Stufe 3 braucht 220: 30 + 400 = 430 → Stufe 4 mit 50.
	_check(int(_xp.get("level")) == 4 and int(_xp.get("xp")) == 50,
		"+400 XP → Stufe 4 mit 50 XP (%d, %d)" % [_xp.get("level"), _xp.get("xp")])
	_check(int(_xp.get("total_xp")) == 530, "total_xp zählt alles (530)")
	_xp.call("add_xp", -5)
	_check(int(_xp.get("total_xp")) == 530, "negative XP werden ignoriert")


func _check_hud() -> void:
	var hud := _player.get_node_or_null(^"XpHud")
	_check(hud != null, "XpHud am Player")
	if hud == null:
		return
	var panel: Control = hud.get("panel")
	var view := panel.get_viewport_rect().size
	var center := panel.get_global_rect().get_center().x
	_check(absf(center - view.x * 0.5) < 2.0 and panel.get_global_rect().position.y < 30.0,
		"XP-Leiste steht oben mittig (Mitte %.0f von %.0f, y %.0f)" % [center, view.x, panel.get_global_rect().position.y])
	var amount: Label = hud.get("amount_label")
	_check(amount.text == "50 / 280 XP", "Anzeige \"50 / 280 XP\" (%s)" % amount.text)
	var label: Label = hud.get("level_label")
	await _frames(1)
	_check(label.size.y <= 26.0, "Stufen-Label hat die gesetzte Höhe (%.0f)" % label.size.y)


func _spawn_enemy(offset: Vector3) -> Node3D:
	var enemy: Node3D = load(ENEMY_SCENE).instantiate()
	current_scene.add_child(enemy)
	enemy.global_position = _player.global_position + offset
	# Zum Spieler schauen, damit er ihn sicher sehen würde.
	enemy.look_at(_player.global_position, Vector3.UP)
	enemy.rotation.x = 0.0
	enemy.rotation.z = 0.0
	return enemy


func _check_enemies() -> void:
	var a := _spawn_enemy(Vector3(0.0, 0.0, -4.0))
	var b := _spawn_enemy(Vector3(2.5, 0.0, -5.0))
	await _physics(5)
	var arrow: MeshInstance3D = a.get_node_or_null(^"Arrow")
	_check(not bool(a.get("hostile")) and not bool(b.get("hostile")), "Gegner starten neutral")
	_check(arrow != null and arrow.visible, "Pfeil über dem Kopf sichtbar")
	if arrow != null:
		_check(arrow.position.y > 1.9, "Pfeil steht über dem Kopf (y %.2f)" % arrow.position.y)
		var mat: StandardMaterial3D = arrow.material_override
		_check(mat.albedo_color.is_equal_approx(a.get("NEUTRAL_COLOR")), "Pfeil gelb (neutral)")
	await _physics(90)
	_check(float(a.get("awareness")) == 0.0 and int(a.get("state")) == 0,
		"neutraler Gegner sieht den Spieler und bleibt ruhig (awareness %.2f, Zustand %d)" % [a.get("awareness"), a.get("state")])
	load(NOISE).call("emit", self, _player.global_position, 25.0, _player, &"shot")
	await _physics(5)
	_check(not bool(a.get("hostile")) and float(a.get("awareness")) == 0.0, "Schuss des Spielers macht ihn nicht feindlich")

	a.call("take_hit", 5.0, a.global_position + Vector3.UP * 1.0, Vector3.FORWARD)
	await _physics(10)
	_check(bool(a.get("hostile")), "Treffer macht ihn feindlich")
	_check(int(a.get("state")) == 3, "getroffener Gegner kämpft (Zustand %d)" % a.get("state"))
	if arrow != null:
		var mat: StandardMaterial3D = arrow.material_override
		_check(mat.albedo_color.is_equal_approx(a.get("HOSTILE_COLOR")), "Pfeil rot (feindlich)")
	_check(bool(b.get("hostile")), "Kollege in der Nähe hört den Alarmruf und wird feindlich")

	var before := int(_xp.get("total_xp"))
	var reward := int(a.get("profile").get("xp_reward"))
	_check(reward > 0, "Profil gibt XP (%d)" % reward)
	a.call("take_hit", 999.0, a.global_position + Vector3.UP * 1.0, Vector3.FORWARD)
	await _physics(2)
	_check(bool(a.call("is_dead")), "Gegner tot")
	_check(int(_xp.get("total_xp")) == before + reward, "Kill gibt %d XP (%d → %d)" % [reward, before, _xp.get("total_xp")])
	_check(arrow != null and not arrow.visible, "Pfeil am toten Gegner aus")
	a.call("take_hit", 999.0, a.global_position + Vector3.UP * 1.0, Vector3.FORWARD)
	_check(int(_xp.get("total_xp")) == before + reward, "toter Gegner gibt nicht nochmal XP")

	b.call("reset_alert")
	_check(not bool(b.get("hostile")), "nach Respawn des Spielers wieder neutral")
	b.set("start_hostile", true)
	b.call("reset_alert")
	_check(bool(b.get("hostile")), "start_hostile: bleibt feindlich")


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
