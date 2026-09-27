extends SceneTree
## Checks that a boss model FACES the player it is chasing, and works out which
## way the model faces from its own geometry rather than assuming a convention.
##
## WHY GEOMETRY, NOT -Z
## --------------------
## zshark.glb turned out to face +Z, not -Z. Its tail fin is a tall, laterally
## thin plate (X 0.088 wide, Y 1.153 tall) at local z = -4.06, which puts the
## head at the +Z end. Assuming the glTF -Z convention here is not a harmless
## default: it makes this probe report a correct model as broken. It already did
## once, and the first version of tools/diag_shark_facing.gd made the same
## mistake by calling the widest slab the head -- that slab is the pectoral fins,
## which sit behind the head and are both the widest and the deepest thing on
## the animal.
##
## So the tail is found by shape: the caudal fin is by a wide margin the most
## vertically-elongated, laterally-thin slab, so the slab maximising Y/X is the
## tail, and the model faces the other way. A model where that does not produce a
## clear winner is reported INCONCLUSIVE rather than guessed at.
##
## WHAT THIS IS FOR
## ----------------
## The shark was authored with a 180 degree yaw baked into its Body while
## shark_boss.gd points the node's -Z at the player, so the shark swam tail-first.
## Nothing reported it: the scene loaded, the hit box worked, damage still
## applied. Only looking at it caught it. This turns that into a number.
##
## Usage:
##   godot --headless --path . --script res://tools/probe_boss_facing.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scenes: PackedStringArray = [
		"res://scenes/objects/shark_boss.tscn",
		"res://scenes/objects/boss.tscn",
	]
	var checked: int = 0
	var failures: int = 0
	var inconclusive: int = 0
	print("")
	for path: String in scenes:
		var packed: PackedScene = load(path)
		if packed == null:
			printerr("BOSS FAIL cannot load ", path)
			failures += 1
			continue
		var boss: Node = packed.instantiate()
		get_root().add_child(boss)
		for _i in 4:
			await process_frame

		var body: Node3D = boss.get_node_or_null("Body") as Node3D
		if body == null:
			print("  %-30s  no Body node, skipped" % path.get_file())
			inconclusive += 1
			boss.queue_free()
			continue

		var mesh: Mesh = _biggest_mesh(body)
		if mesh == null:
			print("  %-30s  no mesh, skipped" % path.get_file())
			inconclusive += 1
			boss.queue_free()
			continue

		var fwd: Vector3 = _forward_from_geometry(mesh, path)
		if fwd == Vector3.ZERO:
			print("  %-30s  INCONCLUSIVE: no clear tail fin, cannot tell which way it faces" % path.get_file())
			inconclusive += 1
			boss.queue_free()
			continue

		# The stand-in player has to exist, and the boss's own _physics_process has
		# to have run at least once, BEFORE _spawn_behind_player() is called: that
		# method dereferences _player.global_basis.z with no null check, so calling
		# it too early throws, leaves the boss sitting on the origin, and the boss
		# then ends up coincident with the player -- where the direction to the
		# player is the zero vector, angle_to() returns 0, and a naive threshold
		# reports a perfect score. That is exactly how the first version of this
		# probe passed both the correct and the reversed model.
		var player := Node3D.new()
		player.name = "ProbePlayer"
		player.add_to_group("player")
		player.set_script(_fake_player())
		get_root().add_child(player)
		player.global_position = Vector3(0.0, 0.8, 0.0)
		for _i in 4:
			await process_frame
		if not boss.has_method("_spawn_behind_player"):
			boss.set("global_position", Vector3(0.0, 3.0, 12.0))
		else:
			boss.call("_spawn_behind_player")
			var d: float = (boss as Node3D).global_position.distance_to(player.global_position)
			if d < 1.0:
				printerr("BOSS FAIL %s did not spawn clear of the player (%.2f m); the probe cannot measure a facing" % [
					path.get_file(), d])
				failures += 1
				inconclusive += 1
				boss.queue_free()
				player.queue_free()
				continue
		for _i in 30:
			if boss.has_method("_physics_process"):
				boss.call("_physics_process", 1.0 / 60.0)
				await process_frame

		# Rotate the mesh-local forward axis into world space through the Body.
		var world_fwd: Vector3 = (body.global_basis * fwd).normalized()
		var to_player: Vector3 = player.global_position - (body as Node3D).global_position
		to_player.y = 0.0
		# A near-zero separation makes the angle meaningless; refuse to score it
		# rather than letting it read as 0 degrees and pass.
		if to_player.length() < 1.0:
			printerr("BOSS FAIL %s ended up on top of the player (%.2f m); cannot measure a facing" % [
				path.get_file(), to_player.length()])
			failures += 1
			inconclusive += 1
			boss.queue_free()
			player.queue_free()
			continue
		to_player = to_player.normalized()
		var deg: float = rad_to_deg(world_fwd.angle_to(to_player))
		var facing: bool = deg < 45.0
		checked += 1
		if not facing:
			failures += 1
		print("  %-30s  model faces local %s  ->  %6.1f deg from the player  %s" % [
			path.get_file(), _axis_name(fwd), deg, "OK" if facing else "FACING THE WRONG WAY"])
		boss.queue_free()
		player.queue_free()
		await process_frame
	print("")
	if failures > 0:
		printerr("BOSS FAIL %d/%d bosses face away from the player" % [failures, checked])
		quit(1)
		return
	if checked == 0:
		printerr("BOSS FAIL nothing could be checked")
		quit(1)
		return
	print("BOSS OK  %d/%d bosses face the player%s" % [
		checked, checked, "" if inconclusive == 0 else "  (%d inconclusive)" % inconclusive])
	quit(0)


