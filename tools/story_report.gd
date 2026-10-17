extends SceneTree
## Writes the story check (tools/story_check.gd) as a readable report and prints its problems.
## Usage: godot --headless --path . --script res://tools/story_report.gd [-- <output path>]
## The report goes to .tmp/story_report.md unless a path is given. Exits 1 when there is an 错误.
const Content = preload("res://scripts/core/content.gd")
const StoryCheck = preload("res://tools/story_check.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://").path_join(".tmp/story_report.md")
	var content := Content.new()
	if not content.load_data():
		printerr("data failed to load: " + content.error_message)
		quit(1)
		return
	var check := StoryCheck.new()
	check.run(content)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(check.markdown())
	file.close()
	for problem: Dictionary in check.problems:
		print("%s %s：%s" % [problem.level, problem.site, problem.text])
	var errors: int = check.errors().size()
	print("STORY CHECK: %d errors, %d notes -> %s" % [errors, check.problems.size() - errors, path])
	quit(1 if errors > 0 else 0)
