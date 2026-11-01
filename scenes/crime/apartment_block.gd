class_name ApartmentBlock
extends Node3D
## Begehbare Wohnung mit Flur, Bad, Wohnküche und Schlafzimmer. Tür zu, Beute im Inventar,
## Tresor im Schlafzimmer, Bewohner nur manchmal.
##
## Lokaler Raum: Mitte der Bodenplatte, Tür in der Wand bei +Z. Die Wohnung ist auf die Tür
## ausgerichtet: In Grundrisskoordinaten liegt die Tür immer am rechten Ende (+X), _flip spiegelt.
##
## 35 % der Wohnungen haben beim Laden 1 oder 2 Bewohner (gleich oft).
## Die übrigen sind leer. `resident_count` >= 0 erzwingt die Zahl (Tests).

## Per preload statt class_name SafeProp: Der Klassen-Cache kennt neue Klassen erst nach einem Editor-Scan.
const SAFE_PROP := preload("res://scenes/crime/safe_prop.gd")
const JEWELRY := preload("res://scenes/items/data/jewelry.tres")
const JEWELS := preload("res://scenes/items/data/jewels.tres")
const CASH := preload("res://scenes/items/data/cash_wad.tres")
const TV := preload("res://scenes/items/data/tv_set.tres")
const ART := preload("res://scenes/items/data/painting.tres")
const PC := preload("res://scenes/items/data/computer.tres")
const PHONE := preload("res://scenes/items/data/smartphone.tres")
const KEY := preload("res://scenes/items/data/keycard.tres")

const RESIDENT_CHANCE := 0.35
const WALL := 0.16
const PARTITION := 0.1
const FLOOR_TOP := 0.1
const ROOM_TOP := 2.7
const DOOR_GAP := 1.16
## Innenleben wird erst aus der Nähe gezeichnet, von außen sieht man es ohnehin nicht.
const VIEW_RANGE := 44.0

@export var key_id := "apt_a"
## -1 = Würfel. 0, 1 oder 2 erzwingen die Bewohnerzahl.
@export var resident_count := -1
@export var hidden_key := ""
@export var unit_width := 8.0
@export var unit_depth := 7.0
## Oberkante der Decke. Im Haus bis zur Platte des nächsten Stocks.
@export var ceiling_top := 2.8
## Türmitte auf der lokalen X-Achse. 0 = nahe am +X-Ende. Das Vorzeichen legt die Spiegelung fest.
@export var door_offset := 0.0
## Türschild.
@export var plate := "WOHNUNG"

var theme := 0
var spawned_residents := 0
var _flip := 1.0
var _left := -4.0
var _right := 4.0
var _back := -3.5
var _front := 3.5
var _bed_wall := 0.0  # Wand zwischen Schlafzimmer und Wohnküche
var _bath_wall := 0.0  # Linke Wand von Bad und Flur
var _bath_front := 0.0  # Wand zwischen Bad und Flur
var _door_x := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key_id) ^ hash(str(global_position))
	theme = rng.randi_range(0, 2)
	_measure()
	var b := SlumBuilder.new(self)
	b.solid_range = VIEW_RANGE
	b.detail_range = VIEW_RANGE
	var colors := _palette()
	_build_shell(b, colors)
	_furnish(b, colors)
	b.finish()
	var door := LockedDoor.new()
	door.name = "Door"
	door.unique_name_in_owner = true
	door.key_id = key_id
	door.locked = true
	door.open_offset = Vector3(0.5, 1.1, -0.5)
	door.position = Vector3(_door_x * _flip, FLOOR_TOP, _front - WALL * 0.5)
	add_child(door)
	door.owner = self
	_place_loot(rng)
	if not hidden_key.is_empty():
		var stash := LootProp.new()
		stash.name = "SpareKey"
		stash.item = key_item(hidden_key)
		stash.prompt_name = "Schlüssel"
		stash.position = _at(_bath_wall + 0.85, 0.9, _back + WALL + 0.22)
		add_child(stash)
	spawned_residents = resolve_resident_count(rng, resident_count)
	_spawn_residents(spawned_residents)
	_lights(colors)
	var sign_plate := Label3D.new()
	sign_plate.name = "Sign"
	sign_plate.text = plate
	sign_plate.position = Vector3(_door_x * _flip, 2.4, _front + 0.02)
	sign_plate.font_size = 36
	sign_plate.pixel_size = 0.006
	sign_plate.modulate = colors["neon"]
	add_child(sign_plate)
	_limit_view()


