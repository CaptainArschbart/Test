class_name UalLibrary
extends RefCounted
## Animationen der Universal Animation Library 1 und 2, übertragen auf das Skelett der Modular-Men-
## Figuren (Schedule 1, P5-3). Erzeugt von tools/retarget_ual.gd; eine Bibliothek für Fußgänger,
## Gegner und Verkäufer. Im AnimationPlayer heißen sie "ual/<Name>", z. B. "ual/LayToIdle".

const PATH := "res://assets/animations/retargeted/ual_mm.res"
const NAME := "ual"
## Aufstehen aus der Rückenlage (UAL2). Startet liegend, Füße nach vorn, endet stehend am Ursprung.
const GET_UP := "ual/LayToIdle"

static var _library: AnimationLibrary


## Hängt die Bibliothek an einen AnimationPlayer einer MM-Figur (einmal geladen, von allen geteilt).
static func attach(player: AnimationPlayer) -> bool:
	if player == null:
		return false
	if player.has_animation_library(NAME):
		return true
	if _library == null:
		if not ResourceLoader.exists(PATH):
			return false
		_library = load(PATH) as AnimationLibrary
	if _library == null:
		return false
	player.add_animation_library(NAME, _library)
	return true
