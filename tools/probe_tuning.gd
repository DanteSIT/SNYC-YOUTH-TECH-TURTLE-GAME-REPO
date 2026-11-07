extends SceneTree
## Checks that the shared gameplay values really come from tuning.gd.
##
## This keeps the "one file to tune" promise honest: if a script stops reading
## Tuning, this probe fails. It does not touch the real save file.
##
## Usage: godot --headless --path . --script res://tools/probe_tuning.gd

const COLLECTABLE := "res://scenes/objects/collectable.tscn"
const HAZARD := "res://scenes/objects/hazard.tscn"
const TURTLE := "res://scenes/player/turtle.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gm: Node = get_root().get_node("GameManager")
	var consts: Dictionary = gm.get_script().get_script_constant_map()

	# Rules and the level list are aliased by GameManager so the rest of the
	# game keeps a stable name to call.
	_expect("max health comes from Tuning",
		consts["MAX_HEALTH"] == Tuning.Rules.MAX_HEALTH)
	_expect("starting lives come from Tuning",
		consts["START_LIVES"] == Tuning.Rules.STARTING_LIVES)
	_expect("star count comes from Tuning",
		consts["STARS"] == Tuning.Rules.STARS)
	_expect("jelly star ratio comes from Tuning",
		is_equal_approx(consts["JELLY_STAR_RATIO"], Tuning.Rules.JELLY_STAR_RATIO))
	_expect("level list comes from Tuning",
		consts["LEVELS"] == Tuning.Levels.PATHS)
	_expect("level list is not empty", Tuning.Levels.PATHS.size() > 0)

	# Object defaults are read from Tuning too, so changing one number there
	# changes every instance that has not been overridden in the inspector.
	var jelly := (load(COLLECTABLE) as PackedScene).instantiate()
	_expect("jelly points come from Tuning",
		jelly.points == Tuning.Collectable.POINTS)
	_expect("jelly bob comes from Tuning",
		is_equal_approx(jelly.bob_amplitude, Tuning.Collectable.BOB_HEIGHT))
	_expect("jelly spin comes from Tuning",
		is_equal_approx(jelly.spin_speed, Tuning.Collectable.SPIN_SPEED))
	_expect("jelly model node is exported", jelly.model_node == "jeLLyfiSH")
	jelly.free()

	var litter := (load(HAZARD) as PackedScene).instantiate()
	_expect("hazard damage comes from Tuning",
		litter.damage == Tuning.Hazard.DAMAGE)
	_expect("hazard patrol comes from Tuning",
		is_equal_approx(litter.patrol_speed, Tuning.Hazard.PATROL_SPEED))
	litter.free()

	# Model and animation slots are exported, so a different turtle can be
	# dropped in without editing the script.
	var turtle := (load(TURTLE) as PackedScene).instantiate()
	var animator: Node = turtle.get_node("CharacterBody3D/PlayerAnimator")
	_expect("animator model slot is exported",
		animator.model_path == NodePath("../Odysse"))
	_expect("animator player slot is exported",
		animator.animation_player_path == NodePath("AnimationPlayer"))
	_expect("animator clip names are exported",
		animator.idle_animation == "IDLE" and animator.swim_animation == "SWIMMING")
	var visuals: Node = turtle.get_node("CharacterBody3D/PlayerVisuals")
	_expect("skin slot is exported",
		visuals.skin_path == NodePath("../Odysse/Armature_002/Skeleton3D/Turtle_LowPoly_Skin"))
	turtle.free()

	# The menu backdrop is a readable table instead of raw matrices.
	var menu_script: Script = load("res://scripts/ui/menu.gd")
	var menu_consts: Dictionary = menu_script.get_script_constant_map()
	var backdrop: Array = menu_consts["BACKDROP"]
	_expect("menu backdrop has rows", backdrop.size() > 0)
	var row_ok := true
	for row in backdrop:
		if not (row.has("scene") and row.has("name") and row.has("position")
				and row.has("rotation") and row.has("scale")):
			row_ok = false
	_expect("every backdrop row has scene, name, position, rotation and scale", row_ok)

	if _failures == 0:
		print("TUNING OK")
	else:
		print("TUNING FAILED: ", _failures, " check(s)")
	quit(1 if _failures > 0 else 0)


func _expect(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
		print("FAIL: ", label)
