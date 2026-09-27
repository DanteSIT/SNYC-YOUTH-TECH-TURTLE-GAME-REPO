extends SceneTree

## Headless floor validation. The seabed is the thing the player stands on, so
## replacing hundreds of box colliders with a generated surface has to be proven
## to still hold the turtle up, and a still screenshot cannot show that.
##
## Two independent checks per level:
##
##   1. the level's own turtle is dropped and must come to rest on the floor
##      rather than falling through it;
##   2. a bare CharacterBody3D is swept down at points along the corridor, which
##      measures the floor independently of the player controller's own physics.
##
## Samples taken at a pipe's z are skipped: the sweep would start inside the pipe
## tube and report a miss that has nothing to do with the seabed.
##
## Usage:
##   godot --headless --path . --script res://tools/probe_floor.gd -- <scene> [n]
##
## Exits 0 if every level passed, 1 otherwise.

const FALL_FRAMES := 90
const SWEEP_FROM_Y := 4.0
const SWEEP_DOWN := 8.0
const SPHERE_R := 0.05


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	if argv.is_empty():
		printerr("PROBE: need <scene>")
		quit(1)
		return
	var scene_path: String = argv[0]
	var samples: int = int(argv[1]) if argv.size() > 1 else 11

	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("PROBE FAIL: cannot load ", scene_path)
		quit(1)
		return
	var world: Node = packed.instantiate()
	root.add_child(world)
	current_scene = world
	for i: int in 8:
		await physics_frame

	var problems: Array[String] = []
	_check_collider(world, problems)
	await _check_turtle(world, problems)
	await _check_corridor(world, samples, problems)

	var label: String = scene_path.get_file().get_basename()
	if problems.is_empty():
		print("%-14s OK" % label)
		quit(0)
	else:
		print("%-14s FAIL" % label)
		for p: String in problems:
			print("    ", p)
		quit(1)


## The collider has to exist and be a real shape. A heightfield or trimesh that
## parsed to nothing is otherwise indistinguishable from a missing floor.
func _check_collider(world: Node, problems: Array[String]) -> void:
	var bodies: Array[Node] = []
	_collect(world, "SeabedBody", bodies)
	if bodies.is_empty():
		problems.append("no SeabedBody in the scene")
		return
	var cols: Array[CollisionShape3D] = []
	_collect_cols(bodies[0], cols)
	if cols.is_empty():
		problems.append("SeabedBody has no CollisionShape3D")
		return
	var s: Shape3D = cols[0].shape
	if s == null:
		problems.append("seabed CollisionShape3D has a null shape")
		return
	var n: int = PhysicsServer3D.body_get_shape_count(
		(bodies[0] as CollisionObject3D).get_rid())
	if n < 1:
		problems.append("seabed body registered 0 shapes with the physics server")


## The level's own turtle must settle on the floor instead of sinking.
func _check_turtle(world: Node, problems: Array[String]) -> void:
	var turtle: Node3D = _find(world, "Turtle") as Node3D
	if turtle == null:
		problems.append("no Turtle node")
		return
	var cb: CharacterBody3D = turtle.get_node_or_null("CharacterBody3D") as CharacterBody3D
	if cb == null:
		problems.append("Turtle has no CharacterBody3D")
		return
	var start: float = cb.global_position.y
	for i: int in FALL_FRAMES:
		await physics_frame
	var rest: float = cb.global_position.y
	if rest < -2.0:
		problems.append("turtle fell through the floor: %.2f -> %.2f" % [start, rest])
	elif not cb.is_on_floor():
		problems.append("turtle came to rest at %.2f but is_on_floor() is false" % rest)
	elif rest < start - 1.6:
		problems.append("turtle sank %.2f m below its spawn" % (start - rest))


## Sweep a plain body down along the corridor. This does not use the player
## controller, so it measures the floor on its own terms.
func _check_corridor(world: Node, samples: int, problems: Array[String]) -> void:
	var pipe_z: Array[float] = []
	for name: String in ["StartPipe", "EndPipe"]:
		var p: Node3D = _find(world, name) as Node3D
		if p != null:
			pipe_z.append(p.global_position.z)
	if pipe_z.size() < 2:
		problems.append("cannot locate both pipes")
		return
	var z_lo: float = minf(pipe_z[0], pipe_z[1])
	var z_hi: float = maxf(pipe_z[0], pipe_z[1])

	var probe := CharacterBody3D.new()
	probe.collision_layer = 0
	probe.collision_mask = 1
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = SPHERE_R
	cs.shape = sphere
	probe.add_child(cs)
	world.add_child(probe)
	for i: int in 4:
		await physics_frame
	var space: PhysicsDirectSpaceState3D = (world as Node3D).get_world_3d().direct_space_state

	var misses: Array[String] = []
	var other: Array[String] = []
	var lo: float = INF
	var hi: float = -INF
	for i: int in samples:
		# sample the middle of each band, clear of the pipes
		var t: float = (float(i) + 0.5) / float(samples)
		var z: float = lerpf(z_lo, z_hi, t)
		probe.global_position = Vector3(0.0, SWEEP_FROM_Y, z)
		await physics_frame
		var k: KinematicCollision3D = probe.move_and_collide(Vector3.DOWN * SWEEP_DOWN)
		if k == null:
			# A sweep that starts already inside a collider reports nothing, so a
			# miss is not on its own proof of a hole in the floor. A ray from the
			# same point tells the two apart.
			var q := PhysicsRayQueryParameters3D.create(
				Vector3(0.0, SWEEP_FROM_Y, z), Vector3(0.0, SWEEP_FROM_Y - SWEEP_DOWN, z))
			q.collision_mask = 1
			q.hit_back_faces = true
			var r: Dictionary = space.intersect_ray(q)
			if r.is_empty():
				misses.append("%.1f" % z)
			else:
				var who: Object = r["collider"]
				var n: Vector3 = r["normal"]
				other.append("swept into %s at z=%.0f (floor is at y=%.2f, n.y=%.0f)"
					% [str((who as Node).name) if who is Node else str(who), z,
						(r["position"] as Vector3).y, n.y])
			continue
		var who: Object = k.get_collider()
		# Platforms legitimately stand proud of the sand, so only seabed hits say
		# anything about the seabed's shape.
		if who is Node and (who as Node).name == "SeabedBody":
			lo = minf(lo, k.get_position().y)
			hi = maxf(hi, k.get_position().y)
		else:
			other.append("%s@%.0f" % [str((who as Node).name), k.get_position().z])
	if not misses.is_empty():
		problems.append("no floor under z: " + ", ".join(misses))
	elif lo == INF:
		problems.append("nothing sampled hit the seabed; instead: "
			+ "; ".join(other))
	elif hi - lo > 3.0:
		problems.append("seabed spans %.1f m across the corridor" % (hi - lo))


func _find(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for c: Node in node.get_children():
		var r: Node = _find(c, name)
		if r != null:
			return r
	return null


func _collect(node: Node, name: String, out: Array[Node]) -> void:
	if node.name == name:
		out.append(node)
	for c: Node in node.get_children():
		_collect(c, name, out)


func _collect_cols(node: Node, out: Array[CollisionShape3D]) -> void:
	for c: Node in node.get_children():
		if c is CollisionShape3D:
			out.append(c as CollisionShape3D)
		_collect_cols(c, out)
