extends Node

# This creates a list in the Inspector where you can drag multiple songs
@export var playlist: Array[AudioStream] = []

@onready var player = $AudioStreamPlayer
var current_index = 0

func _ready():
	if playlist.is_empty():
		print("Warning: No music in MusicManager playlist!")
		return
	
	# Connect the signal: When the player finishes, call _on_song_finished
	player.finished.connect(_on_song_finished)
	
	# Optional: Shuffle the songs so it's different every time
	playlist.shuffle()
	
	# Start the first song
	if has_node("/root/Global"):
		player.volume_db = Global.get_music_db()
	play_music()

func play_music():
	# Load the current song into the player
	if has_node("/root/Global"):
		player.volume_db = Global.get_music_db()
	player.stream = playlist[current_index]
	player.play()

func _on_song_finished():
	# Move to the next index
	current_index += 1
	
	# If we reached the end of the list, loop back to the start (0)
	if current_index >= playlist.size():
		current_index = 0
		# Optional: Reshuffle when the whole playlist finishes
		# playlist.shuffle()
		
	play_music()
