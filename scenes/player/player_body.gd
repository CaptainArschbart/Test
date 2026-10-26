class_name PlayerBody
extends Node3D
## Körper der Spielfigur im selben Cyberpunk-Look wie die Ego-Hände.
##
## Aufbau aus Grundformen (ProcMesh): Stiefel mit Neon-Sohle, Hose mit Knieschützern,
## Gürtel, Jacke mit Brustplatte und Schulterpanzern, Arme mit Handschuhen, Kopf mit
## Kapuze und Leuchtvisier. Füße stehen auf y = 0, Blick nach -Z.
##
## Ego-Sicht: Beine und Stiefel sieht man beim Runterschauen, Becken, Oberkörper, Arme und Kopf
## werfen nur Schatten (sonst steckt die Kamera im Kopf). first_person = false zeigt alles,
## etwa für eine spätere Dritte-Person-Ansicht.
##
## Die Beine laufen mit der Geschwindigkeit des Players, die Arme schwingen gegengleich,
## in der Luft werden die Knie angezogen. Ohne Player darüber bleibt die Grundhaltung.

@export var first_person := true:
	set(value):
		first_person = value
		_update_visibility()
## Schrittlänge: wie viele Schrittzyklen pro Meter.
@export var stride_rate := 1.45
@export var leg_swing_degrees := 32.0
@export var arm_swing_degrees := 22.0
## In der Ego-Sicht rutschen die Beine so weit nach hinten, damit man beim Runterschauen
## an den Oberschenkeln vorbei auf Knie und Stiefel sieht.
@export var first_person_leg_offset := 0.16

@export_group("Materialien")
@export var jacket_material: Material
@export var pants_material: Material
@export var armor_material: Material
@export var glove_material: Material
@export var skin_material: Material
@export var neon_material: Material
@export var visor_material: Material

var _player: CharacterBody3D
var _phase := 0.0
var _swing := 0.0
var _air := 0.0
var _upper_parts: Array[GeometryInstance3D] = []
var _legs: Array[Dictionary] = []
var _arms: Array[Dictionary] = []
var _spine: Node3D
var _hips: Node3D


func _ready() -> void:
	_build()
	_update_visibility()
	var node := get_parent()
	while node != null and not node is CharacterBody3D:
		node = node.get_parent()
	_player = node as CharacterBody3D


func _process(delta: float) -> void:
	var speed := 0.0
	var on_floor := true
	if _player != null:
		speed = Vector2(_player.velocity.x, _player.velocity.z).length()
		on_floor = _player.is_on_floor()
	animate(delta, speed, on_floor)


## Lauf-, Steh- und Sprunghaltung. `speed` in Metern pro Sekunde.
func animate(delta: float, speed: float, on_floor: bool) -> void:
	var target_swing := clampf(speed / 5.0, 0.0, 1.4) if on_floor else 0.0
	_swing = lerpf(_swing, target_swing, minf(8.0 * delta, 1.0))
	_air = lerpf(_air, 0.0 if on_floor else 1.0, minf(6.0 * delta, 1.0))
	_phase = fmod(_phase + delta * speed * stride_rate * PI, TAU)
	var leg := deg_to_rad(leg_swing_degrees) * _swing
	var arm := deg_to_rad(arm_swing_degrees) * _swing
	for i in _legs.size():
		var side := 1.0 if i == 0 else -1.0
		var s := sin(_phase) * side
		var hip: Node3D = _legs[i].hip
		var knee: Node3D = _legs[i].knee
		var ankle: Node3D = _legs[i].ankle
		hip.rotation.x = s * leg - _air * 0.55
		# Das Knie knickt nur, wenn das Bein nach hinten schwingt und wieder vorkommt.
		knee.rotation.x = maxf(0.0, -cos(_phase) * side) * leg * 1.6 + _air * 1.0 + 0.04
		ankle.rotation.x = -hip.rotation.x * 0.3 - knee.rotation.x * 0.35
	for i in _arms.size():
		var side := 1.0 if i == 0 else -1.0
		var shoulder: Node3D = _arms[i].shoulder
		var elbow: Node3D = _arms[i].elbow
		shoulder.rotation.x = -sin(_phase) * side * arm + _air * 0.4
		shoulder.rotation.z = (0.09 + _air * 0.25) * side
		elbow.rotation.x = 0.25 + _swing * 0.35
	var breath := sin(Time.get_ticks_msec() * 0.0013) * 0.012
	_spine.rotation.x = -0.04 * _swing + breath
	_spine.position.y = 0.075 + absf(sin(_phase)) * 0.015 * _swing


