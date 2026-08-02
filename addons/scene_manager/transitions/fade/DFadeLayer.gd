## Generic fade overlay that covers the entire screen.
## Code-only fade, no scene file required, usable from anywhere.
## Inherits ScreenTransitioner, so it can be used directly as a transition
## player (_transitioner_source).
class_name DFadeLayer
extends ScreenTransitioner

# ------------- [Constants] -------------
## Default display layer
const DEFAULT_LAYER: int = 105

# ------------- [Private Variable] -------------
## CanvasLayer used for drawing the fade
var _canvas_layer: CanvasLayer
## ColorRect covering the full screen
var _fade_rect: ColorRect
## Label shown at the center (created on first show_label call)
var _label: Label
var _tween: Tween


# ------------- [Callbacks] -------------
func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = DEFAULT_LAYER
	_canvas_layer.visible = false
	add_child(_canvas_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color(0, 0, 0, 0)
	_canvas_layer.add_child(_fade_rect)


# ------------- [Public Method] -------------
## Fades out (covers the screen). duration is in seconds; <= 0 completes immediately
func play_out(duration: float) -> void:
	if duration <= 0.0:
		return
	await _start_fade(true, duration)


## Fades in (reveals the screen). duration is in seconds; <= 0 completes immediately
func play_in(duration: float) -> void:
	if duration <= 0.0:
		return
	await _start_fade(false, duration)


## Sets whether input events pass through the fade overlay
func set_clickable(clickable: bool) -> void:
	if _fade_rect:
		_fade_rect.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE if clickable else Control.MOUSE_FILTER_STOP
		)


## Sets the display layer (ScreenTransitioner compatible API)
func set_layer(p_layer: int) -> void:
	if _canvas_layer:
		_canvas_layer.layer = p_layer


## Displays centered text.
## Drawn on the fade overlay, so it stays visible during the dark screen
## after fade-out. Can be awaited until fade-in -> hold -> fade-out completes.
func show_label(text: String, hold_duration: float = 0.5, fade_duration: float = 0.2) -> void:
	_ensure_label()
	_label.text = text
	_label.modulate.a = 0.0
	_canvas_layer.visible = true

	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_label, "modulate:a", 1.0, fade_duration)
	_tween.tween_interval(hold_duration)
	_tween.tween_property(_label, "modulate:a", 0.0, fade_duration)
	await _tween.finished


# ------------- [Private Method] -------------
## Plays the fade. Covers the screen if fade_out is true, reveals it if false
func _start_fade(fade_out: bool, duration: float) -> void:
	_is_playing = true
	_canvas_layer.visible = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# Make the overlay opaque at fade-in start
	# (prevents the scene from briefly showing through)
	if not fade_out:
		_fade_rect.color.a = 1.0

	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_fade_rect, "color:a", 1.0 if fade_out else 0.0, duration)
	await _tween.finished

	if not fade_out:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas_layer.visible = false
	_is_playing = false


## Kills the tween if it is running
func _kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()


## Creates the centered label (first call only)
func _ensure_label() -> void:
	if _label:
		return
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_label)
