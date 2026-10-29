@tool
class_name SlumBuilder
extends RefCounted
## Sammelt Geometrie (Boxen, Quads, Zylinder) pro Material und baut daraus am Ende wenige Meshes
## plus eine StaticBody3D mit Box-Kollisionen. So bleibt die Zahl der Draw-Calls klein, auch wenn
## ein Gebäude aus Hunderten Teilen besteht.
##
## Benutzung:  var b := SlumBuilder.new(self); b.box(...); b.quad(...); b.finish()
## Alle Positionen sind lokal zum Wurzelknoten (root). Transform3D-Varianten erlauben Drehungen.

var root: Node3D
## Physik-Layer der Kollision (1 = world).
var collision_layer := 1
## Sichtweite der Meshes in Metern (0 = immer sichtbar). Spart Draw-Calls in der großen Map.
var solid_range := 0.0
var detail_range := 0.0

var _solid := {}  # Material -> SurfaceTool, wirft Schatten
var _flat := {}  # Material -> SurfaceTool, Details ohne Schatten
var _body: StaticBody3D


func _init(target: Node3D) -> void:
	root = target


func _tool(mat: Material, shadow: bool) -> SurfaceTool:
	var table := _solid if shadow else _flat
	var st: SurfaceTool = table.get(mat)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		table[mat] = st
	return st


## Ein Viereck a(oben links) b(oben rechts) c(unten rechts) d(unten links), von außen gesehen.
func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3,
		uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, uv_d: Vector2) -> void:
	st.set_normal(n)
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_uv(uv_b)
	st.add_vertex(b)
	st.set_uv(uv_c)
	st.add_vertex(c)
	st.set_uv(uv_a)
	st.add_vertex(a)
	st.set_uv(uv_c)
	st.add_vertex(c)
	st.set_uv(uv_d)
	st.add_vertex(d)


const _FACES := [
	# Normale, rechts (u), oben (v) von außen gesehen
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
	[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
]


## Unterseiten, die höchstens so hoch liegen (lokal zum Bauteil), liegen auf dem Boden und
## werden weggelassen. Alles darüber (Decken, Dächer, Vordächer, Podeste) bekommt eine Unterseite.
const GROUND_SKIP := 0.05


## Box mit beliebiger Lage. uv_tiles: 0 = jede Seite 0..1 (Kisten), sonst Meter pro UV-Kachel.
## skip_bottom: Unterseite weglassen, wenn sie auf dem Boden liegt (siehe GROUND_SKIP).
func box_x(xform: Transform3D, size: Vector3, mat: Material, collide := true, shadow := true,
		uv_tiles := 0.0, skip_bottom := true, resting := false) -> void:
	var st := _tool(mat, shadow)
	var h := size * 0.5
	for f: Array in _FACES:
		var n: Vector3 = f[0]
		if n == Vector3.DOWN and (resting or (skip_bottom and (xform * (n * h.y)).y <= GROUND_SKIP)):
			continue
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var hn := absf(n.dot(h))
		var hu := absf(u.dot(h))
		var hv := absf(v.dot(h))
		var c := n * hn
		var a := xform * (c - u * hu + v * hv)
		var b := xform * (c + u * hu + v * hv)
		var cc := xform * (c + u * hu - v * hv)
		var d := xform * (c - u * hu - v * hv)
		var wn := (xform.basis * n).normalized()
		var uv_max := Vector2.ONE
		if uv_tiles > 0.0:
			uv_max = Vector2(hu * 2.0, hv * 2.0) / uv_tiles
		_face(st, a, b, cc, d, wn, Vector2(0, 0), Vector2(uv_max.x, 0), uv_max, Vector2(0, uv_max.y))
	if collide:
		collider_x(xform, size)


## Achsparallele Box (center = Mittelpunkt). rot_y in Grad dreht um die eigene Mitte.
func box(center: Vector3, size: Vector3, mat: Material, collide := true, shadow := true,
		rot_y := 0.0, uv_tiles := 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)), center)
	box_x(xf, size, mat, collide, shadow, uv_tiles)


