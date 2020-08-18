tool
extends PopupMenu


var code_editor : TextEdit


func _unhandled_key_input(event: InputEventKey) -> void:
	if visible:
		if event.scancode == KEY_ESCAPE and event.pressed:
			# delete currently selected jump marker
			var tmp = OS.clipboard
			code_editor.cut()
			OS.clipboard = tmp
		
		get_tree().set_input_as_handled()


# called via main script with a signal
func _on_snippet_has_options(options : String, pos : Vector2, text_editor : TextEdit) -> void:
	rect_global_position = pos
	rect_size = Vector2.ZERO
	code_editor = text_editor
	popup()
	
	# fill list with options. Options are in a single string separated by ","s
	for option in options.split(","): 
		add_item(option)
	
	# focus first item in the options list
	yield(get_tree(), "idle_frame")
	var down = InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	Input.parse_input_event(down)


func _on_OptionPopup_index_pressed(index: int) -> void:
	var text = get_item_text(index)
	code_editor.insert_text_at_cursor(text)
	owner._jump_to_next_marker(code_editor)
	hide()


func _on_OptionPopup_popup_hide() -> void:
	clear()

