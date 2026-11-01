class_name ApartmentBlock
extends Node3D
## Begehbare Wohnung: Schlafzimmer, offene Wohnküche mit Flur und ein eigenes Bad. Tür zu, Beute im
## Inventar, Tresor im Schlafzimmer, Bewohner nur manchmal.
##
## Lokaler Raum: Mitte der Bodenplatte, Tür in der Wand bei +Z. Die Wohnung ist auf die Tür
## ausgerichtet: In Grundrisskoordinaten liegt die Tür immer am rechten Ende (+X), _flip spiegelt.
##
## Grundriss von links nach rechts: Schlafzimmer, Wohnküche, rechts Flur (vorn) und Bad (hinten).
## Flur und Wohnküche sind ein Raum, nur Schlafzimmer und Bad haben Wände mit breiten Durchgängen.
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
const PARTITION := 0.12
const FLOOR_TOP := 0.1
const ROOM_TOP := 2.7
const DOOR_GAP := 1.16
## Durchgang ins Schlafzimmer und ins Bad. Breit genug, dass man nirgends hängen bleibt.
const BED_GAP := 1.15
const BATH_GAP := 1.0
const DOOR_TOP := 2.15
## Höhe des Türblatts ab Boden bis zum Sturz (Unterkante Sturz bei 2,26 m ab Bodenplatte).
const DOOR_TOP_HEIGHT := 2.16
## Höhe der dunklen Wandverkleidung.
const PANEL := 0.9
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
var _bed_door_z := 0.0  # Mitte des Durchgangs im Schlafzimmer
var _bath_wall := 0.0  # Linke Wand des Bads, links davon Wohnküche, davor der Flur
var _bath_front := 0.0  # Wand zwischen Bad und Flur
var _bath_door_x := 0.0  # Mitte des Durchgangs ins Bad
var _door_x := 0.0
## Innenleben: Wände, Möbel, Lichter. Bleibt unsichtbar, solange die Tür zu ist.
var _interior: Node3D
var _sealed_nodes: Array[Node3D] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key_id) ^ hash(str(global_position))
	theme = rng.randi_range(0, 2)
	_measure()
	_interior = Node3D.new()
	_interior.name = "Interior"
	add_child(_interior)
	var b := SlumBuilder.new(_interior)
	b.solid_range = VIEW_RANGE
	b.detail_range = VIEW_RANGE
	# Die Frontwand mit Türrahmen sieht man vom Treppenhaus aus immer.
	var front := SlumBuilder.new(self)
	front.solid_range = VIEW_RANGE
	front.detail_range = VIEW_RANGE
	var colors := _palette()
	_build_shell(b, front, colors)
	_furnish(b, colors)
	b.finish()
	front.finish()
	var door := LockedDoor.new()
	door.name = "Door"
	door.unique_name_in_owner = true
	door.key_id = key_id
	door.locked = true
	# Füllt die Wandöffnung bis unter den Sturz. Offen schwingt das Blatt um die Angel an der +X-Kante nach innen.
	door.door_size = Vector2(DOOR_GAP, DOOR_TOP_HEIGHT)
	door.panel_gap = Vector2.ZERO
	door.open_offset = Vector3(DOOR_GAP * 0.5 * (1.0 - cos(deg_to_rad(80.0))), DOOR_TOP_HEIGHT * 0.5, -DOOR_GAP * 0.5 * sin(deg_to_rad(80.0)))
	door.position = Vector3(_door_x * _flip, FLOOR_TOP, _front - WALL * 0.5)
	add_child(door)
	door.owner = self
	door.opened.connect(_reveal.unbind(1))
	_place_loot(rng)
	if not hidden_key.is_empty():
		var stash := LootProp.new()
		stash.name = "SpareKey"
		stash.item = key_item(hidden_key)
		stash.prompt_name = "Schlüssel"
		# Auf dem Schuhregal im Flur, gleich hinter der Tür.
		stash.position = _at(_right - WALL - 0.15, 0.42, _bath_front + 0.8)
		add_child(stash)
	spawned_residents = resolve_resident_count(rng, resident_count)
	_spawn_residents(spawned_residents)
	_lights(colors)
	_seal()
	var sign_plate := Label3D.new()
	sign_plate.name = "Sign"
	sign_plate.text = plate
	sign_plate.position = Vector3(_door_x * _flip, 2.4, _front + 0.02)
	sign_plate.font_size = 36
	sign_plate.pixel_size = 0.006
	sign_plate.modulate = colors["neon"]
	add_child(sign_plate)
	_limit_view()


## Hinter verschlossener Tür wird nichts gezeichnet. Auch Beute und Bewohner bleiben unsichtbar.
func _seal() -> void:
	_interior.visible = false
	for child in get_children():
		if child is LootProp or child is Civilian:
			_sealed_nodes.append(child as Node3D)
			(child as Node3D).visible = false
	# Innen wirft nichts Schatten: Die Sonne erreicht die Räume ohnehin nicht.
	for node: Node in _interior.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _reveal() -> void:
	_interior.visible = true
	for node in _sealed_nodes:
		if is_instance_valid(node):
			node.visible = true
	_sealed_nodes.clear()


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
	_bath_wall = _right - 2.7
	_bed_wall = _left + maxf(3.7, unit_width * 0.39)
	_bath_front = _back + 2.3
	_bed_door_z = _front - WALL - 0.1 - BED_GAP * 0.5
	_bath_door_x = _bath_wall + 0.35 + BATH_GAP * 0.5


func _palette() -> Dictionary:
	match theme:
		1:
			return {
				"wall": Color(0.86, 0.74, 0.62),
				"trim": Color(0.28, 0.18, 0.13),
				"floor": Color(0.78, 0.62, 0.5),
				"cloth": Color(0.55, 0.22, 0.2),
				"neon": Color(1.0, 0.62, 0.28),
				"light": Color(1.0, 0.8, 0.55),
			}
		2:
			return {
				"wall": Color(0.66, 0.74, 0.84),
				"trim": Color(0.12, 0.15, 0.2),
				"floor": Color(0.55, 0.6, 0.68),
				"cloth": Color(0.2, 0.32, 0.5),
				"neon": Color(0.45, 0.75, 1.0),
				"light": Color(0.75, 0.86, 1.0),
			}
		_:
			return {
				"wall": Color(0.78, 0.64, 0.8),
				"trim": Color(0.16, 0.09, 0.16),
				"floor": Color(0.5, 0.42, 0.55),
				"cloth": Color(0.55, 0.14, 0.42),
				"neon": Color(0.3, 0.95, 1.0),
				"light": Color(0.75, 0.92, 1.0),
			}


