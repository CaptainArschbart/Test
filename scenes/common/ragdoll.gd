class_name Ragdoll
extends SkeletonModifier3D
## Ragdoll für die Modular-Men-Figuren (Schedule 1, Phase 5, P5-1 bis P5-5).
##
## Warum kein PhysicalBoneSimulator3D: Das Skelett der Figuren hängt an einem 100-fach skalierten
## Armature-Knoten, und die Füße sind IK-Knochen am Root statt am Unterschenkel. Physikkörper in
## einem skalierten Raum verhalten sich in Godot falsch. Deshalb liegen hier 11 eigene RigidBody3D
## in Metern (top_level, ohne die Skalierung), verbunden mit Gelenken, und dieser Modifier stellt
## danach in jedem Skelett-Update die Knochen auf die Lage der Körper (set_bone_global_pose).
##
## Teile (PARTS): Becken, Brust, Kopf, je Seite Ober- und Unterarm, Ober- und Unterschenkel.
## Mitläufer-Knochen (Bauch, Schultern, Hände, Füße) folgen ihrem Teil starr.
## Gelenke: Kegel (Hals, Schultern, Hüften, Wirbelsäule), Scharniere für Knie und Ellbogen mit
## Grenzen in der natürlichen Richtung.
##
## Schichten: Physik-Schicht 4 „ragdoll“. Die Teile stoßen nur an die Welt (Schicht 1), nicht
## aneinander (sie überlappen am Start, z. B. Hände am Becken, das würde sie auseinandersprengen),
## nicht an Spieler und NPCs (deren Kapseln prüfen Schicht 4 nicht) und nicht an Schüsse (Strahlen
## prüfen 1 und 2). Leichen sind keine statischen Körper, das Navmesh bleibt frei.
## Alle Teile haben CCD, vor allem Becken und Kopf (gehen nicht durch Wände).
##
## Budget (P5-5): höchstens MAX_ACTIVE Ragdolls rechnen gleichzeitig, beim nächsten friert der älteste
## ein. Nach SLEEP_AFTER Sekunden friert jeder ein (Lage bleibt). Weiter als FAR_DISTANCE von der
## Kamera gibt start() false zurück: dann spielt die Figur ihre Todesanimation.
##
## Ablauf: start(impuls, trefferpunkt, geschwindigkeit) beim Tod oder Umwerfen; rested meldet,
## wenn die Figur liegt (unter REST_SPEED für REST_TIME). blend_out(zeit) blendet zurück zur
## Animation (Aufstehen, bis es die UAL2-Animation gibt) und baut die Körper ab.

## Die Figur liegt still (lebt sie noch, kann sie jetzt aufstehen).
signal rested

const LAYER := 1 << 3
const MAX_ACTIVE := 8
const FAR_DISTANCE := 40.0
const SLEEP_AFTER := 30.0
const REST_SPEED := 0.2
const REST_TIME := 0.5
## Obergrenze für den Stoß (N·s). Stärkere Stöße auf ein leichtes Teil sprengen die Gelenke.
const MAX_IMPULSE := 70.0