func _update_visibility() -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if first_person \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for part in _upper_parts:
		part.cast_shadow = mode
	if _hips != null:
		_hips.position.z = first_person_leg_offset if first_person else 0.0


func _build() -> void:
	_ensure_materials()
	var hips := Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0.0, 0.95, 0.0)
	add_child(hips)
	_hips = hips
	# Becken und Gürtel mit Schnalle. Gehört zum Oberkörper: von oben würde es die Beine verdecken.
	var pelvis := [
		_part(hips, ProcMesh.rounded_box(Vector3(0.34, 0.2, 0.21), 0.4), pants_material,
			Vector3(0.0, 0.0, 0.0)),
		_part(hips, ProcMesh.rounded_box(Vector3(0.355, 0.05, 0.225), 0.25), armor_material,
			Vector3(0.0, 0.08, 0.0)),
		_part(hips, ProcMesh.rounded_box(Vector3(0.06, 0.04, 0.02), 0.3), neon_material,
			Vector3(0.0, 0.08, -0.112)),
	]
	for side in [1.0, -1.0]:
		_legs.append(_build_leg(hips, side))

	_spine = Node3D.new()
	_spine.name = "Spine"
	_spine.position = Vector3(0.0, 0.075, 0.0)
	hips.add_child(_spine)
	var upper := pelvis.duplicate()
	# Jacke: Bauch, Brust, Kragen; dazu Brustplatte und Leuchtstreifen.
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.33, 0.24, 0.2), 0.45), jacket_material,
		Vector3(0.0, 0.14, 0.0)))
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.44, 0.3, 0.24), 0.4), jacket_material,
		Vector3(0.0, 0.38, 0.0)))
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.3, 0.2, 0.05), 0.3), armor_material,
		Vector3(0.0, 0.38, -0.115), Vector3(0.08, 0.0, 0.0)))
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.012, 0.16, 0.012), 0.5), neon_material,
		Vector3(0.09, 0.37, -0.142)))
	upper.append(_part(_spine, ProcMesh.rounded_box(Vector3(0.012, 0.16, 0.012), 0.5), neon_material,
		Vector3(-0.09, 0.37, -0.142)))
	upper.append(_part(_spine, ProcMesh.tube(0.09, 0.12, 0.09), jacket_material,
		Vector3(0.0, 0.56, 0.01)))
	# Kopf: Hals, Kopf, Kapuze, Visier.
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.6, 0.0)
	_spine.add_child(head)
	upper.append(_part(head, ProcMesh.tube(0.05, 0.055, 0.1), skin_material, Vector3(0.0, 0.02, 0.0)))
	upper.append(_part(head, ProcMesh.rounded_box(Vector3(0.18, 0.23, 0.21), 0.6), skin_material,
		Vector3(0.0, 0.16, -0.01)))
	upper.append(_part(head, ProcMesh.rounded_box(Vector3(0.23, 0.27, 0.25), 0.62), jacket_material,
		Vector3(0.0, 0.18, 0.025)))
	upper.append(_part(head, ProcMesh.rounded_box(Vector3(0.19, 0.045, 0.06), 0.35), visor_material,
		Vector3(0.0, 0.18, -0.105)))
	for side in [1.0, -1.0]:
		var arm := _build_arm(_spine, side)
		_arms.append(arm)
		upper.append_array(arm.parts)
	for part in upper:
		_upper_parts.append(part)


