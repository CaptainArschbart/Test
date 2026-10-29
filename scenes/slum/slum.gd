extends Node3D
## Slum-Map "Sektor 7": Cyberpunk-Slum im PS1/PS2-Stil aus dem Mapkit (scenes/slum/kit/).
##
## Vier Viertel um eine Kreuzung: Nordost Wohnblöcke mit Feuertreppen und Hinterhof, Nordwest
## Lagerhallen „A2“ mit Containerhof, Südwest Shanty-Viertel auf Stelzen, Südost Markt mit Bars
## und Hotel. Die Geometrie steht als Kit-Knoten in slum.tscn (erzeugt mit tools/gen_slum_map.py,
## im Editor normal bearbeitbar). Dieses Skript macht nur Regen und F11.

## Regen um die Kamera (aus spart Leistung).
@export var rain := true
@export var rain_amount := 2600
## Sichtbarer Regen-Würfel um die Kamera in Metern.
@export var rain_extent := Vector3(26, 14, 26)

var _rain: GPUParticles3D


func _ready() -> void:
	var atmosphere := WorldAtmosphere.new()
	atmosphere.name = "WorldAtmosphere"
	add_child(atmosphere)
	var content := CityContent.new()
	content.name = "CityContent"
	add_child(content)
	if rain:
		_rain = _create_rain()
		add_child(_rain)
		atmosphere.bind_rain(_rain)


func _process(_delta: float) -> void:
	if _rain == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_rain.global_position = cam.global_position + Vector3.UP * rain_extent.y * 0.4


func _unhandled_input(event: InputEvent) -> void:
	# F11 wechselt zwischen Fenster und Vollbild.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		Settings.toggle_fullscreen()


## Regen als schmale, nach unten gestreckte Quads. local_coords aus: Tropfen bleiben in der Welt,
## wenn man läuft, der Emitter folgt nur der Kamera.
func _create_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Rain"
	p.amount = rain_amount
	p.lifetime = 1.1
	p.preprocess = 1.0
	p.local_coords = false
	p.visibility_aabb = AABB(-rain_extent, rain_extent * 2.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(rain_extent.x * 0.5, 1.0, rain_extent.z * 0.5)
	mat.direction = Vector3(0.08, -1, 0.03)
	mat.spread = 2.0
	mat.initial_velocity_min = 16.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3(0, -6, 0)
	mat.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012, 0.42)
	var drop := StandardMaterial3D.new()
	drop.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.albedo_color = Color(0.62, 0.7, 0.85, 0.28)
	drop.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.disable_receive_shadows = true
	quad.material = drop
	p.draw_pass_1 = quad
	return p
