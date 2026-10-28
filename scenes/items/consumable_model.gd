class_name ConsumableModel
extends RefCounted
## 3D-Modelle, Griffe und Inventar-Icons der Verbrauchsitems (ConsumableData.model).
##
## Ein Modell, drei Stellen: Pickup in der Welt (ItemPickup, vergrößert), in der Hand
## (ItemUser, echte Größe) und als Icon im Slot (InventorySlot, Linienzeichnung im Neon-Stil).
## Alles wird aus Grundformen gebaut (wie Hände und Körper), es gibt keine Modelldateien.
##
## Ursprung = Mitte des Griffs, +Y = Längsachse des Items. Teile, die sich beim Benutzen bewegen,
## haben feste Namen (siehe build_*), ConsumableUse spricht sie über get_node an:
##   injector: Cap, Fluid, Plunger      can: Tab, Mouth      noodles: Lid, Noodles      bandage: Roll, Tail

const INJECTOR := &"injector"
const CAN := &"can"
const NOODLES := &"noodles"
const BANDAGE := &"bandage"

## Nadelspitze des Injektors im Raum des Modells (ohne Kappe).
const INJECTOR_TIP := Vector3(0.0, -0.074, 0.0)

## Vergrößerung als Pickup in der Welt, damit die echten Größen (12 cm Dose) lesbar bleiben.
const PICKUP_SCALE := {
	&"injector": 2.6,
	&"can": 2.0,
	&"noodles": 1.9,
	&"bandage": 2.4,
}

## Lage in der Hand, solange das Item nur gewählt ist (Raum des %ItemUser, Drehung in Grad).
const HOLD := {
	&"injector": [Vector3(-0.03, 0.05, -0.02), Vector3(-5.0, 15.0, 18.0)],
	&"can": [Vector3(-0.005, 0.0, 0.0), Vector3(0.0, -25.0, 0.0)],
	&"noodles": [Vector3(-0.02, -0.005, 0.0), Vector3(12.0, -10.0, 0.0)],
	&"bandage": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, -20.0, 8.0)],
}

## Griff der rechten Hand im Raum des Modells (Format wie PlayerHands.POSE_*).
## Die Hand liegt rechts am Item, Handrücken nach außen, Finger umschließen die Längsachse;
## Zeigefinger und Daumen oben.
const GRIPS := {
	# Faust um den Griff, Daumen oben am Kopf (drückt den Kolben).
	&"injector": {
		"pos": Vector3(0.036, -0.005, 0.068),
		"rot": Vector3(8.0, 10.0, -90.0),
		"curl": [[66.0, 76.0, 36.0], [72.0, 80.0, 38.0], [76.0, 82.0, 40.0], [78.0, 82.0, 40.0]],
		"spread": 1.0,
		"thumb": Vector3(-42.0, 12.0, 55.0),
		"thumb_curl": [24.0, 18.0],
	},
	&"can": {
		"pos": Vector3(0.058, -0.004, 0.066),
		"rot": Vector3(6.0, 12.0, -86.0),
		"curl": [[48.0, 46.0, 24.0], [52.0, 48.0, 26.0], [56.0, 50.0, 26.0], [58.0, 50.0, 26.0]],
		"spread": 3.0,
		"thumb": Vector3(-30.0, 22.0, 55.0),
		"thumb_curl": [18.0, 14.0],
	},
	&"noodles": {
		"pos": Vector3(0.066, -0.012, 0.07),
		"rot": Vector3(6.0, 12.0, -84.0),
		"curl": [[40.0, 40.0, 22.0], [44.0, 42.0, 24.0], [48.0, 44.0, 24.0], [50.0, 44.0, 24.0]],
		"spread": 4.0,
		"thumb": Vector3(-26.0, 26.0, 55.0),
		"thumb_curl": [16.0, 12.0],
	},
	&"bandage": {
		"pos": Vector3(0.044, -0.002, 0.066),
		"rot": Vector3(6.0, 10.0, -88.0),
		"curl": [[56.0, 62.0, 30.0], [60.0, 64.0, 32.0], [64.0, 66.0, 32.0], [66.0, 66.0, 32.0]],
		"spread": 2.0,
		"thumb": Vector3(-34.0, 18.0, 55.0),
		"thumb_curl": [20.0, 16.0],
	},
}

static var _materials := {}


