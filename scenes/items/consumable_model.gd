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
const BOTTLE := &"bottle"
const CUP := &"cup"
const BAR := &"bar"
const ONIGIRI := &"onigiri"
const PILLS := &"pills"
const MEDKIT := &"medkit"
const PHONE := &"phone"
const CHIP := &"chip"
const WATCH := &"watch"
const CIGARETTES := &"cigarettes"
const SHARD := &"shard"
const CROWBAR := &"crowbar"
const JEWELRY := &"jewelry"
const JEWELS := &"jewels"
const CASH := &"cash"
const TV := &"tv"
const PAINTING := &"painting"
const COMPUTER := &"computer"
const CUFFS := &"cuffs"
const TIES := &"ties"
const KEYCARD := &"keycard"

## Nadelspitze des Injektors im Raum des Modells (ohne Kappe).
const INJECTOR_TIP := Vector3(0.0, -0.074, 0.0)

## Vergrößerung als Pickup in der Welt, damit die echten Größen (12 cm Dose) lesbar bleiben.
const PICKUP_SCALE := {
	&"injector": 2.6,
	&"can": 2.0,
	&"noodles": 1.9,
	&"bandage": 2.4,
	&"bottle": 1.6,
	&"cup": 1.9,
	&"bar": 2.4,
	&"onigiri": 2.2,
	&"pills": 2.4,
	&"medkit": 1.5,
	&"phone": 2.0,
	&"chip": 2.8,
	&"watch": 2.8,
	&"cigarettes": 2.2,
	&"shard": 2.8,
	&"crowbar": 1.6,
	&"jewelry": 1.8,
	&"jewels": 2.4,
	&"cash": 1.8,
	&"tv": 1.3,
	&"painting": 1.4,
	&"computer": 1.5,
	&"cuffs": 2.2,
	&"ties": 2.4,
	&"keycard": 2.6,
}

## Lage in der Hand, solange das Item nur gewählt ist (Raum des %ItemUser, Drehung in Grad).
const HOLD := {
	&"injector": [Vector3(-0.03, 0.05, -0.02), Vector3(-5.0, 15.0, 18.0)],
	&"can": [Vector3(-0.005, 0.0, 0.0), Vector3(0.0, -25.0, 0.0)],
	&"noodles": [Vector3(-0.02, -0.005, 0.0), Vector3(12.0, -10.0, 0.0)],
	&"bandage": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, -20.0, 8.0)],
	&"bottle": [Vector3(-0.005, 0.01, 0.0), Vector3(0.0, -25.0, 0.0)],
	&"cup": [Vector3(-0.01, 0.0, 0.0), Vector3(0.0, -20.0, 0.0)],
	&"bar": [Vector3(0.0, 0.0, 0.0), Vector3(10.0, -20.0, 0.0)],
	&"onigiri": [Vector3(-0.01, 0.0, 0.0), Vector3(10.0, -15.0, 0.0)],
	&"pills": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, -25.0, 0.0)],
	&"medkit": [Vector3(-0.03, 0.0, 0.0), Vector3(0.0, -20.0, 0.0)],
	&"phone": [Vector3(-0.01, 0.01, 0.0), Vector3(15.0, -30.0, 0.0)],
	&"chip": [Vector3(0.0, 0.0, 0.0), Vector3(20.0, -20.0, 0.0)],
	&"watch": [Vector3(0.0, 0.0, 0.0), Vector3(20.0, -20.0, 0.0)],
	&"cigarettes": [Vector3(0.0, 0.0, 0.0), Vector3(10.0, -25.0, 0.0)],
	&"shard": [Vector3(0.0, 0.0, 0.0), Vector3(10.0, -20.0, 0.0)],
	&"crowbar": [Vector3(0.02, -0.02, -0.05), Vector3(70.0, 10.0, 0.0)],
	&"jewelry": [Vector3(0.0, 0.0, 0.0), Vector3(10.0, -20.0, 0.0)],
	&"jewels": [Vector3(0.0, 0.0, 0.0), Vector3(10.0, -20.0, 0.0)],
	&"cash": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, -20.0, 0.0)],
	&"tv": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, -15.0, 0.0)],
	&"painting": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, -15.0, 0.0)],
	&"computer": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, -15.0, 0.0)],
	&"cuffs": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, -20.0, 0.0)],
	&"ties": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, -20.0, 0.0)],
	&"keycard": [Vector3(0.0, 0.0, 0.0), Vector3(10.0, -25.0, 0.0)],
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
	# Neue Items: Griffe abgeleitet von Dose (rund, Finger umschließen) und Verband (klein, Faust).
	&"bottle": {
		"pos": Vector3(0.056, -0.01, 0.064),
		"rot": Vector3(6.0, 12.0, -86.0),
		"curl": [[50.0, 48.0, 24.0], [54.0, 50.0, 26.0], [58.0, 52.0, 26.0], [60.0, 52.0, 26.0]],
		"spread": 3.0,
		"thumb": Vector3(-30.0, 22.0, 55.0),
		"thumb_curl": [18.0, 14.0],
	},
	&"cup": {
		"pos": Vector3(0.064, -0.01, 0.068),
		"rot": Vector3(6.0, 12.0, -84.0),
		"curl": [[44.0, 42.0, 22.0], [48.0, 44.0, 24.0], [52.0, 46.0, 24.0], [54.0, 46.0, 24.0]],
		"spread": 4.0,
		"thumb": Vector3(-28.0, 24.0, 55.0),
		"thumb_curl": [16.0, 12.0],
	},
	&"pills": {
		"pos": Vector3(0.044, -0.004, 0.066),
		"rot": Vector3(6.0, 10.0, -88.0),
		"curl": [[58.0, 60.0, 30.0], [62.0, 62.0, 32.0], [66.0, 64.0, 32.0], [68.0, 64.0, 32.0]],
		"spread": 2.0,
		"thumb": Vector3(-34.0, 18.0, 55.0),
		"thumb_curl": [20.0, 16.0],
	},
	&"medkit": {
		"pos": Vector3(0.09, -0.01, 0.07),
		"rot": Vector3(6.0, 12.0, -84.0),
		"curl": [[30.0, 30.0, 16.0], [34.0, 32.0, 18.0], [36.0, 34.0, 18.0], [38.0, 34.0, 18.0]],
		"spread": 3.0,
		"thumb": Vector3(-20.0, 30.0, 55.0),
		"thumb_curl": [10.0, 8.0],
	},
	&"crowbar": {
		"pos": Vector3(0.04, -0.02, 0.08),
		"rot": Vector3(8.0, 12.0, -80.0),
		"curl": [[62.0, 70.0, 34.0], [68.0, 74.0, 36.0], [72.0, 76.0, 36.0], [74.0, 76.0, 36.0]],
		"spread": 2.0,
		"thumb": Vector3(-36.0, 14.0, 50.0),
		"thumb_curl": [22.0, 16.0],
	},
}

