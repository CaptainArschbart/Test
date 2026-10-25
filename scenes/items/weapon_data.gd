class_name WeaponData
extends ItemData
## Ein Item, das man in der Hand halten und abfeuern kann (Hitscan).
##
## Liegt die Waffe im gewählten Hotbar-Slot, zeigt der WeaponHolder an der Kamera
## das Modell aus `view_scene` und schießt mit "fire", "reload" lädt nach.

## Schaden pro Treffer. Ziele mit take_hit() bekommen ihn übergeben.
@export var damage := 25.0
## Schuss pro Magazin.
@export_range(1, 200) var magazine_size := 12
## Mindestabstand zwischen zwei Schüssen in Sekunden.
@export var fire_interval := 0.18
## Dauer des Nachladens in Sekunden.
@export var reload_time := 1.2
## Reichweite des Strahls in Metern.
@export var max_range := 80.0
## Modell in der Hand (Szene mit Marker3D "Muzzle" für das Mündungsfeuer).
@export var view_scene: PackedScene
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
@export var empty_sound: AudioStream
