class_name Tuning
extends RefCounted

## One place for the gameplay numbers.
##
## Change a value here, save, then run the game again. These are constants, so
## the change takes effect on the next run (not while the game is already open).
##
## Nothing in this file depends on the rest of the game. If you are looking for
## "how fast does the turtle swim" or "how much does litter hurt", it is here.
##
## For things you may want to swap per scene (models, sounds, animation names),
## use the exported fields on the scene instead. See docs/CUSTOMISING.md.

# ---------------------------------------------------------------------------
# Player movement and camera
# ---------------------------------------------------------------------------
class Player:
	## Side-to-side swim speed, in metres per second.
	const SPEED := 3.0
	## Upward burst from the jump / accept key.
	const JUMP_SPEED := 2.0
	## Up and down swim speed.
	const SWIM_SPEED := 3.0
	## Speed while the boost key is held.
	const BOOST_SPEED := 4.0
	## Short pause before a boost starts, so a tap does not boost.
	const BOOST_DELAY := 0.2
	## Normal camera field of view.
	const CAMERA_FOV := 90.0
	## Camera field of view while boosting.
	const BOOST_FOV := 110.0
	## How quickly the camera fov moves between the two values above.
	const FOV_LERP_SPEED := 5.0
	## How long the turtle blinks and ignores hits after damage.
	const INVULNERABLE_SECONDS := 1.0
	## The soft roof height. Above this the turtle is eased back down.
	const ROOF_HEIGHT := 4.2
	## How hard the roof pushes down. Higher values feel firmer.
	const ROOF_PUSH := 2.5
	## Falling below this height costs a life.
	const FALL_LIMIT := -15.0
	## Where the camera looks, relative to the turtle.
	const CAMERA_LOOK_HEIGHT := 0.3
	## How far the camera may trail behind the turtle.
	const CAMERA_MAX_LAG := 1.0
	## How quickly the model tilts up and down when swimming vertically.
	const TILT_SPEED := 8.0
	## Tilt angle when swimming up or down, in radians.
	const TILT_ANGLE := PI / 25.0
	## Animation speed while idle.
	const IDLE_ANIM_SPEED := 1.0
	## Animation speed while boosting.
	const BOOST_ANIM_SPEED := 1.5
	## How long the eat animation plays, in seconds.
	const EAT_ANIM_SECONDS := 0.6
	## How long the hurt animation plays, in seconds.
	const HURT_ANIM_SECONDS := 0.5
	## Camera blending inside the start and end pipes.
	const PIPE_CAMERA_HALF_LENGTH := 2.4
	const PIPE_CAMERA_RADIUS := 2.0
	const PIPE_CAMERA_FALLOFF := 1.0

# ---------------------------------------------------------------------------
# Game feel (screen shake and hit-stop)
# ---------------------------------------------------------------------------
class Feel:
	## Shake strength when the turtle is hit.
	const SHAKE_DAMAGE := 0.6
	## Shake strength when a boost starts.
	const SHAKE_BOOST := 0.22
	## How quickly shake fades. Higher values stop shaking sooner.
	const SHAKE_DECAY := 1.7
	## How far the camera moves while shaking.
	const SHAKE_POSITION := 0.16
	## How much the camera rolls while shaking.
	const SHAKE_ROLL := 0.055
	## Freeze time after a hit, in seconds.
	const HITSTOP_SECONDS := 0.11
	## Game speed during the freeze. 0.04 is a very short pause.
	const HITSTOP_TIME_SCALE := 0.04

# ---------------------------------------------------------------------------
# Collectable jellyfish
# ---------------------------------------------------------------------------
class Collectable:
	## Points added to the score for one jellyfish.
	const POINTS := 50
	## How far the jellyfish bobs up and down, in metres.
	const BOB_HEIGHT := 0.3
	## How fast it bobs.
	const BOB_SPEED := 1.4
	## How far it sways left and right.
	const SWAY := 0.1
	## How fast it spins.
	const SPIN_SPEED := 1.6
	## Glow colours. Change these to recolour every jellyfish at once.
	const DOME_COLOR := Color(0.78, 0.42, 0.9, 0.55)
	const DOME_GLOW := Color(1.0, 0.75, 1.0)
	const TENTACLE_COLOR := Color(0.9, 0.62, 0.96, 0.75)
	## Glow pulse: brightness moves between base - sway and base + sway.
	const PULSE_BASE := 1.2
	const PULSE_SWAY := 0.6
	const PULSE_SPEED := 2.2
	const DOME_EMISSION := 1.6
	const TENTACLE_EMISSION := 0.8

# ---------------------------------------------------------------------------
# Hazards (ocean litter)
# ---------------------------------------------------------------------------
class Hazard:
	## Damage one touch does. Health is 100, so 25 means four touches.
	const DAMAGE := 25
	## How fast a patrolling hazard moves, in metres per second.
	const PATROL_SPEED := 1.5
	## The warning marker above the litter.
	const WARNING_COLOR := Color(1.0, 0.86, 0.24, 1.0)
	const WARNING_HEIGHT := 0.78
	const WARNING_FONT_SIZE := 56
	const WARNING_PIXEL_SIZE := 0.008
	const WARNING_OUTLINE_SIZE := 16
	## Pulse speed and size of the warning marker.
	const WARNING_PULSE_SPEED := 4.0
	const WARNING_ALPHA_MIN := 0.72
	const WARNING_ALPHA_MAX := 1.0
	const WARNING_SCALE_SWAY := 0.08

# ---------------------------------------------------------------------------
# Rules: health, lives and stars
# ---------------------------------------------------------------------------
class Rules:
	## Health at the start of a level. Hazard damage is subtracted from this.
	const MAX_HEALTH := 100
	## Lives per attempt. Losing them all ends the run.
	const STARTING_LIVES := 3
	## A clear earns three stars: finish, collect most of the jellyfish, and take
	## no damage.
	const STARS := 3
	## Fraction of jellyfish needed for the jelly star (0.8 = 80%). 80% leaves
	## room for a missed collectable without losing the star.
	const JELLY_STAR_RATIO := 0.8

# ---------------------------------------------------------------------------
# Asset paths that are loaded from code
# ---------------------------------------------------------------------------
class Assets:
	const FEEDBACK_BURST := "res://scenes/effects/feedback_burst.tscn"
	const COLLECT_SOUND := "res://assets/audio/jellyfish-plastic-crunch.mp3"
	const COLLECT_OUTLINE := "res://materials/glow_outline_pink.tres"
	const HAZARD_OUTLINE := "res://materials/glow_outline_red.tres"

# ---------------------------------------------------------------------------
# Campaign order
# ---------------------------------------------------------------------------
class Levels:
	## The level list, in play order. Add or reorder paths here and the level
	## select, Continue button and save file all follow along.
	const PATHS: Array[String] = [
		"res://scenes/levels/tutorial.tscn",
		"res://scenes/levels/level_1.tscn",
		"res://scenes/levels/level_2.tscn",
		"res://scenes/levels/level_3.tscn",
		"res://scenes/levels/level_4.tscn",
		"res://scenes/levels/level_5.tscn",
		"res://scenes/levels/level_6.tscn",
		"res://scenes/levels/level_7.tscn",
		"res://scenes/levels/level_8.tscn",
		"res://scenes/levels/level_9.tscn",
		"res://scenes/levels/level_10.tscn",
		"res://scenes/levels/level_11.tscn",
		"res://scenes/levels/level_12.tscn",
		"res://scenes/levels/level_13.tscn",
		"res://scenes/levels/level_14.tscn",
		"res://scenes/levels/level_15.tscn",
	]
