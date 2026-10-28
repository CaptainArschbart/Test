class_name PlayerHands
extends Node3D
## First-Person-Hände unter der Kamera: Cyber-Handschuhe mit Jackenärmel.
##
## Das Modell wird beim Start aus Grundformen gebaut (Handfläche mit Griffpolster, Fingerglieder
## mit Nägeln an den freien Kuppen, Daumen, Knöchelschutz mit Nieten, Klettriemen, Handrücken-Platte,
## Armband mit Neon, Unterarmschiene (links mit Display), hochgeschobener Ärmel mit Falten). Jeder Finger
## hat drei Gelenke, der Daumen zwei; Posen setzen nur Winkel, keine Meshes.
##
## Posen: ohne Waffe hängen die Hände locker unten. Mit Waffe greift die rechte Hand
## den Griff, die linke stützt (beidhändig). Beim Nachladen holt die linke Hand das
## Magazin. Die Griffposen hängen an der Waffenszene im %WeaponHolder und folgen damit
## Rückstoß und Nachlade-Kippen. Eine Waffenszene kann Marker3D "HandGripRight" und
## "HandGripLeft" mitbringen, sonst gelten die Pistolenwerte unten.
##
## Idle atmet leicht, Gehen und Sprint wackeln stärker, Umschauen zieht die Hände
## etwas nach, Landen drückt sie kurz runter. Die Pose aus der Szene bleibt die Mitte;
## die Abweichung wird jedes Frame neu gesetzt, nicht aufaddiert. Das Wippen beim Laufen folgt
## dem Schrittzyklus des Körpers (PlayerBody.get_stride_phase), wie Beine und Kamera.
##
## Leere Hände im Stand: Nach idle_hide_delay Sekunden ohne Bewegung sinken die Hände weich aus dem
## Bild und werden dann ausgeblendet. Laufen, Springen, Fallen, Klettern, Rutschen, eine Waffe oder
## ein Item in der Hand und wake() (Benutzen, Essen) holen sie sofort wieder hoch.
## Sprint mit leeren Händen: Fäuste pumpen gegengleich zu den Beinen (POSE_SPRINT).
## Hängt an Camera3D, damit Drehen und Nicken die Hände mitnehmen.
## Beim Klettern (PlayerMovement) greifen beide Hände fest an die Kante.

@export var bob_frequency: float = 2.2
@export var walk_bob_amplitude: float = 0.012
@export var sprint_bob_amplitude: float = 0.022
@export var idle_bob_amplitude: float = 0.0035
@export var idle_frequency: float = 1.15
@export var sway_amplitude: float = 0.006
## Unter dieser horizontalen Geschwindigkeit gilt der Spieler als stehend.
@export var move_speed_epsilon: float = 0.45
## Wie stark die Hände beim Umschauen nachziehen und wie schnell sie zurückfedern.
@export var look_sway: float = 0.035
@export var look_sway_return: float = 9.0
## Wie schnell zwischen Posen (locker, Griff, Nachladen) überblendet wird.
@export var pose_speed: float = 9.0
## Schwaches Licht nur für Hände und Waffe, damit sie in dunklen Gassen lesbar bleiben.
## Leuchtet über eine eigene Render-Ebene, die Welt bekommt davon nichts ab.
@export var fill_light_energy: float = 1.1
@export var fill_light_color := Color(0.75, 0.85, 1.0)

## Größe der Hände gegenüber einer echten Hand (Größe M). Etwas größer liest sich im Bild besser.
@export var hand_scale: float = 1.15

@export_group("Ausblenden im Stand")
@export var idle_hide_enabled := true
## So lange muss der Spieler stehen, bevor die leeren Hände verschwinden (kein Flackern bei kurzen Stopps).
@export var idle_hide_delay := 1.2
## Dauer des Absinkens und des Wiederhochkommens in Sekunden.
@export var idle_hide_time := 0.45
@export var idle_show_time := 0.18
## Versatz und Kippen, wenn die Hände ganz unten sind (aus dem Bild).
@export var idle_hide_offset := Vector3(0.0, -0.3, 0.1)
@export var idle_hide_pitch_degrees := -30.0

@export_group("Sprint")
## Wie weit die Fäuste beim Pumpen vor und zurück gehen (0–1 auf die Strecke zwischen den Posen).
@export var sprint_pump := 1.0
## Überblendung zwischen lockerer Haltung und Pumpen (pro Sekunde).
@export var sprint_blend_speed := 6.0

@export_group("Materialien")
@export var glove_material: Material
@export var plate_material: Material
@export var skin_material: Material
@export var sleeve_material: Material
@export var neon_material: Material

## Fingerreihenfolge: Zeige-, Mittel-, Ring-, kleiner Finger.
## Gliedlängen und Radien in Metern (echte Hand, etwa Größe M).
const FINGER_LENGTHS := [
	[0.043, 0.026, 0.021],
	[0.047, 0.029, 0.022],
	[0.044, 0.027, 0.021],
	[0.035, 0.021, 0.019],
]
## Etwas schlanker als echt, damit zwischen den Fingern Luft bleibt und sie einzeln lesbar sind.
const FINGER_RADII := [0.0086, 0.009, 0.0085, 0.0075]
## Knöchel relativ zum Handgelenk: x zur Daumenseite negativ (rechte Hand), z nach vorn negativ.
const KNUCKLES := [
	Vector3(-0.0305, 0.002, -0.094),
	Vector3(-0.0102, 0.003, -0.099),
	Vector3(0.0102, 0.002, -0.096),
	Vector3(0.0295, 0.0, -0.088),
]
## Daumen: Mittelhandknochen (im Ballen), Grund- und Endglied.
const THUMB_LENGTHS := [0.04, 0.032, 0.027]
const THUMB_RADIUS := 0.0112

