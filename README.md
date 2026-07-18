# Scene Manager

<p align="center">
<img src="icon.svg" width=256/>
</p>

A comprehensive scene lifecycle management addon for Godot 4, featuring an editor for managing scenes with categories and auto-generated scene enums. Supports exclusive and additive loading patterns, layer-based scene management, CanvasLayer wrapping, and smooth visual transitions.

Auto-complete node incorporated and modified from https://github.com/Lenrow/line-edit-complete-godot by Lenrow.

## Features

* **Scene Organization & Management**
  - Editor UI to manage and categorize scenes
  - Duplication check for scene names and categories
  - Include folder feature to auto-discover scenes in specified paths
  - Auto-generated `Scenes.Id` enums with utility functions (`get_scene()`, `get_scene_path()`)
  - Export `SceneResource` property for inspector-based scene selection with auto-complete
  - File system monitoring — changes to `.tscn` files auto-sync
  - Drag & drop `.tscn` files from the FileSystem dock to register scenes
  - Search/filter scenes by name in the editor panel
  - Invalid `Scenes.Id` reference detection tool
  - Preview panel with thumbnail and transition preview in a SubViewport

* **Multiple Loading Patterns**
  - Exclusive scene loading (`switch_to_scene`) — replaces all existing scenes with a new one
  - Additive scene loading (`add_scene`) — loads multiple scenes simultaneously
  - Duplicate name handling modes: remove old, warn/skip, rename new, append to existing layer
  - Scene removal by ID (`remove_scene`) or by node name (`unload_scene_by_name`)
  - Scene reload functionality

* **Layer & Priority System**
  - CanvasLayer-based scene wrapping with z-index ordering
  - Layer priority system for scene rendering order
  - Pause/process control for lower-priority layers
  - Viewport following per-layer configuration
  - Auto-disposal of empty layers

* **Scene History & Navigation**
  - Ring buffer-based scene history (go back to previous scenes)
  - Offset-based history navigation
  - Clear history, reload current scene
  - Reset Scene Manager to clear history and assume current scene as first

* **Interface Support**
  - `ISceneInitializer` — Pass parameters to new scenes during initialization
  - `IFadeInNotify` — Receive notification when fade-in transition finishes
  - `IFadeOutNotify` — Receive notification when fade-out transition starts/ends

* **Visual Transitions**
  - Built-in fade in/fade out to black
  - Customizable transition timing (play_out_time, play_in_time)
  - Input blocking during transitions
  - Custom transitioner support via `ScreenTransitioner` base class (custom ID per load)
  - No-op transitioner fallback when no transitioner is configured
  - Edit-time transition preview in SubViewport
  - Slide transitioner demo included

* **Async Loading & Progress**
  - Threaded resource loading with progress tracking (0-100%)
  - Batch resource loading support
  - Pre-instantiation with transition scenes (loading screens)
  - Callback hooks before scene instantiation
  - Two-step async flow: `load_scene_with_transition` → `instantiate_async_result` → `activate_prepared_scene`

* **Comprehensive Signal Support**
  - `load_percent_changed(value: int)` — Async loading progress
  - `load_finished` — Async load completed
  - `load_failed` — Async load failed
  - `scene_loaded(scene_id: Scenes.Id, node: Node)` — Scene instantiated and added to the tree
  - `scene_transition_completed(scene_id: Scenes.Id)` — Full transition complete
  - `category_changed(diff: SMgrData.CategoryDiff)` — Scene categories changed
  - `category_reapplied(tags: Array[Scenes.CategoryId])` — Scene reloaded (same ID)
  - `category_tags_notified(tags: Array[Scenes.CategoryId])` — Categories notified to listeners
  - `on_game_end` — Game exit initiated

* **Editor Integration**
  - Real-time editor panel for scene/category management
  - Tab-based UI: "All" tab (categorized/uncategorized) + per-category tabs
  - Category property editing: priority, pause behavior, always-process, follow viewport, layer name
  - Priority map visualization with sortable bar chart
  - Include path management with per-path category assignment
  - Unsaved changes notification with manual/auto-save toggle
  - Direct scene opening from Scene Manager tab
  - Project Settings integration for addon configuration
  - Auto-complete on `SceneResource` inspector property
  - File system watcher for auto-reload on external changes
  - Refresh UID tool for resolving resource conflicts

## How To Use

1. Copy the `scene_manager` folder from `addons` to your project's `addons` directory. (Do not rename the `scene_manager` folder)
2. Open **`Project > Project Settings...`**, go to the **`Plugins`** tab, and enable the `scene_manager` plugin.
3. A **`Scene Manager`** tab will appear on the right side of the editor (default theme view).
4. Use this tab to:
   - Create and organize scene categories
   - Add scenes to the manager
   - Set layer priorities, pause behavior, layer names
   - Configure include paths and category auto-assignment
