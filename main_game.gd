extends Node2D

const GridBoardScript = preload("res://GridBoard.gd")
const PieceMoverScript = preload("res://PieceMover.gd")

# ==============================================================================
# [SYSTEM] TUTORIAL VARIABLES
# ==============================================================================
# Tracks if the tutorial is currently running
var tutorial_active = false
# Current state of the tutorial lesson (INACTIVE, WAITING, or SHOWING)
var tutorial_state = "INACTIVE" 
# Which lesson are we on? (0 = Move, 1 = Rotate, 2 = Switch/Core)
var tutorial_piece_count = 0 
# Timer to animate the hand icon
var tutorial_hand_animation_timer = 0.0

# ==============================================================================
# [SYSTEM] CONFIGURATION (DO NOT CHANGE WITHOUT BACKUP)
# ==============================================================================
const GRID_SIZE = 40              # Size of each block in pixels
const GRADIENT_WIDTH = 120        # Visual width of the background glow
const GRADIENT_ALPHA = 0.03       # Transparency of the background glow
const COLOR_GOLD = Color("ffd700") # Gold color code for high scores/prestige

# ==============================================================================
# [SYSTEM] GAMEPLAY SETTINGS
# ==============================================================================
const STAR_THRESHOLD_1 = 0.40     # 40% completion = 2 Stars
const STAR_THRESHOLD_2 = 0.80     # 80% completion = 3 Stars
const LOCK_DELAY_TIME = 0.5       # Time (seconds) before a piece locks in place

# Automatic Grid Calculation (Don't touch these)
var COLS = 0
var ROWS = 0
var CENTER_X = 0
var CENTER_Y = 0
var OFFSET_X = 0.0

# ==============================================================================
# [SYSTEM] EXPORT VARIABLES (Editor Settings)
# ==============================================================================
@export var game_levels: Array[Resource] = [] # Drag & Drop Levels here in Editor
@export var meta_target_level_index: int = -1 
@export var meta_ghost_duration: float = 4.0

# ==============================================================================
# [VISUALS] COLORS & THEMES
# ==============================================================================
const COLOR_BG = Color("101010")        
const COLOR_ACTIVE_PLAYER = Color("ffffff") 
const COLOR_TARGET = Color("4c566a")    
const COLOR_UI_BTN = Color("2e3440")    
const COLOR_UI_BTN_ACTIVE = Color("434c5e")

var THEME_COLORS = [
	Color("bf616a"), Color("a3be8c"), Color("81a1c1")
]

# ==============================================================================
# [SYSTEM] SHAPE DEFINITIONS (Tetrominoes)
# ==============================================================================
var SHAPES = {
	"I": [[1, 1, 1, 1]],
	"O": [[1, 1], [1, 1]],
	"T": [[0, 1, 0], [1, 1, 1]],
	"L": [[0, 0, 1], [1, 1, 1]],
	"J": [[1, 0, 0], [1, 1, 1]],
	"S": [[0, 1, 1], [1, 1, 0]], 
	"Z": [[1, 1, 0], [0, 1, 1]]
}

const PIECE_QUEUE_SIZE = 3

# ==============================================================================
# [VISUALS] VFX VARIABLES
# ==============================================================================
var drop_trail_rect = Rect2()    # The rectangle for the hard drop trail
var drop_trail_alpha = 0.0       # Opacity of the trail
var last_placed_coords = []      # Where did we just place blocks? (For flash effect)
var placement_flash_alpha = 0.0  # Opacity of the placement flash

# JUICINESS VARIABLES (New Effects)
var portal_particles = null
var spawn_burst_particles = null
var score_pulse_scale = 1.0      # Scale of the score text (starts at 1.0)
var score_color_mod = Color.WHITE
var visual_score = 0.0           # The score number that rolls up smoothly
const FONT_PATH = "res://Fonts/Kenney Mini Square Mono.ttf"
var custom_font = null

# ==============================================================================
# [SYSTEM] GAME STATE (Core Logic)
# ==============================================================================
var cluster = []                 # Array storing all placed blocks
var falling_piece = null         # The currently moving piece
var is_hard_dropping = false     # Are we currently hard dropping?
var level_theme_color = Color.WHITE 
var level_index = 0
var sequence_index = 0
var control_mode = "PIECE"       # Can be "PIECE" or "CORE"
var shake_intensity = 0.0        # How much the screen is shaking
var current_level_targets = []   # Where the gray target blocks are

# Speed & Pause
var current_fall_speed = 2.0     # How fast pieces fall
var is_game_paused = false       # Is the pause menu open?

# Scoring
var score = 0
var stars_earned = 0
var show_results_screen = false
var result_state = ""            # "WIN" or "LOSE"
var consecutive_failures = 0 
var lives = 3 

# Hint System
var hint_active = false
var hint_target_x = 0
var hint_target_matrix = [] 
var hint_ghost_coords = []
var piece_queue = []
var piece_bag = []
var next_piece_baseline_score = -9999

# Visual State
var flash_intensity = 0.0
var flash_color = Color.WHITE
var level_completed = false
var visual_core_rotation = 0.0   # Current rotation angle (for smooth animation)
var meta_ghost_opacity = 0.0

var grid_board = null
var piece_mover = null

# ==============================================================================
# [SYSTEM] INPUT VARIABLES
# ==============================================================================
var touch_start_pos = Vector2.ZERO
var touch_start_time = 0
var drag_accumulator_x = 0.0 
var is_dragging = false
var core_touch_zone = Rect2() 
var lock_timer = 0.0 

# Audio Node
var sfx_connect = null

# UI Button Areas (Calculated in _draw)
var btn_pause_rect = Rect2() 
var btn_next_rect = Rect2() 
var btn_retry_rect = Rect2() 
var btn_skip_rect = Rect2()

# Pause Menu Buttons
var btn_p_resume = Rect2()
var btn_p_levels = Rect2()
var btn_p_settings = Rect2()

# ==============================================================================
# GODOT LIFECYCLE FUNCTIONS
# ==============================================================================
func _ready():
	var vp_size = get_viewport_rect().size
	COLS = floor(vp_size.x / GRID_SIZE)
	ROWS = floor(vp_size.y / GRID_SIZE)
	CENTER_X = floor(COLS / 2)
	CENTER_Y = floor(ROWS * 0.65)
	OFFSET_X = (vp_size.x - (COLS * GRID_SIZE)) / 2
	sfx_connect = $SfxConnect

	grid_board = GridBoardScript.new()
	add_child(grid_board)
	grid_board.configure(COLS, ROWS, CENTER_X, CENTER_Y)
	piece_mover = PieceMoverScript.new()
	add_child(piece_mover)

	# Load font if it exists
	if ResourceLoader.exists(FONT_PATH):
		custom_font = load(FONT_PATH)
		
	# Initialize Particle System
	spawn_portal_particles()

	# Load the first level
	if game_levels.is_empty(): return
	if Global.selected_level < game_levels.size():
		init_level(Global.selected_level)
	else:
		init_level(0)

