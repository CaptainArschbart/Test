class_name UalLibrary
extends RefCounted
## Animationen der Universal Animation Library 1 und 2, übertragen auf das Skelett der Modular-Men-
## Figuren (Schedule 1, P5-3). Erzeugt von tools/retarget_ual.gd; eine Bibliothek für Fußgänger,
## Gegner und Verkäufer. Im AnimationPlayer heißen sie "ual/<Name>", z. B. "ual/LayToIdle".
## Frauen (City Pack, gleiches Skelett, andere Proportionen) bekommen eine eigene (WOMAN).

const PATH := "res://assets/animations/retargeted/ual_mm.res"
const PATH_WOMAN := "res://assets/animations/retargeted/ual_mw.res"
const NAME := "ual"
## Aufstehen aus der Rückenlage (UAL2). Startet liegend, Füße nach vorn, endet stehend am Ursprung.
const GET_UP := "ual/LayToIdle"
## Rückwärts umgeworfen (UAL2), endet auf dem Rücken liegend wie GET_UP beginnt.
const KNOCKBACK := "ual/Hit_Knockback"

static var _libraries := {}


## Hängt die Bibliothek an einen AnimationPlayer einer MM-Figur (einmal geladen, von allen geteilt).
## woman = Frauenfigur aus dem City Pack.
static func attach(player: AnimationPlayer, woman := false) -> bool:
	if player == null:
		return false
	if player.has_animation_library(NAME):
		return true
	var path := PATH_WOMAN if woman else PATH
	if not _libraries.has(path):
		_libraries[path] = load(path) as AnimationLibrary if ResourceLoader.exists(path) else null
	var library: AnimationLibrary = _libraries[path]
	if library == null:
		return false
	player.add_animation_library(NAME, library)
	return true
