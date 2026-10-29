class_name ProcMesh
extends RefCounted
## Einfache Formen für Modelle aus Code (Hände, Spielerkörper).
## Gleiche Maße liefern dasselbe Mesh, damit nichts doppelt im Speicher liegt.

static var _cache := {}


static func capsule(radius: float, height: float) -> Mesh:
	var key := "c%.4f_%.4f" % [radius, height]
	if not _cache.has(key):
		var mesh := CapsuleMesh.new()
		mesh.radius = radius
		mesh.height = maxf(height, radius * 2.0)
		mesh.radial_segments = 16
		mesh.rings = 6
		_cache[key] = mesh
	return _cache[key]


static func tube(top: float, bottom: float, height: float) -> Mesh:
	var key := "t%.4f_%.4f_%.4f" % [top, bottom, height]
	if not _cache.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = top
		mesh.bottom_radius = bottom
		mesh.height = height
		mesh.radial_segments = 24
		mesh.rings = 1
		_cache[key] = mesh
	return _cache[key]


## Abgerundeter Block (Superellipsoid). roundness 0 = Kiste, 1 = Ellipsoid.
## rings/segments: Auflösung (weniger für viele Figuren, z. B. Fußgänger).
static func rounded_box(size: Vector3, roundness: float, rings := 14, segments := 24) -> Mesh:
	var key := "b%s_%.3f_%d_%d" % [size, roundness, rings, segments]
	if _cache.has(key):
		return _cache[key]
	var e := clampf(roundness, 0.05, 1.0)
	var half := size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings + 1:
		var u := -PI * 0.5 + PI * i / rings
		for j in segments + 1:
			var v := -PI + TAU * j / segments
			var cu := spow(cos(u), e)
			var su := spow(sin(u), e)
			var cv := spow(cos(v), e)
			var sv := spow(sin(v), e)
			var p := Vector3(half.x * cu * cv, half.y * su, half.z * cu * sv)
			var nu := spow(cos(u), 2.0 - e)
			var nv := spow(cos(v), 2.0 - e)
			var n := Vector3(nu * nv / half.x, spow(sin(u), 2.0 - e) / half.y,
				nu * spow(sin(v), 2.0 - e) / half.z)
			if n.length_squared() < 1e-12:
				n = Vector3(0.0, signf(u), 0.0)
			st.set_normal(n.normalized())
			st.set_uv(Vector2(float(j) / segments, float(i) / rings))
			st.add_vertex(p)
	for i in rings:
		for j in segments:
			var a := i * (segments + 1) + j
			var b := a + segments + 1
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func spow(value: float, exponent: float) -> float:
	return signf(value) * pow(absf(value), exponent)