## Box, die auf einer anderen aufliegt (Obergeschoss, Dachhaut, Brüstung): ohne Unterseite, die läge
## verdeckt in derselben Ebene wie die Oberseite darunter.
func box_on(center: Vector3, size: Vector3, mat: Material, collide := true, shadow := true) -> void:
	box_x(Transform3D(Basis.IDENTITY, center), size, mat, collide, shadow, 0.0, true, true)


## Box zwischen zwei Ecken (min/max), praktisch für Wände und Böden.
func box_mm(from: Vector3, to: Vector3, mat: Material, collide := true, shadow := true) -> void:
	var lo := from.min(to)
	var hi := from.max(to)
	box((lo + hi) * 0.5, hi - lo, mat, collide, shadow)


## Detail-Quad in der XY-Ebene von xform, schaut nach +Z von xform. Keine Kollision, kein Schatten.
func quad_x(xform: Transform3D, w: float, h: float, mat: Material, uv_rect := Rect2(0, 0, 1, 1),
		shadow := false) -> void:
	var st := _tool(mat, shadow)
	var hw := w * 0.5
	var hh := h * 0.5
	var a := xform * Vector3(-hw, hh, 0)
	var b := xform * Vector3(hw, hh, 0)
	var c := xform * Vector3(hw, -hh, 0)
	var d := xform * Vector3(-hw, -hh, 0)
	var n := (xform.basis * Vector3.BACK).normalized()
	var p := uv_rect.position
	var e := uv_rect.end
	_face(st, a, b, c, d, n, p, Vector2(e.x, p.y), e, Vector2(p.x, e.y))


## Quad an einer Wand. normal zeigt aus der Wand heraus (nur waagerechte Richtungen oder UP).
func quad(center: Vector3, normal: Vector3, w: float, h: float, mat: Material, uv_rect := Rect2(0, 0, 1, 1)) -> void:
	quad_x(facing(center, normal), w, h, mat, uv_rect)


## Transform, dessen +Z in Richtung normal zeigt (für Quads und Wandteile).
static func facing(center: Vector3, normal: Vector3) -> Transform3D:
	var z := normal.normalized()
	var up := Vector3.UP if absf(z.y) < 0.99 else Vector3.FORWARD
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	return Transform3D(Basis(x, y, z), center)


## Zylinder entlang der lokalen Y-Achse von xform (PS1: wenige Segmente).
func cylinder_x(xform: Transform3D, radius: float, height: float, mat: Material, segments := 8,
		collide := false, shadow := true, caps := true) -> void:
	var st := _tool(mat, shadow)
	var hh := height * 0.5
	for i: int in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := Vector3(cos(a1), 0, sin(a1)) * radius
		var nm := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		var u0 := float(i) / segments
		var u1 := float(i + 1) / segments
		_face(st, xform * (p1 + Vector3.UP * hh), xform * (p0 + Vector3.UP * hh),
				xform * (p0 - Vector3.UP * hh), xform * (p1 - Vector3.UP * hh),
				(xform.basis * nm).normalized(), Vector2(u1, 0), Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1))
		if caps:
			var top := xform * (Vector3.UP * hh)
			var tn := (xform.basis * Vector3.UP).normalized()
			st.set_normal(tn)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(top)
			st.set_uv(Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5))
			st.add_vertex(xform * (p0 + Vector3.UP * hh))
			st.set_uv(Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5))
			st.add_vertex(xform * (p1 + Vector3.UP * hh))
	if collide:
		var r2 := radius * 1.6
		collider_x(xform, Vector3(r2, height, r2))


## Senkrechter Zylinder, base = Mitte der Unterseite.
func cylinder(base: Vector3, radius: float, height: float, mat: Material, segments := 8, collide := false) -> void:
	cylinder_x(Transform3D(Basis.IDENTITY, base + Vector3.UP * height * 0.5), radius, height, mat, segments, collide)


## Rohr/Stange von a nach b.
func tube(a: Vector3, b: Vector3, radius: float, mat: Material, segments := 6, shadow := true) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.001:
		return
	var y := dir / length
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	cylinder_x(Transform3D(Basis(x, y, z), (a + b) * 0.5), radius, length, mat, segments, false, shadow, false)


