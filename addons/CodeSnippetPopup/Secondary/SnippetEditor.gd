tool
extends WindowDialog


onready var cancel_button := $Main/VBoxContainer/HBoxContainer2/CancelButton
onready var save_button := $Main/VBoxContainer/HBoxContainer2/SaveButton
onready var delete_button := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/DeleteButton
onready var rename_button := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/RenameButton
onready var add_button := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/AddButton
onready var src_button := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/SrcButton
onready var help_button := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/HelpButton
onready var filter := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/Filter
onready var itemlist := $Main/VBoxContainer/HBoxContainer/VBoxContainer/ItemList
onready var main_texteditor := $Main/VBoxContainer/HBoxContainer/VBoxContainer2/MainTextEdit
onready var add_info := $Main/VBoxContainer/HBoxContainer/VBoxContainer2/AdditionalInfo # aka Quick Note
onready var other_info := $Main/VBoxContainer/HBoxContainer/VBoxContainer2/OtherInfo
onready var snippet_name_dialog := $SnippetNameDialog
onready var snippet_name_lineedit := $SnippetNameDialog/MarginContainer/LineEdit
onready var version_label := $Help/MarginContainer/VBoxContainer/Label
onready var help_popup := $Help
onready var move_up_button := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/MoveUpButton
onready var move_down_button := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/MoveDownButton
onready var save_confirmation_dialog := $SaveConfirmationDialog # only used when a corrupted snippet file is detected
	
var texteditor_text_changed := false # so you don't have to save the snippet body after every character change
var tmp_cfg : ConfigFile # copy of snippets config for easily discardable changes
var file_was_corrupted := false


func _ready() -> void:
	set_process_unhandled_key_input(false)
	add_button.icon = get_icon("Add", "EditorIcons")
	delete_button.icon = get_icon("Remove", "EditorIcons")
	src_button.icon = get_icon("Folder", "EditorIcons")
	cancel_button.icon = get_icon("Close", "EditorIcons")
	save_button.icon = get_icon("Save", "EditorIcons")
	filter.right_icon = get_icon("Search", "EditorIcons")
	help_button.icon = get_icon("Issue", "EditorIcons")
	rename_button.icon = get_icon("Rename", "EditorIcons")
	move_up_button.icon = get_icon("ArrowUp", "EditorIcons")
	move_down_button.icon = get_icon("ArrowDown", "EditorIcons")
	
	# setup version number in help page. Owner needs to be checked otherwise error during Godot's startup (which doesn't effect usability though)
	yield(get_tree(), "idle_frame")
	if owner:
		version_label.text = "v." + owner.version_number


func _unhandled_key_input(event: InputEventKey) -> void:
	if event.scancode == KEY_ESCAPE and event.pressed:
		cancel_button.grab_focus()
	
	# quick access some control nodes when not focusing TextEditors or LineEdits
	elif not main_texteditor.has_focus() and not add_info.has_focus() and not other_info.has_focus() and not filter.has_focus():
		if event.scancode == KEY_DELETE and event.pressed:
			delete_button.grab_focus()
		elif event.scancode == KEY_F and event.pressed:
			filter.grab_focus()
		elif event.scancode == KEY_S and event.pressed:
			move_down_button.grab_focus()
		elif event.scancode == KEY_W and event.pressed:
			move_up_button.grab_focus()
		elif event.scancode == KEY_A and event.pressed:
			add_button.grab_focus()
		elif event.scancode == KEY_C and event.pressed:
			src_button.grab_focus()
		elif event.scancode == KEY_Q and event.pressed:
			add_info.grab_focus()
		elif event.scancode == KEY_B and event.pressed:
			main_texteditor.grab_focus()
		elif event.scancode == KEY_O and event.pressed:
			other_info.grab_focus()
		elif event.scancode == KEY_H and event.pressed:
			help_button.grab_focus()
		elif event.scancode == KEY_R and event.pressed:
			rename_button.grab_focus()


