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
const CASH := preload("res://scenes/items/data/cash_wad.tres")
const SNIPER := preload("res://scenes/items/data/sniper.tres")
const SMG := preload("res://scenes/items/data/smg.tres")
# Neue Waffen an den Lochwänden (Schedule 1, P4-2). Abgesägte und Bullpup gibt es nur als Beute.
const REVOLVER := preload("res://scenes/items/data/revolver.tres")
const HEAVY_PISTOL := preload("res://scenes/items/data/heavy_pistol.tres")
const PUMP := preload("res://scenes/items/data/pump_shotgun.tres")
const COMPACT_SMG := preload("res://scenes/items/data/compact_smg.tres")
const DMR := preload("res://scenes/items/data/dmr.tres")
## Das Präzisionsgewehr verkauft der Laden erst ab dieser Spielerstufe.
const DMR_LEVEL := 5
const BANK := preload("res://scenes/interact/bank_terminal.gd")
const SELL_PAD := preload("res://scenes/crime/loot_sell_pad.gd")
const GAS_STATION := preload("res://scenes/crime/gas_station.gd")
const KENNEY := "res://assets/props/kenney_furniture/%s.glb"
const QUATERNIUS := "res://assets/props/quaternius_furniture/%s.fbx"

enum Kind { GUNS, GAS }

@export var kind: Kind = Kind.GUNS
@export var shop_key := ""
## Verstöße gegen die Placement-Regeln im Innenraum (InteriorPlanner), leer = in Ordnung.
var layout_errors := PackedStringArray()
var _plan: InteriorPlanner


func _ready() -> void:
	if kind == Kind.GAS:
		_build_gas()
	else:
		_build_guns()