func _process(delta):
	# Tell Godot to redraw the screen every frame
	queue_redraw()
	
	# Apply Screen Shake (decay over time)
	if shake_intensity > 0:
		shake_intensity = lerp(shake_intensity, 0.0, 0.1)
		if shake_intensity < 0.5: shake_intensity = 0
		position = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
	else:
		position = Vector2.ZERO
		
	# Decay Flash Effects
	if flash_intensity > 0: flash_intensity = lerp(flash_intensity, 0.0, 0.1)
	if meta_ghost_opacity > 0: meta_ghost_opacity -= delta * 1.0
	if drop_trail_alpha > 0: drop_trail_alpha = lerp(drop_trail_alpha, 0.0, 10.0 * delta)
	if placement_flash_alpha > 0: placement_flash_alpha = lerp(placement_flash_alpha, 0.0, 5.0 * delta)

	# Smooth Score Rolling (Visual only)
	if abs(visual_score - score) > 0.1:
		visual_score = lerp(visual_score, float(score), 10.0 * delta)
	else:
		visual_score = float(score)

	# --- PAUSE CHECK ---
	if is_game_paused: return

	# --- TUTORIAL LOGIC (UPDATED) ---
	if tutorial_active:
		# Update animation timer (Slow speed: 0.8)
		tutorial_hand_animation_timer += delta * 0.8
		
		# If we are already showing the prompt, stop here (PAUSE GRAVITY)
		if tutorial_state == "SHOWING_PROMPT":
			return 
			
		# If we are waiting for the piece to become visible/fall
		if tutorial_state == "WAITING_FOR_VIEW":
			if falling_piece != null:
				# Step 1 (Move): Wait until visible at top (y >= 0)
				# Step 2 & 3 (Rotate/Switch): Wait until piece falls 2 rows (y >= 2)
				var trigger_y = 0.0
				if tutorial_piece_count > 0:
					trigger_y = 2.0
				
				if falling_piece.y >= trigger_y:
					tutorial_state = "SHOWING_PROMPT"
					tutorial_hand_animation_timer = 0.0 # Reset animation

	# --- GRAVITY LOGIC ---
	# Move piece down if it exists and we aren't hard dropping
	if falling_piece != null and not is_hard_dropping and not show_results_screen:
		var colliding = piece_mover.gravity_step(delta, current_fall_speed, grid_board)
		lock_timer = piece_mover.lock_timer
		falling_piece = piece_mover.falling_piece
		if colliding and piece_mover.should_lock(LOCK_DELAY_TIME):
			falling_piece.y = round(falling_piece.y)
			land_piece()

# ==============================================================================
# INPUT HANDLING
# ==============================================================================
func _input(event):
	if is_hard_dropping: return 
	
	# 1. HANDLE PAUSE MENU CLICKS
	if is_game_paused:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if btn_p_resume.has_point(event.position):
				toggle_pause()
			elif btn_p_levels.has_point(event.position):
				get_tree().change_scene_to_file("res://level_select.tscn")
			elif btn_p_settings.has_point(event.position):
				print("Settings Clicked") # Placeholder
		return

	# 2. HANDLE RESULTS SCREEN CLICKS
	if show_results_screen:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if btn_next_rect.has_point(event.position) and result_state == "WIN":
				init_level(level_index + 1)
			elif btn_retry_rect.has_point(event.position):
				init_level(level_index)
			elif btn_skip_rect.has_point(event.position) and result_state == "LOSE":
				consecutive_failures = 0
				init_level(level_index + 1)
		return

	# 3. KEYBOARD INPUTS (For Testing/Desktop)
	if event is InputEventKey and event.pressed:
		if event.is_action("ui_left"): handle_move(-1)
		if event.is_action("ui_right"): handle_move(1)
		if event.is_action("ui_up"): handle_rotate(1)
		if event.keycode == KEY_SPACE: switch_control()
		if event.is_action("ui_down"): hard_drop(); get_viewport().set_input_as_handled()
		if event.keycode == KEY_ESCAPE: toggle_pause()

	# 4. TOUCH INPUTS
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start_pos = event.position
			touch_start_time = Time.get_ticks_msec()
			is_dragging = false
			drag_accumulator_x = 0.0
			
			# Check if Pause Button was clicked
			if btn_pause_rect.has_point(event.position):
				toggle_pause()
				return
		else:
			# Touch Released
			var duration = Time.get_ticks_msec() - touch_start_time
			var drag_vector = event.position - touch_start_pos
			var dist = drag_vector.length()
			
			# Swipe Down -> Hard Drop
			if dist > 50 and abs(drag_vector.y) > abs(drag_vector.x):
				hard_drop()
				is_dragging = false
				return

			# Quick Tap -> Rotate or Switch
			if duration < 200 and dist < 20:
				var screen_w = get_viewport_rect().size.x
				var tap_x = event.position.x
				if tap_x < (screen_w * 0.33): handle_rotate(-1) # Tap Left
				elif tap_x > (screen_w * 0.66): handle_rotate(1) # Tap Right
				else: switch_control() # Tap Center
				is_dragging = false
				return
			is_dragging = false

	# 5. DRAG INPUTS
	if event is InputEventScreenDrag:
		is_dragging = true
		if control_mode == "PIECE":
			drag_accumulator_x += event.relative.x
			var threshold = GRID_SIZE * 1.1 
			# If dragged enough pixels, move the piece
			if abs(drag_accumulator_x) > threshold:
				var direction = sign(drag_accumulator_x)
				handle_move(int(direction))
				drag_accumulator_x -= (direction * threshold)

func toggle_pause():
	is_game_paused = !is_game_paused

# ==============================================================================
# ACTION LOGIC (Movement, Rotation)
# ==============================================================================
func handle_move(dir):
	if control_mode == "CORE": return 
	if falling_piece == null: return
	
	# [TUTORIAL] Unlock if player follows "Move" instruction
	if tutorial_active and tutorial_state == "SHOWING_PROMPT" and tutorial_piece_count == 0:
		tutorial_state = "INACTIVE" # Resume gravity
	
	if piece_mover.move_horizontal(dir, grid_board):
		falling_piece = piece_mover.falling_piece
		lock_timer = piece_mover.lock_timer

