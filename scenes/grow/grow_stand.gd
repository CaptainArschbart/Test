extends StaticBody3D
## Regal „GROWBEDARF“ an jeder Tankstelle: alles für den Anbau zum Kaufen (Samen, Erde, Dünger,
## Topf, Growlampe, Trockengestell, Fermentierglas, Verpackungstisch, leere Tütchen und Gläser).
## Jeder Platz ist ein StreetShop.SaleCounter (E kauft, Packungen geben mehrere Stück).
## Regal 2 m breit (lokal x), 0,45 m tief, Front nach +Z.

const SHOP := preload("res://scenes/crime/street_shop.gd")
const Models := preload("res://scenes/grow/grow_models.gd")
const PLACEABLE := preload("res://scenes/grow/placeable_data.gd")
const ITEM := "res://scenes/items/data/%s.tres"
## [Item, Preis, Stück je Kauf], von oben nach unten, links nach rechts.
const STOCK := [
	["cannabis_seed", 75, 3], ["fertilizer", 18, 1], ["potting_soil", 12, 1], ["baggie_empty", 20, 20],
	["jar_empty", 25, 5], ["curing_jar", 35, 1], ["grow_pot", 40, 1],
	["grow_lamp", 250, 1], ["drying_rack", 80, 1], ["packing_table", 120, 1],
]
const BOARDS := [1.35, 0.9, 0.45]
const SLOTS := [[-0.63, -0.21, 0.21, 0.63], [-0.42, 0.0, 0.42], [-0.42, 0.0, 0.42]]


func _ready() -> void:
	collision_layer = 1
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.2, 0.18)
	var back := _box(Vector3(2.0, 1.8, 0.04), Vector3(0, 0.9, -0.2), wood)
	add_child(back)
	for y: float in BOARDS:
		add_child(_box(Vector3(2.0, 0.03, 0.42), Vector3(0, y - 0.03, 0.0), wood))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.8, 0.1)
	shape.shape = box
	shape.position = Vector3(0, 0.9, -0.2)
	add_child(shape)
	var sign := Label3D.new()
	sign.text = "GROWBEDARF"
	sign.font_size = 64
	sign.pixel_size = 0.004
	sign.outline_size = 10
	sign.modulate = Color(0.4, 1.0, 0.5)
	sign.position = Vector3(0, 1.95, -0.15)
	add_child(sign)
	var i := 0
	for row in BOARDS.size():
		for x: float in SLOTS[row]:
			if i >= STOCK.size():
				break
			var entry: Array = STOCK[i]
			i += 1
			var counter: StaticBody3D = SHOP.SaleCounter.new()
			counter.set("item", load(ITEM % entry[0]))
			counter.set("price", entry[1])
			counter.set("count", entry[2])
			counter.position = Vector3(x, BOARDS[row], 0.02)
			add_child(counter)
			_dress(counter, counter.get("item"))


## Stationen als verkleinertes Modell statt Platzhalter-Würfel.
func _dress(counter: Node3D, item: ItemData) -> void:
	if item == null or item.get_script() != PLACEABLE:
		return
	for child in counter.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	var model := Models.station(item.get("station"))
	var size := Models.footprint(item.get("station"))
	var scale := minf(0.3 / maxf(size.x, size.z), 0.38 / size.y)
	model.scale = Vector3.ONE * scale
	counter.add_child(model)


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	return mi
