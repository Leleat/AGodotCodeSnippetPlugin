tool
extends PopupPanel


var INTERFACE : EditorInterface
var EDITOR : ScriptEditor
var EDITOR_SETTINGS : EditorSettings
	
onready var itemlist = $Main/VBoxContainer/ItemList
onready var filter : LineEdit = $Main/VBoxContainer/HBoxContainer/Filter
onready var copy_button : Button = $Main/VBoxContainer/HBoxContainer/Copy
onready var edit_button : Button = $Main/VBoxContainer/HBoxContainer/Edit
onready var settings_button = $Main/VBoxContainer/HBoxContainer/Settings
onready var SNIPPET_EDITOR : WindowDialog = $SnippetEditor
onready var SETTINGS : WindowDialog = $SettingsPopup
onready var OPTIONS_POPUP : PopupMenu = $OptionsPopup # popup for a snippet with options; for ex. [@1:OptionA,OptionB]
onready var STATUS_POPUP : PopupPanel = $StatusPopup
onready var settings_editshortcut_button := $SettingsPopup/Main/VBoxContainer/HBoxContainer/EditShortcutButton
onready var settings_shortcut_lineedit := $SettingsPopup/Main/VBoxContainer/HBoxContainer/ShortcutLineEdit
onready var settings_filedialog_button := $SettingsPopup/Main/VBoxContainer/HBoxContainer7/FileDialogButton
onready var settings_filedialog := $SettingsPopup/FileDialog
onready var settings_file_path_lineedit := $SettingsPopup/Main/VBoxContainer/HBoxContainer7/FilepathLineEdit
onready var settings_cancel_button := $SettingsPopup/Main/VBoxContainer/HBoxContainer9/CancelButton
onready var settings_save_button := $SettingsPopup/Main/VBoxContainer/HBoxContainer9/SaveButton
onready var settings_adaptive_height_checkbox := $SettingsPopup/Main/VBoxContainer/HBoxContainer2/AdaptiveHeightCheckBox
onready var settings_status_updates_checkbox := $SettingsPopup/Main/VBoxContainer/HBoxContainer10/StatusUpdatesCheckBox
onready var settings_popup_at_cursor_pos_checkbox := $SettingsPopup/Main/VBoxContainer/HBoxContainer8/AtCursorCheckbox
onready var settings_main_height_spinbox := $SettingsPopup/Main/VBoxContainer/HBoxContainer3/PopupHeightSpinBox
onready var settings_main_width_spinbox := $SettingsPopup/Main/VBoxContainer/HBoxContainer4/PopupWidthSpinBox
onready var settings_editor_height_spinbox := $SettingsPopup/Main/VBoxContainer/HBoxContainer5/EditorHeightSpinBox
onready var settings_editor_width_spinbox := $SettingsPopup/Main/VBoxContainer/HBoxContainer6/EditorWidthSpinBox
onready var settings_enter_shortcut_popup := $SettingsPopup/EnterShortcutPopup
onready var settings_shortcut_label := $SettingsPopup/EnterShortcutPopup/MarginContainer/ShortcutLabel
onready var status_popup := $StatusPopup
onready var status_message := $StatusPopup/MarginContainer/HBoxContainer/StatusMessage
onready var status_icon := $StatusPopup/MarginContainer/HBoxContainer/StatusIcon
# settings vars
var keyboard_shortcut : String
var adapt_popup_height : bool
var main_popup_size : Vector2
var editor_size : Vector2
var snippet_config_path : String 
var popup_at_cursor_pos : bool
var status_updates_enabled : bool
# snippet vars
var curr_tabstop_marker = "" # [@X] -> X should be an integer. 
var current_snippet_body : String = ""
var to_mirror : bool = false
var options : String # for the snippets with options. Options are separated by ","
var insertion_pos : Array # position, where snippet was inserted
var current_marker_pos : Array # position, where the current jump marker was
var tabstop_numbers : Array # numerically sorted array of the numbers of the jump markers (aka tabstops)
	
var current_main_screen : String = ""
var snippets_cfg : ConfigFile
var version_number # of plugin
	
const LINE = 0 # different than TextEdits search results 
const COLUMN = 1 # different than TextEdits search results
signal snippet_has_options(options, pos, text_editor)
signal snippet_insertion_done
signal snippet_insertion_aborted


