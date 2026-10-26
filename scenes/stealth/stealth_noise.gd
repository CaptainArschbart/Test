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


static func emit(tree: SceneTree, position: Vector3, radius: float, source: Node = null, kind: StringName = STEP) -> void:
	if tree == null or radius <= 0.0:
		return
	for listener: Node in tree.get_nodes_in_group(GROUP):
		if listener != source and listener.has_method("hear_noise"):
			listener.hear_noise(position, radius, source, kind)
