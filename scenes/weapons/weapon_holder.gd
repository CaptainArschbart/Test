class_name WeaponHolder
extends Node3D
## Waffe in der Hand. Sitzt unter %PlayerHands, wackelt also mit den Händen mit.
##
## Liegt im gewählten Hotbar-Slot eine WeaponData, wird deren view_scene gezeigt.
## "fire" (linke Maustaste) schießt einen Strahl aus der Bildschirmmitte (Hitscan,
## Layer world). Getroffene Knoten mit take_hit(damage, point, normal) bekommen den
## Schaden. "reload" (R, belegbar) füllt das Magazin; Reservemunition gibt es noch nicht.
## Waffen mit `automatic` (SMG) schießen, solange "fire" gehalten wird; jeder Schuss vergrößert
## die Streuung (bloom) und lässt den Rückstoß klettern, ohne Schießen geht beides zurück.
## Hat die Waffenszene einen Knoten "Magazine", fällt er beim Nachladen heraus und kommt
## wieder (die linke Hand folgt dem Marker "Magazine/HandReloadLeft"). Ein Marker3D "Eject"
## wirft mit `eject_shells` Hülsen aus.
## "aim" (rechte Maustaste halten) zielt: Kamera zoomt auf aim_fov, die Waffe rückt mit
## sight_offset in die Bildmitte, Streuung fällt weg und die Maus wird langsamer
## (Player fragt get_look_scale()). Waffen mit has_scope zeigen dann das Zielfernrohr.
## Munitionsanzeige und Zielfernrohr werden im Code erzeugt, damit player.tscn klein bleibt.

const SCOPE_SHADER := preload("res://scenes/weapons/scope_overlay.gdshader")

## Wie schnell das Modell nach dem Rückstoß zurückkommt.
@export var recoil_return := 14.0
## Wie lange Mündungsfeuer und Licht zu sehen sind.
@export var flash_time := 0.05

const IMPACT_COLOR := Color(1.0, 0.75, 0.3)
## Höchstens so viele Hülsen liegen gleichzeitig herum, die ältesten verschwinden zuerst.
const MAX_SHELLS := 30
const SHELL_LIFETIME := 2.5

## Ein Schuss ist raus (für PlayerAvatarSync: andere Spieler sehen Rückstoß und Mündungsfeuer).
signal fired

var _player: Player
var _weapon: WeaponData
var _view: Node3D
var _flash: Node3D
var _flash_light: Light3D
## Munition im Magazin je Waffen-id, damit Wechseln den Stand behält.
var _ammo := {}
var _cooldown := 0.0
var _reload_left := 0.0
var _flash_left := 0.0
var _recoil := 0.0
## Zusätzliche Streuung durch Dauerfeuer (Grad).
var _bloom := 0.0
## "fire" wurde von dieser Waffe angenommen und ist noch gedrückt (Dauerfeuer).
var _trigger := false
var _magazine: Node3D
var _magazine_base := Transform3D.IDENTITY
var _shells: Array[Node3D] = []
var _audio: AudioStreamPlayer
## Schüsse laufen über mehrere Player, damit sich Dauerfeuer nicht selbst abschneidet.
var _shot_audio: Array[AudioStreamPlayer] = []
var _shot_index := 0
var _ammo_label: Label
var _scope: ColorRect
## 0 = aus der Hüfte, 1 = voll im Anschlag.
var _aim := 0.0
var _base_transform: Transform3D
var _base_fov := 80.0


func _ready() -> void:
	_player = _find_player()
	if _player == null:
		push_error("WeaponHolder braucht einen Player über sich.")
		return
	_base_transform = transform
	_audio = AudioStreamPlayer.new()
	_audio.bus = &"SFX"
	add_child(_audio)
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_shot_audio.append(player)
	_create_ammo_hud()
	_create_scope()
	# Kinder sind vor dem Player fertig; inventory ist erst danach gesetzt.
	if not _player.is_node_ready():
		await _player.ready
	_base_fov = _player.camera.fov
	_player.inventory.changed.connect(_update_weapon)
	_player.inventory.selected_changed.connect(_update_weapon.unbind(1))
	_update_weapon()


