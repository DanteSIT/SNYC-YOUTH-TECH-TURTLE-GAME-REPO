extends Node

# Frees stray NavigationRegion3D nodes baked into imported blend scenes.
# The seashell blend ships with a huge baked navmesh (147k verts) that the
# NavigationServer builds/synchronizes, wrecking performance. No gameplay code
# uses navigation, so the regions are always safe to drop.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is NavigationRegion3D:
		var region := node as NavigationRegion3D
		region.navigation_mesh = null
		region.call_deferred("queue_free")
