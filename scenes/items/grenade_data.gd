class_name GrenadeData
extends ItemData
## Wurfgranate. "fire" (Linksklick) wirft sie im Bogen, nach fuse_time geht sie hoch.
## Mit `contact_fuse` (Kontaktgranate) explodiert sie stattdessen beim ersten Aufprall
## (Welt, Gegner, Auto).
##
## Alles im Umkreis mit take_hit(damage, point, normal) bekommt den Schaden, wenn
## keine Wand dazwischen ist; nach außen fällt er bis min_damage_fraction ab. Ein EMP leert
## außerdem die Ausdauer des Spielers, falls er selbst im Radius steht.
## Alle Werte stehen in der .tres unter scenes/items/data/ (emp_grenade, contact_grenade).

enum Blast { EMP, FRAG }

@export var damage := 30.0
@export var radius := 6.0
@export var fuse_time := 1.6
## Abwurfgeschwindigkeit in Blickrichtung (m/s).
@export var throw_speed := 13.0
## Mindestabstand zwischen zwei Würfen in Sekunden.
@export var throw_interval := 0.8
## Leert die Ausdauer des Spielers im Radius.
@export var drains_stamina := true
## Zündet beim ersten Aufprall statt nach fuse_time (fuse_time gilt dann nur als Notzündung).
@export var contact_fuse := false
## Anteil des Schadens am Rand des Radius (1 = überall voller Schaden).
@export_range(0.0, 1.0) var min_damage_fraction := 1.0
## Schaden am Werfer selbst, wenn er im Radius steht (Faktor auf den Schaden, 0 = keiner).
@export_range(0.0, 1.0) var self_damage_factor := 0.0
## Stoß auf frei bewegliche Körper (RigidBody3D) in der Mitte, fällt nach außen ab.
@export var impulse := 0.0
## Hörweite der Explosion für Gegner (Meter).
@export var noise_radius := 40.0
## Aussehen der Explosion: EMP-Kugel oder Feuerball mit Funken, Rauch und Staub.
@export var blast: Blast = Blast.EMP
@export var throw_sound: AudioStream
@export var explosion_sound: AudioStream
