@tool
class_name SlumPiece
extends Node3D
## Basis für alle Mapkit-Teile (Gebäude, Props, Straßen, Schilder).
##
## Ein Teil baut seine Geometrie beim Start selbst aus den Exporten. Im Editor (@tool) baut es
## bei jeder Änderung im Inspector neu, die erzeugten Knoten werden nicht in die Szene gespeichert.
## Unterklassen überschreiben _build(b: SlumBuilder) und rufen für Exporte queue_rebuild() im Setter.

const GEN_META := &"slum_generated"

## Gleicher Seed = gleiches Aussehen. Für Varianten einfach ändern.
@export var seed_value := 1:
	set(v):
		seed_value = v
		queue_rebuild()

var rng := RandomNumberGenerator.new()
var _queued := false


func _ready() -> void:
	rebuild()


func queue_rebuild() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	_deferred_rebuild.call_deferred()


func _deferred_rebuild() -> void:
	_queued = false
	rebuild()


func rebuild() -> void:
	for child: Node in get_children():
		if child.has_meta(GEN_META):
			remove_child(child)
			child.queue_free()
	rng.seed = hash(seed_value) ^ hash(name)
	var b := SlumBuilder.new(self)
	b.solid_range = _solid_range()
	b.detail_range = _detail_range()
	_build(b)
	b.finish()
	for child: Node in get_children():
		if child.owner == null:
			child.set_meta(GEN_META, true)


## Von Unterklassen überschrieben.
func _build(_b: SlumBuilder) -> void:
	pass


## Sichtweite für Mesh bzw. Details (Aufkleber, Linien) in Metern, 0 = immer. Von Unterklassen
## überschrieben: Kleinkram verschwindet im Nebel, Gebäude bleiben (Silhouette).
func _solid_range() -> float:
	return 0.0


func _detail_range() -> float:
	return 0.0


## Fügt einen erzeugten Knoten hinzu (Licht, Label, Skript-Knoten). Wird beim Neubauen entfernt.
func add_gen(node: Node, at := Vector3.ZERO) -> Node:
	add_child(node)
	if node is Node3D:
		(node as Node3D).position = at
	return node


## Punktlicht, bei Bedarf flackernd (flicker 0..1).
func add_light(at: Vector3, color: Color, energy := 1.5, light_range := 6.0, flicker := 0.0, shadow := false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadow
	light.light_specular = 0.6
	light.distance_fade_enabled = true
	light.distance_fade_begin = 45.0
	light.distance_fade_length = 15.0
	add_gen(light, at)
	if flicker > 0.0 and not Engine.is_editor_hint():
		var f := SlumFlicker.new()
		f.amount = flicker
		f.base_energy = energy
		light.add_child(f)
	return light


func pick(options: Array) -> Variant:
	return options[rng.randi() % options.size()]
