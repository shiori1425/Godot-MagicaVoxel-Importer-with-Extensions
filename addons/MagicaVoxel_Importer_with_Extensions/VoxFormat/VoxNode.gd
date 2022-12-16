var id: int;
var attributes = {};
var layerId = -1;
var child_nodes = [];
var models = [];
var translation = Vector3(0, 0, 0);
var rotation = Basis();

func _init(id, attributes):
	self.id = id;
	self.attributes = attributes;