## Kleine Dinge (Riegel, Handy, Chip, Uhr …) greift die Hand wie den Verband.
const SMALL_GRIP_KINDS := [&"bar", &"onigiri", &"phone", &"chip", &"watch", &"cigarettes", &"shard",
	&"jewelry", &"jewels", &"cash", &"cuffs", &"ties", &"keycard", &"tv", &"painting", &"computer"]


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
		BOTTLE:
			_build_bottle(root, color)
		CUP:
			_build_cup(root, color)
		BAR:
			_build_bar(root, color)
		ONIGIRI:
			_build_onigiri(root, color)
		PILLS:
			_build_pills(root, color)
		MEDKIT:
			_build_medkit(root, color)
		PHONE:
			_build_phone(root, color)
		CHIP:
			_build_chip(root, color)
		WATCH:
			_build_watch(root, color)
		CIGARETTES:
			_build_cigarettes(root, color)
		SHARD:
			_build_shard(root, color)
		CROWBAR:
			_build_crowbar(root, color)
		JEWELRY, JEWELS, CASH, CUFFS, TIES, KEYCARD, TV, PAINTING, COMPUTER:
			_build_prop(root, kind, color)
		_:
			_part(root, ProcMesh.rounded_box(Vector3(0.06, 0.06, 0.06), 0.3), _neon(color), Vector3.ZERO)
	if viewmodel:
		_set_layers(root)
	return root


static func has_model(kind: StringName) -> bool:
	return GRIPS.has(kind) or kind in SMALL_GRIP_KINDS


static func grip_pose(kind: StringName) -> Dictionary:
	if kind in SMALL_GRIP_KINDS:
		return GRIPS[BANDAGE]
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
		_:
			_draw_icon_extra(canvas, kind, center, s, color, fill, line)


# --- Modelle für Läden und Beute (alle in echter Größe, +Y = Längsachse) ---------------------