func _unhandled_input(event: InputEvent) -> void:
	# Läuft vor Player._unhandled_input: der Klick, der die Maus erst einfängt, schießt nicht.
	if _weapon == null or event.is_echo() or not _can_use():
		return
	if event.is_action_pressed("fire"):
		get_viewport().set_input_as_handled()
		_trigger = true
		try_fire()
	elif event.is_action_pressed("reload"):
		get_viewport().set_input_as_handled()
		start_reload()


func _process(delta: float) -> void:
	_cooldown -= delta
	if _trigger and (not Input.is_action_pressed("fire") or _weapon == null or not _can_use()):
		_trigger = false
	# Dauerfeuer: Restzeit wird mitgenommen, damit die Feuerrate nicht an der Bildrate hängt.
	if _trigger and _weapon.automatic:
		while _cooldown <= 0.0 and get_ammo() > 0 and try_fire():
			pass
	_cooldown = maxf(_cooldown, 0.0)
	if _weapon != null and _weapon.max_bloom_degrees > 0.0 and not (_trigger and _weapon.automatic):
		_bloom = move_toward(_bloom, 0.0, _weapon.bloom_recovery * delta)
	elif _weapon != null:
		_bloom = move_toward(_bloom, 0.0, _weapon.bloom_recovery * 0.15 * delta)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_flash(false)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
	_recoil = lerpf(_recoil, 0.0, minf(recoil_return * delta, 1.0))
	_update_aim(delta)
	if _view != null:
		# Beim Boxen mit "melee" ist die Waffe kurz weggesteckt.
		_view.visible = not _holstered()
		_view.position = Vector3(0.0, _recoil * 0.3, _recoil)
		_view.rotation.x = _recoil * 3.0
		# Beim Nachladen kippt die Waffe nach unten weg.
		if _reload_left > 0.0 and _weapon != null:
			var t := get_reload_progress()
			_view.rotation.x -= sin(t * PI) * _weapon.reload_tilt
			_view.rotation.z = sin(t * PI) * _weapon.reload_roll
		else:
			_view.rotation.z = 0.0
		_update_magazine()
	# Gedrückt halten schießt nicht automatisch, aber ein leeres Magazin lädt von selbst.
	if _weapon != null and get_ammo() == 0 and _reload_left <= 0.0 and _cooldown <= 0.0 \
			and not _player.input_locked:
		start_reload()


## Ein Schuss, wenn Munition da ist und die Waffe bereit ist. Gibt true zurück, wenn geschossen wurde.
func try_fire() -> bool:
	if _weapon == null or _cooldown > 0.0 or _reload_left > 0.0:
		return false
	if get_ammo() <= 0:
		_play(_weapon.empty_sound)
		_cooldown = _weapon.fire_interval
		_trigger = false
		return false
	_ammo[_weapon.id] = get_ammo() - 1
	# Negativer Rest (Dauerfeuer zwischen zwei Bildern) wird angerechnet.
	_cooldown = minf(_cooldown, 0.0) + _weapon.fire_interval
	_recoil = _weapon.recoil_kick
	_flash_left = flash_time
	_set_flash(true)
	_play_shot(_weapon.fire_sound, randf_range(0.95, 1.05))
	# Gegner hören den Schuss.
	if _player.stealth != null:
		_player.stealth.make_noise(_weapon.noise_radius, StealthNoise.SHOT)
	_shoot_ray()
	if _weapon.eject_shells:
		_eject_shell()
	fired.emit()
	# Kamera springt erst nach dem Strahl hoch, sonst ginge der Schuss daneben.
	var heat := get_heat()
	var kick := _weapon.view_kick_degrees * (1.0 + _weapon.recoil_climb * heat)
	_player.head.rotation.x = clampf(_player.head.rotation.x + deg_to_rad(kick),
		-deg_to_rad(_player.max_pitch_degrees), deg_to_rad(_player.max_pitch_degrees))
	if _weapon.view_kick_horizontal_degrees > 0.0:
		_player.rotate_y(deg_to_rad(randf_range(-1.0, 1.0) * _weapon.view_kick_horizontal_degrees * (0.35 + heat)))
	if _weapon.max_bloom_degrees > 0.0:
		_bloom = minf(_bloom + _weapon.bloom_per_shot, _weapon.max_bloom_degrees)
	_update_hud()
	return true


