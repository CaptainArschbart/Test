extends SceneTree
## Prüft die Läden in Sektor 7 (Einzelspieler): Eingang ohne Kante, großes Tor, neue Items mit Modellen,
## zufällige Ware mit leeren Plätzen, Einkaufen mit Warenkorb und Bezahlen, Klauen (unbemerkt, durch
## Diebstahlsicherung, Verkäufer, Kamera), Vitrine, Kasse aufbrechen, Überfall, bewaffneter Verkäufer,
## Hehler und Verkäufer erschießen.
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_shop.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.
## Ohne typisierte Verweise auf Spielklassen (siehe test_money.gd).

const SLUM := "res://scenes/slum/slum.tscn"
const NEW_ITEMS := ["water_bottle", "coffee", "soy_bar", "onigiri", "beer", "painkillers", "medkit",
	"smartphone", "neuro_chip", "gold_watch", "cigarettes", "data_shard"]

var _checks := 0
var _fails := 0
var _player: Node3D
var _inventory: Node
var _space: PhysicsDirectSpaceState3D
var _shops: Array = []


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


## Die Wartezeiten hier gelten für 60 Hz. Die Option „Physik 30 Hz“ aus user://settings.cfg
## wirkt auch headless, darum für den Test fest auf 60 Hz stellen (ohne zu speichern).
## Bei 30 Hz mit Interpolation hängt die Kamera nach dem Versetzen der Figur hinterher.
func _pin_physics_60() -> void:
	root.get_node("Settings").set("physics_rate", 60)
	Engine.physics_ticks_per_second = 60
	physics_interpolation = false


func _run() -> void:
	_pin_physics_60()
	_check_items()
	change_scene_to_file(SLUM)
	await _frames(30)
	for i in 4:
		await physics_frame
	_player = get_first_node_in_group("player") as Node3D
	_check(_player != null, "Sektor 7 mit Spielerfigur geladen")
	if _player == null:
		_finish()
		return
	_inventory = _player.get("inventory")
	_space = (current_scene as Node3D).get_world_3d().direct_space_state
	_shops = get_nodes_in_group("shop_interior")
	_shops.sort_custom(func(a: Node, b: Node) -> bool: return str(a.get_path()) < str(b.get_path()))
	_check(_shops.size() >= 40, "%d Läden mit Logik" % _shops.size())
	_check_geometry()
	_check_stock()
	if _shops.size() < 12:
		_finish()
		return
	await _check_shopping(_shops[0])
	await _check_theft_unseen(_shops[1])
	await _check_theft_sensor(_shops[2])
	await _check_theft_keeper(_shops[3])
	await _check_theft_camera()
	await _check_cabinet(_shops[5])
	await _check_rob(_shops[6])
	await _check_threat(_shops[7])
	await _check_armed(_shops[8])
	await _check_fence()
	await _check_kill(_shops[9])
	_finish()


# --- Items -------------------------------------------------------------------------------

func _check_items() -> void:
	var model_script: GDScript = load("res://scenes/items/consumable_model.gd")
	var missing: Array[String] = []
	for id: String in NEW_ITEMS:
		var item: Resource = load("res://scenes/items/data/%s.tres" % id)
		if item == null or StringName(item.get("model")) == &"" or not bool(model_script.call("has_model", item.get("model"))) \
				or int(item.get("value")) <= 0:
			missing.append(id)
			continue
		var model: Node3D = model_script.call("build", item.get("model"), item.get("color"), false)
		var meshes := model.find_children("*", "MeshInstance3D", true, false).size()
		if meshes < 3:
			missing.append("%s (%d Teile)" % [id, meshes])
		model.free()
	_check(missing.is_empty(), "%d neue/erweiterte Items mit Modell, Wert und ≥3 Teilen %s" % [NEW_ITEMS.size(), missing])
	# Pickup zeigt das Modell statt des Würfels, auch bei Wertsachen.
	var pickup: Node = load("res://scenes/items/pickup.tscn").instantiate()
	pickup.set("item", load("res://scenes/items/data/gold_watch.tres"))
	root.add_child(pickup)
	_check(pickup.find_child("ConsumableModel", true, false) != null, "Gold-Uhr als Pickup mit Modell")
	pickup.free()


# --- Laden-Geometrie und Bestand -----------------------------------------------------------

func _ground(p: Vector3) -> float:
	var hit := _space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 2.0, 1))
	return hit.position.y if not hit.is_empty() else -9.0


