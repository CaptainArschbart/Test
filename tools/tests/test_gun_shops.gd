extends SceneTree
## Vier Waffenläden, Innenausbau, Händler, verschlossene Waffenkammer.
##
## Aufruf: godot --headless --path . -s res://tools/tests/test_gun_shops.gd

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
	var content := load("res://scenes/crime/city_content.gd").new() as Node3D
	root.add_child(content)
	await process_frame
	var guns: Array[Node] = []
	for child in content.get_children():
		if str(child.get("kind")) == "0":
			guns.append(child)
	_check(guns.size() == 4, "vier Waffenläden, ist %d" % guns.size())
	for shop in guns:
		_check(shop.get_node_or_null(^"Shopkeeper") is CharacterBody3D, "%s hat Händler" % shop.position)
		_check(shop.get_node_or_null(^"Clerk") != null, "%s hat Handelspunkt" % shop.position)
		_check(shop.get_node_or_null(^"Atm") != null, "%s hat Automaten" % shop.position)
		var door := shop.get_node_or_null(^"BackDoor")
		_check(door != null and bool(door.get("locked")), "%s Kammer ist zu" % shop.position)
		_check(shop.get_node_or_null(^"GlassCase") != null, "%s Vitrine" % shop.position)
		_check(shop.get_node_or_null(^"NeonSign") != null, "%s Neon" % shop.position)
		_check(shop.get_node_or_null(^"ArmoryCrate") != null, "%s Waffenkiste" % shop.position)
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(_fails)
