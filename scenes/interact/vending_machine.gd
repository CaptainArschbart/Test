class_name VendingMachine
extends StaticBody3D
## Automat in der Welt. Mit "interact" (E) kauft der Spieler für `price` Credchips ein `product`.
##
## Liegt auf Layer world (Kollision und Strahl). Gehäuse, Leuchtfront und Schild
## entstehen im Code, damit die Karte nur einen Knoten braucht. Der Ursprung ist
## die Mitte der Grundfläche, die Front zeigt nach +Z.

@export var product: ItemData
@export var price := 1
@export var currency: ItemData
@export var size := Vector3(1.0, 2.0, 0.8)


func _ready() -> void:
	collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3.UP * size.y * 0.5
	add_child(shape)
	_build_visual()


func get_interact_text(_player: Player) -> String:
	if product == null:
		return ""
	if price <= 0 or currency == null:
		return "%s ziehen" % product.display_name
	return "%s kaufen (%d %s)" % [product.display_name, price, currency.display_name]


func interact(player: Player) -> void:
	if product == null:
		return
	var inventory := player.inventory
	if price > 0 and currency != null:
		if count_of(inventory, currency) < price:
			player.item_user.show_message("Zu wenig %s" % currency.display_name, Color(1.0, 0.2, 0.35))
			return
		_take(inventory, currency, price)
	var left := inventory.add_item(product, 1)
	if left > 0:
		# Kein Platz: Geld zurück.
		if price > 0 and currency != null:
			inventory.add_item(currency, price, false)
		player.item_user.show_message("Inventar voll", Color(1.0, 0.2, 0.35))


## Wie viele Stück eines Items im ganzen Inventar liegen.
static func count_of(inventory: Inventory, item: ItemData) -> int:
	var total := 0
	for i in inventory.get_size():
		if item.is_same(inventory.get_item(i)):
			total += inventory.get_count(i)
	return total


func _take(inventory: Inventory, item: ItemData, amount: int) -> void:
	for i in inventory.get_size():
		if amount <= 0:
			return
		if item.is_same(inventory.get_item(i)):
			amount -= inventory.remove_at(i, amount)


func _build_visual() -> void:
	var color := product.color if product != null else Color(0.0, 0.95, 1.0)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = size
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.08, 0.07, 0.12)
	body_material.metallic = 0.6
	body_material.roughness = 0.35
	body_mesh.material = body_material
	body.mesh = body_mesh
	body.position = Vector3.UP * size.y * 0.5
	add_child(body)
	var front := MeshInstance3D.new()
	var front_mesh := QuadMesh.new()
	front_mesh.size = Vector2(size.x * 0.75, size.y * 0.55)
	var front_material := StandardMaterial3D.new()
	front_material.albedo_color = color
	front_material.emission_enabled = true
	front_material.emission = color
	front_material.emission_energy_multiplier = 1.6
	front_mesh.material = front_material
	front.mesh = front_mesh
	front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	front.position = Vector3(0.0, size.y * 0.62, size.z * 0.5 + 0.01)
	add_child(front)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 3.0
	light.position = Vector3(0.0, size.y * 0.62, size.z * 0.5 + 0.4)
	add_child(light)
	var sign_label := Label3D.new()
	sign_label.text = product.display_name.to_upper() if product != null else "AUTOMAT"
	sign_label.font_size = 32
	sign_label.pixel_size = 0.004
	sign_label.outline_size = 10
	sign_label.modulate = color
	sign_label.position = Vector3(0.0, size.y + 0.15, size.z * 0.5)
	add_child(sign_label)
