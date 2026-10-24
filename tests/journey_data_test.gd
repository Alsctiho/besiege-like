extends SceneTree

var failures := 0

func _initialize() -> void:
	var loadout := JourneyLoadout.new()
	_check(loadout.acquire("one", "rotor"), "acquire")
	_check(not loadout.acquire("one", "rotor"), "duplicate_rejected")
	for face: String in JourneyCatalog.FACES:
		for direction: String in JourneyCatalog.FACES:
			_check(loadout.install(face, "one", direction).is_empty(), "install_" + face + "_" + direction)
			_check(loadout.slots.size() == 1 and loadout.items.size() == 1, "ownership_conserved")
			var axis := JourneyCatalog.orientation(direction) * Vector3.UP
			_check(axis.distance_to(JourneyCatalog.AXES[direction]) < 0.001, "orientation_" + direction)
	var restored := JourneyLoadout.new()
	_check(restored.restore(loadout.snapshot()), "snapshot_restore")
	_check(not restored.restore({"items": {"one": "rotor"}, "slots": {"left": {"id": "one", "direction": "top"}, "right": {"id": "one", "direction": "front"}}}), "duplicate_equip_rejected")
	_check(restored.items.size() == 1 and restored.slots.size() == 1, "invalid_restore_atomic")
	_check(not loadout.install("wrong", "one", "front").is_empty(), "bad_face_rejected")
	_check(not loadout.install("left", "missing", "front").is_empty(), "missing_item_rejected")
	loadout.acquire("two", "drill")
	_check(loadout.install("bottom", "two", "front").is_empty(), "replacement")
	_check(loadout.equipped_face("one").is_empty() and loadout.items.size() == 2, "replaced_item_returns_inventory")
	loadout.remove("bottom")
	_check(loadout.slots.is_empty() and loadout.items.size() == 2, "remove_preserves_items")
	print("JOURNEY_DATA_COMPLETE failures=", failures)
	quit(0 if failures == 0 else 1)

func _check(passed: bool, label: String) -> void:
	if not passed:
		failures += 1
		push_error("JourneyDataTest: " + label)
