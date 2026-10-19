extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed: PackedScene = load("res://scenes/objects/hazard_can.tscn")
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	print("script attached: ", root.get_script())
	print("has _ready ran? patrol_end=", root.get("patrol_end"))
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	print("mi=", mi.name, " active=", mi.get_active_material(0))
	var m: Material = mi.get_active_material(0)
	print("next_pass=", m.next_pass if m != null else "null")
	print("--- now call apply manually ---")
	GlowOutline.apply(root, load("res://materials/glow_outline_red.tres"))
	var m2: Material = mi.get_active_material(0)
	print("after: active=", m2, " next_pass=", m2.next_pass if m2 != null else "null")
	if m2 != null and m2.next_pass != null:
		print("  grow=", m2.next_pass.get("grow"), " grow_amount=", m2.next_pass.get("grow_amount"))
	quit()