## Teil: Name, Startknochen, Endknochen ("" = Länge entlang des Knochens), Radius, Masse,
## Verlängerung über den Endknochen hinaus (Hand, Fuß, Schädel), Mitläufer-Knochen.
const PARTS := [
	["pelvis", "Hips", "Torso", 0.13, 12.0, 0.0, ["Abdomen"]],
	["chest", "Torso", "Neck", 0.15, 14.0, 0.0, ["Chest", "Shoulder.L", "Shoulder.R"]],
	["head", "Neck", "", 0.11, 5.0, 0.3, ["Head"]],
	["upper_arm_l", "UpperArm.L", "LowerArm.L", 0.05, 2.5, 0.0, []],
	["lower_arm_l", "LowerArm.L", "Wrist.L", 0.045, 2.0, 0.09, ["Wrist.L"]],
	["upper_arm_r", "UpperArm.R", "LowerArm.R", 0.05, 2.5, 0.0, []],
	["lower_arm_r", "LowerArm.R", "Wrist.R", 0.045, 2.0, 0.09, ["Wrist.R"]],
	["upper_leg_l", "UpperLeg.L", "LowerLeg.L", 0.075, 7.0, 0.0, []],
	["lower_leg_l", "LowerLeg.L", "Foot.L", 0.06, 4.0, 0.06, ["Foot.L"]],
	["upper_leg_r", "UpperLeg.R", "LowerLeg.R", 0.075, 7.0, 0.0, []],
	["lower_leg_r", "LowerLeg.R", "Foot.R", 0.06, 4.0, 0.06, ["Foot.R"]],
]
## Gelenk: Elternteil, Kindteil, Art ("cone": Schwenk, Drehung in Grad; "knee"/"elbow": Beugung bis).
const JOINTS := [
	["pelvis", "chest", "cone", 30.0, 20.0],
	["chest", "head", "cone", 40.0, 40.0],
	["chest", "upper_arm_l", "cone", 80.0, 40.0],
	["chest", "upper_arm_r", "cone", 80.0, 40.0],
	["upper_arm_l", "lower_arm_l", "elbow", 140.0, 0.0],
	["upper_arm_r", "lower_arm_r", "elbow", 140.0, 0.0],
	["pelvis", "upper_leg_l", "cone", 60.0, 20.0],
	["pelvis", "upper_leg_r", "cone", 60.0, 20.0],
	["upper_leg_l", "lower_leg_l", "knee", 140.0, 0.0],
	["upper_leg_r", "lower_leg_r", "knee", 140.0, 0.0],
]

static var _active: Array[Ragdoll] = []

## Körper je Teilname (nur während der Ragdoll läuft).
var bodies := {}
## Sekunden seit dem Start.
var time := 0.0
## Läuft gerade (Körper existieren, Knochen folgen ihnen).
var running := false
## Eingefroren (Budget oder SLEEP_AFTER): Lage bleibt, keine Physik mehr.
var frozen := false

## [Knochen-Index, Körper, Versatz Körper → Knochen] in Reihenfolge der Knochen (Eltern zuerst).
var _drive: Array = []
var _joints: Array[Joint3D] = []
var _calm := 0.0
var _rested_sent := false
var _blend: Tween


## Hängt einen Ragdoll an das Skelett (noch ohne Körper, die entstehen erst bei start()).
static func attach(skeleton: Skeleton3D) -> Ragdoll:
	var r := Ragdoll.new()
	r.name = "Ragdoll"
	r.active = false
	skeleton.add_child(r)
	return r


## Schaltet auf Physik. `impulse` (N·s) wirkt am Teil nächst `at`, alle Teile starten mit `velocity`.
## Gibt false zurück, wenn die Figur zu weit von der Kamera weg ist (dann Animation spielen).
func start(impulse := Vector3.ZERO, at := Vector3.INF, velocity := Vector3.ZERO) -> bool:
	var skeleton := get_skeleton()
	if skeleton == null or not is_inside_tree():
		return false
	if running:
		_push(impulse, at)
		return true
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.global_position.distance_to(skeleton.global_position) > FAR_DISTANCE:
		return false
	if _blend != null:
		_blend.kill()
	if not _build(skeleton):
		return false
	for b: RigidBody3D in bodies.values():
		b.linear_velocity = velocity
	_push(impulse, at)
	running = true
	frozen = false
	time = 0.0
	_calm = 0.0
	_rested_sent = false
	influence = 1.0
	active = true
	_active.append(self)
	# Budget: der älteste aktive friert ein.
	while _active.size() > MAX_ACTIVE:
		var old: Ragdoll = _active.pop_front()
		if is_instance_valid(old):
			old.freeze()
	return true


## Umfallen in `direction` (waagerecht genommen), Stärke aus dem Schaden des letzten Treffers,
## Impuls am Teil nächst `point` (INF = Brust). Gibt false zurück, wenn kein Ragdoll möglich ist.
func knock_down(direction: Vector3, damage: float, point: Vector3, velocity: Vector3) -> bool:
	var dir := Vector3(direction.x, 0.0, direction.z)
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	var strength := clampf(damage * 1.2, 25.0, MAX_IMPULSE)
	return start((dir.normalized() + Vector3.UP * 0.15) * strength, point, velocity)


## Lage behalten, keine Physik mehr (Leiche bleibt so liegen).
func freeze() -> void:
	frozen = true
	_active.erase(self)
	for b: RigidBody3D in bodies.values():
		b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		b.freeze = true
		b.collision_layer = 0