## Punkt in Grundrisskoordinaten.
func _at(x: float, y: float, z: float) -> Vector3:
	return Vector3(x * _flip, y, z)


func _dir(x: float, z: float) -> Vector3:
	return Vector3(x * _flip, 0.0, z)


## Box von Ecke zu Ecke in Grundrisskoordinaten.
func _bx(b: SlumBuilder, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, mat: Material,
		collide := true, shadow := true) -> void:
	b.box_mm(_at(x0, y0, z0), _at(x1, y1, z1), mat, collide, shadow)


## Dekor ohne Kollision und Schatten.
func _dx(b: SlumBuilder, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, mat: Material) -> void:
	b.box_mm(_at(x0, y0, z0), _at(x1, y1, z1), mat, false, false)


## Quad an einer Wand. normal in Grundrisskoordinaten.
func _wall_decal(b: SlumBuilder, at: Vector3, normal: Vector3, w: float, h: float, mat: Material) -> void:
	b.quad(at, Vector3(normal.x * _flip, normal.y, normal.z), w, h, mat)


func _steel() -> Material:
	return SlumMats.color(Color(0.42, 0.44, 0.46), 0.0, 0.4, 0.6)


func _build_shell(b: SlumBuilder, front: SlumBuilder, colors: Dictionary) -> void:
	var wall := SlumMats.surface("plaster", colors["wall"])
	var ceiling := SlumMats.surface("plaster", Color(0.86, 0.85, 0.82))
	var tile := SlumMats.surface("tiles_white")
	var inner := _front - WALL
	var back_in := _back + WALL
	var half := PARTITION * 0.5
	# Böden: Holz in den Zimmern, Fliesen in Flur und Bad.
	_bx(b, _left, _bed_wall, 0.0, FLOOR_TOP, _back, _front, SlumMats.surface("wood_dark", colors["floor"]))
	_bx(b, _bed_wall, _bath_wall, 0.0, FLOOR_TOP, _back, _front, SlumMats.surface("wood", colors["floor"]))
	_bx(b, _bath_wall, _right, 0.0, FLOOR_TOP, _bath_front, _front, SlumMats.surface("tiles_dark"))
	_bx(b, _bath_wall, _right, 0.0, FLOOR_TOP, _back, _bath_front, tile)
	_bx(b, _left, _right, ROOM_TOP, ceiling_top, _back, _front, ceiling)
	# Außenwände. Die Front hat die Türöffnung mit Sturz.
	_bx(b, _left, _right, FLOOR_TOP, ROOM_TOP, _back, back_in, wall)
	_bx(b, _left, _left + WALL, FLOOR_TOP, ROOM_TOP, back_in, inner, wall)
	_bx(b, _right - WALL, _right, FLOOR_TOP, ROOM_TOP, back_in, inner, wall)
	var gap0 := _door_x - DOOR_GAP * 0.5
	var gap1 := _door_x + DOOR_GAP * 0.5
	_bx(front, _left, gap0, FLOOR_TOP, ceiling_top, inner, _front, wall)
	_bx(front, gap1, _right, FLOOR_TOP, ceiling_top, inner, _front, wall)
	_bx(front, gap0, gap1, 2.26, ceiling_top, inner, _front, wall)
	# Rahmen um die Tür, innen und außen.
	var trim := SlumMats.color(colors["trim"])
	for z: float in [_front, inner - 0.03]:
		var target := front if z == _front else b
		_bx(target, gap0 - 0.07, gap0, FLOOR_TOP, 2.3, z, z + 0.03, trim, false)
		_bx(target, gap1, gap1 + 0.07, FLOOR_TOP, 2.3, z, z + 0.03, trim, false)
		_bx(target, gap0 - 0.07, gap1 + 0.07, 2.26, 2.33, z, z + 0.03, trim, false)
	# Wand zwischen Schlafzimmer und Wohnküche, mit breitem Durchgang nah an der Frontwand.
	var bed_gap0 := inner - 0.1 - BED_GAP
	var bed_gap1 := inner - 0.1
	_bx(b, _bed_wall - half, _bed_wall + half, FLOOR_TOP, ROOM_TOP, back_in, bed_gap0, wall)
	_bx(b, _bed_wall - half, _bed_wall + half, FLOOR_TOP, ROOM_TOP, bed_gap1, inner, wall)
	_bx(b, _bed_wall - half, _bed_wall + half, DOOR_TOP, ROOM_TOP, bed_gap0, bed_gap1, wall)
	_opening_z(b, _bed_wall, bed_gap0, bed_gap1, trim)
	# Bad: Wand zur Wohnküche (ohne Tür) und Wand zum Flur mit Durchgang.
	var bath_gap0 := _bath_door_x - BATH_GAP * 0.5
	var bath_gap1 := _bath_door_x + BATH_GAP * 0.5
	_bx(b, _bath_wall - half, _bath_wall + half, FLOOR_TOP, ROOM_TOP, back_in, _bath_front + half, wall)
	_bx(b, _bath_wall + half, bath_gap0, FLOOR_TOP, ROOM_TOP, _bath_front - half, _bath_front + half, wall)
	_bx(b, bath_gap1, _right - WALL, FLOOR_TOP, ROOM_TOP, _bath_front - half, _bath_front + half, wall)
	_bx(b, bath_gap0, bath_gap1, DOOR_TOP, ROOM_TOP, _bath_front - half, _bath_front + half, wall)
	_opening_x(b, _bath_front, bath_gap0, bath_gap1, trim)
	# Fliesenspiegel im Bad bis Kopfhöhe.
	_dx(b, _bath_wall + half, _right - WALL, FLOOR_TOP, 1.9, back_in, back_in + 0.015, tile)
	_dx(b, _right - WALL - 0.015, _right - WALL, FLOOR_TOP, 1.9, back_in, _bath_front - half, tile)
	_dx(b, _bath_wall + half, _bath_wall + half + 0.015, FLOOR_TOP, 1.9, back_in, _bath_front - half, tile)
	# Dunkle Wandverkleidung und Sockelleiste. Kein Zentimeter Überlappung mit Möbeln: Sie liegt flach an.
	var panel := SlumMats.surface("wood_dark", Color(0.6, 0.5, 0.46).lerp(colors["trim"], 0.4))
	var rail := SlumMats.color(colors["trim"], 0.0, 0.6)
	_panel_x(b, _left + WALL, _bath_wall - half, back_in, 1.0, panel, rail)
	_panel_z(b, _left + WALL, back_in, inner, 1.0, panel, rail)
	_panel_x(b, _left + WALL, gap0, inner, -1.0, panel, rail)
	_panel_x(b, gap1, _right - WALL, inner, -1.0, panel, rail)
	_panel_z(b, _right - WALL, _bath_front + half, inner, -1.0, panel, rail)
	_window(b, _bed_wall - 1.75, colors)
	_window(b, (_bed_wall + _bath_wall) * 0.5, colors)


