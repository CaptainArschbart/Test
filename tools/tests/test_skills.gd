extends SceneTree
## Skill-System (PlayerSkills): Punkte aus Stufenaufstiegen, Voraussetzungen, Wirkung an Waffe,
## Nahkampf, Granate, Gesundheit, Schaden, Schleichen, Taschendiebstahl, Schloss, Laden und Heilung,
## Speichern/Laden des Profils und der Reiter „Skills“ im Inventar.
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_skills.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne typisierte Verweise auf Spielklassen (ein -s-Skript wird vor den Autoloads kompiliert).

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const CIVILIAN := "res://scenes/civilians/civilian.gd"
const LOCKED_DOOR := "res://scenes/crime/locked_door.gd"
const SHOP := "res://scenes/interact/shop_interior.gd"
const GRENADE := "res://scenes/items/grenade.gd"
const PISTOL := "res://scenes/items/data/pistol.tres"
const MEDKIT := "res://scenes/items/data/medkit.tres"
const FRAG := "res://scenes/items/data/contact_grenade.tres"
const JEWELRY := "res://scenes/items/data/jewelry.tres"
const PROFILE := "user://test_skills_profile.cfg"

var _checks := 0
var _fails := 0
var _root: Node3D
var _player: CharacterBody3D
var _skills: Node
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
		await physics_frame