## Zurück zur Animation (Aufstehen): Einfluss in `seconds` auf 0, danach Körper abbauen.
func blend_out(seconds := 0.4) -> void:
	if not running:
		return
	freeze()
	if _blend != null:
		_blend.kill()
	_blend = create_tween()
	_blend.tween_property(self, "influence", 0.0, seconds)
	_blend.tween_callback(_teardown)


## Becken in Weltkoordinaten (für Aufstehen an der richtigen Stelle, Tests).
func pelvis_position() -> Vector3:
	var p: RigidBody3D = bodies.get("pelvis")
	return p.global_position if p != null else Vector3.INF


## Schnellster Teil (m/s).
func max_speed() -> float:
	var top := 0.0
	for b: RigidBody3D in bodies.values():
		top = maxf(top, b.linear_velocity.length())
	return top


func _exit_tree() -> void:
	_active.erase(self)


func _physics_process(delta: float) -> void:
	if not running or frozen:
		return
	time += delta
	_calm = _calm + delta if max_speed() < REST_SPEED else 0.0
	if _calm >= REST_TIME and not _rested_sent:
		_rested_sent = true
		rested.emit()
	if time >= SLEEP_AFTER:
		freeze()


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _drive.is_empty():
		return
	var to_skeleton := skeleton.global_transform.affine_inverse()
	for d: Array in _drive:
		var body: RigidBody3D = d[1]
		if is_instance_valid(body):
			skeleton.set_bone_global_pose(d[0], to_skeleton * body.global_transform * (d[2] as Transform3D))


## Halber Stoß als Tempo für den ganzen Körper, die andere Hälfte auf das getroffene Teil.
func _push(impulse: Vector3, at: Vector3) -> void:
	if impulse.is_zero_approx() or bodies.is_empty():
		return
	impulse = impulse.limit_length(MAX_IMPULSE)
	var total := 0.0
	for b: RigidBody3D in bodies.values():
		total += b.mass
	for b: RigidBody3D in bodies.values():
		b.linear_velocity += impulse * 0.5 / total
	var target: RigidBody3D = bodies["chest"]
	if at != Vector3.INF:
		var best := INF
		for b: RigidBody3D in bodies.values():
			var d := b.global_position.distance_to(at)
			if d < best:
				best = d
				target = b
	# Als Tempo statt apply_impulse: frisch angelegte Körper haben im Physikserver bis zum ersten
	# Schritt noch 1 kg, ein Impuls wäre 14-mal zu stark. Zentral, ein Hebel am Trefferpunkt
	# dreht das Teil so schnell, dass die Gelenke nachgeben.
	target.linear_velocity += impulse * 0.5 / target.mass


func _bone_world(skeleton: Skeleton3D, bone: int) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone)


func _build(skeleton: Skeleton3D) -> bool:
	_teardown()
	# Blickrichtung der Figur aus dem Becken-Knochen: Hüfte links − rechts ergibt die Seite.
	var left := skeleton.find_bone("UpperLeg.L")
	var right := skeleton.find_bone("UpperLeg.R")
	if left < 0 or right < 0:
		return false
	var side := (_bone_world(skeleton, left).origin - _bone_world(skeleton, right).origin)
	side.y = 0.0
	# Die Figuren schauen nach +Z ihres Skeletts; links ist dort +X (Blender: .L = +X).
	var char_right := -side.normalized() if side.length() > 0.01 else skeleton.global_basis.x.normalized()
	var drives := {}
	for p: Array in PARTS:
		var bone := skeleton.find_bone(p[1])
		if bone < 0:
			_teardown()
			return false
		var start := _bone_world(skeleton, bone)
		var a := start.origin
		var b := a
		var end_bone := skeleton.find_bone(p[2]) if p[2] != "" else -1
		if end_bone >= 0:
			b = _bone_world(skeleton, end_bone).origin
		var dir := (b - a).normalized() if a.distance_to(b) > 0.01 else start.basis.y.normalized()
		b += dir * float(p[5])
		var body := _make_body(p[0], a, b, float(p[3]), float(p[4]), char_right)
		bodies[p[0]] = body
		drives[bone] = body
		for follower: String in p[6]:
			var f := skeleton.find_bone(follower)
			if f >= 0:
				drives[f] = body
	# Versatz Körper → Knochen jetzt festhalten (Pose zum Zeitpunkt des Starts).
	var order := drives.keys()
	order.sort()
	for bone: int in order:
		var body: RigidBody3D = drives[bone]
		_drive.append([bone, body, body.global_transform.affine_inverse() * _bone_world(skeleton, bone)])
	for j: Array in JOINTS:
		_make_joint(bodies[j[0]], bodies[j[1]], j[2], float(j[3]), float(j[4]), char_right)
	return true


