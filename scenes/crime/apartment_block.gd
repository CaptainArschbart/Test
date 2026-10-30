class_name ApartmentBlock
extends Node3D
## Begehbare Wohnung. Tür zu, Beute im Inventar, Bewohner nur manchmal.
##
## 35 % der Wohnungen haben beim Laden 1 oder 2 Bewohner (gleich oft).
## Die übrigen sind leer. `resident_count` >= 0 erzwingt die Zahl (Tests).

const JEWELRY := preload("res://scenes/items/data/jewelry.tres")
const JEWELS := preload("res://scenes/items/data/jewels.tres")
const CASH := preload("res://scenes/items/data/cash_wad.tres")
const TV := preload("res://scenes/items/data/tv_set.tres")
const ART := preload("res://scenes/items/data/painting.tres")
const PC := preload("res://scenes/items/data/computer.tres")
const KEY := preload("res://scenes/items/data/keycard.tres")

const RESIDENT_CHANCE := 0.35

@export var key_id := "apt_a"
## -1 = Würfel. 0, 1 oder 2 erzwingen die Bewohnerzahl.
@export var resident_count := -1
@export var hidden_key := ""

var theme := 0
var spawned_residents := 0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key_id) ^ hash(str(global_position))
	theme = rng.randi_range(0, 2)
	_build_shell(_palette())
	_furnish()
	var door := LockedDoor.new()
	door.name = "Door"
	door.unique_name_in_owner = true
	door.key_id = key_id
	door.locked = true
	door.position = Vector3(0.0, 0.0, 3.4)
	add_child(door)
	door.owner = self
	_place_loot()
	if not hidden_key.is_empty():
		var key := KEY.duplicate() as ItemData
		key.id = hidden_key
		var stash := LootProp.new()
		stash.name = "SpareKey"
		stash.item = key
		stash.prompt_name = "Schlüsselkarte"
		stash.position = Vector3(2.6, 0.55, 2.2)
		add_child(stash)
	spawned_residents = resolve_resident_count(rng, resident_count)
	_spawn_residents(spawned_residents)
	_lights()
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = "WOHNUNG"
	sign.position = Vector3(0.0, 2.55, 3.72)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.modulate = _palette()["neon"]
	add_child(sign)


## 0, oder bei Treffer (35 %) eine 1 oder eine 2, je zur Hälfte.
static func resolve_resident_count(rng: RandomNumberGenerator, forced: int) -> int:
	if forced >= 0:
		return mini(forced, 2)
	if rng.randf() >= RESIDENT_CHANCE:
		return 0
	return 1 if rng.randf() < 0.5 else 2


func _palette() -> Dictionary:
	match theme:
		1:
			return {
				"wall": Color(0.34, 0.22, 0.16),
				"trim": Color(0.22, 0.13, 0.1),
				"floor": Color(0.28, 0.18, 0.12),
				"cloth": Color(0.45, 0.16, 0.18),
				"neon": Color(1.0, 0.62, 0.28),
				"light": Color(1.0, 0.72, 0.4),
			}
		2:
			return {
				"wall": Color(0.16, 0.2, 0.28),
				"trim": Color(0.1, 0.12, 0.18),
				"floor": Color(0.12, 0.14, 0.18),
				"cloth": Color(0.2, 0.28, 0.4),
				"neon": Color(0.45, 0.75, 1.0),
				"light": Color(0.55, 0.75, 1.0),
			}
		_:
			return {
				"wall": Color(0.22, 0.1, 0.2),
				"trim": Color(0.12, 0.06, 0.12),
				"floor": Color(0.1, 0.08, 0.12),
				"cloth": Color(0.55, 0.1, 0.4),
				"neon": Color(0.3, 0.95, 1.0),
				"light": Color(0.35, 0.9, 1.0),
			}


