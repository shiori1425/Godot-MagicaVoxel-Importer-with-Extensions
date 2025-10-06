extends RefCounted
class_name CulledMeshGenerator

const Faces = preload("./Faces.gd")
const SurfaceBuckets = preload("./SurfaceBuckets.gd")

# VOX → Godot basis
const vox_to_godot = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)

# Face normals
const NORMAL_UP      = Vector3.UP
const NORMAL_DOWN    = Vector3.DOWN
const NORMAL_LEFT    = Vector3.LEFT
const NORMAL_RIGHT   = Vector3.RIGHT
const NORMAL_FRONT   = Vector3.FORWARD
const NORMAL_BACK    = Vector3.BACK

# Neighbor offsets
const OFF_UP      = Vector3.UP
const OFF_DOWN    = Vector3.DOWN
const OFF_LEFT    = Vector3.LEFT
const OFF_RIGHT   = Vector3.RIGHT
const OFF_BACK    = Vector3.BACK
const OFF_FORWARD = Vector3.FORWARD

func generate(vox, voxel_data: Dictionary, scale: float, snaptoground: bool, perpalettesurface: bool) -> ArrayMesh:
	# Empty guard
	if voxel_data.size() == 0:
		return ArrayMesh.new()

	# Bounds for snap-to-ground
	var mins = Vector3(1000000.0, 1000000.0, 1000000.0)
	for v in voxel_data:
		if v.x < mins.x:
			mins.x = v.x
		if v.y < mins.y:
			mins.y = v.y
		if v.z < mins.z:
			mins.z = v.z

	var yoffset = Vector3.ZERO
	if snaptoground:
		yoffset = Vector3(0, -mins.z * scale, 0)

	# Shared surface/material buckets (same as Greedy)
	var buckets = SurfaceBuckets.new()
	buckets.vox = vox
	buckets.per_palette = perpalettesurface

	# Build culled faces
	for voxel in voxel_data:
		var pi = int(voxel_data[voxel])
		var color = _color_for_palette(vox, pi)
		var bucket_key = _bucket_key(perpalettesurface, pi)

		# UP
		if face_is_visible(vox, voxel_data, voxel, OFF_UP):
			var st_up = buckets.get_bucket(bucket_key, color)
			st_up.set_normal(NORMAL_UP)
			for p in Faces.Top:
				st_up.add_vertex(yoffset + vox_to_godot * (p + voxel) * scale)

		# DOWN
		if face_is_visible(vox, voxel_data, voxel, OFF_DOWN):
			var st_dn = buckets.get_bucket(bucket_key, color)
			st_dn.set_normal(NORMAL_DOWN)
			for p in Faces.Bottom:
				st_dn.add_vertex(yoffset + vox_to_godot * (p + voxel) * scale)

		# LEFT
		if face_is_visible(vox, voxel_data, voxel, OFF_LEFT):
			var st_l = buckets.get_bucket(bucket_key, color)
			st_l.set_normal(NORMAL_LEFT)
			for p in Faces.Left:
				st_l.add_vertex(yoffset + vox_to_godot * (p + voxel) * scale)

		# RIGHT
		if face_is_visible(vox, voxel_data, voxel, OFF_RIGHT):
			var st_r = buckets.get_bucket(bucket_key, color)
			st_r.set_normal(NORMAL_RIGHT)
			for p in Faces.Right:
				st_r.add_vertex(yoffset + vox_to_godot * (p + voxel) * scale)

		# BACK (+Z)
		if face_is_visible(vox, voxel_data, voxel, OFF_BACK):
			var st_bk = buckets.get_bucket(bucket_key, color)
			st_bk.set_normal(NORMAL_BACK)
			for p in Faces.Front:
				st_bk.add_vertex(yoffset + vox_to_godot * (p + voxel) * scale)

		# FORWARD (-Z)
		if face_is_visible(vox, voxel_data, voxel, OFF_FORWARD):
			var st_fw = buckets.get_bucket(bucket_key, color)
			st_fw.set_normal(NORMAL_FRONT)
			for p in Faces.Back:
				st_fw.add_vertex(yoffset + vox_to_godot * (p + voxel) * scale)

	# Commit to mesh (SurfaceBuckets applies materials and names)
	var mesh = ArrayMesh.new()
	buckets.commit_into(mesh)
	return mesh

# ---------- helpers ----------

func _bucket_key(per_palette: bool, pi: int) -> int:
	if per_palette:
		return pi
	else:
		return -1

func _color_for_palette(vox: Object, pi: int) -> Color:
	if vox != null and vox.colors is Array:
		if pi >= 0 and pi < vox.colors.size():
			return vox.colors[pi]
	return Color(1, 1, 1, 1)

# Preserve your glass adjacency rule with safe fallbacks
func face_is_visible(vox: Object, voxel_data: Dictionary, voxel: Vector3, face_offset: Vector3) -> bool:
	var neighbor = voxel + face_offset
	if not voxel_data.has(neighbor):
		return true

	var local_pi = int(voxel_data[voxel])
	var adj_pi = int(voxel_data[neighbor])

	var local_vm = null
	var adj_vm = null
	if vox != null and (vox.materials is Dictionary):
		if vox.materials.has(local_pi):
			local_vm = vox.materials[local_pi]
		if vox.materials.has(adj_pi):
			adj_vm = vox.materials[adj_pi]

	var local_is_glass = false
	var adj_is_glass = false

	if local_vm != null and local_vm.has_method("is_glass"):
		local_is_glass = bool(local_vm.is_glass())
	if adj_vm != null and adj_vm.has_method("is_glass"):
		adj_is_glass = bool(adj_vm.is_glass())

	# Draw when adjacent is glass and local is not glass
	if adj_is_glass and not local_is_glass:
		return true

	return false
