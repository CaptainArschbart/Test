class_name ThrownGrenade
extends RigidBody3D
## Geworfene Granate (von ItemUser erzeugt). Prallt ab und geht nach data.fuse_time hoch.
##
## Die Explosion trifft alles im Radius mit take_hit(damage, point, normal), wenn keine
## Wand dazwischen ist. Steht der Werfer selbst im Radius und drains_stamina ist an,
## ist seine Ausdauer leer. Mesh, Licht und Blitz entstehen im Code. Die Kamera des Spielers
## wackelt, je näher er an der Explosion steht (CameraShake).

const CameraShakeScript := preload("res://scenes/player/camera_shake.gd")

var data: GrenadeData
var thrower: Player

var _fuse := 0.0
var _light: OmniLight3D


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


func _physics_process(delta: float) -> void:
	_fuse -= delta
	# Blinkt schneller, je näher die Zündung kommt.
	_light.visible = fmod(_fuse, 0.1 + _fuse * 0.2) > 0.05
	if _fuse <= 0.0:
		explode()


## Sofort zünden (auch für Tests).
func explode() -> void:
	set_physics_process(false)
	var center := global_position
	StealthNoise.emit(get_tree(), center, 40.0, self, StealthNoise.EXPLOSION)
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
		if collider == thrower and data.drains_stamina:
			thrower.stats.add_stamina(-thrower.stats.max_stamina)
			thrower.item_user.show_message("EMP! Ausdauer leer", data.color)
		elif data.drains_stamina and collider.has_method("emp_hit"):
			# Gegner mit Elektronik (Enemy): Schaden und Betäubung.
			collider.emp_hit(data.damage, target, (center - target).normalized())
		elif collider.has_method("take_hit"):
			var normal := (center - target).normalized()
			collider.take_hit(data.damage, target, normal)
	_spawn_blast(center)
	queue_free()


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


func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
