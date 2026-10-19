class_name GlowOutline
extends RefCounted

## Glowing "inverted hull" outlines for collectables (pink) and hazards (red).
##
## An outline is a `next_pass` material: it re-draws the mesh with `grow` set,
## which pushes every vertex outwards along its normal, and with
## `cull_mode = CULL_FRONT` so only the far side of that shell survives. The
## near side is culled and the far side is hidden behind the object itself,
## which leaves a thin ring hugging the silhouette -- an outline. Emission is
## pushed above the levels' `glow_hdr_threshold` so the ring blooms.
##
## `grow_amount` is expressed in the mesh's own local units, and the hazard and
## vegetation models in this project are scaled all over the place (from 0.003
## for the hook up to 2.5 for the can). `shell()` therefore divides the wanted
## world-space width by the node's world scale, so every outline is the same
## thickness on screen no matter how the model was scaled to fit.

## Wanted outline thickness, in world units.
const WIDTH := 0.022


## Returns `outline` as a private copy tuned to the size of `instance`.
static func shell(outline: Material, instance: GeometryInstance3D) -> StandardMaterial3D:
	var grown := outline.duplicate() as StandardMaterial3D
	if grown == null:
		return null
	grown.grow_amount = WIDTH / _world_scale(instance)
	return grown


## Convenience: outline every mesh found at or under `root`.
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
				# No material to chain off: the shell is the only pass.
				mi.set_surface_override_material(surface, grown)
				continue
			# The base has to be duplicated too -- imported materials are shared
			# with every other instance of the same model.
			base = base.duplicate()
			base.next_pass = grown
			mi.set_surface_override_material(surface, base)


static func _meshes_under(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node is MeshInstance3D:
		found.append(node)
	# owned=false: mesh nodes inside an instanced .glb belong to the sub-scene.
	found.append_array(node.find_children("*", "MeshInstance3D", true, false))
	return found


static func _world_scale(instance: GeometryInstance3D) -> float:
	var s := instance.global_transform.basis.get_scale()
	return maxf(maxf(s.x, s.y), maxf(s.z, 0.0001))
