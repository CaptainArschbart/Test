# Claude Update-Notice

Arbeitslog von **Claude** (Claude Code) in diesem Repo. Nur Claude schreibt in diese Datei; andere KIs (z. B. Cursor) führen ihre eigene Update-Notice. So überschreiben sich die PRs nicht gegenseitig.

**Regeln für Claude:**
- Vor jeder Arbeit `main` holen und die Update-Notices der anderen KIs (`*_updatenotice.md` im Repo-Root) lesen, aber nicht ändern.
- `AI_HANDOVER.md` nicht mehr anfassen, auch nicht den Abschnitt *Arbeitslog* (Wunsch von Arschi, 2026-10-25).
- Nach jedem Arbeitsgang unten einen Eintrag anhängen, im selben PR wie die Änderung. Alte Einträge nicht ändern, neuester unten.

Vorlage:

```text
### JJJJ-MM-TT · Kurztitel · Claude (für <Person>) · PR #
- Was: …
- Dateien: …
- Wichtig für die Nächsten: …
```

Die Einträge bis einschließlich PR #8 sind rückwirkend aus dem Arbeitslog in `AI_HANDOVER.md` übernommen. Dort beschreiben zum Teil noch „AI_HANDOVER.md“ als geänderte Datei, das war damals so.

---

### 2026-10-25 · Grundgerüst · Claude (für Arschi) · PR #1
- Was: Godot-4-3D-Basis angelegt. Hauptszene mit Himmel, Sonne, CSG-Testlevel; First-Person-Spieler (Laufen, Sprint, Sprung, Maus-Kamera, Respawn); Input Map `move_*`, `jump`, `sprint`; Physik-Layer `world`/`player`; F11 = Vollbild.
- Dateien: `project.godot`, `scenes/main/*`, `scenes/player/*`, `assets/*/.gitkeep`, `README.md`, `.gitignore`, `.gitattributes`.
- Wichtig: Konvention „Szene + Skript im eigenen Ordner unter `scenes/<name>/`“, `.uid`/`.import` gehören ins Repo.

### 2026-10-25 · Cyberpunk-Hauptmenü · Claude (für Arschi) · PR #2
- Was: Hauptmenü als neue Startszene. Neon-Skyline-Shader mit bewegtem Gitter, CRT-Overlay (Scanlines, Farbverschiebung, Glitch), Titel „NEON//GRID“, Knöpfe Start / Optionen / Beenden. Start blendet mit Glitch in `scenes/main/main.tscn` über. Optionen damals: Vollbild, VSync, Lautstärke in `user://settings.cfg`.
- Dateien: `scenes/menu/*` (neu), `project.godot` (`run/main_scene`), `README.md`.
- Wichtig: Theme steckt als Sub-Resource in `main_menu.tscn`. Kein Rückweg vom Spiel ins Menü.

### 2026-10-25 · Steuerungs-Optionen + Übernehmen · Claude (für Arschi) · PR #3
- Was: Neuer Autoload `Settings` (`autoload/settings.gd`) als einzige Stelle für Einstellungen (laden, anwenden, speichern). Optionsmenü mit Reitern „Anzeige & Audio“ und „Steuerung“: Mausempfindlichkeit, Maus-Y invertieren, Tastenbelegung (Tausch bei Doppelbelegung). Änderungen gelten erst nach „Übernehmen“; „Standard“ setzt zurück; „Zurück“ warnt einmal bei offenen Änderungen. `player.gd` liest Empfindlichkeit und Invertierung aus `Settings`.
- Zusammenführung: `scripts/game_settings.gd` von EnScapeZ ist im Autoload aufgegangen und wurde gelöscht. Gleiche Datei und Schlüssel, F11 speichert weiterhin sofort (`Settings.toggle_fullscreen()`), alte `settings.cfg` wird weiter gelesen.
- Dateien: `autoload/settings.gd` (neu), `project.godot` (`[autoload]`), `scenes/menu/main_menu.gd/.tscn`, `scenes/main/main.gd`, `scenes/player/player.gd`, `README.md`, `AI_HANDOVER.md`.
- Wichtig: Neue belegbare Aktion = in `Settings.REBINDABLE_ACTIONS` eintragen. Kein eigenes `preload` für Einstellungen mehr, immer den Autoload `Settings` benutzen.

