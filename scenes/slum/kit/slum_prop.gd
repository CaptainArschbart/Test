@tool
class_name SlumProp
extends SlumPiece
## Props & Clutter aus dem Mapkit: Kisten, Container, Tonnen, Klimageräte, Stromkästen, Müll,
## Absperrungen, Hütchen, Hydranten, Laternen, Strommasten, Marktstände, Autowracks.
##
## Ursprung = Bodenmitte, Vorderseite zeigt nach +Z. Mit "variant" bekommt jede Art eine andere
## Farbe oder Anordnung.

enum Kind {
	CRATE, CRATE_STACK, MILITARY_CRATES, DUMPSTER, BARREL, BARREL_GROUP, AC_UNIT, AC_STACK,
	ELECTRIC_BOX, PALLETS, TRASH_BAGS, TRASH_PILE, CONCRETE_BARRIER, STRIPED_BARRIER, CONE,
	HYDRANT, STREET_LAMP, POWER_POLE, CONTAINER, MARKET_STALL, CAR_WRECK, GENERATOR, FENCE,
	BENCH, WATER_TANK, NEWS_BOX, FIRE_BARREL,
}

@export var kind := Kind.CRATE:
	set(v):
		kind = v
		queue_rebuild()
## Farb-/Formvariante (0, 1, 2 …), je nach Art.
@export var variant := 0:
	set(v):
		variant = v
		queue_rebuild()
## Länge für Zäune und Absperrungen in Metern.
@export var length := 4.0:
	set(v):
		length = v
		queue_rebuild()
## Licht an (Laternen, Marktstände). Aus spart Leistung in dichten Ecken.
@export var light_on := true:
	set(v):
		light_on = v
		queue_rebuild()


func _build(b: SlumBuilder) -> void:
	match kind:
		Kind.CRATE: _crate(b, Vector3(0, 0, 0), 0.8, 0.0)
		Kind.CRATE_STACK: _crate_stack(b)
		Kind.MILITARY_CRATES: _military(b)
		Kind.DUMPSTER: _dumpster(b)
		Kind.BARREL: _barrel(b, Vector3.ZERO, variant)
		Kind.BARREL_GROUP: _barrel_group(b)
		Kind.AC_UNIT: _ac(b, Vector3.ZERO, 0.0)
		Kind.AC_STACK: _ac_stack(b)
		Kind.ELECTRIC_BOX: _electric_box(b)
		Kind.PALLETS: _pallets(b)
		Kind.TRASH_BAGS: _trash_bags(b, Vector3.ZERO, 4 + variant * 2)
		Kind.TRASH_PILE: _trash_pile(b)
		Kind.CONCRETE_BARRIER: _concrete_barrier(b)
		Kind.STRIPED_BARRIER: _striped_barrier(b)
		Kind.CONE: _cone(b, Vector3.ZERO)
		Kind.HYDRANT: _hydrant(b)
		Kind.STREET_LAMP: _street_lamp(b)
		Kind.POWER_POLE: _power_pole(b)
		Kind.CONTAINER: _container(b)
		Kind.MARKET_STALL: _stall(b)
		Kind.CAR_WRECK: _car(b)
		Kind.GENERATOR: _generator(b)
		Kind.FENCE: _fence(b)
		Kind.BENCH: _bench(b)
		Kind.WATER_TANK: _water_tank(b, Vector3.ZERO)
		Kind.NEWS_BOX: _news_box(b)
		Kind.FIRE_BARREL: _fire_barrel(b)


# ------------------------------------------------------------------ Kisten

func _crate(b: SlumBuilder, at: Vector3, s: float, rot: float, tex := "crate_wood") -> void:
	b.box(at + Vector3.UP * s * 0.5, Vector3.ONE * s, SlumMats.uv(tex), true, true, rot)


func _crate_stack(b: SlumBuilder) -> void:
	var tex: String = ["crate_wood", "crate_military", "crate_wood"][variant % 3]
	var layout := [Vector3(-0.45, 0, 0), Vector3(0.45, 0, 0.05), Vector3(0.0, 0, -0.85), Vector3(-0.1, 0.9, 0)]
	for i: int in layout.size():
		if i == 3 and variant % 2 == 1:
			continue
		_crate(b, layout[i], 0.88, rng.randf_range(-12, 12), tex)
	if variant >= 2:
		_crate(b, Vector3(0.5, 0.9, -0.1), 0.7, 25.0, "crate_military")


