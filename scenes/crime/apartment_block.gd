class_name ApartmentBlock
extends Node3D
## Begehbare Wohnung: Wände, verschlossene Tür, Bewohner, Beute.
## Der Bewohner bleibt drinnen (Civilian.stay_put) und hört Einbruch.

const JEWELRY := preload("res://scenes/items/data/jewelry.tres")
const JEWELS := preload("res://scenes/items/data/jewels.tres")
const CASH := preload("res://scenes/items/data/cash_wad.tres")
const TV := preload("res://scenes/items/data/tv_set.tres")
const ART := preload("res://scenes/items/data/painting.tres")
const PC := preload("res://scenes/items/data/computer.tres")
const KEY := preload("res://scenes/items/data/keycard.tres")

@export var key_id := "apt_a"
@export var resident := true
@export var hidden_key := ""


func _ready() -> void:
	_box(Vector3(0.0, 0.05, 0.0), Vector3(8.0, 0.1, 7.0), Color(0.18, 0.16, 0.15))
	_box(Vector3(0.0, 2.7, 0.0), Vector3(8.0, 0.12, 7.0), Color(0.12, 0.11, 0.13))
	_box(Vector3(0.0, 1.4, -3.4), Vector3(8.0, 2.6, 0.2), Color(0.28, 0.22, 0.26))
	_box(Vector3(-3.9, 1.4, 0.0), Vector3(0.2, 2.6, 7.0), Color(0.24, 0.2, 0.22))
	_box(Vector3(3.9, 1.4, 0.0), Vector3(0.2, 2.6, 7.0), Color(0.24, 0.2, 0.22))
	# Lücke 1,4 m, Türblatt 1,1 m, damit das Blatt die Wandenden nicht schneidet.
	_box(Vector3(-2.25, 1.4, 3.4), Vector3(3.1, 2.6, 0.2), Color(0.28, 0.22, 0.26))
	_box(Vector3(2.25, 1.4, 3.4), Vector3(3.1, 2.6, 0.2), Color(0.28, 0.22, 0.26))
	var door := LockedDoor.new()
	door.name = "Door"
	door.key_id = key_id
	door.position = Vector3(0.0, 0.0, 3.4)
	add_child(door)
	_loot("Schmuck", JEWELRY, Vector3(-2.4, 0.8, -2.2), false)
	_loot("Juwelen", JEWELS, Vector3(-1.2, 0.8, -2.2), true)
	_loot("Bargeld", CASH, Vector3(2.0, 0.5, -1.0), false)
	_loot("Fernseher", TV, Vector3(2.6, 0.6, -2.4), false)
	_loot("Bild", ART, Vector3(-3.2, 1.4, 0.4), false)
	_loot("Computer", PC, Vector3(1.4, 0.75, 1.2), false)
	if not hidden_key.is_empty():
		var key := KEY.duplicate() as ItemData
		key.id = hidden_key
		var stash := LootProp.new()
		stash.name = "SpareKey"
		stash.item = key
		stash.prompt_name = "Schlüsselkarte"
		stash.position = Vector3(2.8, 0.4, 1.6)
		add_child(stash)
	if resident:
		var person := Civilian.new()
		person.name = "Resident"
		person.stay_put = true
		person.position = Vector3(0.2, 0.12, -0.4)
		add_child(person)
	var sign := Label3D.new()
	sign.text = "WOHNUNG"
	sign.position = Vector3(0.0, 2.5, 3.7)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.modulate = Color(0.4, 0.9, 1.0)
	add_child(sign)


func _loot(title: String, item: ItemData, at: Vector3, sealed: bool) -> void:
	var prop := LootProp.new()
	prop.prompt_name = title
	prop.item = item
	prop.sealed = sealed
	prop.position = at
	add_child(prop)


func _box(at: Vector3, size: Vector3, color: Color) -> void:
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
	mat.roughness = 0.85
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