func _on_SnippetEditor_about_to_show() -> void:
	# load config in tmp file for easily revertible changes (by just reloading the config file)
	tmp_cfg = ConfigFile.new()
	var err = tmp_cfg.load(owner.snippet_config_path)
	if err != OK:
		push_warning("Error trying to edit snippets. Error code: %s" % err)
		return
	
	set_process_unhandled_key_input(true)
	filter.clear() # this does call the signal, which resets TextEditors and the ItemList. It also fills the list with items.
	filter.call_deferred("grab_focus")
	
	if itemlist.get_item_count():
		itemlist.select(0)
		itemlist.emit_signal("item_selected", 0)
		rename_button.disabled = false
		move_down_button.disabled = false
		move_up_button.disabled = false
	
	if _snippet_file_is_corrupted():
		file_was_corrupted = true
		save_confirmation_dialog.dialog_text = "It looks like a ConfigFile formatting error MAY HAVE creeped in when you edited the snippet file with an external editor." + \
			"\n\nYou shouldn't maked edits (and save) with the built-in SnippetEditor for now. First you should manually recover the proper formatting with your text editor." + \
			"\n\nIf you do save and there is a formatting error, EVERYTHING after the error will be lost. If all snippets loaded properly in the built-in editor, you can ignore this warning."
		save_confirmation_dialog.rect_size = Vector2.ZERO
		save_confirmation_dialog.popup_centered()
	
	else:
		file_was_corrupted = false


func _on_CancelButton_pressed() -> void:
	hide()


func _on_CancelButton_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		hide()
		yield(get_tree(), "idle_frame")
		owner._show_main_popup()


func _on_SaveButton_pressed() -> void:
	if _snippet_file_is_corrupted():
		save_confirmation_dialog.dialog_text = "Formatting error! Manually recover the proper formatting with an external editor first." + \
				" If you continue now and there is a formatting error, EVERYTHING after that error will be lost. Are you sure you want to save?"
		save_confirmation_dialog.rect_size = Vector2.ZERO
		save_confirmation_dialog.popup_centered()
	
	else:
		if file_was_corrupted:
			file_was_corrupted = false
			save_confirmation_dialog.dialog_text = "Manually edited the snippet file." + \
					"\n\nReloading snippets..."
			save_confirmation_dialog.rect_size = Vector2.ZERO
			save_confirmation_dialog.popup_centered()
			yield(get_tree().create_timer(1.8), "timeout")
			save_confirmation_dialog.hide()
			return
		
		_save_to_snippet_file()


func _on_SaveConfirmationDialog_confirmed() -> void:
	if save_confirmation_dialog.dialog_text == "Formatting error! Manually recover the proper formatting with an external editor first." + \
				" If you continue now and there is a formatting error, EVERYTHING after that error will be lost. Are you sure you want to save?":
		_save_to_snippet_file()


func _on_SaveConfirmationDialog_popup_hide() -> void:
	if save_confirmation_dialog.dialog_text == "Manually edited the snippet file.\n\nReloading snippets...":
		_on_SnippetEditor_about_to_show()


func _on_AddButton_pressed() -> void:
	snippet_name_dialog.popup_centered_clamped(Vector2(300, 50), .75)
	snippet_name_dialog.window_title = "New Snippet"
	snippet_name_lineedit.grab_focus()


func _on_DeleteButton_pressed() -> void:
	var to_delete : Array
	if itemlist.get_selected_items():
		for item in itemlist.get_selected_items():
			tmp_cfg.erase_section(itemlist.get_item_text(item))
			to_delete.push_front(item)
		for item in to_delete:
			itemlist.remove_item(item)
		if itemlist.get_item_count() > 0:
			itemlist.grab_focus()
			itemlist.select(0)
			itemlist.emit_signal("item_selected", 0)
		else:
			_reset_texteditors()


func _on_RenameButton_pressed() -> void:
	var selection = itemlist.get_selected_items()
	if selection:
		if selection.size() > 1:
			var idx = selection[0]
			itemlist.select(idx)
			itemlist.emit_signal("item_selected", idx)
		snippet_name_dialog.popup_centered_clamped(Vector2(300, 50), .75)
		snippet_name_dialog.window_title = "Rename Snippet"
		snippet_name_lineedit.text = itemlist.get_item_text(selection[0])
		snippet_name_lineedit.select_all()
		snippet_name_lineedit.grab_focus()
		snippet_name_lineedit.caret_position = snippet_name_lineedit.text.length()