5. After making changes, the plugin auto-saves (if enabled) or you can click **`Save`**.

> **Note**: After activating the Scene Manager plugin, two autoloads are registered: `Scenes` (auto-generated enum + utility class) and `SceneManager` (runtime API, class `SMgrInstance`). Access the runtime API via `SceneManager.switch_to_scene()` and connect to signals like `SceneManager.scene_transition_completed.connect(...)`.

> **Note**: The addon auto-generates a `Scenes` class file. By default, it's saved to `res://scene_manager_data/scenes.gd`. Do not manually edit this file — it will be overwritten by the editor UI.

### Scene Enum & Resource

The `Scenes.Id` enum is auto-generated as you add scenes in the tool view. It also includes utility functions:

```gdscript
# Get the PackedScene for a scene ID
var scene: PackedScene = Scenes.get_scene(Scenes.Id.LEVEL_1)

# Get the file path for a scene ID
var path: String = Scenes.get_scene_path(Scenes.Id.LEVEL_1)
```

You can also use the `SceneResource` class to export a scene selection property in the inspector with auto-complete support:

```gdscript
@export var scene: SceneResource
```

## Tool View

The Scene Manager tab provides a visual interface to manage your scenes:

<p align="center">
<img src="images/screen.jpg"/>
</p>

- **Search bar** — Filter scenes by name across all categories
- **All tab** — Shows categorized and uncategorized scenes in collapsible sections
- **Per-category tabs** — Each category gets its own tab for focused management
- **Category properties** — Edit category name, layer name, priority, pause/always-process/viewport flags
- **Priority map** — Visual bar chart comparing all category priorities
- **Scene items** — Each shows a thumbnail, editable name, file path, and category assignment popup
- **Include paths** — Add directory/files to auto-discover scenes, with per-path category assignment dropdown
- **Preview panel** — Scene thumbnail preview and transition playback for `ScreenTransitioner` scenes
- **Save/auto-save** — Manual save button (disabled when auto-save is on), auto-save toggle
- **Invalid ID checker** — Scans project for stale `Scenes.Id` references
- **File drop** — Drag `.tscn` files from the FileSystem dock to register as include paths

<p align="center">
<img src="images/tool_double_key.png"/>
</p>

<p align="center">
<img src="images/menu.png"/>
</p>

### Scene Categories

Scene categories allow you to organize scenes logically and manage their behavior together (pause state, rendering priority, etc.). Each category can be assigned:

- **Name** — Unique identifier for the category
- **Layer Name** — Custom CanvasLayer node name (overrides `node_name` in SceneLoadOptions)
- **Priority** — Z-order for rendering (higher priority renders on top)
- **Pause Lower Layers** — Whether to pause scenes below this priority
- **Always Process** — Whether to process this scene even when paused
- **Follow Viewport** — Whether this scene's CanvasLayer follows the main viewport

### Include Paths

You can automatically discover scenes by adding folder or file paths to the Include Paths section. Scenes found in these paths will be automatically registered with enum names derived from their file names.

<p align="center">
<img src="images/include.png"/>
</p>

Each include path can have a category assigned via a dropdown, which automatically assigns that category to all scenes under that path.

## SceneManager API

After activating the addon, you can access the Scene Manager globally via the `SceneManager` autoload (class name `SMgrInstance`). Below are the most commonly used functions.

### Loading Scenes

**Switch to a new scene (exclusive loading — replaces all existing layers):**
```gdscript
# Simple switch using Scenes.Id enum
SceneManager.switch_to_scene(Scenes.Id.LEVEL_1, true)

# With custom options
var options = SceneLoadOptions.new()
options.play_out_time = 0.5
options.play_in_time = 0.5
options.clickable = true  # Allow input during transition (default: false = blocked)
SceneManager.switch_to_scene(Scenes.Id.LEVEL_1, true, options)

# Or pass a callback directly for early access
SceneManager.switch_to_scene(Scenes.Id.LEVEL_1, true, SceneLoadOptions.new(),
    func(node: Node):
        print("Scene loaded early: ", node.name)
)
```

**Add scene additively (without removing others):**
```gdscript
var options = SceneLoadOptions.new()
options.node_name = "UI"
SceneManager.add_scene(Scenes.Id.HUD, SMgrInstance.DuplicateNameMode.REMOVE_OLD, options)
```

**Remove a specific additive scene:**
```gdscript
SceneManager.remove_scene(Scenes.Id.HUD)
```

**Unload a scene by layer node name:**
```gdscript
SceneManager.unload_scene_by_name("UI")
```

