class_name CivilianModel
extends EnemyModel
## Körper eines Fußgängers. Nutzt Skelett, Animation und Umfallen von EnemyModel, baut aber zivile
## Kleidung (keine Waffe, keine Statusfarbe) und mit weniger Polygonen (viele Figuren auf einmal).
##
## Stile: Kapuzenjacke, langer Mantel, Regenjacke, Arbeiter mit Warnweste, Punk mit LED-Weste.
## Manche tragen einen Neon-Regenschirm. Zusätzliche Posen: `cower` (geduckt, Hände über dem Kopf)
## und get_up() nach dem Umfallen (Auto).

enum Outfit { HOODIE, COAT, RAINCOAT, WORKER, PUNK }

## 0 = normal, 1 = geduckt mit Händen über dem Kopf.
var cower := 0.0
var outfit := Outfit.HOODIE
var has_umbrella := false

var _umbrella: Node3D
var _hair_colors := [Color(0.06, 0.05, 0.05), Color(0.3, 0.18, 0.1), Color(0.75, 0.7, 0.6), Color(0.9, 0.2, 0.6),
		Color(0.2, 0.8, 1.0), Color(0.55, 0.3, 1.0)]

static var _tube_cache := {}


func build_civilian(variant_seed: int) -> void:
	_rng.seed = variant_seed
	_skeleton()
	outfit = (_rng.randi() % Outfit.size()) as Outfit
	var skin := _skin()
	var accent_color: Color = [Color(0.0, 0.95, 1.0), Color(1.0, 0.2, 0.75), Color(0.6, 0.35, 1.0), Color(1.0, 0.6, 0.1),
			Color(0.3, 1.0, 0.5)][_rng.randi() % 5]
	var accent := _emit("accent", accent_color, 2.0)
	var shoe := _mat("shoe", [Color(0.08, 0.08, 0.08), Color(0.85, 0.85, 0.82), Color(0.35, 0.2, 0.12)][_rng.randi() % 3], 0.6)
	var pants := _mat("pants", [Color(0.1, 0.1, 0.12), Color(0.12, 0.16, 0.26), Color(0.25, 0.22, 0.18),
			Color(0.3, 0.3, 0.32)][_rng.randi() % 4], 0.9)
	match outfit:
		Outfit.HOODIE:
			var top := _mat("top", [Color(0.5, 0.1, 0.35), Color(0.15, 0.3, 0.4), Color(0.6, 0.55, 0.5), Color(0.2, 0.2, 0.22),
					Color(0.15, 0.35, 0.2)][_rng.randi() % 5], 0.9)
			_legs(pants, shoe, 0.17, null)
			_torso(top, Vector3(0.46, 0.56, 0.27))
			_box(_spine, Vector3(0.3, 0.2, 0.06), top, Vector3(0, 0.12, -0.15), 0.4)  # Bauchtasche
			_arms(top, skin, 0.125, null)
			_build_head(skin)
			if _rng.randf() < 0.5:
				_box(_head, Vector3(0.28, 0.3, 0.3), top, Vector3(0, 0.14, 0.03), 0.7)  # Kapuze auf
			else:
				_hair()
		Outfit.COAT:
			var coat := _mat("coat", [Color(0.12, 0.11, 0.1), Color(0.35, 0.28, 0.2), Color(0.18, 0.2, 0.25)][_rng.randi() % 3], 0.8)
			_legs(pants, shoe, 0.17, null)
			_torso(coat, Vector3(0.48, 0.6, 0.29))
			for i: int in 2:
				_box(_hips[i], Vector3(0.23, 0.55, 0.3), coat, Vector3(0, -0.27, 0.01), 0.25)
			_box(_spine, Vector3(0.14, 0.3, 0.02), _mat("shirt", Color(0.75, 0.75, 0.78), 0.8), Vector3(0, 0.42, -0.15), 0.2)
			_arms(coat, skin, 0.13, null)
			_build_head(skin)
			_hair()
			if _rng.randf() < 0.5:
				# Visier-Brille
				_box(_head, Vector3(0.22, 0.05, 0.03), accent, Vector3(0, 0.13, -0.12), 0.3)
		Outfit.RAINCOAT:
			var plastic := _mat("rain", [Color(0.95, 0.85, 0.1), Color(0.2, 0.7, 0.9), Color(0.9, 0.3, 0.5)][_rng.randi() % 3], 0.25)
			_legs(pants, shoe, 0.17, null)
			_torso(plastic, Vector3(0.5, 0.62, 0.3))
			for i: int in 2:
				_box(_hips[i], Vector3(0.24, 0.4, 0.31), plastic, Vector3(0, -0.18, 0.0), 0.3)
			_arms(plastic, skin, 0.135, null)
			_build_head(skin)
			_box(_head, Vector3(0.29, 0.31, 0.31), plastic, Vector3(0, 0.14, 0.03), 0.7)
		Outfit.WORKER:
			var overall := _mat("overall", [Color(0.2, 0.25, 0.35), Color(0.45, 0.3, 0.12)][_rng.randi() % 2], 0.85)
			var vest := _mat("vest", Color(1.0, 0.45, 0.05), 0.6)
			var reflect := _emit("reflect", Color(0.85, 0.9, 0.7), 1.2)
			_legs(overall, _mat("boot", Color(0.12, 0.09, 0.07), 0.7), 0.18, null)
			_torso(overall, Vector3(0.48, 0.56, 0.28))
			_box(_spine, Vector3(0.5, 0.42, 0.3), vest, Vector3(0, 0.34, 0), 0.35)
			_box(_spine, Vector3(0.51, 0.04, 0.31), reflect, Vector3(0, 0.26, 0), 0.2)
			_arms(overall, _mat("glove", Color(0.3, 0.3, 0.1), 0.8), 0.13, null)
			_build_head(skin)
			_box(_head, Vector3(0.27, 0.12, 0.29), _mat("helmet", Color(0.95, 0.8, 0.1), 0.4), Vector3(0, 0.25, 0), 0.6)
		Outfit.PUNK:
			var jacket := _mat("leather", Color(0.07, 0.07, 0.08), 0.4, 0.2)
			_legs(_mat("jeans", Color(0.15, 0.18, 0.3), 0.9), shoe, 0.16, accent)
			_torso(jacket, Vector3(0.46, 0.55, 0.26))
			_box(_spine, Vector3(0.47, 0.03, 0.27), accent, Vector3(0, 0.46, 0), 0.2)
			_box(_spine, Vector3(0.03, 0.4, 0.02), accent, Vector3(0.1, 0.3, -0.14), 0.2)
			_arms(jacket, skin, 0.12, accent)
			_build_head(skin)
			_box(_head, Vector3(0.05, 0.12, 0.24), accent, Vector3(0, 0.27, 0.0), 0.5)  # Irokese
			_box(_head, Vector3(0.16, 0.08, 0.06), _mat("mask", Color(0.2, 0.2, 0.22), 0.4, 0.6), Vector3(0, 0.03, -0.12), 0.4)
	# Kleinkram: Rucksack oder Umhängetasche
	var roll := _rng.randf()
	if roll < 0.3:
		_box(_spine, Vector3(0.32, 0.38, 0.16), _mat("bag", Color(0.15, 0.15, 0.17), 0.8), Vector3(0, 0.3, 0.22), 0.4)
		_box(_spine, Vector3(0.3, 0.02, 0.02), accent, Vector3(0, 0.2, 0.31), 0.2)
	elif roll < 0.5:
		_box(_hips[0], Vector3(0.08, 0.26, 0.3), _mat("satchel", Color(0.35, 0.22, 0.12), 0.8), Vector3(-0.12, -0.05, 0), 0.4)
	has_umbrella = outfit != Outfit.RAINCOAT and _rng.randf() < 0.3
	_commit()
	if has_umbrella:
		_build_umbrella(accent_color)


