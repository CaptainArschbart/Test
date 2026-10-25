# Cursor Update-Notice

Arbeitslog von **Cursor** (Grok) in diesem Repo. Nur Cursor schreibt in diese Datei; andere KIs (z. B. Claude) führen ihre eigene Update-Notice. So überschreiben sich die PRs nicht gegenseitig.

**Regeln für Cursor:**
- Vor jeder Arbeit `main` holen und die Update-Notices der anderen KIs (`*_updatenotice.md` im Repo-Root, derzeit `claude_updatenotice.md`) lesen, aber nicht ändern. Liegt eine fremde Notice nicht im Arbeitsbaum, sie von `origin/main` lesen (`git show origin/main:claude_updatenotice.md`).
- `AI_HANDOVER.md` nicht mehr anfassen, auch nicht Ist-Stand, Änderungsprotokoll oder Arbeitslog (Wunsch von EnScapeZ, 2026-10-25).
- Nach jedem Arbeitsgang **unten** einen Eintrag anhängen, im selben PR wie die Änderung. Alte Einträge nicht ändern, neuester unten.

Vorlage:

```text
### JJJJ-MM-TT · Kurztitel · Cursor (für <Person>) · PR oder Branch
- Auftrag: …
- Was: …
- Dateien: …
- Entscheidungen: …
- Getestet: …
- Nicht getestet: …
- Git: …
- Offen / Wichtig für die Nächsten: …
```

