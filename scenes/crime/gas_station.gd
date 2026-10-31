extends Node3D
## Tankstelle: Verkaufsraum mit echtem Ladenbetrieb, Vordach, vier Zapfsäulen, Vorplatz.
##
## Grundfläche 15×14 m: x −7,5…7,5, z −6…8. Der Laden liegt hinten (z −6…0), die Front zeigt nach +Z.
## Innen läuft alles über ShopInterior (Ladenschild sign_gas): Ware aus Regalen und Kühlschränken,
## Verkäufer, Kasse, Überfall, Alarm, Kamera. Verkaufspult auf der Theke, Tagestresor und
## Schlüsselkarte hinter dem Verkäufer. Getränke-, Snack- und Bankautomat stehen draußen.
## Die Theke steht wie im Mapkit links (−X): ShopInterior lässt den Verkäufer nach +X blicken.
## Kein class_name: StreetShop legt den Knoten per preload an.

const ShopInteriorScript := preload("res://scenes/interact/shop_interior.gd")
const PUMP := preload("res://scenes/crime/gas_pump.gd")
const BANK := preload("res://scenes/interact/bank_terminal.gd")
const SELL_PAD := preload("res://scenes/crime/loot_sell_pad.gd")
const CRED := preload("res://scenes/items/data/credchip.tres")
const WATER := preload("res://scenes/items/data/water_bottle.tres")
const BAR := preload("res://scenes/items/data/soy_bar.tres")
const CASH := preload("res://scenes/items/data/cash_wad.tres")
const KEY := preload("res://scenes/items/data/keycard.tres")

const SHOP_SIGN := "sign_gas"
const WIDTH := 10.0
const DEPTH := 6.0
const HEIGHT := 3.4
const WALL := 0.16
const FLOOR_Y := 0.08
const COURT_Y := 0.06
const DOOR_X := 0.6
const DOOR_W := 1.8
const DOOR_H := 2.4
const ISLAND_X := 2.9
const ISLAND_Z := 5.0
const PUMP_DZ := 1.3
const SENSOR_CHANCE := 0.5
const LIGHT_FADE := 50.0

## Schlüsselkarte, die hier liegt (leer = keine).
var shop_key := ""

var _rng := RandomNumberGenerator.new()
var _metal: StandardMaterial3D
var _dark: StandardMaterial3D
var _wall: StandardMaterial3D
var _trim: StandardMaterial3D
var _white: StandardMaterial3D


func _ready() -> void:
	# Aus der Lage, damit Host und Clients dieselbe Tankstelle bauen.
	_rng.seed = hash(Vector2i(roundi(global_position.x), roundi(global_position.z)))
	_metal = SlumMats.color(Color(0.3, 0.32, 0.33), 0.0, 0.5, 0.5)
	_dark = SlumMats.color(Color(0.06, 0.06, 0.07), 0.0, 0.6, 0.3)
	_wall = SlumMats.surface("plaster", Color(0.6, 0.55, 0.55))
	_trim = SlumMats.color(Color(1.0, 0.42, 0.1), 2.2)
	_white = SlumMats.color(Color(0.92, 0.96, 1.0), 5.0)
	var b := SlumBuilder.new(self)
	_build_court(b)
	_build_shell(b)
	var slots := _build_fittings(b)
	_build_canopy(b)
	_build_yard(b)
	var sensor := _build_sensor(b)
	b.finish()
	_add_shop(slots, sensor)
	_add_pumps()
	_add_car()
	_add_machines()
	_add_loot()
	_add_props()
	_add_signs()


func _build_court(b: SlumBuilder) -> void:
	b.box(Vector3(0.0, COURT_Y * 0.5, 1.0), Vector3(15.0, COURT_Y, 14.0), SlumMats.wet("concrete_dark"))
	var paint := SlumMats.color(Color(0.85, 0.65, 0.12), 0.0, 0.7)
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(s * 6.9, COURT_Y + 0.003, 5.0), Vector3(0.12, 0.006, 5.0), paint, false, false)
	var oil := SlumMats.glass(Color(0.01, 0.01, 0.015, 0.75))
	for i in 7:
		var at := Vector3(_rng.randf_range(-2.0, 2.0), COURT_Y + 0.004, _rng.randf_range(2.8, 7.2))
		b.box(at, Vector3(_rng.randf_range(0.4, 1.1), 0.004, _rng.randf_range(0.3, 0.9)), oil, false, false)


