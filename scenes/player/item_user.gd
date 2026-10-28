class_name ItemUser
extends Node3D
## Benutzen und Item-Aktionen des Spielers. Sitzt unter %PlayerHands, wackelt also mit.
##
## "interact" (E, belegbar): Strahl aus der Bildschirmmitte bis interact_range. Trifft er
## einen Knoten mit interact(player) (Pickups auf Layer interact, Automaten auf world),
## steht unter dem Fadenkreuz "[E] …" aus get_interact_text(player).
## "use_item" (Rechtsklick): ConsumableData im gewählten Slot wird verbraucht.
## "fire" (Linksklick): GrenadeData wird geworfen, MeleeData schlägt zu.
## Schusswaffen (WeaponData) bleiben beim WeaponHolder; Rechtsklick auf Waffen ist frei fürs Zielen.
## Die Anzeigen werden im Code erzeugt, damit player.tscn klein bleibt.

## Reichweite für "interact" in Metern.
@export var interact_range := 2.6

const LAYER_WORLD := 1
const LAYER_INTERACT := 4
const GRENADE_SCRIPT := preload("res://scenes/items/grenade.gd")

## Granate geworfen oder mit der Klinge zugeschlagen (für PlayerAvatarSync).
signal action_performed

var _player: Player
var _item: ItemData
var _target: Object
var _cooldown := 0.0
var _swing := 0.0
var _held: Node3D
var _prompt: Label
var _message: Label
var _boost_label: Label
var _message_tween: Tween


func _ready() -> void:
	_player = _find_player()
	if _player == null:
		push_error("ItemUser braucht einen Player über sich.")
		return
	_create_hud()
	if not _player.is_node_ready():
		await _player.ready
	_player.inventory.changed.connect(_update_item)
	_player.inventory.selected_changed.connect(_update_item.unbind(1))
	_update_item()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or event.is_echo() or not _can_use():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interact()
	elif event.is_action_pressed("use_item") and _item is ConsumableData:
		get_viewport().set_input_as_handled()
		use_selected()
	elif event.is_action_pressed("fire") and (_item is GrenadeData or _item is MeleeData):
		get_viewport().set_input_as_handled()
		use_selected()


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	_target = find_target() if _can_use() else null
	var text := ""
	if _target != null:
		text = _target.get_interact_text(_player)
	_prompt.visible = text != ""
	if _prompt.visible:
		_prompt.text = "[%s] %s" % [_action_key("interact"), text]


func _process(delta: float) -> void:
	if _player == null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_swing = maxf(_swing - delta * 5.0, 0.0)
	if _held != null:
		# Klinge schwingt von rechts oben nach links unten, Granate holt aus.
		var t := sin(_swing * PI)
		_held.rotation = Vector3(-t * 1.2, t * 0.6, t * 0.9)
		_held.position = Vector3(-t * 0.12, t * 0.05, -t * 0.08)
	var boost := _player.stats.get_boost_left()
	_boost_label.visible = boost > 0.0
	if _boost_label.visible:
		_boost_label.text = "OVERDRIVE %ds" % ceili(boost)


## Das, was der Spieler gerade anschaut und benutzen kann, sonst null.
func find_target() -> Object:
	var camera := _player.camera
	var from := camera.global_position
	var to := from - camera.global_basis.z * interact_range
	var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD | LAYER_INTERACT,
		[_player.get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var node := hit.collider as Node
	# Das Skript kann auch am Elternknoten der Kollision hängen.
	while node != null and node != get_tree().current_scene:
		if node.has_method("interact") and node.has_method("get_interact_text"):
			return node
		node = node.get_parent()
	return null


## E: benutzt das angeschaute Objekt. Gibt true zurück, wenn etwas da war.
func interact() -> bool:
	var target := find_target()
	if target == null or target.get_interact_text(_player) == "":
		return false
	target.interact(_player)
	return true


## Benutzt das Item im gewählten Hotbar-Slot. Gibt true zurück, wenn etwas passiert ist.
func use_selected() -> bool:
	var item := _player.inventory.get_selected_item()
	if item == null or _cooldown > 0.0:
		return false
	if item is ConsumableData:
		return _consume(item)
	if item is GrenadeData:
		return _throw(item)
	if item is MeleeData:
		return _strike(item)
	return false


## Klinge oder Granate in der Hand (für die Griffpose der Hände), sonst null.
func get_held_view() -> Node3D:
	return _held


func get_held_item() -> ItemData:
	return _item


## Kurze Meldung unter dem Fadenkreuz, z. B. "NeoCola getrunken".
func show_message(text: String, color := Color(0.0, 1.0, 0.95)) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)
	if _message_tween:
		_message_tween.kill()
	_message.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(1.4)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.5)


