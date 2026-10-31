extends StaticBody3D
## Zapfsäule einer Tankstelle. Zerschossen geht sie hoch und brennt danach eine Weile.
##
## Die Explosion ist eine ThrownGrenade mit eigenen Werten (Schaden, Radius, Lärm, Blitz, Ton kommen
## von dort) und reißt die Säulen daneben mit. Nach RESPAWN steht eine neue da.
## Multiplayer: Der Host rechnet (Treffer per forward_hit), der Zustand läuft über WorldSync
## (Gruppe net_npc). Clients zeigen die Explosion nur, ohne Schaden.
## Kein class_name: GasStation legt den Knoten per preload an.

const BLAST_BASE := preload("res://scenes/items/data/contact_grenade.tres")
const HEALTH := 45.0
const BLAST_DAMAGE := 95.0
const BLAST_RADIUS := 6.0
const BLAST_NOISE := 60.0
## Verzögerung bis zum Knall, damit Nachbarsäulen nacheinander hochgehen.
const FUSE := 0.25
## Säulen in dieser Nähe zünden mit. Eigene Prüfung, weil die Vordachsäule die Sicht der Explosion deckt.
const CHAIN_RANGE := 6.0
const BURN_TIME := 30.0
const RESPAWN := 240.0
const SIZE := Vector3(0.45, 1.75, 0.8)

var health := HEALTH
var broken := false

var _fuse := -1.0
var _burn_left := 0.0
var _respawn_left := 0.0
var _synced := false
var _shape: CollisionShape3D
var _intact: Node3D
var _wreck: Node3D
var _fire: OmniLight3D


func _ready() -> void:
	add_to_group(WorldSync.NPC_GROUP)
	collision_layer = 1
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	_shape.shape = box
	_shape.position = Vector3.UP * SIZE.y * 0.5
	add_child(_shape)
	_build_intact()
	_build_wreck()
	_show_state()


func take_hit(damage: float, point: Vector3, normal: Vector3) -> void:
	if broken:
		return
	if WorldSync.is_client():
		WorldSync.forward_hit(self, &"take_hit", [damage, point, normal])
		return
	health -= damage
	if health <= 0.0 and _fuse < 0.0:
		_fuse = FUSE


## Host: Zündung läuft an, falls die Säule noch steht.
func ignite() -> void:
	if not broken and _fuse < 0.0:
		_fuse = FUSE


func _physics_process(delta: float) -> void:
	if not WorldSync.has_authority():
		return
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse < 0.0:
			_explode()
	elif broken:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			health = HEALTH
			broken = false
			_show_state()


