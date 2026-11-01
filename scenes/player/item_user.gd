class_name ItemUser
extends Node3D
## Benutzen und Item-Aktionen des Spielers. Sitzt unter %PlayerHands, wackelt also mit.
##
## "interact" (E, belegbar): Strahl aus der Bildschirmmitte bis interact_range. Trifft er
## einen Knoten mit interact(player) (Pickups auf Layer interact, Automaten auf world),
## steht unter dem Fadenkreuz "[E] …" aus get_interact_text(player).
## "use_item" (Rechtsklick): ConsumableData im gewählten Slot wird verbraucht. Mit use_animation
## läuft erst die Benutz-Animation (ConsumableUse), der Effekt greift an ihrem Ende.
## Verbrauchsitems mit Modell (ConsumableModel) liegen sichtbar in der rechten Hand.
## "fire" (Linksklick): GrenadeData wird geworfen, MeleeData schlägt zu.
## Wurf: Ausholen (THROW_WINDUP), Loslassen, Durchschwingen; die rechte Hand folgt der Granate.
## Ist eine Granate gewählt, zeigt unten rechts die Anzeige, wie viele davon im Inventar sind.
## Schusswaffen (WeaponData) bleiben beim WeaponHolder; Rechtsklick auf Waffen ist frei fürs Zielen.
## Die Anzeigen werden im Code erzeugt, damit player.tscn klein bleibt.

## Reichweite für "interact" in Metern.
@export var interact_range := 2.6

const LAYER_WORLD := 1
## Andere Spielerfiguren (Multiplayer), damit Klinge und Waffen sie treffen.
const LAYER_PLAYER := 2
const LAYER_INTERACT := 4
const GRENADE_SCRIPT := preload("res://scenes/items/grenade.gd")
## Per preload statt class_name: Nach einem Pull kennt der Klassen-Cache neue Klassen erst nach einem
## Editor-Scan, sonst kompiliert der ganze Spieler nicht.
const PICKPOCKET_BAR := preload("res://scenes/crime/pickpocket_bar.gd")
## Wurfablauf in Sekunden: Ausholen bis zum Loslassen, danach Durchschwingen.
const THROW_WINDUP := 0.16
const THROW_FOLLOW := 0.3

## Granate geworfen oder mit der Klinge zugeschlagen (für PlayerAvatarSync).
signal action_performed

var _player: Player
var _item: ItemData
var _target: Object
var _cooldown := 0.0
var _swing := 0.0
var _held: Node3D
var _prompt: Label
var _pick_bar: PICKPOCKET_BAR
var _message: Label
var _boost_label: Label
var _message_tween: Tween
var _use: ConsumableUse
## 1 = gehaltenes Verbrauchsitem ganz unten (kommt nach dem Benutzen neu ins Bild), 0 = in der Hand.
var _raise := 0.0
var _grenade_label: Label
var _audio: AudioStreamPlayer
## Läuft ein Wurf: Zeit seit dem Klick, sonst -1.
var _throw_time := -1.0
var _throw_item: GrenadeData
## Inventar hat sich während des Wurfs geändert: danach das Item neu anzeigen.
var _pending_update := false


func _ready() -> void:
	_player = _find_player()
	if _player == null:
		push_error("ItemUser braucht einen Player über sich.")
		return
	_create_hud()
	_audio = AudioStreamPlayer.new()
	_audio.bus = &"SFX"
	add_child(_audio)
	if not _player.is_node_ready():
		await _player.ready
	_use = ConsumableUse.new()
	_use.name = "ConsumableUse"
	add_child(_use)
	_use.setup(_player, self)
	_use.finished.connect(_on_use_finished)
	_player.inventory.changed.connect(_update_item)
	_player.inventory.changed.connect(_update_grenade_hud)
	_player.inventory.selected_changed.connect(_update_item.unbind(1))
	_player.inventory.selected_changed.connect(_update_grenade_hud.unbind(1))
	_update_item()
	_update_grenade_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or event.is_echo() or not _can_use():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		interact()
	elif event.is_action_pressed("use_item") and _item is ConsumableData:
		get_viewport().set_input_as_handled()
		if not is_using_consumable():
			use_selected()
	elif event.is_action_pressed("fire") and (_item is GrenadeData or _item is MeleeData) \
			and (_player.melee == null or not _player.melee.is_busy()):
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
	var pick := CivilianCrime.picked_by(_player)
	_pick_bar.visible = pick != null
	if pick != null:
		_pick_bar.set_values(pick.pick_progress, pick.suspicion)


