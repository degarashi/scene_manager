extends GdUnitTestSuite

## Tests for SMgrTransitionService and its inner class NoOpTransitioner.
## Verifies initialization, player lifecycle, transition setup, and cleanup.

const TransitionService := preload(
	"res://addons/scene_manager/transition/transition_service.gd"
)
const SceneLoadOptions := preload(
	"res://addons/scene_manager/data_store/scene_load_options.gd"
)

var _service: SMgrTransitionService


func before_test() -> void:
	_service = TransitionService.new(null, DLoggerClass.new(), null)
	add_child(_service)


func after_test() -> void:
	if is_instance_valid(_service):
		_service.queue_free()


# ------------- [Inner Classes] -------------


## Captures values passed to set_clickable / set_layer for verification.
class CaptureTransitioner extends ScreenTransitioner:
	var captured_clickable: bool = false
	var captured_layer: int = -1

	func set_clickable(p: bool) -> void:
		captured_clickable = p

	func set_layer(p: int) -> void:
		captured_layer = p

	func play_out(_speed: float) -> void:
		pass

	func play_in(_speed: float) -> void:
		pass


# ------------- [Test: Service Initialization] -------------


## Verify constructor correctly holds dependency references
func test_init_stores_references() -> void:
	var log := DLoggerClass.new()

	@warning_ignore("unsafe_call_argument")
	var service := TransitionService.new(null, log, null)
	assert_object(service).is_not_null()
	service.queue_free()


## Verify _ready creates the main transition player
func test_ready_creates_main_player() -> void:
	# _service was added to the tree in before_test, so _ready should have fired
	assert_object(_service.get_main_player()).is_not_null()


## Verify _ready creates NoOpTransitioner (source is null)
func test_ready_creates_noop_when_no_source() -> void:
	var player := _service.get_main_player()
	assert_bool(player is ScreenTransitioner).is_true()


# ------------- [Test: get_main_player] -------------


## Verify get_main_player returns non-null ScreenTransitioner
func test_get_main_player_returns_non_null() -> void:
	var player := _service.get_main_player()
	assert_object(player).is_not_null()


## Verify get_main_player returns a ScreenTransitioner type
func test_get_main_player_is_screen_transitioner() -> void:
	var player := _service.get_main_player()
	assert_bool(player is ScreenTransitioner).is_true()


## Verify get_main_player always returns the same instance
func test_get_main_player_is_stable_reference() -> void:
	var player_a := _service.get_main_player()
	var player_b := _service.get_main_player()
	assert_object(player_a).is_equal(player_b)


# ------------- [Test: NoOpTransitioner] -------------


## NoOpTransitioner.play_out(speed>0) sets _is_playing and clears it after a frame
func test_noop_play_out_with_positive_speed() -> void:
	var noop := TransitionService.NoOpTransitioner.new()
	add_child(noop)

	assert_bool(noop.is_playing()).is_false()

	noop.play_out(1.0)

	# Immediately sets _is_playing = true, suspends at await process_frame
	assert_bool(noop.is_playing()).is_true()

	# After waiting 1 frame, playback completes
	await get_tree().process_frame
	assert_bool(noop.is_playing()).is_false()

	noop.queue_free()


## NoOpTransitioner.play_in(speed>0) sets _is_playing and clears it after a frame
func test_noop_play_in_with_positive_speed() -> void:
	var noop := TransitionService.NoOpTransitioner.new()
	add_child(noop)

	assert_bool(noop.is_playing()).is_false()

	noop.play_in(1.0)

	assert_bool(noop.is_playing()).is_true()

	await get_tree().process_frame
	assert_bool(noop.is_playing()).is_false()

	noop.queue_free()


## NoOpTransitioner.play_out(speed<=0) returns immediately without changing _is_playing
func test_noop_play_out_zero_or_negative_speed() -> void:
	var noop := TransitionService.NoOpTransitioner.new()
	add_child(noop)

	noop.play_out(0.0)
	assert_bool(noop.is_playing()).is_false()

	noop.play_out(-1.0)
	assert_bool(noop.is_playing()).is_false()

	noop.queue_free()


