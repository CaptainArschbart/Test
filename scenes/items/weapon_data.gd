class_name WeaponData
extends ItemData
## Ein Item, das man in der Hand halten und abfeuern kann (Hitscan).
##
## Liegt die Waffe im gewählten Hotbar-Slot, zeigt der WeaponHolder an der Kamera
## das Modell aus `view_scene` und schießt mit "fire", "reload" lädt nach.
## "aim" (rechte Maustaste, halten) zoomt und hebt die Waffe vor das Auge; mit
## `has_scope` erscheint stattdessen das Zielfernrohr.
##
## Alle Werte einer Waffe stehen in ihrer .tres unter scenes/items/data/ (pistol, sniper, smg),
## dort zum Justieren ändern. Mit `automatic` feuert die Waffe, solange "fire" gedrückt bleibt.

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
## Dauerfeuer: schießt, solange "fire" gehalten wird (alle fire_interval Sekunden).
@export var automatic := false

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
## Streuung aus der Hüfte (Grad). Beim Zielen geht sie auf aim_spread_degrees.
@export var hip_spread_degrees := 0.0
## Streuung im Anschlag (Grad).
@export var aim_spread_degrees := 0.0

@export_group("Dauerfeuer")
## Zusätzliche Streuung pro Schuss (Grad), wächst beim Dauerfeuer bis max_bloom_degrees.
@export var bloom_per_shot := 0.0
@export var max_bloom_degrees := 0.0
## So schnell geht die zusätzliche Streuung ohne Schießen zurück (Grad pro Sekunde).
@export var bloom_recovery := 8.0
## Faktor im Anschlag auf die zusätzliche Streuung.
@export_range(0.0, 1.0) var aim_bloom_factor := 0.5

@export_group("Rückstoß")
## Wie weit das Modell beim Schuss nach hinten zuckt (Meter).
@export var recoil_kick := 0.035
## Wie weit die Kamera beim Schuss nach oben springt (Grad).
@export var view_kick_degrees := 0.0
## Rückstoß klettert beim Dauerfeuer: bei voller Streuung ist der Sprung (1 + recoil_climb)-mal so groß.
@export var recoil_climb := 0.0
## Zufälliges Ausbrechen nach links/rechts pro Schuss (Grad), wächst mit der Streuung.
@export var view_kick_horizontal_degrees := 0.0
## Wie stark die Waffe beim Nachladen nach unten kippt (Radiant) und zur Seite rollt.
@export var reload_tilt := 0.9
@export var reload_roll := 0.0
## Hülsen fliegen am Marker3D "Eject" der Waffenszene heraus.
@export var eject_shells := false

@export_group("Schleichen")
## Hörweite des Schusses für Gegner (Meter).
@export var noise_radius := 35.0

@export_group("Sounds")
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
@export var empty_sound: AudioStream