func start_reload() -> void:
	if _weapon == null or _reload_left > 0.0 or get_ammo() >= _weapon.magazine_size:
		return
	_reload_left = _weapon.reload_time
	_play(_weapon.reload_sound)
	_update_hud()


## 0 = ruhig, 1 = volle Dauerfeuer-Streuung.
func get_heat() -> float:
	if _weapon == null or _weapon.max_bloom_degrees <= 0.0:
		return 0.0
	return clampf(_bloom / _weapon.max_bloom_degrees, 0.0, 1.0)


## Aktuelle Streuung in Grad (Hüfte/Anschlag plus Dauerfeuer).
func get_spread_degrees() -> float:
	if _weapon == null:
		return 0.0
	var base := lerpf(_weapon.hip_spread_degrees, _weapon.aim_spread_degrees, _aim)
	return base + _bloom * lerpf(1.0, _weapon.aim_bloom_factor, _aim)


func get_ammo() -> int:
	if _weapon == null:
		return 0
	return _ammo.get(_weapon.id, _weapon.magazine_size)


## 0 = Hüfte, 1 = voll im Anschlag.
func get_aim() -> float:
	return _aim


## Faktor auf die Mausempfindlichkeit: beim Zielen im Verhältnis der Sichtfelder langsamer.
func get_look_scale() -> float:
	if _weapon == null or _aim <= 0.0 or _player == null:
		return 1.0
	var zoomed := _player.camera.fov / _base_fov
	return lerpf(1.0, zoomed * _weapon.aim_sensitivity, _aim)


func get_weapon() -> WeaponData:
	return _weapon


func is_reloading() -> bool:
	return _reload_left > 0.0


## Fortschritt beim Nachladen 0…1, -1 = lädt nicht nach.
func get_reload_progress() -> float:
	if _reload_left <= 0.0 or _weapon == null:
		return -1.0
	return clampf(1.0 - _reload_left / maxf(_weapon.reload_time, 0.001), 0.0, 1.0)


func _finish_reload() -> void:
	_reload_left = 0.0
	if _weapon != null:
		_ammo[_weapon.id] = _weapon.magazine_size
	_update_hud()


