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
git pull.bat                  lokales `git pull`, kein Spielcode
scripts/
  game_settings.gd            class_name GameSettings, user://settings.cfg
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

`.godot/` ist per `.gitignore` ausgeschlossen. Keine `.tres`-Dateien, keine Export-Presets, keine Autoloads, keine Audio-Dateien.

Konvention aus `README.md`: eine Szene und ihr Skript liegen im selben Ordner unter `scenes/<name>/`. `scripts/game_settings.gd` ist die Ausnahme, weil Menü und Spielwelt dieselbe Datei lesen.

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
| Autoloads | keine |
| `[animation]` | `compatibility/default_parent_skeleton_in_mesh_instance_3d=true` |

### Input Map (nur diese sechs Aktionen sind im Projekt definiert)

Alle haben `deadzone` 0.2 und genau ein Tastatur-Event (`physical_keycode`). Keine Maus- und keine Joypad-Events.

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
| F11 (`KEY_F11`) | `main_menu.gd` | Kippt `FullscreenCheck`. Das `toggled`-Signal schaltet das Fenster und schreibt `[video] fullscreen` sofort. |
| F11 (`KEY_F11`) | `main.gd` | Schaltet Fenster ↔ `WINDOW_MODE_FULLSCREEN` und schreibt `[video] fullscreen` sofort. VSync und Lautstärke bleiben in der Datei. |
| Esc | Menü | Nur wenn das Options-Panel sichtbar ist: `ui_cancel` schließt die Optionen und speichert. Sonst keine Wirkung. |
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

Geschrieben von `scripts/game_settings.gd` (`class_name GameSettings`). Kein Autoload. Menü und Spielwelt laden das Skript per `preload`.

| Schlüssel | Default, wenn der Schlüssel fehlt | Wann geschrieben |
|---|---|---|
| `[video] fullscreen` | aktueller Fenstermodus ist bereits Vollbild | Sofort bei jedem Vollbild-Umschalten (Checkbox, F11 im Menü, F11 in der Spielwelt). Beim Öffnen des Menüs wird der gelesene Wert angewendet und dabei erneut geschrieben. |
| `[video] vsync` | `true` | Nur in `save_preferences`, aufgerufen wenn die Optionen mit Zurück oder Esc verlassen werden. |
| `[audio] master_volume` | `80.0` | Ebenfalls nur beim Verlassen der Optionen. |

`set_fullscreen` und `save_preferences` laden die Datei zuerst und ersetzen sie nicht leer. Ein F11 in der Spielwelt löscht Lautstärke und VSync nicht. Fehlt die Datei, liefert `ConfigFile.load` einen Fehler und die Defaults gelten. Lautstärke setzt den Bus `Master` (`linear_to_db(value / 100)`, stumm bei `<= 0`). Unter `assets/audio/` liegt keine Datei, und keine Szene spielt einen Ton ab.

---

## 3. 🎬 Ablauf (Einbahnstraße)

```text
F5
 └─ main_menu.tscn
      Maus sichtbar, Start hat Fokus, settings.cfg wird gelesen und angewendet
      Start
        ├─ Glitch-Stärke 1.0 für 0,5 s (CRT-Shader-Uniform "glitch")
        ├─ Fade (ColorRect $Fade) Alpha 0 → 1 in 0,45 s
        └─ get_tree().change_scene_to_file(game_scene)
             Default: res://scenes/main/main.tscn
              └─ Player._ready setzt MOUSE_MODE_CAPTURED
                   Esc gibt die Maus frei, Klick fängt sie wieder
                   kein Button, kein Pause-Menü, kein change_scene zurück
```

`game_scene` ist `@export_file` am Menü und in der Szene nicht überschrieben. Der Szenenwechsel ersetzt den ganzen Baum. Vollbild, VSync und Bus-Lautstärke bleiben, weil sie an `DisplayServer` und `AudioServer` hängen, nicht am Menü-Knoten.

Es gibt keinen Rückweg ins Menü.

---

## 4. Szenen-Hierarchie

### `scenes/menu/main_menu.tscn` — Wurzel `MainMenu` (`Control`, Skript `main_menu.gd`)

