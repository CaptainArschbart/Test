class_name MeleeData
extends ItemData
## Nahkampfwaffe. "fire" (Linksklick) schlägt kurz vor dem Spieler zu.
##
## Getroffene Knoten mit take_hit(damage, point, normal) bekommen den Schaden.

@export var damage := 40.0
@export var reach := 2.2
## Mindestabstand zwischen zwei Schlägen in Sekunden.
@export var swing_interval := 0.45
## Aufbrechen von Türen und versiegelten Behältern (Brechstange).
@export var breaks_locks := false
## Hörweite beim Aufbrechen, Meter.
@export var break_noise := 18.0
