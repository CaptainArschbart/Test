# Arschi Update-Notice

Arbeitslog von Arschis Seite (Claude für Arschi). Neuer Eintrag ganz unten. `enscapez_updatenotice.md` nur lesen.

### 2026-10-31 · NPCs berauben: Taschendiebstahl und bewaffneter Raub · Claude (für Arschi) · Branch `claude/npc-raub`
- Auftrag: Eine Mechanik, um Passanten zu berauben, leise per Taschendiebstahl oder bewaffnet.
- Vorher: `CivilianCrime` hatte schon einen Sofort-Taschendiebstahl (nur Bargeld, gab auch unbemerkt einen Stern), Hände hoch beim Zielen und Ausrauben erst nach dem Fesseln. Ohne Kabelbinder oder Handschellen ließ sich eine bedrohte Person nicht ausrauben.
- `scenes/crime/civilian_crime.gd`:
  - Taschendiebstahl: Prompt „Taschendiebstahl“ hockend, leise, langsam und hinter der Person (1,8 m). E startet einen Griff von 1,4 s (`PICK_TIME`). Prompt zeigt „Klauen … x %   Verdacht y %“. Der Verdacht steigt pro Sekunde um `(0,15 + Sichtbarkeit × 0,75 + Lärm × 1,2) × Wachsamkeit`, ×1,3 wenn die Person steht. Wachsamkeit wird pro Versuch zufällig 0,7–1,3 gewürfelt. Ab 100 %: „Erwischt!“, die Person ruft „Dieb!“, flieht, eine Fahndungsstufe (`pickpocket`). Hocke verlassen, zu schnell, nicht mehr dahinter (bis 2,2 m beim Folgen) oder Panik: abgebrochen, ohne Beute, ohne Fahndung. Unbemerkt gibt es jetzt keinen Stern mehr.
  - Bewaffneter Raub: Waffe auf eine isolierte Person zielen (wie bisher Hände hoch und eine Stufe `threat`). Neuer Prompt „Ausrauben (bedroht)“. E: „Okay, okay …“, Übergabe 1,6 s (`ROB_TIME`), Prompt „Tasche her! … x %“. Waffe runter oder Leute in der Nähe vorher: abgebrochen, die Person rennt weg. Nach der Übergabe „Nimm's, nimm's!“. Lässt man sie danach laufen: „Polizei!“, eine weitere Stufe (`robbery`). Wird sie vorher gefesselt (Prompt „Fesseln“ nach dem Raub), meldet sie nichts mehr.
  - Tasche: Bargeld 2–18 ¢ und Schmuck (jeder dritte Seed) wie bisher, neu Smartphone (30 %) und Gold-Uhr (10 %), gewürfelt aus `net_seed`. Alle drei Wege (Taschendiebstahl, bewaffnet, gefesselt durchsuchen) leeren dieselbe Tasche. Was nicht ins Inventar passt, bleibt drin.
- `autoload/wanted_manager.gd`: neue Tat `robbery` mit Gewicht 1.
- Neu: `tools/tests/test_npc_robbery.gd`, kleine Arena mit `player.tscn` und vier Passanten.
- Keine neue Input-Aktion (alles über `interact`). Keine Szene geändert.
- Getestet (Godot 4.7.2 stable, headless, in einem eigenen Worktree): `test_npc_robbery.gd` CHECKS 30 FAILS 0. Unbemerkt im Dunkeln: 2 ¢ und Schmuck, Verdacht 0,45, 0 Sterne. Erwischt (Wachsamkeit erzwungen 12): kein Geld, Flucht, 1 Stern. Vor die Person gegangen: abgebrochen. Bewaffnet: Hände hoch, 1 Stern, 5 ¢, nach dem Loslassen 2 Sterne und Flucht. Raub, dann gefesselt: Sterne bleiben bei 1. `test_apartments.gd` CHECKS 44 FAILS 0. Kein `SCRIPT ERROR`.
- Nicht getestet: im Fenster mit Maus, wie gut man einer gehenden Person hockend folgen kann, Werte bei echten Lichtern in Sektor 7. Multiplayer: wie bisher rechnet nur der Host, ein Client kann Passanten nicht berauben.
- Offen: Nahkampfwaffe als Drohung, Animation der Übergabe, Sync für Clients.
- Git: Branch `claude/npc-raub` aus `origin/main` (e22f2f6), Draft-PR mit Basis `main`.

