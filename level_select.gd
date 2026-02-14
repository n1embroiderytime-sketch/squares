extends Control

@export var all_levels: Array[Resource] = []

@onready var grid_classic = $MainMargin/LayoutList/SectionClassic/ContainerClassic/LevelRow
@onready var grid_endless = $MainMargin/LayoutList/SectionEndless/ContainerEndless/LevelRow
@onready var mirror_row = $MainMargin/LayoutList/SectionMirror/ContainerMirror/LevelRow

func _ready():
	_clear_container(grid_classic)
	_clear_container(grid_endless)
	_clear_container(mirror_row)

	setup_endless_mode()
	setup_classic_mode()
	setup_mirror_mode()

	var btn_back = find_child("BtnBack", true, false)
	if btn_back and not btn_back.is_connected("pressed", _on_back_pressed):
		btn_back.pressed.connect(_on_back_pressed)

func setup_endless_mode():
	var btn_endless = preload("res://LevelButton.gd").new()
	grid_endless.add_child(btn_endless)

	var endless_data_path = "res://Gamemodes/Endless/Level00.tres"
	if not ResourceLoader.exists(endless_data_path):
		endless_data_path = "res://Gamemodes/Endless/Level999.tres"
	var endless_data = load(endless_data_path)

	var save_id = 999
	var display_id = 0
	btn_endless.setup(display_id, endless_data, false, 0, true, Global.endless_high_score)

	btn_endless.pressed.connect(func():
		Global.selected_level = save_id
		get_tree().change_scene_to_file("res://endless_game.tscn")
	)
	btn_endless.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_endless.custom_minimum_size = Vector2(0, 180)

func setup_classic_mode():
	for i in range(Global.game_levels.size()):
		var data = Global.game_levels[i]
		var is_locked = i > Global.highest_level_reached
		var stars = Global.level_stars.get(i, 0)

		var btn = preload("res://LevelButton.gd").new()
		grid_classic.add_child(btn)
		btn.setup(i + 1, data, is_locked, stars)

		if not is_locked:
			var lvl_idx = i
			btn.pressed.connect(func(): _on_level_pressed(lvl_idx))

func setup_mirror_mode():
	var mirror_container = $MainMargin/LayoutList/SectionMirror
	mirror_container.modulate = Color(1, 1, 1, 0.5)

	var label = Label.new()
	label.text = "COMING SOON"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	mirror_row.add_child(label)

func _clear_container(container):
	for child in container.get_children():
		child.queue_free()

func _on_level_pressed(lvl_idx):
	Global.selected_level = lvl_idx
	get_tree().change_scene_to_file("res://main_game.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://MainMenu.tscn")
