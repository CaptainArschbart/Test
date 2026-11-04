extends SceneTree
## Überträgt Animationen der Universal Animation Library 1 und 2 (assets/animations/quaternius_ual*)
## auf das Skelett der Modular-Men-Figuren (assets/characters/quaternius_modular_men/) und speichert
## sie als AnimationLibrary. Läuft headless:
##   godot --headless --path . -s res://tools/retarget_ual.gd
## Schreibt assets/animations/retargeted/ual_mm.res (Männer, Modular Men) und ual_mw.res (Frauen aus dem
## City Pack, gleiches Skelett, andere Proportionen). Figuren hängen die passende als Bibliothek "ual"
## an ihren AnimationPlayer (UalLibrary.attach) und spielen z. B. "ual/LayToIdle".
##
## Verfahren: Beide Skelette stehen in ihrer Referenz in T-Pose (UAL: Ruhelage, MM: Bindungspose der
## Haut; die MM-Ruhelage ist eine schiefe Zwischenpose und taugt nicht). Je Knochenpaar gilt
##   MM_global = UAL_global * Versatz,  Versatz = UAL_ref⁻¹ * MM_ref  (nur Drehung).
## Knochenlängen bleiben die der MM-Figur. Das Becken (Body) folgt der UAL-Hüfte, skaliert mit dem
## Verhältnis der Beinlängen. Die Füße hängen bei MM als IK-Knochen am Root; sie werden ans Ende des
## Unterschenkels gesetzt. Knochen ohne Partner (Mittelhand, Pol-Ziele, Root) behalten die Bindungslage.

## Je Ausgabe die Figur, deren Bindungspose und Haut zählen. Die Bindungspose ist bei allen MM-Männern
## gleich, ebenso bei den beiden Frauen. Casual Character hat keine abstehenden Haare, die beim Liegen
## den Bodenausgleich verfälschen würden.
const TARGETS := {
	"res://assets/animations/retargeted/ual_mm.res": "res://assets/characters/quaternius_modular_men/Casual Character.glb",
	"res://assets/animations/retargeted/ual_mw.res": "res://assets/props/city_pack/Animated Woman-nIItLV9nxS.glb",
}
const SOURCES := {
	"ual1": "res://assets/animations/quaternius_ual1/UAL1_Standard.glb",
	"ual2": "res://assets/animations/quaternius_ual2/UAL2_Standard.glb",
}
const TRACK_PREFIX := "RootNode/CharacterArmature/Skeleton3D:"
const FPS := 30.0

## [Quelle, Name, Schleife]. Auswahl nach Schedule 1: Bewegung (P5-7), Treffer und Aufstehen (P5-2,
## P5-6), Pistole (P4-6), Sitzen, Essen, Reden, Tragen (P2-5, P2-6, P3-5, P5-8).
const ANIMS := [
	["ual1", "Idle", true], ["ual1", "Walk", true], ["ual1", "Jog_Fwd", true], ["ual1", "Sprint", true],
	["ual1", "Crouch_Idle", true], ["ual1", "Crouch_Fwd", true],
	["ual1", "Jump_Start", false], ["ual1", "Jump", true], ["ual1", "Jump_Land", false],
	["ual1", "Hit_Chest", false], ["ual1", "Hit_Head", false], ["ual1", "Death01", false],
	["ual1", "Pistol_Idle", true], ["ual1", "Pistol_Aim_Neutral", true], ["ual1", "Pistol_Aim_Up", true],
	["ual1", "Pistol_Aim_Down", true], ["ual1", "Pistol_Shoot", false], ["ual1", "Pistol_Reload", false],
	["ual1", "Sitting_Enter", false], ["ual1", "Sitting_Idle", true], ["ual1", "Sitting_Talking", true],
	["ual1", "Sitting_Exit", false], ["ual1", "Idle_Talking", true], ["ual1", "Interact", false],
	["ual1", "PickUp_Table", false],
	["ual2", "LayToIdle", false], ["ual2", "Hit_Knockback", false], ["ual2", "Consume", false],
	["ual2", "Idle_TalkingPhone", true], ["ual2", "Walk_Carry", true], ["ual2", "Idle_FoldArms", true],
	["ual2", "Idle_Rail", true],
]

