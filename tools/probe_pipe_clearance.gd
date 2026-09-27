extends SceneTree
## Can the turtle reliably get through a transition pipe?
##
## ## The bug this exists for
##
## "When coming into contact with the pipe the player gets stuck." It was a hard
## lock, not a bump: the turtle sat at (z 37.57, y 0.13) for 6 s with the forward
## key held, and the swim key moved it 0.00 m. Four separate things had to be
## measured to explain that, and every one of them was wrong on the first guess:
##
##  1. The player SPAWNS INSIDE the pipe. In every level the Turtle is authored at
##     the same z as the StartPipe (level_1: both at 40.6), sitting in the middle
##     of the tube, ~0.6 m below its axis.
##  2. The vertical input was INVERTED. player_controller read
##     Input.get_axis("ui_up", "ui_down"), and Godot's signature is
##     get_axis(NEGATIVE, POSITIVE) -- the first action returns -1. So ui_up, which
##     project.godot binds to W and the up arrow, produced a downward push:
##     measured, ui_up moved the turtle -1.000 m in y over a third of a second.
##     Inside a pipe, where the only way out is upward, the obvious key drove the
##     turtle into the wall. That alone is enough to explain the report.
##  3. Gravity pulled the turtle into the bore wall in ~0.22 s, because the level's
##     own spawn leaves only ~0.24 m of floor under the box.
##  4. The collider could not let go. It was a 2624-face ConcavePolygonShape3D
##     baked from the .blend, and move_and_slide cannot depenetrate a body out of
##     a concave surface -- once inside, there is no "inside" to be pushed out of.
##     It was also not trustworthy: cast_motion reported contacts at offsets where
##     ray casts proved the bore empty, and at its own reported contact poses
##     intersect_shape found nothing overlapping at all.
##
## It is now a ring of 16 convex boxes, which fixes 4 properly, plus the corrected
## input axis for 2. Gravity is left alone: an earlier attempt made the turtle
## neutrally buoyant in the bore, which turned out to be unnecessary and actively
## harmful, and the comment at the gravity line in player_controller.gd explains
## what the measurements said.
##
## ## Reading the output
##
##   PIPE OK / PIPE FAIL   the verdict, on the last line
##
## Run it per level, since the pipes are instanced and placed by each level:
##   godot --headless --path . --script res://tools/probe_pipe_clearance.gd
##   godot --headless --path . --script res://tools/probe_pipe_clearance.gd -- res://scenes/levels/level_9.tscn