### 2026-10-25 · Arbeitslog eingeführt · Claude (für Arschi) · PR #4
- Was: Abschnitt 8 „Arbeitslog“ mit Regel und Vorlage angelegt und die bisherigen Arbeitsgänge rückwirkend eingetragen.
- Dateien: `AI_HANDOVER.md`.

### 2026-10-25 · Hotbar + Inventar · Claude (für Arschi) · PR #5
- Was: Hotbar mit 9 Slots (Tasten 1–9, Mausrad) und Inventar-Fenster (Tab) mit 27 Rucksack-Slots im Neon-Stil. Drag & Drop zum Verschieben/Tauschen/Stapeln, Rechtsklick = Hotbar ↔ Rucksack, aus dem Fenster ziehen oder Q = wegwerfen. Items sind `ItemData`-Resources (6 Beispiele), Pickups in der Welt leuchten, drehen sich und werden beim Drüberlaufen eingesammelt. Neue Aktionen `inventory`, `drop_item`, `hotbar_1`…`hotbar_9` sind im Optionsmenü belegbar; die Tastenliste dort scrollt jetzt (`KeyScroll`).
- Dateien: `scenes/inventory/*` (neu), `scenes/items/*` (neu), `scenes/player/player.gd/.tscn`, `scenes/main/main.tscn` (Knoten `Pickups`), `scenes/menu/main_menu.tscn` (`KeyScroll` um `%KeyGrid`), `autoload/settings.gd` (`REBINDABLE_ACTIONS`), `project.godot` (Input Map), `README.md`, `AI_HANDOVER.md`.
- Wichtig für die Nächsten: HUD und Inventar hängen am Player, also hat jede Map mit `player.tscn` sie automatisch. Items in eine Map setzen = `scenes/items/pickup.tscn` instanzieren und `item` + `count` setzen. Items haben noch keine Wirkung und das Inventar wird nicht gespeichert. Mit Godot 4.7 headless getestet (Aufsammeln, Stapeln, Tauschen, Wegwerfen, Inventar öffnen, Menü).

### 2026-10-25 · Testmap „Neon District“ · Claude (für Arschi) · PR #6
- Was: Neue Testmap `scenes/testmap/testmap.tscn` im Cyberpunk-Stil des Menüs (Nacht, Nebel, Glow, Leuchtreklamen, Fassaden-Shader). Testzonen: Treppen mit 4 Stufenhöhen plus eine Treppe mit Rampen-Kollision, Rampen 15–50°, Tunnel mit sinkender Decke, Messwand, Sprunghöhe, Weitsprung-Lücken, Parkour-Turm aufs Dach, großer Platz mit Deckung und Brücke. 16 `Marker3D` in Gruppe `item_spawn` unter `Pickups/SpawnPoints` als Plätze für Items. *Start* im Menü lädt jetzt die Testmap; `scenes/main/main.tscn` bleibt unverändert und ist per F6 startbar.
- Dateien: `scenes/testmap/*` (neu), `scenes/menu/main_menu.gd` (nur Default von `game_scene`), `README.md`, `AI_HANDOVER.md`.
- Wichtig für die Nächsten: Der Player kann keine Stufen hochlaufen, schon 0,15 m blockt (headless getestet). Entweder Stufensteigen in `player.gd` einbauen oder Treppen wie `Stairs_RampCollision` mit unsichtbarer Rampe bauen. Inventar/HUD aus dem Hotbar-PR hängen am Player und sind damit automatisch in der Testmap; Pickups können als Instanzen unter `Pickups` an die `item_spawn`-Marker (Mittelpunkt ca. 0,5 m über dem Pad). Die Szene ist mit einem Python-Skript erzeugt, aber normal im Editor bearbeitbar.

