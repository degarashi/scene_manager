extends GdUnitTestSuite

## Tests for FadeTransitioner — the default fade in/out transition effect.
## Verifies instantiation, _ready initialization, property setters,
## animation playback lifecycle (is_playing, play_out, play_in),
## and node cleanup.

const FADE_SCENE := preload(
	"res://addons/scene_manager/transitions/fade/fade_transitioner.tscn"
)

# Speed value for fast playback: 0.02 → custom_speed = 50 → ~20ms duration
const _FAST_SPEED: float = 0.02


# ------------- [Test: Instantiation] -------------


## FadeTransitioner can be created with .new().
## NOTE: Does NOT add to tree; @onready children (%fade, etc.)
## only resolve when added from the packed scene.
func test_can_instance_with_new() -> void:
	var ft := FadeTransitioner.new()
	assert_object(ft).is_not_null()
	assert_bool(ft is ScreenTransitioner).is_true()
	ft.free()


## When instantiated from the packed scene and added to the tree,
## _ready() initializes all @onready references (CanvasLayer, ColorRect,
## AnimationPlayer).
func test_ready_initializes_children() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var anim_player: AnimationPlayer = ft._animation_player as AnimationPlayer
	assert_object(anim_player).is_not_null()

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var color_rect: ColorRect = ft._fade_color_rect as ColorRect
	assert_object(color_rect).is_not_null()

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var canvas: CanvasLayer = ft._canvas as CanvasLayer
	assert_object(canvas).is_not_null()


# ------------- [Test: set_clickable] -------------


## set_clickable(false) sets mouse filter to MOUSE_FILTER_STOP (blocking input).
func test_set_clickable_false_blocks_input() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var rect: ColorRect = ft._fade_color_rect

	ft.set_clickable(false)
	assert_int(rect.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


## set_clickable(true) sets mouse filter to MOUSE_FILTER_IGNORE (passthrough).
func test_set_clickable_true_passes_input() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var rect: ColorRect = ft._fade_color_rect

	ft.set_clickable(true)
	assert_int(rect.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## set_clickable toggles between block and passthrough states.
func test_set_clickable_toggle() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var rect: ColorRect = ft._fade_color_rect

	ft.set_clickable(false)
	assert_int(rect.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	ft.set_clickable(true)
	assert_int(rect.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

	ft.set_clickable(false)
	assert_int(rect.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


# ------------- [Test: set_layer] -------------


## set_layer() correctly updates the CanvasLayer layer property.
func test_set_layer() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var canvas: CanvasLayer = ft._canvas

	ft.set_layer(42)
	assert_int(canvas.layer).is_equal(42)


## set_layer() accepts and stores arbitrary integer values.
func test_set_layer_multiple_values() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var canvas: CanvasLayer = ft._canvas

	ft.set_layer(10)
	assert_int(canvas.layer).is_equal(10)

	ft.set_layer(999)
	assert_int(canvas.layer).is_equal(999)


# ------------- [Test: is_playing] -------------


## is_playing() returns false before any transition method is called.
func test_is_playing_initial_false() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	assert_bool(ft.is_playing()).is_false()


## is_playing() is true immediately after play_out starts,
## and false after the animation completes.
func test_is_playing_during_and_after_play_out() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	assert_bool(ft.is_playing()).is_false()

	ft.play_out(_FAST_SPEED)
	assert_bool(ft.is_playing()).is_true()

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var anim_player: AnimationPlayer = ft._animation_player
	await anim_player.animation_finished
	await get_tree().process_frame
	assert_bool(ft.is_playing()).is_false()


## is_playing() is true immediately after play_in starts,
## and false after the animation completes.
func test_is_playing_during_and_after_play_in() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	assert_bool(ft.is_playing()).is_false()

	ft.play_in(_FAST_SPEED)
	assert_bool(ft.is_playing()).is_true()

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var anim_player: AnimationPlayer = ft._animation_player
	await anim_player.animation_finished
	await get_tree().process_frame
	assert_bool(ft.is_playing()).is_false()


# ------------- [Test: play_out] -------------


## play_out() with positive speed plays the fade-out animation and
## starts the AnimationPlayer.
func test_play_out_positive_speed_animates() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var anim_player: AnimationPlayer = ft._animation_player

	assert_bool(anim_player.is_playing()).is_false()
	assert_bool(ft.is_playing()).is_false()

	ft.play_out(_FAST_SPEED)
	assert_bool(anim_player.is_playing()).is_true()
	assert_bool(ft.is_playing()).is_true()

	await anim_player.animation_finished
	await get_tree().process_frame
	assert_bool(anim_player.is_playing()).is_false()
	assert_bool(ft.is_playing()).is_false()


## play_out() returns immediately when speed is zero.
func test_play_out_zero_speed_returns_immediately() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	ft.play_out(0.0)
	assert_bool(ft.is_playing()).is_false()


## play_out() returns immediately when speed is negative.
func test_play_out_negative_speed_returns_immediately() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	ft.play_out(-1.0)
	assert_bool(ft.is_playing()).is_false()


# ------------- [Test: play_in] -------------


## play_in() with positive speed plays the fade-in animation and
## starts the AnimationPlayer.
func test_play_in_positive_speed_animates() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	@warning_ignore("unsafe_property_access", "unsafe_cast")
	var anim_player: AnimationPlayer = ft._animation_player

	assert_bool(anim_player.is_playing()).is_false()
	assert_bool(ft.is_playing()).is_false()

	ft.play_in(_FAST_SPEED)
	assert_bool(anim_player.is_playing()).is_true()
	assert_bool(ft.is_playing()).is_true()

	await anim_player.animation_finished
	await get_tree().process_frame
	assert_bool(anim_player.is_playing()).is_false()
	assert_bool(ft.is_playing()).is_false()


## play_in() returns immediately when speed is zero.
func test_play_in_zero_speed_returns_immediately() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	ft.play_in(0.0)
	assert_bool(ft.is_playing()).is_false()


## play_in() returns immediately when speed is negative.
func test_play_in_negative_speed_returns_immediately() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	ft.play_in(-1.0)
	assert_bool(ft.is_playing()).is_false()


# ------------- [Test: Cleanup] -------------


## queue_free properly removes the transitioner from the scene tree.
func test_queue_free_cleans_up_node() -> void:
	@warning_ignore("unsafe_cast")
	var ft: ScreenTransitioner = FADE_SCENE.instantiate()
	add_child(ft)

	assert_bool(is_instance_valid(ft)).is_true()

	ft.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_valid(ft)).is_false()