func _military(b: SlumBuilder) -> void:
	var mat := SlumMats.uv("crate_military")
	for i: int in 3:
		b.box(Vector3((i - 1) * 1.05, 0.3, 0), Vector3(1.0, 0.6, 0.6), mat, true, true, rng.randf_range(-4, 4))
	b.box(Vector3(-0.5, 0.9, 0), Vector3(1.0, 0.6, 0.6), mat, true, true, 3)
	b.box(Vector3(0.55, 0.9, 0.05), Vector3(1.0, 0.6, 0.6), mat, true, true, -6)


func _pallets(b: SlumBuilder) -> void:
	var mat := SlumMats.uv("pallet")
	var count := 3 + variant * 2
	for i: int in count:
		b.box(Vector3(rng.randf_range(-0.05, 0.05), 0.07 + i * 0.14, rng.randf_range(-0.05, 0.05)),
				Vector3(1.2, 0.13, 1.0), mat, true, true, rng.randf_range(-6, 6))


# ------------------------------------------------------------------ Container, Tonnen

func _dumpster(b: SlumBuilder) -> void:
	var tex := "dumpster_green" if variant % 2 == 0 else "dumpster_blue"
	var mat := SlumMats.uv(tex)
	var dark := SlumMats.color(Color(0.08, 0.09, 0.08), 0.0, 0.6, 0.4)
	b.box(Vector3(0, 0.62, 0), Vector3(1.9, 1.0, 1.1), mat)
	# Deckel leicht offen, Rollen
	var lid := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0 if variant < 2 else -55.0)), Vector3(0, 1.14, -0.55))
	b.box_x(lid * Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0.55)), Vector3(1.95, 0.06, 1.15), mat, false)
	for x: float in [-0.8, 0.8]:
		for z: float in [-0.4, 0.4]:
			b.cylinder_x(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, 0.07, z)), 0.07, 0.06, dark, 6)
	b.box(Vector3(0, 0.95, 0.58), Vector3(1.6, 0.05, 0.06), dark, false)
	if variant >= 2:
		_trash_bags(b, Vector3(1.4, 0, 0.4), 3)


func _barrel(b: SlumBuilder, at: Vector3, v: int) -> void:
	var tex := "barrel_blue" if v % 2 == 0 else "barrel_rust"
	b.cylinder(at, 0.29, 0.88, SlumMats.uv(tex), 10, true)
	var ring := SlumMats.color(Color(0.1, 0.1, 0.1), 0.0, 0.5, 0.5)
	b.cylinder(at + Vector3.UP * 0.88, 0.26, 0.02, ring, 10)


## Tonne mit Feuer: glühende Glut oben, flackerndes oranges Licht.
func _fire_barrel(b: SlumBuilder) -> void:
	b.cylinder(Vector3.ZERO, 0.29, 0.88, SlumMats.uv("barrel_rust", Color(0.7, 0.6, 0.55)), 10, true)
	var ember := SlumMats.color(Color(1.0, 0.45, 0.1), 6.0)
	var flame := SlumMats.color(Color(1.0, 0.7, 0.2), 8.0)
	b.cylinder(Vector3.UP * 0.86, 0.25, 0.04, ember, 10)
	for i: int in 4:
		var a := TAU * i / 4.0 + rng.randf()
		var p := Vector3(cos(a) * 0.1, 0.9, sin(a) * 0.1)
		b.box(p + Vector3.UP * 0.12, Vector3(0.08, 0.25 + rng.randf() * 0.15, 0.08), flame, false, false, rng.randf() * 90.0)
	# Holz und Müll ringsum, Leute wärmen sich hier
	b.box(Vector3(0.7, 0.06, 0.2), Vector3(0.6, 0.12, 0.12), SlumMats.surface("wood_dark"), false, true, 30)
	if light_on:
		add_light(Vector3(0, 1.4, 0), Color(1.0, 0.5, 0.2), 2.4, 7.0, 0.35, variant == 1)


func _barrel_group(b: SlumBuilder) -> void:
	_barrel(b, Vector3(-0.32, 0, 0), variant)
	_barrel(b, Vector3(0.33, 0, 0.1), variant + 1)
	_barrel(b, Vector3(0.0, 0, -0.55), variant)
	if variant % 2 == 0:
		# umgekippte Tonne
		b.cylinder_x(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(1.0, 0.29, 0.4)), 0.29, 0.88,
				SlumMats.uv("barrel_rust"), 10, true)