## Wasserflasche: durchsichtiger Körper mit Wasser, Etikett, Schraubdeckel (Tab, dreht beim Trinken).
static func _build_bottle(root: Node3D, color: Color) -> void:
	_part(root, ProcMesh.tube(0.031, 0.031, 0.16), _glass(), Vector3(0.0, -0.01, 0.0))
	_part(root, ProcMesh.tube(0.028, 0.028, 0.12), _mat(&"water", Color(0.55, 0.85, 1.0), 0.0, 0.1), Vector3(0.0, -0.03, 0.0))
	_part(root, ProcMesh.tube(0.0318, 0.0318, 0.05), _neon(color, 1.2), Vector3(0.0, -0.01, 0.0))
	_part(root, ProcMesh.tube(0.012, 0.031, 0.03), _glass(), Vector3(0.0, 0.085, 0.0))
	var label := _label3d("AQUA", color, 0.0004)
	label.position = Vector3(0.0, -0.008, 0.033)
	root.add_child(label)
	var cap := Node3D.new()
	cap.name = "Tab"
	cap.position = Vector3(0.0, 0.106, 0.0)
	root.add_child(cap)
	_part(cap, ProcMesh.tube(0.0125, 0.0125, 0.014), _neon(color, 0.8), Vector3.ZERO)
	var mouth := _part(root, ProcMesh.tube(0.009, 0.009, 0.001), _mat(&"dark", Color(0.01, 0.01, 0.012), 0.0, 0.9), Vector3(0.0, 0.1, 0.0))
	mouth.name = "Mouth"
	mouth.visible = false


## Kaffeebecher: Pappbecher mit Banderole, Deckel und Trinklasche (Tab).
static func _build_cup(root: Node3D, color: Color) -> void:
	var paper := _mat(&"paper", Color(0.86, 0.85, 0.9), 0.0, 0.8)
	var lid_mat := _mat(&"lid_black", Color(0.06, 0.06, 0.07), 0.0, 0.5)
	_part(root, ProcMesh.tube(0.042, 0.032, 0.12), paper, Vector3.ZERO)
	_part(root, ProcMesh.tube(0.04, 0.036, 0.045), _mat(&"sleeve", Color(0.35, 0.22, 0.12), 0.0, 0.9), Vector3(0.0, -0.005, 0.0))
	_part(root, ProcMesh.tube(0.0405, 0.0405, 0.006), _neon(color, 1.4), Vector3(0.0, 0.012, 0.0))
	_part(root, ProcMesh.tube(0.04, 0.044, 0.012), lid_mat, Vector3(0.0, 0.066, 0.0))
	var tab := Node3D.new()
	tab.name = "Tab"
	tab.position = Vector3(0.0, 0.073, 0.02)
	root.add_child(tab)
	_part(tab, ProcMesh.rounded_box(Vector3(0.014, 0.002, 0.01), 0.4), lid_mat, Vector3.ZERO)
	var mouth := _part(root, ProcMesh.rounded_box(Vector3(0.01, 0.001, 0.006), 0.5), _mat(&"coffee", Color(0.2, 0.1, 0.05), 0.0, 0.3), Vector3(0.0, 0.073, 0.02))
	mouth.name = "Mouth"
	mouth.visible = false


## Soja-Riegel: Folienverpackung, aufgerissenes Ende (Lid), Riegel darin (Noodles = wird gegessen).
static func _build_bar(root: Node3D, color: Color) -> void:
	var wrapper := _mat(&"wrapper", Color(0.12, 0.1, 0.14), 0.7, 0.35)
	_part(root, ProcMesh.rounded_box(Vector3(0.038, 0.11, 0.016), 0.35), wrapper, Vector3(0.0, -0.01, 0.0))
	_part(root, ProcMesh.rounded_box(Vector3(0.039, 0.03, 0.0165), 0.3), _neon(color, 1.5), Vector3(0.0, -0.02, 0.0))
	var label := _label3d("SOJA+", Color.WHITE, 0.0003)
	label.position = Vector3(0.0, 0.015, 0.0085)
	label.rotation = Vector3(0.0, 0.0, PI * 0.5)
	root.add_child(label)
	var bar := _part(root, ProcMesh.rounded_box(Vector3(0.032, 0.03, 0.012), 0.4), _mat(&"bar", Color(0.6, 0.42, 0.22), 0.0, 0.8), Vector3(0.0, 0.058, 0.0))
	bar.name = "Noodles"
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0.0, 0.045, 0.0)
	root.add_child(lid)
	_part(lid, ProcMesh.rounded_box(Vector3(0.036, 0.012, 0.004), 0.3), wrapper, Vector3(0.0, 0.004, 0.009))