func _shoot_ray() -> void:
	var camera := _player.camera
	var from := camera.global_position
	var direction := -camera.global_basis.z
	# Streuung: zufällig im Kegel, aus der Hüfte und beim Dauerfeuer größer.
	var spread := deg_to_rad(get_spread_degrees())
	if spread > 0.0:
		var angle := randf() * TAU
		var amount := sqrt(randf()) * spread
		var axis := camera.global_basis.x * cos(angle) + camera.global_basis.y * sin(angle)
		direction = direction.rotated(axis.normalized(), amount)
	var to := from + direction * _weapon.max_range
	# Layer world und player: andere Spieler sind im Multiplayer treffbar, die eigene Figur nicht.
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [_player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	if collider != null and collider.has_method("take_hit"):
		collider.take_hit(_weapon.damage, hit.position, hit.normal)
	var body := collider is CharacterBody3D
	_show_impact(hit.position, hit.normal, body)
	if WorldSync.is_online():
		_remote_impact.rpc(hit.position, hit.normal, body)


## Einschlag eines Schusses dieses Spielers auf den anderen Rechnern.
@rpc("any_peer", "unreliable", "call_remote")
func _remote_impact(point: Vector3, normal: Vector3, body: bool) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	_show_impact(point, normal, body)


func _show_impact(point: Vector3, normal: Vector3, body: bool) -> void:
	_spawn_impact(point, normal)
	# Treffer auf Körper zeigen keinen Staub, sondern nur den Funken.
	if not body:
		_spawn_debris(point, normal)


## Kurzer Funke am Einschlag, verschwindet nach 0,15 s.
func _spawn_impact(point: Vector3, normal: Vector3) -> void:
	var spark := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = IMPACT_COLOR
	mesh.material = material
	spark.mesh = mesh
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(spark)
	spark.global_position = point + normal * 0.02
	var tween := spark.create_tween()
	tween.tween_property(spark, "scale", Vector3.ONE * 0.2, 0.15)
	tween.tween_callback(spark.queue_free)


## Ein paar Splitter und etwas Staub, die vom Einschlag wegspritzen (CPU-Partikel, laufen auch
## im Kompatibilitäts-Renderer).
func _spawn_debris(point: Vector3, normal: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 8
	particles.lifetime = 0.45
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 35.0
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 3.0
	particles.gravity = Vector3(0.0, -9.0, 0.0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.015
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.5, 0.45)
	material.emission_enabled = true
	material.emission = IMPACT_COLOR
	material.emission_energy_multiplier = 0.6
	mesh.material = material
	particles.mesh = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(particles)
	particles.global_position = point + normal * 0.03
	# Partikel fliegen entlang der Flächennormale.
	if absf(normal.dot(Vector3.UP)) < 0.99:
		particles.look_at(particles.global_position + normal, Vector3.UP)
		particles.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)


## Messinghülse fliegt rechts aus dem Auswurf, prallt in der Welt ab und verschwindet wieder.
func _eject_shell() -> void:
	if _view == null:
		return
	var eject := _view.get_node_or_null("Eject") as Node3D
	if eject == null:
		return
	var shell := RigidBody3D.new()
	shell.collision_layer = 0
	shell.collision_mask = 1
	shell.mass = 0.01
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.01, 0.01, 0.022)
	shape.shape = box
	shell.add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0045
	mesh.bottom_radius = 0.005
	mesh.height = 0.02
	mesh.radial_segments = 6
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.62, 0.25)
	material.metallic = 0.9
	material.roughness = 0.3
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.rotation.x = PI * 0.5
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.add_child(mesh_instance)
	get_tree().current_scene.add_child(shell)
	shell.global_transform = eject.global_transform
	var basis := _player.camera.global_basis
	shell.linear_velocity = _player.velocity + basis.x * randf_range(1.6, 2.4) \
		+ basis.y * randf_range(1.0, 1.6) + basis.z * randf_range(0.0, 0.4)
	shell.angular_velocity = Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	_shells.append(shell)
	while _shells.size() > MAX_SHELLS:
		var old: Node3D = _shells.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	get_tree().create_timer(SHELL_LIFETIME).timeout.connect(func() -> void:
		if is_instance_valid(shell):
			_shells.erase(shell)
			shell.queue_free())


## Magazin fällt heraus (0–35 %), bleibt unten, während die Hand das neue holt, und wird wieder
## eingesetzt (55–85 %). Ohne Nachladen sitzt es an seinem Platz.
func _update_magazine() -> void:
	if _magazine == null:
		return
	var t := get_reload_progress()
	var out := 0.0
	if t > 0.0:
		if t < 0.35:
			out = ease(t / 0.35, 2.0)
		elif t < 0.55:
			out = 1.0
		elif t < 0.85:
			out = 1.0 - ease((t - 0.55) / 0.3, 0.5)
	var drop := Transform3D(Basis(Vector3.RIGHT, -0.35 * out), Vector3(-0.03 * out, -0.2 * out, 0.04 * out))
	_magazine.transform = Transform3D(drop.basis * _magazine_base.basis, _magazine_base.origin + drop.origin)


func _update_weapon() -> void:
	var item := _player.inventory.get_selected_item()
	var weapon := item as WeaponData
	if weapon == _weapon:
		return
	_weapon = weapon
	_reload_left = 0.0
	_recoil = 0.0
	_bloom = 0.0
	_trigger = false
	_aim = 0.0
	_apply_aim()
	if _view != null:
		_view.queue_free()
		_view = null
	_flash = null
	_flash_light = null
	_magazine = null
	if _weapon != null and _weapon.view_scene != null:
		_view = _weapon.view_scene.instantiate()
		add_child(_view)
		_flash = _view.get_node_or_null("Muzzle/Flash")
		_flash_light = _view.get_node_or_null("Muzzle/FlashLight")
		_magazine = _view.get_node_or_null("Magazine") as Node3D
		if _magazine != null:
			_magazine_base = _magazine.transform
	_set_flash(false)
	_update_hud()


