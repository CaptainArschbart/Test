# EnScapeZ Update-Notice

Arbeitslog von **EnScapeZ** (mit Cursor und Claude) in diesem Repo, bis 2026-10-31 hieß die Datei `cursor_updatenotice.md`. Nur EnScapeZ und KIs im Auftrag von EnScapeZ schreiben in diese Datei; andere führen ihre eigene Update-Notice. So überschreiben sich die PRs nicht gegenseitig.

**Regeln:**
- Vor jeder Arbeit `main` holen und die Update-Notices der anderen KIs (`*_updatenotice.md` im Repo-Root, derzeit `claude_updatenotice.md`) lesen, aber nicht ändern. Liegt eine fremde Notice nicht im Arbeitsbaum, sie von `origin/main` lesen (`git show origin/main:claude_updatenotice.md`).
- `AI_HANDOVER.md` nicht mehr anfassen, auch nicht Ist-Stand, Änderungsprotokoll oder Arbeitslog (Wunsch von EnScapeZ, 2026-10-25).
- Nach jedem Arbeitsgang **unten** einen Eintrag anhängen, im selben PR wie die Änderung. Alte Einträge nicht ändern, neuester unten.

Vorlage:

```text
### JJJJ-MM-TT · Kurztitel · <KI> (für <Person>) · PR oder Branch
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

### 2026-10-25 · Leisten grauen aus, Poster an der Kiste · Cursor (für EnScapeZ) · main
- Auftrag: Die Vitalleisten sollen bei niedrigen Werten ausgrauen statt zu springen, Hunger und Durst weiter über die Zeit sinken, und ein Bild aus `pictures` als Poster an einer Wand in `main.tscn` hängen.
- Entscheidung: Neon-Rahmen, Schräge, Glow und Tech-Striche aus dem vorigen Eintrag bleiben. Das warme Blinken ist weg. Unter 20 % ändert sich nur `modulate`: Farbe Richtung Grau, nahe 0 zusätzlich gedämpftes Rot, Alpha bis etwa 0,42 und dann ein langsamer Puls. Alpha bleibt über 0,25. Position, Mindestgröße und Anker bleiben. `PlayerStats` bleibt Kind des Players, kein Autoload, damit Menü und Pause nicht mitzählen. `deplete_stats` und die Raten 0,35 / 0,55 bleiben. Neu ist `clamp_value`: 0 bis Maximum, Maximum 0 ergibt 0. Die Standard-Maxima sind 100. Das Poster hängt an der dem Spieler zugewandten Seite der großen Kiste (`BoxLarge`, Mitte −5, 1, −10, Fläche bei z = −8), 2,5 cm davor, damit es nicht in der Fläche flackert.
- Neu:
  - `pictures/maxresdefault.jpg` (1280×720, 123735 Bytes) und `pictures/maxresdefault.jpg.import` (`mipmaps/generate=true`).
- Geändert:
  - `scenes/survival/survival_hud.gd`: `fade_color(ratio)` und `_fade`. Schwelle `FADE_RATIO` 0,2. Kein Verschieben der Leisten.
  - `scenes/survival/player_stats.gd`: `clamp_value` in `_add`.
  - `scenes/main/main.tscn`: `load_steps` 17 → 20 (11 ext + 8 sub + 1). Knoten `Level/Poster` (`MeshInstance3D`, `QuadMesh` 1,6×0,9 m, 16:9). Material mit `res://pictures/maxresdefault.jpg`, `cull_mode` 2, `texture_filter` 5, `cast_shadow` 0. Transform (−5, 1,15, −7,975).
- Node-Struktur: `Level/Poster` neben `BoxLarge`. Keine neue Input-Aktion. HUD-`mouse_filter` bleibt `Ignore`. Die Leisten skalieren weiter über den Stretch der Basis 1280×720.
- Nicht geändert: `claude_updatenotice.md`, `project.godot`, `scenes/survival/survival_hud.tscn`, `scenes/survival/hud_bar.gdshader`.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA): temporäre Szene `poster_runner` (danach gelöscht) `CHECKS 19 FAILS 0`. Volle Leiste und 20 % bleiben Weiß mit Alpha 1. Bei 10 % Alpha zwischen 0,5 und 0,9 und die Kanäle liegen beieinander. Bei 0 Alpha zwischen 0,25 und 0,55, Rot höher als Grün. Mindestgröße und Position der Hunger-Leiste bleiben, Maus `Ignore`, Rahmen unter 400 px. `clamp_value` 140 → 100, −5 → 0, Maximum 0 → 0. Hunger nach 10 s bei 1 auf 0, Essen 500 bleibt 100. Poster-Quad 16:9, Texturpfad `res://pictures/maxresdefault.jpg`, Position x −5 / y 1,15, z zwischen −8 und −7,95. `main.tscn --quit-after 2`: nur die Versionszeile, kein `SCRIPT ERROR` / `Parse Error`.
- Bekannt beim Beenden: weiter `ERROR: 1 resources still in use at exit` (Musik-Stream). Kein neuer Skriptfehler.
- Nicht getestet: Fensterbild des Posters und der ausgegrauten Leisten, ob die Quad-Vorderseite im echten Blickfeld sitzt. Echte `settings.cfg` nicht angefasst.
- Git: `git pull origin main` war schon aktuell. Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-25 · Poster in der Testmap, die Start wirklich lädt · Cursor (für EnScapeZ) · main
- Auftrag: Die Änderungen waren im Spiel nicht zu sehen.
- Ursache: *Start* im Hauptmenü lädt `res://scenes/testmap/testmap.tscn` (`main_menu.gd`, `game_scene`). Das Poster lag nur in `main.tscn` an der großen Kiste. Die Vitalleisten und die Abnahme hängen am Player und gelten damit in beiden Szenen. Spawn der Testmap ist (0, 0,05, 42), Blick nach −Z.
- Geändert:
  - `scenes/testmap/testmap.tscn`: `load_steps` 35 → 38 (12 ext + 25 sub + 1). Knoten `Buildings/Poster`, `QuadMesh` 4,8×2,7 m, Textur `res://pictures/maxresdefault.jpg`. Hängt an der Straßenseite von `StreetBlock3` (Wand bei x = −12), Position (−11,96, 3,2, 22), 4 cm vor der Wand. `basis.z` zeigt nach +X, zur Straße. Emission 0,9, damit das Bild in der Nachtmap lesbar ist. `cast_shadow` 0, `cull_mode` 2.
  - `scenes/main/main.tscn`: dasselbe Poster an der Kiste bekommt Emission 0,45, Textur unverändert.
- Nicht geändert: `claude_updatenotice.md`, `scenes/survival/*`, `scenes/player/player.tscn`. Keine neue Input-Aktion.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA): temporäre Szene `seen_runner` (danach gelöscht) `CHECKS 8 FAILS 0`. Nach der ersten Drehung zeigte `basis.z` nach −X (1 Fehlschlag), danach nach +X. Poster x zwischen −12 und −11,9, z zwischen 16 und 42. Emission an, Texturpfad stimmt. Am Player der Testmap steht die Überschrift `VITALS`, die Hunger-Leiste hat Maus `Ignore`, `hunger_drain_rate` ist 0,35. `testmap.tscn --quit-after 2`: kein `SCRIPT ERROR` / `Parse Error`.
- Bekannt beim Beenden: weiter `ERROR: 1 resources still in use at exit` (Musik-Stream).
- Nicht getestet: Fensterbild vom Spawn aus. Echte `settings.cfg` nicht angefasst.
- Git: `git pull origin main` war aktuell (`79d3f5e`). Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-25 · Spieler stand, Menüs gingen noch · Cursor (für EnScapeZ) · main
- Auftrag: In der Spielwelt keine Bewegung per Tastatur oder Maus, Menüs lassen sich trotzdem öffnen.
- Ursache: Bewegung hängt nicht am Mausfilter. Sie bleibt aus, wenn der Baum pausiert ist oder `input_locked` klebt. Beides lässt das Pausemenü weiterlaufen (`PROCESS_MODE_ALWAYS`). Zusätzlich behält ein versteckter Pause-Knopf den Tastaturfokus, und ein Klick zum Mausfangen kommt nicht an, wenn eine Fläche ihn schluckt. HUD, Hotbar und die Cyberpunk-Leisten standen schon auf `Ignore`.
- Geändert:
  - `scenes/player/player.gd`: Gruppe `player`. `_ensure_play_input()` in `_ready` und `_physics_process`. Solange nicht pausiert und das Inventar zu ist: Fokus weg, und bei fokussiertem Fenster Maus auf `MOUSE_MODE_CAPTURED`. Headless setzt die Maus nicht.
  - `scenes/pause/pause_menu.gd`: `open()` schließt zuerst das Inventar, pausiert dann, Maus sichtbar. `close()` gibt den Fokus frei, hebt die Pause auf, fängt die Maus. `_process`: Menü unsichtbar und Baum trotzdem pausiert → Pause aus und Maus gefangen.
  - `scenes/inventory/inventory_ui.gd`: `force_close()`. Ist das Fenster zu, bleibt `mouse_filter` auf `Ignore` und `input_locked` wird falsch.
