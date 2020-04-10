tool


static func get_dock(dclass : String, base_control_vbox : VBoxContainer) -> Node: # dclass : "FileSystemDock" || "ImportDock" || "NodeDock" || "SceneTreeDock" || "InspectorDock"; compares names in case of custom docks
	for tabcontainer in base_control_vbox.get_child(1).get_child(0).get_children(): # LEFT left
		for dock in tabcontainer.get_children():
			if dock.get_class() == dclass or dock.name == dclass:
				return dock
	for tabcontainer in base_control_vbox.get_child(1).get_child(1).get_child(0).get_children(): # LEFT right
		for dock in tabcontainer.get_children():
			if dock.get_class() == dclass or dock.name == dclass:
				return dock
	for tabcontainer in base_control_vbox.get_child(1).get_child(1).get_child(1).get_child(1).get_child(0).get_children(): # RIGHT left
		for dock in tabcontainer.get_children():
			if dock.get_class() == dclass or dock.name == dclass:
				return dock
	for tabcontainer in base_control_vbox.get_child(1).get_child(1).get_child(1).get_child(1).get_child(1).get_children(): # RIGHT right
		for dock in tabcontainer.get_children():
			if dock.get_class() == dclass or dock.name == dclass:
				return dock
	push_warning("Plugin: Error finding %s." % dclass)
	return null


static func get_current_script_texteditor(script_editor : ScriptEditor) -> TextEdit:
	var script_index = 0
	for script in script_editor.get_open_scripts():
		if script == script_editor.get_current_script():
			break
		script_index += 1
	return script_editor.get_child(0).get_child(1).get_child(1).get_child(script_index).get_child(0).get_child(0).get_child(0) as TextEdit 
