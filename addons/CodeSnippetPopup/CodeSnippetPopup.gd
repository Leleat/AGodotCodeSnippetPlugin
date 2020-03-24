tool
extends PopupPanel


var INTERFACE : EditorInterface
var EDITOR : ScriptEditor

onready var item_list = $MarginContainer/VBoxContainer/ItemList
onready var filter : LineEdit = $MarginContainer/VBoxContainer/HBoxContainer/Filter
onready var copy_button : Button = $MarginContainer/VBoxContainer/HBoxContainer/Copy
onready var edit_button : Button = $MarginContainer/VBoxContainer/HBoxContainer/Edit
onready var snippet_editor : WindowDialog = $TextEditPopupPanel
onready var timer : Timer = $JumpStackTimer

export (String) var custom_keyboard_shortcut # go to "Editor > Editor Settings... > Shortcuts > Bindings" to see how a keyboard_shortcut looks as a String 
export (String) var keyword_signals = "sig " # short for _signal
export (String) var snippet_marker_pos = "@" # if this is changed, the CodeSnippets.cfg should also be edited
export (bool) var adapt_popup_height = true

var keyboard_shortcut : String = "Control+Tab" 
var current_main_screen : String = ""
var jump_stack : Array = [0, 0] # [0] = how many jumps left, [1] = start_pos to search for markers; can be cleared by quickly double tapping the shortcut
var code_snippets : ConfigFile
const snippet_config = "res://addons/CodeSnippetPopup/CodeSnippets.cfg"
const types : Array = ["-", "bool", "int", "float", "String", "Vector2", "Rect2", "Vector3", "Transform2D", "Plane", "Quat", "AABB", "Basis", \
		"Transform", "Color", "NodePath", "RID", "Object", "Dictionary", "Array", "PoolByteArray", "PoolIntArray", "PoolRealArray", \
		"PoolStringArray", "PoolVector2Array", "PoolVector3Array", "PoolColorArray", "Variant"] # type hints for vars when using the _signal keyword


func _ready() -> void:
	keyboard_shortcut = custom_keyboard_shortcut if custom_keyboard_shortcut else keyboard_shortcut
	filter.right_icon = get_icon("Search", "EditorIcons")
	_update_snippets()
	snippet_editor.connect("snippets_changed", self, "_update_snippets")


func _unhandled_key_input(event : InputEventKey) -> void:
	if event.as_text() == keyboard_shortcut and current_main_screen == "Script" and not visible:
		if jump_stack[0] == 0:
			_update_popup_list()
			popup_centered(Vector2(750, 500) * (OS.get_screen_dpi() / 100))
			filter.grab_focus()
		else:
			var code_editor : TextEdit = _get_current_code_editor()
			if not timer.is_stopped():
				while jump_stack[0] != 0:
					_jump_to_and_delete_next_jump_marker(code_editor)
				return
			timer.start()
			_jump_to_and_delete_next_jump_marker(code_editor)


func _on_main_screen_changed(new_screen : String) -> void:
	current_main_screen = new_screen


func _update_snippets() -> void:
	var file = ConfigFile.new()
	var error = file.load(snippet_config)
	if error != OK:
		push_warning("Code Snippet Plugin: Error loading the code_snippets. Error code: %s." % error)
	code_snippets = file
	filter.grab_focus()
	_update_popup_list()


