tool
extends PopupMenu

signal fill_list
var code_editor : TextEdit

# TODO popup at cursor position

func _on_DropDown_shown(option_string : String) -> void:
	rect_size = Vector2.ZERO
	var options = option_string.split(",")
	for option in options:
		add_item(option)


func _on_DropDownPopup_popup_hide() -> void:
	clear()


func _on_DropDownPopup_index_pressed(index: int) -> void:
	var placeholder = get_item_text(index)
	code_editor.insert_text_at_cursor(placeholder)
	hide()