func _consume(item: ConsumableData) -> bool:
	var stats := _player.stats
	if not stats.is_alive():
		return false
	_player.inventory.remove_at(_player.inventory.selected)
	if item.heal > 0.0:
		stats.heal(item.heal)
	if item.stamina > 0.0:
		stats.add_stamina(item.stamina)
	if item.food > 0.0:
		stats.eat(item.food)
	if item.water > 0.0:
		stats.drink(item.water)
	if item.speed_multiplier != 1.0 and item.boost_duration > 0.0:
		stats.boost_speed(item.speed_multiplier, item.boost_duration)
	_cooldown = 0.35
	show_message("%s %s" % [item.display_name, item.use_verb], item.color)
	return true


func _throw(item: GrenadeData) -> bool:
	_player.inventory.remove_at(_player.inventory.selected)
	var camera := _player.camera
	var forward := -camera.global_basis.z
	var grenade: ThrownGrenade = GRENADE_SCRIPT.new()
	grenade.data = item
	grenade.thrower = _player
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = camera.global_position + forward * 0.5 + Vector3.DOWN * 0.1
	grenade.linear_velocity = forward * item.throw_speed + Vector3.UP * 3.0 \
		+ Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	grenade.add_collision_exception_with(_player)
	_cooldown = item.throw_interval
	_swing = 1.0
	action_performed.emit()
	return true


func _strike(item: MeleeData) -> bool:
	_cooldown = item.swing_interval
	_swing = 1.0
	action_performed.emit()
	var camera := _player.camera
	var from := camera.global_position
	var to := from - camera.global_basis.z * item.reach
	var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD, [_player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.collider
		if collider != null and collider.has_method("take_hit"):
			collider.take_hit(item.damage, hit.position, hit.normal)
	return true


## Zeigt Klinge oder Granate in der Hand. Schusswaffen zeichnet der WeaponHolder.
func _update_item() -> void:
	var item := _player.inventory.get_selected_item()
	if item == _item:
		return
	_item = item
	_swing = 0.0
	if _held != null:
		_held.queue_free()
		_held = null
	if item is MeleeData:
		_held = _make_held(BoxMesh.new(), item.color)
		(_held.get_child(0) as MeshInstance3D).mesh.size = Vector3(0.015, 0.03, 0.5)
		_held.get_child(0).position = Vector3(0.0, 0.0, -0.22)
	elif item is GrenadeData:
		_held = _make_held(SphereMesh.new(), item.color)
		var mesh: SphereMesh = (_held.get_child(0) as MeshInstance3D).mesh
		mesh.radius = 0.045
		mesh.height = 0.09
	if _held != null:
		add_child(_held)


func _make_held(mesh: Mesh, color: Color) -> Node3D:
	var root := Node3D.new()
	var instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	mesh.material = material
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Wie die Hände: das Fülllicht der Hände beleuchtet nur diese Ebene.
	instance.layers |= PlayerHands.VIEWMODEL_LAYER
	root.add_child(instance)
	return root


func _can_use() -> bool:
	return _player.controls_local_body() and not _player.input_locked and not _player.noclip \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused


## Name der ersten Taste einer Aktion, z. B. "E".
func _action_key(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			return Settings.key_name(code)
	return action


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ItemHud"
	layer.layer = 2
	add_child(layer)
	_prompt = _make_label(layer, 40.0, 20, Color(1.0, 1.0, 1.0))
	_message = _make_label(layer, 70.0, 18, Color(0.0, 1.0, 0.95))
	_message.modulate.a = 0.0
	_boost_label = _make_label(layer, -150.0, 18, Color(1.0, 0.55, 0.1))
	_boost_label.visible = false
	_prompt.visible = false


## Zentrierte Zeile, `offset` Pixel unter (bzw. über) der Bildschirmmitte.
func _make_label(parent: Node, offset: float, size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -300.0
	label.offset_right = 300.0
	label.offset_top = offset
	label.offset_bottom = offset + 30.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.2))
	label.add_theme_constant_override("outline_size", 5)
	parent.add_child(label)
	return label


func _find_player() -> Player:
	var node: Node = self
	while node != null:
		if node is Player:
			return node as Player
		node = node.get_parent()
	return null
