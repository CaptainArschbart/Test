extends SceneTree
## Rendert für jedes Item unter scenes/items/data/ sein 3D-Modell (ItemDisplay) als Inventar-Icon.
##
## Aufruf (Projektordner, mit Fenster, headless rendert nicht):
##   godot --path . -s res://tools/gen_item_icons.gd
## Schreibt assets/icons/items/<id>.png. Danach einmal `godot --headless --path . --import` und
##   ICONS_APPLY=1 godot --headless --path . -s res://tools/gen_item_icons.gd
## trägt die Bilder als ItemData.icon in die .tres ein.
## ICONS_OUT=/pfad schreibt die Bilder woandershin (zum Ansehen), ICONS_SHEET=1 legt dort
## zusätzlich sheet.png mit allen Icons auf Slot-Hintergrund an.

const DATA_DIR := "res://scenes/items/data"
const OUT_DIR := "res://assets/icons/items"
const SIZE := 256
## Blickrichtung auf das Modell: leicht von oben und schräg vorn.
const VIEW_DIR := Vector3(0.55, 0.42, 1.0)
## Waffen zeigen mit dem Lauf nach links oben (-Z ist vorn), Items stehen aufrecht.
const WEAPON_YAW := 90.0
const WEAPON_TILT := 24.0
## Lange, dünne Items (+Y ist die Längsachse) liegen schräg im Bild, damit sie das Quadrat füllen.
const LONG_ROLL := -42.0
## So viel länger als breit gilt ein Item als lang.
const LONG_RATIO := 2.0
## Rand um die Silhouette (Anteil der Bildgröße), lässt Platz für die Kontur.
const MARGIN := 1.18
## Erst zur Laufzeit laden: ItemDisplay zieht Skripte nach, die Autoloads brauchen.
const DISPLAY_PATH := "res://scenes/items/item_display.gd"
## Breite der Neon-Kontur in Pixeln (bei SIZE) und ihre Deckkraft.
const OUTLINE_PX := 6
const OUTLINE_ALPHA := 0.75


func _initialize() -> void:
	_run.call_deferred()


func _items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for f in DirAccess.get_files_at(DATA_DIR):
		if f.get_extension() == "tres":
			var item := load(DATA_DIR.path_join(f)) as ItemData
			if item != null and not item.is_currency:
				out.append(item)
	return out


func _run() -> void:
	if OS.get_environment("ICONS_APPLY") == "1":
		_apply()
		return
	var out := OS.get_environment("ICONS_OUT")
	if out == "":
		out = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)

	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	_setup_stage(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)

	var display: Script = load(DISPLAY_PATH)
	var images: Dictionary = {}
	for item in _items():
		var model: Node3D = display.call("build", item)
		if model == null:
			print("  skip %s (kein Modell)" % item.id)
			continue
		var pivot := Node3D.new()
		vp.add_child(pivot)
		pivot.add_child(model)
		if item is WeaponData:
			pivot.rotation_degrees = Vector3(WEAPON_TILT, WEAPON_YAW, 0.0)
		else:
			var size := _bounds(pivot).size
			if size.y > LONG_RATIO * maxf(size.x, size.z):
				pivot.rotation_degrees.z = LONG_ROLL
		_frame(cam, pivot)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := _outline(vp.get_texture().get_image(), item.color)
		img.save_png(out.path_join(item.id + ".png"))
		images[item.id] = img
		print("  icon %s" % item.id)
		pivot.queue_free()
		await process_frame
	if OS.get_environment("ICONS_SHEET") == "1":
		_sheet(images, out)
	print("ICONS %d" % images.size())
	quit(0)


func _setup_stage(vp: SubViewport) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.65)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	# Hauptlicht schräg von oben, kühles Gegenlicht von hinten (Neon-Kante).
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	key.light_energy = 1.4
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	rim.light_color = Color(0.4, 0.8, 1.0)
	rim.light_energy = 1.1
	vp.add_child(rim)


func _meshes(pivot: Node3D) -> Array[VisualInstance3D]:
	var out: Array[VisualInstance3D] = []
	for node in pivot.find_children("*", "VisualInstance3D", true, false):
		if node is Light3D or not (node as Node3D).is_visible_in_tree():
			continue
		out.append(node as VisualInstance3D)
	return out