func _check_geometry() -> void:
	var worst := 0.0
	var worst_name := ""
	var lowest := 99.0
	for node: Node in current_scene.find_children("Shop*", "Node3D", true, false):
		if node.get("footprint") == null:
			continue
		var xf := (node as Node3D).global_transform
		var fp: Vector2 = node.get("footprint")
		for x: float in [-0.2, 0.6]:
			var inside := _ground(xf * Vector3(x, 0, fp.y * 0.5 - 1.2))
			var door := _ground(xf * Vector3(x, 0, fp.y * 0.5 + 0.15))
			var outside := _ground(xf * Vector3(x, 0, fp.y * 0.5 + 0.6))
			var step := maxf(absf(inside - door), absf(door - outside))
			if step > worst:
				worst = step
				worst_name = "%s (%.2f/%.2f/%.2f)" % [node.name, inside, door, outside]
		var floor_y := _ground(xf * Vector3(0, 0, fp.y * 0.5 - 0.1))
		var from := xf * Vector3(0, floor_y + 0.2, fp.y * 0.5 - 0.1)
		var up := _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 5.0, 1))
		if not up.is_empty():
			lowest = minf(lowest, up.position.y - floor_y)
	_check(worst <= 0.03, "Keine Kante am Eingang (größte Stufe %.3f m %s)" % [worst, worst_name])
	_check(lowest >= 2.4, "Tor überall mindestens 2,4 m hoch (%.2f m)" % lowest)


func _check_stock() -> void:
	var slots := 0
	var empty := 0
	var kinds := {}
	var item_ids := {}
	var layouts := {}
	var fewest := 999
	var no_model := 0
	for shop: Node in _shops:
		var count := int((shop.get("slots") as Array).size())
		slots += count
		fewest = mini(fewest, count)
		empty += int(shop.call("empty_slots"))
		for i in count:
			kinds[shop.call("slot_kind", i)] = true
			var item: Resource = shop.call("item_at", i)
			if item != null:
				item_ids[item.get("id")] = true
				if StringName(item.get("model")) == &"":
					no_model += 1
		layouts[str(shop.get("slot_item"))] = true
	var ratio := float(empty) / maxf(slots, 1)
	_check(fewest >= 15, "Jeder Laden hat mindestens 15 Warenplätze (wenigste: %d, gesamt %d)" % [fewest, slots])
	_check(kinds.has("shelf") and kinds.has("fridge") and kinds.has("cabinet") and kinds.has("wall"),
		"Platzarten: %s" % str(kinds.keys()))
	_check(ratio > 0.15 and ratio < 0.5, "Leere Plätze: %d%% (Zufall, Soll ~30%%)" % roundi(ratio * 100.0))
	_check(item_ids.size() >= 12, "%d verschiedene Items in den Läden" % item_ids.size())
	_check(no_model == 0, "Jede Ware im Regal hat ein Modell")
	_check(layouts.size() >= _shops.size() - 2, "Bestückung je Laden verschieden (%d Varianten)" % layouts.size())


# --- Hilfen ------------------------------------------------------------------------------

func _setup(shop: Node, sensor: bool, camera: bool, busy: bool) -> void:
	shop.set("has_sensor", sensor)
	shop.set("camera_alive", camera and shop.get("_camera") != null)
	shop.set("busy", busy)
	shop.set("_busy_left", 999.0)
	shop.set("_keeper_turn", 1.0 if busy else 0.0)
	shop.set("keeper_state", 0)
	shop.set("_alarm_left", 0.0)
	shop.set("_silent_alarm_left", -1.0)
	var keeper: Node3D = shop.get("_keeper")
	keeper.rotation.y = PI * 0.5 if busy else -PI * 0.5
	# Ladenbestand fürs Testen auffüllen.
	shop.call("_restock", true)


## Ein Platz mit Ware der Art `kind`, möglichst nah an der Tür (für "sieht mich" am Ausgang).
func _slot_of_kind(shop: Node, kind: String) -> int:
	var best := -1
	var best_z := -INF
	for i in (shop.get("slots") as Array).size():
		if shop.call("slot_kind", i) != kind or shop.call("item_at", i) == null:
			continue
		var z: float = (shop.get("slots")[i]["xf"] as Transform3D).origin.z
		if z > best_z:
			best_z = z
			best = i
	return best


## Stellt den Spieler vor einen Platz (0,8 m davor, Blick hin) im Raum des Ladens.
func _go_to_slot(shop: Node, slot: int) -> void:
	var xf: Transform3D = (shop as Node3D).global_transform * (shop.get("slots")[slot]["xf"] as Transform3D)
	var front := xf.basis.z.normalized()
	front.y = 0.0
	var spot := xf.origin + front.normalized() * 0.8
	_player.global_position = Vector3(spot.x, _floor_at(shop), spot.z)
	_player.rotation.y = atan2(front.x, front.z)
	await _frames(3)
	# Ware wird erst in der Nähe gebaut (Prüfung alle 0,4 s).
	await create_timer(0.5).timeout