## 0, oder bei Treffer (35 %) eine 1 oder eine 2, je zur Hälfte.
static func resolve_resident_count(rng: RandomNumberGenerator, forced: int) -> int:
	if forced >= 0:
		return mini(forced, 2)
	if rng.randf() >= RESIDENT_CHANCE:
		return 0
	return 1 if rng.randf() < 0.5 else 2


## Schlüssel zu einer Wohnung als Item. Für versteckte Ersatzschlüssel und Beute (Taschendiebstahl).
static func key_item(id: String) -> ItemData:
	var key := KEY.duplicate() as ItemData
	key.id = id
	key.display_name = "Wohnungsschlüssel %s" % id
	return key


func _measure() -> void:
	_flip = -1.0 if door_offset < 0.0 else 1.0
	_right = unit_width * 0.5
	_left = -_right
	_front = unit_depth * 0.5
	_back = -_front
	_door_x = absf(door_offset) if not is_zero_approx(door_offset) else _right - 1.2
	_bath_wall = _right - 2.2
	_bed_wall = _left + maxf(3.4, unit_width * 0.36)
	_bath_front = _back + 2.1


func _palette() -> Dictionary:
	match theme:
		1:
			return {
				"wall": Color(0.62, 0.48, 0.38),
				"trim": Color(0.28, 0.18, 0.13),
				"floor": Color(0.78, 0.62, 0.5),
				"cloth": Color(0.5, 0.2, 0.2),
				"neon": Color(1.0, 0.62, 0.28),
				"light": Color(1.0, 0.76, 0.48),
			}
		2:
			return {
				"wall": Color(0.42, 0.5, 0.6),
				"trim": Color(0.12, 0.15, 0.2),
				"floor": Color(0.55, 0.6, 0.68),
				"cloth": Color(0.2, 0.3, 0.45),
				"neon": Color(0.45, 0.75, 1.0),
				"light": Color(0.68, 0.82, 1.0),
			}
		_:
			return {
				"wall": Color(0.5, 0.38, 0.52),
				"trim": Color(0.16, 0.09, 0.16),
				"floor": Color(0.5, 0.42, 0.55),
				"cloth": Color(0.55, 0.14, 0.42),
				"neon": Color(0.3, 0.95, 1.0),
				"light": Color(0.62, 0.9, 1.0),
			}


## Punkt in Grundrisskoordinaten.
func _at(x: float, y: float, z: float) -> Vector3:
	return Vector3(x * _flip, y, z)


## Box von Ecke zu Ecke in Grundrisskoordinaten.
func _bx(b: SlumBuilder, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, mat: Material,
		collide := true, shadow := true) -> void:
	b.box_mm(_at(x0, y0, z0), _at(x1, y1, z1), mat, collide, shadow)


## Quad an einer Wand. normal in Grundrisskoordinaten.
func _wall_decal(b: SlumBuilder, at: Vector3, normal: Vector3, w: float, h: float, mat: Material) -> void:
	b.quad(at, Vector3(normal.x * _flip, normal.y, normal.z), w, h, mat)