func _build_shell(colors: Dictionary) -> void:
	_box(Vector3(0.0, 0.05, 0.0), Vector3(8.0, 0.1, 7.0), colors["floor"])
	_box(Vector3(0.0, 2.75, 0.0), Vector3(8.0, 0.1, 7.0), colors["trim"])
	_box(Vector3(0.0, 1.4, -3.4), Vector3(8.0, 2.7, 0.16), colors["wall"])
	_box(Vector3(-3.92, 1.4, 0.0), Vector3(0.16, 2.7, 7.0), colors["wall"])
	_box(Vector3(3.92, 1.4, 0.0), Vector3(0.16, 2.7, 7.0), colors["wall"])
	# Türspalt 1,4 m in der Mitte, Blatt 1,1 m.
	_box(Vector3(-2.25, 1.4, 3.42), Vector3(3.1, 2.7, 0.16), colors["wall"])
	_box(Vector3(2.25, 1.4, 3.42), Vector3(3.1, 2.7, 0.16), colors["wall"])


func _furnish() -> void:
	var colors := _palette()
	_prop("Sofa", Vector3(-2.15, 0.32, -2.35), Vector3(1.8, 0.55, 0.8), colors["cloth"])
	_prop("Bed", Vector3(-2.2, 0.28, 0.7), Vector3(1.7, 0.45, 1.35), colors["cloth"])
	_prop("Nightstand", Vector3(-3.15, 0.28, -0.15), Vector3(0.45, 0.5, 0.4), colors["trim"])
	_prop("Kitchen", Vector3(2.85, 0.48, 0.15), Vector3(1.5, 0.9, 2.0), colors["trim"])
	_prop("Fridge", Vector3(3.35, 0.85, -1.55), Vector3(0.7, 1.6, 0.65), Color(0.75, 0.78, 0.8))
	_prop("Desk", Vector3(1.55, 0.4, 1.15), Vector3(1.2, 0.72, 0.6), colors["trim"])
	_prop("Table", Vector3(0.15, 0.22, -1.15), Vector3(1.0, 0.38, 0.55), colors["trim"])
	_lamp(Vector3(-2.2, 0.85, -0.15), colors["light"])
	_lamp(Vector3(2.5, 1.15, 0.15), colors["neon"])


func _place_loot() -> void:
	_loot("Schmuck", JEWELRY, Vector3(-3.15, 0.6, -0.15), false, &"Jewelry")
	_loot("Juwelen", JEWELS, Vector3(-2.15, 0.7, -2.15), true, &"Jewels")
	_loot("Bargeld", CASH, Vector3(0.15, 0.5, -1.15), false, &"Cash")
	_loot("Fernseher", TV, Vector3(2.35, 0.85, -2.55), false, &"Television")
	_loot("Bild", ART, Vector3(-3.55, 1.45, 0.9), false, &"Artwork")
	_loot("Computer", PC, Vector3(1.55, 0.85, 1.15), false, &"Computer")


func _spawn_residents(count: int) -> void:
	var spots: Array[Vector3] = [Vector3(0.35, 0.12, -0.15), Vector3(-0.45, 0.12, 1.7)]
	for i in mini(count, spots.size()):
		var person := Civilian.new()
		person.name = "Resident%d" % (i + 1)
		person.unique_name_in_owner = true
		person.stay_put = true
		person.position = spots[i]
		person.rotation.y = PI if i == 0 else 0.0
		add_child(person)
		person.owner = self


func _lights() -> void:
	var colors := _palette()
	_omni(Vector3(0.0, 2.45, 0.2), colors["light"], 1.1)
	_omni(Vector3(-2.0, 2.2, -1.4), colors["neon"], 0.45)


func _loot(title: String, item: ItemData, at: Vector3, sealed: bool, node_name: StringName) -> void:
	var prop := LootProp.new()
	prop.name = node_name
	prop.unique_name_in_owner = true
	prop.prompt_name = title
	prop.item = item
	prop.sealed = sealed
	prop.position = at
	add_child(prop)
	prop.owner = self


func _prop(node_name: String, at: Vector3, size: Vector3, color: Color) -> void:
	var body := _box(at, size, color)
	body.name = node_name


func _lamp(at: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.06
	bulb.height = 0.12
	mesh.mesh = bulb
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	add_child(mesh)


func _omni(at: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 6.5
	light.shadow_enabled = false
	add_child(light)


func _box(at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	return body
