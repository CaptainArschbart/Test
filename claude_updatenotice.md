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