func _floor_at(shop: Node) -> float:
	return (shop as Node3D).global_position.y + float(shop.get("floor_y")) + 0.02


func _local_spot(shop: Node, local: Vector3) -> Vector3:
	return (shop as Node3D).to_global(Vector3(local.x, float(shop.get("floor_y")) + 0.05, local.z))


func _go_outside(shop: Node) -> void:
	var b: AABB = shop.get("bounds")
	_player.global_position = _local_spot(shop, Vector3(b.get_center().x * 0.3, 0, b.end.z + 1.5))
	await _frames(3)


func _count(id: String) -> int:
	var total := 0
	for i: int in int(_inventory.call("get_size")):
		var item: Resource = _inventory.call("get_item", i)
		if item != null and item.get("id") == id:
			total += int(_inventory.call("get_count", i))
	return total


func _take(shop: Node, slot: int) -> Resource:
	var item: Resource = shop.call("item_at", slot)
	shop.call("request", _player, &"take", slot)
	return item


func _clear_inventory() -> void:
	for i: int in int(_inventory.call("get_size")):
		_inventory.call("remove_at", i, 999)
	_inventory.call("take_all_money")


# --- Abläufe -----------------------------------------------------------------------------

func _check_shopping(shop: Node) -> void:
	_setup(shop, true, false, false)
	_clear_inventory()
	_inventory.call("add_money", 100)
	var slot := _slot_of_kind(shop, "shelf")
	await _go_to_slot(shop, slot)
	var goods: Node = shop.find_child("Goods%d" % slot, false, false)
	_check(goods != null and goods.find_children("*", "MeshInstance3D", true, false).size() >= 3,
		"Ware steht als Modell im Regal (%s)" % (goods.name if goods else "-"))
	var text: String = goods.call("get_interact_text", _player) if goods else ""
	_check(text.begins_with("Nehmen:"), "Regal: [E] %s" % text)
	var item := _take(shop, slot)
	var price := int(shop.call("price_of", item))
	_check(_count(str(item.get("id"))) == 1 and int(shop.get("my_unpaid")) == price,
		"Genommen: %s, Warenkorb %d ¢" % [item.get("id"), price])
	var keeper: Node = shop.get("_keeper")
	_check(str(keeper.call("get_interact_text", _player)) == "Bezahlen (%d ¢)" % price, "Verkäufer: [E] Bezahlen (%d ¢)" % price)
	keeper.call("interact", _player)
	await _frames(2)
	var ui: Node = _player.get_node_or_null(^"ShopUI")
	_check(ui != null and bool(ui.call("is_open")), "Ladenfenster offen")
	_check(bool(ui.call("pay")) and int(_inventory.get("money")) == 100 - price and int(shop.get("my_unpaid")) == 0,
		"Bezahlt: Bargeld %d, Warenkorb leer" % int(_inventory.get("money")))
	ui.call("close")
	await _go_outside(shop)
	await _frames(3)
	_check(int(shop.get("keeper_state")) == 0 and _count(str(item.get("id"))) == 1,
		"Mit bezahlter Ware raus: kein Alarm, trotz Diebstahlsicherung")


func _check_theft_unseen(shop: Node) -> void:
	_setup(shop, false, false, true)
	_clear_inventory()
	var slot := _slot_of_kind(shop, "shelf")
	await _go_to_slot(shop, slot)
	var item := _take(shop, slot)
	await _go_outside(shop)
	await _frames(3)
	_check(int(shop.get("keeper_state")) == 0 and _count(str(item.get("id"))) == 1 and int(shop.get("my_unpaid")) == 0,
		"Unbemerkt geklaut (keine Sicherung, keine Kamera, Verkäufer räumt ein)")


func _check_theft_sensor(shop: Node) -> void:
	_setup(shop, true, false, true)
	var slot := _slot_of_kind(shop, "shelf")
	await _go_to_slot(shop, slot)
	_take(shop, slot)
	await _go_outside(shop)
	await _frames(3)
	_check(int(shop.get("keeper_state")) == 2, "Diebstahlsicherung piept: Alarm")


