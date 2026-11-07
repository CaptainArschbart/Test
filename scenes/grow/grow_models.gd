class_name GrowModels
extends RefCounted
## Prozedurale Modelle für den Anbau (keine Modelldateien): Hanfpflanze in allen Stadien, Topf,
## LED-Growlampe, Trockengestell, Fermentierglas, Verpackungstisch mit Feinwaage und die kleinen
## Items (Erde, Samen, Dünger, Blüten, Tütchen, Gläser). Alles in echter Größe, Meter, +Y oben.
##
## Pflanze: Hauptstamm mit Knoten, an jedem Knoten zwei gegenständige Fächerblätter (sieben gesägte
## Fiederblättchen, das mittlere am längsten), im Wachstum Seitentriebe, in der Blüte Blütenstände
## (Colas) an Spitze und Triebenden mit Stempeln: weiß, später orange, dazu Harzglanz. Gesundheit
## färbt die Blätter von Grün nach Gelbbraun und lässt sie hängen.
## Die Pflanze besteht aus drei Meshes (Stamm, Blätter, Blüten), damit viele Töpfe wenig kosten.

static var _mats := {}


# --- Pflanze ------------------------------------------------------------------------------------

## size 0…1 (Keimling bis ausgewachsen), flower 0…1.3 (Blüte, über 1 überreif), health 0…1.
static func plant(size: float, flower: float, health: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Plant"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	size = clampf(size, 0.0, 1.0)
	var height := 0.06 + 0.95 * size
	var nodes := maxi(1, int(2 + size * 8.0))
	var stem := SurfaceTool.new()
	stem.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var buds := SurfaceTool.new()
	buds.begin(Mesh.PRIMITIVE_TRIANGLES)
	var green := Color(0.16, 0.42, 0.12).lerp(Color(0.62, 0.55, 0.16), clampf(1.0 - health, 0.0, 1.0))
	if flower > 1.05:
		# Spätblüte: ältere Blätter werden gelb (normal am Ende der Blüte).
		green = green.lerp(Color(0.7, 0.62, 0.2), clampf((flower - 1.05) * 1.5, 0.0, 0.6))
	var droop := clampf(1.0 - health, 0.0, 1.0) * 0.9
	var stem_r := 0.004 + 0.01 * size
	_cylinder(stem, Vector3.ZERO, Vector3(0, height, 0), stem_r, stem_r * 0.4, Color(0.3, 0.45, 0.18))
	for i in nodes:
		var t := float(i + 1) / float(nodes + 1)
		var y := height * t
		var twist := i * PI * 0.5
		var leaf_len := (0.06 + 0.21 * size) * (1.0 - t * 0.45)
		for side in [-1.0, 1.0]:
			var dir := Vector3(cos(twist) * side, 0.0, sin(twist) * side)
			var base := Vector3(0, y, 0)
			var petiole := base + dir * (0.03 + 0.05 * size) + Vector3.UP * (0.02 - droop * 0.05)
			_cylinder(stem, base, petiole, stem_r * 0.35, stem_r * 0.25, Color(0.32, 0.48, 0.2))
			_fan_leaf(leaves, petiole, dir, leaf_len, 0.25 - droop * 0.9, green)
			# Seitentriebe ab halber Größe, unten länger.
			if size > 0.45 and i < nodes - 2:
				var branch_len := (0.08 + 0.22 * size) * (1.0 - t)
				var tip := base + dir.rotated(Vector3.UP, 0.6) * branch_len + Vector3.UP * branch_len * 0.9
				_cylinder(stem, base, tip, stem_r * 0.5, stem_r * 0.3, Color(0.3, 0.45, 0.18))
				_fan_leaf(leaves, tip, dir.rotated(Vector3.UP, 0.6), leaf_len * 0.7, 0.4 - droop, green)
				if flower > 0.05:
					_cola(buds, tip, minf(flower, 1.0) * (0.03 + 0.04 * size), flower, rng)
	# Spitze: kleines Blattbüschel, in der Blüte die Hauptcola.
	_fan_leaf(leaves, Vector3(0, height, 0), Vector3.RIGHT, 0.04 + 0.05 * size, 1.2, green)
	if flower > 0.05:
		_cola(buds, Vector3(0, height, 0), minf(flower, 1.0) * (0.05 + 0.08 * size), flower, rng)
	root.add_child(_instance(stem, "Stem", _mat(&"plant_stem", Color.WHITE, true)))
	root.add_child(_instance(leaves, "Leaves", _mat(&"plant_leaf", Color.WHITE, true, true)))
	if flower > 0.05:
		root.add_child(_instance(buds, "Buds", _mat(&"plant_bud", Color.WHITE, true)))
	return root


## Fächerblatt: sieben gesägte Fiederblättchen fächerförmig vom Blattstielende aus.
static func _fan_leaf(st: SurfaceTool, at: Vector3, dir: Vector3, length: float, lift: float, color: Color) -> void:
	var forward := Vector3(dir.x, 0.0, dir.z).normalized()
	if forward.length() < 0.01:
		forward = Vector3.RIGHT
	var side := forward.cross(Vector3.UP).normalized()
	var spread := [-1.25, -0.82, -0.4, 0.0, 0.4, 0.82, 1.25]
	var lengths := [0.42, 0.68, 0.9, 1.0, 0.9, 0.68, 0.42]
	for k in 7:
		var a: float = spread[k]
		var leaf_dir := (forward * cos(a) + side * sin(a)) * cos(lift * 0.6) + Vector3.UP * sin(lift * 0.6) * (1.0 - absf(a) * 0.3)
		leaf_dir = leaf_dir.normalized()
		var leaf_l: float = length * lengths[k]
		var width := leaf_l * 0.16
		var normal := leaf_dir.cross(side.rotated(Vector3.UP, a)).normalized()
		var lateral := normal.cross(leaf_dir).normalized()
		# Lanzettlich mit Sägezähnen: Punkte entlang des Blättchens.
		var steps := 6
		var prev_l := at
		var prev_r := at
		for s in range(1, steps + 1):
			var u := float(s) / steps
			var w := sin(u * PI) * width * (1.0 if s % 2 == 0 else 0.78)
			var center := at + leaf_dir * leaf_l * u
			var l := center + lateral * w
			var r := center - lateral * w
			var shade := color.lerp(color.lightened(0.25), u * 0.5)
			_tri(st, prev_l, l, center, shade, normal)
			_tri(st, prev_l, center, prev_r, shade, normal)
			_tri(st, prev_r, center, r, shade, normal)
			prev_l = l
			prev_r = r


## Blütenstand: dichte Kelche, weiße bis orange Stempel, Harzglanz.
static func _cola(st: SurfaceTool, at: Vector3, size: float, flower: float, rng: RandomNumberGenerator) -> void:
	if size <= 0.002:
		return
	var bud_color := Color(0.35, 0.55, 0.22).lerp(Color(0.42, 0.5, 0.28), clampf(flower - 0.6, 0.0, 0.5))
	var pistil := Color(0.95, 0.95, 0.9).lerp(Color(0.85, 0.45, 0.12), clampf((flower - 0.55) * 1.6, 0.0, 1.0))
	var count := 6 + int(size * 120.0)
	for i in count:
		var h := rng.randf() * size * 2.2
		var r := size * 0.45 * (1.0 - h / (size * 2.6))
		var a := rng.randf() * TAU
		var p := at + Vector3(cos(a) * r, h - size * 0.3, sin(a) * r)
		_blob(st, p, size * rng.randf_range(0.18, 0.3), bud_color.lerp(Color(0.85, 0.9, 0.8), rng.randf() * 0.25))
		if i % 2 == 0:
			var out := Vector3(cos(a), 0.4, sin(a)).normalized()
			_cylinder(st, p, p + out * size * 0.35, size * 0.025, size * 0.01, pistil)


static func _blob(st: SurfaceTool, at: Vector3, r: float, color: Color) -> void:
	# Oktaeder als kleiner Kelch.
	var pts := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r, 0), Vector3(0, -r, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	var faces := [[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5]]
	for f: Array in faces:
		var a: Vector3 = at + pts[f[0]]
		var b: Vector3 = at + pts[f[1]]
		var c: Vector3 = at + pts[f[2]]
		_tri(st, a, b, c, color, (b - a).cross(c - a).normalized())


static func _cylinder(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, color: Color) -> void:
	var axis := b - a
	if axis.length() < 0.0005:
		return
	var y := axis.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var seg := 6
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := x * cos(a0) + z * sin(a0)
		var d1 := x * cos(a1) + z * sin(a1)
		var p0 := a + d0 * ra
		var p1 := a + d1 * ra
		var q0 := b + d0 * rb
		var q1 := b + d1 * rb
		_tri(st, p0, q0, q1, color, d0)
		_tri(st, p0, q1, p1, color, d1)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, normal: Vector3) -> void:
	for p: Vector3 in [a, b, c]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(p)


