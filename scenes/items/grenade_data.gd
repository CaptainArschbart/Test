class_name GrenadeData
extends ItemData
## Wurfgranate. "fire" (Linksklick) wirft sie im Bogen, nach fuse_time geht sie hoch.
##
## Alles im Umkreis mit take_hit(damage, point, normal) bekommt den Schaden, wenn
## keine Wand dazwischen ist. Ein EMP leert außerdem die Ausdauer des Spielers,
## falls er selbst im Radius steht.

@export var damage := 30.0
@export var radius := 6.0
@export var fuse_time := 1.6
## Abwurfgeschwindigkeit in Blickrichtung (m/s).
@export var throw_speed := 13.0
## Mindestabstand zwischen zwei Würfen in Sekunden.
@export var throw_interval := 0.8
## Leert die Ausdauer des Spielers im Radius.
@export var drains_stamina := true