## Onigiri: Reisdreieck mit Nori-Streifen (Lid = Folienlasche, Noodles = Spitze, die gegessen wird).
static func _build_onigiri(root: Node3D, color: Color) -> void:
	var rice := _mat(&"rice", Color(0.96, 0.95, 0.92), 0.0, 0.9)
	var tri := CylinderMesh.new()
	tri.top_radius = 0.048
	tri.bottom_radius = 0.048
	tri.height = 0.032
	tri.radial_segments = 3
	tri.rings = 1
	var body := _part(root, tri, rice, Vector3.ZERO)
	body.rotation = Vector3(PI * 0.5, 0.0, PI * 0.5)
	_part(root, ProcMesh.rounded_box(Vector3(0.05, 0.035, 0.034), 0.2), _mat(&"nori", Color(0.05, 0.12, 0.07), 0.0, 0.7), Vector3(0.0, -0.022, 0.0))
	_part(root, ProcMesh.rounded_box(Vector3(0.012, 0.09, 0.0345), 0.2), _neon(color, 0.9), Vector3(0.0, -0.005, 0.0))
	var tip := _part(root, ProcMesh.rounded_box(Vector3(0.03, 0.02, 0.03), 0.6), rice, Vector3(0.0, 0.03, 0.0))
	tip.name = "Noodles"
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0.0, 0.04, 0.0)
	root.add_child(lid)
	_part(lid, ProcMesh.rounded_box(Vector3(0.012, 0.016, 0.003), 0.3), _neon(color, 1.2), Vector3(0.0, 0.006, 0.017))


## Pillendose: orange durchscheinend, weiße Kappe (Tab), Pillen innen.
static func _build_pills(root: Node3D, color: Color) -> void:
	if not _materials.has("amber"):
		var amber := StandardMaterial3D.new()
		amber.albedo_color = Color(1.0, 0.55, 0.1, 0.6)
		amber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		amber.roughness = 0.2
		_materials["amber"] = amber
	_part(root, ProcMesh.tube(0.02, 0.02, 0.075), _materials["amber"], Vector3(0.0, -0.005, 0.0))
	for i in 6:
		_part(root, ProcMesh.capsule(0.005, 0.016), _mat(&"pill", Color(0.95, 0.95, 0.9), 0.0, 0.5),
			Vector3(sin(i * 2.1) * 0.009, -0.03 + i * 0.008, cos(i * 2.1) * 0.009))
	_part(root, ProcMesh.tube(0.0205, 0.0205, 0.03), _mat(&"label_white", Color(0.92, 0.92, 0.95), 0.0, 0.7), Vector3(0.0, -0.01, 0.0))
	_part(root, ProcMesh.rounded_box(Vector3(0.006, 0.016, 0.003), 0.3), _neon(color, 1.4), Vector3(0.0, -0.01, 0.0205))
	var cap := Node3D.new()
	cap.name = "Tab"
	cap.position = Vector3(0.0, 0.041, 0.0)
	root.add_child(cap)
	_part(cap, ProcMesh.tube(0.022, 0.022, 0.014), _mat(&"cap_white", Color(0.97, 0.97, 0.97), 0.0, 0.4), Vector3.ZERO)


## Medkit: Kunststoffkoffer mit Kreuz auf beiden Seiten, Griff oben.
static func _build_medkit(root: Node3D, color: Color) -> void:
	_part(root, ProcMesh.rounded_box(Vector3(0.16, 0.12, 0.06), 0.25), _mat(&"medkit", Color(0.9, 0.9, 0.92), 0.0, 0.5), Vector3.ZERO)
	_part(root, ProcMesh.rounded_box(Vector3(0.162, 0.012, 0.062), 0.2), _neon(color, 1.2), Vector3.ZERO)
	for side: float in [1.0, -1.0]:
		_part(root, ProcMesh.rounded_box(Vector3(0.05, 0.014, 0.002), 0.2), _neon(color, 1.8), Vector3(0.0, 0.025, 0.031 * side))
		_part(root, ProcMesh.rounded_box(Vector3(0.014, 0.05, 0.002), 0.2), _neon(color, 1.8), Vector3(0.0, 0.025, 0.031 * side))
	_part(root, ProcMesh.rounded_box(Vector3(0.07, 0.018, 0.018), 0.5), _mat(&"rubber", Color(0.03, 0.03, 0.035), 0.0, 0.9), Vector3(0.0, 0.072, 0.0))


## Handy: flaches Gerät mit leuchtendem Display und Kamera hinten.
static func _build_phone(root: Node3D, color: Color) -> void:
	_part(root, ProcMesh.rounded_box(Vector3(0.07, 0.145, 0.008), 0.2), _mat(&"phone", Color(0.05, 0.05, 0.06), 0.8, 0.25), Vector3.ZERO)
	_part(root, ProcMesh.rounded_box(Vector3(0.063, 0.133, 0.001), 0.15), _neon(color, 1.1), Vector3(0.0, 0.0, 0.0042))
	var lens := _part(root, ProcMesh.tube(0.006, 0.006, 0.002), _glass(), Vector3(-0.02, 0.055, -0.0045))
	lens.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var label := _label3d("12:07", Color.WHITE, 0.00035)
	label.position = Vector3(0.0, 0.035, 0.0048)
	root.add_child(label)