## Verkleidung an einer Wand entlang X. side = 1: Wand liegt hinten (Verkleidung ragt nach +Z),
## -1: Wand liegt vorn (nach -Z).
func _panel_x(b: SlumBuilder, x0: float, x1: float, z: float, side: float, panel: Material, rail: Material) -> void:
	if x1 - x0 < 0.05:
		return
	_dx(b, x0, x1, FLOOR_TOP, PANEL, z, z + 0.015 * side, panel)
	_dx(b, x0, x1, PANEL, PANEL + 0.04, z, z + 0.03 * side, rail)
	_dx(b, x0, x1, FLOOR_TOP, 0.18, z + 0.015 * side, z + 0.03 * side, rail)


## Verkleidung an einer Wand entlang Z. side = 1: Wand liegt links (ragt nach +X), -1: rechts.
func _panel_z(b: SlumBuilder, x: float, z0: float, z1: float, side: float, panel: Material, rail: Material) -> void:
	if z1 - z0 < 0.05:
		return
	_dx(b, x, x + 0.015 * side, FLOOR_TOP, PANEL, z0, z1, panel)
	_dx(b, x, x + 0.03 * side, PANEL, PANEL + 0.04, z0, z1, rail)
	_dx(b, x + 0.015 * side, x + 0.03 * side, FLOOR_TOP, 0.18, z0, z1, rail)


## Zarge um einen Durchgang in einer Wand quer zur X-Achse (Wand bei x, Öffnung z0..z1).
func _opening_z(b: SlumBuilder, x: float, z0: float, z1: float, mat: Material) -> void:
	var t := PARTITION * 0.5 + 0.02
	_dx(b, x - t, x + t, FLOOR_TOP, DOOR_TOP + 0.05, z0 - 0.05, z0, mat)
	_dx(b, x - t, x + t, FLOOR_TOP, DOOR_TOP + 0.05, z1, z1 + 0.05, mat)
	_dx(b, x - t, x + t, DOOR_TOP, DOOR_TOP + 0.05, z0, z1, mat)


## Zarge um einen Durchgang in einer Wand quer zur Z-Achse (Wand bei z, Öffnung x0..x1).
func _opening_x(b: SlumBuilder, z: float, x0: float, x1: float, mat: Material) -> void:
	var t := PARTITION * 0.5 + 0.02
	_dx(b, x0 - 0.05, x0, FLOOR_TOP, DOOR_TOP + 0.05, z - t, z + t, mat)
	_dx(b, x1, x1 + 0.05, FLOOR_TOP, DOOR_TOP + 0.05, z - t, z + t, mat)
	_dx(b, x0, x1, DOOR_TOP, DOOR_TOP + 0.05, z - t, z + t, mat)


## Fenster in der Rückwand: Nachtblau, Rahmen, Kreuz, Sims, zwei Gardinen. Die Außenseite ist die Fassade.
func _window(b: SlumBuilder, x: float, colors: Dictionary) -> void:
	var z := _back + WALL
	var frame := SlumMats.color(Color(0.1, 0.1, 0.11))
	var cloth := SlumMats.color(colors["cloth"], 0.0, 0.95)
	_dx(b, x - 0.62, x + 0.62, 1.05, 2.25, z, z + 0.015, SlumMats.color(Color(0.12, 0.2, 0.34), 1.0))
	_dx(b, x - 0.72, x + 0.72, 1.0, 1.05, z, z + 0.1, SlumMats.color(colors["trim"], 0.0, 0.6))
	_dx(b, x - 0.68, x + 0.68, 2.25, 2.3, z, z + 0.05, frame)
	_dx(b, x - 0.68, x - 0.62, 1.05, 2.25, z, z + 0.05, frame)
	_dx(b, x + 0.62, x + 0.68, 1.05, 2.25, z, z + 0.05, frame)
	_dx(b, x - 0.02, x + 0.02, 1.05, 2.25, z, z + 0.04, frame)
	_dx(b, x - 0.62, x + 0.62, 1.63, 1.67, z, z + 0.04, frame)
	_dx(b, x - 0.78, x - 0.46, 0.98, 2.32, z + 0.06, z + 0.095, cloth)
	_dx(b, x + 0.46, x + 0.78, 0.98, 2.32, z + 0.06, z + 0.095, cloth)
	_dx(b, x - 0.84, x + 0.84, 2.34, 2.37, z + 0.05, z + 0.08, _steel())


func _furnish(b: SlumBuilder, colors: Dictionary) -> void:
	_kitchen(b, colors)
	_living(b, colors)
	_bedroom(b, colors)
	_bath(b)
	_hall(b, colors)


