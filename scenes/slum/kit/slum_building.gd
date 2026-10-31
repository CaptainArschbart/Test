@tool
class_name SlumBuilding
extends SlumPiece
## Gebäude aus dem Mapkit: Wohnblock, Laden, Lagerhalle, Shanty-Hütte auf Stelzen, Hochhaus.
##
## Ursprung = Bodenmitte der Grundfläche, Vorderseite (Eingang, Schild) zeigt nach +Z.
## Wohnblöcke können eine Außentreppe bis aufs Dach haben (Stufen 0,2 m, Stufe für Stufe begehbar),
## Läden und Lagerhallen sind im Erdgeschoss begehbar.

enum Style { RESIDENTIAL, SHOP, WAREHOUSE, SHANTY, TOWER }
enum Side { NONE, LEFT, RIGHT }

@export var style := Style.RESIDENTIAL:
	set(v):
		style = v
		queue_rebuild()
## Breite (x) und Tiefe (z) in Metern.
@export var footprint := Vector2(10, 8):
	set(v):
		footprint = v
		queue_rebuild()
@export_range(1, 30) var floors := 4:
	set(v):
		floors = v
		queue_rebuild()
@export var floor_height := 3.0:
	set(v):
		floor_height = v
		queue_rebuild()
## Wandtextur (Name in assets/textures/slum/, z. B. concrete, brick, plaster_teal, corrugated_blue).
@export var wall := "concrete":
	set(v):
		wall = v
		queue_rebuild()
## Erdgeschoss-Textur, leer = wie die Wand.
@export var ground_wall := "":
	set(v):
		ground_wall = v
		queue_rebuild()
@export var wall_tint := Color.WHITE:
	set(v):
		wall_tint = v
		queue_rebuild()
## Anteil beleuchteter Fenster.
@export_range(0.0, 1.0) var lit_ratio := 0.35:
	set(v):
		lit_ratio = v
		queue_rebuild()
## Hausnummer als Schablone an der Front (leer = keine). Erlaubt: 07, A2.
@export var number := "":
	set(v):
		number = v
		queue_rebuild()
## Schild über dem Eingang / Laden (Texturname, z. B. sign_bar, sign_shop, sign_ramen).
@export var front_sign := "":
	set(v):
		front_sign = v
		queue_rebuild()
## Laden: Höhe des Ladenbodens. 0,15 = bündig mit dem Gehweg davor, 0 = Straße direkt vor der Tür.
## Eine Schwelle in der Türöffnung schließt an den Boden davor an, damit keine Kante bleibt.
@export var floor_level := 0.15:
	set(v):
		floor_level = v
		queue_rebuild()
## Senkrechtes Schild an der Ecke (z. B. sign_hotel, sign_pharmacy).
@export var side_sign := "":
	set(v):
		side_sign = v
		queue_rebuild()
## Außentreppe bis aufs Dach (nur Wohnblock).
@export var stair_side := Side.NONE:
	set(v):
		stair_side = v
		queue_rebuild()
@export_range(0.0, 1.0) var balcony_chance := 0.25:
	set(v):
		balcony_chance = v
		queue_rebuild()
## Klimageräte, Wassertank, Antennen und Hütte auf dem Dach.
@export var rooftop_clutter := true:
	set(v):
		rooftop_clutter = v
		queue_rebuild()
## Shanty: Höhe der Plattform über dem Boden (0 = Hütte am Boden).
@export var stilt_height := 2.4:
	set(v):
		stilt_height = v
		queue_rebuild()
## Shanty: Seite der Treppe zur Plattform.
@export var shanty_stair := Side.RIGHT:
	set(v):
		shanty_stair = v
		queue_rebuild()
## Shanty: Seite ohne Geländer, z. B. wo ein Steg (SlumWalkway) andockt. Nicht die Treppenseite.
@export var open_left := false:
	set(v):
		open_left = v
		queue_rebuild()
@export var open_right := false:
	set(v):
		open_right = v
		queue_rebuild()
## Erdgeschoss hohl, zwei Stockwerke mit je zwei Wohnungen, Flur und Treppe.
@export var walk_in_apartments := false:
	set(v):
		walk_in_apartments = v
		queue_rebuild()

## Abstand der Decals vor der Wand. Jede Art hat einen eigenen Abstand, damit überlappende Decals
## nicht in derselben Ebene liegen (Z-Fighting). Mindestens 2 cm, sonst flackert es auf Entfernung.
const DECAL_OPENING := 0.025  # Fenster, Türen, Gerätefronten, Schilder vor ihrem Rahmen
const DECAL_VENT := 0.035
const DECAL_STENCIL := 0.04
const DECAL_GRAFFITI := 0.045
const DECAL_TAG := 0.05
const DECAL_POSTER := 0.055

const ShopInteriorScript := preload("res://scenes/interact/shop_interior.gd")
const ApartmentHouseScript := preload("res://scenes/crime/apartment_house.gd")

var _w := 10.0
var _d := 8.0
var _h := 12.0
var _wall_mat: Material
var _trim_mat: Material
var _metal: Material
var _dark_metal: Material


func _build(b: SlumBuilder) -> void:
	_w = footprint.x
	_d = footprint.y
	_h = floors * floor_height
	_wall_mat = SlumMats.surface(wall, wall_tint)
	_trim_mat = SlumMats.surface("concrete_dark")
	_metal = SlumMats.color(Color(0.16, 0.17, 0.18), 0.0, 0.55, 0.6)
	_dark_metal = SlumMats.color(Color(0.07, 0.07, 0.08), 0.0, 0.6, 0.5)
	match style:
		Style.RESIDENTIAL: _residential(b)
		Style.SHOP: _shop(b)
		Style.WAREHOUSE: _warehouse(b)
		Style.SHANTY: _shanty(b)
		Style.TOWER: _tower(b)
	_add_occluder()


## Unsichtbarer Block im Inneren fürs Occlusion Culling: Was ganz dahinter steht, wird nicht
## gezeichnet. Nur massive Teile: kein begehbares Erdgeschoss (Laden), keine Lagerhalle, keine Hütte.
func _add_occluder() -> void:
	var y0 := 0.3
	match style:
		Style.RESIDENTIAL, Style.TOWER:
			if walk_in_apartments:
				return
			pass
		Style.SHOP:
			if floors < 2:
				return
			y0 = floor_height + 0.3
		_:
			return
	var top := _h - 0.2
	if top - y0 < 1.5 or _w < 2.0 or _d < 2.0:
		return
	var occ := OccluderInstance3D.new()
	occ.name = "Occluder"
	var box := BoxOccluder3D.new()
	box.size = Vector3(_w - 0.6, top - y0, _d - 0.6)
	occ.occluder = box
	add_gen(occ, Vector3(0, (y0 + top) * 0.5, 0))


# ================================================================== Wohnblock

func _residential(b: SlumBuilder) -> void:
	var ground := SlumMats.surface(ground_wall, wall_tint) if ground_wall != "" else _wall_mat
	if walk_in_apartments:
		_hollow_shell(b, ground)
	else:
		b.box(Vector3(0, floor_height * 0.5, 0), Vector3(_w, floor_height, _d), ground)
		if floors > 1:
			b.box_on(Vector3(0, floor_height + (_h - floor_height) * 0.5, 0), Vector3(_w, _h - floor_height, _d), _wall_mat)
	if not walk_in_apartments:
		_plinth(b)
	_ledges(b, 1)
	_roof(b, _gap_for_stairs())
	_facade_windows(b, 1, [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT])
	if walk_in_apartments:
		_fixed_entrance(b)
		_spawn_apartment_house()
	else:
		_ground_floor_front(b)
	_pipes(b)
	_wall_clutter(b)
	if stair_side != Side.NONE:
		_exterior_stairs(b)
	if rooftop_clutter:
		_rooftop(b)
	if number != "":
		b.quad(Vector3(-_w * 0.5 + 1.0, _h - 1.4, _d * 0.5 + DECAL_STENCIL), Vector3.BACK, 1.4, 1.05,
				SlumMats.decal("stencil_" + number.to_lower()))
	if side_sign != "":
		_vertical_sign(b, Vector3(_w * 0.5 - 0.7, minf(_h - 2.5, 7.0), _d * 0.5), side_sign)


func _hollow_shell(b: SlumBuilder, ground: Material) -> void:
	var t := 0.24
	var ymid := _h * 0.5
	b.box(Vector3(-_w * 0.5 + t * 0.5, ymid, 0), Vector3(t, _h, _d), _wall_mat)
	b.box(Vector3(_w * 0.5 - t * 0.5, ymid, 0), Vector3(t, _h, _d), _wall_mat)
	b.box(Vector3(0, ymid, -_d * 0.5 + t * 0.5), Vector3(_w, _h, t), _wall_mat)
	var gap := 1.5
	var front_z := _d * 0.5 - t * 0.5
	var side_w := (_w - gap) * 0.5
	var side_c := gap * 0.5 + side_w * 0.5
	b.box(Vector3(-side_c, ymid, front_z), Vector3(side_w, _h, t), ground)
	b.box(Vector3(side_c, ymid, front_z), Vector3(side_w, _h, t), ground)
	var lintel_h := maxf(_h - 2.6, 0.2)
	b.box(Vector3(0, 2.6 + lintel_h * 0.5, front_z), Vector3(gap + 0.08, lintel_h, t), ground)
	b.box(Vector3(0, 0.06, 0), Vector3(_w - 0.6, 0.12, _d - 0.6), _trim_mat)
	if floors > 3:
		var y0 := 3.0 * floor_height
		b.box_on(Vector3(0, y0 + (_h - y0) * 0.5, 0), Vector3(_w - 0.55, _h - y0, _d - 0.55), _wall_mat)


