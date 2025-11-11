class_name FileUtils
extends Object


static func _as_resource_path(path: String) -> String:
	if path.begins_with("res://"):
		return path
	if path.begins_with("//"):
		return path.replace("//", "res://")
	if path.begins_with("/"):
		return "res:/" + path
	return "res://" + path.trim_prefix("/")


static func find_resources_by_type(dir_path: String, type_name: String) -> Array:
	"""
	Recursively scan the directory at `dir_path` and return an Array of resource paths
	whose resource class (or scene root node class) matches `type_name`.

	- dir_path: path to scan. Can be 'res://...' or relative like 'scenes/gameplay'.
	- type_name: the Resource/Node class name to match (string).

	Returns: Array of matching resource paths (String).
	"""
	var out: Array = []
	
	if dir_path == null or dir_path == "":
		return out

	var path := _as_resource_path(dir_path)
	var dir := DirAccess.open(path)
	if dir == null:
		return out

	dir.include_hidden = false
	# Begin listing
	@warning_ignore("return_value_discarded")
	dir.list_dir_begin()
	var entry := ""
	while true:
		entry = dir.get_next()
		if entry == "":
			break
		if entry == "." or entry == "..":
			continue

		var full := dir.get_current_dir() + "/" + entry
		print(full)
		if dir.current_is_dir():
			# Recurse into subdirectory
			out += find_resources_by_type(full, type_name)
			continue

		# Try to load the resource
		var res := ResourceLoader.load(full)
		if res == null:
			# Not a loadable resource (binary, import, etc.)
			continue

		var matched := false
		var rclass = res.get_script().get_global_name()
		print(rclass)
		if str(rclass) == type_name:
			matched = true
		elif ClassDB.class_exists(type_name):
			# Check inheritance (works for script classes registered via class_name too)
			if ClassDB.is_parent_class(rclass, type_name):
				matched = true

		if matched:
			out.append(ResourceLoader.load(full))

	return out