func _kitchen(b: SlumBuilder, colors: Dictionary) -> void:
	var half := PARTITION * 0.5
	var x0 := _bed_wall + half
	var x1 := _bath_wall - half - 0.8
	var z0 := _back + WALL
	var z1 := z0 + 0.6
	var wood := SlumMats.surface("wood", colors["cloth"].lerp(Color(0.5, 0.45, 0.4), 0.6))
	var top := SlumMats.color(Color(0.1, 0.1, 0.11), 0.0, 0.35)
	var white := SlumMats.color(Color(0.72, 0.74, 0.75), 0.0, 0.5)
	var pot := SlumMats.color(Color(0.2, 0.21, 0.23), 0.0, 0.4, 0.6)
	_mark("Kitchen", _at((x0 + x1) * 0.5, 0.5, z0 + 0.3))
	_bx(b, x0, x1, FLOOR_TOP, 0.92, z0, z1, wood)
	_dx(b, x0, x1, 0.92, 0.97, z0, z1 + 0.03, top)
	# Herd mit Topf, Spüle mit Hahn und Abtropfgestell.
	var stove := x0 + 0.45
	_dx(b, stove - 0.3, stove + 0.3, 0.97, 0.98, z0 + 0.03, z1 - 0.03, SlumMats.color(Color(0.04, 0.04, 0.05)))
	for dx: float in [-0.14, 0.14]:
		for dz: float in [-0.13, 0.13]:
			b.cylinder_x(Transform3D(Basis.IDENTITY, _at(stove + dx, 0.985, z0 + 0.3 + dz)), 0.08, 0.01,
					SlumMats.color(Color(0.5, 0.12, 0.08), 0.6), 8, false, false)
	b.cylinder_x(Transform3D(Basis.IDENTITY, _at(stove - 0.14, 1.06, z0 + 0.17)), 0.1, 0.16, pot, 8, false, false)
	_dx(b, stove - 0.28, stove - 0.2, 1.0, 1.03, z0 + 0.15, z0 + 0.19, pot)
	var sink := x1 - 0.4
	_dx(b, sink - 0.24, sink + 0.24, 0.97, 0.985, z0 + 0.1, z1 - 0.1, _steel())
	b.tube(_at(sink, 0.97, z0 + 0.06), _at(sink, 1.2, z0 + 0.06), 0.012, _steel(), 4, false)
	b.tube(_at(sink, 1.2, z0 + 0.06), _at(sink, 1.2, z0 + 0.22), 0.012, _steel(), 4, false)
	# Türen und Griffe der Unterschränke.
	var x := x0 + 0.05
	while x + 0.5 <= x1:
		_dx(b, x, x + 0.48, 0.14, 0.88, z1, z1 + 0.005, wood)
		_dx(b, x + 0.18, x + 0.3, 0.8, 0.82, z1 + 0.005, z1 + 0.02, _steel())
		x += 0.52
	# Abzugshaube mit Oberschrank über dem Herd, so schmal, dass das Fenster frei bleibt.
	_dx(b, x0, x0 + 0.72, 1.55, 2.25, z0, z0 + 0.34, wood)
	_dx(b, x0 + 0.04, x0 + 0.68, 1.5, 1.55, z0 + 0.02, z0 + 0.4, _steel())
	_dx(b, x0 + 0.1, x0 + 0.62, 1.1, 1.5, z0 + 0.34, z0 + 0.35, wood)
	_dx(b, x0 + 0.3, x0 + 0.42, 0.97, 1.03, z0 + 0.34, z0 + 0.35, SlumMats.color(Color(0.7, 0.2, 0.15)))
	# Kühlschrank zwischen Küchenzeile und Badwand.
	var fx0 := _bath_wall - half - 0.7
	var fx1 := _bath_wall - half - 0.05
	_mark("Fridge", _at((fx0 + fx1) * 0.5, 0.9, z0 + 0.33))
	_bx(b, fx0, fx1, FLOOR_TOP, 1.9, z0, z0 + 0.66, white)
	_dx(b, fx0 + 0.02, fx1 - 0.02, 1.24, 1.26, z0 + 0.66, z0 + 0.67, SlumMats.color(Color(0.2, 0.2, 0.22)))
	_dx(b, fx0 + 0.08, fx0 + 0.11, 0.7, 1.15, z0 + 0.67, z0 + 0.69, _steel())
	_dx(b, fx0 + 0.08, fx0 + 0.11, 1.32, 1.65, z0 + 0.67, z0 + 0.69, _steel())
	# Mikrowelle auf dem Kühlschrank.
	var mw := (fx0 + fx1) * 0.5
	_dx(b, mw - 0.25, mw + 0.25, 1.9, 2.12, z0 + 0.1, z0 + 0.5, SlumMats.color(Color(0.17, 0.18, 0.2), 0.0, 0.4, 0.4))
	_dx(b, mw - 0.21, mw + 0.05, 1.93, 2.09, z0 + 0.5, z0 + 0.51, SlumMats.glass(Color(0.1, 0.12, 0.14, 0.9)))


