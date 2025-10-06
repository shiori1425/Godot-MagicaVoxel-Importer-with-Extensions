const Faces       = preload("./Faces.gd")
const VoxData     = preload("./VoxFormat/VoxData.gd")
const VoxMaterial = preload("./VoxFormat/VoxMaterial.gd")
const SurfaceBuckets = preload("./SurfaceBuckets.gd")

# Godot axis basis to match VOX coordinate space
const vox_to_godot = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)

# Names for the faces by orientation
enum FaceOrientation {
	Top = 0,
	Bottom = 1,
	Left = 2,
	Right = 3,
	Front = 4,
	Back = 5,
}

# An Array(FaceOrientation) of all possible face orientations
const face_orientations : Array = [
	FaceOrientation.Top,
	FaceOrientation.Bottom,
	FaceOrientation.Left,
	FaceOrientation.Right,
	FaceOrientation.Front,
	FaceOrientation.Back
]

# An Array(int) of the depth axis by orientation
const depth_axis : Array = [
	Vector3.AXIS_Z,
	Vector3.AXIS_Z,
	Vector3.AXIS_X,
	Vector3.AXIS_X,
	Vector3.AXIS_Y,
	Vector3.AXIS_Y,
]

# An Array(int) of the width axis by orientation
const width_axis : Array = [
	Vector3.AXIS_Y,
	Vector3.AXIS_Y,
	Vector3.AXIS_Z,
	Vector3.AXIS_Z,
	Vector3.AXIS_X,
	Vector3.AXIS_X,
]

# An Array(int) of height axis by orientation
const height_axis : Array = [
	Vector3.AXIS_X,
	Vector3.AXIS_X,
	Vector3.AXIS_Y,
	Vector3.AXIS_Y,
	Vector3.AXIS_Z,
	Vector3.AXIS_Z,
]

# An Array(Vector3) describing what vectors to use to check for face occlusion by orientation
const face_checks : Array = [
	Vector3(0, 0, 1),
	Vector3(0, 0, -1),
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(0, -1, 0),
	Vector3(0, 1, 0),
]

# An array of the face meshes by orientation
const face_meshes : Array = [
	Faces.Front,
	Faces.Back,
	Faces.Left,
	Faces.Right,
	Faces.Bottom,
	Faces.Top,
]

# An Array(Vector3) describing what normals to use by orientation
const normals : Array = [
	Vector3(0, 1, 0),
	Vector3(0, -1, 0),
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(0, 0, 1),
	Vector3(0, 0, -1),
]

# ===== Runtime state =====

# VoxData ref
var _vox_ref: VoxData = null

# Shared surface bucket manager (handles single-surface vs per-palette)
var _buckets: SurfaceBuckets = null

# Whether to group/merge by palette index (true) or by color (false)
var _per_palette: bool = true

# Bounds of the volume
var mins : Vector3 = Vector3(1000000, 1000000, 1000000)
var maxs : Vector3 = Vector3(-1000000, -1000000, -1000000)

# ----- Main -----
# Generate a mesh for the given voxel_data with single-pass greedy face merging
# Primary Reference: https://0fps.net/2012/06/30/meshing-in-a-minecraft-game/
# Secondary Reference: https://www.gedge.ca/dev/2014/08/17/greedy-voxel-meshing
# voxel_data is a Dictionary[Vector3] -> palette index (int). DO NOT convert to Color here.
func generate(vox: VoxData, voxel_data: Dictionary, scale: float, snaptoground: bool, perpalettesurface: bool) -> ArrayMesh:

	# Remeber, MagicaVoxel thinks Y is the depth axis. We convert to the correct
	# coordinate space when we generate the faces.
	
	_vox_ref = vox
	_per_palette = perpalettesurface

	# reset bounds
	mins = Vector3(1000000, 1000000, 1000000)
	maxs = Vector3(-1000000, -1000000, -1000000)

	# Short-circuit empty models
	if voxel_data.size() == 0:
		return ArrayMesh.new()

	# Initialize shared buckets (material generation lives in VoxMaterial via SurfaceBuckets)
	_buckets = SurfaceBuckets.new()
	_buckets.vox = vox
	_buckets.per_palette = perpalettesurface

	# Find bounds
	for v in voxel_data:
		mins.x = min(mins.x, v.x)
		mins.y = min(mins.y, v.y)
		mins.z = min(mins.z, v.z)
		maxs.x = max(maxs.x, v.x)
		maxs.y = max(maxs.y, v.y)
		maxs.z = max(maxs.z, v.z)

	# Iterate over all face orientations to reduce problem to 3 dimensions
	for o in face_orientations:
		generate_geometry_for_orientation(voxel_data, o, scale, snaptoground)

	# Commit all surfaces into a single ArrayMesh
	var mesh := ArrayMesh.new()
	_buckets.commit_into(mesh)
	return mesh

