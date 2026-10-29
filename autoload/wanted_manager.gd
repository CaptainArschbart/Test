extends Node
## Fahndung mit 1–5 Sternen (Autoload "WantedManager").
##
## Straftaten heben die Sterne. Polizisten (Enemy mit Profil cop.tres) spawnen
## um den Spieler. Sehen sie ihn nicht mehr, fällt alle `hide_seconds` ein Stern.

signal stars_changed(stars: int)

const STAR_MAX := 5
const HIDE_SECONDS := 18.0
const REPORT_COOLDOWN := 12.0
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const COP_PROFILE := preload("res://scenes/enemies/profiles/cop.tres")

const WEIGHTS := {
	&"burglary": 1,
	&"pickpocket": 1,
	&"threat": 1,
	&"murder": 2,
}

var stars := 0
var _hidden := 0.0
var _cooldown := {}
var _hud: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WantedHud"
	layer.layer = 6
	add_child(layer)
	_hud = Label.new()
	_hud.name = "Stars"
	_hud.unique_name_in_owner = true
	_hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hud.offset_left = -280.0
	_hud.offset_top = 18.0
	_hud.offset_right = -24.0
	_hud.offset_bottom = 52.0
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_theme_font_size_override("font_size", 22)
	_hud.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	layer.add_child(_hud)
	_hud.owner = layer
	_refresh_hud()


func star_count() -> int:
	return stars


func set_stars(value: int) -> void:
	var next := clampi(value, 0, STAR_MAX)
	if next == stars:
		_refresh_hud()
		return
	stars = next
	_hidden = 0.0
	if stars == 0:
		_despawn_all()
	stars_changed.emit(stars)
	_refresh_hud()


## `token` bündelt Wiederholungen derselben Tat (dieselbe Tür, derselbe Passant).
func report(kind: StringName, _at: Vector3, token: int = 0) -> void:
	var key := "%s:%d" % [kind, token]
	var now := Time.get_ticks_msec() / 1000.0
	if float(_cooldown.get(key, 0.0)) > now:
		return
	_cooldown[key] = now + REPORT_COOLDOWN
	var gain := int(WEIGHTS.get(kind, 1))
	set_stars(stars + gain)


func _process(delta: float) -> void:
	if stars <= 0:
		return
	if WorldSync.is_client():
		return
	var player := _player()
	if player == null:
		return
	_sync_police(player)
	if _any_cop_sees(player):
		_hidden = 0.0
		return
	_hidden += delta
	if _hidden >= HIDE_SECONDS:
		_hidden = 0.0
		set_stars(stars - 1)


func _sync_police(player: Node3D) -> void:
	var wanted := _units()
	var goal := _unit_goal()
	while wanted.size() > goal:
		var extra: Node = wanted.pop_back()
		var anchor := extra.get_parent()
		if anchor != null and str(anchor.name).begins_with("CopAnchor"):
			anchor.queue_free()
		else:
			extra.queue_free()
	var scene := get_tree().current_scene
	if scene == null:
		return
	while wanted.size() < goal:
		var angle := randf() * TAU
		var flat := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(22.0, 36.0)
		var pos := player.global_position + flat
		pos.y = player.global_position.y
		var anchor := Node3D.new()
		anchor.name = "CopAnchor"
		scene.add_child(anchor)
		anchor.global_position = pos
		var unit := ENEMY_SCENE.instantiate() as Enemy
		unit.name = "WantedCop"
		unit.profile = COP_PROFILE
		unit.start_hostile = true
		unit.variant_seed = randi()
		anchor.add_child(unit)
		unit.add_to_group(&"wanted_unit")
		unit.engage(player as Player)
		wanted.append(unit)


func _unit_goal() -> int:
	if stars <= 0:
		return 0
	var count := stars
	if stars >= 4:
		count += 1
	return mini(count, 6)


func _units() -> Array[Node]:
	var list: Array[Node] = []
	for node in get_tree().get_nodes_in_group(&"wanted_unit"):
		if is_instance_valid(node):
			list.append(node)
	return list


func _despawn_all() -> void:
	for node in _units():
		var anchor := node.get_parent()
		if anchor != null and str(anchor.name).begins_with("CopAnchor"):
			anchor.queue_free()
		else:
			node.queue_free()


func _any_cop_sees(player: Node3D) -> bool:
	var space := player.get_world_3d().direct_space_state
	if space == null:
		return false
	for node in _units():
		var cop := node as Node3D
		if cop == null:
			continue
		var from := cop.global_position + Vector3.UP * 1.5
		var to := player.global_position + Vector3.UP * 1.2
		if from.distance_to(to) > 32.0:
			continue
		var query := PhysicsRayQueryParameters3D.create(from, to, 1, [cop.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider := hit.collider as Node
		if collider != null and (collider == player or player.is_ancestor_of(collider)):
			return true
	return false


func _player() -> Node3D:
	var best: Node3D = null
	for node in get_tree().get_nodes_in_group(&"player"):
		var body := node as Node3D
		if body == null:
			continue
		if body.has_method("controls_local_body") and not bool(body.call("controls_local_body")):
			continue
		if body.get("dead") == true:
			continue
		best = body
	return best


func _refresh_hud() -> void:
	if _hud == null:
		return
	if stars <= 0:
		_hud.text = ""
		_hud.visible = false
		return
	var text := ""
	for i in STAR_MAX:
		text += "★" if i < stars else "☆"
	_hud.text = "WANTED  " + text
	_hud.visible = true