func _on_MoveUpButton_pressed() -> void:
	var selection = itemlist.get_selected_items()
	if selection.size() == 1:
		# move all items above the new index to new tmp file and delete them in tmp_cfg
		var new_idx = max(selection[0] - 1, 0)
		var old_idx = selection[0]
		var tmp = ConfigFile.new()
		var i = 0
		for section in tmp_cfg.get_sections():
			if i != old_idx:
				if i >= new_idx:
					var snippet_name = itemlist.get_item_text(i)
					tmp.set_value(snippet_name, "body", tmp_cfg.get_value(snippet_name, "body", ""))
					if tmp_cfg.has_section_key(snippet_name, "additional_info"):
						tmp.set_value(snippet_name, "additional_info", tmp_cfg.get_value(snippet_name, "additional_info"))
					if tmp_cfg.has_section_key(snippet_name, "other_info"):
						tmp.set_value(snippet_name, "other_info", tmp_cfg.get_value(snippet_name, "other_info"))
					tmp_cfg.erase_section(snippet_name)
			i += 1
		
		# copy tmp to tmp_cfg
		for section in tmp.get_sections():
			tmp_cfg.set_value(section, "body", tmp.get_value(section, "body", ""))
			if tmp.has_section_key(section, "additional_info"):
				tmp_cfg.set_value(section, "additional_info", tmp.get_value(section, "additional_info"))
			if tmp_cfg.has_section_key(section, "other_info"):
				tmp_cfg.set_value(section, "other_info", tmp.get_value(section, "other_info"))
		
		# reload itemlist
		itemlist.clear()
		for section in tmp_cfg.get_sections():
			if filter.text.strip_edges().is_subsequence_ofi(section):
				itemlist.add_item(section)
		
		# (re)select item
		itemlist.select(new_idx)
		itemlist.emit_signal("item_selected", new_idx)


func _on_MoveDownButton_pressed() -> void:
	var selection = itemlist.get_selected_items()
	if selection.size() == 1:
		# move all items below the old index to a tmp ConfigFile. Then delete old snippet and re-enter it later
		var old_idx = selection[0]
		var new_idx = min(selection[0] + 1, itemlist.get_item_count() - 1)
		var tmp = ConfigFile.new()
		var section_name = itemlist.get_item_text(itemlist.get_selected_items()[0])
		var body = tmp_cfg.get_value(section_name, "body", "")
		var quick_note = tmp_cfg.get_value(section_name, "additional_info", "")
		var other_info = tmp_cfg.get_value(section_name, "other_info", "")
		tmp_cfg.erase_section(section_name)
		var i = 0
		for section in tmp_cfg.get_sections():
			if i > old_idx:
				tmp.set_value(section, "body", tmp_cfg.get_value(section, "body", ""))
				if tmp_cfg.has_section_key(section, "additional_info"):
					tmp.set_value(section, "additional_info", tmp_cfg.get_value(section, "additional_info"))
				if tmp_cfg.has_section_key(section, "other_info"):
					tmp.set_value(section, "other_info", tmp_cfg.get_value(section, "other_info"))
				tmp_cfg.erase_section(section)
			i += 1
		
		# re-add selected item
		tmp_cfg.set_value(section_name, "body", body)
		if quick_note:
			tmp_cfg.set_value(section_name, "additional_info", quick_note)
		if other_info:
			tmp_cfg.set_value(section_name, "other_info", other_info)
		
		# copy tmp to tmp_cfg
		for section in tmp.get_sections():
			tmp_cfg.set_value(section, "body", tmp.get_value(section, "body", ""))
			if tmp.has_section_key(section, "additional_info"):
				tmp_cfg.set_value(section, "additional_info", tmp.get_value(section, "additional_info"))
			if tmp_cfg.has_section_key(section, "other_info"):
				tmp_cfg.set_value(section, "other_info", tmp.get_value(section, "other_info"))
		
		# reload itemlist
		itemlist.clear()
		for section in tmp_cfg.get_sections():
			if filter.text.strip_edges().is_subsequence_ofi(section):
				itemlist.add_item(section)
		
		# (re)select
		itemlist.select(new_idx)
		itemlist.emit_signal("item_selected", new_idx)


func _on_SrcButton_pressed() -> void:
	var err = OS.shell_open("file://" + ProjectSettings.globalize_path(owner.snippet_config_path.get_base_dir()))
	if err != OK:
		push_warning("Snippet Error: LocalPath: %s" % owner.snippet_config_path.get_base_dir())
		push_warning("Snippet Error: GlobalPath: %s" % ProjectSettings.globalize_path(owner.snippet_config_path.get_base_dir()))
		push_warning("Error opening source folder for your code snippets with your file manager. Error code: %s" % err)


