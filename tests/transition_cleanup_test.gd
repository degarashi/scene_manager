extends GdUnitTestSuite

## Tests for _cleanup_transition_player helper in SMgrInstance.
## Verifies it frees custom players but preserves the main player.

var sm: SMgrInstance


func before() -> void:
	sm = get_node("/root/SceneManager") as SMgrInstance
	await get_tree().create_timer(1.5).timeout


# ------------- [Inner Classes] -------------
## Simple mock implementation of ScreenTransitioner for testing
class MockTransitioner extends ScreenTransitioner:
	func set_clickable(_clickable: bool) -> void:
		pass
	func set_layer(_layer: int) -> void:
		pass
	func play_out(_speed: float) -> void:
		pass
	func play_in(_speed: float) -> void:
		pass


func test_cleanup_does_not_free_main_player() -> void:
	var main_player := _get_main_player()

	# Ensure the main player is valid before the call
	assert_object(main_player).is_not_null()
	assert_bool(is_instance_valid(main_player)).is_true()

	# Calling cleanup with the main player must NOT free it
	sm._cleanup_transition_player(main_player)

	# The main player must still be valid
	assert_bool(is_instance_valid(main_player)).is_true()


func test_cleanup_frees_custom_player() -> void:
	var custom_player := _create_mock_transitioner()

	# Verify it's valid before cleanup
	assert_object(custom_player).is_not_null()
	assert_bool(is_instance_valid(custom_player)).is_true()

	# Call cleanup — this should queue_free the custom player
	sm._cleanup_transition_player(custom_player)

	# Wait for queue_free to take effect
	await get_tree().process_frame
	await get_tree().process_frame

	# The custom player should now be invalid (freed)
	assert_bool(is_instance_valid(custom_player)).is_false()


func test_cleanup_handles_null_gracefully() -> void:
	# Calling _cleanup_transition_player(null) must not crash
	sm._cleanup_transition_player(null)

	# Reaching here means no error occurred
	assert_bool(true).is_true()


# ------------- [Helpers] -------------


func _get_main_player() -> ScreenTransitioner:
	return sm._transition_service.get_main_player()


func _create_mock_transitioner() -> ScreenTransitioner:
	# Create a simple mock implementation of ScreenTransitioner
	var mock := MockTransitioner.new()
	add_child(mock)
	return mock