func _update_aim(delta: float) -> void:
	var wants := _weapon != null and _reload_left <= 0.0 and _can_use() \
		and Input.is_action_pressed("aim")
	var speed := 1.0 / maxf(_weapon.aim_time, 0.01) if _weapon != null else 10.0
	_aim = move_toward(_aim, 1.0 if wants else 0.0, speed * delta)
	_apply_aim()


## Setzt Sichtfeld, Waffenposition, Hände und Zielfernrohr passend zu _aim.
func _apply_aim() -> void:
	if _player == null or not _player.is_node_ready():
		return
	var t := ease(_aim, -2.0)
	var fov := _base_fov
	var scoped := false
	if _weapon != null:
		fov = lerpf(_base_fov, _weapon.aim_fov, t)
		var aim_transform := Transform3D(Basis(), Vector3(0.0, 0.0, -_weapon.aim_distance) - _weapon.sight_offset)
		var hip := _base_transform.translated_local(_weapon.hip_offset)
		transform = hip.interpolate_with(aim_transform, t)
		scoped = _weapon.has_scope and _aim > 0.85
	else:
		transform = _base_transform
	if _player.melee != null:
		fov += _player.melee.get_fov_offset()
	_player.camera.fov = fov
	_player.hands.motion_scale = 1.0 - t * 0.85
	_player.hands.visible = not scoped
	if _scope != null:
		_scope.visible = scoped


func _set_flash(on: bool) -> void:
	if _flash != null:
		_flash.visible = on
		_flash.rotation.z = randf() * TAU
	if _flash_light != null:
		_flash_light.visible = on


func _can_use() -> bool:
	return _player.controls_local_body() and not _player.input_locked and not _player.noclip \
			and _player.pointer_captured() and not get_tree().paused and not _holstered()


func _holstered() -> bool:
	return _player.melee != null and _player.melee.is_holstering()


func _play(stream: AudioStream, pitch := 1.0) -> void:
	if stream == null:
		return
	_audio.stream = stream
	_audio.pitch_scale = pitch
	_audio.play()


func _play_shot(stream: AudioStream, pitch: float) -> void:
	if stream == null or _shot_audio.is_empty():
		return
	var player := _shot_audio[_shot_index]
	_shot_index = (_shot_index + 1) % _shot_audio.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


func _create_ammo_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AmmoHud"
	layer.layer = 2
	add_child(layer)
	_ammo_label = Label.new()
	_ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_label.anchor_left = 1.0
	_ammo_label.anchor_top = 1.0
	_ammo_label.anchor_right = 1.0
	_ammo_label.anchor_bottom = 1.0
	_ammo_label.offset_left = -300.0
	_ammo_label.offset_top = -78.0
	_ammo_label.offset_right = -28.0
	_ammo_label.offset_bottom = -24.0
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_ammo_label.add_theme_font_size_override("font_size", 30)
	_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.15))
	_ammo_label.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.2))
	_ammo_label.add_theme_constant_override("outline_size", 6)
	_ammo_label.visible = false
	layer.add_child(_ammo_label)


func _create_scope() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ScopeOverlay"
	layer.layer = 1
	add_child(layer)
	_scope = ColorRect.new()
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = SCOPE_SHADER
	_scope.material = material
	_scope.visible = false
	layer.add_child(_scope)


func _update_hud() -> void:
	if _ammo_label == null:
		return
	_ammo_label.visible = _weapon != null
	if _weapon == null:
		return
	if _reload_left > 0.0:
		_ammo_label.text = "NACHLADEN …"
	else:
		_ammo_label.text = "%d / %d" % [get_ammo(), _weapon.magazine_size]
		var empty := get_ammo() == 0
		_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.3) if empty else Color(1.0, 0.6, 0.15))


func _find_player() -> Player:
	var node: Node = self
	while node != null:
		if node is Player:
			return node as Player
		node = node.get_parent()
	return null
