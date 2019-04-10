tool
extends EditorImportPlugin

const VoxFile = preload("./VoxFile.gd");
const Faces = preload("./Faces.gd");

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
	var scale = 0.1
	if options.Scale:
		scale = float(options.Scale)
	
	var file = File.new()
	var err = file.open(source_path, File.READ)

	if err != OK:
		if file.is_open(): file.close()
		return err
	
	var identifier = PoolByteArray([ file.get_8(), file.get_8(), file.get_8(), file.get_8() ]).get_string_from_ascii()
	var version = file.get_32()
	print('Importing: ', source_path, ' (scale: ', scale, ', file version: ', version, ')');
	
	var vox = VoxData.new();
	if identifier == 'VOX ':
		var voxFile = VoxFile.new(file);
		while voxFile.has_data_to_read():
			read_chunk(vox, voxFile);
	file.close()

	var st = SurfaceTool.new()
	
	for model in vox.models:
		var diffVector = model.size / 2 - Vector3(0.5, 0.5, 0.5)
		print('diffVector: ', diffVector)
	
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
		for voxel in model.voxels:
			var voxelSides = []
			if not model.voxels.has(voxel + Vector3.UP): voxelSides += Faces.Top
			if not model.voxels.has(voxel + Vector3.DOWN): voxelSides += Faces.Bottom
			if not model.voxels.has(voxel + Vector3.LEFT): voxelSides += Faces.Left
			if not model.voxels.has(voxel + Vector3.RIGHT): voxelSides += Faces.Right
			if not model.voxels.has(voxel + Vector3.BACK): voxelSides += Faces.Front
			if not model.voxels.has(voxel + Vector3.FORWARD): voxelSides += Faces.Back
			
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

class VoxData:
	var models: Array = [Model.new()];
	var current_index = -1;
	var colors = null;
	var nodes = {};
	
	func get_model() -> Model: return models[current_index];

class VoxNode:
	var id: int;
	var attributes = {};
	var child_nodes = [];
	var models = [];
	var translation = Vector3(0, 0, 0);
	var rotation = Basis();
	
	func _init(id, attributes):
		self.id = id;
		self.attributes = attributes;

class Model:
	var size: Vector3;
	var voxels = {};

func string_to_vector3(input: String) -> Vector3:
	var data = input.split_floats(' ');
	return Vector3(data[0], data[1], data[2]);

func byte_to_basis(data: int):
	var x_ind = ((data >> 0) & 0x03);
	var y_ind = ((data >> 2) & 0x03);
	var indexes = [0, 1, 2];
	indexes.erase(x_ind);
	indexes.erase(y_ind);
	var z_ind = indexes[0];
	var x_sign = 1 if ((data >> 4) & 0x01) == 0 else -1;
	var y_sign = 1 if ((data >> 5) & 0x01) == 0 else -1;
	var z_sign = 1 if ((data >> 6) & 0x01) == 0 else -1;
	var result = Basis();
	result.x[0] = x_sign if x_ind == 0 else 0;
	result.x[1] = x_sign if x_ind == 1 else 0;
	result.x[2] = x_sign if x_ind == 2 else 0;
	
	result.y[0] = y_sign if y_ind == 0 else 0;
	result.y[1] = y_sign if y_ind == 1 else 0;
	result.y[2] = y_sign if y_ind == 2 else 0;
	
	result.z[0] = z_sign if z_ind == 0 else 0;
	result.z[1] = z_sign if z_ind == 1 else 0;
	result.z[2] = z_sign if z_ind == 2 else 0;
	return result;

func read_chunk(vox: VoxData, file: VoxFile):
	var chunk_id = file.get_string(4);
	var chunk_size = file.get_32();
	var childChunks = file.get_32()

	file.set_chunk_size(chunk_size);
	match chunk_id:
		'SIZE':
			vox.current_index += 1;
			var model = vox.get_model();
			var x = file.get_32();
			var z = file.get_32();
			var y = file.get_32();
			model.size = Vector3(x, y, z);
		'XYZI':
			var model = vox.get_model();
			for _i in range(file.get_32()):
				var x = file.get_8()
				var z = (model.size.z - file.get_8())-1
				var y = file.get_8()
				var c = file.get_8()
				var voxel = Vector3(x, y, z)
				model.voxels[voxel] = c - 1
		'RGBA':
			vox.colors = []
			for _i in range(256):
				var r = float(file.get_8() / 255.0)
				var g = float(file.get_8() / 255.0)
				var b = float(file.get_8() / 255.0)
				var a = float(file.get_8() / 255.0)
				vox.colors.append(Color(r, g, b, a))
		'nTRN':
			var node_id = file.get_32();
			var attributes = file.get_vox_dict();
			var node = VoxNode.new(node_id, attributes);
			vox.nodes[node_id] = node;
			
			var child = file.get_32();
			node.child_nodes.append(child);
			
			file.get_buffer(8);
			var num_of_frames = file.get_32();
			for _frame in range(num_of_frames):
				var frame_attributes = file.get_vox_dict();
				if (frame_attributes.has('_t')):
					var trans = frame_attributes['_t'];
					node.translation = string_to_vector3(trans);
				if (frame_attributes.has('_r')):
					var rot = frame_attributes['_r'];
					node.rotation = byte_to_basis(int(rot));
		'nGRP':
			var node_id = file.get_32();
			var attributes = file.get_vox_dict();
			var node = VoxNode.new(node_id, attributes);
			vox.nodes[node_id] = node;
			
			var num_children = file.get_32();
			for _c in num_children:
				node.child_nodes.append(file.get_32());
		'nSHP':
			var node_id = file.get_32();
			var attributes = file.get_vox_dict();
			var node = VoxNode.new(node_id, attributes);
			vox.nodes[node_id] = node;
			
			var num_models = file.get_32();
			for _i in range(num_models):
				node.models.append(file.get_32());
				file.get_vox_dict();
	file.read_remaining();