### 2026-10-31 · Taschendiebstahl leichter, Person bleibt stehen · Claude (für Arschi) · Branch `claude/taschendieb-leichter`
- Auftrag: Taschendiebstahl etwas leichter machen, und die Person soll nicht aus der Reichweite laufen.
- `scenes/civilians/civilian.gd`: Während eines Griffs (`crime.is_being_picked()`) bleibt eine gehende, wartende oder stehende Person stehen. Weg und Blickrichtung bleiben, danach geht sie weiter. Bei Panik, Ducken oder Umfallen greift das nicht.
- `scenes/crime/civilian_crime.gd`:
  - Neu `is_being_picked()`.
  - Griff 1,2 s statt 1,4 s.
  - Start-Reichweite 2,0 m statt 1,8 m. Beim Griff 2,6 m statt 2,2 m, und der Winkel hinter der Person ist weiter (Skalarprodukt < -0,1 statt < -0,35).
  - Verdacht pro Sekunde `0,08 + Sichtbarkeit × 0,5 + Lärm × 0,9` statt `0,15 + × 0,75 + × 1,2`. Der Aufschlag ×1,3 für stehende Personen fällt weg, weil jetzt jede Person beim Griff steht. Wachsamkeit 0,6–1,1 statt 0,7–1,3.
- `tools/tests/test_npc_robbery.gd`: neuer Fall mit einer gehenden Person.
- Getestet (Godot 4.7.2 stable, headless): `test_npc_robbery.gd` CHECKS 34 FAILS 0. Die gehende Person bewegt sich während des Griffs 0,03 m (Abbremsen), danach geht sie weiter. Verdacht bei unbemerktem Griff im Dunkeln 0,14 (vorher 0,45). `test_apartments.gd` CHECKS 44 FAILS 0.
- Nicht getestet: Gefühl im Fenster mit Maus, Werte bei echten Lichtern in Sektor 7.
- Git: Branch `claude/taschendieb-leichter` aus `origin/main` (7d5689d), PR mit Basis `main`.

### 2026-11-01 · Editor-Spam „placeholder instance“ in civilian_crime.gd behoben · Claude (für Arschi) · Branch `claude/editor-bewohner`
- Fehler: Im Editor (nicht im Spiel) kam ständig `civilian_crime.gd:141 - Invalid call function 'is_client' in base 'Node (world_sync.gd)': Attempt to call a method on a placeholder instance`.
- Ursache: `slum_building.gd` ist `@tool` und baut bei `walk_in_apartments` das Wohnhaus per `ApartmentHouseScript.new()`. Mit `.new()` entstehen echte Instanzen statt Platzhaltern, also lief die Kette `ApartmentHouse` → `ApartmentBlock` → `Civilian.new()` → `CivilianCrime` im Editor wirklich. `_physics_process` rief dort `WorldSync.is_client()` auf, und Autoloads sind im Editor nur Platzhalter.
- `scenes/crime/apartment_block.gd`: `_spawn_residents()` macht im Editor nichts (`Engine.is_editor_hint()`), wie schon `ShopInterior` in `slum_building.gd`. Im Spiel ändert sich nichts. Im Editor stehen in den Wohnungen keine Bewohner mehr.
- Getestet (Godot 4.7.2 stable, headless): `slum.tscn` im Editor geöffnet, 400 Frames. Vorher 8059 dieser Fehler, nachher 0. `test_apartments.gd` CHECKS 55 FAILS 0.
- Git: Branch `claude/editor-bewohner` aus `origin/main` (c6c47b4), Draft-PR mit Basis `main`.

### 2026-11-01 · Leuchtschilder an Gebäuden kleiner, Eingänge frei · Claude (für Arschi) · Branch `claude/schilder-kleiner`
- Fehler: Ausleger-Schilder (z. B. NOODLES) waren viel zu groß, und vor manchen Läden hing ein Schild (薬局) vor dem Eingang.
- Ursache: In `slum_building.gd` war bei Schildern nur eine Kante fest, die andere folgte dem Seitenverhältnis der Textur. Ausleger (`_vertical_sign`) waren immer 3 m hoch, breite Texturen (256×96) ragten so 8 m aus der Wand. Front-Schilder (`_flat_sign`) hatten eine feste Breite, hohe Texturen (薬局 80×176, ホテル 80×200) wurden bei Läden 9 m hoch und hingen bis vor die Tür.
- `scenes/slum/kit/slum_building.gd`: neu `_sign_size(tex, max_w, max_h)` passt die Textur unverzerrt in einen Rahmen. Grenzen (Breite × Höhe): Ausleger 1,5 × 3,0 m, Laden-Front 3,2 × 1,1 m (vorher bis 4,2 m breit), Wohnhaus-Tür 2,4 × 0,9 m, Lagerhalle 1,8 × 1,0 m, Hochhaus wie bisher bis 9 m breit, höchstens 4 m hoch.
- Beispiele: NOODLES-Ausleger 1,5 × 0,56 m (vorher 8 × 3 m), 薬局-Ausleger unverändert 1,36 × 3 m, 薬局 über dem Laden 0,5 × 1,1 m (vorher 1,9 × 4,2 m+), NOODLES über dem Laden 2,9 × 1,1 m.
- Getestet (Godot 4.7.2 stable, headless): `slum.tscn` im Editor und das Spiel geladen, kein `SCRIPT ERROR`. Nicht im Fenster angesehen.
- Git: Branch `claude/schilder-kleiner` aus `origin/main` (264f362), Draft-PR mit Basis `main`.