func handle_rotate(dir):
	# [TUTORIAL] Unlock if player follows "Rotate" instruction
	if tutorial_active and tutorial_state == "SHOWING_PROMPT" and tutorial_piece_count == 1:
		tutorial_state = "INACTIVE"
		
	# [TUTORIAL] Unlock if player rotates CORE (Step 3)
	if tutorial_active and tutorial_state == "SHOWING_PROMPT" and tutorial_piece_count == 2:
		if control_mode == "CORE":
			tutorial_state = "INACTIVE"
		else:
			return # Block rotation if they haven't switched to Core yet

	if control_mode == "CORE":
		rotate_core(dir)
	else:
		if piece_mover.rotate_piece(dir, grid_board):
			falling_piece = piece_mover.falling_piece
			lock_timer = piece_mover.lock_timer

func switch_control():
	# [TUTORIAL] Handle "Switch" instruction
	if tutorial_active and tutorial_state == "SHOWING_PROMPT" and tutorial_piece_count == 2:
		if control_mode == "PIECE":
			# Allow switching to CORE, but keep prompt active (change text to "Rotate")
			control_mode = "CORE"
			return

	if control_mode == "PIECE":
		control_mode = "CORE"
	else:
		control_mode = "PIECE"

# ==============================================================================
# CORE GAME LOOP
# ==============================================================================
func init_level(idx):
	# Safety check for index
	if idx >= game_levels.size(): idx = 0 
	if idx != level_index: consecutive_failures = 0
		
	# Reset all state variables
	shake_intensity = 0.0
	position = Vector2.ZERO
	level_index = idx
	sequence_index = 0
	lives = 3 
	hint_active = false
	level_completed = false
	show_results_screen = false
	stars_earned = 0
	is_game_paused = false
	
	score = 0
	visual_score = 0.0
	control_mode = "PIECE" 
	
	# Calculate speed based on level difficulty
	current_fall_speed = get_fall_speed_for_level(idx)
	
	# Create the starting Core (4 blocks in center)
	grid_board.reset_core()
	cluster = grid_board.cluster
	meta_ghost_opacity = meta_ghost_duration
	level_theme_color = THEME_COLORS.pick_random()
	
	# Load targets from Level Resource
	var level_data = game_levels[idx]
	grid_board.set_targets_from_level(level_data)
	current_level_targets = grid_board.current_level_targets
	
	# [TUTORIAL CHECK] If Level 0, start tutorial
	if level_index == 0:
		tutorial_active = true
		tutorial_piece_count = 0
		tutorial_state = "WAITING_FOR_VIEW" # Wait until piece is visible
	else:
		tutorial_active = false
		tutorial_state = "INACTIVE"

	reset_piece_pipeline()
	ensure_piece_queue()

	spawn_piece()
	if portal_particles: portal_particles.color = level_theme_color
	trigger_spawn_burst()

# Difficulty Curve Formula
func get_fall_speed_for_level(lvl):
	if lvl < 5:
		return 2.0
	return 2.0 + ((lvl - 5) * 0.2)

func spawn_piece():
	if level_completed or show_results_screen: return

	ensure_piece_queue()
	if piece_queue.is_empty():
		evaluate_end_game() # No moves left? Game Over.
		return

	var next_type = piece_queue.pop_front()
		
	hint_active = false
	piece_mover.spawn_piece(next_type, SHAPES, COLS)
	falling_piece = piece_mover.falling_piece
	lock_timer = piece_mover.lock_timer
	ensure_piece_queue()
	if piece_queue.is_empty():
		next_piece_baseline_score = -9999
	else:
		next_piece_baseline_score = evaluate_piece_potential(SHAPES[piece_queue[0]])
	trigger_spawn_burst()
	
	# [TUTORIAL] Reset tutorial state for the next piece
	if tutorial_active:
		if tutorial_piece_count < 3:
			tutorial_state = "WAITING_FOR_VIEW"
		else:
			tutorial_active = false # End tutorial after 3 lessons

# ==============================================================================
# LOGIC: COLLISION & PLACEMENT
# ==============================================================================
func land_piece():
	if level_completed or show_results_screen: return 
	var gy = round(falling_piece.y)
	
	# 1. Validate placement
	if not grid_board.piece_is_connected(falling_piece.x, gy, falling_piece.matrix): handle_rejection(); return
	if gy < 0: handle_rejection(); return
	if not grid_board.piece_fits_targets(falling_piece.x, gy, falling_piece.matrix): handle_rejection(); return

	# 2. SUCCESS: Place the blocks
	last_placed_coords = grid_board.commit_piece(falling_piece.x, gy, falling_piece.matrix)
	cluster = grid_board.cluster
	
	placement_flash_alpha = 1.0
	var center_x = OFFSET_X + ((falling_piece.x + falling_piece.matrix[0].size()/2.0) * GRID_SIZE)
	var center_y = (falling_piece.y + falling_piece.matrix.size()/2.0) * GRID_SIZE
	spawn_impact_particles(Vector2(center_x, center_y))

	score += 150
	
	# [JUICINESS] Trigger Pulse & Text
	trigger_score_pulse()
	spawn_floating_text(Vector2(center_x, center_y), 150)
	
	if sfx_connect: sfx_connect.play()
	trigger_vfx("SUCCESS")
	falling_piece = null
	piece_mover.falling_piece = null
	sequence_index += 1 
	
	# [TUTORIAL] Advance to next lesson
	if tutorial_active:
		tutorial_piece_count += 1

	adapt_buffer_after_placement()
	check_victory_100_percent() 
	spawn_piece()
	trigger_spawn_burst()

# ==============================================================================
# LOGIC: UTILITIES (Rotation, Collision, AI)
# ==============================================================================
func check_victory_100_percent():
	if level_completed: return
	var percent = calculate_completion_percent()
	if percent >= 1.0: trigger_level_complete(3)

func evaluate_end_game():
	var percent = calculate_completion_percent()
	if percent >= STAR_THRESHOLD_2: trigger_level_complete(3) 
	elif percent >= STAR_THRESHOLD_1: trigger_level_complete(2) 
	elif percent > 0.0: trigger_level_complete(1)
	else: trigger_game_over()

func calculate_completion_percent():
	return grid_board.calculate_completion_percent()

