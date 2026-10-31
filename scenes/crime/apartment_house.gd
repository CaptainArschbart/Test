class_name ApartmentHouse
extends Node3D
## Treppenhaus mit vier Wohnungen in einem bestehenden Wohnblock.
##
## Hängt im lokalen Raum des Gebäudes (Mitte, Front +Z). Eingang vorn in der Mitte. Eine gegenläufige
## Treppe in zwei Spuren: links vom Erdgeschoss nach hinten auf den Absatz im 1. Stock, rechts von
## dort wieder nach vorn auf den Absatz im 2. Stock. Dazwischen die Trennwand, die Spuren darüber
## bleiben offen, damit nirgends der Kopf anstößt. Die Wohnungen liegen links und rechts, ihre
## Türen gehen vom jeweiligen Absatz ab: im 1. Stock hinten, im 2. Stock vorn.

const UNIT_SCRIPT := preload("res://scenes/crime/apartment_block.gd")
const WALL := 0.24
const SPINE := 0.12
const STEPS := 15
const RUN := 0.27
const FLOOR_Y := 0.12

@export var building_width := 12.0
@export var building_depth := 10.0
@export var floor_height := 3.0
@export var corridor_half := 1.3
## Vor die Schlüssel-ids gesetzt, damit jedes Haus eigene Schlüssel hat. Res2 hat keinen:
## Die Karte an der Tankstelle öffnet dort `apt_c`.
@export var key_prefix := ""

var unit_depth := 4.2
var unit_width := 7.2
var _stair_back := -2.0
var _stair_front := 2.0
var _inner_z := 4.7
var _wall: Material
var _floor: Material
var _metal: Material


func _ready() -> void:
	_inner_z = building_depth * 0.5 - WALL
	_stair_back = -RUN * STEPS * 0.5
	_stair_front = -_stair_back
	unit_depth = building_width * 0.5 - WALL - corridor_half - 0.04
	unit_width = building_depth - WALL * 2.0 - 0.04
	_wall = SlumMats.surface("plaster", Color(0.5, 0.52, 0.5))
	_floor = SlumMats.surface("tiles_dark", Color(0.8, 0.8, 0.8))
	_metal = SlumMats.color(Color(0.16, 0.17, 0.18), 0.0, 0.55, 0.6)
	var b := SlumBuilder.new(self)
	b.solid_range = 60.0
	b.detail_range = 40.0
	_stairwell(b)
	_lobby(b)
	b.finish()
	var back_door := (-_inner_z + _stair_back) * 0.5
	var front_door := -back_door
	_unit("apt_1", "", 1, -1, back_door, "1 L")
	_unit("apt_2", "apt_1", 1, 1, back_door, "1 R")
	_unit("apt_3", "apt_2", 2, -1, front_door, "2 L")
	_unit("apt_c", "apt_3", 2, 1, front_door, "2 R")


func _unit(key: String, hide: String, floor_index: int, side: int, door_z: float, door_plate: String) -> void:
	var unit := UNIT_SCRIPT.new() as ApartmentBlock
	unit.name = "Unit_%s" % key
	unit.key_id = key_prefix + key
	unit.hidden_key = "" if hide.is_empty() else key_prefix + hide
	unit.resident_count = -1
	unit.unit_width = unit_width
	unit.unit_depth = unit_depth
	unit.ceiling_top = floor_height
	# Linke Tür zeigt nach +X in den Flur, rechte nach -X. Lokales X läuft links nach -Z.
	unit.door_offset = -door_z if side < 0 else door_z
	unit.plate = door_plate
	var x := side * (corridor_half + 0.02 + unit_depth * 0.5)
	unit.position = Vector3(x, floor_index * floor_height - ApartmentBlock.FLOOR_TOP, 0.0)
	unit.rotation.y = PI * 0.5 if side < 0 else -PI * 0.5
	add_child(unit)


