class_name WeaponData
extends ItemData
## Ein Item, das man in der Hand halten und abfeuern kann (Hitscan).
##
## Liegt die Waffe im gewählten Hotbar-Slot, zeigt der WeaponHolder an der Kamera
## das Modell aus `view_scene` und schießt mit "fire", "reload" lädt nach.
## "aim" (rechte Maustaste, halten) zoomt und hebt die Waffe vor das Auge; mit
## `has_scope` erscheint stattdessen das Zielfernrohr.
##
## Alle Werte einer Waffe stehen in ihrer .tres unter scenes/items/data/ (pistol, sniper, smg,
## revolver, pump_shotgun …), dort zum Justieren ändern. Mit `automatic` feuert die Waffe, solange
## "fire" gedrückt bleibt, mit `burst_count` schießt ein Klick einen Feuerstoß. Schrotflinten
## schießen `pellets` Kugeln pro Schuss, deren Schaden mit der Entfernung fällt (damage_at).

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
## Waffenklasse (Ladensortiment, Gegner-Ausrüstung, später Munitionsart).
@export_enum("pistol", "smg", "rifle", "shotgun", "sniper") var weapon_class := "pistol"

@export_group("Schrot")
## Kugeln pro Schuss (1 = normale Waffe). Jede Kugel trifft für sich und macht `damage`.
@export_range(1, 24) var pellets := 1
## Kegel, in dem sich die Kugeln verteilen (Grad), kommt zur normalen Streuung dazu.
@export var pellet_spread_degrees := 0.0

@export_group("Schadensabfall")
## Bis hierhin voller Schaden (Meter). 0 = kein Abfall.
@export var falloff_start := 0.0
## Ab hier nur noch `min_damage_factor` × Schaden, dazwischen linear.
@export var falloff_end := 0.0
@export_range(0.0, 1.0) var min_damage_factor := 1.0

@export_group("Feuerstoß")
## Schüsse pro Abzug (Bullpup: 3). 1 = Einzelfeuer bzw. Dauerfeuer mit `automatic`.
@export_range(1, 6) var burst_count := 1
## Abstand der Schüsse im Feuerstoß (Sekunden); danach gilt fire_interval.
@export var burst_interval := 0.07

@export_group("Nachladen")
## Patrone für Patrone (Revolver, Pumpgun): reload_time gilt pro Patrone, Schießen bricht ab.
@export var reload_single := false

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


## Schaden einer Kugel auf `distance` Meter (Schadensabfall der Schrotflinten).
func damage_at(distance: float) -> float:
	return damage * falloff_factor(distance)


## 1 bis falloff_start, dann linear bis min_damage_factor bei falloff_end.
func falloff_factor(distance: float) -> float:
	if falloff_end <= falloff_start or falloff_end <= 0.0:
		return 1.0
	var t := clampf((distance - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0)
	return lerpf(1.0, min_damage_factor, t)
