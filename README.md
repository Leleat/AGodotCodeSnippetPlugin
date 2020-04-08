# A Godot Code Snippet Plugin

This plugin for Godot 3.2.X adds a popup which lists all available code snippets. The popup is shown with Control+Tab. 

The snippets can be filtered by a search_string. Ending the seach_string with " X" will jump to the X-th item in the snippet list. Activating a snippet will insert it at the cursor position. The snippets can be edited within Godot itself using the "Edit" button or you can directly edit the .cfg file with the editor of your choice. 

You can define "tabstops", "mirrorable variables" and "placeholders/dropdown choice".

**See the example in the plugin for more details.**

*New:*

- bugfix: position of the choice popup when there is no scrollbar appears now correctly (or at least at a better position)
- ~~multiple tabstops will cause the error *modules/gdscript/gdscript_tokenizer.cpp:1129 - Condition "tk_rb[ofs].type != TK_IDENTIFIER" is true. Returned: StringName()*. It does not hinder the functionality though.~~ fixed
- activating a dropdown choice will now jump to the next tabstop
- ~~"Esc"-aping the dropdown choice options without changing the placeholder will mess up the formatting of the snippet.~~ workaround implemented
- ~~The position of the dropdown options isn't right. I need a better way to position it.~~ fixed; needs more testing for different resolutions though.


**Installation**:

Either download it from the official Godot AssetLib (within Godot itself) or download the addons folder from GitHub (https://github.com/Leleat/AGodotCodeSnippetPlugin) and move it to the root (res://) of your project. Enable the plugin in the project settings.

![Preview](preview.png)