## Neuro-Chip: Platine im Glasgehäuse mit leuchtendem Kern und Goldkontakten.
static func _build_chip(root: Node3D, color: Color) -> void:
	_part(root, ProcMesh.rounded_box(Vector3(0.045, 0.06, 0.008), 0.25), _glass(), Vector3.ZERO)
	_part(root, ProcMesh.rounded_box(Vector3(0.036, 0.05, 0.003), 0.1), _mat(&"pcb", Color(0.05, 0.2, 0.12), 0.2, 0.5), Vector3.ZERO)
	_part(root, ProcMesh.rounded_box(Vector3(0.016, 0.016, 0.004), 0.2), _neon(color, 2.5), Vector3(0.0, 0.004, 0.0))
	for i in 5:
		_part(root, ProcMesh.rounded_box(Vector3(0.004, 0.006, 0.0035), 0.1), _mat(&"gold", Color(1.0, 0.8, 0.3), 1.0, 0.25),
			Vector3(-0.012 + i * 0.006, -0.026, 0.0))


## Gold-Uhr: Armband als Ring, Gehäuse mit leuchtendem Zifferblatt.
static func _build_watch(root: Node3D, color: Color) -> void:
	var gold := _mat(&"gold", Color(1.0, 0.8, 0.3), 1.0, 0.25)
	var band := TorusMesh.new()
	band.inner_radius = 0.028
	band.outer_radius = 0.034
	band.rings = 24
	band.ring_segments = 8
	var ring := _part(root, band, gold, Vector3.ZERO)
	ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var face := _part(root, ProcMesh.tube(0.019, 0.019, 0.01), gold, Vector3(0.0, 0.0, 0.034))
	face.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var dial := _part(root, ProcMesh.tube(0.016, 0.016, 0.002), _neon(color, 1.3), Vector3(0.0, 0.0, 0.0395))
	dial.rotation = Vector3(PI * 0.5, 0.0, 0.0)


## Zigarettenschachtel mit Banderole und drei herausschauenden Zigaretten.
static func _build_cigarettes(root: Node3D, color: Color) -> void:
	_part(root, ProcMesh.rounded_box(Vector3(0.055, 0.085, 0.022), 0.15), _mat(&"pack", Color(0.12, 0.12, 0.14), 0.0, 0.6), Vector3.ZERO)
	_part(root, ProcMesh.rounded_box(Vector3(0.0555, 0.02, 0.0225), 0.1), _neon(color, 1.3), Vector3(0.0, -0.01, 0.0))
	for i in 3:
		_part(root, ProcMesh.tube(0.0038, 0.0038, 0.02), _mat(&"filter", Color(0.85, 0.6, 0.3), 0.0, 0.8),
			Vector3(-0.012 + i * 0.009, 0.048, 0.003))
	var label := _label3d("KAGE", Color.WHITE, 0.0003)
	label.position = Vector3(0.0, 0.02, 0.0115)
	root.add_child(label)


## Data-Shard: leuchtender Kristallstab in Metallfassung.
static func _build_shard(root: Node3D, color: Color) -> void:
	_part(root, ProcMesh.rounded_box(Vector3(0.018, 0.03, 0.012), 0.2), _mat(&"metal", Color(0.62, 0.64, 0.68), 0.9, 0.25), Vector3(0.0, -0.025, 0.0))
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0.0
	crystal.bottom_radius = 0.009
	crystal.height = 0.05
	crystal.radial_segments = 6
	crystal.rings = 1
	_part(root, crystal, _neon(color, 2.2), Vector3(0.0, 0.015, 0.0))
	_part(root, ProcMesh.tube(0.0105, 0.0105, 0.004), _neon(color, 1.0), Vector3(0.0, -0.009, 0.0))


static func _label3d(text: String, color: Color, pixel: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.outline_size = 6
	label.pixel_size = pixel
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.0, 0.1)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return label


