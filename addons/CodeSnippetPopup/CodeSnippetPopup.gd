tool
extends PopupPanel


var INTERFACE : EditorInterface
var EDITOR : ScriptEditor
	
onready var itemlist = $Main/VBoxContainer/ItemList
onready var filter : LineEdit = $Main/VBoxContainer/HBoxContainer/Filter
onready var copy_button : Button = $Main/VBoxContainer/HBoxContainer/Copy
onready var edit_button : Button = $Main/VBoxContainer/HBoxContainer/Edit
onready var settings_button = $Main/VBoxContainer/HBoxContainer/Settings
onready var SNIPPET_EDITOR : WindowDialog = $SnippetEditor
onready var SETTINGS : WindowDialog = $SettingsPopup
onready var OPTIONS_POPUP : PopupMenu = $OptionsPopup # popup for a snippet with options; for ex. [@1:OptionA,OptionB]
onready var settings_shortcut_lineedit := $SettingsPopup/MarginContainer/VBoxContainer/HBoxContainer/ShortcutLineEdit
onready var settings_filedialog_button := $SettingsPopup/MarginContainer/VBoxContainer/HBoxContainer7/FileDialogButton
onready var settings_filedialog := $SettingsPopup/FileDialog
onready var settings_file_path_lineedit := $SettingsPopup/MarginContainer/VBoxContainer/HBoxContainer7/FilepathLineEdit
onready var settings_cancel_button := $SettingsPopup/MarginContainer/VBoxContainer/HBoxContainer9/CancelButton
onready var settings_save_button := $SettingsPopup/MarginContainer/VBoxContainer/HBoxContainer9/SaveButton
onready var settings_adaptive_height_checkbox := $SettingsPopup/MarginContainer/VBoxContainer/HBoxContainer2/AdaptiveHeightCheckBox
onready var settings_popup_at_cursor_pos_checkbox := $SettingsPopup/MarginContainer/VBoxContainer/HBoxContainer8/AtCursorCheckbox
onready var settings_main_height_spinbox := $SettingsPopup/MarginContainer/VBoxContainer/HBoxContainer3/PopupHeightSpinBox
onready var settings_main_width_spinbox := $SettingsPopup/MarginContainer/VBoxContainer/HBoxContainer4/PopupWidthSpinBox
onready var settings_editor_height_spinbox := $SettingsPopup/MarginContainer/VBoxContainer/HBoxContainer5/EditorHeightSpinBox
onready var settings_editor_width_spinbox := $SettingsPopup/MarginContainer/VBoxContainer/HBoxContainer6/EditorWidthSpinBox
# settings vars
var keyboard_shortcut : String
var adapt_popup_height : bool
var main_popup_size : Vector2
var editor_size : Vector2
var snippet_config_path : String 
var popup_at_cursor_pos : bool
# snippet vars
var curr_tabstop_marker = "" # [@X] -> X should be an integer. Using the same X multiple times will replace them by whatever you typed for the first X (after a shortcut press)
var current_snippet = ""
var delayed_one_key_press : bool = false
var placeholder : String # for the snippets with options
var starting_pos : Array # pos, where snippet was inserted
var curr_snippet_pos : Array # pos, where the current tabstop marker was
var tabstop_numbers : Array # technically doesn't have to be an int
	
var current_main_screen : String = ""
var code_snippets : ConfigFile
var version_number 
var prev_file_path := ""


func _ready() -> void:
	var ver_nr = ConfigFile.new()
	var error = ver_nr.load("res://addons/CodeSnippetPopup/plugin.cfg")
	if error != OK:
		push_warning("Error %s getting version number." % error)
		return
	version_number = ver_nr.get_value("plugin", "version", "?") 
	
	OPTIONS_POPUP.connect("show_options", OPTIONS_POPUP, "_on_DropDown_shown")
	
	filter.right_icon = get_icon("Search", "EditorIcons")
	copy_button.icon = get_icon("ActionCopy", "EditorIcons")
	edit_button.icon = get_icon("Edit", "EditorIcons")
	settings_button.icon = get_icon("Tools", "EditorIcons")
	settings_filedialog_button.icon = get_icon("Folder", "EditorIcons")
	settings_save_button.icon = get_icon("Save", "EditorIcons")
	settings_cancel_button.icon = get_icon("Close", "EditorIcons")
	
	_load_settings()
	_update_snippets()