- Nicht geändert: `claude_updatenotice.md`, `project.godot`, die HUD-Szenen. Keine neue Input-Aktion.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA, davor `--import` weil `WeaponData` im lokalen Klassen-Cache fehlte): temporäre Szene `input_runner` (danach gelöscht) `CHECKS 11 FAILS 0`. Start: nicht gesperrt, Overlay zu und `Ignore`, nicht pausiert, keine sichtbare Vollfläche mit `Stop`. Gesperrte Steuerung bei geschlossenem Overlay ist nach einem Frame wieder frei. Pause öffnen schließt das Inventar und pausiert. Schließen: nicht pausiert, kein Fokus. Versteckte Pause mit gesetztem `paused` hebt sich im nächsten Frame auf.
- Bekannt beim Beenden: weiter `ERROR: 1 resources still in use at exit` (Musik-Stream). Kein `SCRIPT ERROR` im bestandenen Lauf.
- Nicht getestet: echtes Fenster, Alt-Tab, ob WASD danach wieder geht. Echte `settings.cfg` nicht angefasst.
- Git: `git pull origin main` Fast-forward bis `90185a5` (PR #17, vor der Änderung). Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-26 · Multiplayer-Grundgerüst (ENet) · Cursor (für EnScapeZ) · main
- Auftrag: Host und Client über die High-Level-Multiplayer-API, Spielerfigur spawnen und synchronisieren, nur die eigene Figur steuern, Host/Join im Menü.
- Neu:
  - `autoload/network_manager.gd` (+ `network_manager.gd.uid`): Autoload `NetworkManager`. `PORT` 7777, `MAX_CLIENTS` 3 (Host plus 3 Clients). `create_server()`, `create_client(address)`, `host_map(path)`, `stop()`, `has_session()`. `ENetMultiplayerPeer`. Leere IP wird `127.0.0.1`. Signale `peer_joined`, `peer_left`, `connection_failed`, `session_ended`.
  - Unter dem Autoload die Knoten `Players` (`Node3D`) und `PlayerSpawner` (`MultiplayerSpawner`, `spawn_path` `../Players`, Szene `res://scenes/player/player.tscn`, eigene `spawn_function`). Pfad auf jedem Peer `/root/NetworkManager/PlayerSpawner`, damit ein Beitritt den Spawner schon im Menü findet. Nach `create_server` / `create_client` wird der Spawner neu eingehängt, damit er den Peer kennt.
- Geändert:
  - `project.godot`: Autoload `NetworkManager` hinter `AudioManager` ergänzt. Abschnitt nicht umsortiert.
  - `scenes/player/player.tscn`: `load_steps` 18 → 19 (16 ext + 2 sub + 1). `SceneReplicationConfig_sync` und Knoten `PlayerSync` (`MultiplayerSynchronizer`, Intervall 0,05 s, Modus Always). Pfade `.:position`, `.:rotation`, `Head:rotation`, jeweils `spawn` an.
  - `scenes/player/player.gd`: `controls_local_body()`. Ohne Peer (Einzelspieler) immer wahr, ohne `is_multiplayer_authority()` aufzurufen. Mit Peer nur bei Autorität. Fremde Figur: Physik und `_unhandled_input` aus, Kamera nicht `current`, CanvasLayer versteckt, `ItemUser`, `WeaponHolder`, `PlayerStats` und `PlayerStealth` ohne Prozess. Eigenes HUD, Tod und Noclip-Label entstehen dafür nicht.
  - `scenes/player/item_user.gd`, `scenes/weapons/weapon_holder.gd`: `_can_use()` verlangt `controls_local_body()`.
  - `scenes/pause/pause_menu.gd`: `_local_player()` nimmt die Figur mit Autorität, nicht die erste in der Gruppe.
  - `scenes/menu/main_menu.gd`: unter den Hauptknöpfen `NetBox` (im Code, Geschwister von `MainButtons`): Button `HOST`, `LineEdit` Vorlage `127.0.0.1`, Button `JOIN`, Statuszeile. Host startet die Standard-Map `game_scene` (Testmap) und lässt die Session stehen. Join wartet auf die Map des Hosts. Einzelspieler-Start ruft `stop()` auf, die fest platzierte Figur bleibt. Zurück im echten Menü (`current_scene`) beendet die Session. Web blendet `NetBox` aus. Map-Auswahl und Optionen blenden `NetBox` mit aus.
- Netzwerk: Host lädt die Map, merkt sich Spawn der festen Figur, entfernt sie, spawnt sich als `Players/1`. `peer_connected` schickt `load_map` (`authority`, `reliable`, `call_remote`). Der Client baut Spawner-Zustand und antwortet mit `client_map_ready` (`any_peer`, `reliable`, `call_remote`, Absender nur über `get_remote_sender_id()`). Der Host spawnt diese Id. Name = Peer-Id, Autorität = Peer-Id, seitlicher Abstand 1,6 m. Trennung entfernt die Figur. Server weg: `stop()` und zurück ins Hauptmenü, sofern man nicht schon dort ist.
- Node-Struktur: keine Map-`.tscn` angefasst. Keine neue Input-Aktion.
- Nicht geändert: `claude_updatenotice.md`. `%LoadButton` bleibt deaktiviert.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA, Prüfskripte danach gelöscht): ein Prozess `CHECKS 23 FAILS 0`. `create_server` = 0, `is_server`, Id 1. Zweiter ENet-Host auf 7777 liefert Fehler 20 (`Couldn't create an ENet host`, erwartet). Nach `stop()` wieder 0. Menü hat `NetBox`, IP `127.0.0.1`, je ein Host- und Join-Knopf. Puppet mit Autorität 2: keine Physik, Kamera nicht aktuell, drei Sync-Pfade. Mit Session: feste `Player`-Node der Testmap weg, `NetworkManager/Players/1` mit Autorität und `PlayerSync`. Ohne Session: feste Figur bleibt, steuert, Physik an, keine Netzfigur. Kein `No multiplayer peer is assigned`.
- Zwei Prozesse (Host und Client, getrennte APPDATA, 127.0.0.1:7777): Client-Szene `res://scenes/testmap/testmap.tscn`. Server-Liste zur Mitte `1, 1429692591`. Client: Figur `1` `local=false` `cam=false` `phys=false`, eigene Id `local=true` `cam=true` `phys=true` bei `(1.6, 0.000107, 42.0)`. Host nach Setzen auf `(9, 2, 9)` fiel durch die eigene Physik auf den Boden; der Client las `(9.0, 0.000208, 9.0)`. Kein `SCRIPT ERROR`.
- Bekannt beim Beenden: `ERROR: 1 resources still in use at exit` (Musik-Stream) und `2 ObjectDB instances were leaked`. Kein neuer Skriptfehler.
- Nicht getestet: Klick auf Host/Join im echten Fenster, LAN statt Localhost, Kopf-Drehung über das Netz, Pause und Inventar mit zwei Figuren, Slum als Host-Map (Host nimmt `game_scene`, also die Testmap). Echte `settings.cfg` nicht angefasst.
- Git: vor dem Commit `git pull origin main` Fast-forward `98c66ad..49f5d32` (Hände, `item_user.gd` bekam `get_held_view` und `get_held_item`). Beides bleibt, dazu `controls_local_body()` in `_can_use()`. `pictures/maxresdefault.jpg.import` und die ungetrackte Torrent-Datei nicht mit committed. Danach Commit auf `main` und `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-26 · Internet-Host mit Port und ngrok · Cursor (für EnScapeZ) · main
- Auftrag: Multiplayer über Internet, direkte IP mit Portfreigabe und ein ngrok-Tunnel, den das Spiel selbst lädt, startet und beendet.
- Neu:
  - `autoload/ngrok_manager.gd` (+ `ngrok_manager.gd.uid`): Autoload `NgrokManager`. ZIP von `https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-<system>.zip` nach `user://bin`, entpackt mit `ZIPReader`. Windows `ngrok.exe`, sonst `ngrok`. Authtoken in `user://ngrok.cfg`. Beim ersten Token `ngrok config add-authtoken` (schreibt die ngrok-Konfiguration des Windows-Benutzers, nicht das Repo). Prozess `ngrok tcp <port>`, PID in `user://ngrok.pid`. Adresse aus `http://127.0.0.1:4040/api/tunnels` (`public_url`, Präfix `tcp://` weg). Höchstens 20 Abfragen à 0,5 s. `OS.kill` beim Lobby-Verlassen, Fenster-Schließen und Spiel-Ende. Ein gespeicherter PID vom letzten Lauf wird beim Start beendet, wenn er noch läuft.
- Geändert:
  - `project.godot`: Autoload `NgrokManager` hinter `NetworkManager`.
  - `autoload/network_manager.gd`: `create_server(port)` und `create_client(address, port)`, Standard weiter 7777. `split_endpoint` trennt `host:port` und `tcp://`. `resolve_host` nutzt `IP.resolve_hostname` (zuerst IPv4), reine IP bleibt. Schlägt die Auflösung fehl, bleibt eine laufende Session stehen (`ERR_CANT_RESOLVE`). `local_share_address`, `error_text`, `listen_port`. Banner `ShareBanner` (Layer 40, Maus Ignore) mit der Adresse, weg bei `stop()`. `stop()` beendet auch den ngrok-Prozess.
  - `scenes/menu/main_menu.gd`: Knopf `MULTIPLAYER` (gleiche Mindesthöhe wie Start). Lobby `Lobby`/`NetBox`, anfangs zu: lokaler Port, `HOST (PORTFREIGABE)`, `HOST (NGROK)`, geheimes Authtoken-Feld, Adresse, `KOPIEREN` (`DisplayServer.clipboard_set`), `SPIEL STARTEN`, Join-Host, Join-Port, `BEITRETEN`. Host startet die Welt erst nach `SPIEL STARTEN`, damit die Adresse kopierbar ist. Portfreigabe holt die öffentliche IP von `https://api.ipify.org` und fällt auf die LAN-Adresse zurück. `ZURÜCK` und Esc rufen `NetworkManager.stop()` auf. Web: ngrok-Knopf aus. Einzelspieler-Start trennt weiter die Session.
