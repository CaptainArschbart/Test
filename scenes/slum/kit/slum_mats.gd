@tool
class_name SlumMats
extends RefCounted
## Materialbibliothek des Slum-Mapkits. Alle Materialien werden einmal erzeugt und geteilt.
##
## Flächen (Wände, Böden, Dächer) nutzen Welt-Triplanar-Mapping: Die Textur kachelt in Metern,
## egal wie groß eine Box ist, und braucht keine UVs. Details (Fenster, Türen, Schilder) sind
## Quads mit UV 0..1 und Alpha. Alles mit Nearest-Filter für den PS1/PS2-Look.
## Texturen liegen in assets/textures/slum/ und kommen aus tools/gen_slum_textures.py.

const TEX_DIR := "res://assets/textures/slum/"

## Meter pro Kachel, wenn ein Name hier nicht steht, gilt 2 m.
const TILE_METERS := {
	"asphalt": 6.0, "asphalt_old": 6.0, "sidewalk": 3.0, "sidewalk_small": 2.0, "curb": 1.0,
	"brick": 1.0, "brick_dark": 1.0, "concrete": 3.0, "concrete_dark": 3.0, "concrete_green": 3.0,
	"corrugated_blue": 2.0, "corrugated_rust": 2.0, "corrugated_grey": 2.0, "corrugated_green": 2.0,
	"plaster": 2.5, "plaster_teal": 2.5, "plaster_pink": 2.5, "shutter": 1.5, "tiles_dark": 1.0,
	"tiles_white": 1.0, "wood": 1.2, "wood_dark": 1.2, "metal_plate": 1.0, "roof_tar": 3.0,
	"rust": 1.5, "tarp_blue": 2.0, "tarp_red": 2.0, "hazard": 0.6, "red_white": 0.6,
}

static var _cache := {}


static func texture(tex_name: String) -> Texture2D:
	var path := TEX_DIR + tex_name + ".png"
	if not ResourceLoader.exists(path):
		push_warning("SlumMats: Textur fehlt: " + path)
		return null
	return load(path)


## Wand/Boden/Dach mit Welt-Triplanar. tint färbt die Textur ein (z. B. dunkler für Schatten-Varianten).
static func surface(tex_name: String, tint := Color.WHITE, roughness := 0.9) -> StandardMaterial3D:
	var key := "s|%s|%s|%s" % [tex_name, tint.to_html(), roughness]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture(tex_name)
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_triplanar_sharpness = 6.0
	mat.uv1_scale = Vector3.ONE / float(TILE_METERS.get(tex_name, 2.0))
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_cache[key] = mat
	return mat


## Nasse Fläche (Asphalt, Gehweg): weniger rau, damit Lampen und Neon spiegeln.
static func wet(tex_name: String, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "w|%s|%s" % [tex_name, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var mat := surface(tex_name, tint).duplicate() as StandardMaterial3D
	mat.roughness = 0.35
	mat.metallic_specular = 0.7
	_cache[key] = mat
	return mat


## Props mit UVs je Seite (Kisten, Container, Tonnen). Die ganze Textur liegt auf jeder Seite.
static func uv(tex_name: String, tint := Color.WHITE, roughness := 0.85) -> StandardMaterial3D:
	var key := "u|%s|%s|%s" % [tex_name, tint.to_html(), roughness]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture(tex_name)
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_cache[key] = mat
	return mat


## Detail-Quad mit Alpha (Fenster, Tür, Graffiti). Mit emit_name leuchtet die Maske in emit_color.
static func decal(tex_name: String, emit_name := "", emit_color := Color.BLACK, energy := 1.0) -> StandardMaterial3D:
	var key := "d|%s|%s|%s|%s" % [tex_name, emit_name, emit_color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture(tex_name)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.roughness = 0.8
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if emit_name != "":
		mat.emission_enabled = true
		mat.emission = emit_color
		mat.emission_texture = texture(emit_name)
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mat.emission_energy_multiplier = energy
	_cache[key] = mat
	return mat


## Leuchtschild: Tafel aus tex_name, Schrift leuchtet über tex_name + "_emit".
static func sign_mat(tex_name: String, energy := 3.0) -> StandardMaterial3D:
	var key := "n|%s|%s" % [tex_name, energy]
	if _cache.has(key):
		return _cache[key]
	var mat := decal(tex_name).duplicate() as StandardMaterial3D
	var emit := TEX_DIR + tex_name + "_emit.png"
	if ResourceLoader.exists(emit):
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_texture = load(emit)
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mat.emission_energy_multiplier = energy
	_cache[key] = mat
	return mat


## Einfarbig, optional leuchtend (Neonröhren, Lampenschirme, Kabel).
static func color(c: Color, emission := 0.0, roughness := 0.7, metallic := 0.0) -> StandardMaterial3D:
	var key := "c|%s|%s|%s|%s" % [c.to_html(), emission, roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = roughness
	mat.metallic = metallic
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = emission
	_cache[key] = mat
	return mat