func _build_guns() -> void:
	# Grundriss-Prüfung (Schedule 1, P0-2): Raum 8 × 7 m, Eingang vorn (+Z), Lager hinter der Trennwand.
	_plan = InteriorPlanner.new(Rect2(-4.0, -3.5, 8.0, 7.0))
	_room(Vector3(8.0, 3.2, 7.0))
	_front_opening()
	_partition()
	# Theke 1 m tief: vorn Platz für Handelspunkt und Ankauf, hinten die Vitrine.
	_counter(Vector3(0.0, 0.45, 1.3), Vector3(3.8, 0.9, 1.0))
	_glass_case(Vector3(0.0, 1.075, 1.15), Vector3(2.8, 0.35, 0.45))
	_plan.on_top(Vector2(0.0, 1.15), 0.9, "Vitrine")
	_sale(PISTOL, 40, Vector3(-1.2, 1.05, 1.05))
	_sale(SMG, 80, Vector3(-0.4, 1.05, 1.05))
	_sale(M4, 120, Vector3(0.4, 1.05, 1.2))
	_sale(AK, 110, Vector3(1.2, 1.05, 1.2))
	_sale(SNIPER, 200, Vector3(-1.2, 1.05, 1.35))
	_sale(CROWBAR, 15, Vector3(1.2, 1.05, 1.4))
	_ammo_stack(Vector3(0.2, 0.95, 1.3))
	_pegboard(Vector3(-3.55, 1.6, 0.4))
	_pegboard(Vector3(3.55, 1.6, 0.4))
	# Lochwände: links Pumpgun und Pistolen, rechts Präzisionsgewehr und Kompakt-MP (kaufbar).
	_wall_sale(PUMP, 140, Vector3(-3.55, 1.95, 0.4), -1)
	_wall_sale(REVOLVER, 90, Vector3(-3.55, 1.5, 0.0), -1)
	_wall_sale(HEAVY_PISTOL, 65, Vector3(-3.55, 1.5, 0.8), -1)
	_wall_sale(DMR, 260, Vector3(3.55, 1.95, 0.4), 1, DMR_LEVEL)
	_wall_sale(COMPACT_SMG, 85, Vector3(3.55, 1.45, 0.4), 1)
	var door := LockedDoor.new()
	door.name = "BackDoor"
	door.unique_name_in_owner = true
	door.key_id = shop_key if not shop_key.is_empty() else "gun_back"
	door.position = Vector3(-1.4, 0.0, -0.7)
	add_child(door)
	door.owner = self
	# Die Tür schwenkt in den Laden; beidseits bleibt Platz.
	_plan.keep(Rect2(-1.95, -0.64, 1.1, 1.0), "Schwenkbereich Hintertür")
	_plan.keep(Rect2(-1.95, -1.7, 1.1, 0.94), "Platz hinter der Hintertür")
	var register := LootProp.new()
	register.name = "Register"
	register.prompt_name = "Kasse"
	register.item = CASH
	register.count = 4
	register.sealed = true
	register.position = Vector3(1.65, 0.9, 1.05)
	add_child(register)
	_plan.on_top(Vector2(1.65, 1.05), 0.9, "Kasse")
	var shelf := LootProp.new()
	shelf.name = "ArmoryCrate"
	shelf.prompt_name = "Waffenkiste"
	shelf.item = SNIPER
	shelf.sealed = true
	shelf.position = Vector3(-2.4, 0.55, -2.3)
	add_child(shelf)
	_plan.keep(Rect2(-2.8, -2.0, 0.8, 0.6), "Platz vor der Waffenkiste")
	_furnish_guns()
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
	_plan.solid(InteriorPlanner.footprint(Vector2(3.15, 1.7), Vector2(0.9, 0.6), -90.0), "Geldautomat", 2.1)
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
	clerk.position = Vector3(0.9, 0.99, 1.58)
	add_child(clerk)
	clerk.owner = self
	var sell := SELL_PAD.new() as Node3D
	sell.name = "SellPad"
	sell.unique_name_in_owner = true
	sell.position = Vector3(-0.8, 0.9, 1.58)
	add_child(sell)
	sell.owner = self
	_plan.on_top(Vector2(0.9, 1.58), 0.9, "Handelspunkt")
	_plan.on_top(Vector2(-0.8, 1.58), 0.9, "Ankauf")
	_plan.keep(Rect2(-1.9, 1.8, 3.8, 0.8), "Platz vor der Theke")
	_plan.keep(Rect2(-1.0, 0.1, 2.0, 0.65), "Platz des Verkäufers")
	_plan.check_reachable(Vector2(0.0, 3.3), {"Theke": Vector2(0.0, 2.3), "Geldautomat": Vector2(2.35, 1.7),
			"Verkäufer": Vector2(0.15, 0.35), "Hintertür": Vector2(-1.4, -0.3), "Waffenkiste": Vector2(-2.4, -1.75)})
	_report_layout()


## Verstöße des Grundrisses melden (Test liest layout_errors, im Editor stehen sie im Fehlerlog).
func _report_layout() -> void:
	layout_errors = _plan.errors
	for e in layout_errors:
		push_error("%s %s: %s" % [name, Kind.keys()[kind], e])


func _room(size: Vector3) -> void:
	_solid(Vector3(0.0, 0.05, 0.0), Vector3(size.x, 0.1, size.z), Color(0.12, 0.11, 0.13))
	_solid(Vector3(0.0, size.y - 0.08, 0.0), Vector3(size.x, 0.1, size.z), Color(0.08, 0.08, 0.1))
	var hx := size.x * 0.5 - 0.08
	var hz := size.z * 0.5 - 0.08
	_wall(Vector3(-hx, size.y * 0.5, 0.0), Vector3(0.16, size.y, size.z), Color(0.16, 0.12, 0.14), "Wand links")
	_wall(Vector3(hx, size.y * 0.5, 0.0), Vector3(0.16, size.y, size.z), Color(0.16, 0.12, 0.14), "Wand rechts")
	_wall(Vector3(0.0, size.y * 0.5, -hz), Vector3(size.x, size.y, 0.16), Color(0.16, 0.12, 0.14), "Rückwand")