func _build_shell(b: SlumBuilder, colors: Dictionary) -> void:
	var wall := SlumMats.surface("plaster", colors["wall"])
	var ceiling := SlumMats.surface("concrete", Color(0.8, 0.8, 0.8))
	var tile := SlumMats.surface("tiles_white")
	var inner := _front - WALL
	# Böden: Holz in den Zimmern, Fliesen in Flur und Bad.
	_bx(b, _left, _bed_wall, 0.0, FLOOR_TOP, _back, _front, SlumMats.surface("wood_dark", colors["floor"]))
	_bx(b, _bed_wall, _bath_wall, 0.0, FLOOR_TOP, _back, _front, SlumMats.surface("wood", colors["floor"]))
	_bx(b, _bath_wall, _right, 0.0, FLOOR_TOP, _bath_front, _front, SlumMats.surface("tiles_dark"))
	_bx(b, _bath_wall, _right, 0.0, FLOOR_TOP, _back, _bath_front, tile)
	_bx(b, _left, _right, ROOM_TOP, ceiling_top, _back, _front, ceiling)
	# Außenwände. Die Front hat die Türöffnung mit Sturz.
	_bx(b, _left, _right, FLOOR_TOP, ROOM_TOP, _back, _back + WALL, wall)
	_bx(b, _left, _left + WALL, FLOOR_TOP, ROOM_TOP, _back + WALL, inner, wall)
	_bx(b, _right - WALL, _right, FLOOR_TOP, ROOM_TOP, _back + WALL, inner, wall)
	var gap0 := _door_x - DOOR_GAP * 0.5
	var gap1 := _door_x + DOOR_GAP * 0.5
	_bx(b, _left, gap0, FLOOR_TOP, ceiling_top, inner, _front, wall)
	_bx(b, gap1, _right, FLOOR_TOP, ceiling_top, inner, _front, wall)
	_bx(b, gap0, gap1, 2.26, ceiling_top, inner, _front, wall)
	# Rahmen außen um die Tür.
	var trim := SlumMats.color(colors["trim"])
	_bx(b, gap0 - 0.07, gap0, FLOOR_TOP, 2.3, _front, _front + 0.03, trim, false)
	_bx(b, gap1, gap1 + 0.07, FLOOR_TOP, 2.3, _front, _front + 0.03, trim, false)
	_bx(b, gap0 - 0.07, gap1 + 0.07, 2.26, 2.33, _front, _front + 0.03, trim, false)
	# Innenwände mit Durchgängen.
	var half := PARTITION * 0.5
	var bed_gap0 := _front - WALL - 1.25
	var bed_gap1 := bed_gap0 + 1.05
	_bx(b, _bed_wall - half, _bed_wall + half, FLOOR_TOP, ROOM_TOP, _back + WALL, bed_gap0, wall)
	_bx(b, _bed_wall - half, _bed_wall + half, FLOOR_TOP, ROOM_TOP, bed_gap1, inner, wall)
	_bx(b, _bed_wall - half, _bed_wall + half, 2.2, ROOM_TOP, bed_gap0, bed_gap1, wall)
	_bx(b, _bath_wall - half, _bath_wall + half, FLOOR_TOP, ROOM_TOP, _back + WALL, _bath_front + half, wall)
	var bath_gap0 := _bath_wall + 0.3
	var bath_gap1 := bath_gap0 + 0.95
	_bx(b, _bath_wall + half, bath_gap0, FLOOR_TOP, ROOM_TOP, _bath_front - half, _bath_front + half, wall)
	_bx(b, bath_gap1, _right - WALL, FLOOR_TOP, ROOM_TOP, _bath_front - half, _bath_front + half, wall)
	_bx(b, bath_gap0, bath_gap1, 2.2, ROOM_TOP, _bath_front - half, _bath_front + half, wall)
	# Fliesenspiegel im Bad bis Kopfhöhe.
	_bx(b, _bath_wall + half, _right - WALL, FLOOR_TOP, 1.9, _back + WALL, _back + WALL + 0.015, tile, false, false)
	_bx(b, _right - WALL - 0.015, _right - WALL, FLOOR_TOP, 1.9, _back + WALL, _bath_front - half, tile, false, false)
	_bx(b, _bath_wall + half, _bath_wall + half + 0.015, FLOOR_TOP, 1.9, _back + WALL, _bath_front - half, tile, false, false)
	# Sockelleisten an den langen Wänden.
	_bx(b, _left + WALL, _bath_wall - half, FLOOR_TOP, 0.18, _back + WALL, _back + WALL + 0.02, trim, false, false)
	_bx(b, _left + WALL, _bed_wall - half, FLOOR_TOP, 0.18, inner - 0.02, inner, trim, false, false)
	_bx(b, _bed_wall + half, gap0, FLOOR_TOP, 0.18, inner - 0.02, inner, trim, false, false)
	_window(b, _bed_wall - 1.75, colors)
	_window(b, (_bed_wall + _bath_wall) * 0.5, colors)