Die Einträge bis einschließlich dem zweiten Merge von `origin/main` (PR #8 Noclip) sind rückwirkend aus Abschnitt 11 von `AI_HANDOVER.md` gekürzt. Ausführlich stehen sie dort noch (Stand Commit `a316675`). Ab diesem Eintrag gilt nur noch diese Datei.

---

### 2026-10-25 · Gemeinsame Optionen, Pausemenü, Audio-Busse · Cursor (für EnScapeZ) · Branch `cursor/pause-menu-shared-options`
- Was: Hauptmenü und Pausemenü (Esc) nutzen dieselbe Options-Szene `scenes/options/options_menu.tscn` mit Theme `scenes/ui/cyber_theme.tres` (Reiter Grafik / Audio / Steuerung, Wirkung erst nach „Übernehmen“). Neues Pausemenü `scenes/pause/pause_menu.tscn`. Audio-Busse Music/SFX (`default_bus_layout.tres`). `Settings` um `msaa`, `render_scale`, `music_volume`, `sfx_volume` erweitert.
- Dateien: `scenes/options/*`, `scenes/pause/*`, `scenes/ui/*`, `default_bus_layout.tres` (neu), `autoload/settings.gd`, `scenes/menu/main_menu.gd/.tscn`, `scenes/main/main.tscn/.gd`, `scenes/player/player.gd`.
- Wichtig für die Nächsten: **Jede neue Spielszene muss `res://scenes/pause/pause_menu.tscn` selbst instanziieren**, sonst tut Esc dort nichts (kein Autoload). Neue Einstellungen nur in `options_menu.tscn/.gd` bauen.

### 2026-10-25 · Regel gegen Merge-Konflikte · Cursor (für EnScapeZ) · Commit `761ef92`
- Was: `.cursor/rules/00_conflict_prevention.mdc` (`alwaysApply`): vor Dateiänderung Remote abgleichen, Features unter `scenes/<feature>/`, Unique Names, gemeinsame Dateien nur additiv, Konflikte nach Dateityp beide Seiten behalten, kein `--ours/--theirs`.
- Dateien: `.cursor/rules/00_conflict_prevention.mdc`.

### 2026-10-25 · Erster Merge origin/main (Testmap PR #6) · Cursor (für EnScapeZ) · Commit `3af8c95`
- Was: `origin/main` (Testmap „Neon District“) in den Branch gemergt. `PauseMenu` als letztes Kind in `scenes/testmap/testmap.tscn` ergänzt. Konflikte in `AI_HANDOVER.md` und `README.md` damals noch in diesen Dateien gelöst.
- Dateien: `scenes/testmap/testmap.tscn` (PauseMenu), Merge-Commit `3af8c95`.
- Wichtig: Start lädt die Testmap; ohne PauseMenu-Instanz dort tut Esc nichts.

### 2026-10-25 · Zweiter Merge origin/main (Noclip PR #8) · Cursor (für EnScapeZ) · Commit `a316675`
- Was: `origin/main` (`882ff59`, PR #8 Noclip) gemergt. Konflikte in `player.gd` (1) und `AI_HANDOVER.md` (3): beide Seiten behalten. `REBINDABLE_ACTIONS` und Input Map haben danach `noclip` + `noclip_down`. Pause friert Noclip mit ein (`_physics_process` early-return).
- Dateien: `scenes/player/player.gd`, `autoload/settings.gd`, `project.godot`, Merge-Commit `a316675` (Eltern `3af8c95` + `882ff59`).
- Getestet (damals, isoliertes APPDATA): pause_flow 33/0/1, options_flow 92/0 (8 Aktionen / 16 Zellen), noclip_flow 22/0, options_gui beide Panels 605 px hoch. Echte `settings.cfg` Hash unverändert `36AE68DD83F195FBE807EC5CB10BE3FCECA55649D0391757C4A2CD68AC8BE313`.

### 2026-10-25 · Regel 01_update_notice_rules.mdc · Cursor (für EnScapeZ) · uncommittet
- Auftrag: Als Systemarchitekt `.cursor/rules/01_update_notice_rules.mdc` anlegen: Cursor schreibt nur in die eigene Notice, Claudes Notice nur lesen, Zero-Bug-PR.
- Was: Datei mit Frontmatter `alwaysApply: true`, Abschnitte 1–3 wörtlich aus dem Auftrag, Abschnitt 4 Abbildung auf dieses Repo plus 8-Punkte-Prüfliste vor Commit/PR.
- Dateien: `.cursor/rules/01_update_notice_rules.mdc` (neu, 40 Zeilen, ungetrackt).
- Getestet: Datei gelesen, Abschnitte 1–3 stimmen mit dem Auftrag. Kein Godot-Lauf (keine Spieldatei).
- Git: nicht committet. Ein früherer Versuch, nur gestagte Merge-Dateien zu committen, scheiterte: `fatal: Exiting because of an unresolved conflict` (6 Dateien U).

### 2026-10-25 · Eigene Datei cursor_updatenotice.md, AI_HANDOVER.md nicht mehr beschreiben · Cursor (für EnScapeZ) · dieser Arbeitsgang
- Auftrag: Nicht mehr in `AI_HANDOVER.md` schreiben. Eigene Datei `cursor_updatenotice.md` anlegen. Die Notices der anderen (Claude) lesen und nur in die eigene schreiben, damit PRs dieselbe Datei nicht überschreiben.
- Gelesen (nur gelesen, nicht geändert):
  - `origin/main:claude_updatenotice.md` (Commit `8297ad1`, Merge PR #9 `9f6518e`). Claude schreibt seitdem nicht mehr in `AI_HANDOVER.md`. Einträge PR #1–#6, #8, #5-Merge, #9. Hinweis dort: „Cursor-Update-Notices gab es zu diesem Zeitpunkt noch keine im Repo.“
  - Arbeitslog in der lokalen `AI_HANDOVER.md` (Abschnitt 12) nur gelesen; Datei nicht editiert.
- Neu: `cursor_updatenotice.md` (diese Datei).
- Geändert:
  - `.cursor/rules/01_update_notice_rules.mdc` Abschnitt 4: Cursor-Notice = `cursor_updatenotice.md`, Claude-Notice = `claude_updatenotice.md`. Cursor schreibt nicht mehr in `AI_HANDOVER.md`.
  - `.cursor/rules/ai-handover.mdc`: Protokollziel von `AI_HANDOVER.md` auf `cursor_updatenotice.md` umgestellt, sonst würde die alte Regel weiter in die gemeinsame Datei zwingen.
- Nicht geändert: `AI_HANDOVER.md` (auch kein Ist-Stand, kein Abschnitt 11, kein Arbeitslog). `claude_updatenotice.md` liegt in diesem Arbeitsbaum noch nicht (offener Merge ist `a6c4b08`, PR #9 kam danach).
- Entscheidungen:
  - **Eigene Datei statt Abschnitt 11.** Gleiches Muster wie Claude (PR #9). Zwei KIs, zwei Dateien, ein gemeinsames `AI_HANDOVER.md` ist der Konfliktmagnet.
  - **Neueste Einträge unten**, wie bei Claude. Anhängen am Ende statt Einfügen oben.
  - **Alte ausführliche Einträge 1–10 bleiben in `AI_HANDOVER.md`.** Hier nur gekürzt. Ab jetzt gilt nur diese Datei.
  - **`claude_updatenotice.md` nicht in den Arbeitsbaum kopiert.** Das ist Claudes Datei. Nach dem nächsten sauberen Merge von `origin/main` liegt sie hier von selbst.
- Getestet: `git show origin/main:claude_updatenotice.md` gelesen (komplette Datei). `git log a6c4b08..origin/main` = `8297ad1`, `9f6518e`. Diese Datei und die zwei Regeldateien geschrieben. Kein Godot-Lauf.
- Nicht getestet: Ob Cursor die geänderten Regeln lädt (kein Neustart). Merge der Hotbar (PR #5) und von PR #9. Commit/Push.
- Git: Branch `cursor/pause-menu-shared-options`, letzter Push `a316675`. Offener Merge mit `origin/main` zum Zeitpunkt `a6c4b08` (PR #5). `origin/main` ist inzwischen `9f6518e` (PR #9, eigene Claude-Notice). Konfliktmarker stehen weiter in `AI_HANDOVER.md` (8 Blöcke) und `README.md` (1 Block). Vier Szenen (`main.tscn`, `main_menu.tscn`, `player.gd`, `testmap.tscn`) sind im Arbeitsbaum ohne Marker, Git zählt sie weiter als unmerged. Nichts committet, nichts gepusht.
- Offen / Wichtig für die Nächsten:
  - Offenen Merge beenden: Konflikte in `README.md` und den vier Szenen nach `00_conflict_prevention.mdc` (beide Seiten). `AI_HANDOVER.md` nur soweit lösen, dass Marker weg sind — **keinen neuen Cursor-Text** dort einfügen; Claudes Arbeitslog-Seite Zeichen für Zeichen behalten.
  - Danach `origin/main` (`9f6518e`) erneut einmergen, damit `claude_updatenotice.md` im Branch liegt. Claudes Datei nicht editieren.
  - `KeyScroll` in `scenes/options/options_menu.tscn` (19 Aktionen) ist eine lokale Extra-Änderung, noch ungestaged.
  - Zero-Bug-Prüfliste, erst dann Commit/Push. `gh` ist auf dieser Maschine nicht installiert; PR über Compare-Link.
  - Echte `settings.cfg` nicht anfassen (Hash `36AE68DD83F195FBE807EC5CB10BE3FCECA55649D0391757C4A2CD68AC8BE313`).

### 2026-10-25 · Offenen Hotbar-Merge verworfen, Claude hat das schon · Cursor (für EnScapeZ) · dieser Arbeitsgang
- Auftrag: Das nicht voll zu Ende fixen; Claude hat es schon gemacht.
- Was: Offenen Merge von `origin/main` (`a6c4b08`, PR #5 Hotbar/Inventar) mit `git merge --abort` abgebrochen. Hotbar, Inventar, Pickups, Claudes `KeyScroll` und `claude_updatenotice.md` (PR #9) nicht nachgebaut. `scenes/options/options_menu.tscn` (lokales KeyScroll für 19 Aktionen) auf `a316675` zurückgesetzt.
- Behalten: `cursor_updatenotice.md`, `.cursor/rules/01_update_notice_rules.mdc`, `.cursor/rules/ai-handover.mdc` (vorher nach `%TEMP%` kopiert, nach dem Abort zurückgelegt).
- Getestet: `git status` nach Abort: `M .cursor/rules/ai-handover.mdc`, `?? .cursor/rules/01_update_notice_rules.mdc`, `?? cursor_updatenotice.md`. HEAD wieder `a316675`. Keine `UU`, kein `MERGE_HEAD`.
- Nicht getestet: erneuter Merge von `origin/main` (`9f6518e`).
- Git: kein Commit, kein Push. Branch sauber außer den drei Cursor-Notice-Dateien.
- Offen: Wenn `origin/main` später einmergt wird, Claudes Dateien so lassen. Nicht in `AI_HANDOVER.md` oder `claude_updatenotice.md` schreiben.

### 2026-10-25 · git pull · Cursor (für EnScapeZ) · dieser Arbeitsgang
- Auftrag: `git pull`.
- Was: `git pull` auf `cursor/pause-menu-shared-options`. Ausgabe: `Already up to date.` (lokal = `origin/cursor/pause-menu-shared-options` = `a316675`). Fetch brachte zusätzlich `origin/main` `9f6518e` → `435477b` und den neuen Remote-Branch `origin/claude/project-thread-dodbnm`. Weder gemergt noch ausgecheckt.
- Dateien: keine.
- Git: kein Commit, kein Push. Lokale uncommittete Cursor-Dateien unverändert (`ai-handover.mdc` geändert, `01_update_notice_rules.mdc` und `cursor_updatenotice.md` ungetrackt).

### 2026-10-25 · git pull (erneut) · Cursor (für EnScapeZ) · dieser Arbeitsgang
- Auftrag: `git pull`.
- Was: Erneut `Already up to date.` HEAD `435477b` (Merge PR #10). Branch ist `ahead 8` gegenüber `origin/cursor/pause-menu-shared-options` (lokale Commits, nicht gepullt weil Remote nichts Neues hat). Ungetrackt: `01_update_notice_rules.mdc`, `cursor_updatenotice.md`.
- Dateien: keine außer dieser Notice.

### 2026-10-25 · git push · Cursor (für EnScapeZ) · dieser Arbeitsgang
- Auftrag: `git push`.
- Was: `cursor/pause-menu-shared-options` nach `origin` geschoben: `a316675..435477b`. Ausgabe ohne Fehler.
- Nicht mitgeschoben (ungetrackt): `.cursor/rules/01_update_notice_rules.mdc`, `cursor_updatenotice.md`.

### 2026-10-25 · Cursor-Notice immer mit committen und pushen · Cursor (für EnScapeZ) · dieser Arbeitsgang
- Auftrag: `cursor_updatenotice.md` muss unbedingt und immer mit `git push` hochgeladen werden und bei jeder Änderung dabei sein.
- Was: Regel festgeschrieben. Letzter Push (`a316675..435477b`) hat die Notice nicht mitgenommen, weil sie ungetrackt war — das ist der Fehler, der nicht wieder vorkommen darf.
- Neu:
  - `.cursor/hooks.json` + `.cursor/hooks/require-cursor-notice.py`: blockt `git commit`/`git push`, wenn `cursor_updatenotice.md` ungetrackt oder nicht mitgestaged/committed ist (`failClosed: true`).
- Geändert:
  - `.cursor/rules/01_update_notice_rules.mdc`: Absatz „IMMER mit committen und pushen“.
  - `.cursor/rules/ai-handover.mdc`: wieder auf `cursor_updatenotice.md` gestellt (die alte AI_HANDOVER-Version war nach dem Main-Merge wieder da) plus Pflicht add/commit/push.
- Getestet: Hook-Skript mit `python` 3.14 vorhanden. Marker-Check und Commit folgen in demselben Arbeitsgang.
- Git: dieser Eintrag wird mit `git add cursor_updatenotice.md` in denselben Commit gepackt und danach gepusht.

### 2026-10-25 · Notice sofort auf GitHub, 100 % immer mit hoch · Cursor (für EnScapeZ) · dieser Arbeitsgang
- Auftrag: `cursor_updatenotice.md` sofort ins GitHub-Projekt laden und für immer merken, dass sie ganz wichtig ist und 100 % jedes Mal mit hochgeladen wird.
- Was: Datei lag schon auf `origin/cursor/pause-menu-shared-options` (`b36b447`). Zusätzliche dauerhafte Regel `.cursor/rules/02_cursor_notice_always_upload.mdc` (`alwaysApply: true`). Persistente Merkdateien im Cursor-Agent-Store (persönlich + diese Session).
- Neu: `.cursor/rules/02_cursor_notice_always_upload.mdc`.
- Git: dieser Eintrag + die neue Regel werden sofort committet und gepusht. Auf `origin/main` liegt die Notice noch nicht (nur auf diesem Branch).
- Link nach dem Push: `https://github.com/CaptainArschbart/Test/blob/cursor/pause-menu-shared-options/cursor_updatenotice.md`

### 2026-10-25 · Notice auf origin/main hochgeladen · Cursor (für EnScapeZ) · dieser Arbeitsgang
- Auftrag: Die Cursor-Notice wirklich hochladen (nicht nur auf dem Feature-Branch lassen).
- Was: `origin/main` war Fast-Forward hinter diesem Branch (2 Notice-Commits `b36b447`, `c743776` plus dieser). Datei nach `origin/main` schieben, damit sie im GitHub-Projekt auf dem Hauptbranch liegt.
- Dateien: `cursor_updatenotice.md` (dieser Eintrag).
- Git: Push auf `origin/cursor/pause-menu-shared-options` und Fast-Forward nach `origin/main`.

### 2026-10-25 · Regel: Notice immer auf main · Cursor (für EnScapeZ) · dieser Arbeitsgang
- Auftrag: Update-Notice immer auf dem main-Branch halten; sonst bringt das nichts.
- Was: Feste Regel: `cursor_updatenotice.md` muss nach jedem Arbeitsgang auf `origin/main` liegen, nicht nur auf dem Feature-Branch.
- Geändert:
  - `.cursor/rules/02_cursor_notice_always_upload.mdc`: Ablauf Fast-Forward `HEAD:main` oder nur die Notice-Datei auf `main`; Schluss erst nach `git ls-tree origin/main`.
  - `.cursor/rules/01_update_notice_rules.mdc` und `.cursor/rules/ai-handover.mdc`: Ziel ist `origin/main`.
- Git: Commit + Push Arbeitsbranch + Fast-Forward nach `origin/main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-25 · Nur noch main pullen und pushen · Cursor (für EnScapeZ) · dieser Arbeitsgang
- Auftrag: Nur noch die main-Branch zum Pullen und Pushen benutzen, damit Cursor auf dem gleichen Branch wie Claude arbeitet. Ganz wichtige Regel.
- Was: Lokales `main` von `2117c2e` auf `f822b9c` fast-forward (`git checkout main`, `git pull origin main`). Ab jetzt kein `cursor/`-Branch mehr für Pull/Push.
- Neu: `.cursor/rules/03_main_only.mdc` (`alwaysApply: true`).
- Geändert:
  - `.cursor/rules/00_conflict_prevention.mdc` Abschnitt 4: Cursor und Claude auf `main`.
  - `.cursor/rules/02_cursor_notice_always_upload.mdc`, `01_update_notice_rules.mdc`, `ai-handover.mdc`: nur `git pull origin main` / `git push origin main`.
  - `.cursor/hooks/require-cursor-notice.py` + `hooks.json`: blockt Pull/Push/Commit, wenn HEAD nicht `main` ist oder das Remote nicht `origin/main` ist.
- Git: Commit auf `main`, nur `git push origin main`.
- Korrektur im selben Arbeitsgang: Hook hat `git push origin main; git fetch …` als Remote `main;` gelesen und den Push blockiert. `rstrip(";,&|")` ergänzt.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-25 · Hotbar, Inventar und Hotkeys verknüpft · Cursor (für EnScapeZ) · main
- Auftrag: Nach dem Stand auf `main` Hotbar, Inventar und die Tasten in den Settings aufeinander abstimmen und fehlerfrei machen. Claudes Notice nur lesen.
- Gelesen: `claude_updatenotice.md` (PR #5, #10). Hotbar/Inventar hängen am Player (`inventory_ui.tscn`, kein `scenes/ui/hotbar.tscn`). 19 Aktionen in `Settings.REBINDABLE_ACTIONS`, Liste in `options_menu.tscn` unter `KeyScroll` (Mindesthöhe 240). Esc schließt zuerst das Inventar, Pause liegt auf CanvasLayer 10.
- Geändert:
  - `scenes/player/player.gd`: `hotbar_1`…`hotbar_9` und `drop_item` gelten auch bei offenem Inventar. Umschauen und Mausfang bleiben gesperrt. Tastenwiederholung (Echo) wird ignoriert, damit gehaltenes Q nicht den Stapel leert.
  - `scenes/inventory/inventory_ui.gd`: Tab-Echo schaltet das Fenster nicht doppelt. Bei `paused` keine Inventar-Eingabe. Slots erst nach `Inventory.ready`. Drop außerhalb des Fensters mit geprüftem Index.
  - `scenes/inventory/inventory_slot.gd`: Slot-Beschriftung ist die belegte Taste aus `Settings.key_bindings` (`hotbar_N`), neu gezeichnet bei `Settings.changed`. HUD und Inventar-Hotbar zeigen dieselbe Beschriftung.
  - `scenes/inventory/inventory.gd`: `has_index`. `get_item` / `get_count` / `remove_at` / `move` / `quick_move` bei ungültigem Index ohne Absturz.
  - `scenes/inventory/inventory_ui.tscn`: `layer = 2` (über dem Noclip-HUD auf Layer 1, unter dem Pausemenü auf Layer 10). `load_steps` bleibt 3.
  - `scenes/pause/pause_menu.gd`: Esc-Echo ignoriert, damit nach dem Schließen des Inventars nicht sofort die Pause aufgeht.
- Nicht geändert: `claude_updatenotice.md`, `AI_HANDOVER.md`, `project.godot` (Input Map `hotbar_1`…`hotbar_9` = Tasten 1–9, `inventory` = Tab, `drop_item` = Q war schon da), `autoload/settings.gd`.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA):
  - Nach Neustart des Klassen-Caches (lokal `.godot/global_script_class_cache.cfg` hatte nur `Player`; Datei ist gitignored): `testmap.tscn --quit-after 2` nur die Versionszeile, keine `ERROR`/`SCRIPT ERROR`.
  - Temporäre Szene `hotbar_sync_runner` (nicht committet, danach gelöscht): `CHECKS 79 FAILS 0`. Darin Testmap und `main.tscn`: 9 HUD-Slots, 9 Panel-Slots, 27 Rucksack, Layer 2/10, Auswahl per `hotbar_2`/`hotbar_4` auch bei offenem Inventar, Tab-Echo lässt offen, ein Drop, Drop-Echo ändert die Menge nicht, Quick-Move Hotbar↔Rucksack, Esc schließt nur das Inventar, Esc-Echo öffnet nicht die Pause, zweites Esc pausiert, Tab und Hotbar während Pause wirkungslos, `hotbar_1` auf Z belegt wählt Slot 0 und beide Leisten zeigen `Z`, Options-`%KeyGrid` hat 38 Zellen (19 Aktionen × 2) inklusive Inventar, Wegwerfen, Slot 1 und Slot 9.
- Nicht getestet: Fensterlauf, Mausrad, Controller, Drag mit echter Maus. Echte `settings.cfg` nicht angefasst (APPDATA war isoliert).
- Git: Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-25 · Überleben: HP, Ausdauer, Hunger, Durst · Cursor (für EnScapeZ) · main
- Auftrag: Vollständiges Überlebenssystem mit HP, Ausdauer, Hunger, Durst und vier HUD-Leisten. Claudes Notice nur gelesen.
- Entscheidung: Kein Autoload. `PlayerStats` ist ein Kind des Players, wie das Inventar. Im Hauptmenü gibt es den Knoten nicht. Bei Pause läuft er nicht, weil der Baum steht. Jede Map mit `player.tscn` hat die Werte und die Leisten.
- Neu:
  - `scenes/survival/player_stats.gd` (`class_name PlayerStats`). Signale `stat_changed(stat_name, current, maximum)` und `died`. Standard je 100. Hunger −0,35/s, Durst −0,55/s. Sprint −20 Ausdauer/s, Erholung +15/s erst 0,75 s nach dem Sprint und erst wieder ab 15 Punkten. Unter 25 Hunger oder Durst ist die Erholung halb. Bei 0 Hunger −4 HP/s, bei 0 Durst −6 HP/s (beides zusammen −10). `eat` / `drink` / `heal` / `damage` / `restore_all`.
  - `scenes/survival/survival_hud.tscn` + `survival_hud.gd`. CanvasLayer 2. Leisten `%HPBar`, `%StaminaBar`, `%HungerBar`, `%DurstBar` (Farben Magenta, Cyan, Orange, Blau). Position oben links ab y = 56, damit die Zeile „NOCLIP“ (y = 20, Layer 1) frei bleibt. Pausemenü bleibt Layer 10. `load_steps` = 7 (1 ext + 5 sub + 1). `step = 0` an den Leisten, sonst rundet die Bar auf 0,01.
  - `.uid` zu den beiden neuen Skripten.
- Geändert:
  - `scenes/player/player.tscn`: Knoten `PlayerStats`, Instanz `SurvivalHud`. `load_steps` 7 → 9 (5 ext + 3 sub + 1).
  - `scenes/player/player.gd`: Sprint (Boden und Noclip) nur, wenn `PlayerStats` ihn erlaubt. Bei `died`: Respawn und alle vier Werte voll.
- Nicht geändert: `claude_updatenotice.md`, `AI_HANDOVER.md`, `project.godot` (kein neuer Autoload, keine neue Input-Aktion).
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA): temporäre Szene `survival_runner` (danach gelöscht) `CHECKS 38 FAILS 0`. Darin: Verhungern, keine Ausdauer-Erholung bei Hunger 0, halbe Erholung unter 25, Sprint startet nicht unter 15 und stoppt bei 0, HP-Verlust wenn Hunger und Durst beide 0, `died` genau einmal, Testmap und `main.tscn` mit vier Leisten auf Layer 2 die den Werten folgen, Tod füllt wieder auf, Pause hält Hunger an. `testmap.tscn --quit-after 2`: nur die Versionszeile, kein `ERROR` / `SCRIPT ERROR`.
- Nicht getestet: Fensterbild der Leisten, Shift im echten Fenster, Controller. Echte `settings.cfg` nicht angefasst.
- Git: Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-25 · First-Person-Hände an der Kamera · Cursor (für EnScapeZ) · main
- Auftrag: Sichtbares Hände-System am Spieler, Kind der Kamera, mit Idle- und Laufbewegung als Basis für spätere Werkzeuge.
- Entscheidung: Eigene Szene `scenes/hands/` statt Meshes direkt in `player.tscn`. Kein `AnimationPlayer`: es gibt keine Clip-Dateien, das Wackeln folgt der echten Geschwindigkeit. Platzhalter (Kapsel + Kasten), kein importiertes Arm-Modell. Schatten aus, etwas Emission, damit die Hände in der Nacht-Testmap sichtbar bleiben. Kamera-`near` auf 0,05, die Hände liegen bei z = −0,4.
- Neu:
  - `scenes/hands/player_hands.tscn`: Wurzel `PlayerHands` (`Node3D`). Kinder `LeftHand` und `RightHand` (`MeshInstance3D`, Kapsel) mit je `Palm` (`BoxMesh`). `load_steps` = 5 (1 ext + 3 sub + 1).
  - `scenes/hands/player_hands.gd` (`class_name PlayerHands`). Idle atmet (`idle_frequency` 1,15, Amplitude 0,0035). Ab 0,45 m/s Gehen (`bob_frequency` 2,2, Amplitude 0,012), beim Sprint 1,65-fach Frequenz und Amplitude 0,022. Pose wird jedes Frame aus der Szenen-Mitte neu gesetzt, nicht aufaddiert.
  - `scenes/hands/player_hands.gd.uid`.
- Geändert:
  - `scenes/player/player.tscn`: Instanz unter `Head/Camera3D`, `unique_name_in_owner` → `%PlayerHands`. `load_steps` 9 → 10 (6 ext + 3 sub + 1). `Camera3D.near = 0.05`.
  - `scenes/player/player.gd`: `@onready var hands: PlayerHands = %PlayerHands`.
- Nicht geändert: `claude_updatenotice.md`, `AI_HANDOVER.md`, `project.godot`.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA): temporäre Szene `hands_runner` (danach gelöscht) `CHECKS 20 FAILS 0` auf Testmap und `main.tscn`. `%PlayerHands` ist Kind von `Camera3D`, linke und rechte Hand plus Handflächen da, Sprint-Ausschlag größer als Gehen, Gehen größer als Idle, 80 Idle-Schritte ohne Wegdriften. `testmap.tscn --quit-after 2`: nur die Versionszeile, kein `ERROR` / `SCRIPT ERROR`.
- Nicht getestet: Fensterbild (ob die Hände das Fadenkreuz frei lassen), Maus-Nicken im Fenster. Echte `settings.cfg` nicht angefasst.
- Git: Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-25 · Stufensteigen und Schrittgeräusche · Cursor (für EnScapeZ) · main
- Auftrag: Der Spieler soll über Stufen laufen, ohne hängen zu bleiben, und Geräusche für Gehen, Sprint und harten Aufprall bekommen.
- Entscheidung: Die Kapsel bleibt die einzige Kollision. Ein Kasten am Boden würde an Kanten stärker hängen. Vor `move_and_slide` tastet ein Strahl nach vorn unten eine flache Trittfläche ab (Normale unter 22°). Die Kapsel wird nur angehoben, wenn sie danach wirklich höher steht. Sonst wird der Schritt verworfen, damit sie nicht durch die Stufe rutscht. `max_step_height` 0,45 m: die Teststufen 0,15 / 0,25 / 0,35 m gehen, 0,50 m bleibt eine Kante. `floor_max_angle` 46°: die 40°-Rampe ist Boden, die 50°-Rampe (Schild „zu steil“) nicht. `max_slides` 8. `floor_snap_length` 0,45 m, damit der Abstieg an Stufen bis 0,45 m am Boden bleibt. Keine neuen Input-Aktionen.
- Neu:
  - `assets/audio/footstep_01.wav`, `footstep_02.wav`, `footstep_03.wav`: kurze Platzhalter-Schritte.
  - `assets/audio/land_01.wav`, `land_02.wav`: kurze Platzhalter-Aufpralle.
  - Dazu die fünf `.import`-Dateien.
- Geändert:
  - `scenes/player/player.gd`: Stufen, Schritttakt und Aufprall. Gehen alle 0,46 s bei voller Gehgeschwindigkeit, Lautstärke −2 dB. Sprint alle 0,30 s, +2,5 dB, Tonhöhe 1,12. Langsamer wird der Abstand länger. Aufprall ab 6,5 m/s Fall (etwa 2 m). Ein normaler Sprung löst keinen Aufprall aus. Läuft ein Schritt schon, wird er gestoppt, bevor der nächste startet.
  - `scenes/player/player.tscn`: `load_steps` 10 → 15 (11 ext + 3 sub + 1). Neue Knoten `%Footsteps` und `%LandImpact` (`AudioStreamPlayer3D`, Bus `SFX`, `unit_size` 12). `footstep_sounds` und `land_sounds` zeigen auf die WAVs.
- Node-Struktur: `%Footsteps`, `%LandImpact` direkt unter `Player`. Keine neue Input-Map.
- Nicht geändert: `claude_updatenotice.md`, `AI_HANDOVER.md`, `project.godot`.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA): temporäre Szene `motion_runner` (danach gelöscht) `CHECKS 25 FAILS 0`. Darin: Sprung bleibt höher als 0,6 m und spielt keinen Aufprall, Gehen setzt einen Schritt-Stream mit Tonhöhe unter 1,08 und Lautstärke unter 0 dB, Sprint Tonhöhe mindestens 1,05 und Lautstärke über 1 dB, Stufen 0,15 / 0,25 / 0,35 m werden erklommen, 0,50 m und eine 1,2-m-Wand blocken, 40°-Rampe steigt, 50°-Rampe nicht, Fall aus 3,5 m spielt den Aufprall. Testmap: Höchstwert der 0,15-m-Treppe über 0,75 m, der 0,35-m-Treppe über 1,6 m, die 0,50-m-Treppe blockt. `testmap.tscn` und `main.tscn --quit-after 2`: nur die Versionszeile, kein `ERROR` / `SCRIPT ERROR`.
- Nicht getestet: Fensterbild auf den Treppen, ob die Platzhalter im Lautsprecher gut klingen, Controller. Echte `settings.cfg` nicht angefasst.
- Git: Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-25 · Hintergrundmusik aus sounds/ · Cursor (für EnScapeZ) · main
- Auftrag: Die MP3s im Ordner `sounds` als Hintergrundmusik auf dem Bus „Music“ abspielen und den Musik-Regler in den Optionen in Echtzeit darauf wirken lassen.
- Entscheidung: Autoload `AudioManager` nach `Settings`. Alle `*.mp3` in `res://sounds` werden alphabetisch geladen und nacheinander gespielt. Am Ende der Liste beginnt der erste Titel wieder. Das Import-Flag `loop` bleibt `false`, sonst würde `finished` nicht kommen und nur der erste Titel laufen. Die Liste selbst wiederholt sich. Der Spieler hängt am Bus `Music`. Pause stoppt die Musik nicht (`PROCESS_MODE_ALWAYS`). Der Regler speichert weiter erst bei „Übernehmen“; während des Ziehens stellt `Settings.preview_bus` den Bus sofort über `AudioServer.set_bus_volume_db`. Zweimal „Zurück“ stellt die gespeicherte Lautstärke wieder her.
- Neu:
  - `autoload/audio_manager.gd` und `autoload/audio_manager.gd.uid`.
  - `sounds/MC MIMMON.mp3`
  - `sounds/Mimom Mc.mp3`
  - `sounds/Mimon Baraka  Bing Bao Ming Mao.mp3` (zwei Leerzeichen zwischen Baraka und Bing)
  - `sounds/YE-HH.mp3`
  - dazu die vier `.import`-Dateien (`loop=false`).
- Geändert:
  - `project.godot`: Autoload `AudioManager` hinter `Settings`.
  - `autoload/settings.gd`: `preview_bus(bus_name, percent)` setzt die Bus-Lautstärke, ohne zu speichern.
  - `scenes/options/options_menu.gd`: Musik-Regler ruft `preview_bus` für `Music` auf. „Standard“ ebenfalls. Schließen der Seite setzt den Bus auf `Settings.music_volume`.
- Reihenfolge beim Start: `res://sounds/MC MIMMON.mp3`, dann `res://sounds/Mimom Mc.mp3`, dann `res://sounds/Mimon Baraka  Bing Bao Ming Mao.mp3`, dann `res://sounds/YE-HH.mp3`.
- Nicht geändert: `claude_updatenotice.md`. Keine neue Input-Aktion.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA): temporäre Szene `music_runner` (danach gelöscht) `CHECKS 16 FAILS 0`. Vier Pfade in dieser Reihenfolge, erster Titel läuft, Bus ist `Music`, Import-`loop` ist aus. `preview_bus` bei 50 % liegt auf `linear_to_db(0.5)`, bei 0 ist der Bus stumm, bei 100 % auf 0 dB. Der Regler auf 40 setzt denselben Bus; zweimal Zurück stellt den vorherigen Wert wieder her.
- Bekannt beim Beenden: Godot 4.7.2 meldet `ERROR: 1 resources still in use at exit` (`AudioStreamPlaybackMP3` für die laufende Datei), auch nachdem der Player gestoppt und der Stream geleert wurde. Kein `SCRIPT ERROR`. Das passiert beim Schließen, nicht während des Abspielens.
- Nicht getestet: Klang aus den Lautsprechern, ob der Titelwechsel im langen Fenster hörbar ist. Echte `settings.cfg` nicht angefasst.
- Git: Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-25 · 2K/4K: Mausfilter und 3D-Puffer · Cursor (für EnScapeZ) · main
- Auftrag: Das Spiel friert bei 2K/4K ein und der Spieler kommt nicht mehr vom Fleck. Full HD läuft. Ursache suchen in Stretch, Vollflächen-UI mit Mausfilter und der Fenstergröße, ohne den MainLoop in einer Resize-Schleife zu fangen.
- Entscheidung: Stretch `canvas_items` + `aspect` `expand` stand nach `git pull origin main` schon auf `main` (Commit `346420a`, PR #13, „Menüs skalieren mit der Auflösung“). `project.godot` bleibt in diesem Commit unangetastet. Die UI rechnet damit weiter in 1280×720 und wird gleichmäßig hochskaliert. Zusätzlich: Flächen, die niemand anklickt, bekommen `mouse_filter = 2` (`IGNORE`). Der 3D-Puffer wird auf eine lange Kante von 1920 px begrenzt, damit 4K mit MSAA nicht einen nativen 4K-Framebuffer aufmacht. Der Reglerwert bleibt darunter erhalten (50 % auf 4K bleibt 0,25). Fenstergröße 0 teilt nicht. `size_changed` schreibt weder Fenstergröße noch Fenstermodus, merkt sich die letzte Größe und bricht ab, wenn der Aufruf schon läuft.
- Geändert:
  - `autoload/settings.gd`: `RENDER_LONG_EDGE` 1920, `scale_for_window`, `_apply_3d_scale`. `apply()` setzt darüber `viewport.scaling_3d_scale`. `Window`-`size_changed` am Root hängt einmal in `_ready`.
  - `scenes/pause/pause_menu.tscn`: `Root`, `Dim`, `Center`, `Title`, `Hint`, `Spacer` auf `mouse_filter = 2`. Knöpfe und das Options-Panel bleiben `Stop`.
  - `scenes/inventory/inventory_ui.tscn`: `%InventoryOverlay` und `%ItemName` auf `mouse_filter = 2`. Overlay startet unsichtbar.
  - `scenes/inventory/inventory_ui.gd`: offen `MOUSE_FILTER_STOP` (Ablegen neben dem Fenster), zu `MOUSE_FILTER_IGNORE`.
  - `scenes/menu/main_menu.tscn`: `Background` war schon `Ignore`. Dazu `Margin`, `Layout`, `TitleBox`, `Title`, `Subtitle`, `Gap`, `MainButtons`, `Footer`. Claudes mittiges Optionsfenster (`anchor_top/bottom = 0.5`, Offsets −312 / 276) bleibt. Die Menü-Wurzel bleibt `Stop`, das ist die Menü-Szene selbst.
  - `scenes/player/player.gd`: das NOCLIP-Label setzt `MOUSE_FILTER_IGNORE`.
- Nicht geändert: `claude_updatenotice.md`, `project.godot` (Stretch kam mit dem Pull). Keine neue Input-Aktion. HUD-Leisten und Hotbar hatten `Ignore` schon.
- Zusammengeführt: Vor dem Ändern war `origin/main` bei `6496afe`. Danach lag `105da31` (PR #13) auf dem Remote und betraf `project.godot` und `scenes/menu/main_menu.tscn`. Lokale Änderungen gestasht, Fast-forward, Stash zurück. `main_menu.tscn` automatisch vereint: Mausfilter und die zentrierte Optionsfläche. `project.godot` war danach identisch mit dem Remote, kein eigener Diff.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA): temporäre Szene `display_runner` (danach gelöscht) `CHECKS 14 FAILS 0`. Darin Stretch `canvas_items`/`expand`, Skala 1920×1080 = 1, 2560×1440 = 1920/2560, 3840×2160 = 0,5, 0×0 = Reglerwert, kleinerer Regler auf 4K bleibt, Pause-Root und Dim `Ignore` und unsichtbar, Overlay zu und `Ignore`, Menü-Rand `Ignore`, Optionsfenster `anchor_top` 0,5, `size_changed`-Handler 40-mal ohne Hänger. `testmap.tscn --quit-after 2`: nur die Versionszeile, kein `SCRIPT ERROR` / `Parse Error`.
- Bekannt beim Beenden: weiter `ERROR: 1 resources still in use at exit` (Musik-Stream, siehe Eintrag darüber). Kein neuer Skriptfehler.
- Nicht getestet: echtes 2K- oder 4K-Fenster, Vollbild auf einem solchen Monitor, ob die Bewegung dort wieder läuft. Echte `settings.cfg` nicht angefasst.
- Git: Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-25 · Cyberpunk-HUD und Hunger/Durst · Cursor (für EnScapeZ) · main
- Auftrag: Die vier Überlebensleisten sollen cyberpunk aussehen, und Hunger sowie Durst sollen mit der Zeit sinken, mit Strafe bei 0.
- Entscheidung: `PlayerStats` bleibt ein Kind des Players, kein Autoload. Im Hauptmenü gibt es den Knoten nicht, bei Pause steht der Baum. Die Abnahme lief schon in `_process(delta)` (Hunger 0,35/s, Durst 0,55/s, bei 0 kein Ausdauer-Nachschub, HP −4/s bei Hunger 0 und −6/s bei Durst 0, Klammer 0…Maximum). Die Raten heißen jetzt `hunger_drain_rate` und `thirst_drain_rate`, die Werte sind dieselben. Neu ist der Name `deplete_stats(delta)`. `advance` ruft dieselbe Funktion, damit alte Aufrufe bleiben. Eine negative Rate zählt als 0. Das HUD bleibt eine feste Fläche in der 1280×720-Basis (Rahmen 16,40 bis 308,188), der Stretch skaliert sie auf 2K/4K mit. Keine Vollbild-Anker.
- Neu:
  - `scenes/survival/hud_bar.gdshader` und `hud_bar.gdshader.uid`. Acht senkrechte Ticks und ein heller oberer Rand auf der schon gezeichneten Leiste. `segments` ist mindestens 1, keine Teilung durch 0, keine Schleife über die Auflösung.
- Geändert:
  - `scenes/survival/player_stats.gd`: Exporte `hunger_drain_rate` / `thirst_drain_rate`, Funktion `deplete_stats`.
  - `scenes/survival/survival_hud.tscn`: `load_steps` 7 → 10 (2 ext + 7 sub + 1). Rahmen `Frame` (Cyan-Rand, Schatten), Magenta-Streifen `Accent`, Überschrift `VITALS`. Leisten schräg (`skew` 0,55), Ecken 0, Glow über `shadow_size` 7. Farben: HP Cyan, Ausdauer Neon-Gelb, Hunger Orange, Durst Rot. Shader auf allen vier Leisten. `mouse_filter = 2`. Namen `%HPBar` `%StaminaBar` `%HungerBar` `%DurstBar` bleiben.
  - `scenes/survival/survival_hud.gd`: unter der Schwelle wird die Leiste warm, bei 0 blinkt sie. Blink taktet über `Time.get_ticks_msec()`, nicht über aufsummiertes `delta`. `max_value` 0 wird zu 1, der Wert bleibt in 0…Maximum.
- Node-Struktur: `SurvivalHud/Frame/Accent`, `SurvivalHud/Frame/Header`, `SurvivalHud/Frame/Bars/…`. Keine neue Input-Aktion.
- Nicht geändert: `claude_updatenotice.md`, `project.godot`, `scenes/player/player.tscn`. Ordner `pictures/` (ein jpg) bleibt unangetastet.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA): temporäre Szene `hud_runner` (danach gelöscht) `CHECKS 20 FAILS 0`. 2 s bei Hunger 10 landen auf 9,3. `delta` 0 und negativ ändern nichts. Essen über 100 bleibt bei 100. Negative Rate senkt nicht. Hunger und Durst 0: HP 80 → 70 in 1 s, Ausdauer bleibt 40, beide Bedürfnisse bleiben 0. Mit vollen Bedürfnissen steigt Ausdauer 40 → 55 in 1 s. HUD: Rahmen klein, Maus `Ignore`, HP-Füllung Cyan mit Schatten, Schräge 0,55, Shader-Material, Gelb/Orange/Rot, Text `VITALS`. `testmap.tscn --quit-after 2`: nur die Versionszeile, kein `SCRIPT ERROR` / `Parse Error`.
- Bekannt beim Beenden: weiter `ERROR: 1 resources still in use at exit` (Musik-Stream). Kein neuer Skriptfehler.
- Nicht getestet: Fensterbild der Leisten, Blinken mit dem Auge, 2K/4K-Screenshot. Echte `settings.cfg` nicht angefasst.
- Git: davor `git pull origin main` (Fast-forward `eea10d5..74d97c5`, Optionen-Audio, keine gemeinsamen Dateien). Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`