## Wand: wie _solid, zusätzlich im Grundriss gemeldet.
func _wall(at: Vector3, size: Vector3, color: Color, what: String) -> void:
	_solid(at, size, color)
	if _plan != null:
		_plan.wall(InteriorPlanner.footprint(Vector2(at.x, at.z), Vector2(size.x, size.z)), what)


func _front_opening() -> void:
	_wall(Vector3(-2.7, 1.6, 3.42), Vector3(2.4, 3.2, 0.16), Color(0.22, 0.1, 0.12), "Front links")
	_wall(Vector3(2.7, 1.6, 3.42), Vector3(2.4, 3.2, 0.16), Color(0.22, 0.1, 0.12), "Front rechts")


func _partition() -> void:
	_wall(Vector3(-2.9, 1.6, -0.7), Vector3(1.8, 3.2, 0.12), Color(0.2, 0.14, 0.16), "Trennwand links")
	_wall(Vector3(1.5, 1.6, -0.7), Vector3(4.6, 3.2, 0.12), Color(0.2, 0.14, 0.16), "Trennwand rechts")


func _counter(at: Vector3, size: Vector3) -> void:
	_solid(at, size, Color(0.18, 0.14, 0.1))
	if _plan != null:
		_plan.solid(InteriorPlanner.footprint(Vector2(at.x, at.z), Vector2(size.x, size.z)), "Theke", at.y + size.y * 0.5)


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


## Kaufbare Waffe an der Lochwand. `at` = Mitte der Wand dort (x der Wand), `wall` −1 = linke Wand
## (Raum bei +X), +1 = rechte. Die Waffe liegt flach an der Wand, Lauf entlang Z, Seite zum Raum.
func _wall_sale(item: WeaponData, price: int, at: Vector3, wall: int, min_level := 0) -> void:
	var sale := WallSale.new()
	sale.item = item
	sale.price = price
	sale.currency = CRED
	sale.min_level = min_level
	sale.name = "Wall_" + item.id
	# Vor der Plattenfläche (Platte 6 cm dick) mit 3 cm Abstand.
	sale.position = Vector3(at.x - wall * (0.03 + WallSale.DEPTH * 0.5), at.y, at.z)
	sale.rotation.y = 0.0 if wall < 0 else PI
	add_child(sale)


## Möbel aus den Packs (assets/props/kenney_furniture, quaternius_furniture). Alles steht an Wänden
## oder in Ecken: Laufweg Eingang–Theke, Hintertür (x −2…−0,8) und Waffenkiste bleiben frei.
func _furnish_guns() -> void:
	# Kundenbereich: Teppich, Pflanze in der freien Ecke (rechts steht der Automat).
	_decor(KENNEY % "rugRectangle", Vector3(0.0, 0.1, 2.5), 90.0, 2.6, 0.0, false)
	_decor(KENNEY % "pottedPlant", Vector3(-3.35, 0.1, 3.0), 0.0, 0.0, 1.3, true)
	_decor(QUATERNIUS % "Trashcan_Small1", Vector3(-3.4, 0.1, 1.9), 0.0, 0.0, 0.55, true)
	# Hinter der Theke: Regale an der Trennwand, Blick zum Laden.
	_decor(QUATERNIUS % "Shelf_Large", Vector3(1.9, 0.1, -0.42), 90.0, 1.6, 0.0, true)
	_decor(KENNEY % "bookcaseClosedWide", Vector3(-2.9, 0.1, -0.41), 90.0, 1.5, 0.0, true)
	_decor(KENNEY % "cardboardBoxClosed", Vector3(0.9, 0.1, -0.35), 0.0, 0.0, 0.45, true)
	# Lampen unter der Decke über den Leuchtbalken.
	for x: float in [-1.8, 1.8]:
		_decor(QUATERNIUS % "Light_Ceiling2", Vector3(x, 2.55, 2.3), 0.0, 0.0, 0.55, false, true)
	# Lager: Schreibtisch mit Stuhl, Monitor und Lampe, Kartons in der Ecke.
	_decor(KENNEY % "desk", Vector3(1.6, 0.1, -2.6), 90.0, 1.5, 0.0, true)
	_decor(KENNEY % "chairDesk", Vector3(1.6, 0.1, -1.7), 180.0, 0.0, 1.0, true)
	_decor(KENNEY % "computerScreen", Vector3(1.4, 0.88, -2.75), 180.0, 0.0, 0.42, false)
	_decor(QUATERNIUS % "Light_Desk", Vector3(2.1, 0.88, -2.75), 0.0, 0.0, 0.4, false)
	for k in 3:
		_decor(KENNEY % "cardboardBoxClosed", Vector3(-3.35, 0.1 + k * 0.42, -3.05), k * 25.0, 0.0, 0.42, k == 0)
	_decor(KENNEY % "cardboardBoxOpen", Vector3(-3.3, 0.1, -2.35), 15.0, 0.0, 0.4, true)