func _ready() -> void:
	# setup version number variable. Used when in name of settings.cfg file and displayed in built-in help page.
	var ver_nr = ConfigFile.new()
	var error = ver_nr.load("res://addons/CodeSnippetPopup/plugin.cfg")
	if error != OK:
		push_warning("Error %s getting version number." % error)
		return
	version_number = ver_nr.get_value("plugin", "version", "?") 
	
	connect("snippet_has_options", OPTIONS_POPUP, "_on_snippet_has_options")
	connect("snippet_insertion_aborted", self, "_on_snippet_insertion_aborted")
	connect("snippet_insertion_done", self, "_on_snippet_insertion_done")
	
	filter.right_icon = get_icon("Search", "EditorIcons")
	copy_button.icon = get_icon("ActionCopy", "EditorIcons")
	edit_button.icon = get_icon("Edit", "EditorIcons")
	settings_button.icon = get_icon("Tools", "EditorIcons")
	settings_filedialog_button.icon = get_icon("Folder", "EditorIcons")
	settings_save_button.icon = get_icon("Save", "EditorIcons")
	settings_cancel_button.icon = get_icon("Close", "EditorIcons")
	settings_editshortcut_button.icon = get_icon("Edit", "EditorIcons")
	
	_load_settings()
	_update_snippets()


func _unhandled_key_input(event : InputEventKey) -> void:
	if event.as_text() == keyboard_shortcut and current_main_screen == "Script" and not SETTINGS.visible:
		# if Tab (and possibly other keys) is part of the keyboard shortcut, you cannot check the pressed state else it won't work ... I don't know why 
		# For other shortcuts you need to check the pressed state, otherwise the code will activate on press AND on release
		if not "Tab".is_subsequence_ofi(keyboard_shortcut) and not event.pressed:
			return
		
		# first time press or press after completing previous snippet insertion (incl. jumping/mirroring). 
		if tabstop_numbers.empty():
			_show_main_popup()
		
		# key press after snippet insertion. Jump to next marker and mirror variable
		else:
			var editor : TextEdit = _get_current_script_texteditor()
			_jump_to_next_marker(editor)
	
	if event.scancode == KEY_ESCAPE and event.pressed:
		# abort auto-jumping
		if not tabstop_numbers.empty() and not OPTIONS_POPUP.visible:
			tabstop_numbers.clear()
			options = ""
			to_mirror = false
			emit_signal("snippet_insertion_aborted")
		
		elif SETTINGS.visible:
			if settings_cancel_button.has_focus():
				SETTINGS.hide()
			elif settings_editshortcut_button.icon == get_icon("DebugSkipBreakpointsOff", "EditorIcons"):
				settings_editshortcut_button.icon = get_icon("Edit", "EditorIcons")
			else:
				settings_cancel_button.grab_focus()
	
	# Settings page: recording keyboard input on release for shortcut setting.
	if settings_enter_shortcut_popup.visible and not event.pressed:
		settings_shortcut_lineedit.text = event.as_text()
		settings_enter_shortcut_popup.hide()


func _on_main_screen_changed(new_screen : String) -> void:
	current_main_screen = new_screen


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
		var snippet : String = snippets_cfg.get_value(snippet_name, "body", "").replace("\n", "\n" + tabs)
		var marker_pos = snippet.find(curr_tabstop_marker)
		if marker_pos != -1:
			snippet.erase(marker_pos, curr_tabstop_marker.length()) 
		OS.clipboard = snippet
	hide()


func _on_CodeSnippetPopup_popup_hide() -> void:
	filter.clear()
	_get_current_script_texteditor().grab_focus()


func _on_Edit_pressed() -> void:
	var snippet_file : File = File.new()
	var error = snippet_file.open(snippet_config_path, File.READ)
	if error != OK:
		push_warning("Error editing the snippets_cfg. Error code: %s." % error)
		return
	var txt = snippet_file.get_as_text()
	snippet_file.close()
	
	SNIPPET_EDITOR.popup_centered_clamped(editor_size, .95)


func _show_main_popup() -> void:
	if popup_at_cursor_pos: 
		# position is set in _adapt_list_height(); otherwise the position will be off in lower parts of the code editor
		rect_size = main_popup_size
		popup()
	else:
		popup_centered_clamped(main_popup_size)
	_update_popup_list()