const TURTLE_BOX := Vector3(0.883728, 0.28460693, 0.9614258)
const SWEEP_HEIGHT := 0.25
const AXIS_SAMPLES := 11
const DIRS := 12


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var level_path: String = "res://scenes/levels/level_1.tscn"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		level_path = args[0]

	var packed: PackedScene = load(level_path)
	if packed == null:
		printerr("PIPE FAIL cannot load ", level_path)
		quit(1)
		return
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	# Physics must be stepped before any space query means anything.
	for _i in 8:
		await physics_frame

	var space: PhysicsDirectSpaceState3D = get_root().get_world_3d().direct_space_state
	print("")
	print("level            ", level_path)
	print("turtle collider  ", TURTLE_BOX)

	var failures: int = 0

	# --- static geometry -------------------------------------------------------
	# Every query below excludes the pipes and the turtle, so a contact can only be
	# terrain, a wall, a gate or a hazard. Without that, the sweep's contact was
	# often the level's own start wall.
	var excluded: Array[RID] = []
	for body: StaticBody3D in _pipe_bodies(world):
		excluded.append(body.get_rid())
	var player_rid: RID = _player_rid(world)
	if player_rid.is_valid():
		excluded.append(player_rid)

	for body: StaticBody3D in _pipe_bodies(world):
		var pipe: Node3D = body.get_parent() as Node3D
		var pieces: Array[CollisionShape3D] = []
		for c: Node in body.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
				pieces.append(c)
		if pieces.is_empty():
			continue
		print("")
		print("pipe %-12s %d collider piece(s): %s" % [
			str(pipe.name), pieces.size(), _classes(pieces)])
		var bore: float = _bore_radius(body, pieces)
		var half_len: float = _half_length(body, pieces)
		print("  at %s   bore radius %.2f m   half-length %.2f m" % [
			body.global_position, bore, half_len])
		failures += _sweep(space, body, bore, half_len, excluded)
		failures += _bore_polar(space, pipe, bore)
		failures += _seabed_through_bore(space, pipe, bore, excluded)

	# --- input polarity --------------------------------------------------------
	var turtle: CharacterBody3D = null
	for n: Node in world.find_children("*", "CharacterBody3D", true, false):
		if n.is_in_group("player"):
			turtle = n
			break
	var end_pipe: Node3D = world.find_child("EndPipe", true, false) as Node3D
	if turtle == null:
		printerr("PIPE FAIL the level has no player to drive")
		quit(1)
		return
	if turtle.has_method("set_flow"):
		turtle.call("set_flow", 0.0)
	var spawn: Vector3 = turtle.global_position
	print("")
	print("vertical input polarity (measured in open water, clear of every pipe):")
	# spawn + 2.4 m is inside the pipe's own upper wall: the tube's outer surface
	# reaches 1.4 + 1.95 = 3.35, so a probe at 0.8 + 2.4 = 3.2 sits in the
	# collider and the reading is about the pipe, not about the input.
	var probe: Vector3 = spawn + Vector3(0.0, 2.4, 0.0)
	if end_pipe != null:
		probe.z = minf(probe.z, end_pipe.global_position.z + 4.6)
	failures += await _vertical_polarity(turtle, probe)

	# --- dynamic traversal -----------------------------------------------------
	print("")
	print("dynamic traversal with the real player controller:")
	# The level's own spawn pose, captured once. Every variant starts from it, not
	# from wherever the previous one finished, or a broken run can look like a
	# fixed one.
	failures += await _traverse(world, "StartPipe", spawn, false, "spawn, forward only", 0.0, true)
	# The complaint is "I touched the pipe and could not get free", so start hard
	# against the bottom of the bore and check the player can drive back out.
	failures += await _traverse(world, "StartPipe", spawn, false, "wedged low, forward", -1.0, true)
	# Holding the swim key pins the turtle to the bore's ceiling, which is what a
	# tube does. Measured for the record, never failed.
	await _traverse(world, "StartPipe", spawn, true, "spawn, holding swim up", 0.0, false)

	print("")
	if failures > 0:
		printerr("PIPE FAIL %d problem(s); see the INTRUDER / OCCLUDED BORE / NOT ROUND / STUCK lines above for which" % failures)
		quit(1)
		return
	print("PIPE OK  the bore is clear, ui_up swims up, and the turtle traverses the pipe")
	quit(0)


# --- collider introspection ---------------------------------------------------


func _pipe_bodies(world: Node) -> Array[StaticBody3D]:
	var out: Array[StaticBody3D] = []
	for n: Node in world.find_children("*", "StaticBody3D", true, false):
		var parent: Node = n.get_parent()
		# The pipe's own body, not the seabed or any other static geometry.
		if parent != null and "Pipe" in str(parent.name):
			out.append(n)
	return out


func _player_rid(world: Node) -> RID:
	for n: Node in world.find_children("*", "CharacterBody3D", true, false):
		if n.is_in_group("player"):
			return (n as CollisionObject3D).get_rid()
	return RID()


func _classes(pieces: Array[CollisionShape3D]) -> String:
	var seen: Dictionary = {}
	for cs: CollisionShape3D in pieces:
		seen[cs.shape.get_class()] = int(seen.get(cs.shape.get_class(), 0)) + 1
	var parts: PackedStringArray = []
	for k: String in seen:
		parts.append("%d x %s" % [int(seen[k]), k])
	return " ".join(parts)


