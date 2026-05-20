# Scene Manager

<p align="center">
<img src="icon.svg" width=256/>
</p>

A comprehensive scene lifecycle management addon for Godot 4, featuring an editor for managing scenes with categories and auto-generated scene enums. Supports multiple loading patterns, layer-based scene management, and smooth visual transitions.

Auto-complete node incorporated and modified from https://github.com/Lenrow/line-edit-complete-godot by Lenrow.

## Features

* **Scene Organization & Management**
  - Editor UI to manage and categorize scenes
  - Duplication check for scene names and categories
  - Include folder feature to auto-discover scenes in specified paths
  - Auto-generated `Scenes.Id` enums to prevent typo errors
  - Export `SceneResource` property for inspector-based scene selection with auto-complete

* **Multiple Loading Patterns**
  - Exclusive scene loading (removes all existing scenes)
  - Additive scene loading (load multiple scenes simultaneously)
  - Scene transitions with customizable visual effects
  - Async loading with progress tracking and transition scenes
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
  - Reset Scene Manager to clear history and assume current scene as first

* **Interface Support**
  - `ISceneInitializer` - Pass parameters to new scenes during initialization
  - `IFadeInNotify` - Receive notification when fade-in transition finishes
  - `IFadeOutNotify` - Receive notification when fade-out transition starts/ends

* **Visual Transitions**
  - Built-in fade in/fade out to black
  - Customizable transition timing (play_out_time, play_in_time)
  - Input blocking during transitions
  - Abstract transitioner base class for custom transition effects

* **Async Loading & Progress**
  - Threaded resource loading with progress tracking (0-100%)
  - Batch resource loading support
  - Pre-instantiation with transition scenes (loading screens)
  - Callback hooks before scene instantiation

* **Comprehensive Signal Support**
  - `load_percent_changed(value: int)` - Async loading progress
  - `load_finished` - Async load completed
  - `load_failed` - Async load failed
  - `scene_loaded(scene_id: Scenes.Id, node: Node)` - Scene instantiated and added to the tree
  - `scene_transition_completed(scene_id: Scenes.Id)` - Full transition complete
  - `category_changed(diff: SMgrData.CategoryDiff)` - Scene categories changed
  - `category_reapplied(tags: Array[Scenes.CategoryId])` - Scene reloaded
  - `category_tags_notified(tags: Array[Scenes.CategoryId])` - Categories notified to listeners
  - `on_game_end` - Game exit initiated

* **Editor Integration**
  - Real-time editor panel for scene/category management
  - Scene filesystem path navigation
  - Unsaved changes notification
  - Direct scene opening from Scene Manager tab
  - Project Settings integration for addon configuration

## How To Use

1. Copy the `scene_manager` folder from `addons` to your project's `addons` directory. (Do not rename the `scene_manager` folder)
2. Open **`Project > Project Settings...`**, go to the **`Plugins`** tab, and enable the `scene_manager` plugin.
3. A **`Scene Manager`** tab will appear on the right side of the editor (default theme view).
4. Use this tab to:
   - Create and organize scene categories
   - Add scenes to the manager
   - Set layer priorities and pause behavior
   - Configure async loading settings
5. After making changes, click **`Save`** to persist your configuration.

> **Note**: After activating the Scene Manager plugin, the `SceneManager` is available globally as an autoload. Access it via static methods like `SceneManager.switch_to_scene()` or connect to signals like `SceneManager.scene_transition_completed.connect(...)`.

> **Note**: The addon auto-generates a `Scenes.Id` enum file. By default, it's saved to `res://scenes.gd`. Do not manually edit this file — it will be overwritten by the editor UI.

### Scene Enum & Resource

The `Scenes.Id` enum is auto-generated as you add scenes in the tool view. You can also use the `SceneResource` class to export a scene selection property in the inspector with auto-complete support.

```gdscript
@export var scene: SceneResource
```

<p align="center">
<img src="images/inspector.png"/>
</p>

## Tool View

