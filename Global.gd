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
var endless_has_saved_run = false
var endless_run_state = {}

# Audio settings
var music_volume = 0.8
var sfx_volume = 0.8
var settings_return_scene = "res://MainMenu.tscn"

const SAVE_PATH = "user://lookmom_save.json"

func _ready():
	load_game()
	call_deferred("apply_audio_settings")

func save_game():
	var data = {
		"highest_level_reached": highest_level_reached,
		"level_stars": level_stars,
		"endless_high_score": endless_high_score,
		"endless_current_score": endless_current_score,
		"endless_has_saved_run": endless_has_saved_run,
		"endless_run_state": endless_run_state,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume
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
			if "endless_has_saved_run" in data:
				endless_has_saved_run = bool(data["endless_has_saved_run"])
			if "endless_run_state" in data and data["endless_run_state"] is Dictionary:
				endless_run_state = data["endless_run_state"].duplicate(true)
			if "music_volume" in data:
				music_volume = clamp(float(data["music_volume"]), 0.0, 1.0)
			if "sfx_volume" in data:
				sfx_volume = clamp(float(data["sfx_volume"]), 0.0, 1.0)


func volume_to_db(linear_volume):
	if linear_volume <= 0.0001:
		return -80.0
	return linear_to_db(linear_volume)

func get_music_db():
	return volume_to_db(music_volume)

func get_sfx_db():
	return volume_to_db(sfx_volume)

func apply_audio_settings():
	var music_player = get_node_or_null("/root/MusicManager/AudioStreamPlayer")
	if music_player:
		music_player.volume_db = get_music_db()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_game()