func _fixed_entrance(b: SlumBuilder) -> void:
	b.box(Vector3(0, 0.08, _d * 0.5 + 0.35), Vector3(1.6, 0.16, 0.7), _trim_mat)
	b.box(Vector3(0, 2.32, _d * 0.5 + 0.06), Vector3(1.7, 0.12, 0.12), _trim_mat, false)
	add_light(Vector3(0, 2.4, _d * 0.5 + 0.6), Color(0.55, 0.85, 1.0), 1.2, 6.0, 0.0)


func _spawn_apartment_house() -> void:
	var house := ApartmentHouseScript.new()
	house.name = "ApartmentHouse"
	house.set("building_width", _w)
	house.set("building_depth", _d)
	house.set("floor_height", floor_height)
	add_gen(house)


func _plinth(b: SlumBuilder) -> void:
	# Nur 1,5 cm vor der Wand: Türen und Decals (ab 2,5 cm) liegen davor, nicht in derselben Ebene.
	b.box(Vector3(0, 0.25, 0), Vector3(_w + 0.03, 0.5, _d + 0.03), _trim_mat, false)


func _ledges(b: SlumBuilder, from_floor: int) -> void:
	for f: int in range(from_floor, floors):
		b.box(Vector3(0, f * floor_height, 0), Vector3(_w + 0.24, 0.16, _d + 0.24), _trim_mat, false)


## Dach mit Brüstung. gap = [Seite, z_von, z_bis] lässt eine Lücke für die Außentreppe.
func _roof(b: SlumBuilder, gap: Array) -> void:
	var tar := SlumMats.surface("roof_tar")
	b.box_on(Vector3(0, _h + 0.03, 0), Vector3(_w - 0.1, 0.06, _d - 0.1), tar)
	var ph := 0.9
	var t := 0.22
	var y := _h + ph * 0.5
	b.box_on(Vector3(0, y, _d * 0.5 - t * 0.5), Vector3(_w, ph, t), _wall_mat)
	b.box_on(Vector3(0, y, -_d * 0.5 + t * 0.5), Vector3(_w, ph, t), _wall_mat)
	for side: float in [-1.0, 1.0]:
		var x := side * (_w * 0.5 - t * 0.5)
		if not gap.is_empty() and gap[0] == side:
			var z0: float = gap[1]
			var z1: float = gap[2]
			_wall_z(b, x, -_d * 0.5 + t, z0, y, ph, t)
			_wall_z(b, x, z1, _d * 0.5 - t, y, ph, t)
		else:
			b.box_on(Vector3(x, y, 0), Vector3(t, ph, _d - 2 * t), _wall_mat)
	# Abdeckung der Brüstung
	b.box(Vector3(0, _h + ph + 0.04, _d * 0.5 - t * 0.5), Vector3(_w + 0.06, 0.08, t + 0.08), _trim_mat, false)
	b.box(Vector3(0, _h + ph + 0.04, -_d * 0.5 + t * 0.5), Vector3(_w + 0.06, 0.08, t + 0.08), _trim_mat, false)


func _wall_z(b: SlumBuilder, x: float, z0: float, z1: float, y: float, h: float, t: float) -> void:
	if z1 - z0 < 0.05:
		return
	b.box_on(Vector3(x, y, (z0 + z1) * 0.5), Vector3(t, h, z1 - z0), _wall_mat)


func _window_mat() -> Material:
	var r := rng.randf()
	if r < lit_ratio:
		var warm: Color = pick([Color(1.0, 0.75, 0.45), Color(1.0, 0.6, 0.35), Color(0.7, 0.85, 1.0), Color(1.0, 0.45, 0.7)])
		return SlumMats.decal(pick(["window_lit", "window_lit2"]), "window_emit", warm, 1.6)
	if r < lit_ratio + 0.2:
		return SlumMats.decal("window_bars")
	return SlumMats.decal("window_dark")


## Fensterraster auf den angegebenen Seiten ab Stockwerk from_floor.
func _facade_windows(b: SlumBuilder, from_floor: int, sides: Array) -> void:
	var stair_x := 0.0
	if stair_side == Side.LEFT:
		stair_x = -1.0
	elif stair_side == Side.RIGHT:
		stair_x = 1.0
	for n: Vector3 in sides:
		if n.x != 0.0 and n.x == stair_x:
			continue
		var span := _w if n.z != 0.0 else _d
		var depth := _d if n.z != 0.0 else _w
		var cols := maxi(1, int(floor((span - 1.0) / 2.4)))
		var spacing := span / cols
		var along := Vector3(-n.z, 0, n.x)  # rechts, von außen gesehen
		for f: int in range(from_floor, floors):
			var y := f * floor_height + floor_height * 0.5 + 0.1
			for c: int in cols:
				var u := -span * 0.5 + spacing * (c + 0.5)
				var p := n * (depth * 0.5) + along * u + Vector3.UP * y
				if rng.randf() < 0.08:
					continue  # zugemauert
				b.quad(p + n * DECAL_OPENING, n, 1.1, 1.38, _window_mat())
				# Sims und Sturz geben Tiefe
				b.box_x(SlumBuilder.facing(p + n * 0.06 + Vector3.DOWN * 0.74, n), Vector3(1.3, 0.08, 0.14), _trim_mat, false)
				b.box_x(SlumBuilder.facing(p + n * 0.04 + Vector3.UP * 0.74, n), Vector3(1.24, 0.1, 0.08), _trim_mat, false)
				var roll := rng.randf()
				var bal_w := minf(1.9, spacing - 0.6)  # Nachbarbalkone berühren sich nicht
				if roll < balcony_chance and n.z > 0.0 and f > 0 and _balcony_fits(p.x, bal_w * 0.5, f):
					_balcony(b, p, n, along, bal_w)
				elif roll < balcony_chance + 0.15:
					_ac_unit(b, p + Vector3.DOWN * 1.15 + n * 0.19 + along * rng.randf_range(-0.3, 0.3), n)
				elif roll < balcony_chance + 0.2 and f < floors - 1 and c < cols - 1:
					# Wäscheleine zwischen zwei Fenstern
					var cable := SlumMats.color(Color(0.05, 0.05, 0.05))
					var a := p + n * 0.6 + Vector3.UP * 0.6
					var e := a + along * spacing
					b.cable(a, e, 0.25, cable, 0.012, 6)
					# Halter aus der Wand, an denen die Leine hängt
					for end: Vector3 in [a, e]:
						b.tube(end - n * 0.6, end + Vector3.UP * 0.02, 0.012, _metal, 4)
					for k: int in 3:
						var cloth := SlumMats.color(pick([Color(0.6, 0.1, 0.1), Color(0.2, 0.3, 0.6), Color(0.8, 0.8, 0.7), Color(0.3, 0.5, 0.3)]), 0.0, 0.9)
						b.quad(a + along * (spacing * (0.25 + k * 0.25)) + Vector3.DOWN * 0.45, n, 0.35, 0.5, cloth)
						b.quad(a + along * (spacing * (0.25 + k * 0.25)) + Vector3.DOWN * 0.45, -n, 0.35, 0.5, cloth)


## Balkone nur an der Vorderseite (+Z): nicht ins Ausleger-Schild und nicht vors Ladenschild.
func _balcony_fits(x: float, half: float, f: int) -> bool:
	if side_sign != "" and x + half > _w * 0.5 - 0.95:
		return false
	if style == Style.SHOP and front_sign != "" and f == 1 and absf(x) - half < 2.4:
		return false
	return true


## Platte auf Höhe des Geschossbodens direkt an der Wand, Geländer auf der Platte knapp innerhalb
## der Kante (vorn und an beiden Seiten bis zur Wand), darunter zwei Konsolen.
func _balcony(b: SlumBuilder, window_center: Vector3, n: Vector3, along: Vector3, width: float) -> void:
	var depth := 1.1
	var half := width * 0.5
	var inset := 0.05
	var wall := window_center + Vector3.DOWN * (floor_height * 0.5 + 0.1)  # Wandfläche auf Bodenhöhe
	b.box_x(SlumBuilder.facing(wall + n * (depth * 0.5) + Vector3.UP * 0.06, n), Vector3(width, 0.12, depth), _trim_mat)
	var y0 := wall + Vector3.UP * 0.12
	var front := y0 + n * (depth - inset)
	var l := front - along * (half - inset)
	var r := front + along * (half - inset)
	b.railing(l, r, _metal, 1.0, 0.5)
	b.railing(l, l - n * (depth - inset), _metal, 1.0, 0.5)
	b.railing(r, r - n * (depth - inset), _metal, 1.0, 0.5)
	for s: float in [-1.0, 1.0]:
		var foot := wall + along * (s * (half - 0.2))
		b.tube(foot + Vector3.DOWN * 0.55, foot + n * (depth - 0.15), 0.03, _metal, 4)
	# Blech als Sichtschutz innen am vorderen Geländer, manchmal Pflanzen oder Kram
	if rng.randf() < 0.6:
		var sheet := SlumMats.surface(pick(["corrugated_blue", "corrugated_rust", "corrugated_green"]))
		b.box_x(SlumBuilder.facing(y0 + n * (depth - inset - 0.06) + Vector3.UP * 0.5, n),
				Vector3(width - 2.0 * inset - 0.06, 0.8, 0.03), sheet, false)
	if rng.randf() < 0.5:
		b.box_x(SlumBuilder.facing(y0 + n * 0.4 + Vector3.UP * 0.25 + along * (half - 0.45), n),
				Vector3(0.5, 0.5, 0.5), SlumMats.uv("crate_wood"), false)


func _ac_unit(b: SlumBuilder, at: Vector3, n: Vector3) -> void:
	var xf := SlumBuilder.facing(at, n)
	var body := SlumMats.color(Color(0.6, 0.61, 0.58), 0.0, 0.6)
	b.box_x(xf, Vector3(0.8, 0.55, 0.36), body, false)
	b.quad_x(xf * Transform3D(Basis.IDENTITY, Vector3(0.1, 0, 0.18 + DECAL_OPENING)), 0.48, 0.48, SlumMats.decal("ac_front"))
	b.box_x(xf * Transform3D(Basis.IDENTITY, Vector3(0, -0.3, -0.05)), Vector3(0.85, 0.04, 0.45), _metal, false)
	# Kondenswasser-Rohr
	var drip := xf * Vector3(0.35, -0.28, 0)
	b.tube(drip, drip + Vector3.DOWN * 0.6, 0.012, _dark_metal, 4)