func trigger_level_complete(stars):
	if level_completed: return
	level_completed = true
	stars_earned = stars
	
	if (level_index + 1) > Global.highest_level_reached:
		Global.highest_level_reached = level_index + 1
	var old_stars = Global.level_stars.get(level_index, 0)
	if stars > old_stars:
		Global.level_stars[level_index] = stars
	Global.save_game()

	result_state = "WIN"
	show_results_screen = true
	consecutive_failures = 0 
	trigger_vfx("SUCCESS")

func trigger_game_over():
	result_state = "LOSE"
	show_results_screen = true
	consecutive_failures += 1 
	trigger_vfx("FAIL")

func handle_rejection():
	lives -= 1
	score = max(0, score - 50)
	shake_intensity = 5.0 
	flash_intensity = 0.2 
	flash_color = Color("bf616a") 
	
	if lives <= 0:
		trigger_game_over()
	else:
		falling_piece.y = -4 
		falling_piece.x = floor(COLS / 2) - ceil(falling_piece.matrix[0].size() / 2.0)
		calculate_hint_move() 
		hint_active = true
		lock_timer = 0.0
		piece_mover.reset_lock_timer()

func calculate_hint_move():
	# Simple AI to find a valid spot
	hint_ghost_coords.clear()
	if falling_piece == null: return
	var best_score = -1
	var best_state = {}
	var sim_matrix = falling_piece.matrix
	for r in range(4):
		for x in range(-2, COLS):
			var sim_y = -4.0
			var landed = false
			while true:
				if check_sim_collision(x, sim_y + 1, sim_matrix, cluster): 
					landed = true; break
				sim_y += 1
				if sim_y > ROWS: break
			if landed:
				var gy = round(sim_y)
				if gy >= 0:
					var current_score = 0
					for row in range(sim_matrix.size()):
						for col in range(sim_matrix[row].size()):
							if sim_matrix[row][col] == 1:
								var rel_x = (x + col) - CENTER_X
								var rel_y = (gy + row) - CENTER_Y
								for t in current_level_targets:
									if t.x == rel_x and t.y == rel_y: current_score += 1
					if current_score > best_score:
						best_score = current_score
						best_state = { "x": x, "y": gy, "rot": r, "matrix": sim_matrix }
		sim_matrix = rotate_matrix_data(sim_matrix)

	if best_score > 0:
		hint_target_x = best_state.x
		hint_target_matrix = best_state.matrix
		var m = best_state.matrix
		for r in range(m.size()):
			for c in range(m[r].size()):
				if m[r][c] == 1:
					hint_ghost_coords.append(Vector2(best_state.x + c, best_state.y + r))

# [AI] "SEE THE FUTURE" LOGIC
func reset_piece_pipeline():
	piece_queue.clear()
	piece_bag.clear()
	next_piece_baseline_score = -9999

func refill_piece_bag():
	piece_bag = SHAPES.keys()
	piece_bag.shuffle()

func pick_piece_from_bag(prefer_helpful):
	if piece_bag.is_empty():
		refill_piece_bag()
	if piece_bag.is_empty():
		return ""

	var candidates = piece_bag.duplicate()
	candidates.shuffle()
	var selected = candidates[0]
	var selected_score = evaluate_piece_potential(SHAPES[selected])

	for piece_type in candidates:
		var score = evaluate_piece_potential(SHAPES[piece_type])
		if prefer_helpful:
			if score > selected_score:
				selected = piece_type
				selected_score = score
		else:
			if score < selected_score:
				selected = piece_type
				selected_score = score

	piece_bag.erase(selected)
	return selected

func ensure_piece_queue():
	while piece_queue.size() < PIECE_QUEUE_SIZE:
		var next_piece = pick_piece_from_bag(true)
		if next_piece == "":
			break
		piece_queue.append(next_piece)

func adapt_buffer_after_placement():
	# Piece B is at index 0, Piece C (buffer) is index 1.
	if piece_queue.size() < 2:
		return
	if next_piece_baseline_score <= -9999:
		return

	var next_type = piece_queue[0]
	var current_score = evaluate_piece_potential(SHAPES[next_type])
	var score_drop = next_piece_baseline_score - current_score

	# If Piece A blocked the best line for Piece B, tweak Piece C before it is shown.
	if score_drop >= 8:
		var prefer_helpful = lives <= 2
		var replacement = pick_piece_from_bag(prefer_helpful)
		if replacement != "":
			var previous_buffer = piece_queue[1]
			piece_queue[1] = replacement
			piece_bag.append(previous_buffer)
			piece_bag.shuffle()

func get_smart_piece_type():
	ensure_piece_queue()
	if piece_queue.is_empty():
		return ""
	return piece_queue[0]

func evaluate_piece_potential(matrix):
	# Simulate placing this piece in every possible rotation and position
	# Returns the highest score achievable with this piece
	var max_score = -9999
	var sim_cluster = cluster.duplicate(true)
	var sim_targets = current_level_targets.duplicate(true)
	
	# Test all 4 Core Rotations
	for core_rot in range(4):
		var test_matrix = matrix
		# Test all 4 Piece Rotations
		for piece_rot in range(4):
			# Test all X positions
			for x in range(-3, COLS):
				var score = simulate_placement_score(x, test_matrix, sim_cluster, sim_targets)
				if score > max_score: max_score = score
			
			test_matrix = rotate_matrix_data(test_matrix)
		
		# Rotate Simulation World for next pass
		rotate_simulation_data(sim_cluster, sim_targets)
		
	return max_score

func simulate_placement_score(start_x, matrix, sim_cluster, sim_targets):
	# 1. Drop the piece
	var sim_y = -4.0
	while true:
		if check_sim_collision(start_x, sim_y + 1, matrix, sim_cluster): break
		sim_y += 1
		if sim_y > ROWS: return -9999 # Out of bounds
	
	var gy = round(sim_y)
	if gy < 0: return -9999 # Failed to land on board
	
	# 2. Check Connectivity (Must touch existing block)
	var connected = false
	for r in range(matrix.size()):
		for c in range(matrix[r].size()):
			if matrix[r][c] == 1:
				var ax = start_x + c; var ay = gy + r
				if check_sim_occupied(ax+1, ay, sim_cluster) or \
				   check_sim_occupied(ax-1, ay, sim_cluster) or \
				   check_sim_occupied(ax, ay+1, sim_cluster) or \
				   check_sim_occupied(ax, ay-1, sim_cluster): connected = true
	if not connected: return -9999
	
	# 3. Calculate Score
	var current_score = 0
	for r in range(matrix.size()):
		for c in range(matrix[r].size()):
			if matrix[r][c] == 1:
				var rel_x = (start_x + c) - CENTER_X
				var rel_y = (gy + r) - CENTER_Y
				
				# Bonus: Hits a Target
				var hits_target = false
				for t in sim_targets:
					if t.x == rel_x and t.y == rel_y:
						hits_target = true
						break
				
				if hits_target:
					current_score += 10 # Good!
				else:
					current_score -= 2 # Bad (Wasted space)
				
	return current_score