func _process(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	_burn_left -= delta
	_fire.light_energy = randf_range(2.0, 3.4)
	if _burn_left <= 0.0:
		_set_burning(false)


func _explode() -> void:
	broken = true
	_respawn_left = RESPAWN
	_show_state()
	_set_burning(true)
	var blast := _new_blast()
	get_tree().current_scene.add_child(blast)
	blast.global_position = _blast_center()
	blast.explode()
	for pump: Node in get_parent().get_children():
		if pump != self and pump.has_method("ignite") and global_position.distance_to((pump as Node3D).global_position) <= CHAIN_RANGE:
			pump.call("ignite")


func _new_blast() -> ThrownGrenade:
	var data := BLAST_BASE.duplicate() as GrenadeData
	data.damage = BLAST_DAMAGE
	data.radius = BLAST_RADIUS
	data.noise_radius = BLAST_NOISE
	data.self_damage_factor = 0.0
	var blast := ThrownGrenade.new()
	blast.data = data
	return blast


func _blast_center() -> Vector3:
	return global_position + Vector3.UP * 0.9


func net_get_state() -> Array:
	return [health, broken]


func net_apply_state(data: Array) -> void:
	if data.size() < 2:
		return
	health = float(data[0])
	var new_broken := bool(data[1])
	var boom := new_broken and not broken and _synced
	_synced = true
	if new_broken == broken:
		return
	broken = new_broken
	_show_state()
	_set_burning(broken and boom)
	if boom:
		var blast := _new_blast()
		blast.remote = true
		get_tree().current_scene.add_child(blast)
		blast.explode_remote(_blast_center())


func _show_state() -> void:
	_intact.visible = not broken
	_wreck.visible = broken
	_shape.disabled = broken


func _set_burning(on: bool) -> void:
	_burn_left = BURN_TIME if on else 0.0
	_fire.visible = on
	for child: Node in _wreck.get_children():
		if child is CPUParticles3D:
			(child as CPUParticles3D).emitting = on


func _build_intact() -> void:
	_intact = Node3D.new()
	_intact.name = "Intact"
	add_child(_intact)
	var b := SlumBuilder.new(_intact)
	var shell := SlumMats.color(Color(0.1, 0.13, 0.17), 0.0, 0.4, 0.5)
	var glow := SlumMats.color(Color(1.0, 0.45, 0.1), 3.0)
	var screen := SlumMats.color(Color(0.2, 1.0, 0.75), 2.5)
	var dark := SlumMats.color(Color(0.03, 0.03, 0.04), 0.0, 0.7)
	b.box(Vector3(0.0, 0.1, 0.0), Vector3(0.55, 0.2, 0.9), dark, false)
	b.box(Vector3(0.0, 0.85, 0.0), Vector3(SIZE.x, 1.3, SIZE.z), shell, false)
	b.box(Vector3(0.0, 1.62, 0.0), Vector3(SIZE.x + 0.06, 0.26, SIZE.z + 0.06), glow, false, false)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (SIZE.x * 0.5 + 0.005), 1.15, 0.0), Vector3(0.01, 0.34, 0.5), screen, false, false)
		b.box(Vector3(side * (SIZE.x * 0.5 + 0.005), 0.8, 0.0), Vector3(0.01, 0.2, 0.4), dark, false, false)
		# Zapfpistole im Halter, Schlauch hängt in die Säule.
		var holster := Vector3(side * (SIZE.x * 0.5 + 0.05), 1.0, 0.33)
		b.box(holster, Vector3(0.08, 0.26, 0.08), dark, false)
		b.cable(Vector3(side * (SIZE.x * 0.5), 1.4, 0.36), holster + Vector3.DOWN * 0.1, 0.5, dark, 0.018)
	b.finish()


func _build_wreck() -> void:
	_wreck = Node3D.new()
	_wreck.name = "Wreck"
	add_child(_wreck)
	var b := SlumBuilder.new(_wreck)
	var burnt := SlumMats.color(Color(0.04, 0.035, 0.03), 0.0, 0.95)
	b.box(Vector3(0.0, 0.1, 0.0), Vector3(0.55, 0.2, 0.9), burnt, false)
	b.box(Vector3(0.05, 0.42, -0.08), Vector3(0.36, 0.5, 0.5), burnt, false)
	b.finish()
	_fire = OmniLight3D.new()
	_fire.light_color = Color(1.0, 0.5, 0.15)
	_fire.omni_range = 7.0
	_fire.position = Vector3.UP * 0.9
	_fire.shadow_enabled = false
	_wreck.add_child(_fire)
	_wreck.add_child(_flames(Color(1.0, 0.5, 0.1), 0.11, 26, 0.7, 1.8))
	_wreck.add_child(_flames(Color(0.06, 0.06, 0.07), 0.22, 14, 2.2, 1.1))


func _flames(color: Color, radius: float, amount: int, life: float, rise: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	particles.mesh = mesh
	particles.amount = amount
	particles.lifetime = life
	particles.emitting = false
	particles.position = Vector3.UP * 0.5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.25
	particles.direction = Vector3.UP
	particles.spread = 12.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = rise * 0.6
	particles.initial_velocity_max = rise
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	return particles
