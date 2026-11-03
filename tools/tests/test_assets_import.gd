extends SceneTree
## Lädt jedes 3D-Modell unter den einsortierten Asset-Ordnern und prüft, ob es importiert ist und Meshes hat.
## Dazu: Charaktere haben ein Skelett, die Animationsbibliothek hat Animationen, Skyboxen sind Texturen.
##
## Aufruf (Projektordner, vorher einmal `godot --headless --path . --import`):
##   godot --headless --path . -s res://tools/tests/test_assets_import.gd
## Ergebnis steht in der letzten Zeile: "CHECKS n FAILS m", Exitcode 0 = alles grün.

const MODEL_DIRS := ["res://assets/characters", "res://assets/animations", "res://assets/buildings",
		"res://assets/props", "res://assets/items"]
const MODEL_EXT := ["glb", "gltf", "fbx"]
const SKY_DIR := "res://assets/sky/kenney_skyboxes"
const UAL2 := "res://assets/animations/quaternius_ual2/UAL2_Standard.glb"

var _checks := 0
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _files(dir: String, exts: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in exts:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d), exts))
	return out


func _count(node: Node, type: String) -> int:
	var n := 1 if node.is_class(type) else 0
	for c in node.get_children():
		n += _count(c, type)
	return n


func _run() -> void:
	var total := 0
	var broken := PackedStringArray()
	for dir in MODEL_DIRS:
		for path in _files(dir, MODEL_EXT):
			total += 1
			var scene := load(path) as PackedScene
			var inst: Node = scene.instantiate() if scene != null else null
			if inst == null or _count(inst, "MeshInstance3D") == 0:
				broken.append(path)
			if inst != null:
				if path.begins_with("res://assets/characters"):
					_check(_count(inst, "Skeleton3D") > 0, "Skelett in %s" % path.get_file())
				inst.free()
	print("  info %d Modelle geladen" % total)
	for p in broken:
		print("  info ohne Mesh oder nicht ladbar: " + p)
	_check(total >= 706, "Alle Modelle gefunden (%d)" % total)
	_check(broken.is_empty(), "Alle Modelle laden mit Mesh (%d kaputt)" % broken.size())

	var ual := load(UAL2) as PackedScene
	var ual_inst: Node = ual.instantiate() if ual != null else null
	var anims := 0
	if ual_inst != null:
		var players := ual_inst.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			var names := (players[0] as AnimationPlayer).get_animation_list()
			anims = names.size()
			print("  info Animationen: " + ", ".join(names))
		ual_inst.free()
	_check(anims >= 43, "Animationsbibliothek hat alle 43 Animationen (%d)" % anims)

	var skies := _files(SKY_DIR, ["png"])
	var sky_ok := skies.size() == 5
	for p in skies:
		sky_ok = sky_ok and load(p) is Texture2D
	_check(sky_ok, "5 Skyboxen als Textur geladen")
	_finish()


func _finish() -> void:
	print("CHECKS %d FAILS %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
