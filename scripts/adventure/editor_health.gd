@tool
extends RefCounted

static func snapshot(tree: SceneTree) -> Dictionary:
	var windows: Array[Dictionary] = []
	var queue: Array[Node] = [tree.root]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is Window and node.visible and node != tree.root:
			var texts: Array[String] = []
			var children: Array[Node] = [node]
			while not children.is_empty():
				var child: Node = children.pop_front()
				if child is Label or child is Button or child is LineEdit:
					texts.append(str(child.text))
				children.append_array(child.get_children(true))
			windows.append({"path": str(node.get_path()), "title": node.title, "exclusive": node.exclusive, "texts": texts})
		queue.append_array(node.get_children(true))
	var settings := EditorInterface.get_editor_settings()
	var blender_path: String = str(settings.get_setting("filesystem/import/blender/blender_path"))
	return {"checked_at_unix": Time.get_unix_time_from_system(), "editor_pid": OS.get_process_id(), "project_path": ProjectSettings.globalize_path("res://"), "visible_windows": windows, "blocking_window_count": windows.size(), "blender_path": blender_path, "blender_executable_exists": FileAccess.file_exists(blender_path), "scanning": EditorInterface.get_resource_filesystem().is_scanning()}
