class_name MeleeTuning
extends Resource
## Alle Werte für den unbewaffneten Nahkampf (Boxen und aufgeladener Dash-Schlag) an einer Stelle.
## Die Standardwerte stehen in melee_tuning.tres; dort im Inspector justieren.

@export_group("Boxen")
## Schaden pro Faustschlag.
@export var jab_damage := 18.0
## Jeder dritte Schlag einer Kombo ist ein Haken mit diesem Faktor auf Schaden und Rückstoß.
@export var hook_multiplier := 1.5
## Reichweite ab Kamera in Metern.
@export var jab_reach := 1.7
## Radius der Trefferkugel (verzeiht etwas Zielungenauigkeit).
@export var jab_radius := 0.28
## Mindestabstand zwischen zwei Schlägen in Sekunden.
@export var jab_interval := 0.3
## Zeit vom Drücken bis zum Treffer (Faust ganz vorn).
@export var jab_hit_time := 0.08
## Dauer der ganzen Schlagbewegung (raus und zurück).
@export var jab_duration := 0.28
## Innerhalb dieser Zeit nach einem Schlag zählt der nächste zur Kombo (Links/Rechts im Wechsel).
@export var combo_window := 0.65
## Rückstoß auf den Gegner in m/s.
@export var jab_knockback := 1.8
## Kurzes Anhalten des Spiels beim Treffer (Sekunden Echtzeit).
@export var jab_hitstop := 0.045
## Kamerawackeln beim Treffer (Trauma 0–1).
@export var jab_shake := 0.12
## So weit hören Gegner einen Treffer (Meter).
@export var jab_noise := 6.0

@export_group("Aufladen")
## Ab dieser Haltezeit beginnt das Aufladen (kürzer = normaler Schlag).
@export var charge_delay := 0.22
## Zeit bis voll aufgeladen.
@export var charge_time := 0.8
## Unter diesem Anteil passiert beim Loslassen nichts (Faust geht zurück in die Deckung).
@export_range(0.0, 1.0) var charge_min := 0.45
## Beim Aufladen läuft man so viel langsamer (Faktor).
@export_range(0.1, 1.0) var charge_move_factor := 0.6

@export_group("Dash")
## Weite des Dashs bei voller Ladung (bei charge_min entsprechend weniger, mind. dash_min_distance).
@export var dash_distance := 5.0
@export var dash_min_distance := 2.5
## Geschwindigkeit des Dashs in m/s.
@export var dash_speed := 17.0
## Trifft der Dash innerhalb dieser Reichweite (ab Körpermitte) auf einen Gegner, wird abgebrochen und geschlagen.
@export var dash_stop_reach := 1.3
## Senkrechte Tiefe, ab der vorne kein Boden mehr ist (Kante). Etwas mehr als eine Treppenstufe.
@export var dash_edge_depth := 0.7
## Wie weit vor dem Körper nach der Kante gesucht wird.
@export var dash_edge_probe := 0.55
## Sichtfeld-Zuschlag in Grad während des Dashs.
@export var dash_fov_kick := 9.0
## Kamerawackeln beim Losdashen.
@export var dash_shake := 0.18
## Pause bis zum nächsten aufgeladenen Angriff.
@export var power_cooldown := 1.6

@export_group("Powerschlag")
## Schaden bei voller Ladung (bei charge_min die Hälfte).
@export var power_damage := 65.0
@export var power_reach := 1.9
@export var power_radius := 0.45
## Rückstoß auf den getroffenen Gegner in m/s.
@export var power_knockback := 8.0
## Betäubung des getroffenen Gegners in Sekunden.
@export var power_stun := 1.2
## Schockwelle um den Einschlag: andere Gegner im Radius bekommen einen Teil des Schadens und werden weggestoßen.
@export var shockwave_radius := 2.6
@export_range(0.0, 1.0) var shockwave_damage_factor := 0.3
@export var shockwave_knockback := 5.0
@export var power_hitstop := 0.11
@export var power_shake := 0.5
@export var power_noise := 14.0
## Dauer der Schlagbewegung nach dem Dash.
@export var power_duration := 0.42
