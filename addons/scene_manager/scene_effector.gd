extends Node


## Definition of animation keys.
class _AnimKey:
	const FADE = &"fade"


## Flag to manage whether an animation is currently playing.
var _is_playing: bool = false

@onready var _fade_color_rect: ColorRect = %fade
@onready var _animation_player: AnimationPlayer = %animation_player


func set_clickable(clickable: bool) -> void:
	_fade_color_rect.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE if clickable else Control.MOUSE_FILTER_STOP
	)


## Common playback logic.
func _play_fade(speed: float, backwards: bool) -> void:
	# Error if called again during a fade process.
	assert(not _is_playing, "SceneEffector: Fade logic called while animation is already playing.")

	if speed <= 0:
		return

	_is_playing = true

	# Adjust playback speed using 1.0 / speed.
	_animation_player.play(
		_AnimKey.FADE, -1, (1.0 / speed) * (-1.0 if backwards else 1.0), backwards
	)
	await _animation_player.animation_finished

	_is_playing = false


func fade_out(speed: float) -> void:
	await _play_fade(speed, false)


func fade_in(speed: float) -> void:
	await _play_fade(speed, true)