**Async load with transition scene (loading screen):**
```gdscript
# 1. Start the loading flow
SceneManager.load_scene_with_transition(
    Scenes.Id.LEVEL_2,       # Target scene
    Scenes.Id.LOADING_SCREEN, # Loading screen scene
    true,                    # Add current to history
    SMgrInstance.DuplicateNameMode.WARN_AND_SKIP,
    SceneLoadOptions.new()   # Options for the loading screen
)

# load_scene_with_transition also accepts unload_old (bool) as 6th parameter
```

```gdscript
# 2. In the loading screen, connect to signals
SceneManager.load_percent_changed.connect(func(percent: int):
    progress_bar.value = percent
)

SceneManager.load_finished.connect(func():
    # Instantiate the loaded scene (hidden behind the loading screen)
    SceneManager.instantiate_async_result()
    # When ready, activate the scene to perform the transition
    SceneManager.activate_prepared_scene()
)
```

```gdscript
# Or, start async loading manually
var reserved = SceneManager.get_reserved_scene()
SceneManager.start_async_load(reserved)

# Once finished:
SceneManager.instantiate_async_result()
# ... later ...
SceneManager.activate_prepared_scene()
```

### History Navigation

```gdscript
# Go back to previous scene
if not await SceneManager.load_previous_scene():
    print("No previous scene in history")

# Jump back by N scenes
SceneManager.back_to_previous_by_offset(2)

# Reload current scene
SceneManager.reload_current_scene()

# Get history info
var history: Array[Scenes.Id] = SceneManager.get_history_list()
var count: int = SceneManager.get_history_count()

# Clear history
SceneManager.clear_history()
```

### Utility Functions

```gdscript
# Exit game with fade
SceneManager.exit_game(1.0)  # fade_time optional, defaults to 1.0

# Get root node of the current main scene
var current_node = SceneManager.get_current_scene_node()

# Get reserved scene info during async load
var reserved_id = SceneManager.get_reserved_scene()
var reserved_options = SceneManager.get_reserved_load_option()

# Access raw scene database (SMgrData)
var db: SMgrData = SceneManager.get_scene_data()
```

### SceneLoadOptions

Customize scene loading behavior with `SceneLoadOptions`:

```gdscript
@export var node_name: String = "World"   # Parent CanvasLayer node name
@export var play_out_time: float = 0.5    # Fade out duration in seconds
@export var play_in_time: float = 0.5     # Fade in duration in seconds
@export var transition_id: Scenes.Id = Scenes.Id.NONE  # Custom transitioner scene ID
@export var transition_layer: int = -1    # Transition layer (-1 = project default)
@export var params: Variant = null        # Parameters to pass via ISceneInitializer
@export var clickable: bool = false       # false = block input during transition

# Callbacks
var pre_wrap_cb: Callable                 # Called before layer is added to tree
var pre_node_cb: Callable                 # Called before scene node is added to layer
var scene_loaded_cb: Callable             # Called after scene is instantiated
```

Constructor defaults come from project settings:

```gdscript
# All parameters are optional
var options = SceneLoadOptions.new(
    "World",       # node_name
    false,         # clickable
    -1.0,          # play_out_time (negative = use project default)
    -1.0,          # play_in_time (negative = use project default)
    Callable(),    # pre_wrap_cb
    Callable(),    # pre_node_cb
    Scenes.Id.NONE, # transition_id
    -1,            # transition_layer
    Callable()     # scene_loaded_cb
)
```

Use `copy()` to deep-copy:

```gdscript
var copy = options.copy()
```

### DuplicateNameMode

Controls behavior when `add_scene` encounters an existing layer with the same name:

| Mode | Behavior |
|---|---|
| `REMOVE_OLD` | Remove the existing SceneLayer before adding the new one |
| `WARN_AND_SKIP` | Print a warning and abort the addition |
| `RENAME_NEW` | Append a numeric suffix to the new SceneLayer |
| `APPEND` | Add the new scene node to the existing SceneLayer |

### Scene Loading Modes

The `SceneManager` supports these loading patterns:

* **Exclusive (switch\_to\_scene)**: Removes all existing layers and replaces them with a new one. Ideal for major level transitions.

* **Additive (add\_scene)**: Adds a new layer without removing others. Perfect for HUDs, menus, or localized sub-scenes.

* **Targeted (node\_name)**: By setting `node_name` in `SceneLoadOptions`, you control which CanvasLayer the scene goes into. This allows replacing a specific named layer while leaving others untouched.

## Custom Transitions

Implement custom transition effects by extending `ScreenTransitioner`:

