tool
extends WindowDialog


onready var cancel_button := $Main/VBoxContainer/HBoxContainer2/CancelButton
onready var save_button := $Main/VBoxContainer/HBoxContainer2/SaveButton
onready var delete_button := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/DeleteButton
onready var add_button := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/AddButton
onready var src_button := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/SrcButton
onready var help_button := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/HelpButton
onready var filter := $Main/VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/Filter
onready var itemlist := $Main/VBoxContainer/HBoxContainer/VBoxContainer/ItemList
onready var main_texteditor := $Main/VBoxContainer/HBoxContainer/VBoxContainer2/MainTextEdit
onready var add_info := $Main/VBoxContainer/HBoxContainer/VBoxContainer2/AdditionalInfo
onready var other_info := $Main/VBoxContainer/HBoxContainer/VBoxContainer2/OtherInfo
onready var snippet_name_dialog := $SnippetNameDialog
onready var snippet_name_lineedit := $SnippetNameDialog/MarginContainer/LineEdit
onready var version_label := $Help/MarginContainer/VBoxContainer/Label
onready var help_popup := $Help
var text_changed := false
var tmp_cfg : ConfigFile # copy of snippets config; to do reversible changes to the config


func _ready() -> void:
	set_process_unhandled_key_input(false)
	add_button.icon = get_icon("Add", "EditorIcons")
	delete_button.icon = get_icon("Remove", "EditorIcons")
	src_button.icon = get_icon("Folder", "EditorIcons")
	cancel_button.icon = get_icon("Close", "EditorIcons")
	save_button.icon = get_icon("Save", "EditorIcons")
	filter.right_icon = get_icon("Search", "EditorIcons")
	help_button.icon = get_icon("Issue", "EditorIcons")
	yield(get_tree(), "idle_frame")
	if owner:
		version_label.text = "v." + owner.version_number


func _unhandled_key_input(event: InputEventKey) -> void:
	if event.scancode == KEY_ESCAPE and event.pressed:
		cancel_button.grab_focus()
	
	elif itemlist.has_focus() or cancel_button.has_focus() or save_button.has_focus() or add_button.has_focus() or src_button.has_focus() or delete_button.has_focus() or help_button.has_focus():
		if event.scancode == KEY_DELETE and event.pressed:
			delete_button.grab_focus()
		elif event.scancode == KEY_F and event.pressed:
			filter.grab_focus()
		elif event.scancode == KEY_S and event.pressed:
			save_button.grab_focus()
		elif event.scancode == KEY_A and event.pressed:
			add_button.grab_focus()
		elif event.scancode == KEY_C and event.pressed:
			src_button.grab_focus()
		elif event.scancode == KEY_Q and event.pressed:
			add_info.grab_focus()


# called via the main plugin CodeSnippetPopup.tscn/.gd
func edit_snippet(size : Vector2) -> void:
	tmp_cfg = ConfigFile.new()
	var err = tmp_cfg.load(owner.snippet_config_path)
	if err != OK:
		push_warning("Error trying to edit snippets. Error code: %s" % err)
		return
	popup_centered_clamped(size, 0.75)
	set_process_unhandled_key_input(true)
	filter.clear()
	filter.grab_focus()
	itemlist.clear()
	_reset_texteditors()
	for section in tmp_cfg.get_sections():
		itemlist.add_item(section)
	if itemlist.get_item_count():
		itemlist.select(0)
		itemlist.emit_signal("item_selected", 0)


func _on_CancelButton_pressed() -> void:
	hide()


func _on_CancelButton_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		hide()
		yield(get_tree(), "idle_frame")
		owner._update_popup_list()
		owner.popup()
		owner.delayed_one_key_press = false


func _on_SaveButton_pressed() -> void:
	var err = tmp_cfg.save(owner.snippet_config_path)
	if err != OK:
		push_warning("Error saving snippets. Error code: %s" % err)
		return
	else:
		owner._update_snippets()
		owner._update_popup_list()
		hide()


func _on_AddButton_pressed() -> void:
	snippet_name_dialog.popup_centered_clamped(Vector2(200, 50), .75)
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


func _on_SrcButton_pressed() -> void:
	OS.shell_open(ProjectSettings.globalize_path(owner.snippet_config_path.get_base_dir()))


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


func _on_ItemList_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		itemlist.select_mode = ItemList.SELECT_SINGLE
	elif event is InputEventMouse:
		itemlist.select_mode = ItemList.SELECT_MULTI # to allow multi delete operation via mouse


func _on_TextEditors_text_changed() -> void:
	text_changed = true


func _on_MainTextEdit_focus_exited() -> void:
	if text_changed and itemlist.get_selected_items().size() == 1:
		tmp_cfg.set_value(itemlist.get_item_text(itemlist.get_selected_items()[0]), "body", main_texteditor.text)


func _on_AdditionalInfo_focus_exited() -> void:
	if text_changed and itemlist.get_selected_items().size() == 1:
		tmp_cfg.set_value(itemlist.get_item_text(itemlist.get_selected_items()[0]), "additional_info", add_info.text)


func _on_OtherInfo_focus_exited() -> void:
	if text_changed and itemlist.get_selected_items().size() == 1:
		tmp_cfg.set_value(itemlist.get_item_text(itemlist.get_selected_items()[0]), "other_info", other_info.text)


func _on_SnippetNameLineEdit_text_entered(new_text: String) -> void:
	snippet_name_dialog.hide()
	if new_text:
		_reset_texteditors()
		itemlist.add_item(new_text)
		itemlist.select(itemlist.get_item_count() - 1)
		main_texteditor.grab_focus()


func _on_SnippetNameDialog_popup_hide() -> void:
	snippet_name_lineedit.clear()


func _reset_texteditors() -> void:
	main_texteditor.text = ""
	add_info.text = ""
	other_info.text = ""
