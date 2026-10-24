class_name JourneyLoadout
extends RefCounted

signal changed
var items: Dictionary = {}
var slots: Dictionary = {}

func acquire(identifier: String, kind: String) -> bool:
	if items.has(identifier) or not JourneyCatalog.DEFINITIONS.has(kind):
		return false
	items[identifier] = kind
	changed.emit()
	return true

func equipped_face(identifier: String) -> String:
	for face: String in slots:
		if slots[face].id == identifier:
			return face
	return ""

func install(face: String, identifier: String, direction: String) -> String:
	if not JourneyCatalog.FACES.has(face) or not JourneyCatalog.FACES.has(direction):
		return "接口或朝向无效"
	if not items.has(identifier):
		return "没有这枚零件"
	var kind: String = items[identifier]
	if kind == "wheel" and (face != "bottom" or direction != "bottom"):
		return "轮足连接结构只支持下方接口、朝下安装"
	var previous_face := equipped_face(identifier)
	if not previous_face.is_empty():
		slots.erase(previous_face)
	slots[face] = {"id": identifier, "direction": direction}
	changed.emit()
	return ""

func remove(face: String) -> void:
	if slots.erase(face):
		changed.emit()

func kind_at(face: String) -> String:
	return str(items.get(slots.get(face, {}).get("id", ""), ""))

func direction_at(face: String) -> String:
	return str(slots.get(face, {}).get("direction", face))

func snapshot() -> Dictionary:
	return {"items": items.duplicate(true), "slots": slots.duplicate(true)}

func restore(data: Dictionary) -> bool:
	var candidate_items: Variant = data.get("items", {})
	var candidate_slots: Variant = data.get("slots", {})
	if not candidate_items is Dictionary or not candidate_slots is Dictionary:
		return false
	var used: Dictionary = {}
	for identifier: Variant in candidate_items:
		if not identifier is String or not JourneyCatalog.DEFINITIONS.has(candidate_items[identifier]):
			return false
	for face: Variant in candidate_slots:
		var entry: Variant = candidate_slots[face]
		if not JourneyCatalog.FACES.has(face) or not entry is Dictionary:
			return false
		var identifier: String = str(entry.get("id", ""))
		var direction: String = str(entry.get("direction", ""))
		if not candidate_items.has(identifier) or used.has(identifier) or not JourneyCatalog.FACES.has(direction):
			return false
		if candidate_items[identifier] == "wheel" and (face != "bottom" or direction != "bottom"):
			return false
		used[identifier] = true
	items = candidate_items.duplicate(true)
	slots = candidate_slots.duplicate(true)
	changed.emit()
	return true