func _ground_floor_front(b: SlumBuilder) -> void:
	var front := Vector3(0, 0, _d * 0.5)
	var door_x := rng.randf_range(-_w * 0.25, _w * 0.25)
	var door := Vector3(door_x, 1.1, _d * 0.5 + DECAL_OPENING)
	b.quad(door, Vector3.BACK, 1.1, 2.2, SlumMats.decal(pick(["door_metal", "door_security", "door_wood"])))
	# Türrahmen und Vordach mit Lampe
	b.box(Vector3(door_x, 2.32, _d * 0.5 + 0.06), Vector3(1.4, 0.12, 0.12), _trim_mat, false)
	b.box(Vector3(door_x, 2.62, _d * 0.5 + 0.45), Vector3(1.8, 0.08, 0.9), _metal, false)
	var lamp_col: Color = pick([Color(1.0, 0.75, 0.45), Color(0.6, 0.9, 1.0), Color(1.0, 0.5, 0.3)])
	b.box(Vector3(door_x, 2.52, _d * 0.5 + 0.5), Vector3(0.3, 0.06, 0.16), SlumMats.color(lamp_col, 6.0), false, false)
	add_light(Vector3(door_x, 2.35, _d * 0.5 + 0.8), lamp_col, 1.4, 6.0, 0.15 if rng.randf() < 0.3 else 0.0)
	# Stufe vor der Tür
	b.box(Vector3(door_x, 0.08, _d * 0.5 + 0.35), Vector3(1.6, 0.16, 0.7), _trim_mat)
	# Erdgeschoss-Fenster mit Gittern
	for x: float in [-_w * 0.5 + 1.4, _w * 0.5 - 1.4]:
		if absf(x - door_x) < 1.8:
			continue
		b.quad(front + Vector3(x, 1.6, DECAL_OPENING), Vector3.BACK, 1.2, 1.0, SlumMats.decal("window_bars"))
	_ground_decals(b, Vector3.BACK, _w, _d, door_x)
	if front_sign != "":
		_flat_sign(b, Vector3(door_x, 3.3 if floors > 1 else 2.9, _d * 0.5 + 0.18), Vector3.BACK, front_sign, 2.4)


## Graffiti, Poster und Tags im Erdgeschoss.
func _ground_decals(b: SlumBuilder, n: Vector3, span: float, depth: float, avoid_x: float) -> void:
	var along := Vector3(-n.z, 0, n.x)
	# Feste Plätze im Abstand von 3 m, damit sich nichts überlappt. Nicht jeder Platz wird belegt.
	var slots := maxi(1, int(span / 3.0))
	var slot_w := span / slots
	for i: int in slots:
		var u := -span * 0.5 + slot_w * (i + 0.5)
		if absf(u - avoid_x) < 1.6 or rng.randf() < 0.35:
			continue
		var p := n * (depth * 0.5) + along * u
		var r := rng.randf()
		if r < 0.35:
			b.quad(p + n * DECAL_GRAFFITI + Vector3.UP * rng.randf_range(0.9, 1.3), n, minf(2.4, slot_w - 0.2), minf(1.2, slot_w * 0.5 - 0.1),
					SlumMats.decal(pick(["graffiti_1", "graffiti_2", "graffiti_3"])))
		elif r < 0.7:
			for k: int in rng.randi_range(1, 3):
				b.quad(p + along * (k * 0.5 - 0.5) + n * (DECAL_POSTER + 0.01 * k) + Vector3.UP * rng.randf_range(1.2, 1.7), n, 0.45, 0.68,
						SlumMats.decal(pick(["poster_1", "poster_2", "poster_3", "poster_4"])))
		else:
			b.quad(p + n * DECAL_TAG + Vector3.UP * rng.randf_range(0.6, 1.6), n, 1.4, 0.7, SlumMats.decal(pick(["tag_1", "tag_2"])))


func _pipes(b: SlumBuilder) -> void:
	var pipe := SlumMats.color(Color(0.2, 0.22, 0.22), 0.0, 0.5, 0.6)
	var rusty := SlumMats.surface("rust")
	# Fallrohre an den Vorderecken
	for side: float in [-1.0, 1.0]:
		if rng.randf() < 0.7:
			var x := side * (_w * 0.5 - 0.25)
			var z := _d * 0.5 + 0.12
			b.tube(Vector3(x, 0.0, z), Vector3(x, _h + 0.3, z), 0.08, rusty if rng.randf() < 0.5 else pipe, 6)
			for y: float in range(1, int(_h), 3):
				b.box(Vector3(x, y, z - 0.06), Vector3(0.22, 0.05, 0.12), pipe, false)
	# Rohrbündel an einer Seitenwand
	var sx := pick([-1.0, 1.0]) as float
	if (stair_side == Side.LEFT and sx < 0) or (stair_side == Side.RIGHT and sx > 0):
		sx = -sx
	var x0 := sx * (_w * 0.5 + 0.1)
	for i: int in rng.randi_range(1, 3):
		var z := -_d * 0.25 + i * 0.25
		b.tube(Vector3(x0 + sx * 0.05 * i, 0, z), Vector3(x0 + sx * 0.05 * i, _h - 0.5, z), 0.05 + 0.02 * i, pipe, 6)
	# Stromkasten mit Kabeln
	var box_z := rng.randf_range(-_d * 0.3, _d * 0.3)
	var ebox := SlumBuilder.facing(Vector3(x0 + sx * 0.18, 1.3, box_z), Vector3(sx, 0, 0))
	b.box_x(ebox, Vector3(0.7, 1.0, 0.3), SlumMats.color(Color(0.34, 0.38, 0.34), 0.0, 0.7, 0.2), false)
	b.quad_x(ebox * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.15 + DECAL_OPENING)), 0.6, 0.78, SlumMats.decal("electric_box"))


