extends "res://main_game.gd"

# --- ENDLESS CONFIGURATION ---
const MAX_RADIUS_BEFORE_ZOOM = 4
const MAX_RADIUS_BEFORE_RESET = 6 
const ZOOM_STEP = 0.05
const PRESTIGE_BONUS = 5000

# --- UI & VISUALS ---
# [DO NOT DELETE] Custom Font & Portal Settings

# --- NEW JUICINESS STATE ---

# --- STATE ---
var current_base_zoom = 1.0
var prestige_count = 0
var is_resetting = false 

# [VISUALS] Debug line toggle (False = Hide, True = Show Gold Line)
var show_debug_lines = true 

var camera = null
var autosave_elapsed = 0.0
const ENDLESS_AUTOSAVE_INTERVAL = 15.0

func _ready():
	randomize()
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

	score = 0
	visual_score = 0.0
	lives = 0 # UI Trick: Hides hearts in parent draw function
	level_index = 999
	control_mode = "PIECE"
	level_target_piece_map = {}
	camera = get_node_or_null("Camera2D")

	if ResourceLoader.exists(FONT_PATH):
		custom_font = load(FONT_PATH)

	spawn_portal_particles()

	cluster = [
		{"x": -1, "y": -1, "is_gold": true, "is_starting_core": true},
		{"x": 0, "y": -1, "is_gold": true, "is_starting_core": true},
		{"x": -1, "y": 0, "is_gold": true, "is_starting_core": true},
		{"x": 0, "y": 0, "is_gold": true, "is_starting_core": true}
	]
	grid_board.cluster = cluster
	current_level_targets = []
	grid_board.current_level_targets = []
	level_theme_color = THEME_COLORS.pick_random()

	reset_piece_pipeline()
	ensure_piece_queue()
	trigger_spawn_burst()
	spawn_piece()
	commit_endless_progress(true)

# --- PROCEDURAL TEXTURE GENERATION ---
# 64x64 Texture with 6px Border
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

# [FIX] Refined Particle Systems
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

