@tool
class_name FadeTransitioner
extends ScreenTransitioner


## Definition of animation keys.
class _AnimKey:
	const FADE = &"fade"


@onready var _fade_color_rect: ColorRect = %fade
@onready var _animation_player: AnimationPlayer = %animation_player
@onready var _canvas: CanvasLayer = %canvas


## [Virtual]
func set_clickable(clickable: bool) -> void:
	_fade_color_rect.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE if clickable else Control.MOUSE_FILTER_STOP
	)


## [Virtual]
func set_layer(layer: int) -> void:
	_canvas.layer = layer


## Common playback logic.
func _play_fade(speed: float, backwards: bool) -> void:
	# Warning if called again during a fade process.
	if _is_playing:
		push_warning("SceneEffector: Fade logic called while animation is already playing.")
		return

	if speed <= 0:
		return

	_is_playing = true

	if not _animation_player.has_animation(_AnimKey.FADE):
		push_error("FadeTransitioner: Animation 'fade' not found.")
		_is_playing = false
		return

	# For fade-in (backwards), ensure the overlay is fully opaque before starting
	# to prevent the scene from flashing briefly.
	if backwards:
		_fade_color_rect.color.a = 1.0

	# Adjust playback speed using 1.0 / speed.
	_animation_player.play(
		_AnimKey.FADE, -1, (1.0 / speed) * (-1.0 if backwards else 1.0), backwards
	)
	await _animation_player.animation_finished

	_is_playing = false


## [Virtual]
func play_out(speed: float) -> void:
	await _play_fade(speed, false)


## [Virtual]
func play_in(speed: float) -> void:
	await _play_fade(speed, true)