## Lüftungsgitter, Klimageräte und Kabel an Seiten- und Rückwand.
func _wall_clutter(b: SlumBuilder) -> void:
	for n: Vector3 in [Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
		if (n.x < 0 and stair_side == Side.LEFT) or (n.x > 0 and stair_side == Side.RIGHT):
			continue
		var span := _w if n.z != 0.0 else _d
		var depth := _d if n.z != 0.0 else _w
		var along := Vector3(-n.z, 0, n.x)
		# Zwei Lüfter links und rechts oben, Graffiti in der Mitte unten: feste Bereiche, damit sich
		# nichts überdeckt. Dazu eigene Abstände zur Wand (DECAL_*), falls doch.
		for side: float in [-1.0, 1.0]:
			var u := side * rng.randf_range(span * 0.25, span * 0.4)
			var p := n * (depth * 0.5 + DECAL_VENT) + along * u + Vector3.UP * rng.randf_range(2.3, 2.6)
			b.quad(p, n, 0.6, 0.6, SlumMats.decal(pick(["vent_grille", "vent_louver"])))
		if rng.randf() < 0.6:
			var p := n * (depth * 0.5 + DECAL_GRAFFITI) + along * rng.randf_range(-span * 0.12, span * 0.12)
			b.quad(p + Vector3.UP * 1.05, n, minf(2.2, span * 0.4), 1.1, SlumMats.decal(pick(["graffiti_1", "graffiti_2", "graffiti_3", "tag_1"])))


## Außentreppe (Feuertreppe) an einer Seite: zwei Spuren im Wechsel, damit niemand an der
## nächsten Flucht den Kopf stößt. An jedem Ende ein Podest über beide Spuren, oben Ausstieg aufs Dach.
func _exterior_stairs(b: SlumBuilder) -> void:
	var sx := -1.0 if stair_side == Side.LEFT else 1.0
	var g := _stair_geometry()
	var steps: int = g.steps
	var rise: float = g.rise
	var run := 0.27
	var flight: float = g.flight
	var landing: float = g.landing
	var lane := 1.15
	var z_lo: float = g.z_lo
	var z_hi: float = g.z_hi
	var wall_x := sx * _w * 0.5
	var plate := SlumMats.surface("metal_plate")
	for f: int in floors:
		var y0 := f * floor_height
		var top := y0 + floor_height
		var forward := f % 2 == 0
		var lx := wall_x + sx * (lane * (0.5 + float(f % 2)) + 0.05)
		var start := Vector3(lx, y0, z_lo if forward else z_hi)
		var dir := Vector3.BACK if forward else Vector3.FORWARD
		b.stairs(start, dir, steps, lane - 0.05, plate, rise, run, false, _metal)
		# Podest über beide Spuren am Ende der Flucht
		var lz := (z_hi + landing * 0.5) if forward else (z_lo - landing * 0.5)
		var px := wall_x + sx * (lane + 0.05)
		b.box(Vector3(px, top - 0.08, lz), Vector3(lane * 2.0, 0.16, landing), plate)
		var far_z := lz + (landing * 0.5 if forward else -landing * 0.5)
		var outer_x := wall_x + sx * (lane * 2.0 + 0.05)
		for dz: float in [-landing * 0.5 + 0.06, landing * 0.5 - 0.06]:
			b.tube(Vector3(outer_x - sx * 0.05, 0, lz + dz), Vector3(outer_x - sx * 0.05, top - 0.16, lz + dz), 0.04, _metal, 6)
		# Geländer: Podest außen und am Ende, äußere Spur außen, zwischen den Spuren
		b.railing(Vector3(outer_x, top, lz - landing * 0.5), Vector3(outer_x, top, lz + landing * 0.5), _metal, 1.0, 0.6)
		if f < floors - 1:
			b.railing(Vector3(wall_x + sx * 0.05, top, far_z), Vector3(outer_x, top, far_z), _metal, 1.0, 0.6)
		var a := Vector3(0, y0, start.z)
		var e := Vector3(0, top, start.z + dir.z * flight)
		if f % 2 == 1:
			_slanted_rail(b, a + Vector3(outer_x, 0, 0), e + Vector3(outer_x, 0, 0))
		_slanted_rail(b, a + Vector3(wall_x + sx * (lane + 0.05), 0, 0), e + Vector3(wall_x + sx * (lane + 0.05), 0, 0))
		# Tür vom Podest ins Haus, manchmal mit Lampe
		if f < floors - 1:
			b.quad(Vector3(wall_x + sx * 0.03, top + 1.1, lz), Vector3(sx, 0, 0), 1.0, 2.1, SlumMats.decal("door_metal"))
			if rng.randf() < 0.5:
				var col := Color(1.0, 0.7, 0.4)
				b.box(Vector3(wall_x + sx * 0.08, top + 2.4, lz), Vector3(0.1, 0.06, 0.3), SlumMats.color(col, 6.0), false, false)
				add_light(Vector3(wall_x + sx * 0.7, top + 2.2, lz), col, 0.9, 4.0, 0.1)


## Maße der Außentreppe (gemeinsam für Treppe und Dachlücke).
func _stair_geometry() -> Dictionary:
	var steps := int(roundf(floor_height / 0.2))
	var rise := floor_height / steps
	var flight := steps * 0.27
	var landing := 1.25
	var z_lo := -_d * 0.5 + landing
	return {"steps": steps, "rise": rise, "flight": flight, "landing": landing, "z_lo": z_lo, "z_hi": z_lo + flight}


## Schräges Treppengeländer (Handlauf + Pfosten) von a (unten) nach e (oben).
func _slanted_rail(b: SlumBuilder, a: Vector3, e: Vector3) -> void:
	var posts := 4
	for i: int in posts + 1:
		var p := a.lerp(e, float(i) / posts)
		b.tube(p, p + Vector3.UP * 1.0, 0.025, _metal, 4)
	b.tube(a + Vector3.UP * 1.0, e + Vector3.UP * 1.0, 0.03, _metal, 4)
	b.tube(a + Vector3.UP * 0.5, e + Vector3.UP * 0.5, 0.02, _metal, 4)
	# Kollision als senkrechte Stücke: eine schräge Box würde an den Enden über das Podest ragen.
	var flat := Vector3(e.x - a.x, 0, e.z - a.z)
	var pieces := maxi(1, int(ceil(flat.length() / 0.6)))
	var yaw := atan2(flat.x, flat.z)
	for i: int in pieces:
		var t := (i + 0.5) / pieces
		var p := a.lerp(e, t)
		b.collider_x(Transform3D(Basis(Vector3.UP, yaw), p + Vector3.UP * 0.6), Vector3(0.08, 1.2, flat.length() / pieces))


## Lücke in der Dachbrüstung, wo die Außentreppe oben ankommt: [Seite, z_von, z_bis].
func _gap_for_stairs() -> Array:
	if style != Style.RESIDENTIAL or stair_side == Side.NONE:
		return []
	var sx := -1.0 if stair_side == Side.LEFT else 1.0
	var g := _stair_geometry()
	if (floors - 1) % 2 == 0:
		return [sx, g.z_hi, g.z_hi + g.landing]
	return [sx, g.z_lo - g.landing, g.z_lo]


func _rooftop(b: SlumBuilder) -> void:
	var y := _h + 0.06
	# Klimageräte in Reihe
	var ac_count := rng.randi_range(1, 4)
	for i: int in ac_count:
		# Klimageräte im hinteren Teil, die Dachhütte steht vorn (nicht ineinander)
		var p := Vector3(rng.randf_range(-_w * 0.35, _w * 0.35), y, rng.randf_range(-_d * 0.38, -_d * 0.18))
		var body := SlumMats.color(Color(0.55, 0.56, 0.54), 0.0, 0.6)
		b.box(p + Vector3.UP * 0.35, Vector3(1.0, 0.7, 0.8), body)
		b.quad(p + Vector3(0, 0.35, 0.4 + DECAL_OPENING), Vector3.BACK, 0.6, 0.6, SlumMats.decal("ac_front"))
	# Antennen und Satellitenschüssel
	for i: int in rng.randi_range(1, 3):
		var p := Vector3(rng.randf_range(-_w * 0.4, _w * 0.4), y, rng.randf_range(-_d * 0.4, _d * 0.4))
		b.tube(p, p + Vector3.UP * rng.randf_range(2.0, 4.5), 0.03, _metal, 4)
	if rng.randf() < 0.5:
		var p := Vector3(rng.randf_range(-_w * 0.3, _w * 0.3), y, -_d * 0.3)
		b.tube(p, p + Vector3.UP * 1.0, 0.04, _metal, 4)
		b.cylinder_x(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-60)), p + Vector3(0, 1.1, 0.1)), 0.45, 0.08,
				SlumMats.color(Color(0.7, 0.7, 0.68), 0.0, 0.5), 10)
	# Wassertank auf Beinen
	if _w > 7.0 and rng.randf() < 0.7:
		var t := Vector3(-_w * 0.5 + 1.6, y, -_d * 0.5 + 1.6)
		var tank := SlumMats.surface("rust", Color(0.75, 0.8, 0.85))
		for dx: float in [-0.6, 0.6]:
			for dz: float in [-0.6, 0.6]:
				b.box(t + Vector3(dx, 0.6, dz), Vector3(0.1, 1.2, 0.1), _dark_metal, false)
		b.box(t + Vector3(0, 1.25, 0), Vector3(1.5, 0.1, 1.5), _dark_metal)
		b.cylinder(t + Vector3.UP * 1.3, 0.75, 1.4, tank, 10, true)
	# Shanty-Anbau auf dem Dach
	if _w >= 8.0 and rng.randf() < 0.65:
		_roof_shack(b, Vector3(_w * 0.5 - 2.0 - rng.randf_range(0, 1.0), y, maxf(0.9, rng.randf_range(0.9, _d * 0.5 - 1.6))))


func _roof_shack(b: SlumBuilder, at: Vector3) -> void:
	var w := 2.8
	var d := 2.4
	var h := 2.3
	var mats := ["corrugated_blue", "corrugated_rust", "corrugated_green", "wood", "corrugated_grey"]
	b.box(at + Vector3(0, h * 0.5, -d * 0.5 + 0.03), Vector3(w, h, 0.06), SlumMats.surface(pick(mats)))
	b.box(at + Vector3(-w * 0.5 + 0.03, h * 0.5, 0), Vector3(0.06, h, d - 0.12), SlumMats.surface(pick(mats)))
	b.box(at + Vector3(w * 0.5 - 0.03, h * 0.5, 0), Vector3(0.06, h, d - 0.12), SlumMats.surface(pick(mats)))
	# Front mit Tür-Öffnung
	b.box(at + Vector3(-w * 0.25 - 0.25, h * 0.5, d * 0.5 - 0.03), Vector3(w * 0.5 - 0.5, h, 0.06), SlumMats.surface(pick(mats)))
	b.box(at + Vector3(w * 0.25 + 0.25, h * 0.5, d * 0.5 - 0.03), Vector3(w * 0.5 - 0.5, h, 0.06), SlumMats.surface(pick(mats)))
	b.box(at + Vector3(0, h - 0.2, d * 0.5 - 0.03), Vector3(1.0, 0.4, 0.06), SlumMats.surface(pick(mats)), false)
	var roof := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(8)), at + Vector3(0, h + 0.15, 0.1))
	b.box_x(roof, Vector3(w + 0.5, 0.05, d + 0.8), SlumMats.surface("corrugated_rust"))
	b.quad(at + Vector3(0.9, 1.3, d * 0.5 + DECAL_OPENING), Vector3.BACK, 0.6, 0.5, SlumMats.decal("window_lit", "window_emit", Color(1.0, 0.7, 0.4), 1.4))
	var tarp := SlumMats.surface("tarp_blue")
	b.box(at + Vector3(-w * 0.5 - 0.04, h * 0.55, 0.3), Vector3(0.02, h * 0.8, 1.4), tarp, false)
	add_light(at + Vector3(0, h - 0.4, 0), Color(1.0, 0.7, 0.4), 0.9, 4.0, 0.2)


# ================================================================== Laden