func _build_shell(b: SlumBuilder) -> void:
	var hx := WIDTH * 0.5
	var zc := -DEPTH * 0.5
	b.box(Vector3(0.0, FLOOR_Y - 0.005, zc), Vector3(WIDTH, 0.01, DEPTH), SlumMats.surface("tiles_white"), false, false)
	b.box(Vector3(0.0, HEIGHT - 0.06, zc), Vector3(WIDTH, 0.12, DEPTH), _dark)
	b.box(Vector3(0.0, HEIGHT * 0.5, -DEPTH + WALL * 0.5), Vector3(WIDTH, HEIGHT, WALL), _wall)
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(s * (hx - WALL * 0.5), HEIGHT * 0.5, zc), Vector3(WALL, HEIGHT, DEPTH), _wall)
	# Leuchtband außen um das Dach.
	b.box(Vector3(0.0, HEIGHT + 0.04, zc), Vector3(WIDTH + 0.1, 0.08, DEPTH + 0.1), _trim, false, false)
	# Front: Glas links und rechts der offenen Tür, Sturz darüber.
	var left := DOOR_X - DOOR_W * 0.5
	var right := DOOR_X + DOOR_W * 0.5
	var glass := SlumMats.glass(Color(0.55, 0.85, 1.0, 0.16))
	var glass_top := DOOR_H
	for span: Vector2 in [Vector2(-hx, left), Vector2(right, hx)]:
		var mid := (span.x + span.y) * 0.5
		var length := span.y - span.x
		b.box(Vector3(mid, 0.3, -0.06), Vector3(length, 0.6, 0.12), _dark)
		b.box(Vector3(mid, (0.6 + glass_top) * 0.5, -0.06), Vector3(length, glass_top - 0.6, 0.06), glass, true, false)
		var x := span.x
		while x <= span.y + 0.01:
			b.box(Vector3(x, glass_top * 0.5, -0.06), Vector3(0.07, glass_top, 0.1), _metal, false)
			x += length / 2.0
	b.box(Vector3(0.0, (DOOR_H + HEIGHT) * 0.5, -0.06), Vector3(WIDTH, HEIGHT - DOOR_H, 0.12), _wall)
	_add_light(Vector3(-2.8, HEIGHT - 0.5, -3.0), Color(0.95, 0.97, 1.0), 1.6, 6.5)
	_add_light(Vector3(2.0, HEIGHT - 0.5, -3.0), Color(0.95, 0.97, 1.0), 1.6, 6.5)