func _update_snippets() -> void:
	var file = ConfigFile.new()
	var error = file.load(snippet_config_path)
	if error == ERR_FILE_NOT_FOUND:
		file.save(snippet_config_path)
		_load_default_snippets()
		_update_snippets()
		return
	elif error != OK:
		push_warning("Error loading the snippets_cfg. Error code: %s." % error)
		return
	snippets_cfg = file


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
	for snippet_name in snippets_cfg.get_sections():
		if search_string and not search_string.is_subsequence_ofi(snippet_name):
			continue
		
		# quickselect numer
		itemlist.add_item(" " + String(counter) + "  :: ", null, false)
		
		# snippet name
		itemlist.add_item(snippet_name)
		
		# tooltip for snippet name
		itemlist.set_item_tooltip(itemlist.get_item_count() - 1, snippets_cfg.get_value(snippet_name, "other_info", ""))
		itemlist.set_item_tooltip_enabled(itemlist.get_item_count() - 1, true)
		
		# quick note (additional info)
		itemlist.add_item(snippets_cfg.get_value(snippet_name, "additional_info", ""), null, false)
		itemlist.set_item_disabled(itemlist.get_item_count() - 1, true)
		
		#tooltip for quick note (additional info) - same as other tooltip
		itemlist.set_item_tooltip(itemlist.get_item_count() - 1, snippets_cfg.get_value(snippet_name, "other_info", ""))
		itemlist.set_item_tooltip_enabled(itemlist.get_item_count() - 1, true)
		counter += 1
	
	quickselect_line = clamp(quickselect_line as int, 0, itemlist.get_item_count() / itemlist.max_columns - 1)
	if itemlist.get_item_count() > 0:
		itemlist.select(quickselect_line * itemlist.max_columns + 1)
		itemlist.ensure_current_is_visible()
		
	call_deferred("_adapt_list_height")


func _paste_code_snippet(snippet_name : String) -> void:
	var code_editor : TextEdit = _get_current_script_texteditor()
	current_snippet_body = snippets_cfg.get_value(snippet_name, "body", "")
	
	# respect existing tabs
	var tab_count : int = code_editor.get_line(code_editor.cursor_get_line()).count("\t")
	var tabs : String = "\t".repeat(tab_count)
	current_snippet_body = current_snippet_body.replace("\n", "\n" + tabs)
	
	insertion_pos = [code_editor.cursor_get_line(), code_editor.cursor_get_column()]
	code_editor.insert_text_at_cursor(current_snippet_body)
	tabstop_numbers = _get_tabstop_numbers()
	
	_jump_to_next_marker(code_editor)


func _get_tabstop_numbers() -> Array:
	var array : Array
	var pos = current_snippet_body.find("[@")
	
	# loop through snippet's body and look for markers. Format is either [@X] or [@X:OptionA,OptionB...]
	while pos != -1:
		var mid_pos = current_snippet_body.find(":", pos + 2)
		var end_pos = current_snippet_body.find("]", pos + 2)
		if end_pos == -1:
			push_warning("Jump marker is not set up properly. The format is [@X:OptionA,OptionB] where X should be an integer and \":OptionA,OptionB,...\" is/are optional")
			return []
		
		# number is the X in [@X] or in [@X:OptionA,...]
		var number = current_snippet_body.substr(pos + 2, (mid_pos if mid_pos != -1 and mid_pos < end_pos else end_pos) - pos - 2)
		array.push_back(number)
		pos = current_snippet_body.find("[@", pos + 2)
	array.sort()
	return array


