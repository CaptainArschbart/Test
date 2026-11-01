class_name ApartmentHouse
extends Node3D
## Treppenhaus mit Wohnungen in einem bestehenden Wohnblock, vom 1. Stock bis unters Dach.
##
## Hängt im lokalen Raum des Gebäudes (Mitte, Front +Z). Eingang vorn in der Mitte. Eine gegenläufige
## Treppe in zwei Spuren: links vom Erdgeschoss nach hinten auf den Absatz im 1. Stock, rechts von
## dort wieder nach vorn auf den Absatz im 2. Stock, links wieder nach hinten und so weiter. Dazwischen
## die Trennwand. Die Wohnungen liegen links und rechts, ihre Türen gehen vom jeweiligen Absatz ab:
## in ungeraden Stockwerken hinten, in geraden vorn.
##
## Nur wenige Wohnungen sind begehbar: je Haus `WALKABLE_UNITS` (2), zufällig über alle Stockwerke verteilt.
## Die erste hat `apt_1`, die zweite `apt_c` (Tankstellenkarte), dessen Schlüssel in `apt_1` versteckt ist.
## Die übrigen haben nur eine feste Tür in einer geschlossenen Wand, dahinter wird nichts gebaut.

const UNIT_SCRIPT := preload("res://scenes/crime/apartment_block.gd")
const WALL := 0.24
const SPINE := 0.12
const STEPS := 15
const RUN := 0.27
const FLOOR_Y := 0.12
## Ab diesem Kameraabstand wird das Innere (Treppenhaus, Wohnungen, Lichter) nicht gezeichnet.
const INTERIOR_FAR := 45.0
## Begehbare Wohnungen je Haus (höchstens).
const WALKABLE_UNITS := 2

@export var building_width := 12.0
@export var building_depth := 10.0
@export var floor_height := 3.0
## Stockwerke des Gebäudes mit Erdgeschoss. Wohnungen liegen im 1. bis zum obersten Stock.
@export var floors := 3
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
var _view_check := 0.0


func _ready() -> void:
	_inner_z = building_depth * 0.5 - WALL
	_stair_back = -RUN * STEPS * 0.5
	_stair_front = -_stair_back
	unit_depth = building_width * 0.5 - WALL - corridor_half - 0.04
	unit_width = building_depth - WALL * 2.0
	_wall = SlumMats.surface("plaster", Color(0.5, 0.52, 0.5))
	_floor = SlumMats.surface("tiles_dark", Color(0.8, 0.8, 0.8))
	_metal = SlumMats.color(Color(0.16, 0.17, 0.18), 0.0, 0.55, 0.6)
	var plan := _plan()
	var b := SlumBuilder.new(self)
	b.solid_range = 60.0
	b.detail_range = 40.0
	_stairwell(b)
	_lobby(b)
	for entry: Dictionary in plan:
		if not entry["walkable"]:
			_blind_unit(b, entry)
	b.finish()
	for entry: Dictionary in plan:
		if entry["walkable"]:
			_unit(entry)


## Eine Zeile je Wohnung: Stock, Seite, Schlüssel, Versteck, Türschild, Türposition, begehbar.
func _plan() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key_prefix + "walkable") ^ hash(str(global_position))
	var back_door := (-_inner_z + _stair_back) * 0.5
	var plan: Array[Dictionary] = []
	for floor_index in range(1, floors):
		for side: int in [-1, 1]:
			plan.append({
				"floor": floor_index,
				"side": side,
				"key": "f%d%s" % [floor_index, "l" if side < 0 else "r"],
				"hide": "",
				"plate": "%d %s" % [floor_index, "L" if side < 0 else "R"],
				"door_z": back_door if floor_index % 2 == 1 else -back_door,
				"walkable": false,
			})
	# Zufällig WALKABLE_UNITS Wohnungen freischalten: erst apt_1, dann apt_c mit dem Schlüssel darin.
	var order: Array[int] = []
	for i in plan.size():
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := order[i]
		order[i] = order[j]
		order[j] = swap
	var keys := ["apt_1", "apt_c"]
	for n in mini(WALKABLE_UNITS, mini(keys.size(), order.size())):
		var entry := plan[order[n]]
		entry["walkable"] = true
		entry["key"] = keys[n]
		entry["hide"] = "" if n == 0 else keys[n - 1]
	return plan


func _process(delta: float) -> void:
	_view_check -= delta
	if _view_check > 0.0:
		return
	_view_check = 0.5
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		visible = cam.global_position.distance_to(global_position) < INTERIOR_FAR + floors * floor_height * 0.5


func _unit(entry: Dictionary) -> void:
	var side: int = entry["side"]
	var floor_index: int = entry["floor"]
	var key: String = entry["key"]
	var hide: String = entry["hide"]
	var door_z: float = entry["door_z"]
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
	unit.plate = entry["plate"]
	unit.front_tint = Color(0.5, 0.52, 0.5)
	unit.front_trim = Color(0.14, 0.12, 0.12)
	unit.door_texture = _door_texture(entry)
	var x := side * (corridor_half + unit_depth * 0.5)
	unit.position = Vector3(x, floor_index * floor_height - ApartmentBlock.FLOOR_TOP, 0.0)
	unit.rotation.y = PI * 0.5 if side < 0 else -PI * 0.5
	add_child(unit)


## Türbild der Wohnung, gleich bei begehbaren und festen Türen.
func _door_texture(entry: Dictionary) -> String:
	return ["door_wood", "door_metal", "door_security"][(entry["floor"] + (0 if entry["side"] < 0 else 1)) % 3]


