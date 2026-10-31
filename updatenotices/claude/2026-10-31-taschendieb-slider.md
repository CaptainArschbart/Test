# Taschendiebstahl als Doppel-Slider · Claude (für Arschi)

## 2026-10-31 · Griff und Verdacht in einem Balken · Branch `claude/taschendieb-slider`

- Auftrag: Das UI des Taschendiebstahls nach Arschis Skizze als waagerechten Doppel-Slider bauen.
- Vorher: Es gab keinen Balken. Der Prompt unter dem Fadenkreuz zeigte nur Text: „[E] Klauen … x %   Verdacht y %“.
- `scenes/crime/pickpocket_bar.gd` (neu, `PickpocketBar`): Ein Control, das sich selbst zeichnet. Ein langer, weißer Balken mit abgerundeten Enden und schwarzem Rand. Von links wächst Grün (Griff), von rechts wächst Rot (Verdacht). Die graue senkrechte Markierung (Totpunkt) liegt bei 60 % der Breite (`DEAD_POINT`). Gelbe Pfeile an beiden Spitzen zeigen die Richtung.
- Abbildung auf die Spiellogik (Werte unverändert: `PICK_TIME` 1,2 s, Verdachtsrate, Wachsamkeit):
  - Grün = `pick_progress` × Strecke vom linken Ende bis zum Totpunkt. Grün am Totpunkt heißt geklaut.
  - Rot = `suspicion` × Strecke vom rechten Ende bis zum Totpunkt. Rot am Totpunkt (Verdacht 100 %) heißt erwischt.
  - Entscheidung: Die Logik bleibt bei zwei getrennten Werten, die beide auf den Totpunkt zulaufen. Wer zuerst dort ist, entscheidet. Würde Rot erst an der grünen Spitze erwischen, hinge der Zeitpunkt vom Fortschritt ab. Dann wäre ein Griff kurz vor dem Ziel schwerer als am Anfang, und die abgestimmten Werte aus `claude/taschendieb-leichter` würden nicht mehr stimmen. Weil Rot bei 100 % genau am Totpunkt steht, berührt es Grün nie vor dem Erwischen. Das Bild passt also zur Skizze.
- `scenes/crime/civilian_crime.gd`:
  - Laufende Griffe stehen in der Gruppe `pickpocket_running`. Neu `CivilianCrime.picked_by(player)` liefert den Griff dieses Spielers. Neu `_end_pick()` beendet ihn an allen vier Stellen (fertig, erwischt, abgebrochen, gefesselt).
  - Der Prompt während des Griffs ist nur noch „Klauen …“, die Prozente zeigt der Slider.
- `scenes/player/item_user.gd`: erzeugt den Slider im `ItemHud` (480 × 24 px, 104 px unter der Bildschirmmitte, unter der Meldungszeile). Er ist sichtbar, solange der eigene Spieler einen Griff laufen hat. Das gilt auch, wenn man dabei kurz am Passanten vorbeischaut, denn der Prompt verschwindet dann.
- Multiplayer: wie vorher. Der Griff läuft nur auf dem Host, also zeigt nur der Host den Slider. Ein Client kann Passanten weiter nicht bestehlen (bekannte Sync-Lücke, nicht Teil dieses Auftrags). Es wird nichts Neues über das Netz geschickt.
- `tools/tests/test_npc_robbery.gd`: neue Prüfungen. Der Slider ist während des Griffs sichtbar, Grün liegt links vom Totpunkt, Rot rechts davon, er zeigt den Fortschritt und ist danach ausgeblendet.
- Getestet (Godot 4.7.2 stable, headless, eigener Worktree): `test_npc_robbery.gd` CHECKS 39 FAILS 0. Kein `SCRIPT ERROR`. Keine Zwei-Prozess-Tests, weil kein Netzcode geändert wurde und keiner den Taschendiebstahl prüft.
- Nicht getestet: das Aussehen im Fenster und in 4K (keine Screenshot-Tests). Bitte im Spiel ansehen: hockend hinter einen Passanten, E.
- Git: Branch `claude/taschendieb-slider` aus `origin/main` (59805ff), Draft-PR mit Basis `main`.
