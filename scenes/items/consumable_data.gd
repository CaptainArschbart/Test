class_name ConsumableData
extends ItemData
## Ein Item, das man mit "use_item" (Rechtsklick) verbraucht: Essen, Trinken, Stims.
##
## Jeder Wert über 0 füllt die passende Leiste in PlayerStats auf. Mit
## speed_multiplier > 1 läuft der Spieler für boost_duration Sekunden schneller.

@export var heal := 0.0
@export var stamina := 0.0
@export var food := 0.0
@export var water := 0.0
## Laufgeschwindigkeit während des Boosts (1 = kein Boost).
@export var speed_multiplier := 1.0
@export var boost_duration := 0.0
## Erscheint nach dem Benutzen, z. B. "getrunken".
@export var use_verb := "benutzt"