The Scene Manager tab provides a visual interface to manage your scenes. You can:
- Create categories (tabs) to organize scenes
- Add scenes to categories from your filesystem
- Set scene metadata (priority, pause behavior, etc.)
- View unsaved changes indicator in the top-right corner
- Open scenes directly in the editor with the play button

<p align="center">
<img src="images/tool.png"/>
</p>

### Scene Categories

Scene categories allow you to organize scenes logically and manage their behavior together (pause state, rendering priority, etc.). Each category can be assigned:
- **Name** - Unique identifier for the category
- **Priority** - Z-order for rendering (higher priority renders on top)
- **Pause Lower Layers** - Whether to pause scenes below this priority
- **Always Process** - Whether to process this scene even when paused
- **Follow Viewport** - Whether this scene's CanvasLayer follows the main viewport

### Include Paths

You can automatically discover scenes by adding folder or file paths to the Include Paths section. Scenes found in these paths will be automatically added to the manager with enum names derived from their file names.

<p align="center">
<img src="images/include.png"/>
</p>

## SceneManager API

After activating the addon, you can access the Scene Manager globally via the `SceneManager` autoload. Below are the most commonly used functions.

### Loading Scenes

**Switch to a new scene (exclusive loading):**
```gdscript
# Simple switch using Scenes.Id enum
SceneManager.switch_to_scene(Scenes.Id.LEVEL_1, true)

# With custom options
var options = SceneLoadOptions.new()
options.play_out_time = 0.5
options.play_in_time = 0.5
options.clickable = false  # Allow input during transition
SceneManager.switch_to_scene(Scenes.Id.LEVEL_1, true, options)

# Or pass scene_loaded_cb callback directly to switch_to_scene for early access
SceneManager.switch_to_scene(Scenes.Id.LEVEL_1, true, SceneLoadOptions.new(),
    func(node: Node):
        print("Scene loaded early: ", node.name)
)
```

**Add scene additively (without removing others):**
```gdscript
var options = SceneLoadOptions.new()
options.node_name = "UI"  # Parent node name
SceneManager.add_scene(Scenes.Id.HUD, SMgrInstance.DuplicateNameMode.REMOVE_OLD, options)
```

**Async load with progress:**
```gdscript
var options = SceneLoadOptions.new()
options.play_out_time = 1.0
options.play_in_time = 1.0

# Connect to signals
SceneManager.load_percent_changed.connect(func(percent: int):
    progress_bar.value = percent
)

SceneManager.load_finished.connect(func():
    # Instantiate the loaded scene (hidden)
    SceneManager.instantiate_async_result()
    # When ready, activate the scene to perform the transition
    SceneManager.activate_prepared_scene()
)

# Start async load (with transition scene)
SceneManager.load_scene_with_transition(
    Scenes.Id.LEVEL_2,
    Scenes.Id.LOADING_SCREEN,
    true,
    SMgrInstance.DuplicateNameMode.WARN_AND_SKIP,
    SceneLoadOptions.new()
)
```

### History Navigation

```gdscript
# Go back to previous scene
if not SceneManager.load_previous_scene():
    print("No previous scene in history")

# Jump back by N scenes
SceneManager.back_to_previous_by_offset(2)

# Reload current scene
SceneManager.reload_current_scene()

# Get history info
var history: Array[Scenes.Id] = SceneManager.get_history_list()
var count: int = SceneManager.get_history_count()
```

### Utility Functions

```gdscript
# Exit game with fade
SceneManager.exit_game(fade_time)

# Get root node of the current main scene
var current_node = SceneManager.get_current_scene_node()

# Unload a specific scene by its node name
SceneManager.unload_scene_by_name("UI")

# Get reserved scene info during async load
var reserved_id = SceneManager.get_reserved_scene()
var reserved_options = SceneManager.get_reserved_load_option()

# Access raw scene database
var db = SceneManager.get_scene_data()

# Connect to transition completion
SceneManager.scene_transition_completed.connect(func(scene_id: Scenes.Id):
    print("Scene loaded: ", scene_id)
)
```

### SceneLoadOptions

Customize scene loading behavior with `SceneLoadOptions`:

