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
## Mitläufer-Knochen (Bauch, Schultern, Hände, Füße) folgen ihrem Teil starr. Auch Body und Root folgen
## dem Becken: An Body hängen bei jeder MM-Figur 600 bis 950 Hautpunkte (Hosenbund, Jackensaum), bei
## Punk 134 an Root; blieben sie stehen, zöge sich die Haut vom Liegenden bis in Standhöhe.
## Gelenke: Kegel (Hals, Schultern, Hüften, Wirbelsäule), Scharniere für Knie und Ellbogen mit
## Grenzen in der natürlichen Richtung.
##
## Schichten: Physik-Schicht 4 „ragdoll“. Die Teile stoßen nur an Schicht 1, nicht
## aneinander (sie überlappen am Start, z. B. Hände am Becken, das würde sie auseinandersprengen),
## nicht an Spieler (Schicht 2) und nicht an Schüsse (Strahlen prüfen 1 und 2). NPC-Kapseln liegen
## auf Schicht 1: fremde schieben Leichen weg, die eigene ist per Ausnahme ausgenommen. Leichen sind keine statischen Körper, das Navmesh bleibt frei.
## Alle Teile haben CCD, vor allem Becken und Kopf (gehen nicht durch Wände).
##
## Budget (P5-5): höchstens MAX_ACTIVE Ragdolls rechnen gleichzeitig, beim nächsten friert der älteste
## ein. Nach SLEEP_AFTER Sekunden friert jeder ein (Lage bleibt). Weiter als FAR_DISTANCE von der
## Kamera gibt start() false zurück: dann spielt die Figur ihre Todesanimation.
##
## Ablauf: start(impuls, trefferpunkt, geschwindigkeit) beim Tod oder Umwerfen; rested meldet,
## wenn die Figur liegt (unter REST_SPEED für REST_TIME). Aufstehen (EnemyModel._ragdoll_rise):
## roll_over() dreht aus Bauch- oder Seitenlage auf den Rücken, rise_into_pose() fährt die Teile mit
## Physik in das erste Bild von UAL2 LayToIdle und blendet dann aus (blend_out), die Körper verschwinden.
## Hände und Füße haben eigene Kapseln an Unterarm und Unterschenkel (EXTRA).

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
## Umdrehen aus der Bauchlage: so lange (s) dauert eine halbe Drehung um die Längsachse.
const ROLL_TIME := 0.6
## Aufstehen: Höchsttempo (m/s, rad/s), mit dem die Teile in die Zielpose fahren.
const MATCH_MAX_SPEED := 6.0
const MATCH_MAX_SPIN := 14.0