func _process(delta: float) -> void:
	if _player == null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_swing = maxf(_swing - delta * 5.0, 0.0)
	if _held != null:
		# Beim Boxen mit "melee" kurz weggesteckt.
		_held.visible = _player.melee == null or not _player.melee.is_holstering()
	if _throw_time >= 0.0:
		_update_throw(delta)
	elif _held != null and _item != null and ConsumableModel.has_model(_item.model):
		_raise = maxf(_raise - delta / 0.25, 0.0)
		var hold := ConsumableModel.hold_transform(_item.model)
		var low := smoothstep(0.0, 1.0, _raise)
		_held.transform = Transform3D(hold.basis, hold.origin + ConsumableUse.LOW_OFFSET * low)
		_held.visible = _held.visible and (_use == null or not _use.is_active())
	elif _held != null:
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
	_player.hands.wake()
	return true


## Benutzt das Item im gewählten Hotbar-Slot. Gibt true zurück, wenn etwas passiert ist.
func use_selected() -> bool:
	var item := _player.inventory.get_selected_item()
	if item == null or _cooldown > 0.0:
		return false
	# Im Stand ausgeblendete Hände kommen zum Benutzen hoch.
	_player.hands.wake()
	if item is ConsumableData:
		return _consume(item)
	if item is GrenadeData:
		return _throw(item)
	if item is MeleeData:
		return _strike(item)
	return false


## Klinge, Granate oder Verbrauchsitem in der Hand (für die Griffpose der Hände), sonst null.
## Während der Benutz-Animation ist es deren Modell.
func get_held_view() -> Node3D:
	if _use != null and _use.is_active():
		return _use.get_view()
	return _held


## Griff der rechten Hand im Raum des gehaltenen Modells (Verbrauchsitems), leer = PlayerHands entscheidet.
func get_held_grip() -> Dictionary:
	var item := _use_item_data()
	if item != null and ConsumableModel.has_model(item.model):
		return ConsumableModel.grip_pose(item.model)
	return {}


## Ziel der linken Hand während der Benutz-Animation: {"pose", "space", "follow"}, leer = locker.
func get_left_hand_target() -> Dictionary:
	if _use == null:
		return {}
	return _use.get_left_target()


## Läuft gerade eine Benutz-Animation (inklusive Wegstecken)?
func is_using_consumable() -> bool:
	return _use != null and _use.is_active()


func get_consumable_use() -> ConsumableUse:
	return _use


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
	if not _player.stats.is_alive():
		return false
	if item.use_animation != &"" and ConsumableUse.has_animation(item.use_animation) \
			and ConsumableModel.has_model(item.model):
		return _use.start(item, _player.inventory.selected)
	return apply_consumable(item, _player.inventory.selected)


## Verbraucht ein Stück aus `slot` und wendet die Werte an (von _consume direkt oder am Ende der
## Benutz-Animation). false, wenn der Slot das Item nicht mehr hat oder der Spieler tot ist.
func apply_consumable(item: ConsumableData, slot: int) -> bool:
	var stats := _player.stats
	if not stats.is_alive() or not item.is_same(_player.inventory.get_item(slot)):
		return false
	_player.inventory.remove_at(slot)
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


## Klick: Ausholen beginnt, die Granate fliegt erst am Ende des Ausholens los.
func _throw(item: GrenadeData) -> bool:
	if _throw_time >= 0.0:
		return false
	_throw_time = 0.0
	_throw_item = item
	_cooldown = item.throw_interval
	_play(item.throw_sound)
	return true