## Fenster in der Rückwand: Nachtblau, Rahmen, Kreuz, zwei Gardinen. Die Außenseite ist die Fassade.
func _window(b: SlumBuilder, x: float, colors: Dictionary) -> void:
	var z := _back + WALL
	var frame := SlumMats.color(Color(0.1, 0.1, 0.11))
	var cloth := SlumMats.color(colors["cloth"], 0.0, 0.95)
	_bx(b, x - 0.62, x + 0.62, 1.05, 2.25, z, z + 0.015, SlumMats.color(Color(0.12, 0.2, 0.34), 1.0), false, false)
	_bx(b, x - 0.68, x + 0.68, 1.0, 1.05, z, z + 0.08, frame, false)
	_bx(b, x - 0.68, x + 0.68, 2.25, 2.3, z, z + 0.05, frame, false)
	_bx(b, x - 0.68, x - 0.62, 1.05, 2.25, z, z + 0.05, frame, false)
	_bx(b, x + 0.62, x + 0.68, 1.05, 2.25, z, z + 0.05, frame, false)
	_bx(b, x - 0.02, x + 0.02, 1.05, 2.25, z, z + 0.04, frame, false)
	_bx(b, x - 0.62, x + 0.62, 1.63, 1.67, z, z + 0.04, frame, false)
	_bx(b, x - 0.78, x - 0.42, 0.95, 2.32, z + 0.06, z + 0.09, cloth, false, false)
	_bx(b, x + 0.42, x + 0.78, 0.95, 2.32, z + 0.06, z + 0.09, cloth, false, false)
	_bx(b, x - 0.85, x + 0.85, 2.34, 2.37, z + 0.05, z + 0.08, _steel(), false, false)


func _steel() -> Material:
	return SlumMats.color(Color(0.42, 0.44, 0.46), 0.0, 0.4, 0.6)


func _furnish(b: SlumBuilder, colors: Dictionary) -> void:
	_kitchen(b, colors)
	_living(b, colors)
	_bedroom(b, colors)
	_bath(b)
	_hall(b, colors)


func _kitchen(b: SlumBuilder, colors: Dictionary) -> void:
	var x0 := _bed_wall + 0.1
	var x1 := _bath_wall - 0.8
	var z0 := _back + WALL
	var z1 := z0 + 0.6
	var wood := SlumMats.surface("wood", colors["cloth"].lerp(Color(0.5, 0.45, 0.4), 0.6))
	var top := SlumMats.color(Color(0.1, 0.1, 0.11), 0.0, 0.35)
	var white := SlumMats.color(Color(0.72, 0.74, 0.75), 0.0, 0.5)
	_mark("Kitchen", _at((x0 + x1) * 0.5, 0.5, z0 + 0.3))
	_bx(b, x0, x1, FLOOR_TOP, 0.92, z0, z1, wood)
	_bx(b, x0 - 0.02, x1 + 0.02, 0.92, 0.97, z0, z1 + 0.03, top, false)
	# Herd, Spüle, Griffe.
	var stove := x0 + 0.45
	_bx(b, stove - 0.3, stove + 0.3, 0.97, 0.98, z0 + 0.03, z1 - 0.03, SlumMats.color(Color(0.04, 0.04, 0.05)), false, false)
	for dx: float in [-0.14, 0.14]:
		for dz: float in [-0.13, 0.13]:
			b.cylinder_x(Transform3D(Basis.IDENTITY, _at(stove + dx, 0.985, z0 + 0.3 + dz)), 0.08, 0.01,
					SlumMats.color(Color(0.5, 0.12, 0.08), 0.6), 8, false, false)
	var sink := x1 - 0.4
	_bx(b, sink - 0.24, sink + 0.24, 0.97, 0.985, z0 + 0.1, z1 - 0.1, _steel(), false, false)
	b.tube(_at(sink, 0.97, z0 + 0.06), _at(sink, 1.2, z0 + 0.06), 0.012, _steel(), 4, false)
	b.tube(_at(sink, 1.2, z0 + 0.06), _at(sink, 1.2, z0 + 0.22), 0.012, _steel(), 4, false)
	var front := z1 + 0.005
	var x := x0 + 0.05
	while x + 0.5 <= x1:
		_bx(b, x, x + 0.48, 0.14, 0.88, z1, front, wood, false, false)
		_bx(b, x + 0.18, x + 0.3, 0.8, 0.82, front, front + 0.015, _steel(), false, false)
		x += 0.52
	# Wandbord mit Dosen neben dem Fenster.
	_bx(b, x0, x0 + 0.5, 1.65, 1.68, z0, z0 + 0.22, wood, false)
	_bx(b, x0 + 0.08, x0 + 0.18, 1.68, 1.82, z0 + 0.05, z0 + 0.15, SlumMats.color(Color(0.7, 0.2, 0.15)), false, false)
	_bx(b, x0 + 0.26, x0 + 0.36, 1.68, 1.8, z0 + 0.05, z0 + 0.15, SlumMats.color(Color(0.2, 0.5, 0.3)), false, false)
	# Kühlschrank zwischen Küchenzeile und Badwand.
	var fx0 := _bath_wall - 0.75
	var fx1 := _bath_wall - 0.08
	_mark("Fridge", _at((fx0 + fx1) * 0.5, 0.9, z0 + 0.33))
	_bx(b, fx0, fx1, FLOOR_TOP, 1.9, z0, z0 + 0.66, white)
	_bx(b, fx0 + 0.02, fx1 - 0.02, 1.24, 1.26, z0 + 0.66, z0 + 0.67, SlumMats.color(Color(0.2, 0.2, 0.22)), false, false)
	_bx(b, fx0 + 0.08, fx0 + 0.11, 0.7, 1.15, z0 + 0.67, z0 + 0.69, _steel(), false, false)
	_bx(b, fx0 + 0.08, fx0 + 0.11, 1.32, 1.65, z0 + 0.67, z0 + 0.69, _steel(), false, false)