func _check_theft_keeper(shop: Node) -> void:
	_setup(shop, false, false, false)
	var slot := _slot_of_kind(shop, "shelf")
	await _go_to_slot(shop, slot)
	_take(shop, slot)
	# Durch die Tür nach draußen, im Blick des Verkäufers.
	var b: AABB = shop.get("bounds")
	_player.global_position = _local_spot(shop, Vector3(0.0, 0, b.end.z - 0.6))
	await _frames(2)
	for i in 3:
		await physics_frame
	var seen := bool(shop.call("sees", _player))
	await _go_outside(shop)
	await _frames(3)
	_check(seen and int(shop.get("keeper_state")) == 2, "Verkäufer sieht den Dieb an der Tür: Alarm (sah ihn: %s)" % seen)


func _check_theft_camera() -> void:
	var shop: Node = null
	for candidate: Node in _shops.slice(10):
		if candidate.get("_camera") != null:
			shop = candidate
			break
	_check(shop != null, "Laden mit Kamera gefunden")
	if shop == null:
		return
	_setup(shop, false, true, true)
	# Einen Platz suchen, den die Kamera sieht.
	var slot := -1
	for i in (shop.get("slots") as Array).size():
		if shop.call("item_at", i) == null or shop.call("slot_kind", i) == "cabinet":
			continue
		await _go_to_slot(shop, i)
		for k in 2:
			await physics_frame
		if bool(shop.call("camera_sees", _player)):
			slot = i
			break
	_check(slot >= 0, "Kamera sieht einen Warenplatz")
	if slot < 0:
		return
	_take(shop, slot)
	await _go_outside(shop)
	await _frames(3)
	_check(int(shop.get("keeper_state")) == 0 and float(shop.get("_silent_alarm_left")) > 0.0,
		"Kamera: erst raus, Alarm kommt verzögert")
	await create_timer(5.5).timeout
	_check(int(shop.get("keeper_state")) == 2, "Kamera-Alarm nach 5 s")
	# Kamera zerschießen, dann klappt es.
	_setup(shop, false, true, true)
	await _go_to_slot(shop, slot)
	var camera: Node = shop.get("_camera")
	camera.call("take_hit", 25.0, Vector3.ZERO, Vector3.UP)
	_check(not bool(shop.get("camera_alive")), "Kamera zerschossen")
	_take(shop, slot)
	await _go_outside(shop)
	await create_timer(5.5).timeout
	_check(int(shop.get("keeper_state")) == 0, "Ohne Kamera: kein Alarm")


func _check_cabinet(shop: Node) -> void:
	_setup(shop, false, false, false)
	var slot := _slot_of_kind(shop, "cabinet")
	if slot < 0:
		# Leere Vitrine: einen Platz mit Zigaretten bestücken.
		for i in (shop.get("slots") as Array).size():
			if shop.call("slot_kind", i) == "cabinet":
				var items: PackedInt32Array = shop.get("slot_item")
				var counts: PackedInt32Array = shop.get("slot_count")
				items[i] = 11
				counts[i] = 1
				shop.set("slot_item", items)
				shop.set("slot_count", counts)
				shop.call("_refresh_slot", i)
				slot = i
				break
	_check(slot >= 0, "Vitrine hat Ware")
	if slot < 0:
		return
	# Hinter die Theke, vor die Vitrine, im Blick des Verkäufers.
	var keeper: Node3D = shop.get("_keeper")
	_player.global_position = keeper.global_position + (shop as Node3D).global_basis.x.normalized() * 1.2
	await _frames(2)
	await create_timer(0.5).timeout
	for i in 2:
		await physics_frame
	var text := str(shop.find_child("Goods%d" % slot, false, false).call("get_interact_text", _player))
	_check(text.begins_with("Aus der Vitrine"), "Vitrine: [E] %s" % text)
	_take(shop, slot)
	await _frames(2)
	_check(int(shop.get("keeper_state")) == 2, "Vitrine vor seinen Augen geplündert: Alarm")


func _check_rob(shop: Node) -> void:
	_setup(shop, false, false, true)
	_inventory.call("take_all_money")
	var register: Node3D = shop.get("_register")
	var cash := int(shop.get("cash"))
	_player.global_position = register.global_position + (shop as Node3D).global_basis.x.normalized() * 0.9
	_player.global_position.y = _floor_at(shop)
	await _frames(2)
	_check(str(register.call("get_interact_text", _player)).begins_with("Kasse aufbrechen"), "Kasse: [E] Kasse aufbrechen")
	register.call("interact", _player)
	await create_timer(1.0).timeout
	_check(int(_inventory.get("money")) == 0, "Nach 1 s noch kein Geld (dauert)")
	await create_timer(2.4).timeout
	_check(int(_inventory.get("money")) == cash and int(shop.get("cash")) == 0, "Kasse geknackt: +%d ¢" % cash)
	# Weggehen bricht ab.
	shop.set("cash", 50)
	register.call("interact", _player)
	await _frames(2)
	_player.global_position += (shop as Node3D).global_basis.x.normalized() * 3.0
	await create_timer(3.5).timeout
	_check(int(shop.get("cash")) == 50, "Weggehen bricht das Aufbrechen ab")