func _make_body(part: String, a: Vector3, b: Vector3, radius: float, mass: float, char_right: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "Rag_" + part
	body.top_level = true
	body.mass = mass
	body.collision_layer = LAYER
	body.collision_mask = 1
	body.linear_damp = 0.1
	body.angular_damp = 1.5
	var mat := PhysicsMaterial.new()
	mat.friction = 0.9
	mat.bounce = 0.05
	body.physics_material_override = mat
	body.continuous_cd = true
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	# Kapselspitzen genau auf Start- und Endpunkt (die Füße starten nicht im Boden).
	capsule.height = maxf(a.distance_to(b), radius * 2.0 + 0.01)
	shape.shape = capsule
	body.add_child(shape)
	add_child(body)
	# Kapsel-Achse (Y) entlang des Teils, X so nah wie möglich an der rechten Seite der Figur.
	var y := (b - a).normalized() if a.distance_to(b) > 0.001 else Vector3.UP
	var x := (char_right - y * char_right.dot(y))
	if x.length() < 0.01:
		x = y.cross(Vector3.FORWARD)
	x = x.normalized()
	body.global_transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	return body


func _make_joint(a: RigidBody3D, b: RigidBody3D, kind: String, limit: float, twist: float, char_right: Vector3) -> void:
	# Drehpunkt: Anfang des Kindteils (dort sitzt sein Startknochen).
	var axis_b := b.global_basis.y
	var pivot := b.global_position - axis_b * (_length(b) * 0.5)
	var joint: Joint3D
	if kind == "cone":
		var cone := ConeTwistJoint3D.new()
		cone.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(limit))
		cone.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(twist))
		joint = cone
		# Drehachse (X des Gelenks) entlang des Kindteils.
		var x := axis_b.normalized()
		var y := x.cross(char_right)
		if y.length() < 0.01:
			y = x.cross(Vector3.FORWARD)
		y = y.normalized()
		joint.top_level = true
		add_child(joint)
		joint.global_transform = Transform3D(Basis(x, y, x.cross(y)), pivot)
	else:
		# Scharnier um Z des Gelenks. Eine positive Drehung um Z zählt in Godot als negativer
		# Gelenkwinkel: Beugung in natürlicher Richtung = unteres Limit.
		var hinge := HingeJoint3D.new()
		var h := (-char_right if kind == "knee" else char_right).normalized()
		var up := a.global_basis.y
		var low := b.global_basis.y
		# Wie weit das Gelenk beim Start schon gebeugt ist (um h, positiv = natürlich).
		var bent := atan2(up.cross(low).dot(h), up.dot(low))
		hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -maxf(deg_to_rad(limit) - bent, 0.05))
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, maxf(bent + deg_to_rad(5.0), 0.05))
		joint = hinge
		var z := h
		var x := up - z * up.dot(z)
		if x.length() < 0.01:
			x = z.cross(Vector3.UP)
		x = x.normalized()
		joint.top_level = true
		add_child(joint)
		joint.global_transform = Transform3D(Basis(x, z.cross(x), z), pivot)
	joint.name = "Joint_%s_%s" % [a.name, b.name]
	joint.node_a = joint.get_path_to(a)
	joint.node_b = joint.get_path_to(b)
	joint.exclude_nodes_from_collision = true
	_joints.append(joint)


func _length(body: RigidBody3D) -> float:
	var shape := body.get_child(0) as CollisionShape3D
	var capsule := shape.shape as CapsuleShape3D
	return capsule.height


func _teardown() -> void:
	_active.erase(self)
	for j in _joints:
		if is_instance_valid(j):
			j.queue_free()
	_joints.clear()
	for b: RigidBody3D in bodies.values():
		if is_instance_valid(b):
			b.queue_free()
	bodies.clear()
	_drive.clear()
	running = false
	frozen = false
	active = false
	influence = 1.0
