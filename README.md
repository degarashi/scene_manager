
# Scene Manager

## In Progress
**Current Changes**:
- Scenes can be specified as enums now to prevent typo errors using strings
- Shader is removed to make it not depend on it, especially for web builds that can conflict.
- Restructuring files and folder structure

<p align="center">
<img src="icon.svg" width=256/>
</p>

A tool to manage transition between different scenes for Godot 4, featuring an editor for adding scenes and an auto-generated scene file.

Auto-complete node incorporated and modified from https://github.com/Lenrow/line-edit-complete-godot by Lenrow.

## Features

* A tool menu structure to manage and categorize your scene in the editor
* Duplication check for scene names and list names
* Include folder feature in UI to only add scenes in the specified folder or the scene file itself
* Categorization for scenes
* Can go back to a previous scene using the ring buffer the `Scene Manager` tracks. Size of the ring buffer can be adjusted.
* Reset `Scene Manager` function to assume the current scene as the first ever seen scene and resetting the back buffer
* Default fade in and fade out to black built-in
* You can create instance of a scene just by calling the scene with a key
* Project/Settings includes addon settings to customize the `Scene Manager`
  * Can specify the location of the `scene.gd` file that's generated
  * Global default fade in and out times for the built-in fade transition
  * Auto save is an internal property setting the addon uses to keep track of whether or not to automatically save changes made to the scene manager tool
* Support for the following signals to get information throughout the scene loading:
  * load_finished
  * load_percent_changed(value: int)
  * scene_loaded
  * fade_in_started
  * fade_out_started
  * fade_in_finished
  * fade_out_finished
* Ability to navigate to the scene path in filesystem on godot when clicked on scene address in Scene Manager tool
* Can open a desired scene from Scene Manager tab

## How To Use?

1. Copy and paste `scene_manager` folder which is inside `addons` folder. (don't change the `scene_manager` folder name)
2. From editor toolbar, choose **`Project > Project Settings...`** then in **`Plugins`** tab, activate scene_manager plugin.
3. Use `Scene Manager` tab on right side of the screen (on default godot theme view) to manage your scenes.
4. After you are done with managing your scenes, always **save** your changes so that your changes have effect inside your actual game.

> **Note**: After activating `Scene Manager` tool, you have access to **SceneManager** script globally from anywhere in your scripts. For more information, read [SceneManager](#scenemanager) section.

> **Note**: This tool saves your scenes data inside `res://scenes.gd` file by default. If you want to have your latest changes and avoid redefining your scene keys, **do not** remove it, **do not** change it or modify it in anyway.

## Tool View

This is the tool that you will see on your right side of the godot editor after activating `scene_manager` plugin. With the **Add** button under scenes categories, you can create new categories to manage your scenes which will show up as tabs. Note that it will notify you if there's unsaved changes to the scene information in the top right corner. Scenes can be loaded directly with the button on the right.

<p align="center">
<img src="images/tool.png"/>
</p>

### Double key checker

If editing of a scene key causes at least two keys of another scene match, both of them will get red color and you have to fix the duplication, otherwise the plugin does not work properly as you expect it to work. Editing scene keys will also automatically normalize the formatting as you type to lower case and underscores as spaces to keep everything in the same style and make it valid to store in a dictionary. Symbols and other invalid characters can't be entered and will be stripped out.

<p align="center">
<img src="images/tool_double_key.png"/>
</p>

### Include Folder

Every folder and file that is added inside this section will be included and scenes inside them will get added to the tool with default keys matching the file name.

<p align="center">
<img src="images/include.png"/>
</p>

## Scene Menu

Every scene has a button beside them which will open up a menu to configure the category of that specific scene.

<p align="center">
<img src="images/menu.png"/>
</p>

# Demo

## Demo Description
The demo project showcases the primary workflows of the Scene Manager:
- **Direct Switching**: Immediate transition between scenes with basic fade effects.
- **Loading Screen**: Utilizing `ResourceLoader` asynchronously to display real-time progress.
- **Additive Loading**: Keeping the current scene while loading another on top (e.g., for UI overlays or small mini-games).
- **History Management**: Navigating back through previous scenes using the built-in stack.

## Demo Code

### Simple Example Without any Loading Screen
```gdscript
# Simple switch using Enums
func _on_button_pressed():
    SceneManager.switch_to_scene(Scenes.Id.LEVEL_1)