func _jump_to_next_marker(code_editor : TextEdit) -> void:
	yield(get_tree(), "idle_frame") # Do not remove, else it causes focus issues !!!
	
	if to_mirror: # this happens one shortcut press delayed since to_mirror is set in the code block below
		var marker_nr = curr_tabstop_marker.substr(2, curr_tabstop_marker.length() - 3) # Format of [@X] means X.length = [@X].length - [@].length
		var mirrored_var = _get_mirror_var(code_editor)
		var mirror_marker_count = tabstop_numbers.count(marker_nr) 
		var pos = [current_marker_pos[LINE], current_marker_pos[COLUMN]]
		
		# actual mirroring
		while mirror_marker_count:
			var result = _custom_search(code_editor, curr_tabstop_marker, 1, pos[LINE], pos[COLUMN])
			if result:
				code_editor.select(result[TextEdit.SEARCH_RESULT_LINE], result[TextEdit.SEARCH_RESULT_COLUMN], result[TextEdit.SEARCH_RESULT_LINE], result[TextEdit.SEARCH_RESULT_COLUMN] \
						+ curr_tabstop_marker.length())
				code_editor.insert_text_at_cursor(mirrored_var)
				pos = [result[TextEdit.SEARCH_RESULT_LINE], result[TextEdit.SEARCH_RESULT_COLUMN]]
			mirror_marker_count -= 1
		
		# necessary to later properly find pos in _get_mirror_var()
		current_snippet_body = current_snippet_body.replace(curr_tabstop_marker, mirrored_var)
		
		# "delete" all markers of the same number after mirroring
		var tmp : Array
		for nr in tabstop_numbers:
			if marker_nr != nr:
				tmp.push_back(nr)
		tabstop_numbers = tmp
		
		to_mirror = false
	
	if tabstop_numbers:
		var nr = tabstop_numbers.pop_front()
		to_mirror = true if tabstop_numbers and nr == tabstop_numbers[0] else false
		var result = _custom_search(code_editor, "[@" + nr, 1, insertion_pos[LINE], insertion_pos[COLUMN])
		if result.size() > 0:
			curr_tabstop_marker = "[@" + nr + "]"
			options = _get_options("[@" + nr)
			current_marker_pos = [result[TextEdit.SEARCH_RESULT_LINE], result[TextEdit.SEARCH_RESULT_COLUMN]]
			code_editor.select(current_marker_pos[LINE], current_marker_pos[COLUMN], current_marker_pos[LINE], current_marker_pos[COLUMN] + curr_tabstop_marker.length() + (options.length() + 1 if options else 0))
			
			if options.split(",", false).size() == 1:
				code_editor.insert_text_at_cursor(options)
				code_editor.select(current_marker_pos[LINE], current_marker_pos[COLUMN], current_marker_pos[LINE], current_marker_pos[COLUMN] + options.length())
			
			elif options: 
				code_editor.insert_text_at_cursor(curr_tabstop_marker)
				code_editor.select(current_marker_pos[LINE], current_marker_pos[COLUMN], current_marker_pos[LINE], current_marker_pos[COLUMN] + curr_tabstop_marker.length())
				emit_signal("snippet_has_options", options, _get_cursor_position(), code_editor)
			
			else:
				# moving cursor to the selection; cursor_set_line and _column don't seem to work. So I just cut and paste (and reselect the marker)
				var tmp = OS.clipboard
				code_editor.cut()
				code_editor.paste()
				code_editor.select(current_marker_pos[LINE], current_marker_pos[COLUMN], current_marker_pos[LINE], current_marker_pos[COLUMN] + curr_tabstop_marker.length())
				OS.clipboard = tmp
		
		# last marker doesn't get mirrored
		if not tabstop_numbers:
			if not OPTIONS_POPUP.visible:
				emit_signal("snippet_insertion_done")
			# if last marker is marker (i.e. it hasn't been replaced by a variable) delete it
			var selection : String = code_editor.get_selection_text()
			if  selection and selection.begins_with("[@") and selection.ends_with("]"):
				var tmp = OS.clipboard
				code_editor.cut()
				OS.clipboard = tmp
	
	# last marker was mirrored or no markers at all
	else:
		emit_signal("snippet_insertion_done")


