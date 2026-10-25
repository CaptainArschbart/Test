# 🤖 Project AI Handover Log

> **Engine:** Godot 4.7 (Feature-Tag `4.7`, Renderer Forward Plus)  
> **Projekt-Typ:** 3D Game (Grundgerüst: Cyberpunk-Hauptmenü plus First-Person-Testwelt)  
> **Projektname:** Godot 3D Base  
> **Letztes Update:** 2026-10-25  
> **Hauptszene:** `res://scenes/menu/main_menu.tscn`  
> **Sprache:** GDScript (Standard-Godot, nicht .NET / C#)

Dieses Dokument ist der Ist-Stand des Repos. Es beschreibt nur, was in `project.godot`, den Szenen und den Skripten steht.

`scenes/interactive/interactive_box.tscn` ist **nicht** im Projekt. Es gibt keinen Ordner `scenes/interactive/`.

---

## 1. 📁 Ordner- & Datei-Struktur

```text
project.godot                 Hauptszene, Input Map, Physik-Layer, 4× MSAA
icon.svg
icon.svg.import
README.md
.gitignore
.gitattributes
AI_HANDOVER.md
autoload/
  settings.gd                 Autoload "Settings", user://settings.cfg
  settings.gd.uid
scenes/
  menu/
    main_menu.tscn            Startszene, Control
    main_menu.gd              uid://b56yhlqq1bgvx
    main_menu.gd.uid
    menu_background.gdshader  uid://cw7ulhsglsebx
    menu_background.gdshader.uid
    crt_overlay.gdshader      uid://cveheluq50cmp
    crt_overlay.gdshader.uid
  main/
    main.tscn                 Spielwelt, wird von Start geladen
    main.gd                   uid://npu706i2yy2e
    main.gd.uid
  player/
    player.tscn               CharacterBody3D, First Person
    player.gd                 class_name Player, uid://3ek5xjcrt0uw
    player.gd.uid
assets/
  audio/.gitkeep              leer
  materials/.gitkeep          leer
  models/.gitkeep             leer
  textures/.gitkeep           leer
```

`.godot/` ist per `.gitignore` ausgeschlossen. Keine `.tres`-Dateien, keine Export-Presets, keine Audio-Dateien. Einziger Autoload: `Settings`.

Konvention aus `README.md`: eine Szene und ihr Skript liegen im selben Ordner unter `scenes/<name>/`. `autoload/settings.gd` ist die Ausnahme, weil es ein Autoload ohne eigene Szene ist.

---

## 2. ⚙️ project.godot

| Bereich | Wert |
|---|---|
| `config/name` | `Godot 3D Base` |
| `config/description` | Grundgerüst für ein 3D-Spiel in Godot 4 (GDScript). |
| `run/main_scene` | `res://scenes/menu/main_menu.tscn` |
| `config/features` | `4.7`, `Forward Plus` |
| `config/icon` | `res://icon.svg` |
| Viewport | 1280 × 720 |
| MSAA 3D | `2` → 4× MSAA |
| Autoloads | `Settings` → `res://autoload/settings.gd` |
| `[animation]` | `compatibility/default_parent_skeleton_in_mesh_instance_3d=true` |

### Input Map (nur diese sechs Aktionen sind im Projekt definiert)

Alle haben `deadzone` 0.2 und genau ein Tastatur-Event (`physical_keycode`). Keine Maus- und keine Joypad-Events. Die Tabelle zeigt die Standardbelegung aus `project.godot`. Der Spieler kann alle sechs im Menü neu belegen; `Settings` ersetzt beim Start und nach *Übernehmen* das Tastatur-Event der Aktion in der `InputMap`.

| Aktion | Taste | physical_keycode | Verwendung |
|---|---|---|---|
| `move_forward` | W | 87 | `player.gd` |
| `move_back` | S | 83 | `player.gd` |
| `move_left` | A | 65 | `player.gd` |
| `move_right` | D | 68 | `player.gd` |
| `jump` | Leertaste | 32 | `player.gd`, nur am Boden |
| `sprint` | Shift | 4194325 (`KEY_SHIFT`) | `player.gd`, gehalten |

### Tasten außerhalb der Input Map

| Taste | Ort | Wirkung |
|---|---|---|
| F11 (`KEY_F11`) | `main_menu.gd`, `main.gd` | `Settings.toggle_fullscreen()`: schaltet das Fenster und speichert sofort. Im Menü wird zusätzlich die Vollbild-Checkbox der offenen Optionen nachgezogen. |
| Esc | Menü | Während eine Taste neu belegt wird: bricht das Belegen ab. Sonst, wenn das Options-Panel offen ist: wie *Zurück* (bei nicht übernommenen Änderungen erst eine Warnung, beim zweiten Mal verwerfen). Sonst keine Wirkung. |
| Esc | Spielwelt | `ui_cancel` in `player.gd` macht die Maus sichtbar. Kein Pause-Menü, kein Szenenwechsel. |
| Mausklick | Spielwelt | Jeder gedrückte `InputEventMouseButton` setzt `MOUSE_MODE_CAPTURED`. |

### Controller und UI-Fokus

Die Spielaktionen haben keine Gamepad-Belegung. Laufen, Sprint und Sprung sind nur Tastatur.

Das Menü definiert keine eigenen UI-Aktionen. Godots eingebaute `ui_up`, `ui_down`, `ui_accept` und `ui_cancel` sind im Projekt nicht überschrieben und behalten die Engine-Defaults (Pfeiltasten, Enter, Escape, Controller-Stick, D-Pad, Joypad-Buttons). Die Menü-Buttons liegen in einer `VBoxContainer` und nehmen Fokus (`grab_focus`, zusätzlich `mouse_entered` → `grab_focus`). Damit lässt sich das Menü mit Tastatur und mit dem Controller-Fokus bedienen. Die Spielwelt nicht.

`Beenden` wird ausgeblendet, wenn `OS.has_feature("web")`. Es gibt keinen Web-Export-Preset im Repo.

### Physik-Layer (3D)

| Layer-Bit | Name | Verwendung |
|---|---|---|
| 1 | `world` | Default der CSG-Körper (`use_collision = true`, Layer nicht gesetzt) |
| 2 | `player` | `Player.collision_layer = 2` |

`Player.collision_mask` ist nicht gesetzt und bleibt auf dem Godot-Default `1` (nur `world`). Layer 3–32 sind unbenannt.

Schwerkraft steht nicht in `project.godot`. `Player.gravity` liest `physics/3d/default_gravity` (Engine-Default 9.8).

### user://settings.cfg

Gelesen und geschrieben vom Autoload `Settings` (`autoload/settings.gd`). Er lädt die Datei in `_ready`, also vor jeder Szene, und wendet alles an. Auch ein direkter Start von `main.tscn` (F6) bekommt so die gespeicherten Werte.

| Schlüssel | Standard | Wirkung |
|---|---|---|
| `[video] fullscreen` | `false` | `DisplayServer.window_set_mode` |
| `[video] vsync` | `true` | `DisplayServer.window_set_vsync_mode` |
| `[audio] master_volume` | `80.0` (0–100) | Bus `Master`, `linear_to_db(value / 100)`, stumm bei `<= 0` |
| `[controls] mouse_sensitivity` | `1.0` | Faktor auf `Player.mouse_sensitivity` |
| `[controls] invert_y` | `false` | dreht die Pitch-Richtung im Player um |
| `[keys] <aktion>` | Belegung aus `project.godot` | `physical_keycode` für `move_*`, `jump`, `sprint` |

Geschrieben wird nur bei *Übernehmen* im Optionsmenü und bei F11. Fehlt die Datei, gelten die Standardwerte. Unter `assets/audio/` liegt keine Datei, und keine Szene spielt einen Ton ab.

---|---|---|
| `[video] fullscreen` | aktueller Fenstermodus ist bereits Vollbild | Sofort bei jedem Vollbild-Umschalten (Checkbox, F11 im Menü, F11 in der Spielwelt). Beim Öffnen des Menüs wird der gelesene Wert angewendet und dabei erneut geschrieben. |
| `[video] vsync` | `true` | Nur in `save_preferences`, aufgerufen wenn die Optionen mit Zurück oder Esc verlassen werden. |
| `[audio] master_volume` | `80.0` | Ebenfalls nur beim Verlassen der Optionen. |

`set_fullscreen` und `save_preferences` laden die Datei zuerst und ersetzen sie nicht leer. Ein F11 in der Spielwelt löscht Lautstärke und VSync nicht. Fehlt die Datei, liefert `ConfigFile.load` einen Fehler und die Defaults gelten. Lautstärke setzt den Bus `Master` (`linear_to_db(value / 100)`, stumm bei `<= 0`). Unter `assets/audio/` liegt keine Datei, und keine Szene spielt einen Ton ab.

---

## 3. 🎬 Ablauf (Einbahnstraße)

```text
F5
 └─ main_menu.tscn
      Maus sichtbar, Start hat Fokus (settings.cfg hat der Autoload schon angewendet)
      Start
        ├─ Glitch-Stärke 1.0 für 0,5 s (CRT-Shader-Uniform "glitch")
        ├─ Fade (ColorRect $Fade) Alpha 0 → 1 in 0,45 s
        └─ get_tree().change_scene_to_file(game_scene)
             Default: res://scenes/main/main.tscn
              └─ Player._ready setzt MOUSE_MODE_CAPTURED
                   Esc gibt die Maus frei, Klick fängt sie wieder
                   kein Button, kein Pause-Menü, kein change_scene zurück
```

`game_scene` ist `@export_file` am Menü und in der Szene nicht überschrieben. Der Szenenwechsel ersetzt den ganzen Baum. Einstellungen bleiben, weil sie im Autoload `Settings` und an `DisplayServer`, `AudioServer` und `InputMap` hängen, nicht am Menü-Knoten.

Es gibt keinen Rückweg ins Menü.

---

## 4. Szenen-Hierarchie

### `scenes/menu/main_menu.tscn` — Wurzel `MainMenu` (`Control`, Skript `main_menu.gd`)

```text
MainMenu (Control)                     theme: cyber, script main_menu.gd
├── Background (ColorRect)             Shader menu_background.gdshader
├── Margin (MarginContainer)
│   └── Layout (VBoxContainer)
│       ├── %TitleBox
│       │   ├── %TitleCyan             "NEON//GRID"
│       │   ├── %TitleMagenta          "NEON//GRID"
│       │   └── %Title                 "NEON//GRID"
│       ├── %Subtitle                  "// SYSTEM ONLINE_"
│       ├── Spacer
│       ├── %MainButtons (VBoxContainer)
│       │   ├── %StartButton           "START"
│       │   ├── %OptionsButton         "OPTIONEN"
│       │   └── %QuitButton            "BEENDEN"
│       └── Footer
├── %OptionsPanel (PanelContainer)     anfangs unsichtbar, mittig; beim Öffnen werden %TitleBox und %Subtitle ausgeblendet
│   └── Options
│       ├── Header                     "> OPTIONEN"
│       ├── %Tabs (TabContainer)
│       │   ├── "ANZEIGE & AUDIO"      %FullscreenCheck, %VsyncCheck, %VolumeSlider/%VolumeValue
│       │   └── "STEUERUNG"            %SensitivitySlider/%SensitivityValue (0.1–3.0),
│       │                              %InvertYCheck, KeyHint, %KeyGrid (4 Spalten, Knöpfe im Code erzeugt)
│       ├── ActionRow                  %ApplyButton "ÜBERNEHMEN" (nur aktiv bei Änderungen),
│       │                              %DefaultsButton "STANDARD", %BackButton "ZURÜCK"
│       └── %StatusLabel               "Ungespeicherte Änderungen" / "übernommen" / Warnung
├── Fade (ColorRect)                   schwarz, Alpha 0, Pfad $Fade
└── Overlay (ColorRect)                Shader crt_overlay.gdshader, Pfad $Overlay
```

`%` bedeutet `unique_name_in_owner`. Relative Pfade im Skript: `$Overlay.material`, `$Fade`.

Hintergrund-Shader zeichnet Himmel, zwei Skyline-Ebenen und ein perspektivisches Bodengitter. CRT-Shader zeichnet Scanlines, chromatische Aberration, Vignette, Rauschen und das Uniform `glitch` (0 = ruhig, 1 = stark).

### `scenes/main/main.tscn` — Wurzel `Main` (`Node3D`, Skript `main.gd`)

```text
Main (Node3D)
├── WorldEnvironment                   Sky, ACES, SSAO, Glow
├── Sun (DirectionalLight3D)           Schatten an, max distance 80
├── Level (Node3D)
│   ├── Ground (CSGBox3D)              100×1×100, Position (0, -0.5, 0)
│   ├── BoxSmall (CSGBox3D)            Default-Größe 2×2×2, Position (4, 0.5, -6)
│   ├── BoxLarge (CSGBox3D)            4×2×4, Position (-5, 1, -10)
│   └── Ramp (CSGBox3D)                3×0.3×8, etwa 20° um X, Position (8, 0.6, 2)
└── Player                             Instanz player.tscn, Transform nicht überschrieben
```

Environment: `background_mode = 2` (Sky), `ambient_light_source = 3` (Sky), `reflected_light_source = 2` (Sky), `tonemap_mode = 2` (ACES), SSAO und Glow an. Boden `Color(0.32, 0.45, 0.3)`, Kisten `Color(0.55, 0.6, 0.68)`, Rampe `Color(0.7, 0.62, 0.45)`. Alle vier CSG-Knoten haben `use_collision = true`. `BoxSmall` ragt mit der Default-Höhe in den Boden. CSG ist Platzhalter-Geometrie.

### `scenes/player/player.tscn` — Wurzel `Player` (`CharacterBody3D`, `class_name Player`)

```text
Player                                 collision_layer = 2, collision_mask = 1 (Default)
├── CollisionShape3D                   Capsule radius 0.4, height 1.8, Offset Y 0.9
├── Body (MeshInstance3D)              gleiche Kapsel, Farbe (0.85, 0.45, 0.2), Schatten an
└── Head (Node3D)                      Offset Y 1.6
    └── Camera3D                       current = true, fov = 80
```

Kein Knoten hat `unique_name_in_owner`. Zugriffe: `$Head`, `$Head/Camera3D`.

---

## 5. 📜 Skripte

### `autoload/settings.gd` (Autoload `Settings`)

- `extends Node`, kein `class_name` (der Autoload-Name ist `Settings`)
- Signal `changed` nach jedem `apply()`
- Konstanten `PATH := "user://settings.cfg"` und `REBINDABLE_ACTIONS` (Aktion → Anzeigename im Menü). Eine weitere Aktion belegbar machen: dort eintragen.
- Felder: `fullscreen`, `vsync`, `master_volume`, `mouse_sensitivity`, `invert_y`, `key_bindings` (Aktion → `physical_keycode`)
- Öffentlich: `get_values()`, `get_defaults()`, `apply_values(dict)` (übernehmen, anwenden, speichern), `apply()`, `toggle_fullscreen()`, `key_name(code)` (statisch, Name im aktuellen Tastaturlayout), `load_settings()`, `save_settings()`
- Standard-Tastenbelegung wird in `_ready` aus der `InputMap` gelesen, bevor die Datei geladen wird

### `scenes/menu/main_menu.gd`

- `extends Control`, kein `class_name`
- Keine eigenen `signal`-Deklarationen. Verbindungen laufen auf Button- und Slider-Signale.

| Export | Default |
|---|---|
| `game_scene` | `res://scenes/main/main.tscn` |
| `glitch_interval_min` | `1.5` |
| `glitch_interval_max` | `4.5` |
| `glitch_duration` | `0.18` |

Engine-Callbacks: `_ready`, `_process`, `_input` (fängt die Taste beim Neubelegen ab), `_unhandled_input`. Alles andere ist privat.

State: `_glitch_timer`, `_glitch_left`, `_starting`. `_starting` blockiert einen zweiten Start. Die Buttons werden dabei `PROCESS_MODE_DISABLED`.

Optionen: `_draft` ist eine Kopie von `Settings.get_values()`, die die Bedienelemente ändern. *Übernehmen* ruft `Settings.apply_values(_draft)` auf, *Standard* lädt `Settings.get_defaults()` in `_draft`, *Zurück* verwirft (mit einmaliger Warnung, `_confirm_discard`). `_rebinding_action` ist die Aktion, die gerade auf eine Taste wartet; ist die neue Taste schon vergeben, tauschen die beiden Aktionen ihre Tasten.

### `scenes/main/main.gd`

- `extends Node3D`, kein `class_name`
- Keine Exports, keine Signale, keine Node-Pfade
- Einzige Methode: `_unhandled_input` für F11 → `Settings.toggle_fullscreen()`
- Kennt den Player nicht

### `scenes/player/player.gd`

- `class_name Player`
- `extends CharacterBody3D`

| Gruppe | Variable | Default |
|---|---|---|
| Bewegung | `walk_speed` | `5.0` |
| Bewegung | `sprint_speed` | `8.0` |
| Bewegung | `jump_velocity` | `4.5` |
| Bewegung | `acceleration` | `12.0` |
| Bewegung | `air_control` | `0.3`, Range 0–1 |
| Kamera | `mouse_sensitivity` | `0.002` |
| Kamera | `max_pitch_degrees` | `85.0`, Range 0–89 |
| Respawn | `respawn_height` | `-30.0` |

Keine davon ist in der `.tscn` überschrieben.

| Mitglied | Rolle |
|---|---|
| `respawn()` | Setzt `global_transform` auf den in `_ready` gemerkten Start und `velocity` auf null |
| `gravity` | Einmal aus den ProjectSettings gelesen |
| `head`, `camera` | `@onready` auf `$Head` und `$Head/Camera3D` |
| `_spawn_transform` | privat, kein Marker in der Szene |

Keine `signal`-Deklaration. Yaw dreht den Body, Pitch nur `Head`. Wirksame Empfindlichkeit ist `mouse_sensitivity * Settings.mouse_sensitivity`; `Settings.invert_y` dreht die Pitch-Richtung um. Unter `respawn_height` ruft `_physics_process` `respawn()` auf. Bewegung: `Input.get_vector("move_left", "move_right", "move_forward", "move_back")`, in `transform.basis` gedreht, horizontal per `lerpf`. In der Luft ist die Beschleunigung `acceleration * air_control`.

---

## 6. 🔌 Abhängigkeiten

```text
project.godot
  main_scene ──► scenes/menu/main_menu.tscn
                    ├── main_menu.gd
                    │     ├── Autoload Settings
                    │     ├── $Overlay, $Fade, %Buttons
                    │     └── Start ──► scenes/main/main.tscn
                    ├── menu_background.gdshader
                    └── crt_overlay.gdshader
  main.tscn
    ├── main.gd ── Autoload Settings   (nur F11)
    └── instance scenes/player/player.tscn
          └── player.gd
                ├── Input Map: move_*, jump, sprint, ui_cancel
                ├── ProjectSettings: physics/3d/default_gravity
                ├── Autoload Settings: mouse_sensitivity, invert_y
                └── $Head, $Head/Camera3D
```

---

## 7. 🚫 Nicht vorhanden

- Ordner `scenes/interactive/` und Szene `interactive_box.tscn`
- Weitere Autoloads außer `Settings`; eigene Signale außer `Settings.changed`
- Pause-Menü, Spielziel, Gegner, Items, Rückweg ins Hauptmenü
- Gamepad-Events an `move_*`, `jump`, `sprint` (auch das Neubelegen im Menü kennt nur Tastatur)
- Dateien unter `assets/` außer `.gitkeep`
- Audio, das die gespeicherte Lautstärke hörbar machen würde

---

## 8. 📝 Arbeitslog

**Regel für alle (Menschen und KIs):** Nach jedem Arbeitsgang hier unten einen Eintrag anhängen, bevor committet wird. Ältere Einträge nicht ändern, nur neue anhängen (neuester unten). Die Abschnitte 1–7 oben beschreiben den Ist-Stand und werden bei Änderungen mit aktualisiert.

Vorlage:

```text
### JJJJ-MM-TT · Kurztitel · wer (Mensch / KI) · PR oder Commit
- Was: …
- Dateien: …
- Wichtig für die Nächsten: …
```

### 2026-10-25 · Grundgerüst · Claude (für Arschi) · PR #1
- Was: Godot-4-3D-Basis angelegt. Hauptszene mit Himmel, Sonne, CSG-Testlevel; First-Person-Spieler (Laufen, Sprint, Sprung, Maus-Kamera, Respawn); Input Map `move_*`, `jump`, `sprint`; Physik-Layer `world`/`player`; F11 = Vollbild.
- Dateien: `project.godot`, `scenes/main/*`, `scenes/player/*`, `assets/*/.gitkeep`, `README.md`, `.gitignore`, `.gitattributes`.
- Wichtig: Konvention „Szene + Skript im eigenen Ordner unter `scenes/<name>/`“, `.uid`/`.import` gehören ins Repo.

### 2026-10-25 · AI_HANDOVER angelegt · EnScapeZ · Commit 482c15e
- Was: Erste Fassung dieser Datei. `project.godot` mit Godot 4.7 geöffnet (Feature-Tag `4.7`, `[animation]`-Kompatibilitätseintrag). Hilfsskript `git pull.bat` (später von Arschi wieder gelöscht, b6335b3).

### 2026-10-25 · Cyberpunk-Hauptmenü · Claude (für Arschi) · PR #2
- Was: Hauptmenü als neue Startszene. Neon-Skyline-Shader mit bewegtem Gitter, CRT-Overlay (Scanlines, Farbverschiebung, Glitch), Titel „NEON//GRID“, Knöpfe Start / Optionen / Beenden. Start blendet mit Glitch in `scenes/main/main.tscn` über. Optionen damals: Vollbild, VSync, Lautstärke in `user://settings.cfg`.
- Dateien: `scenes/menu/*` (neu), `project.godot` (`run/main_scene`), `README.md`.
- Wichtig: Theme steckt als Sub-Resource in `main_menu.tscn`. Kein Rückweg vom Spiel ins Menü.

### 2026-10-25 · GameSettings-Helfer + AI_HANDOVER-Update · EnScapeZ · Commit dcb2c84
- Was: `scripts/game_settings.gd` (`class_name GameSettings`, statisch) für `settings.cfg`; F11 in der Spielwelt speichert Vollbild sofort. AI_HANDOVER auf den Menü-Stand gebracht.
- Hinweis: Dieser Helfer wurde in PR #3 vom Autoload `Settings` abgelöst (siehe nächster Eintrag).

### 2026-10-25 · Steuerungs-Optionen + Übernehmen · Claude (für Arschi) · PR #3
- Was: Neuer Autoload `Settings` (`autoload/settings.gd`) als einzige Stelle für Einstellungen (laden, anwenden, speichern). Optionsmenü mit Reitern „Anzeige & Audio“ und „Steuerung“: Mausempfindlichkeit, Maus-Y invertieren, Tastenbelegung (Tausch bei Doppelbelegung). Änderungen gelten erst nach „Übernehmen“; „Standard“ setzt zurück; „Zurück“ warnt einmal bei offenen Änderungen. `player.gd` liest Empfindlichkeit und Invertierung aus `Settings`.
- Zusammenführung: `scripts/game_settings.gd` von EnScapeZ ist im Autoload aufgegangen und wurde gelöscht. Gleiche Datei und Schlüssel, F11 speichert weiterhin sofort (`Settings.toggle_fullscreen()`), alte `settings.cfg` wird weiter gelesen.
- Dateien: `autoload/settings.gd` (neu), `project.godot` (`[autoload]`), `scenes/menu/main_menu.gd/.tscn`, `scenes/main/main.gd`, `scenes/player/player.gd`, `README.md`, `AI_HANDOVER.md`.
- Wichtig: Neue belegbare Aktion = in `Settings.REBINDABLE_ACTIONS` eintragen. Kein eigenes `preload` für Einstellungen mehr, immer den Autoload `Settings` benutzen.

### 2026-10-25 · Arbeitslog eingeführt · Claude (für Arschi) · PR #4
- Was: Abschnitt 8 „Arbeitslog“ mit Regel und Vorlage angelegt und die bisherigen Arbeitsgänge rückwirkend eingetragen.
- Dateien: `AI_HANDOVER.md`.