## Baut das Modell zu `kind`. Unbekannt = leuchtender Würfel. `viewmodel` legt alles zusätzlich auf
## die Render-Ebene der Hände (Fülllicht in der Ego-Sicht), Schatten sind dann aus.
static func build(kind: StringName, color: Color, viewmodel := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Consumable_%s" % kind
	match kind:
		INJECTOR:
			_build_injector(root, color)
		CAN:
			_build_can(root, color)
		NOODLES:
			_build_noodles(root, color)
		BANDAGE:
			_build_bandage(root, color)
		_:
			_part(root, ProcMesh.rounded_box(Vector3(0.06, 0.06, 0.06), 0.3), _neon(color), Vector3.ZERO)
	if viewmodel:
		_set_layers(root)
	return root


static func has_model(kind: StringName) -> bool:
	return GRIPS.has(kind)


static func grip_pose(kind: StringName) -> Dictionary:
	return GRIPS.get(kind, GRIPS[CAN])


## Lage in der Hand (Raum des %ItemUser).
static func hold_transform(kind: StringName) -> Transform3D:
	var hold: Array = HOLD.get(kind, HOLD[CAN])
	return Transform3D(euler_basis(hold[1]), hold[0])


static func pickup_scale(kind: StringName) -> float:
	return PICKUP_SCALE.get(kind, 1.0)


static func euler_basis(degrees: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)))


# --- Modelle -------------------------------------------------------------------

## Auto-Injektor (Stim): Griff mit Rillen, Sichtfenster mit leuchtender Flüssigkeit, Kolben oben,
## Nadel unten unter einer Schutzkappe.
static func _build_injector(root: Node3D, color: Color) -> void:
	var shell := _mat(&"shell", Color(0.08, 0.085, 0.1), 0.35, 0.45)
	var metal := _mat(&"metal", Color(0.62, 0.64, 0.68), 0.9, 0.25)
	var rubber := _mat(&"rubber", Color(0.03, 0.03, 0.035), 0.0, 0.9)
	# Nase und Nadel.
	_part(root, ProcMesh.tube(0.0135, 0.0075, 0.022), metal, Vector3(0.0, -0.046, 0.0))
	_part(root, ProcMesh.tube(0.0011, 0.0006, 0.017), _mat(&"needle", Color(0.9, 0.92, 0.95), 1.0, 0.1),
		Vector3(0.0, -0.0655, 0.0))
	# Griff mit Gummirillen.
	_part(root, ProcMesh.tube(0.0135, 0.0135, 0.036), shell, Vector3(0.0, -0.017, 0.0))
	for i in 3:
		_part(root, ProcMesh.tube(0.0145, 0.0145, 0.004), rubber, Vector3(0.0, -0.029 + i * 0.01, 0.0))
	# Sichtfenster: Glas außen, leuchtende Flüssigkeit innen (Fluid schrumpft beim Injizieren).
	var fluid := Node3D.new()
	fluid.name = "Fluid"
	fluid.position = Vector3(0.0, 0.002, 0.0)
	root.add_child(fluid)
	_part(fluid, ProcMesh.tube(0.0108, 0.0108, 0.03), _neon(color, 2.2), Vector3(0.0, 0.015, 0.0))
	_part(root, ProcMesh.tube(0.0139, 0.0139, 0.034), _glass(), Vector3(0.0, 0.018, 0.0))
	# Skala am Fenster.
	for i in 4:
		_part(root, ProcMesh.rounded_box(Vector3(0.004, 0.0012, 0.0012), 0.2), metal,
			Vector3(0.0, 0.007 + i * 0.007, 0.0142))
	# Kragen und Kolben.
	_part(root, ProcMesh.tube(0.0146, 0.0146, 0.008), metal, Vector3(0.0, 0.039, 0.0))
	var plunger := Node3D.new()
	plunger.name = "Plunger"
	root.add_child(plunger)
	_part(plunger, ProcMesh.tube(0.0055, 0.0055, 0.012), metal, Vector3(0.0, 0.047, 0.0))
	_part(plunger, ProcMesh.tube(0.0095, 0.0095, 0.006), _neon(color, 1.6), Vector3(0.0, 0.055, 0.0))
	# Schutzkappe über der Nadel, in Itemfarbe.
	var cap := Node3D.new()
	cap.name = "Cap"
	root.add_child(cap)
	_part(cap, ProcMesh.tube(0.0098, 0.0118, 0.032), _neon(color, 0.9), Vector3(0.0, -0.063, 0.0))
	_part(cap, ProcMesh.tube(0.0122, 0.0122, 0.004), rubber, Vector3(0.0, -0.049, 0.0))
	# Warnstreifen am Griff.
	_part(root, ProcMesh.rounded_box(Vector3(0.003, 0.03, 0.002), 0.3), _neon(color, 1.4),
		Vector3(0.0, -0.017, 0.0138))


