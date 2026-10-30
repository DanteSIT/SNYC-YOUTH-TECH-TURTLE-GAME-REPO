class_name GlowOutline
extends RefCounted

## Glowing outlines for collectables (pink) and hazards (red).
##
## The outline is a next_pass material: a slightly enlarged copy of the mesh
## drawn with front faces culled. The enlarged copy is hidden behind the object
## except at the silhouette, where it leaves a thin glowing rim.

## Outline thickness in world units.
const WIDTH := 0.022


## Returns a copy of `outline` scaled for `instance`.
static func shell(outline: Material, instance: GeometryInstance3D) -> StandardMaterial3D:
	var grown := outline.duplicate() as StandardMaterial3D
	if grown == null:
		return null
	# grow_amount works in local space, so undo the node's scale.
	grown.grow_amount = WIDTH / _world_scale(instance)
	return grown


## Outlines every mesh at or below `root`.
static func apply(root: Node, outline: Material) -> void:
	for node in _meshes_under(root):
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null:
			continue
		var grown := shell(outline, mi)
		if grown == null:
			continue
		for surface in mesh.get_surface_count():
			var base := mi.get_active_material(surface)
			if base == null:
				mi.set_surface_override_material(surface, grown)
				continue
			# Imported materials are shared, so copy before adding the pass.
			base = base.duplicate()
			base.next_pass = grown
			mi.set_surface_override_material(surface, base)


static func _meshes_under(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node is MeshInstance3D:
		found.append(node)
	found.append_array(node.find_children("*", "MeshInstance3D", true, false))
	return found


static func _world_scale(instance: GeometryInstance3D) -> float:
	var s := instance.global_transform.basis.get_scale()
	return maxf(maxf(s.x, s.y), maxf(s.z, 0.0001))