## Ablauf des Wurfs: Hand geht zurück und hoch, schnellt vor (Loslassen), schwingt durch und kommt
## zurück. Danach zeigt die Hand die nächste Granate oder ist leer.
func _update_throw(delta: float) -> void:
	var before := _throw_time
	_throw_time += delta
	if before < THROW_WINDUP and _throw_time >= THROW_WINDUP:
		_release(_throw_item)
	if _held != null:
		var pos := Vector3.ZERO
		var rot := Vector3.ZERO
		if _throw_time < THROW_WINDUP:
			var t := ease(_throw_time / THROW_WINDUP, 0.6)
			pos = Vector3(0.04, 0.1, 0.14) * t
			rot = Vector3(0.9, -0.2, 0.3) * t
		else:
			var t := clampf((_throw_time - THROW_WINDUP) / THROW_FOLLOW, 0.0, 1.0)
			# Schnell nach vorn unten, dann weich zurück in die Ruhelage.
			var forward := sin(minf(t * 1.6, 1.0) * PI * 0.5)
			var back := ease(clampf((t - 0.45) / 0.55, 0.0, 1.0), -2.0)
			var thrown_pos := Vector3(-0.1, -0.08, -0.22)
			var thrown_rot := Vector3(-1.0, 0.25, -0.2)
			var wind_pos := Vector3(0.04, 0.1, 0.14)
			var wind_rot := Vector3(0.9, -0.2, 0.3)
			pos = wind_pos.lerp(thrown_pos, forward).lerp(Vector3.ZERO, back)
			rot = wind_rot.lerp(thrown_rot, forward).lerp(Vector3.ZERO, back)
		_held.position = pos
		_held.rotation = rot
	if _throw_time >= THROW_WINDUP + THROW_FOLLOW:
		_throw_time = -1.0
		_throw_item = null
		if _held != null:
			_held.position = Vector3.ZERO
			_held.rotation = Vector3.ZERO
		if _pending_update:
			_pending_update = false
			_update_item()
		_show_held_mesh(true)


## Granate verlässt die Hand.
func _release(item: GrenadeData) -> void:
	_show_held_mesh(false)
	# Der Slot kann sich beim Ausholen geändert haben: nur werfen, was noch da ist.
	var index := _find_item(item)
	if index < 0:
		return
	_player.inventory.remove_at(index)
	var camera := _player.camera
	var forward := -camera.global_basis.z
	var grenade: ThrownGrenade = GRENADE_SCRIPT.new()
	grenade.data = item
	grenade.thrower = _player
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = camera.global_position + forward * 0.5 + Vector3.DOWN * 0.1
	grenade.linear_velocity = forward * item.throw_speed * _player.skill_mult(&"throw_mult") + Vector3.UP * 3.0 \
		+ Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	grenade.add_collision_exception_with(_player)
	WorldSync.announce_grenade(grenade)
	action_performed.emit()


func _find_item(item: ItemData) -> int:
	var inventory := _player.inventory
	if inventory.get_item(inventory.selected) != null and inventory.get_item(inventory.selected).is_same(item):
		return inventory.selected
	for i in inventory.get_size():
		var other := inventory.get_item(i)
		if other != null and other.is_same(item):
			return i
	return -1


func _show_held_mesh(on: bool) -> void:
	if _held != null:
		for child in _held.get_children():
			if child is GeometryInstance3D:
				child.visible = on


## Wie viele Stück eines Items im ganzen Inventar sind (Hotbar und Rucksack).
func count_item(item: ItemData) -> int:
	var total := 0
	var inventory := _player.inventory
	for i in inventory.get_size():
		var other := inventory.get_item(i)
		if other != null and other.is_same(item):
			total += inventory.get_count(i)
	return total


func is_throwing() -> bool:
	return _throw_time >= 0.0


