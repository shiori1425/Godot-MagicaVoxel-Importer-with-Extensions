extends RefCounted
class_name VoxMaterial

const VOX_DEBUG_PRINT := false

# -------- helpers --------
static func _parse_float_str(s: String, dflt: float) -> float:
	var t := s.strip_edges()
	if t == "":
		return dflt
	var f := t.to_float()
	if f != 0.0:
		return f
	if t == "0" or t == "0.0":
		return 0.0
	return dflt

static func _prop_s(props: Dictionary, name: String, obj: Object, dflt: String) -> String:
	if props.has(name) and props[name] != null:
		return str(props[name])
	var v = obj.get(name)
	if v != null:
		return str(v)
	return dflt

static func _prop_f(props: Dictionary, name: String, obj: Object, dflt: float) -> float:
	if props.has(name):
		var v = props[name]
		var t := typeof(v)
		if t == TYPE_FLOAT: return v
		if t == TYPE_INT:   return v + 0.0
		if t == TYPE_STRING: return _parse_float_str(v, dflt)
	var v2 = obj.get(name)
	if v2 != null:
		var t2 := typeof(v2)
		if t2 == TYPE_FLOAT: return v2
		if t2 == TYPE_INT:   return v2 + 0.0
		if t2 == TYPE_STRING: return _parse_float_str(v2, dflt)
	return dflt

# -------- state --------
var properties: Dictionary = {}

func _init(props: Dictionary = {}) -> void:
	properties = props.duplicate(true) if typeof(props) == TYPE_DICTIONARY else {}

# ------- helpers ------
static func shared_vertex_color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	return m

static func material_for_palette(vox: Object, pi: int, color: Color) -> Material:
	var mat: Material = null
	# If VoxMaterial objects are stored on vox.materials[pi] and expose get_material(color)
	if vox != null and (vox.materials is Dictionary) and vox.materials.has(pi):
		var vmat = vox.materials[pi]
		if vmat != null and vmat.has_method("get_material"):
			mat = vmat.get_material(color)

	return mat if mat != null else shared_vertex_color_material()
	
# -------- main --------
func get_material(palette_color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true

	# Pull MATL dict (underscored keys per MV spec)
	var props: Dictionary = {}
	var maybe_props = get("properties")
	if typeof(maybe_props) == TYPE_DICTIONARY:
		props = maybe_props

	# Read values (string/int/float all accepted)
	var vtype   : String = _prop_s(props, "_type", self, "")
	var rough_v : float  = _prop_f(props, "_rough", self, 1.0)
	var spec_v  : float  = _prop_f(props, "_sp", self, -1.0)
	var alpha_v  : float  = _prop_f(props, "_alpha", self, -1.0)
	var trans_v  : float  = _prop_f(props, "_trans", self, -1.0)
	var weight_v: float  = _prop_f(props, "_weight", self, -1.0)
	var flux_v  : float  = _prop_f(props, "_flux", self, -1.0)
	var ior_v   : float  = _prop_f(props, "_ior", self, -1.0)
	var emit_v : float = _prop_f(props, "_emit", self, -1.0)
	var metal_v : float = float(props.get("_metal",-1.0))

	# Debug — confirms what we actually read
	var keys_str := str(props.keys()) if props.size() > 0 else "[]"
	if VOX_DEBUG_PRINT:
		print("[VoxMaterial 4.5] keys=", keys_str,
			" type=", vtype, " rough=", rough_v, " spec=", spec_v,
			" flux=", flux_v, " ior=", ior_v,
			" emit=", emit_v, " metal=", metal_v,
			" alpha=", alpha_v, " trans=", trans_v)

	# Baseline roughness
	mat.roughness = clamp(rough_v, 0.0, 1.0)

	match vtype:
		"_emit":
			mat.emission_enabled = true
			mat.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
			mat.emission = Color(palette_color.r, palette_color.g, palette_color.b)

			# Combine MV "Emission" (0..100) and "Radiant flux/Power" (≈1..5).
			# If both are present: scale flux by the normalized emission.
			# If only one is present: use whichever exists.
			var energy := -1.0
			if emit_v > 0.0 and flux_v > 0.0:
				energy = (emit_v) * flux_v
			elif emit_v >= 0.0:
				energy = emit_v
			elif flux_v >= 0.0:
				energy = flux_v

			if energy <= 0.0:
				energy = 1.0  # never leave zero in 4.x

			mat.emission_energy_multiplier = energy
			mat.metallic = 0.0

		# ---------- METAL ----------
		"_metal":
			# Metallic amount (weight), with sensible default
			var metallic_amount := metal_v
			if metallic_amount < 0.0:
				metallic_amount = 1.0
			mat.metallic = clamp(metallic_amount, 0.0, 1.0)

			# Roughness already set above; clamp again in case weight implied changes
			mat.roughness = clamp(rough_v, 0.0, 1.0)

			# Optional specular from VOX (0..1); otherwise keep Godot default
			if spec_v >= 0.0:
				mat.metallic_specular = clamp(spec_v, 0.0, 1.0)

		# ---------- GLASS ----------
		"_glass":
			# Transparent + refraction in 4.5
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.refraction_enabled = true

			# IOR -> refraction strength (heuristic scaling to Godot’s 0..1)
			var use_ior := ior_v
			if use_ior < 0.0:
				use_ior = 1.33
			var refr := (use_ior - 1.0) * 0.6
			if refr < 0.0:
				refr = 0.0
			if refr > 1.0:
				refr = 1.0
			mat.refraction_scale = refr

			# Glass shouldn’t be metallic; roughness from VOX if present
			mat.metallic = 0.0
			mat.roughness = clamp(rough_v, 0.0, 1.0)

			if alpha_v >= 0.0:
				var ac := mat.albedo_color
				ac.a = clamp(alpha_v, 0.0, 1.0)
				mat.albedo_color = ac

		# ---------- DEFAULT / OTHER ----------
		_:
			if spec_v >= 0.0:
				mat.specular = clamp(spec_v, 0.0, 1.0)

	return mat
