@tool
class_name SlumSign
extends SlumPiece
## Leuchtschild / Decal aus dem Mapkit (BAR, 24時間営業, 薬局, ホテル, NG-C7, Graffiti, Poster …).
##
## WALL: flach an einer Wand (Rückseite bei z = 0, schaut nach +Z).
## BLADE: Ausleger-Schild quer zur Wand, beidseitig lesbar.
## ROOF: Reklametafel auf Stelzen fürs Dach.
## DECAL: nur das Bild ohne Rahmen und Licht (Graffiti, Poster, Schablonen).

enum Mount { WALL, BLADE, ROOF, DECAL }

## Texturname in assets/textures/slum/ (ohne .png).
@export var texture_name := "sign_bar":
	set(v):
		texture_name = v
		queue_rebuild()
@export var mount := Mount.WALL:
	set(v):
		mount = v
		queue_rebuild()
## Breite in Metern, die Höhe folgt aus dem Seitenverhältnis der Textur.
@export var width := 2.4:
	set(v):
		width = v
		queue_rebuild()
@export var light_color := Color(1.0, 0.3, 0.4):
	set(v):
		light_color = v
		queue_rebuild()
@export var light_energy := 1.6:
	set(v):
		light_energy = v
		queue_rebuild()
## 0 = ruhig, 1 = kaputte Röhre.
@export_range(0.0, 1.0) var flicker := 0.0:
	set(v):
		flicker = v
		queue_rebuild()


func _build(b: SlumBuilder) -> void:
	var tex := SlumMats.texture(texture_name)
	var aspect := 2.5
	if tex != null:
		aspect = float(tex.get_width()) / float(tex.get_height())
	var w := width
	var h := w / aspect
	var frame := SlumMats.color(Color(0.06, 0.06, 0.07), 0.0, 0.6, 0.5)
	var metal := SlumMats.color(Color(0.16, 0.17, 0.18), 0.0, 0.55, 0.6)
	var mat: StandardMaterial3D = SlumMats.decal(texture_name) if mount == Mount.DECAL else SlumMats.sign_mat(texture_name, 3.2)
	if flicker > 0.0 and mat.emission_enabled and not Engine.is_editor_hint():
		mat = mat.duplicate()
	match mount:
		Mount.DECAL:
			b.quad(Vector3(0, 0, 0.02), Vector3.BACK, w, h, mat)
			return
		Mount.WALL:
			b.box(Vector3(0, 0, 0.05), Vector3(w + 0.1, h + 0.1, 0.1), frame, false)
			b.quad(Vector3(0, 0, 0.105), Vector3.BACK, w, h, mat)
			_glow(Vector3(0, 0, 0.9), mat)
		Mount.BLADE:
			var c := Vector3(0, 0, 0.3 + w * 0.5)
			for y: float in [h * 0.5 - 0.15, -h * 0.5 + 0.15]:
				b.box(Vector3(0, y, 0.15), Vector3(0.06, 0.06, 0.3), metal, false)
			b.box(c, Vector3(0.12, h + 0.1, w + 0.1), frame, false)
			b.quad_x(Transform3D(Basis(Vector3.UP, PI * 0.5), c + Vector3(0.065, 0, 0)), w, h, mat)
			b.quad_x(Transform3D(Basis(Vector3.UP, -PI * 0.5), c + Vector3(-0.065, 0, 0)), w, h, mat)
			_glow(c + Vector3(0.8, 0, 0), mat)
			_glow(c + Vector3(-0.8, 0, 0), null, 0.6)
		Mount.ROOF:
			var lift := 1.2
			b.box(Vector3(0, lift + h * 0.5, 0), Vector3(w + 0.2, h + 0.2, 0.15), frame)
			b.quad(Vector3(0, lift + h * 0.5, 0.08), Vector3.BACK, w, h, mat)
			for x: float in [-w * 0.35, w * 0.35]:
				b.box(Vector3(x, lift * 0.5, -0.2), Vector3(0.12, lift + 0.2, 0.12), metal, false)
				b.tube(Vector3(x, 0, -1.0), Vector3(x, lift + h * 0.3, -0.15), 0.04, metal, 4)
			# Strahler von unten
			for x: float in [-w * 0.3, w * 0.3]:
				b.box(Vector3(x, lift - 0.1, 0.5), Vector3(0.25, 0.15, 0.2), metal, false)
			_glow(Vector3(0, lift + h * 0.5, 1.2), mat)


func _glow(at: Vector3, mat: StandardMaterial3D, scale := 1.0) -> void:
	if light_energy <= 0.0:
		return
	var light := add_light(at, light_color, light_energy * scale, 5.0 + width, flicker)
	if mat != null and flicker > 0.0 and light.get_child_count() > 0:
		var f := light.get_child(0) as SlumFlicker
		f.material = mat
		f.base_emission = mat.emission_energy_multiplier
