class_name WeaponData
extends ItemData
## Ein Item, das man in der Hand halten und abfeuern kann (Hitscan).
##
## Liegt die Waffe im gewählten Hotbar-Slot, zeigt der WeaponHolder an der Kamera
## das Modell aus `view_scene` und schießt mit "fire", "reload" lädt nach.
## "aim" (rechte Maustaste, halten) zoomt und hebt die Waffe vor das Auge; mit
## `has_scope` erscheint stattdessen das Zielfernrohr.

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
## Größe des Modells, wenn die Waffe als Pickup in der Welt liegt.
@export var pickup_scale := 2.2

## Verschiebung des Modells aus der Hüfte (lange Waffen weiter nach vorn).
@export var hip_offset := Vector3.ZERO

@export_group("Zielen")
## Sichtfeld der Kamera beim Zielen (Grad). Normal sind 80.
@export_range(5.0, 90.0) var aim_fov := 60.0
## Sekunden bis zum vollen Anschlag.
@export var aim_time := 0.15
## Punkt im Modell (Kimme bzw. Zielfernrohr), der beim Zielen in die Bildmitte rückt.
@export var sight_offset := Vector3(0.0, 0.06, 0.0)
## Abstand dieses Punktes vor der Kamera beim Zielen (Meter).
@export var aim_distance := 0.3
## Zusätzlicher Faktor auf die Mausempfindlichkeit beim Zielen. Der Zoom selbst
## verlangsamt die Maus schon im Verhältnis der Sichtfelder.
@export var aim_sensitivity := 1.0
## Zielfernrohr: bei vollem Anschlag Overlay statt Modell.
@export var has_scope := false
## Streuung aus der Hüfte (Grad). Beim Zielen geht sie auf 0.
@export var hip_spread_degrees := 0.0

@export_group("Rückstoß")
## Wie weit das Modell beim Schuss nach hinten zuckt (Meter).
@export var recoil_kick := 0.035
## Wie weit die Kamera beim Schuss nach oben springt (Grad).
@export var view_kick_degrees := 0.0

@export_group("Schleichen")
## Hörweite des Schusses für Gegner (Meter).
@export var noise_radius := 35.0

@export_group("Sounds")
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
@export var empty_sound: AudioStream