# ------------------------------------------------------------------ Technik

func _ac(b: SlumBuilder, at: Vector3, rot: float) -> void:
	var body := SlumMats.color(Color(0.62, 0.63, 0.6), 0.0, 0.6)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(rot)), at)
	b.box_x(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), Vector3(0.85, 0.6, 0.38), body)
	b.quad_x(xf * Transform3D(Basis.IDENTITY, Vector3(0.1, 0.3, 0.195)), 0.5, 0.5, SlumMats.decal("ac_front"))
	b.quad_x(xf * Transform3D(Basis.IDENTITY, Vector3(-0.31, 0.3, 0.195)), 0.16, 0.5, SlumMats.decal("vent_louver"))


func _ac_stack(b: SlumBuilder) -> void:
	var frame := SlumMats.surface("rust")
	var rows := 2 + variant % 2
	for r: int in rows:
		for c: int in 2:
			_ac(b, Vector3((c - 0.5) * 0.95, r * 0.66, 0), 0.0)
		b.box(Vector3(0, r * 0.66 + 0.63, 0), Vector3(1.9, 0.04, 0.42), frame, false)
	b.tube(Vector3(-0.95, 0, 0.2), Vector3(-0.95, rows * 0.66, 0.2), 0.02, frame)
	b.tube(Vector3(0.95, 0, 0.2), Vector3(0.95, rows * 0.66, 0.2), 0.02, frame)


func _electric_box(b: SlumBuilder) -> void:
	var body := SlumMats.color(Color(0.36, 0.4, 0.36), 0.0, 0.7, 0.2)
	b.box(Vector3(0, 0.75, 0), Vector3(0.8, 1.5, 0.35), body)
	b.quad(Vector3(0, 0.95, 0.18), Vector3.BACK, 0.7, 0.9, SlumMats.decal("electric_box"))
	b.box(Vector3(0, 1.53, 0.02), Vector3(0.9, 0.06, 0.45), body, false)
	var cable := SlumMats.color(Color(0.04, 0.04, 0.04))
	for i: int in 3:
		var x := -0.25 + i * 0.25
		b.tube(Vector3(x, 1.5, -0.05), Vector3(x + rng.randf_range(-0.3, 0.3), 3.2, -0.12), 0.025, cable)
	var led := SlumMats.color(Color(0.1, 1.0, 0.3), 4.0)
	b.box(Vector3(0.28, 1.35, 0.18), Vector3(0.04, 0.04, 0.02), led, false, false)


func _generator(b: SlumBuilder) -> void:
	var body := SlumMats.color(Color(0.55, 0.42, 0.12), 0.0, 0.6, 0.3)
	var dark := SlumMats.color(Color(0.1, 0.1, 0.1), 0.0, 0.6, 0.5)
	b.box(Vector3(0, 0.1, 0), Vector3(1.6, 0.2, 0.9), dark)
	b.box(Vector3(0, 0.6, 0), Vector3(1.4, 0.8, 0.8), body)
	b.quad(Vector3(-0.3, 0.6, 0.41), Vector3.BACK, 0.5, 0.5, SlumMats.decal("vent_grille"))
	b.quad(Vector3(0.35, 0.6, 0.41), Vector3.BACK, 0.45, 0.3, SlumMats.decal("sign_beware"))
	b.tube(Vector3(0.5, 1.0, -0.2), Vector3(0.5, 1.6, -0.2), 0.05, dark)
	b.cable(Vector3(-0.7, 0.4, 0), Vector3(-2.5, 0.02, 1.0), 0.05, dark, 0.03, 5)


func _water_tank(b: SlumBuilder, at: Vector3) -> void:
	var tank := SlumMats.surface("rust", Color(0.8, 0.85, 0.9))
	var legs := SlumMats.color(Color(0.15, 0.15, 0.15), 0.0, 0.6, 0.6)
	for x: float in [-0.7, 0.7]:
		for z: float in [-0.7, 0.7]:
			b.box(at + Vector3(x, 0.6, z), Vector3(0.1, 1.2, 0.1), legs, false)
	b.box(at + Vector3(0, 1.25, 0), Vector3(1.7, 0.1, 1.7), legs)
	b.cylinder(at + Vector3.UP * 1.3, 0.85, 1.6, tank, 12, true)
	b.cylinder(at + Vector3.UP * 2.9, 0.5, 0.15, tank, 12)
	b.tube(at + Vector3(0.6, 1.3, 0.6), at + Vector3(0.6, 0.0, 0.6), 0.04, legs)


