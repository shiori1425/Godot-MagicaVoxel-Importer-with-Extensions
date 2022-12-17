tool
extends EditorPlugin

var pluginToMesh
var pluginToMeshLibrary

func _enter_tree():
	pluginToMesh = preload('vox-importer-mesh.gd').new()
	pluginToMeshLibrary = preload('vox-importer-meshLibrary.gd').new()
	add_import_plugin(pluginToMesh)
	add_import_plugin(pluginToMeshLibrary)
	add_custom_type("FramedMeshInstance", "MeshInstance", preload("FramedMeshInstance.gd"), preload("FramedMeshInstance.png"))

func _exit_tree():
	remove_import_plugin(pluginToMesh)
	remove_import_plugin(pluginToMeshLibrary)
	pluginToMesh = null
	pluginToMeshLibrary = null
	remove_custom_type("FramedMeshInstance")
