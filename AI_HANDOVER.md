# 🤖 Project AI Handover Log

> **Engine:** Godot 4.7 (Feature-Tag `4.7`, Renderer Forward Plus). Getestet mit 4.7.2 stable.  
> **Projekt-Typ:** 3D Game (Grundgerüst: Cyberpunk-Hauptmenü, First-Person-Testwelt, Pausemenü, gemeinsame Optionen)  
> **Projektname:** Godot 3D Base  
> **Letztes Update:** 2026-10-25 (Eintrag 9: `origin/main` gemergt, Konflikte gelöst, Pausemenü auch in der Testmap)  
> **Hauptszene:** `res://scenes/menu/main_menu.tscn`  
> **Sprache:** GDScript (Standard-Godot, nicht .NET / C#)

Dieses Dokument ist der Ist-Stand des Repos. Es beschreibt nur, was in `project.godot`, den Szenen und den Skripten steht. Abschnitt 9 sagt, was getestet wurde und was nicht. Abschnitt 10 ist das Test-Rezept. **Abschnitt 11 ist das Änderungsprotokoll**: was wann gemacht wurde, welche Datei wie geändert wurde und warum (neuester Eintrag zuerst). **Abschnitt 12 ist der kurze Arbeitslog** der anderen Beteiligten (neuester Eintrag unten).

**Pflege-Regel:** Wer hier etwas ändert, trägt es im selben Arbeitsgang ausführlich in Abschnitt 11 ein und zieht die Ist-Stand-Abschnitte nach. Die Regel steht in `.cursor/rules/ai-handover.mdc` (`alwaysApply: true`). Wie man Merge-Konflikte vermeidet und löst, steht in `.cursor/rules/00_conflict_prevention.mdc` (`alwaysApply: true`).

`scenes/interactive/interactive_box.tscn` ist **nicht** im Projekt. Es gibt keinen Ordner `scenes/interactive/`.

---

## 1. 📁 Ordner- & Datei-Struktur

```text
project.godot                 Hauptszene, Autoload, Input Map, Physik-Layer, 4× MSAA
default_bus_layout.tres       Audio-Busse Master (implizit), Music, SFX
icon.svg
icon.svg.import
README.md
.gitignore
.gitattributes
AI_HANDOVER.md
.cursor/
  rules/
    00_conflict_prevention.mdc  Regel (alwaysApply): Merge-Konflikte vermeiden und verlustfrei lösen
    ai-handover.mdc           Regel (alwaysApply): Handover immer ausführlich pflegen
autoload/
  settings.gd                 Autoload "Settings", user://settings.cfg
  settings.gd.uid
scenes/
  ui/
    cyber_theme.tres          gemeinsames Neon-Theme für Hauptmenü, Pausemenü und Optionen (noch ohne uid)
  options/
    options_menu.tscn         Optionen-Seite (VBoxContainer), von Haupt- und Pausemenü eingebunden
    options_menu.gd           (noch ohne .uid, siehe Abschnitt 9)
  menu/
    main_menu.tscn            Startszene, Control, bindet options_menu.tscn ein
    main_menu.gd              uid://b56yhlqq1bgvx
    main_menu.gd.uid
    menu_background.gdshader  uid://cw7ulhsglsebx
    menu_background.gdshader.uid
    crt_overlay.gdshader      uid://cveheluq50cmp
    crt_overlay.gdshader.uid
  main/
    main.tscn                 alte einfache Testwelt (nur noch per F6), enthält PauseMenu
    main.gd                   uid://npu706i2yy2e
    main.gd.uid
  testmap/
    testmap.tscn              Testmap "Neon District", wird von Start geladen, enthält PauseMenu
    testmap.gd                F11, sonst leer
    testmap.gd.uid
    building_facade.gdshader  Fassade mit Fensterraster in Weltkoordinaten
    building_facade.gdshader.uid
  pause/
    pause_menu.tscn           CanvasLayer, Pausemenü, bindet options_menu.tscn ein
    pause_menu.gd             (noch ohne .uid, siehe Abschnitt 9)
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

`.godot/` ist per `.gitignore` ausgeschlossen. Außer `default_bus_layout.tres` und `scenes/ui/cyber_theme.tres` gibt es keine `.tres`-Dateien, keine Export-Presets, keine Audio-Dateien. Einziger Autoload: `Settings`.

Konvention aus `README.md`: eine Szene und ihr Skript liegen im selben Ordner unter `scenes/<name>/`. `autoload/settings.gd` ist die Ausnahme (Autoload ohne eigene Szene), `scenes/ui/` hält nur das gemeinsame Theme. `default_bus_layout.tres` liegt im Projektstamm, weil Godot genau diesen Pfad als Standard für das Bus-Layout lädt (`audio/buses/default_bus_layout`, in `project.godot` nicht überschrieben).

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
| MSAA 3D (Projekt) | `2` → 4× MSAA. Zur Laufzeit überschreibt `Settings` den Wert am Root-Viewport. |
| Autoloads | `Settings` → `res://autoload/settings.gd` |
| `[animation]` | `compatibility/default_parent_skeleton_in_mesh_instance_3d=true` |

### Input Map (nur diese sechs Aktionen sind im Projekt definiert)

Alle haben `deadzone` 0.2 und genau ein Tastatur-Event (`physical_keycode`). Keine Maus- und keine Joypad-Events. Die Tabelle zeigt die Standardbelegung aus `project.godot`. Der Spieler kann alle sechs in den **Optionen** (Reiter Steuerung) neu belegen, im Hauptmenü ebenso wie im Pausemenü, denn beide zeigen dieselbe Szene. `Settings` ersetzt beim Start und nach *Übernehmen* das Tastatur-Event der Aktion in der `InputMap`.

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
| Esc (`ui_cancel`) | Spielwelt, Menü zu | `pause_menu.gd` öffnet das Pausemenü (siehe Abschnitt 5). Das Event wird als verarbeitet markiert. |
| Esc (`ui_cancel`) | Pausemenü, Optionen offen | Ruft `options.request_back()`, genau wie der Knopf *Zurück*: läuft eine Tastenbelegung, bricht Esc nur diese ab (`options_menu.gd` fängt die Taste in `_input`). Sonst bei offenen Änderungen erst Warnung, beim zweiten Mal verwerfen, sonst zurück zur Hauptseite. Das Spiel bleibt pausiert. |
| Esc (`ui_cancel`) | Pausemenü, Hauptseite | Fortsetzen (schließt, fängt die Maus ein). |
| Esc | Hauptmenü | Dasselbe `options.request_back()`, solange die Optionen offen sind. Sonst keine Wirkung. |
| F11 (`KEY_F11`) | `testmap.gd` und `main.gd` (Spiel läuft) | `Settings.toggle_fullscreen()`: schaltet das Fenster, `save_settings()` sofort. |
| F11 (`KEY_F11`) | `pause_menu.gd` (Menü offen) | Dasselbe. Nötig, weil `testmap.gd` und `main.gd` bei angehaltenem Baum keine Eingaben bekommen. |
| F11 (`KEY_F11`) | `main_menu.gd` | Dasselbe. |

Bei offenen Optionen zieht `options_menu.gd` die Vollbild-Checkbox und den Entwurf selbst nach, sobald `Settings.changed` kommt. Der Host muss dafür nichts tun.
| Mausklick | Spielwelt | `player.gd`: jeder gedrückte `InputEventMouseButton` setzt `MOUSE_MODE_CAPTURED`, falls die Maus frei war (z. B. nach Alt-Tab). Esc gibt die Maus im Player **nicht** mehr frei, das macht das Pausemenü. |

`ui_cancel` ist der Engine-Default (Esc, Joypad-B). Im Projekt nicht überschrieben.

### Controller und UI-Fokus

Die Spielaktionen haben keine Gamepad-Belegung. Laufen, Sprint und Sprung sind nur Tastatur.

Menüs (Haupt- und Pausemenü) definieren keine eigenen UI-Aktionen. Godots `ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_accept` und `ui_cancel` behalten die Engine-Defaults (Pfeiltasten, Enter, Esc, Stick, D-Pad, Joypad-Buttons). Das Pausemenü setzt beim Öffnen den Fokus auf *Fortsetzen*, in den Optionen auf die Tab-Leiste, nach *Zurück* auf *Optionen*. Damit sind beide Menüs mit Tastatur und Controller-Fokus bedienbar, die Spielwelt nicht.

`Beenden` bzw. `Spiel beenden` wird in beiden Menüs ausgeblendet, wenn `OS.has_feature("web")`. Es gibt keinen Web-Export-Preset im Repo.

### Physik-Layer (3D)

| Layer-Bit | Name | Verwendung |
|---|---|---|
| 1 | `world` | Default der CSG-Körper (`use_collision = true`, Layer nicht gesetzt) |
| 2 | `player` | `Player.collision_layer = 2` |

`Player.collision_mask` ist nicht gesetzt und bleibt auf dem Godot-Default `1` (nur `world`). Layer 3–32 sind unbenannt. Schwerkraft steht nicht in `project.godot`. `Player.gravity` liest `physics/3d/default_gravity` (Engine-Default 9.8).

---

## 3. 🔊 Audio-Busse und 🖥️ Grafik-Einstellungen

### Audio-Busse (`default_bus_layout.tres`)

| Index | Bus | Send | Start-dB | Steuerung |
|---|---|---|---|---|
| 0 | `Master` | Ausgabe | 0 | `Settings.master_volume` (Standard 80 %) |
| 1 | `Music` | `Master` | 0 | `Settings.music_volume` (Standard 100 %) |
| 2 | `SFX` | `Master` | 0 | `Settings.sfx_volume` (Standard 100 %) |

- Alle drei Regler gehen von 0 bis 100 %. Umrechnung in `Settings._apply_bus`: `linear_to_db(percent / 100)`. Bei 0 % wird der Bus auf −80 dB gesetzt und stumm geschaltet.
- `Settings._ensure_buses()` legt `Music` und `SFX` zur Laufzeit an (Send `Master`), falls das Layout fehlt oder sie nicht enthält. `_apply_bus` ignoriert unbekannte Busse.
- **Es gibt keine Audio-Dateien und keinen `AudioStreamPlayer`.** Die Busse sind vorbereitet. Ein späterer Player muss seine Eigenschaft `bus` auf `Music` bzw. `SFX` setzen, damit die Regler greifen.

### Grafik (angewendet in `Settings.apply()`)

| Einstellung | Feld | Wirkung | Wertebereich |
|---|---|---|---|
| Vollbild | `fullscreen` | `DisplayServer.window_set_mode(FULLSCREEN / WINDOWED)`, nur wenn sich der Zustand ändert | bool |
| VSync | `vsync` | `DisplayServer.window_set_vsync_mode(ENABLED / DISABLED)` | bool |
| Kantenglättung | `msaa` | `get_viewport().msaa_3d` am Root | `Viewport.MSAA`: 0 aus, 1 2×, 2 4× (Standard), 3 8× |
| 3D-Auflösung | `render_scale` | `get_viewport().scaling_3d_scale`, nur die 3D-Szene, UI bleibt scharf | 0.5 bis 1.0 (`Settings.RENDER_SCALE_MIN`), in den Optionen als 50–100 % in 5er-Schritten |

`apply()` fasst den Fenstermodus nur an, wenn Soll und Ist verschieden sind. Sonst würde jeder Slider-Schritt ein maximiertes Fenster in den Fenstermodus zurücksetzen.

### user://settings.cfg

Gelesen und geschrieben vom Autoload `Settings`. Er lädt die Datei in `_ready`, also vor jeder Szene, und wendet alles an. Auch ein direkter Start einer Spielszene (`testmap.tscn` oder `main.tscn`, F6) bekommt so die gespeicherten Werte. Fehlt die Datei, gelten die Standardwerte.

| Schlüssel | Standard | Wirkung |
|---|---|---|
| `[video] fullscreen` | `false` | Fenstermodus |
| `[video] vsync` | `true` | VSync |
| `[video] msaa` | `2` (4×) | wird beim Laden auf 0–3 begrenzt |
| `[video] render_scale` | `1.0` | wird beim Laden auf 0.5–1.0 begrenzt |
| `[audio] master_volume` | `80.0` | Bus `Master` |
| `[audio] music_volume` | `100.0` | Bus `Music`, begrenzt auf 0–100 |
| `[audio] sfx_volume` | `100.0` | Bus `SFX`, begrenzt auf 0–100 |
| `[controls] mouse_sensitivity` | `1.0` | Faktor auf `Player.mouse_sensitivity` |
| `[controls] invert_y` | `false` | dreht die Pitch-Richtung im Player um |
| `[keys] <aktion>` | Belegung aus `project.godot` | `physical_keycode` für `move_*`, `jump`, `sprint` |

`save_settings()` schreibt **immer alle** Schlüssel. Geschrieben wird:

| Auslöser | Wo |
|---|---|
| *Übernehmen* in den Optionen (Hauptmenü und Pausemenü, dieselbe Szene) | `Settings.apply_values()`: setzt alle Felder, `apply()`, `save_settings()` |
| F11 | `Settings.toggle_fullscreen()`: schaltet, `apply()`, `save_settings()` |

Die Optionen arbeiten in beiden Menüs mit einem **Entwurf**: Bis *Übernehmen* gedrückt wird, ändert sich nichts am Spiel, am `AudioServer`, am Viewport und an der Datei (keine Live-Vorschau). *Zurück* oder Esc mit offenem Entwurf fragt einmal nach, das zweite Mal verwirft. Nur F11 wirkt und speichert sofort.

---

## 4. 🎬 Ablauf

```text
F5
 └─ main_menu.tscn
      Maus sichtbar, Start hat Fokus (settings.cfg hat der Autoload schon angewendet)
      Start
        ├─ Glitch-Stärke 1.0 für 0,5 s (CRT-Shader-Uniform "glitch")
        ├─ Fade (ColorRect $Fade) Alpha 0 → 1 in 0,45 s  (schwarzer Bildschirm)
        └─ get_tree().change_scene_to_file(game_scene)
             Default: res://scenes/testmap/testmap.tscn
              └─ Player._ready setzt MOUSE_MODE_CAPTURED
                   Spiel läuft, Maus gefangen
                   │
                   Esc ──► Pausemenü
                   │         get_tree().paused = true, Maus sichtbar
                   │         ├─ Fortsetzen / Esc: paused = false, Maus gefangen
                   │         ├─ Optionen (dieselbe Szene wie im Hauptmenü): Grafik / Audio / Steuerung,
                   │         │     Entwurf, Wirkung erst nach ÜBERNEHMEN
                   │         ├─ Zurück zum Hauptmenü: paused = false,
                   │         │     change_scene_to_file(main_menu_scene) ──► main_menu.tscn
                   │         └─ Spiel beenden: get_tree().quit()
```

`game_scene` (Hauptmenü) und `main_menu_scene` (Pausemenü) sind `@export_file` und in den Szenen nicht überschrieben. Der Szenenwechsel ersetzt den ganzen Baum. Einstellungen bleiben, weil sie im Autoload `Settings` und an `DisplayServer`, `AudioServer`, `InputMap` und dem Root-Viewport hängen.

Der Weg zurück ins Hauptmenü existiert, aber nur über das Pausemenü. Ein Spielstand wird nicht gespeichert, beide Ausstiege fragen nicht nach. Die beiden Ausstiege liegen auf der Hauptseite des Pausemenüs. Dorthin kommt man aus den Optionen nur über *Zurück* oder Esc, bei offenem Entwurf also erst nach der Verwerfen-Warnung.

---

## 5. 🎬 Szenen-Hierarchie

### `scenes/menu/main_menu.tscn` — Wurzel `MainMenu` (`Control`, Skript `main_menu.gd`)

```text
MainMenu (Control)                     theme: scenes/ui/cyber_theme.tres, script main_menu.gd
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
├── %OptionsPanel (PanelContainer)     anfangs unsichtbar, mittig (780 breit); beim Öffnen werden %TitleBox und %Subtitle ausgeblendet
│   └── %Options                       Instanz von scenes/options/options_menu.tscn (siehe unten)
├── Fade (ColorRect)                   schwarz, Alpha 0, Pfad $Fade
└── Overlay (ColorRect)                Shader crt_overlay.gdshader, Pfad $Overlay
```

`%` bedeutet `unique_name_in_owner`. Relative Pfade im Skript: `$Overlay.material`, `$Fade`. Hintergrund-Shader zeichnet Himmel, zwei Skyline-Ebenen und ein Bodengitter. CRT-Shader zeichnet Scanlines, Farbverschiebung, Vignette, Rauschen und das Uniform `glitch` (0 ruhig, 1 stark).

Das Hauptmenü hat keine eigenen Options-Bedienelemente mehr. Alles, was früher unter `OptionsPanel/Options` hing (Reiter, Slider, Tastenbelegung, Übernehmen/Standard/Zurück), steckt in der gemeinsamen Szene. Das Hauptmenü verbindet nur `options.closed` (Titel und Knöpfe wieder zeigen) und `options.glitch_requested` (CRT-Glitch).

### `scenes/options/options_menu.tscn` — Wurzel `Options` (`VBoxContainer`, Skript `options_menu.gd`)

Die einzige Options-Oberfläche des Projekts. Hauptmenü (`%Options` unter `%OptionsPanel`) und Pausemenü (`%Options` unter `Pages`) binden dieselbe Szene ein. Die Szene hat kein eigenes Theme und erbt es vom Host. Beide Hosts benutzen `scenes/ui/cyber_theme.tres`.

```text
Options (VBoxContainer)                    separation 12
├── Header                                 "> OPTIONEN"
├── %Tabs (TabContainer, use_hidden_tabs_for_min_size = true)
│   ├── GRAFIK        %FullscreenCheck, %VsyncCheck,
│   │                 %MsaaOption (OptionButton: AUS, 2x, 4x, 8x; Item-ID = Viewport.MSAA),
│   │                 %RenderScaleSlider (50–100, Schritt 5) / %RenderScaleValue
│   ├── AUDIO         %MasterSlider / %MasterValue, %MusicSlider / %MusicValue,
│   │                 %SfxSlider / %SfxValue (je 0–100, Schritt 5)
│   └── STEUERUNG     %SensitivitySlider (0.1–3.0, Schritt 0.05) / %SensitivityValue,
│                     %InvertYCheck, KeyHint, %KeyGrid (4 Spalten, 6 Aktionen, Knöpfe im Code erzeugt)
├── ActionRow         %ApplyButton "ÜBERNEHMEN" (nur aktiv bei Änderungen),
│                     %DefaultsButton "STANDARD", %BackButton "ZURÜCK"
└── %StatusLabel
```

`use_hidden_tabs_for_min_size` hält den Rahmen bei allen Reitern gleich hoch. Folge: `TabContainer` misst auch die versteckten Reiter. Ein `Label` mit `autowrap_mode` meldet dort mangels Breite eine riesige Mindesthöhe und lässt das ganze Panel in die Höhe wachsen. Deshalb hat `KeyHint` **keinen** Zeilenumbruch. Wer einem Reiter ein umbrechendes Label gibt, muss ihm eine `custom_minimum_size.x` geben.

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
├── Player                             Instanz player.tscn, Transform nicht überschrieben
└── PauseMenu                          Instanz pause_menu.tscn, als letztes Kind
```

Environment: `background_mode = 2` (Sky), `ambient_light_source = 3` (Sky), `reflected_light_source = 2` (Sky), `tonemap_mode = 2` (ACES), SSAO und Glow an. Boden `Color(0.32, 0.45, 0.3)`, Kisten `Color(0.55, 0.6, 0.68)`, Rampe `Color(0.7, 0.62, 0.45)`. Alle vier CSG-Knoten haben `use_collision = true`. `BoxSmall` ragt mit der Default-Höhe in den Boden. CSG ist Platzhalter-Geometrie.

### `scenes/pause/pause_menu.tscn` — Wurzel `PauseMenu` (`CanvasLayer`, Skript `pause_menu.gd`)

Szene-Eigenschaften: `layer = 10`, `visible = false`, `process_mode = ALWAYS` (3). Kinder erben ALWAYS und laufen deshalb auch bei `get_tree().paused = true`. Das Theme ist `scenes/ui/cyber_theme.tres` (dasselbe wie im Hauptmenü), gesetzt an `Root`.

```text
PauseMenu (CanvasLayer)
└── Root (Control, Vollbild, theme = cyber_theme.tres)
    ├── Dim (ColorRect)                      abdunkeln, schluckt Mausklicks
    └── Center (CenterContainer)
        └── Panel (PanelContainer, min. 780 breit, wie das Optionen-Panel im Hauptmenü)
            └── Pages (VBoxContainer)
                ├── %MainPage (VBoxContainer)
                │   ├── Title "> PAUSE", Hint "// SPIEL ANGEHALTEN // ESC = FORTSETZEN // F11 = VOLLBILD"
                │   ├── %ResumeButton      "FORTSETZEN"
                │   ├── %OptionsButton     "OPTIONEN"
                │   ├── %MainMenuButton    "ZURÜCK ZUM HAUPTMENÜ"
                │   └── %QuitButton        "SPIEL BEENDEN"
                └── %Options (Instanz von scenes/options/options_menu.tscn, anfangs unsichtbar)
```

Die Optionen im Pausemenü sind genau die Szene aus dem Hauptmenü, kein eigener Nachbau.

### `scenes/testmap/testmap.tscn` — Wurzel `Testmap` (`Node3D`, Skript `testmap.gd`)

Nacht-Cyberpunk-Map, etwa x −53…53, z −89…51 (unsichtbare Wände unter `Bounds`). Alles ist CSG mit `use_collision = true` auf Layer 1 (`world`); reine Deko (Leuchtstreifen, Gitter, Schilder) hat keine Kollision. Spawn bei (0, 0, 42), Blick nach −Z.

```text
Testmap (Node3D)
├── WorldEnvironment        Nachthimmel, Ambient-Farbe, ACES, SSR, SSAO, Glow, Nebel
├── Moon (DirectionalLight3D)  schwach bläulich, Schatten an
├── Street                  Asphalt (ganze Map), Gehwege mit 0,2 m Bordstein, Laternen, Spawn-Ring
├── Buildings               Häuserzeilen, Kulisse rundum (Material Fassaden-Shader), Leuchtreklamen
├── ZoneWest                Treppen (Stufen 0,15/0,25/0,35/0,50 m), Rampen 15/30/40/50° (2,5 m hoch),
│                           Tunnel (Decke 2,6/1,95/1,7 m), Messwand 1–6 m
├── ZoneEast                Sprunghöhe 0,5–1,5 m, Weitsprung-Lücken 2–6 m, Parkour-Turm (je +0,9 m) auf Dach 7,2 m
├── Plaza                   offene Fläche z −30…−88, Leuchtgitter, Holo-Säule, Kisten, Mauern, Brücke 3,3 m
├── Pickups
│   └── SpawnPoints         16 Marker3D, Gruppe "item_spawn", je mit leuchtendem Pad (MeshInstance3D)
├── Bounds                  4 StaticBody3D-Wände, unsichtbar
├── Player                  Instanz player.tscn, Position (0, 0.05, 42)
└── PauseMenu               Instanz pause_menu.tscn, als letztes Kind (siehe Eintrag 9)
```

Zusätzlich `ZoneWest/Stairs_RampCollision`: Treppe 0,20 m, Stufen nur Optik, Kollision ist eine unsichtbare Rampe (`StaticBody3D`) über die Stufenkanten. So sind begehbare Treppen gedacht, solange der Player kein Stufensteigen kann.

Gemessen mit Godot 4.5 headless und den Standardwerten des Players: Sprung erreicht etwa 1,03 m (1,0-m-Block geht, 1,25 m nicht). Rampen bis 40° gehen, 50° nicht (`floor_max_angle` 45°). Weitsprung: gehend bis 4 m, mit Sprint 6 m. Tunnel 1,95 m passt, 1,7 m blockt. Parkour-Turm ist bis aufs Dach schaffbar. Die echten Treppen (0,15–0,50 m) gehen nur mit Springen, weil der Player kein Stufensteigen hat.

Die Szene wurde mit einem Python-Generator erzeugt, ist aber eine normale `.tscn` und darf im Editor bearbeitet werden. Der Generator liegt nicht im Repo.

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

## 6. 📜 Skripte

### `autoload/settings.gd` (Autoload `Settings`)

- `extends Node`, kein `class_name`. Der Autoload-Name ist `Settings`.
- Signal `changed`, wird am Ende jedes `apply()` gesendet.
- Konstanten: `PATH`, `MASTER_BUS`, `MUSIC_BUS`, `SFX_BUS`, `RENDER_SCALE_MIN`, `REBINDABLE_ACTIONS` (Aktion → Anzeigename in den Optionen).
- Felder: `fullscreen`, `vsync`, `msaa` (int), `render_scale`, `master_volume`, `music_volume`, `sfx_volume`, `mouse_sensitivity`, `invert_y`, `key_bindings` (Aktion → `physical_keycode`).
- Öffentlich: `get_values()`, `get_defaults()`, `apply_values(dict)` (übernehmen, anwenden, speichern; neuere Schlüssel mit `values.get(..., aktuell)`), `apply()`, `toggle_fullscreen()`, `key_name(code)` (statisch; im Headless-Modus ohne Layout-Abfrage, weil `keyboard_get_keycode_from_physical` dort einen Fehler meldet), `load_settings()`, `save_settings()`.
- Privat: `_apply_bus`, `_ensure_buses`, `_read_binding`.
- `_ready` legt fehlende Busse an, liest die Standard-Tastenbelegung aus der `InputMap`, lädt die Datei und wendet an.
- **Ein Änderungsweg für die Optionen:** Die gemeinsame Options-Szene bearbeitet eine Kopie (`get_values()`) und ruft bei *Übernehmen* `apply_values()`. Daneben gibt es nur F11 über `toggle_fullscreen()`. `apply()` kann jeder aufrufen, es ist idempotent.
- `changed` hört die Options-Szene ab, um die Vollbild-Checkbox bei F11 nachzuziehen.

### `scenes/pause/pause_menu.gd`

- `extends CanvasLayer`, kein `class_name`. Keine eigenen `signal`-Deklarationen.
- Export: `main_menu_scene` (`@export_file("*.tscn")`), Standard `res://scenes/menu/main_menu.tscn`.
- Öffentlich: `open()` und `close()`. `visible` ist der Offen-Zustand.
- `const OptionsMenu := preload("res://scenes/options/options_menu.gd")`, `@onready var options: OptionsMenu = %Options`. Das Skript hat bewusst kein `class_name`, damit auch headless Läufe ohne Editor-Cache funktionieren.
- `open()`: `get_tree().paused = true`, `Input.mouse_mode = VISIBLE`, Optionen verstecken, Hauptseite zeigen, Fokus auf *Fortsetzen*.
- `close()`: verstecken, `paused = false`, `Input.mouse_mode = CAPTURED`. Speichern ist nicht nötig, die Optionen speichern bei *Übernehmen* selbst.
- `_unhandled_input`: `ui_cancel` öffnet, ruft in den Optionen `options.request_back()` oder schließt. F11 nur bei offenem Menü. Beide Fälle rufen `set_input_as_handled()`.
- `_exit_tree`: war das Menü offen, wird `paused = false` gesetzt, damit die Pause nicht in die nächste Szene wandert.
- Die früheren eigenen Handler für Vollbild, VSync, MSAA, 3D-Auflösung, Master, Musik, SFX, Sensitivität und Y-Invertierung sowie `_refresh()` sind entfernt. Das macht jetzt `options_menu.gd`.
- Menü-Knöpfe: *Fortsetzen* → `close`, *Optionen* → `_show_options` (Hauptseite aus, `options.open()`), *Zurück zum Hauptmenü* → `_on_main_menu_pressed` (`paused = false`, `change_scene_to_file`), *Spiel beenden* → `_on_quit_pressed` (`quit`). `options.closed` ist mit `_show_main_page` verbunden (Hauptseite zeigen, Fokus auf *Optionen*).
- Das Menü ist **kein** Autoload. Es existiert nur als Instanz in den Spielszenen `testmap.tscn` (wird von *Start* geladen) und `main.tscn`. Jede neue Spielszene muss `pause_menu.tscn` selbst einbinden, sonst tut Esc dort nichts. (Genau das fehlte nach dem Merge in `testmap.tscn`, siehe Eintrag 9.)

### `scenes/menu/main_menu.gd`

- `extends Control`, kein `class_name`. Keine eigenen `signal`-Deklarationen.

| Export | Default |
|---|---|
| `game_scene` | `res://scenes/testmap/testmap.tscn` |
| `glitch_interval_min` | `1.5` |
| `glitch_interval_max` | `4.5` |
| `glitch_duration` | `0.18` |

Engine-Callbacks: `_ready`, `_process`, `_unhandled_input`. Alles andere ist privat. State: `_glitch_timer`, `_glitch_left`, `_starting` (blockiert einen zweiten Start, deaktiviert dabei die Buttons). Optionen: `const OptionsMenu := preload("res://scenes/options/options_menu.gd")`, `@onready var options: OptionsMenu = %Options`. `_show_options` blendet Titel und Knöpfe aus und ruft `options.open()`. `options.closed` → `_hide_options` (alles wieder zeigen, Fokus auf *Optionen*). `options.glitch_requested` → `_trigger_glitch`. Esc bei offenen Optionen → `options.request_back()`, F11 → `Settings.toggle_fullscreen()`. Entwurf, Tastenbelegung und Verwerfen-Warnung stecken nicht mehr hier, sondern in `options_menu.gd`.

### `scenes/options/options_menu.gd`

- `extends VBoxContainer`, kein `class_name` (Hosts laden das Skript per `preload`). Vollständig typisiert.
- Signale: `closed` (Seite wurde verlassen) und `glitch_requested(strength: float, duration: float)` (Effektwunsch fürs Hauptmenü, das Pausemenü hört nicht zu).
- Öffentlich: `open()` (Entwurf = `Settings.get_values()`, erster Reiter, Oberfläche füllen, zeigen, Fokus auf die Tab-Leiste) und `request_back()` (Zurück-Knopf und Esc der Hosts). Alles andere ist privat.
- State: `_draft` (Dictionary, leer solange die Seite zu ist), `_rebinding_action`, `_key_buttons`, `_confirm_discard`.
- *Übernehmen* → `Settings.apply_values(_draft)`, dann `_draft = Settings.get_values()`. *Standard* → `Settings.get_defaults()` in den Entwurf. `request_back()`: läuft eine Tastenbelegung, passiert nichts. Ist der Entwurf ungleich `Settings.get_values()` und noch nicht gewarnt, erscheint die Warnung. Sonst `_close()`: Entwurf leeren, verstecken, `closed` senden.
- Der Vergleich Entwurf gegen Settings (`_same_values`) nimmt für Kommazahlen `is_equal_approx`, weil ein Slider mit Schrittweite 0.05 den gespeicherten Wert nicht immer bitgenau trifft. Der Schlüssel `key_bindings` wird als verschachteltes Dictionary verglichen.
- Tastenbelegung: `_input` fängt während der Belegung jede Taste ab (Esc bricht nur die Belegung ab). Ist eine Taste schon vergeben, tauschen die beiden Aktionen.
- `Settings.changed` → `_on_settings_changed`: ist die Seite offen, wird `_draft.fullscreen` auf den neuen Wert gesetzt (F11). Dadurch folgt die Checkbox, und F11 allein macht den Entwurf nicht „ungespeichert“.
- Die MSAA-Auswahl füllt `_ready` mit den IDs `Viewport.MSAA_*`, die Zuordnung zu `Settings.msaa` ist also die Identität. Die 3D-Auflösung ist ein Slider in Prozent (50–100) und wird als `value / 100.0` in den Entwurf geschrieben.

### `scenes/main/main.gd`

- `extends Node3D`, kein `class_name`. Keine Exports, keine Signale, keine Node-Pfade.
- Einzige Methode: `_unhandled_input` für F11 → `Settings.toggle_fullscreen()`.
- Kennt weder Player noch PauseMenü. Bei pausiertem Baum läuft die Methode nicht.

### `scenes/testmap/testmap.gd`

- `extends Node3D`, kein `class_name`; nur `_unhandled_input` für F11 → `Settings.toggle_fullscreen()` (wie `main.gd`)

### `scenes/testmap/building_facade.gdshader`

- `spatial`, rechnet Fenster aus Weltposition und Normale, darum keine UVs nötig und beliebig große Boxen möglich
- Uniforms: `wall_color`, `glass_color`, `cell_size` (Fensterraster in m), `lit_ratio`, `emission_strength`, `first_floor_height`, drei Fensterfarben
- In `testmap.tscn` zwei ShaderMaterials: `Mat_facade` und `Mat_facade_dense` (dichter, mehr Licht)

### `scenes/player/player.gd`

- `class_name Player`, `extends CharacterBody3D`.

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

Keine `signal`-Deklaration. Yaw dreht den Body, Pitch nur `Head`. Wirksame Empfindlichkeit ist `mouse_sensitivity * Settings.mouse_sensitivity`; `Settings.invert_y` dreht die Pitch-Richtung um. Mausbewegung wirkt nur bei `MOUSE_MODE_CAPTURED`. Der frühere Zweig, der bei `ui_cancel` die Maus freigab, ist entfernt. Unter `respawn_height` ruft `_physics_process` `respawn()` auf. Bewegung: `Input.get_vector("move_left", "move_right", "move_forward", "move_back")`, in `transform.basis` gedreht, horizontal per `lerpf`. In der Luft ist die Beschleunigung `acceleration * air_control`. Bei pausiertem Baum laufen weder Physik noch Eingabe des Players.

---

## 7. 🔌 Abhängigkeiten

```text
project.godot
  main_scene ──► scenes/menu/main_menu.tscn
  autoload   ──► Settings (autoload/settings.gd)
                    ├── liest/schreibt user://settings.cfg
                    ├── wirkt auf DisplayServer, Root-Viewport (msaa_3d, scaling_3d_scale),
                    │   AudioServer (Master, Music, SFX), InputMap
                    └── Signal changed
  default_bus_layout.tres ──► AudioServer (Music, SFX)

scenes/ui/cyber_theme.tres ──► Theme für main_menu.tscn und pause_menu.tscn (und damit für die Optionen)

scenes/options/options_menu.tscn
  └── options_menu.gd ── Settings (get_values, get_defaults, apply_values, changed, key_name,
                                   REBINDABLE_ACTIONS), Signale closed / glitch_requested

main_menu.tscn
  ├── theme ── scenes/ui/cyber_theme.tres
  ├── instance scenes/options/options_menu.tscn
  ├── main_menu.gd ── Settings.toggle_fullscreen, options.open / request_back / closed / glitch_requested
  │     └── Start ──► scenes/testmap/testmap.tscn
  ├── menu_background.gdshader
  └── crt_overlay.gdshader

testmap.tscn
  ├── testmap.gd ── Settings.toggle_fullscreen (F11, nur wenn nicht pausiert)
  ├── building_facade.gdshader
  ├── instance scenes/player/player.tscn
  │     └── player.gd ── (wie bei main.tscn)
  └── instance scenes/pause/pause_menu.tscn
        └── (wie bei main.tscn)

main.tscn (nicht mehr vom Menü geladen, nur per F6)
  ├── main.gd ── Settings.toggle_fullscreen (F11, nur wenn nicht pausiert)
  ├── instance scenes/player/player.tscn
  │     └── player.gd ── Settings.mouse_sensitivity, Settings.invert_y,
  │                      Input Map: move_*, jump, sprint,
  │                      ProjectSettings: physics/3d/default_gravity, $Head, $Head/Camera3D
  └── instance scenes/pause/pause_menu.tscn
        ├── theme ── scenes/ui/cyber_theme.tres
        ├── instance scenes/options/options_menu.tscn
        └── pause_menu.gd ── Settings.toggle_fullscreen, options.open / request_back / closed,
                             SceneTree.paused, Input.mouse_mode, ui_cancel,
                             Zurück ──► scenes/menu/main_menu.tscn
```

---

## 8. 🚫 Nicht vorhanden

- Ordner `scenes/interactive/` und Szene `interactive_box.tscn`
- Weitere Autoloads außer `Settings`; eigene Signale außer `Settings.changed`
- Spielziel, Gegner, Items, Spielstand
- Bestätigungsabfrage bei *Zurück zum Hauptmenü* und *Spiel beenden*
- Live-Vorschau in den Optionen: Änderungen wirken erst nach *Übernehmen* (Hauptmenü und Pausemenü gleich). Das Pausemenü hatte kurz eine Live-Vorschau, siehe Eintrag 7
- Gamepad-Events an `move_*`, `jump`, `sprint`
- Audio-Dateien und `AudioStreamPlayer`; die Busse `Music` und `SFX` sind leer
- Dateien unter `assets/` außer `.gitkeep`

---

## 9. ✅ Teststand

Geprüft mit Godot 4.7.2 stable (headless und im Fenster) gegen den Stand dieses Dokuments, alle Läufe mit **isoliertem `APPDATA`** (siehe Abschnitt 10), die echte `settings.cfg` blieb dabei unangetastet (Hash vor und nach den Läufen identisch). Zahlen aus der echten Ausgabe der letzten Läufe:

| Lauf | Ergebnis |
|---|---|
| `--headless` Start von Projekt, `testmap.tscn` und `main.tscn` je mit `--quit-after 5` (**nach** dem Merge mit `origin/main`, Eintrag 9) | 3 von 3 ohne Ausgabe außer der Versionszeile, also keine Fehler und Warnungen |
| `--headless` Start von Projekt, `main_menu.tscn`, `main.tscn`, `pause_menu.tscn` und `options_menu.tscn` je mit `--quit-after 5` | 5 von 5 ohne Ausgabe außer der Versionszeile, aber **vor** dem Merge gemessen (Eintrag 7). Nach dem Merge nur Projekt, `main.tscn` und `testmap.tscn` einzeln gestartet, die anderen drei sind über `options_flow.gd` und `pause_flow.gd` geladen worden |
| `options_flow.gd` (Headless): dieselbe Prüfroutine einmal im Hauptmenü, einmal im Pausemenü, dazu Strukturvergleich und Übernahme der Werte vom Hauptmenü ins Spiel | **92 PASS, 0 FAIL**, keine `ERROR`/`SCRIPT`/`WARNING`-Zeilen (nach dem Merge). Der erste Lauf danach hatte **91 PASS, 1 FAIL**: Der Test erwartete nach *Start* die Szene `Main` statt `Testmap`. Der Fehler lag im Test, nach Anpassung 92/0 |
| `pause_flow.gd` (Headless): Skripte und Szenen laden (jetzt auch `testmap.gd`/`testmap.tscn`), Esc, Pause, Spieler steht still, Fortsetzen, Zurück ins Hauptmenü, dazu Prüfung, dass `testmap.tscn` (16 `item_spawn`-Marker) und `main.tscn` je `Player` und `PauseMenu` haben | **33 PASS, 0 FAIL, 1 SKIP** (Player-Look braucht eine echte Maus, im Fensterlauf nachgeholt). *Start* lädt dabei `Testmap`, und das `PauseMenu` darin reagiert auf Esc |
| `pause_gui.gd` gegen `testmap.tscn` (Fenster 1280×720, Vulkan Forward+, AMD Radeon RX 9070 XT) | Mausmodus nach Start 2 (gefangen), nach Esc 0 (frei), nach Fortsetzen 2. Look-Differenz −0,4 bei Erwartung −0,4, `ok=true`. Screenshots von Pausemenü und GRAFIK-Reiter über der Neon-Straße angesehen |
| `options_gui.gd` (Fenster 1280×720): Screenshots der drei Reiter in beiden Menüs | Beide Panels 780 px breit, gleiche x-Position (250), gleicher Aufbau, per Bildvergleich bestanden (GRAFIK, AUDIO, STEUERUNG) |
| `apply_test.gd` (Headless) | Master nach `_ready` −1,938 dB, nach `apply()` −6,02 dB (50 %), Music −12,04 dB (25 %), SFX −80 dB und stumm (0 %), `scaling_3d_scale` 0,7 |

Inhalt von `options_flow.gd` je Menü (dieselben Prüfungen, deshalb „gleich“ belegt): 3 Reiter GRAFIK/AUDIO/STEUERUNG, ÜBERNEHMEN anfangs gesperrt, 4 Kantenglättungs-Einträge, 12 Zellen der Tastenbelegung. Änderungen nur im Entwurf (Settings, `AudioServer` unverändert, Beschriftungen folgen). Neubelegung Springen → G erst im Entwurf, Esc während der Belegung bricht nur diese ab. *Übernehmen*: MSAA 8×, 3D-Auflösung 0,7, Master 50 %, Musik 25 %, SFX stumm, Sensitivität 2,0, Y-Invert, `jump` = G in `Settings`, `InputMap` und `settings.cfg`. Esc mit offenem Entwurf: Warnung, zweites Esc verwirft. Wieder öffnen zeigt die übernommenen Werte. *Standard* lädt Standardwerte nur in den Entwurf. F11 zieht die Checkbox nach und macht den Entwurf nicht „ungespeichert“. *Zurück* ohne Änderung schließt sofort. Zusätzlich: gleiche Szene (`scene_file_path`), gleiches Theme (`resource_path`), identische Knotenstruktur (66 Knoten), im Hauptmenü übernommene Werte stehen nach *Start* im Pausemenü.

Frühere Zahlen („49 Prüfungen, 48 bestanden“) stammen vom alten Pausemenü mit eigenen Optionen und gelten nicht mehr. Dieses `pause_flow.gd` gibt es so nicht mehr.

Nicht geprüft:

- **Echter Vollbild-Wechsel aus dem Pausemenü.** Der Headless-Modus kennt keinen Fenstermodus. Geprüft ist nur die Verkabelung (Checkbox ↔ `Settings.fullscreen` ↔ `apply()`).
- **Hörbare Lautstärke.** Es gibt keine Audio-Wiedergabe. Geprüft ist der Wert am Bus (dB und Mute).
- **Controller.** Der Fokus ist gesetzt, ein Gerät war nicht angeschlossen.
- **Echte Mausklicks in den Optionen.** Die Tests lösen die Signale der Bedienelemente per Skript aus (`pressed.emit()`, `value =`) und senden Tasten per `Input.parse_input_event`. Das aufgeklappte Popup des Dropdowns *Kantenglättung* (Stil `PopupMenu` im Theme) wurde nie angezeigt, nur das geschlossene Dropdown per Screenshot.

Offene Kleinigkeiten:

- `scenes/pause/pause_menu.gd`, `scenes/options/options_menu.gd` und `scenes/ui/cyber_theme.tres` haben noch keine `.uid`-Datei. Godot legt sie an, sobald das Projekt im Editor geöffnet und gespeichert wird. Sie gehören dann ins Repo.
- `user://settings.cfg` des Entwicklers: Der Inhalt ist Spielstand des Entwicklers (siehe Eintrag 7). Tests dürfen sie nicht anfassen, siehe Abschnitt 10.
- Die Testskripte liegen nur in `%TEMP%\godot_tests\` und nicht im Repo. Wer sie wiederverwenden will, legt sie z. B. unter `tools/` ab.

---

## 10. 🧪 Test-Rezept (für die nächste KI)

Godot liegt auf dem Entwicklerrechner unter `C:\Users\EnScapeZ\Desktop\Godot_v4.7.2-stable_win64.exe` und ist nicht im `PATH`. Unten `<godot>` und `<projekt>` entsprechend einsetzen.

| Ziel | Befehl | Auswertung |
|---|---|---|
| Projekt startet fehlerfrei | `<godot> --headless --path <projekt> --quit-after 5` | Keine Ausgabe nach der Versionszeile = keine Fehler |
| Einzelne Szene laden | `<godot> --headless --path <projekt> res://scenes/pause/pause_menu.tscn --quit-after 5` | wie oben |
| Ablauf prüfen | Testskript `extends SceneTree`, Aufruf mit `--script <datei>` | `PASS`/`FAIL`-Zeilen, `quit(failures)` als Exit-Code |
| Aussehen und Mausfang | wie oben, aber ohne `--headless`, mit `--windowed --resolution 1280x720`, Screenshot per `root.get_texture().get_image().save_png(...)` nach `await RenderingServer.frame_post_draw` | Bilder ansehen |

Stolpersteine, die schon Zeit gekostet haben:

- `--check-only --script res://...` meldet für **jedes** Skript, das `Settings` benutzt, fälschlich `Identifier not found: Settings`, auch für unverändert funktionierenden Code. Autoloads sind in diesem Modus nicht registriert. Stattdessen Szene oder Projekt starten.
- Ein `--script`-Testskript wird vor den Autoloads kompiliert und kann `Settings` deshalb nicht als Bezeichner verwenden: `var s := root.get_node("Settings")`. In `_initialize()` zuerst `await process_frame`, sonst ist der Autoload noch nicht `_ready` (`is_node_ready()` ist `false`, `get_viewport()` liefert `null`).
- Headless kennt weder Mausmodus (immer `0`, `VISIBLE`) noch Fenstermodus. Mausfang und Vollbild nur im echten Fenster prüfen.
- Tasten simulieren: `InputEventKey` mit `keycode` **und** `physical_keycode` setzen, über `Input.parse_input_event`, danach zwei Frames warten.
- **Tests dürfen die echte `settings.cfg` nie anfassen.** Sie liegt unter `%APPDATA%\Godot\app_userdata\Godot 3D Base\settings.cfg` und gehört dem Entwickler: Er startet das Spiel selbst und stellt dort Dinge ein. Sichern und Zurückkopieren war ein Fehler (siehe Eintrag 7): Man kann seine Einstellungen überschreiben, und der Hash-Vergleich beweist nur, dass man sich selbst zurückgeschrieben hat. Stattdessen den Testprozess auf ein Temp-Verzeichnis umlenken. Godot liest `APPDATA` aus der Umgebung des Prozesses:
  ```powershell
  $iso = "$env:TEMP\godot_appdata_iso"; New-Item -ItemType Directory $iso -Force | Out-Null
  $old = $env:APPDATA
  try { $env:APPDATA = $iso; & $godot --headless --path . --script $test } finally { $env:APPDATA = $old }
  ```
  Nachgewiesen: Der Testprozess meldet dann `user dir=…\Temp\godot_appdata_iso\Godot\app_userdata\Godot 3D Base`. Ohne `settings.cfg` im Temp-Verzeichnis gelten die Standardwerte (`fullscreen=false`), ein Fensterlauf springt also nicht in den Vollbildmodus. `try`/`finally` ist Pflicht, sonst bleibt `APPDATA` in der Shell verbogen, wenn der Lauf abbricht.
- Hängt ein `--script`-Test (z. B. nach einem `SCRIPT ERROR` in `_initialize`), läuft der Prozess weiter. Mit `Start-Process -PassThru` starten, `WaitForExit(60000)` und bei Zeitüberschreitung `Stop-Process`. Ausgabe per `-RedirectStandardOutput` und `-RedirectStandardError` in Dateien holen.
- Szenen, die der Test per `change_scene_to_file` verlässt (Start, Zurück ins Hauptmenü), werden freigegeben. Pfade und Eigenschaften vorher in Variablen lesen, sonst `previously freed`.
- Knoten, die per Code erzeugt werden, und Engine-interne Knoten heißen `@TabBar@4`, `@Label@12` usw. Die Zahl hängt vom Erzeugungszeitpunkt ab. Beim Strukturvergleich zweier Instanzen die Zahl wegnormalisieren (`@(\w+)@\d+` → `@$1`), sonst meldet der Vergleich Unterschiede, die keine sind.
- Ein umbrechendes `Label` in einem `TabContainer` mit `use_hidden_tabs_for_min_size` bläht den ganzen Rahmen auf, siehe Abschnitt 5. Zeigt ein Screenshot ein leeres, bildhohes Panel, zuerst danach suchen.
- `grep`/`Select-String "^FAIL"` zählt die Zusammenfassung `FAILURES=0` mit. Auf `^FAIL ` (mit Leerzeichen) prüfen.

---

## 11. 📝 Änderungsprotokoll (neuester Eintrag zuerst)

Vorlage für neue Einträge steht in `.cursor/rules/ai-handover.mdc`. Alle Einträge unten stammen vom selben Tag, 2026-10-25. Die Einträge 1 bis 5 sind aus dem Verlauf der Sitzung nachgetragen. Änderungen anderer Personen oder Systeme, die per `git pull` hereinkamen, sind nur anhand der Commit-Nachrichten und der Diffs beschrieben.

### Eintrag 9 — `origin/main` in den Branch gemergt, Konflikte gelöst, Pausemenü in die Testmap

- **Auftrag:** „mach das“, als Antwort auf meine Frage, ob ich `origin/main` in den Branch `cursor/pause-menu-shared-options` mergen und die Konflikte lösen soll, damit der Pull Request sauber ist. Vorgehen nach `.cursor/rules/00_conflict_prevention.mdc` (Abschnitt 5).
- **Ausgangslage:** `git fetch` brachte `origin/main` von `6bf1f89` auf `fec1027`. Neu seit dem Merge-Base `2117c2e`: `4476473` (Arbeitslog in `AI_HANDOVER.md`, PR #4) und `7ca5e2d` „Testmap „Neon District“: Cyberpunk-Straße mit Testzonen“ (PR #6, Claude). Gegenüber `2117c2e` änderte das Remote 8 Dateien: `AI_HANDOVER.md` (+98/−5), `README.md` (+5/−3), `scenes/menu/main_menu.gd` (+1/−1: Default von `game_scene` jetzt `res://scenes/testmap/testmap.tscn`), neu `scenes/testmap/` mit `testmap.tscn` (2673 Zeilen), `testmap.gd`, `building_facade.gdshader` und beiden `.uid`. Vor dem Merge gelesen: Diff von `main_menu.gd`, `README.md`, `AI_HANDOVER.md` und `testmap.gd` des Remotes.
- **Merge:** `git merge origin/main --no-commit --no-ff`, ohne `-X ours/theirs`. Ergebnis: `scenes/menu/main_menu.gd` automatisch sauber (mein Umbau und Claudes Einzeiler berühren verschiedene Stellen, geprüft: `game_scene` zeigt auf die Testmap, `OptionsMenu`-Code unverändert). Die neuen `scenes/testmap/*`-Dateien kamen ohne Konflikt. **Konflikte in 2 Dateien, 5 Blöcke:** `README.md` (1) und `AI_HANDOVER.md` (4).
- **Geändert (Auflösung, jeweils beide Seiten behalten):**
  - `README.md`, Ordnerstruktur: `main/` (alte einfache Testwelt, Claude), `testmap/` (Claude), `pause/` (meins) stehen jetzt alle drei da. Zusätzlich Pausemenü-Zeile: „Teil von `testmap.tscn` und `main.tscn`; neue Spielszenen müssen es selbst einbinden“.
  - `AI_HANDOVER.md`, Block 1 (Strukturbaum): `main.tscn` „alte einfache Testwelt (nur noch per F6), enthält PauseMenu“, `testmap/` mit `testmap.tscn` (enthält PauseMenu), `testmap.gd`, `building_facade.gdshader` und beiden `.uid`, `pause/` mit beiden Dateien.
  - Block 2 (Szenenbeschreibung): Abschnitt `pause_menu.tscn` (meiner) und Abschnitt `testmap.tscn` (Claudes) nebeneinander. Im Testmap-Baum steht zusätzlich `PauseMenu` als letztes Kind.
  - Block 3 (Abhängigkeitsbaum): Mein Baum bleibt die Grundlage, weil Claudes Seite auf der alten Form des Baums beruhte. Übernommen von Claude: *Start* → `testmap.tscn`, Zweig `testmap.tscn` (jetzt mit `testmap.gd`, Shader, Player-Instanz **und** Pausemenü-Instanz), `main.tscn` als „nicht mehr vom Menü geladen, nur per F6“. Nicht übernommen: seine alte Zeile „Input Map … ui_cancel“ bei `player.gd`, weil der `ui_cancel`-Zweig im Player entfernt ist.
  - Block 4 (Abschnitte 9 bis 11 gegen Claudes „8. Arbeitslog“): Meine Abschnitte 9 (Teststand), 10 (Test-Rezept) und 11 (Änderungsprotokoll) bleiben. Claudes Arbeitslog steht jetzt als **Abschnitt 12** (Nummer 8 ist bei mir „Nicht vorhanden“), Eintragstext unverändert. Davor ein Hinweis von mir (Zusammenführung, zwei Protokolle). In Claudes Regelsatz steht „Abschnitte 1–7“, dort habe ich **„1–10“** geschrieben (die Zahl wäre sonst falsch). Seine Zeile „- Audio, das die gespeicherte Lautstärke hörbar machen würde“ aus der alten Liste „Nicht vorhanden“ ist nicht übernommen, sie steht in meinem Abschnitt 8 sinngemäß als „Audio-Dateien und `AudioStreamPlayer`“.
  - `AI_HANDOVER.md`, nachgezogen (nicht konfliktbehaftet, aber veraltet): F11-Zeilen nennen `testmap.gd` und `main.gd`; der F6-Satz in Abschnitt 3 nennt beide Spielszenen; Abschnitt 6 „Das Menü existiert nur als Instanz in `testmap.tscn` und `main.tscn`, neue Spielszenen müssen es selbst einbinden“; Abschnitt 9 neue Zahlen; Kopfzeile „Letztes Update“; Verweis auf Abschnitt 12; Kurzfassung im Arbeitslog.
  - **`scenes/testmap/testmap.tscn` (Claudes Datei, kleiner Eingriff):** `load_steps` 27 → 28, neue `ext_resource` `4_pause` auf `res://scenes/pause/pause_menu.tscn`, neuer letzter Knoten `[node name="PauseMenu" parent="." instance=ExtResource("4_pause")]`. Gegenüber `origin/main` per `git diff`: +3 Zeilen, 1 geändert (`load_steps`). Sonst nichts an der Szene.
- **Fund und Grund für den Eingriff in die Testmap:** Der Merge war textlich möglich, aber **funktional falsch**. *Start* lädt jetzt die Testmap, und die hatte kein `PauseMenu`. Esc hätte im echten Spielstart nichts getan, die ganze Arbeit der Einträge 5 bis 7 wäre im Spiel unsichtbar gewesen. Ein reiner Textmerge hätte das nicht gezeigt. Entdeckt durch das Lesen von `testmap.tscn` (nur `Player`, kein `PauseMenu`) vor dem Commit.
- **Entscheidungen und Gründe:**
  - **Zwei Protokolle nebeneinander statt eines.** Claudes Regel lautet „unten anhängen, neuester unten“, meine „oben, neuester oben, ausführlich“. Ein Zusammenlegen würde Einträge einer fremden Seite umformatieren oder umsortieren. Das habe ich nicht ohne Auftrag getan. Stattdessen: Ausführlich in Abschnitt 11, Kurzfassung mit Verweis in Abschnitt 12, damit auch Claude (der nur dort liest) meine Änderungen sieht. Ob es bei zwei Protokollen bleibt, ist offen.
  - **`PauseMenu` als Instanz in die Testmap statt es zum Autoload zu machen.** Ein Autoload würde auch im Hauptmenü Esc abfangen und `main.tscn` doppelt bestücken. Die Instanz entspricht der Lösung in `main.tscn`.
  - **Tests an die neue Startszene angepasst, nicht der Code an die Tests.** Die alten Skripte erwarteten nach *Start* die Szene `Main`.
- **Getestet** (Godot 4.7.2, alle Läufe mit isoliertem `APPDATA`, echte `settings.cfg` vor und nach jedem Lauf mit gleichem Hash `36AE68DD…`):
  - Konfliktmarker: `rg "^(<<<<<<<|=======|>>>>>>>)" . --glob "!.godot"` ohne Treffer (rg-Exit 1) nach der Auflösung.
  - `--headless --quit-after 5` für Projekt, `testmap.tscn`, `main.tscn`: je ohne Ausgabe außer der Versionszeile.
  - `pause_flow.gd` (angepasst): **33 PASS, 0 FAIL, 1 SKIP**. *Start* lädt `Testmap`, deren `PauseMenu` öffnet bei Esc (pausiert, Menü läuft weiter, Spieler steht still), Optionen und Fortsetzen und Zurück ins Hauptmenü funktionieren. `testmap.tscn` hat `Player`, `PauseMenu` und 16 `item_spawn`-Marker, `main.tscn` hat weiter `Player` und `PauseMenu`.
  - `options_flow.gd` (Szenenname angepasst): erster Lauf **91 PASS, 1 FAIL** („Start laedt die Spielwelt“, erwartete `Main`, Fehler im Test), nach der Anpassung **92 PASS, 0 FAIL**, keine `ERROR`/`SCRIPT`/`WARNING`-Zeilen.
  - Fensterlauf gegen `testmap.tscn` (1280×720, Vulkan Forward+, AMD Radeon RX 9070 XT): Maus nach Start 2, nach Esc 0, nach Fortsetzen 2. Look −0,4 bei Erwartung −0,4. Screenshots des Pausemenüs und des GRAFIK-Reiters über der Neon-Straße angesehen: Aufbau und Theme wie zuvor.
- **Nicht getestet:** Echtes Spielen der Testmap (Treppen, Rampen, Sprünge, Tunnel, Fassaden-Shader) und alles andere an Claudes Szene, ich habe sie nur geladen und das Pausemenü darin geprüft. Echte Mausklicks in den Menüs, Controller, Ton, Vollbild-Wechsel (wie bisher). Die vier Zonen-Aussagen in Claudes Eintrag („Player kann keine Stufen steigen“ usw.) habe ich nicht nachgemessen. Nach der Auflösung kein neuer Lauf von `options_gui.gd` (Bildvergleich beider Menüs) und `apply_test.gd`, weil sich weder Optionen-Szene noch `Settings` geändert haben.
- **Git:** Merge-Commit auf `cursor/pause-menu-shared-options` (Eltern: letzter Branch-Stand `761ef92` und `origin/main` `fec1027`), danach Push. Der Hash steht im `git log`. Es gab genau diese zwei Konfliktdateien. Verworfen wurde keine Seite ganz. Nicht verwendet: `--ours`, `--theirs`, `-X`, `reset --hard`, Force-Push.
- **Offen:** Pull Request als Entwurf anlegen (`gh` fehlt auf diesem Rechner, Compare-Link siehe Eintrag 8 und Schlussantwort). Entscheiden, ob die zwei Protokolle (Abschnitt 11 und 12) zusammengelegt werden. Weitere Spielszenen müssen `pause_menu.tscn` selbst einbinden, sonst fehlt dort Esc. Spielerisches von Claudes Testmap (Stufensteigen) ist offen und nicht Teil dieses Merges.

### Eintrag 8 — Regel gegen Merge-Konflikte (`00_conflict_prevention.mdc`)

- **Auftrag:** Als „System-Architekt“ im Ordner `.cursor/rules/` die Regeldatei `00_conflict_prevention.mdc` anlegen, die Merge-Konflikte bei paralleler Arbeit mit anderen KIs und Entwicklern (z. B. Claude) vermeidet und bestehende Konflikte automatisch behebt. Der Auftrag lieferte Frontmatter, Titel, Abschnitt 1 komplett und von Abschnitt 2 die Punkte „Kapselung“ und den Anfang von „Node-Referenzen“.
- **Ausgangslage:** Es gab nur `.cursor/rules/ai-handover.mdc` (Protokollpflicht). Eine Regel zu Konflikten gab es nicht. Echte Konflikte gab es in diesem Repo schon: `project.godot` (Eintrag 2: `run/main_scene` und `config/features`) und aktuell absehbar `AI_HANDOVER.md` und `README.md` gegen `origin/main` (siehe Eintrag 7, Git).
- **Neu:** `.cursor/rules/00_conflict_prevention.mdc` (60 Zeilen, 7270 Zeichen, `alwaysApply: true`). Inhalt:
  - Frontmatter, Titel, Abschnitt 1 (erste zwei Punkte) und Abschnitt 2 (Punkt „Kapselung“) **wörtlich aus dem Auftrag**. Der erste Punkt von Abschnitt 1 ist unverändert, im zweiten Punkt steht statt „(z. B. neue Abschnitte/Einträge unten anfügen)“ jetzt „(z. B. neue Abschnitte/Einträge ergänzen)“, Grund siehe Entscheidungen.
  - Von mir ergänzt (der Auftrag verlangt „komplett vermeiden“, bot dafür aber keinen Text an): Abschnitt 1 um den Abgleich mit dem Remote (`git fetch`, `git log`/`git diff` gegen `origin/<basis>`, vor dem Ändern mergen, nicht rebasen, kein Force-Push) und die Commit-Auswahl; Abschnitt 2 um „Gemeinsame Szenen schmal anfassen“ (mit Vermerk „Merge-Risiko“ im Handover bei größeren Umbauten), „Keine Kosmetik-Diffs“ und „Neue Dateien statt Umbau“; Abschnitt 3 „Gemeinsame Dateien“ (`project.godot`, `AI_HANDOVER.md`, `README.md`, Autoloads, `.uid`); Abschnitt 4 „Branches“ (kurzlebig, Präfix `cursor/`, vor dem Push `origin` einmergen); Abschnitt 5 „Konflikte beheben“ mit sechs Schritten (Überblick mit den Merge-Stufen `:1:`/`:2:`/`:3:`, Verbotsliste, Lösen nach Dateityp, bei Widerspruch `AskQuestion`, Prüfung vor dem Commit, Dokumentation).
  - **Der Auftragstext bricht mitten in Abschnitt 2 ab** („Node-Referenzen: Verwende für dynam“). Den Rest habe ich ergänzt, **das ist meine Annahme, nicht der Wortlaut des Nutzers**: Unique Names (`%Name`) oder `@export`-Referenzen statt fester Pfade, Laden per `preload`. Bitte gegen die eigentliche Absicht prüfen und den Punkt bei Bedarf anpassen. Falls im Auftrag noch weitere Abschnitte folgen sollten, sind sie nicht angekommen.
- **Geändert:**
  - `AI_HANDOVER.md`: Kopfzeile „Letztes Update“, Pflege-Regel-Absatz (Verweis auf die neue Regel), Strukturbaum (neue Zeile `00_conflict_prevention.mdc`), dieser Eintrag. Sonst nichts, passend zur neuen Regel (nur betroffene Zeilen).
- **Entscheidungen und Gründe:**
  - **Reihenfolge im Änderungsprotokoll bleibt „neuester oben“.** Das Beispiel im Auftrag sagte „unten anfügen“, `ai-handover.mdc` und die sieben vorhandenen Einträge verlangen „oben“. Beides gleichzeitig würde sich widersprechen, und eine KI müsste raten. Deshalb steht in der neuen Regel ausdrücklich, dass die Protokoll-Reihenfolge `ai-handover.mdc` bestimmt, und im Auftragstext wurde „unten anfügen“ zu „ergänzen“ neutralisiert. Umstellen auf „unten“ wäre eine Änderung in beiden Regeln und ein Umsortieren der Einträge, das habe ich nicht ohne Auftrag gemacht.
  - **Ehrliche Grenze:** Ob oben oder unten, zwei Branches, die an derselben Stelle einfügen, kollidieren in Git trotzdem. Die Regel verhindert das nicht, sie macht die Lösung eindeutig (beide Einträge behalten, Nummer des eigenen Eintrags erhöhen). Wirklich konfliktfrei wäre ein Eintrag pro Datei (z. B. `docs/handover/0008-….md`). Das wurde **nicht** gebaut, weil es die Struktur der Übergabe ändert.
  - **„Letztes Update“ als Konfliktmagnet benannt.** Jeder Branch ändert diese Zeile, also kollidiert sie bei jedem Merge. Die Regel legt fest: Der Eintrag mit der höheren Nummer gewinnt.
  - **Automatische Konfliktlösung nur verlustfrei.** `--ours`/`--theirs` für ganze Dateien, `-X ours/theirs`, `reset --hard` und das bloße Löschen der Marker sind verboten, weil damit die Arbeit der anderen Seite verloren gehen kann. Bei unvereinbaren Änderungen soll gefragt werden statt zu raten.
  - **`globs: **/*` unverändert aus dem Auftrag übernommen.** In strengem YAML ist ein führendes `*` ein Alias. Ich konnte das nicht prüfen (kein PyYAML installiert). Cursor liest solche Zeilen üblicherweise tolerant, und mit `alwaysApply: true` wird `globs` nicht gebraucht. Sollte die Regel in Cursor nicht erscheinen, ist diese Zeile der erste Verdächtige (dann `globs` löschen oder in Anführungszeichen setzen).
  - **Titel mit Emoji** ( 🛡️ ) wie im Auftrag.
- **Getestet:** Datei gelesen und gezählt (60 Zeilen). Der in der Regel genannte Marker-Befehl `rg "^(<<<<<<<|=======|>>>>>>>)" --glob "!*.md"` über das Projekt: kein Treffer (rg-Exit 1), die Regeldatei löst ihn nicht aus. Zusätzlich vorab geprüft: `git fetch` und `git log main..origin/main` (siehe Eintrag 7), auf die sich die Regel stützt. Die Regel behauptet nichts über Godot-Verhalten, das ich nicht aus diesem Projekt kenne (`load_steps` = ext + sub + 1: gegen `main_menu.tscn` geprüft, 5 + 5 + 1 = 11).
- **Nicht getestet:** Ob Cursor die Regel tatsächlich lädt (kein Neustart und keine Cursor-Oberfläche geprüft). Ob eine andere KI (Claude) `.cursor/rules/` überhaupt liest: Das tut sie nur, wenn sie über Cursor läuft oder man ihr den Inhalt gibt. Die Konfliktlösungsschritte wurden an keinem echten Konflikt ausprobiert. Ein Godot-Lauf war nicht nötig, weil sich keine Spieldatei geändert hat.
- **Git:** Auf Anweisung des Nutzers (Diff-Tab-Aktion „committen und Pull Request anlegen“, als Entwurf) zweiter Commit auf `cursor/pause-menu-shared-options` mit `.cursor/rules/00_conflict_prevention.mdc` (neu) und `AI_HANDOVER.md` (geändert), danach Push nach `origin`. Der Commit-Hash steht im `git log` des Branches. Vorher war die Regeldatei ungetrackt (Commit `73bc44d` aus Eintrag 7 enthält sie nicht). Weitere Dateien gab es nicht. **Pull Request nicht angelegt:** `gh` ist auf diesem Rechner nicht installiert (`gh --version` meldet „nicht erkannt“), Anmeldung nicht geprüft. Der Nutzer bekommt stattdessen den Compare-Link `https://github.com/CaptainArschbart/Test/compare/main...cursor/pause-menu-shared-options` und legt den Entwurf dort an. Der Konflikt mit `origin/main` (`6bf1f89`) in `AI_HANDOVER.md` und `README.md` ist **weiterhin ungelöst**, ich habe ihn auf diesen Auftrag hin nicht angefasst. Er erscheint spätestens im Pull Request.
- **Offen:** Rest von Abschnitt 2 und eventuell weitere Abschnitte des Auftrags nachliefern oder bestätigen. Entscheiden, ob das Protokoll auf eine Datei pro Eintrag umgestellt werden soll (einziger echter Schutz vor Textkonflikten in `AI_HANDOVER.md`). Den offenen Merge mit `origin/main` nach den neuen Regeln durchführen (Eintragsnummer des Remotes prüfen, falls dort ebenfalls „Eintrag 8“ vergeben wurde, bekommt einer von beiden die nächste Nummer).

### Eintrag 7 — Optionen in Hauptmenü und Pausemenü sind jetzt dieselbe Szene

- **Auftrag:** „aber optionen menu vom hauptmenu und wenn man im spiel ist nachdem man starten gedrückt hat sollte im esc menü die optionen gleich sein“.
- **Ausgangslage:** Zwei getrennte Implementierungen. Hauptmenü: Entwurf mit *Übernehmen*/*Standard*/*Zurück* (Verwerfen-Warnung), zwei Reiter *ANZEIGE & AUDIO* und *STEUERUNG* mit Tastenbelegung, 5 Einstellungen, kein MSAA/3D-Auflösung/Musik/SFX. Pausemenü: Live-Anwendung bei jeder Änderung, drei Reiter *GRAFIK*/*AUDIO*/*STEUERUNG*, 9 Einstellungen, keine Tastenbelegung. Zwei Theme-Kopien mit leicht unterschiedlichem Panel-Alpha (0,88 gegen 0,92), dem Hauptmenü fehlten `OptionButton` und `PopupMenu`.
- **Neu:**
  - `scenes/options/options_menu.tscn` und `options_menu.gd`: die gemeinsame Options-Szene (Aufbau siehe Abschnitt 5 und 6). Reiter GRAFIK / AUDIO / STEUERUNG, alle 9 Einstellungen plus Tastenbelegung, Entwurf mit *Übernehmen*, *Standard*, *Zurück*, Statuszeile. Signale `closed` und `glitch_requested`.
  - `scenes/ui/cyber_theme.tres`: ein gemeinsames Theme, zusammengesetzt aus dem Pause-Theme (Obermenge, hat `OptionButton` und `PopupMenu`). Panel-Alpha 0,9 als Mittelwert.
- **Geändert:**
  - `scenes/menu/main_menu.tscn` (laut `git diff --numstat` +5/−282): Theme-Sub-Resources (144 Zeilen) entfernt, stattdessen `ext_resource` auf `cyber_theme.tres`. Der gesamte Unterbaum `OptionsPanel/Options/...` (Reiter, Slider, Tastenbelegung, Knöpfe, Statuszeile) durch eine Instanz `%Options` von `options_menu.tscn` ersetzt. `OptionsPanel` selbst (Position, 780 breit) bleibt. Hintergrund, Titel, Hauptknöpfe, Footer, Fade und CRT-Overlay unverändert. `load_steps` 22 → 11. Per `git diff` geprüft: Entfallen sind nur die Optionen-Knoten.
  - `scenes/menu/main_menu.gd` (laut `git diff --numstat` +10/−162): Entwurf, Neubelegung, `_input`, Dirty-Prüfung, Statuszeile und alle Options-Handler entfernt. Neu: `const OptionsMenu := preload(...)`, `%Options`. `_show_options()` blendet Titel und Knöpfe aus und ruft `options.open()`. `options.closed` → `_hide_options()`. `options.glitch_requested` → `_trigger_glitch`. Esc bei offenen Optionen → `options.request_back()`. F11 → `Settings.toggle_fullscreen()`. Glitch-Logik, Start, Beenden unverändert.
  - `scenes/pause/pause_menu.tscn`: `OptionsPage` (eigener Nachbau der Optionen) durch eine Instanz `%Options` von `options_menu.tscn` ersetzt, Theme extern, Panel-Mindestbreite 680 → 780 (wie das Optionen-Panel im Hauptmenü), damit die Seite beim Wechsel nicht springt.
  - `scenes/pause/pause_menu.gd`: alle Options-Handler und `_refresh()` entfernt. Esc in den Optionen ruft `options.request_back()`. `Settings.save_settings()` in `close()`, `_show_main_page()`, `_on_main_menu_pressed()` und `_on_quit_pressed()` entfernt (nichts Ungespeichertes mehr, *Übernehmen* speichert selbst).
  - `autoload/settings.gd`: Kopfkommentar und Kommentar an `apply()` (beschrieben noch zwei Änderungswege und „jeder Slider-Schritt“). Eine Logikänderung: `key_name()` fragt im Headless-Modus (`DisplayServer.get_name() == "headless"`) das Tastaturlayout nicht ab, weil `keyboard_get_keycode_from_physical` dort pro Aufruf `ERROR: Not supported by this display server` meldet. Im Fenster ändert sich nichts.
  - `AI_HANDOVER.md`: Ist-Stand-Abschnitte 1 bis 10 auf den neuen Stand gebracht, dieser Eintrag, Korrektur in Eintrag 6.
  - `README.md`: Aufzählungspunkte „Optionen“ und „Pausemenü“ neu formuliert (eine gemeinsame Szene, Übernehmen statt Live-Vorschau), Ordnerstruktur um `scenes/ui/` und `scenes/options/` ergänzt.
- **Entscheidungen und Gründe:**
  - **Eine Szene statt Angleichen zweier Nachbauten.** Nur so bleiben die Optionen dauerhaft gleich: Eine neue Einstellung wird an einer Stelle gebaut und erscheint in beiden Menüs. Das Hauptmenü war bisher bewusst nicht umgebaut worden (parallele Arbeit anderer, Merge-Risiko). Der Auftrag verlangt aber ausdrücklich Gleichheit, und der Options-Unterbaum musste ohnehin neu aufgebaut werden, daher wurde er jetzt ersetzt. Wer parallel an den Optionen im Hauptmenü gearbeitet hat, bekommt Merge-Konflikte in `main_menu.tscn` und `main_menu.gd`.
  - **Das Hauptmenü-Modell (Entwurf, *Übernehmen*, *Standard*, Verwerfen-Warnung) gilt für beide.** Es war zuerst da (vom Projekt-Owner), und die Tastenbelegung baut darauf auf. Preis: Das Pausemenü hat **keine Live-Vorschau** mehr (vorher: Lautstärke und MSAA wirkten sofort). Die Alternative, im Hauptmenü ebenfalls live zu übernehmen, wurde nicht gebaut, weil sie das bestehende Hauptmenü-Verhalten (Verwerfen möglich) abschaffen würde. Das lässt sich ändern, es betrifft dann nur `options_menu.gd`.
  - **Gemeinsames Theme.** Zwei Theme-Kopien würden wieder auseinanderlaufen, und das Hauptmenü brauchte `OptionButton`/`PopupMenu`. Die Panel-Transparenz weicht dadurch minimal von beiden alten Werten ab (0,9).
  - **Reiter GRAFIK / AUDIO / STEUERUNG** (Pausemenü-Aufbau) statt *ANZEIGE & AUDIO* / *STEUERUNG*, weil er mehr Einstellungen sauber trennt. Die Tastenbelegung liegt im Reiter STEUERUNG wie vorher im Hauptmenü.
  - **`Settings.changed` hört die Options-Szene selbst ab**, damit beide Hosts F11 nicht extra behandeln müssen. Beim Nachziehen wird nur `fullscreen` im Entwurf ersetzt, andere ungespeicherte Änderungen bleiben.
  - **Toleranter Float-Vergleich im Dirty-Check**, weil ein Slider mit Schrittweite 0,05 den gespeicherten Wert nicht bitgenau trifft und sonst „ungespeichert“ meldet, obwohl nichts geändert wurde.
  - **Kein `class_name` für die Options-Szene.** Hosts laden das Skript per `preload` und nutzen es als Typ. Ein `class_name` bräuchte den globalen Klassen-Cache, den Headless-Läufe ohne Editor nicht zuverlässig neu aufbauen.
  - **Gefundener Fehler während der Arbeit:** Der erste Screenshot zeigte in GRAFIK und AUDIO ein leeres, bildhohes Panel. Ursache: `KeyHint` hatte `autowrap_mode = 3`, und `TabContainer` mit `use_hidden_tabs_for_min_size` misst auch den versteckten Reiter, dort ohne Breite. Behoben durch Entfernen des Umbruchs (Text passt in eine Zeile). Siehe Abschnitt 5.
- **Korrektur an früheren Aussagen (Eintrag 6) – `settings.cfg`:** In Eintrag 6 stand, die Datei habe Reste eines Testlaufs enthalten, und ich habe sie auf die 66-Byte-Sicherung zurückgesetzt. Das war sehr wahrscheinlich falsch. Beobachtet wurde: Nach dem Zurücksetzen (Hash `DD0A15C3…`) hatte die Datei beim nächsten Blick wieder 265 Byte mit dem **identischen Hash `36AE68DD…`** und der Zeit 19:56:33, und es lief kein Godot-Prozess von mir. Der Inhalt (`fullscreen=false`, `vsync=false`, `msaa=3`, `master_volume=80`, sonst Standard) passt dazu, dass der Entwickler das Spiel selbst gestartet, Vollbild ausgeschaltet und im neuen Pausemenü 8× Kantenglättung gewählt hat. Seine Nachricht („nachdem man starten gedrückt hat … esc menü“) beschreibt genau diesen Ablauf. Bewiesen ist es nicht. Folge: Die 265-Byte-Datei ist sehr wahrscheinlich der **echte Stand des Entwicklers**, und mein Zurückkopieren hat ihn kurz überschrieben, bis das Spiel ihn neu schrieb. Ich habe die Datei danach **nicht mehr verändert** (Hash `36AE68DD…` vor und nach jedem Lauf dieses Eintrags gleich). Die Sicherungen liegen in `%TEMP%\godot_tests\` (`settings.cfg.backup` = 66 Byte, `settings.cfg.user_current_19-56` = 265 Byte). Bitte bestätigen oder korrigieren, ob die aktuellen Werte so gewollt sind.
- **Getestet** (alle mit isoliertem `APPDATA`, Zahlen aus der echten Ausgabe, Details in Abschnitt 9):
  - Start von Projekt und allen vier Szenen headless: 5 von 5 ohne Ausgabe außer der Versionszeile.
  - `options_flow.gd`: 92 PASS, 0 FAIL, keine Fehlerzeilen. Zwei Fehlversuche auf dem Weg, beide im Test und nicht im Spielcode: ein Zugriff auf einen freigegebenen Knoten nach dem Szenenwechsel, und ein Strukturvergleich, der an automatischen Knotennamen (`@TabBar@4` gegen `@TabBar@29`, je 28 Knoten) scheiterte. Beide behoben, Nachlauf grün.
  - `pause_flow.gd`: 28 PASS, 0 FAIL, 1 SKIP.
  - `pause_gui.gd` (Fenster): Maus 2 → 0 → 2, Look −0,4 gegen −0,4.
  - `options_gui.gd` (Fenster 1280×720): sechs Screenshots (drei Reiter je Menü) angesehen. Beide Panels 780 px breit bei x = 250. Höhe: Hauptmenü 588 px (durch Anker gestreckt), Pausemenü 551 px (natürliche Höhe). Das Hauptmenü hat zusätzlich sein CRT-Overlay und den animierten Hintergrund, das ist sein eigener Look.
  - `apply_test.gd`: Master −1,938 dB beim Start, −6,02 dB bei 50 %.
- **Nicht getestet:** Echte Mausklicks (Tests lösen Signale per Skript aus), das aufgeklappte Dropdown-Popup, Controller, Vollbild-Wechsel (headless unmöglich), Ton. Ob die gleiche Panel-Höhe (588 gegen 551 px) stört, ist Geschmackssache, ich habe sie nicht angeglichen, weil das Pausemenü auf der Hauptseite dann zu hoch wäre.
- **Git:** Auf Anweisung des Nutzers (Diff-Tab-Aktion „Branch anlegen, committen, pushen“) neuer Branch `cursor/pause-menu-shared-options` von `main` (Stand `2117c2e`), ein Commit mit allen Änderungen aus den Einträgen 5 bis 7, danach Push nach `origin`. Der Commit-Hash steht im `git log` des Branches (er kann nicht im selben Commit stehen). Enthalten: Neu `scenes/options/`, `scenes/ui/`, `scenes/pause/`, `default_bus_layout.tres`, `.cursor/rules/ai-handover.mdc`. Geändert `AI_HANDOVER.md`, `README.md`, `autoload/settings.gd`, `scenes/main/main.gd`, `scenes/main/main.tscn`, `scenes/menu/main_menu.gd`, `scenes/menu/main_menu.tscn`, `scenes/player/player.gd`. Nichts Fremdes ausgeschlossen, weil `git status` nur diese Dateien zeigte. Godot hat beim Laufen keine `.uid`-Dateien angelegt. **Remote ist weitergelaufen:** `git fetch` zeigte `origin/main` auf `6bf1f89` (PR #4, Commit `4476473` „AI_HANDOVER: Arbeitslog mit Regel und bisherigen Arbeitsgängen“, Diff gegen `2117c2e`: `AI_HANDOVER.md` +42 Zeilen, `README.md` 1 Zeile). Der Branch baut auf `2117c2e` auf, nicht auf `6bf1f89`. Beim Zusammenführen sind Konflikte in `AI_HANDOVER.md` und `README.md` zu erwarten. Den Inhalt von `4476473` habe ich nicht gelesen und nicht eingearbeitet.
- **Offen:** Branch mit `origin/main` (`6bf1f89`) zusammenführen und die Konflikte in `AI_HANDOVER.md` und `README.md` lösen, bevor er nach `main` geht. `.uid`-Dateien für `pause_menu.gd`, `options_menu.gd` und `cyber_theme.tres` entstehen erst im Editor. Nach dem Mergen mit paralleler Arbeit am Hauptmenü die Options-Konflikte prüfen. Die Testskripte (`options_flow.gd`, `pause_flow.gd`, `options_gui.gd`, `pause_gui.gd`, `apply_test.gd`) liegen nur in `%TEMP%\godot_tests\`.

### Eintrag 6 — Pflicht zur ausführlichen Protokollierung eingeführt

- **Auftrag:** „schreibe immer ausdrücklich in die ai handover was du gemacht hast ausführlich“.
- **Neu:**
  - `.cursor/rules/ai-handover.mdc`: Cursor-Regel mit `alwaysApply: true`. Sie verlangt nach jeder Aufgabe, die etwas im Projekt ändert, einen Eintrag oben in Abschnitt 11 und das Nachziehen der Ist-Stand-Abschnitte, und legt fest, was ein Eintrag enthält (Auftrag, Neu/Geändert/Gelöscht je Datei, Entscheidungen und Gründe, Getestet, Nicht getestet, Git, Offen).
- **Geändert:**
  - Außerhalb des Repos: `%APPDATA%\Godot\app_userdata\Godot 3D Base\settings.cfg` kurzzeitig auf die 66-Byte-Sicherung zurückgesetzt. Das war ein Fehler, siehe Eintrag 7.
  - `AI_HANDOVER.md`: Hinweis zu Abschnitt 11 und zur Pflege-Regel im Kopf. Strukturbaum um `.cursor/rules/ai-handover.mdc`. Teststand mit den nachgezählten Zahlen. Neue Abschnitte 10 (Test-Rezept) und 11 (dieses Protokoll). Einträge 1 bis 5 nachgetragen.
- **Entscheidungen und Gründe:**
  - Die Regel liegt im Projekt (`.cursor/rules/`), nicht nur im Chat. Dadurch gilt sie in jedem neuen Chat und für alle, die das Repo mit Cursor öffnen. `.cursor/` steht nicht in der `.gitignore`.
  - Neuester Eintrag steht oben, damit die nächste KI zuerst den aktuellen Stand sieht.
  - Reine Fragen und Analysen ohne Änderung brauchen keinen Eintrag. Das steht so in der Regel.
- **Korrektur an früheren Aussagen:** In der Antwort zu Eintrag 5 stand „49 Prüfungen bestanden“. Richtig ist: 49 Prüfungen, davon 48 bestanden, 0 fehlgeschlagen, 1 übersprungen. Zweimal an der echten Ausgabe nachgezählt. Dabei fiel auf, dass `Select-String "^FAIL"` die Zeile `FAILURES=0` mitzählt (siehe Abschnitt 10).
- **Beim Prüfen des Protokolls gefunden und korrigiert:**
  - Die Einträge 1 bis 5 wurden zunächst teilweise aus dem Gedächtnis geschrieben. Danach habe ich sie gegen `git log`, `git show --stat`, `git ls-tree`, die Szene und die Testskripte geprüft. Hashes, Dateilisten, Zeilenstatistiken, Knotenzahl (22 Knoten mit eindeutigem Namen, 47 Knoten insgesamt) und Testinhalte stimmten. Falsch oder unbelegt waren: der Alias `Settings` in Eintrag 4 (war ein lokaler Alias auf `game_settings.gd`, nicht der Autoload), der Wortlaut der 403-Meldung, zwei Aussagen zu Eintrag 2 und ein Platzhalter. Alles ist ersetzt oder entfernt.
  - **`user://settings.cfg` des Entwicklers war nicht unverändert.** Zu Beginn der Prüfung hatte sie 265 Byte (`fullscreen=false`, `vsync=false`, `msaa=3`, alle Schlüsselgruppen). Die Sicherung vom Beginn meiner Tests hat 66 Byte (`fullscreen=true`, `vsync=false`, `master_volume=80.0`). Meine frühere Aussage „unverändert wiederhergestellt“ war damit falsch. **Meine damalige Erklärung („Reste eines Testlaufs“) und das Zurückkopieren der 66-Byte-Datei waren sehr wahrscheinlich ebenfalls falsch:** Die Datei wurde kurz danach mit identischem Inhalt neu geschrieben, ohne dass ein Testprozess von mir lief. Details und Korrektur in Eintrag 7.
- **Getestet** (frische Läufe am Ende dieses Eintrags, jeweils mit dem Ergebnis aus der echten Ausgabe):
  - `--headless` Start von Projekt, `main.tscn` und `pause_menu.tscn` mit `--quit-after 5`: außer der Versionszeile keine Ausgabe, also keine Fehler und keine Warnungen.
  - `bus_test.gd`: 3 Busse (Master, Music und SFX mit Send `Master`, je 0 dB). Hinweis: `--script` läuft vor dem Autoload, deshalb zeigt dieser Test 0,0 dB. Der Startwert kommt aus `apply_test.gd`.
  - `apply_test.gd`: Master nach `_ready` = −1,938 dB (Erwartung −1,938 für 80 %). Nach `apply()` mit 50 / 25 / 0 %: Master −6,02 dB, Music −12,04 dB, SFX −80 dB und stumm. Root-Viewport: `scaling_3d_scale` 0,7.
  - `pause_flow.gd` (Headless): 49 Prüfungen, **48 PASS, 0 FAIL, 1 SKIP**, `FAILURES=0`.
  - `pause_gui.gd` (Fenster, 1280×720, Vulkan Forward+, AMD Radeon RX 9070 XT): Mausmodus nach Start 2, nach Esc 0, nach Fortsetzen 2. Look-Differenz −0,4 bei Erwartung −0,4 (100 px × 0,002 × Faktor 2), `ok=true`. Fünf Screenshots (1280×720) geschrieben.
- **Nicht getestet:** Ob Cursor die Regel in einem neuen Chat tatsächlich lädt. Das lässt sich erst im nächsten Chat sehen.
- **Git:** nichts committet.
- **Offen:** Die neuen Dateien (`.cursor/rules/ai-handover.mdc`, `default_bus_layout.tres`, `scenes/pause/`) und alle Änderungen aus Eintrag 5 sind noch nicht committet.

### Eintrag 5 — Pausemenü, Audio-Busse und Grafik-Optionen

> **Teilweise überholt durch Eintrag 7.** Beschrieben ist der Stand damals. Die eigenen Optionen des Pausemenüs (`OptionsPage`, die Einzel-Handler, `_refresh()`, die Live-Vorschau, das Speichern beim Verlassen) und die „Offen“-Punkte zum Hauptmenü (ohne MSAA, 3D-Auflösung, Musik, SFX, ohne Tastenbelegung im Pausemenü) gibt es nicht mehr. Pausemenü und Hauptmenü zeigen jetzt dieselbe Options-Szene. Die Audio-Busse, `Settings`-Felder und die Pause-Logik gelten weiter.

- **Auftrag:** `git pull` und Abgleich. Ingame-Pausemenü auf Esc (`ui_cancel`) mit Grafik (Vollbild synchron mit F11 und `settings.cfg`, VSync, Auflösung/MSAA), Audio (Master, SFX, Musik, Busse vorbereiten), Steuerung (Mausempfindlichkeit) und den Aktionen Fortsetzen, Zurück zum Hauptmenü, Spiel beenden. Statisch getypter 4.7-Code. Testen. Handover um Pausemenü und Busse ergänzen.
- **Stand nach `git pull`** (Fast-Forward `9d6c44b` → `2117c2e`, Remote-Commits `62bead4` „Optionen: Maus/Tastatur-Einstellungen und Übernehmen-Knopf“, `89a6933` „main übernehmen: GameSettings-Helfer durch Autoload Settings ersetzt“, PR #3):
  - Neu: `autoload/settings.gd` (+ `.uid`) und der Eintrag `[autoload] Settings` in `project.godot`.
  - `scenes/menu/main_menu.gd` und `.tscn` stark erweitert: Reiter, Tasten-Neubelegung, Entwurf mit *Übernehmen*, *Standard*, Warnung beim Verwerfen.
  - `player.gd` liest `Settings.mouse_sensitivity` und `Settings.invert_y`. `main.gd` ruft `Settings.toggle_fullscreen()`.
  - `scripts/game_settings.gd` (mein Helfer aus Eintrag 4) ist gelöscht, der Autoload ersetzt ihn.
  - Die alte `AI_HANDOVER.md` enthielt nach dem Merge einen Rest der früheren Settings-Tabelle (`---|---|---|`) mitten im Text.
- **Neu:**
  - `scenes/pause/pause_menu.tscn`: `CanvasLayer` (`layer = 10`, `visible = false`, `process_mode = ALWAYS`). Darunter `Root` (Vollbild-`Control`, Theme), `Dim`, `Center`, `Panel`, `Pages` mit `%MainPage` (Titel, Hinweiszeile, vier Knöpfe) und `%OptionsPage` (Header, `%Tabs` mit GRAFIK, AUDIO, STEUERUNG, `%BackButton`). 22 Knoten mit `unique_name_in_owner`. Das Neon-Theme ist aus `main_menu.tscn` kopiert und um `OptionButton` und `PopupMenu` ergänzt. `%Tabs` hat `use_hidden_tabs_for_min_size = true`.
  - `scenes/pause/pause_menu.gd`: `open()`, `close()`, Esc- und F11-Behandlung, ein Handler pro Option (Feld in `Settings` setzen, `Settings.apply()`), `_refresh()` mit `set_*_no_signal` und Anbindung an `Settings.changed`, `_exit_tree()` hebt eine offene Pause auf. Export `main_menu_scene`. Vollständig typisiert (`@onready var x: Typ = %Name`, typisierte Parameter und Rückgaben).
  - `default_bus_layout.tres`: Busse `Music` (Index 1) und `SFX` (Index 2), je Send `Master`, 0 dB. `Master` ist implizit. Godot lädt diesen Pfad als Standard, `project.godot` bleibt unverändert.
- **Geändert:**
  - `autoload/settings.gd`: Konstanten `MASTER_BUS`, `MUSIC_BUS`, `SFX_BUS`, `RENDER_SCALE_MIN`. Neue Felder `msaa` (int, Standard `Viewport.MSAA_4X` = 2), `render_scale` (1.0), `music_volume` (100), `sfx_volume` (100). `get_values()` und `get_defaults()` enthalten die vier neuen Schlüssel. `apply_values()` liest sie mit `values.get(...)`. `apply()` setzt den Fenstermodus nur noch, wenn sich der Vollbild-Zustand ändert, setzt `msaa_3d` und `scaling_3d_scale` am Root-Viewport und die drei Busse über `_apply_bus`. `load_settings()` liest `[video] msaa`, `render_scale` und `[audio] music_volume`, `sfx_volume` mit Begrenzung. `save_settings()` schreibt sie. Neue private Funktionen `_apply_bus` und `_ensure_buses` (läuft als Erstes in `_ready`). Kopfkommentar beschreibt die zwei Änderungswege.
  - `scenes/main/main.tscn`: `load_steps` 9 → 10, `ext_resource` `3_pause`, Knoten `PauseMenu` als letztes Kind von `Main`.
  - `scenes/main/main.gd`: nur der Kommentar. Die Logik (F11 → `Settings.toggle_fullscreen()`) ist unverändert.
  - `scenes/player/player.gd`: Der Zweig `elif event.is_action_pressed("ui_cancel"): Input.mouse_mode = VISIBLE` ist entfernt. Er hätte beim Esc die Maus freigegeben, statt das Pausemenü zu öffnen. Der Klick-Zweig, der die Maus wieder einfängt, bleibt. Kopfkommentar angepasst.
  - `README.md`: Esc- und F11-Zeile, Ordnerstruktur (`default_bus_layout.tres`, `scenes/pause/`), Abschnitt zum Pausemenü, `Settings` um die neuen Werte ergänzt.
  - `AI_HANDOVER.md`: komplett neu geschrieben, auch um den Merge-Rest zu entfernen.
- **Entscheidungen und Gründe:**
  - Das Pausemenü wirkt **live** (Feld setzen, `apply()`) und speichert beim Verlassen der Optionen. Das Hauptmenü arbeitet mit Entwurf und *Übernehmen*. Ein Pausemenü ohne Vorschau fühlt sich bei Lautstärke und Helligkeit schlecht an. Gespeichert wird nicht bei jedem Slider-Schritt, um die Datei nicht hundertfach zu schreiben.
  - Das Hauptmenü wurde **nicht** umgebaut, und es gibt keine gemeinsame Options-Komponente. Das Hauptmenü wird parallel von anderer Seite bearbeitet, ein Umbau hätte Merge-Konflikte erzeugt. Folge: Das Theme ist doppelt vorhanden. Änderungen am Stil müssen in beiden `.tscn` gemacht werden.
  - Keine zweite Settings-Klasse. Alles läuft über den vorhandenen Autoload.
  - `apply()` fasst den Fenstermodus nur bei Änderung an. Sonst setzt jeder Slider-Schritt ein maximiertes Fenster auf „Fenster“ zurück. Das betrifft auch das Hauptmenü positiv.
  - 0 % Lautstärke wird zu −80 dB plus Mute. `linear_to_db(0.0)` wäre −inf.
  - Busse aus `default_bus_layout.tres` (sichtbar im Editor) **und** ein Laufzeit-Guard `_ensure_buses()`. Das Layout wurde von Hand geschrieben, Godot bestätigte es im Test. Der Guard schützt trotzdem, falls die Datei fehlt.
  - MSAA wirkt am Root-Viewport und überschreibt zur Laufzeit die Projekteinstellung `anti_aliasing/quality/msaa_3d`. Die Auswahl-IDs des Dropdowns sind direkt die `Viewport.MSAA`-Werte.
  - Das Pausemenü verarbeitet F11 selbst, weil `main.gd` bei pausiertem Baum keine Eingaben bekommt.
  - `_exit_tree()` hebt die Pause auf, damit sie nicht in die nächste Szene wandert.
  - Das Pausemenü ist kein Autoload, sondern Teil von `main.tscn`. So kann es im Hauptmenü nicht auftauchen.
  - Die Rahmenhöhe sprang zwischen den Reitern, weil `TabContainer` nur den aktuellen Reiter misst. Behoben mit `use_hidden_tabs_for_min_size`.
- **Getestet** (Godot 4.7.2 stable):
  - `--headless` Start von Projekt, `main.tscn` und `pause_menu.tscn` je mit `--quit-after 5`: keine Fehler, keine Warnungen.
  - Bus-Layout und `Settings`: drei Busse (Master, Music, SFX, Send Master). Beim Start liegt Master bei −1,938 dB (80 %), die gespeicherte `settings.cfg` wird gelesen.
  - Headless-Ablauftest, 49 Prüfungen: **48 bestanden, 0 fehlgeschlagen, 1 übersprungen**. Inhalt: alle fünf Skripte kompilieren. Esc im Hauptmenü pausiert nichts. Start lädt `Main`. Esc öffnet, `paused = true`, `process_mode = ALWAYS`, Fokus auf *Fortsetzen*. Spieler steht bei Pause still (Geschwindigkeit −5 gesetzt, Y unverändert). Vollbild-Checkbox ↔ `Settings.fullscreen` in beide Richtungen, F11 im offenen Menü. VSync. MSAA 4 Einträge, 8× und Aus am Root-Viewport. 3D-Auflösung 70 % → `scaling_3d_scale` 0,7. Master 50 % = −6,02 dB, Musik 25 % = −12,04 dB, SFX 0 % stumm, SFX 100 % wieder hörbar. Sensitivität 2,0, Y-Invertierung. Esc aus den Optionen → Hauptseite, Pause bleibt. `settings.cfg` enthält danach `master_volume=50`, `music_volume=25`, `render_scale=0.7`, `msaa=0`, `mouse_sensitivity=2.0`. Esc im Hauptteil = Fortsetzen. Fortsetzen-Knopf. Zurück zum Hauptmenü lädt `MainMenu`, nicht pausiert, Fokus setzbar.
  - Fensterlauf (1280×720, Vulkan Forward+, AMD RX 9070 XT): Mausmodus 2 → 0 → 2 (gefangen, frei, gefangen). Player-Look: Drehung −0,4 rad bei Erwartung −0,4 (100 px × 0,002 × Faktor 2). Fünf Screenshots (Spiel, Pause, drei Reiter). Dabei das Höhenproblem der Reiter gefunden und behoben, danach mit neuen Screenshots bestätigt.
- **Nicht getestet:** echter Vollbild-Wechsel aus dem Pausemenü (Headless kennt keinen Fenstermodus), hörbare Lautstärke (keine Audio-Dateien), Bedienung mit einem Controller (keiner angeschlossen).
- **Git:** `git pull` als Fast-Forward. Nichts committet.
- **Offen:**
  - `scenes/pause/pause_menu.gd` hat noch keine `.uid`-Datei. Godot legt sie an, sobald das Projekt im Editor geöffnet wird.
  - Das Hauptmenü zeigt MSAA, 3D-Auflösung, Musik und SFX nicht. *Standard* plus *Übernehmen* setzt sie dort auf die Standardwerte zurück.
  - *Spiel beenden* und *Zurück zum Hauptmenü* fragen nicht nach. Ein Spielstand existiert ohnehin nicht.
  - Änderungen im Pausemenü sind erst nach dem Verlassen der Optionen auf der Platte.

### Eintrag 4 — Vollbild vereinheitlicht, Handover neu geschrieben (später ersetzt)

- **Auftrag:** (1) `run/main_scene` auf das Hauptmenü. (2) F11 in `main.gd` soll den Zustand wie das Menü in `user://settings.cfg` sichern. (3) `AI_HANDOVER.md` komplett neu, mit Godot 4.7, Ordnerstruktur inklusive `scenes/interactive/interactive_box.tscn`, Input Map, Settings und der Einbahnstraße.
- **Neu:**
  - `scripts/game_settings.gd` (`class_name GameSettings`, `RefCounted`, nur statische Funktionen `get_fullscreen`, `get_vsync`, `get_master_volume`, `set_fullscreen`, `save_preferences`). `set_fullscreen` lädt die Datei zuerst und ändert nur den Vollbild-Schlüssel, damit VSync und Lautstärke nicht verloren gehen.
- **Geändert:**
  - `scenes/main/main.gd` (11 Zeilen geändert): neue Konstante `const Settings := preload("res://scripts/game_settings.gd")`. Das ist ein lokaler Alias auf das Helfer-Skript und **nicht** der spätere Autoload `Settings`. F11 berechnet `enable_fullscreen` (aktueller Modus ≠ Vollbild), setzt den Fenstermodus und ruft `Settings.set_fullscreen(enable_fullscreen)`.
  - `scenes/menu/main_menu.gd` (26 Zeilen geändert): dieselbe Alias-Konstante statt `SETTINGS_PATH`. `_on_fullscreen_toggled` ruft `Settings.set_fullscreen(on)` und speichert damit sofort. `_load_settings` nutzt `get_fullscreen`, `get_vsync`, `get_master_volume`. `_save_settings` ruft `save_preferences(fullscreen, vsync, volume)`. Die eigene `ConfigFile`-Logik im Menü ist entfernt. Kopfkommentare angepasst.
  - `AI_HANDOVER.md`: neu geschrieben (Godot 4.7, Hauptmenü als Startszene, Ablauf als Einbahnstraße, Input Map, Speicherverhalten).
  - `project.godot`: unverändert. `run/main_scene` zeigte nach der Konfliktlösung aus Eintrag 2 bereits auf das Menü.
- **Entscheidungen und Gründe:**
  - `scenes/interactive/interactive_box.tscn` existierte nicht. Die Übergabe führt sie ausdrücklich als nicht vorhanden, statt sie zu erfinden.
  - Der Helfer war eine kleine eigene Lösung, weil keine zentrale Settings-Klasse existierte.
- **Korrektur an früheren Aussagen:** Ich schrieb damals „Godot ist hier nicht installiert“. Das war falsch. Ich hatte nur `PATH` und `C:\Program Files\Godot` durchsucht. Die Datei liegt auf dem Desktop. Gefunden erst in Eintrag 5.
- **Getestet:** nur durch Lesen des Quelltexts. Kein Godot-Lauf.
- **Git:** Commit `dcb2c84` „Änderungen hinzugefügt“ (5 Dateien, +273/−166). `git pull.bat` fehlte im Arbeitsverzeichnis schon vor dem `git add .` (nicht von mir gelöscht), die Löschung wurde mit committet. Push abgelehnt (`fetch first`), weil das Remote parallel `b6335b3` „Delete git pull.bat“ hatte. `git pull` ergab den Merge `9d6c44b` ohne Konflikt, danach Push `b6335b3..9d6c44b` erfolgreich.
- **Später ersetzt:** `scripts/game_settings.gd` wurde durch den Autoload `Settings` abgelöst (siehe Eintrag 5). Die Datei existiert nicht mehr.

### Eintrag 3 — Analyse des Spielstands

- **Auftrag:** „analysiere das game vom jetzigen stand“.
- **Änderungen am Repo:** keine. Das Ergebnis liegt als Canvas außerhalb des Projekts: `C:\Users\EnScapeZ\.cursor\projects\b-AI-game-Test\canvases\game-state.canvas.tsx`.
- **Befunde:** F11 in der Spielwelt wurde nicht gespeichert, im Menü erst beim Verlassen der Optionen. Die Lautstärke wirkte auf keinen hörbaren Ton, weil es kein Audio gibt. Die README behauptete Controller-Bedienung, obwohl die Spielaktionen nur Tastatur haben. Die `AI_HANDOVER.md` war veraltet. `BoxSmall` ragt in den Boden. Aus der Welt gab es keinen Weg zurück ins Menü.
- **Getestet:** nur durch Lesen. Kein Godot-Lauf.
- **Folge:** Die Befunde zu Vollbild und Handover wurden in Eintrag 4 bearbeitet, der Rückweg ins Menü in Eintrag 5.

### Eintrag 2 — Hauptmenü-Merge und Konflikt in `project.godot`

- **Auftrag:** `git pull`, Merge-Konflikt in `project.godot` lösen: Hauptszene vom Remote (`res://scenes/menu/main_menu.tscn`), Godot-Features vom lokalen Stand (`4.7`, `Forward Plus`), alle Konfliktmarker entfernen.
- **Ausgangslage:** lokaler Commit `482c15e` (Eintrag 1). Remote hatte `78b70ec` „Cyberpunk-Hauptmenü als Startszene“ (PR #2, `6638006`).
- **Konflikt:** `project.godot`, Zeilen `run/main_scene` (lokal `main.tscn`, remote `main_menu.tscn`) und `config/features` (lokal `4.7`, remote `4.4`).
- **Geändert:** `project.godot`: `run/main_scene="res://scenes/menu/main_menu.tscn"`, `config/features=PackedStringArray("4.7", "Forward Plus")`. Per Suche bestätigt, dass `<<<<<<<`, `=======` und `>>>>>>>` nicht mehr vorkommen.
- **Aus dem Remote ohne Konflikt übernommen:** `scenes/menu/main_menu.tscn`, `main_menu.gd`, `crt_overlay.gdshader`, `menu_background.gdshader` samt `.uid`-Dateien, außerdem Änderungen an `README.md`.
- **Zwischenfall:** Ein `git commit` bei noch ungelöstem Konflikt wurde von Git abgelehnt, erst nach der Lösung und `git add project.godot` ging er durch.
- **Git:** Merge-Commit `b24108d` „Änderungen hinzugefügt“ (Eltern `482c15e` und `6638006`). Gegenüber dem lokalen Stand brachte er 9 Dateien, +600/−2 Zeilen. Der Push ging an das Remote.
- **Getestet:** nur Konfliktmarker-Suche und Sichtprüfung. Kein Godot-Lauf.

### Eintrag 1 — Erstanalyse und erste Fassung der Übergabe

- **Auftrag:** Das Projekt als Godot-4-3D-Systems-Engineer analysieren und `AI_HANDOVER.md` nach vorgegebenem Format anlegen: Ordnerstruktur, `project.godot` (Rendering, Input Map, Autoloads, Hauptszene), Szenen- und Skript-Hierarchie, `@export`, Signale, öffentliche Methoden, `%`- und `$`-Zugriffe.
- **Befund damals** (Stand `23f566b`, per `git ls-tree` und `git show` belegt): zwei Szenen (`main`, `player`), zwei Skripte (`main.gd`, `player.gd`), Feature-Tag `4.4`, Hauptszene `main.tscn`, kein `[autoload]`, weder `signal` noch `.connect(` im Code, sechs Input-Aktionen (`move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `sprint`), Physik-Layer-Namen gesetzt, `assets/audio|materials|models|textures` nur mit `.gitkeep`.
- **Neu:** `AI_HANDOVER.md` (erste Fassung mit sechs Abschnitten).
- **Git:** `git pull` und `git fetch` holten PR #1 (`23f566b`, Godot-4-3D-Grundgerüst). Commit `482c15e` „Änderungen hinzugefügt“ mit `AI_HANDOVER.md`, `git pull.bat` und zwei Änderungen, die der Godot-Editor selbst gemacht hatte (nicht von mir): `project.godot` (Feature-Tag `4.4` → `4.7`, neuer `[animation]`-Eintrag) und `icon.svg.import` (neue Import-Optionen). Die ersten Push-Versuche scheiterten mit HTTP 403, weil das Konto EnScapeZ keine Schreibrechte auf `CaptainArschbart/Test` hatte. Ein späterer Push wurde mit `fetch first` abgelehnt und ging nach `git pull` durch.
- **Getestet:** nur durch Lesen. Kein Godot-Lauf.

---

## 12. 📝 Arbeitslog (kurze Einträge, neuester unten)

> **Hinweis zur Zusammenführung (Eintrag 9):** Dieser Abschnitt stammt von Claude (PR #4 und #6) und hieß dort „8. Arbeitslog“. Er ist hier Abschnitt 12, weil Abschnitt 8 inzwischen „Nicht vorhanden“ heißt. Der Text der Einträge ist unverändert. Es gibt jetzt **zwei Protokolle**: Abschnitt 11 (ausführlich, neuester oben, Regel `.cursor/rules/ai-handover.mdc`) und diesen Abschnitt (kurz, neuester unten). Wer mit Cursor arbeitet, schreibt den ausführlichen Eintrag in Abschnitt 11 und hängt hier eine Kurzfassung mit Verweis an. Ob beide Protokolle zu einem zusammengelegt werden, ist offen.

**Regel für alle (Menschen und KIs):** Nach jedem Arbeitsgang hier unten einen Eintrag anhängen, bevor committet wird. Ältere Einträge nicht ändern, nur neue anhängen (neuester unten). Die Abschnitte 1–10 oben beschreiben den Ist-Stand und werden bei Änderungen mit aktualisiert.

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

### 2026-10-25 · Testmap „Neon District“ · Claude (für Arschi) · PR folgt (Branch `claude/project-thread-0flw0w`)
- Was: Neue Testmap `scenes/testmap/testmap.tscn` im Cyberpunk-Stil des Menüs (Nacht, Nebel, Glow, Leuchtreklamen, Fassaden-Shader). Testzonen: Treppen mit 4 Stufenhöhen plus eine Treppe mit Rampen-Kollision, Rampen 15–50°, Tunnel mit sinkender Decke, Messwand, Sprunghöhe, Weitsprung-Lücken, Parkour-Turm aufs Dach, großer Platz mit Deckung und Brücke. 16 `Marker3D` in Gruppe `item_spawn` unter `Pickups/SpawnPoints` als Plätze für Items. *Start* im Menü lädt jetzt die Testmap; `scenes/main/main.tscn` bleibt unverändert und ist per F6 startbar.
- Dateien: `scenes/testmap/*` (neu), `scenes/menu/main_menu.gd` (nur Default von `game_scene`), `README.md`, `AI_HANDOVER.md`.
- Wichtig für die Nächsten: Der Player kann keine Stufen hochlaufen, schon 0,15 m blockt (headless getestet). Entweder Stufensteigen in `player.gd` einbauen oder Treppen wie `Stairs_RampCollision` mit unsichtbarer Rampe bauen. Inventar/HUD aus dem Hotbar-PR hängen am Player und sind damit automatisch in der Testmap; Pickups können als Instanzen unter `Pickups` an die `item_spawn`-Marker (Mittelpunkt ca. 0,5 m über dem Pad). Die Szene ist mit einem Python-Skript erzeugt, aber normal im Editor bearbeitbar.

### 2026-10-25 · Gemeinsame Optionen, Pausemenü, Konflikt-Regel, Merge · Cursor (für EnScapeZ) · Branch `cursor/pause-menu-shared-options` (Entwurfs-PR folgt)
- Was: Hauptmenü und Pausemenü (Esc) nutzen jetzt **dieselbe** Options-Szene `scenes/options/options_menu.tscn` mit gemeinsamem Theme `scenes/ui/cyber_theme.tres` (Reiter Grafik / Audio / Steuerung, Wirkung erst nach „Übernehmen“). Neues Pausemenü `scenes/pause/pause_menu.tscn`. Audio-Busse Music/SFX (`default_bus_layout.tres`), `Settings` um `msaa`, `render_scale`, `music_volume`, `sfx_volume` erweitert. Neue Cursor-Regel `.cursor/rules/00_conflict_prevention.mdc`. `origin/main` (inkl. Testmap) in den Branch gemergt.
- Dateien: `scenes/options/*`, `scenes/pause/*`, `scenes/ui/*`, `default_bus_layout.tres` (alle neu), `autoload/settings.gd`, `scenes/menu/main_menu.gd/.tscn` (Optionen ausgelagert), `scenes/main/main.tscn/.gd`, `scenes/player/player.gd`, **`scenes/testmap/testmap.tscn`** (nur `PauseMenu`-Instanz ergänzt), `README.md`, `AI_HANDOVER.md`.
- Wichtig für die Nächsten: Die Testmap hat jetzt ein `PauseMenu` als letztes Kind. **Jede neue Spielszene muss `res://scenes/pause/pause_menu.tscn` selbst instanziieren**, sonst tut Esc dort nichts (das Pausemenü ist kein Autoload). Neue Einstellungen werden nur in `options_menu.tscn/.gd` gebaut und erscheinen automatisch in beiden Menüs. Das Pausemenü hat keine Live-Vorschau mehr. Ausführlich in Abschnitt 11, Einträge 5 bis 9. Vor dem Ändern gemeinsamer Dateien `.cursor/rules/00_conflict_prevention.mdc` lesen (Abgleich mit dem Remote, nur das Nötigste ändern).