func _living(b: SlumBuilder, colors: Dictionary) -> void:
	var cloth := SlumMats.color(colors["cloth"], 0.0, 0.95)
	var dark := SlumMats.color(colors["trim"], 0.0, 0.6)
	var wood := SlumMats.surface("wood_dark", Color(0.8, 0.72, 0.65))
	var x0 := _bed_wall + PARTITION * 0.5
	var z0 := _sofa_z()
	var z1 := z0 + 1.9
	_mark("Sofa", _at(x0 + 0.42, 0.35, (z0 + z1) * 0.5))
	_bx(b, x0, x0 + 0.84, FLOOR_TOP, 0.42, z0, z1, cloth)
	_bx(b, x0, x0 + 0.22, 0.42, 0.85, z0, z1, cloth)
	_bx(b, x0, x0 + 0.84, 0.42, 0.62, z0, z0 + 0.16, cloth)
	_bx(b, x0, x0 + 0.84, 0.42, 0.62, z1 - 0.16, z1, cloth)
	for cushion: int in 2:
		var c0 := z0 + 0.2 + cushion * 0.76
		_bx(b, x0 + 0.24, x0 + 0.34, 0.45, 0.76, c0, c0 + 0.68, dark, false)
	# Couchtisch.
	var cx := x0 + 1.4
	var cz := (z0 + z1) * 0.5
	_mark("Table", _at(cx, 0.3, cz))
	_bx(b, cx - 0.3, cx + 0.3, 0.4, 0.44, cz - 0.55, cz + 0.55, wood)
	for sx: float in [-0.26, 0.26]:
		for sz: float in [-0.5, 0.5]:
			_bx(b, cx + sx - 0.03, cx + sx + 0.03, FLOOR_TOP, 0.4, cz + sz - 0.03, cz + sz + 0.03, dark, false)
	# Fernsehbank an der Frontwand, Teppich davor.
	var tx := _tv_x()
	var inner := _front - WALL
	_bx(b, tx - 0.62, tx + 0.62, FLOOR_TOP, 0.5, inner - 0.42, inner, wood)
	_bx(b, cx - 0.75, cx + 0.75, FLOOR_TOP, FLOOR_TOP + 0.012, z0, z1, SlumMats.color(colors["cloth"].darkened(0.4), 0.0, 1.0), false, false)
	# Stehlampe in der Ecke.
	var lamp := _at(x0 + 0.22, FLOOR_TOP, z1 + 0.12)
	b.tube(lamp, lamp + Vector3.UP * 1.45, 0.015, _steel(), 4, false)
	_bx(b, x0 + 0.12, x0 + 0.32, 1.5, 1.72, z1 + 0.02, z1 + 0.22, SlumMats.color(colors["light"], 2.0), false, false)


func _sofa_z() -> float:
	return _back + WALL + 0.8