func _living(b: SlumBuilder, colors: Dictionary) -> void:
	var half := PARTITION * 0.5
	var cloth := SlumMats.color(colors["cloth"], 0.0, 0.95)
	var dark := SlumMats.color(colors["trim"], 0.0, 0.6)
	var wood := SlumMats.surface("wood_dark", Color(0.8, 0.72, 0.65))
	var x0 := _bed_wall + half
	var z0 := _sofa_z()
	var z1 := z0 + 1.75
	# Sofa an der Schlafzimmerwand, Blick nach +X zum Fernseher.
	_mark("Sofa", _at(x0 + 0.42, 0.35, (z0 + z1) * 0.5))
	_bx(b, x0, x0 + 0.88, FLOOR_TOP, 0.42, z0, z1, cloth)
	_bx(b, x0, x0 + 0.22, 0.42, 0.9, z0, z1, cloth)
	_bx(b, x0, x0 + 0.88, 0.42, 0.64, z0, z0 + 0.16, cloth)
	_bx(b, x0, x0 + 0.88, 0.42, 0.64, z1 - 0.16, z1, cloth)
	for cushion: int in 2:
		var c0 := z0 + 0.2 + cushion * 0.7
		_dx(b, x0 + 0.24, x0 + 0.38, 0.45, 0.8, c0, c0 + 0.64, dark)
	_dx(b, x0 + 0.24, x0 + 0.86, 0.42, 0.47, z0 + 0.16, z1 - 0.16, cloth)
	_dx(b, x0 + 0.5, x0 + 0.72, 0.47, 0.68, z0 + 0.2, z0 + 0.5, SlumMats.color(colors["neon"].darkened(0.5), 0.0, 0.9))
	# Teppich und Couchtisch zwischen Sofa und Fernseher.
	var cx := x0 + 1.5
	var cz := (z0 + z1) * 0.5
	_dx(b, cx - 0.85, cx + 0.85, FLOOR_TOP, FLOOR_TOP + 0.012, cz - 1.0, cz + 1.0,
			SlumMats.color(colors["cloth"].darkened(0.4), 0.0, 1.0))
	_dx(b, cx - 0.85, cx - 0.82, FLOOR_TOP, FLOOR_TOP + 0.014, cz - 1.0, cz + 1.0, SlumMats.color(colors["neon"].darkened(0.3), 0.0, 1.0))
	_dx(b, cx + 0.82, cx + 0.85, FLOOR_TOP, FLOOR_TOP + 0.014, cz - 1.0, cz + 1.0, SlumMats.color(colors["neon"].darkened(0.3), 0.0, 1.0))
	_mark("Table", _at(cx, 0.3, cz))
	_bx(b, cx - 0.28, cx + 0.28, 0.4, 0.44, cz - 0.5, cz + 0.5, wood)
	for sx: float in [-0.24, 0.24]:
		for sz: float in [-0.44, 0.44]:
			_dx(b, cx + sx - 0.03, cx + sx + 0.03, FLOOR_TOP, 0.4, cz + sz - 0.03, cz + sz + 0.03, dark)
	_dx(b, cx - 0.12, cx + 0.12, 0.44, 0.47, cz - 0.38, cz - 0.14, SlumMats.color(Color(0.8, 0.8, 0.75), 0.0, 0.9))
	# Fernsehbank an der Badwand, die Kühlschrankseite bleibt frei.
	var tv := _tv_z()
	var tx := _bath_wall - half
	_bx(b, tx - 0.42, tx, FLOOR_TOP, 0.5, tv - 0.62, tv + 0.62, wood)
	_dx(b, tx - 0.435, tx - 0.42, 0.16, 0.46, tv - 0.58, tv - 0.02, dark)
	_dx(b, tx - 0.435, tx - 0.42, 0.16, 0.46, tv + 0.02, tv + 0.58, dark)
	_dx(b, tx - 0.44, tx - 0.435, 0.46, 0.48, tv - 0.6, tv + 0.6, SlumMats.color(colors["neon"], 1.5))
	# Bücherregal an der Frontwand.
	var inner := _front - WALL
	var shelf := SlumMats.surface("wood", Color(0.7, 0.6, 0.5))
	var bx0 := _bed_wall + 0.55
	var bx1 := bx0 + 0.95
	_bx(b, bx0, bx1, FLOOR_TOP, 1.85, inner - 0.3, inner, shelf)
	for level: int in 4:
		var y := 0.45 + level * 0.36
		_dx(b, bx0 + 0.03, bx1 - 0.03, y, y + 0.025, inner - 0.3, inner - 0.28, dark)
		var x := bx0 + 0.06
		var i := 0
		while x + 0.07 < bx1 - 0.05 and level < 3:
			var h := 0.2 + 0.05 * float((i * 7 + level * 3) % 4)
			var c: Color = [colors["cloth"], Color(0.25, 0.4, 0.55), Color(0.7, 0.62, 0.3), Color(0.3, 0.5, 0.35)][(i + level) % 4]
			_dx(b, x, x + 0.06, y + 0.025, y + 0.025 + h, inner - 0.26, inner - 0.04, SlumMats.color(c, 0.0, 0.9))
			x += 0.075
			i += 1
	# Pflanze in der Ecke zwischen Bücherregal und Flur, Stehlampe neben dem Sofa.
	_plant(b, _bath_wall - 0.5, inner - 0.35, 1.0)
	var lamp := _at(x0 + 0.25, FLOOR_TOP, z1 + 0.25)
	b.tube(lamp, lamp + Vector3.UP * 1.5, 0.015, _steel(), 4, false)
	_dx(b, x0 + 0.13, x0 + 0.37, 1.5, 1.74, z1 + 0.13, z1 + 0.37, SlumMats.color(colors["light"], 2.0))


## Topfpflanze mit Stamm und Blattkränzen.
func _plant(b: SlumBuilder, x: float, z: float, height: float) -> void:
	var pot := SlumMats.color(Color(0.45, 0.25, 0.18), 0.0, 0.9)
	var leaf := SlumMats.color(Color(0.18, 0.45, 0.25), 0.0, 0.9)
	b.cylinder_x(Transform3D(Basis.IDENTITY, _at(x, FLOOR_TOP + 0.17, z)), 0.2, 0.34, pot, 8, true, true)
	b.cylinder_x(Transform3D(Basis.IDENTITY, _at(x, FLOOR_TOP + 0.345, z)), 0.17, 0.02, SlumMats.color(Color(0.12, 0.08, 0.06)), 8, false, false)
	b.tube(_at(x, FLOOR_TOP + 0.3, z), _at(x, FLOOR_TOP + height * 0.8, z), 0.02, SlumMats.color(Color(0.3, 0.2, 0.12)), 4, false)
	for tier: int in 3:
		var y := FLOOR_TOP + height * (0.45 + tier * 0.17)
		for i: int in 5:
			var a := i * TAU / 5.0 + tier * 0.6
			var d := _dir(cos(a), sin(a))
			var basis := Basis(Vector3.UP, atan2(-d.z, d.x)) * Basis(Vector3.BACK, 0.5)
			b.box_x(Transform3D(basis, _at(x, y, z) + d * 0.13), Vector3(0.3, 0.015, 0.08), leaf, false, false)