## Render-Ebene 20: nur Hände und gehaltene Waffe (Ebene 1 bleibt, Weltlicht wirkt weiter).
const VIEWMODEL_LAYER := 1 << 19

## Posen: Lage der Hand (Handgelenk), Fingerkrümmung je Gelenk in Grad,
## Daumen (Grundgelenk als Euler-Winkel in Grad, dann Krümmung der zwei Glieder).
## Die Hand zeigt mit den Fingern nach -Z, der Handrücken nach +Y.
## Drehung entweder als "rot" (Euler in Grad) oder als "fingers" + "back": Richtung, in die
## die gestreckten Finger zeigen, und Richtung des Handrückens (wird rechtwinklig gemacht).
## Daumen: x = zur Handfläche hin (negativ), y = vom Zeigefinger weg gespreizt,
## z = Drehung um die eigene Achse, damit er sich zur Handmitte hin beugt (Gegenstellung).
## Die Fingerkrümmung bleibt pro Gelenk unter 90° und in der Summe bei höchstens 210° (Faust),
## sonst knickt der Finger sichtbar durch die eigene Hand.
const POSE_RELAXED := {
	"pos": Vector3(0.2, -0.195, -0.3),
	"fingers": Vector3(-0.18, 0.06, -1.0),
	"back": Vector3(0.7, 0.75, 0.0),
	"curl": [[16.0, 22.0, 12.0], [20.0, 26.0, 14.0], [25.0, 30.0, 16.0], [30.0, 34.0, 18.0]],
	"spread": 5.0,
	"thumb": Vector3(-22.0, 30.0, 55.0),
	"thumb_curl": [10.0, 12.0],
}
## Rechte Hand am Pistolengriff, im Raum der Waffenszene.
const POSE_GRIP_RIGHT := {
	"pos": Vector3(0.033, -0.056, 0.072),
	"rot": Vector3(15.0, 8.0, -92.0),
	"curl": [[40.0, 52.0, 22.0], [72.0, 76.0, 34.0], [76.0, 78.0, 36.0], [78.0, 78.0, 38.0]],
	"spread": 1.5,
	"thumb": Vector3(-40.0, 14.0, 55.0),
	"thumb_curl": [18.0, 12.0],
}
## Linke Hand stützt von unten (Becher-Griff): Handfläche nach oben unter dem Griff,
## Finger legen sich vorn um die rechten Finger, Daumen an der linken Seite.
const POSE_GRIP_LEFT := {
	"pos": Vector3(-0.045, -0.112, 0.07),
	"fingers": Vector3(0.38, 0.42, -0.82),
	"back": Vector3(-0.55, -1.0, 0.0),
	"curl": [[28.0, 46.0, 20.0], [32.0, 50.0, 22.0], [36.0, 54.0, 24.0], [40.0, 56.0, 24.0]],
	"spread": 2.0,
	"thumb": Vector3(8.0, 18.0, 55.0),
	"thumb_curl": [6.0, 4.0],
}
## Linke Hand unten am Griff (Magazin).
const POSE_RELOAD_LEFT := {
	"pos": Vector3(-0.01, -0.15, 0.05),
	"rot": Vector3(25.0, -10.0, 175.0),
	"curl": [[34.0, 44.0, 22.0], [38.0, 46.0, 24.0], [42.0, 50.0, 26.0], [46.0, 52.0, 26.0]],
	"spread": 3.0,
	"thumb": Vector3(-20.0, 32.0, 55.0),
	"thumb_curl": [16.0, 14.0],
}
## Rechte Hand an Klinge und Granate (Raum des gehaltenen Items im %ItemUser).
## Klinge: Faust um das hintere Ende, die Klinge kommt oben aus der Faust nach vorn.
const POSE_BLADE_RIGHT := {
	"pos": Vector3(0.034, -0.02, 0.085),
	"rot": Vector3(15.0, 8.0, -92.0),
	"curl": [[68.0, 78.0, 38.0], [76.0, 82.0, 40.0], [78.0, 84.0, 42.0], [80.0, 84.0, 42.0]],
	"spread": 1.0,
	"thumb": Vector3(-50.0, 10.0, 55.0),
	"thumb_curl": [30.0, 24.0],
}
## Granate liegt in der Handfläche, die Finger umschließen sie locker.
const POSE_GRENADE_RIGHT := {
	"pos": Vector3(0.07, -0.04, 0.06),
	"rot": Vector3(10.0, 12.0, -78.0),
	"curl": [[46.0, 46.0, 24.0], [50.0, 48.0, 26.0], [54.0, 50.0, 26.0], [56.0, 50.0, 26.0]],
	"spread": 5.0,
	"thumb": Vector3(-30.0, 22.0, 55.0),
	"thumb_curl": [20.0, 16.0],
}