func _unhandled_key_input(event : InputEventKey) -> void:
	if event.as_text() == keyboard_shortcut and current_main_screen == "Script":
		if tabstop_numbers.empty():
			_update_popup_list()
			if popup_at_cursor_pos:
				rect_global_position = _get_cursor_position()
				rect_size = main_popup_size
				popup()
			else:
				popup_centered_clamped(main_popup_size)
			filter.grab_focus()
			delayed_one_key_press = false
		else:
			_jump_to_and_delete_next_marker(_get_current_script_texteditor())
	
	if event.scancode == KEY_ESCAPE and event.pressed:
		if not tabstop_numbers.empty() and not OPTIONS_POPUP.visible:
			tabstop_numbers.clear()
			placeholder = ""
		
		elif SETTINGS.visible:
			if settings_cancel_button.has_focus():
				SETTINGS.hide()
			else:
				settings_cancel_button.grab_focus()


func _on_main_screen_changed(new_screen : String) -> void:
	current_main_screen = new_screen


func _update_snippets() -> void:
	var file = ConfigFile.new()
	var error = file.load(snippet_config_path)
	if error == ERR_FILE_NOT_FOUND:
		file.save(snippet_config_path)
		_load_default_snippets()
		_update_snippets()
		return
	elif error != OK:
		push_warning("Error loading the code_snippets. Error code: %s." % error)
		return
	code_snippets = file


func _update_popup_list() -> void:
	filter.grab_focus()
	itemlist.clear()
	var search_string : String = filter.text
	
	# typing " X" at the end of the search_string jumps to the X-th item in the list
	var quickselect_line = 0
	var qs_starts_at = search_string.find_last(" ")
	if qs_starts_at != -1:
		quickselect_line = search_string.substr(qs_starts_at + 1)
		if quickselect_line.is_valid_integer():
			search_string.erase(qs_starts_at + 1, quickselect_line.length())
	
	search_string = search_string.strip_edges()
	var counter = 0
	for snippet_name in code_snippets.get_sections():
		if search_string and not snippet_name.match("*" + search_string + "*") and not search_string.is_subsequence_ofi(snippet_name):
			continue
		itemlist.add_item(" " + String(counter) + "  :: ", null, false)
		itemlist.add_item(snippet_name)
		itemlist.set_item_tooltip(itemlist.get_item_count() - 1, code_snippets.get_value(snippet_name, "other_info", ""))
		itemlist.set_item_tooltip_enabled(itemlist.get_item_count() - 1, true)
		itemlist.add_item(code_snippets.get_value(snippet_name, "additional_info", ""), null, false)
		itemlist.set_item_disabled(itemlist.get_item_count() - 1, true)
		counter += 1
	
	quickselect_line = clamp(quickselect_line as int, 0, itemlist.get_item_count() / itemlist.max_columns - 1)
	if itemlist.get_item_count() > 0:
		itemlist.select(quickselect_line * itemlist.max_columns + 1)
		itemlist.ensure_current_is_visible()
		
	call_deferred("_adapt_list_height")


func _paste_code_snippet(snippet_name : String) -> void:
	var code_editor : TextEdit = _get_current_script_texteditor()
	var tab_count = code_editor.get_line(code_editor.cursor_get_line()).count("\t")
	var tabs = "\t".repeat(tab_count)
	
	current_snippet = code_snippets.get_value(snippet_name, "body")
	current_snippet = current_snippet.replace("\n", "\n" + tabs)
	
	starting_pos = [code_editor.cursor_get_line(), code_editor.cursor_get_column()]
	code_editor.insert_text_at_cursor(current_snippet)
	
	tabstop_numbers = _setup_tabstop_numbers()
	if tabstop_numbers:
		_jump_to_and_delete_next_marker(code_editor)