```gdscript
@export var node_name: String = "World"  # Parent node for the scene
@export var play_out_time: float = 0.5   # Fade out duration in seconds
@export var play_in_time: float = 0.5    # Fade in duration in seconds
@export var transition_id: Scenes.Id = Scenes.Id.NONE # Custom transition ID
@export var transition_layer: int = -1   # Transition layer
@export var params: Variant = null       # Parameters to pass to the new scene
@export var clickable: bool = false      # Block input during transition

# Callbacks
var pre_wrap_cb: Callable                # Called before layer is added to tree
var pre_node_cb: Callable                # Called before scene node is added to layer
var scene_loaded_cb: Callable            # Called after scene is instantiated
```

### Scene Loading Modes

The `SceneManager` supports multiple loading patterns to handle different architectural needs in Godot.

<p align="center">
<img src="images/scene-manager1.png"/>
</p>

*   **Exclusive (SINGLE)**: Removes all existing layers and replaces them with a new one. Ideal for major level transitions.
    <p align="center"><img src="images/scene-manager2.png"/></p>

*   **Additive**: Adds a new layer without removing others. Perfect for HUDs, menus, or localized sub-scenes.
    <p align="center"><img src="images/scene-manager3.png"/></p>

*   **Single Node**: Removes all scenes under a specific node name and replaces them, while leaving other nodes (like a persistent UI layer) untouched.
    <p align="center"><img src="images/scene-manager4.png"/> <img src="images/scene-manager5.png"/> <img src="images/scene-manager6.png"/></p>

# Demo

## Demo Scenarios

The demo project showcases the primary workflows of the Scene Manager:

- **Direct Switching**: Simple button-press scene transitions with fade effects
- **Loading Screen**: Async resource loading with real-time progress display
- **Additive Loading**: Keep current scene while loading UI/overlays on top
- **History Navigation**: Use back button to return to previous scenes from history

## Demo Code Examples

### Simple Scene Switch
```gdscript
func _on_level_button_pressed():
    SceneManager.switch_to_scene(Scenes.Id.LEVEL_1, true)
```

### Async Loading with Progress Display
```gdscript
func start_level_with_loading_screen():
    var options = SceneLoadOptions.new()
    options.play_out_time = 0.8
    options.play_in_time = 0.8
    
    SceneManager.load_percent_changed.connect(_on_load_progress)
    SceneManager.load_finished.connect(_on_load_finished)
    
    SceneManager.load_scene_with_transition(
        Scenes.Id.LEVEL_1,
        Scenes.Id.LOADING_SCREEN,
        true,
        SMgrInstance.DuplicateNameMode.WARN_AND_SKIP,
        options
    )

func _on_load_progress(percent: int):
    progress_label.text = "%d%%" % percent

func _on_load_finished():
    # Instantiate the loaded scene (placed behind the scenes for now)
    SceneManager.instantiate_async_result()
    # Finalize the transition
    SceneManager.activate_prepared_scene()
```

### Additive UI Loading
```gdscript
func show_pause_menu():
    var ui_options = SceneLoadOptions.new()
    ui_options.node_name = "UI"
    ui_options.play_out_time = 0.3
    ui_options.play_in_time = 0.3
    
    SceneManager.add_scene(Scenes.Id.PAUSE_MENU, 
        SMgrInstance.DuplicateNameMode.REMOVE_OLD, 
        ui_options)

func hide_pause_menu():
    SceneManager.unload_scene_by_name("UI")
```

### History Navigation
```gdscript
func _on_back_button_pressed():
    if not SceneManager.load_previous_scene():
        print("No previous scene to go back to")

func _on_restart_pressed():
    SceneManager.reload_current_scene()
```

## Project Settings

The Scene Manager includes project-level settings to customize behavior:

- **Scene Manager Path** - Path to the auto-generated `scenes.gd` file (default: `res://scene_manager_data/scenes.gd`)
- **Default Play Out Time** - Default fade out duration (default: 1.0s)
- **Default Play In Time** - Default fade in duration (default: 1.0s)
- **Transition Layer** - Z-index for the transition layer (default: 100)
- **Enable Log** - Whether to enable debug logging