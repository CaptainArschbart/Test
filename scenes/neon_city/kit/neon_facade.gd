@tool
class_name NeonFacade
extends RefCounted
## Fassaden der Neon City aus den Bauteil-Packs (Quaternius Downtown City, Kenney Retro Urban).
##
## Ein NeonTower mit `kit` legt pro Stockwerk und Seite Wandstücke vor seinen Baukörper: Fenster,
## Schaufenster, Türen, Gesimse. Gleiche Stücke eines Hauses werden als MultiMesh gezeichnet (ein
## Draw-Call pro Stücktyp und Block aus acht Stockwerken, die Blöcke helfen beim Frustum-Culling).
## Gemessen: die ganze Neon City mit allen Fassaden läuft schneller als Sektor 7, darum gibt es keine
## Detailstufe. Fenster mit Innenraum (Downtown: Material MI_FakeInterior) leuchten zufällig nach
## lit_ratio, bei Kenney liegt dafür ein Lichtfeld im Rahmen.

const DT := "res://assets/buildings/quaternius_downtown_city/%s.gltf"
const KN := "res://assets/buildings/kenney_retro_urban/%s.glb"
const FLOORS_PER_CHUNK := 8
## Abstand der Stücke vor der Wand (gegen Z-Fighting mit dem Baukörper).
const OFFSET := 0.03

## module = Breite eines Stücks (m), scale = Faktor auf das Modell, yaw = Drehung, bis die Vorderseite
## nach +Z zeigt. upper/wide/ground: [Name, Gewicht]; wide-Stücke sind zwei Module breit.
## fill = Farbe des Baukörpers (sichtbar an Ecken und Rändern). glow = Lichtfeld im Fensterrahmen
## (Mitte, Größe in Metern) für Stücke ohne eigenen Innenraum.
const KITS := {
	&"dt_brick": {"base": DT, "module": 2.0, "scale": 1.0, "yaw": 0.0, "fill": Color(0.33, 0.17, 0.13),
		"upper": [["Brick_Window_Square_Single", 3], ["Brick_Window_Trim_Single", 2], ["Brick_Window_Trim", 2], ["Brick_Plain_3", 1]],
		"wide": [["Brick_Inset_Window", 1], ["Brick_RedWhite_DoubleWindow", 1], ["Brick_Window_CurvedDouble", 1]],
		"ground": [["Metal_FirstFloor_Window", 1]], "ground_plain": "Brick_BottomTrim", "door": "DoorFrame_Metal_Single",
		"cornice": "Cornice_Brick_Center"},
	&"dt_metal": {"base": DT, "module": 2.0, "scale": 1.0, "yaw": 0.0, "fill": Color(0.2, 0.2, 0.22),
		"upper": [["Metal_FullWindow", 4], ["Metal_Window_Half", 1]], "wide": [["Metal_Window", 1]],
		"ground": [["Metal_FirstFloor_Window", 1]], "ground_plain": "Metal_FirstFloor_Wall", "door": "DoorFrame_Metal_Single",
		"cornice": "Cornice_Metal_Center"},
	&"dt_trim": {"base": DT, "module": 2.0, "scale": 1.0, "yaw": 0.0, "fill": Color(0.55, 0.5, 0.42),
		"upper": [["Trim_Window", 4], ["Trim_Plain_3", 1]], "wide": [],
		"ground": [["Trim_FirstFloor_Window_001", 1]], "ground_plain": "Trim_FirstFloor_Wall", "door": "DoorFrame_Trim",
		"cornice": "Cornice_Trim_Center"},
	&"kn_brick": {"base": KN, "module": 3.0, "scale": 3.0, "yaw": 180.0, "fill": Color(0.36, 0.2, 0.16),
		"upper": [["wall-a-flat-window", 3], ["wall-a-flat", 1]], "wide": [],
		"ground": [["wall-a-flat-window", 1]], "ground_plain": "wall-a-flat", "door": "wall-a-flat", "door_overlay": "door-type-a",
		"garage": "wall-a-flat-garage", "cornice": "", "glow": [Vector2(0.0, 1.62), Vector2(1.55, 1.4)]},
	&"kn_metal": {"base": KN, "module": 3.0, "scale": 3.0, "yaw": 180.0, "fill": Color(0.36, 0.48, 0.36),
		"upper": [["wall-b-flat-window", 3], ["wall-b-flat", 2]], "wide": [],
		"ground": [["wall-b-flat-window", 1]], "ground_plain": "wall-b-flat", "door": "wall-b-flat", "door_overlay": "door-type-a",
		"garage": "wall-b-flat-garage", "cornice": "", "glow": [Vector2(0.0, 1.62), Vector2(1.55, 1.4)]},
}

