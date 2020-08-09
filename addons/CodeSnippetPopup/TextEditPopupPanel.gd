tool
extends WindowDialog


onready var text_edit = $VBoxContainer/MarginContainer/TextEdit
onready var cancel_button = $VBoxContainer/HBoxContainer/CancelButton
onready var save_button = $VBoxContainer/HBoxContainer/SaveButton
	
const snippet_config = "res://addons/CodeSnippetPopup/CodeSnippets.cfg"
signal snippets_changed

func _ready() -> void:
	$VBoxContainer/HelpButton.icon = get_icon("Issue", "EditorIcons")


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
	var error = file.open("res://addons/CodeSnippetPopup/CodeSnippets.cfg", File.WRITE)
	if error != OK:
		push_warning("Code Snippet Plugin: Error saving the code_snippets. Error code: %s." % error)
		return
	file.store_string(text_edit.text)
	file.close()
	hide()
	emit_signal("snippets_changed")


func _on_HelpButton_pressed() -> void:
	$Help.popup_centered()