func _sofa_z() -> float:
	return _back + WALL + 1.0


func _tv_z() -> float:
	return _sofa_z() + 0.875


func _bedroom(b: SlumBuilder, colors: Dictionary) -> void:
	var cloth := SlumMats.color(colors["cloth"], 0.0, 0.95)
	var dark := SlumMats.color(colors["trim"], 0.0, 0.6)
	var wood := SlumMats.surface("wood_dark", Color(0.85, 0.75, 0.68))
	var sheet := SlumMats.color(Color(0.8, 0.78, 0.75), 0.0, 0.95)
	var x0 := _left + WALL
	var z0 := _back + WALL
	var inner := _front - WALL
	# Bett mit Kopfteil an der linken Wand, Decke und zwei Kissen.
	_mark("Bed", _at(x0 + 1.0, 0.3, z0 + 0.75))
	_bx(b, x0, x0 + 1.95, FLOOR_TOP, 0.3, z0, z0 + 1.5, dark)
	_dx(b, x0 + 0.03, x0 + 1.92, 0.3, 0.48, z0 + 0.03, z0 + 1.47, sheet)
	_dx(b, x0 + 0.65, x0 + 1.94, 0.48, 0.53, z0 + 0.02, z0 + 1.48, cloth)
	_dx(b, x0 + 1.5, x0 + 1.95, 0.48, 0.54, z0 + 0.02, z0 + 1.48, SlumMats.color(colors["neon"].darkened(0.5), 0.0, 0.9))
	_bx(b, x0, x0 + 0.08, FLOOR_TOP, 1.05, z0, z0 + 1.5, dark)
	_dx(b, x0 + 0.1, x0 + 0.55, 0.48, 0.6, z0 + 0.14, z0 + 0.66, sheet)
	_dx(b, x0 + 0.1, x0 + 0.55, 0.48, 0.6, z0 + 0.84, z0 + 1.36, sheet)
	# Nachttisch mit Lampe.
	var n0 := x0 + 2.0
	_mark("Nightstand", _at(n0 + 0.22, 0.3, z0 + 0.22))
	_bx(b, n0, n0 + 0.44, FLOOR_TOP, 0.55, z0, z0 + 0.44, wood)
	_dx(b, n0 + 0.04, n0 + 0.4, 0.3, 0.32, z0 + 0.44, z0 + 0.45, dark)
	b.cylinder_x(Transform3D(Basis.IDENTITY, _at(n0 + 0.34, 0.62, z0 + 0.1)), 0.05, 0.14, _steel(), 6, false, false)
	_dx(b, n0 + 0.27, n0 + 0.41, 0.69, 0.8, z0 + 0.03, z0 + 0.17, SlumMats.color(colors["light"], 1.5))
	# Schreibtisch an der linken Wand, Stuhl davor.
	var d0 := z0 + 1.75
	_mark("Desk", _at(x0 + 0.35, 0.4, d0 + 0.65))
	_bx(b, x0, x0 + 0.7, 0.72, 0.77, d0, d0 + 1.3, wood)
	for dz: float in [0.03, 1.27]:
		_dx(b, x0 + 0.05, x0 + 0.65, FLOOR_TOP, 0.72, d0 + dz - 0.02, d0 + dz + 0.02, dark)
	_dx(b, x0 + 0.05, x0 + 0.65, 0.35, 0.72, d0 + 1.25, d0 + 1.29, dark)
	_bx(b, x0 + 0.85, x0 + 1.27, 0.48, 0.53, d0 + 0.45, d0 + 0.87, cloth)
	_dx(b, x0 + 1.23, x0 + 1.28, 0.53, 0.98, d0 + 0.45, d0 + 0.87, cloth)
	b.tube(_at(x0 + 1.06, FLOOR_TOP, d0 + 0.66), _at(x0 + 1.06, 0.48, d0 + 0.66), 0.03, _steel(), 6, false)
	# Kleiderschrank mit zwei Türen an der Frontwand, Wäschekorb daneben.
	var w0 := x0 + 1.15
	var w1 := w0 + 1.2
	_mark("Wardrobe", _at((w0 + w1) * 0.5, 1.0, inner - 0.3))
	_bx(b, w0, w1, FLOOR_TOP, 2.1, inner - 0.6, inner, wood)
	var mid := (w0 + w1) * 0.5
	_dx(b, mid - 0.006, mid + 0.006, 0.14, 2.05, inner - 0.605, inner - 0.6, dark)
	_dx(b, w0 + 0.03, w1 - 0.03, 2.05, 2.1, inner - 0.605, inner - 0.6, dark)
	for side: float in [-0.09, 0.09]:
		_dx(b, mid + side - 0.012, mid + side + 0.012, 1.0, 1.25, inner - 0.63, inner - 0.6, _steel())
	b.cylinder_x(Transform3D(Basis.IDENTITY, _at(w0 - 0.35, FLOOR_TOP + 0.25, inner - 0.3)), 0.24, 0.5,
			SlumMats.color(Color(0.6, 0.55, 0.45), 0.0, 0.95), 8, false, true)
	# Teppich vor dem Bett, Spiegel an der Wand, Poster über dem Schreibtisch.
	_dx(b, x0 + 2.1, x0 + 3.2, FLOOR_TOP, FLOOR_TOP + 0.012, z0 + 0.6, z0 + 1.9, SlumMats.color(colors["cloth"].darkened(0.5), 0.0, 1.0))
	_wall_decal(b, _at(x0 + 0.01, 1.6, d0 - 0.4), Vector3.RIGHT, 0.5, 0.75, SlumMats.decal("poster_%d" % (1 + theme)))