## Durchhängendes Kabel zwischen a und b (sag = Durchhang in Metern).
func cable(a: Vector3, b: Vector3, sag: float, mat: Material, radius := 0.02, pieces := 8) -> void:
	var prev := a
	for i: int in range(1, pieces + 1):
		var t := float(i) / pieces
		var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		tube(prev, p, radius, mat, 4, false)
		prev = p


## Nur Kollision (unsichtbar), z. B. Rampen unter Treppen oder Grenzwände.
func collider_x(xform: Transform3D, size: Vector3) -> void:
	if _body == null:
		_body = StaticBody3D.new()
		_body.name = "Collision"
		_body.collision_layer = collision_layer
		_body.collision_mask = 0
		root.add_child(_body)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.transform = xform
	_body.add_child(shape)


func collider(center: Vector3, size: Vector3, rot_y := 0.0) -> void:
	collider_x(Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)), center), size)


## Treppe: Stufen von start in Richtung dir (waagerecht), jede Stufe rise hoch und run tief.
## Gibt die Oberkante der letzten Stufe zurück. Die Stufen sind echte Boxen (Stufe für Stufe begehbar).
func stairs(start: Vector3, dir: Vector3, steps: int, width: float, mat: Material,
		rise := 0.2, run := 0.3, solid := false, side_mat: Material = null) -> Vector3:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var yaw := atan2(d.x, d.z)
	var basis := Basis(Vector3.UP, yaw)
	for i: int in steps:
		var top := start.y + rise * (i + 1)
		var h := top - start.y if solid else minf(rise * 1.0, top - start.y)
		var center := start + d * (run * (i + 0.5)) + Vector3.UP * (top - h * 0.5 - start.y)
		box_x(Transform3D(basis, center), Vector3(width, h, run), mat)
	if side_mat != null and not solid:
		# Wangen links und rechts als schräge Träger
		var length := run * steps
		var height := rise * steps
		var slope := atan2(height, length)
		for side: float in [-1.0, 1.0]:
			var mid := start + d * (length * 0.5) + basis.x * side * (width * 0.5 + 0.04) + Vector3.UP * (height * 0.5 - 0.1)
			var b := basis * Basis(Vector3.RIGHT, -slope)
			box_x(Transform3D(b, mid), Vector3(0.06, 0.22, sqrt(length * length + height * height)), side_mat, false)
	return start + d * (run * steps) + Vector3.UP * (rise * steps)


## Geländer entlang einer Linie (Pfosten + Handlauf), mit Kollision bis Hüfthöhe.
func railing(a: Vector3, b: Vector3, mat: Material, height := 1.0, post_spacing := 1.2, collide := true) -> void:
	var length := a.distance_to(b)
	var posts := maxi(1, int(ceil(length / post_spacing)))
	for i: int in posts + 1:
		var p := a.lerp(b, float(i) / posts)
		tube(p, p + Vector3.UP * height, 0.025, mat, 4)
	tube(a + Vector3.UP * height, b + Vector3.UP * height, 0.03, mat, 4)
	tube(a + Vector3.UP * height * 0.5, b + Vector3.UP * height * 0.5, 0.02, mat, 4)
	if collide:
		var dir := (b - a)
		var yaw := atan2(dir.x, dir.z)
		collider_x(Transform3D(Basis(Vector3.UP, yaw), (a + b) * 0.5 + Vector3.UP * height * 0.5),
				Vector3(0.08, height, length))


## Baut die Meshes. Danach ist der Builder leer und kann weiterbenutzt werden.
func finish() -> void:
	_commit(_solid, "Mesh", GeometryInstance3D.SHADOW_CASTING_SETTING_ON, solid_range)
	_commit(_flat, "Details", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, detail_range)
	_solid.clear()
	_flat.clear()
	_body = null


func _commit(table: Dictionary, node_name: String, shadow: GeometryInstance3D.ShadowCastingSetting,
		visible_range := 0.0) -> void:
	if table.is_empty():
		return
	var mesh := ArrayMesh.new()
	for mat: Material in table:
		var st: SurfaceTool = table[mat]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = shadow
	if visible_range > 0.0:
		mi.visibility_range_end = visible_range
		mi.visibility_range_end_margin = 8.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	root.add_child(mi)
