extends Control

@export var all_levels: Array[Resource] = []
@export var classic_levels_path: String = "res://Gamemodes/Classic"

@onready var grid_classic = $MainMargin/LayoutList/SectionClassic/ContainerClassic/LevelRow
@onready var grid_endless = $MainMargin/LayoutList/SectionEndless/ContainerEndless/LevelRow
@onready var mirror_row = $MainMargin/LayoutList/SectionMirror/ContainerMirror/LevelRow

func _ready():
	_clear_container(grid_classic)
	_clear_container(grid_endless)
	_clear_container(mirror_row)

	all_levels = load_levels_from_folder(classic_levels_path)
	if all_levels.is_empty():
		all_levels = Global.game_levels.duplicate(true)
	else:
		Global.game_levels = all_levels.duplicate(true)

	setup_endless_mode()
	setup_classic_mode()
	setup_mirror_mode()

	var btn_back = find_child("BtnBack", true, false)
	if btn_back and not btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.connect(_on_back_pressed)

func load_levels_from_folder(path: String) -> Array[Resource]:
	var loaded_levels: Array[Resource] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return loaded_levels

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var files: Array[String] = []
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	files.sort()
	for f in files:
		var full_path = path.path_join(f)
		if ResourceLoader.exists(full_path):
			var level_res = load(full_path)
			if level_res:
				loaded_levels.append(level_res)

	return loaded_levels

func setup_endless_mode():
	var btn_endless = preload("res://LevelButton.gd").new()
	grid_endless.add_child(btn_endless)

	var endless_data_path = "res://Gamemodes/Endless/Level00.tres"
	if not ResourceLoader.exists(endless_data_path):
		endless_data_path = "res://Gamemodes/Endless/Level999.tres"
	var endless_data = load(endless_data_path)

	btn_endless.setup(0, endless_data, false, 0, true, Global.endless_high_score)
	btn_endless.pressed.connect(func():
		Global.selected_level = 999
		get_tree().change_scene_to_file("res://endless_game.tscn")
	)
	btn_endless.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_endless.custom_minimum_size = Vector2(0, 180)

func setup_classic_mode():
	for i in range(all_levels.size()):
		var data = all_levels[i]
		var is_locked = i > Global.highest_level_reached
		var stars = Global.level_stars.get(i, 0)

		var btn = preload("res://LevelButton.gd").new()
		grid_classic.add_child(btn)
		btn.setup(i + 1, data, is_locked, stars)

		if not is_locked:
			var lvl_idx = i
			btn.pressed.connect(func(): _on_level_pressed(lvl_idx))

func setup_mirror_mode():
	var btn_mirror = preload("res://LevelButton.gd").new()
	mirror_row.add_child(btn_mirror)

	var mirror_data = load("res://Gamemodes/Classic/Level001.tres")
	btn_mirror.setup(0, mirror_data, false, 0)
	btn_mirror.pressed.connect(func():
		Global.selected_level = 0
		get_tree().change_scene_to_file("res://mirror_game.tscn")
	)
	btn_mirror.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_mirror.custom_minimum_size = Vector2(0, 180)

func _clear_container(container):
	for child in container.get_children():
		child.queue_free()

func _on_level_pressed(lvl_idx):
	Global.selected_level = lvl_idx
	get_tree().change_scene_to_file("res://main_game.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://MainMenu.tscn")