```gdscript
class_name MyTransitioner
extends ScreenTransitioner

func set_clickable(clickable: bool) -> void:
    # Control mouse pass-through

func set_layer(layer: int) -> void:
    # Set the CanvasLayer for the transition overlay

func play_out(speed: float) -> void:
    # Cover the scene (fade out)

func play_in(speed: float) -> void:
    # Reveal the scene (fade in)
```

Pass custom transitioners per load via `SceneLoadOptions.transition_id`. The demo includes a `SlideTransitioner` as an example.

## Signals

Signals are emitted on the `SceneManager` autoload:

```gdscript
SceneManager.scene_transition_completed.connect(func(scene_id: Scenes.Id):
    print("Scene loaded: ", scene_id)
)
```

| Signal | Arguments | When |
|---|---|---|
| `load_percent_changed` | `value: int` | Async loading progress (0-100) |
| `load_finished` | — | Async load completed |
| `load_failed` | — | Async load failed |
| `scene_loaded` | `scene_id: Scenes.Id, node: Node` | Scene instantiated and added to the tree |
| `scene_transition_completed` | `scene_id: Scenes.Id` | Entire transition (including visual effects) finished |
| `category_changed` | `diff: SMgrData.CategoryDiff` | Scene categories changed during switch |
| `category_reapplied` | `tags: Array[Scenes.CategoryId]` | Same scene reloaded, categories re-applied |
| `category_tags_notified` | `tags: Array[Scenes.CategoryId]` | Categories notified to listeners |
| `on_game_end` | — | Game exit initiated |

## Demo

### Demo Scenarios

The demo project (`demo/`) showcases the primary workflows:

- **Direct Switching**: Simple button-press scene transitions with fade effects
- **Loading Screen**: Async resource loading with real-time progress display (real and simulated)
- **Additive Loading**: Keep current scene while loading UI/overlays on top
- **History Navigation**: Use back button to return to previous scenes from history
- **Custom Transition**: Slide transitioner example

### Demo Code Examples

**Simple Scene Switch:**
```gdscript
func _on_level_button_pressed():
    SceneManager.switch_to_scene(Scenes.Id.SCENE_1, true)
```

**Async Loading with Progress Display:**
```gdscript
func start_level_with_loading_screen():
    SceneManager.load_scene_with_transition(
        Scenes.Id.SCENE_1,
        Scenes.Id.LOADING_SCREEN,
        true,
        SMgrInstance.DuplicateNameMode.WARN_AND_SKIP,
        SceneLoadOptions.new()
    )

# In loading_screen.gd:
func _ready():
    SceneManager.load_percent_changed.connect(_on_load_progress)
    SceneManager.load_finished.connect(_on_load_finished)
    var resv_scene := SceneManager.get_reserved_scene()
    if resv_scene != Scenes.Id.NONE:
        SceneManager.start_async_load(resv_scene)

func _on_load_progress(percent: int):
    progress_bar.value = percent

func _on_load_finished():
    SceneManager.instantiate_async_result()
    await get_tree().create_timer(0.3).timeout
    progress_bar.value = 100
    move_to_next_scene_button.visible = true

func _on_move_to_next_scene_button_button_up():
    SceneManager.activate_prepared_scene()
```

**Additive UI Loading:**
```gdscript
func show_pause_menu():
    var ui_options = SceneLoadOptions.new()
    ui_options.node_name = "UI"
    ui_options.play_out_time = 0.3
    ui_options.play_in_time = 0.3

    SceneManager.add_scene(Scenes.Id.ADDITIONAL_0,
        SMgrInstance.DuplicateNameMode.REMOVE_OLD,
        ui_options)

func hide_pause_menu():
    SceneManager.unload_scene_by_name("UI")
```

**History Navigation:**
```gdscript
func _on_back_button_pressed():
    if not await SceneManager.load_previous_scene():
        print("No previous scene to go back to")

func _on_restart_pressed():
    SceneManager.reload_current_scene()
```

## Project Settings

The Scene Manager includes project-level settings accessible from **Project > Project Settings > Scene Manager**:

| Setting | Path | Default | Description |
|---|---|---|---|
| **Scene Manager Path** | `scene_manager/scenes/scenes_path` | `res://scene_manager_data/scenes.gd` | Path to the auto-generated `Scenes` class file |
| **Default Play Out Time** | `scene_manager/scenes/default_play_out_time` | `1.0` | Default fade out duration (seconds) |
| **Default Play In Time** | `scene_manager/scenes/default_play_in_time` | `1.0` | Default fade in duration (seconds) |
| **Transition Layer** | `scene_manager/scenes/transition_layer` | `100` | Z-index for the transition CanvasLayer |
| **Auto Save** | `scene_manager/scenes/autosave` | `false` | Auto-save scene data on changes |
| **Enable Log** | `scene_manager/general/enable_log` | `false` | Enable debug logging |