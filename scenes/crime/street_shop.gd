class_name StreetShop
extends Node3D
## Waffenladen oder Tankstelle, zur Laufzeit auf die Map gesetzt.
##
## Waffen liegen nicht lose herum: die Theke verkauft sie gegen Credchips.
## Die Hintertür ist zu und geht mit Schlüssel oder Brechstange auf.

const PISTOL := preload("res://scenes/items/data/pistol.tres")
const M4 := preload("res://scenes/items/data/m4.tres")
const AK := preload("res://scenes/items/data/ak47.tres")
const CROWBAR := preload("res://scenes/items/data/crowbar.tres")
const CUFFS := preload("res://scenes/items/data/handcuffs.tres")
const TIES := preload("res://scenes/items/data/zipties.tres")
const CRED := preload("res://scenes/items/data/credchip.tres")
const WATER := preload("res://scenes/items/data/water_bottle.tres")
const BAR := preload("res://scenes/items/data/soy_bar.tres")
const CASH := preload("res://scenes/items/data/cash_wad.tres")
const KEY := preload("res://scenes/items/data/keycard.tres")

enum Kind { GUNS, GAS }

@export var kind: Kind = Kind.GUNS
@export var shop_key := ""


func _ready() -> void:
	if kind == Kind.GAS:
		_build_gas()
	else:
		_build_guns()


func _build_guns() -> void:
	_shell(Vector3(7.0, 3.0, 6.0), "WAFFEN")
	_sale(PISTOL, 40, Vector3(-1.2, 0.9, 0.2))
	_sale(M4, 120, Vector3(0.0, 0.9, 0.2))
	_sale(AK, 110, Vector3(1.2, 0.9, 0.2))
	_sale(CROWBAR, 15, Vector3(-1.2, 0.9, 1.0))
	_sale(CUFFS, 8, Vector3(0.0, 0.9, 1.0))
	_sale(TIES, 4, Vector3(1.2, 0.9, 1.0))
	var door := LockedDoor.new()
	door.name = "BackDoor"
	door.key_id = shop_key if not shop_key.is_empty() else "gun_back"
	door.position = Vector3(0.0, 0.0, -2.4)
	add_child(door)
	var stash := LootProp.new()
	stash.prompt_name = "Kasse"
	stash.item = CASH
	stash.count = 3
	stash.sealed = true
	stash.position = Vector3(2.2, 0.9, 0.6)
	add_child(stash)


func _build_gas() -> void:
	_canopy()
	_pump(Vector3(-2.2, 0.0, 1.4))
	_pump(Vector3(2.2, 0.0, 1.4))
	_shell(Vector3(5.0, 3.0, 4.0), "TANKE")
	var drinks := _machine(WATER, 2, Vector3(-1.4, 0.0, 3.2))
	drinks.consume_now = true
	var snacks := _machine(BAR, 2, Vector3(1.4, 0.0, 3.2))
	snacks.consume_now = true
	var stash := LootProp.new()
	stash.prompt_name = "Kasse"
	stash.item = CASH
	stash.count = 2
	stash.sealed = true
	stash.position = Vector3(0.4, 0.9, -0.4)
	add_child(stash)
	if not shop_key.is_empty():
		var card := KEY.duplicate() as ItemData
		card.id = shop_key
		card.display_name = "Schlüsselkarte"
		var prop := LootProp.new()
		prop.prompt_name = "Schlüsselkarte"
		prop.item = card
		prop.position = Vector3(-1.4, 0.9, -0.6)
		add_child(prop)


func _shell(size: Vector3, title: String) -> void:
	_solid(Vector3(0.0, 0.05, 0.0), Vector3(size.x, 0.1, size.z), Color(0.15, 0.15, 0.16))
	_solid(Vector3(0.0, size.y - 0.1, 0.0), Vector3(size.x, 0.12, size.z), Color(0.1, 0.1, 0.12))
	var hx := size.x * 0.5 - 0.1
	var hz := size.z * 0.5 - 0.1
	_solid(Vector3(-hx, size.y * 0.5, 0.0), Vector3(0.16, size.y, size.z), Color(0.2, 0.16, 0.18))
	_solid(Vector3(hx, size.y * 0.5, 0.0), Vector3(0.16, size.y, size.z), Color(0.2, 0.16, 0.18))
	_solid(Vector3(0.0, size.y * 0.5, -hz), Vector3(size.x, size.y, 0.16), Color(0.2, 0.16, 0.18))
	var sign := Label3D.new()
	sign.text = title
	sign.position = Vector3(0.0, size.y - 0.4, hz + 0.2)
	sign.font_size = 56
	sign.pixel_size = 0.012
	sign.modulate = Color(1.0, 0.45, 0.15)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)


func _canopy() -> void:
	_solid(Vector3(0.0, 3.4, 4.5), Vector3(8.0, 0.12, 5.0), Color(0.85, 0.15, 0.2))
	_solid(Vector3(-3.6, 1.7, 2.4), Vector3(0.2, 3.4, 0.2), Color(0.3, 0.3, 0.32))
	_solid(Vector3(3.6, 1.7, 6.4), Vector3(0.2, 3.4, 0.2), Color(0.3, 0.3, 0.32))


func _pump(at: Vector3) -> void:
	_solid(at + Vector3(0.0, 0.7, 0.0), Vector3(0.5, 1.4, 0.35), Color(0.1, 0.35, 0.55))


func _solid(at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 1
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
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)


func _sale(item: ItemData, price: int, at: Vector3) -> void:
	var counter := SaleCounter.new()
	counter.item = item
	counter.price = price
	counter.currency = CRED
	counter.position = at
	add_child(counter)


func _machine(product: ItemData, price: int, at: Vector3) -> VendingMachine:
	var machine := VendingMachine.new()
	machine.product = product
	machine.price = price
	machine.currency = CRED
	machine.position = at
	add_child(machine)
	return machine


class SaleCounter extends StaticBody3D:
	var item: ItemData
	var price := 1
	var currency: ItemData

	func _ready() -> void:
		collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, 0.25, 0.35)
		shape.shape = box
		shape.position = Vector3(0.0, 0.12, 0.0)
		add_child(shape)
		if item != null and ConsumableModel.has_model(item.model):
			var model := ConsumableModel.build(item.model, item.color, false)
			model.position = Vector3(0.0, 0.3, 0.0)
			add_child(model)
		elif item is WeaponData and (item as WeaponData).view_scene != null:
			var view := (item as WeaponData).view_scene.instantiate()
			view.position = Vector3(0.0, 0.28, 0.0)
			view.scale = Vector3.ONE * 0.45
			add_child(view)
		else:
			var mesh := MeshInstance3D.new()
			var cube := BoxMesh.new()
			cube.size = Vector3(0.4, 0.12, 0.16)
			mesh.mesh = cube
			mesh.position = Vector3(0.0, 0.2, 0.0)
			add_child(mesh)

	func get_interact_text(_player: Player) -> String:
		if item == null:
			return ""
		return "%s kaufen (%d ¢)" % [item.display_name, price]

	func interact(player: Player) -> void:
		if item == null:
			return
		if player.inventory.money < price:
			player.item_user.show_message("Zu wenig Credchips", Color(1.0, 0.2, 0.35))
			return
		var left := player.inventory.add_item(item, 1)
		if left > 0:
			player.item_user.show_message("Inventar voll", Color(1.0, 0.2, 0.35))
			return
		player.inventory.spend_money(price)
		player.item_user.show_message("%s gekauft" % item.display_name, Color(0.4, 1.0, 0.7))
