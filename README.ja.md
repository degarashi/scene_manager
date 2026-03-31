# Scene Manager

<p align="center">
<img src="icon.svg" width=256/>
</p>

Godot 4向けの包括的なシーンライフサイクル管理アドオンです。シーンを管理するためのエディタ、自動生成されるシーン列挙型、複数のローディングパターン、レイヤーベースのシーン管理、スムーズなビジュアルトランジションをサポートしています。

オートコンプリートノードは https://github.com/Lenrow/line-edit-complete-godot の Lenrow によって組み込まれ、変更されました。

## 機能

* **シーン組織化と管理**
  - シーン管理とカテゴリ分けのためのエディタUI
  - シーン名とカテゴリ名の重複チェック
  - 指定パスでシーンを自動検出するインクルードフォルダ機能
  - 入力ミスを防ぐための自動生成 `Scenes.Id` 列挙型
  - インスペクタベースのシーン選択と自動補完用に `SceneResource` プロパティをエクスポート

* **複数のローディングパターン**
  - 排他的シーンローディング（既存のシーンをすべて削除）
  - 加算的シーンローディング（複数のシーンを同時にロード）
  - カスタマイズ可能なビジュアルエフェクト付きシーントランジション
  - 進捗トラッキングとトランジションシーン付き非同期ローディング
  - シーンリロード機能

* **レイヤー・プライオリティシステム**
  - z-インデックス順序付きCanvasLayerベースのシーンラッピング
  - シーンレンダリング順序のプライオリティシステム
  - 下位層のポーズ/プロセス制御
  - レイヤーごとのビューポートフォロー設定
  - 空のレイヤーの自動削除

* **シーン履歴とナビゲーション**
  - リングバッファベースのシーン履歴（前のシーンに戻る）
  - オフセットベースの履歴ナビゲーション
  - 構成可能な履歴バッファサイズ
  - シーンマネージャをリセットして履歴をクリアし、現在のシーンを最初として想定

* **ビジュアルトランジション**
  - 組み込みのフェードイン/フェードアウト（黒）
  - カスタマイズ可能なトランジション時間（play_out_time、play_in_time）
  - トランジション中の入力ブロック
  - カスタムトランジションエフェクト用の抽象トランジショナーベースクラス

* **非同期ローディングと進捗表示**
  - 進捗トラッキング(0-100%)付きスレッド化リソースローディング
  - バッチリソースローディングサポート
  - トランジションシーン(ローディング画面)での事前インスタンス化
  - シーンインスタンス化前のコールバックフック

* **包括的なシグナルサポート**
  - `load_percent_changed(value: int)` - 非同期ローディング進捗
  - `load_finished` - 非同期ロード完了
  - `load_failed` - 非同期ロード失敗
  - `scene_loaded(scene_id: Scenes.Id)` - シーンインスタンス化
  - `scene_transition_completed(scene_id: Scenes.Id)` - トランジション完全完了
  - `category_changed(diff: SMgrData.CategoryDiff)` - シーンカテゴリ変更
  - `category_reapplied(tags: Array[Scenes.CategoryId])` - シーンリロード
  - `category_tags_notified(tags: Array[Scenes.CategoryId])` - カテゴリがリスナーに通知
  - `on_game_end` - ゲーム終了開始

* **エディタ統合**
  - シーン/カテゴリ管理のためのリアルタイムエディタパネル
  - シーンファイルシステムパスナビゲーション
  - 保存されていない変更通知
  - Scene Managerタブから直接シーンを開く
  - プロジェクト設定統合によるアドオン設定

## 使用方法

1. `addons` フォルダから `scene_manager` フォルダをプロジェクトの `addons` ディレクトリにコピーしてください。（`scene_manager` フォルダの名前を変更しないでください）
2. **`プロジェクト > プロジェクト設定...`** を開き、**`プラグイン`** タブに移動して `scene_manager` プラグインを有効にしてください。
3. エディタの右側に **`Scene Manager`** タブが表示されます（デフォルトテーマビュー）。
4. このタブを使用して以下を行います：
   - シーンカテゴリの作成と整理
   - マネージャにシーンを追加
   - レイヤープライオリティとポーズ動作を設定
   - 非同期ローディング設定を設定