## Sprint: Faust, Daumen oben, Handrücken nach außen. Vorn hoch vor der Brust, hinten tief am
## Bildrand. Die Hand pendelt zwischen den beiden Lagen (rechte Hand nach vorn, wenn das linke
## Bein vorn ist). Links wird gespiegelt.
const POSE_SPRINT := {
	"pos": Vector3(0.17, -0.2, -0.34),
	"fingers": Vector3(-0.35, 0.4, -1.0),
	"back": Vector3(1.0, 0.25, 0.1),
	"curl": [[70.0, 80.0, 40.0], [74.0, 82.0, 42.0], [76.0, 84.0, 42.0], [78.0, 84.0, 42.0]],
	"spread": 1.0,
	"thumb": Vector3(-48.0, 12.0, 55.0),
	"thumb_curl": [28.0, 22.0],
}
## Hintere Lage der Sprint-Faust: Versatz zur vorderen Lage und zusätzliches Kippen (Grad, um x).
const SPRINT_BACK_OFFSET := Vector3(0.07, -0.2, 0.2)
const SPRINT_BACK_PITCH := -55.0

## Hand flach auf einer Kante, Finger greifen über die Kante (Lage kommt beim Klettern aus der Welt).
const POSE_LEDGE := {
	"pos": Vector3.ZERO,
	"rot": Vector3.ZERO,
	"curl": [[38.0, 46.0, 30.0], [42.0, 50.0, 32.0], [44.0, 52.0, 32.0], [46.0, 52.0, 30.0]],
	"spread": 6.0,
	"thumb": Vector3(-20.0, 30.0, 55.0),
	"thumb_curl": [16.0, 20.0],
}

## Beim Klettern bleiben die Hände mindestens so hoch und so weit vorn (Raum der Hände).
const LEDGE_MIN_Y := -0.22
## Hohe Kanten: Hände oben im Bild statt darüber.
const LEDGE_MAX_Y := 0.16
const LEDGE_MAX_Z := -0.32

## Faktor auf alle Ausschläge (WeaponHolder senkt ihn beim Zielen).
var motion_scale: float = 1.0

var _base_position: Vector3
var _base_rotation: Vector3
var _time: float = 0.0
var _player: Player
var _right: Dictionary
var _left: Dictionary
var _pose_right: Dictionary
var _pose_left: Dictionary
var _last_look := Basis.IDENTITY
var _look_offset := Vector2.ZERO
var _land_dip: float = 0.0
var _was_on_floor := true
var _idle_time := 0.0
## 0 = Hände voll da, 1 = ganz ausgeblendet.
var _hide := 0.0
var _wake_left := 0.0
var _sprint_weight := 0.0
var _body: Node
var _lit_view: Node3D
var _metal_material: StandardMaterial3D
var _rubber_material: StandardMaterial3D
var _nail_material: StandardMaterial3D
var _screen_material: StandardMaterial3D



func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	_ensure_materials()
	_add_fill_light()
	_right = _build_hand(1.0)
	_left = _build_hand(-1.0)
	_pose_right = _resting_pose(1.0)
	_pose_left = _resting_pose(-1.0)
	_apply_pose(_right, _pose_right)
	_apply_pose(_left, _pose_left)
	_player = _find_player()
	if _player == null:
		push_error("PlayerHands braucht einen Player über sich.")
		return
	_last_look = (get_parent() as Node3D).global_basis
	_body = _player.get_node_or_null("Body")


func _process(delta: float) -> void:
	if _player == null:
		return
	var flat := Vector2(_player.velocity.x, _player.velocity.z)
	var sprinting := _player.stats != null and _player.stats.is_sprinting()
	_update_look_sway(delta)
	_update_landing(delta)
	update_idle_hide(delta, flat.length())
	apply_motion(delta, flat.length(), sprinting)
	update_pose(delta)


## Holt die Hände für `seconds` hoch, auch im Stand (z. B. beim Benutzen oder Essen).
func wake(seconds := 1.0) -> void:
	_wake_left = maxf(_wake_left, seconds)
	_idle_time = 0.0


## 0 = Hände voll sichtbar, 1 = ausgeblendet (im Stand ohne Waffe).
func get_hide_amount() -> float:
	return _hide


## Gewicht der Sprint-Pose (0–1).
func get_sprint_weight() -> float:
	return _sprint_weight


## Leere Hände im Stand weich aus dem Bild nehmen, bei jeder Aktion sofort wieder zeigen.
func update_idle_hide(delta: float, horizontal_speed: float) -> void:
	_wake_left = maxf(_wake_left - delta, 0.0)
	if _needs_hands(horizontal_speed):
		_idle_time = 0.0
	else:
		_idle_time += delta
	var target := 1.0 if idle_hide_enabled and _idle_time >= idle_hide_delay else 0.0
	var duration := idle_hide_time if target > _hide else idle_show_time
	_hide = move_toward(_hide, target, delta / maxf(duration, 0.01))
	var shown := _hide < 0.999
	for hand: Dictionary in [_right, _left]:
		(hand.root as Node3D).visible = shown
		(hand.arm as Node3D).visible = shown


func _needs_hands(horizontal_speed: float) -> bool:
	if _wake_left > 0.0 or horizontal_speed > move_speed_epsilon or not _player.is_on_floor():
		return true
	if _weapon_view() != null or _held_item() != null:
		return true
	var movement := _player.movement
	if movement != null and (movement.get_grab_weight() > 0.0 or movement.is_sliding() or movement.is_mantling()):
		return true
	return false


