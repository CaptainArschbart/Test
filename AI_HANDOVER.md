# 🤖 Project AI Handover Log

> **Engine:** Godot 4.4 (Feature-Tag `4.4`, Renderer Forward Plus)  
> **Projekt-Typ:** 3D Game (Grundgerüst, kein fertiges Spiel)  
> **Projektname:** Godot 3D Base  
> **Letztes Update:** 2026-10-25  
> **Startszene:** `res://scenes/menu/main_menu.tscn` (Hauptmenü) → Spielwelt `res://scenes/main/main.tscn`  
> **Sprache:** GDScript (Standard-Godot, nicht .NET / C#)

Dieses Dokument ist der Ist-Stand des Repos. Es beschreibt nur, was in `project.godot`, den Szenen und den Skripten tatsächlich steht.

---

## 1. 📁 Ordner- & Datei-Struktur

```text
project.godot
icon.svg
icon.svg.import
README.md
.gitignore
.gitattributes
assets/
  audio/.gitkeep          (leer, Platzhalter)
  materials/.gitkeep      (leer, Platzhalter)
  models/.gitkeep         (leer, Platzhalter)
  textures/.gitkeep       (leer, Platzhalter)
scenes/
  main/
    main.tscn             Hauptszene: Welt, Licht, Test-Level, Player-Instanz
    main.gd               uid://npu706i2yy2e
    main.gd.uid
  player/
    player.tscn           CharacterBody3D, First Person
    player.gd             class_name Player, uid://3ek5xjcrt0uw
    player.gd.uid
```

Es gibt keine weiteren `.gd`-, `.tscn`- oder `.tres`-Dateien. Keine UI-Szene, keine Gegner, keine Items, keine geladenen Modelle, Texturen oder Audio-Dateien. `.godot/` ist per `.gitignore` ausgeschlossen und gehört nicht zum Projektinhalt.

Konvention aus `README.md`: eine Szene und ihr Skript liegen im selben Ordner unter `scenes/<name>/`. Neue Systeme (Gegner, Items, UI) bekommen einen eigenen Ordner dort. `.uid`- und `.import`-Dateien gehören ins Repo.

---

## 2. ⚙️ project.godot

| Bereich | Wert |
|---|---|
| `config/name` | `Godot 3D Base` |
| `config/description` | Grundgerüst für ein 3D-Spiel in Godot 4 (GDScript). |
| `run/main_scene` | `res://scenes/menu/main_menu.tscn` |
| `config/features` | `4.4`, `Forward Plus` |
| `config/icon` | `res://icon.svg` |
| Viewport | 1280 × 720 |
| MSAA 3D | `2` → 4× MSAA |
| Autoloads | `Settings` → `res://autoload/settings.gd` (siehe Abschnitt 7) |
| Gruppen | keine definiert |
| Shader / Renderer-Overrides | keine außer MSAA |

### Input Map

Alle Aktionen haben `deadzone` 0.2 und genau ein Tastatur-Event (`physical_keycode`). Keine Maus-, Gamepad- oder Zweitbelegung.

| Aktion | Taste | physical_keycode |
|---|---|---|
| `move_forward` | W | 87 |
| `move_back` | S | 83 |
| `move_left` | A | 65 |
| `move_right` | D | 68 |
| `jump` | Leertaste | 32 |
| `sprint` | Shift | 4194325 (`KEY_SHIFT`) |

Zusätzlich hart im Code, nicht in der Input Map:

| Taste | Ort | Wirkung |
|---|---|---|
| Esc (`ui_cancel`, Godot-Default) | `player.gd` | Maus sichtbar machen |
| Linksklick (`InputEventMouseButton`) | `player.gd` | Maus wieder einfangen |
| F11 (`KEY_F11`) | `main.gd`, `main_menu.gd` | Fenster ↔ Vollbild über `Settings.toggle_fullscreen()` |

### Physik-Layer (3D)

| Layer-Bit | Name | Verwendung im Projekt |
|---|---|---|
| 1 | `world` | Default-Layer der CSG-Körper (`use_collision = true`, Layer nicht überschrieben) |
| 2 | `player` | `Player.collision_layer = 2` |

`Player.collision_mask` ist in der Szene nicht gesetzt und bleibt damit auf dem Godot-Default `1` (nur `world`). Der Spieler kollidiert nicht mit anderen Objekten auf Layer 2.

Schwerkraft wird nicht in `project.godot` überschrieben. `Player.gravity` liest `physics/3d/default_gravity` (Godot-Default 9.8).

---

## 3. 🎬 Szenen-Hierarchie

Es gibt zwei Szenen. `Main` instanziiert `Player` als Kind. Der Player hat in `main.tscn` keinen eigenen Transform und startet daher im Ursprung.

### `scenes/main/main.tscn` — Wurzel `Main` (`Node3D`, Skript `main.gd`)

```text
Main (Node3D)                          script: main.gd
├── WorldEnvironment                   Environment: Sky, ACES, SSAO, Glow
├── Sun (DirectionalLight3D)           Schatten an, shadow max distance 80
├── Level (Node3D)
│   ├── Ground (CSGBox3D)              100×1×100, Position (0, -0.5, 0), Kollision
│   ├── BoxSmall (CSGBox3D)            Default-Größe 2×2×2, Position (4, 0.5, -6)
│   ├── BoxLarge (CSGBox3D)            4×2×4, Position (-5, 1, -10)
│   └── Ramp (CSGBox3D)                3×0.3×8, ~20° um X, Position (8, 0.6, 2)
└── Player (Instanz player.tscn)       Position (0, 0, 0)
```

Environment-Subressourcen (nur in der Szene, keine `.tres`-Datei):

- `ProceduralSkyMaterial` → `Sky` → `Environment`
- `background_mode = 2` (Sky), `ambient_light_source = 3` (Sky), `reflected_light_source = 2` (Sky)
- `tonemap_mode = 2` (ACES), `ssao_enabled = true`, `glow_enabled = true`
- Materialien: Boden `Color(0.32, 0.45, 0.3)`, Kisten `Color(0.55, 0.6, 0.68)`, Rampe `Color(0.7, 0.62, 0.45)`

CSG ist bewusst Platzhalter-Geometrie. `README.md` sagt, sie später durch echte Modelle zu ersetzen. Alle vier CSG-Knoten haben `use_collision = true`.

### `scenes/player/player.tscn` — Wurzel `Player` (`CharacterBody3D`, Skript `player.gd`, `class_name Player`)

```text
Player (CharacterBody3D)               collision_layer = 2, collision_mask = 1 (Default)
├── CollisionShape3D                   CapsuleShape3D, radius 0.4, height 1.8, Offset Y 0.9
├── Body (MeshInstance3D)              CapsuleMesh, gleiche Maße, Schatten an, Offset Y 0.9
└── Head (Node3D)                      Offset Y 1.6
    └── Camera3D                       current = true, fov = 80
```

Körperfarbe `Color(0.85, 0.45, 0.2)`. Kapsel und Kollision sind 1.8 m hoch und sitzen mit dem Boden bei Y = 0, wenn der Player bei Y = 0 steht. Die Kamera sitzt bei lokaler Höhe 1.6.

Kein Knoten trägt `unique_name_in_owner`. Es gibt keine `%NodeName`-Zugriffe.

---

## 4. 📜 Skripte

### `scenes/main/main.gd`

- `extends Node3D`
- Kein `class_name`
- Keine `@export`-Variablen
- Keine `signal`-Deklarationen
- Keine `@onready`-Referenzen
- Keine Node-Pfade (`$` oder `%`)
- Einzige Methode: `_unhandled_input` (Engine-Callback, nicht als API gedacht)

State: keiner. F11 schaltet `DisplayServer.window_get_mode()` zwischen `WINDOW_MODE_FULLSCREEN` und `WINDOW_MODE_WINDOWED`. Echo-Events werden ignoriert.

### `scenes/player/player.gd`

- `class_name Player`
- `extends CharacterBody3D`
- Globale Klasse. Andere Skripte können den Typ `Player` ohne `preload` verwenden, sobald Godot die Klasse registriert hat.

#### Exportierte Variablen (Inspector-Gruppen)

| Gruppe | Variable | Default | Hinweis |
|---|---|---|---|
| Bewegung | `walk_speed` | `5.0` | m/s am Boden ohne Sprint |
| Bewegung | `sprint_speed` | `8.0` | aktiv bei gehaltener Aktion `sprint` |
| Bewegung | `jump_velocity` | `4.5` | nur wenn `is_on_floor()` |
| Bewegung | `acceleration` | `12.0` | Lerp-Gewicht `min(accel * delta, 1)` |
| Bewegung | `air_control` | `0.3` | `@export_range(0.0, 1.0)`. In der Luft wird `acceleration` damit multipliziert |
| Kamera | `mouse_sensitivity` | `0.002` | Radiant-Faktor auf `event.relative` |
| Kamera | `max_pitch_degrees` | `85.0` | `@export_range(0.0, 89.0)`, klemmt `Head.rotation.x` |
| Respawn | `respawn_height` | `-30.0` | Welt-Y, unter der `respawn()` läuft |

Keine dieser Variablen ist in der `.tscn` überschrieben. Die Defaults im Skript gelten.

#### Signale

Keine. Weder `signal` noch `emit` noch Verbindungen in den Szenen.

#### Öffentliche Mitglieder und State

| Mitglied | Sichtbarkeit | Rolle |
|---|---|---|
| `respawn()` | öffentlich, dokumentiert | Setzt `global_transform` auf den Start-Transform und `velocity` auf `Vector3.ZERO` |
| `gravity` | öffentlich, kein `@export` | Einmal beim Laden aus `ProjectSettings` gelesen, nicht pro Frame |
| `head` | öffentlich, `@onready` | `Node3D`, Pfad `$Head` |
| `camera` | öffentlich, `@onready` | `Camera3D`, Pfad `$Head/Camera3D` |
| `_spawn_transform` | privat | In `_ready` aus `global_transform` gespeichert. Respawn kehrt hierhin zurück, nicht zu einem Marker in der Szene |

Engine-Callbacks, keine externe API: `_ready`, `_unhandled_input`, `_physics_process`.

#### Node-Pfade

| Zugriff | Art |
|---|---|
| `$Head` | relativer Pfad, direktes Kind |
| `$Head/Camera3D` | relativer Pfad, Enkel |
| `%…` | nicht verwendet |

`Head` und `Camera3D` umzubenennen oder zu verschachteln bricht die `@onready`-Zeilen.

#### Bewegungs-State (pro Physik-Frame)

1. Nicht auf dem Boden: `velocity.y -= gravity * delta`.
2. `jump` gerade gedrückt und auf dem Boden: `velocity.y = jump_velocity`.
3. Eingabe über `Input.get_vector("move_left", "move_right", "move_forward", "move_back")`, in den lokalen Basis-Raum gedreht (`transform.basis`). Y der Bewegung bleibt unberührt, damit Schwerkraft und Sprung erhalten bleiben.
4. Zieltempo ist `sprint_speed` oder `walk_speed`. Horizontale Geschwindigkeit wird mit `lerpf` angenähert. In der Luft ist die Annäherung `acceleration * air_control`.
5. `move_and_slide()`.
6. `global_position.y < respawn_height` ruft `respawn()` auf.

Maus-State:

- `_ready` setzt `Input.MOUSE_MODE_CAPTURED`.
- Yaw dreht den `CharacterBody3D` (`rotate_y`). Pitch dreht nur `Head` und wird auf ±`max_pitch_degrees` geklemmt.
- Look nur bei `MOUSE_MODE_CAPTURED`.
- `ui_cancel` (Esc) macht die Maus sichtbar. Jeder gedrückte Mausbutton fängt sie wieder ein.

Es gibt keine Animation, keine Health-, Inventar- oder Interaktions-Logik und keinen separaten State-Enum.

---

## 5. 🔌 Abhängigkeiten zwischen den Teilen

```text
project.godot
  main_scene ──► scenes/main/main.tscn
                      ├── main.gd          (nur F11, kennt den Player nicht)
                      └── instance ──► scenes/player/player.tscn
                                           └── player.gd
                                                 ├── Input Map: move_*, jump, sprint, ui_cancel
                                                 ├── ProjectSettings: physics/3d/default_gravity
                                                 └── Nodes: $Head, $Head/Camera3D
```

`main.gd` hält keine Referenz auf `Player`. Der Player findet seinen Spawn selbst über den eigenen `global_transform` in `_ready`. Ein später gesetzter Transform am instanzierten Player in `main.tscn` wäre damit der Respawn-Punkt, solange er vor `_ready` steht.

---

## 6. 🚫 Bewusst nicht vorhanden

Für das nächste KI-System: diese Dinge nicht als vorhanden annehmen und nicht „reparieren“, ohne dass es ausdrücklich gewünscht ist.

- Nur ein Autoload (`Settings`), sonst keine Singletons
- Keine eigenen Signale und keine Signal-Verbindungen
- Keine Gruppen
- UI nur im Hauptmenü (`scenes/menu/`), kein HUD im Spiel
- Keine Ressourcen unter `assets/` (nur `.gitkeep`)
- Keine externen Modelle; Level ist CSG
- Kein Pause-Menü, kein Spielzustand, kein Speicherstand
- Keine zweiten Kameras, kein Third-Person-Rig
- Input Map ohne Gamepad
- Physik-Layer 3–32 sind unbenannt und unbenutzt

---

## 7. 🖥️ Hauptmenü & Settings

Hinweis: Die Abschnitte 1–6 beschreiben das Grundgerüst. Seitdem dazugekommen:

```text
autoload/
  settings.gd             Autoload "Settings"
scenes/menu/
  main_menu.tscn          Startszene (Control), Theme als Sub-Resource in der Szene
  main_menu.gd            Menülogik, Optionen, Tastenbelegung
  menu_background.gdshader  Skyline + Neon-Gitter (canvas_item)
  crt_overlay.gdshader    Scanlines, Farbverschiebung, Glitch (liest Screen-Texture)
```

### `autoload/settings.gd` (Autoload `Settings`)

- Felder: `fullscreen`, `vsync`, `master_volume` (0–100), `mouse_sensitivity` (Faktor, 1.0 = Standard), `invert_y`, `key_bindings` (Aktion → `physical_keycode`).
- `REBINDABLE_ACTIONS`: die im Menü belegbaren Aktionen mit Anzeigenamen. Neue Aktion belegbar machen = hier eintragen.
- Speichert in `user://settings.cfg` (Sektionen `video`, `audio`, `controls`, `keys`). Lädt und wendet beim Spielstart an; Tastenbelegung ersetzt die Events der Aktion in der `InputMap` (genau ein Tastatur-Event pro Aktion).
- API: `get_values()`, `get_defaults()`, `apply_values(dict)` (anwenden + speichern), `toggle_fullscreen()`, `key_name(code)`. Signal `changed` nach jedem Anwenden.
- `player.gd` nutzt `mouse_sensitivity * Settings.mouse_sensitivity` und `Settings.invert_y`.

### Optionsmenü (`main_menu.gd`)

- Bearbeitet eine Kopie (`_draft`) der Settings. Erst **Übernehmen** ruft `Settings.apply_values()` auf. **Standard** lädt `get_defaults()` in die Kopie. **Zurück**/Esc mit offenen Änderungen warnt einmal, beim zweiten Mal wird verworfen.
- Tastenbelegung: Knopf anklicken, nächste Taste wird in `_input` abgefangen; Esc bricht ab. Ist die Taste schon vergeben, tauschen die beiden Aktionen.
- Reiter (`TabContainer`): „ANZEIGE & AUDIO“ und „STEUERUNG“. Die Tastenknöpfe werden im Code in `KeyGrid` erzeugt.