static func _instance(st: SurfaceTool, name: String, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


# --- Stationen ----------------------------------------------------------------------------------

## Pflanztopf 11 l (schwarzer Kunststoff), optional mit Erde.
static func pot(soil: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Pot"
	_mesh(root, _tube(0.15, 0.115, 0.26), _mat(&"pot", Color(0.06, 0.06, 0.07)), Vector3(0, 0.13, 0))
	_mesh(root, _tube(0.158, 0.158, 0.02), _mat(&"pot_rim", Color(0.09, 0.09, 0.1)), Vector3(0, 0.255, 0))
	if soil:
		_mesh(root, _tube(0.14, 0.14, 0.01), _mat(&"soil", Color(0.17, 0.11, 0.07)), Vector3(0, 0.235, 0))
	return root


## LED-Growlampe auf Ständer: Panel 0,6 × 0,3 m in 1,6 m Höhe, leuchtet violett (18/6) bzw. warm (12/12).
static func lamp(on: bool, flower_cycle: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Lamp"
	var metal := _mat(&"lamp_metal", Color(0.2, 0.21, 0.23))
	_mesh(root, _box(Vector3(0.5, 0.02, 0.4)), metal, Vector3(0, 0.01, 0))
	_mesh(root, _tube(0.015, 0.015, 1.6), metal, Vector3(-0.22, 0.81, 0))
	_mesh(root, _box(Vector3(0.3, 0.02, 0.02)), metal, Vector3(-0.08, 1.62, 0))
	_mesh(root, _box(Vector3(0.62, 0.04, 0.32)), _mat(&"lamp_panel", Color(0.1, 0.1, 0.11)), Vector3(0.12, 1.6, 0))
	var glow := Color(0.85, 0.35, 1.0) if not flower_cycle else Color(1.0, 0.65, 0.4)
	var diodes := _mat(&"lamp_on_veg" if not flower_cycle else &"lamp_on_flower", glow, false, false, 3.0) if on \
		else _mat(&"lamp_off", Color(0.15, 0.15, 0.17))
	_mesh(root, _box(Vector3(0.56, 0.005, 0.27)), diodes, Vector3(0.12, 1.578, 0))
	return root


## Trockengestell: Rahmen mit zwei Leinen, daran hängen Äste mit Blüten (fill 0…1), dry 0…1 färbt sie.
static func rack(fill: float, dry: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Rack"
	var wood := _mat(&"rack_wood", Color(0.45, 0.32, 0.2))
	for x in [-0.45, 0.45]:
		_mesh(root, _box(Vector3(0.04, 1.4, 0.04)), wood, Vector3(x, 0.7, -0.2))
		_mesh(root, _box(Vector3(0.04, 1.4, 0.04)), wood, Vector3(x, 0.7, 0.2))
		_mesh(root, _box(Vector3(0.04, 0.04, 0.44)), wood, Vector3(x, 1.38, 0))
	var line := _mat(&"rack_line", Color(0.85, 0.85, 0.8))
	for z in [-0.1, 0.1]:
		_mesh(root, _box(Vector3(0.9, 0.006, 0.006)), line, Vector3(0, 1.36, z))
	var branches := int(round(clampf(fill, 0.0, 1.0) * 12.0))
	var color := Color(0.3, 0.5, 0.2).lerp(Color(0.42, 0.42, 0.22), clampf(dry, 0.0, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in branches:
		var x := -0.38 + (i % 6) * 0.15
		var z := -0.1 if i < 6 else 0.1
		var top := Vector3(x, 1.35, z)
		var bottom := top + Vector3(rng.randf_range(-0.02, 0.02), -0.35 + dry * 0.05, 0.0)
		_cylinder(st, top, bottom, 0.005, 0.004, Color(0.4, 0.42, 0.22))
		for k in 5:
			var p := top.lerp(bottom, 0.25 + k * 0.17)
			_blob(st, p + Vector3(rng.randf_range(-0.015, 0.015), 0, 0.012), 0.022 * (1.0 - dry * 0.3), color)
	if branches > 0:
		root.add_child(_instance(st, "Buds", _mat(&"plant_bud", Color.WHITE, true)))
	return root


## Fermentierglas 2 l (Einmachglas mit Bügelverschluss) auf Regalbrett, fill 0…1, Schimmel grau-weiß.
static func jar(fill: float, mold: bool, open: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "CuringJar"
	_mesh(root, _box(Vector3(0.3, 0.03, 0.3)), _mat(&"rack_wood", Color(0.45, 0.32, 0.2)), Vector3(0, 0.015, 0))
	_mesh(root, _tube(0.075, 0.075, 0.22), _glass(), Vector3(0, 0.14, 0))
	_mesh(root, _tube(0.077, 0.077, 0.02), _mat(&"jar_lid", Color(0.75, 0.75, 0.78), false, false, 0.0, 0.8),
		Vector3(0, 0.26 + (0.05 if open else 0.0), 0))
	if fill > 0.01:
		var h := 0.2 * clampf(fill, 0.0, 1.0)
		var content := Color(0.32, 0.38, 0.2) if not mold else Color(0.75, 0.75, 0.7)
		_mesh(root, _tube(0.068, 0.068, h), _mat(&"jar_content_mold" if mold else &"jar_content", content), Vector3(0, 0.035 + h * 0.5, 0))
	return root


## Verpackungstisch: Tisch, Feinwaage mit Anzeige, Kiste Tütchen, zwei Gläser.
static func table() -> Node3D:
	var root := Node3D.new()
	root.name = "PackingTable"
	var top := _mat(&"table_top", Color(0.18, 0.18, 0.2))
	_mesh(root, _box(Vector3(1.0, 0.04, 0.55)), top, Vector3(0, 0.76, 0))
	for x in [-0.46, 0.46]:
		for z in [-0.24, 0.24]:
			_mesh(root, _box(Vector3(0.04, 0.74, 0.04)), _mat(&"lamp_metal", Color(0.2, 0.21, 0.23)), Vector3(x, 0.37, z))
	# Feinwaage (0,01 g) mit leuchtender Anzeige.
	_mesh(root, _box(Vector3(0.12, 0.025, 0.16)), _mat(&"scale_body", Color(0.75, 0.76, 0.8), false, false, 0.0, 0.6), Vector3(-0.2, 0.793, 0.05))
	_mesh(root, _box(Vector3(0.1, 0.004, 0.1)), _mat(&"scale_plate", Color(0.85, 0.86, 0.9), false, false, 0.0, 0.9), Vector3(-0.2, 0.807, 0.03))
	_mesh(root, _box(Vector3(0.06, 0.002, 0.025)), _mat(&"scale_display", Color(0.3, 1.0, 0.6), false, false, 2.0), Vector3(-0.2, 0.806, 0.115))
	# Tütchen-Box und zwei Gläser.
	_mesh(root, _box(Vector3(0.16, 0.06, 0.1)), _mat(&"bag_box", Color(0.3, 0.3, 0.32)), Vector3(0.12, 0.81, -0.12))
	for x in [0.3, 0.38]:
		_mesh(root, _tube(0.03, 0.03, 0.08), _glass(), Vector3(x, 0.82, 0.1))
	return root


## Standard-Aussehen einer Station (Icons, Vorschau beim Aufstellen, Pickups).
static func station(kind: StringName) -> Node3D:
	match kind:
		&"pot":
			return pot(true)
		&"lamp":
			return lamp(true, false)
		&"rack":
			return rack(0.5, 0.0)
		&"jar":
			return jar(0.7, false)
		&"table":
			return table()
	return pot(false)


## Größe der Grundfläche einer Station (x, Höhe, z) für Kollision und Platzprüfung.
static func footprint(kind: StringName) -> Vector3:
	match kind:
		&"lamp":
			return Vector3(0.5, 1.65, 0.4)
		&"rack":
			return Vector3(0.96, 1.42, 0.46)
		&"jar":
			return Vector3(0.3, 0.3, 0.3)
		&"table":
			return Vector3(1.0, 0.8, 0.55)
	return Vector3(0.32, 0.27, 0.32)


# --- Kleine Items (ConsumableModel ruft das für die Grow-Arten) ----------------------------------

static func item(root: Node3D, kind: StringName, color: Color) -> void:
	match kind:
		&"soil":
			_mesh(root, _box(Vector3(0.16, 0.24, 0.07)), _mat(&"soil_bag", Color(0.1, 0.25, 0.12)), Vector3.ZERO)
			_mesh(root, _box(Vector3(0.161, 0.06, 0.071)), _mat(&"soil_band", color, false, false, 1.0), Vector3(0, 0.03, 0))
		&"seeds":
			_mesh(root, _box(Vector3(0.07, 0.1, 0.005)), _mat(&"seed_pack", Color(0.12, 0.12, 0.14)), Vector3.ZERO)
			_mesh(root, _box(Vector3(0.05, 0.05, 0.006)), _mat(&"seed_label", color, false, false, 1.2), Vector3(0, 0.01, 0))
		&"fertilizer":
			_mesh(root, _tube(0.03, 0.035, 0.13), _mat(&"fert_bottle", Color(0.9, 0.9, 0.92)), Vector3.ZERO)
			_mesh(root, _tube(0.015, 0.015, 0.02), _mat(&"fert_cap", color, false, false, 0.8), Vector3(0, 0.075, 0))
			_mesh(root, _tube(0.0305, 0.0355, 0.05), _mat(&"fert_label", color, false, false, 0.6), Vector3(0, -0.01, 0))
		&"buds":
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i in 9:
				_blob(st, Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.015, 0.02), rng.randf_range(-0.02, 0.02)),
					rng.randf_range(0.012, 0.02), color.lerp(Color(0.85, 0.9, 0.8), rng.randf() * 0.2))
			var mi := _instance(st, "Buds", _mat(&"plant_bud", Color.WHITE, true))
			root.add_child(mi)
		&"baggie", &"baggie_full":
			_mesh(root, _box(Vector3(0.06, 0.08, 0.004)), _glass(), Vector3.ZERO)
			_mesh(root, _box(Vector3(0.061, 0.006, 0.005)), _mat(&"zip", color, false, false, 1.2), Vector3(0, 0.035, 0))
			if kind == &"baggie_full":
				_mesh(root, _box(Vector3(0.045, 0.045, 0.012)), _mat(&"bag_content", Color(0.35, 0.42, 0.22)), Vector3(0, -0.012, 0))
		&"watering_can", &"watering_can_full":
			watering_can(root, kind == &"watering_can_full")
		&"jar", &"jar_full":
			_mesh(root, _tube(0.035, 0.035, 0.09), _glass(), Vector3.ZERO)
			_mesh(root, _tube(0.036, 0.036, 0.015), _mat(&"small_lid", color, false, false, 0.8, 0.7), Vector3(0, 0.052, 0))
			if kind == &"jar_full":
				_mesh(root, _tube(0.031, 0.031, 0.065), _mat(&"jar_content", Color(0.32, 0.38, 0.2)), Vector3(0, -0.01, 0))


## Gießkanne (5 l), etwa 24 cm hoch: Körper, Tülle mit Brause nach vorn (+X), Bügel oben.
static func watering_can(root: Node3D, full: bool) -> void:
	var body := _mat(&"can_body", Color(0.12, 0.45, 0.3), false, false, 0.0, 0.2)
	_mesh(root, _tube(0.085, 0.095, 0.2), body, Vector3(0, 0.1, 0))
	_mesh(root, _tube(0.06, 0.085, 0.03), body, Vector3(0, 0.215, 0))
	var spout := _mesh(root, _tube(0.012, 0.02, 0.24), body, Vector3(0.15, 0.13, 0))
	spout.rotation.z = -1.0
	var rose := _mesh(root, _tube(0.028, 0.014, 0.03), _mat(&"can_rose", Color(0.7, 0.72, 0.7), false, false, 0.0, 0.8),
		Vector3(0.255, 0.205, 0))
	rose.rotation.z = -1.0
	var handle := _mesh(root, _box(Vector3(0.17, 0.018, 0.02)), body, Vector3(-0.02, 0.27, 0))
	handle.rotation.z = 0.15
	_mesh(root, _box(Vector3(0.018, 0.08, 0.02)), body, Vector3(-0.1, 0.22, 0))
	if full:
		_mesh(root, _tube(0.058, 0.058, 0.004), _mat(&"can_water", Color(0.35, 0.65, 0.95), false, false, 0.6),
			Vector3(0, 0.226, 0))


## Wasserhahn an der Wand mit Becken (Front nach +Z), etwa 1 m hoch.
static func tap() -> Node3D:
	var root := Node3D.new()
	var steel := _mat(&"tap_steel", Color(0.75, 0.77, 0.8), false, false, 0.0, 0.85)
	_mesh(root, _box(Vector3(0.08, 1.1, 0.06)), _mat(&"tap_pipe", Color(0.3, 0.32, 0.34), false, false, 0.0, 0.5),
		Vector3(0, 0.55, -0.05))
	_mesh(root, _box(Vector3(0.4, 0.12, 0.3)), _mat(&"tap_basin", Color(0.82, 0.84, 0.86), false, false, 0.0, 0.3),
		Vector3(0, 0.6, 0.12))
	_mesh(root, _tube(0.015, 0.015, 0.16), steel, Vector3(0, 0.9, 0.05)).rotation.x = PI * 0.5
	_mesh(root, _tube(0.013, 0.013, 0.07), steel, Vector3(0, 0.865, 0.13))
	_mesh(root, _tube(0.03, 0.03, 0.03), _mat(&"tap_knob", Color(0.2, 0.45, 0.95), false, false, 0.3), Vector3(0, 0.96, 0.02))
	return root


# --- Bausteine ----------------------------------------------------------------------------------

static func _mesh(root: Node3D, mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	root.add_child(mi)
	return mi


static func _tube(top: float, bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 16
	m.rings = 1
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _glass() -> StandardMaterial3D:
	if not _mats.has(&"glass"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.95, 1.0, 0.25)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic_specular = 0.9
		_mats[&"glass"] = m
	return _mats[&"glass"]


## Material-Cache. vertex = Farbe aus den Ecken, two_sided für Blätter, glow > 0 leuchtet.
static func _mat(key: StringName, color: Color, vertex := false, two_sided := false, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = vertex
	# Eckpunkt-Farben sind wie alle Farben hier sRGB (sonst wirken Blätter und Blüten ausgeblichen).
	m.vertex_color_is_srgb = vertex
	m.roughness = 0.75
	m.metallic = metal
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m