func _shop(b: SlumBuilder) -> void:
	var fh := floor_height
	var t := 0.25
	var fl := maxf(floor_level, 0.0)
	var ground := SlumMats.surface(ground_wall if ground_wall != "" else wall, wall_tint)
	var floor_mat := SlumMats.surface("tiles_dark")
	# Erdgeschoss hohl: Rück- und Seitenwände, Front mit großer Toröffnung (bis 6,2 m breit)
	b.box(Vector3(0, fh * 0.5, -_d * 0.5 + t * 0.5), Vector3(_w, fh, t), ground)
	b.box(Vector3(-_w * 0.5 + t * 0.5, fh * 0.5, 0), Vector3(t, fh, _d - 2 * t), ground)
	b.box(Vector3(_w * 0.5 - t * 0.5, fh * 0.5, 0), Vector3(t, fh, _d - 2 * t), ground)
	var open_w := clampf(_w - 2.6, 3.0, 6.2)
	var side_w := (_w - open_w) * 0.5
	var lintel := 0.35
	b.box(Vector3(-_w * 0.5 + side_w * 0.5, fh * 0.5, _d * 0.5 - t * 0.5), Vector3(side_w, fh, t), ground)
	b.box(Vector3(_w * 0.5 - side_w * 0.5, fh * 0.5, _d * 0.5 - t * 0.5), Vector3(side_w, fh, t), ground)
	b.box(Vector3(0, fh - lintel * 0.5, _d * 0.5 - t * 0.5), Vector3(open_w, lintel, t), ground)
	# Boden auf Höhe des Bodens davor, Schwelle durch die Wand bis auf den Gehweg (keine Kante, keine Rinne).
	# 5 mm über dem Gehweg, damit die Oberflächen nicht in einer Ebene flackern.
	var top := fl + 0.005 if fl > 0.0 else 0.02
	b.box(Vector3(0, top * 0.5, 0), Vector3(_w - 2 * t, top, _d - 2 * t), floor_mat)
	b.box(Vector3(0, top * 0.5, _d * 0.5 + 0.05), Vector3(open_w, top, t + 0.7), SlumMats.surface("metal_plate"))
	# Decke zwischen den Wänden, darüber die Obergeschosse
	b.box(Vector3(0, fh - 0.1, 0), Vector3(_w - 2 * t, 0.2, _d - 2 * t), SlumMats.surface("concrete", Color(0.75, 0.75, 0.78)))
	if floors > 1:
		b.box_on(Vector3(0, fh + (_h - fh) * 0.5, 0), Vector3(_w, _h - fh, _d), _wall_mat)
		_ledges(b, 1)
		_facade_windows(b, 1, [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT])
	_roof(b, [])
	_plinth_front(b, open_w)
	# Rolltor ganz hochgezogen: Kasten über der Öffnung, unten schaut eine Lamellenkante heraus,
	# seitlich Führungsschienen. Lichte Höhe ca. 2,6 m.
	var gate_top := fh - lintel
	b.box(Vector3(0, gate_top + 0.18, _d * 0.5 + 0.2), Vector3(open_w + 0.4, 0.42, 0.34), _metal, false)
	b.quad(Vector3(0, gate_top - 0.06, _d * 0.5 + 0.02), Vector3.BACK, open_w, 0.12, SlumMats.decal("door_security"), Rect2(0, 0, 1, 0.08))
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(s * (open_w * 0.5 + 0.06), gate_top * 0.5, _d * 0.5 + 0.06), Vector3(0.1, gate_top, 0.12), _dark_metal, false)
	# Markise
	var awn := SlumMats.surface(pick(["tarp_red", "tarp_blue"]))
	var awn_x := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(22)), Vector3(0, fh + 0.05, _d * 0.5 + 0.85))
	b.box_x(awn_x, Vector3(open_w + 0.8, 0.05, 1.6), awn, false)
	b.quad(Vector3(0, fh - 0.32, _d * 0.5 + 1.6), Vector3.BACK, open_w + 0.8, 0.24, SlumMats.decal("red_white"), Rect2(0, 0, 8, 1))
	# Einrichtung wie ein echter Späti: Theke seitlich am Eingang (Verkäufer sieht Tür und Gänge),
	# dahinter eine Vitrine mit Wertsachen, Regalgänge (1,5 m hoch, man kann sich dahinter ducken),
	# Kühlschränke an der rechten Wand, Wandregale hinten. Plätze für echte Ware bekommt ShopInterior.
	var ix0 := -_w * 0.5 + t
	var ix1 := _w * 0.5 - t
	var iz0 := -_d * 0.5 + t
	var iz1 := _d * 0.5 - t
	var slots: Array = []
	var wood := SlumMats.surface("wood_dark")
	var counter_len := clampf(_d * 0.34, 2.0, 2.8)
	var counter_x := ix0 + 1.35
	var counter_z1 := iz1 - 1.1
	var counter_zc := counter_z1 - counter_len * 0.5
	b.box(Vector3(counter_x, fl + 0.5, counter_zc), Vector3(0.6, 1.0, counter_len), wood)
	b.box(Vector3(counter_x, fl + 1.03, counter_zc), Vector3(0.7, 0.06, counter_len + 0.04), _metal, false)
	b.box(Vector3(counter_x + 0.31, fl + 0.25, counter_zc), Vector3(0.02, 0.05, counter_len - 0.1), SlumMats.color(Color(1.0, 0.3, 0.7), 4.0), false, false)
	# Kartenterminal neben der Kasse, Aufsteller mit Kaugummi.
	b.box(Vector3(counter_x + 0.1, fl + 1.11, counter_z1 - 0.95), Vector3(0.1, 0.1, 0.16), _dark_metal, false)
	b.box(Vector3(counter_x + 0.14, fl + 1.15, counter_z1 - 0.95), Vector3(0.01, 0.05, 0.1), SlumMats.color(Color(0.3, 1.0, 0.6), 3.0), false, false)
	b.box(Vector3(counter_x + 0.15, fl + 1.2, counter_zc + counter_len * 0.3), Vector3(0.3, 0.3, 0.25), SlumMats.color(Color(0.9, 0.2, 0.5), 0.0, 0.5), false)
	# Vitrine an der linken Wand hinter dem Verkäufer (Glasfront, Licht innen).
	var cab_x := ix0 + 0.25
	b.box(Vector3(cab_x, fl + 0.45, counter_zc), Vector3(0.45, 0.9, counter_len), _dark_metal, true)
	b.box(Vector3(cab_x, fl + 1.35, counter_zc), Vector3(0.45, 0.9, counter_len), SlumMats.glass(Color(0.6, 0.85, 1.0, 0.18)), false, false)
	b.box(Vector3(cab_x, fl + 1.82, counter_zc), Vector3(0.47, 0.04, counter_len + 0.02), SlumMats.color(Color(1.0, 0.85, 0.6), 4.0), false, false)
	for i in int(counter_len / 0.55):
		var z := counter_zc - counter_len * 0.5 + 0.3 + i * 0.55
		slots.append({"kind": "cabinet", "xf": Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cab_x + 0.05, fl + 0.92, z))})
	# Regalgänge: Mittelregale längs, beidseitig bestückt.
	var aisle_z0 := iz0 + 1.2
	var aisle_z1 := iz1 - 1.6
	var aisle_len := aisle_z1 - aisle_z0
	var gx := counter_x + 1.0 + 0.45 + 0.35
	var limit := ix1 - 0.7 - 1.0 - 0.45
	var aisle_names := ["SNACKS", "INSTANT", "PFLEGE", "DIVERSES"]
	var aisle := 0
	while gx <= limit and aisle_len > 1.8:
		for n: Vector3 in [Vector3.LEFT, Vector3.RIGHT]:
			slots.append_array(_shelf_unit(b, Vector3(gx + n.x * 0.23, fl, (aisle_z0 + aisle_z1) * 0.5), n, aisle_len, 1.5, 0.45, "shelf"))
		b.box(Vector3(gx, fl + 1.52, (aisle_z0 + aisle_z1) * 0.5), Vector3(0.95, 0.04, aisle_len + 0.04), _metal, false)
		_aisle_sign(Vector3(gx, fh - 0.55, aisle_z1 + 0.2), aisle_names[aisle % aisle_names.size()])
		b.box(Vector3(gx, fh - 0.24, (aisle_z0 + aisle_z1) * 0.5), Vector3(0.1, 0.05, aisle_len * 0.8), SlumMats.color(Color(0.9, 0.95, 1.0), 5.0), false, false)
		add_light(Vector3(gx, fh - 0.5, (aisle_z0 + aisle_z1) * 0.5), Color(0.92, 0.96, 1.0), 1.6, 5.0)
		gx += 1.9
		aisle += 1
	# Kühlschränke an der rechten Wand.
	var fridge_x := ix1 - 0.35
	var fz := iz0 + 0.8
	while fz + 0.6 <= iz1 - 1.3:
		_fridge(b, Vector3(fridge_x, fl, fz))
		for row_y: float in [0.6, 1.2]:
			slots.append({"kind": "fridge", "xf": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(fridge_x - 0.05, fl + row_y, fz))})
		fz += 1.25
	if fz > iz0 + 0.8:
		_aisle_sign(Vector3(fridge_x - 0.4, fh - 0.55, iz0 + 1.0), "DRINKS")
	# Wandregal hinten.
	var back_x0 := gx - 1.9 + 0.8 if aisle > 0 else counter_x + 1.2
	var back_len := (fridge_x - 0.6) - back_x0
	if back_len > 1.0:
		slots.append_array(_shelf_unit(b, Vector3(back_x0 + back_len * 0.5, fl, iz0 + 0.25), Vector3.BACK, back_len, 2.0, 0.45, "wall"))
	# Kamera unter der Decke vorn rechts, schaut in den Laden.
	var camera_at := Vector3.INF
	if rng.randf() < 0.6:
		camera_at = Vector3(ix1 - 0.35, fh - 0.35, iz1 - 0.35)
		b.box(camera_at + Vector3(0.0, 0.18, 0.0), Vector3(0.06, 0.15, 0.06), _dark_metal, false)
	# Diebstahlsicherung: zwei Säulen am Eingang.
	var sensor := rng.randf() < (0.8 if front_sign == "sign_pharmacy" or front_sign == "sign_24h" else 0.4)
	if sensor:
		for s: float in [-1.0, 1.0]:
			var sx := s * (minf(_w - 2.6, 6.2) * 0.5 - 0.35)
			if s < 0.0:
				sx = maxf(sx, counter_x + 0.7)
			b.box(Vector3(sx, fl + 0.75, iz1 - 0.45), Vector3(0.08, 1.5, 0.35), SlumMats.color(Color(0.85, 0.88, 0.9), 0.0, 0.3, 0.3), true)
			b.box(Vector3(sx, fl + 0.75, iz1 - 0.45), Vector3(0.09, 1.3, 0.05), SlumMats.color(Color(0.3, 0.8, 1.0), 2.5), false, false)
	var neon_col: Color = pick([Color(0.2, 1.0, 0.8), Color(1.0, 0.3, 0.7), Color(1.0, 0.8, 0.4)])
	b.box(Vector3(0, fh - 0.24, iz1 - 0.6), Vector3(1.6, 0.05, 0.12), SlumMats.color(neon_col, 6.0), false, false)
	b.box(Vector3(counter_x, fh - 0.24, counter_zc), Vector3(0.12, 0.05, 1.0), SlumMats.color(Color(1.0, 0.95, 0.85), 5.0), false, false)
	add_light(Vector3(0, fh - 0.6, iz1 - 0.8), neon_col.lerp(Color(1.0, 0.85, 0.7), 0.5), 2.0, 6.0, 0.05)
	add_light(Vector3(counter_x, fh - 0.5, counter_zc), Color(1.0, 0.9, 0.75), 1.4, 4.5)
	if front_sign != "":
		_flat_sign(b, Vector3(0, fh + 0.7, _d * 0.5 + 0.18), Vector3.BACK, front_sign, minf(open_w + 0.6, 4.2))
	if side_sign != "":
		_vertical_sign(b, Vector3(_w * 0.5 - 0.7, fh + 2.2, _d * 0.5), side_sign)
	_ground_decals(b, Vector3.LEFT, _d, _w, 99.0)
	_ground_decals(b, Vector3.RIGHT, _d, _w, 99.0)
	if rooftop_clutter:
		_rooftop(b)
	# Spiel-Logik (Verkäufer, Kasse, Ware) nur im laufenden Spiel, nicht im Editor.
	if not Engine.is_editor_hint():
		var interior: Node3D = ShopInteriorScript.new()
		interior.name = "ShopInterior"
		interior.set("shop_sign", front_sign)
		interior.set("floor_y", fl)
		interior.set("keeper_at", Vector3(ix0 + 0.65, fl, counter_zc))
		interior.set("register_at", Vector3(counter_x, fl + 1.06, counter_z1 - 0.45))
		interior.set("counter_at", Vector3(counter_x + 0.1, fl + 1.06, counter_zc))
		interior.set("bounds", AABB(Vector3(ix0, fl - 0.5, iz0), Vector3(ix1 - ix0, fh, iz1 - iz0 + 0.2)))
		interior.set("camera_at", camera_at)
		interior.set("has_sensor", sensor)
		interior.set("slots", slots)
		interior.set("seed_value", rng.randi())
		add_gen(interior)


