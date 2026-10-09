extends RefCounted
## Alternating generations keep an earlier save if a write is interrupted.
const Session = preload("res://scripts/core/session.gd")
var directory: String
var generation: int = 0
var last_error: String = ""

func _init(save_directory: String = "user://saves") -> void:
	directory = save_directory

func _candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for slot: int in [0, 1]:
		var path := directory.path_join("journey_%d.json" % slot)
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK:
			continue
		var parsed: Variant = parser.data
		if parsed is Dictionary and (parsed.get("generation") is float or parsed.get("generation") is int) and parsed.get("session") is Dictionary:
			if not is_finite(float(parsed.generation)) or float(parsed.generation) < 0 or float(parsed.generation) > 1000000000 or float(parsed.generation) != floor(float(parsed.generation)):
				continue
			var validator = Session.new()
			if validator.restore(parsed.session):
				candidates.append(parsed)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.generation) > int(b.generation))
	return candidates

func has_save() -> bool:
	return not _candidates().is_empty()

func save_game(session) -> bool:
	last_error = ""
	if session.player.is_empty():
		last_error = "请先创建角色。"
		return false
	var candidates := _candidates()
	if not candidates.is_empty():
		generation = maxi(generation, int(candidates[0].generation))
	var next_generation := generation + 1
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		last_error = "无法创建存档目录（%d）。" % error
		return false
	var file := FileAccess.open(directory.path_join("journey_%d.json" % (next_generation % 2)), FileAccess.WRITE)
	if file == null:
		last_error = "无法写入存档（%d）。" % FileAccess.get_open_error()
		return false
	file.store_string(JSON.stringify({"generation": next_generation, "session": session.snapshot()}, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "存档写入失败（%d）。" % write_error
		return false
	generation = next_generation
	return true

func load_game(session) -> bool:
	last_error = ""
	var candidates := _candidates()
	for candidate: Dictionary in candidates:
		if session.restore(candidate.session):
			generation = int(candidate.generation)
			return true
	last_error = "没有可读取的有效存档。"
	return false