func _get_mirror_var(code_editor : TextEdit) -> String:
	# get the ENTIRE CODE of the TextEditor before the current jump marker
	code_editor.select(0, 0, current_marker_pos[LINE], current_marker_pos[COLUMN])
	var _code_before_marker = code_editor.get_selection_text()
	
	# get the CODE OF THE SNIPPET after the current jump marker
	var pos = current_snippet_body.find(curr_tabstop_marker)
	var _snippet_text_after_marker = current_snippet_body.substr(pos + curr_tabstop_marker.length())
	
	# find the position of the CODE OF THE SNIPPET after the jump marker in the ENTIRE CODE
	# offset is needed in case of markers having the same number with no in-between markers. This messes up the find() call. For ex. "# [@1][@1]" as a snippet body would cause problems
	var offset = curr_tabstop_marker.length() if code_editor.text.substr(_code_before_marker.length(), 4) == curr_tabstop_marker else 0
	var _end_of_mirror_var = code_editor.text.find(_snippet_text_after_marker, _code_before_marker.length() + offset)
	
	return code_editor.text.substr(_code_before_marker.length(), _end_of_mirror_var - _code_before_marker.length()) 


func _get_options(marker : String) -> String:
	var pos = current_snippet_body.find(marker)
	var end_pos = current_snippet_body.find("]", pos + marker.length())
	
	if pos != -1 and end_pos != -1:
		if current_snippet_body[pos + marker.length()] == ":":
			var mid_pos = pos + marker.length()
			var opt = current_snippet_body.substr(mid_pos + 1, end_pos - mid_pos - 1)
			current_snippet_body.erase(mid_pos, opt.length() + 1) # erase options so that all markers wit the same number have the Format of [@X] for later removal
			return opt
		elif current_snippet_body[pos + marker.length()] == "]":
			return ""
	
	# this should only be reached if the user manually changed markers since _get_tabstop_numbers() checks if the tabstops are setup properly initially
	push_warning("Jump marker is not set up properly. The format is [@X:place,holder,s] where X should be an integer and \":place,holder,s\" is/are optional")
	tabstop_numbers.clear()
	return ""


func _adapt_list_height() -> void:
	if adapt_popup_height:
		var script_icon = get_icon("Script", "EditorIcons")
		var row_height = script_icon.get_size().y + (8)
		var rows = max(itemlist.get_item_count() / itemlist.max_columns, 1) + 1
		var margin = filter.rect_size.y + $Main.margin_top + abs($Main.margin_bottom)
		var height = row_height * rows + margin
		rect_size.y = clamp(height, 0, main_popup_size.y)
	
	if popup_at_cursor_pos:
		rect_global_position = _get_cursor_position()
		if rect_global_position.y + rect_size.y > OS.get_screen_size().y:
			rect_global_position.y = OS.get_screen_size().y - rect_size.y


func _get_cursor_position() -> Vector2: # approx.; could use help for more precision
	var code_editor : TextEdit = _get_current_script_texteditor()
	var code_font = get_font("source", "EditorFonts") if not INTERFACE.get_editor_settings().get_setting("interface/editor/code_font") else load("interface/editor/code_font")
	var hscroll = code_editor.scroll_horizontal
	var vscroll = code_editor.scroll_vertical
	var vscroll_bar = code_editor.get_child(1)
	
	var curr_line : String
	var curr_line_width
	var line_height = code_font.get_string_size("").y + EDITOR_SETTINGS.get_setting("text_editor/theme/line_spacing")
	var tabs = " ".repeat(EDITOR_SETTINGS.get_setting("text_editor/indent/size") as int)
	
	# when inserting snippet
	if code_editor.get_selection_text(): 
		curr_line = code_editor.get_line(code_editor.get_selection_from_line())
		var selection_pos = curr_line.find( code_editor.get_selection_text()) 
		var line_til_selection = curr_line.substr(0, selection_pos) 
		curr_line_width = code_font.get_string_size( line_til_selection.replace("\t", tabs) ).x
	
	else:
		curr_line = code_editor.get_line(code_editor.cursor_get_line())
		var line_til_cursor = curr_line.substr(0, code_editor.cursor_get_column()) 
		curr_line_width = code_font.get_string_size( line_til_cursor.replace("\t", tabs) ).x
	
	var hidden_lines = 0
	for line in (code_editor.get_selection_from_line() if code_editor.get_selection_text() else code_editor.cursor_get_line()):
		if code_editor.is_line_hidden(line):
			hidden_lines += 1
	
	var pos : Vector2
	pos.x = code_editor.rect_global_position.x + curr_line_width + 80 - hscroll - (15 if not vscroll_bar.visible else 0) # 80 is the value from the left until the code folding symbol // 15 is just a MagicNr which looked right
	pos.y = code_editor.rect_global_position.y + (code_editor.cursor_get_line() - code_editor.scroll_vertical - hidden_lines - 1) * line_height + 48 # 48 is a MagicNr which looked right 
	return pos


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
################### Status popup ########################
#########################################################


