class_name ThrownGrenade
extends RigidBody3D
## Geworfene Granate (von ItemUser erzeugt). Prallt ab und geht nach data.fuse_time hoch.
## Kontaktgranaten (data.contact_fuse) gehen beim ersten Aufprall hoch.
##
## Die Explosion trifft alles im Radius mit take_hit(damage, point, normal), wenn keine
## Wand dazwischen ist. Steht der Werfer selbst im Radius und drains_stamina ist an,
## ist seine Ausdauer leer. Mesh, Licht und Blitz entstehen im Code. Die Kamera des Spielers
## wackelt, je näher er an der Explosion steht (CameraShake).

const CameraShakeScript := preload("res://scenes/player/camera_shake.gd")

var data: GrenadeData
var thrower: Player

## Feste Lebenszeit, falls eine Kontaktgranate nie etwas trifft (aus der Welt gefallen).
const CONTACT_MAX_FLIGHT := 8.0

var _fuse := 0.0
var _light: OmniLight3D
var _exploded := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	mass = 0.4
	continuous_cd = true
	var material := PhysicsMaterial.new()
	material.bounce = 0.35
	material.friction = 0.8
	physics_material_override = material
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.06
	shape.shape = sphere
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.06
	sphere_mesh.height = 0.12
	sphere_mesh.material = _glow_material(data.color, 2.5)
	mesh.mesh = sphere_mesh
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	_light = OmniLight3D.new()
	_light.light_color = data.color
	_light.light_energy = 1.0
	_light.omni_range = 2.0
	add_child(_light)
	_fuse = data.fuse_time
	if data.contact_fuse:
		_fuse = CONTACT_MAX_FLIGHT
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_contact)
		material.bounce = 0.0
		# Leuchtring, damit man die Flugbahn sieht.
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.055
		torus.outer_radius = 0.068
		torus.material = _glow_material(Color(1.0, 0.9, 0.3), 3.0)
		ring.mesh = torus
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)


func _physics_process(delta: float) -> void:
	_fuse -= delta
	# Blinkt schneller, je näher die Zündung kommt. Kontaktgranaten leuchten durchgehend.
	if not data.contact_fuse:
		_light.visible = fmod(_fuse, 0.1 + _fuse * 0.2) > 0.05
	if _fuse <= 0.0:
		if data.contact_fuse:
			queue_free()
		else:
			explode()


## Kontaktzünder: der erste Körper, den die Granate berührt (Welt, Gegner, Auto).
func _on_contact(_body: Node) -> void:
	if not _exploded:
		explode.call_deferred()


## Sofort zünden (auch für Tests).
func explode() -> void:
	if _exploded:
		return
	_exploded = true
	set_physics_process(false)
	var center := global_position
	StealthNoise.emit(get_tree(), center, data.noise_radius, self, StealthNoise.EXPLOSION)
	CameraShakeScript.explosion(get_tree(), center, data.radius)
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = data.radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), center)
	query.collision_mask = 1 | 2
	var done := {}
	for result in space.intersect_shape(query, 64):
		var collider := result.collider as CollisionObject3D
		if collider == null or done.has(collider):
			continue
		done[collider] = true
		var target := _shape_center(collider, result.shape)
		if not _in_sight(space, center, target, collider):
			continue
		var amount := damage_at(center.distance_to(target))
		if collider is RigidBody3D and data.impulse > 0.0:
			var push := (target - center).normalized() + Vector3.UP * 0.4
			(collider as RigidBody3D).apply_central_impulse(push.normalized() * data.impulse * amount / data.damage)
		if collider == thrower:
			if data.drains_stamina:
				thrower.stats.add_stamina(-thrower.stats.max_stamina)
				thrower.item_user.show_message("EMP! Ausdauer leer", data.color)
			if data.self_damage_factor > 0.0:
				thrower.stats.damage(amount * data.self_damage_factor, &"grenade")
		elif data.drains_stamina and collider.has_method("emp_hit"):
			# Gegner mit Elektronik (Enemy): Schaden und Betäubung.
			collider.emp_hit(amount, target, (center - target).normalized())
		elif collider.has_method("take_hit"):
			var normal := (center - target).normalized()
			collider.take_hit(amount, target, normal)
	if data.blast == GrenadeData.Blast.FRAG:
		_spawn_frag_blast(center)
	else:
		_spawn_blast(center)
	_play_explosion(center)
	queue_free()


## Schaden in `distance` Metern Abstand: voll in der Mitte, am Rand min_damage_fraction.
func damage_at(distance: float) -> float:
	var t := clampf(distance / maxf(data.radius, 0.01), 0.0, 1.0)
	return data.damage * lerpf(1.0, data.min_damage_fraction, t)


func _play_explosion(center: Vector3) -> void:
	if data.explosion_sound == null:
		return
	var sound := AudioStreamPlayer3D.new()
	sound.stream = data.explosion_sound
	sound.bus = &"SFX"
	sound.unit_size = 10.0
	sound.max_db = 6.0
	sound.max_distance = 160.0
	sound.pitch_scale = randf_range(0.92, 1.05)
	get_tree().current_scene.add_child(sound)
	sound.global_position = center
	sound.finished.connect(sound.queue_free)
	sound.play()