## Hülle aller Meshes im Weltraum (Pivot schon gedreht).
func _bounds(pivot: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in _meshes(pivot):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Orthogonale Kamera so setzen, dass die Silhouette (Ecken aller Mesh-Hüllen, in Kamerasicht
## projiziert) das Bild mit etwas Rand füllt und mittig sitzt.
func _frame(cam: Camera3D, pivot: Node3D) -> void:
	var box := _bounds(pivot)
	var center := box.get_center()
	var dist := maxf(box.size.length(), 0.05) * 2.0
	cam.position = center + VIEW_DIR.normalized() * dist
	cam.look_at(center)
	var inv := cam.global_transform.affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for mi in _meshes(pivot):
		var local := mi.get_aabb()
		for i in 8:
			var p: Vector3 = inv * (mi.global_transform * local.get_endpoint(i))
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var mid := (lo + hi) * 0.5
	cam.position += cam.global_basis.x * mid.x + cam.global_basis.y * mid.y
	cam.size = maxf(hi.x - lo.x, hi.y - lo.y) * MARGIN
	cam.near = 0.01
	cam.far = dist * 4.0


## Neon-Kontur in der Item-Farbe um die Silhouette: Alpha OUTLINE_PX-mal um ein Pixel weiten,
## nach außen ausblenden und unter das Bild legen. Hält dunkle Modelle auf dem Slot lesbar.
func _outline(src: Image, color: Color) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var alpha := PackedFloat32Array()
	alpha.resize(w * h)
	for y in h:
		for x in w:
			alpha[y * w + x] = img.get_pixel(x, y).a
	var glow := alpha.duplicate()
	for step in OUTLINE_PX:
		var grown := glow.duplicate()
		var fade := 1.0 - float(step) / OUTLINE_PX
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var i := y * w + x
				var m := maxf(maxf(glow[i - 1], glow[i + 1]), maxf(glow[i - w], glow[i + w]))
				grown[i] = maxf(grown[i], m * fade if m > grown[i] else grown[i])
		glow = grown
	for y in h:
		for x in w:
			var i := y * w + x
			var halo := clampf(glow[i] - alpha[i], 0.0, 1.0) * OUTLINE_ALPHA
			if halo <= 0.0:
				continue
			var c := img.get_pixel(x, y)
			var back := Color(color.lightened(0.2), halo)
			img.set_pixel(x, y, back.blend(c))
	return img


func _sheet(images: Dictionary, out: String) -> void:
	var cell := 96
	var cols := 8
	var rows := ceili(images.size() / float(cols))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.02, 0.0, 0.06))
	var i := 0
	for id: String in images:
		var img: Image = images[id].duplicate()
		img.resize(cell - 16, cell - 16, Image.INTERPOLATE_LANCZOS)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % cols) * cell + 8, (i / cols) * cell + 8))
		i += 1
	sheet.save_png(out.path_join("sheet.png"))


## Trägt vorhandene Icons als ItemData.icon in die .tres ein.
## Schreibt nur zwei Zeilen in die Datei (ext_resource und `icon = …`), damit alle anderen Werte
## so stehen bleiben wie von Hand gesetzt. ResourceSaver würde Standardwerte weglassen.
func _apply() -> void:
	var n := 0
	for item in _items():
		var path := OUT_DIR.path_join(item.id + ".png")
		if not ResourceLoader.exists(path):
			continue
		var text := FileAccess.get_file_as_string(item.resource_path)
		if text.contains(path):
			n += 1
			continue
		var lines := text.split("\n")
		var ext_line := '[ext_resource type="Texture2D" path="%s" id="icon_item"]' % path
		var last_ext := -1
		for i in lines.size():
			if lines[i].begins_with("[ext_resource"):
				last_ext = i
		if last_ext >= 0:
			lines.insert(last_ext + 1, ext_line)
		else:
			# Ohne ext_resource: nach Kopfzeile und Leerzeile einfügen.
			lines.insert(1, "")
			lines.insert(2, ext_line)
		lines[0] = _bump_load_steps(lines[0])
		while lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "":
			lines.remove_at(lines.size() - 1)
		lines.append('icon = ExtResource("icon_item")')
		lines.append("")
		var file := FileAccess.open(item.resource_path, FileAccess.WRITE)
		file.store_string("\n".join(lines))
		file.close()
		n += 1
	print("APPLIED %d" % n)
	quit(0)


func _bump_load_steps(header: String) -> String:
	var rx := RegEx.create_from_string("load_steps=(\\d+)")
	var m := rx.search(header)
	if m == null:
		return header
	return header.replace(m.get_string(), "load_steps=%d" % (int(m.get_string(1)) + 1))