```text
MainMenu (Control)                     theme: cyber, script main_menu.gd
├── Background (ColorRect)             Shader menu_background.gdshader
├── Margin (MarginContainer)
│   └── Layout (VBoxContainer)
│       ├── TitleBox
│       │   ├── %TitleCyan             "NEON//GRID"
│       │   ├── %TitleMagenta          "NEON//GRID"
│       │   └── %Title                 "NEON//GRID"
│       ├── %Subtitle                  "// SYSTEM ONLINE_"
│       ├── Spacer
│       ├── %MainButtons (VBoxContainer)
│       │   ├── %StartButton           "START"
│       │   ├── %OptionsButton         "OPTIONEN"
│       │   └── %QuitButton            "BEENDEN"
│       ├── %OptionsPanel              anfangs visible = false
│       │   └── Options
│       │       ├── Header             "> OPTIONEN"
│       │       ├── %FullscreenCheck
│       │       ├── %VsyncCheck
│       │       ├── VolumeRow
│       │       │   ├── VolumeLabel
│       │       │   ├── %VolumeSlider  step 5, value 80
│       │       │   └── %VolumeValue
│       │       └── %BackButton        "ZURÜCK"
│       └── Footer
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

### `scripts/game_settings.gd`

- `class_name GameSettings`
- `extends RefCounted`
- Kein Node, keine Szene, kein Autoload
- Öffentliche statische Methoden: `get_fullscreen`, `get_vsync`, `get_master_volume`, `set_fullscreen`, `save_preferences`
- Konstante `PATH := "user://settings.cfg"`
- Keine Signale, keine `@export`

### `scenes/menu/main_menu.gd`

- `extends Control`, kein `class_name`
- Keine eigenen `signal`-Deklarationen. Verbindungen laufen auf Button- und Slider-Signale.

| Export | Default |
|---|---|
| `game_scene` | `res://scenes/main/main.tscn` |
| `glitch_interval_min` | `1.5` |
| `glitch_interval_max` | `4.5` |
| `glitch_duration` | `0.18` |

Öffentliche Engine-Callbacks: `_ready`, `_process`, `_unhandled_input`. Der Rest ist privat (`_on_start_pressed`, `_show_options`, `_hide_options`, `_on_fullscreen_toggled`, `_on_vsync_toggled`, `_on_volume_changed`, `_load_settings`, `_save_settings`, `_trigger_glitch`, `_schedule_glitch`).

State: `_glitch_timer`, `_glitch_left`, `_starting`. `_starting` blockiert einen zweiten Start. Die Buttons werden dabei `PROCESS_MODE_DISABLED`.

### `scenes/main/main.gd`

- `extends Node3D`, kein `class_name`
- Keine Exports, keine Signale, keine Node-Pfade
- Einzige Methode: `_unhandled_input` für F11 plus `Settings.set_fullscreen`
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

Keine `signal`-Deklaration. Yaw dreht den Body, Pitch nur `Head`. Unter `respawn_height` ruft `_physics_process` `respawn()` auf. Bewegung: `Input.get_vector("move_left", "move_right", "move_forward", "move_back")`, in `transform.basis` gedreht, horizontal per `lerpf`. In der Luft ist die Beschleunigung `acceleration * air_control`.

---

## 6. 🔌 Abhängigkeiten

```text
project.godot
  main_scene ──► scenes/menu/main_menu.tscn
                    ├── main_menu.gd
                    │     ├── preload scripts/game_settings.gd
                    │     ├── $Overlay, $Fade, %Buttons
                    │     └── Start ──► scenes/main/main.tscn
                    ├── menu_background.gdshader
                    └── crt_overlay.gdshader
  main.tscn
    ├── main.gd ── preload scripts/game_settings.gd   (nur F11)
    └── instance scenes/player/player.tscn
          └── player.gd
                ├── Input Map: move_*, jump, sprint, ui_cancel
                ├── ProjectSettings: physics/3d/default_gravity
                └── $Head, $Head/Camera3D
```

---

## 7. 🚫 Nicht vorhanden

- Ordner `scenes/interactive/` und Szene `interactive_box.tscn`
- Autoloads und eigene Signale
- Pause-Menü, Spielziel, Gegner, Items, Rückweg ins Hauptmenü
- Gamepad-Events an `move_*`, `jump`, `sprint`
- Dateien unter `assets/` außer `.gitkeep`
- Audio, das die gespeicherte Lautstärke hörbar machen würde