## Icons der neuen Modelle (gleicher Linienstil wie draw_icon).
static func _draw_icon_extra(canvas: CanvasItem, kind: StringName, center: Vector2, s: float, color: Color,
		fill: Color, line: float) -> void:
	match kind:
		BOTTLE, PILLS:
			var r := s * (0.15 if kind == BOTTLE else 0.17)
			var h := s * (0.34 if kind == BOTTLE else 0.24)
			var body := Rect2(center - Vector2(r, h * 0.7), Vector2(r * 2.0, h * 1.7))
			canvas.draw_rect(body, fill)
			canvas.draw_rect(body, color, false, line)
			var cap := Rect2(center + Vector2(-r * 0.55, -h * 0.7 - s * 0.1), Vector2(r * 1.1, s * 0.1))
			canvas.draw_rect(cap, color if kind == BOTTLE else Color.WHITE)
			canvas.draw_line(center + Vector2(-r, h * 0.1), center + Vector2(r, h * 0.1), color, line)
		CUP:
			var top := s * 0.24
			var bottom := s * 0.17
			var h := s * 0.3
			var cup := PackedVector2Array([center + Vector2(-top, -h * 0.7), center + Vector2(top, -h * 0.7),
				center + Vector2(bottom, h), center + Vector2(-bottom, h)])
			canvas.draw_colored_polygon(cup, fill)
			cup.append(cup[0])
			canvas.draw_polyline(cup, color, line, true)
			canvas.draw_rect(Rect2(center + Vector2(-top * 1.08, -h * 0.95), Vector2(top * 2.16, h * 0.25)), color)
		BAR, CIGARETTES, PHONE, CHIP:
			var size := Vector2(0.4, 0.46)
			match kind:
				BAR:
					size = Vector2(0.24, 0.5)
				CIGARETTES:
					size = Vector2(0.36, 0.5)
				PHONE:
					size = Vector2(0.3, 0.6)
			var rect := Rect2(center - size * s * 0.5, size * s)
			canvas.draw_rect(rect, fill)
			canvas.draw_rect(rect, color, false, line)
			match kind:
				BAR:
					canvas.draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y * 0.55), Vector2(rect.size.x, rect.size.y * 0.2)), color)
				CIGARETTES:
					for i in 3:
						var x := rect.position.x + rect.size.x * (0.25 + i * 0.25)
						canvas.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y - s * 0.08), Color.WHITE, 3.0)
				PHONE:
					canvas.draw_rect(rect.grow(-s * 0.04), Color(color, 0.6))
				CHIP:
					canvas.draw_rect(Rect2(center - Vector2(s * 0.08, s * 0.08), Vector2(s * 0.16, s * 0.16)), Color.WHITE)
					for i in 4:
						var x := rect.position.x + rect.size.x * (0.2 + i * 0.2)
						canvas.draw_line(Vector2(x, rect.end.y), Vector2(x, rect.end.y + s * 0.06), Color(1.0, 0.8, 0.3), 2.0)
		ONIGIRI:
			var tri := PackedVector2Array([center + Vector2(0.0, -s * 0.3), center + Vector2(s * 0.3, s * 0.22),
				center + Vector2(-s * 0.3, s * 0.22)])
			canvas.draw_colored_polygon(tri, Color(1.0, 1.0, 1.0, 0.3))
			tri.append(tri[0])
			canvas.draw_polyline(tri, color, line, true)
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.12, s * 0.02), Vector2(s * 0.24, s * 0.2)), Color(0.05, 0.15, 0.08))
		MEDKIT:
			var rect := Rect2(center - Vector2(s * 0.3, s * 0.2), Vector2(s * 0.6, s * 0.45))
			canvas.draw_rect(rect, fill)
			canvas.draw_rect(rect, color, false, line)
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.05, -s * 0.12), Vector2(s * 0.1, s * 0.3)), Color.WHITE)
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.15, -s * 0.02), Vector2(s * 0.3, s * 0.1)), Color.WHITE)
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-s * 0.1, -s * 0.2), center + Vector2(-s * 0.1, -s * 0.28),
				center + Vector2(s * 0.1, -s * 0.28), center + Vector2(s * 0.1, -s * 0.2)]), color, line)
		WATCH:
			canvas.draw_arc(center, s * 0.26, 0.0, TAU, 28, Color(1.0, 0.8, 0.3), 3.0, true)
			canvas.draw_circle(center, s * 0.15, fill)
			canvas.draw_arc(center, s * 0.15, 0.0, TAU, 20, color, line, true)
			canvas.draw_line(center, center + Vector2(0.0, -s * 0.1), Color.WHITE, 2.0)
			canvas.draw_line(center, center + Vector2(s * 0.07, 0.0), Color.WHITE, 2.0)
		SHARD:
			var crystal := PackedVector2Array([center + Vector2(0.0, -s * 0.32), center + Vector2(s * 0.1, s * 0.05),
				center + Vector2(-s * 0.1, s * 0.05)])
			canvas.draw_colored_polygon(crystal, Color(color, 0.7))
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.1, s * 0.05), Vector2(s * 0.2, s * 0.22)), color, false, line)
		CROWBAR:
			canvas.draw_line(center + Vector2(-s * 0.28, s * 0.2), center + Vector2(s * 0.2, -s * 0.22), color, line * 2.0)
			canvas.draw_rect(Rect2(center + Vector2(s * 0.08, -s * 0.32), Vector2(s * 0.16, s * 0.16)), color)
		JEWELRY, JEWELS:
			canvas.draw_circle(center, s * 0.16, fill)
			canvas.draw_arc(center, s * 0.16, 0.0, TAU, 16, color, line, true)
		CASH, KEYCARD, CUFFS, TIES:
			var rect := Rect2(center - Vector2(s * 0.28, s * 0.16), Vector2(s * 0.56, s * 0.32))
			canvas.draw_rect(rect, fill)
			canvas.draw_rect(rect, color, false, line)
		TV, PAINTING, COMPUTER:
			var screen := Rect2(center - Vector2(s * 0.32, s * 0.22), Vector2(s * 0.64, s * 0.4))
			canvas.draw_rect(screen, fill)
			canvas.draw_rect(screen, color, false, line)


