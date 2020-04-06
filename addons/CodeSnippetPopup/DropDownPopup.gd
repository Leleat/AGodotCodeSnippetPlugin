tool
extends PopupMenu

signal fill_list
var code_editor : TextEdit
var main : PopupPanel


func _unhandled_key_input(event: InputEventKey) -> void:
	if visible:
		get_tree().set_input_as_handled()


func _on_DropDown_shown(option_string : String) -> void:
	rect_size = Vector2.ZERO
	var options = option_string.split(",")
	for option in options:
		add_item(option)
	yield(get_tree(), "idle_frame")
	var down = InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	Input.parse_input_event(down)


func _on_DropDownPopup_popup_hide() -> void:
	clear()


func _on_DropDownPopup_index_pressed(index: int) -> void:
	var placeholder = get_item_text(index)
	code_editor.insert_text_at_cursor(placeholder)
	hide()
	main._jump_to_and_delete_next_marker(code_editor)