## NoOpTransitioner.play_in(speed<=0) returns immediately without changing _is_playing
func test_noop_play_in_zero_or_negative_speed() -> void:
	var noop := TransitionService.NoOpTransitioner.new()
	add_child(noop)

	noop.play_in(0.0)
	assert_bool(noop.is_playing()).is_false()

	noop.play_in(-1.0)
	assert_bool(noop.is_playing()).is_false()

	noop.queue_free()


## NoOpTransitioner.set_clickable / set_layer do nothing (no errors)
func test_noop_setters_are_noops() -> void:
	var noop := TransitionService.NoOpTransitioner.new()
	add_child(noop)

	# These calls should pass without errors
	noop.set_clickable(true)
	noop.set_clickable(false)
	noop.set_layer(0)
	noop.set_layer(999)

	noop.queue_free()

	assert_bool(true).is_true()  # Reaching here means success


## Verify NoOpTransitioner is_playing works through the service
func test_service_noop_is_playing() -> void:
	var player := _service.get_main_player()
	assert_bool(player.is_playing()).is_false()


# ------------- [Test: setup_transition_player] -------------


## Verify setup_transition_player returns main player with default options
func test_setup_transition_player_default_returns_main_player() -> void:
	var opts := SceneLoadOptions.new()
	var player := _service.setup_transition_player(opts)

	assert_object(player).is_not_null()
	assert_object(player).is_equal(_service.get_main_player())


## Verify custom options set clickable / transition_layer
func test_setup_transition_player_custom_options() -> void:
	var opts := SceneLoadOptions.new()
	opts.clickable = true
	opts.transition_layer = 50

	var player := _service.setup_transition_player(opts)
	assert_object(player).is_not_null()
	assert_object(player).is_equal(_service.get_main_player())


## Verify setup_transition_player reflects SceneLoadOptions clickable
func test_setup_transition_player_propagates_clickable() -> void:
	var capturer := CaptureTransitioner.new()
	add_child(capturer)

	# Swap service's internal player with capturer
	_service._transition_player = capturer

	var opts := SceneLoadOptions.new()
	opts.clickable = true
	_service.setup_transition_player(opts)

	assert_bool(capturer.captured_clickable).is_true()

	capturer.queue_free()


## Verify setup_transition_player reflects SceneLoadOptions transition_layer
func test_setup_transition_player_propagates_layer() -> void:
	var capturer := CaptureTransitioner.new()
	add_child(capturer)

	_service._transition_player = capturer

	var opts := SceneLoadOptions.new()
	opts.transition_layer = 42
	_service.setup_transition_player(opts)

	assert_int(capturer.captured_layer).is_equal(42)

	capturer.queue_free()


## Verify default project setting is used when transition_layer = -1
func test_setup_transition_player_default_layer() -> void:
	var capturer := CaptureTransitioner.new()
	add_child(capturer)

	_service._transition_player = capturer

	var opts := SceneLoadOptions.new()
	opts.transition_layer = -1  # Default
	_service.setup_transition_player(opts)

	# Default transition_layer from project settings is 100
	assert_int(capturer.captured_layer).is_equal(100)

	capturer.queue_free()


# ------------- [Test: _get_custom_transitioner] -------------


## Returns null when options.transition_id == Scenes.Id.NONE
func test_get_custom_transitioner_none_returns_null() -> void:
	var opts := SceneLoadOptions.new()
	opts.transition_id = Scenes.Id.NONE

	var result := _service._get_custom_transitioner(opts)
	assert_object(result).is_null()


# ------------- [Test: _exit_tree] -------------


## Verify _exit_tree frees the transition player
func test_exit_tree_frees_main_player() -> void:
	var player := _service.get_main_player()
	assert_bool(is_instance_valid(player)).is_true()

	_service._exit_tree()

	# Wait for queue_free to take effect (2 frames as per cleanup test pattern)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_valid(player)).is_false()


## Verify calling _exit_tree twice causes no error (idempotent)
func test_exit_tree_idempotent() -> void:
	var player := _service.get_main_player()
	assert_bool(is_instance_valid(player)).is_true()

	_service._exit_tree()
	_service._exit_tree()  # Second call frees nothing

	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_valid(player)).is_false()


## Verify get_main_player returns null after _exit_tree
func test_exit_tree_clears_main_player_reference() -> void:
	_service._exit_tree()
	assert_object(_service.get_main_player()).is_null()



