extends Node
## Platform-independent save storage (user:// maps to app-private storage on
## Android and iOS). Writes are crash-safe: data goes to a temp file first,
## the previous save is kept as a backup and used if the main file is damaged.

const SAVE_FILE := "save.json"
const TMP_FILE := "save.tmp"
const BAK_FILE := "save.bak"
const VERSION := 1


func load_data() -> Dictionary:
	for file_name in [SAVE_FILE, BAK_FILE]:
		var d := _read("user://" + file_name)
		if not d.is_empty():
			return d
	return {}


func save_data(data: Dictionary) -> bool:
	var payload := JSON.stringify({"version": VERSION, "data": data})
	var f := FileAccess.open("user://" + TMP_FILE, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: cannot open temp file (error %d)" % FileAccess.get_open_error())
		return false
	f.store_string(payload)
	f.flush()
	f.close()

	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if dir.file_exists(SAVE_FILE):
		dir.copy(SAVE_FILE, BAK_FILE)
		dir.remove(SAVE_FILE)
	var err := dir.rename(TMP_FILE, SAVE_FILE)
	if err != OK:
		push_warning("SaveSystem: rename failed (error %d)" % err)
		return false
	return true


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int(parsed.get("version", 0)) > VERSION:
		return {}
	var data = parsed.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data