## The mesh-local axis the model's head points along, derived from where its tail
## fin is, or Vector3.ZERO when the animal has no unambiguous tail.
func _forward_from_geometry(mesh: Mesh, path: String) -> Vector3:
	var verts := PackedVector3Array()
	for s: int in range(mesh.get_surface_count()):
		verts.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	if verts.is_empty():
		return Vector3.ZERO

	const SLABS := 16
	var z0: float = mesh.get_aabb().position.z
	var span: float = maxf(0.0001, mesh.get_aabb().size.z)
	var best_ratio: float = -1.0
	var best_mid: float = 0.0
	var runner_up: float = -1.0
	for s: int in range(SLABS):
		var za: float = z0 + span * s / SLABS
		var zb: float = z0 + span * (s + 1) / SLABS
		var xmin := INF
		var xmax := -INF
		var ymin := INF
		var ymax := -INF
		var n: int = 0
		for v: Vector3 in verts:
			if v.z >= za and v.z < zb:
				n += 1
				xmin = minf(xmin, v.x)
				xmax = maxf(xmax, v.x)
				ymin = minf(ymin, v.y)
				ymax = maxf(ymax, v.y)
		if n == 0:
			continue
		# A caudal fin is tall and laterally thin; the body is the other way round.
		var ratio: float = (ymax - ymin) / maxf(0.0001, xmax - xmin)
		if ratio > best_ratio:
			runner_up = best_ratio
			best_ratio = ratio
			best_mid = (za + zb) * 0.5
		elif ratio > runner_up:
			runner_up = ratio
	# Require a clear winner, or a symmetric blob will hand back a confident lie.
	if best_ratio < 2.0 or best_ratio < runner_up * 2.0:
		return Vector3.ZERO
	print("      %s: tail fin at local z %+.2f (slab aspect %.1f vs next %.1f), so the head is at %s" % [
		path.get_file(), best_mid, best_ratio, runner_up,
		"+Z" if best_mid < (z0 + span * 0.5) else "-Z"])
	return Vector3.BACK if best_mid < (z0 + span * 0.5) else Vector3.FORWARD


func _axis_name(v: Vector3) -> String:
	if absf(v.x) > 0.5:
		return "+X" if v.x > 0.0 else "-X"
	if absf(v.y) > 0.5:
		return "+Y" if v.y > 0.0 else "-Y"
	return "+Z" if v.z > 0.0 else "-Z"


func _biggest_mesh(body: Node) -> Mesh:
	var best: Mesh = null
	var best_tris: int = -1
	var mis: Array[Node] = []
	_collect(body, mis)
	for m: Node in mis:
		var mesh: Mesh = (m as MeshInstance3D).mesh
		if mesh == null:
			continue
		var tris: int = 0
		for s: int in range(mesh.get_surface_count()):
			var idx: Variant = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
			if idx is PackedInt32Array:
				tris += (idx as PackedInt32Array).size() / 3
			else:
				tris += mesh.surface_get_array_len(s) / 3
		if tris > best_tris:
			best_tris = tris
			best = mesh
	return best


func _fake_player() -> Script:
	var s := GDScript.new()
	s.source_code = """
extends Node3D
func set_flow(_f: float) -> void:
	pass
"""
	s.reload()
	return s


func _collect(from: Node, out: Array[Node]) -> void:
	for c: Node in from.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append(c)
		_collect(c, out)
