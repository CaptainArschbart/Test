class_name VehicleModel
extends Node3D
## Low-Poly-Auto im Stil des Mapkits (Boxen, flache Farben, Neon). Vorne ist -Z.
##
## Arten: KOMPAKT (kleiner Stadtflitzer), LIMOUSINE (flach, Lichtleiste vorn), TRANSPORTER (hoher
## Kasten mit Leuchtstreifen), TAXI (gelbe Limousine mit Dachschild), PICKUP (Ladefläche, Dachlampen).
## Karosserie und Glas laufen über SlumBuilder (ein Mesh pro Material), Räder sind eigene Knoten,
## damit sie sich drehen. Rück- und Bremslicht teilen ein eigenes Material pro Auto.

enum Kind { COMPACT, SEDAN, VAN, TAXI, PICKUP }

const PAINTS := [Color(0.08, 0.08, 0.1), Color(0.25, 0.27, 0.3), Color(0.35, 0.06, 0.08), Color(0.05, 0.22, 0.25),
		Color(0.22, 0.08, 0.3), Color(0.55, 0.55, 0.58), Color(0.1, 0.14, 0.3), Color(0.4, 0.3, 0.12)]
const ACCENTS := [Color(0.0, 0.95, 1.0), Color(1.0, 0.15, 0.7), Color(0.6, 0.3, 1.0), Color(1.0, 0.55, 0.1),
		Color(0.2, 1.0, 0.4)]

var kind := Kind.SEDAN
var half_length := 2.3
var half_width := 0.92
var height := 1.4
var headlight: SpotLight3D

var _wheels: Array[Node3D] = []
var _wheel_radius := 0.34
var _tail_mat: StandardMaterial3D
var _spin := 0.0

static var _wheel_mesh: CylinderMesh
static var _wheel_mat: StandardMaterial3D


func build(new_kind: Kind, rng: RandomNumberGenerator) -> void:
	kind = new_kind
	var paint_color: Color = PAINTS[rng.randi() % PAINTS.size()]
	if kind == Kind.TAXI:
		paint_color = Color(0.95, 0.72, 0.08)
	var accent: Color = ACCENTS[rng.randi() % ACCENTS.size()]
	var paint := SlumMats.color(paint_color, 0.0, 0.3, 0.45)
	var dark := SlumMats.color(Color(0.04, 0.04, 0.05), 0.0, 0.7)
	var glass := SlumMats.color(Color(0.04, 0.07, 0.1), 0.0, 0.08, 0.6)
	var neon := SlumMats.color(accent, 3.0)
	var head := SlumMats.color(Color(0.85, 0.92, 1.0), 4.0)
	_tail_mat = StandardMaterial3D.new()
	_tail_mat.albedo_color = Color(0.7, 0.03, 0.05)
	_tail_mat.emission_enabled = true
	_tail_mat.emission = Color(1.0, 0.05, 0.08)
	_tail_mat.emission_energy_multiplier = 1.4
	var b := SlumBuilder.new(self)
	match kind:
		Kind.COMPACT: _compact(b, paint, glass)
		Kind.SEDAN, Kind.TAXI: _sedan(b, paint, glass, neon)
		Kind.VAN: _van(b, paint, glass, neon)
		Kind.PICKUP: _pickup(b, paint, glass, dark)
	if kind == Kind.TAXI:
		b.box(Vector3(0, 1.38, 0.2), Vector3(0.7, 0.2, 0.3), SlumMats.color(Color(1.0, 0.85, 0.3), 3.0), false, false)
		for z: float in [-0.6, 0.6]:
			b.box(Vector3(half_width + 0.005, 0.62, z), Vector3(0.01, 0.08, 0.8), dark, false, false)
	# Unterboden, Radkästen, Unterbodenbeleuchtung
	b.box(Vector3(0, 0.36, 0), Vector3(half_width * 2.0 - 0.12, 0.24, half_length * 2.0 - 0.5), dark, false)
	b.box(Vector3(0, 0.2, 0), Vector3(half_width * 2.0 - 0.4, 0.03, half_length * 2.0 - 1.0), neon, false, false)
	# Scheinwerfer und Rücklichter
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (half_width - 0.25), 0.66, -half_length - 0.01), Vector3(0.34, 0.11, 0.04), head, false, false)
	b.finish()
	var tail := SlumBuilder.new(self)
	for side: float in [-1.0, 1.0]:
		tail.box(Vector3(side * (half_width - 0.24), 0.7, half_length + 0.01), Vector3(0.36, 0.1, 0.04), _tail_mat, false, false)
	tail.finish()
	_build_wheels()
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visibility_range_end = 160.0
	headlight = SpotLight3D.new()
	headlight.position = Vector3(0, 0.7, -half_length - 0.1)
	headlight.rotation.x = deg_to_rad(-8.0)
	headlight.spot_range = 22.0
	headlight.spot_angle = 34.0
	headlight.spot_attenuation = 0.9
	headlight.light_energy = 3.0
	headlight.light_color = Color(0.85, 0.92, 1.0)
	headlight.shadow_enabled = false
	headlight.distance_fade_enabled = true
	headlight.distance_fade_begin = 60.0
	headlight.distance_fade_length = 12.0
	add_child(headlight)


