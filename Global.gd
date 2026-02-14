extends Node

# --- GAME DATA ---
var game_levels = [
	preload("res://Gamemodes/Classic/Level001.tres"),
	preload("res://Gamemodes/Classic/Level002.tres"),
	preload("res://Gamemodes/Classic/Level010.tres"),
	preload("res://Gamemodes/Classic/Level011.tres"),
	preload("res://Gamemodes/Classic/Level012.tres"),
	preload("res://Gamemodes/Classic/Level013.tres")
]

# --- GAME STATE ---
var highest_level_reached = 0
var selected_level = 0
var level_stars = {}

# Endless progression
var endless_high_score = 0
var endless_current_score = 0

const SAVE_PATH = "user://lookmom_save.json"

func _ready():
	load_game()

func save_game():
	var data = {
		"highest_level_reached": highest_level_reached,
		"level_stars": level_stars,
		"endless_high_score": endless_high_score,
		"endless_current_score": endless_current_score
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var data = json.get_data()
			if "highest_level_reached" in data:
				highest_level_reached = int(data["highest_level_reached"])
			if "level_stars" in data:
				for key in data["level_stars"]:
					level_stars[int(key)] = int(data["level_stars"][key])
			if "endless_high_score" in data:
				endless_high_score = int(data["endless_high_score"])
			if "endless_current_score" in data:
				endless_current_score = int(data["endless_current_score"])
