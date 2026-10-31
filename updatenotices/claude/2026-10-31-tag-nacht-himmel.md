# Tag-Nacht-Himmel · Claude (für Arschi)

## 2026-10-31 · Eigener Himmel mit Sonne, Mond, Sternen und Wolken

- `scenes/world/world_sky.gdshader` (neu): Der Himmel ist ein eigener Sky-Shader. Er zeichnet einen Farbverlauf vom Horizont zum Zenit, die Sonne mit Hof, den Mond, funkelnde Sterne, ziehende Wolken und nachts einen pink-violetten Lichtschein der Stadt am Horizont und unter den Wolken. Vorher war der Himmel immer derselbe Nacht-Verlauf, tagsüber nur grau überblendet.
- `scenes/world/world_atmosphere.gd`:
  - Farben je Tagesphase: Nacht, Dämmerung (orange/rosa), Tag (blau) und bedeckt (grau). Umgebungslicht und Nebelfarbe gehen mit, damit die Ferne in den Himmel übergeht.
  - Die DirectionalLight3D „Moon“ ist tagsüber die Sonne und nachts der Mond, also immer die Lichtquelle über dem Horizont. Vorher kam das Nachtlicht von unterhalb des Horizonts.
  - Wetterwechsel blenden über 20 s weich über: Wolkendecke, Licht, Nebel. Vorher sprang das Wetter.
  - `fog_sky_affect` hängt jetzt am Wetter (0,15 klar bis 0,6 bei Regen), `volumetric_fog_sky_affect` steht auf 0,2. Vorher hat der Nebel den Himmel zu 70 % grau überdeckt.
  - Sonne und Mond leuchten den volumetrischen Nebel nicht mehr an (`light_volumetric_fog_energy = 0`). Neonlichter tun es weiterhin.
  - Die Himmels-Reflexionen laufen inkrementell (128er-Cubemap) und werden höchstens fünfmal pro Sekunde neu angestoßen. Echtzeit hätte eine 256er-Cubemap pro Bild erzwungen.
- Wolkenrauschen: Gradientenrauschen mit Ganzzahl-Hash. Wertrauschen und ein fract()-Hash erzeugten harte, gerade Kanten am Himmel, die wie riesige Kästen aussahen.
- `tools/tests/shot_sky.gd` (neu): macht Screenshots zu 8 Tageszeiten bei klarem Wetter und bei Regen. Aufruf: `godot --path . -s res://tools/tests/shot_sky.gd -- <ordner>`.
- Nicht geändert: Die Tageslänge bleibt bei 8 Minuten (`DAY_LENGTH`). Die Tageszeit wird im Multiplayer weiterhin nicht synchronisiert, wie vorher.
- Getestet mit Godot 4.7.2 unter Windows: `test_sector7_city` 44/0. Die Screenshots aller Phasen wurden angesehen.

## 2026-10-31 · Bloom-Regler, schwächeres Leuchten, kein Neon-Regenschirm

- Optionen › Grafik: neuer Regler „Bloom-Stärke“ (0–200 %, Standard 100 %) unter dem Glow-Schalter. `Settings.glow_strength` (0–2) wird in `settings.cfg` gespeichert. `world_atmosphere.gd` multipliziert damit `glow_intensity` und `glow_bloom` der Karte. Bei 0 % ist Glow aus.
- Glow allgemein schwächer: Slum `glow_intensity` von 0,9 auf 0,5, `glow_bloom` von 0,05 auf 0,02, `glow_hdr_threshold` von 1,1 auf 1,4. Testmap: Intensität von 1,0 auf 0,55, Bloom von 0,08 auf 0,03, Schwelle neu 1,4.
- Leuchtende Materialien schwächer: `SlumMats.EMISSION_SCALE = 0.65` für alle Kit-Materialien (Neon, Schilder, Fenster). `EnemyModel._emit` ebenfalls ×0,65, das gilt auch für Akzente der Passanten. Ladenschilder und Wohnblock-Leuchten von 2–3 auf 1,3.
- Unverändert: Statusfarbe der Gegner, Visier der Wachen, Bremslichter, Schießscheiben.
- Neon-Regenschirm der Passanten komplett entfernt (`civilian_model.gd`). Der Zufallsgenerator zieht dafür keine Zahl mehr, deshalb sehen die Passanten bei gleichem Seed etwas anders aus.
- Getestet mit Godot 4.7.2 headless: `test_options_scroll` 27/0, `test_resolution_window` 6/0, `test_sector7_city` 44/0. `test_content_update` 45/1: „Einbruch +1 Stern“ schlägt jedes Mal fehl. Das liegt in `locked_door`/`WantedManager`, nicht in dieser Änderung.
