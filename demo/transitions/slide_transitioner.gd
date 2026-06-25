class_name SlideTransitioner
extends ScreenTransitioner

@onready var _slide: ColorRect = %slide
@onready var _canvas: CanvasLayer = %canvas


func set_clickable(clickable: bool) -> void:
	_slide.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE if clickable else Control.MOUSE_FILTER_STOP
	)


func set_layer(layer: int) -> void:
	_canvas.layer = layer


func play_out(speed: float) -> void:
	if _is_playing:
		return
	_is_playing = true

	var viewport_size := get_viewport_rect().size
	_slide.size = viewport_size
	_slide.position = Vector2(viewport_size.x, 0)

	var tween := create_tween()
	tween.tween_property(_slide, "position:x", 0.0, speed).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	_is_playing = false


func play_in(speed: float) -> void:
	if _is_playing:
		return
	_is_playing = true

	var viewport_size := get_viewport_rect().size
	_slide.size = viewport_size
	_slide.position = Vector2(0, 0)

	var tween := create_tween()
	tween.tween_property(_slide, "position:x", -viewport_size.x, speed).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	_is_playing = false