## Jedes Frame vom Auto: Räder drehen, Bremslicht.
func update(speed: float, delta: float, braking: bool) -> void:
	_spin = fmod(_spin + speed * delta / _wheel_radius, TAU)
	for w: Node3D in _wheels:
		w.rotation.x = -_spin
	_tail_mat.emission_energy_multiplier = 5.0 if braking else 1.4


func _compact(b: SlumBuilder, paint: Material, glass: Material) -> void:
	half_length = 1.9
	half_width = 0.86
	height = 1.5
	b.box(Vector3(0, 0.62, 0), Vector3(1.72, 0.55, 3.8), paint, false)
	b.box(Vector3(0, 1.17, 0.35), Vector3(1.56, 0.55, 2.2), paint, false)
	# Scheiben rundherum, Frontscheibe schräg
	b.box_x(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-35.0)), Vector3(0, 1.12, -0.86)), Vector3(1.5, 0.62, 0.05), glass, false)
	b.box(Vector3(0, 1.2, 1.46), Vector3(1.44, 0.4, 0.04), glass, false)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 0.785, 1.2, 0.35), Vector3(0.02, 0.38, 1.9), glass, false)
	_wheel_radius = 0.3


func _sedan(b: SlumBuilder, paint: Material, glass: Material, neon: Material) -> void:
	half_length = 2.35
	half_width = 0.94
	height = 1.35
	b.box(Vector3(0, 0.6, 0), Vector3(1.88, 0.5, 4.7), paint, false)
	b.box(Vector3(0, 1.06, 0.35), Vector3(1.62, 0.44, 2.1), paint, false)
	b.box_x(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-55.0)), Vector3(0, 1.02, -0.85)), Vector3(1.56, 0.62, 0.05), glass, false)
	b.box_x(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(50.0)), Vector3(0, 1.02, 1.55)), Vector3(1.56, 0.5, 0.05), glass, false)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 0.815, 1.08, 0.35), Vector3(0.02, 0.32, 1.9), glass, false)
	# Lichtleiste vorn und hinten
	b.box(Vector3(0, 0.78, -2.36), Vector3(1.5, 0.03, 0.03), neon, false, false)
	b.box(Vector3(0, 0.84, 2.36), Vector3(1.1, 0.03, 0.03), neon, false, false)
	# Spoiler
	b.box(Vector3(0, 0.98, 2.2), Vector3(1.7, 0.05, 0.3), paint, false)


