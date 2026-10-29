extends Node
## Kamerawackeln des lokalen Spielers. Der Player legt den Knoten im Code an (kein class_name,
## damit nach dem Pull kein Klassen-Cache fehlt).
##
## Zwei Quellen:
## - Rennen: rhythmisches Wippen im Takt der Schritte. Den Takt gibt der Körper vor
##   (PlayerBody.get_stride_phase), damit Kamera, Beine und Ego-Hände zusammen auftreten.
## - Explosionen: add_explosion() lädt ein "Trauma" (0–1) auf, das mit der Entfernung abnimmt und
##   schnell abklingt. Das Wackeln wächst mit Trauma², kleine Stöße bleiben dezent.
##
## Der Knoten rechnet nur Versätze aus (get_rotation_offset, get_position_offset). Angewandt werden
## sie von PlayerMovement zusammen mit Hocken, Rutsch-Neigung und Kletter-Nicken, damit keiner den
## anderen überschreibt. Das Low-Health-Wackeln (Camera3D.h_offset/v_offset) bleibt davon getrennt.
## Stärke über Settings.camera_shake (Optionen → Steuerung, 0 = aus).

const GROUP := &"camera_shake"

@export_group("Rennen")
## Wie tief die Kamera bei jedem Auftritt sinkt (Meter, Spitze zu Spitze).
@export var sprint_bob_height := 0.024
## Seitliches Pendeln über das Standbein (Meter).
@export var sprint_bob_side := 0.010
## Nicken bei jedem Auftritt und Rollen zum Standbein hin (Grad).
@export var sprint_pitch_degrees := 0.45
@export var sprint_roll_degrees := 0.6
## Anteil beim normalen Gehen (0 = nur beim Sprinten).
@export_range(0.0, 1.0) var walk_factor := 0.0
## Kamera sinkt kurz nach dem Auftritt am tiefsten (Bogenmaß im Schrittzyklus).
@export var step_lag := 0.35
## Wie schnell das Wippen ein- und ausblendet (pro Sekunde).
@export var sprint_blend_speed := 5.0

@export_group("Explosion")
## Größter Ausschlag bei Trauma 1 (Grad): Nicken, Drehen, Rollen.
@export var explosion_max_degrees := Vector3(4.0, 3.0, 5.0)
## Größter Versatz bei Trauma 1 (Meter).
@export var explosion_max_offset := 0.04
## Trauma direkt an der Explosion.
@export_range(0.0, 1.0) var explosion_trauma := 0.9
## Reichweite des Stoßes als Vielfaches des Explosionsradius (mindestens explosion_min_range).
@export var explosion_range_factor := 4.0
@export var explosion_min_range := 8.0
## Abbau des Traumas pro Sekunde.
@export var trauma_decay := 1.4
## Zittern pro Sekunde (Rauschfrequenz).
@export var explosion_frequency := 18.0

## Zielen dämpft das Wackeln so stark (0–1), damit Zielen nicht leidet.
@export_range(0.0, 1.0) var aim_damping := 0.7

var trauma := 0.0

var _player: Player
var _body: Node
var _noise := FastNoiseLite.new()
var _time := 0.0
var _sprint_weight := 0.0
var _rotation := Vector3.ZERO
var _offset := Vector3.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	# Vor PlayerMovement, damit die Kamera im selben Bild schon die neuen Werte bekommt.
	process_priority = -10
	_player = get_parent() as Player
	_body = _player.get_node_or_null("Body") if _player != null else null
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0


func _process(delta: float) -> void:
	update(delta)


