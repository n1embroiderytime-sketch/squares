extends Control

# --- CONFIGURATION ---
const AUTO_SMASH_TIME = 3.0 # Seconds to wait before auto-smashing
const DEBRIS_COUNT = 40
const EXPLOSION_POWER = 800.0

var debris_colors = [Color("00ffff"), Color("00ff00"), Color("ffcc00"), Color("ff00ff")]
var has_smashed = false # Flag to prevent double-smashing

@onready var logo_label = $LogoContainer
@onready var debris_container = $DebrisContainer
@onready var sfx_smash = $SfxSmash

func _ready():
	if sfx_smash:
		sfx_smash.volume_db = Global.get_sfx_db()
	# Start the safety timer (Auto-smash if user does nothing)
	get_tree().create_timer(AUTO_SMASH_TIME).timeout.connect(_on_timeout)

func _input(event):
	# If player clicks/touches anywhere, SMASH!
	if not has_smashed and (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		smash_logo()

func _on_timeout():
	if not has_smashed:
		smash_logo()

func smash_logo():
	has_smashed = true
	
	if sfx_smash.stream: sfx_smash.play()
	
	logo_label.visible = false
	var center_pos = logo_label.position + (logo_label.size / 2)
	
	for i in range(DEBRIS_COUNT):
		spawn_shard(center_pos)
		
	# Wait for debris to fall, then load menu
	await get_tree().create_timer(1.5).timeout
	transition_to_menu()

func spawn_shard(origin):
	var rb = RigidBody2D.new()
	var vis = ColorRect.new()
	var size = randf_range(10, 25)
	
	vis.size = Vector2(size, size)
	vis.color = debris_colors.pick_random()
	vis.position = Vector2(-size/2, -size/2)
	
	rb.add_child(vis)
	
	var offset_x = randf_range(-150, 150)
	var offset_y = randf_range(-50, 50)
	rb.position = origin + Vector2(offset_x, offset_y)
	
	rb.gravity_scale = randf_range(2.0, 5.0) 
	var impulse = Vector2(randf_range(-1, 1), randf_range(-1, 0.5)).normalized() * EXPLOSION_POWER
	rb.linear_velocity = impulse
	rb.angular_velocity = randf_range(-10, 10)
	
	debris_container.add_child(rb)

var is_switching = false # Add this flag at the top of the script if you want, or just rely on the tree check

func transition_to_menu():
	# 1. Safety Check: Are we still part of the game world?
	if not is_inside_tree(): 
		return
	
	# 2. Prevent double-triggering
	if is_switching: 
		return
	is_switching = true
	
	# 3. GO!
	get_tree().change_scene_to_file("res://MainMenu.tscn")