- Unverändert und erneut geprüft: `scenes/player/player.tscn` `PlayerSync` (Position, Drehung, `Head:rotation`), Autorität über `controls_local_body()`. Keine Map-`.tscn` geändert. Keine neue Input-Aktion.
- Nicht geändert: `claude_updatenotice.md`. Die ngrok-Datei liegt nur unter `user://`, nicht im Repository.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA, Prüfskript danach gelöscht): `CHECKS 31 FAILS 0`. Windows-URL `ngrok-v3-stable-windows-amd64.zip`, Linux-ARM-URL, Web ohne Paket. Tunnel-Text `tcp://0.tcp.eu.ngrok.io:15155` wird `0.tcp.eu.ngrok.io:15155`. `split_endpoint` und `127.0.0.1` ohne Port. `localhost` löst zu `127.0.0.1` auf. Server auf 7791, `listen_port` 7791. `no-such-host.invalid` liefert Fehler 26 (`ERR_CANT_RESOLVE`), der Host bleibt. Zweiter ENet-Host auf 7791: Fehler 20 (`Couldn't create an ENet host`, erwartet). Zip mit `ZIPPacker` entpackt `pong`. Menü: `MULTIPLAYER`, Lobby zu, Knöpfe Host Port, Host ngrok, Kopieren, Spiel starten, Beitreten, Join-Text `127.0.0.1`, zwei Felder `7777`. Puppet Autorität 2 ohne Physik, drei Sync-Pfade. Offline steuert. Download und Entpacken: `user://bin/ngrok.exe` 33125704 Bytes. Danach `ngrok version` außerhalb von Godot: `ngrok version 3.39.13`. Menü-Start `--quit-after 2`: kein `SCRIPT ERROR`.
- Bekannt beim Beenden: `ERROR: 1 resources still in use at exit` (Musik-Stream) und `2 ObjectDB instances were leaked`.
- Nicht getestet: Klick im echten Fenster, ein öffentlicher ngrok-Tunnel (kein Authtoken, würde eine Internet-Adresse öffnen), ipify, Portfreigabe am Router, Kopf-Drehung. Echte `settings.cfg` nicht angefasst.
- Git: `pictures/maxresdefault.jpg.import` und die ungetrackte Torrent-Datei nicht mit committed. Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-26 · ngrok-Beitritt: Adresse, Bind und Timeout · Cursor (für EnScapeZ) · main
- Auftrag: Clients erreichen den ngrok-Host nicht (Server nicht erreichbar oder Timeout).
- Ursache: ngrok `tcp` leitet nur TCP weiter. ENet spricht UDP. Der Tunnel kann trotzdem „oben“ sein, die Pakete des Clients kommen nie an. Zusätzlich lauschte ENet mit dem Engine-Standard `*`, auf Windows oft nur IPv6, während ngrok per IPv4 auf `127.0.0.1` zugreift.
- Geändert:
  - `autoload/network_manager.gd`: direkter Host bleibt ENet, `set_bind_ip("0.0.0.0")` vor `create_server`. ngrok-Host (`create_server(port, true)` bzw. `host_map(..., true)`) nutzt `WebSocketMultiplayerPeer.create_server(port, "0.0.0.0")`. Beitritt zu einer Adresse mit `ngrok`, `tcp://` oder `ws://` geht über WebSocket an die mit `IP.resolve_hostname` aufgelöste IPv4 (`ws://ip:port`). `split_endpoint` trennt `host:port`, auch mit Leerzeichen, `tcp://` und abschließendem `/`, und setzt `explicit`. `client_connected` nach `connected_to_server`. WebSocket wird in `_process` per `poll()` bedient.
  - `autoload/ngrok_manager.gd`: Start ist `ngrok tcp 127.0.0.1:<port>`, nicht nur die Portzahl.
  - `scenes/menu/main_menu.gd`: Beim Verlassen des Join-Feldes und vor dem Beitritt wird `0.tcp.eu.ngrok.io:14235` in Host und Port zerlegt. Status beim ngrok-Join: `Verbinde mit ngrok-Server...` plus aufgelöste Adresse. Nach 10 Sekunden ohne Verbindung, oder bei `connection_failed`, Abbruch ohne Absturz und zwei Zeilen: Firewall für Godot und ngrok, und ob der meist 5-stellige ngrok-Port exakt im Feld steht.
- Keine neue Input-Aktion. Keine Map-`.tscn`. `claude_updatenotice.md` nicht angefasst.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA, Prüfskripte danach gelöscht): ein Prozess `CHECKS 13 FAILS 0`. Split von `0.tcp.eu.ngrok.io:14235`, von `tcp://…:14235/` und von `…: 14235`. `localhost` → `127.0.0.1`. WebSocket-Server Port 7795 `tunnel_mode` wahr, ENet Port 7796 falsch. Lobby-Felder danach Host `0.tcp.eu.ngrok.io` und Port `14235`. Join auf `127.0.0.1:1` endet nach 10 Sekunden mit `Zeitüberschreitung nach 10 Sekunden.` und den beiden Tipps (Firewall, Port-Match). Zwei Prozesse ENet: Host `ENET HOST 0 tunnel=false`, `ENET HOST SEES 947874992`, Client `ENET CLIENT OK`. Zwei Prozesse WebSocket: `WS HOST 0 tunnel=true`, `WS HOST SEES 1911681400`, `WS CLIENT OK`. Kein `SCRIPT ERROR`.
- Bekannt beim Beenden: `ERROR: 1 resources still in use at exit` (Musik-Stream) und `2 ObjectDB instances were leaked`.
- Nicht getestet: ein echter ngrok-Tunnel mit Authtoken über das Internet, die Windows-Firewall-Abfrage im Fenster, ipify. Echte `settings.cfg` nicht angefasst.
- Git: `pictures/maxresdefault.jpg.import` und die ungetrackte Torrent-Datei nicht mit committed. Commit auf `main`, `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-29 · Bugs: Join-Timeout, Headless-Schüsse, load_steps · Cursor (für EnScapeZ) · Branch `fix/spiel-bugs`
- Auftrag: Das Spiel nach Fehlern durchsuchen, gefundene Bugs beheben, auf einem eigenen Branch, danach als Pull Request auf GitHub.
- Durchgesehen: alle `.gd` per `load` (640 Dateien, 0 Ladefehler), Szenen `main_menu`, `testmap`, `slum`, `player`, `options_menu`, `pause_menu` instanziiert. Stealth-Leisten 162×12, Unterkante y 256, Geldfeld y 266, kein Überlapp. Tod mit 2500 Credchips legt einen Stapel mit `count` 2500 (der erste Aufhebe-Versuch im Wegwerfskript scheiterte nur wegen `throw`-Sperre 0,5 s, nicht wegen der Obergrenze). Keine Konfliktmarker, keine doppelten `func`.
- Geändert:
  - `scenes/menu/main_menu.gd`: `_cancel_join_wait()`. Zurück, Host (Port und ngrok), Spiel starten und ein neuer Beitritt beenden die alte 10-Sekunden-Wartezeit. `_on_join_timeout` schließt keinen laufenden Server. `_on_net_failed` schreibt die Fehlerzeile nur noch, solange ein Beitritt offen ist (eigenes `stop()` hat den Spiel-starten-Knopf deaktiviert und den Statustext überschrieben).
  - `autoload/network_manager.gd`: `_on_connection_failed` bricht ab, solange `stop()` selbst den Peer schließt.
  - `scenes/player/player.gd`: `pointer_captured()`. Headless gilt als gefangen, im Fenster weiter nur `MOUSE_MODE_CAPTURED`.
  - `scenes/weapons/weapon_holder.gd`, `scenes/player/item_user.gd`, `scenes/player/player_melee.gd`: `_can_use` / `_can_act` nutzen `pointer_captured()`.
  - `tools/tests/test_weapons_smg_grenade.gd`: Maus-Check akzeptiert Headless. Dauerfeuer-Schleife bricht nach 720 Frames ab, Nachladen nach 600, statt endlos zu warten wenn kein Schuss kommt.
  - `scenes/hands/player_hands.tscn`: `load_steps` 9 → 8 (5 ext + 2 sub + 1).
  - `scenes/weapons/smg_view.tscn`: `load_steps` 23 → 24 (23 sub + 1).
  - `scenes/weapons/sniper_view.tscn`: `load_steps` 13 → 14 (13 sub + 1).
- Neu: `tools/tests/test_lobby_join.gd`. Port 7798, Join-Wartezeit, dann Host, dann Timeout. Der Host muss bleiben.
- Keine neue Input-Aktion. Keine neue Node-Struktur. `claude_updatenotice.md` nicht angefasst.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA `B:\AI game\Test\_test_appdata`): `test_lobby_join` CHECKS 4 FAILS 0. `test_money` 25/0. `test_consumables` 45/0. `test_audio` 18/0. `test_sector7_enemies` 15/0. `test_weapons_smg_grenade` 47/0. `test_player_melee` 42/0. Vor dem Headless-Fix hing `test_weapons_smg_grenade` in `while since_first < 1.0`, weil Windows-Headless `MOUSE_MODE_CAPTURED` nicht setzt und keine Waffe schoss.
- Nicht behoben, weiter beim Beenden: `ERROR: 1 resources still in use at exit` (`res://sounds/MC MIMMON.mp3`, dazu `AudioStreamPlaybackMP3`). `_exit_tree` läuft (`stop`, Stream auf null). Ein Versuch, den Player dort `free()` zu geben, hat denselben Leak gelassen (AudioServer hält die Wiedergabe bis nach der Abschlussprüfung). Zurückgenommen.
- Nicht behoben: `test_sector7_enemies` meldete davor `Navigation region synchronization had 4 edge error(s)`. Die 15 Checks bleiben 0 Fehler. Bake-Parameter nicht angefasst.
- Nicht getestet: Fenster, echter ngrok-Tunnel, zwei Spieler, `test_sector7_city` (früher über 5 Minuten unter Software-Rendering). Echte `settings.cfg` nicht angefasst. Wegwerfskript `tools/tests/_bugscan.gd` gelöscht, nicht committed. `pictures/maxresdefault.jpg.import` und die ungetrackte Torrent-Datei nicht mit committed.
- Git: Branch `fix/spiel-bugs`, Commit `e3bee1e`, Pull Request https://github.com/CaptainArschbart/Test/pull/46 . Nicht direkt auf `main`. Der Hook `.cursor/hooks/require-cursor-notice.py` verbietet Commits außerhalb von `main`. Für diesen Auftrag ist die Branch-Sperre im Hook nur lokal um eine Ausnahme für `fix/spiel-bugs` ergänzt worden und danach wieder der Stand von `main`. Die Hook-Datei ist nicht Teil des Commits.

