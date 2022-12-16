A fork of CloneDeath's Godot plugin [MagicaVoxel importer with extensions](https://github.com/CloneDeath/MagicaVoxel-Importer-with-Extensions).

This fork adds a number of features that are waiting to be pulled into CloneDeath's plugin.  If you wish to use these features _now_ then use _this_ plugin instead.
- __Hiding layers in MagicaVoxel removes their associated objects from Godot.__ - This allows for toggling optional objects in MagicaVoxel, such as items of clothing.
- __MagicaVoxel objects are merged in Godot in layer order.__ - Later layers are merged "on top" of earlier layers when imported into Godot.  This allows the user to control which objects show "on top".  It is useful for adding tight features where an extra voxel is inappropriate, such as for facial expressions, or tight clothing.
- __An option to only use voxels from the first MagicaVoxel keyframe.__ - MagicaVoxel now allows creating multiple keyframes of voxels.  If each keyframe represents a separate pose then it can look strange when they are all imported into Godot on top of each other.  This option fixes that.
