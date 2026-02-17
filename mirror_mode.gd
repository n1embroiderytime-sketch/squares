extends "res://main_game.gd"

@export var mirror_game_levels: Array[Resource] = []

func _ready():
	if not mirror_game_levels.is_empty():
		game_levels = mirror_game_levels.duplicate(true)
	elif not Global.game_levels.is_empty():
		game_levels = Global.game_levels.duplicate(true)
	super._ready()

func _draw():
	super._draw()

	# Mirror axis is horizontal, between relative rows -1 and 0.
	var center_screen_x = OFFSET_X + (CENTER_X * GRID_SIZE)
	var axis_screen_y = (CENTER_Y * GRID_SIZE)
	var vp_size = get_viewport_rect().size
	var line_col = Color("ebcb8b")
	line_col.a = 0.7
	draw_line(Vector2(center_screen_x - 220, axis_screen_y), Vector2(center_screen_x + 220, axis_screen_y), line_col, 2.0)

func get_cluster_block(rel_x, rel_y):
	for b in cluster:
		if b.x == rel_x and b.y == rel_y:
			return b
	return null

func mirror_rel_y(rel_y):
	return -rel_y - 1

func land_piece():
	if level_completed or show_results_screen:
		return

	var gy = round(falling_piece.y)
	if will_collide(falling_piece.x, gy, falling_piece.matrix):
		handle_rejection()
		return
	if gy < 0:
		handle_rejection()
		return
	if not grid_board.piece_is_connected(falling_piece.x, gy, falling_piece.matrix):
		handle_rejection()
		return

	var placements = []
	var placement_keys = {}
	for r in range(falling_piece.matrix.size()):
		for c in range(falling_piece.matrix[r].size()):
			if falling_piece.matrix[r][c] != 1:
				continue
			var rel_x = (falling_piece.x + c) - CENTER_X
			var rel_y = (gy + r) - CENTER_Y
			var candidates = [
				{"x": rel_x, "y": rel_y},
				{"x": rel_x, "y": mirror_rel_y(rel_y)}
			]
			for pos in candidates:
				var key = str(pos.x) + "," + str(pos.y)
				if not placement_keys.has(key):
					placement_keys[key] = true
					placements.append(pos)

	# Validate all generated placements before mutating cluster.
	for pos in placements:
		if get_cluster_block(pos.x, pos.y) != null:
			handle_rejection()
			return

	last_placed_coords.clear()
	for pos in placements:
		cluster.append({"x": pos.x, "y": pos.y})
		last_placed_coords.append(Vector2(CENTER_X + pos.x, CENTER_Y + pos.y))

	grid_board.cluster = cluster
	placement_flash_alpha = 1.0

	var center_x = OFFSET_X + ((falling_piece.x + falling_piece.matrix[0].size() / 2.0) * GRID_SIZE)
	var center_y = (falling_piece.y + falling_piece.matrix.size() / 2.0) * GRID_SIZE
	spawn_impact_particles(Vector2(center_x, center_y))

	score += 150
	trigger_score_pulse()
	spawn_floating_text(Vector2(center_x, center_y), 150)

	if sfx_connect:
		sfx_connect.play()
	trigger_vfx("SUCCESS")
	falling_piece = null
	piece_mover.falling_piece = null
	sequence_index += 1

	check_victory_100_percent()
	spawn_piece()
	trigger_spawn_burst()