func _on_HelpButton_pressed() -> void:
	help_popup.popup_centered_clamped(Vector2(1000, 1000), .75)


func _on_SnippetEditor_popup_hide() -> void:
	set_process_unhandled_key_input(false)


func _on_ItemList_item_selected(index: int) -> void:
	main_texteditor.text = tmp_cfg.get_value(itemlist.get_item_text(index), "body", "")
	add_info.text = tmp_cfg.get_value(itemlist.get_item_text(index), "additional_info", "")
	other_info.text = tmp_cfg.get_value(itemlist.get_item_text(index), "other_info", "")


func _on_ItemList_multi_selected(index: int, selected: bool) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		_reset_texteditors()
	else:
		main_texteditor.text = tmp_cfg.get_value(itemlist.get_item_text(index), "body", "")
		add_info.text = tmp_cfg.get_value(itemlist.get_item_text(index), "additional_info", "")
		other_info.text = tmp_cfg.get_value(itemlist.get_item_text(index), "other_info", "")


func _on_Filter_text_changed(new_text: String) -> void:
	_reset_texteditors()
	itemlist.clear()
	for section in tmp_cfg.get_sections():
		if new_text.strip_edges().is_subsequence_ofi(section):
			itemlist.add_item(section)
	if itemlist.get_item_count():
		itemlist.select(0)
		itemlist.emit_signal("item_selected", 0)
	
	if new_text:
		move_down_button.disabled = true
		move_up_button.disabled = true
	else:
		move_down_button.disabled = false
		move_up_button.disabled = false


func _on_ItemList_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.scancode in [KEY_SHIFT, KEY_DELETE]:
		itemlist.select_mode = ItemList.SELECT_SINGLE
		move_down_button.disabled = false
		move_up_button.disabled = false
		rename_button.disabled = false
	
	elif event is InputEventMouseButton:
		itemlist.select_mode = ItemList.SELECT_MULTI # to allow multi delete operation via mouse
		yield(get_tree(), "idle_frame")
		if itemlist.get_selected_items().size() > 1:
			move_down_button.disabled = true
			move_up_button.disabled = true
			rename_button.disabled = true
		else:
			move_down_button.disabled = false
			move_up_button.disabled = false
			rename_button.disabled = false


func _on_TextEditors_text_changed() -> void:
	# set this var, so you don't have to save the snippet body after every key press
	texteditor_text_changed = true


func _on_MainTextEdit_focus_exited() -> void:
	if texteditor_text_changed and itemlist.get_selected_items().size() == 1:
		tmp_cfg.set_value(itemlist.get_item_text(itemlist.get_selected_items()[0]), "body", main_texteditor.text)


func _on_AdditionalInfo_focus_exited() -> void:
	if texteditor_text_changed and itemlist.get_selected_items().size() == 1:
		tmp_cfg.set_value(itemlist.get_item_text(itemlist.get_selected_items()[0]), "additional_info", add_info.text)


func _on_OtherInfo_focus_exited() -> void:
	if texteditor_text_changed and itemlist.get_selected_items().size() == 1:
		tmp_cfg.set_value(itemlist.get_item_text(itemlist.get_selected_items()[0]), "other_info", other_info.text)