## Getränkedose (NeoCola): dunkle Dose mit Neonringen und Schriftzug, Lasche oben.
static func _build_can(root: Node3D, color: Color) -> void:
	var paint := _mat(&"can_paint", Color(0.07, 0.03, 0.1), 0.65, 0.35)
	var alu := _mat(&"alu", Color(0.78, 0.8, 0.84), 0.95, 0.22)
	_part(root, ProcMesh.tube(0.033, 0.033, 0.1), paint, Vector3(0.0, -0.005, 0.0))
	_part(root, ProcMesh.tube(0.033, 0.027, 0.008), alu, Vector3(0.0, -0.059, 0.0))
	_part(root, ProcMesh.tube(0.0275, 0.033, 0.012), alu, Vector3(0.0, 0.051, 0.0))
	_part(root, ProcMesh.tube(0.0275, 0.0275, 0.002), alu, Vector3(0.0, 0.057, 0.0))
	_part(root, ProcMesh.tube(0.0285, 0.0285, 0.003), alu, Vector3(0.0, 0.0585, 0.0))
	for y: float in [0.03, -0.04]:
		_part(root, ProcMesh.tube(0.0334, 0.0334, 0.005), _neon(color, 2.0), Vector3(0.0, y, 0.0))
	# Schräger Blitz als Logo vorn und hinten.
	for side: float in [1.0, -1.0]:
		var bolt := _part(root, ProcMesh.rounded_box(Vector3(0.008, 0.05, 0.002), 0.3), _neon(color, 1.6),
			Vector3(0.0, -0.005, 0.0332 * side))
		bolt.rotation = Vector3(0.0, 0.0, 0.45)
		var label := Label3D.new()
		label.text = "NEO"
		label.font_size = 48
		label.outline_size = 8
		label.pixel_size = 0.00045
		label.modulate = Color(1.0, 0.95, 0.9)
		label.outline_modulate = Color(color, 1.0)
		label.position = Vector3(0.0, 0.012, 0.0338 * side)
		label.rotation = Vector3(0.0, 0.0 if side > 0.0 else PI, PI * 0.5)
		label.double_sided = false
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(label)
	# Trinköffnung (anfangs versteckt) und Lasche mit Drehpunkt an der Niete.
	var mouth := _part(root, ProcMesh.rounded_box(Vector3(0.011, 0.0012, 0.014), 0.5),
		_mat(&"dark", Color(0.01, 0.01, 0.012), 0.0, 0.9), Vector3(0.0, 0.0587, -0.012))
	mouth.name = "Mouth"
	mouth.visible = false
	var tab := Node3D.new()
	tab.name = "Tab"
	tab.position = Vector3(0.0, 0.0592, 0.002)
	root.add_child(tab)
	_part(tab, ProcMesh.rounded_box(Vector3(0.011, 0.0015, 0.022), 0.4), alu, Vector3(0.0, 0.0, 0.004))
	_part(tab, ProcMesh.tube(0.002, 0.002, 0.002), alu, Vector3.ZERO)


