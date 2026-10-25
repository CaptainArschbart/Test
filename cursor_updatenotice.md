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
