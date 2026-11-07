extends StaticBody3D
## Wasserhahn mit Becken: E füllt die gewählte Gießkanne auf 5 Liter (leer oder angebrochen).
## Steht neben dem Growbedarf-Regal an jeder Tankstelle. Front nach +Z.

const Models := preload("res://scenes/grow/grow_models.gd")
const ITEM := "res://scenes/items/data/%s.tres"
const CAN := "watering_can"
const CAN_EMPTY := "watering_can_empty"


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_child(Models.tap())
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.42, 1.0, 0.36)
	shape.shape = box
	shape.position = Vector3(0, 0.5, 0.08)
	add_child(shape)


func _can(player: Player) -> ItemData:
	if player == null or player.inventory == null:
		return null
	var item := player.inventory.get_selected_item()
	return item if item != null and (item.id == CAN or item.id == CAN_EMPTY) else null


func get_interact_text(player: Player) -> String:
	var can := _can(player)
	if can == null:
		return "Wasserhahn – Gießkanne wählen"
	var liters := 0 if can.id == CAN_EMPTY else player.inventory.get_count(player.inventory.selected)
	if liters >= _full().max_stack:
		return "Gießkanne ist voll"
	return "Gießkanne füllen (%d / %d l)" % [liters, _full().max_stack]


func interact(player: Player) -> void:
	var can := _can(player)
	if can == null:
		return
	var inv := player.inventory
	var slot: int = inv.selected
	var full := _full()
	if can.id == CAN_EMPTY:
		inv.remove_at(slot, 1)
		inv.add_at(slot, full, full.max_stack)
	else:
		var missing := full.max_stack - inv.get_count(slot)
		if missing <= 0:
			player.item_user.show_message("Gießkanne ist schon voll", Color(1.0, 0.5, 0.3))
			return
		inv.add_at(slot, full, missing)
	player.item_user.show_message("Gießkanne gefüllt (%d l)" % full.max_stack, Color(0.4, 0.8, 1.0))


func _full() -> ItemData:
	return load(ITEM % CAN) as ItemData