## Idle, Gehen oder Sprint. `horizontal_speed` in Metern pro Sekunde.
func apply_motion(delta: float, horizontal_speed: float, sprinting: bool) -> void:
	var moving := horizontal_speed > move_speed_epsilon
	var frequency := idle_frequency
	var amplitude_y := idle_bob_amplitude
	var amplitude_x := idle_bob_amplitude * 0.4
	if moving and sprinting:
		frequency = bob_frequency * 1.65
		amplitude_y = sprint_bob_amplitude
		amplitude_x = sway_amplitude * 1.5
	elif moving:
		frequency = bob_frequency
		amplitude_y = walk_bob_amplitude
		amplitude_x = sway_amplitude
	amplitude_y *= motion_scale
	amplitude_x *= motion_scale
	_time += delta * frequency
	var wave := sin(_time)
	var sway := sin(_time * 0.5)
	if moving and _body != null and _body.has_method("get_stride_phase") and _player.is_on_floor():
		# Im Takt der Füße: tiefster Punkt kurz nach jedem Auftritt, seitlich einmal pro Doppelschritt.
		var phase: float = _body.get_stride_phase()
		wave = cos(2.0 * (phase - PI * 0.5 - 0.35))
		sway = sin(phase - 0.35)
	var look := _look_offset * motion_scale
	var lowered := smoothstep(0.0, 1.0, _hide)
	position = _base_position + Vector3(sway * amplitude_x - look.x * 0.5, wave * amplitude_y + look.y * 0.5 - _land_dip * motion_scale, 0.0) \
		+ idle_hide_offset * lowered
	rotation = _base_rotation + Vector3(wave * amplitude_y * 2.0 + look.y * 1.5 + deg_to_rad(idle_hide_pitch_degrees) * lowered,
		look.x * 1.5, sway * amplitude_x * 1.5 + look.x * 0.8)


## Überblendet beide Hände zur Pose, die zur aktuellen Waffe passt.
func update_pose(delta: float) -> void:
	var weight := 1.0 - exp(-pose_speed * delta)
	var view := _weapon_view()
	if view != _lit_view:
		_lit_view = view
		if view != null:
			_set_viewmodel_layer(view)
	var target_right := _resting_pose(1.0)
	var target_left := _resting_pose(-1.0)
	if view != null:
		var holder := _player.weapon_holder
		var space := holder.transform * view.transform
		var arm_space := holder.transform * Transform3D(Basis.IDENTITY, view.position)
		var reloading := holder.is_reloading()
		_sprint_weight = 0.0
		target_right = _pose_in_space(POSE_GRIP_RIGHT, space, arm_space, view.get_node_or_null("HandGripRight"))
		var left_pose := POSE_RELOAD_LEFT if reloading else POSE_GRIP_LEFT
		var left_marker: Node = null if reloading else view.get_node_or_null("HandGripLeft")
		target_left = _pose_in_space(left_pose, space, arm_space, left_marker)
		# Der Griff sitzt fest: die rechte Hand folgt der Waffe sofort (Rückstoß).
		_pose_right = _blend_pose(_pose_right, target_right, maxf(weight, 0.6))
	elif _held_item() != null:
		# Klinge oder Granate: rechte Hand greift, linke bleibt locker unten.
		_sprint_weight = 0.0
		var held := _held_item()
		var item_user: Node3D = _player.item_user
		var space := item_user.transform * held.transform
		var arm_space := item_user.transform * Transform3D(Basis.IDENTITY, held.position)
		var pose := POSE_GRENADE_RIGHT if _player.item_user.get_held_item() is GrenadeData else POSE_BLADE_RIGHT
		target_right = _pose_in_space(pose, space, arm_space, null)
		_pose_right = _blend_pose(_pose_right, target_right, maxf(weight, 0.6))
	else:
		# Leere Hände: beim Sprint pumpen die Fäuste, Gewicht weich überblendet.
		_update_sprint_weight(delta)
		if _sprint_weight > 0.001:
			var phase: float = _body.get_stride_phase() if _body != null and _body.has_method("get_stride_phase") else 0.0
			target_right = _blend_pose(target_right, _sprint_pose(1.0, phase), _sprint_weight)
			target_left = _blend_pose(target_left, _sprint_pose(-1.0, phase), _sprint_weight)
			# Die Fäuste folgen dem Takt direkt, sonst hinkt das Pumpen hinterher.
			weight = maxf(weight, _sprint_weight * 0.7)
		_pose_right = _blend_pose(_pose_right, target_right, weight)
	_pose_left = _blend_pose(_pose_left, target_left, weight)
	# Ein wenig Leben in den Fingern, auch beim Stillstehen.
	var breath := sin(Time.get_ticks_msec() * 0.0011) * 2.0
	# Klettern: Hände liegen fest an der Kante (Weltpunkte), egal wie sich die Kamera bewegt.
	var grab := _player.movement.get_grab_weight() if _player.movement != null else 0.0
	if grab > 0.001:
		var grips := _player.movement.get_grab_transforms()
		_apply_pose(_right, _blend_pose(_pose_right, _ledge_pose(grips[0]), grab))
		_apply_pose(_left, _blend_pose(_pose_left, _ledge_pose(grips[1]), grab))
		return
	_apply_pose(_right, _pose_right, breath if view == null and _held_item() == null else 0.0)
	_apply_pose(_left, _pose_left, breath)


func _update_sprint_weight(delta: float) -> void:
	var target := 0.0
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if _player.stats != null and _player.stats.is_sprinting() and speed > move_speed_epsilon \
			and _player.is_on_floor():
		target = 1.0
	_sprint_weight = move_toward(_sprint_weight, target, sprint_blend_speed * delta)