5. 変更後、**`保存`** をクリックして設定を保存します。

> **注意**: Scene Managerプラグインを有効化すると、`SMgrInstance`（シーンマネージャ）がグローバルオートロードとして利用可能になります。`SMgrInstance.switch_to_scene()` などの静的メソッドでアクセスするか、`SMgrInstance.scene_transition_completed.connect(...)` などのシグナルに接続してください。

> **注意**: アドオンは `Scenes.Id` 列挙型ファイルを自動生成します。デフォルトではこれは `res://scenes.gd` に保存されます。このファイルを手動で編集しないでください — エディタUIによって上書きされます。

## ツールビュー

シーンマネージャタブは、シーン管理のためのビジュアルインターフェースを提供します。以下が可能です：
- カテゴリ（タブ）を作成してシーンを整理
- ファイルシステムからカテゴリにシーンを追加
- シーンメタデータ（プライオリティ、ポーズ動作など）を設定
- 右上隅の保存されていない変更インジケータを表示
- 再生ボタンでエディタから直接シーンを開く

<p align="center">
<img src="images/tool.png"/>
</p>

### シーンカテゴリ

シーンカテゴリを使用すると、シーンを論理的に整理し、その動作を一緒に管理できます（ポーズ状態、レンダリングプライオリティなど）。各カテゴリに以下を割り当てることができます：
- **名前** - カテゴリの一意の識別子
- **プライオリティ** - レンダリングのzオーダー（高いプライオリティは上に表示）
- **下位レイヤーをポーズ** - このプライオリティ下のシーンをポーズするかどうか
- **常にプロセス** - ポーズ時でもこのシーンを処理するかどうか
- **ビューポートをフォロー** - このシーンのCanvasLayerがメインビューポートをフォローするかどうか

### インクルードパス

インクルードパスセクションにフォルダまたはファイルパスを追加することで、シーンを自動検出できます。これらのパスにあるシーンはマネージャに自動的に追加され、ファイル名から派生した列挙型名を持ちます。

<p align="center">
<img src="images/include.png"/>
</p>

## SceneManager API

アドオンを有効化した後、`SMgrInstance` オートロードを介してシーンマネージャにグローバルにアクセスできます。以下は最も一般的に使用される関数です。

### シーンのローディング

**新しいシーンに切り替える（排他的ローディング）：**
```gdscript
# Scenes.Id 列挙型を使用した簡単な切り替え
SMgrInstance.switch_to_scene(Scenes.Id.LEVEL_1)

# カスタムオプション付き
var options = SceneLoadOptions.new()
options.play_out_time = 0.5
options.play_in_time = 0.5
options.clickable = false  # トランジション中に入力を許可
SMgrInstance.switch_to_scene(Scenes.Id.LEVEL_1, true, options)
```

**シーンを加算的に追加（他を削除せずに）：**
```gdscript
var options = SceneLoadOptions.new()
options.node_name = "UI"  # 親ノード名
SMgrInstance.add_scene(Scenes.Id.HUD, SMgrInstance.DuplicateNameMode.REMOVE_OLD, options)
```

**進捗付き非同期ローディング：**
```gdscript
var options = SceneLoadOptions.new()
options.play_out_time = 1.0
options.play_in_time = 1.0

# シグナルに接続
SMgrInstance.load_percent_changed.connect(func(percent: int):
    progress_bar.value = percent
)

SMgrInstance.load_finished.connect(func():
    SMgrInstance.instantiate_async_result()
)

# 非同期ローディングを開始（トランジションシーン付き）
SMgrInstance.load_scene_with_transition(
    Scenes.Id.LEVEL_2,
    Scenes.Id.LOADING_SCREEN,
    true,
    options
)
```

### 履歴ナビゲーション