## Theke, Vitrine, Regale, Kühlschränke. Gibt die Warenplätze für ShopInterior zurück.
func _build_fittings(b: SlumBuilder) -> Array:
	var ix0 := -WIDTH * 0.5 + WALL
	var ix1 := WIDTH * 0.5 - WALL
	var iz0 := -DEPTH + WALL
	var iz1 := -0.12
	var fl := FLOOR_Y
	var slots: Array = []
	var counter_x := _counter_x()
	var counter_zc := _counter_zc()
	var counter_len := 2.6
	b.box(Vector3(counter_x, fl + 0.5, counter_zc), Vector3(0.6, 1.0, counter_len), SlumMats.color(Color(0.16, 0.13, 0.12), 0.0, 0.6))
	b.box(Vector3(counter_x, fl + 1.03, counter_zc), Vector3(0.7, 0.06, counter_len + 0.04), _metal, false)
	b.box(Vector3(counter_x + 0.31, fl + 0.25, counter_zc), Vector3(0.02, 0.05, counter_len - 0.1), _trim, false, false)
	# Vitrine hinter dem Verkäufer.
	var cab_x := ix0 + 0.25
	b.box(Vector3(cab_x, fl + 0.45, counter_zc), Vector3(0.45, 0.9, counter_len), _dark)
	b.box(Vector3(cab_x, fl + 1.35, counter_zc), Vector3(0.45, 0.9, counter_len), SlumMats.glass(Color(0.6, 0.85, 1.0, 0.18)), false, false)
	b.box(Vector3(cab_x, fl + 1.82, counter_zc), Vector3(0.47, 0.04, counter_len + 0.02), SlumMats.color(Color(1.0, 0.85, 0.6), 4.0), false, false)
	for i in 4:
		var z := counter_zc - counter_len * 0.5 + 0.35 + i * 0.63
		slots.append({"kind": "cabinet", "xf": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cab_x + 0.05, fl + 0.92, z))})
	# Zwei Regalgänge, beidseitig bestückt.
	var aisle_z0 := iz0 + 1.05
	var aisle_z1 := iz1 - 1.7
	var aisle_len := aisle_z1 - aisle_z0
	var aisle_zc := (aisle_z0 + aisle_z1) * 0.5
	for gx: float in [-0.75, 1.75]:
		for n: Vector3 in [Vector3.LEFT, Vector3.RIGHT]:
			slots.append_array(_shelf(b, Vector3(gx + n.x * 0.23, fl, aisle_zc), n, aisle_len, 1.5, "shelf"))
		b.box(Vector3(gx, fl + 1.52, aisle_zc), Vector3(0.95, 0.04, aisle_len + 0.04), _metal, false)
		b.box(Vector3(gx, HEIGHT - 0.2, aisle_zc), Vector3(0.1, 0.05, aisle_len * 0.8), _white, false, false)
	# Wandregal hinten, Kühlschränke rechts.
	var fridge_x := ix1 - 0.35
	slots.append_array(_shelf(b, Vector3(0.5, fl, iz0 + 0.25), Vector3.BACK, 5.0, 2.0, "wall"))
	var fz := iz0 + 0.8
	while fz + 0.6 <= iz1 - 1.3:
		_fridge(b, Vector3(fridge_x, fl, fz))
		for row_y: float in [0.6, 1.2]:
			slots.append({"kind": "fridge", "xf": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(fridge_x - 0.05, fl + row_y, fz))})
		fz += 1.25
	# Schreibtisch und Tresor hinter dem Verkäufer.
	b.box(Vector3(ix0 + 0.55, fl + 0.4, iz0 + 0.5), Vector3(1.0, 0.8, 0.7), _metal)
	b.box(Vector3(ix0 + 0.35, fl + 1.0, iz0 + 0.25), Vector3(0.45, 0.32, 0.03), SlumMats.color(Color(0.2, 1.0, 0.75), 2.0), false, false)
	return slots


func _counter_x() -> float:
	return -WIDTH * 0.5 + WALL + 1.35


func _counter_zc() -> float:
	return -2.6


## Regalseite. `n` = Front, `at` = Mitte der Grundfläche. Echte Ware liegt auf dem dritten Boden.
func _shelf(b: SlumBuilder, at: Vector3, n: Vector3, length: float, height: float, kind: String) -> Array:
	var depth := 0.45
	var xf := SlumBuilder.facing(at, n)
	b.box_x(xf * Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, -depth * 0.5 + 0.02)), Vector3(length, height, 0.04), _metal)
	for s: float in [-1.0, 1.0]:
		b.box_x(xf * Transform3D(Basis.IDENTITY, Vector3(s * (length * 0.5 - 0.02), height * 0.5, 0.0)), Vector3(0.04, height, depth), _metal)
	var boards: Array[float] = [0.1, 0.55, 1.0]
	if height > 1.7:
		boards.append(1.45)
	var goods := [Color(0.85, 0.2, 0.15), Color(0.95, 0.75, 0.15), Color(0.2, 0.55, 0.85), Color(0.25, 0.7, 0.35), Color(0.9, 0.9, 0.85)]
	var slots: Array = []
	var count := maxi(int(length / 1.1), 1)
	for bi: int in boards.size():
		var y := boards[bi]
		b.box_x(xf * Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.0)), Vector3(length, 0.03, depth), _metal)
		if bi == 2:
			for k: int in count:
				var x := -length * 0.5 + (k + 0.5) * length / count
				slots.append({"kind": kind, "xf": xf * Transform3D(Basis.IDENTITY, Vector3(x, y + 0.015, depth * 0.12))})
			continue
		var k := -length * 0.5 + 0.12
		while k < length * 0.5 - 0.12:
			if _rng.randf() < 0.75:
				var c: Color = goods[_rng.randi() % goods.size()]
				var h := _rng.randf_range(0.12, 0.3)
				b.box_x(xf * Transform3D(Basis.IDENTITY, Vector3(k, y + 0.015 + h * 0.5, _rng.randf_range(-0.05, 0.08))),
						Vector3(0.18, h, 0.2), SlumMats.color(c, 0.0, 0.6), false, false)
			k += 0.24
	return slots