# ------------------------------------------------------------------ Müll

func _trash_bags(b: SlumBuilder, at: Vector3, count: int) -> void:
	var mats := [SlumMats.color(Color(0.04, 0.04, 0.05), 0.0, 0.35), SlumMats.color(Color(0.12, 0.13, 0.12), 0.0, 0.4),
		SlumMats.color(Color(0.1, 0.14, 0.24), 0.0, 0.4)]
	for i: int in count:
		var p := at + Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.5, 0.5))
		var s := rng.randf_range(0.35, 0.55)
		var mat: Material = mats[rng.randi() % mats.size()]
		b.box(p + Vector3.UP * s * 0.38, Vector3(s, s * 0.75, s * 0.9), mat, false, true, rng.randf_range(0, 90))
		b.box(p + Vector3.UP * s * 0.8, Vector3(s * 0.3, s * 0.2, s * 0.3), mat, false, true, rng.randf_range(0, 90))
	b.collider(at + Vector3.UP * 0.2, Vector3(1.4, 0.4, 1.0))


func _trash_pile(b: SlumBuilder) -> void:
	_trash_bags(b, Vector3.ZERO, 6)
	b.quad_x(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.3, 0.02, 0.6)), 2.4, 2.0, SlumMats.decal("trash"))
	_crate(b, Vector3(-0.9, 0, -0.5), 0.6, 30.0)
	var tire := SlumMats.color(Color(0.05, 0.05, 0.05), 0.0, 0.8)
	b.cylinder_x(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.9, 0.1, -0.4)), 0.32, 0.2, tire, 8)


# ------------------------------------------------------------------ Straße

func _concrete_barrier(b: SlumBuilder) -> void:
	var mat := SlumMats.surface("concrete", Color(0.85, 0.85, 0.82))
	var segs := maxi(1, int(round(length / 2.0)))
	for i: int in segs:
		var x := (i - (segs - 1) * 0.5) * 2.05
		b.box(Vector3(x, 0.15, 0), Vector3(2.0, 0.3, 0.6), mat)
		b.box(Vector3(x, 0.55, 0), Vector3(2.0, 0.5, 0.36), mat, true, true, 0)
		b.box(Vector3(x, 0.92, 0), Vector3(2.0, 0.24, 0.22), mat)
		b.quad(Vector3(x, 0.55, 0.185), Vector3.BACK, 1.6, 0.25, SlumMats.decal("hazard") if rng.randf() < 0.3 else SlumMats.decal("tag_1"))


func _striped_barrier(b: SlumBuilder) -> void:
	var stripes := SlumMats.surface("red_white")
	var legs := SlumMats.color(Color(0.12, 0.12, 0.12), 0.0, 0.6, 0.5)
	var w := clampf(length, 1.2, 3.0)
	b.box(Vector3(0, 0.85, 0), Vector3(w, 0.25, 0.05), stripes)
	b.box(Vector3(0, 0.45, 0), Vector3(w * 0.9, 0.12, 0.05), stripes, false)
	for x: float in [-w * 0.42, w * 0.42]:
		b.tube(Vector3(x, 0, -0.35), Vector3(x, 0.98, 0), 0.03, legs)
		b.tube(Vector3(x, 0, 0.35), Vector3(x, 0.98, 0), 0.03, legs)
	var lamp := SlumMats.color(Color(1.0, 0.55, 0.1), 5.0)
	b.box(Vector3(-w * 0.42, 1.04, 0), Vector3(0.1, 0.1, 0.1), lamp, false, false)


func _cone(b: SlumBuilder, at: Vector3) -> void:
	var orange := SlumMats.color(Color(0.9, 0.35, 0.06), 0.0, 0.6)
	var white := SlumMats.color(Color(0.85, 0.85, 0.82), 0.0, 0.6)
	b.box(at + Vector3.UP * 0.02, Vector3(0.42, 0.04, 0.42), orange)
	b.cylinder(at + Vector3.UP * 0.04, 0.16, 0.18, orange, 8)
	b.cylinder(at + Vector3.UP * 0.22, 0.13, 0.1, white, 8)
	b.cylinder(at + Vector3.UP * 0.32, 0.1, 0.18, orange, 8)
	b.cylinder(at + Vector3.UP * 0.5, 0.05, 0.12, orange, 6)