func _box(size: Vector3, center: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	_root.add_child(body)
	body.global_position = center


func _run() -> void:
	_root = Node3D.new()
	_root.name = "SkillArena"
	root.add_child(_root)
	current_scene = _root
	_box(Vector3(200.0, 1.0, 200.0), Vector3(0.0, -0.5, 0.0))
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_player.name = "TestPlayer"
	_root.add_child(_player)
	await _frames(10)
	_player.get("movement").set("crouch_hold", true)
	_skills = _player.get("skills")
	_xp = _player.get("xp")
	_check(_skills != null and _xp != null, "Player hat PlayerSkills und PlayerXp")
	if _skills == null or _xp == null:
		_finish()
		return
	_check(not bool(_skills.get("autosave")), "headless: kein automatisches Speichern ins echte Profil")
	_points_and_requirements()
	await _combat_effects()
	await _survival_effects()
	await _rogue_effects()
	_shop_prices()
	_save_and_load()
	await _skill_tab()
	_finish()


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(_fails)


func _level_to(target: int) -> void:
	var total := 0
	for lvl in range(int(_xp.get("level")), target):
		total += _xp.call("needed_for", lvl)
	total -= int(_xp.get("xp"))
	_xp.call("add_xp", total)


func _points_and_requirements() -> void:
	_check(int(_skills.call("points_free")) == 0, "Stufe 1: keine Punkte")
	_check(not bool(_skills.call("learn", &"steady_hand")), "ohne Punkt nichts lernbar")
	_check(_skills.call("state_of", &"steady_hand") == "unlocked", "Stufe-1-Skill freigeschaltet, aber kein Punkt")
	_level_to(4)
	_check(int(_xp.get("level")) == 4 and int(_skills.get("level")) == 4, "Stufenaufstieg kommt bei den Skills an (Stufe %d)" % int(_skills.get("level")))
	_check(int(_skills.call("points_free")) == 3, "Stufe 4: 3 Punkte (%d)" % int(_skills.call("points_free")))
	_check(_skills.call("state_of", &"fast_reload") == "locked", "Schnellladen gesperrt ohne Ruhige Hand")
	_check(not bool(_skills.call("learn", &"fast_reload")), "Voraussetzung fehlt: nicht lernbar")
	_check(_skills.call("state_of", &"steady_hand") == "available", "Ruhige Hand freischaltbar")


func _combat_effects() -> void:
	var inventory: Node = _player.get("inventory")
	inventory.call("add_item", load(PISTOL), 1)
	inventory.call("select", 0)
	await _frames(4)
	var holder: Node = _player.get("weapon_holder")
	_check(holder.call("get_weapon") != null, "Pistole in der Hand")
	var spread_before := float(holder.call("get_spread_degrees"))
	_check(bool(_skills.call("learn", &"steady_hand")), "Ruhige Hand gelernt")
	var spread_after := float(holder.call("get_spread_degrees"))
	_check(spread_before > 0.0 and is_equal_approx(spread_after, spread_before * 0.7),
		"Streuung −30 %% (%.2f° → %.2f°)" % [spread_before, spread_after])
	_check(_skills.call("state_of", &"fast_reload") == "available", "Schnellladen jetzt freischaltbar")
	_check(bool(_skills.call("learn", &"fast_reload")), "Schnellladen gelernt")
	holder.call("try_fire")
	holder.call("start_reload")
	var weapon: Resource = holder.call("get_weapon")
	var reload_left := float(holder.get("_reload_left"))
	_check(is_equal_approx(reload_left, float(weapon.get("reload_time")) * 0.65),
		"Nachladen 35 %% kürzer (%.2f s statt %.2f s)" % [reload_left, float(weapon.get("reload_time"))])
	# Nahkampf an einem Ziel, das den Schaden mitschreibt.
	var target := _damage_recorder()
	var melee: Node = _player.get("melee")
	melee.call("_apply_hit", target, 20.0, Vector3.ZERO, Vector3.UP, Vector3.ZERO, 0.0)
	var plain := float(target.get("last"))
	_check(bool(_skills.call("learn", &"heavy_fists")), "Schwere Fäuste gelernt")
	melee.call("_apply_hit", target, 20.0, Vector3.ZERO, Vector3.UP, Vector3.ZERO, 0.0)
	_check(is_equal_approx(plain, 20.0) and is_equal_approx(float(target.get("last")), 25.0),
		"Faustschaden +25 %% (%.1f → %.1f)" % [plain, float(target.get("last"))])
	target.queue_free()
	_check(int(_skills.call("points_free")) == 0, "alle 3 Punkte verteilt")
	_check(not bool(_skills.call("learn", &"demolition")), "ohne freien Punkt kein weiterer Skill")
	_level_to(16)
	_check(int(_skills.call("points_free")) == 12, "Stufe 16: 12 weitere Punkte (%d)" % int(_skills.call("points_free")))
	var grenade: Node = (load(GRENADE) as GDScript).new()
	grenade.set("data", load(FRAG))
	grenade.set("thrower", _player)
	var frag_plain := float(grenade.call("damage_at", 0.0))
	_check(bool(_skills.call("learn", &"demolition")), "Sprengmeister gelernt")
	var frag_skill := float(grenade.call("damage_at", 0.0))
	_check(is_equal_approx(frag_skill, frag_plain * 1.3), "Granatenschaden +30 %% (%.0f → %.0f)" % [frag_plain, frag_skill])
	_check(is_equal_approx(float(_player.call("skill_mult", &"throw_mult")), 1.25), "Wurfweite +25 %")
	grenade.free()
	var stats: Node = _player.get("stats")
	_player.call("apply_damage", 10.0, &"guard")
	var hp_plain := 100.0 - float(stats.get("hp"))
	stats.call("heal", 100.0)
	_check(bool(_skills.call("learn", &"armored_skin")), "Panzerhaut gelernt (beide Voraussetzungen da)")
	_player.call("apply_damage", 10.0, &"guard")
	var hp_skill := float(stats.get("max_hp")) - float(stats.get("hp"))
	_check(is_equal_approx(hp_plain, 10.0) and is_equal_approx(hp_skill, 8.0), "Panzerhaut: 20 %% weniger Schaden (%.1f → %.1f)" % [hp_plain, hp_skill])
	stats.call("heal", 100.0)


func _survival_effects() -> void:
	var stats: Node = _player.get("stats")
	_check(bool(_skills.call("learn", &"tough")), "Zäh gelernt")
	_check(is_equal_approx(float(stats.get("max_hp")), 125.0) and is_equal_approx(float(stats.get("hp")), 125.0),
		"Zäh: 125 max HP, gleich aufgefüllt (%.0f / %.0f)" % [float(stats.get("hp")), float(stats.get("max_hp"))])
	_check(bool(_skills.call("learn", &"endurance")), "Ausdauernd gelernt")
	_check(is_equal_approx(float(stats.get("max_stamina")), 130.0), "Ausdauernd: 130 max Ausdauer")
	_check(is_equal_approx(float(stats.get("stamina_regen_per_second")), 15.0 * 1.25), "Ausdauer lädt 25 % schneller")
	# Heilung durch Items: Medkit ohne und mit Sanitäter.
	var item_user: Node = _player.get("item_user")
	var inventory: Node = _player.get("inventory")
	var medkit: Resource = load(MEDKIT)
	stats.call("damage", 100.0, &"test")
	inventory.call("add_item", medkit, 2)
	var hp0 := float(stats.get("hp"))
	item_user.call("apply_consumable", medkit, _slot_of(medkit))
	var healed_plain := float(stats.get("hp")) - hp0
	_check(bool(_skills.call("learn", &"medic")), "Sanitäter gelernt")
	stats.call("damage", 120.0, &"test")
	var hp1 := float(stats.get("hp"))
	item_user.call("apply_consumable", medkit, _slot_of(medkit))
	var healed_skill := float(stats.get("hp")) - hp1
	_check(healed_plain > 0.0 and is_equal_approx(healed_skill, minf(healed_plain * 1.5, 125.0 - hp1)),
		"Medkit heilt 50 %% mehr (%.0f → %.0f)" % [healed_plain, healed_skill])
	stats.call("heal", 200.0)
	await _frames(2)


func _rogue_effects() -> void:
	var stealth: Node = _player.get("stealth")
	var vis_plain := float(stealth.call("_compute_visibility"))
	_check(bool(_skills.call("learn", &"soft_soles")), "Leise Sohlen gelernt")
	_check(bool(_skills.call("learn", &"shadow")), "Schatten gelernt")
	var vis_skill := float(stealth.call("_compute_visibility"))
	_check(is_equal_approx(vis_skill, clampf(vis_plain * 0.75, 0.0, 1.0)), "Schatten: Sichtbarkeit −25 %% (%.3f → %.3f)" % [vis_plain, vis_skill])
	# Lärm: Schritt mit Leise Sohlen, Schuss unverändert.
	stealth.set("noise_level", 0.0)
	stealth.call("make_noise", 10.0, &"step")
	var step_noise := float(stealth.get("noise_level"))
	stealth.set("noise_level", 0.0)
	stealth.call("make_noise", 10.0, &"shot")
	var shot_noise := float(stealth.get("noise_level"))
	_check(is_equal_approx(step_noise, 0.3) and is_equal_approx(shot_noise, 0.5), "Schritte 40 %% leiser, Schüsse nicht (%.2f / %.2f)" % [step_noise, shot_noise])
	# Schloss knacken.
	var door: Node = (load(LOCKED_DOOR) as GDScript).new()
	_root.add_child(door)
	door.global_position = Vector3(-30, 0, -30)
	door.call("interact", _player)
	_check(bool(door.get("locked")), "ohne Dietrich und Schlüssel bleibt die Tür zu")
	_check(bool(_skills.call("learn", &"quick_fingers")), "Flinke Finger gelernt")
	_check(bool(_skills.call("learn", &"lockpick")), "Dietrich gelernt")
	_check(str(door.call("get_interact_text", _player)) == "Schloss knacken", "Tür zeigt „Schloss knacken“")
	door.call("interact", _player)
	_check(not bool(door.get("locked")) and not bool(door.get("forced_open")), "Dietrich: Tür leise offen")
	door.queue_free()
	# Taschendiebstahl mit Flinke Finger und Großer Fang. Seed 0: 2 ¢ und Schmuck.
	_check(bool(_skills.call("learn", &"big_score")), "Großer Fang gelernt")
	var civ := (load(CIVILIAN) as GDScript).new() as CharacterBody3D
	civ.set("stay_put", true)
	civ.set("net_seed", 0)
	_root.add_child(civ)
	civ.global_position = Vector3(40, 0, 0)
	civ.rotation.y = 0.0
	await _frames(4)
	_player.global_position = Vector3(40, 0, 1.2)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	Input.action_press("crouch")
	await _frames(12)
	var crime: Node = civ.get_node("CivilianCrime")
	var inventory: Node = _player.get("inventory")
	var money := int(inventory.get("money"))
	civ.call("interact", _player)
	await _frames(20)
	var progress := float(crime.get("pick_progress"))
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var plain_progress := 20.0 * dt / 1.2
	_check(progress > plain_progress * 1.3, "Griff 35 %% schneller (%.2f statt %.2f nach 20 Frames)" % [progress, plain_progress])
	await _frames(60)
	_check(float(crime.get("pick_progress")) < 0.0, "Griff fertig")
	_check(int(inventory.get("money")) == money + 3, "Großer Fang: 3 ¢ statt 2 ¢ (%d → %d)" % [money, int(inventory.get("money"))])
	Input.action_release("crouch")
	civ.queue_free()
	await _frames(4)


func _shop_prices() -> void:
	var shop: Node = (load(SHOP) as GDScript).new()
	shop.set("shop_sign", "sign_shop")
	var medkit: Resource = load(MEDKIT)
	var jewelry: Resource = load(JEWELRY)
	var price := int(shop.call("price_of", medkit))
	var fence := int(shop.call("fence_price", jewelry))
	_check(int(shop.call("price_of", medkit, _player)) == price, "ohne Feilscher: gleicher Preis mit Spieler")
	_check(bool(_skills.call("learn", &"haggler")), "Feilscher gelernt")
	var price_skill := int(shop.call("price_of", medkit, _player))
	var fence_skill := int(shop.call("fence_price", jewelry, _player))
	_check(price_skill == maxi(roundi(price * 0.85), 1) or absi(price_skill - roundi(float(price) * 0.85)) <= 1,
		"Feilscher: Laden 15 %% billiger (%d → %d ¢)" % [price, price_skill])
	_check(fence > 0 and fence_skill > fence, "Feilscher: Hehler zahlt mehr (%d → %d ¢)" % [fence, fence_skill])
	_check(bool(_skills.call("learn", &"camera_hack")), "Kamera-Hack gelernt")
	_check(not bool(shop.call("camera_sees", _player)), "Kamera-Hack: Kamera sieht den Spieler nicht")
	_check(int(_skills.call("points_spent")) == 15 and int(_skills.call("points_free")) == 0, "alle 15 Skills gelernt, alle Punkte verteilt")
	shop.free()


func _save_and_load() -> void:
	var learned_before: Dictionary = (_skills.get("learned") as Dictionary).duplicate()
	var level_before := int(_xp.get("level"))
	_xp.call("add_xp", 37)
	var xp_before := int(_xp.get("xp"))
	_check(int(_skills.call("save_profile", PROFILE)) == OK, "Profil gespeichert")
	_skills.call("reset")
	_xp.set("level", 1)
	_xp.set("xp", 0)
	_skills.call("set_level", 1)
	_check(int(_skills.call("points_spent")) == 0 and is_equal_approx(float(_player.get("stats").get("max_hp")), 100.0),
		"Zurückgesetzt: keine Skills, 100 max HP")
	_check(bool(_skills.call("load_profile", PROFILE)), "Profil geladen")
	_check(int(_xp.get("level")) == level_before and int(_xp.get("xp")) == xp_before,
		"Stufe und XP wieder da (%d, %d XP)" % [int(_xp.get("level")), int(_xp.get("xp"))])
	_check((_skills.get("learned") as Dictionary).size() == learned_before.size(), "alle %d Skills wieder da" % learned_before.size())
	_check(is_equal_approx(float(_player.get("stats").get("max_hp")), 125.0), "Wirkung nach dem Laden (125 max HP)")
	# Kaputtes Profil: Skill ohne Voraussetzung und mehr Skills als Punkte.
	var config := ConfigFile.new()
	config.set_value("xp", "level", 3)
	config.set_value("skills", "learned", PackedStringArray(["armored_skin", "tough", "endurance", "medic", "steady_hand"]))
	config.save(PROFILE)
	_skills.call("load_profile", PROFILE)
	var learned: Dictionary = _skills.get("learned")
	_check(not learned.has(&"armored_skin"), "Skill ohne Voraussetzung verworfen")
	_check(learned.size() == 2, "nur so viele Skills wie Punkte (Stufe 3: %d)" % learned.size())
	_check(int(_skills.call("points_free")) == 0, "danach 0 freie Punkte")


func _skill_tab() -> void:
	var ui: Node = _player.get_node("InventoryUI")
	_skills.call("reset")
	_skills.call("set_level", 3)
	ui.call("_set_open", true)
	ui.call("set_tab", 1)
	await process_frame
	var view: Control = ui.get("skill_view")
	_check(view != null and view.visible, "Reiter Skills zeigt den Skill-Baum")
	_check(not (ui.get("backpack_grid") as Control).visible, "Rucksack im Skills-Reiter versteckt")
	var tabs: Array = ui.get("_tab_buttons")
	_check(str((tabs[1] as Button).text).contains("2"), "Reiter zeigt freie Punkte (%s)" % (tabs[1] as Button).text)
	_check(view.call("rect_of", &"fast_reload").position.y > view.call("rect_of", &"steady_hand").position.y,
		"Stufe 2 liegt unter Stufe 1")
	var at: Vector2 = (view.call("rect_of", &"tough") as Rect2).get_center()
	_check(view.call("skill_at", at) == &"tough", "Klickfläche trifft den Knoten")
	_check(bool(view.call("press", &"tough")), "Klick auf Zäh lernt den Skill")
	_check(not bool(view.call("press", &"camera_hack")), "Klick auf gesperrten Skill lernt nichts")
	ui.call("_on_skill_hovered", &"medic")
	_check(str(ui.get("info_description").text).contains("Zäh"), "Info zeigt Wirkung und Voraussetzung")
	ui.call("set_tab", 0)
	_check(not view.visible and (ui.get("backpack_grid") as Control).visible, "zurück zum Inventar")
	ui.call("_set_open", false)


func _slot_of(item: Resource) -> int:
	var inventory: Node = _player.get("inventory")
	for i in int(inventory.call("get_size")):
		var other: Resource = inventory.call("get_item", i)
		if other != null and other.call("is_same", item):
			return i
	return -1


## Ziel mit melee_hit, das den letzten Schaden merkt.
func _damage_recorder() -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar last := 0.0\nfunc melee_hit(damage: float, _p: Vector3, _n: Vector3, _push: Vector3, _s: float) -> void:\n\tlast = damage\n"
	script.reload()
	var node: Node = script.new()
	_root.add_child(node)
	return node