## MM-Knochen -> [UAL1, UAL2].
const MAP := {
	"Body": ["DEF-hips", "pelvis"], "Hips": ["DEF-hips", "pelvis"],
	"Abdomen": ["DEF-spine.001", "spine_01"], "Torso": ["DEF-spine.002", "spine_02"],
	"Chest": ["DEF-spine.003", "spine_03"], "Neck": ["DEF-neck", "neck_01"], "Head": ["DEF-head", "Head"],
	"Shoulder.L": ["DEF-shoulder.L", "clavicle_l"], "UpperArm.L": ["DEF-upper_arm.L", "upperarm_l"],
	"LowerArm.L": ["DEF-forearm.L", "lowerarm_l"], "Wrist.L": ["DEF-hand.L", "hand_l"],
	"Shoulder.R": ["DEF-shoulder.R", "clavicle_r"], "UpperArm.R": ["DEF-upper_arm.R", "upperarm_r"],
	"LowerArm.R": ["DEF-forearm.R", "lowerarm_r"], "Wrist.R": ["DEF-hand.R", "hand_r"],
	"UpperLeg.L": ["DEF-thigh.L", "thigh_l"], "LowerLeg.L": ["DEF-shin.L", "calf_l"],
	"Foot.L": ["DEF-foot.L", "foot_l"],
	"UpperLeg.R": ["DEF-thigh.R", "thigh_r"], "LowerLeg.R": ["DEF-shin.R", "calf_r"],
	"Foot.R": ["DEF-foot.R", "foot_r"],
}
const FINGERS := ["index", "middle", "ring", "pinky"]
## Becken und Füße bekommen eine Positionsspur je Bild, alle anderen eine feste.
const MOVING := ["Body", "Foot.L", "Foot.R"]
## Animationen am Boden: Die MM-Figur ist anders gebaut als die UAL-Puppe (und schon die Puppe liegt
## in LayToIdle 8 cm im Boden). Hier wird das Becken je Bild so weit angehoben, dass die Haut nicht
## unter y = 0 kommt.
const GROUND_FIX := ["LayToIdle", "Death01", "Hit_Knockback"]
## Jeder wievielte Hautpunkt für den Bodenausgleich zählt.
const GROUND_STRIDE := 2


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := _full_map()
	var sources := {}
	for key: String in SOURCES:
		sources[key] = _source_info(load(SOURCES[key]) as PackedScene)
	var failed := false
	for out: String in TARGETS:
		var target := _target_info(TARGETS[out])
		var library := AnimationLibrary.new()
		for entry: Array in ANIMS:
			var src: Dictionary = sources[entry[0]]
			var col := 0 if entry[0] == "ual1" else 1
			var anim := _retarget(src, target, map, col, entry[1], entry[2])
			if anim == null:
				push_error("Animation fehlt: %s/%s" % [entry[0], entry[1]])
				continue
			library.add_animation(entry[1], anim)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
		var err := ResourceSaver.save(library, out, ResourceSaver.FLAG_COMPRESS)
		failed = failed or err != OK
		print("RETARGET %d -> %s (%s)" % [library.get_animation_list().size(), out, error_string(err)])
	quit(1 if failed else 0)


## MAP plus Finger: MM Index2..4 <- index.01..03, Thumb1..3 <- thumb.01..03; Index1 (Mittelhand) bleibt.
func _full_map() -> Dictionary:
	var out := MAP.duplicate()
	for side in ["L", "R"]:
		var s: String = side.to_lower()
		for f: String in FINGERS:
			for i in 3:
				out["%s%d.%s" % [f.capitalize(), i + 2, side]] = [
					"DEF-f_%s.%02d.%s" % [f, i + 1, side], "%s_%02d_%s" % [f, i + 1, s]]
		for i in 3:
			out["Thumb%d.%s" % [i + 1, side]] = ["DEF-thumb.%02d.%s" % [i + 1, side], "thumb_%02d_%s" % [i + 1, s]]
	return out


## Zielskelett: Bindungspose (Skelettraum), Eltern, Lage des Skeletts in der Szene.
func _target_info(path: String) -> Dictionary:
	var body: Node3D = (load(path) as PackedScene).instantiate()
	var sk := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var skin: Skin = null
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null:
			skin = mi.skin
			break
	var ref := {}
	for i in skin.get_bind_count():
		var name := skin.get_bind_name(i)
		var bone := sk.find_bone(name) if name != "" else skin.get_bind_bone(i)
		ref[bone] = skin.get_bind_pose(i).affine_inverse()
	var info := {
		"names": [], "parents": [], "ref": [], "skin": [],
		# Lage des Skeletts relativ zur Szenenwurzel (CharacterArmature: 100-fach, -90° um X).
		"scene": _chain(sk, body),
	}
	# Haut für den Bodenausgleich: je Fläche Punkte, Knochen (Skelett-Index) und Gewichte.
	for mi: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null:
			continue
		var binds := []
		for i in mi.skin.get_bind_count():
			var bn := mi.skin.get_bind_name(i)
			binds.append([sk.find_bone(bn) if bn != "" else mi.skin.get_bind_bone(i), mi.skin.get_bind_pose(i)])
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			info.skin.append({"binds": binds, "verts": arr[Mesh.ARRAY_VERTEX], "bones": arr[Mesh.ARRAY_BONES],
				"weights": arr[Mesh.ARRAY_WEIGHTS]})
	for b in sk.get_bone_count():
		info.names.append(sk.get_bone_name(b))
		info.parents.append(sk.get_bone_parent(b))
		info.ref.append(ref.get(b, sk.get_bone_global_rest(b)))
	body.free()
	return info