## Sprint-Faust für eine Seite bei Phase `phase` des Laufzyklus (rechter Fuß setzt bei π/2 auf).
func _sprint_pose(side: float, phase: float) -> Dictionary:
	var pose := POSE_SPRINT.duplicate()
	var mirror := Vector3(side, 1.0, 1.0)
	pose.fingers = pose.fingers * mirror
	pose.back = pose.back * mirror
	var result := _to_runtime(pose)
	# Rechte Faust vorn, wenn das linke Bein vorn ist (Phase 3π/2), linke gegengleich.
	var forward := -sin(phase) * side
	var t := (1.0 - forward * sprint_pump) * 0.5
	var front: Vector3 = POSE_SPRINT.pos * mirror
	var back := front + SPRINT_BACK_OFFSET * mirror
	# Leichter Bogen: in der Mitte etwas tiefer (der Ellbogen schwingt am Körper vorbei).
	result.pos = front.lerp(back, t) + Vector3(0.0, -0.035 * sin(t * PI), 0.0)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(SPRINT_BACK_PITCH) * t)
	result.basis = tilt * result.basis
	result.arm_basis = result.basis
	return result


## Greifpose an einer Kante: Welt-Transform des Handgelenks in den Raum der Hände.
func _ledge_pose(world: Transform3D) -> Dictionary:
	var pose := _to_runtime(POSE_LEDGE)
	var local := global_transform.affine_inverse() * world
	# Steigt die Kamera über die Kante, rutschen die Hände sonst aus dem Bild. Dann bleiben sie
	# unten im Bild und drücken sich ab (wie beim echten Hochstemmen). Bei hohen Kanten oben im Bild.
	local.origin.y = clampf(local.origin.y, LEDGE_MIN_Y, LEDGE_MAX_Y)
	local.origin.z = minf(local.origin.z, LEDGE_MAX_Z)
	pose.pos = local.origin
	pose.basis = local.basis.orthonormalized()
	pose.arm_basis = pose.basis
	return pose


func _update_look_sway(delta: float) -> void:
	var now := (get_parent() as Node3D).global_basis
	var diff := (_last_look.inverse() * now).get_euler()
	_last_look = now
	if delta > 0.0:
		_look_offset += Vector2(diff.y, diff.x) * look_sway / maxf(delta * 60.0, 0.2)
	_look_offset = _look_offset.limit_length(0.05)
	_look_offset = _look_offset.lerp(Vector2.ZERO, minf(look_sway_return * delta, 1.0))


func _update_landing(delta: float) -> void:
	var on_floor := _player.is_on_floor()
	if on_floor and not _was_on_floor:
		_land_dip = 0.025
	_was_on_floor = on_floor
	_land_dip = lerpf(_land_dip, 0.0, minf(8.0 * delta, 1.0))


## Die Szene der gehaltenen Waffe, oder null ohne Waffe.
func _weapon_view() -> Node3D:
	if _player.weapon_holder == null or _player.weapon_holder.get_weapon() == null:
		return null
	for child in _player.weapon_holder.get_children():
		if child is Node3D and not child.is_queued_for_deletion():
			return child
	return null


## Klinge oder Granate in der Hand (vom %ItemUser), sonst null.
func _held_item() -> Node3D:
	if _player.item_user == null:
		return null
	var held := _player.item_user.get_held_view()
	if held == null or held.is_queued_for_deletion():
		return null
	return held


func _resting_pose(side: float) -> Dictionary:
	var pose := POSE_RELAXED.duplicate()
	var mirror := Vector3(side, 1.0, 1.0)
	pose.pos = pose.pos * mirror
	pose.fingers = pose.fingers * mirror
	pose.back = pose.back * mirror
	return _to_runtime(pose)


## Basis aus Fingerrichtung und Handrücken-Richtung (siehe Posen oben).
static func _hand_basis(fingers: Vector3, back: Vector3) -> Basis:
	var z := -fingers.normalized()
	var y := (back - z * back.dot(z)).normalized()
	return Basis(y.cross(z), y, z)


## Pose aus dem Raum der Waffe in den Raum der Hände. Ein Marker ersetzt Lage und Drehung.
## arm_space ist die Waffe ohne eigene Drehung: der Unterarm macht Kippen nicht mit.
func _pose_in_space(pose: Dictionary, space: Transform3D, arm_space: Transform3D, marker: Node) -> Dictionary:
	var result := _to_runtime(pose)
	var local := Transform3D(result.basis, result.pos)
	if marker is Node3D:
		local = (marker as Node3D).transform
	var placed := space * local
	result.pos = placed.origin
	result.basis = placed.basis.orthonormalized()
	result.arm_basis = (arm_space * local).basis.orthonormalized()
	return result


func _to_runtime(pose: Dictionary) -> Dictionary:
	var basis: Basis
	if pose.has("fingers"):
		basis = _hand_basis(pose.fingers, pose.back)
	else:
		var r: Vector3 = pose.rot
		basis = Basis.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z)))
	return {
		"pos": pose.pos,
		"basis": basis,
		"arm_basis": basis,
		"curl": pose.curl,
		"spread": pose.spread,
		"thumb": pose.thumb,
		"thumb_curl": pose.thumb_curl,
	}


