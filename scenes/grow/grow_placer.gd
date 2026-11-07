extends Node3D
## Aufstellen von PlaceableData-Items (Anbau-Stationen). Hängt unter ItemUser.
## Ist so ein Item gewählt, zeigt eine halbdurchsichtige Vorschau, wo es landet (grün = passt,
## rot = kein ebener Boden oder kein Platz). Rechtsklick (use_item) stellt es auf, Blick zum Spieler.
## Kein class_name: ItemUser lädt das per preload (Klassen-Cache nach einem Pull).

const Models := preload("res://scenes/grow/grow_models.gd")
const PlaceableDataScript := preload("res://scenes/grow/placeable_data.gd")
const StationScript := preload("res://scenes/grow/grow_station.gd")
## Reichweite (m) und wie flach der Boden sein muss (Normale y).
const RANGE := 3.5
const FLAT := 0.85

var player: Player

var _ghost: Node3D
var _ghost_kind := &""
var _valid := false
var _spot := Transform3D()
var _ok_mat: StandardMaterial3D
var _bad_mat: StandardMaterial3D


func _ready() -> void:
	_ok_mat = _ghost_mat(Color(0.3, 1.0, 0.5, 0.35))
	_bad_mat = _ghost_mat(Color(1.0, 0.25, 0.25, 0.35))


func _physics_process(_delta: float) -> void:
	var item := _item()
	if item == null:
		_clear_ghost()
		return
	var kind: StringName = item.station
	if _ghost == null or kind != _ghost_kind:
		_clear_ghost()
		_ghost = Models.station(kind)
		_ghost.top_level = true
		add_child(_ghost)
		_ghost_kind = kind
	_valid = _find_spot(kind)
	_ghost.global_transform = _spot
	for mi in _ghost.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _ok_mat if _valid else _bad_mat


## Rechtsklick: aufstellen. true, wenn eine Station entstand.
func place() -> bool:
	var item := _item()
	if item == null:
		return false
	_valid = _find_spot(item.station)
	if not _valid:
		player.item_user.show_message("Hier nicht – ebenen, freien Boden anschauen", Color(1.0, 0.5, 0.3))
		return false
	if player.inventory.remove_item(item, 1) != 1:
		return false
	var station := StationScript.create(item.station, item)
	get_tree().current_scene.add_child(station)
	station.global_transform = _spot
	GrowSync.placed(station)
	player.item_user.show_message("%s aufgestellt" % item.display_name, Color(0.4, 1.0, 0.6))
	return true


func _item() -> ItemData:
	if player == null or player.inventory == null:
		return null
	var item := player.inventory.get_selected_item()
	return item if item is PlaceableDataScript else null


## Boden unter dem Fadenkreuz: eben, frei, nah genug. Setzt _spot.
func _find_spot(kind: StringName) -> bool:
	var camera := player.camera
	var from := camera.global_position
	var to := from - camera.global_basis.z * RANGE
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()]))
	var yaw := player.global_rotation.y
	if hit.is_empty():
		_spot = Transform3D(Basis(Vector3.UP, yaw), to)
		return false
	_spot = Transform3D(Basis(Vector3.UP, yaw), hit.position)
	if (hit.normal as Vector3).y < FLAT:
		return false
	return fits(space, kind, _spot)


## Passt eine Station `kind` an `spot` (nichts im Weg, Spieler eingeschlossen)?
static func fits(space: PhysicsDirectSpaceState3D, kind: StringName, spot: Transform3D, ignore := RID()) -> bool:
	var size := Models.footprint(kind)
	var box := BoxShape3D.new()
	box.size = size - Vector3(0.02, 0.0, 0.02)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	# Etwas über dem Boden, sonst zählt der Boden selbst.
	query.transform = spot * Transform3D(Basis(), Vector3(0, size.y * 0.5 + 0.04, 0))
	query.collision_mask = 1 | 2
	if ignore.is_valid():
		query.exclude = [ignore]
	return space.intersect_shape(query, 1).is_empty()


func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
		_ghost_kind = &""


func _ghost_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
