class_name EnemyProfile
extends Resource
## Werte eines Gegnertyps (Straßengangster, Sicherheitsdienst, Scharfschütze …).
## Die .tres liegen in scenes/enemies/profiles/. Ein Enemy bekommt sein Profil über den Export
## `profile`; Werte hier ändern ändert alle Gegner dieses Typs.

enum Style { MELEE, PISTOL, RIFLE }
enum Look { GANGSTER, SECURITY, SNIPER, COP }

@export var display_name := "Gangster"
## Fraktion für Rufe und spätere Beziehungen (gang, security, police).
@export var faction: StringName = &"gang"
@export var look: Look = Look.GANGSTER
@export var style: Style = Style.MELEE
## Akzentfarbe (Neon-Streifen, Visier, Haare). Zustandsfarben kommen dazu.
@export var accent := Color(1.0, 0.2, 0.75)

@export_group("Leben")
@export var max_health := 80.0
## Kopftreffer (oberhalb von 1,55 m) machen so viel mehr Schaden.
@export var headshot_multiplier := 2.0
## Treffer aus dem Hinterhalt (Gegner ahnungslos, Spieler näher als 2,5 m).
@export var sneak_multiplier := 3.0
## Sekunden betäubt nach EMP oder Hinterhalt-Treffer, der nicht tötet.
@export var stun_time := 3.0

@export_group("Sehen und Hören")
@export var view_distance := 20.0
## Halber Öffnungswinkel in Grad.
@export var view_angle := 55.0
@export var sight_gain := 1.4
@export var awareness_decay := 0.12
@export var hearing_scale := 1.0
@export var flashlight := false
## Andere in diesem Radius hören den Alarmruf.
@export var shout_radius := 20.0

@export_group("Bewegung")
@export var walk_speed := 1.6
@export var run_speed := 4.4
## Bleibt bei Alarm auf seinem Posten (Scharfschütze).
@export var hold_position := false

@export_group("Kampf")
@export var damage := 12.0
## Todesursache auf dem Death-Screen (DeathScreen.CAUSES).
@export var death_cause: StringName = &"gang"
## Nahkampf: Reichweite. Fernkampf: größte Schussweite.
@export var attack_range := 1.8
## Fernkampf: diesen Abstand zum Spieler sucht er.
@export var preferred_distance := 10.0
## Sekunden zwischen Angriffen bzw. Schüssen einer Salve.
@export var attack_interval := 1.1
## Schüsse pro Salve, danach Pause.
@export var burst := 3
@export var burst_pause := 1.4
@export var magazine := 12
@export var reload_time := 2.0
## Trefferchance auf 10 m gegen einen stehenden, gut sichtbaren Spieler.
@export_range(0.0, 1.0) var accuracy := 0.55
## Zielzeit vor dem ersten Schuss (Scharfschütze: Laser sichtbar).
@export var aim_time := 0.6

@export_group("Beute")
## Item-Ressourcen, die er fallen lassen kann.
@export var loot_items: Array[ItemData] = []
## Chance je Eintrag in loot_items (gleicher Index), 0…1.
@export var loot_chances: PackedFloat32Array = PackedFloat32Array()
## Credchips: min/max (0 = keine).
@export var credits_min := 0
@export var credits_max := 0

@export_group("Erfahrung")
## XP für den Spieler, wenn er diesen Gegner tötet.
@export var xp_reward := 25

@export_group("Stimme")
## Tonhöhe der Rufe und Grunzer.
@export var voice_pitch := 1.0