### 2026-11-01 · Strommasten nicht mehr durch Laden-Markisen · Claude (für Arschi) · Branch `claude/markise-masten`
- Fehler: An drei Läden stand ein Strommast (`SlumProp` `POWER_POLE`) 0,5 m vor der Fassade, mitten in der Markise.
- Die Masten bleiben stehen, weil die Kabel (`Cables*` unter `Power`) genau an ihren Querträgern hängen. Stattdessen bekommt die Markise eine Lücke.
- `scenes/slum/kit/slum_building.gd`: neues Export `awning_gaps` (lokale x-Stellen, Mitte = 0). Die Markise samt rot-weißer Kante wird dort mit einer 0,5 m breiten Lücke (`AWNING_GAP`) geteilt. Ohne Einträge sieht alles aus wie vorher.
- `scenes/slum/slum.tscn`: Shop11 `(-1.5)`, Shop12 `(2.0)`, Shop39 `(-0.7)`, jeweils PowerPole11, 16 und 26.
- Getestet (Godot 4.7.2 stable, headless): Prüfskript über alle 41 Läden in `slum.tscn`, vorher 3 Masten in Markisen, nachher 0. `slum.tscn` im Editor geladen, kein `SCRIPT ERROR`. Nicht im Fenster angesehen.
- Git: Branch `claude/markise-masten` aus `origin/main` (4ce1772), Draft-PR mit Basis `main`.

### 2026-11-01 · Pausemenü kleiner, Optionen übersichtlicher · Claude (für Arschi) · Branch `claude/pause-kompakt`
- Wunsch: Pausemenü kleiner, Optionen übersichtlicher, Hinweise nur beim Drüberfahren mit der Maus.
- `scenes/pause/pause_menu.tscn`: Feld 320 statt 540 px breit, Titel 24 statt 34 px, Knöpfe 18 statt 24 px. Die Zeile „SPIEL ANGEHALTEN // ESC … // F11 …“ ist weg, Esc und F11 stehen jetzt im Tooltip von FORTSETZEN und OPTIONEN. Die Optionen im Pausemenü sind 600 × 430 statt 720 × 520 px groß (wie im Hauptmenü).
- `scenes/options/options_menu.gd/.tscn` (gilt für Haupt- und Pausemenü): Alle Erklärungen stehen in `HINTS` und erscheinen nur als Tooltip, auch über der Beschriftung der Zeile. Der lange Upscaling-Text (`UpscaleHint`) und der Text neben TASTENBELEGUNG sind keine sichtbaren Zeilen mehr. „Physik 30 Hz (schont die CPU)“ heißt jetzt „Physik 30 Hz“, „Render-Thread (experimentell, nach Neustart)“ heißt „Render-Thread“, der Rest steht im Tooltip. Grafik hat kleine Abschnitte ANZEIGE, QUALITÄT, LEISTUNG. Alle Zeilen haben dieselbe Beschriftungsbreite (160 px, vorher teils 220), Abstand zwischen Zeilen 6 statt 10 px.
- `tools/tests/test_options_scroll.gd`: prüft Tooltips, fehlende Hinweiszeilen und die schmale Pause.
- Getestet (Godot 4.7.2 stable, headless): `test_options_scroll.gd` CHECKS 35 FAILS 0, `test_resolution_window.gd` CHECKS 6 FAILS 0. Nicht im Fenster angesehen (Tooltip-Aussehen kommt aus dem Godot-Standard, `cyber_theme.tres` hat keinen Tooltip-Stil).
- Git: Branch `claude/pause-kompakt` aus `origin/main` (4b40dab), Draft-PR mit Basis `main`.