## Teil: Name, Startknochen, Endknochen ("" = Länge entlang des Knochens), Radius, Masse,
## Verlängerung über den Endknochen hinaus (Hand, Fuß, Schädel), Mitläufer-Knochen.
const PARTS := [
	["pelvis", "Hips", "Torso", 0.13, 12.0, 0.0, ["Abdomen", "Body", "Root"]],
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
## Zusatzkapseln für Hand und Fuß: Sie stehen quer zu Unterarm bzw. Unterschenkel (Finger, Schuh) und
## lägen ohne eigene Form im Boden. Gleicher Körper, also kein Gelenk und keine Kosten für die Physik.
## [Teil, Knochen, Spitzenknochen ("" = Fuß entlang seiner Y-Achse), Radius]
const EXTRA := [
	["lower_arm_l", "Wrist.L", "Middle4.L", 0.035],
	["lower_arm_r", "Wrist.R", "Middle4.R", 0.035],
	["lower_leg_l", "Foot.L", "", 0.05],
	["lower_leg_r", "Foot.R", "", 0.05],
]
## Fuß: Ferse hinter und Spitze vor dem Fußknochen, Mitte so weit über der Sohle (Meter).
const FOOT_BACK := 0.03
const FOOT_FRONT := 0.17
const FOOT_LIFT := 0.045
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
## Startknochen je Körper (für rise_into_pose).
var _start_bone := {}
var _joints: Array[Joint3D] = []
var _calm := 0.0
var _rested_sent := false
var _blend: Tween
var _roll_t := -1.0
var _roll_axis := Vector3.FORWARD
var _roll_pivot := Vector3.ZERO
var _roll_start := {}
var _roll_floor := 0.0
var _roll_angle := PI
var _roll_duration := 0.6
## Aufstehen: Zielpose je Körper (Welt), Zeit, Überblendung danach.
var _match := {}
var _match_t := -1.0
var _match_time := 0.0
var _match_blend := 0.0


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


## Die Figur, zu der das Skelett gehört (erster PhysicsBody3D darüber), oder null.
func host_body() -> PhysicsBody3D:
	var node: Node = get_parent()
	while node != null and not node is PhysicsBody3D:
		node = node.get_parent()
	return node as PhysicsBody3D


## Knochen in Weltkoordinaten, so wie der Ragdoll ihn gerade stellt (INF, wenn er nicht mitläuft).
func bone_position(bone: int) -> Vector3:
	for d: Array in _drive:
		if d[0] == bone and is_instance_valid(d[1]):
			return ((d[1] as RigidBody3D).global_transform * (d[2] as Transform3D)).origin
	return Vector3.INF


## Mitte eines Teils in Weltkoordinaten ("pelvis", "head", ...), INF wenn es fehlt.
func part_position(part: String) -> Vector3:
	var p: RigidBody3D = bodies.get(part)
	return p.global_position if p != null else Vector3.INF


## Wie weit die Brust nach oben zeigt: 1 = Rückenlage (Gesicht oben), -1 = Bauchlage.
func facing_up() -> float:
	return _front().y


## Vorderseite der Brust (Welt, Länge 1); ohne Körper nach oben.
func _front() -> Vector3:
	var chest: RigidBody3D = bodies.get("chest")
	if chest == null:
		return Vector3.UP
	# Teil-Basis: X = rechte Seite der Figur, Y = Becken -> Hals. Vorn = Y x X.
	return chest.global_basis.y.cross(chest.global_basis.x).normalized()


## Bauch- oder Seitenlage: Körper um die Längsachse auf den Rücken drehen (vor dem Aufstehen). Physik
## allein dreht nicht verlässlich (Arme und Reibung halten fest); deshalb werden die Teile als
## kinematische Körper um die Achse Becken -> Kopf gedreht, genau so weit, dass die Brust nach oben
## zeigt, und dabei so angehoben, dass kein Teil unter den Boden kommt. Dauer: ROLL_TIME für eine halbe
## Drehung. Danach wieder Physik, rested kommt erneut. Eingefroren oder schon auf dem Rücken: false.
func roll_over() -> bool:
	if not running or frozen or _roll_t >= 0.0:
		return false
	var pelvis := part_position("pelvis")
	var head := part_position("head")
	var axis := Vector3(head.x - pelvis.x, 0.0, head.z - pelvis.z)
	_roll_axis = axis.normalized() if axis.length() > 0.05 else Vector3.FORWARD
	# Winkel um die Achse, der die Brust (senkrecht zur Achse genommen) nach oben dreht.
	var front := _front()
	front -= _roll_axis * front.dot(_roll_axis)
	if front.length() < 0.05:
		return false
	front = front.normalized()
	_roll_angle = atan2(_roll_axis.dot(front.cross(Vector3.UP)), front.dot(Vector3.UP))
	if absf(_roll_angle) < deg_to_rad(20.0):
		return false
	_roll_duration = maxf(ROLL_TIME * absf(_roll_angle) / PI, 0.2)
	_roll_pivot = Vector3.ZERO
	_roll_start.clear()
	for b: RigidBody3D in bodies.values():
		_roll_pivot += b.global_position / bodies.size()
		_roll_start[b] = b.global_transform
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO
		b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		b.freeze = true
	_roll_floor = _lowest_point()
	_roll_t = 0.0
	_calm = 0.0
	_rested_sent = false
	time = minf(time, SLEEP_AFTER - 5.0)
	return true


## Aufstehen ohne Durchdringen: Die Teile fahren `seconds` lang mit Physik (Boden hält sie auf) in die
## Pose, die das Skelett gerade aus der Animation hat (erstes Bild der Aufsteh-Animation), danach blendet
## der Ragdoll in `blend` Sekunden aus. Eine direkte Überblendung von Ragdoll zu Animation dreht die
## Knochen einzeln und zieht Arme und Beine dabei durch den Boden.
func rise_into_pose(seconds: float, blend: float) -> void:
	var skeleton := get_skeleton()
	if not running or skeleton == null:
		return
	_match.clear()
	for d: Array in _drive:
		var body: RigidBody3D = d[1]
		# Ziel aus dem Startknochen des Körpers (Mitläufer wie Root bewegen sich in der Animation anders).
		if not is_instance_valid(body) or _start_bone.get(body, -1) != d[0]:
			continue
		var bone_world := skeleton.global_transform * skeleton.get_bone_global_pose(d[0])
		var target := bone_world * (d[2] as Transform3D).affine_inverse()
		_match[body] = Transform3D(target.basis.orthonormalized(), target.origin)
	if frozen:
		frozen = false
		for b: RigidBody3D in bodies.values():
			b.freeze = false
			b.collision_layer = LAYER
	_match_t = 0.0
	_match_time = maxf(seconds, 0.01)
	_match_blend = blend
	time = minf(time, SLEEP_AFTER - 5.0)


## Fährt gerade in die Zielpose (rise_into_pose); danach blendet er aus.
func is_matching() -> bool:
	return _match_t >= 0.0


## Läuft gerade das Umdrehen aus der Bauchlage.
func is_rolling() -> bool:
	return _roll_t >= 0.0


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
	if _roll_t >= 0.0:
		_roll_step(delta)
		return
	if _match_t >= 0.0:
		_match_step(delta)
		return
	_calm = _calm + delta if max_speed() < REST_SPEED else 0.0
	if _calm >= REST_TIME and not _rested_sent:
		_rested_sent = true
		rested.emit()
	if time >= SLEEP_AFTER:
		freeze()


func _match_step(delta: float) -> void:
	_match_t += delta
	if _match_t >= _match_time:
		_match_t = -1.0
		_match.clear()
		blend_out(_match_blend)
		return
	var left := maxf(_match_time - _match_t, delta)
	for b: RigidBody3D in _match:
		if not is_instance_valid(b):
			continue
		var target: Transform3D = _match[b]
		b.linear_velocity = ((target.origin - b.global_position) / left).limit_length(MATCH_MAX_SPEED)
		var q := target.basis.get_rotation_quaternion() * b.global_basis.orthonormalized().get_rotation_quaternion().inverse()
		if q.w < 0.0:
			q = -q
		var angle := q.get_angle()
		b.angular_velocity = q.get_axis().normalized() * minf(angle / left, MATCH_MAX_SPIN) if angle > 0.001 else Vector3.ZERO


func _roll_step(delta: float) -> void:
	_roll_t += delta
	var k := smoothstep(0.0, 1.0, minf(_roll_t / _roll_duration, 1.0))
	var turn := Transform3D(Basis(_roll_axis, _roll_angle * k), _roll_pivot) * Transform3D(Basis(), -_roll_pivot)
	for b: RigidBody3D in _roll_start:
		if is_instance_valid(b):
			b.global_transform = turn * (_roll_start[b] as Transform3D)
	var lift := _roll_floor - _lowest_point()
	if lift > 0.0:
		for b: RigidBody3D in _roll_start:
			if is_instance_valid(b):
				b.global_position += Vector3.UP * lift
	if _roll_t >= _roll_duration:
		_roll_t = -1.0
		for b: RigidBody3D in _roll_start:
			if is_instance_valid(b):
				b.freeze = false
		_roll_start.clear()
		_calm = 0.0


## Tiefster Punkt aller Kapseln (Welt-y), Hand- und Fußkapseln eingeschlossen.
func _lowest_point() -> float:
	var low := INF
	for b: RigidBody3D in bodies.values():
		for child in b.get_children():
			var cs := child as CollisionShape3D
			if cs == null or not cs.shape is CapsuleShape3D:
				continue
			var shape := cs.shape as CapsuleShape3D
			var xf := b.global_transform * cs.transform
			var half := maxf(shape.height * 0.5 - shape.radius, 0.0)
			low = minf(low, xf.origin.y - absf(xf.basis.y.normalized().y) * half - shape.radius)
	return low


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
		_start_bone[body] = bone
		for follower: String in p[6]:
			var f := skeleton.find_bone(follower)
			if f >= 0:
				drives[f] = body
	for e: Array in EXTRA:
		_add_extra(skeleton, bodies.get(e[0]), e[1], e[2], float(e[3]))
	# Die eigene Figur (CharacterBody3D, Schicht 1) steht noch da, wenn sie lebend umfällt: die Teile
	# starten in ihrer Kapsel und dürfen sie nicht stoßen.
	var host := host_body()
	if host != null:
		for b: RigidBody3D in bodies.values():
			b.add_collision_exception_with(host)
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


## Zweite Kapsel am Körper (Hand bzw. Fuß), aus der Pose beim Start.
func _add_extra(skeleton: Skeleton3D, body: RigidBody3D, bone_name: String, tip_name: String, radius: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if body == null or bone < 0:
		return
	var at := _bone_world(skeleton, bone)
	var a := at.origin
	var b: Vector3
	if tip_name != "":
		var tip := skeleton.find_bone(tip_name)
		if tip < 0:
			return
		b = _bone_world(skeleton, tip).origin
		b += (b - a).normalized() * 0.03
	else:
		# Fuß: Knochen sitzt an der Sohle, Y zeigt zur Spitze; Kapsel etwas nach oben (zum Knie) setzen.
		var forward := at.basis.y.normalized()
		var knee := skeleton.find_bone(bone_name.replace("Foot", "LowerLeg"))
		var up := (_bone_world(skeleton, knee).origin - a).normalized() if knee >= 0 else Vector3.UP
		var mid := a + up * FOOT_LIFT
		b = mid + forward * FOOT_FRONT
		a = mid - forward * FOOT_BACK
	if a.distance_to(b) < 0.02:
		return
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(a.distance_to(b), radius * 2.0 + 0.01)
	shape.shape = capsule
	body.add_child(shape)
	shape.transform = body.global_transform.affine_inverse() * Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)


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
	_start_bone.clear()
	_roll_t = -1.0
	_roll_start.clear()
	_match_t = -1.0
	_match.clear()
	running = false
	frozen = false
	active = false
	influence = 1.0