func _decor(path: String, at: Vector3, yaw_deg: float, fit_length: float, fit_height: float, collide: bool,
		ceiling := false) -> void:
	var prop := NeonProp.new()
	prop.model = path
	prop.fit_length = fit_length
	prop.fit_height = fit_height if fit_height > 0.0 else 1.0
	prop.collide = collide
	prop.visible_range = 0.0
	prop.position = at
	prop.rotation.y = deg_to_rad(yaw_deg)
	add_child(prop)
	if _plan == null or ceiling:
		return
	# Grundfläche aus der Hülle des Modells, wie NeonProp sie beim Laden misst und skaliert.
	var what := path.get_file().get_basename()
	var holder := prop.get_node_or_null("Model") as Node3D
	var size := Vector3.ZERO
	if holder != null and holder.get_child_count() > 0:
		var box := NeonProp._bounds(holder.get_child(0) as Node3D)
		size = (Basis(Vector3.UP, holder.rotation.y) * (box.size * holder.scale.x)).abs()
	var rect := InteriorPlanner.footprint(Vector2(at.x, at.z), Vector2(size.x, size.z), yaw_deg)
	if collide:
		_plan.solid(rect, what, at.y + size.y)
	else:
		_plan.on_top(Vector2(at.x, at.z), at.y, what)
		_plan.support(rect, at.y + size.y, what)


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
	var station := GAS_STATION.new() as Node3D
	station.name = "Station"
	station.set("shop_key", shop_key)
	add_child(station)


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


## Waffe zum Kaufen an der Wand (gleiche Kaufregeln wie SaleCounter, optional ab Spielerstufe).
## Das Modell liegt in Originalgröße flach an, die Kollisionsbox deckt es ab.
class WallSale extends SaleCounter:
	const DEPTH := 0.08
	const SCALE := 0.85
	var min_level := 0

	func _ready() -> void:
		collision_layer = 1
		var weapon := item as WeaponData
		var length := 0.3
		if weapon != null and weapon.view_scene != null:
			var view: Node3D = weapon.view_scene.instantiate()
			view.scale = Vector3.ONE * SCALE
			var muzzle := view.get_node_or_null("Muzzle") as Node3D
			var front := muzzle.position.z * SCALE if muzzle != null else -0.25
			length = absf(front) + 0.12
			# Mitte der Waffe auf die Mitte des Platzes.
			view.position = Vector3(0.0, 0.0, -front * 0.5 + 0.03)
			add_child(view)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(DEPTH, 0.22, length)
		shape.shape = box
		add_child(shape)

	func get_interact_text(player: Player) -> String:
		var text := super.get_interact_text(player)
		if min_level > 0 and _level(player) < min_level:
			text += " – ab Stufe %d" % min_level
		return text

	func interact(player: Player) -> void:
		if min_level > 0 and _level(player) < min_level:
			player.item_user.show_message("Erst ab Stufe %d" % min_level, Color(1.0, 0.75, 0.3))
			return
		super.interact(player)

	func _level(player: Player) -> int:
		return player.xp.level if player.xp != null else 1


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