func _setup_tabstop_numbers() -> Array:
	var array : Array
	var pos = current_snippet.find("[@")
	while pos != -1:
		var mid_pos = current_snippet.find(":", pos + 2)
		var end_pos = current_snippet.find("]", pos + 2)
		if end_pos == -1:
			push_warning("Jump marker is not set up properly. The format is [@X:place,holder,s] where X should be an integer and \":place,holder,s\" is/are optional")
			return []
		var number = current_snippet.substr(pos + 2, (mid_pos if mid_pos != -1 and mid_pos < end_pos else end_pos) - pos - 2)
		if not number in array:
			array.push_back(number)
		pos = current_snippet.find("[@", pos + 2)
	array.sort()
	return array


func _jump_to_and_delete_next_marker(code_editor : TextEdit) -> void:
	code_editor.deselect() # placeholders
	yield(get_tree(), "idle_frame") # placeholders
	
	if delayed_one_key_press: # place the mirror vars after the keyboard shortcut was pressed
		var mirror_var : String = _get_mirror_var(code_editor)
		var specific_marker_count = max(current_snippet.count(curr_tabstop_marker) - 1, 0)
		var pos = [curr_snippet_pos[0], curr_snippet_pos[1]]
		while specific_marker_count:
			var result = _custom_search(code_editor, curr_tabstop_marker, 1, pos[0], pos[1])
			if result:
				code_editor.select(result[TextEdit.SEARCH_RESULT_LINE], result[TextEdit.SEARCH_RESULT_COLUMN], result[TextEdit.SEARCH_RESULT_LINE], result[TextEdit.SEARCH_RESULT_COLUMN] \
						+ curr_tabstop_marker.length())
				code_editor.insert_text_at_cursor(mirror_var)
				pos = [result[TextEdit.SEARCH_RESULT_LINE], result[TextEdit.SEARCH_RESULT_COLUMN]]
			specific_marker_count -= 1
		current_snippet = current_snippet.replace(curr_tabstop_marker, mirror_var)
	
	if not tabstop_numbers.empty():
		var number = tabstop_numbers.pop_front()
		var result = _custom_search(code_editor, "[@" + number, 1, starting_pos[0], starting_pos[1])
		if result.size() > 0:
			_set_current_marker_and_placeholders("[@" + number)
			delayed_one_key_press = true
			curr_snippet_pos = [result[TextEdit.SEARCH_RESULT_LINE], result[TextEdit.SEARCH_RESULT_COLUMN]]
			code_editor.select(curr_snippet_pos[0], curr_snippet_pos[1], curr_snippet_pos[0], curr_snippet_pos[1] + curr_tabstop_marker.length() + (placeholder.length() + 1 if placeholder else 0))
			if placeholder: # the PopupMenu needs to be called even if just one place holder is there; otherwise buggy (for ex: mirror example)
				code_editor.insert_text_at_cursor(curr_tabstop_marker)
				code_editor.select(curr_snippet_pos[0], curr_snippet_pos[1], curr_snippet_pos[0], curr_snippet_pos[1] + curr_tabstop_marker.length())
				OPTIONS_POPUP.code_editor = code_editor
				OPTIONS_POPUP.rect_global_position = _get_cursor_position()
				OPTIONS_POPUP.emit_signal("show_options", placeholder)
				OPTIONS_POPUP.popup()
				placeholder = ""
			else:
				var tmp = OS.clipboard
				code_editor.cut()
				OS.clipboard = tmp
	else:
		code_editor.deselect() # if last marker gives options, _get_mirror_var will make a selection


