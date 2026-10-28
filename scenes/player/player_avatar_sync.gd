class_name PlayerAvatarSync
extends Node
## Zeigt fremde Spieler im Multiplayer als ganze Figur.
##
## Eigene Figur (Autorität): sammelt jedes Physik-Frame Position, Blick, Geschwindigkeit und
## Zustände (Boden, Hocken, Rutschen, Klettern, Waffe, Zielen, Nachladen, Tod, Noclip) in die
## net_*-Felder. PlayerSync in player.tscn schickt sie alle 0,05 s an die anderen.
##
## Fremde Figur: PlayerBody zeigt alles (first_person = false), die schwebenden Ego-Hände der
## fremden Kamera sind aus. Position, Drehung und Blick werden mit INTERP_DELAY Verzögerung
## zwischen zwei Paketen geglättet (sonst springt die Figur 20-mal pro Sekunde). Schüsse und
## Schläge kommen als Zähler (net_shots, net_actions): steigt der Zähler, spielt die Figur
## Rückstoß, Mündungsfeuer und den Schuss-Sound bzw. den Schlag/Wurf. Schritte macht die
## fremde Figur selbst (PlayerBody.stepped auf %Footsteps).
##
## Ohne Multiplayer-Peer tut der Knoten nichts außer Werte zu sammeln.

## So weit hinter dem neuesten Paket wird gezeigt (zwei Pakete Puffer).
const INTERP_DELAY := 0.1
## Weiter als das zwischen zwei Paketen = Teleport (Respawn), nicht glätten.
const TELEPORT_DISTANCE := 4.0
const ITEM_PATH := "res://scenes/items/data/%s.tres"

enum Flag { FLOOR = 1, SLIDE = 2, DEAD = 4, NOCLIP = 8 }

var net_position := Vector3.ZERO:
	set(value):
		net_position = value
		_push_snapshot()
var net_yaw := 0.0
var net_pitch := 0.0
var net_velocity := Vector3.ZERO
var net_flags := Flag.FLOOR
var net_crouch := 0.0
var net_climb := -1.0
var net_aim := 0.0
var net_reload := -1.0
var net_held := "":
	set(value):
		if value == net_held:
			return
		net_held = value
		if _puppet and _body != null:
			_apply_held()
var net_shots := 0:
	set(value):
		var fired := _puppet and _synced_once and value > net_shots
		net_shots = value
		if fired:
			_on_remote_shot()
var net_actions := 0:
	set(value):
		var acted := _puppet and _synced_once and value > net_actions
		net_actions = value
		if acted and _body != null:
			_body.trigger_action()

var _player: Player
var _body: PlayerBody
var _puppet := false
var _synced_once := false
## [Zeit, Position, Yaw, Pitch], älteste zuerst.
var _snapshots: Array = []
var _shot_audio: AudioStreamPlayer3D
var _last_step := 0


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_error("PlayerAvatarSync muss ein Kind des Players sein.")
		set_process(false)
		set_physics_process(false)
		return
	# Tote Figuren stehen still (process_mode DISABLED), der Zustand soll trotzdem raus.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _player.is_node_ready():
		await _player.ready
	_body = _player.get_node_or_null("Body") as PlayerBody
	_puppet = not _player.controls_local_body()
	if _puppet:
		_setup_puppet()
	else:
		_player.weapon_holder.fired.connect(func() -> void: net_shots += 1)
		_player.item_user.action_performed.connect(func() -> void: net_actions += 1)
		_collect()
	set_physics_process(not _puppet)
	set_process(_puppet)


func _physics_process(_delta: float) -> void:
	_collect()


func _process(delta: float) -> void:
	_apply_snapshot()
	_player.hands.visible = false
	if _body == null:
		return
	var flags := net_flags
	_body.look_pitch = _player.head.rotation.x
	_body.crouch = net_crouch
	_body.sliding = flags & Flag.SLIDE != 0
	_body.climb = net_climb
	_body.aim = net_aim
	_body.reload = net_reload
	_body.dead = flags & Flag.DEAD != 0
	var on_floor := flags & Flag.FLOOR != 0 and flags & Flag.NOCLIP == 0
	_body.animate(delta, net_velocity, on_floor)