func can_piece_fit_in_multiverse(base_matrix):
	var sim_cluster = cluster.duplicate(true)
	var sim_targets = current_level_targets.duplicate(true)
	for i in range(4):
		if check_piece_against_world(base_matrix, sim_cluster, sim_targets): return true
		rotate_simulation_data(sim_cluster, sim_targets)
	return false

func check_piece_against_world(base_matrix, test_cluster, test_targets):
	var test_matrix = base_matrix
	for r in range(4):
		for x in range(-2, COLS + 1):
			if simulate_drop(x, test_matrix, test_cluster, test_targets): return true
		test_matrix = rotate_matrix_data(test_matrix)
	return false

func rotate_simulation_data(clus, targs):
	grid_board.rotate_simulation_data(clus, targs)

func simulate_drop(start_x, matrix, test_cluster, test_targets):
	var sim_y = -4.0
	while true:
		if check_sim_collision(start_x, sim_y + 1, matrix, test_cluster): break
		sim_y += 1
		if sim_y > ROWS: return false

	var gy = round(sim_y)
	if gy < 0: return false
	
	var connected = false
	for r in range(matrix.size()):
		for c in range(matrix[r].size()):
			if matrix[r][c] == 1:
				var ax = start_x + c; var ay = gy + r
				if check_sim_occupied(ax+1, ay, test_cluster) or \
				   check_sim_occupied(ax-1, ay, test_cluster) or \
				   check_sim_occupied(ax, ay+1, test_cluster) or \
				   check_sim_occupied(ax, ay-1, test_cluster): 
					connected = true
	if not connected: return false

	for r in range(matrix.size()):
		for c in range(matrix[r].size()):
			if matrix[r][c] == 1:
				var rel_x = (start_x + c) - CENTER_X
				var rel_y = (gy + r) - CENTER_Y
				var is_target = false
				for t in test_targets:
					if t.x == rel_x and t.y == rel_y: is_target = true; break
				if not is_target: return false 
	return true

func check_sim_collision(tx, ty, matrix, test_cluster):
	for r in range(matrix.size()):
		for c in range(matrix[r].size()):
			if matrix[r][c] == 1:
				var ax = tx + c
				var ay = ty + r
				if ax < 0 or ax >= COLS: return true
				if floor(ay + 0.9) >= ROWS: return true
				if ay >= 0:
					if check_sim_occupied(ax, floor(ay+0.1), test_cluster) or \
					   check_sim_occupied(ax, floor(ay+0.9), test_cluster): return true
	return false

func check_sim_occupied(x, y, test_cluster):
	for b in test_cluster:
		if CENTER_X + b.x == x and CENTER_Y + b.y == y: return true
	return false

func will_collide(tx, ty, matrix):
	return grid_board.will_collide(tx, ty, matrix)

func is_occupied(x, y):
	return grid_board.is_occupied(x, y)

func rotate_matrix_data(m):
	return piece_mover.rotate_matrix_data(m)

func rotate_piece(dir):
	if falling_piece == null: return
	var m = falling_piece.matrix
	var new_m = rotate_matrix_data(m)
	if dir == -1: 
		new_m = rotate_matrix_data(rotate_matrix_data(rotate_matrix_data(m)))
	if not will_collide(falling_piece.x, falling_piece.y, new_m): falling_piece.matrix = new_m

func rotate_core(dir):
	if level_completed or show_results_screen: return
	if not grid_board.rotate_core(dir): return

	cluster = grid_board.cluster
	current_level_targets = grid_board.current_level_targets

	if hint_active: calculate_hint_move()

	if dir == 1:
		visual_core_rotation = -90.0
	else:
		visual_core_rotation = 90.0
	var tween = create_tween()
	tween.tween_property(self, "visual_core_rotation", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	check_victory_100_percent()

func spawn_impact_particles(pos):
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.amount = 12
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.6
	particles.direction = Vector2(0, -1) 
	particles.spread = 180.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = COLOR_ACTIVE_PLAYER 
	add_child(particles)
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()

func trigger_vfx(type):
	if type == "SUCCESS":
		shake_intensity = 10.0; flash_intensity = 0.3; flash_color = Color.WHITE
	elif type == "FAIL":
		pass

func hard_drop():
	if falling_piece == null or show_results_screen or control_mode == "CORE": return
	if is_hard_dropping: return
	if tutorial_active: return # Disable Hard Drop in Tutorial

	is_hard_dropping = true
	var drop_result = piece_mover.hard_drop(grid_board, OFFSET_X, GRID_SIZE)
	falling_piece = piece_mover.falling_piece

	if drop_result.score_gained > 0:
		score += drop_result.score_gained
		spawn_floating_text(Vector2(OFFSET_X + (falling_piece.x * GRID_SIZE), falling_piece.y * GRID_SIZE), drop_result.score_gained)

	drop_trail_rect = Rect2(drop_result.draw_x, drop_result.start_y, drop_result.matrix_w, drop_result.end_y - drop_result.start_y + drop_result.matrix_h)
	drop_trail_alpha = 0.4

	queue_redraw()
	await get_tree().create_timer(0.15).timeout
	land_piece()
	is_hard_dropping = false

# ==============================================================================
# [VISUALS] PARTICLE GENERATORS
# ==============================================================================
func generate_hollow_texture():
	var size = 64 
	var thickness = 8 
	
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0)) 
	
	var border_col = Color.WHITE
	
	for x in range(size):
		for t in range(thickness):
			img.set_pixel(x, t, border_col)
			img.set_pixel(x, size - 1 - t, border_col)
			
	for y in range(size):
		for t in range(thickness):
			img.set_pixel(t, y, border_col)
			img.set_pixel(size - 1 - t, y, border_col)
		
	return ImageTexture.create_from_image(img)