func _tv_x() -> float:
	return minf(_bed_wall + 1.75, _bath_wall - 0.68)


func _bedroom(b: SlumBuilder, colors: Dictionary) -> void:
	var cloth := SlumMats.color(colors["cloth"], 0.0, 0.95)
	var dark := SlumMats.color(colors["trim"], 0.0, 0.6)
	var wood := SlumMats.surface("wood_dark", Color(0.85, 0.75, 0.68))
	var sheet := SlumMats.color(Color(0.72, 0.7, 0.68), 0.0, 0.95)
	var x0 := _left + WALL
	var z0 := _back + WALL
	var inner := _front - WALL
	_mark("Bed", _at(x0 + 1.0, 0.3, z0 + 0.75))
	_bx(b, x0, x0 + 1.95, FLOOR_TOP, 0.3, z0, z0 + 1.45, dark)
	_bx(b, x0 + 0.03, x0 + 1.92, 0.3, 0.48, z0 + 0.03, z0 + 1.42, sheet)
	_bx(b, x0 + 0.65, x0 + 1.94, 0.48, 0.53, z0 + 0.02, z0 + 1.43, cloth, false)
	_bx(b, x0, x0 + 0.06, FLOOR_TOP, 1.0, z0, z0 + 1.45, dark)
	_bx(b, x0 + 0.1, x0 + 0.55, 0.48, 0.58, z0 + 0.14, z0 + 0.66, sheet, false)
	_bx(b, x0 + 0.1, x0 + 0.55, 0.48, 0.58, z0 + 0.78, z0 + 1.3, sheet, false)
	# Nachttisch, Lampe.
	var n0 := x0 + 2.0
	_mark("Nightstand", _at(n0 + 0.22, 0.3, z0 + 0.22))
	_bx(b, n0, n0 + 0.44, FLOOR_TOP, 0.55, z0, z0 + 0.44, wood)
	# Schreibtisch an der Wand, Stuhl davor.
	var d0 := inner - 1.5
	_mark("Desk", _at(x0 + 0.35, 0.4, d0 + 0.65))
	_bx(b, x0, x0 + 0.7, 0.72, 0.77, d0, d0 + 1.3, wood)
	for dz: float in [0.03, 1.27]:
		_bx(b, x0 + 0.05, x0 + 0.65, FLOOR_TOP, 0.72, d0 + dz - 0.02, d0 + dz + 0.02, dark)
	_bx(b, x0 + 0.85, x0 + 1.27, 0.48, 0.53, d0 + 0.45, d0 + 0.87, cloth)
	_bx(b, x0 + 1.23, x0 + 1.28, 0.53, 0.98, d0 + 0.45, d0 + 0.87, cloth, false)
	b.tube(_at(x0 + 1.06, FLOOR_TOP, d0 + 0.66), _at(x0 + 1.06, 0.48, d0 + 0.66), 0.03, _steel(), 6, false)
	# Kleiderschrank an der Frontwand.
	var w1 := _bed_wall - 1.15
	var w0 := w1 - 1.1
	_mark("Wardrobe", _at((w0 + w1) * 0.5, 1.0, inner - 0.3))
	_bx(b, w0, w1, FLOOR_TOP, 2.05, inner - 0.6, inner, wood)
	var mid := (w0 + w1) * 0.5
	_bx(b, mid - 0.006, mid + 0.006, 0.14, 2.0, inner - 0.605, inner - 0.6, dark, false, false)
	for side: float in [-0.09, 0.09]:
		_bx(b, mid + side - 0.012, mid + side + 0.012, 1.0, 1.25, inner - 0.62, inner - 0.6, _steel(), false, false)