## Rechnet die Versätze für dieses Bild. Öffentlich für Prüfskripte.
func update(delta: float) -> void:
	_time += delta
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	var strength := Settings.camera_shake
	if _player == null or strength <= 0.0:
		_sprint_weight = 0.0
		_rotation = Vector3.ZERO
		_offset = Vector3.ZERO
		return
	var aim := 0.0
	if _player.weapon_holder != null:
		aim = _player.weapon_holder.get_aim()
	var damping := 1.0 - aim * aim_damping

	_sprint_weight = move_toward(_sprint_weight, _running_target(), sprint_blend_speed * delta)
	var rot := Vector3.ZERO
	var pos := Vector3.ZERO
	if _sprint_weight > 0.0 and _body != null and _body.has_method("get_stride_phase"):
		var phase: float = _body.get_stride_phase()
		var amount: float = _sprint_weight * (1.0 - aim)
		# Zweimal pro Zyklus ein Auftritt: tiefster Punkt kurz danach, dazwischen Flugphase.
		var step := cos(2.0 * (phase - PI * 0.5 - step_lag))
		var sway := sin(phase - step_lag)
		pos.y = -sprint_bob_height * 0.5 * step * amount
		pos.x = sprint_bob_side * sway * amount
		rot.x = -deg_to_rad(sprint_pitch_degrees) * 0.5 * step * amount
		rot.z = -deg_to_rad(sprint_roll_degrees) * sway * amount

	if trauma > 0.0:
		var shake := trauma * trauma * damping
		var t := _time * explosion_frequency
		rot.x += deg_to_rad(explosion_max_degrees.x) * shake * _noise.get_noise_2d(t, 0.0)
		rot.y += deg_to_rad(explosion_max_degrees.y) * shake * _noise.get_noise_2d(t, 100.0)
		rot.z += deg_to_rad(explosion_max_degrees.z) * shake * _noise.get_noise_2d(t, 200.0)
		pos += Vector3(_noise.get_noise_2d(t, 300.0), _noise.get_noise_2d(t, 400.0), 0.0) \
			* explosion_max_offset * shake
	_rotation = rot * strength
	_offset = pos * strength


## Drehung (Bogenmaß: Nicken, Drehen, Rollen) relativ zur Kamera.
func get_rotation_offset() -> Vector3:
	return _rotation


## Versatz in Metern im Raum des Körpers (y = Welt-Senkrechte), PlayerMovement rechnet ihn in den Kopf um.
func get_position_offset() -> Vector3:
	return _offset


## Anteil des Renn-Wippens (0–1).
func get_sprint_weight() -> float:
	return _sprint_weight


## Stoß durch eine Explosion bei `center`. Nimmt mit der Entfernung quadratisch ab.
## Gibt das hinzugefügte Trauma zurück.
func add_explosion(center: Vector3, radius: float, strength := 1.0) -> float:
	if _player == null or _player.camera == null:
		return 0.0
	var reach := maxf(radius * explosion_range_factor, explosion_min_range)
	var distance := _player.camera.global_position.distance_to(center)
	var k := clampf(1.0 - distance / reach, 0.0, 1.0)
	var added := explosion_trauma * strength * k * k
	trauma = minf(trauma + added, 1.0)
	return added


## Kurzer Stoß ohne Ort (Faustschlag, Dash). `amount` (0–1) kommt aufs Trauma.
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Alles sofort auf null (Tod, Respawn).
func reset() -> void:
	trauma = 0.0
	_sprint_weight = 0.0
	_rotation = Vector3.ZERO
	_offset = Vector3.ZERO


## Explosion für alle lokalen Kameras in der Szene (Granaten rufen das auf).
static func explosion(tree: SceneTree, center: Vector3, radius: float, strength := 1.0) -> void:
	for node in tree.get_nodes_in_group(GROUP):
		node.add_explosion(center, radius, strength)


func _running_target() -> float:
	if not _player.is_on_floor() or _player.noclip or _player.dead:
		return 0.0
	if _player.movement != null and (_player.movement.is_sliding() or _player.movement.is_mantling()):
		return 0.0
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if speed < 1.0:
		return 0.0
	var sprinting := _player.stats != null and _player.stats.is_sprinting()
	return 1.0 if sprinting else walk_factor