func _hydrant(b: SlumBuilder) -> void:
	var red := SlumMats.color(Color(0.55, 0.08, 0.06), 0.0, 0.5, 0.3)
	b.cylinder(Vector3.ZERO, 0.17, 0.12, red, 8, true)
	b.cylinder(Vector3.UP * 0.12, 0.13, 0.55, red, 8)
	b.cylinder(Vector3.UP * 0.67, 0.15, 0.06, red, 8)
	b.cylinder(Vector3.UP * 0.73, 0.1, 0.12, red, 8)
	b.tube(Vector3(-0.2, 0.45, 0), Vector3(0.2, 0.45, 0), 0.06, red)
	b.tube(Vector3(0, 0.45, 0), Vector3(0, 0.45, 0.2), 0.07, red)


func _news_box(b: SlumBuilder) -> void:
	var body := SlumMats.color(Color(0.1, 0.25, 0.45), 0.0, 0.5, 0.3)
	b.box(Vector3(0, 0.55, 0), Vector3(0.5, 1.1, 0.45), body)
	b.quad(Vector3(0, 0.8, 0.23), Vector3.BACK, 0.4, 0.3, SlumMats.decal("window_dark"))
	b.quad(Vector3(0, 0.4, 0.23), Vector3.BACK, 0.4, 0.5, SlumMats.decal(pick(["poster_1", "poster_3"])))


func _street_lamp(b: SlumBuilder) -> void:
	var pole := SlumMats.color(Color(0.12, 0.13, 0.14), 0.0, 0.5, 0.6)
	var glow := SlumMats.color(Color(1.0, 0.78, 0.5), 6.0)
	b.cylinder(Vector3.ZERO, 0.14, 0.4, pole, 8, true)
	b.tube(Vector3(0, 0.3, 0), Vector3(0, 5.6, 0), 0.07, pole, 6)
	b.tube(Vector3(0, 5.5, 0), Vector3(0, 5.9, 0.9), 0.05, pole, 6)
	b.tube(Vector3(0, 5.9, 0.9), Vector3(0, 5.85, 1.5), 0.05, pole, 6)
	b.box(Vector3(0, 5.78, 1.5), Vector3(0.36, 0.14, 0.6), pole, false)
	b.box(Vector3(0, 5.7, 1.5), Vector3(0.28, 0.03, 0.48), glow, false, false)
	b.collider(Vector3(0, 2.8, 0), Vector3(0.2, 5.6, 0.2))
	if light_on:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.72, 0.42)
		spot.light_energy = 10.0
		spot.spot_range = 13.0
		spot.spot_angle = 62.0
		spot.spot_attenuation = 0.8
		spot.shadow_enabled = variant == 1
		spot.distance_fade_enabled = true
		spot.distance_fade_begin = 50.0
		spot.distance_fade_length = 15.0
		add_gen(spot, Vector3(0, 5.6, 1.5))
		spot.rotation_degrees = Vector3(-90, 0, 0)
		if variant == 2 and not Engine.is_editor_hint():
			var f := SlumFlicker.new()
			f.amount = 0.6
			f.base_energy = 10.0
			spot.add_child(f)


func _power_pole(b: SlumBuilder) -> void:
	var wood := SlumMats.surface("wood_dark")
	var metal := SlumMats.color(Color(0.18, 0.18, 0.18), 0.0, 0.6, 0.5)
	var insul := SlumMats.color(Color(0.5, 0.55, 0.5), 0.0, 0.4)
	b.cylinder(Vector3.ZERO, 0.16, 9.0, wood, 8, true)
	for y: float in [7.6, 8.5]:
		b.box(Vector3(0, y, 0), Vector3(2.2, 0.14, 0.14), wood, false)
		for x: float in [-0.9, -0.3, 0.3, 0.9]:
			b.cylinder(Vector3(x, y + 0.07, 0), 0.05, 0.16, insul, 6)
	# Trafo-Tonne
	b.cylinder(Vector3(0.32, 6.0, 0), 0.25, 0.8, metal, 8)
	b.tube(Vector3(0.32, 6.8, 0), Vector3(0.9, 7.6, 0), 0.02, metal, 4)
	# Steigeisen
	for i: int in 10:
		var y := 1.8 + i * 0.5
		var side := 1.0 if i % 2 == 0 else -1.0
		b.tube(Vector3(0, y, 0), Vector3(0.0, y, 0.3 * side), 0.015, metal, 4)
	# Kabel hängen nach beiden Seiten etwas herunter (Verbindungen setzt die Map mit SlumCables)
	var cable := SlumMats.color(Color(0.03, 0.03, 0.03))
	b.cable(Vector3(-0.9, 8.6, 0), Vector3(-0.2, 6.2, 0.3), 0.3, cable)