func _bath(b: SlumBuilder) -> void:
	var porcelain := SlumMats.color(Color(0.82, 0.84, 0.84), 0.0, 0.3)
	var half := PARTITION * 0.5
	var z0 := _back + WALL
	var x0 := _bath_wall + half
	var x1 := _right - WALL
	# WC an der Rückwand, mit Spülkasten und Deckel.
	var tx := x0 + 0.46
	_mark("Toilet", _at(tx, 0.3, z0 + 0.4))
	_bx(b, tx - 0.19, tx + 0.19, FLOOR_TOP, 0.44, z0 + 0.18, z0 + 0.66, porcelain)
	_dx(b, tx - 0.21, tx + 0.21, 0.44, 0.47, z0 + 0.16, z0 + 0.68, porcelain)
	_bx(b, tx - 0.22, tx + 0.22, 0.47, 0.82, z0 + 0.02, z0 + 0.18, porcelain, false)
	_dx(b, tx - 0.03, tx + 0.03, 0.82, 0.85, z0 + 0.06, z0 + 0.12, _steel())
	# Waschtisch mit Spiegelschrank und Leuchte.
	var sx := x0 + 1.14
	_mark("Sink", _at(sx, 0.5, z0 + 0.25))
	_bx(b, sx - 0.32, sx + 0.32, 0.72, 0.9, z0, z0 + 0.46, porcelain)
	b.tube(_at(sx, FLOOR_TOP, z0 + 0.22), _at(sx, 0.72, z0 + 0.22), 0.04, porcelain, 6, false)
	b.tube(_at(sx, 0.9, z0 + 0.08), _at(sx, 1.02, z0 + 0.08), 0.012, _steel(), 4, false)
	_dx(b, sx - 0.3, sx + 0.3, 1.2, 1.75, z0 + 0.016, z0 + 0.03, SlumMats.color(Color(0.5, 0.58, 0.62), 0.0, 0.08, 0.9))
	_dx(b, sx - 0.33, sx + 0.33, 1.17, 1.2, z0 + 0.016, z0 + 0.04, _steel())
	_dx(b, sx - 0.33, sx + 0.33, 1.75, 1.78, z0 + 0.016, z0 + 0.04, _steel())
	_dx(b, sx - 0.3, sx + 0.3, 1.8, 1.84, z0 + 0.02, z0 + 0.09, SlumMats.color(Color(0.9, 0.95, 1.0), 2.5))
	# Dusche in der Ecke: Wanne, Glas, Brause an der Stange, Shampoo.
	var s0 := x1 - 0.85
	var sz := z0 + 0.95
	_mark("Shower", _at((s0 + x1) * 0.5, 0.2, z0 + 0.43))
	_dx(b, s0, x1, FLOOR_TOP, 0.16, z0, sz, porcelain)
	var glass := SlumMats.glass(Color(0.6, 0.85, 1.0, 0.2))
	_bx(b, s0, x1, 0.16, 2.0, sz - 0.015, sz, glass, true, false)
	_bx(b, s0 - 0.015, s0, 0.16, 2.0, z0, sz, glass, true, false)
	_dx(b, s0 - 0.02, x1, 1.98, 2.02, sz - 0.02, sz + 0.005, _steel())
	_dx(b, s0 - 0.02, s0 + 0.005, 1.98, 2.02, z0, sz, _steel())
	var rod := _at(x1 - 0.08, 0.7, z0 + 0.4)
	b.tube(rod, _at(x1 - 0.08, 1.9, z0 + 0.4), 0.012, _steel(), 4, false)
	_dx(b, x1 - 0.2, x1 - 0.04, 1.86, 1.9, z0 + 0.32, z0 + 0.48, _steel())
	_dx(b, x1 - 0.2, x1 - 0.14, FLOOR_TOP + 0.06, 0.4, z0 + 0.1, z0 + 0.18, SlumMats.color(Color(0.8, 0.4, 0.15)))
	_dx(b, x1 - 0.3, x1 - 0.24, FLOOR_TOP + 0.06, 0.34, z0 + 0.1, z0 + 0.18, SlumMats.color(Color(0.3, 0.6, 0.7)))
	# Waschmaschine an der rechten Wand: Trommelfenster und Knöpfe zeigen nach links.
	var wz := z0 + 1.5
	var wm := SlumMats.color(Color(0.8, 0.82, 0.83), 0.0, 0.4)
	_bx(b, x1 - 0.6, x1, FLOOR_TOP, 0.95, wz, wz + 0.6, wm)
	_dx(b, x1 - 0.61, x1 - 0.6, 0.3, 0.7, wz + 0.1, wz + 0.5, SlumMats.color(Color(0.1, 0.13, 0.17), 0.0, 0.1, 0.5))
	_dx(b, x1 - 0.62, x1 - 0.61, 0.38, 0.62, wz + 0.18, wz + 0.42, SlumMats.glass(Color(0.4, 0.55, 0.7, 0.6)))
	_dx(b, x1 - 0.61, x1 - 0.6, 0.78, 0.9, wz + 0.1, wz + 0.5, SlumMats.color(Color(0.25, 0.27, 0.3)))
	# Handtuchhaken und Handtuch an der Wand zum Flur, Bodenmatte.
	_dx(b, x0 + 0.01, x0 + 0.03, 0.9, 1.5, z0 + 1.3, z0 + 1.7, SlumMats.color(Color(0.3, 0.55, 0.55), 0.0, 0.95))
	_dx(b, x0 + 0.01, x0 + 0.04, 1.5, 1.54, z0 + 1.3, z0 + 1.7, _steel())
	_dx(b, _bath_door_x - 0.35, _bath_door_x + 0.35, FLOOR_TOP, FLOOR_TOP + 0.012, _bath_front - 0.7, _bath_front - 0.15,
			SlumMats.color(Color(0.55, 0.3, 0.4), 0.0, 1.0))


