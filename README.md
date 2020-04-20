# A Godot Code Snippet Plugin

This plugin for Godot 3.2.X adds a popup which lists all available code snippets. The popup is shown with **Control+Tab**. You can edit the shortcut via an export variable of the CodeSnippetPopup.tscn (see Godot's built-in shortcuts to see how a shortcut looks like as a string). After changing the shortcut you need to restart the editor.

**Features**:

- tabstops (the order of the jumping is defined by the user)
- mirrorable variables
- placeholders/dropdown choice (see gif)
- The snippets can be filtered by a search_string. Ending the seach_string with " X" will jump to the X-th item in the snippet list. 

**See the examples in the plugin for more details.**

**Installation**:

Either download it from the official Godot AssetLib (within Godot itself) or download the addons folder from GitHub (https://github.com/Leleat/AGodotCodeSnippetPlugin) and move it to the root (res://) of your project. Enable the plugin in the project settings.


**Preview**

![gif](preview.gif)
![Preview](preview.png)
