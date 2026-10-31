extends SceneTree
## Finds gameplay objects that sit inside the seabed.
##
## Casts a ray straight down at each collectable, hazard and platform, and
## compares the object's own origin with the floor height there. Negative
## clearance means the sand is above the object's origin.

const PREFIXES := ["Collect", "Hazard"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level_path := "res://scenes/levels/level_1.tscn"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		level_path = args[0]

	var packed: PackedScene = load(level_path)
	if packed == null:
		printerr("BURIED cannot load ", level_path)
		quit(1)
		return
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	for _i in 8:
		await physics_frame

	var space := get_root().get_world_3d().direct_space_state
	var terrain: Node = world.get_node_or_null("Terrain")
	var total := 0
	var buried := 0

	print("")
	print("level ", level_path)
	for child in world.get_children():
		var name := String(child.name)
		if not (child is Node3D):
			continue
		var pos: Vector3 = (child as Node3D).global_position
		# Platforms are grounded by tools/ground_platforms.py, so just report
		# where the floor is under each one.
		if name.begins_with("Platform"):
			var ground := _terrain_under(space, terrain, child, pos)
			if not is_nan(ground):
				print("PLATFORM %s %.4f %.4f %.4f" % [name, pos.y, ground, pos.z])
			continue
		var prefix := ""
		for p in PREFIXES:
			if name.begins_with(p):
				prefix = p
				break
		if prefix == "":
			continue
		var floor_y := _terrain_under(space, terrain, child, pos)
		if is_nan(floor_y):
			continue
		total += 1
		var clearance := pos.y - floor_y
		if clearance < 0.15:
			buried += 1
			print("FIX %s %s %.4f %.4f %.4f" % [prefix, name, pos.y, floor_y, pos.z])
			print("  %-14s %-10s y %6.2f  floor %6.2f  clearance %6.2f  z %7.1f"
				% [prefix, name, pos.y, floor_y, clearance, pos.z])

	print("BURIED %d of %d objects touch or sit inside the floor" % [buried, total])
	quit(1 if buried > 0 else 0)


## Ray-casts down until it reaches the seabed, skipping platforms.
func _terrain_under(space: PhysicsDirectSpaceState3D, terrain: Node, child: Node, pos: Vector3) -> float:
	var top := 4.4
	var bottom := pos.y - 6.0
	var exclude: Array[RID] = []
	if child is CollisionObject3D:
		exclude.append(child.get_rid())
	for _i in 16:
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(0.0, top, pos.z), Vector3(0.0, bottom, pos.z))
		query.exclude = exclude
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return NAN
		if terrain != null and terrain.is_ancestor_of(hit.collider):
			return hit.position.y
		var collider: Object = hit.collider
		if collider is CollisionObject3D:
			exclude.append((collider as CollisionObject3D).get_rid())
		top = hit.position.y - 0.02
		if top <= bottom:
			return NAN
	return NAN
