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
		var layout: PackedStringArray = shop.get("layout_errors")
		_check(layout.is_empty(), "%s Innenraum ohne Placement-Fehler %s" % [shop.position, layout])
	_check_planner()
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(_fails)


## Gegenprobe: Der Grundriss-Planer meldet Überschneidung, Schweben und zugestellte Wege wirklich.
func _check_planner() -> void:
	var plan := InteriorPlanner.new(Rect2(0, 0, 4, 4))
	plan.solid(Rect2(0, 0, 1, 1), "Kiste A", 0.5)
	plan.solid(Rect2(0.5, 0.5, 1, 1), "Kiste B", 0.5)
	_check(Array(plan.errors).any(func(e: String) -> bool: return e.begins_with("R2")), "Planer meldet Überschneidung")
	plan = InteriorPlanner.new(Rect2(0, 0, 4, 4))
	plan.solid(Rect2(0, 0, 1, 1), "Tisch", 0.8)
	plan.on_top(Vector2(0.5, 0.5), 0.8, "Monitor")
	_check(plan.errors.is_empty(), "Planer: Monitor auf dem Tisch ist in Ordnung")
	plan.on_top(Vector2(2.5, 2.5), 0.8, "Lampe in der Luft")
	_check(Array(plan.errors).any(func(e: String) -> bool: return e.begins_with("R1")), "Planer meldet Schweben")
	plan = InteriorPlanner.new(Rect2(0, 0, 4, 4))
	plan.wall(Rect2(0, 1.8, 4, 0.4), "Wand quer durch")
	plan.check_reachable(Vector2(2, 0.5), {"hinten": Vector2(2, 3.5)})
	_check(Array(plan.errors).any(func(e: String) -> bool: return e.begins_with("R5")), "Planer meldet unerreichbares Ziel")