func _bath(b: SlumBuilder) -> void:
	var porcelain := SlumMats.color(Color(0.82, 0.84, 0.84), 0.0, 0.3)
	var half := PARTITION * 0.5
	var z0 := _back + WALL
	var x0 := _bath_wall + half
	var x1 := _right - WALL
	# WC an der Rückwand.
	var tx := x0 + 0.4
	_mark("Toilet", _at(tx, 0.3, z0 + 0.4))
	_bx(b, tx - 0.19, tx + 0.19, FLOOR_TOP, 0.44, z0 + 0.18, z0 + 0.66, porcelain)
	_bx(b, tx - 0.21, tx + 0.21, 0.44, 0.47, z0 + 0.16, z0 + 0.68, porcelain, false)
	_bx(b, tx - 0.22, tx + 0.22, 0.47, 0.82, z0 + 0.02, z0 + 0.18, porcelain, false)
	# Waschtisch mit Spiegel.
	var sx := x0 + 0.95
	_mark("Sink", _at(sx, 0.5, z0 + 0.25))
	_bx(b, sx - 0.32, sx + 0.32, 0.72, 0.9, z0, z0 + 0.46, porcelain)
	b.tube(_at(sx, FLOOR_TOP, z0 + 0.22), _at(sx, 0.72, z0 + 0.22), 0.04, porcelain, 6, false)
	_bx(b, sx - 0.3, sx + 0.3, 1.2, 1.75, z0 + 0.016, z0 + 0.03, SlumMats.color(Color(0.5, 0.58, 0.62), 0.0, 0.08, 0.9), false, false)
	_bx(b, sx - 0.3, sx + 0.3, 1.78, 1.82, z0 + 0.02, z0 + 0.09, SlumMats.color(Color(0.9, 0.95, 1.0), 2.5), false, false)
	# Dusche in der Ecke: Wanne, Glas, Brause.
	var s0 := maxf(x1 - 0.72, sx + 0.34)
	var sz := z0 + 0.86
	_mark("Shower", _at((s0 + x1) * 0.5, 0.2, z0 + 0.43))
	_bx(b, s0, x1, FLOOR_TOP, 0.16, z0, sz, porcelain, false)
	_bx(b, s0, x1, 0.16, 2.0, sz - 0.015, sz, SlumMats.glass(Color(0.6, 0.85, 1.0, 0.2)), true, false)
	_bx(b, s0 - 0.015, s0, 0.16, 2.0, z0, sz, SlumMats.glass(Color(0.6, 0.85, 1.0, 0.2)), true, false)
	var head := _at(x1 - 0.1, 2.0, z0 + 0.4)
	b.tube(head + _dir(0.1, 0.0), head + _dir(-0.16, 0.0), 0.012, _steel(), 4, false)
	_bx(b, x1 - 0.32, x1 - 0.18, 1.96, 1.99, z0 + 0.33, z0 + 0.47, _steel(), false, false)
	# Handtuch an der Tür zum Flur.
	_bx(b, x0 + 0.02, x0 + 0.04, 0.9, 1.5, z0 + 1.1, z0 + 1.55, SlumMats.color(Color(0.3, 0.55, 0.55), 0.0, 0.95), false, false)


func _dir(x: float, z: float) -> Vector3:
	return Vector3(x * _flip, 0.0, z)


func _hall(b: SlumBuilder, colors: Dictionary) -> void:
	var inner := _front - WALL
	var x1 := _right - WALL
	var wood := SlumMats.surface("wood_dark", Color(0.85, 0.75, 0.68))
	# Schuhregal, Garderobe, Fußmatte hinter der Tür.
	var z0 := _bath_front + 0.3
	_bx(b, x1 - 0.3, x1, FLOOR_TOP, 0.42, z0, z0 + 0.8, wood)
	_bx(b, x1 - 0.03, x1, 1.65, 1.75, z0, z0 + 0.8, wood, false)
	for i: int in 3:
		var hook := z0 + 0.15 + i * 0.25
		_bx(b, x1 - 0.1, x1, 1.58, 1.62, hook - 0.01, hook + 0.01, _steel(), false, false)
	_bx(b, x1 - 0.1, x1 - 0.02, 1.0, 1.58, z0 + 0.32, z0 + 0.5, SlumMats.color(colors["cloth"].darkened(0.3), 0.0, 0.95), false, false)
	_bx(b, _door_x - 0.42, _door_x + 0.42, FLOOR_TOP, FLOOR_TOP + 0.012, inner - 0.75, inner - 0.1, SlumMats.color(Color(0.16, 0.12, 0.09), 0.0, 1.0), false, false)
	# Poster im Schlafzimmer, Kalender in der Küche.
	_wall_decal(b, _at(_bed_wall - PARTITION * 0.5 - 0.01, 1.5, _back + WALL + 1.45), Vector3.LEFT, 0.5, 0.75,
			SlumMats.decal("poster_%d" % (1 + theme)))
	_wall_decal(b, _at(_bed_wall + PARTITION * 0.5 + 0.01, 1.45, _sofa_z() + 0.95), Vector3.RIGHT, 0.45, 0.68,
			SlumMats.decal("poster_%d" % (2 + theme)))