func _update_popup_list() -> void:
	item_list.clear()
	var search_string : String = filter.text
	
	# typing " X" at the end of the search_string jumps to the X-th item in the list
	var quickselect_line = 0
	var qs_starts_at = search_string.find_last(" ")
	if qs_starts_at != -1:
		quickselect_line = search_string.substr(qs_starts_at + 1)
		if quickselect_line.is_valid_integer():
			search_string.erase(qs_starts_at + 1, quickselect_line.length())
	
	# show the signals of the current scene root
	if search_string.begins_with(keyword_signals):
		search_string.erase(0, keyword_signals.length())
		search_string = search_string.strip_edges()
		copy_button.visible = false
		edit_button.visible = false
		var counter = 0
		for _signal in INTERFACE.get_edited_scene_root().get_signal_list():
			if search_string and not _signal.name.match("*" + search_string + "*"):
				continue
			item_list.add_item(" " + String(counter) + "  :: ", null, false)
			item_list.add_item(_signal.name)
			if _signal.args:
				item_list.add_item("(") 
				var current_item = item_list.get_item_count() - 1
				for arg_index in _signal.args.size():
						item_list.set_item_text(current_item, item_list.get_item_text(current_item) + _signal.args[arg_index].name + " : " \
						+ (_signal.args[arg_index].get("class_name") if _signal.args[arg_index].get("class_name") else types[_signal.args[arg_index].type]) \
						+ (", " if arg_index < _signal.args.size() - 1 else ""))
				item_list.set_item_text(current_item, item_list.get_item_text(current_item) + ")") 
				item_list.set_item_disabled(current_item, true)
			else:
				item_list.add_item("", null, false)
				item_list.set_item_disabled(item_list.get_item_count() - 1, true)
			counter += 1
	
	# show code snippets
	else:
		search_string = search_string.strip_edges()
		copy_button.visible = true
		edit_button.visible = true
		var counter = 0
		for snippet_name in code_snippets.get_sections():
			if search_string and not snippet_name.match("*" + search_string + "*"):
				continue
			item_list.add_item(" " + String(counter) + "  :: ", null, false)
			item_list.add_item(snippet_name)
			item_list.add_item(code_snippets.get_value(snippet_name, "additional_info"), null, false) \
					if code_snippets.has_section_key(snippet_name, "additional_info") else item_list.add_item("", null, false)
			item_list.set_item_disabled(item_list.get_item_count() - 1, true)
			counter += 1
	
	quickselect_line = clamp(quickselect_line as int, 0, item_list.get_item_count() / item_list.max_columns - 1)
	if item_list.get_item_count() > 0:
		item_list.select(quickselect_line * item_list.max_columns + 1)
		item_list.ensure_current_is_visible()
		
	call_deferred("_adapt_list_height")


func _paste_signal(signal_name : String) -> void:
	var code_editor : TextEdit = _get_current_code_editor()
	var script_name = EDITOR.get_current_script().resource_path.get_file().get_basename()
	var snippet = "connect(\"%s\", , \"_on_%s_%s\")" % [signal_name, script_name, signal_name]
	code_editor.insert_text_at_cursor(snippet)
	var new_column = code_editor.cursor_get_column() - signal_name.length() - script_name.length() - 10 # 10 = , "_on_")
	code_editor.cursor_set_column(new_column)
	OS.clipboard = "func _on_%s_%s():\n\tpass" % [script_name, signal_name]


func _paste_code_snippet(snippet_name : String) -> void:
	var code_editor : TextEdit = _get_current_code_editor()
	var use_type_hints = INTERFACE.get_editor_settings().get_setting("text_editor/completion/add_type_hints")
	var snippet : String = code_snippets.get_value(snippet_name, "body") 
	if use_type_hints and code_snippets.has_section_key(snippet_name, "type_hint"):
		snippet += code_snippets.get_value(snippet_name, "type_hint")
	elif not use_type_hints and code_snippets.has_section_key(snippet_name, "no_type_hint"):
		snippet += code_snippets.get_value(snippet_name, "no_type_hint")
	
	var goto_pos = snippet.find(snippet_marker_pos)
	if goto_pos != -1:
		snippet.erase(goto_pos, snippet_marker_pos.length())
		jump_stack[0] = snippet.count(snippet_marker_pos, goto_pos)
		if jump_stack[0]:
			jump_stack[1] = [code_editor.cursor_get_line(), code_editor.cursor_get_column()]
		_goto_first_snippet_marker(snippet, goto_pos, code_editor)
		
	code_editor.call_deferred("insert_text_at_cursor", snippet)


func _goto_first_snippet_marker(snippet : String, goto_pos: int, code_editor : TextEdit) -> void:
	var old_line = code_editor.cursor_get_line()
	var new_line = old_line + snippet.count("\n", 0, goto_pos)
	var new_columm = snippet.rfind("\n", goto_pos)
	
	new_columm = goto_pos - new_columm - 1 if new_columm != -1 else goto_pos
	new_columm += code_editor.get_line(new_line).length() if not snippet.count("\n", 0, goto_pos) else 0 # respect previous columns
	EDITOR.call_deferred("goto_line", new_line)
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	code_editor.call_deferred("cursor_set_column", new_columm)


