tool
extends EditorImportPlugin

func _init():
	print('Vox Importer: ready')

func get_importer_name():
	return 'Vox.Importer'

func get_visible_name():
	return 'Vox Importer'

func get_recognized_extensions():
	return [ 'vox' ]

func get_resource_type():
	return 'Mesh'

func get_save_extension():
	return 'mesh'

func get_preset_count():
	return 0

func get_preset_name(_preset):
	return 'Default'
	
func get_import_options(_preset):
	return [
		{
			'name': 'Scale',
			'default_value': 0.1
		}
	]

func get_option_visibility(_option, _options):
	return true

func import(source_path, destination_path, options, _platforms, _gen_files):
	print('Vox Importer: importing ', source_path)

	var scale = 0.1
	if options.Scale:
		scale = float(options.Scale)
	print('Vox Importer: scale: ', scale)
	
	var file = File.new()
	var err = file.open(source_path, File.READ)

	if err != OK:
		if file.is_open(): file.close()
		return err
	
	var identifier = PoolByteArray([ file.get_8(), file.get_8(), file.get_8(), file.get_8() ]).get_string_from_ascii()
	#warning-ignore:unused_variable
	var version = file.get_32()
	
	var vox = VoxNode.new();
	if identifier == 'VOX ':
		while file.get_position() < file.get_len():
			read_chunk(vox, file);
	file.close()

	var st = SurfaceTool.new()
	
	for model in vox.models:
		var diffVector = model.size / 2 - Vector3(0.5, 0.5, 0.5)
		print('diffVector: ', diffVector)
	
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
		for voxel in model.voxels:
			var voxelSides = []
			if not model.voxels.has(Vector3(voxel.x, voxel.y + 1, voxel.z)): voxelSides += top
			if not model.voxels.has(Vector3(voxel.x, voxel.y - 1, voxel.z)): voxelSides += bottom
			if not model.voxels.has(Vector3(voxel.x - 1, voxel.y, voxel.z)): voxelSides += left
			if not model.voxels.has(Vector3(voxel.x + 1, voxel.y, voxel.z)): voxelSides += right
			if not model.voxels.has(Vector3(voxel.x, voxel.y, voxel.z + 1)): voxelSides += front
			if not model.voxels.has(Vector3(voxel.x, voxel.y, voxel.z - 1)): voxelSides += back
			
			st.add_color(vox.colors[model.voxels[voxel]])
	
			for t in voxelSides:
				st.add_vertex(((t * 0.5) + voxel - diffVector) * scale)
		
	st.generate_normals()
	
	var material = SpatialMaterial.new()
	material.vertex_color_is_srgb = true
	material.vertex_color_use_as_albedo = true
	material.roughness = 1
	st.set_material(material)

	var mesh = st.commit()
	
	var full_path = "%s.%s" % [ destination_path, get_save_extension() ]
	return ResourceSaver.save(full_path, mesh)

class VoxNode:
	var models: Array = [Model.new()];
	var current_index = -1;
	var colors = null;
	
	func get_model() -> Model: return models[current_index];

class Model:
	#warning-ignore:unused_class_variable
	var size: Vector3;
	#warning-ignore:unused_class_variable
	var voxels = {};

func read_chunk(vox: VoxNode, file: File):
	var chunkId = PoolByteArray([ file.get_8(), file.get_8(), file.get_8(), file.get_8() ]).get_string_from_ascii();
	var chunkSize = file.get_32();
	#warning-ignore:unused_variable
	var childChunks = file.get_32()

	match chunkId:
		'SIZE':
			vox.current_index += 1;
			var model = vox.get_model();
			var x = file.get_32();
			var z = file.get_32();
			var y = file.get_32();
			model.size = Vector3(x, y, z);
			print('SIZE: ', x, ', ', y, ', ', z)
			#warning-ignore:return_value_discarded
			file.get_buffer(chunkSize - 4 * 3)
		'XYZI':
			var model = vox.get_model();
			print('XYZI')
			for _i in range(file.get_32()):
				var x = file.get_8()
				var z = model.size.z - file.get_8()
				var y = file.get_8()
				var c = file.get_8()
				var voxel = Vector3(x, y, z)
				model.voxels[voxel] = c - 1
		'RGBA':
			print('RGBA');
			vox.colors = []
			for _i in range(256):
				var r = float(file.get_8() / 255.0)
				var g = float(file.get_8() / 255.0)
				var b = float(file.get_8() / 255.0)
				var a = float(file.get_8() / 255.0)
				vox.colors.append(Color(r, g, b, a))
		'MAIN':
			print('MAIN')
			#warning-ignore:return_value_discarded
			file.get_buffer(chunkSize)
		_:
			print(chunkId, ' - UNHANDLED');
			#warning-ignore:return_value_discarded
			file.get_buffer(chunkSize)

var top = [
	Vector3( 1.0000, 1.0000, 1.0000),
	Vector3(-1.0000, 1.0000, 1.0000),
	Vector3(-1.0000, 1.0000,-1.0000),
	
	Vector3(-1.0000, 1.0000,-1.0000),
	Vector3( 1.0000, 1.0000,-1.0000),
	Vector3( 1.0000, 1.0000, 1.0000),
]

var bottom = [
	Vector3(-1.0000,-1.0000,-1.0000),
	Vector3(-1.0000,-1.0000, 1.0000),
	Vector3( 1.0000,-1.0000, 1.0000),
	
	Vector3( 1.0000, -1.0000, 1.0000),
	Vector3( 1.0000, -1.0000,-1.0000),
	Vector3(-1.0000, -1.0000,-1.0000),
]

var front = [
	Vector3(-1.0000, 1.0000, 1.0000),
	Vector3( 1.0000, 1.0000, 1.0000),
	Vector3( 1.0000,-1.0000, 1.0000),
	
	Vector3( 1.0000,-1.0000, 1.0000),
	Vector3(-1.0000,-1.0000, 1.0000),
	Vector3(-1.0000, 1.0000, 1.0000),
]

var back = [
	Vector3( 1.0000,-1.0000,-1.0000),
	Vector3( 1.0000, 1.0000,-1.0000),
	Vector3(-1.0000, 1.0000,-1.0000),
	
	Vector3(-1.0000, 1.0000,-1.0000),
	Vector3(-1.0000,-1.0000,-1.0000),
	Vector3( 1.0000,-1.0000,-1.0000)
]

var left = [
	Vector3(-1.0000, 1.0000, 1.0000),
	Vector3(-1.0000,-1.0000, 1.0000),
	Vector3(-1.0000,-1.0000,-1.0000),
	
	Vector3(-1.0000,-1.0000,-1.0000),
	Vector3(-1.0000, 1.0000,-1.0000),
	Vector3(-1.0000, 1.0000, 1.0000),
]

var right = [
	Vector3( 1.0000, 1.0000, 1.0000),
	Vector3( 1.0000, 1.0000,-1.0000),
	Vector3( 1.0000,-1.0000,-1.0000),
	
	Vector3( 1.0000,-1.0000,-1.0000),
	Vector3( 1.0000,-1.0000, 1.0000),
	Vector3( 1.0000, 1.0000, 1.0000),
]