func _place_loot(rng: RandomNumberGenerator) -> void:
	var x0 := _left + WALL
	var z0 := _back + WALL
	var inner := _front - WALL
	var couch := _bed_wall + 0.05 + 1.4
	var couch_z := _sofa_z() + 0.95
	var desk := inner - 0.85
	_loot("Schmuck", JEWELRY, _at(x0 + 2.22, 0.55, z0 + 0.22), false, &"Jewelry")
	_loot("Juwelen", JEWELS, _at(couch, 0.44, couch_z), true, &"Jewels")
	_loot("Bargeld", CASH, _at(_bed_wall + 1.0, 0.97, z0 + 0.3), false, &"Cash")
	_loot("Fernseher", TV, _at(_tv_x(), 0.5, inner - 0.21), false, &"Television")
	_loot("Bild", ART, _at(x0 + 0.05, 1.35, -0.1 if unit_depth < 5.0 else z0 + 1.9), false, &"Artwork")
	(get_node(^"%Artwork") as Node3D).rotation.y = PI * 0.5 * _flip
	_loot("Computer", PC, _at(x0 + 0.35, 0.77, desk - 0.2), false, &"Computer")
	_loot("Handy", PHONE, _at(x0 + 0.35, 0.77, desk + 0.4), false, &"Phone")
	var safe := SAFE_PROP.new()
	safe.name = "Safe"
	safe.unique_name_in_owner = true
	safe.prompt_name = "Tresor"
	safe.item = CASH
	safe.count = rng.randi_range(2, 4)
	safe.sealed = true
	safe.position = _at(_bed_wall - 0.42, FLOOR_TOP, z0 + 0.32)
	add_child(safe)
	safe.owner = self


func _spawn_residents(count: int) -> void:
	# Bewohner sind Spiel-Logik. Im Editor baut slum_building.gd (@tool) den Block per .new(), dann
	# liefe CivilianCrime echt und riefe das Platzhalter-Autoload WorldSync auf.
	if Engine.is_editor_hint():
		return
	var spots: Array[Vector3] = [
		_at((_bed_wall + _bath_wall) * 0.5 + 0.6, FLOOR_TOP + 0.02, _back + WALL + 1.3),
		_at(_bed_wall - 1.7, FLOOR_TOP + 0.02, _back + WALL + 1.9),
	]
	for i in mini(count, spots.size()):
		var person := Civilian.new()
		person.name = "Resident%d" % (i + 1)
		person.unique_name_in_owner = true
		person.stay_put = true
		person.position = spots[i]
		person.rotation.y = PI if i == 0 else 0.0
		add_child(person)
		person.owner = self


func _lights(colors: Dictionary) -> void:
	var living := (_bed_wall + _bath_wall) * 0.5
	var bedroom := (_left + _bed_wall) * 0.5
	var bath := (_bath_wall + _right) * 0.5
	var y := ROOM_TOP - 0.24
	_omni(_at(living, y, 0.0), colors["light"], 1.2)
	_omni(_at(bedroom, y, 0.0), colors["light"], 0.9)
	_omni(_at(bath, y, (_back + _bath_front) * 0.5), Color(0.9, 0.95, 1.0), 0.9)
	var b := SlumBuilder.new(self)
	b.solid_range = VIEW_RANGE
	var shade := SlumMats.color(colors["light"], 3.0)
	for x: float in [living, bedroom]:
		_bx(b, x - 0.22, x + 0.22, ROOM_TOP - 0.1, ROOM_TOP, -0.22, 0.22, shade, false, false)
	b.finish()


func _omni(at: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 30.0
	light.distance_fade_length = 8.0
	add_child(light)


## Fester Punkt für Möbel, die im gemeinsamen Mesh aufgehen.
func _mark(node_name: String, at: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = node_name
	marker.position = at
	add_child(marker)


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


func _limit_view() -> void:
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry.visibility_range_end <= 0.0:
			geometry.visibility_range_end = VIEW_RANGE