func _stairwell(b: SlumBuilder) -> void:
	var c := corridor_half
	var lane := c - SPINE * 0.5
	var lane_x := SPINE * 0.5 + lane * 0.5
	var plate := SlumMats.surface("metal_plate")
	var first_rise := (floor_height - FLOOR_Y) / STEPS
	b.stairs(Vector3(-lane_x, FLOOR_Y, _stair_front), Vector3.FORWARD, STEPS, lane, plate, first_rise, RUN, true)
	b.stairs(Vector3(lane_x, floor_height, _stair_back), Vector3.BACK, STEPS, lane, plate, floor_height / STEPS, RUN)
	# Absätze. Oberkante bündig mit der Treppe und den Wohnungsböden.
	var fh := floor_height
	b.box_mm(Vector3(-c, fh - 0.2, -_inner_z), Vector3(c, fh, _stair_back), _floor)
	b.box_mm(Vector3(-c, fh * 2.0 - 0.2, _stair_front), Vector3(c, fh * 2.0, _inner_z), _floor)
	# Decke über dem 2. Stock. Der Block darüber hat keine Unterseite.
	b.box_mm(Vector3(-c, fh * 3.0 - 0.1, -_inner_z), Vector3(c, fh * 3.0, _inner_z), SlumMats.surface("concrete", Color(0.7, 0.7, 0.7)))
	# Trennwand zwischen den Spuren, oben Brüstungshöhe des 2. Stocks.
	b.box_mm(Vector3(-SPINE * 0.5, FLOOR_Y, _stair_back), Vector3(SPINE * 0.5, fh * 2.0 + 1.1, _stair_front), _wall)
	# Geländer am Absatz im 2. Stock über der linken Spur.
	b.railing(Vector3(-c, fh * 2.0, _stair_front), Vector3(-SPINE * 0.5, fh * 2.0, _stair_front), _metal, 1.1, 0.5)
	# Wandleuchten: Halle, Absatz hinten, Absatz vorn.
	var neon := SlumMats.color(Color(0.8, 0.95, 1.0), 4.0)
	b.box(Vector3(c - 0.04, 2.5, _stair_front + 1.3), Vector3(0.08, 0.1, 0.7), neon, false, false)
	b.box(Vector3(0.0, fh + 2.35, -_inner_z + 0.04), Vector3(0.7, 0.1, 0.08), neon, false, false)
	b.box(Vector3(0.0, fh * 2.0 + 2.35, _inner_z - 0.04), Vector3(0.7, 0.1, 0.08), neon, false, false)
	_omni(Vector3(0.3, 2.4, _stair_front + 1.3), Color(0.75, 0.9, 1.0), 1.2)
	_omni(Vector3(0.0, fh + 2.2, -_inner_z + 0.6), Color(0.75, 0.9, 1.0), 1.2)
	_omni(Vector3(0.0, fh * 2.0 + 2.2, _inner_z - 0.6), Color(0.75, 0.9, 1.0), 1.2)


## Eingangshalle: Wände zum Flur, Briefkästen, Mülltonne, Kellertür unter dem Absatz.
func _lobby(b: SlumBuilder) -> void:
	var c := corridor_half
	var fh := floor_height
	for side: float in [-1.0, 1.0]:
		var x := side * (c + 0.1)
		var top := fh - 0.12
		b.box(Vector3(x, (FLOOR_Y + top) * 0.5, 0.0), Vector3(0.2, top - FLOOR_Y, _inner_z * 2.0), _wall)
	var boxes := SlumMats.color(Color(0.28, 0.32, 0.3), 0.0, 0.5, 0.5)
	var slot := SlumMats.color(Color(0.05, 0.05, 0.06))
	var z0 := _stair_front + 0.3
	for row: int in 3:
		for col: int in 4:
			var at := Vector3(c - 0.09, 1.0 + row * 0.3, z0 + col * 0.3)
			b.box(at, Vector3(0.18, 0.27, 0.27), boxes, col == 0 and row == 0)
			b.box(at + Vector3(-0.09, 0.05, 0.0), Vector3(0.006, 0.03, 0.18), slot, false, false)
	b.box(Vector3(-c + 0.3, FLOOR_Y + 0.4, _inner_z - 0.4), Vector3(0.5, 0.8, 0.5), SlumMats.surface("rust"))
	b.quad(Vector3(-c + 0.01, 1.5, _stair_front + 0.9), Vector3.RIGHT, 0.5, 0.75, SlumMats.decal("poster_3"))
	b.quad(Vector3(-c + 0.012, 1.0, _stair_front + 1.7), Vector3.RIGHT, 1.2, 0.6, SlumMats.decal("tag_1"))
	# Kellertür am hinteren Ende der rechten Spur (nur Optik).
	b.quad(Vector3(c * 0.5, FLOOR_Y + 1.05, -_inner_z + 0.03), Vector3.BACK, 1.0, 2.1, SlumMats.decal("door_metal"))


func _omni(at: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 34.0
	light.distance_fade_length = 8.0
	add_child(light)