## Kühlschrank an der rechten Wand, Front nach −X, 1,2 m breit. Die Kollision steht hinter der Ware.
func _fridge(b: SlumBuilder, at: Vector3) -> void:
	b.box(at + Vector3(0.3, 1.0, 0.0), Vector3(0.1, 2.0, 1.2), SlumMats.color(Color(0.8, 0.92, 1.0), 0.9), false, false)
	for s: float in [-1.0, 1.0]:
		b.box(at + Vector3(0.0, 1.0, s * 0.58), Vector3(0.7, 2.0, 0.04), _metal, false)
	for y: float in [0.6, 1.2, 1.75]:
		b.box(at + Vector3(0.0, y - 0.02, 0.0), Vector3(0.6, 0.03, 1.12), _metal, false, false)
	b.box(at + Vector3(0.0, 1.98, 0.0), Vector3(0.7, 0.05, 1.2), _metal, false)
	b.box(at + Vector3(-0.34, 1.0, 0.0), Vector3(0.02, 1.9, 1.14), SlumMats.glass(Color(0.6, 0.85, 1.0, 0.12)), false, false)
	b.collider(at + Vector3(0.22, 1.0, 0.0), Vector3(0.3, 2.0, 1.2))


func _build_canopy(b: SlumBuilder) -> void:
	var y := 3.95
	var roof := SlumMats.color(Color(0.14, 0.15, 0.17), 0.0, 0.5, 0.4)
	b.box(Vector3(0.0, y, ISLAND_Z), Vector3(11.0, 0.3, 6.4), roof)
	# Leuchtband rundum.
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(0.0, y, ISLAND_Z + s * 3.205), Vector3(11.02, 0.1, 0.02), _trim, false, false)
		b.box(Vector3(s * 5.505, y, ISLAND_Z), Vector3(0.02, 0.1, 6.42), _trim, false, false)
		_add_light(Vector3(s * 3.2, 3.5, ISLAND_Z), Color(0.95, 0.95, 1.0), 2.0, 9.0)
	for x: float in [-4.0, -1.35, 1.35, 4.0]:
		b.box(Vector3(x, y - 0.16, ISLAND_Z), Vector3(1.6, 0.03, 4.6), SlumMats.color(Color(0.92, 0.96, 1.0), 1.4), false, false)
	for s: float in [-1.0, 1.0]:
		var x: float = s * ISLAND_X
		b.box(Vector3(x, 0.105, ISLAND_Z), Vector3(1.0, 0.09, 5.0), SlumMats.color(Color(0.42, 0.42, 0.44), 0.0, 0.7))
		b.box(Vector3(x, 2.0, ISLAND_Z), Vector3(0.35, 3.8, 0.35), _metal)
		for z: float in [-2.3, 2.3]:
			b.cylinder(Vector3(x, 0.15, ISLAND_Z + z), 0.07, 0.9, SlumMats.color(Color(0.95, 0.75, 0.1), 0.0, 0.5), 8, true)
		# Mülleimer an der Säule.
		b.box(Vector3(x, 0.55, ISLAND_Z + 0.3), Vector3(0.3, 0.8, 0.3), _dark, true)


## Luftstation und Reifenstapel an der Seite.
func _build_yard(b: SlumBuilder) -> void:
	var at := Vector3(-6.7, COURT_Y, 2.2)
	b.box(at + Vector3(0.0, 0.6, 0.0), Vector3(0.5, 1.2, 0.4), SlumMats.color(Color(0.7, 0.12, 0.12), 0.0, 0.5))
	b.box(at + Vector3(0.26, 0.9, 0.0), Vector3(0.01, 0.3, 0.26), SlumMats.color(Color(1.0, 0.85, 0.3), 2.0), false, false)
	b.cable(at + Vector3(0.0, 1.1, 0.21), at + Vector3(0.25, 0.8, 0.22), 0.7, _dark, 0.02)
	var rubber := SlumMats.color(Color(0.03, 0.03, 0.035), 0.0, 0.9)
	for i in 4:
		b.cylinder(Vector3(-6.75, COURT_Y + i * 0.24, 0.8), 0.36, 0.22, rubber, 12, true)
	for i in 2:
		b.cylinder(Vector3(-6.0, COURT_Y + i * 0.24, 0.9), 0.36, 0.22, rubber, 12, true)