# Generates all of the geometry for a given face orientation
func generate_geometry_for_orientation(voxel_data: Dictionary, o: int, scale: float, snaptoground: bool) -> void:
	# Sweep through the volume along the depth, reducing the problem to 2D
	var da : int = depth_axis[o]
	for slice in range(mins[da], maxs[da] + 1):
		var faces : Dictionary = query_slice_faces(voxel_data, o, slice)
		if faces.size() > 0:
			generate_geometry(faces, o, slice, scale, snaptoground)

# Returns the voxels in the set voxel_data with a visible face along the slice
# for the given orientation.
# IMPORTANT:
#  - per-palette mode stores **palette index (int)** as the token
#  - single-surface mode stores **Color** as the token
# This ensures greedy merging compares equal tokens correctly (index vs color).
func query_slice_faces(voxel_data: Dictionary, o: int, slice: float) -> Dictionary:
	var ret : Dictionary = {}
	var da = depth_axis[o]
	for v in voxel_data:
		if v[da] == slice and voxel_data.has(v + face_checks[o]) == false:
			var pi := int(voxel_data[v])
			ret[v] = pi if _per_palette else _color_for_palette(pi)
	return ret

# Returns a Color for a given palette index; white if out-of-range.
func _color_for_palette(pi: int) -> Color:
	if _vox_ref != null and _vox_ref.colors is Array and pi >= 0 and pi < _vox_ref.colors.size():
		return _vox_ref.colors[pi]
	return Color(1, 1, 1, 1)

# Generates geometry for the given orientation for the set of faces
func generate_geometry(faces: Dictionary, o: int, slice: float, scale: float, snaptoground: bool) -> void:
	var da : int = depth_axis[o]
	var wa : int = width_axis[o]
	var ha : int = height_axis[o]
	var v : Vector3 = Vector3()
	v[da] = slice

	# Iterate the rows of the sparse volume
	v[ha] = mins[ha]
	while v[ha] <= maxs[ha]:
		# Iterate over the voxels of the row
		v[wa] = mins[wa]
		while v[wa] <= maxs[wa]:
			if faces.has(v):
				generate_geometry_for_face(faces, v, o, scale, snaptoground)
			v[wa] += 1.0
		v[ha] += 1.0

# Generates the geometry for the given face and orientation and returns the set of remaining faces
func generate_geometry_for_face(faces: Dictionary, face: Vector3, o: int, scale: float, snaptoground: bool) -> Dictionary:
	var da : int = depth_axis[o]
	var wa : int = width_axis[o]
	var ha : int = height_axis[o]

	# Greedy face merging (compare equal tokens).
	# Token is palette index in per-palette mode, or Color in single-surface mode.
	var width  : int = width_query(faces, face, o)
	var height : int = height_query(faces, face, o, width)
	var grow : Vector3 = Vector3(1, 1, 1)
	grow[wa] *= width
	grow[ha] *= height

	# Generate geometry
	var yoffset := Vector3.ZERO
	if snaptoground:
		yoffset = Vector3(0, -mins.z * scale, 0)

	# Resolve palette + color depending on mode
	var palette_id : int
	var color      : Color
	if _per_palette:
		palette_id = int(faces[face])               # token is palette index
		color      = _color_for_palette(palette_id) # still pass color for vertex tint
	else:
		palette_id = -1                             # single surface key inside buckets
		color      = Color(faces[face])             # token is color already

	# Ask the bucket manager for the correct SurfaceTool for this run
	var st := _buckets.get_bucket(palette_id, color)

	# Per-face attributes
	st.set_normal(normals[o])
	# (we rely on vertex colors; SurfaceBuckets sets the material appropriately)

	# Emit merged quad (as two tris via SurfaceTool)
	for vert in face_meshes[o]:
		st.add_vertex(yoffset + vox_to_godot * ((vert * grow) + face) * scale)

	# Remove these faces from the pool
	var v : Vector3 = Vector3()
	v[da] = face[da]
	for iy in range(height):
		v[ha] = face[ha] + float(iy)
		for ix in range(width):
			v[wa] = face[wa] + float(ix)
			faces.erase(v)

	return faces

# Returns the number of voxels wide the run starting at face is with respect to the set of faces and orientation
func width_query(faces: Dictionary, face: Vector3, o: int) -> int:
	var wd : int = width_axis[o]
	var v  : Vector3 = face
	while faces.has(v) and faces[v] == faces[face]:
		v[wd] += 1.0
	return int(v[wd] - face[wd])

# Returns the number of voxels high the run starting at face is with respect to the set of faces and orientation, with the given width
func height_query(faces: Dictionary, face: Vector3, o: int, width: int) -> int:
	var hd : int = height_axis[o]
	var token = faces[face]  # int (palette) in per-palette mode, Color otherwise
	var v    : Vector3 = face
	v[hd] += 1.0
	while faces.has(v) and faces[v] == token and width_query(faces, v, o) >= width:
		v[hd] += 1.0
	return int(v[hd] - face[hd])
