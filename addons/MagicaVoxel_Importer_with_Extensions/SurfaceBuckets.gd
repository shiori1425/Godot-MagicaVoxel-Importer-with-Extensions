# SurfaceBuckets.gd
extends RefCounted
class_name SurfaceBuckets

const VoxMaterial = preload("./VoxFormat/VoxMaterial.gd")

var vox: Object
var per_palette: bool = false

# key(int) -> {"st": SurfaceTool, "mat": Material, "key": int}
var _map: Dictionary = {}

func get_bucket(pi: int, color: Color) -> SurfaceTool:
	var key: int
	if per_palette:
		key = pi
	else:
		key = -1

	var entry = _map.get(key)
	if entry == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

		var mat: Material
		if per_palette:
			mat = VoxMaterial.material_for_palette(vox, pi, color)
		else:
			mat = VoxMaterial.shared_vertex_color_material()

		st.set_material(mat)
		entry = {
			"st": st,
			"mat": mat,
			"key": key,
		}
		_map[key] = entry

	# keep vertex color updated (used in single-surface mode, harmless otherwise)
	entry.st.set_color(color)
	return entry.st

func commit_into(mesh: ArrayMesh) -> void:
	for entry in _map.values():
		var st: SurfaceTool = entry.st
		var mat: Material = entry.mat
		var key: int = entry.key

		var arrays := st.commit_to_arrays()
		if arrays.is_empty():
			continue

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var si := mesh.get_surface_count() - 1
		mesh.surface_set_material(si, mat)

		# Name surfaces for clarity in the inspector
		if per_palette and key >= 0:
			mesh.surface_set_name(si, "pi_%d" % key)
		else:
			mesh.surface_set_name(si, "vertex_color")