# ------------------------------------------------------------------ Große Teile

func _container(b: SlumBuilder) -> void:
	var colors := [Color(0.42, 0.12, 0.08), Color(0.12, 0.25, 0.42), Color(0.18, 0.32, 0.2), Color(0.55, 0.42, 0.12)]
	var tex := SlumMats.surface("corrugated_grey", colors[variant % colors.size()] * 2.2)
	var frame := SlumMats.color(colors[variant % colors.size()] * 0.7, 0.0, 0.7, 0.3)
	var l := 6.0
	var w := 2.44
	var h := 2.6
	b.box(Vector3(0, h * 0.5, 0), Vector3(w - 0.08, h - 0.1, l - 0.1), tex)
	for x: float in [-w * 0.5 + 0.04, w * 0.5 - 0.04]:
		for z: float in [-l * 0.5 + 0.04, l * 0.5 - 0.04]:
			b.box(Vector3(x, h * 0.5, z), Vector3(0.12, h, 0.12), frame, false)
	b.box(Vector3(0, h - 0.04, 0), Vector3(w, 0.1, l), frame, false)
	b.box(Vector3(0, 0.05, 0), Vector3(w, 0.1, l), frame, false)
	# Türen an der Stirnseite (+Z)
	var bars := SlumMats.color(Color(0.1, 0.1, 0.1), 0.0, 0.5, 0.6)
	for x: float in [-0.35, 0.35]:
		b.tube(Vector3(x, 0.2, l * 0.5 + 0.03), Vector3(x, h - 0.2, l * 0.5 + 0.03), 0.025, bars, 4)
	b.quad(Vector3(0.6, 1.9, l * 0.5 + 0.02), Vector3.BACK, 0.8, 0.5, SlumMats.decal("stencil_a2" if variant % 2 == 0 else "stencil_07"))


func _stall(b: SlumBuilder) -> void:
	var wood := SlumMats.surface("wood")
	var tarp := SlumMats.surface(["tarp_red", "tarp_blue"][variant % 2])
	var metal := SlumMats.color(Color(0.2, 0.2, 0.2), 0.0, 0.6, 0.5)
	b.box(Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 1.0), wood)
	b.box(Vector3(0, 0.93, 0.05), Vector3(2.5, 0.06, 1.1), wood, false)
	for x: float in [-1.15, 1.15]:
		b.tube(Vector3(x, 0, 0.5), Vector3(x, 2.3, 0.5), 0.04, metal)
		b.tube(Vector3(x, 0, -0.5), Vector3(x, 2.5, -0.5), 0.04, metal)
	var roof := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(0, 2.45, 0.1))
	b.box_x(roof, Vector3(2.7, 0.04, 1.6), tarp, false)
	b.quad(Vector3(0, 2.25, 0.88), Vector3.BACK, 2.7, 0.36, SlumMats.decal(["sign_noodles", "sign_ramen", "sign_24h"][variant % 3]))
	# Waren: bunte Kistchen und Schüsseln
	var goods := [Color(0.8, 0.2, 0.1), Color(0.9, 0.7, 0.1), Color(0.2, 0.6, 0.3), Color(0.9, 0.9, 0.85)]
	for i: int in 8:
		var c: Color = goods[rng.randi() % goods.size()]
		b.box(Vector3(-1.0 + i * 0.28, 1.02, rng.randf_range(-0.2, 0.25)), Vector3(0.2, rng.randf_range(0.08, 0.2), 0.2),
				SlumMats.color(c, 0.0, 0.6), false)
	var bulb := SlumMats.color(Color(1.0, 0.85, 0.6), 8.0)
	b.box(Vector3(0, 2.15, 0), Vector3(0.1, 0.12, 0.1), bulb, false, false)
	b.tube(Vector3(0, 2.2, 0), Vector3(0, 2.42, 0), 0.01, metal, 4)
	if light_on:
		add_light(Vector3(0, 2.0, 0.3), Color(1.0, 0.75, 0.45), 1.6, 5.5, 0.08)