func _plinth_front(b: SlumBuilder, open_w: float) -> void:
	var side_w := (_w - open_w) * 0.5
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (_w * 0.5 - side_w * 0.5), 0.2, _d * 0.5 + 0.03), Vector3(side_w + 0.06, 0.4, 0.08), _trim_mat, false)


## Regal (eine Seite) mit Rückwand, Böden und Füllware. `n` = Richtung, in die die Front zeigt,
## `at` = Mitte der Grundfläche. Gibt die Plätze für echte Ware zurück (zweiter und dritter Boden,
## alle ~0,9 m), als {"kind", "xf"} mit xf = Lage auf dem Boden, +Z zeigt aus dem Regal heraus.
func _shelf_unit(b: SlumBuilder, at: Vector3, n: Vector3, length: float, height: float, depth: float, kind: String) -> Array:
	var metal := SlumMats.color(Color(0.3, 0.32, 0.33), 0.0, 0.5, 0.5)
	var xf := SlumBuilder.facing(at, n)
	b.box_x(xf * Transform3D(Basis.IDENTITY, Vector3(0, height * 0.5, -depth * 0.5 + 0.02)), Vector3(length, height, 0.04), metal, true)
	for s: float in [-1.0, 1.0]:
		b.box_x(xf * Transform3D(Basis.IDENTITY, Vector3(s * (length * 0.5 - 0.02), height * 0.5, 0.0)), Vector3(0.04, height, depth), metal, true)
	var boards: Array[float] = [0.1, 0.55, 1.0]
	if height > 1.7:
		boards.append(1.45)
	for y: float in boards:
		b.box_x(xf * Transform3D(Basis.IDENTITY, Vector3(0, y, 0.0)), Vector3(length, 0.03, depth), metal, true)
		# Preisleiste vorn.
		b.box_x(xf * Transform3D(Basis.IDENTITY, Vector3(0, y - 0.03, depth * 0.5)), Vector3(length, 0.035, 0.01),
				SlumMats.color(Color(1.0, 0.9, 0.3), 0.6), false, false)
	var goods := [Color(0.85, 0.2, 0.15), Color(0.95, 0.75, 0.15), Color(0.2, 0.55, 0.85), Color(0.25, 0.7, 0.35), Color(0.9, 0.9, 0.85)]
	var slots: Array = []
	var count := maxi(int(length / 1.1), 1)
	for bi: int in boards.size():
		var y := boards[bi]
		# Boden 3 trägt die echte Ware, die anderen Füllware (Kartons, Packungen).
		if bi == 2:
			for k: int in count:
				var x := -length * 0.5 + (k + 0.5) * length / count
				slots.append({"kind": kind, "xf": xf * Transform3D(Basis.IDENTITY, Vector3(x, y + 0.015, depth * 0.12))})
			continue
		var k := -length * 0.5 + 0.12
		while k < length * 0.5 - 0.12:
			if rng.randf() < 0.75:
				var c: Color = goods[rng.randi() % goods.size()]
				var h := rng.randf_range(0.12, 0.3)
				b.box_x(xf * Transform3D(Basis.IDENTITY, Vector3(k, y + 0.015 + h * 0.5, rng.randf_range(-0.05, 0.08))),
						Vector3(0.18, h, 0.2), SlumMats.color(c, 0.0, 0.6), false, false)
			k += 0.24
	return slots


## Getränkekühlschrank an der rechten Wand (Front zeigt nach -X), 1,2 m breit: Korpus mit Leuchtrückwand,
## drei Böden (0,6 / 1,2 / 1,75 m) und Glastür. Die Ware steht auf den Böden hinter dem Glas.
func _fridge(b: SlumBuilder, at: Vector3) -> void:
	b.box(at + Vector3(0.3, 1.0, 0), Vector3(0.1, 2.0, 1.2), _metal, true)
	for s: float in [-1.0, 1.0]:
		b.box(at + Vector3(0.0, 1.0, s * 0.58), Vector3(0.7, 2.0, 0.04), _metal, true)
	b.box(at + Vector3(0.0, 1.98, 0), Vector3(0.7, 0.04, 1.2), _metal, true)
	b.box(at + Vector3(0.0, 0.15, 0), Vector3(0.7, 0.3, 1.2), _dark_metal, true)
	b.quad_x(Transform3D(Basis(Vector3.UP, -PI * 0.5), at + Vector3(0.245, 1.1, 0)), 1.1, 1.6, SlumMats.color(Color(0.55, 0.9, 1.0), 2.5))
	for row: float in [0.6, 1.2, 1.75]:
		b.box(at + Vector3(0.0, row - 0.01, 0), Vector3(0.55, 0.02, 1.12), SlumMats.glass(Color(0.8, 0.95, 1.0, 0.5)), true, false)
	b.box(at + Vector3(-0.34, 1.12, 0), Vector3(0.02, 1.7, 1.12), SlumMats.glass(Color(0.7, 0.9, 1.0, 0.12)), false, false)
	b.box(at + Vector3(-0.36, 1.1, 0.5), Vector3(0.03, 0.5, 0.03), _metal, false)