func _van(b: SlumBuilder, paint: Material, glass: Material, neon: Material) -> void:
	half_length = 2.5
	half_width = 1.0
	height = 2.25
	b.box(Vector3(0, 1.3, 0.25), Vector3(2.0, 1.85, 4.5), paint, false)
	b.box(Vector3(0, 0.75, -2.2), Vector3(2.0, 0.75, 0.6), paint, false)
	b.box_x(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-20.0)), Vector3(0, 1.6, -2.03)), Vector3(1.8, 0.8, 0.05), glass, false)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 1.005, 1.6, -1.45), Vector3(0.02, 0.55, 0.8), glass, false)
		# Leuchtstreifen und „Firmenschild“ an der Seite
		b.box(Vector3(side * 1.01, 1.0, 0.6), Vector3(0.02, 0.06, 3.2), neon, false, false)
		b.box(Vector3(side * 1.01, 1.7, 0.8), Vector3(0.02, 0.6, 1.6), SlumMats.color(Color(0.9, 0.9, 0.85), 0.0, 0.6), false, false)
	b.box(Vector3(0, 2.26, 0.6), Vector3(0.9, 0.12, 1.0), SlumMats.color(Color(0.3, 0.3, 0.32), 0.0, 0.6, 0.5), false)


func _pickup(b: SlumBuilder, paint: Material, glass: Material, dark: Material) -> void:
	half_length = 2.5
	half_width = 0.96
	height = 1.75
	b.box(Vector3(0, 0.68, 0), Vector3(1.92, 0.6, 5.0), paint, false)
	b.box(Vector3(0, 1.3, -0.45), Vector3(1.76, 0.65, 1.7), paint, false)
	b.box_x(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-30.0)), Vector3(0, 1.28, -1.33)), Vector3(1.66, 0.62, 0.05), glass, false)
	b.box(Vector3(0, 1.35, 0.42), Vector3(1.6, 0.42, 0.04), glass, false)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 0.885, 1.35, -0.45), Vector3(0.02, 0.4, 1.4), glass, false)
		b.box(Vector3(side * 0.9, 1.15, 1.45), Vector3(0.1, 0.35, 2.0), paint, false)
	b.box(Vector3(0, 1.15, 2.45), Vector3(1.8, 0.35, 0.1), paint, false)
	# Überrollbügel mit Lampen
	b.box(Vector3(0, 1.75, 0.55), Vector3(1.7, 0.08, 0.08), dark, false)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 0.82, 1.4, 0.55), Vector3(0.08, 0.7, 0.08), dark, false)
	for x: float in [-0.6, -0.2, 0.2, 0.6]:
		b.box(Vector3(x, 1.84, 0.55), Vector3(0.18, 0.12, 0.1), SlumMats.color(Color(1.0, 0.9, 0.6), 3.0), false, false)
	b.box(Vector3(0, 1.05, 1.4), Vector3(1.0, 0.4, 0.8), SlumMats.uv("crate_wood"), false)


func _build_wheels() -> void:
	if _wheel_mesh == null:
		_wheel_mesh = CylinderMesh.new()
		_wheel_mesh.top_radius = 1.0
		_wheel_mesh.bottom_radius = 1.0
		_wheel_mesh.height = 1.0
		_wheel_mesh.radial_segments = 8
		_wheel_mesh.rings = 1
		_wheel_mat = SlumMats.color(Color(0.05, 0.05, 0.05), 0.0, 0.8)
	var r := _wheel_radius
	for side: float in [-1.0, 1.0]:
		for z: float in [-half_length + 0.8, half_length - 0.8]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * (half_width - 0.12), r, z)
			add_child(pivot)
			var mi := MeshInstance3D.new()
			mi.mesh = _wheel_mesh
			mi.material_override = _wheel_mat
			mi.rotation.z = PI * 0.5
			mi.scale = Vector3(r, 0.24, r)
			mi.visibility_range_end = 90.0
			pivot.add_child(mi)
			_wheels.append(pivot)
