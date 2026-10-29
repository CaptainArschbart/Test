class_name StealthNoise
extends RefCounted
## Geräusche für Gegner. Wer etwas hören soll, steht in der Gruppe "noise_listener"
## und hat `hear_noise(position: Vector3, radius: float, source: Node, kind: StringName)`.
##
## radius = Meter, bis zu denen das Geräusch ohne Wand dazwischen zu hören ist.
## Richtwerte: Schleichen 2,5, Gehen 7, Sprinten 14, Landung 8–20, Schuss 35, Explosion 40.

const GROUP := &"noise_listener"

const STEP := &"step"
const LAND := &"land"
const SLIDE := &"slide"
const CLIMB := &"climb"
const SHOT := &"shot"
const EXPLOSION := &"explosion"
const SHOUT := &"shout"
## Gewaltsames Aufbrechen (Brechstange, Tür, Tresor).
const BURGLARY := &"burglary"


static func emit(tree: SceneTree, position: Vector3, radius: float, source: Node = null, kind: StringName = STEP) -> void:
	emit_local(tree, position, radius, source, kind)
	# Multiplayer-Client: Gegner rechnet nur der Host, er muss eigene Geräusche auch hören.
	if tree == null or radius <= 0.0 or not _is_local_source(source):
		return
	var sync := tree.root.get_node_or_null(^"WorldSync")
	if sync != null:
		sync.call("forward_noise", position, radius, kind)


## Nur auf diesem Rechner (ohne Weiterleitung an den Host).
static func emit_local(tree: SceneTree, position: Vector3, radius: float, source: Node = null, kind: StringName = STEP) -> void:
	if tree == null or radius <= 0.0:
		return
	for listener: Node in tree.get_nodes_in_group(GROUP):
		if listener != source and listener.has_method("hear_noise"):
			listener.hear_noise(position, radius, source, kind)


## Eigene Spielerfigur oder eine selbst geworfene Granate.
static func _is_local_source(source: Node) -> bool:
	if source is Player:
		return (source as Player).controls_local_body()
	if source is ThrownGrenade:
		return not (source as ThrownGrenade).remote
	return false
