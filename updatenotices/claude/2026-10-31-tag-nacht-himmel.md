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