func _on_SnippetNameLineEdit_text_entered(new_text: String) -> void:
	snippet_name_dialog.hide()
	
	for section in tmp_cfg.get_sections():
		if new_text == section:
			push_warning("That snippet already exists!")
			return
	
	if new_text:
		# Add a new snippet
		if snippet_name_dialog.window_title == "New Snippet":
			_reset_texteditors()
			itemlist.add_item(new_text)
			itemlist.select(itemlist.get_item_count() - 1)
			main_texteditor.grab_focus()
		
		# Rename an existing snippet
		# insert section with the new name and copies old values to it
		# then delete all sections which were before the old entry and reinsert them
		elif snippet_name_dialog.window_title == "Rename Snippet":
			var old_snippet_name = itemlist.get_item_text(itemlist.get_selected_items()[0])
			var body = tmp_cfg.get_value(old_snippet_name, "body", "")
			var quick_note = tmp_cfg.get_value(old_snippet_name, "additional_info", "")
			var other_info = tmp_cfg.get_value(old_snippet_name, "other_info", "")
			# new_idx is the index in the cfg file and independant of the ItemList since the ItemList may be filtered
			var new_idx = 0 
			for section in tmp_cfg.get_sections():
				if section == old_snippet_name:
					break
				new_idx += 1
			tmp_cfg.erase_section(old_snippet_name)
			var tmp = ConfigFile.new()
			var i = 0
			
			# copy all snippets below the renamed snippet to a tmp ConfigFile
			for section in tmp_cfg.get_sections():
				if i >= new_idx:
					tmp.set_value(section, "body", tmp_cfg.get_value(section, "body", ""))
					if tmp_cfg.has_section_key(section, "additional_info"):
						tmp.set_value(section, "additional_info", tmp_cfg.get_value(section, "additional_info"))
					if tmp_cfg.has_section_key(section, "other_info"):
						tmp.set_value(section, "other_info", tmp_cfg.get_value(section, "other_info"))
					tmp_cfg.erase_section(section)
				i += 1
			
			# add renamed snippet to the snippet cfg
			tmp_cfg.set_value(new_text, "body", body)
			if quick_note:
				tmp_cfg.set_value(new_text, "additional_info", quick_note)
			if other_info:
				tmp_cfg.set_value(new_text, "other_info", other_info)
			
			# paste old snippets from the tmp configfile below the new renamed snippet
			for section in tmp.get_sections():
				tmp_cfg.set_value(section, "body", tmp.get_value(section, "body", ""))
				if tmp.has_section_key(section, "additional_info"):
					tmp_cfg.set_value(section, "additional_info", tmp.get_value(section, "additional_info"))
				if tmp_cfg.has_section_key(section, "other_info"):
					tmp_cfg.set_value(section, "other_info", tmp.get_value(section, "other_info"))
			
			# reload itemlist
			itemlist.clear()
			for section in tmp_cfg.get_sections():
				if not filter.text or (filter.text and filter.text.strip_edges().is_subsequence_ofi(section)):
					itemlist.add_item(section)
			
			# select renamed name
			for item in itemlist.get_item_count():
				if itemlist.get_item_text(item) == new_text:
					itemlist.select(item)
					itemlist.emit_signal("item_selected", item)
					break


func _on_SnippetNameDialog_popup_hide() -> void:
	snippet_name_lineedit.clear()


func _reset_texteditors() -> void:
	main_texteditor.text = ""
	add_info.text = ""
	other_info.text = ""


# the snippets file is saved via Godot's ConfigFile
# if the snippet file is edited with an external text editor, formatting errors may happen
# if the snippet file is later edited with the built-in editor and saved, the wrongly formatted part AND EVERYTHING AFTER THAT will be cut off from the file
# here we load the full snippet file as a String and compare it to a ConfigFile. Both are stripped of escape characters and spaces.
# this ... hopefully... reveals formatting errors..........
func _snippet_file_is_corrupted() -> bool:
	# get complete file_content (but only get the characters)
	var file = File.new()
	file.open(owner.snippet_config_path, File.READ)
	var file_content : String = file.get_as_text().c_unescape().strip_escapes().c_unescape().replace(" ", "").replace("\\", "")
	file.close()
	
	# get valid ConfigFile content to compare against complete content
	owner._update_snippets()
	var cfg_content : String = ""
	for section in owner.snippets_cfg.get_sections():
		cfg_content += "[" + section + "]"
		
		for key in owner.snippets_cfg.get_section_keys(section):
			# unused key
			if not key in ["body", "additional_info", "other_info"]:
				push_warning("Unknown section key in snippet file. Key: %s. That key has no function." % key)
			
			cfg_content += key + "=\"" + owner.snippets_cfg.get_value(section, key, "") + "\""
	
	cfg_content = cfg_content.c_unescape().strip_escapes().replace(" ", "").replace("\\", "")
	
	return file_content != cfg_content


func _save_to_snippet_file() -> void:
	var err = tmp_cfg.save(owner.snippet_config_path)
	if err != OK:
		push_warning("Error saving snippets. Error code: %s" % err)
		return
	else:
		owner._update_snippets()
		owner._show_main_popup()
		hide()