func _jump_to_and_delete_next_jump_marker(code_editor : TextEdit) -> void:
	var result = code_editor.search(snippet_marker_pos, 1, jump_stack[1][0], jump_stack[1][1])
	if result.size() > 0:
		jump_stack[1][0] = result[TextEdit.SEARCH_RESULT_LINE]
		jump_stack[1][1] = result[TextEdit.SEARCH_RESULT_COLUMN]
		code_editor.cursor_set_line(jump_stack[1][0])
		code_editor.cursor_set_column(jump_stack[1][1])
		
		var tmp = OS.clipboard # couldn't find/think of a better way to mark the jump positions and delete the markers
		code_editor.deselect()
		code_editor.select(jump_stack[1][0], jump_stack[1][1], jump_stack[1][0], jump_stack[1][1] + 1)
		code_editor.cut()
		OS.clipboard = tmp
	
	jump_stack[0] -= 1


func _adapt_list_height() -> void:
	if adapt_popup_height:
		var script_icon = get_icon("Script", "EditorIcons")
		var row_height = script_icon.get_size().y + (8 * (OS.get_screen_dpi() / 100))
		var rows = max(item_list.get_item_count() / item_list.max_columns, 1) + 1
		var margin = filter.rect_size.y + $MarginContainer.margin_top + abs($MarginContainer.margin_bottom)
		var height = row_height * rows + margin
		rect_size.y = clamp(height, 0, 500 * (OS.get_screen_dpi() / 100))


func _get_current_code_editor() -> TextEdit:
	var script_index = 0
	for script in EDITOR.get_open_scripts():
		if script == EDITOR.get_current_script():
			break
		script_index += 1
	return EDITOR.get_child(0).get_child(1).get_child(1).get_child(script_index).get_child(0).get_child(0).get_child(0) as TextEdit # :(


func _on_Filter_text_changed(new_text: String) -> void:
	_update_popup_list()


func _on_Filter_text_entered(new_text: String) -> void:
	var selection = item_list.get_selected_items()
	if selection:
		_activate_item(selection[0])
	else:
		_activate_item()


func _on_ItemList_item_activated(index: int) -> void:
	_activate_item(index)


func _activate_item(selected_index : int = -1) -> void:
	if selected_index == -1 or item_list.is_item_disabled(selected_index):
		hide()
		return
	
	var selected_name = item_list.get_item_text(selected_index)
	if filter.text.begins_with(keyword_signals):
		_paste_signal(selected_name)
	else:
		_paste_code_snippet(selected_name)
	hide()


func _on_Copy_pressed() -> void:
	var selection = item_list.get_selected_items()
	if selection:
		var use_type_hints = INTERFACE.get_editor_settings().get_setting("text_editor/completion/add_type_hints")
		var snippet_name = item_list.get_item_text(selection[0])
		var snippet : String = code_snippets.get_value(snippet_name, "body")
		if use_type_hints and code_snippets.has_section_key(snippet_name, "type_hint"):
			snippet += code_snippets.get_value(snippet_name, "type_hint")
		elif not use_type_hints and code_snippets.has_section_key(snippet_name, "no_type_hint"):
			snippet += code_snippets.get_value(snippet_name, "no_type_hint")
		var marker_pos = snippet.find(snippet_marker_pos)
		if marker_pos != -1:
			snippet.erase(marker_pos, snippet_marker_pos.length()) 
		OS.clipboard = snippet
	hide()


func _on_CodeSnippetPopup_popup_hide() -> void:
	filter.clear()


func _on_Edit_pressed() -> void:
	var snippet_file : File = File.new()
	var error = snippet_file.open(snippet_config, File.READ)
	if error != OK:
		push_warning("Code Snippet Plugin: Error editing the code_snippets. Error code: %s." % error)
		return
	var txt = snippet_file.get_as_text()
	snippet_file.close()
	
	snippet_editor.edit_snippet(txt)
