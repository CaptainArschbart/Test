# Skill-Bäume Kampf, Bewegung, Stealth · Claude (für Arschi)

## 2026-11-01 · Neue Aufteilung der drei Bäume

Auf Wunsch sind die drei Bäume jetzt **Kampf**, **Bewegung** und **Stealth** statt Kampf, Gauner und Tech. Reiter, Punkte (einer pro Stufe), Speichern und Multiplayer funktionieren wie in PR #65.

| Baum | Stufe | Skill | Wirkung | Wo |
|---|---|---|---|---|
| Kampf | 1 | Ruhige Hand | Streuung −30 % | `weapon_holder.gd` |
| Kampf | 1 | Schwere Fäuste | Nahkampf +25 % | `player_melee.gd`, `item_user.gd` |
| Kampf | 2 | Schnellladen (← Ruhige Hand) | Nachladen 35 % kürzer | `weapon_holder.gd` |
| Kampf | 2 | Sprengmeister (← Schwere Fäuste) | Granaten +30 % Schaden, +25 % Wurfweite | `grenade.gd`, `item_user.gd` |
| Kampf | 3 | Panzerhaut (← beide) | 20 % weniger Schaden | `player.gd` |
| Bewegung | 1 | Sprinter | Sprint 12 % schneller | `player.gd` (neu) |
| Bewegung | 1 | Ausdauernd | +30 % Ausdauer, 25 % schneller nachgeladen | `PlayerStats` |
| Bewegung | 2 | Rutschpartie (← Sprinter) | Rutschen startet 20 % schneller, bremst 25 % weniger | `player_movement.gd` (neu) |
| Bewegung | 2 | Kletterer (← Ausdauernd) | Klettern an Kanten 35 % schneller | `player_movement.gd` (neu) |
| Bewegung | 3 | Freiläufer (← beide) | Sprung 15 % höher, Fallschaden halbiert | `player.gd` (neu) |
| Stealth | 1 | Leise Sohlen | Schritte, Rutschen, Landungen 40 % leiser | `player_stealth.gd` |
| Stealth | 1 | Flinke Finger | Taschendiebstahl 35 % schneller, Verdacht 25 % langsamer | `civilian_crime.gd` |
| Stealth | 2 | Schatten (← Leise Sohlen) | Sichtbarkeit −25 % | `player_stealth.gd` |
| Stealth | 2 | Dietrich (← Flinke Finger) | Verschlossene Türen leise knacken (E) | `locked_door.gd` |
| Stealth | 3 | Kamera-Hack (← beide) | Ladenkameras zeichnen dich nicht auf | `shop_interior.gd` |

- **Gestrichen:** Zäh, Sanitäter, Feilscher und Großer Fang. Ihre Stellen im Code sind wieder wie vor dem Skill-System: Heilung in `item_user.gd`, Preise und Ladenraub in `shop_interior.gd`/`shop_ui.gd`, Bargeld und Raubzeit in `civilian_crime.gd`. `PlayerSkills.apply_stats` passt nur noch die Ausdauer an, nicht mehr die HP.
- **Alte Profile:** Gespeicherte Skills, die es nicht mehr gibt (z. B. `tough`), fallen beim Laden einfach weg. Der Punkt ist dann wieder frei.
- Baumfarben: Kampf Magenta, Bewegung Grün, Stealth Cyan.
- `test_skills` prüft die neuen Skills am echten Verhalten: Sprintgeschwindigkeit, Rutsch-Start, Kletterzeit an einer 1,2-m-Kante, Sprunggeschwindigkeit, Fallschaden, eine laufende Ladenkamera. `test_mp_sync` nutzt die neuen Skills für den Abgleich.
- Getestet mit Godot 4.7.2 headless:

| Test | Checks | Fehler | Anmerkung |
|---|---|---|---|
| `test_skills` | 72 | 0 | |
| `test_mp_sync -- host/client testmap` | 17 / 19 | 0 | Skills pro Spieler mit den neuen Bäumen |
| `test_player_move` | 7 | 0 | |
| `test_options_scroll` | 27 | 0 | |
| `test_consumables` | 45 | 0 | |
| `test_apartments` | 55 | 0 | |
| `test_npc_robbery` | 39 | 1 | „gehende Person bleibt beim Griff stehen“, auf `main` (4b40dab) genauso |
| `test_shop` | 43 | 1 | „Spieler zielt auf den Verkäufer“, auf `main` genauso |
| `test_player_melee` | 42 | 2 | „zu kurz aufgeladen: kein Dash“, „Cooldown“, auf `main` genauso |

Die vier roten Prüfungen kommen nicht aus diesem PR, sie schlagen auf dem unveränderten `main` identisch fehl. Vermutlich hängt das mit der Physikrate seit dem Performance-PR #64 zusammen (die Tests zählen feste Frames). Das sollte ein eigener Fix sein.

