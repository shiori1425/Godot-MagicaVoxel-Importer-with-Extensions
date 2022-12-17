tool
extends MeshInstance

export(MeshLibrary) var frames = null setget setMeshLibrary
func setMeshLibrary(v):
	frames = v;
	currentFrame = 0
	if v == null:
		meshCount = 0;
		self.mesh = null;
	else:
		meshCount = v.get_item_list().size()
		self.mesh = v.get_item_mesh(0)

export(int) var currentFrame = 0 setget setCurrentFrame
func setCurrentFrame(v):
	if v >= 0 and v < meshCount:
		currentFrame = v
		self.mesh = frames.get_item_mesh(v)

var meshCount = 0;
