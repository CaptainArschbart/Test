class_name SafeProp
extends LootProp
## Tresor: Stahlkasten mit Tür. Geht nur mit der Brechstange auf, laut und mit Fahndung.
## Danach steht er offen, E räumt ihn aus. Der Kasten bleibt stehen.

const SIZE := Vector3(0.7, 0.85, 0.6)
const WALL := 0.05

var _door: MeshInstance3D
var _stash: MeshInstance3D


func _build_look() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position = Vector3(0.0, SIZE.y * 0.5, 0.0)
	add_child(shape)
	var steel := SlumMats.color(Color(0.13, 0.15, 0.17), 0.0, 0.45, 0.7)
	var b := SlumBuilder.new(self)
	var half := SIZE * 0.5
	b.box(Vector3(0.0, WALL * 0.5, 0.0), Vector3(SIZE.x, WALL, SIZE.z), steel, false)
	b.box(Vector3(0.0, SIZE.y - WALL * 0.5, 0.0), Vector3(SIZE.x, WALL, SIZE.z), steel, false)
	b.box(Vector3(0.0, half.y, -half.z + WALL * 0.5), Vector3(SIZE.x, SIZE.y, WALL), steel, false)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (half.x - WALL * 0.5), half.y, 0.0), Vector3(WALL, SIZE.y, SIZE.z), steel, false)
	b.finish()
	_door = MeshInstance3D.new()
	_door.name = "SafeDoor"
	var plate := BoxMesh.new()
	plate.size = Vector3(SIZE.x - 0.04, SIZE.y - 0.04, 0.05)
	plate.material = SlumMats.color(Color(0.2, 0.22, 0.25), 0.0, 0.4, 0.8)
	_door.mesh = plate
	_door.position = Vector3(0.0, half.y, half.z + 0.02)
	add_child(_door)
	var dial := MeshInstance3D.new()
	var round_dial := CylinderMesh.new()
	round_dial.top_radius = 0.07
	round_dial.bottom_radius = 0.07
	round_dial.height = 0.03
	round_dial.material = SlumMats.color(Color(0.75, 0.72, 0.6), 0.0, 0.35, 0.8)
	dial.mesh = round_dial
	dial.rotation.x = PI * 0.5
	dial.position = Vector3(0.1, 0.05, 0.035)
	_door.add_child(dial)
	var lamp := MeshInstance3D.new()
	var dot := BoxMesh.new()
	dot.size = Vector3(0.03, 0.03, 0.01)
	dot.material = SlumMats.color(Color(1.0, 0.15, 0.1), 5.0)
	lamp.mesh = dot
	lamp.position = Vector3(-0.2, 0.28, 0.03)
	_door.add_child(lamp)
	_stash = MeshInstance3D.new()
	_stash.name = "Stash"
	var pile := BoxMesh.new()
	pile.size = Vector3(0.42, 0.22, 0.3)
	pile.material = SlumMats.color(item.color if item != null else Color(0.3, 0.7, 0.4), 0.3)
	_stash.mesh = pile
	_stash.position = Vector3(0.0, 0.17, 0.0)
	add_child(_stash)


func get_interact_text(_player: Player) -> String:
	if taken:
		return ""
	if sealed:
		return "%s (Brechstange, Linksklick)" % prompt_name
	return "%s ausräumen" % prompt_name


## Ein Schlag öffnet nur. Das Geld holt E, sonst räumt ein zweiter Schlag den Tresor nebenbei aus.
func break_open(player: Node) -> void:
	if taken or not sealed:
		return
	super.break_open(player)
	_door.position = Vector3(SIZE.x * 0.5 + 0.2, SIZE.y * 0.5, SIZE.z * 0.5 + 0.28)
	_door.rotation.y = deg_to_rad(-105.0)
	if not WorldSync.is_client():
		var token := get_parent().get_instance_id() if get_parent() != null else get_instance_id()
		WantedManager.report(&"burglary", global_position, token)


func _after_take() -> void:
	_stash.visible = false