## Quelle: Ruhelage, Eltern, Animationen.
func _source_info(scene: PackedScene) -> Dictionary:
	var body: Node3D = scene.instantiate()
	var sk := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var ap := body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var info := {"index": {}, "names": [], "parents": [], "rest": [], "anims": {},
		"path": str(ap.get_node(ap.root_node).get_path_to(sk)), "scene": _chain(sk, body)}
	for b in sk.get_bone_count():
		info.index[sk.get_bone_name(b)] = b
		info.names.append(sk.get_bone_name(b))
		info.parents.append(sk.get_bone_parent(b))
		info.rest.append(sk.get_bone_rest(b))
	for name in ap.get_animation_list():
		info.anims[name] = ap.get_animation(name)
	body.free()
	return info


func _chain(node: Node, top: Node) -> Transform3D:
	var t := Transform3D()
	var n := node
	while n != null and n != top:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## Spuren je Quellknochen: [Drehung, Position] (-1 = keine).
func _tracks(src: Dictionary, anim: Animation) -> Array:
	var out := []
	for name: String in src.names:
		var path := NodePath("%s:%s" % [src.path, name])
		out.append([anim.find_track(path, Animation.TYPE_ROTATION_3D), anim.find_track(path, Animation.TYPE_POSITION_3D)])
	return out


## Globale Lagen (Szenenraum, Meter) aller Quellknochen zur Zeit t, ohne Animation = Ruhelage.
func _source_globals(src: Dictionary, anim: Animation, tracks: Array, t: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var count: int = src.parents.size()
	out.resize(count)
	for b in count:
		var local: Transform3D = src.rest[b]
		if anim != null:
			var rot := local.basis.get_rotation_quaternion()
			var pos := local.origin
			if tracks[b][0] >= 0:
				rot = anim.rotation_track_interpolate(tracks[b][0], t)
			if tracks[b][1] >= 0:
				pos = anim.position_track_interpolate(tracks[b][1], t)
			local = Transform3D(Basis(rot), pos)
		var parent: int = src.parents[b]
		out[b] = (out[parent] if parent >= 0 else src.scene) * local
	return out


func _retarget(src: Dictionary, tgt: Dictionary, map: Dictionary, col: int, name: String, loop: bool) -> Animation:
	if not src.anims.has(name):
		return null
	var source: Animation = src.anims[name]
	var src_of := {}
	for b in tgt.names.size():
		var tn: String = tgt.names[b]
		if map.has(tn) and src.index.has(map[tn][col]):
			src_of[b] = src.index[map[tn][col]]
	var scene: Transform3D = tgt.scene
	var scene_rot := scene.basis.orthonormalized()
	var to_skel := scene.affine_inverse()
	var ref_src := _source_globals(src, null, [], 0.0)
	# Versätze und feste Größen aus beiden T-Posen.
	var offset := {}
	for b: int in src_of:
		var s_ref := scene_rot.inverse() * ref_src[src_of[b]].basis.orthonormalized()
		offset[b] = (s_ref.inverse() * (tgt.ref[b] as Transform3D).basis.orthonormalized()).orthonormalized()
	var body: int = tgt.names.find("Body")
	var hips_src: int = src_of[body]
	var leg_t: int = tgt.names.find("UpperLeg.L")
	var leg_s: int = src_of[leg_t]
	# Höhe des Hüftgelenks über dem Boden (Meter) in beiden Figuren.
	var k := (scene * (tgt.ref[leg_t] as Transform3D)).origin.y / ref_src[leg_s].origin.y
	var body_ref: Transform3D = tgt.ref[body]
	var hips_ref_skel := to_skel * ref_src[hips_src].origin
	var body_c := body_ref.basis.orthonormalized().inverse() * (body_ref.origin - hips_ref_skel * k)
	var bind_local := []
	for b in tgt.names.size():
		var p: int = tgt.parents[b]
		bind_local.append(((tgt.ref[p] as Transform3D).affine_inverse() if p >= 0 else Transform3D()) * (tgt.ref[b] as Transform3D))
	var foot_of := {}
	for side in ["L", "R"]:
		var foot: int = tgt.names.find("Foot." + side)
		var low: int = tgt.names.find("LowerLeg." + side)
		var low_ref: Transform3D = tgt.ref[low]
		foot_of[foot] = [low, low_ref.basis.orthonormalized().inverse() * ((tgt.ref[foot] as Transform3D).origin - low_ref.origin)]

	var anim := Animation.new()
	var frames := maxi(int(ceil(source.length * FPS)), 1)
	anim.length = source.length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var rot_tracks := {}
	var pos_tracks := {}
	for b in tgt.names.size():
		var path := NodePath(TRACK_PREFIX + tgt.names[b])
		var rt := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rt, path)
		rot_tracks[b] = rt
		var pt := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pt, path)
		pos_tracks[b] = pt
		var bl: Transform3D = bind_local[b]
		if not src_of.has(b):
			anim.rotation_track_insert_key(rt, 0.0, bl.basis.get_rotation_quaternion())
		if not MOVING.has(tgt.names[b]):
			anim.position_track_insert_key(pt, 0.0, bl.origin)
	var last_q := {}
	var tracks := _tracks(src, source)
	for f in frames + 1:
		var t := minf(f / FPS, source.length)
		var sg := _source_globals(src, source, tracks, t)
		var glob := _frame(tgt, src_of, offset, bind_local, foot_of, sg, scene_rot, body,
			(to_skel * sg[hips_src].origin) * k, body_c, Vector3.ZERO)
		if GROUND_FIX.has(name):
			var low := _lowest(tgt, glob)
			if low < 0.0:
				glob = _frame(tgt, src_of, offset, bind_local, foot_of, sg, scene_rot, body,
					(to_skel * sg[hips_src].origin) * k, body_c, to_skel.basis * Vector3(0.0, -low, 0.0))
		for b in tgt.names.size():
			var p: int = tgt.parents[b]
			var local: Transform3D = (glob[p].affine_inverse() if p >= 0 else Transform3D()) * glob[b]
			if src_of.has(b):
				var q := local.basis.get_rotation_quaternion()
				if last_q.has(b) and (last_q[b] as Quaternion).dot(q) < 0.0:
					q = -q
				last_q[b] = q
				anim.rotation_track_insert_key(rot_tracks[b], t, q)
			if MOVING.has(tgt.names[b]):
				anim.position_track_insert_key(pos_tracks[b], t, local.origin)
	return anim


