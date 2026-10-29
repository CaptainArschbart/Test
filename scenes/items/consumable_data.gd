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

@export_group("Animation")
# Das Modell steht in ItemData.model (z. B. "injector", "can", "noodles", "bandage").
## Benutz-Animation aus ConsumableUse: "inject", "drink", "eat", "bandage".
## Leer = sofort verbraucht (altes Verhalten, ohne Animation).
@export var use_animation: StringName = &""
## Dauer des eigentlichen Benutzens in Sekunden (ohne Ziehen und Wegstecken).
## 0 = Standard der Animation. Der Effekt greift erst, wenn die Zeit ganz durch ist.
@export var use_time := 0.0