## Wohnung ohne Zugang: eine geschlossene Wand zum Flur mit fester Tür, Rahmen und Schild.
func _blind_unit(b: SlumBuilder, entry: Dictionary) -> void:
	var side: int = entry["side"]
	var y0: float = entry["floor"] * floor_height - ApartmentBlock.FLOOR_TOP
	var c := corridor_half
	var door_z: float = entry["door_z"]
	b.box_mm(Vector3(side * c, y0, -_inner_z), Vector3(side * (c + 0.2), y0 + floor_height, _inner_z), _wall)
	var face := side * (c - 0.012)
	var normal := Vector3(-side, 0.0, 0.0)
	var trim := SlumMats.color(Color(0.14, 0.12, 0.12))
	var door_y := y0 + ApartmentBlock.FLOOR_TOP
	var tex := _door_texture(entry)
	b.quad(Vector3(face, door_y + 1.08, door_z), normal, ApartmentBlock.DOOR_GAP, 2.16, SlumMats.decal(tex))
	var half := ApartmentBlock.DOOR_GAP * 0.5
	for edge: float in [-half - 0.07, half]:
		b.box_mm(Vector3(side * (c - 0.03), door_y, door_z + edge), Vector3(side * c, door_y + 2.2, door_z + edge + 0.07),
				trim, false, false)
	b.box_mm(Vector3(side * (c - 0.03), door_y + 2.16, door_z - half - 0.07), Vector3(side * c, door_y + 2.23, door_z + half + 0.07),
			trim, false, false)
	var label := Label3D.new()
	label.text = str(entry["plate"])
	label.position = Vector3(side * (c - 0.02), door_y + 2.4, door_z)
	label.rotation.y = -PI * 0.5 * side
	label.font_size = 36
	label.pixel_size = 0.006
	label.modulate = Color(0.55, 0.6, 0.62)
	add_child(label)


func _stairwell(b: SlumBuilder) -> void:
	var c := corridor_half
	var lane := c - SPINE * 0.5
	var lane_x := SPINE * 0.5 + lane * 0.5
	var plate := SlumMats.surface("metal_plate")
	var fh := floor_height
	var top := floors * fh
	var rise := fh / STEPS
	# Läufe: gerade von vorn nach hinten in der linken Spur, ungerade zurück in der rechten.
	for flight in floors - 1:
		var from_front := flight % 2 == 0
		var x := -lane_x if from_front else lane_x
		var z := _stair_front if from_front else _stair_back
		var dir := Vector3.FORWARD if from_front else Vector3.BACK
		if flight == 0:
			b.stairs(Vector3(x, FLOOR_Y, z), dir, STEPS, lane, plate, (fh - FLOOR_Y) / STEPS, RUN, true)
		else:
			b.stairs(Vector3(x, flight * fh, z), dir, STEPS, lane, plate, rise, RUN)
	# Absätze, Oberkante bündig mit der Treppe und den Wohnungsböden: ungerade hinten, gerade vorn.
	for floor_index in range(1, floors):
		var y := floor_index * fh
		if floor_index % 2 == 1:
			b.box_mm(Vector3(-c, y - 0.2, -_inner_z), Vector3(c, y, _stair_back), _floor)
		else:
			b.box_mm(Vector3(-c, y - 0.2, _stair_front), Vector3(c, y, _inner_z), _floor)
	# Decke über dem obersten Stock. Der Block darüber hat keine Unterseite.
	b.box_mm(Vector3(-c, top - 0.1, -_inner_z), Vector3(c, top, _inner_z), SlumMats.surface("concrete", Color(0.7, 0.7, 0.7)))
	# Trennwand zwischen den Spuren, bis unter die Decke.
	b.box_mm(Vector3(-SPINE * 0.5, FLOOR_Y, _stair_back), Vector3(SPINE * 0.5, top - 0.1, _stair_front), _wall)
	# Geländer am obersten Absatz vor der Spur, die von dort nicht weiter hinaufführt.
	var last := floors - 1
	if last >= 1:
		if last % 2 == 0:
			b.railing(Vector3(-c, last * fh, _stair_front), Vector3(-SPINE * 0.5, last * fh, _stair_front), _metal, 1.1, 0.5)
		else:
			b.railing(Vector3(SPINE * 0.5, last * fh, _stair_back), Vector3(c, last * fh, _stair_back), _metal, 1.1, 0.5)
	# Wandleuchten: Halle und jeder Absatz.
	var neon := SlumMats.color(Color(0.8, 0.95, 1.0), 4.0)
	b.box(Vector3(c - 0.04, 2.5, _stair_front + 1.3), Vector3(0.08, 0.1, 0.7), neon, false, false)
	_omni(Vector3(0.3, 2.4, _stair_front + 1.3), Color(0.75, 0.9, 1.0), 1.2)
	for floor_index in range(1, floors):
		var back := floor_index % 2 == 1
		var z := -_inner_z + 0.04 if back else _inner_z - 0.04
		b.box(Vector3(0.0, floor_index * fh + 2.35, z), Vector3(0.7, 0.1, 0.08), neon, false, false)
		_omni(Vector3(0.0, floor_index * fh + 2.2, z + (0.56 if back else -0.56)), Color(0.75, 0.9, 1.0), 1.2)


## Eingangshalle: Wände zum Flur, Briefkästen, Mülltonne, Kellertür unter dem Absatz.
func _lobby(b: SlumBuilder) -> void:
	var c := corridor_half
	var fh := floor_height
	for side: float in [-1.0, 1.0]:
		var x := side * (c + 0.1)
		# Genau bis zur Unterkante der Wohnungen darüber: kein Spalt, keine Überlappung in derselben Ebene.
		var top := fh - ApartmentBlock.FLOOR_TOP
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
