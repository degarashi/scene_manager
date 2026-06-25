@tool
## Abstract base class for scene transition effects.
@abstract class_name ScreenTransitioner
extends Node

## Whether the transition effect is currently playing.
var _is_playing: bool = false

## [Abstract] Sets whether mouse events pass through the transition overlay.
@abstract func set_clickable(_clickable: bool) -> void

## [Abstract] Sets the display layer for the transition overlay.
@abstract func set_layer(_layer: int) -> void

## [Abstract] Plays the fade-out transition (covering the scene).
@abstract func play_out(_speed: float) -> void

## [Abstract] Plays the fade-in transition (revealing the scene).
@abstract func play_in(_speed: float) -> void


func is_playing() -> bool:
	return _is_playing
