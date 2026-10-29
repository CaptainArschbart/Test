# Fix: Parserfehler „Cannot infer the type of holder“ · Claude (für Arschi) · PR #40

## 2026-10-29 · Doppelte Funktion und fehlende Sound-Helfer nach den Merges

- Ursache: Nach den Merges von #34 (Multiplayer-Playermodel) und #36 (SMG/Kontaktgranate) stand `get_reload_progress()` zweimal in `scenes/weapons/weapon_holder.gd`. Damit kompilierte die Klasse `WeaponHolder` nicht, `_player.weapon_holder` hatte keinen Typ mehr und `var holder := …` in `player_hands.gd:419` (und `player_movement.gd`, `player_avatar_sync.gd`) meldete den Fehler.
- Fix: die Variante aus #36 (0 = lädt nicht nach) entfernt, die aus #34 (-1 = lädt nicht nach) behalten. Alle Aufrufer passen dazu: Kippen der Waffe nur während des Nachladens, `_update_magazine` prüft `t > 0`, `PlayerBody` braucht -1 für „lädt nicht“.
- Zweiter Fehler beim Durchsehen gefunden: `scenes/traffic/vehicle_sounds.gd` nutzte `EnemySounds.MIX_RATE` und `_to_stream()`, die seit dem Sound-PR (324e972) nicht mehr existieren. Dadurch kompilierten `traffic_car.gd`, `traffic_director.gd` und `civilian.gd`-Abhängige nicht. `MIX_RATE` und `_to_stream()` liegen jetzt lokal in `vehicle_sounds.gd`, `hit()` gibt `AudioStream` zurück (der Aufprall ist jetzt eine geladene Datei).
- Geänderte Dateien: `scenes/weapons/weapon_holder.gd`, `scenes/traffic/vehicle_sounds.gd`.
- Getestet (Godot 4.7.2 headless/xvfb): alle `.gd` mit `--check-only` ohne Parse-Fehler (außer den bekannten Autoload-Meldungen im `--script`-Modus). Hauptmenü, Testmap, Sektor 7 laden ohne `SCRIPT ERROR`. `test_weapons_smg_grenade` 47/0, `test_consumables` 45/0, `test_sector7_enemies` 15/0, `test_audio` 18/0.
- Offen / Hinweise:
  - `test_player_melee` 42 Checks: je Lauf schlägt ein anderer zeitkritischer Check fehl („Waffe weggesteckt“ nach 3 Frames, „Sichtfeld-Kick beim Dash“), einmal 0 Fehler. Wirkt wie Frame-Timing unter Software-Rendering, nicht wie Folge dieses Fixes.
  - `test_sector7_city` lief hier nicht innerhalb von 5 Minuten durch (Software-Rendering), nicht ausgewertet.
