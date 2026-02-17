extends Control

@onready var slider_music = $MainMargin/VBox/Panel/VBoxContent/MusicRow/SliderMusic
@onready var slider_sfx = $MainMargin/VBox/Panel/VBoxContent/SfxRow/SliderSfx
@onready var value_music = $MainMargin/VBox/Panel/VBoxContent/MusicRow/ValueMusic
@onready var value_sfx = $MainMargin/VBox/Panel/VBoxContent/SfxRow/ValueSfx
@onready var btn_back = $MainMargin/VBox/BtnBack

func _ready():
	slider_music.value = Global.music_volume
	slider_sfx.value = Global.sfx_volume
	_update_labels()

	slider_music.value_changed.connect(_on_music_changed)
	slider_sfx.value_changed.connect(_on_sfx_changed)
	btn_back.pressed.connect(_on_back_pressed)

func _on_music_changed(v):
	Global.music_volume = clamp(float(v), 0.0, 1.0)
	Global.apply_audio_settings()
	_update_labels()

func _on_sfx_changed(v):
	Global.sfx_volume = clamp(float(v), 0.0, 1.0)
	_update_labels()

func _update_labels():
	value_music.text = str(int(round(slider_music.value * 100.0))) + "%"
	value_sfx.text = str(int(round(slider_sfx.value * 100.0))) + "%"

func _on_back_pressed():
	Global.save_game()
	var target_scene = Global.settings_return_scene
	if target_scene == "":
		target_scene = "res://MainMenu.tscn"
	get_tree().change_scene_to_file(target_scene)