### 2026-10-25 · Noclip-Modus · Claude (für Arschi) · PR #8
- Was: Flugmodus im Player. V schaltet um; dann ohne Kollision und Schwerkraft in Blickrichtung fliegen, Leertaste hoch, Strg runter, Shift ×3 schneller. Anzeige „NOCLIP“ oben links. Beide Tasten unter *Optionen → Steuerung* belegbar. Headless mit Godot 4.5 in der Testmap geprüft (hoch fliegen, durch die Grenzwand, nach dem Ausschalten fällt man wieder).
- Dateien: `scenes/player/player.gd`, `project.godot` (Aktionen `noclip`, `noclip_down`), `autoload/settings.gd` (`REBINDABLE_ACTIONS`), `README.md`, `AI_HANDOVER.md`.
- Wichtig für die Nächsten: `player.tscn` bewusst nicht angefasst (HUD im Code), damit es mit dem offenen Hotbar-PR nicht kollidiert. Konflikte mit Hotbar-PR und Pausemenü-Branch sind nur Einfügungen an denselben Stellen (`REBINDABLE_ACTIONS`, Input Map nach `sprint`, Kopf von `_physics_process`): beide Seiten behalten. Wer Noclip in einem Release nicht will, nimmt die zwei Einträge aus `REBINDABLE_ACTIONS` und die Aktion `noclip` raus. Schaltet man Noclip in einer Wand aus, schiebt `move_and_slide` den Player nur teilweise heraus.