func animate(delta: float) -> void:
	super.animate(delta)
	if is_fallen():
		return
	if cower > 0.01:
		for i: int in 2:
			var sign := 1.0 if i == 0 else -1.0
			_shoulders[i].rotation.x = lerpf(_shoulders[i].rotation.x, 2.7, cower)
			_shoulders[i].rotation.z = lerpf(_shoulders[i].rotation.z, 0.35 * sign, cower)
			_elbows[i].rotation.x = lerpf(_elbows[i].rotation.x, 2.3, cower)
		_head.rotation.x = lerpf(_head.rotation.x, 0.45, cower)
	if _umbrella != null:
		_umbrella.visible = cower < 0.5
		if cower < 0.5:
			_shoulders[1].rotation.x = 0.5
			_shoulders[1].rotation.z = 0.0
			_elbows[1].rotation.x = 1.3


## Nach dem Umfallen wieder aufstehen (fall() hat den Körper gekippt).
func get_up(time := 0.9) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "basis", Basis.IDENTITY, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", Vector3.ZERO, time)
	tween.chain().tween_callback(func() -> void: _dead = false)


func _torso(mat: Material, size: Vector3) -> void:
	_box(_spine, size, mat, Vector3(0, 0.3, 0), 0.4)
	_box(_spine, Vector3(size.x - 0.04, 0.16, size.z - 0.02), mat, Vector3(0, -0.02, 0), 0.4)