## Diebstahlsicherung an der Tür, nur an manchen Tankstellen.
func _build_sensor(b: SlumBuilder) -> bool:
	if _rng.randf() >= SENSOR_CHANCE:
		return false
	for s: float in [-1.0, 1.0]:
		var at := Vector3(DOOR_X + s * (DOOR_W * 0.5 + 0.05), FLOOR_Y + 0.75, -0.45)
		b.box(at, Vector3(0.08, 1.5, 0.35), SlumMats.color(Color(0.85, 0.88, 0.9), 0.0, 0.3, 0.3))
		b.box(at, Vector3(0.09, 1.3, 0.05), SlumMats.color(Color(0.3, 0.8, 1.0), 2.5), false, false)
	return true


func _add_shop(slots: Array, sensor: bool) -> void:
	var ix0 := -WIDTH * 0.5 + WALL
	var ix1 := WIDTH * 0.5 - WALL
	var iz0 := -DEPTH + WALL
	var counter_x := _counter_x()
	var counter_zc := _counter_zc()
	var interior: Node3D = ShopInteriorScript.new()
	interior.name = "ShopInterior"
	interior.set("shop_sign", SHOP_SIGN)
	interior.set("floor_y", FLOOR_Y)
	interior.set("keeper_at", Vector3(ix0 + 0.65, FLOOR_Y, counter_zc))
	interior.set("register_at", Vector3(counter_x, FLOOR_Y + 1.06, counter_zc + 0.85))
	interior.set("counter_at", Vector3(counter_x + 0.1, FLOOR_Y + 1.06, counter_zc))
	interior.set("bounds", AABB(Vector3(ix0, FLOOR_Y - 0.5, iz0), Vector3(ix1 - ix0, HEIGHT, -iz0)))
	interior.set("camera_at", Vector3(ix1 - 0.35, HEIGHT - 0.4, -0.45))
	interior.set("has_sensor", sensor)
	interior.set("slots", slots)
	interior.set("seed_value", _rng.randi())
	add_child(interior)
	var sell := SELL_PAD.new() as Node3D
	sell.name = "SellPad"
	sell.unique_name_in_owner = true
	sell.position = Vector3(counter_x, FLOOR_Y + 1.06, counter_zc - 0.85)
	sell.rotation.y = PI * 0.5
	add_child(sell)
	sell.owner = get_parent()


func _add_pumps() -> void:
	for s: float in [-1.0, 1.0]:
		for dz: float in [-PUMP_DZ, PUMP_DZ]:
			var pump := PUMP.new() as Node3D
			pump.name = "Pump%d" % get_child_count()
			pump.position = Vector3(s * ISLAND_X, 0.15, ISLAND_Z + dz)
			add_child(pump)


## Ein Wagen steht an der Säule. Nur Kulisse, ein fester Block.
func _add_car() -> void:
	var kinds: Array[VehicleModel.Kind] = [VehicleModel.Kind.COMPACT, VehicleModel.Kind.SEDAN, VehicleModel.Kind.TAXI, VehicleModel.Kind.PICKUP]
	var car := VehicleModel.new()
	car.name = "ParkedCar"
	add_child(car)
	car.build(kinds[_rng.randi() % kinds.size()], _rng)
	car.headlight.visible = false
	var x := 1.25 if _rng.randf() < 0.5 else -1.25
	car.position = Vector3(x, COURT_Y, ISLAND_Z)
	car.rotation.y = 0.0 if _rng.randf() < 0.5 else PI
	var body := StaticBody3D.new()
	body.name = "ParkedCarBody"
	body.collision_layer = 1
	body.position = Vector3(x, COURT_Y + car.height * 0.5, ISLAND_Z)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(car.half_width * 2.0, car.height, car.half_length * 2.0)
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _add_machines() -> void:
	_machine(WATER, Vector3(-3.4, COURT_Y, 0.5))
	_machine(BAR, Vector3(-2.2, COURT_Y, 0.5))
	var atm: StaticBody3D = BANK.new()
	atm.name = "Atm"
	atm.position = Vector3(3.6, COURT_Y, 0.4)
	add_child(atm)