func _get_mirror_var(code_editor : TextEdit) -> String:
	code_editor.select(0, 0, curr_snippet_pos[0], curr_snippet_pos[1])
	var _code_before_marker = code_editor.get_selection_text()
	var pos = current_snippet.find(curr_tabstop_marker)
	var _text_in_snippet_after_marker = current_snippet.substr(pos + curr_tabstop_marker.length() + 1)
	var _end_of_mirror_var = code_editor.text.find(_text_in_snippet_after_marker, _code_before_marker.length())
	return code_editor.text.substr(_code_before_marker.length(), _end_of_mirror_var - _code_before_marker.length() - 1) 


func _set_current_marker_and_placeholders(marker : String) -> void:
	var pos = current_snippet.find(marker)
	var end_pos = current_snippet.find("]", pos + marker.length())
	
	if pos != -1 and end_pos != -1:
		if current_snippet[pos + marker.length()] == ":":
			var mid_pos = pos + marker.length()
			placeholder = current_snippet.substr(mid_pos + 1, end_pos - mid_pos - 1)
			current_snippet.erase(mid_pos, placeholder.length() + 1)
			curr_tabstop_marker = current_snippet.substr(pos, mid_pos - pos + 1)
			return
		elif current_snippet[pos + marker.length()] == "]":
			placeholder = ""
			curr_tabstop_marker = current_snippet.substr(pos, end_pos - pos + 1)
			return
	# this should only be reached if the user manually changed markers since _setup_tabstop_numbers() checks if the tabstops are setup properly initially
	push_warning("Jump marker is not set up properly. The format is [@X:place,holder,s] where X should be an integer and \":place,holder,s\" is/are optional")
	tabstop_numbers.clear()
	placeholder = ""


func _adapt_list_height() -> void:
	if adapt_popup_height:
		var script_icon = get_icon("Script", "EditorIcons")
		var row_height = script_icon.get_size().y + (8)
		var rows = max(itemlist.get_item_count() / itemlist.max_columns, 1) + 1
		var margin = filter.rect_size.y + $Main.margin_top + abs($Main.margin_bottom)
		var height = row_height * rows + margin
		rect_size.y = clamp(height, 0, 500)


func _on_Filter_text_changed(new_text: String) -> void:
	_update_popup_list()


func _on_Filter_text_entered(new_text: String) -> void:
	var selection = itemlist.get_selected_items()
	if selection:
		_activate_item(selection[0])
	else:
		_activate_item()


func _on_ItemList_item_activated(index: int) -> void:
	_activate_item(index)


func _activate_item(selected_index : int = -1) -> void:
	if selected_index == -1 or itemlist.is_item_disabled(selected_index):
		hide()
		return
	
	var selected_name = itemlist.get_item_text(selected_index)
	_paste_code_snippet(selected_name)
	hide()


func _on_Copy_pressed() -> void:
	var selection = itemlist.get_selected_items()
	if selection:
		var code_editor : TextEdit = _get_current_script_texteditor()
		var tab_count = code_editor.get_line(code_editor.cursor_get_line()).count("\t")
		var tabs = "\t".repeat(tab_count)
		var snippet_name = itemlist.get_item_text(selection[0])
		var snippet : String = code_snippets.get_value(snippet_name, "body", "").replace("\n", "\n" + tabs)
		var marker_pos = snippet.find(curr_tabstop_marker)
		if marker_pos != -1:
			snippet.erase(marker_pos, curr_tabstop_marker.length()) 
		OS.clipboard = snippet
	hide()


func _on_CodeSnippetPopup_popup_hide() -> void:
	filter.clear()


func _on_Edit_pressed() -> void:
	var snippet_file : File = File.new()
	var error = snippet_file.open(snippet_config_path, File.READ)
	if error != OK:
		push_warning("Error editing the code_snippets. Error code: %s." % error)
		return
	var txt = snippet_file.get_as_text()
	snippet_file.close()
	
	SNIPPET_EDITOR.edit_snippet(editor_size) 