func _hall(b: SlumBuilder, colors: Dictionary) -> void:
	var inner := _front - WALL
	var x1 := _right - WALL
	var wood := SlumMats.surface("wood_dark", Color(0.85, 0.75, 0.68))
	var jacket := SlumMats.color(colors["cloth"].darkened(0.3), 0.0, 0.95)
	# Schuhregal mit Schuhen, Garderobe mit Jacken an der rechten Wand, Spiegel darüber.
	var z0 := _bath_front + 0.35
	_bx(b, x1 - 0.3, x1, FLOOR_TOP, 0.42, z0, z0 + 0.9, wood)
	_dx(b, x1 - 0.3, x1, 0.26, 0.28, z0, z0 + 0.9, SlumMats.color(colors["trim"]))
	for i: int in 3:
		_dx(b, x1 - 0.22, x1 - 0.06, 0.28, 0.36, z0 + 0.1 + i * 0.27, z0 + 0.3 + i * 0.27, SlumMats.color(Color(0.1, 0.1, 0.12), 0.0, 0.8))
	_dx(b, x1 - 0.03, x1, 1.65, 1.75, z0, z0 + 0.9, wood)
	for i: int in 4:
		var hook := z0 + 0.12 + i * 0.22
		_dx(b, x1 - 0.1, x1, 1.58, 1.62, hook - 0.01, hook + 0.01, _steel())
	_dx(b, x1 - 0.12, x1 - 0.02, 0.95, 1.58, z0 + 0.1, z0 + 0.32, jacket)
	_dx(b, x1 - 0.1, x1 - 0.02, 1.05, 1.58, z0 + 0.56, z0 + 0.76, SlumMats.color(Color(0.3, 0.32, 0.36), 0.0, 0.95))
	_dx(b, x1 - 0.015, x1, 1.0, 1.55, z0 + 0.95, z0 + 1.35, SlumMats.color(Color(0.5, 0.58, 0.62), 0.0, 0.08, 0.9))
	# Fußmatte hinter der Tür, Schirmständer daneben.
	_dx(b, _door_x - 0.42, _door_x + 0.42, FLOOR_TOP, FLOOR_TOP + 0.012, inner - 0.75, inner - 0.1, SlumMats.color(Color(0.16, 0.12, 0.09), 0.0, 1.0))
	b.cylinder_x(Transform3D(Basis.IDENTITY, _at(_door_x - 0.8, FLOOR_TOP + 0.25, inner - 0.2)), 0.1, 0.5,
			SlumMats.color(Color(0.18, 0.2, 0.24), 0.0, 0.5, 0.4), 8, false, true)
	# Pflanze neben der Badtür, Poster in Flur und Wohnküche.
	_plant(b, x1 - 0.35, inner - 0.35, 1.25)
	_wall_decal(b, _at(_bed_wall + PARTITION * 0.5 + 0.01, 1.5, _sofa_z() + 0.9), Vector3.RIGHT, 0.55, 0.8,
			SlumMats.decal("poster_%d" % (2 + theme)))


func _place_loot(rng: RandomNumberGenerator) -> void:
	var x0 := _left + WALL
	var z0 := _back + WALL
	var inner := _front - WALL
	var half := PARTITION * 0.5
	var table_x := _bed_wall + half + 1.5
	var desk := z0 + 1.75
	_loot("Schmuck", JEWELRY, _at(x0 + 2.22, 0.55, z0 + 0.22), false, &"Jewelry")
	_loot("Juwelen", JEWELS, _at(table_x, 0.44, _sofa_z() + 0.875), true, &"Jewels")
	_loot("Bargeld", CASH, _at(_bed_wall + 1.3, 0.97, z0 + 0.3), false, &"Cash")
	_loot("Fernseher", TV, _at(_bath_wall - half - 0.21, 0.5, _tv_z()), false, &"Television")
	(get_node(^"%Television") as Node3D).rotation.y = PI * 0.5 * -_flip
	_loot("Bild", ART, _at(x0 + 0.05, 1.35, desk + 0.65), false, &"Artwork")
	(get_node(^"%Artwork") as Node3D).rotation.y = PI * 0.5 * _flip
	_loot("Computer", PC, _at(x0 + 0.35, 0.77, desk + 0.3), false, &"Computer")
	_loot("Handy", PHONE, _at(x0 + 0.35, 0.77, desk + 0.95), false, &"Phone")
	var safe := SAFE_PROP.new()
	safe.name = "Safe"
	safe.unique_name_in_owner = true
	safe.prompt_name = "Tresor"
	safe.item = CASH
	safe.count = rng.randi_range(2, 4)
	safe.sealed = true
	safe.position = _at(_bed_wall - 0.5, FLOOR_TOP, z0 + 0.34)
	add_child(safe)
	safe.owner = self


func _spawn_residents(count: int) -> void:
	# Bewohner sind Spiel-Logik. Im Editor baut slum_building.gd (@tool) den Block per .new(), dann
	# liefe CivilianCrime echt und riefe das Platzhalter-Autoload WorldSync auf.
	if Engine.is_editor_hint():
		return
	var spots: Array[Vector3] = [
		_at(_bed_wall + 1.5, FLOOR_TOP + 0.02, _bath_front + 1.0),
		_at(_left + 2.4, FLOOR_TOP + 0.02, _back + WALL + 2.7),
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
	_omni(_at(living, y, 0.0), colors["light"], 1.3)
	_omni(_at(bedroom, y, 0.0), colors["light"], 1.0)
	_omni(_at(bath, y, (_back + _bath_front) * 0.5), Color(0.9, 0.95, 1.0), 0.9)
	var b := SlumBuilder.new(_interior)
	b.solid_range = VIEW_RANGE
	var shade := SlumMats.color(colors["light"], 3.0)
	for x: float in [living, bedroom]:
		_bx(b, x - 0.22, x + 0.22, ROOM_TOP - 0.1, ROOM_TOP, -0.22, 0.22, shade, false, false)
	_bx(b, bath - 0.2, bath + 0.2, ROOM_TOP - 0.08, ROOM_TOP, (_back + _bath_front) * 0.5 - 0.2,
			(_back + _bath_front) * 0.5 + 0.2, SlumMats.color(Color(0.9, 0.95, 1.0), 3.0), false, false)
	_bx(b, _door_x - 0.2, _door_x + 0.2, ROOM_TOP - 0.08, ROOM_TOP, _front - 1.0, _front - 0.6, shade, false, false)
	b.finish()


func _omni(at: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 5.5
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 30.0
	light.distance_fade_length = 8.0
	_interior.add_child(light)


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