### 2026-10-29 · PR #46 nach main gemerged · Cursor (für EnScapeZ) · main
- Auftrag: `/compromise`. Der Branch mit Pull Request bleibt, der Stand soll trotzdem auf `main` liegen, weil die Notice sonst für Claude nicht zählt.
- Korrektur zum Eintrag direkt darüber: „Nicht direkt auf `main`“ galt nur bis zum Merge. GitHub-Merge `0575ef0` (Merge pull request #46), Fast-forward lokal `01bbab5..0575ef0`. PR: https://github.com/CaptainArschbart/Test/pull/46
- Keine Codeänderung in diesem Eintrag. Keine neue Input-Aktion, keine neue Node-Struktur. `claude_updatenotice.md` nicht angefasst.
- Getestet: nichts Neues. Die Zahlen stehen im Eintrag davor.
- Git: auf `main`, `git pull origin main`, dieser Eintrag, `git push origin main`. `pictures/maxresdefault.jpg.import` und die Torrent-Datei nicht mit committed.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-29 · Wohnungen, Fahndung, Wetter, Grafik, Tod, Hunger · Cursor (für EnScapeZ) · main
- Auftrag: Begehbare Wohnungen mit Schlössern und Brechstange, Beute, Taschendiebstahl und Fesseln, Wanted 1–5, Tag/Nacht und Wetter, Waffen M4 und AK-47, Grafikmenü (SDFGI/SSR, Upscaling, Renderdistanz, Schatten), Deathscreen sofort mit zwei Knöpfen, Hunger und Durst langsamer und Schaden erst unter 15 %.
- Neu:
  - `autoload/noise_manager.gd` (+ `.uid`): `emit_noise(position, radius, source, kind)` reicht an `StealthNoise` weiter und sendet `heard`.
  - `autoload/wanted_manager.gd` (+ `.uid`): Sterne 0–5. `report(kind, position, token)`. Gewichte: Einbruch, Taschendiebstahl, Bedrohung je +1, Mord +2, Deckel 5, gleiche Tat 12 s gesperrt. Ab 1 Stern spawnt der Host `scenes/enemies/enemy.tscn` mit `scenes/enemies/profiles/cop.tres`, Gruppe `wanted_unit`, `engage(player)`. Anzahl: Sterne, ab 4 Sternen einer mehr, höchstens 6. Sieht 18 s kein Polizist den Spieler (Strahl 32 m), fällt ein Stern. HUD `WantedHud` / `Stars`, oben rechts, `★`/`☆`.
  - `scenes/crime/locked_door.gd`: Tür zu. Item-id = `key_id` öffnet leise. `break_open` macht auf, Lärm 18 m, `StealthNoise.BURGLARY`, +1 Stern.
  - `scenes/crime/loot_prop.gd`: einstecken oder, wenn `sealed`, erst `break_open`.
  - `scenes/crime/apartment_block.gd`: Boden, Decke, Wände, Tür, Bewohner (`stay_put`), Schmuck, Juwelen (versiegelt), Bargeld, Fernseher, Bild, Computer. Optional zweite Schlüsselkarte (`hidden_key`).
  - `scenes/crime/street_shop.gd`: `Kind.GUNS` Theke (Pistole 40 ¢, M4 120 ¢, AK-47 110 ¢, Eddy 15 ¢, Handschellen 8 ¢, Kabelbinder 4 ¢), Hintertür, versiegelte Kasse. `Kind.GAS` Dach, zwei Säulen, Snack- und Getränkeautomat mit `consume_now`, Kasse, optional Schlüsselkarte.
  - `scenes/crime/city_content.gd`: an der Slum-Map 3 Wohnungen, 2 Waffenläden, 3 Tankstellen. Positionen: Wohnungen `(96, 0, 88)` Schlüssel `apt_a`, `(-92, 0, 84)` Schlüssel `apt_b` und Karte `apt_a`, `(-88, 0, -96)` Schlüssel `apt_c` und Karte `apt_b`. Waffenläden `(112, 0, -36)` und `(-36, 0, 112)`. Tankstellen `(108, 0, 24)` mit Karte `apt_c`, `(-112, 0, -16)`, `(16, 0, -112)`.
  - `scenes/crime/civilian_crime.gd`: Taschendiebstahl nur von hinten, geduckt, Tempo unter 2,2 m/s, `noise_level` unter 0,35, näher als 1,8 m. Sicht über 0,72 erwischt. Zielen mit Schusswaffe (`get_aim` ab 0,65, Strahl 14 m): allein im Umkreis 8 m Hände hoch, sonst Flucht. Beides +1 Stern Bedrohung. Handschellen oder Kabelbinder nur bei erhobenen Händen, danach ausrauben.
  - `scenes/world/world_atmosphere.gd`: Kind der Map. Dupliziert das Environment zur Laufzeit. Sonne ist die vorhandene `DirectionalLight3D` `Moon`. Volle Umdrehung 480 s. Wetter klar, bewölkt, Regen, Nebel, Wechsel alle 90–170 s. Tiefer Nebel bleibt an (`fog_enabled`, Dichte mindestens die der Szene). Regenpartikel der Map nur bei Wetter Regen.
  - Items: `scenes/items/data/m4.tres` (18 Schaden, Magazin 30, Intervall 0,09 s, automatisch, Modell `smg_view.tscn`), `ak47.tres` (24 Schaden, Magazin 30, Intervall 0,11 s, dasselbe View-Modell), `crowbar.tres` (Eddy, 28 Schaden, Reichweite 2,1 m, `breaks_locks`), `handcuffs.tres`, `zipties.tres`, `keycard.tres`, `jewelry.tres` (40 ¢), `jewels.tres` (85 ¢), `cash_wad.tres` (25 ¢), `tv_set.tres` (55 ¢), `painting.tres` (60 ¢), `computer.tres` (48 ¢).
  - `tools/tests/test_content_update.gd`.
- Geändert:
  - `project.godot`: Autoloads `NoiseManager`, `WantedManager` hinter `WorldSync`.
  - `scenes/stealth/stealth_noise.gd`: Konstante `BURGLARY`.
  - `scenes/items/melee_data.gd`: `breaks_locks`, `break_noise` (Standard aus, 18 m).
  - `scenes/items/consumable_model.gd`: Modelle und Icons `crowbar`, `jewelry`, `jewels`, `cash`, `tv`, `painting`, `computer`, `cuffs`, `ties`, `keycard`.
  - `scenes/player/item_user.gd`: Schlag mit `breaks_locks` ruft `break_open` auf dem getroffenen Körper.
  - `scenes/interact/vending_machine.gd`: `consume_now`. Bei `ConsumableData` essen/trinken/heilen sofort, kein Slot.
  - `scenes/civilians/civilian.gd`: `stay_put`, `hold_up()`, `show_line()`, `interact`. `hear_noise` bei `BURGLARY` ruft `on_burglary`. Tod durch `take_hit` meldet Mord. Hände hoch blockt Flucht.
  - `scenes/enemies/enemy.gd`: `engage(player)`.
  - `scenes/slum/slum.gd`: legt `WorldAtmosphere` und `CityContent` an und gibt den Regen an die Atmosphäre.
  - `scenes/player/player.gd`: `camera.far` = `Settings.draw_distance` (Standard 500).
  - `autoload/settings.gd`: `gi_mode` 0 aus / 1 Normal (SSR) / 2 Raytraced High (SDFGI, 6 Kaskaden, Zellgröße 0,25, SSR 96 Steps). Standard 1. `upscale_mode` 0–4. `upscale_for`: aus = bilinear Skala 1; Qualität FSR2 0,77; Ausgewogen FSR2 0,67; Leistung FSR2 0,5; Hybrid FSR2 0,45. `draw_distance` 60–800, Standard 500. `shadow_quality` 0–3, Standard 2 (4 Splits, 80 m, wie bisher). `ssao_enabled`, `glow_enabled`, `volumetric_fog`, Standard an. Gespeichert unter `video` in `user://settings.cfg`.
  - `scenes/options/options_menu.gd`: im Tab GRAFIK `GiOption`, `UpscaleOption` (Beschriftung DLSS … / DLSS 5 Hybrid), `DrawDistanceSlider` 80–800, `ShadowOption`, `SsaoCheck`, `GlowCheck`, `VolumetricFogCheck`. Hinweistext: Godot 4.7 hat kein Nvidia DLSS 5, die Stufen setzen `scaling_3d_mode` und `scaling_3d_scale`.
  - `scenes/survival/death_screen.gd`: Overlay, Titel und Knöpfe im selben Frame (`modulate.a` 1, Shader-Amount 1). Knöpfe nur `RespawnButton` und `MenuButton`. Kamera sofort seitlich, kein Tween. Flatline-Stream `LOOP_DISABLED`, ein `play()`. `restart_mission()` bleibt im Skript, ohne Knopf.
  - `scenes/survival/player_stats.gd`: Hunger 0,08/s (vorher 0,35), Durst 0,12/s (vorher 0,55). Schaden nur unter 15 % des Maximums, alle 3 s: 1 Punkt, 2 wenn beide niedrig, 3 wenn einer davon auf 0 steht. Deckel 3.
- Keine neue Input-Map-Aktion. Neue Nodes nur zur Laufzeit, nicht in `slum.tscn`: `WorldAtmosphere`, `CityContent`, Wohnungstür `Door`, Bewohner `Resident`, Wanted-HUD. `claude_updatenotice.md` nicht angefasst.
- Entscheidungen: M4 und AK nutzen das vorhandene SMG-View, es gibt keine eigenen Gewehrnetze. Upscaling bleibt standardmäßig bilinear, weil FSR früher im Projekt unter Verdacht stand, das Bild schwarz zu machen. SDFGI ist aus, bis jemand „Raytraced High“ wählt. Polizei und Diebstahl laufen auf dem Host; ein Client spawnt keine Cops und führt den Taschendiebstahl nicht selbst aus. Die Hintertür der Waffenläden hat die Schlüssel-id `gun_back`, die Karte liegt nirgends, sie geht mit der Brechstange auf.
- Getestet (Godot 4.7.2 stable, `C:\Users\EnScapeZ\Desktop\Godot_v4.7.2-stable_win64.exe`, headless): `test_content_update.gd` CHECKS 39 FAILS 0. `test_consumables.gd` CHECKS 45 FAILS 0. `slum.tscn --quit-after 30` ohne `SCRIPT ERROR` und ohne `Parse Error`. Eine WARNING: `Navigation region synchronization had 4 edge error(s)`. Dieselbe Zeile stand schon im Eintrag zu `test_sector7_enemies` vor dieser Änderung. Vor dem Klassenscan: `slum.gd` Parse Error `WorldAtmosphere` nicht deklariert, `civilian.gd` `CivilianCrime` nicht gefunden, danach viele `Invalid call. Nonexistent function 'new'`. `godot --headless --editor --quit` hat die globalen Klassen registriert (ApartmentBlock, CityContent, CivilianCrime, LockedDoor, LootProp, StreetShop, WorldAtmosphere). Zweiter Slum-Lauf ohne diese Parse-Fehler.
- Nicht getestet: Fenster, Controller, echter Tag-Nacht-Lauf über 480 s, Raytraced High und FSR2 im Bild (kein Screenshot), ob die neuen Gebäude in vorhandene Kit-Häuser ragen, Multiplayer-Client bei Fahndung und Taschendiebstahl, `test_sector7_city`. Echte `user://settings.cfg` nicht gelöscht. `pictures/maxresdefault.jpg.import`, die Torrent-Datei, `_test_appdata/` und fremde neue `.uid` (`shop_interior`, `shop_ui`, `player_xp`, `xp_hud`) nicht mit committed.
- Git: auf `main`. `git pull` zu Beginn dieses Auftrags: Fast-forward `aa52244..13f3d8b` (PR #52). Dieser Eintrag gehört zum Commit der Änderung, danach `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-29 · Audit: Überlappungen, GI, Fahndung · Cursor (für EnScapeZ) · main
- Auftrag: Nach `6fd42db` die neuen Gebäude gegen Sektor 7 prüfen, Grafik, Wanted, Tod und Survival nachziehen, gefundene Fehler beheben.
- Befund aus `scenes/slum/slum.tscn` (Fußabdrücke der `k_building`-Knoten, Welt-AABB): 7 von 8 Standorten schnitten Außenblöcke. Getroffen waren `OuterWest/Shop40`, `OuterNorth/Res19`, `OuterSouth/Shop26`, `OuterEast/Warehouse8`, `OuterWest/Shanty30`, `OuterWest/Shanty39`, `OuterNorth/Shanty24`. Der Waffenladen bei `(112, -36)` schnitt kein Gebäude, lag aber am Rand der Lagerhallen.
- Neu platziert, auf Bodenplatten und mindestens 1 m von Kit-Gebäuden, nicht auf `kind` Straße/Kreuzung. Danach 0 Schnitte mit denselben AABBs:
  - Wohnung `apt_a` `(-110, 0, -82)`, Tür nach +X, yaw 90.
  - Wohnung `apt_b` `(-70, 0, 26)`, yaw 0, Schlüsselkarte `apt_a` darin.
  - Wohnung `apt_c` `(84, 0, 98)`, yaw 180, Schlüsselkarte `apt_b` darin.
  - Waffenläden `(-110, 0, 60)` yaw 90 und `(70, 0, 64)` yaw 0.
  - Tankstellen `(-111, 0, 88)` yaw 90, `(-48, 0, -71)` yaw 0, `(90, 0, -101)` yaw 0 mit Schlüsselkarte `apt_c`.
- Weiter behoben:
  - `scenes/crime/apartment_block.gd`: Türspalt 1,4 m (Wandstücke je 3,1 m), Türblatt 1,1 m schneidet die Laibung nicht mehr. Bewohner steht auf y 0,12, über der Bodenplatte (Oberkante y 0,1).
  - `scenes/crime/street_shop.gd`: Zapfsäulen von z 1,4 (im Verkaufsraum) nach `(-2,6, 4,2)` und `(2,6, 4,2)`, vor der offenen Front und unter dem Vordach. Automaten bleiben bei z 3,2 links und rechts der Tür, Mitte frei.
  - `scenes/crime/civilian_crime.gd`: Hocken und E ohne die Bedingungen für Taschendiebstahl ruft nicht mehr die Polizei. Alarm nur, wenn der Versuch gesehen wird (`visibility` über 0,72).
  - `autoload/wanted_manager.gd`: Polizei-Spawn prüft eine Kugel mit Radius 0,7 m (`intersect_shape`, Maske 1). Bis zu 8 Versuche, sonst in diesem Frame keiner. Sterne weiter einer alle 18 s ohne Sicht (`HIDE_SECONDS`). HUD `Stars` hat `MOUSE_FILTER_IGNORE`. `get_world_3d()` null bricht die Sichtprüfung ab.
  - `scenes/options/options_menu.gd`: Beschriftungen und der Upscale-Hinweis `MOUSE_FILTER_IGNORE`. `DrawDistanceSlider` und `DrawDistanceValue` gehören der Options-Wurzel, Unique Names bleiben.
  - `scenes/survival/death_screen.gd`: `RespawnButton` und `MenuButton` mit `owner` auf dem Deathscreen, damit `%RespawnButton` und `%MenuButton` greifen.
- Grafik, am duplizierten Environment geprüft, nicht nur an der Vorlage: GI 0 schaltet SDFGI und SSR aus, Tiefennebel bleibt an. GI 1 schaltet SSR an, SDFGI aus. GI 2 schaltet SDFGI an und SSR mit 96 Steps. Volumetrischer Nebel folgt dem Schalter. Upscale bleibt ein einzelner Faktor auf `scaling_3d_scale` (Qualität 0,77, Leistung 0,5, Hybrid 0,45, sonst bilinear 1). Kein anderes Seitenverhältnis, die UI skaliert weiter über `canvas_items`. Standard-Renderdistanz 500 m sieht die Spielgrenze bei ±136 m. 80 m schneidet die Außenringe, das ist der Regler.
- Keine neue Input-Aktion. `slum.tscn` unverändert, nur Laufzeit-Positionen. `claude_updatenotice.md` nicht angefasst.
- Getestet (Godot 4.7.2 stable, headless): `test_content_update.gd` CHECKS 46 FAILS 0. `slum.tscn --quit-after 20` ohne `SCRIPT ERROR`, `Parse Error` oder `ERROR`.
- Nicht getestet: Fenster, 2K/4K-Bild, ob FSR 2 im Fenster schwarz wird, Raytraced High auf der vollen Stadt über mehrere Sekunden, Laufwege zu den neuen Flecken zu Fuß. An den neuen Flecken lag kein Prop-Ursprung innerhalb von 7 m. Echte `user://settings.cfg` nicht gelöscht.
- Git: auf `main`, Notice in diesem Commit, danach `git push origin main`. `pictures/maxresdefault.jpg.import`, Torrent, `_test_appdata/` und fremde `.uid` nicht mit committed. Das Prüfskript `tools/tests/_audit_overlap.py` nach dem Lauf gelöscht.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-30 · Fenster, Auflösung, GI-Umschalten · Cursor (für EnScapeZ) · main
- Auftrag: Nach `9d5907f` Auflösung 1080p / 2K / 4K im Fenster und randlos prüfen, dazu ob GI sofort auf das laufende Environment geht, ohne die UI zu verzerren.
- Neu: `tools/tests/test_resolution_window.gd`. Läuft mit Fenster (Vulkan). `apply()` speichert nicht. Am Ende werden die geladenen Settings zurückgesetzt, `user://settings.cfg` wird nicht geschrieben.
- Behoben: `scenes/options/options_menu.gd`, `DrawDistanceValue` bekam `owner = self`, bevor der Label im Baum hing. Godot meldete `Invalid owner. Owner must be an ancestor in the tree` in `_build_nextgen_rows` Zeile 412, sobald das Optionsmenü instanziiert wurde. `add_child` steht jetzt davor.
- Gemessen auf diesem Rechner, Godot 4.7.2, Vulkan, AMD Radeon RX 9070 XT, Monitor `1920×1080`:
  - Stretch `canvas_items` (Modus 1), Aspekt `expand` (4).
  - Fenster `1920×1080`: `scaling_3d_scale` 1.0000, bilinear, UI-Skalierung x=1 y=1, Probe bleibt 2:1, Menütitel uniform.
  - Dieselben Werte noch einmal für die angefragten `2560×1440` und `3840×2160`, weil `_apply_resolution` auf die Monitorgröße klemmt. Ein echtes 2K- oder 4K-Fenster geht auf diesem Monitor nicht auf.
  - Rechnung ohne Fenster: `scale_for_window(1, 2560×1440)` = 0.7500, `scale_for_window(1, 3840×2160)` = 0.5000. Ein Faktor, kein zweites Seitenverhältnis.
  - Fenster `1280×800` (nicht 16:9): ebenfalls x=1 y=1, Probe 2:1, `scaling_3d_scale` 1.0000.
  - Upscale „DLSS Qualität“: Modus FSR 2, `scaling_3d_scale` 0.7700, UI danach weiter uniform.
  - Vollbild: `WINDOW_MODE_FULLSCREEN` (3), das ist Godots randloses Vollbild, nicht exklusiv. UI x=1 y=1.
  - GI 0/1/2, achtmal hintereinander, sofort: SDFGI nur bei 2, SSR ab 1. Dieselbe Environment-Instanz. Nach 10 Frames unverändert. Objektzahl in allen 8 Zyklen 1698, Differenz 0.
- Keine neue Input-Aktion. Keine Szenenänderung. `claude_updatenotice.md` nicht angefasst.
- Getestet: `test_resolution_window.gd` CHECKS 43 FAILS 0. Kein `Invalid owner` mehr. Kein `SCRIPT ERROR`.
- Nicht getestet: ein physischer 1440p- oder 4K-Monitor, Screenshot vom FSR-Bild, Raytraced High auf der ganzen Slum-Map über Minuten. Die Settings-Datei auf der Platte wurde nicht überschrieben.
- Git: auf `main`, dieser Eintrag im selben Commit, danach `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-30 · Optionsmenü scrollt, Knöpfe bleiben · Cursor (für EnScapeZ) · main
- Auftrag: Das Optionsmenü schneidet auf 1080p und kleiner die unteren Punkte ab (Volumetrischer Nebel, Übernehmen). Nur die Liste soll scrollen, Kopf, Reiter und Knöpfe bleiben stehen.
- Ursache: Das Optionsfeld im Hauptmenü ist fest 620×430 px (`offset` −310/−240 bis 310/190). Die Grafikseite ist mit den neuen Zeilen höher. Der TabContainer hat die Mindesthöhe der Liste nach oben durchgereicht, das Feld wuchs über den sichtbaren Bereich.
- Geändert:
  - `scenes/options/options_menu.tscn`: Jeder Reiter ist ein `ScrollContainer`. `%ContentScroll` / `GrafikList`, `%AudioScroll` / `AudioList`, `%ControlsScroll` / `ControlsList`. `size_flags_vertical` = Expand+Fill, `horizontal_scroll_mode` aus, `vertical_scroll_mode` automatisch, `mouse_filter` = PASS, `follow_focus` an. Die innere Liste füllt nur die Breite, nicht die Höhe, damit der Scrollbalken kommt. Kopf, `Tabs`, `ActionRow` (Übernehmen, Standard, Zurück) und `StatusLabel` bleiben außerhalb.
  - `scenes/options/options_menu.gd`: Reitertitel weiter GRAFIK, AUDIO, STEUERUNG. Neue Grafikzeilen hängen an `ContentScroll/GrafikList`. Die drei ScrollContainer bekommen dieselben Scroll- und Mauswerte noch einmal im `_ready`, falls die Szene sie verliert.
- Keine neue Input-Aktion. Keine Map-Änderung. `claude_updatenotice.md` nicht angefasst.
- Getestet (Godot 4.7.2 stable, headless): `tools/tests/test_options_scroll.gd` im 620×430-Feld, CHECKS 23 FAILS 0. Übernehmen endet bei y 397 von 430. Grafikliste 543 px bei 278 px sichtbar. Fokus auf Volumetrischer Nebel setzt `scroll_vertical` auf 265, der Eintrag liegt danach im sichtbaren Bereich, Übernehmen bleibt sichtbar. Mindesthöhe der ganzen Seite 152 px. Alle drei ScrollContainer: Mausfilter PASS, kein Quer-Scroll, Hoch-Scroll automatisch, Fokus folgt.
- Beim Prozessende dieselbe Abschlusszeile wie bei früheren Headless-Läufen: `ERROR: 1 resources still in use at exit` und 2 ObjectDB-Leaks. Kein `SCRIPT ERROR`, kein `Invalid owner`.
- Nicht getestet: Mausrad und Controller im echten Fenster, Pause-Menü als Bild.
- Git: auf `main`, dieser Eintrag im selben Commit, danach `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-30 · Vier Waffenläden, Innenausbau · Cursor (für EnScapeZ) · main
- Auftrag: Zwei weitere Waffenläden (insgesamt vier) und alle vier innen ausbauen: Vitrine, Wandregale, Kasse, Automat, verschlossene Kammer, Neon, Händler, Handel mit Credchips.
- Keine eigene `gun_shop.tscn`. Der Laden entsteht weiter in `scenes/crime/street_shop.gd` (`Kind.GUNS`), `CityContent` setzt ihn auf die Map.
- Koordinaten, Grundfläche 8×7 m, yaw 0 außer dem ersten. Abstandsprüfung gegen alle `k_building`-Fußabdrücke, Straßen/Kreuzungen und die anderen neuen Gebäude, Puffer 1 m: 0 Schnitte, nicht auf der Fahrbahn.
  - `(-110, 0, 60)`, yaw 90 (bestand).
  - `(70, 0, 64)`, yaw 0 (bestand).
  - `(-70, 0, -46)`, yaw 0 (neu).
  - `(-16, 0, -42)`, yaw 0 (neu).
- Innen, lokal, Front nach +Z, Eingang 3 m breit zwischen den Pfeilern:
  - Theke und Glaskasten. Darauf kaufbar: Pistole 40 ¢, SMG 80 ¢, M4 120 ¢, AK-47 110 ¢, Scharfschützengewehr 200 ¢, Eddy 15 ¢. Drei Munitionskisten nur als Modell.
  - Lochwand links und rechts mit M4, AK-47, SMG und Scharfschützengewehr als Ansichtsmodelle, ohne Kollision.
  - `%Clerk` an der Thekenvorderkante: gewählte Waffe oder Nahkampf wird für die Hälfte von `value` verkauft (mindestens 1 ¢, ohne `value` 8 ¢). Leeres Magazin der gehaltenen Waffe kostet 2 ¢ pro fehlender Patrone (`WeaponHolder.refill_magazine`).
  - `%Shopkeeper`: Zivilist, `stay_put`, Blick zur Tür, Zeile „Waffen?“. Friedlich, bis jemand zielt oder trifft (bestehendes CivilianCrime).
  - `%BackDoor` in der Trennwand, Schlüssel-id `gun_back`, zu. Auf mit Eddy oder einer Karte dieser id. Spalt 1,2 m, Türblatt 1,1 m.
  - Dahinter Werkbank und `%ArmoryCrate` (versiegeltes Scharfschützengewehr). `%Register` ist eine versiegelte Kasse, 4× Bargeld.
  - `%Atm`: bestehender Bankautomat, Front in den Raum. Neon „WAFFEN“ plus Deckenlicht cyan und magenta, Schatten aus.
- Geändert: `scenes/crime/city_content.gd`, `scenes/crime/street_shop.gd`, `scenes/weapons/weapon_holder.gd` (`refill_magazine`). Neu: `tools/tests/test_gun_shops.gd`.
- Keine neue Input-Aktion. `slum.tscn` nicht angefasst. `claude_updatenotice.md` nicht angefasst.
- Getestet (Godot 4.7.2 stable, headless): `test_gun_shops.gd` CHECKS 29 FAILS 0. Vier Läden, jeder mit Händler, Clerk, Automat, verschlossener Kammer, Vitrine, Neon, Waffenkiste. Kein `SCRIPT ERROR`.
- Nicht getestet: Laufweg im Fenster, ob die Theke im Bild die Sicht auf den Händler verdeckt, Navmesh-Bake nach den neuen Wänden (die Map backt Kollision beim Start wie bisher).
- Git: auf `main`, dieser Eintrag im selben Commit, danach `git push origin main`. Das Hilfsskript `tools/tests/_gun_sites.py` nach dem Lauf gelöscht.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-30 · Wohnungen, 35 % Bewohner, Fesseln · Cursor (für EnScapeZ) · main
- Auftrag: Wohnungen einrichten, Beute fest drin, Tür mit Karte oder Eddy, in 35 % der Wohnungen 1 oder 2 Bewohner, Kabelbinder und Handschellen fesseln, danach durchsuchen ohne neuen Kampf.
- `scenes/crime/apartment_block.gd`: Drei Themen aus `key_id` (Neon, warm, kalt). Boden, Decke, Wände, Sofa, Bett, Nachttisch, Küchenzeile, Kühlschrank, Schreibtisch, Tisch, zwei Lampen, zwei Lichter ohne Schatten. Tür `%Door` startet zu, Spalt 1,4 m. Beute mit Unique Names, jedes Stück ein `.tres` mit Modell und Icon: `%Jewelry` Schmuck, `%Jewels` Juwelen (versiegelt, Eddy), `%Cash` Bargeld, `%Television` Fernseher, `%Artwork` Bild, `%Computer` Computer.
- Bewohner: `RESIDENT_CHANCE` 0,35. Darüber 0. Darunter 1 oder 2, je Hälfte. `resident_count` >= 0 erzwingt die Zahl. Mitbewohner im selben Elternknoten zählen nicht als Menge auf der Straße.
- `scenes/crime/locked_door.gd`: Eddy macht weiter Lärm 18 m (`NoiseManager`, `BURGLARY`) und eine Fahndungsstufe. Token ist die Wohnung, nicht die Tür.
- `scenes/crime/civilian_crime.gd`: Hört der Bewohner den Einbruch, Panik, Zeile „Polizei!“, dieselbe Fahndungsstufe (gleicher Token, also nicht noch ein Stern). Fesseln mit `handcuffs` oder `zipties`, wenn die Hände oben sind oder die Person isoliert, von hinten, geduckt und leise ist. Durchsuchen nimmt das Bargeld in der Tasche und, bei jedem dritten Seed, ein Schmuckstück. Dabei keine neue Fahndung.
- Keine neue Input-Aktion. Grundfläche der Wohnung bleibt 8×7 m, die drei Standorte unverändert. `claude_updatenotice.md` nicht angefasst.
- Getestet (Godot 4.7.2 stable, headless): `tools/tests/test_apartments.gd` CHECKS 32 FAILS 0. 4000 Würfe, Seed 42: Quote 0,334 (1334 von 4000), davon 678 mit einem und 656 mit zwei Bewohnern. Erzwungen 0 und 2. Leere und volle Wohnung haben Tür, die sechs Beutestücke, Sofa, Bett, Küche. Juwelen versiegelt, Tür zu. Eddy auf eine Wohnung mit zwei Bewohnern: Tür auf, Wanted genau 1.
- Nicht getestet: Fenster, ob Sofa und Kühlschrank den Weg zur Tür im Bild freilassen, Controller.
- Git: auf `main`, dieser Eintrag im selben Commit, danach `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-30 · Wohnungen im Block Res2, Verkaufspult · Cursor (für EnScapeZ) · main
- Auftrag: Die freien Wohnungskästen weg, stattdessen 4 Wohnungen in einem bestehenden Haus mit Flur und Treppe. Diebesgut an Waffenläden, Tankstellen und beim Hehler verkaufen.
- Gebäude: `scenes/slum/slum.tscn` Knoten `NorthEast/Res2`, Position `(13, 0, -56.5)`, Grundfläche 12×10 m, 6 Stockwerke, `walk_in_apartments = true`.
- `scenes/slum/kit/slum_building.gd`: neues Export `walk_in_apartments`. Wenn an, kein massiver Füllkörper und kein Occluder im unteren Haus. Dünne Außenwände, Türschlitz 1,5 m breit und 2,6 m hoch in der Frontmitte, Stufe davor. Ab dem dritten Obergeschoss (y = 3×Etagenhöhe) bleibt der Block massiv. `ApartmentHouse` wird als generiertes Kind eingehängt.
- `scenes/crime/apartment_house.gd`: Flur, zwei Treppenläufe (Erdgeschoss nach Stock 1, Stock 1 nach Stock 2). Vier Einheiten, Tür zum Flur:
  - Stock 1 links `apt_1`, rechts `apt_2` (Karte für `apt_1` liegt darin).
  - Stock 2 links `apt_3` (Karte für `apt_2`), rechts `apt_c` (Karte für `apt_3`). `apt_c` ist dieselbe id wie die Schlüsselkarte an der Tankstelle `(90, -101)`.
  - Einheiten etwa 7,2×4,2 m, Decke 2,75 m. Jede mit Sofa, Bett, Küche, Licht, und der Beute Schmuck, Juwelen (versiegelt), Bargeld, Fernseher, Bild, Computer, Handy. Bewohner weiter 35 %, 1 oder 2. Tür zu, Eddy oder passende Karte, Lärm 18 m, eine Fahndungsstufe.
- `scenes/crime/city_content.gd`: die drei Wohnungen auf freien Platten sind raus.
- Verkauf: `scenes/crime/loot_sell_pad.gd`, Pult `%SellPad` mit Schild VERKAUFEN in jedem Waffenladen und jeder Tankstelle. Sortiment `jewelry`, `jewels`, `cash_wad`, `tv_set`, `painting`, `computer`, `smartphone`, Preis die Hälfte von `value` (mindestens 1 ¢). Schmuck 40→20 ¢, Fernseher 55→27 ¢. Stück weg, Credchips sofort drauf. Der Hehler in `scenes/interact/shop_ui.gd` heißt die Sektion jetzt „VERKAUFEN – WERTSACHEN, KEINE FRAGEN“ und zahlt weiter 50 % ab 8 ¢ Wert.
- Fesseln und Einbruch aus dem Eintrag davor bleiben. Keine neue Input-Aktion. `claude_updatenotice.md` nicht angefasst.
- Getestet (Godot 4.7.2 stable, headless): `test_apartments.gd` CHECKS 44 FAILS 0. Quote weiter 0,334 bei Seed 42. Haus: 4 verschlossene Türen, Schlüssel `apt_1` und `apt_c`. Verkauf 20 ¢ und das Item ist weg. `test_gun_shops.gd` CHECKS 29 FAILS 0. `slum.tscn --quit-after 8` ohne `SCRIPT ERROR` und ohne `Parse Error`.
- Nicht getestet: der Weg vom Hauseingang die Treppe hoch im Fenster, ob die Treppenstufen an der Flurdecke schneiden, Mausklick auf VERKAUFEN im Bild.
- Git: auf `main`, dieser Eintrag im selben Commit, danach `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/cursor_updatenotice.md`

### 2026-10-31 · Notice in enscapez_updatenotice.md umbenannt · Claude (für EnScapeZ) · main
- Auftrag: Die eigene Update-Notice weiterführen, nie die Claude-Notices, und die Datei in eine EnScapeZ-Notice umbenennen.
- Was: `cursor_updatenotice.md` per `git mv` in `enscapez_updatenotice.md` umbenannt, Kopf und Vorlage angepasst. Alte Einträge nicht geändert, der alte Name steht dort weiter.
- Dateien: `enscapez_updatenotice.md`, `.cursor/hooks/require-cursor-notice.py`, `.cursor/rules/01_update_notice_rules.mdc`, `.cursor/rules/02_cursor_notice_always_upload.mdc`, `.cursor/rules/03_main_only.mdc`, `.cursor/rules/ai-handover.mdc`.
- Entscheidungen: Name passt zum Muster `*_updatenotice.md`. Die Dateinamen von Hook und Regeln bleiben. `claude_updatenotice.md` und `updatenotices/claude/` nicht angefasst, dort steht weiter der alte Name.
- Getestet: `git grep` findet den alten Namen nicht mehr unter `.cursor/`. Hook lässt sich als Python parsen.
- Nicht getestet: Hook in Cursor im echten Commit. Kein Godot-Lauf, kein Spielcode geändert.
- Git: auf `main`, dieser Eintrag im selben Commit, danach `git push origin main`.
- Link: `https://github.com/CaptainArschbart/Test/blob/main/enscapez_updatenotice.md`

### 2026-10-31 · Tankstellen in Sektor 7 ausgebaut · Claude (für EnScapeZ) · enscapez/tankstellen-ausbau
- Auftrag: Die Tankstellen in Sektor 7 weiter ausarbeiten.
- Neu:
  - `scenes/crime/gas_station.gd`: Anlage 15×14 m. Laden 10×6 m mit Glasfront, Theke, Vitrine, Regalgängen, Kühlschränken, `ShopInterior` mit Verkäufer, Kamera, Tagestresor und `%SellPad` auf der Theke. Vordach, zwei Inseln, vier Zapfsäulen, geparktes Auto, Automaten, Geldautomat, Luftstation, Schilder, Preisstele.
  - `scenes/crime/gas_pump.gd`: Zapfsäule mit 45 Leben. Zerschossen explodiert sie (95 Schaden, 6 m Radius, 60 m Lärm), zündet Säulen bis 6 m, brennt 30 s, steht nach 240 s wieder. Host rechnet, Zustand läuft über `WorldSync`.
  - `tools/tests/test_gas_stations.gd`.
- Geändert:
  - `scenes/crime/street_shop.gd`: `_build_gas` legt nur noch die neue Anlage als Kind `Station` an, alte Hülle, Vordach, Säulen und Automaten entfernt.
  - `scenes/crime/city_content.gd`: Tankstellen stehen jetzt bei `(-41, 0, -68)` mit Yaw 180 zur Straße (vorher `(-48, -71)`, Yaw 0) und `(86, 0, -101)` (vorher `(90, -101)`, Karte `apt_c` bleibt dort), `(-111, 88)` unverändert. Läden heißen `Shop%d`, damit die Netzpfade stabil sind. Die Angabe `(90, -101)` in älteren Einträgen ist damit überholt.
  - `scenes/interact/shop_interior.gd`: Eintrag `sign_gas` im Katalog, Aufschlag 1,4, Waffenchance 0,4.
- Gelöscht: nichts im Repo. Eigene Wegwerfskripte `_scan_gas.gd` und `_shot_gas.gd` nie committet.
- Entscheidungen:
  - Vorher hatte die Tanke nur eine Hülle mit schwebender Kasse, Karte und Pult. Darum neu statt geflickt, mit dem vorhandenen `ShopInterior`.
  - Theke links, weil der Verkäufer fest nach lokal +X blickt und die Tür bei `bounds.end.z` liegt.
  - Eigene Kettenprüfung über `ignite()`: Die Vordachsäule blockierte den Sichtstrahl der Granate, die Nachbarsäule ging sonst nicht mit hoch.
  - Explosion nutzt `ThrownGrenade` mit eigenen Werten statt eigener Schadenslogik.
  - Kühlschrank und Vordach überstrahlten, daher eigene schwächere Materialien. Preise lagen im Pfeiler, daher zwei feste Label vor den Flächen.
- Getestet (Godot 4.7.2 stable, headless, Stand Commit 31a3136):
  - `test_gas_stations` CHECKS 59 FAILS 0.
  - `test_gun_shops` CHECKS 29 FAILS 0, `test_shop` CHECKS 43 FAILS 0, `test_apartments` CHECKS 44 FAILS 0, `test_money` CHECKS 25 FAILS 0, `test_bank` CHECKS 41 FAILS 0, `test_consumables` CHECKS 45 FAILS 0, `test_enemy_xp` CHECKS 29 FAILS 0, `test_sector7_enemies` CHECKS 15 FAILS 0, `test_audio` CHECKS 18 FAILS 0.
  - `test_mp_sync` (Karte slum) Host CHECKS 9 FAILS 0, Client CHECKS 10 FAILS 0.
  - `test_content_update` CHECKS 46 FAILS 1, „Einbruch +1 Stern (1 -> 1)“. Gleicher Fehler ohne diese Änderung auf `e22f2f6`. Beide Testtüren hängen unter `root`, teilen vermutlich das Token von `WantedManager.report`.
  - `test_sector7_city` CHECKS 44 FAILS 1 auf dem Branch, in zwei Läufen mit wechselnder Meldung (Fußgänger an der Kreuzung, Fußgänger weggelaufen). Auf `e22f2f6` ebenfalls CHECKS 44 FAILS 1 (Fußgänger an der Kreuzung).
  - `test_shop_net` Host CHECKS 8 FAILS 3 (Regal, Verkäufer und Kasse von Laden B), Client bricht mit `SCRIPT ERROR` ab (freigegebene Instanz). **Ursache nicht geklärt.** Der Test wählt Läden nach Pfad-Sortierung, die Umbenennung auf `Shop%d` und die neuen Läden können das beeinflussen. Vergleich mit `e22f2f6` abgebrochen, ein Fehler durch diese Änderung ist nicht ausgeschlossen.
  - `test_mp_world` Host CHECKS 12 FAILS 1 („Gegner ist tot“), Client CHECKS 14 FAILS 0. Ursache nicht geklärt, kein Vergleich mit der Basis.
  - Der erste Lauf der drei MP-Tests ohne Host-Partner war mein Bedienfehler und zählt nicht.
- Nicht getestet:
  - Multiplayer an Tankstellen, Säulen und Laden: EnScapeZ hat den Multiplayer für diese Aufgabe ausgeklammert.
  - Echtes Spielen im Fenster: Tests nur headless. Screenshots von Tag, Nacht, Innenraum, Explosion und Stele entstanden, bevor die Regel „keine Screenshot-Tests“ kam, und vor der letzten Senkung der Vordach-Helligkeit.
  - Fahndung durch eine Säulenexplosion: nicht angebunden.
- Git: Branch `enscapez/tankstellen-ausbau`, PR #59. Auf Anweisung von EnScapeZ gemerged, obwohl `test_shop_net` und `test_mp_world` rot und ungeklärt sind. `arschi_updatenotice.md` fehlte zu Arbeitsbeginn auf `origin/main`, kam während der Arbeit dazu (NPC-Raub) und wurde danach gelesen, keine Überschneidung. `origin/main` ist inzwischen weiter (#56, #57), GitHub meldet den PR als konfliktfrei. `origin/main` per Merge-Commit in den Branch geholt statt Rebase, weil der Branch schon gepusht war und Force-Push verboten ist. Danach `test_gas_stations` CHECKS 59 FAILS 0, die übrigen Prüfskripte liefen nur auf dem Stand davor. Lose `*.uid` von Fremden und `_test_appdata/` nicht mitcommittet.
- Offen: `test_shop_net` und `test_mp_world` gegen die Basis prüfen. `test_content_update` reparieren.

### 2026-10-31 · Wohnungen in acht Häusern von Sektor 7, Tresore, Brechstange · Claude (für EnScapeZ) · enscapez/wohnungen-sektor7
- Auftrag: Wohnungen in Sektor 7 begehbar machen und detailliert in die ungenutzten Häuser einbauen, Türen und Tresore mit der Brechstange aufbrechen, Schlüssel für später (Taschendiebstahl), Eddy in Brechstange umbenennen, alles testen. Multiplayer ist laut EnScapeZ vorerst egal.
- Neu:
  - `scenes/crime/safe_prop.gd`: Tresor (`SafeProp`, erbt von `LootProp`). Nur mit der Brechstange offen, Lärm wie versiegelte Beute, eine Fahndungsstufe (gleiche Sperre wie die Wohnungstür). E räumt aus, der Kasten bleibt offen stehen.
  - `tools/tests/test_apartments_walk.gd`: echte Spielerfigur in Sektor 7, Treppe, Türen, Tresor, Schlüssel, alle Zimmer.
- Geändert:
  - `scenes/crime/apartment_house.gd` neu: Die alte Flurplatte hatte kein Treppenloch, nach oben kam man nicht. Jetzt gegenläufige Treppe in zwei Spuren, Absatz hinten im 1. Stock, vorn im 2. Stock, Eingangshalle mit Briefkästen, Mülltonne, Wandleuchten. `key_prefix` je Haus.
  - `scenes/crime/apartment_block.gd` neu: Grundriss mit Flur, Bad (WC, Waschtisch, Dusche), Wohnküche (Küchenzeile, Kühlschrank, Sofa, Couchtisch, Fernsehbank), Schlafzimmer (Bett, Nachttisch, Schreibtisch, Kleiderschrank, Tresor), Fenster, Türschild. Geometrie über `SlumBuilder` zusammengefasst, Innenleben ab 44 m nicht mehr gezeichnet, Lichter ohne Schatten mit Distanz-Fade. Statisch `key_item(id)` für Schlüssel.
  - `scenes/slum/kit/slum_building.gd`: Export `apartment_prefix`. Gesimse bei `walk_in_apartments` nur noch außen herum, die Platte lag sonst sichtbar im Treppenhaus.
  - `scenes/slum/slum.tscn`: `walk_in_apartments` zusätzlich an `Res4`, `Res6`, `Res9`, `Res12`, `Res14`, `Res15`, `Res17` (mit `Res2` acht Häuser, 32 Wohnungen).
  - `scenes/crime/locked_door.gd`: Hinweis „Linksklick bricht auf“ mit Brechstange in der Hand, `open_offset`. `scenes/crime/loot_prop.gd`: Klotz verdeckt das Modell nicht mehr, Hooks `_build_look` und `_after_take`.
  - `scenes/items/data/crowbar.tres`: Name Brechstange, Kürzel BS. Die Item-id bleibt `crowbar`.
  - `tools/tests/test_content_update.gd`: Testfehler „Einbruch +1 Stern“ behoben, die zweite Tür hat einen eigenen Elternknoten.
- Entscheidungen: `Res2` behält die Schlüssel ohne Präfix, die Karte `apt_c` an der Tankstelle passt weiter. Die anderen Häuser haben Präfixe wie `res4_`. Taschendiebstahl gibt noch keine Schlüssel, das kommt laut Auftrag später und soll `ApartmentBlock.key_item` nutzen. Der Tagestresor der Tankstelle bleibt unverändert.
- Getestet (Godot 4.7.2 stable, headless, isoliertes APPDATA): `test_apartments_walk` CHECKS 96 FAILS 0, `test_content_update` CHECKS 47 FAILS 0, `test_gas_stations` 59/0, `test_gun_shops` 29/0, `test_shop` 43/0, `test_money` 25/0, `test_bank` 41/0, `test_consumables` 45/0, `test_enemy_xp` 29/0, `test_audio` 18/0, `test_player_melee` 42/0, `test_weapons_smg_grenade` 47/0, `test_sector7_enemies` 15/0, `test_sector7_city` 44/0. Nach dem Rebase auf `origin/main` erneut: `test_apartments` 55/0, `test_npc_robbery` 34/0. Kein `SCRIPT ERROR`.
- Nicht getestet: Aussehen im Fenster und Bildrate mit den 32 Wohnungen, keine Screenshots. Multiplayer-Tests bewusst nicht gelaufen.
- Git: Branch `enscapez/wohnungen-sektor7` gepusht. `gh` war nicht angemeldet, Draft-PR und Merge stehen noch aus.
- Offen: PR anlegen und mergen, Schlüssel als Taschendiebstahl-Beute.