static var _pieces := {}


## So weit springt der Baukörper hinter die Fassadenebene zurück: Fenster und Innenraum der Stücke
## liegen bis 0,26 m hinter ihrer Vorderkante und wären sonst im Baukörper verborgen.
const INSET := 0.3


static func module(kit: StringName) -> float:
	return KITS[kit]["module"]


static func has_kit(kit: StringName) -> bool:
	return KITS.has(kit)


static func fill_color(kit: StringName) -> Color:
	return KITS[kit]["fill"]


## Mesh eines Stücks (dunkel bzw. beleuchtet) und seine Lage im Modell. Gecacht.
static func piece(path: String) -> Dictionary:
	if _pieces.has(path):
		return _pieces[path]
	var info := {}
	var scene := load(path) as PackedScene
	if scene != null:
		var inst: Node3D = scene.instantiate()
		var mis := inst.find_children("*", "MeshInstance3D", true, false)
		if not mis.is_empty():
			var mi := mis[0] as MeshInstance3D
			var xf := Transform3D()
			var n: Node = mi
			while n != inst and n != null:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var dark := mi.mesh.duplicate() as Mesh
			var lit := mi.mesh.duplicate() as Mesh
			var interior := false
			for i in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(i)
				if mat != null and mat.resource_name.contains("FakeInterior") and mat is BaseMaterial3D:
					interior = true
					# An: gleichmäßig warmes Zimmerlicht hinter der Scheibe. Aus: der Innenraum wie im Pack
					# (tagsüber sieht man Räume, nachts ist er dunkel).
					var on := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					on.emission_enabled = true
					on.emission = Color(1.0, 0.8, 0.52)
					on.emission_energy_multiplier = 3.0
					lit.surface_set_material(i, on)
					dark.surface_set_material(i, mat)
				elif mat != null and mat.resource_name.contains("Glass"):
					# Das Glas aus dem Pack ist fast schwarz: heller und leicht blau, damit es den Himmel aufnimmt.
					dark.surface_set_material(i, _glass())
					lit.surface_set_material(i, _glass())
				elif mat != null:
					dark.surface_set_material(i, mat)
					lit.surface_set_material(i, mat)
			info = {"dark": dark, "lit": lit, "xform": xf, "interior": interior}
		inst.free()
	_pieces[path] = info
	return info


