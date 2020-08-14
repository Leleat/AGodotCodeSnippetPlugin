tool
extends WindowDialog


onready var text_edit = $VBoxContainer/MarginContainer/TextEdit
onready var cancel_button = $VBoxContainer/HBoxContainer/CancelButton
onready var save_button = $VBoxContainer/HBoxContainer/SaveButton
	
signal snippets_changed

func _ready() -> void:
	$VBoxContainer/HBoxContainer2/HelpButton.icon = get_icon("Issue", "EditorIcons")
	yield(get_tree(), "idle_frame")
	if owner:
		$VBoxContainer/HBoxContainer2/Label.text = "v." + owner.version_number
	

# called via the main plugin CodeSnippetPopup.tscn/.gd
func edit_snippet(snippets : String, size : Vector2) -> void:
	popup_centered_clamped(size, 0.75)
	
	text_edit.text = snippets
	text_edit.grab_focus()


func _on_CancelButton_pressed() -> void:
	text_edit.text = ""
	hide()


func _on_SaveButton_pressed() -> void:
	var file : File = File.new()
	var error = file.open(owner.snippet_config, File.WRITE)
	if error != OK:
		push_warning("Code Snippet Plugin: Error saving the code_snippets. Error code: %s." % error)
		return
	file.store_string(text_edit.text)
	file.close()
	hide()
	emit_signal("snippets_changed")


func _on_HelpButton_pressed() -> void:
	$Help.popup_centered()


func _on_TextEdit_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancel_button.grab_focus()


func _on_CancelButton_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hide()
		yield(get_tree(), "idle_frame")
		owner._update_popup_list()
		owner.popup_centered_clamped(owner.pop_size)
		owner.filter.grab_focus()
		owner.delayed_one_key_press = false
