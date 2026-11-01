# Testfehler auf main · Claude (für Arschi)

## 2026-11-01 · Tests laufen fest mit 60 Hz Physik

Ursache: Die Option „Physik 30 Hz“ (#64) steht in `user://settings.cfg` (`physics_rate=30` in `%APPDATA%\Godot\app_userdata\Godot 3D Base\settings.cfg`). `Settings._ready()` lädt sie auch headless, also lief die Physik in den Tests mit 30 Hz. Die Tests warten feste Frame-Zahlen ab, die für 60 Hz gedacht sind. Dadurch hing das Ergebnis von den Einstellungen auf dem Rechner ab. Die Spiellogik rechnet mit `delta` und ist nicht falsch.

- `test_npc_robbery.gd`: 40 Physik-Frames sind bei 30 Hz 1,33 s, also länger als `CivilianCrime.PICK_TIME` (1,2 s). Der Griff war vorbei, die Person lief schon weiter.
- `test_player_melee.gd`: Das „zu kurze“ Aufladen dauerte bei 30 Hz doppelt so lang und reichte für einen Dash. Der Cooldown-Check wartete doppelt so lang und lag schon hinter dem Cooldown.
- `test_shop.gd`, „Spieler zielt auf den Verkäufer“: Der Test versetzt die Figur und prüft nach 2 Bildern. Bei 30 Hz mit Interpolation hängt die Kamera (`PlayerMovement.refresh_camera`) dann noch an der alten interpolierten Position. Hier war es nur ab und zu rot. Lokal mit 30 Hz lief der Test einmal grün, der Fehler ist also nicht sicher nachgestellt.
- Lösung: Jeder der drei Tests stellt am Anfang von `_run()` mit `_pin_physics_60()` die Physik auf 60 Hz und schaltet die Interpolation aus (`Settings.physics_rate = 60`, nicht gespeichert). Die 30-Hz-Variante prüft weiter `test_player_move.gd`.
- Andere Tests mit festen Frame-Zahlen können dasselbe Problem haben, wenn 30 Hz eingestellt ist. Geändert habe ich nur die drei genannten Tests, laufen lassen nur diese und `test_player_move`.
- Getestet mit Godot 4.7.2 headless und `physics_rate=30` in den lokalen Einstellungen:

| Test | Checks |
|---|---|
| test_npc_robbery | 39, 0 Fehler |
| test_shop | 43, 0 Fehler |
| test_player_melee | 42, 0 Fehler |
| test_player_move | 7, 0 Fehler |