func _build_head(skin: Material) -> void:
	_box(_head, Vector3(0.1, 0.1, 0.1), skin, Vector3(0, -0.04, 0), 0.6)
	_box(_head, Vector3(0.21, 0.25, 0.23), skin, Vector3(0, 0.1, 0), 0.6)
	var eye := _mat("eye", Color(0.04, 0.04, 0.05), 0.5)
	for x: float in [-0.05, 0.05]:
		_box(_head, Vector3(0.04, 0.02, 0.01), eye, Vector3(x, 0.13, -0.115), 0.3)


func _hair() -> void:
	var hair := _mat("hair", _hair_colors[_rng.randi() % _hair_colors.size()], 0.8)
	match _rng.randi() % 3:
		0:
			_box(_head, Vector3(0.23, 0.1, 0.25), hair, Vector3(0, 0.22, 0.01), 0.6)
		1:
			_box(_head, Vector3(0.24, 0.26, 0.12), hair, Vector3(0, 0.12, 0.08), 0.6)
			_box(_head, Vector3(0.23, 0.08, 0.24), hair, Vector3(0, 0.23, 0.0), 0.6)
		_:
			var cap := _mat("cap", [Color(0.1, 0.1, 0.1), Color(0.6, 0.1, 0.15), Color(0.1, 0.3, 0.5)][_rng.randi() % 3], 0.7)
			_box(_head, Vector3(0.24, 0.08, 0.25), cap, Vector3(0, 0.24, 0), 0.6)
			_box(_head, Vector3(0.18, 0.02, 0.1), cap, Vector3(0, 0.21, -0.15), 0.3)


func _build_umbrella(color: Color) -> void:
	_umbrella = Node3D.new()
	_umbrella.name = "Umbrella"
	add_child(_umbrella)
	var shaft := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.012
	stick.bottom_radius = 0.012
	stick.height = 0.95
	stick.radial_segments = 4
	stick.rings = 1
	shaft.mesh = stick
	shaft.material_override = _mat("stick", Color(0.2, 0.2, 0.22), 0.5, 0.5)
	shaft.position = Vector3(0.25, 1.72, -0.42)
	_umbrella.add_child(shaft)
	var canopy := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 0.62
	cone.height = 0.24
	cone.radial_segments = 8
	cone.rings = 1
	canopy.mesh = cone
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.75)
	cloth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloth.emission_enabled = true
	cloth.emission = color
	cloth.emission_energy_multiplier = 0.6
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	canopy.material_override = cloth
	canopy.position = Vector3(0.25, 2.25, -0.42)
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_umbrella.add_child(canopy)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.6
	ring.outer_radius = 0.64
	ring.rings = 12
	ring.ring_segments = 3
	rim.mesh = ring
	rim.material_override = _emit("rim", color, 3.0)
	rim.position = Vector3(0.25, 2.13, -0.42)
	_umbrella.add_child(rim)
	for mi: MeshInstance3D in [shaft, canopy, rim]:
		mi.visibility_range_end = 80.0


# Weniger Polygone als die Gegner: es laufen viele Fußgänger gleichzeitig herum.
func _box(joint: Node3D, size: Vector3, mat: Material, offset: Vector3, roundness := 0.4) -> void:
	_add(joint, ProcMesh.rounded_box(size, roundness, 5, 8), mat, Transform3D(Basis(), offset))


func _tube(joint: Node3D, radius: float, length: float, mat: Material, offset: Vector3, rot: Vector3) -> void:
	var key := "%.3f_%.3f" % [radius, length]
	if not _tube_cache.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = length
		mesh.radial_segments = 6
		mesh.rings = 1
		_tube_cache[key] = mesh
	_add(joint, _tube_cache[key], mat, Transform3D(Basis.from_euler(rot), offset))
