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
const SNIPER := preload("res://scenes/items/data/sniper.tres")
const SMG := preload("res://scenes/items/data/smg.tres")
const BANK := preload("res://scenes/interact/bank_terminal.gd")
const SELL_PAD := preload("res://scenes/crime/loot_sell_pad.gd")

enum Kind { GUNS, GAS }

@export var kind: Kind = Kind.GUNS
@export var shop_key := ""


func _ready() -> void:
	if kind == Kind.GAS:
		_build_gas()
	else:
		_build_guns()


func _build_guns() -> void:
	_room(Vector3(8.0, 3.2, 7.0))
	_front_opening()
	_partition()
	_counter(Vector3(0.0, 0.45, 1.15), Vector3(3.4, 0.9, 0.7))
	_glass_case(Vector3(0.0, 1.05, 1.15), Vector3(3.0, 0.35, 0.45))
	_sale(PISTOL, 40, Vector3(-1.2, 1.05, 1.05))
	_sale(SMG, 80, Vector3(-0.4, 1.05, 1.05))
	_sale(M4, 120, Vector3(0.4, 1.05, 1.2))
	_sale(AK, 110, Vector3(1.2, 1.05, 1.2))
	_sale(SNIPER, 200, Vector3(-1.2, 1.05, 1.35))
	_sale(CROWBAR, 15, Vector3(1.2, 1.05, 1.4))
	_ammo_stack(Vector3(0.2, 1.02, 1.35))
	_pegboard(Vector3(-3.55, 1.6, 0.4))
	_pegboard(Vector3(3.55, 1.6, 0.4))
	_rack_weapon(M4, Vector3(-3.55, 1.7, 0.9), 90.0)
	_rack_weapon(AK, Vector3(-3.55, 1.35, -0.1), 90.0)
	_rack_weapon(SMG, Vector3(3.55, 1.7, 0.9), -90.0)
	_rack_weapon(SNIPER, Vector3(3.55, 1.35, -0.1), -90.0)
	var door := LockedDoor.new()
	door.name = "BackDoor"
	door.unique_name_in_owner = true
	door.key_id = shop_key if not shop_key.is_empty() else "gun_back"
	door.position = Vector3(-1.4, 0.0, -0.7)
	add_child(door)
	door.owner = self
	var register := LootProp.new()
	register.name = "Register"
	register.prompt_name = "Kasse"
	register.item = CASH
	register.count = 4
	register.sealed = true
	register.position = Vector3(1.5, 0.95, 1.0)
	add_child(register)
	var shelf := LootProp.new()
	shelf.name = "ArmoryCrate"
	shelf.prompt_name = "Waffenkiste"
	shelf.item = SNIPER
	shelf.sealed = true
	shelf.position = Vector3(-2.4, 0.55, -2.3)
	add_child(shelf)
	_table(Vector3(1.6, 0.4, -2.15))
	_neon(Vector3(0.0, 2.55, 3.65))
	_ceiling_light(Vector3(0.0, 2.85, 1.3), Color(0.25, 0.85, 1.0), 1.4)
	_ceiling_light(Vector3(0.0, 2.7, -1.9), Color(1.0, 0.25, 0.55), 0.7)
	var atm: StaticBody3D = BANK.new()
	atm.name = "Atm"
	atm.unique_name_in_owner = true
	atm.position = Vector3(3.15, 0.0, 1.7)
	atm.rotation.y = -PI * 0.5
	add_child(atm)
	atm.owner = self
	var keeper := Civilian.new()
	keeper.name = "Shopkeeper"
	keeper.unique_name_in_owner = true
	keeper.stay_put = true
	keeper.position = Vector3(0.15, 0.12, 0.35)
	keeper.rotation.y = PI
	add_child(keeper)
	keeper.owner = self
	keeper.show_line("Waffen?")
	var clerk := GunClerk.new()
	clerk.name = "Clerk"
	clerk.unique_name_in_owner = true
	clerk.position = Vector3(0.9, 0.95, 1.55)
	add_child(clerk)
	clerk.owner = self
	var sell := SELL_PAD.new() as Node3D
	sell.name = "SellPad"
	sell.unique_name_in_owner = true
	sell.position = Vector3(-0.8, 0.95, 1.55)
	add_child(sell)
	sell.owner = self


func _room(size: Vector3) -> void:
	_solid(Vector3(0.0, 0.05, 0.0), Vector3(size.x, 0.1, size.z), Color(0.12, 0.11, 0.13))
	_solid(Vector3(0.0, size.y - 0.08, 0.0), Vector3(size.x, 0.1, size.z), Color(0.08, 0.08, 0.1))
	var hx := size.x * 0.5 - 0.08
	var hz := size.z * 0.5 - 0.08
	_solid(Vector3(-hx, size.y * 0.5, 0.0), Vector3(0.16, size.y, size.z), Color(0.16, 0.12, 0.14))
	_solid(Vector3(hx, size.y * 0.5, 0.0), Vector3(0.16, size.y, size.z), Color(0.16, 0.12, 0.14))
	_solid(Vector3(0.0, size.y * 0.5, -hz), Vector3(size.x, size.y, 0.16), Color(0.16, 0.12, 0.14))


func _front_opening() -> void:
	_solid(Vector3(-2.7, 1.6, 3.42), Vector3(2.4, 3.2, 0.16), Color(0.22, 0.1, 0.12))
	_solid(Vector3(2.7, 1.6, 3.42), Vector3(2.4, 3.2, 0.16), Color(0.22, 0.1, 0.12))