func _machine(product: ItemData, at: Vector3) -> void:
	var machine := VendingMachine.new()
	machine.product = product
	machine.price = 2
	machine.currency = CRED
	machine.consume_now = true
	machine.position = at
	add_child(machine)


func _add_loot() -> void:
	var iz0 := -DEPTH + WALL
	var ix0 := -WIDTH * 0.5 + WALL
	var safe := LootProp.new()
	safe.name = "DaySafe"
	safe.prompt_name = "Tagestresor"
	safe.item = CASH
	safe.count = 3
	safe.sealed = true
	safe.position = Vector3(ix0 + 1.5, FLOOR_Y, iz0 + 0.35)
	add_child(safe)
	if shop_key.is_empty():
		return
	var card := KEY.duplicate() as ItemData
	card.id = shop_key
	card.display_name = "Schlüsselkarte"
	var prop := LootProp.new()
	prop.name = "KeyCard"
	prop.prompt_name = "Schlüsselkarte"
	prop.item = card
	prop.position = Vector3(ix0 + 0.7, FLOOR_Y + 0.8, iz0 + 0.55)
	add_child(prop)


func _add_props() -> void:
	_prop(SlumProp.Kind.DUMPSTER, Vector3(-6.4, COURT_Y, -4.4), PI * 0.5)
	_prop(SlumProp.Kind.BARREL_GROUP, Vector3(6.3, COURT_Y, -4.8), 0.0)
	_prop(SlumProp.Kind.CRATE_STACK, Vector3(6.4, COURT_Y, -2.4), 0.4)
	_prop(SlumProp.Kind.AC_UNIT, Vector3(-2.5, HEIGHT, -3.6), 0.0)
	_prop(SlumProp.Kind.AC_UNIT, Vector3(2.0, HEIGHT, -4.2), PI)


func _prop(kind: SlumProp.Kind, at: Vector3, yaw: float) -> void:
	var prop := SlumProp.new()
	prop.kind = kind
	prop.position = at
	prop.rotation.y = yaw
	add_child(prop)


func _add_signs() -> void:
	var fascia := MeshInstance3D.new()
	fascia.name = "ShopSign"
	var board := BoxMesh.new()
	board.size = Vector3(5.6, 0.62, 0.06)
	board.material = _trim
	fascia.mesh = board
	fascia.position = Vector3(0.0, 2.92, 0.02)
	fascia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fascia)
	_label("TANKE // 24H", Vector3(0.0, 2.92, 0.06), 64, 0.011, Color(0.05, 0.03, 0.02))
	_label("KRAFTSTOFF", Vector3(0.0, 3.95, ISLAND_Z + 3.23), 40, 0.009, Color(1.0, 0.85, 0.6))
	# Preisstele vorne rechts.
	var b := SlumBuilder.new(self)
	b.box(Vector3(6.6, 3.5, 7.3), Vector3(0.4, 7.0, 0.3), _dark)
	b.box(Vector3(6.6, 5.4, 7.3), Vector3(1.5, 2.8, 0.34), SlumMats.color(Color(0.03, 0.04, 0.06), 0.0, 0.4), false)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(6.6, 6.72, 7.3 + side * 0.175), Vector3(1.4, 0.05, 0.01), _trim, false, false)
	b.finish()
	var prices := "TANKE
SUPER  1,89 ¢
DIESEL  1,74 ¢
EDDY-H2  2,10 ¢"
	for side: float in [-1.0, 1.0]:
		var label := _label(prices, Vector3(6.6, 5.4, 7.3 + side * 0.18), 36, 0.0048, Color(1.0, 0.7, 0.3))
		label.rotation.y = 0.0 if side > 0.0 else PI


func _label(text: String, at: Vector3, font: int, pixel: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = font
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 0
	label.double_sided = false
	add_child(label)
	return label


func _add_light(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = LIGHT_FADE
	light.distance_fade_length = 15.0
	add_child(light)