func _get_cursor_position() -> Vector2: # approx.
	var code_editor = _get_current_script_texteditor()
	var code_font = get_font("source", "EditorFonts") if not INTERFACE.get_editor_settings().get_setting("interface/editor/code_font") else load("interface/editor/code_font")
	var curr_line = code_editor.get_line(code_editor.get_selection_from_line() if code_editor.get_selection_text() else code_editor.cursor_get_line()).replace("\t", "    ")
	var line_size = code_font.get_string_size(curr_line.substr(0, curr_line.find("[@")) if code_editor.get_selection_text() else code_editor.get_line(code_editor.cursor_get_line()).substr(0, \
			code_editor.cursor_get_column()))
	
	var editor_height = code_editor.get_child(1).max_value / code_editor.get_child(1).page * code_editor.rect_size.y
	var line_height = editor_height / code_editor.get_line_count() if code_editor.get_child(1).visible else line_size.y + 6.5 # else: in case there is no scrollbar 
	
	return code_editor.rect_global_position + Vector2(line_size.x + 80, ((code_editor.get_selection_from_line() + 1 if code_editor.get_selection_text() \
			else code_editor.cursor_get_line()) - code_editor.scroll_vertical) * line_height) # this assumes that scroll_vertical() = first visible line


func _custom_search(code_editor : TextEdit, search_string : String, flags : int, from_line : int, from_column : int) -> PoolIntArray:
	var result = code_editor.search(search_string, flags, from_line, from_column)
	if result and result[TextEdit.SEARCH_RESULT_LINE] < from_line:
		# EOF reached and search started from the top again
		return PoolIntArray([])
	return result


func _get_current_script_texteditor() -> TextEdit:
	var script_index = EDITOR.get_child(0).get_child(1).get_child(1).get_current_tab_control().get_index() # be careful about help pages
	return EDITOR.get_child(0).get_child(1).get_child(1).get_child(script_index).get_child(0).get_child(0).get_child(0) as TextEdit 


#########################################################
############# Settings and Config files #################
#########################################################


func _on_SettingsButton_pressed() -> void:
	SETTINGS.popup_centered_clamped(Vector2(600, 300), .75)
	settings_shortcut_lineedit.grab_focus()


func _on_AdaptiveHeightCheckBox_toggled(button_pressed: bool) -> void:
	adapt_popup_height = button_pressed


func _on_AtCursorCheckbox_toggled(button_pressed: bool) -> void:
	popup_at_cursor_pos = button_pressed


func _on_ShortcutLineEdit_text_changed(new_text: String) -> void:
	if new_text:
		keyboard_shortcut = new_text
	else:
		settings_shortcut_lineedit.text = keyboard_shortcut


func _on_MainHeightSpinBox_value_changed(value: float) -> void:
	main_popup_size.y = value


func _on_MainWidthSpinBox_value_changed(value: float) -> void:
	main_popup_size.x = value


func _on_EditorHeightSpinBox_value_changed(value: float) -> void:
	editor_size.y = value


func _on_EditorWidthSpinBox_value_changed(value: float) -> void:
	editor_size.x = value


func _on_FilepathLineEdit_text_changed(new_text: String) -> void:
	if not prev_file_path:
		prev_file_path = snippet_config_path
	snippet_config_path = new_text


func _on_FileDialogButton_pressed() -> void:
	settings_filedialog.popup_centered_clamped(Vector2(800, 900), .8)


func _on_FileDialog_dir_selected(dir: String) -> void:
	settings_file_path_lineedit.text = dir + "/CodeSnippets.cfg"
	settings_file_path_lineedit.emit_signal("text_changed", dir + "/CodeSnippets.cfg")


func _on_FileDialog_file_selected(path: String) -> void:
	settings_file_path_lineedit.text = path
	settings_file_path_lineedit.emit_signal("text_changed", path)


