## シーン演出の基底抽象クラス
@abstract class_name ScreenTransitioner
extends Node

## 演出が実行中かどうか
var _is_playing: bool = false

## [Abstract] マウスイベントの透過設定
@abstract func set_clickable(_clickable: bool) -> void

## 表示レイヤーの設定
@abstract func set_layer(_layer: int) -> void

## [Abstract] 演出（開始）の実行
@abstract func play_out(_speed: float) -> void

## [Abstract] 演出（終了/復帰）の実行
@abstract func play_in(_speed: float) -> void


func is_playing() -> bool:
	return _is_playing