## Legt die Stücke für eine Stufe des Hauses an. out sammelt "Pfad|lit|Block" -> Array[Transform3D].
## glow sammelt Lichtfelder (Transform3D, Größe, an/aus) für Kenney-Fenster.
static func layout(kit_name: StringName, size: Vector2, y0: float, y1: float, floor_height: float, ground_tier: bool,
		shop_front: bool, industrial: bool, lit_ratio: float, rng: RandomNumberGenerator, out: Dictionary, glow: Array) -> void:
	var kit: Dictionary = KITS[kit_name]
	var module: float = kit["module"]
	var s: float = kit["scale"]
	var base: String = kit["base"]
	var first := int(round(y0 / floor_height))
	var last := int(round(y1 / floor_height))
	for side in 4:
		var normal: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][side]
		var along := size.x if side % 2 == 0 else size.y
		var depth := size.y if side % 2 == 0 else size.x
		var n := int(along / module + 0.001)
		if n < 1:
			continue
		var tangent := normal.cross(Vector3.UP)
		var basis := Basis(Vector3.UP, atan2(normal.x, normal.z) + deg_to_rad(kit["yaw"])).scaled(Vector3.ONE * s)
		# Spalten: gleiche Fensterart übereinander, ab und zu ein doppelt breites Stück.
		var columns: Array = []
		var i := 0
		while i < n:
			if not (kit["wide"] as Array).is_empty() and i + 1 < n and rng.randf() < 0.3:
				columns.append([_pick(kit["wide"], rng), 2])
				i += 2
			else:
				columns.append([_pick(kit["upper"], rng), 1])
				i += 1
		var door_col := columns.size() / 2
		var face := normal * (depth * 0.5 + OFFSET)
		for f in range(first, last):
			var cursor := -module * n * 0.5
			for c in columns.size():
				var width: int = columns[c][1]
				var cx := cursor + module * width * 0.5
				cursor += module * width
				var name: String = columns[c][0]
				if f == 0 and ground_tier:
					name = _ground_piece(kit, side, c == door_col, shop_front, industrial, rng)
					if width == 2:
						# Erdgeschoss in zwei Modulen statt eines breiten Fensters.
						for k in 2:
							var nm := name if k == 0 else _ground_piece(kit, side, false, shop_front, industrial, rng)
							_add(out, glow, kit, base % nm, Transform3D(basis, face + tangent * (cx + (k - 0.5) * module) + Vector3.UP * f * floor_height),
									f, lit_ratio, rng, normal)
						continue
				_add(out, glow, kit, base % name, Transform3D(basis, face + tangent * cx + Vector3.UP * f * floor_height), f, lit_ratio, rng, normal)
				if f == 0 and ground_tier and c == door_col and side == 0 and not shop_front and kit.has("door_overlay"):
					_add(out, glow, kit, base % String(kit["door_overlay"]),
							Transform3D(basis, face + normal * 0.02 + tangent * cx + Vector3.UP * f * floor_height), f, 0.0, rng, normal)
		# Gesims oben auf der Stufe.
		if String(kit["cornice"]) != "":
			var path := base % String(kit["cornice"])
			for k in n:
				var cx := -module * n * 0.5 + module * (k + 0.5)
				_add(out, glow, kit, path, Transform3D(basis, face + tangent * cx + Vector3.UP * (y1 - 1.0)), last, 0.0, rng, normal)


static func _ground_piece(kit: Dictionary, side: int, door: bool, shop_front: bool, industrial: bool, rng: RandomNumberGenerator) -> String:
	if side == 0:
		if industrial and kit.has("garage"):
			return kit["garage"] if rng.randf() < 0.6 else kit["ground_plain"]
		if door and not shop_front:
			return kit["door"]
		if shop_front:
			return _pick(kit["ground"], rng)
	return kit["ground_plain"] if rng.randf() < 0.7 else _pick(kit["ground"], rng)


static func _add(out: Dictionary, glow: Array, kit: Dictionary, path: String, xf: Transform3D, floor_index: int,
		lit_ratio: float, rng: RandomNumberGenerator, normal: Vector3) -> void:
	var info := piece(path)
	if info.is_empty():
		return
	var lit := rng.randf() < lit_ratio
	if kit.has("glow") and path.contains("window"):
		var g: Array = kit["glow"]
		var center: Vector2 = g[0]
		glow.append([Transform3D(Basis(Vector3.UP, atan2(normal.x, normal.z)), xf.origin + normal * 0.05 + Vector3.UP * center.y), g[1], lit])
		lit = false
	var key := "%s|%d|%d" % [path, 1 if lit and info["interior"] else 0, floor_index / FLOORS_PER_CHUNK]
	if not out.has(key):
		out[key] = []
	(out[key] as Array).append(xf * (info["xform"] as Transform3D))


## Baut aus den gesammelten Lagen MultiMesh-Knoten unter owner.
static func commit(owner: SlumPiece, out: Dictionary) -> void:
	for key: String in out:
		var parts := key.split("|")
		var info := piece(parts[0])
		var xfs: Array = out[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = info["lit"] if parts[1] == "1" else info["dark"]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var node := MultiMeshInstance3D.new()
		node.name = "Facade"
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		owner.add_gen(node)


static func _glass() -> StandardMaterial3D:
	if not _pieces.has("_glass"):
		var m := StandardMaterial3D.new()
		m.resource_name = "NeonGlass"
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		m.albedo_color = Color(0.46, 0.56, 0.66, 0.62)
		m.metallic = 0.35
		m.roughness = 0.12
		_pieces["_glass"] = m
	return _pieces["_glass"]


static func _pick(list: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for e: Array in list:
		total += int(e[1])
	var r := rng.randi() % maxi(total, 1)
	for e: Array in list:
		r -= int(e[1])
		if r < 0:
			return e[0]
	return list[0][0]