func _car(b: SlumBuilder) -> void:
	var paint := SlumMats.surface("rust", [Color(0.7, 0.75, 0.85), Color(0.9, 0.6, 0.6), Color(0.7, 0.9, 0.7)][variant % 3])
	var dark := SlumMats.color(Color(0.05, 0.05, 0.06), 0.0, 0.7)
	var glass := SlumMats.color(Color(0.03, 0.05, 0.07), 0.0, 0.15, 0.4)
	b.box(Vector3(0, 0.65, 0), Vector3(1.8, 0.6, 4.2), paint)
	b.box(Vector3(0, 1.18, -0.2), Vector3(1.6, 0.5, 2.1), paint)
	b.box(Vector3(0, 1.18, 0.86), Vector3(1.5, 0.42, 0.06), glass, false, true, 0)
	b.box(Vector3(0, 1.18, -1.26), Vector3(1.5, 0.42, 0.06), glass, false)
	for x: float in [-0.81, 0.81]:
		b.box(Vector3(x, 1.18, -0.2), Vector3(0.02, 0.36, 1.8), glass, false)
	# Ein Rad fehlt, der Wagen hängt schief
	for p: Vector3 in [Vector3(-0.85, 0.32, 1.3), Vector3(0.85, 0.32, 1.3), Vector3(-0.85, 0.32, -1.3)]:
		b.cylinder_x(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), p), 0.32, 0.24, dark, 8)
	b.box(Vector3(0.75, 0.18, -1.3), Vector3(0.3, 0.36, 0.3), SlumMats.uv("crate_wood"))
	var tail := SlumMats.color(Color(0.6, 0.05, 0.05), 0.6)
	b.box(Vector3(-0.65, 0.75, -2.11), Vector3(0.3, 0.12, 0.02), tail, false)
	b.box(Vector3(0.65, 0.75, -2.11), Vector3(0.3, 0.12, 0.02), tail, false)


func _fence(b: SlumBuilder) -> void:
	var metal := SlumMats.color(Color(0.3, 0.3, 0.3), 0.0, 0.5, 0.6)
	var mesh_mat := SlumMats.decal("chainlink")
	var segs := maxi(1, int(ceil(length / 2.5)))
	var seg_len := length / segs
	for i: int in segs + 1:
		var x := -length * 0.5 + i * seg_len
		b.tube(Vector3(x, 0, 0), Vector3(x, 2.2, 0), 0.04, metal)
	b.tube(Vector3(-length * 0.5, 2.2, 0), Vector3(length * 0.5, 2.2, 0), 0.03, metal)
	b.tube(Vector3(-length * 0.5, 0.1, 0), Vector3(length * 0.5, 0.1, 0), 0.03, metal)
	for i: int in segs:
		var x := -length * 0.5 + (i + 0.5) * seg_len
		b.quad(Vector3(x, 1.15, 0), Vector3.BACK, seg_len, 2.1, mesh_mat, Rect2(0, 0, seg_len / 0.5, 4.2))
		b.quad(Vector3(x, 1.15, 0), Vector3.FORWARD, seg_len, 2.1, mesh_mat, Rect2(0, 0, seg_len / 0.5, 4.2))
	b.collider(Vector3(0, 1.1, 0), Vector3(length, 2.2, 0.1))


func _bench(b: SlumBuilder) -> void:
	var wood := SlumMats.surface("wood_dark")
	var metal := SlumMats.color(Color(0.15, 0.15, 0.15), 0.0, 0.5, 0.6)
	b.box(Vector3(0, 0.45, 0), Vector3(1.8, 0.06, 0.45), wood)
	b.box(Vector3(0, 0.8, -0.22), Vector3(1.8, 0.3, 0.05), wood, false)
	for x: float in [-0.75, 0.75]:
		b.box(Vector3(x, 0.22, 0), Vector3(0.06, 0.44, 0.4), metal, false)