## Instant-Nudelbecher: Pappbecher mit Neonbanderole, Folien-Deckel (Lid) mit Lasche, Nudeln darunter.
static func _build_noodles(root: Node3D, color: Color) -> void:
	var paper := _mat(&"paper", Color(0.86, 0.85, 0.9), 0.0, 0.8)
	_part(root, ProcMesh.tube(0.046, 0.034, 0.09), paper, Vector3.ZERO)
	_part(root, ProcMesh.tube(0.0425, 0.0385, 0.032), _neon(color, 1.3), Vector3(0.0, 0.002, 0.0))
	_part(root, ProcMesh.tube(0.0475, 0.0475, 0.005), paper, Vector3(0.0, 0.0445, 0.0))
	# Schriftzeichen auf der Banderole.
	var label := Label3D.new()
	label.text = "麺 NOODL"
	label.font_size = 40
	label.outline_size = 6
	label.pixel_size = 0.0005
	label.modulate = Color(1.0, 1.0, 1.0)
	label.outline_modulate = Color(0.1, 0.0, 0.15)
	label.position = Vector3(0.0, 0.002, 0.0418)
	label.rotation = Vector3(-0.13, 0.0, 0.0)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(label)
	var noodles := _part(root, ProcMesh.tube(0.043, 0.043, 0.004), _mat(&"noodle", Color(0.96, 0.78, 0.38), 0.0, 0.55),
		Vector3(0.0, 0.037, 0.0))
	noodles.name = "Noodles"
	for i in 5:
		var a := i * 1.3
		_part(noodles, ProcMesh.rounded_box(Vector3(0.012, 0.004, 0.006), 0.6),
			_mat(&"veggie", Color(0.3, 0.75, 0.25), 0.0, 0.6), Vector3(cos(a) * 0.022, 0.003, sin(a) * 0.022))
	# Deckel klappt an der vorderen Kante (+Z, zum Spieler) auf, die Lasche sitzt hinten.
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0.0, 0.0475, 0.046)
	root.add_child(lid)
	_part(lid, ProcMesh.tube(0.0478, 0.0478, 0.002), _mat(&"foil", Color(0.75, 0.72, 0.8), 0.9, 0.3), Vector3(0.0, 0.0, -0.046))
	_part(lid, ProcMesh.tube(0.03, 0.03, 0.0005), _neon(color, 1.0), Vector3(0.0, 0.0012, -0.046))
	_part(lid, ProcMesh.rounded_box(Vector3(0.016, 0.002, 0.014), 0.4), _mat(&"foil", Color(0.75, 0.72, 0.8), 0.9, 0.3),
		Vector3(0.0, 0.0, -0.096))


## Nano-Verband: weiße Rolle mit leuchtender Achse und Siegelband, loses Ende (Tail) zum Abziehen.
static func _build_bandage(root: Node3D, color: Color) -> void:
	var cloth := _mat(&"cloth", Color(0.9, 0.9, 0.93), 0.0, 0.95)
	var roll := Node3D.new()
	roll.name = "Roll"
	root.add_child(roll)
	_part(roll, ProcMesh.tube(0.022, 0.022, 0.05), cloth, Vector3.ZERO)
	_part(roll, ProcMesh.tube(0.009, 0.009, 0.0525), _mat(&"shell", Color(0.08, 0.085, 0.1), 0.35, 0.45), Vector3.ZERO)
	_part(roll, ProcMesh.tube(0.0065, 0.0065, 0.054), _neon(Color(0.2, 1.0, 0.95), 2.0), Vector3.ZERO)
	# Siegelband in Itemfarbe mit Kreuz.
	_part(roll, ProcMesh.tube(0.0225, 0.0225, 0.012), _neon(color, 1.2), Vector3.ZERO)
	_part(roll, ProcMesh.rounded_box(Vector3(0.012, 0.004, 0.002), 0.2), cloth, Vector3(0.0, 0.0, 0.0228))
	_part(roll, ProcMesh.rounded_box(Vector3(0.004, 0.012, 0.002), 0.2), cloth, Vector3(0.0, 0.0, 0.0228))
	var tail := _part(roll, ProcMesh.rounded_box(Vector3(0.0015, 0.046, 0.03), 0.2), cloth, Vector3(0.022, 0.0, -0.012))
	tail.name = "Tail"
	tail.rotation = Vector3(0.0, -0.3, 0.0)


# --- Icons ---------------------------------------------------------------------