func spawn_portal_particles():
	if portal_particles != null: return
	
	var vp_size = get_viewport_rect().size
	var texture = generate_hollow_texture()
	
	# 1. AMBIENT RAIN (Subtle Background)
	portal_particles = CPUParticles2D.new()
	portal_particles.position = Vector2(vp_size.x / 2.0, -20) 
	portal_particles.amount = 35 # Reduced count
	portal_particles.lifetime = 0.75
	portal_particles.texture = texture
	
	portal_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	portal_particles.emission_rect_extents = Vector2(vp_size.x / 2.0, 10)
	
	portal_particles.gravity = Vector2(0, 60) 
	# Smaller scale: 0.3 * 64px = ~19px squares
	portal_particles.scale_amount_min = 0.1 
	portal_particles.scale_amount_max = 0.3
	portal_particles.color = level_theme_color 
	portal_particles.color.a = 0.3 
	add_child(portal_particles)

func trigger_spawn_burst():
	if spawn_burst_particles:
		spawn_burst_particles.restart()
		spawn_burst_particles.emitting = true

# ==============================================================================
# [VISUALS] WARP GRID (Space Bending Effect)
# ==============================================================================
func draw_local_warp_grid(vp_size, center_x):
	var gravity_points = []
	# 1. Collect gravity points (Active piece or Core)
	if control_mode == "PIECE" and falling_piece != null:
		for r in range(falling_piece.matrix.size()):
			for c in range(falling_piece.matrix[r].size()):
				if falling_piece.matrix[r][c] == 1:
					var relative_grid_x = (falling_piece.x + c) - CENTER_X
					var gx = center_x + (relative_grid_x * GRID_SIZE) + (GRID_SIZE / 2.0)
					var gy = ((falling_piece.y + r) * GRID_SIZE) + (GRID_SIZE / 2.0)
					gravity_points.append(Vector2(gx, gy))
	elif control_mode == "CORE":
		for b in cluster:
			var gx = center_x + (b.x * GRID_SIZE) + (GRID_SIZE / 2.0)
			var gy = (CENTER_Y * GRID_SIZE) + (b.y * GRID_SIZE) + (GRID_SIZE / 2.0)
			gravity_points.append(Vector2(gx, gy))

	if gravity_points.is_empty(): return 

	var active_radius = 100.0 
	var screen_w = vp_size.x
	var screen_h = vp_size.y
	var start_idx = -ceil(center_x / GRID_SIZE)
	var end_idx = ceil((screen_w - center_x) / GRID_SIZE)
	
	# Draw Vertical warped lines
	for i in range(start_idx, end_idx + 1):
		var base_x = center_x + (i * GRID_SIZE)
		var points = PackedVector2Array()
		var colors = PackedColorArray()
		for y in range(0, int(screen_h), 4):
			var pt = Vector2(base_x, y)
			var warped_result = get_nearest_warp(pt, gravity_points, active_radius)
			if warped_result.alpha > 0.0:
				points.append(warped_result.pos)
				colors.append(Color(1, 1, 1, warped_result.alpha * 0.15)) 
		if points.size() > 1:
			draw_polyline_colors(points, colors, 1.0)

	# Draw Horizontal warped lines
	for y in range(0, int(screen_h), int(GRID_SIZE)):
		var points = PackedVector2Array()
		var colors = PackedColorArray()
		for x in range(0, int(screen_w), 4):
			var pt = Vector2(x, y)
			var warped_result = get_nearest_warp(pt, gravity_points, active_radius)
			if warped_result.alpha > 0.0:
				points.append(warped_result.pos)
				colors.append(Color(1, 1, 1, warped_result.alpha * 0.15))
		if points.size() > 1:
			draw_polyline_colors(points, colors, 1.0)

func get_nearest_warp(pt, gravity_points, radius):
	var closest_dist = 99999.0
	var closest_point = Vector2.ZERO
	for gp in gravity_points:
		var d = pt.distance_to(gp)
		if d < closest_dist:
			closest_dist = d
			closest_point = gp
	if closest_dist < 30.0: return { "pos": pt, "alpha": 0.0 }
	if closest_dist < radius:
		var diff = pt - closest_point
		var strength = 12.0
		var t = closest_dist / radius
		var influence = sin((1.0 - t) * PI / 2.0)
		var warped_pos = pt - (diff.normalized() * influence * strength)
		var alpha = influence
		return { "pos": warped_pos, "alpha": alpha }
	else: return { "pos": pt, "alpha": 0.0 }

