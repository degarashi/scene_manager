extends GdUnitTestSuite

## DFadeLayer — tests for the generic fade overlay.
## Verifies the ScreenTransitioner contract (set_clickable / set_layer / play_out / play_in / is_playing)
## and the show_label behavior.

const FADE_SCENE := preload("res://addons/scene_manager/transitions/fade/DFadeLayer.tscn")

# Short duration for fast playback (seconds)
const _FAST_SPEED: float = 0.02


func _instance() -> DFadeLayer:
	var fade := FADE_SCENE.instantiate() as DFadeLayer
	add_child(fade)
	return fade


## Waits until the fade completes. Polls per frame instead of using a fixed
## timer, so completion is reliably awaited even with frame delays during a
## full suite run.
func _await_fade_complete(fade: DFadeLayer, timeout_ms: int = 2000) -> void:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while fade.is_playing() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


# ------------- [Test: Instantiation] -------------


## DFadeLayer can be treated as a ScreenTransitioner
func test_is_screen_transitioner() -> void:
	var fade := _instance()
	assert_bool(fade is ScreenTransitioner).is_true()


## _ready creates the CanvasLayer / ColorRect
func test_ready_initializes_children() -> void:
	var fade := _instance()
	@warning_ignore("unsafe_property_access")
	assert_object(fade._canvas_layer).is_not_null()
	@warning_ignore("unsafe_property_access")
	assert_object(fade._fade_rect).is_not_null()


# ------------- [Test: set_clickable] -------------


## set_clickable(false) blocks input; true makes it pass through
func test_set_clickable_toggle() -> void:
	var fade := _instance()
	@warning_ignore("unsafe_property_access")
	var rect: ColorRect = fade._fade_rect

	fade.set_clickable(false)
	assert_int(rect.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	fade.set_clickable(true)
	assert_int(rect.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


# ------------- [Test: set_layer] -------------


## set_layer() updates the CanvasLayer layer
func test_set_layer() -> void:
	var fade := _instance()
	@warning_ignore("unsafe_property_access")
	var canvas: CanvasLayer = fade._canvas_layer

	fade.set_layer(42)
	assert_int(canvas.layer).is_equal(42)


# ------------- [Test: is_playing] -------------


## play_out / play_in complete immediately with duration <= 0
func test_zero_speed_returns_immediately() -> void:
	var fade := _instance()
	assert_bool(fade.is_playing()).is_false()

	fade.play_out(0.0)
	assert_bool(fade.is_playing()).is_false()

	fade.play_in(-1.0)
	assert_bool(fade.is_playing()).is_false()


## is_playing() is true while play_out runs and false after completion
func test_play_out_lifecycle() -> void:
	var fade := _instance()
	assert_bool(fade.is_playing()).is_false()

	fade.play_out(_FAST_SPEED)
	assert_bool(fade.is_playing()).is_true()

	await _await_fade_complete(fade)
	assert_bool(fade.is_playing()).is_false()


## is_playing() is true while play_in runs and false after completion
func test_play_in_lifecycle() -> void:
	var fade := _instance()
	assert_bool(fade.is_playing()).is_false()

	fade.play_in(_FAST_SPEED)
	assert_bool(fade.is_playing()).is_true()

	await _await_fade_complete(fade)
	assert_bool(fade.is_playing()).is_false()


# ------------- [Test: play_out / play_in] -------------


## The play_out -> play_in sequence toggles the visibility state
func test_play_out_then_play_in() -> void:
	var fade := _instance()
	@warning_ignore("unsafe_property_access")
	var canvas: CanvasLayer = fade._canvas_layer
	@warning_ignore("unsafe_property_access")
	var rect: ColorRect = fade._fade_rect

	fade.play_out(_FAST_SPEED)
	await _await_fade_complete(fade)
	assert_bool(canvas.visible).is_true()
	assert_float(rect.color.a).is_equal(1.0)

	fade.play_in(_FAST_SPEED)
	await _await_fade_complete(fade)
	assert_bool(canvas.visible).is_false()
	assert_float(rect.color.a).is_equal(0.0)


# ------------- [Test: show_label] -------------


## show_label creates and shows the label; alpha returns to 0 after completion
func test_show_label() -> void:
	var fade := _instance()

	await fade.show_label("Level 1", 0.05, 0.02)

	@warning_ignore("unsafe_property_access")
	assert_object(fade._label).is_not_null()
	@warning_ignore("unsafe_property_access")
	assert_str(fade._label.text).is_equal("Level 1")
	@warning_ignore("unsafe_property_access")
	assert_float(fade._label.modulate.a).is_equal(0.0)