# --- Hilfen --------------------------------------------------------------------

static func _build_crowbar(root: Node3D, color: Color) -> void:
	var metal := _mat(&"crow_metal", Color(0.35, 0.36, 0.38), 0.85, 0.35)
	var grip := _mat(&"crow_grip", color, 0.1, 0.7)
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.025, 0.62, 0.025)
	_part(root, shaft, metal, Vector3(0.0, 0.12, 0.0))
	var hook := BoxMesh.new()
	hook.size = Vector3(0.09, 0.02, 0.02)
	_part(root, hook, metal, Vector3(0.04, 0.42, 0.0))
	var handle := CylinderMesh.new()
	handle.top_radius = 0.02
	handle.bottom_radius = 0.02
	handle.height = 0.16
	_part(root, handle, grip, Vector3(0.0, -0.16, 0.0))


static func _build_prop(root: Node3D, kind: StringName, color: Color) -> void:
	match kind:
		TV:
			_build_tv(root, color)
		PAINTING:
			_build_painting(root, color)
		COMPUTER:
			_build_computer(root, color)
		CASH:
			_build_cash(root, color)
		JEWELS:
			_build_jewels(root, color)
		JEWELRY:
			_build_jewelry(root)
		_:
			var mesh := BoxMesh.new()
			match kind:
				KEYCARD:
					mesh.size = Vector3(0.086, 0.004, 0.054)
				CUFFS:
					mesh.size = Vector3(0.14, 0.03, 0.05)
				TIES:
					mesh.size = Vector3(0.1, 0.02, 0.04)
				_:
					mesh.size = Vector3(0.05, 0.03, 0.05)
			_part(root, mesh, _neon(color, 0.6), Vector3.ZERO)