## Eigene Figur: Zustand in die net_*-Felder schreiben.
func _collect() -> void:
	net_position = _player.global_position
	net_yaw = _player.rotation.y
	net_pitch = _player.head.rotation.x
	net_velocity = _player.velocity
	var flags := 0
	if _player.is_on_floor():
		flags |= Flag.FLOOR
	if _player.movement.is_sliding():
		flags |= Flag.SLIDE
	if _player.dead:
		flags |= Flag.DEAD
	if _player.noclip:
		flags |= Flag.NOCLIP
	net_flags = flags
	net_crouch = _player.movement.crouch_amount
	net_climb = _player.movement.get_climb_progress()
	var holder := _player.weapon_holder
	net_aim = holder.get_aim()
	net_reload = holder.get_reload_progress()
	var item := _player.inventory.get_selected_item()
	net_held = item.id if item != null else ""


## Fremde Figur: ganzer Körper sichtbar, Ego-Hände und ihre Waffe aus, Schritte selbst.
func _setup_puppet() -> void:
	_player.hands.visible = false
	_player.hands.process_mode = Node.PROCESS_MODE_DISABLED
	if _body != null:
		_body.first_person = false
		_body.external_drive = true
		_body.stepped.connect(_on_step)
		_apply_held()
	_shot_audio = AudioStreamPlayer3D.new()
	_shot_audio.name = "RemoteShot"
	_shot_audio.bus = &"SFX"
	_shot_audio.unit_size = 14.0
	_shot_audio.max_distance = 90.0
	_shot_audio.position = Vector3.UP * 1.4
	_player.add_child(_shot_audio)
	_snapshots.clear()


func _push_snapshot() -> void:
	if not _puppet:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not _snapshots.is_empty():
		var last: Array = _snapshots.back()
		if (last[1] as Vector3).distance_to(net_position) > TELEPORT_DISTANCE:
			_snapshots.clear()
	_snapshots.append([now, net_position, net_yaw, net_pitch])
	while _snapshots.size() > 12:
		_snapshots.pop_front()
	_synced_once = true


## Zeigt die Figur INTERP_DELAY hinter dem neuesten Paket, zwischen zwei Paketen gemischt.
func _apply_snapshot() -> void:
	if _snapshots.is_empty():
		return
	var render_time := Time.get_ticks_msec() / 1000.0 - INTERP_DELAY
	var from: Array = _snapshots[0]
	var to: Array = from
	for i in range(1, _snapshots.size()):
		to = _snapshots[i]
		if float(to[0]) >= render_time:
			break
		from = to
	var t := 1.0
	var span := float(to[0]) - float(from[0])
	if span > 0.0001:
		t = clampf((render_time - float(from[0])) / span, 0.0, 1.0)
	# Alte Pakete wegwerfen, eins davor bleibt zum Mischen.
	while _snapshots.size() > 2 and float(_snapshots[1][0]) < render_time:
		_snapshots.pop_front()
	_player.global_position = (from[1] as Vector3).lerp(to[1], t)
	_player.rotation.y = lerp_angle(float(from[2]), float(to[2]), t)
	_player.head.rotation.x = lerpf(float(from[3]), float(to[3]), t)


func _apply_held() -> void:
	_body.set_held_item(_held_item())


func _held_item() -> ItemData:
	if net_held.is_empty() or not ResourceLoader.exists(ITEM_PATH % net_held):
		return null
	return load(ITEM_PATH % net_held) as ItemData


func _on_remote_shot() -> void:
	if _body != null:
		_body.trigger_fire()
	var weapon := _held_item() as WeaponData
	if weapon != null and weapon.fire_sound != null and _shot_audio != null:
		_shot_audio.stream = weapon.fire_sound
		_shot_audio.pitch_scale = randf_range(0.95, 1.05)
		_shot_audio.play()


## Schritt der fremden Figur, leiser beim Hocken, lauter beim Rennen.
func _on_step() -> void:
	var sounds := _player.footstep_sounds
	if sounds.is_empty() or _player.footsteps == null:
		return
	_last_step = (_last_step + 1 + randi() % maxi(sounds.size() - 1, 1)) % sounds.size()
	var speed := Vector2(net_velocity.x, net_velocity.z).length()
	var loud := clampf((speed - 2.0) / 6.0, 0.0, 1.0)
	_player.footsteps.stream = sounds[_last_step]
	_player.footsteps.volume_db = lerpf(_player.walk_volume_db, _player.sprint_volume_db, loud) \
		- 12.0 * net_crouch
	_player.footsteps.pitch_scale = lerpf(1.0, _player.sprint_pitch, loud) * randf_range(0.95, 1.05)
	_player.footsteps.play()