func _check_threat(shop: Node) -> void:
	_setup(shop, false, false, false)
	shop.set("armed", false)
	var cash := int(shop.get("cash"))
	var keeper: Node3D = shop.get("_keeper")
	_player.global_position = keeper.global_position + (shop as Node3D).global_basis.x.normalized() * 2.0
	_player.global_position.y = _floor_at(shop)
	await _frames(2)
	var camera: Camera3D = _player.get("camera")
	var target := keeper.global_position + Vector3.UP * 1.2
	var to := target - camera.global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	(_player.get("head") as Node3D).rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await _frames(2)
	_check(bool(shop.call("aims_at_keeper", _player)), "Spieler zielt auf den Verkäufer")
	shop.call("request", _player, &"threat")
	await _frames(3)
	var found := false
	for node: Node in get_nodes_in_group("item_pickup"):
		var item: Resource = node.get("item")
		if item != null and item.get("id") == "credchip" and int(node.get("count")) == cash:
			found = true
	_check(int(shop.get("keeper_state")) == 1 and found, "Überfall: Hände hoch, %d ¢ auf der Theke" % cash)


func _check_armed(shop: Node) -> void:
	_setup(shop, false, false, false)
	shop.set("armed", true)
	var keeper: Node3D = shop.get("_keeper")
	_player.global_position = keeper.global_position + (shop as Node3D).global_basis.x.normalized() * 2.0
	_player.global_position.y = _floor_at(shop)
	await _frames(2)
	var stats: Node = _player.get("stats")
	stats.call("heal", 100.0)
	var hp := float(stats.get("hp"))
	shop.call("_raise_alarm", _player, "Test")
	await create_timer(5.0).timeout
	var shots := int(shop.get("shots_fired"))
	_check(shots >= 2, "Bewaffneter Verkäufer schießt im Alarm (%d Schüsse, HP %.0f → %.0f)" % [shots, hp, float(stats.get("hp"))])
	stats.call("heal", 100.0)
	shop.set("keeper_state", 0)


func _check_fence() -> void:
	var shop: Node = null
	for candidate: Node in _shops:
		if bool(candidate.call("is_fence")):
			shop = candidate
			break
	_check(shop != null, "Hehler (Ankauf) gefunden")
	if shop == null:
		return
	_setup(shop, false, false, false)
	_clear_inventory()
	_inventory.call("add_item", load("res://scenes/items/data/gold_watch.tres"), 1, false)
	_inventory.call("add_item", load("res://scenes/items/data/noodles.tres"), 1, false)
	var ui: Node = load("res://scenes/interact/shop_ui.gd").call("for_player", _player)
	ui.call("open", shop)
	await _frames(2)
	var watch: Resource = load("res://scenes/items/data/gold_watch.tres")
	var noodles: Resource = load("res://scenes/items/data/noodles.tres")
	_check(bool(ui.call("sell", watch)) and int(_inventory.get("money")) == 35 and _count("gold_watch") == 0,
		"Gold-Uhr beim Hehler verkauft: +35 ¢")
	_check(not bool(ui.call("sell", noodles)), "Nudeln kauft der Hehler nicht")
	ui.call("close")


func _check_kill(shop: Node) -> void:
	_setup(shop, false, false, false)
	var keeper: Node = shop.get("_keeper")
	keeper.call("take_hit", 30.0, Vector3.ZERO, Vector3.FORWARD)
	keeper.call("take_hit", 40.0, Vector3.ZERO, Vector3.FORWARD)
	await _frames(2)
	_check(int(shop.get("keeper_state")) == 3, "Verkäufer erschossen")
	_inventory.call("take_all_money")
	var cash := int(shop.get("cash"))
	var register: Node3D = shop.get("_register")
	_player.global_position = register.global_position + (shop as Node3D).global_basis.x.normalized() * 0.9
	_player.global_position.y = _floor_at(shop)
	register.call("interact", _player)
	await create_timer(1.4).timeout
	_check(cash > 0 and int(_inventory.get("money")) == cash, "Kasse nach seinem Tod schnell offen: +%d ¢" % cash)


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