func _on_snippet_insertion_aborted() -> void:
	if status_updates_enabled:
		status_popup.rect_size = Vector2.ZERO
		status_popup.rect_global_position = _get_cursor_position()
		status_icon.icon = get_icon("ImportFail", "EditorIcons")
		status_popup.popup()
		yield(get_tree().create_timer(1.2), "timeout")
		status_popup.hide()


func _on_snippet_insertion_done() -> void:
	if status_updates_enabled:
		status_popup.rect_size = Vector2.ZERO
		status_popup.rect_global_position = _get_cursor_position()
		status_popup.popup()
		status_icon.icon = get_icon("ImportCheck", "EditorIcons")
		yield(get_tree().create_timer(1.2), "timeout")
		status_popup.hide()


#########################################################
############# Settings and Config files #################
#########################################################


func _on_SettingsButton_pressed() -> void:
	SETTINGS.popup_centered_clamped(Vector2(600, 350), .75)
	settings_editshortcut_button.grab_focus()


func _on_ShortcutEditButton_pressed() -> void:
	if settings_editshortcut_button.icon == get_icon("Edit", "EditorIcons"):
		settings_editshortcut_button.set_deferred("icon", get_icon("DebugSkipBreakpointsOff", "EditorIcons"))
		var size = Vector2(300, 100)
		settings_enter_shortcut_popup.rect_size = size
		settings_enter_shortcut_popup.rect_global_position = OS.get_screen_size() / 2 - size / 2
		get_focus_owner().release_focus()
		settings_enter_shortcut_popup.call_deferred("show_modal")


func _on_EnterShortcutPopup_modal_closed_or_hide() -> void:
	if settings_editshortcut_button:
		settings_editshortcut_button.icon = get_icon("Edit", "EditorIcons")
		settings_editshortcut_button.grab_focus()


func _on_FileDialogButton_pressed() -> void:
	settings_filedialog.popup_centered_clamped(Vector2(800, 900), .8)
	settings_filedialog.current_dir = ProjectSettings.globalize_path(snippet_config_path.get_base_dir())


func _on_FileDialog_dir_selected(dir: String) -> void:
	settings_file_path_lineedit.text = dir + "/CodeSnippets.cfg"
	settings_file_path_lineedit.emit_signal("text_changed", dir + "/CodeSnippets.cfg")


func _on_FileDialog_file_selected(path: String) -> void:
	settings_file_path_lineedit.text = path
	settings_file_path_lineedit.emit_signal("text_changed", path)


func _on_SettingsSaveButton_pressed() -> void: # settings button
	var settings = ConfigFile.new()
	var error = settings.load("user://../code_snippets_settings%s.cfg" % version_number)
	if error != OK:
		push_warning("Plugin couldn't load snippet settings. Error code: %s" % error)
		return
	
	# set shortcut setting
	var prev_shortcut = settings.get_value("Settings", "shortcut")
	var new_shortcut = settings_shortcut_lineedit.text
	if prev_shortcut != new_shortcut:
		var shortcut_is_valid = true
		for key in new_shortcut.split("+"):
			if not OS.find_scancode_from_string(key): # doesn't check invalid key combos (for example Control+Control+E), only invalid single keys
				shortcut_is_valid = false
				settings_shortcut_lineedit.text = prev_shortcut
				push_warning("Invalid keyboard shortcut for code snippets." )
		if shortcut_is_valid:
			keyboard_shortcut = settings_shortcut_lineedit.text
	
	# set snippet file path setting
	var prev_file_path = settings.get_value("Settings", "file_path")
	var new_file_path = settings_file_path_lineedit.text
	if prev_file_path != new_file_path:
		if not ProjectSettings.globalize_path(new_file_path).get_base_dir(): # invalid path... sorta
			settings_file_path_lineedit.text = prev_file_path
			push_warning("Invalid file path for code snippets." )
		else:
			var new_file = File.new()
			var err = new_file.open(new_file_path, File.READ_WRITE)
			if err == ERR_FILE_NOT_FOUND:
				new_file.open(new_file_path, File.WRITE_READ)
			elif err != OK:
				push_warning("Error saving the snippets_cfg. Error code: %s." % err)
				return
			if new_file.get_as_text() == "":
				var file = File.new()
				var err2 = file.open(prev_file_path, File.READ)
				if err2 != OK:
					push_warning("Error saving the snippets_cfg. Error code: %s." % err2)
					return
				new_file.store_string(file.get_as_text())
				file.close()
				new_file.close()
			snippet_config_path = new_file_path
		_update_snippets()
	
	# set other settings
	adapt_popup_height = settings_adaptive_height_checkbox.pressed
	status_updates_enabled = settings_status_updates_checkbox.pressed
	popup_at_cursor_pos = settings_popup_at_cursor_pos_checkbox.pressed
	main_popup_size.y = settings_main_height_spinbox.value
	main_popup_size.x = settings_main_width_spinbox.value
	editor_size.y = settings_editor_height_spinbox.value
	editor_size.x = settings_editor_width_spinbox.value
	
	_save_settings()
	_update_popup_list()
	SETTINGS.hide()