func _on_SettingsSaveButton_pressed() -> void: # settings button
	_save_settings()
	if prev_file_path: # file path for snippets was changed
		var new_file = File.new()
		var err = new_file.open(snippet_config_path, File.READ_WRITE)
		if err == ERR_FILE_NOT_FOUND:
			new_file.open(snippet_config_path, File.WRITE_READ)
		elif err != OK:
			push_warning("Error saving the code_snippets. Error code: %s." % err)
			return
		if new_file.get_as_text() == "":
			var file = File.new()
			var error = file.open(prev_file_path, File.READ)
			if error != OK:
				push_warning("Error saving the code_snippets. Error code: %s." % error)
				return
			new_file.store_string(file.get_as_text())
			file.close()
			new_file.close()
		_update_snippets()
		prev_file_path = ""
	SETTINGS.hide()


func _on_SettingsCancelButton_pressed() -> void:
	SETTINGS.hide() # does call signal


func _on_SettingsPopup_popup_hide() -> void:
	_load_settings() # reset made changes if not saved


func _load_settings():
	var config = ConfigFile.new()
	var error = config.load("user://../code_snippets_settings%s.cfg" % version_number)
	
	settings_shortcut_lineedit.text = config.get_value("Settings", "shortcut", "Control+Tab")
	settings_adaptive_height_checkbox.pressed = config.get_value("Settings", "adaptive_height", true) as bool
	settings_popup_at_cursor_pos_checkbox.pressed= config.get_value("Settings", "popup_at_cursor_pos", false) as bool
	settings_main_height_spinbox.value = config.get_value("Settings", "main_h", 500) as int
	settings_main_width_spinbox.value = config.get_value("Settings", "main_w", 750) as int
	settings_editor_height_spinbox.value = config.get_value("Settings", "editor_h", 800) as int
	settings_editor_width_spinbox.value = config.get_value("Settings", "editor_w", 1000) as int
	settings_file_path_lineedit.text = config.get_value("Settings", "file_path", "user://../CodeSnippets.cfg")
	
	if error == ERR_FILE_NOT_FOUND:
		_save_settings()
	elif error != OK:
		push_warning("Error loading settings. Error code: %s" % error)
		return 
	
	keyboard_shortcut = settings_shortcut_lineedit.text
	adapt_popup_height = settings_adaptive_height_checkbox.pressed
	popup_at_cursor_pos = settings_popup_at_cursor_pos_checkbox.pressed
	main_popup_size.y = settings_main_height_spinbox.value
	main_popup_size.x = settings_main_width_spinbox.value
	editor_size.y = settings_editor_height_spinbox.value
	editor_size.x = settings_editor_width_spinbox.value
	snippet_config_path = settings_file_path_lineedit.text


func _save_settings():
	var config = ConfigFile.new()
	config.set_value("Settings", "shortcut", settings_shortcut_lineedit.text)
	config.set_value("Settings", "adaptive_height", "true" if settings_adaptive_height_checkbox.pressed else "") 
	config.set_value("Settings", "popup_at_cursor_pos", "true" if settings_popup_at_cursor_pos_checkbox.pressed else "") 
	config.set_value("Settings", "main_h", settings_main_height_spinbox.value)
	config.set_value("Settings", "main_w", settings_main_width_spinbox.value)
	config.set_value("Settings", "editor_h", settings_editor_height_spinbox.value)
	config.set_value("Settings", "editor_w", settings_editor_width_spinbox.value) 
	config.set_value("Settings", "file_path", settings_file_path_lineedit.text) 
	var err = config.save("user://../code_snippets_settings%s.cfg" % version_number)
	if err != OK:
		push_warning("Error saving code_snippets. Error code: %s." % err)
		return


func _load_default_snippets() -> void:
	var file = File.new()
	var err = file.open(snippet_config_path, File.WRITE)
	if err != OK:
		push_warning("Error loading default code_snippets. Error code: %s." % err)
		return
	var snippets
	var default_snippets = File.new()
	var error = default_snippets.open("res://addons/CodeSnippetPopup/DefaultCodeSnippets.cfg", File.READ)
	if error != OK:
		push_warning("Error loading default code_snippets. Error code: %s." % error)
		return
	snippets = default_snippets.get_as_text()
	default_snippets.close()
	file.store_string(snippets) 
	file.close()