func _partition() -> void:
	_solid(Vector3(-2.9, 1.6, -0.7), Vector3(1.8, 3.2, 0.12), Color(0.2, 0.14, 0.16))
	_solid(Vector3(1.5, 1.6, -0.7), Vector3(4.6, 3.2, 0.12), Color(0.2, 0.14, 0.16))


func _counter(at: Vector3, size: Vector3) -> void:
	_solid(at, size, Color(0.18, 0.14, 0.1))


func _glass_case(at: Vector3, size: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "GlassCase"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.55, 0.9, 1.0, 0.22)
	glass.emission_enabled = true
	glass.emission = Color(0.2, 0.75, 1.0)
	glass.emission_energy_multiplier = 0.55
	glass.roughness = 0.05
	mesh.material_override = glass
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


func _ammo_stack(at: Vector3) -> void:
	for i in 3:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.1, 0.14)
		mesh.mesh = box
		mesh.position = at + Vector3(0.0, float(i) * 0.1, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.32, 0.12)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.35, 0.05)
		mat.emission_energy_multiplier = 0.3
		mesh.material_override = mat
		add_child(mesh)


func _pegboard(at: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 1.3, 1.6)
	mesh.mesh = box
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.09, 0.1)
	mesh.material_override = mat
	add_child(mesh)


func _rack_weapon(item: WeaponData, at: Vector3, yaw_deg: float) -> void:
	if item.view_scene == null:
		return
	var view := item.view_scene.instantiate()
	view.position = at
	view.rotation.y = deg_to_rad(yaw_deg)
	view.scale = Vector3.ONE * 0.55
	add_child(view)


func _table(at: Vector3) -> void:
	_solid(at, Vector3(1.4, 0.75, 0.7), Color(0.25, 0.25, 0.28))


func _neon(at: Vector3) -> void:
	var board := MeshInstance3D.new()
	board.name = "NeonSign"
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 0.45, 0.08)
	board.mesh = box
	board.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.3)
	mat.emission_energy_multiplier = 1.3
	board.material_override = mat
	add_child(board)
	var sign := Label3D.new()
	sign.text = "WAFFEN"
	sign.position = at + Vector3(0.0, 0.0, 0.06)
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.modulate = Color(1.0, 0.85, 0.7)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sign)
	var glow := OmniLight3D.new()
	glow.position = at + Vector3(0.0, -0.2, 0.4)
	glow.light_color = Color(1.0, 0.2, 0.35)
	glow.light_energy = 1.2
	glow.omni_range = 6.0
	glow.shadow_enabled = false
	add_child(glow)


func _ceiling_light(at: Vector3, color: Color, energy: float) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.06, 0.25)
	mesh.mesh = box
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.3
	mesh.material_override = mat
	add_child(mesh)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0.0, -0.15, 0.0)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 7.0
	light.shadow_enabled = false
	add_child(light)


func _build_gas() -> void:
	_canopy()
	# Vor dem offenen Schaufenster, unter dem Vordach, nicht im Verkaufsraum.
	_pump(Vector3(-2.6, 0.0, 4.2))
	_pump(Vector3(2.6, 0.0, 4.2))
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
	var sell := SELL_PAD.new() as Node3D
	sell.name = "SellPad"
	sell.unique_name_in_owner = true
	sell.position = Vector3(0.0, 0.9, 0.8)
	add_child(sell)
	sell.owner = self


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
			var model := ConsumableModel.build(item.model, item.color)
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


class GunClerk extends StaticBody3D:
	const ROUND_PRICE := 2

	func _ready() -> void:
		collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.45, 0.18, 0.28)
		shape.shape = box
		add_child(shape)
		var mesh := MeshInstance3D.new()
		var pad := BoxMesh.new()
		pad.size = box.size
		mesh.mesh = pad
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.9, 0.75)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.6
		mesh.material_override = mat
		add_child(mesh)

	func get_interact_text(player: Player) -> String:
		var payout := _sale_offer(player)
		if payout >= 0:
			var item := player.inventory.get_selected_item()
			return "Verkaufen: %s (%d ¢)" % [item.display_name, payout]
		var cost := _refill_cost(player)
		if cost > 0:
			return "Magazin füllen (%d ¢)" % cost
		return "Handel"

	func interact(player: Player) -> void:
		var payout := _sale_offer(player)
		if payout >= 0:
			player.inventory.remove_at(player.inventory.selected, 1)
			player.inventory.add_money(payout)
			player.item_user.show_message("Verkauft für %d ¢" % payout, Color(0.4, 1.0, 0.7))
			return
		var cost := _refill_cost(player)
		if cost <= 0:
			player.item_user.show_message("Waffe wählen oder Magazin ist voll", Color(1.0, 0.75, 0.3))
			return
		if player.inventory.money < cost:
			player.item_user.show_message("Zu wenig Credchips", Color(1.0, 0.2, 0.35))
			return
		var rounds := player.weapon_holder.refill_magazine()
		if rounds <= 0:
			return
		player.inventory.spend_money(cost)
		player.item_user.show_message("Magazin +%d" % rounds, Color(0.4, 1.0, 0.7))

	func _sale_offer(player: Player) -> int:
		var item := player.inventory.get_selected_item()
		if item == null or not (item is WeaponData or item is MeleeData):
			return -1
		if item.value > 0:
			return maxi(item.value / 2, 1)
		return 8

	func _refill_cost(player: Player) -> int:
		var holder := player.weapon_holder
		if holder == null:
			return 0
		var weapon := holder.get_weapon()
		if weapon == null:
			return 0
		var missing := weapon.magazine_size - holder.get_ammo()
		if missing <= 0:
			return 0
		return missing * ROUND_PRICE
