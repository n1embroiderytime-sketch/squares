extends Control

# --- CONFIGURATION ---
const GRID_SIZE = 40
const FALL_SPEED = 100.0
const SPAWN_RATE = 0.8 

var SHAPES = {
	"I": [[1, 1, 1, 1]],
	"O": [[1, 1], [1, 1]],
	"T": [[0, 1, 0], [1, 1, 1]],
	"L": [[0, 0, 1], [1, 1, 1]],
	"J": [[1, 0, 0], [1, 1, 1]],
	"S": [[0, 1, 1], [1, 1, 0]],
	"Z": [[1, 1, 0], [0, 1, 1]]
}
var SHAPE_KEYS = ["I", "O", "T", "L", "J", "S", "Z"]
var COLORS = [
	Color("bf616a"), Color("a3be8c"), Color("ebcb8b"), Color("81a1c1"), Color("b48ead")
]

var falling_bg_pieces = []
var spawn_timer = 0.0

@onready var logo_container = $MenuContainer/LogoContainer 

func _ready():
	# 1. Connect buttons
	if has_node("MenuContainer/BtnPlay"):
		$MenuContainer/BtnPlay.pressed.connect(func(): go_to_scene("res://LevelSelect.tscn"))
	
	if has_node("MenuContainer/BtnSettings"):
		$MenuContainer/BtnSettings.pressed.connect(func():
			Global.settings_return_scene = "res://MainMenu.tscn"
			go_to_scene("res://settings_menu.tscn")
		)
	
	# 2. Bouncing Title
	if logo_container:
		await get_tree().process_frame
		logo_container.pivot_offset = logo_container.size / 2
		
		var tween = create_tween().set_loops()
		tween.tween_property(logo_container, "scale", Vector2(1.1, 1.1), 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(logo_container, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
		
	# 3. Check Unlocks
	check_unlocks()
	
	# 4. [NEW] FILL THE SCREEN IMMEDIATELY
	# Instead of just 5 pieces, we loop through the entire height of the screen
	var vp_size = get_viewport_rect().size
	
	# Start from -100 (above) and go down to the bottom
	# Step by 80 pixels (approx 2 grid blocks) to avoid total overlapping
	for y_pos in range(-100, vp_size.y, 80):
		# Spawn 2 attempts per row to make it look dense
		spawn_bg_piece(y_pos)
		spawn_bg_piece(y_pos + 20) # Slight offset

func _process(delta):
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_bg_piece() # Spawn new ones at top as normal
		spawn_timer = SPAWN_RATE
	
	var vp_height = get_viewport_rect().size.y
	for i in range(falling_bg_pieces.size() - 1, -1, -1):
		var p = falling_bg_pieces[i]
		p.y += FALL_SPEED * delta
		if p.y > vp_height:
			falling_bg_pieces.remove_at(i)
	queue_redraw()

func spawn_bg_piece(y_override = null):
	var type = SHAPE_KEYS.pick_random()
	var matrix = SHAPES[type]
	var vp_size = get_viewport_rect().size
	
	var attempts = 0
	var safe_spot_found = false
	var final_x = 0.0
	var final_y = -150.0 
	
	if y_override != null:
		final_y = y_override
	
	while attempts < 10 and not safe_spot_found:
		attempts += 1
		# Random X position
		var test_x = randf_range(20, vp_size.x - (GRID_SIZE * 4))
		var overlap_detected = false
		
		# Simple overlap check
		for p in falling_bg_pieces:
			var x_dist = abs(p.x - test_x)
			var y_dist = abs(p.y - final_y)
			if x_dist < (GRID_SIZE * 3.5) and y_dist < (GRID_SIZE * 4.5):
				overlap_detected = true
				break
		
		if not overlap_detected:
			final_x = test_x
			safe_spot_found = true
	
	# If we found a spot (or if we are forcing the screen fill, we might be lenient)
	if safe_spot_found:
		var new_piece = {
			"matrix": matrix,
			"x": final_x, 
			"y": final_y,
			"color": COLORS.pick_random(),
			"opacity": randf_range(0.3, 0.6)
		}
		falling_bg_pieces.append(new_piece)

func _draw():
	var vp_size = get_viewport_rect().size
	var center_y = vp_size.y / 2
	var safe_zone = 250.0 
	
	draw_rect(Rect2(Vector2.ZERO, vp_size), Color("050505"), true)
	
	for p in falling_bg_pieces:
		# Calculate fade based on distance from center (Title area)
		var dist_from_center = abs((p.y + (GRID_SIZE)) - center_y)
		var fade_alpha = clamp((dist_from_center - 100) / safe_zone, 0.0, 1.0)
		var final_alpha = p.opacity * fade_alpha
		
		if final_alpha <= 0.05: continue
		
		var draw_col = p.color
		draw_col.a = final_alpha 
		
		for r in range(p.matrix.size()):
			for c in range(p.matrix[r].size()):
				if p.matrix[r][c] == 1:
					var px = p.x + (c * GRID_SIZE)
					var py = p.y + (r * GRID_SIZE)
					var rect = Rect2(px + 5, py + 5, GRID_SIZE - 10, GRID_SIZE - 10)
					draw_rect(rect, draw_col, false, 4.0)

func check_unlocks():
	var daily_btn = $MenuContainer/BtnDailyC 
	if Global.highest_level_reached >= 5:
		if daily_btn: daily_btn.visible = true
	else:
		if daily_btn: daily_btn.visible = false

func go_to_scene(path):
	get_tree().change_scene_to_file(path)
