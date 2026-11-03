extends SceneTree
## Prüft Item-Icons und -Modelle: Jedes Item (außer Währung) hat ein gerendertes Icon und ein
## Display-Modell, jede Waffenszene hat ihr importiertes Modell und die Marker, die WeaponHolder,
## PlayerHands und der Pickup brauchen. Pickups von Klinge und Granate zeigen ihr Modell.
##
## Aufruf (Projektordner):
##   godot --headless --path . -s res://tools/tests/test_item_icons.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const DATA_DIR := "res://scenes/items/data"
const ICON_DIR := "res://assets/icons/items"
const WEAPONS := ["pistol", "smg", "ak47", "m4", "sniper"]
## Erst zur Laufzeit laden: ItemDisplay zieht pickup-nahe Skripte nach, die Autoloads brauchen.
const DISPLAY_PATH := "res://scenes/items/item_display.gd"

var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for f in DirAccess.get_files_at(DATA_DIR):
		if f.get_extension() == "tres":
			var item := load(DATA_DIR.path_join(f)) as ItemData
			if item != null:
				out.append(item)
	return out


func _meshes(node: Node) -> int:
	var n := 1 if node is MeshInstance3D else 0
	for c in node.get_children():
		n += _meshes(c)
	return n


func _run() -> void:
	change_scene_to_file("res://scenes/testmap/testmap.tscn")
	for i in 10:
		await process_frame
	var display: Script = load(DISPLAY_PATH)
	var missing_icon := PackedStringArray()
	var missing_model := PackedStringArray()
	var items := _items()
	for item in items:
		if item.is_currency:
			continue
		if item.icon == null or not item.icon.resource_path.begins_with(ICON_DIR):
			missing_icon.append(item.id)
		elif item.icon.get_width() < 128:
			missing_icon.append(item.id + " (zu klein)")
		var model: Node3D = display.call("build", item)
		if model == null or _meshes(model) == 0:
			missing_model.append(item.id)
		if model != null:
			model.free()
	_check(items.size() >= 35, "Alle Items gefunden (%d)" % items.size())
	_check(missing_icon.is_empty(), "Jedes Item hat ein gerendertes Icon %s" % [missing_icon])
	_check(missing_model.is_empty(), "Jedes Item hat ein Display-Modell %s" % [missing_model])

	var views := {}
	for id: String in WEAPONS:
		var weapon := load(DATA_DIR.path_join(id + ".tres")) as WeaponData
		var view: Node3D = weapon.view_scene.instantiate()
		views[weapon.view_scene.resource_path] = id
		var model := view.get_node_or_null("Model")
		_check(model != null and _meshes(model) > 0, "%s: importiertes Modell mit Mesh" % id)
		_check(view.get_node_or_null("Muzzle/Flash") != null and view.get_node_or_null("Muzzle/FlashLight") != null,
				"%s: Mündung mit Blitz und Licht" % id)
		var muzzle := view.get_node("Muzzle") as Node3D
		_check(muzzle.position.z < -0.15, "%s: Mündung vor dem Griff (z %.2f)" % [id, muzzle.position.z])
		var mag := view.get_node_or_null("Magazine")
		if weapon.automatic:
			_check(mag != null and mag.get_node_or_null("HandReloadLeft") != null, "%s: Magazin mit Nachlade-Marker" % id)
			_check(view.get_node_or_null("HandGripLeft") != null and view.get_node_or_null("Eject") != null,
					"%s: linker Griff und Hülsenauswurf" % id)
		# Die Visierhöhe passt zum Modell: Mitte zwischen Lauf und gut 10 cm darüber.
		_check(weapon.sight_offset.y > muzzle.position.y - 0.05 and weapon.sight_offset.y < muzzle.position.y + 0.1,
				"%s: Visier über dem Lauf (%.3f, Lauf %.3f)" % [id, weapon.sight_offset.y, muzzle.position.y])
		view.free()
	_check(views.size() == WEAPONS.size(), "Jede Waffe hat ihre eigene Szene (%d)" % views.size())

	# Klinge und Granate liegen als Modell statt als Würfel in der Welt.
	for id: String in ["mono_blade", "emp_grenade", "contact_grenade"]:
		var pickup: Node3D = load("res://scenes/items/pickup.tscn").instantiate()
		pickup.set("item", load(DATA_DIR.path_join(id + ".tres")))
		current_scene.add_child(pickup)
		await process_frame
		await process_frame
		var shown := pickup.get_node_or_null("Visual/ConsumableModel")
		var cube := pickup.get_node_or_null("Visual/Mesh") as Node3D
		_check(shown != null and cube != null and not cube.visible, "%s: Pickup zeigt Modell statt Würfel" % id)
		pickup.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