# ==============================================================================
# [VISUALS] JUICINESS HELPERS (Tweening)
# ==============================================================================
func trigger_score_pulse():
	var t = create_tween()
	# Scale up to 1.8x (Bigger pop!)
	score_pulse_scale = 1.8 
	score_color_mod = COLOR_GOLD
	t.set_parallel(true)
	t.tween_property(self, "score_pulse_scale", 1.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "score_color_mod", Color.WHITE, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func spawn_floating_text(pos, value):
	var label = Label.new()
	label.text = "+" + str(value)
	if custom_font: label.add_theme_font_override("font", custom_font)
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = COLOR_GOLD
	label.position = pos
	label.z_index = 100 
	add_child(label)
	
	var t = create_tween()
	t.set_parallel(true)
	# Float up and fade out
	t.tween_property(label, "position:y", pos.y - 80, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(label.queue_free)

# ==============================================================================
# DRAWING (Rendering the Game)
# ==============================================================================
func _draw():
	var vp_size = get_viewport_rect().size
	# 1. Background
	draw_rect(Rect2(0, 0, vp_size.x, vp_size.y), COLOR_BG, true)
	
	var piece_draw_color = COLOR_ACTIVE_PLAYER if control_mode == "PIECE" else level_theme_color
	var core_draw_color = level_theme_color if control_mode == "PIECE" else COLOR_ACTIVE_PLAYER
	var glow_color = COLOR_ACTIVE_PLAYER
	
	# 2. Grid Distortion Effect
	var center_pixel_x = OFFSET_X + (CENTER_X * GRID_SIZE)
	var center_pixel_y = CENTER_Y * GRID_SIZE
	draw_local_warp_grid(vp_size, center_pixel_x)
	
	draw_gradient_overlay(vp_size, glow_color)
	
	# 3. Hard Drop Trail
	if drop_trail_alpha > 0:
		var trail_col = Color(COLOR_ACTIVE_PLAYER.r, COLOR_ACTIVE_PLAYER.g, COLOR_ACTIVE_PLAYER.b, drop_trail_alpha)
		draw_rect(drop_trail_rect, trail_col, true)
	
	# 4. Draw Core
	core_touch_zone = Rect2(center_pixel_x - (1.5 * GRID_SIZE), center_pixel_y - (1.5 * GRID_SIZE), 3 * GRID_SIZE, 3 * GRID_SIZE)
	draw_set_transform(Vector2(center_pixel_x, center_pixel_y), deg_to_rad(visual_core_rotation), Vector2(1,1))
	
	# Targets
	for t in current_level_targets:
		var is_filled = false
		for b in cluster:
			if b.x == t.x and b.y == t.y: is_filled = true; break
		if not is_filled:
			var gx = t.x * GRID_SIZE; var gy = t.y * GRID_SIZE
			var offset = 5
			var size = GRID_SIZE - (offset * 2)
			var rect = Rect2(gx + offset, gy + offset, size, size)
			draw_rect(rect, COLOR_TARGET, false, 4.0) 
			draw_rect(rect, Color(COLOR_TARGET.r, COLOR_TARGET.g, COLOR_TARGET.b, 0.1), true)
	
	# Placed Blocks
	for b in cluster:
		var x = b.x * GRID_SIZE
		var y = b.y * GRID_SIZE
		draw_tech_block(x, y, core_draw_color, control_mode == "CORE")
		
	draw_set_transform(Vector2(0,0), 0, Vector2(1,1))
	
	# 5. Draw Hint Ghost
	if hint_active and not hint_ghost_coords.is_empty():
		var dynamic_ghost_col = level_theme_color.lightened(0.4)
		for coord in hint_ghost_coords:
			var draw_x = OFFSET_X + (coord.x * GRID_SIZE)
			var draw_y = coord.y * GRID_SIZE
			draw_rect(Rect2(draw_x, draw_y, GRID_SIZE, GRID_SIZE), Color(dynamic_ghost_col.r, dynamic_ghost_col.g, dynamic_ghost_col.b, 0.3), true)
			draw_rect(Rect2(draw_x, draw_y, GRID_SIZE, GRID_SIZE), dynamic_ghost_col, false, 2.0)

	# 6. Draw Falling Piece
	if falling_piece != null:
		var py = falling_piece.y; var px = falling_piece.x
		for r in range(falling_piece.matrix.size()):
			for c in range(falling_piece.matrix[r].size()):
				if falling_piece.matrix[r][c] == 1:
					var draw_x = OFFSET_X + ((px + c) * GRID_SIZE)
					var draw_y = (py + r) * GRID_SIZE
					draw_tech_block(draw_x, draw_y, piece_draw_color, control_mode == "PIECE")

	# 7. Placement Flash
	if placement_flash_alpha > 0:
		for coord in last_placed_coords:
			var draw_x = OFFSET_X + (coord.x * GRID_SIZE)
			var draw_y = coord.y * GRID_SIZE
			var flash_col = Color(1, 1, 1, placement_flash_alpha)
			draw_rect(Rect2(draw_x, draw_y, GRID_SIZE, GRID_SIZE), flash_col, true)

	draw_top_bar(vp_size)
	
	# 8. Overlays
	if tutorial_active and tutorial_state == "SHOWING_PROMPT":
		draw_tutorial_overlay(vp_size)

	if is_game_paused:
		draw_pause_menu(vp_size)
	
	if flash_intensity > 0:
		draw_rect(Rect2(0, 0, vp_size.x, vp_size.y), Color(flash_color.r, flash_color.g, flash_color.b, flash_intensity), true)
	
	# 9. Results Popup
	if show_results_screen:
		draw_rect(Rect2(0, 0, vp_size.x, vp_size.y), Color(0, 0, 0, 0.8), true)
		var panel_w = 400
		var panel_h = 400
		var panel_rect = Rect2((vp_size.x - panel_w)/2, (vp_size.y - panel_h)/2, panel_w, panel_h)
		draw_rect(panel_rect, Color("2e3440"), true) 
		draw_rect(panel_rect, Color("eceff4"), false, 4.0) 
		
		var title_text = "LEVEL COMPLETE" if result_state == "WIN" else "GAME OVER"
		draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(panel_w/2 - 80, 50), title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)
		draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(panel_w/2 - 60, 90), "SCORE: " + str(score), HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.LIGHT_GRAY)
		
		var star_y = panel_rect.position.y + 130
		var star_start_x = panel_rect.position.x + (panel_w/2) - 60 
		for i in range(1, 4): 
			var star_rect = Rect2(star_start_x + ((i-1)*50), star_y, 40, 40)
			var is_earned = (i <= stars_earned)
			var star_col = Color("ebcb8b") if is_earned else Color(0.2, 0.2, 0.2) 
			draw_rect(star_rect, star_col, true)
			draw_rect(star_rect, Color.WHITE, false, 2.0) 
		
		var pop_btn_w = 200; var pop_btn_h = 50; 
		var pop_btn_x = (vp_size.x - pop_btn_w) / 2
		
		btn_retry_rect = Rect2(pop_btn_x, panel_rect.end.y - 130, pop_btn_w, pop_btn_h)
		draw_rect(btn_retry_rect, Color("bf616a"), true) 
		draw_string(ThemeDB.fallback_font, btn_retry_rect.position + Vector2(80, 32), "RETRY", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)

		if result_state == "WIN":
			btn_next_rect = Rect2(pop_btn_x, panel_rect.end.y - 70, pop_btn_w, pop_btn_h)
			draw_rect(btn_next_rect, Color("a3be8c"), true) 
			draw_string(ThemeDB.fallback_font, btn_next_rect.position + Vector2(80, 32), "NEXT", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color.WHITE)
		
		elif result_state == "LOSE" and consecutive_failures >= 3:
			btn_skip_rect = Rect2(pop_btn_x, panel_rect.end.y - 70, pop_btn_w, pop_btn_h)
			draw_rect(btn_skip_rect, Color("ebcb8b"), true) 
			draw_string(ThemeDB.fallback_font, btn_skip_rect.position + Vector2(80, 32), "SKIP >", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color("2e3440"))