```gdscript
# 前のシーンに戻る
if not SMgrInstance.load_previous_scene():
    print("履歴に前のシーンがありません")

# N個のシーンを戻る
SMgrInstance.back_to_previous_by_offset(2)

# 現在のシーンをリロード
SMgrInstance.reload_current_scene()

# 履歴情報を取得
var history: Array[Scenes.Id] = SMgrInstance.get_history_list()
var count: int = SMgrInstance.get_history_count()
```

### ユーティリティ関数

```gdscript
# フェード付きでゲームを終了
SMgrInstance.exit_game(fade_time)

# 現在のシーンデータを取得
var scene_data = SMgrInstance.get_scene_data()
var path = scene_data.get_scene_path_from_enum(Scenes.Id.LEVEL_1)

# トランジション完了に接続
SMgrInstance.scene_transition_completed.connect(func(scene_id: Scenes.Id):
    print("シーンがロードされました: ", scene_id)
)
```

### SceneLoadOptions

`SceneLoadOptions` でシーンローディング動作をカスタマイズします：

```gdscript
var options = SceneLoadOptions.new()
options.node_name = "World"           # シーンの親ノード
options.play_out_time = 1.0           # フェードアウト時間（秒）
options.play_in_time = 1.0            # フェードイン時間（秒）
options.clickable = false             # トランジション中に入力をブロック

# 事前ラッピングコールバック（ラッパーノードで呼び出し）
options.pre_wrap_cb = func(layer: SMgrSceneLayer):
    print("ラッパーノードが作成されました")

# 事前ノードコールバック（シーンノードで呼び出し）
options.pre_node_cb = func(node: Node):
    print("シーンノードが作成されました")
```

# デモ

## デモシナリオ

デモプロジェクトはシーンマネージャの主要なワークフローを紹介しています：

- **直接切り替え**: ボタン押下で簡単なシーン切り替え（フェードエフェクト付き）
- **ローディング画面**: リアルタイム進捗表示付き非同期リソースローディング
- **加算的ローディング**: 現在のシーンを保持しながら、上にUIをロード
- **履歴ナビゲーション**: 戻るボタンで履歴から前のシーンに戻る

## デモコード例

### シンプルなシーン切り替え
```gdscript
func _on_level_button_pressed():
    SMgrInstance.switch_to_scene(Scenes.Id.LEVEL_1)
```

### 進捗表示付き非同期ローディング
```gdscript
func start_level_with_loading_screen():
    var options = SceneLoadOptions.new()
    options.play_out_time = 0.8
    options.play_in_time = 0.8
    
    SMgrInstance.load_percent_changed.connect(_on_load_progress)
    SMgrInstance.load_finished.connect(_on_load_finished)
    
    SMgrInstance.load_scene_with_transition(
        Scenes.Id.LEVEL_1,
        Scenes.Id.LOADING_SCREEN,
        true,
        options
    )

func _on_load_progress(percent: int):
    progress_label.text = "%d%%" % percent

func _on_load_finished():
    SMgrInstance.instantiate_async_result()
```

### 加算的UIローディング
```gdscript
func show_pause_menu():
    var ui_options = SceneLoadOptions.new()
    ui_options.node_name = "UI"
    ui_options.play_out_time = 0.3
    ui_options.play_in_time = 0.3
    
    SMgrInstance.add_scene(Scenes.Id.PAUSE_MENU, 
        SMgrInstance.DuplicateNameMode.REMOVE_OLD, 
        ui_options)

func hide_pause_menu():
    SMgrInstance.unload_scene_by_name("UI")
```

### 履歴ナビゲーション
```gdscript
func _on_back_button_pressed():
    if not SMgrInstance.load_previous_scene():
        print("戻るシーンがありません")

func _on_restart_pressed():
    SMgrInstance.reload_current_scene()
```

## プロジェクト設定

シーンマネージャには動作をカスタマイズするためのプロジェクトレベルの設定が含まれています：

- **Scene Manager Path** - 自動生成される `scenes.gd` ファイルの保存先（デフォルト：`res://`）
- **Default Fade Time** - トランジションのデフォルトフェード時間（デフォルト：1.0秒）
- **History Buffer Size** - 履歴に保持するシーン数（デフォルト：10）