static func _box_part(root: Node3D, size: Vector3, material: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := _part(root, mesh, material, pos)
	part.rotation_degrees = rot
	return part


## Flachbildfernseher auf Standfuß. Schaut nach +Z.
static func _build_tv(root: Node3D, color: Color) -> void:
	var shell := _mat(&"tv_shell", Color(0.05, 0.05, 0.06), 0.4, 0.4)
	_box_part(root, Vector3(0.42, 0.25, 0.035), shell, Vector3(0.0, 0.05, 0.0))
	_box_part(root, Vector3(0.39, 0.22, 0.004), _neon(color.lightened(0.45), 0.9), Vector3(0.0, 0.05, 0.0185))
	_box_part(root, Vector3(0.39, 0.012, 0.005), _neon(Color(1.0, 0.25, 0.7), 1.2), Vector3(0.0, 0.1, 0.0205))
	_box_part(root, Vector3(0.05, 0.07, 0.03), shell, Vector3(0.0, -0.08, -0.01))
	_box_part(root, Vector3(0.22, 0.012, 0.1), shell, Vector3(0.0, -0.11, 0.0))


## Bild im Rahmen mit Neonsonne und drei Streifen. Schaut nach +Z.
static func _build_painting(root: Node3D, color: Color) -> void:
	var frame := _mat(&"art_frame", Color(0.55, 0.42, 0.18), 0.7, 0.35)
	_box_part(root, Vector3(0.36, 0.28, 0.025), frame, Vector3.ZERO)
	_box_part(root, Vector3(0.32, 0.24, 0.028), _mat(&"art_canvas", Color(0.07, 0.05, 0.16), 0.0, 0.9), Vector3.ZERO)
	var sun := CylinderMesh.new()
	sun.top_radius = 0.065
	sun.bottom_radius = 0.065
	sun.height = 0.004
	sun.radial_segments = 10
	var disc := _part(root, sun, _neon(color, 1.4), Vector3(0.0, 0.04, 0.0145))
	disc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	for i: int in 3:
		_box_part(root, Vector3(0.28 - i * 0.05, 0.014, 0.004), _neon(Color(0.2, 0.9, 1.0), 1.0),
				Vector3(0.0, -0.035 - i * 0.03, 0.0145))


## Monitor mit Tastatur. Schaut nach +Z.
static func _build_computer(root: Node3D, color: Color) -> void:
	var shell := _mat(&"pc_shell", Color(0.14, 0.15, 0.17), 0.4, 0.45)
	_box_part(root, Vector3(0.3, 0.19, 0.025), shell, Vector3(0.0, 0.06, -0.03))
	_box_part(root, Vector3(0.27, 0.16, 0.004), _neon(color, 0.9), Vector3(0.0, 0.06, -0.016))
	_box_part(root, Vector3(0.03, 0.08, 0.03), shell, Vector3(0.0, -0.03, -0.04))
	_box_part(root, Vector3(0.14, 0.01, 0.1), shell, Vector3(0.0, -0.07, -0.03))
	_box_part(root, Vector3(0.24, 0.012, 0.08), _mat(&"pc_keys", Color(0.2, 0.21, 0.24), 0.2, 0.6), Vector3(0.0, -0.07, 0.08))


## Zwei Bündel mit Banderole und eins obendrauf.
static func _build_cash(root: Node3D, color: Color) -> void:
	var paper := _mat(&"cash_paper", color.darkened(0.15), 0.0, 0.9)
	var band := _mat(&"cash_band", Color(0.9, 0.85, 0.7), 0.0, 0.9)
	for i: int in 2:
		var x := -0.035 + i * 0.07
		_box_part(root, Vector3(0.065, 0.025, 0.05), paper, Vector3(x, -0.0125, 0.0))
		_box_part(root, Vector3(0.012, 0.027, 0.052), band, Vector3(x, -0.0125, 0.0))
	_box_part(root, Vector3(0.065, 0.025, 0.05), paper, Vector3(0.0, 0.0125, 0.0), Vector3(0.0, 12.0, 0.0))
	_box_part(root, Vector3(0.012, 0.027, 0.052), band, Vector3(0.0, 0.0125, 0.0), Vector3(0.0, 12.0, 0.0))


## Drei geschliffene Steine auf einem Samtkissen.
static func _build_jewels(root: Node3D, color: Color) -> void:
	_box_part(root, Vector3(0.09, 0.012, 0.07), _mat(&"jewel_pad", Color(0.35, 0.08, 0.2), 0.0, 0.95), Vector3(0.0, -0.02, 0.0))
	var gem := _neon(color, 1.1)
	_box_part(root, Vector3(0.032, 0.032, 0.032), gem, Vector3(-0.025, 0.002, 0.005), Vector3(45.0, 20.0, 45.0))
	_box_part(root, Vector3(0.026, 0.026, 0.026), gem, Vector3(0.025, -0.003, -0.01), Vector3(45.0, 60.0, 45.0))
	_box_part(root, Vector3(0.022, 0.022, 0.022), gem, Vector3(0.005, -0.006, 0.02), Vector3(45.0, 40.0, 45.0))


## Goldring mit Stein und eine Kette.
static func _build_jewelry(root: Node3D) -> void:
	var gold := _mat(&"gold", Color(1.0, 0.82, 0.35), 0.9, 0.25)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.022
	ring.outer_radius = 0.032
	ring.rings = 10
	ring.ring_segments = 6
	_part(root, ring, gold, Vector3(-0.03, 0.0, 0.0)).rotation_degrees = Vector3(70.0, 0.0, 0.0)
	_box_part(root, Vector3(0.018, 0.018, 0.018), _neon(Color(0.9, 0.2, 0.5), 1.2), Vector3(-0.03, 0.03, -0.008), Vector3(45.0, 0.0, 45.0))
	var chain := TorusMesh.new()
	chain.inner_radius = 0.034
	chain.outer_radius = 0.04
	chain.rings = 12
	chain.ring_segments = 4
	_part(root, chain, gold, Vector3(0.04, -0.012, 0.0)).rotation_degrees = Vector3(80.0, 0.0, 0.0)


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