# ==============================================================================
# [UI] DRAWING HELPERS
# ==============================================================================
func draw_top_bar(vp):
	var top_bar_h = 60
	draw_rect(Rect2(0, 0, vp.x, top_bar_h), Color(0.1, 0.1, 0.1, 1.0), true) # SOLID BLACK
	
	var font_to_use = custom_font if custom_font else ThemeDB.fallback_font
	var font_size = 24
	var score_text = "SCORE: " + str(int(visual_score))
	
	# Score (With Pulse Effect)
	var text_size = font_to_use.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var score_pos = Vector2(20, 40)
	var center_offset = Vector2(text_size.x / 2.0, -text_size.y / 4.0)
	var pivot = score_pos + center_offset
	
	draw_set_transform(pivot, 0, Vector2(score_pulse_scale, score_pulse_scale))
	draw_string(font_to_use, -center_offset, score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, score_color_mod)
	draw_set_transform(Vector2(0,0), 0, Vector2(1,1)) 
	
	# Lives
	var lives_text = ""
	for i in range(lives): lives_text += "♥ "
	draw_string(font_to_use, Vector2(vp.x/2 - 40, 40), lives_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color("bf616a"))

	# Pause Button (|| Symbol)
	btn_pause_rect = Rect2(vp.x - 60, 0, 60, 60)
	draw_rect(Rect2(vp.x - 40, 18, 6, 24), Color.WHITE, true)
	draw_rect(Rect2(vp.x - 28, 18, 6, 24), Color.WHITE, true)
	
	# Keep particles at top
	if portal_particles:
		portal_particles.position = Vector2(vp.x / 2.0, 70)
	if spawn_burst_particles:
		spawn_burst_particles.position = Vector2(vp.x / 2.0, 70)

func draw_tutorial_overlay(vp_size):
	var font_to_use = custom_font if custom_font else ThemeDB.fallback_font
	var center = Vector2(vp_size.x / 2, vp_size.y / 2)
	
	# Dim Background
	draw_rect(Rect2(0, 0, vp_size.x, vp_size.y), Color(0,0,0,0.5), true)
	
	var instruction_text = ""
	var hand_pos = center
	# Animation cycle (2.5 seconds loop)
	var anim_cycle = fmod(tutorial_hand_animation_timer, 2.5)
	var hand_scale = 1.0
	var hand_color = Color(1,1,1,1)
	
	# STEP 1: MOVE
	if tutorial_piece_count == 0:
		instruction_text = "TOUCH & DRAG"
		if anim_cycle < 0.5: hand_pos = center # Wait
		elif anim_cycle < 0.7: hand_scale = 0.8; hand_color = Color(0.8,0.8,0.8,1) # Press
		elif anim_cycle < 1.5: # Drag
			var t = (anim_cycle - 0.7) / 0.8
			t = t * t * (3 - 2 * t) # Smoothstep
			hand_pos = center + Vector2(t * 150, 0)
			hand_scale = 0.8
		else: hand_pos = center + Vector2(150, 0) # Release
		
	# STEP 2: ROTATE
	elif tutorial_piece_count == 1:
		instruction_text = "TAP SIDE TO ROTATE"
		var target = Vector2(vp_size.x * 0.8, center.y)
		hand_pos = target
		if anim_cycle > 1.0 and anim_cycle < 1.2:
			hand_scale = 0.8; hand_color = Color(0.8,0.8,0.8,1) # Tap
		
	# STEP 3: SWITCH & ROTATE CORE
	elif tutorial_piece_count == 2:
		if control_mode == "PIECE":
			instruction_text = "TAP CENTER TO SWITCH"
			hand_pos = center
		else:
			instruction_text = "ROTATE THE CORE!"
			hand_pos = Vector2(vp_size.x * 0.8, center.y)
			
		if anim_cycle > 1.0 and anim_cycle < 1.2:
			hand_scale = 0.8; hand_color = Color(0.8,0.8,0.8,1) # Tap
	
	draw_square_hand_icon(hand_pos, hand_color, hand_scale)
	
	var text_pos = center - Vector2(0, 100)
	draw_string(font_to_use, text_pos - Vector2(100, 0), instruction_text, HORIZONTAL_ALIGNMENT_CENTER, 200, 32, Color.WHITE)

func draw_square_hand_icon(pos, color, scale_mod=1.0):
	# Pixel art style "Mitten" cursor using rects
	var s = 1.5 * scale_mod
	var t = Transform2D().scaled(Vector2(s, s)).translated(pos)
	draw_set_transform_matrix(t)
	
	# Main hand body (Square-ish)
	draw_rect(Rect2(-10, 0, 20, 20), color, true)
	# Index Finger (pointing up)
	draw_rect(Rect2(-10, -15, 8, 15), color, true)
	# Thumb (sticking out left)
	draw_rect(Rect2(-18, 5, 8, 10), color, true)
	
	draw_set_transform_matrix(Transform2D())

func draw_pause_menu(vp):
	var font_to_use = custom_font if custom_font else ThemeDB.fallback_font
	
	# Overlay
	draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0, 0, 0, 0.7), true)
	
	# Menu Box
	var w = 300
	var h = 350
	var x = (vp.x - w) / 2
	var y = (vp.y - h) / 2
	var box_rect = Rect2(x, y, w, h)
	
	draw_rect(box_rect, Color("2e3440"), true)
	draw_rect(box_rect, Color("eceff4"), false, 3.0)
	
	draw_string(font_to_use, Vector2(x + w/2 - 40, y + 50), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, -1, 32, Color.WHITE)
	
	# Buttons
	var btn_w = 220
	var btn_h = 50; var btn_x = x + (w - btn_w) / 2
	var start_y = y + 100; var gap = 70
	
	# Resume
	btn_p_resume = Rect2(btn_x, start_y, btn_w, btn_h)
	draw_rect(btn_p_resume, Color("a3be8c"), true)
	draw_string(font_to_use, Vector2(btn_x + 60, start_y + 35), "RESUME", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)
	
	# Levels
	btn_p_levels = Rect2(btn_x, start_y + gap, btn_w, btn_h)
	draw_rect(btn_p_levels, Color("5e81ac"), true)
	draw_string(font_to_use, Vector2(btn_x + 30, start_y + gap + 35), "LEVEL SELECT", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)
	
	# Settings
	btn_p_settings = Rect2(btn_x, start_y + gap*2, btn_w, btn_h)
	draw_rect(btn_p_settings, Color("4c566a"), true)
	draw_string(font_to_use, Vector2(btn_x + 50, start_y + gap*2 + 35), "SETTINGS", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.LIGHT_GRAY)

# Helper for drawing blocks
func draw_tech_block(x, y, color, is_active):
	var offset = 5.0
	var size = GRID_SIZE - (offset * 2)
	var rect = Rect2(x + offset, y + offset, size, size)
	var thickness = 5.0 if is_active else 4.0
	draw_rect(rect, color, false, thickness)
	if is_active: draw_rect(rect, Color(1, 1, 1, 0.1), true)

func save_state():
	pass
	
# Helper for gradient (placeholder for now)
func draw_gradient_overlay(vp, active_color):
	return
	