## Hängeschild über einem Gang (Text, leuchtend, beidseitig).
func _aisle_sign(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.004
	label.outline_size = 8
	label.double_sided = true
	label.modulate = Color(1.0, 0.95, 0.85)
	label.outline_modulate = Color(0.9, 0.2, 0.5)
	add_gen(label, at)


func _flat_sign(b: SlumBuilder, at: Vector3, n: Vector3, tex: String, width: float) -> void:
	var t := SlumMats.texture(tex)
	var aspect := 2.6
	if t != null:
		aspect = float(t.get_width()) / float(t.get_height())
	var h := width / aspect
	b.box_x(SlumBuilder.facing(at - n * (0.05 + DECAL_OPENING), n), Vector3(width + 0.12, h + 0.12, 0.1), _dark_metal, false)
	var mat := SlumMats.sign_mat(tex, 3.0)
	b.quad(at, n, width, h, mat)
	var light_col := _sign_color(tex)
	add_light(at + n * 0.9, light_col, 1.4, 5.0, 0.12 if rng.randf() < 0.35 else 0.0)


## Senkrechtes Ausleger-Schild an der Front. at = Befestigungspunkt an der Wand (Mitte, Höhe).
## Das Schild steht quer zur Fassade und ist von der Straße aus beidseitig lesbar.
func _vertical_sign(b: SlumBuilder, at: Vector3, tex: String) -> void:
	var t := SlumMats.texture(tex)
	var aspect := 0.4
	if t != null:
		aspect = float(t.get_width()) / float(t.get_height())
	var h := 3.0
	var w := h * aspect
	var c := at + Vector3(0, 0, 0.25 + w * 0.5)
	for y: float in [h * 0.5 - 0.15, -h * 0.5 + 0.15]:
		b.box(Vector3(at.x, at.y + y, at.z + 0.15), Vector3(0.06, 0.06, 0.3), _metal, false)
	b.box(c, Vector3(0.12, h + 0.1, w + 0.1), _dark_metal, false)
	var mat := SlumMats.sign_mat(tex, 3.5)
	b.quad_x(Transform3D(Basis(Vector3.UP, PI * 0.5), c + Vector3(0.06 + DECAL_OPENING, 0, 0)), w, h, mat)
	b.quad_x(Transform3D(Basis(Vector3.UP, -PI * 0.5), c + Vector3(-0.06 - DECAL_OPENING, 0, 0)), w, h, mat)
	add_light(c + Vector3(0.8, 0, 0), _sign_color(tex), 1.5, 6.0, 0.2 if rng.randf() < 0.4 else 0.0)
	add_light(c + Vector3(-0.8, 0, 0), _sign_color(tex), 1.0, 4.0)


func _sign_color(tex: String) -> Color:
	var table := {
		"sign_bar": Color(1.0, 0.2, 0.25), "sign_24h": Color(0.25, 0.85, 1.0), "sign_pharmacy": Color(0.25, 1.0, 0.5),
		"sign_hotel": Color(1.0, 0.3, 0.25), "sign_vacancy": Color(1.0, 0.25, 0.5), "sign_ngc7": Color(0.5, 0.55, 1.0),
		"sign_ramen": Color(1.0, 0.65, 0.2), "sign_hotel2": Color(0.95, 0.95, 0.85), "sign_shop": Color(1.0, 0.6, 0.2),
		"sign_noodles": Color(1.0, 0.25, 0.8), "sign_open": Color(0.35, 1.0, 0.8),
	}
	return table.get(tex, Color(1.0, 0.8, 0.6))


# ================================================================== Lagerhalle

func _warehouse(b: SlumBuilder) -> void:
	var t := 0.3
	var h := _h
	var corr := _wall_mat
	var base := SlumMats.surface("concrete_dark")
	# Sockel aus Beton, darüber Wellblech
	var plinth := 1.2
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (_w * 0.5 - t * 0.5), plinth * 0.5, 0), Vector3(t, plinth, _d), base)
		b.box(Vector3(side * (_w * 0.5 - t * 0.5), plinth + (h - plinth) * 0.5, 0), Vector3(t, h - plinth, _d), corr)
	b.box(Vector3(0, plinth * 0.5, -_d * 0.5 + t * 0.5), Vector3(_w - 2 * t, plinth, t), base)
	b.box(Vector3(0, plinth + (h - plinth) * 0.5, -_d * 0.5 + t * 0.5), Vector3(_w - 2 * t, h - plinth, t), corr)
	# Front mit großem Tor (4,2 × 4,5) und kleiner Tür
	var gate_w := minf(4.6, _w - 3.0)
	var gate_h := minf(4.5, h - 1.2)
	var gx := -_w * 0.12
	# Frontteile reichen nur bis an die Seitenwände (sonst liegen ihre Flächen in denen der Seitenwände).
	var left := (_w * 0.5 + gx - gate_w * 0.5) - t
	var right := (_w * 0.5 - gx - gate_w * 0.5) - t
	var fz := _d * 0.5 - t * 0.5
	b.box(Vector3(-_w * 0.5 + t + left * 0.5, h * 0.5, fz), Vector3(left, h, t), corr)
	b.box(Vector3(_w * 0.5 - t - right * 0.5, h * 0.5, fz), Vector3(right, h, t), corr)
	b.box(Vector3(gx, gate_h + (h - gate_h) * 0.5, fz), Vector3(gate_w, h - gate_h, t), corr)
	# Rolltor halb offen
	var open := 2.6
	b.box(Vector3(gx, gate_h - (gate_h - open) * 0.5, fz), Vector3(gate_w, gate_h - open, 0.08), SlumMats.surface("shutter"), true)
	b.box(Vector3(gx, gate_h + 0.25, fz + 0.3), Vector3(gate_w + 0.3, 0.5, 0.5), _metal, false)
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(gx + s * (gate_w * 0.5 + 0.12), gate_h * 0.5, fz + 0.18), Vector3(0.2, gate_h, 0.12), SlumMats.surface("hazard"), false)
	# Kleine Tür rechts
	var dx := _w * 0.5 - t - right * 0.5
	b.quad(Vector3(dx, 1.1, _d * 0.5 + DECAL_OPENING), Vector3.BACK, 1.1, 2.2, SlumMats.decal("door_metal"))
	b.box(Vector3(dx, 0.08, _d * 0.5 + 0.4), Vector3(1.6, 0.16, 0.8), base)
	# Dach (flach mit Oberlichtern), Dachrand
	b.box(Vector3(0, h + 0.1, 0), Vector3(_w + 0.3, 0.2, _d + 0.3), SlumMats.surface("corrugated_grey", Color(0.7, 0.7, 0.7)))
	for i: int in int(_d / 5.0):
		var z := -_d * 0.5 + 2.5 + i * 5.0
		b.box(Vector3(0, h + 0.35, z), Vector3(_w * 0.5, 0.3, 1.4), SlumMats.color(Color(0.3, 0.35, 0.3), 0.0, 0.2, 0.2), false)
	# Schornsteine / Abluft
	for i: int in rng.randi_range(1, 2):
		var p := Vector3(rng.randf_range(-_w * 0.35, _w * 0.35), h, rng.randf_range(-_d * 0.4, -_d * 0.1))
		b.cylinder(p, 0.35, 3.5, SlumMats.surface("rust"), 8)
		b.cylinder(p + Vector3.UP * 3.5, 0.45, 0.2, _dark_metal, 8)
	# Rohre außen an der Seite
	var pipe := SlumMats.color(Color(0.22, 0.25, 0.25), 0.0, 0.5, 0.6)
	b.tube(Vector3(_w * 0.5 + 0.2, 0, -_d * 0.3), Vector3(_w * 0.5 + 0.2, h - 0.5, -_d * 0.3), 0.12, pipe, 8)
	b.tube(Vector3(_w * 0.5 + 0.2, h - 0.5, -_d * 0.3), Vector3(_w * 0.5 + 0.2, h - 0.5, _d * 0.3), 0.12, pipe, 8)
	b.tube(Vector3(_w * 0.5 + 0.2, 1.2, _d * 0.3), Vector3(_w * 0.5 + 0.2, h - 0.5, _d * 0.3), 0.12, pipe, 8)
	# Beschriftung und Lampen
	if number != "":
		b.quad(Vector3(gx, gate_h + (h - gate_h) * 0.5 + 0.1, _d * 0.5 + DECAL_STENCIL), Vector3.BACK, 2.4, 1.8,
				SlumMats.decal("stencil_" + number.to_lower()))
	b.quad(Vector3(dx, 2.8, _d * 0.5 + DECAL_STENCIL), Vector3.BACK, 1.4, 0.47, SlumMats.decal("sign_beware"))
	for lx: float in [gx - gate_w * 0.5 - 0.5, dx]:
		b.box(Vector3(lx, gate_h + 0.4, _d * 0.5 + 0.25), Vector3(0.4, 0.12, 0.3), _metal, false)
		b.box(Vector3(lx, gate_h + 0.33, _d * 0.5 + 0.25), Vector3(0.3, 0.03, 0.2), SlumMats.color(Color(1.0, 0.85, 0.6), 5.0), false, false)
		add_light(Vector3(lx, gate_h + 0.1, _d * 0.5 + 0.8), Color(1.0, 0.8, 0.55), 2.0, 9.0, 0.0)
	if front_sign != "":
		_flat_sign(b, Vector3(dx, gate_h + 0.9, _d * 0.5 + 0.18), Vector3.BACK, front_sign, 1.8)
	_ground_decals(b, Vector3.LEFT, _d, _w, 99.0)
	_ground_decals(b, Vector3.FORWARD, _w, _d, 99.0)
	# Innen: Boden, Laufsteg an der Rückwand mit Treppe, Lampen
	b.box(Vector3(0, 0.04, 0), Vector3(_w - 2 * t, 0.08, _d - 2 * t), SlumMats.surface("concrete_dark", Color(0.8, 0.8, 0.8)))
	var deck_h := minf(3.4, h - 2.2)
	var deck_d := 1.6
	var plate := SlumMats.surface("metal_plate")
	var deck_z := -_d * 0.5 + t + deck_d * 0.5
	b.box(Vector3(0, deck_h - 0.08, deck_z), Vector3(_w - 2 * t, 0.16, deck_d), plate)
	b.railing(Vector3(-_w * 0.5 + t, deck_h, deck_z + deck_d * 0.5), Vector3(_w * 0.5 - t - 1.3, deck_h, deck_z + deck_d * 0.5), _metal, 1.0, 1.0)
	for x: float in range(int(-_w * 0.5 + 2), int(_w * 0.5 - 1), 3):
		b.tube(Vector3(x, 0, deck_z + deck_d * 0.5 - 0.1), Vector3(x, deck_h - 0.16, deck_z + deck_d * 0.5 - 0.1), 0.06, _metal, 6)
	var steps := int(roundf(deck_h / 0.2))
	var rise := deck_h / steps
	var sx := _w * 0.5 - t - 0.65
	b.stairs(Vector3(sx, 0, deck_z + deck_d * 0.5 + steps * 0.27), Vector3.FORWARD, steps, 1.1, plate, rise, 0.27, false, _metal)
	for i: int in 2:
		var lp := Vector3(-_w * 0.2 + i * _w * 0.4, h - 0.6, 0)
		b.box(lp, Vector3(0.6, 0.1, 0.6), _metal, false)
		b.box(lp + Vector3.DOWN * 0.06, Vector3(0.45, 0.02, 0.45), SlumMats.color(Color(1.0, 0.9, 0.75), 4.0), false, false)
		add_light(lp + Vector3.DOWN * 0.5, Color(1.0, 0.85, 0.65), 2.5, 12.0, 0.08 if i == 1 else 0.0)


# ================================================================== Shanty

