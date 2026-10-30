class_name ApartmentHouse
extends Node3D
## Vier Wohnungen in einem bestehenden Wohnblock: Flur, Treppe, zwei pro Stock.
##
## Hängt im lokalen Raum des Gebäudes (Mitte, Front +Z). Die Einheiten stehen
## links und rechts vom Flur, Tür zum Flur. Stock 1 und 2, nicht das Erdgeschoss.

const UNIT_SCRIPT := preload("res://scenes/crime/apartment_block.gd")

@export var building_width := 12.0
@export var building_depth := 10.0
@export var floor_height := 3.0
@export var corridor_half := 0.9

var unit_depth := 4.2
var unit_width := 7.2


func _ready() -> void:
	unit_depth = minf(4.2, (building_width - corridor_half * 2.0 - 0.8) * 0.5)
	unit_width = minf(7.2, building_depth - 1.6)
	_corridor_floors()
	_stairs(0, 1, 1.4, -1.0)
	_stairs(1, 2, -2.0, 1.0)
	_unit("apt_1", "", 1, -1, 0)
	_unit("apt_2", "apt_1", 1, 1, 1)
	_unit("apt_3", "apt_2", 2, -1, 2)
	_unit("apt_c", "apt_3", 2, 1, 0)


func _unit(key: String, hide: String, floor_index: int, side: int, theme_hint: int) -> void:
	var unit := UNIT_SCRIPT.new() as ApartmentBlock
	unit.name = "Unit_%s" % key
	unit.key_id = key
	unit.hidden_key = hide
	unit.resident_count = -1
	unit.unit_width = unit_width
	unit.unit_depth = unit_depth
	unit.theme = theme_hint
	var x := side * (corridor_half + unit_depth * 0.5)
	unit.position = Vector3(x, floor_index * floor_height, 0.2)
	# Linke Tür zeigt nach +X in den Flur, rechte nach -X.
	unit.rotation.y = PI * 0.5 if side < 0 else -PI * 0.5
	add_child(unit)


func _corridor_floors() -> void:
	for floor_index in [1, 2]:
		var slab := StaticBody3D.new()
		slab.name = "CorridorFloor%d" % floor_index
		slab.collision_layer = 1
		slab.position = Vector3(0.0, floor_index * floor_height + 0.04, 0.4)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(corridor_half * 2.0, 0.08, unit_width - 0.4)
		shape.shape = box
		slab.add_child(shape)
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = box.size
		mesh.mesh = cube
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.14, 0.13, 0.15)
		mesh.material_override = mat
		slab.add_child(mesh)
		add_child(slab)


func _stairs(from_floor: int, to_floor: int, z_start: float, direction: float) -> void:
	var steps := 12
	var rise := floor_height / float(steps)
	var run := 0.32
	var y0 := from_floor * floor_height
	for i in steps:
		var step := StaticBody3D.new()
		step.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(corridor_half * 1.6, rise, run)
		shape.shape = box
		step.add_child(shape)
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = box.size
		mesh.mesh = cube
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.22, 0.2, 0.18)
		mesh.material_override = mat
		step.add_child(mesh)
		var z := z_start + direction * run * (float(i) + 0.5)
		step.position = Vector3(0.0, y0 + rise * (float(i) + 0.5), z)
		add_child(step)