## Every corner of every collider piece, expressed in the StaticBody3D's own space.
## The tube's axis is that space's Y axis, because the body carries the -90 degree
## pitch that stands the .blend's local Y up along world Z.
##
## The piece's own CollisionShape3D transform is what places it around the ring, so
## it has to be applied. Leaving it out collapses every segment onto the axis and
## reports a "bore" of 0.44 m, which is a suspiciously plausible-looking number
## that means nothing at all.
func _corners(body: StaticBody3D, pieces: Array[CollisionShape3D]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var inverse := body.global_transform.affine_inverse()
	for cs: CollisionShape3D in pieces:
		for v: Vector3 in _shape_corners(cs.shape):
			out.append(inverse * (body.global_transform * cs.transform * v))
	return out


func _shape_corners(s: Shape3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if s is BoxShape3D:
		var h: Vector3 = (s as BoxShape3D).size * 0.5
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					out.append(Vector3(h.x * sx, h.y * sy, h.z * sz))
	elif s is ConcavePolygonShape3D:
		out.append_array((s as ConcavePolygonShape3D).get_faces())
	return out


## The closest any collider geometry comes to the tube's axis. For a ring of boxes
## this is the bore; for the old trimesh it reported 1.30 where ray casts measured
## a 1.50 cylinder, which is one of the reasons the trimesh was not trusted.
func _bore_radius(body: StaticBody3D, pieces: Array[CollisionShape3D]) -> float:
	var best := INF
	for v: Vector3 in _corners(body, pieces):
		best = minf(best, Vector2(v.x, v.z).length())
	return best if is_finite(best) else 0.0


func _half_length(body: StaticBody3D, pieces: Array[CollisionShape3D]) -> float:
	var best := 0.0
	for v: Vector3 in _corners(body, pieces):
		best = maxf(best, absf(v.y))
	return best


# --- static checks ------------------------------------------------------------


## Sweep the turtle's own box along the tube's axis at a ladder of heights.
##
## Only offsets that keep the whole box inside the bore are required to pass.
## Further out the box is on its way to the rim, which is correct geometry and is
## reported rather than failed -- an earlier version of this counted rim hits as
## failures and cried wolf on 10 perfectly good offsets.
func _sweep(space: PhysicsDirectSpaceState3D, body: StaticBody3D,
		bore: float, tube_half: float, excluded: Array[RID]) -> int:
	var axis: Vector3 = body.global_basis.y.normalized()
	var basis := body.global_basis.orthonormalized()
	# Sweep no further out than the tube, plus a little to clear its end rings.
	# Reaching 4 m past each end leaves the sweep starting outside the level on
	# the StartPipe side, where it is already inside the start wall.
	var half_len: float = tube_half + 0.6
	var box_half_y: float = TURTLE_BOX.y * 0.5

	var box := BoxShape3D.new()
	box.size = TURTLE_BOX
	var blocked := 0
	var rim := 0
	var heights: PackedFloat64Array = []
	var h: float = -1.2
	while h <= 2.0:
		heights.append(h)
		h += SWEEP_HEIGHT

	print("  height sweep through the bore (offset from the pipe's own centre):")
	for hv: float in heights:
		var centre: Vector3 = body.global_position + basis.z * hv
		var from: Vector3 = centre - axis * half_len
		var motion: Vector3 = axis * (half_len * 2.0)
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = box
		params.transform = Transform3D(Basis.IDENTITY, from)
		params.collision_mask = 0xFFFFFFFF
		params.margin = 0.0
		params.exclude = excluded
		# The sweep vector lives on the query object, not as a second argument.
		params.motion = motion
		var result: PackedFloat32Array = space.cast_motion(params)
		var clear: bool = result[0] >= 0.999
		var must_pass: bool = absf(hv) + box_half_y <= bore
		var tag := ""
		if not clear:
			var frac: float = result[0]
			var touch: Vector3 = from + motion * frac
			var along: float = absf((touch - body.global_position).dot(axis))
			# cast_motion reports where it stopped but not what stopped it, and every
			# guess about the culprit has been wrong here. Ask the space directly.
			tag = _who_is_there(space, box, touch + motion.normalized() * 0.05, along,
				tube_half, excluded)
			if along <= tube_half * 0.9:
				if must_pass:
					tag += "  BLOCKED INSIDE"
					blocked += 1
			else:
				rim += 1
		print("    y %+5.2f  %-9s %-14s %s" % [
			hv, "clear" if clear else "blocked",
			"in the bore" if must_pass else "off-axis", tag])
	print("    %d offsets must pass, %d failed, %d hit the rim instead" % [
		heights.size() - rim - blocked, blocked, rim])
	return blocked


## Name whatever is sitting at a contact pose.
func _who_is_there(space: PhysicsDirectSpaceState3D, box: BoxShape3D,
		at: Vector3, along: float, tube_half: float, excluded: Array[RID]) -> String:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.transform = Transform3D(Basis.IDENTITY, at)
	params.collision_mask = 0xFFFFFFFF
	params.exclude = excluded
	# A positive margin, and the box nudged a little past the contact. With
	# margin = 0 at the exact contact pose, a grazing touch counts as zero
	# penetration, so intersect_shape reports "nothing overlaps" and the query
	# appears to contradict the sweep that called it. Nudge past the touch so the
	# overlap is real, then name what is there.
	params.margin = 0.15
	var hits: Array[Dictionary] = space.intersect_shape(params, 4)
	if hits.is_empty():
		return "  at %5.2f m along the axis, nothing overlaps" % along
	var who: PackedStringArray = []
	for h: Dictionary in hits:
		var c: Object = h.get("collider")
		who.append("<none>" if c == null else str((c as Node).get_path()))
	who.sort()
	return "  at %5.2f m along the axis: %s" % [along, " ".join(who)]


## Bore radius by direction, measuring the PIPE'S OWN WALL and nothing else.
##
## This deliberately says nothing about other objects in the bore. The seabed is
## supposed to meet the pipe's floor -- on most levels both sit at y = 0.00 -- so
## "somebody else was hit" is not by itself a defect, and an earlier version that
## treated it as one condemned all 16 levels over a surface that belongs there.
##
## Whether something obstructs the turtle is a different question with a different
## answer, and it is asked by _sweep, which tests the turtle's own box and names
## whatever stops it. Two checks, two jobs.
func _bore_polar(space: PhysicsDirectSpaceState3D, pipe: Node3D, bore: float) -> int:
	var pipe_path: String = str(pipe.get_path())
	print("  bore radius by direction (0 = +X, counter-clockwise), pipe's own wall:")
	var bad := 0
	for st: float in [-2.6, -0.9, 0.9, 2.6]:
		var cells: PackedStringArray = []
		var lo := INF
		var hi := -INF
		for i: int in range(DIRS):
			var a: float = TAU * i / DIRS
			var dir := Vector3(cos(a), sin(a), 0.0)
			var origin := Vector3(0.0, pipe.global_position.y, pipe.global_position.z + st)
			# Skip anything that is not the pipe until only the pipe is left, so a
			# platform in the bore cannot make a perfectly good tube look
			# misshapen. A single ray answers only the first thing it hits, hence
			# the loop: excluding one body can uncover another.
			var skip: Array[RID] = []
			var wall := INF
			for attempt: int in range(4):
				var params := PhysicsRayQueryParameters3D.new()
				params.collision_mask = 0xFFFFFFFF
				params.exclude = skip
				params.from = origin
				params.to = origin + dir * (bore + 4.0)
				var hit: Dictionary = space.intersect_ray(params)
				if not hit.has("position"):
					wall = bore + 4.0
					break
				var path: String = str((hit["collider"] as Node).get_path())
				if path.begins_with(pipe_path):
					wall = origin.distance_to(hit["position"])
					break
				skip.append((hit["collider"] as CollisionObject3D).get_rid())
			cells.append("%5.2f" % wall)
			lo = minf(lo, wall)
			hi = maxf(hi, wall)
		print("    z%+5.1f  %s" % [st, " ".join(cells)])
		# The node's origin need not be the bore's exact centre, and a 16-gon ring
		# is not a circle, so judge the spread against a threshold rather than
		# expecting one number. A healthy ring reads 1.40 to 1.56, a spread of 0.16.
		if hi - lo > 0.25:
			printerr("    z%+5.1f  NOT ROUND: the pipe's own wall is %.2f m further out one way than another" % [
				st, hi - lo])
			bad += 1
	return bad


## Terrain straight down the pipe's axis, with the pipe itself excluded.
##
## The exclusion matters: a ray dropped down the axis enters through the bore's
## inner ceiling at axis + radius and never reaches the ground. Without it the
## seabed reads 2.9 m tall and looks like it is blocking the pipe.
func _seabed_through_bore(space: PhysicsDirectSpaceState3D, pipe: Node3D, bore: float,
		excluded: Array[RID]) -> int:
	var clear_floor: float = pipe.global_position.y - bore + 0.05
	var params := PhysicsRayQueryParameters3D.new()
	params.collision_mask = 0xFFFFFFFF
	# The pipe, because a ray down its axis enters through the bore's inner
	# ceiling and never reaches the ground; and the turtle, because it spawns
	# inside the StartPipe and its own back reads 0.97, which looks exactly like a
	# dune if the collider is not named.
	params.exclude = excluded
	var intruding := 0
	var cells: PackedStringArray = []
	var who: Dictionary = {}
	var tall_counts: Dictionary = {}
	var z: float = pipe.global_position.z - 3.8
	while z <= pipe.global_position.z + 3.8 + 0.001:
		# Start below the corridor ceiling (a 0.2 m box at y = 4.6): a ray that
		# begins above it hits the ceiling on every sample.
		params.from = Vector3(0.0, 4.0, z)
		params.to = Vector3(0.0, -3.0, z)
		var hit: Dictionary = space.intersect_ray(params)
		var y: float = hit["position"].y if hit.has("position") else -99.0
		cells.append("%5.2f" % y)
		if y > clear_floor:
			intruding += 1
		var name := "<nothing>"
		if hit.has("collider"):
			name = str((hit["collider"] as Node).get_path())
		who[name] = int(who.get(name, 0)) + 1
		# Remember who was in the way where it mattered, not just who was hit
		# somewhere: on most levels the seabed is under every sample and only one
		# platform is the actual problem, and a bare count hides which.
		if y > clear_floor and name != "<nothing>":
			tall_counts[name] = int(tall_counts.get(name, 0)) + 1
		z += 3.8 * 2.0 / AXIS_SAMPLES
	print("  ground / obstacle height down the bore axis (x=0, pipe excluded), clear floor y%+.2f:" % clear_floor)
	print("    %s" % " ".join(cells))
	var parts: PackedStringArray = []
	for k: String in who:
		parts.append("%s x%d" % [k, int(who[k])])
	print("    hit by: %s" % " ".join(parts))
	if intruding > 0:
		var tall: Dictionary = {}
		for name: String in tall_counts:
			tall[name] = int(tall[name])
		var listed: PackedStringArray = []
		for k: String in tall_counts:
			listed.append("%s x%d" % [k, int(tall_counts[k])])
		printerr("  OCCLUDED BORE: something sits in the tube at %d of %d samples: %s" % [
			intruding, cells.size(), " ".join(listed)])
		return 1
	print("  nothing else is in the bore along its whole length")
	return 0


# --- input ---------------------------------------------------------------------


## Does the key that means "up" actually raise the turtle?
##
## ui_up is bound to W and the up arrow in project.godot, so the answer has to be
## yes. It was not: the controller's get_axis("ui_up", "ui_down") took ui_up as the
## NEGATIVE action, so holding W dove.
func _vertical_polarity(turtle: CharacterBody3D, probe: Vector3) -> int:
	var results := {}
	for action: String in ["ui_up", "ui_down"]:
		turtle.global_position = probe
		turtle.velocity = Vector3.ZERO
		await physics_frame
		turtle.global_position = probe
		turtle.velocity = Vector3.ZERO
		Input.action_press(action)
		for _i in 20:
			await physics_frame
		Input.action_release(action)
		results[action] = turtle.global_position.y - probe.y
		for _i in 4:
			await physics_frame
	for action: String in ["ui_up", "ui_down"]:
		var dy: float = results[action]
		print("  %-8s moved the turtle %+.3f m in y  ->  %s" % [
			action, dy,
			"rises" if dy > 0.02 else ("SINKS" if dy < -0.02 else "no movement")])
	if float(results.get("ui_up", 0.0)) <= 0.02:
		printerr("  POLARITY: ui_up (W / up arrow) pushes the turtle DOWN; vertical input is inverted")
		return 1
	# Both keys rising means the sign check above passed for the wrong reason, and
	# a probe that cannot fail is worse than no probe.
	if float(results.get("ui_down", 0.0)) >= -0.02:
		printerr("  POLARITY: ui_down also raises the turtle, so the up/down axes are not opposed")
		return 1
	print("  ui_up raises the turtle and ui_down sinks it, as the bindings imply")
	return 0


# --- dynamic -------------------------------------------------------------------


## Drive the real player controller into the pipe and see whether it gets through.
##
## This is the test that matches what a player does, and it covers things no static
## query can: gravity, the absence of any lateral input (player_controller forces
## velocity.x = 0 every frame, so the player cannot side-step out of trouble), and
## move_and_slide's depenetration against whatever the collider is made of.
func _traverse(world: Node, pipe_name: String, spawn: Vector3, hold_up: bool, label: String,
		y_offset: float = 0.0, must_pass: bool = true) -> int:
	var pipe: Node3D = world.find_child(pipe_name, true, false) as Node3D
	var turtle: CharacterBody3D = null
	for n: Node in world.find_children("*", "CharacterBody3D", true, false):
		if n.is_in_group("player"):
			turtle = n
			break
	if pipe == null or turtle == null:
		printerr("  no ", pipe_name, " or player to drive")
		return 1

	turtle.global_position = Vector3(spawn.x, spawn.y + y_offset, spawn.z)
	turtle.velocity = Vector3.ZERO
	await physics_frame

	# ui_right yields direction = +1, and the controller turns that into
	# velocity.z = -speed, which is -Z: toward the pipe and the goal.
	Input.action_press("ui_right")
	if hold_up:
		Input.action_press("ui_up")
	var t := 0.0
	var z0: float = turtle.global_position.z
	var last_z: float = z0
	var stalled_for := 0.0
	var worst := 0.0
	var lowest: float = turtle.global_position.y
	var trace: PackedStringArray = []
	for step: int in range(420):
		await physics_frame
		t += 1.0 / 60.0
		# Hit-stop and death both mutate Engine.time_scale; keep the clock sane so
		# the stall timer below means wall-clock seconds.
		if not is_equal_approx(Engine.time_scale, 1.0):
			Engine.time_scale = 1.0
		var p: Vector3 = turtle.global_position
		lowest = minf(lowest, p.y)
		if step % 12 == 0 and trace.size() < 8:
			trace.append("t%4.1f z%+7.2f y%+6.2f" % [t, p.z, p.y])
		var moved: float = absf(p.z - last_z)
		last_z = p.z
		# With the key held the turtle should always be making progress along z.
		if moved < 0.02:
			stalled_for += 1.0 / 60.0
		else:
			stalled_for = 0.0
		worst = maxf(worst, stalled_for)
		if p.z < pipe.global_position.z - 6.0:
			break
	Input.action_release("ui_right")
	Input.action_release("ui_up")
	for _i in 4:
		await physics_frame

	var end: Vector3 = turtle.global_position
	var passed: bool = end.z < pipe.global_position.z - 4.0
	print("  %-24s spawns at z%+.2f y%+.2f" % [label, spawn.z, spawn.y + y_offset])
	print("  %-24s -> z%+.2f y%+.2f (lowest y%+.2f), pipe at z%+.2f" % [
		"", end.z, end.y, lowest, pipe.global_position.z])
	print("  %-24s    %s" % ["", "  ".join(trace)])
	if not must_pass:
		print("  %-24s    (informational: holding swim pins it to the bore wall)" % [""])
		return 0
	if not passed:
		printerr("  %-24s STUCK: %.2f m short of the far side, longest stall %.2f s" % [
			label, pipe.global_position.z - 4.0 - end.z, worst])
		return 1
	if worst > 0.35:
		printerr("  %-24s STALL: got through but crawled, longest stall %.2f s" % [label, worst])
		return 1
	print("  %-24s OK: through, longest stall %.2f s" % [label, worst])
	return 0