func _strike(item: MeleeData) -> bool:
	_cooldown = item.swing_interval
	_swing = 1.0
	action_performed.emit()
	var camera := _player.camera
	var from := camera.global_position
	var to := from - camera.global_basis.z * item.reach
	var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD | LAYER_PLAYER, [_player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.collider
		if item.breaks_locks and collider != null and collider.has_method("break_open"):
			collider.call("break_open", _player)
		elif collider != null and collider.has_method("take_hit"):
			collider.take_hit(item.damage * _player.skill_mult(&"melee_mult"), hit.position, hit.normal)
	return true


## Zeigt Klinge oder Granate in der Hand. Schusswaffen zeichnet der WeaponHolder.
func _update_item() -> void:
	if _throw_time >= 0.0:
		# Die Hand bleibt bis zum Ende des Wurfs, auch wenn es die letzte Granate war.
		_pending_update = true
		return
	var item := _player.inventory.get_selected_item()
	if item == _item:
		return
	_item = item
	_swing = 0.0
	_raise = 0.0
	if _held != null:
		_held.queue_free()
		_held = null
	if item != null and ConsumableModel.has_model(item.model):
		_held = ConsumableModel.build(item.model, item.color, true)
		_held.transform = ConsumableModel.hold_transform(item.model)
		_raise = 1.0
	elif item is MeleeData:
		_held = _make_held(BoxMesh.new(), item.color)
		(_held.get_child(0) as MeshInstance3D).mesh.size = Vector3(0.015, 0.03, 0.5)
		_held.get_child(0).position = Vector3(0.0, 0.0, -0.22)
	elif item is GrenadeData:
		_held = _make_held(SphereMesh.new(), item.color)
		var mesh: SphereMesh = (_held.get_child(0) as MeshInstance3D).mesh
		mesh.radius = 0.045
		mesh.height = 0.09
		if (item as GrenadeData).contact_fuse:
			# Kontaktgranate: dunkler Körper mit Zünderkappe und Leuchtring.
			var body_material := StandardMaterial3D.new()
			body_material.albedo_color = Color(0.12, 0.12, 0.14)
			body_material.metallic = 0.6
			body_material.roughness = 0.4
			mesh.material = body_material
			var ring := TorusMesh.new()
			ring.inner_radius = 0.042
			ring.outer_radius = 0.05
			_add_held_part(ring, item.color, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))
			var cap := CylinderMesh.new()
			cap.top_radius = 0.014
			cap.bottom_radius = 0.018
			cap.height = 0.03
			_add_held_part(cap, Color(1.0, 0.85, 0.3), Vector3(0.0, 0.05, 0.0), Vector3.ZERO)
	if _held != null:
		add_child(_held)


## Gehaltenes Item oder das aus der laufenden Benutz-Animation.
func _use_item_data() -> ItemData:
	if _use != null and _use.is_active():
		return _use.get_item()
	return _item


func _on_use_finished(completed: bool) -> void:
	# Nach dem Benutzen kommt das nächste Stück von unten ins Bild, nach einem Abbruch steht es schon da.
	if completed:
		_raise = 1.0
	_player.hands.wake()


func _add_held_part(mesh: PrimitiveMesh, color: Color, pos: Vector3, rot: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.layers |= PlayerHands.VIEWMODEL_LAYER
	_held.add_child(instance)


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
			and _player.pointer_captured() and not get_tree().paused


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
	# Taschendiebstahl: Griff gegen Verdacht, unter der Meldungszeile.
	_pick_bar = PICKPOCKET_BAR.new()
	_pick_bar.name = "PickpocketBar"
	_pick_bar.anchor_left = 0.5
	_pick_bar.anchor_right = 0.5
	_pick_bar.anchor_top = 0.5
	_pick_bar.anchor_bottom = 0.5
	_pick_bar.offset_left = -PICKPOCKET_BAR.SIZE.x * 0.5
	_pick_bar.offset_right = PICKPOCKET_BAR.SIZE.x * 0.5
	_pick_bar.offset_top = 100.0
	_pick_bar.offset_bottom = 100.0 + PICKPOCKET_BAR.SIZE.y
	_pick_bar.visible = false
	layer.add_child(_pick_bar)
	# Granaten-Anzeige unten rechts, an der Stelle der Munitionsanzeige der Waffen.
	_grenade_label = Label.new()
	_grenade_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grenade_label.anchor_left = 1.0
	_grenade_label.anchor_top = 1.0
	_grenade_label.anchor_right = 1.0
	_grenade_label.anchor_bottom = 1.0
	_grenade_label.offset_left = -420.0
	_grenade_label.offset_top = -78.0
	_grenade_label.offset_right = -28.0
	_grenade_label.offset_bottom = -24.0
	_grenade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_grenade_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_grenade_label.add_theme_font_size_override("font_size", 30)
	_grenade_label.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.2))
	_grenade_label.add_theme_constant_override("outline_size", 6)
	_grenade_label.visible = false
	layer.add_child(_grenade_label)


func _update_grenade_hud() -> void:
	if _grenade_label == null or _player == null or _player.inventory == null:
		return
	var item := _player.inventory.get_selected_item() as GrenadeData
	_grenade_label.visible = item != null
	if item == null:
		return
	_grenade_label.text = "%s  ×%d" % [item.display_name.to_upper(), count_item(item)]
	_grenade_label.add_theme_color_override("font_color", item.color)


func _play(stream: AudioStream) -> void:
	if stream == null or _audio == null:
		return
	_audio.stream = stream
	_audio.pitch_scale = randf_range(0.95, 1.05)
	_audio.play()


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