## Zeichnet das Icon zu `kind` in den Slot (Linien im Neon-Stil). `s` = Kantenlänge des Icons.
static func draw_icon(canvas: CanvasItem, kind: StringName, center: Vector2, s: float, color: Color) -> void:
	var fill := Color(color, 0.22)
	var line := 2.0
	match kind:
		INJECTOR:
			# Schräger Injektor: Körper, Fenster mit Flüssigkeit, Kolben, Nadel.
			var dir := Vector2(1.0, -1.0).normalized()
			var nrm := Vector2(dir.y, -dir.x)
			var w := s * 0.11
			var a := center - dir * s * 0.28
			var b := center + dir * s * 0.24
			var body := PackedVector2Array([a + nrm * w, b + nrm * w, b - nrm * w, a - nrm * w, a + nrm * w])
			canvas.draw_colored_polygon(body.slice(0, 4), fill)
			canvas.draw_polyline(body, color, line, true)
			var f0 := center + dir * s * 0.02
			var f1 := center + dir * s * 0.2
			canvas.draw_colored_polygon(PackedVector2Array([f0 + nrm * w * 0.6, f1 + nrm * w * 0.6,
				f1 - nrm * w * 0.6, f0 - nrm * w * 0.6]), Color(color, 0.85))
			canvas.draw_line(b, b + dir * s * 0.1, color, line * 1.5)
			canvas.draw_line(b + dir * s * 0.1 + nrm * w * 0.8, b + dir * s * 0.1 - nrm * w * 0.8, color, line)
			canvas.draw_line(a, a - dir * s * 0.1, color, line * 0.75)
			canvas.draw_line(a - dir * s * 0.1, a - dir * s * 0.14, Color.WHITE, 1.0)
		CAN:
			var r := s * 0.2
			var h := s * 0.32
			var rect := Rect2(center - Vector2(r, h), Vector2(r * 2.0, h * 2.0))
			canvas.draw_rect(rect, fill)
			canvas.draw_rect(rect, color, false, line)
			canvas.draw_line(Vector2(rect.position.x, center.y - h * 0.45), Vector2(rect.end.x, center.y - h * 0.45), color, line)
			canvas.draw_line(Vector2(rect.position.x, center.y + h * 0.55), Vector2(rect.end.x, center.y + h * 0.55), color, line)
			# Blitz.
			canvas.draw_polyline(PackedVector2Array([center + Vector2(r * 0.3, -h * 0.3), center + Vector2(-r * 0.25, h * 0.08),
				center + Vector2(r * 0.2, h * 0.02), center + Vector2(-r * 0.3, h * 0.4)]), Color.WHITE, 1.5, true)
			canvas.draw_line(center + Vector2(-r * 0.2, -h - 2.0), center + Vector2(r * 0.4, -h - 2.0), color, line)
		NOODLES:
			var top := s * 0.27
			var bottom := s * 0.19
			var h := s * 0.24
			var cup := PackedVector2Array([center + Vector2(-top, -h * 0.6), center + Vector2(top, -h * 0.6),
				center + Vector2(bottom, h), center + Vector2(-bottom, h)])
			canvas.draw_colored_polygon(cup, fill)
			cup.append(cup[0])
			canvas.draw_polyline(cup, color, line, true)
			canvas.draw_line(center + Vector2(-top * 0.92, 0.0), center + Vector2(top * 0.92, 0.0), color, line)
			# Dampf.
			for i in 3:
				var x := (i - 1) * s * 0.12
				var pts := PackedVector2Array()
				for j in 6:
					pts.append(center + Vector2(x + sin(j * 1.3 + i) * s * 0.03, -h * 0.75 - j * s * 0.035))
				canvas.draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.75), 1.5, true)
		BANDAGE:
			var r := s * 0.22
			canvas.draw_circle(center + Vector2(-s * 0.06, 0.0), r, fill)
			canvas.draw_arc(center + Vector2(-s * 0.06, 0.0), r, 0.0, TAU, 28, color, line, true)
			canvas.draw_arc(center + Vector2(-s * 0.06, 0.0), r * 0.42, 0.0, TAU, 20, color, line, true)
			# Loses Ende und Kreuz.
			var tail := PackedVector2Array([center + Vector2(-s * 0.06, r), center + Vector2(s * 0.3, r),
				center + Vector2(s * 0.3, r - s * 0.12), center + Vector2(s * 0.08, r - s * 0.12)])
			canvas.draw_polyline(tail, color, line, true)
			var c := center + Vector2(-s * 0.06, 0.0)
			canvas.draw_line(c + Vector2(-r * 0.25, 0.0), c + Vector2(r * 0.25, 0.0), Color.WHITE, 2.0)
			canvas.draw_line(c + Vector2(0.0, -r * 0.25), c + Vector2(0.0, r * 0.25), Color.WHITE, 2.0)


# --- Hilfen --------------------------------------------------------------------

static func _part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance


static func _set_layers(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.layers |= PlayerHands.VIEWMODEL_LAYER
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_layers(child)


static func _mat(key: StringName, color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var cache_key := "%s_%s" % [key, color.to_html()]
	if not _materials.has(cache_key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = metallic
		material.roughness = roughness
		_materials[cache_key] = material
	return _materials[cache_key]


static func _neon(color: Color, energy := 1.5) -> StandardMaterial3D:
	var cache_key := "neon_%s_%.2f" % [color.to_html(), energy]
	if not _materials.has(cache_key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color.darkened(0.3)
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
		material.roughness = 0.4
		_materials[cache_key] = material
	return _materials[cache_key]


static func _glass() -> StandardMaterial3D:
	if not _materials.has("glass"):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.7, 0.9, 1.0, 0.28)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.metallic = 0.2
		material.roughness = 0.05
		material.cull_mode = BaseMaterial3D.CULL_BACK
		_materials["glass"] = material
	return _materials["glass"]