## Globale Lagen (Skelettraum) aller MM-Knochen für ein Bild; lift hebt das Becken (Skelettraum).
func _frame(tgt: Dictionary, src_of: Dictionary, offset: Dictionary, bind_local: Array, foot_of: Dictionary,
		sg: Array[Transform3D], scene_rot: Basis, body: int, body_pos: Vector3, body_c: Vector3,
		lift: Vector3) -> Array[Transform3D]:
	var glob: Array[Transform3D] = []
	glob.resize(tgt.names.size())
	for b in tgt.names.size():
		var p: int = tgt.parents[b]
		var parent: Transform3D = glob[p] if p >= 0 else Transform3D()
		var g: Transform3D
		if src_of.has(b):
			var rot := (scene_rot.inverse() * sg[src_of[b]].basis.orthonormalized()) * (offset[b] as Basis)
			g = Transform3D(rot.orthonormalized(), (parent * (bind_local[b] as Transform3D)).origin)
		else:
			g = parent * (bind_local[b] as Transform3D)
		if b == body:
			g.origin = body_pos + g.basis * body_c + lift
		elif foot_of.has(b):
			var low: int = foot_of[b][0]
			g.origin = glob[low].origin + glob[low].basis * (foot_of[b][1] as Vector3)
		glob[b] = g
	return glob


## Tiefster Hautpunkt (Meter über dem Boden der Figur) in dieser Pose.
func _lowest(tgt: Dictionary, glob: Array[Transform3D]) -> float:
	var scene: Transform3D = tgt.scene
	var low := INF
	for part: Dictionary in tgt.skin:
		var mats: Array[Transform3D] = []
		for bind: Array in part.binds:
			mats.append(scene * glob[bind[0]] * (bind[1] as Transform3D))
		var verts: PackedVector3Array = part.verts
		var bones: PackedInt32Array = part.bones
		var weights: PackedFloat32Array = part.weights
		var per := bones.size() / verts.size()
		for v in range(0, verts.size(), GROUND_STRIDE):
			var y := 0.0
			for j in per:
				var w := weights[v * per + j]
				if w > 0.0:
					y += (mats[bones[v * per + j]] * verts[v]).y * w
			low = minf(low, y)
	return low