func _on_SettingsCancelButton_pressed() -> void:
	SETTINGS.hide() # does call signal


func _on_SettingsPopup_popup_hide() -> void:
	_load_settings() # reset made changes if not saved


func _load_settings():
	var config = ConfigFile.new()
	var error = config.load("user://../code_snippets_settings%s.cfg" % version_number)
	
	settings_shortcut_lineedit.text = config.get_value("Settings", "shortcut", "Control+T")
	settings_adaptive_height_checkbox.pressed = config.get_value("Settings", "adaptive_height", true) as bool
	settings_status_updates_checkbox.pressed = config.get_value("Settings", "show_status_updates", true) as bool
	settings_popup_at_cursor_pos_checkbox.pressed= config.get_value("Settings", "popup_at_cursor_pos", false) as bool
	settings_main_height_spinbox.value = config.get_value("Settings", "main_h", 500) as int
	settings_main_width_spinbox.value = config.get_value("Settings", "main_w", 750) as int
	settings_editor_height_spinbox.value = config.get_value("Settings", "editor_h", 800) as int
	settings_editor_width_spinbox.value = config.get_value("Settings", "editor_w", 1200) as int
	settings_file_path_lineedit.text = config.get_value("Settings", "file_path", "user://../CodeSnippets.cfg")
	
	if error == ERR_FILE_NOT_FOUND:
		_save_settings()
	elif error != OK:
		push_warning("Error loading settings. Error code: %s" % error)
		return 
	
	keyboard_shortcut = settings_shortcut_lineedit.text
	adapt_popup_height = settings_adaptive_height_checkbox.pressed
	status_updates_enabled = settings_status_updates_checkbox.pressed
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
	config.set_value("Settings", "show_status_updates", "true" if settings_status_updates_checkbox.pressed else "") 
	config.set_value("Settings", "popup_at_cursor_pos", "true" if settings_popup_at_cursor_pos_checkbox.pressed else "") 
	config.set_value("Settings", "main_h", settings_main_height_spinbox.value)
	config.set_value("Settings", "main_w", settings_main_width_spinbox.value)
	config.set_value("Settings", "editor_h", settings_editor_height_spinbox.value)
	config.set_value("Settings", "editor_w", settings_editor_width_spinbox.value) 
	config.set_value("Settings", "file_path", settings_file_path_lineedit.text) 
	var err = config.save("user://../code_snippets_settings%s.cfg" % version_number)
	if err != OK:
		push_warning("Error saving snippets_cfg. Error code: %s." % err)
		return


func _load_default_snippets() -> void:
	var file = File.new()
	var err = file.open(snippet_config_path, File.WRITE)
	if err != OK:
		push_warning("Error loading default snippets_cfg. Error code: %s." % err)
		return
	var snippets
	var default_snippets = File.new()
	var error = default_snippets.open("res://addons/CodeSnippetPopup/DefaultCodeSnippets.cfg", File.READ)
	if error != OK:
		push_warning("Error loading default snippets_cfg. Error code: %s." % error)
		return
	snippets = default_snippets.get_as_text()
	default_snippets.close()
	file.store_string(snippets) 
	file.close()