func _build_leg(hips: Node3D, side: float) -> Dictionary:
	var hip := Node3D.new()
	hip.position = Vector3(0.095 * side, -0.05, 0.0)
	hips.add_child(hip)
	_part(hip, ProcMesh.capsule(0.078, 0.48), pants_material, Vector3(0.0, -0.21, 0.0))
	# Oberschenkeltasche rechts.
	if side > 0.0:
		_part(hip, ProcMesh.rounded_box(Vector3(0.05, 0.12, 0.1), 0.35), armor_material,
			Vector3(0.075, -0.2, 0.0))
	var knee := Node3D.new()
	knee.position = Vector3(0.0, -0.43, 0.0)
	hip.add_child(knee)
	_part(knee, ProcMesh.capsule(0.062, 0.46), pants_material, Vector3(0.0, -0.2, 0.0))
	_part(knee, ProcMesh.rounded_box(Vector3(0.1, 0.11, 0.05), 0.35), armor_material,
		Vector3(0.0, -0.03, -0.055))
	_part(knee, ProcMesh.rounded_box(Vector3(0.05, 0.012, 0.012), 0.5), neon_material,
		Vector3(0.0, -0.03, -0.082))
	var ankle := Node3D.new()
	ankle.position = Vector3(0.0, -0.42, 0.0)
	knee.add_child(ankle)
	# Stiefel mit Schaft, Kappe und leuchtender Sohlenkante.
	_part(ankle, ProcMesh.tube(0.068, 0.072, 0.13), armor_material, Vector3(0.0, 0.03, 0.0))
	_part(ankle, ProcMesh.rounded_box(Vector3(0.12, 0.09, 0.27), 0.35), armor_material,
		Vector3(0.0, -0.045, -0.05))
	_part(ankle, ProcMesh.rounded_box(Vector3(0.125, 0.018, 0.275), 0.3), neon_material,
		Vector3(0.0, -0.085, -0.05))
	return {"hip": hip, "knee": knee, "ankle": ankle}


func _build_arm(spine: Node3D, side: float) -> Dictionary:
	var parts := []
	var shoulder := Node3D.new()
	shoulder.position = Vector3(0.25 * side, 0.48, 0.0)
	spine.add_child(shoulder)
	parts.append(_part(shoulder, ProcMesh.rounded_box(Vector3(0.14, 0.08, 0.15), 0.45), armor_material,
		Vector3(0.015 * side, 0.03, 0.0), Vector3(0.0, 0.0, -0.25 * side)))
	parts.append(_part(shoulder, ProcMesh.capsule(0.058, 0.33), jacket_material, Vector3(0.0, -0.14, 0.0)))
	var elbow := Node3D.new()
	elbow.position = Vector3(0.0, -0.29, 0.0)
	shoulder.add_child(elbow)
	parts.append(_part(elbow, ProcMesh.capsule(0.05, 0.3), jacket_material, Vector3(0.0, -0.13, 0.0)))
	parts.append(_part(elbow, ProcMesh.tube(0.042, 0.042, 0.05), armor_material, Vector3(0.0, -0.25, 0.0)))
	parts.append(_part(elbow, ProcMesh.tube(0.044, 0.044, 0.006), neon_material, Vector3(0.0, -0.235, 0.0)))
	parts.append(_part(elbow, ProcMesh.rounded_box(Vector3(0.05, 0.1, 0.085), 0.45), glove_material,
		Vector3(0.0, -0.33, -0.005)))
	return {"shoulder": shoulder, "elbow": elbow, "parts": parts}


func _part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


func _ensure_materials() -> void:
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.1, 0.1, 0.12)
	for property in ["jacket_material", "pants_material", "armor_material", "glove_material",
			"skin_material", "neon_material", "visor_material"]:
		if get(property) == null:
			set(property, fallback)
