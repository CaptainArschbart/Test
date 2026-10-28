class_name WeaponHolder
extends Node3D
## Waffe in der Hand. Sitzt unter %PlayerHands, wackelt also mit den Händen mit.
##
## Liegt im gewählten Hotbar-Slot eine WeaponData, wird deren view_scene gezeigt.
## "fire" (linke Maustaste) schießt einen Strahl aus der Bildschirmmitte (Hitscan,
## Layer world). Getroffene Knoten mit take_hit(damage, point, normal) bekommen den
## Schaden. "reload" (R, belegbar) füllt das Magazin; Reservemunition gibt es noch nicht.
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
var _audio: AudioStreamPlayer
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
		try_fire()
	elif event.is_action_pressed("reload"):
		get_viewport().set_input_as_handled()
		start_reload()


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
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
			var t := 1.0 - _reload_left / _weapon.reload_time
			_view.rotation.x -= sin(t * PI) * 0.9
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
		return false
	_ammo[_weapon.id] = get_ammo() - 1
	_cooldown = _weapon.fire_interval
	_recoil = _weapon.recoil_kick
	_flash_left = flash_time
	_set_flash(true)
	_play(_weapon.fire_sound, randf_range(0.95, 1.05))
	# Gegner hören den Schuss.
	if _player.stealth != null:
		_player.stealth.make_noise(_weapon.noise_radius, StealthNoise.SHOT)
	_shoot_ray()
	# Kamera springt erst nach dem Strahl hoch, sonst ginge der Schuss daneben.
	_player.head.rotation.x = clampf(_player.head.rotation.x + deg_to_rad(_weapon.view_kick_degrees),
		-deg_to_rad(_player.max_pitch_degrees), deg_to_rad(_player.max_pitch_degrees))
	_update_hud()
	return true


func start_reload() -> void:
	if _weapon == null or _reload_left > 0.0 or get_ammo() >= _weapon.magazine_size:
		return
	_reload_left = _weapon.reload_time
	_play(_weapon.reload_sound)
	_update_hud()


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


func _finish_reload() -> void:
	_reload_left = 0.0
	if _weapon != null:
		_ammo[_weapon.id] = _weapon.magazine_size
	_update_hud()


func _shoot_ray() -> void:
	var camera := _player.camera
	var from := camera.global_position
	var direction := -camera.global_basis.z
	# Streuung aus der Hüfte: zufällig im Kegel, beim Zielen keine.
	var spread := deg_to_rad(_weapon.hip_spread_degrees) * (1.0 - _aim)
	if spread > 0.0:
		var angle := randf() * TAU
		var amount := sqrt(randf()) * spread
		var axis := camera.global_basis.x * cos(angle) + camera.global_basis.y * sin(angle)
		direction = direction.rotated(axis.normalized(), amount)
	var to := from + direction * _weapon.max_range
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [_player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	if collider != null and collider.has_method("take_hit"):
		collider.take_hit(_weapon.damage, hit.position, hit.normal)
	_spawn_impact(hit.position, hit.normal)


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


func _update_weapon() -> void:
	var item := _player.inventory.get_selected_item()
	var weapon := item as WeaponData
	if weapon == _weapon:
		return
	_weapon = weapon
	_reload_left = 0.0
	_recoil = 0.0
	_aim = 0.0
	_apply_aim()
	if _view != null:
		_view.queue_free()
		_view = null
	_flash = null
	_flash_light = null
	if _weapon != null and _weapon.view_scene != null:
		_view = _weapon.view_scene.instantiate()
		add_child(_view)
		_flash = _view.get_node_or_null("Muzzle/Flash")
		_flash_light = _view.get_node_or_null("Muzzle/FlashLight")
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
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused and not _holstered()


func _holstered() -> bool:
	return _player.melee != null and _player.melee.is_holstering()


func _play(stream: AudioStream, pitch := 1.0) -> void:
	if stream == null:
		return
	_audio.stream = stream
	_audio.pitch_scale = pitch
	_audio.play()


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
