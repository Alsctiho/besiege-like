class_name SaveManager
## 机器存档：JSON 写入 user://machines/<slot>.json

const DIR := "user://machines/"


static func save_machine(machine: Machine, slot: String) -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR + slot + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(machine.serialize(), "\t"))
	f.close()
	return OK


static func load_machine(machine: Machine, slot: String) -> Error:
	var path := DIR + slot + ".json"
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return FileAccess.get_open_error()
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return ERR_INVALID_DATA
	machine.deserialize(parsed)
	return OK


static func slot_exists(slot: String) -> bool:
	return FileAccess.file_exists(DIR + slot + ".json")


## 列出所有玩家存档槽名（不含扩展名）
static func list_slots() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			out.append(f.trim_suffix(".json"))
	out.sort()
	return out


static func load_slot_data(slot: String) -> Dictionary:
	var f := FileAccess.open(DIR + slot + ".json", FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