func _blend_pose(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var curl := []
	for i in 4:
		var row := []
		for j in 3:
			row.append(lerpf(from.curl[i][j], to.curl[i][j], weight))
		curl.append(row)
	var from_q := Quaternion(from.basis)
	return {
		"pos": from.pos.lerp(to.pos, weight),
		"basis": Basis(from_q.slerp(Quaternion(to.basis), weight)),
		"arm_basis": Basis(Quaternion(from.arm_basis).slerp(Quaternion(to.arm_basis), weight)),
		"curl": curl,
		"spread": lerpf(from.spread, to.spread, weight),
		"thumb": from.thumb.lerp(to.thumb, weight),
		"thumb_curl": [lerpf(from.thumb_curl[0], to.thumb_curl[0], weight),
			lerpf(from.thumb_curl[1], to.thumb_curl[1], weight)],
	}


func _apply_pose(hand: Dictionary, pose: Dictionary, extra_curl := 0.0) -> void:
	var side: float = hand.side
	var root: Node3D = hand.root
	root.transform = Transform3D(pose.basis, pose.pos)
	(hand.arm as Node3D).transform = Transform3D(pose.arm_basis, pose.pos)
	for i in 4:
		var joints: Array = hand.fingers[i]
		var spread := deg_to_rad((1.5 - i) * pose.spread * 0.6) * side
		for j in 3:
			var joint: Node3D = joints[j]
			var bend := deg_to_rad(pose.curl[i][j] + extra_curl * (1.0 + i * 0.3))
			joint.rotation = Vector3(-bend, spread if j == 0 else 0.0, 0.0)
	var thumb: Vector3 = pose.thumb
	var base: Node3D = hand.thumb[0]
	base.rotation = Vector3(deg_to_rad(thumb.x), deg_to_rad(thumb.y) * side, deg_to_rad(thumb.z) * side)
	for j in 2:
		var joint: Node3D = hand.thumb[j + 1]
		joint.rotation = Vector3(-deg_to_rad(pose.thumb_curl[j]), 0.0, 0.0)


# --- Modell -----------------------------------------------------------------

## Baut eine Hand. side 1 = rechts, -1 = links (gespiegelt über x).
func _build_hand(side: float) -> Dictionary:
	var pivot := Node3D.new()
	pivot.name = "RightHand" if side > 0.0 else "LeftHand"
	add_child(pivot)
	# Alles Sichtbare hängt unter einem skalierten Knoten; Posen setzen nur den Pivot.
	var root := Node3D.new()
	root.name = "Model"
	root.scale = Vector3.ONE * hand_scale
	pivot.add_child(root)

	# Handfläche: weich abgerundeter Block, zum kleinen Finger hin etwas schmaler.
	_part(root, ProcMesh.rounded_box(Vector3(0.084, 0.03, 0.094), 0.32), glove_material,
		Vector3(0.0, 0.0, -0.048), Vector3(0.0, 0.0, 0.0))
	# Daumenballen.
	_part(root, ProcMesh.rounded_box(Vector3(0.034, 0.028, 0.056), 0.55), glove_material,
		Vector3(-0.028 * side, -0.008, -0.03), Vector3(0.0, 0.3 * side, 0.0))
	# Handrücken-Panzerplatte mit Neon-Schlitz.
	_part(root, ProcMesh.rounded_box(Vector3(0.066, 0.008, 0.056), 0.22), plate_material,
		Vector3(0.0, 0.0165, -0.052), Vector3(-0.06, 0.0, 0.0))
	_part(root, ProcMesh.rounded_box(Vector3(0.004, 0.003, 0.04), 0.5), neon_material,
		Vector3(0.012 * side, 0.0212, -0.054), Vector3(-0.06, 0.0, 0.0))
	_part(root, ProcMesh.rounded_box(Vector3(0.004, 0.003, 0.03), 0.5), neon_material,
		Vector3(-0.006 * side, 0.0212, -0.06), Vector3(-0.06, 0.0, 0.0))
	# Knöchelschutz quer über die Grundgelenke, mit Nieten über jedem Knöchel.
	_part(root, ProcMesh.rounded_box(Vector3(0.08, 0.012, 0.016), 0.35), plate_material,
		Vector3(0.0, 0.012, -0.091), Vector3(0.0, 0.0, 0.0))
	for knuckle: Vector3 in KNUCKLES:
		_part(root, ProcMesh.tube(0.0035, 0.0045, 0.004), _metal_material,
			Vector3(knuckle.x * side, 0.0185, -0.091), Vector3.ZERO)
	# Klettriemen mit Schnalle über dem Handrücken, Griffpolster in der Handfläche.
	_part(root, ProcMesh.rounded_box(Vector3(0.088, 0.012, 0.017), 0.3), _rubber_material,
		Vector3(0.0, 0.006, -0.014), Vector3.ZERO)
	_part(root, ProcMesh.rounded_box(Vector3(0.016, 0.005, 0.02), 0.3), _metal_material,
		Vector3(0.03 * side, 0.0125, -0.014), Vector3.ZERO)
	_part(root, ProcMesh.rounded_box(Vector3(0.066, 0.008, 0.05), 0.4), _rubber_material,
		Vector3(0.004 * side, -0.0135, -0.06), Vector3.ZERO)
	_part(root, ProcMesh.rounded_box(Vector3(0.03, 0.007, 0.03), 0.45), _rubber_material,
		Vector3(-0.026 * side, -0.016, -0.026), Vector3(0.0, 0.25 * side, 0.0))

	var fingers := []
	for i in 4:
		var knuckle: Vector3 = KNUCKLES[i]
		knuckle.x *= side
		var joints := _build_chain(root, knuckle, FINGER_LENGTHS[i], FINGER_RADII[i], true)
		fingers.append(joints)

	# Daumen: Sattelgelenk an der Handkante nahe dem Handgelenk, auf der Seite der Handfläche.
	# Das erste Glied (Mittelhandknochen) steckt im Daumenballen, Grund- und Endglied sind frei.
	var thumb_base := Node3D.new()
	thumb_base.position = Vector3(-0.03 * side, -0.009, -0.018)
	root.add_child(thumb_base)
	var thumb_joints := [thumb_base]
	thumb_joints.append_array(_build_chain(thumb_base, Vector3.ZERO, THUMB_LENGTHS, THUMB_RADIUS, false).slice(1))
	# Das erste Glied liegt im Grundgelenk selbst (Mittelhandknochen des Daumens).
	_segment(thumb_base, THUMB_LENGTHS[0], THUMB_RADIUS * 1.18, glove_material)

	# Handgelenk: Armband mit Leuchtring, dann Jackenärmel mit Bündchen. Der Unterarm ist
	# ein eigener Knoten, damit das Handgelenk abknicken kann (Nachladen kippt nur die Hand).
	var arm_pivot := Node3D.new()
	arm_pivot.name = pivot.name + "Arm"
	add_child(arm_pivot)
	var arm := Node3D.new()
	arm.name = "Model"
	arm.scale = Vector3.ONE * hand_scale
	arm_pivot.add_child(arm)
	_part(arm, ProcMesh.tube(0.036, 0.034, 0.05), plate_material,
		Vector3(0.0, 0.0, 0.018), Vector3(PI * 0.5, 0.0, 0.0), Vector3(1.0, 1.0, 0.72))
	_part(arm, ProcMesh.tube(0.0372, 0.0372, 0.005), neon_material,
		Vector3(0.0, 0.0, 0.004), Vector3(PI * 0.5, 0.0, 0.0), Vector3(1.0, 1.0, 0.72))
	_part(arm, ProcMesh.tube(0.0372, 0.0372, 0.003), neon_material,
		Vector3(0.0, 0.0, 0.034), Vector3(PI * 0.5, 0.0, 0.0), Vector3(1.0, 1.0, 0.72))
	_part(arm, ProcMesh.tube(0.047, 0.045, 0.04), sleeve_material,
		Vector3(0.0, 0.0, 0.064), Vector3(PI * 0.5, 0.0, 0.0), Vector3(1.0, 1.0, 0.82))
	_part(arm, ProcMesh.tube(0.062, 0.048, 0.42), sleeve_material,
		Vector3(0.0, 0.0, 0.29), Vector3(PI * 0.5, 0.0, 0.0), Vector3(1.0, 1.0, 0.85))
	# Hochgeschobener Ärmel: Wulst am Bündchen und Falten.
	_part(arm, ProcMesh.tube(0.053, 0.053, 0.03), sleeve_material,
		Vector3(0.0, 0.0, 0.1), Vector3(PI * 0.5, 0.0, 0.0), Vector3(1.0, 1.0, 0.86))
	for i in 3:
		var z := 0.17 + i * 0.075
		var r := 0.05 + z * 0.028
		_part(arm, ProcMesh.tube(r, r, 0.018), sleeve_material,
			Vector3(0.0, -0.002 * i, z), Vector3(PI * 0.5 + 0.12 * (i - 1), 0.0, 0.0), Vector3(1.0, 1.0, 0.86))
	# Unterarmschiene über dem Handgelenk.
	_part(arm, ProcMesh.rounded_box(Vector3(0.05, 0.012, 0.05), 0.3), plate_material,
		Vector3(0.0, 0.031, 0.06), Vector3(-0.05, 0.0, 0.0))
	if side < 0.0:
		# Links: Handgelenk-Display mit Rahmen und Anzeige.
		_part(arm, ProcMesh.rounded_box(Vector3(0.04, 0.006, 0.034), 0.25), _rubber_material,
			Vector3(0.0, 0.039, 0.06), Vector3(-0.05, 0.0, 0.0))
		_part(arm, ProcMesh.rounded_box(Vector3(0.032, 0.002, 0.026), 0.2), _screen_material,
			Vector3(0.0, 0.0425, 0.06), Vector3(-0.05, 0.0, 0.0))
		for i in 3:
			_part(arm, ProcMesh.rounded_box(Vector3(0.006 + i * 0.006, 0.001, 0.003), 0.5), neon_material,
				Vector3(-0.008 + i * 0.003, 0.0445, 0.052 + i * 0.007), Vector3(-0.05, 0.0, 0.0))
	else:
		# Rechts: Leuchtschlitz und ein Kabel von der Schiene in den Ärmel.
		_part(arm, ProcMesh.rounded_box(Vector3(0.004, 0.002, 0.034), 0.5), neon_material,
			Vector3(0.012, 0.038, 0.06), Vector3(-0.05, 0.0, 0.0))
		_part(arm, ProcMesh.tube(0.0045, 0.0045, 0.07), _rubber_material,
			Vector3(-0.016, 0.034, 0.105), Vector3(PI * 0.5 - 0.15, 0.0, 0.0))

	var thumb_chain: Array = thumb_joints
	return {"root": pivot, "arm": arm_pivot, "side": side, "fingers": fingers, "thumb": thumb_chain}


## Gelenkkette entlang -Z. Gibt die Gelenke zurück (Index 0 = Grundgelenk).
## Fingerkuppen bleiben frei (Handschuh ohne Fingerspitzen).
func _build_chain(parent: Node3D, start: Vector3, lengths: Array, radius: float, finger: bool) -> Array:
	var joints := []
	var node := parent
	var offset := start
	for j in lengths.size():
		var joint := Node3D.new()
		joint.position = offset
		node.add_child(joint)
		joints.append(joint)
		var length: float = lengths[j]
		var r := radius * (1.0 - j * 0.09)
		var last := j == lengths.size() - 1
		if finger or j > 0:
			_segment(joint, length, r, skin_material if last else glove_material)
		if finger and j == 0:
			# Kleine Panzerplatte auf dem Grundglied mit Leuchtpunkt, damit jeder Finger einzeln lesbar ist.
			_part(joint, ProcMesh.rounded_box(Vector3(r * 1.7, r * 0.7, length * 0.62), 0.3), plate_material,
				Vector3(0.0, r * 0.82, -length * 0.5), Vector3.ZERO)
			_part(joint, ProcMesh.rounded_box(Vector3(r * 0.5, r * 0.2, length * 0.3), 0.5), neon_material,
				Vector3(0.0, r * 1.18, -length * 0.5), Vector3.ZERO)
		if finger and j == 1:
			# Metallkappe auf dem Mittelgelenk (heller Knöchel).
			_part(joint, ProcMesh.rounded_box(Vector3(r * 1.5, r * 0.6, r * 1.3), 0.45), _metal_material,
				Vector3(0.0, r * 0.78, -r * 0.2), Vector3.ZERO)
		if last:
			# Fingernagel auf der freien Kuppe.
			_part(joint, ProcMesh.rounded_box(Vector3(r * 1.15, r * 0.3, length * 0.48), 0.45), _nail_material,
				Vector3(0.0, r * 0.86, -length * 0.66), Vector3(0.05, 0.0, 0.0))
			# Abschlussring des Handschuhs vor der Fingerkuppe.
			_part(joint, ProcMesh.tube(r * 1.12, r * 1.12, 0.0045), glove_material,
				Vector3(0.0, 0.0, -0.002), Vector3(PI * 0.5, 0.0, 0.0))
		node = joint
		offset = Vector3(0.0, 0.0, -length)
	return joints


## Ein Fingerglied: Kapsel vom Gelenk aus nach -Z.
func _segment(joint: Node3D, length: float, radius: float, material: Material) -> void:
	var mesh := ProcMesh.capsule(radius, length + radius * 1.6)
	_part(joint, mesh, material, Vector3(0.0, 0.0, -length * 0.5), Vector3(PI * 0.5, 0.0, 0.0))


func _part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot: Vector3,
		scale_by := Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.layers = 1 | VIEWMODEL_LAYER
	instance.position = pos
	instance.rotation = rot
	instance.scale = scale_by
	parent.add_child(instance)
	return instance


func _add_fill_light() -> void:
	var light := OmniLight3D.new()
	light.name = "FillLight"
	light.light_color = fill_light_color
	light.light_energy = fill_light_energy
	light.light_specular = 0.6
	light.omni_range = 1.2
	light.shadow_enabled = false
	light.light_cull_mask = VIEWMODEL_LAYER
	light.position = Vector3(-0.1, 0.25, 0.1)
	add_child(light)


func _set_viewmodel_layer(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers |= VIEWMODEL_LAYER
	for child in node.get_children():
		_set_viewmodel_layer(child)


## Fehlt ein Material in der Szene, gibt es einfache Ersatzfarben. Nieten, Gummi, Nägel und
## das Display am linken Handgelenk kommen immer aus dem Code.
func _ensure_materials() -> void:
	_metal_material = _flat(Color(0.55, 0.57, 0.6), 0.9, 0.3)
	_rubber_material = _flat(Color(0.03, 0.03, 0.035), 0.0, 0.9)
	_nail_material = _flat(Color(0.86, 0.68, 0.62), 0.0, 0.35)
	_screen_material = _flat(Color(0.05, 0.02, 0.06), 0.2, 0.15)
	_screen_material.emission_enabled = true
	_screen_material.emission = Color(1.0, 0.15, 0.55)
	_screen_material.emission_energy_multiplier = 0.9
	if glove_material == null:
		glove_material = _flat(Color(0.07, 0.075, 0.09), 0.0, 0.75)
	if plate_material == null:
		plate_material = _flat(Color(0.16, 0.17, 0.2), 0.85, 0.3)
	if skin_material == null:
		skin_material = _flat(Color(0.78, 0.56, 0.45), 0.0, 0.6)
	if sleeve_material == null:
		sleeve_material = _flat(Color(0.12, 0.08, 0.1), 0.0, 0.85)
	if neon_material == null:
		neon_material = _flat(Color(0.1, 0.95, 1.0), 0.0, 0.4)
		neon_material.emission_enabled = true
		neon_material.emission = Color(0.1, 0.95, 1.0)
		neon_material.emission_energy_multiplier = 2.5


static func _flat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _find_player() -> Player:
	var node: Node = self
	while node != null:
		if node is Player:
			return node as Player
		node = node.get_parent()
	return null