# --- NEW: SCOREBOARD PULSE TWEEN ---
func trigger_score_pulse():
	# Resets the scale and creates a new elastic tween
	var t = create_tween()
	score_pulse_scale = 1.5 
	score_color_mod = COLOR_GOLD
	
	t.set_parallel(true)
	t.tween_property(self, "score_pulse_scale", 1.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "score_color_mod", Color.WHITE, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# --- NEW: FLOATING TEXT SYSTEM ---
func spawn_floating_text(pos, value):
	var label = Label.new()
	label.text = "+" + str(value)
	if custom_font: label.add_theme_font_override("font", custom_font)
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = COLOR_GOLD
	label.position = pos
	label.z_index = 100 # Ensure it's on top of everything
	add_child(label)
	
	var t = create_tween()
	t.set_parallel(true)
	# Float up and fade out
	t.tween_property(label, "position:y", pos.y - 80, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(label.queue_free)


func ensure_piece_queue():
	while piece_queue.size() < PIECE_QUEUE_SIZE:
		if piece_bag.is_empty():
			refill_piece_bag()
		if piece_bag.is_empty():
			break
		var next_piece = piece_bag.pop_front()
		piece_queue.append(next_piece)
		piece_queue_locked.append(false)

func commit_endless_progress(force_save := false):
	var current_score_int = max(0, int(score))
	Global.endless_current_score = current_score_int
	if current_score_int > Global.endless_high_score:
		Global.endless_high_score = current_score_int
		force_save = true
	if force_save:
		Global.save_game()

func _input(event):
	if is_resetting:
		return

	if is_game_paused and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if btn_p_resume.has_point(event.position):
			toggle_pause()
			return
		elif btn_p_levels.has_point(event.position):
			commit_endless_progress(true)
			is_game_paused = false
			get_tree().change_scene_to_file("res://level_select.tscn")
			return
		elif btn_p_settings.has_point(event.position):
			return

	super._input(event)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp_size = get_viewport_rect().size
		var pause_rect = Rect2(vp_size.x - 70, 10, 60, 60)
		if pause_rect.has_point(event.position):
			toggle_pause()
			commit_endless_progress(true)

func _process(delta):
	super._process(delta)
	if camera:
		var target_zoom = current_base_zoom
		camera.zoom = camera.zoom.lerp(Vector2(target_zoom, target_zoom), 2.0 * delta)

	if abs(visual_score - score) > 0.1:
		visual_score = lerp(visual_score, float(score), 10.0 * delta)
	else:
		visual_score = float(score)

	if not is_game_paused and not is_resetting:
		autosave_elapsed += delta
		if autosave_elapsed >= ENDLESS_AUTOSAVE_INTERVAL:
			autosave_elapsed = 0.0
			commit_endless_progress(true)

# --- SCENARIO C: TOTAL MISS (BOTTOM/COLLISION) ---
func handle_rejection():
	score = max(0, score - 500)
	visual_score = float(score) 
	
	trigger_vfx("FAIL")
	shake_intensity = 5.0
	
	if falling_piece:
		falling_piece.y = -3
		falling_piece.x = floor(COLS / 2) - ceil(falling_piece.matrix[0].size() / 2.0)
		lock_timer = 0.0

# [LOGIC] THE CORE LOOP
func land_piece():
	if is_resetting: return
	var gy = round(falling_piece.y)
	
	var connected = false
	for r in range(falling_piece.matrix.size()):
		for c in range(falling_piece.matrix[r].size()):
			if falling_piece.matrix[r][c] == 1:
				var ax = falling_piece.x + c; var ay = gy + r
				if is_occupied(ax+1, ay) or is_occupied(ax-1, ay) or is_occupied(ax, ay+1) or is_occupied(ax, ay-1): 
					connected = true
	
	if not connected or gy < 0:
		handle_rejection(); return

	save_state()
	var blocks_added_count = 0
	var trimmed_count = 0
	
	for r in range(falling_piece.matrix.size()):
		for c in range(falling_piece.matrix[r].size()):
			if falling_piece.matrix[r][c] == 1:
				var final_x = (falling_piece.x + c) - CENTER_X
				var final_y = (gy + r) - CENTER_Y
				
				var limit = MAX_RADIUS_BEFORE_RESET
				var inside_x = (final_x >= -limit) and (final_x < limit)
				var inside_y = (final_y >= -limit) and (final_y < limit)
				
				# Calc World Position for VFX
				var vp_size = get_viewport_rect().size
				var center_x = vp_size.x / 2.0
				var world_x = center_x + (final_x * GRID_SIZE) + (GRID_SIZE/2.0)
				var world_y = ((CENTER_Y + final_y) * GRID_SIZE) + (GRID_SIZE/2.0)
				
				if inside_x and inside_y:
					cluster.append({ "x": final_x, "y": final_y, "is_gold": false, "is_starting_core": false })
					grid_board.cluster = cluster
					blocks_added_count += 1
					# Add floating text for block placement if desired, or keep it for the bonus
				else:
					trimmed_count += 1
					spawn_trim_particles(Vector2(world_x, world_y))
					score += 10 
					spawn_floating_text(Vector2(world_x, world_y), 10) # <-- Floating Text for Trim
	
	if blocks_added_count > 0:
		trigger_vfx("SUCCESS")
		score += 100 
		trigger_score_pulse() # <-- Pulse Effect
		commit_endless_progress()
		# Spawn floating text at the center of the piece roughly
		var vp_s = get_viewport_rect().size
		spawn_floating_text(Vector2(vp_s.x/2.0, (falling_piece.y * GRID_SIZE) + 100), 100) 
		
		falling_piece = null
		check_gold_squares() 
		trigger_spawn_burst()
		check_core_size(false) 
	else:
		falling_piece = null 
		trigger_vfx("FAIL")
		check_core_size(true) 

func spawn_trim_particles(pos):
	var p = CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.amount = 8; p.one_shot = true; p.explosiveness = 1.0; p.lifetime = 0.4
	p.spread = 180.0; p.gravity = Vector2(0, 0)
	p.initial_velocity_min = 50; p.initial_velocity_max = 100
	p.scale_amount_min = 2.0; p.scale_amount_max = 5.0
	p.color = Color("bf616a") 
	add_child(p)
	await get_tree().create_timer(0.5).timeout
	p.queue_free()

func check_gold_squares():
	var max_checked_size = MAX_RADIUS_BEFORE_RESET * 2
	var newly_gold = false
	for size in range(4, max_checked_size + 1, 2): 
		var half = size / 2
		var min_val = -half; var max_val = half - 1
		var is_perfect = true
		var blocks_in_range = []
		for x in range(min_val, max_val + 1):
			for y in range(min_val, max_val + 1):
				var b = get_block_at_rel(x, y)
				if b == null: is_perfect = false; break
				blocks_in_range.append(b)
			if not is_perfect: break
		if is_perfect:
			for b in blocks_in_range:
				if not b.get("is_gold", false):
					b["is_gold"] = true; newly_gold = true; score += 500 
					
					# Spawn floating text on the specific gold block
					var vp_size = get_viewport_rect().size
					var center_x = vp_size.x / 2.0
					var world_x = center_x + (b.x * GRID_SIZE) + (GRID_SIZE/2.0)
					var world_y = ((CENTER_Y + b.y) * GRID_SIZE) + (GRID_SIZE/2.0)
					spawn_floating_text(Vector2(world_x, world_y), 500)
					
	if newly_gold: 
		trigger_vfx("GOLD_COMPLETE")
		trigger_score_pulse() # <-- Pulse Effect
		commit_endless_progress()

func get_block_at_rel(rx, ry):
	for b in cluster:
		if b.x == rx and b.y == ry: return b
	return null

func rotate_core(dir):
	grid_board.cluster = cluster

	if is_resetting or level_completed or show_results_screen: return
	var new_cluster = []
	for b in cluster:
		var nx; var ny
		if dir == 1: nx = -b.y - 1; ny = b.x
		else: nx = b.y; ny = -b.x - 1
		new_cluster.append({"x": nx, "y": ny, "is_gold": b.get("is_gold", false), "is_starting_core": b.get("is_starting_core", false)})
	cluster = new_cluster
	grid_board.cluster = cluster
	if dir == 1: visual_core_rotation = -90.0
	else: visual_core_rotation = 90.0
	var tween = create_tween()
	tween.tween_property(self, "visual_core_rotation", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func check_core_size(force_trigger = false):
	var max_dist = 0
	for b in cluster:
		var d = max(abs(b.x), abs(b.y))
		if b.x >= 0: d = max(d, b.x + 1) 
		if b.y >= 0: d = max(d, b.y + 1) 
		if d > max_dist: max_dist = d
	
	if max_dist > MAX_RADIUS_BEFORE_ZOOM:
		var target = 1.0 - ((max_dist - MAX_RADIUS_BEFORE_ZOOM) * ZOOM_STEP)
		current_base_zoom = clamp(target, 0.6, 1.0) 
	else: current_base_zoom = 1.0
	
	if force_trigger:
		trigger_prestige()
	else:
		if falling_piece == null: spawn_piece() 

func trigger_prestige():
	is_resetting = true; falling_piece = null; prestige_count += 1
	for r in range(MAX_RADIUS_BEFORE_RESET, 1, -1):
		var blocks_removed_in_ring = 0
		var min_v = -r; var max_v = r - 1
		for i in range(cluster.size() - 1, -1, -1):
			var b = cluster[i]
			var is_in_ring = (b.x == min_v or b.x == max_v or b.y == min_v or b.y == max_v)
			var is_outside_inner = (b.x < (-r + 1) or b.x > (r - 2) or b.y < (-r + 1) or b.y > (r - 2))
			if is_in_ring and is_outside_inner:
				if b.get("is_starting_core", false): continue
				cluster.remove_at(i); blocks_removed_in_ring += 1
		if blocks_removed_in_ring > 0:
			var pts = (blocks_removed_in_ring * 50) * r
			score += pts
			trigger_score_pulse() # <-- Pulse Effect
			
			shake_intensity = 3.0; if sfx_connect: sfx_connect.play()
			queue_redraw()
			await get_tree().create_timer(0.2).timeout
	shake_intensity = 20.0; flash_intensity = 0.8; flash_color = COLOR_GOLD 
	current_base_zoom = 1.0; is_resetting = false; grid_board.cluster = cluster; spawn_piece()
	trigger_spawn_burst()

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
				   check_sim_occupied(ax, ay-1, test_cluster): connected = true
	return connected

# --- WARP GRID ---
func draw_local_warp_grid(vp_size, center_x):
	var gravity_points = []
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

# --- DRAWING ---
func _draw():
	var vp_size = get_viewport_rect().size
	draw_rect(Rect2(0, 0, vp_size.x, vp_size.y), COLOR_BG, true)
	
	var center_pixel_x = vp_size.x / 2.0
	var center_pixel_y = CENTER_Y * GRID_SIZE 
	
	draw_local_warp_grid(vp_size, center_pixel_x)
	draw_gradient_overlay(vp_size, level_theme_color)

	if drop_trail_alpha > 0:
		var trail_col = Color(COLOR_ACTIVE_PLAYER.r, COLOR_ACTIVE_PLAYER.g, COLOR_ACTIVE_PLAYER.b, drop_trail_alpha)
		draw_rect(drop_trail_rect, trail_col, true)
	
	var limit_blocks = MAX_RADIUS_BEFORE_RESET
	var limit_px = limit_blocks * GRID_SIZE 
	var tl_x = -limit_px; var tl_y = -limit_px
	var width = limit_px * 2
	var limit_rect = Rect2(tl_x, tl_y, width, width)
	
	draw_set_transform(Vector2(center_pixel_x, center_pixel_y), 0, Vector2(1,1))
	
	# [VISUAL FIX] Reverted to Gold/White Line
	var limit_color = COLOR_GOLD 
	limit_color.a = 0.1 
	if show_debug_lines:
		draw_rect(limit_rect, limit_color, false, 2.0)
	
	var corner_len = 20.0; var corner_col = COLOR_GOLD; corner_col.a = 0.3
	draw_line(limit_rect.position, limit_rect.position + Vector2(corner_len, 0), corner_col, 4)
	draw_line(limit_rect.position, limit_rect.position + Vector2(0, corner_len), corner_col, 4)
	draw_line(limit_rect.end, limit_rect.end - Vector2(corner_len, 0), corner_col, 4)
	draw_line(limit_rect.end, limit_rect.end - Vector2(0, corner_len), corner_col, 4)
	var tr = limit_rect.position + Vector2(width, 0)
	draw_line(tr, tr - Vector2(corner_len, 0), corner_col, 4); draw_line(tr, tr + Vector2(0, corner_len), corner_col, 4)
	var bl = limit_rect.position + Vector2(0, width)
	draw_line(bl, bl + Vector2(corner_len, 0), corner_col, 4); draw_line(bl, bl - Vector2(0, corner_len), corner_col, 4)

	draw_set_transform(Vector2(center_pixel_x, center_pixel_y), deg_to_rad(visual_core_rotation), Vector2(1,1))
	for b in cluster:
		var x = b.x * GRID_SIZE; var y = b.y * GRID_SIZE
		var block_col = level_theme_color
		if control_mode == "CORE": block_col = COLOR_ACTIVE_PLAYER
		else: if b.get("is_gold", false): block_col = COLOR_GOLD
		draw_tech_block(x, y, block_col, control_mode == "CORE")

	draw_set_transform(Vector2(0,0), 0, Vector2(1,1))

	if falling_piece != null:
		var py = falling_piece.y; var px = falling_piece.x
		for r in range(falling_piece.matrix.size()):
			for c in range(falling_piece.matrix[r].size()):
				if falling_piece.matrix[r][c] == 1:
					var relative_grid_x = (px + c) - CENTER_X
					var draw_x = center_pixel_x + (relative_grid_x * GRID_SIZE)
					var draw_y = (py + r) * GRID_SIZE
					var piece_col = COLOR_ACTIVE_PLAYER
					if control_mode == "CORE": piece_col = level_theme_color
					draw_tech_block(draw_x, draw_y, piece_col, control_mode == "PIECE")

	if placement_flash_alpha > 0:
		for coord in last_placed_coords:
			var relative_grid_x = coord.x - CENTER_X
			var draw_x = center_pixel_x + (relative_grid_x * GRID_SIZE)
			var draw_y = coord.y * GRID_SIZE
			var flash_col = Color(1, 1, 1, placement_flash_alpha)
			draw_rect(Rect2(draw_x, draw_y, GRID_SIZE, GRID_SIZE), flash_col, true)

	draw_endless_ui(vp_size)
	
	if flash_intensity > 0:
		draw_rect(Rect2(0, 0, vp_size.x, vp_size.y), Color(flash_color.r, flash_color.g, flash_color.b, flash_intensity), true)
	if is_game_paused:
		draw_pause_menu(vp_size)

	if show_results_screen: pass

# --- [UI] LEFT-ALIGNED SCOREBOARD WITH PULSE ---
func draw_endless_ui(vp):
	var top_bar_h = 80
	draw_rect(Rect2(0, 0, vp.x, top_bar_h), Color(0.05, 0.05, 0.05, 0.9), true)
	
	var score_text = str(int(visual_score))
	var font_to_use = custom_font if custom_font else ThemeDB.fallback_font
	var font_size = 42
	
	# Draw Score Top Left (Margin 40px)
	var score_pos = Vector2(40, 55)
	
	# --- SCALE LOGIC ---
	# Calculate pivot (center of text) to scale correctly
	var text_size = font_to_use.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var center_offset = Vector2(text_size.x / 2.0, -text_size.y / 4.0)
	var pivot = score_pos + center_offset
	
	# Apply Scale and Color
	draw_set_transform(pivot, 0, Vector2(score_pulse_scale, score_pulse_scale))
	draw_string(font_to_use, -center_offset, score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, score_color_mod)
	draw_set_transform(Vector2(0,0), 0, Vector2(1,1)) # Reset
	# -------------------
	
	var pause_x = vp.x - 60; var pause_y = 20
	draw_rect(Rect2(pause_x, pause_y, 10, 30), Color.WHITE, true)
	draw_rect(Rect2(pause_x + 15, pause_y, 10, 30), Color.WHITE, true)
	
	if portal_particles:
		portal_particles.position = Vector2(vp.x / 2.0, 70)
	if spawn_burst_particles:
		spawn_burst_particles.position = Vector2(vp.x / 2.0, 70)

# --- HELPERS ---
func trigger_vfx(type):
	super.trigger_vfx(type)
	if type == "GOLD_COMPLETE":
		shake_intensity = 20.0; flash_intensity = 0.5; flash_color = COLOR_GOLD
		if sfx_connect: sfx_connect.play()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		commit_endless_progress(true)