func _shanty(b: SlumBuilder) -> void:
	var sh := stilt_height
	var wood := SlumMats.surface("wood")
	var dark_wood := SlumMats.surface("wood_dark")
	var mats := ["corrugated_blue", "corrugated_rust", "corrugated_green", "corrugated_grey", "wood", "plaster_teal"]
	# Plattform auf Stelzen
	if sh > 0.05:
		b.box(Vector3(0, sh - 0.08, 0), Vector3(_w, 0.16, _d), wood)
		var stilt_mat: Material = SlumMats.surface("rust") if rng.randf() < 0.5 else dark_wood
		for x: float in [-_w * 0.5 + 0.15, 0.0, _w * 0.5 - 0.15]:
			for z: float in [-_d * 0.5 + 0.15, _d * 0.5 - 0.15]:
				b.box(Vector3(x + rng.randf_range(-0.1, 0.1), (sh - 0.16) * 0.5, z), Vector3(0.18, sh - 0.16, 0.18), stilt_mat, true)
		# Querstreben
		for z: float in [-_d * 0.5 + 0.15, _d * 0.5 - 0.15]:
			var a := Vector3(-_w * 0.5 + 0.15, 0.3, z)
			var e := Vector3(0, sh - 0.3, z)
			b.tube(a, e, 0.05, stilt_mat, 4)
			b.tube(Vector3(_w * 0.5 - 0.15, 0.3, z), e, 0.05, stilt_mat, 4)
	var hut_w := _w - 1.4
	var hut_d := _d - 1.5
	var hh := floor_height - 0.4
	# Vorne bleibt ein 1,2 m breiter Gang frei (Treppen und Stege docken dort an).
	var base := Vector3(-0.3, sh, -0.45)
	# Wände aus Flicken: jede Wand in 2–3 Paneele aus verschiedenen Materialien
	_patch_wall(b, base + Vector3(0, 0, -hut_d * 0.5), Vector3.RIGHT, hut_w, hh, mats, false)
	_patch_wall(b, base + Vector3(-hut_w * 0.5, 0, 0), Vector3.FORWARD, hut_d, hh, mats, false)
	_patch_wall(b, base + Vector3(hut_w * 0.5, 0, 0), Vector3.FORWARD, hut_d, hh, mats, true)
	_patch_wall(b, base + Vector3(0, 0, hut_d * 0.5), Vector3.RIGHT, hut_w, hh, mats, false, true)
	# Schräges Wellblechdach mit Überstand
	var roof := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10)), base + Vector3(0, hh + 0.25, 0.2))
	b.box_x(roof, Vector3(hut_w + 0.7, 0.05, hut_d + 1.2), SlumMats.surface(pick(["corrugated_rust", "corrugated_grey"])))
	# Plane über einem Teil
	var tarp := SlumMats.surface(pick(["tarp_blue", "tarp_red"]))
	b.box_x(roof * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(4)), Vector3(hut_w * 0.25, 0.06, 0)), Vector3(hut_w * 0.55, 0.02, hut_d + 1.0), tarp, false)
	b.box(base + Vector3(hut_w * 0.5 + 0.1, hh * 0.45, hut_d * 0.25), Vector3(0.02, hh * 0.8, 1.2), tarp, false)
	# Licht innen + Glühbirne
	var col: Color = pick([Color(1.0, 0.7, 0.4), Color(1.0, 0.55, 0.3), Color(0.6, 0.9, 1.0)])
	b.box(base + Vector3(0, hh - 0.35, 0), Vector3(0.08, 0.1, 0.08), SlumMats.color(col, 8.0), false, false)
	add_light(base + Vector3(0, hh - 0.6, 0.3), col, 1.3, 5.0, 0.15)
	# Innen ein paar Sachen
	b.box(base + Vector3(-hut_w * 0.3, 0.25, -hut_d * 0.3), Vector3(1.2, 0.5, 0.7), SlumMats.color(Color(0.3, 0.2, 0.2), 0.0, 0.9), true)
	b.box(base + Vector3(hut_w * 0.3, 0.4, -hut_d * 0.3), Vector3(0.6, 0.8, 0.5), SlumMats.uv("crate_wood"), true)
	# Geländer am Plattformrand und Treppe
	if sh > 0.05:
		var y := sh
		var x0 := -_w * 0.5 + 0.05
		var x1 := _w * 0.5 - 0.05
		var z0 := -_d * 0.5 + 0.05
		var z1 := _d * 0.5 - 0.05
		var stair_w := 1.0
		var steps := int(roundf(sh / 0.2))
		var rise := sh / steps
		var run := 0.27
		var rail := SlumMats.surface("wood_dark")
		b.railing(Vector3(x0, y, z0), Vector3(x1, y, z0), rail, 0.95, 1.0)
		b.railing(Vector3(x0, y, z1), Vector3(x1, y, z1), rail, 0.95, 1.0)
		if shanty_stair == Side.NONE:
			if not open_left:
				b.railing(Vector3(x0, y, z0), Vector3(x0, y, z1), rail, 0.95, 1.0)
			if not open_right:
				b.railing(Vector3(x1, y, z0), Vector3(x1, y, z1), rail, 0.95, 1.0)
		else:
			# Treppe außen an der Seite, läuft nach -Z hoch; oben ist das Geländer offen.
			var sx := signf(1.0 if shanty_stair == Side.RIGHT else -1.0)
			var edge := x1 if sx > 0.0 else x0
			var other := x0 if sx > 0.0 else x1
			var stair_x := edge + sx * (stair_w * 0.5 + 0.02)
			var top_z := z1 - 1.0
			var bottom_z := top_z + steps * run
			b.stairs(Vector3(stair_x, 0, bottom_z), Vector3.FORWARD, steps, stair_w, wood, rise, run, false, rail)
			var other_open := open_left if sx > 0.0 else open_right
			if not other_open:
				b.railing(Vector3(other, y, z0), Vector3(other, y, z1), rail, 0.95, 1.0)
			b.railing(Vector3(edge, y, z0), Vector3(edge, y, top_z - 0.1), rail, 0.95, 1.0)
			var out_x := stair_x + sx * stair_w * 0.5
			_slanted_rail(b, Vector3(out_x, 0, bottom_z), Vector3(out_x, sh, top_z))
	# Kram unter der Plattform
	if sh > 1.5:
		b.box(Vector3(_w * 0.25, 0.3, -_d * 0.2), Vector3(0.6, 0.6, 0.6), SlumMats.uv("crate_wood"), true, true, 20)
		b.cylinder(Vector3(-_w * 0.25, 0, 0), 0.29, 0.88, SlumMats.uv("barrel_rust"), 10, true)


## Wand aus Paneelen entlang dir (Breite length) ab start (Mitte unten). door = Öffnung in der Mitte,
## window = kleines Fenster mit Licht.
func _patch_wall(b: SlumBuilder, center: Vector3, dir: Vector3, length: float, h: float, mats: Array,
		window: bool, door := false) -> void:
	var count := rng.randi_range(2, 3)
	var seg := length / count
	# Senkrecht zur Wand. Zeigt bei Vorder-/Rückwand nach +Z, bei Seitenwänden nach +X.
	var n := dir.cross(Vector3.UP).normalized()
	for i: int in count:
		var u := -length * 0.5 + seg * (i + 0.5)
		var p := center + dir * u + Vector3.UP * h * 0.5 + n * (0.02 * (i % 2))
		var size := Vector3(seg + 0.04, h + rng.randf_range(-0.1, 0.1), 0.06)
		if door and i == count / 2:
			# Türöffnung: nur Sturz
			var lintel := SlumBuilder.facing(p + Vector3.UP * (h * 0.5 - 0.25), n)
			b.box_x(lintel, Vector3(seg + 0.04, 0.5, 0.06), SlumMats.surface(pick(mats)), false)
			continue
		var xf := SlumBuilder.facing(p, n)
		# Steht auf der Plattform: keine Unterseite (läge in der Plattform-Oberseite)
		b.box_x(xf, size, SlumMats.surface(pick(mats)), true, true, 0.0, true, true)
		if window and i == 0:
			b.quad_x(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0.03 + DECAL_OPENING)), 0.7, 0.6,
					SlumMats.decal("window_lit2", "window_emit", Color(1.0, 0.7, 0.4), 1.4))
			b.quad_x(xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.2, -0.03 - DECAL_OPENING)), 0.7, 0.6, SlumMats.decal("window_dark"))


# ================================================================== Hochhaus (Hintergrund)

func _tower(b: SlumBuilder) -> void:
	b.box(Vector3(0, _h * 0.5, 0), Vector3(_w, _h, _d), _tower_mat())
	# Stufen/Rücksprünge oben und Antennen machen die Silhouette interessant
	var top_w := _w * rng.randf_range(0.5, 0.8)
	var top_d := _d * rng.randf_range(0.5, 0.8)
	var top_h := floor_height * rng.randi_range(2, 5)
	b.box(Vector3(rng.randf_range(-1, 1), _h + top_h * 0.5, rng.randf_range(-1, 1)), Vector3(top_w, top_h, top_d), _tower_mat(), false)
	for i: int in rng.randi_range(1, 3):
		var p := Vector3(rng.randf_range(-top_w * 0.4, top_w * 0.4), _h + top_h, rng.randf_range(-top_d * 0.4, top_d * 0.4))
		var ah := rng.randf_range(3.0, 9.0)
		b.tube(p, p + Vector3.UP * ah, 0.08, _metal, 4)
		b.box(p + Vector3.UP * ah, Vector3(0.25, 0.25, 0.25), SlumMats.color(Color(1.0, 0.1, 0.1), 8.0), false, false)
	if front_sign != "":
		_flat_sign(b, Vector3(0, _h * rng.randf_range(0.55, 0.8), _d * 0.5 + 0.2), Vector3.BACK, front_sign, minf(_w * 0.6, 9.0))
	if side_sign != "":
		_vertical_sign(b, Vector3(_w * 0.5 - 1.0, _h * 0.5, _d * 0.5), side_sign)


func _tower_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scenes/slum/slum_facade.gdshader")
	mat.set_shader_parameter("wall_tex", SlumMats.texture(wall))
	mat.set_shader_parameter("grime_tex", SlumMats.texture("grime"))
	mat.set_shader_parameter("tint", wall_tint)
	mat.set_shader_parameter("tile_meters", float(SlumMats.TILE_METERS.get(wall, 2.0)))
	mat.set_shader_parameter("cell_size", Vector2(2.6, floor_height))
	mat.set_shader_parameter("lit_ratio", lit_ratio)
	mat.set_shader_parameter("seed_offset", float(seed_value) * 13.7)
	return mat