### 2026-10-25 · Hotbar-PR mit main zusammengeführt · Claude (für Arschi) · PR #5
- Was: Merge-Konflikte nach Testmap (#6) und Noclip (#8) aufgelöst, beide Seiten behalten: Aktionen und `REBINDABLE_ACTIONS` enthalten jetzt Inventar, Hotbar und Noclip (19 belegbar). Bei offenem Inventar ist Noclip gesperrt (kein Umschalten, kein Fliegen). Beispiel-Items an den `item_spawn`-Markern der Testmap verteilt.
- Dateien: `scenes/player/player.gd`, `autoload/settings.gd`, `project.godot`, `README.md`, `AI_HANDOVER.md`, `scenes/testmap/testmap.tscn` (Pickups).

### 2026-10-25 · Eigene Update-Notice für Claude · Claude (für Arschi) · PR #9
- Was: `claude_updatenotice.md` angelegt, alle bisherigen Claude-Arbeiten (PR #1–#6, #8) rückwirkend eingetragen. Die beiden Hotbar-Einträge (PR #5) aus dem Arbeitslog in `AI_HANDOVER.md` entfernt; der Rest von `AI_HANDOVER.md` ist unverändert. Hinweis in `README.md` (Zusammenarbeit) angepasst.
- Dateien: `claude_updatenotice.md` (neu), `AI_HANDOVER.md` (nur die zwei PR-#5-Einträge raus), `README.md`.
- Wichtig für die Nächsten: Cursor-Update-Notices gab es zu diesem Zeitpunkt noch keine im Repo.

### 2026-10-25 · Pausemenü-PR (#7) mit main zusammengeführt · Claude (für Arschi) · PR #10 (ersetzt #7)
- Was: PR #7 von EnScapeZ/Cursor (Pausemenü, Audio-Busse, gemeinsame Optionen-Szene) hatte Merge-Konflikte mit main, weil inzwischen Hotbar/Inventar (#5) und die Claude-Update-Notice (#9) gemergt waren. #7 ist geschlossen, deshalb neuer PR auf Basis des Branches `cursor/pause-menu-shared-options` plus main. Beide Seiten behalten: Pausemenü und Pickups in `main.tscn` und `testmap.tscn`, Esc schließt zuerst das Inventar, erst das nächste Esc öffnet das Pausemenü. Die scrollbare Tastenliste aus #5 (`KeyScroll`) in die neue gemeinsame Szene `scenes/options/options_menu.tscn` übertragen, mit Mindesthöhe 240, sonst wäre sie im (zentrierten) Pausemenü 0 px hoch.
- Dateien: `scenes/main/main.tscn`, `scenes/testmap/testmap.tscn`, `scenes/menu/main_menu.tscn` (Version aus #7), `scenes/options/options_menu.tscn`, `scenes/player/player.gd` (nur Kommentar), `README.md` (Steuerungstabelle), `AI_HANDOVER.md` (nur Konfliktstellen aufgelöst, beide Inhalte zusammengeführt, keine neuen Einträge).
- Getestet: Godot 4.5 headless, alle Szenen laden; Testmap: Tab öffnet Inventar, Esc schließt es, nächstes Esc pausiert, Tab bei Pause wirkungslos, Optionen im Pausemenü zeigen 19 Tasten (38 Zellen) in 240 px Scrollbereich, Esc zurück und fortsetzen.
- Wichtig für die Nächsten: `scenes/menu/main_menu.tscn` enthält keine Optionen mehr, alles zu Optionen gehört nach `scenes/options/`.

### 2026-10-25 · Hauptmenü neu gestaltet · Claude (für Arschi) · PR #11
- Was: Titel und Knöpfe links mittig. Knöpfe größer (78 px hoch, 480 px breit, Schrift 34) und schräg (`StyleBoxFlat.skew`), Hover/Fokus magenta. Neuer Knopf *Spielstand laden* (`%LoadButton`), vorerst deaktiviert mit Tooltip, weil es noch kein Speichersystem gibt. Titel jetzt „NEON DISTRICT“ (Platzhalter, bis Arschi einen Namen nennt) als ein einzelnes Label ohne Cyan/Magenta-Kopien. Effekte deutlich schwächer: CRT-Overlay ohne Farbverschiebung (Uniform `aberration` entfernt), Scanlines 0,22 → 0,07, Rauschen 0,04 → 0,015, Glitch nur noch alle 5–10 s mit Stärke 0,3 und kleinem Streifenversatz; Glitch-Anfragen der Optionen werden im Hauptmenü auf 30 % gedämpft. Neuer Hintergrund-Shader: Sterne, Mond, Wolken, Flugtaxis, drei Häuserreihen mit Fenstern, Leuchtreklamen und Antennen-Blinklichtern, nasse Straße mit Spiegelung, links abgedunkelt für Lesbarkeit.
- Dateien: `scenes/menu/main_menu.tscn` (Knoten `TitleCyan`/`TitleMagenta` entfernt, `TitleBox` ist jetzt `VBoxContainer`, Footer direkt unter der Wurzel, Knopf-Theme als Sub-Resource `Theme_menu_buttons` nur für `%MainButtons`), `scenes/menu/main_menu.gd`, `scenes/menu/crt_overlay.gdshader`, `scenes/menu/menu_background.gdshader`, `README.md`.
- Nicht geändert: `scenes/ui/cyber_theme.tres`, `scenes/options/*`, `scenes/pause/*` (Options- und Pausemenü sehen aus wie vorher).
- Getestet: Godot 4.7.2 headless/Xvfb: Import ohne Fehler, Menü-Screenshots, Fokus-Stil, Optionen öffnen/schließen, *Spielstand laden* deaktiviert, *Start* lädt `Testmap`; `testmap.tscn` und `main.tscn` starten ohne Fehler.
- Wichtig für die Nächsten: Wer ein Speichersystem baut, schaltet `%LoadButton` frei (`disabled = false`, `pressed` verbinden). Den Spielnamen ändern = Text von `%Title` in `main_menu.tscn`.

### 2026-10-25 · Inventar-Fenster blieb leer offen · Claude (für Arschi) · PR #12
- Was: Arschi sah im Spiel ein leeres Inventar-Fenster (nur Überschriften, keine Slots), das sich nicht schließen ließ. Das Fenster war in `inventory_ui.tscn` standardmäßig sichtbar und wurde erst am Ende von `_ready` versteckt. Bricht `_ready` vorher ab oder lässt sich das Skript lokal nicht laden, bleibt es stehen. Jetzt ist `InventoryOverlay` in der Szene unsichtbar, `_ready` versteckt es als Erstes, und ein fehlender `Inventory`-Knoten am Player gibt eine klare Fehlermeldung statt eines hängenden Fensters.
- Ursache auf Arschis Rechner nicht sicher geklärt: Auf `main` (Godot 4.7, Testmap und `main.tscn`, auch über Menü → Start) tritt der Fehler nicht auf. Vermutlich ein lokaler Stand, bei dem `inventory_ui.gd` oder ein abhängiges Skript nicht lädt.
- Dateien: `scenes/inventory/inventory_ui.gd`, `scenes/inventory/inventory_ui.tscn`, `claude_updatenotice.md`.
- Wichtig für die Nächsten: Gelesen `cursor_updatenotice.md` (Cursor-Änderungen an Inventar/Hotbar vom 25.10. sind drin und unverändert). Falls das Fenster nach diesem Fix noch auftaucht: Godot-Ausgabe/Debugger-Fehler beim Start ansehen.

### 2026-10-25 · Menüs skalieren mit der Auflösung · Claude (für Arschi) · PR #13
- Was: Projekt-Stretch auf `canvas_items` mit Seitenverhältnis `expand` gestellt. Alle 2D-Oberflächen (Hauptmenü, Optionen, Pausemenü, Inventar, Hotbar, HUD) werden jetzt von der Basis 1280×720 gleichmäßig hochskaliert (1080p ×1,5, 1440p ×2, 4K ×3) statt bei hoher Auflösung klein zu bleiben bzw. sich zu strecken. Breitere oder höhere Bildschirme bekommen mehr Rand, nichts wird verzerrt. 3D wird weiter in voller Auflösung gerendert (`render_scale` aus den Optionen gilt unverändert). Das Optionsfenster im Hauptmenü war oben und unten am Bildschirmrand verankert und wurde auf hohen Bildschirmen (16:10, 4:3) mitgezogen; jetzt ist es mittig verankert mit fester Größe 780×588 (gleiche Größe wie vorher bei 720p).
- Dateien: `project.godot` (`[display]`: `window/stretch/mode`, `window/stretch/aspect`, nur angehängt), `scenes/menu/main_menu.tscn` (nur Anker/Offsets von `%OptionsPanel`).
- Getestet: Godot 4.7.2 unter Xvfb/OpenGL mit `--resolution` 1920×1080, 2560×1440, 3840×2160, 2560×1080 (21:9) und 1920×1200 (16:10): Hauptmenü, Optionen, Testmap mit HUD/Hotbar und Pausemenü sehen auf allen gleich aus, keine Skriptfehler.
- Wichtig für die Nächsten: Neue UI für 1280×720 bauen, sie skaliert automatisch. Nichts am Bildschirm oben und unten gleichzeitig verankern, wenn es eine feste Größe haben soll (bei 16:10 ist die Basis 1280×800), lieber mittig verankern oder einen `CenterContainer` nehmen.

### 2026-10-25 · Audio-Ausgabegerät wählbar · Claude (für Arschi) · PR #14
- Was: Im Reiter *Audio* der gemeinsamen Optionen (Haupt- und Pausemenü) gibt es oben die Zeile *Ausgabegerät* (`%OutputDeviceOption`) mit allen Geräten aus `AudioServer.get_output_device_list()`; „Default“ heißt dort „Systemstandard“. Die Liste wird bei jedem Öffnen neu gelesen. Wie alles andere gilt die Wahl erst nach *Übernehmen*, *Standard* setzt auf Systemstandard zurück. Gespeichert als `[audio] output_device` in `user://settings.cfg`. Ist das gespeicherte Gerät nicht angeschlossen, läuft der Ton über das Standardgerät, die Wahl bleibt aber gespeichert und erscheint in der Liste als „… (nicht verbunden)“.
- Dateien: `autoload/settings.gd` (neues Feld `output_device`, Konstante `DEFAULT_OUTPUT_DEVICE`, `_apply_output_device()`, in get_values/get_defaults/apply_values/load/save ergänzt, nichts umbenannt), `scenes/options/options_menu.gd`, `scenes/options/options_menu.tscn` (neue Knoten `OutputDeviceRow`, `OutputDeviceLabel`, `%OutputDeviceOption` vor `MasterRow`, `load_steps` unverändert).
- Getestet: Godot 4.7.2 unter Xvfb (Dummy-Audio, Liste nur „Default“): 11/11 Prüfungen (Anzeige „Systemstandard“, fehlendes Gerät → Ton über Default und Wahl bleibt in `settings.cfg`, Markierung „(nicht verbunden)“, Wechsel macht *Übernehmen* aktiv und greift erst danach, *Standard* setzt zurück). `testmap.tscn` und `main.tscn` starten ohne Skriptfehler.
- Nicht getestet: echter Gerätewechsel mit mehreren Soundkarten/Kopfhörern (im Container gibt es nur das Dummy-Gerät).

### 2026-10-25 · Auflösung wählbar · Claude (für Arschi) · PR #15
- Was: Im Reiter *Grafik* unter *Vollbild* neue Zeile *Auflösung* (`%ResolutionOption`). Liste aus `Settings.RESOLUTIONS` (1280×720 bis 3840×2160, 16:9, 16:10 und 21:9), gefiltert auf das, was auf den Monitor passt (`Settings.available_resolutions()`). Gilt im Fenstermodus nach *Übernehmen*: Fenster bekommt die Größe (höchstens Monitorgröße) und wird zentriert. Im Vollbild ist die Auswahl ausgegraut, weil Godot 4 die Monitorauflösung nicht umschaltet; dort gilt die Monitorauflösung und die Menüs skalieren über den Stretch-Modus aus PR #13 mit. Gespeichert als `[video] resolution` (`Vector2i`), Standard 1280×720. `apply()` setzt das Fenster nur bei einer geänderten Auflösung oder beim Wechsel Vollbild → Fenster neu, ein von Hand vergrößertes Fenster bleibt sonst so.
- Dateien: `autoload/settings.gd` (Feld `resolution`, Konstanten `RESOLUTIONS`/`DEFAULT_RESOLUTION`, `available_resolutions()`, `_apply_resolution()`, nur ergänzt), `scenes/options/options_menu.gd`, `scenes/options/options_menu.tscn` (Knoten `ResolutionRow`, `ResolutionLabel`, `%ResolutionOption` zwischen `FullscreenCheck` und `VsyncCheck`).
- Git: Auf dem Stand von PR #14 (Ausgabegerät) aufgebaut, weil beide dieselben Dateien ändern.
- Getestet: Godot 4.7.2 unter Xvfb mit 1920×1080-Bildschirm: 13/13 Prüfungen (Liste nur bis 1920×1080, Standard 1280×720, Fenstergröße ändert sich erst nach *Übernehmen*, 1600×900 gesetzt und gespeichert, erneutes `apply()` setzt nicht zurück, im Vollbild ausgegraut, *Standard* zurück auf 1280×720, zu große gespeicherte Größe wird auf Monitorgröße begrenzt und bleibt wählbar). `testmap.tscn`/`main.tscn` ohne Skriptfehler.
- Nicht getestet: echter Windows-Desktop mit Taskleiste/Fensterrahmen, mehrere Monitore.

### 2026-10-25 · Auflösung auch im Vollbild, kleinere Menüs · Claude (für Arschi) · PR #16
- Was: Die gewählte Auflösung gilt jetzt auch im Vollbild und ändert dort wirklich die Pixeldichte. Im Vollbild stellt `Settings._apply_resolution()` den Stretch-Modus des Root-Fensters auf `viewport` mit `content_scale_size` = gewählte Auflösung: Godot rendert alles (3D und Oberfläche) in dieser Größe und skaliert das fertige Bild auf den Monitor hoch (bei 1280×720 auf einem 1440p-Monitor also sichtbar gröber). Die Bildschirmauflösung des Monitors selbst schaltet Godot 4 nicht um. Im Fenster bleibt `canvas_items`, aber mit der gewählten Auflösung als Basisgröße, und das Fenster bekommt wie bisher diese Größe. Die Auswahl ist im Vollbild nicht mehr ausgegraut, die Liste enthält zusätzlich die Monitorauflösung („(Monitor)“). Der 3D-Deckel bei 1920 px (`RENDER_LONG_EDGE`) rechnet jetzt mit der tatsächlichen Rendergröße (`_render_size()`).
- Folge für alle UI: Die Basisgröße der Oberfläche ist jetzt die gewählte Auflösung statt fest 1280×720 (ersetzt den Teil von PR #13). Bei 1280×720 sieht alles aus wie vorher, bei höherer Auflösung ist die Oberfläche in Pixeln gleich groß und wirkt damit kleiner, wie in den meisten PC-Spielen.
- Menüs kleiner (Arschis Wunsch): `cyber_theme.tres` Schriftgrößen 22 → 18 (Standard, CheckButton, OptionButton, PopupMenu), Button 30 → 24, Tabs 20 → 17, Panel-Innenrand 32/24 → 24/18. Pausemenü 780 → 540 px breit, Titel 44 → 34. Optionen: Überschrift 30 → 24, Aktionsknöpfe 22 → 18, Beschriftungsspalte 200 → 160 px, Tastenbelegung-Liste 240 → 200 px hoch, Tastenknöpfe Schrift 20 → 16. Optionsfenster im Hauptmenü 780×588 → 620×430. Die großen Knöpfe des Hauptmenüs (eigenes Theme) sind unverändert.
- Dateien: `autoload/settings.gd` (`_apply_resolution()` umgebaut, neu `_clamped_resolution()`, `_render_size()`, `available_resolutions()` nimmt die Monitorauflösung dazu), `scenes/options/options_menu.gd` (`_update_resolution_enabled()` entfernt, Monitor-Markierung), `scenes/options/options_menu.tscn`, `scenes/pause/pause_menu.tscn`, `scenes/menu/main_menu.tscn` (nur Offsets von `%OptionsPanel`), `scenes/ui/cyber_theme.tres`.
- Getestet: Godot 4.7.2 unter Xvfb (2560×1600 und 1920×1080): Prüfskript (Monitorauflösung in der Liste und sortiert, im Vollbild aktiv, Vollbild rendert 1280×720/1920×1080/2560×1600, 3D-Deckel 0,75 bei 2560, gespeichert, zurück ins Fenster → `canvas_items` und Fenster 1600×900, *Standard* → 1280×720). Screenshots von Hauptmenü, allen Options-Reitern und Pausemenü bei 1280×720 und 1920×1080. `testmap.tscn`/`main.tscn` ohne Skriptfehler. Hinweis: Eine 16:9-Auflösung auf einem 16:10-Monitor wird wegen `expand` zu z. B. 1280×800 (kein schwarzer Rand).
- Nicht getestet: echtes exklusives Vollbild unter Windows (Xvfb hat keinen Fenstermanager).
- Wichtig für die Nächsten: UI nicht mehr auf feste 1280×720 auslegen, sondern mittig/über Anker bauen, sie muss auch bei 1920×1080 und mehr ohne Hochskalierung gut aussehen.

### 2026-10-25 · 4K verpixelt: Vollbild nativ, Oberfläche immer scharf · Claude (für Arschi) · PR #17
- Problem: Arschi meldete nach PR #16, dass das Spiel auf 4K stark verpixelt ist. Ursache: PR #16 hat im Vollbild alles (auch die Oberfläche) in der gespeicherten Auflösung gerendert, und die war von PR #15 meist noch 1280×720. Auf 4K wurde also ein 720p-Bild dreifach hochgezogen.
- Was:
  - Vollbild und Fenster haben jetzt getrennte Auflösungen.
    - `resolution` bleibt die Fenstergröße.
    - Neu ist `fullscreen_resolution` (`[video] fullscreen_resolution`). `Vector2i.ZERO` steht für die Monitorauflösung und ist der Standard. Alte `settings.cfg` haben den Schlüssel nicht und landen damit automatisch auf „Monitor“.
  - Der Stretch-Umbau aus PR #16 ist zurückgenommen. Das Root-Fenster wird nicht mehr angefasst, es gilt wieder `canvas_items` mit Basis 1280×720 aus `project.godot`. Die Oberfläche wird dadurch immer in voller Fenster- bzw. Monitorauflösung gezeichnet und ist scharf.
  - Eine kleinere Vollbild-Auflösung wirkt nur noch auf die 3D-Welt. `_apply_3d_scale()` multipliziert `scaling_3d_scale` mit `fullscreen_factor()`, z. B. 1280×720 auf 4K → 1/3.
  - Hochskaliert wird jetzt mit FSR statt bilinear, wenn der Renderer das kann. Mit dem Kompatibilitäts-Renderer bleibt es bilinear.
  - Der 1920-px-Deckel von EnScapeZ (`RENDER_LONG_EDGE`) gilt unverändert. Auf 4K läuft 3D also auch bei „Monitor“ mit Faktor 0,5, jetzt aber mit FSR.
  - Optionen: Die Liste *Auflösung* zeigt die Werte für den Modus, der gerade im Haken *Vollbild* steht.
    - Im Vollbild steht oben „Monitor (B × H)“, darunter die kleineren Auflösungen von groß nach klein.
    - Im Fenster stehen die Fenstergrößen wie bisher.
    - Beim Umschalten des Hakens wechselt die Liste.
- Die kleineren Menüs aus PR #16 (Theme, Pausemenü, Optionen) bleiben.
- Dateien:
  - `autoload/settings.gd`:
    - Neu: Feld `fullscreen_resolution` und `fullscreen_factor()`.
    - `_apply_resolution()` wieder ohne Stretch-Änderung.
    - `_apply_3d_scale()` mit Vollbild-Faktor und FSR.
    - Entfernt: `_clamped_resolution()` und `_render_size()`.
  - `scenes/options/options_menu.gd`: `_resolution_key()`, `_wanted_resolution()` und `_fill_resolutions()` je nach Modus.
  - `scenes/options/options_menu.tscn`: nur der Tooltip.
- Getestet: Godot 4.7.2 unter Xvfb mit 3840×2160, 16/16 Prüfungen:
  - Alte Datei (Vollbild + 1280×720) → Vollbild „Monitor“.
  - Stretch wieder `canvas_items` 1280×720.
  - 4K nativ → 3D 0,5.
  - 1920×1080 → 0,5, 1280×720 → 1/3.
  - Nur die Vollbild-Auflösung ändert sich, und sie wird gespeichert.
  - Die Liste wechselt mit dem Haken, die Wahl bleibt.
  - *Standard* → Fenster 1280×720 und Vollbild „Monitor“.
  - 4K-Screenshot: Pausemenü-Schrift scharf.
  - `testmap.tscn` ohne Skriptfehler.
- Nicht getestet: echtes Windows-Vollbild, FSR (im Container läuft nur der OpenGL-Kompatibilitäts-Renderer).
- Wichtig für die Nächsten: Soll 3D auf 4K wirklich nativ laufen, muss `RENDER_LONG_EDGE` erhöht werden. Das hatte EnScapeZ wegen Hängern auf 4K eingebaut, also vorher auf 4K testen.