## Mitte der getroffenen Kollisionsform (der Knoten selbst steht oft auf dem Boden).
func _shape_center(collider: CollisionObject3D, shape_index: int) -> Vector3:
	var owner_id := collider.shape_find_owner(shape_index)
	var shape_owner := collider.shape_owner_get_owner(owner_id) as Node3D
	return shape_owner.global_position if shape_owner != null else collider.global_position


## Keine Wand zwischen Granate und Ziel. Trifft der Strahl das Ziel selbst, zählt es.
func _in_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, collider: Object) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
	var hit := space.intersect_ray(query)
	return hit.is_empty() or hit.collider == collider


## Leuchtende Kugel, die aufbläht und verblasst, dazu ein heller Lichtblitz.
func _spawn_blast(center: Vector3) -> void:
	var blast := Node3D.new()
	get_tree().current_scene.add_child(blast)
	blast.global_position = center
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var material := _glow_material(data.color, 3.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color.a = 0.6
	sphere.material = material
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.scale = Vector3.ONE * 0.2
	blast.add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = data.color
	light.light_energy = 8.0
	light.omni_range = data.radius * 1.5
	blast.add_child(light)
	var tween := blast.create_tween().set_parallel()
	tween.tween_property(mesh, "scale", Vector3.ONE * data.radius, 0.35)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.tween_property(light, "light_energy", 0.0, 0.45)
	tween.chain().tween_callback(blast.queue_free)


## Splittergranate: Feuerball, greller Blitz, Funken, Rauchwolke und Bodenstaub.
## Alles CPU-Partikel und einfache Meshes, läuft in Forward+ und Kompatibilität.
func _spawn_frag_blast(center: Vector3) -> void:
	var blast := Node3D.new()
	get_tree().current_scene.add_child(blast)
	blast.global_position = center
	var fire := Color(1.0, 0.55, 0.15)
	# Feuerball: heller Kern und orange Hülle, blähen sich schnell auf.
	var balls: Array[MeshInstance3D] = []
	for layer in 2:
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		var color := Color(1.0, 0.92, 0.6) if layer == 0 else fire
		var material := _glow_material(color, 6.0 if layer == 0 else 3.5)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color.a = 0.95 if layer == 0 else 0.7
		sphere.material = material
		mesh.mesh = sphere
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.scale = Vector3.ONE * 0.1
		blast.add_child(mesh)
		balls.append(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.3)
	light.light_energy = 14.0
	light.omni_range = data.radius * 2.5
	light.shadow_enabled = false
	blast.add_child(light)
	blast.add_child(_particles(48, 0.9, Vector3.UP, 180.0, 7.0, 16.0, Vector3(0, -12, 0), 0.025, 0.05,
		Color(1.0, 0.8, 0.35), 4.0, false))
	var smoke := _particles(22, 2.6, Vector3.UP, 70.0, 1.0, 3.5, Vector3(0, 0.6, 0), 0.6, 1.4,
		Color(0.18, 0.17, 0.17, 0.75), 0.0, true)
	smoke.damping_min = 1.5
	smoke.damping_max = 2.5
	blast.add_child(smoke)
	# Staub, der flach über den Boden rollt.
	var dust := _particles(26, 2.0, Vector3.UP, 88.0, 3.0, 6.0, Vector3(0, -0.4, 0), 0.4, 0.9,
		Color(0.42, 0.36, 0.3, 0.6), 0.0, true)
	dust.position.y = -0.1
	dust.damping_min = 2.5
	dust.damping_max = 4.0
	blast.add_child(dust)
	var core: StandardMaterial3D = balls[0].mesh.material
	var shell: StandardMaterial3D = balls[1].mesh.material
	var tween := blast.create_tween().set_parallel()
	tween.tween_property(balls[0], "scale", Vector3.ONE * data.radius * 0.35, 0.12)
	tween.tween_property(balls[1], "scale", Vector3.ONE * data.radius * 0.6, 0.22)
	tween.tween_property(core, "albedo_color:a", 0.0, 0.2)
	tween.tween_property(shell, "albedo_color:a", 0.0, 0.4).set_delay(0.05)
	tween.tween_property(light, "light_energy", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(2.4)
	tween.chain().tween_callback(blast.queue_free)


func _particles(amount: int, lifetime: float, direction: Vector3, spread: float, speed_min: float,
		speed_max: float, gravity: Vector3, size_min: float, size_max: float, color: Color,
		glow: float, soft: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = direction
	particles.spread = spread
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.gravity = gravity
	particles.scale_amount_min = size_min
	particles.scale_amount_max = size_max
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	var mesh: Mesh
	if soft:
		# Weiche Rauchballen: Billboards, wachsen und blassen aus.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		mesh = quad
		var ramp := Gradient.new()
		ramp.set_color(0, color)
		ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
		particles.color_ramp = ramp
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 0.4))
		curve.add_point(Vector2(1.0, 1.6))
		particles.scale_amount_curve = curve
	else:
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		mesh = box
		particles.color = color
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = material
	particles.mesh = mesh
	particles.emitting = true
	return particles


func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
