extends Node
var cols = 0
var rows = 0
var center_x = 0
var center_y = 0

var cluster = []
var current_level_targets = []

func configure(p_cols, p_rows, p_center_x, p_center_y):
	cols = p_cols
	rows = p_rows
	center_x = p_center_x
	center_y = p_center_y

func reset_core():
	cluster = [
		{"x": -1, "y": -1},
		{"x": 0, "y": -1},
		{"x": -1, "y": 0},
		{"x": 0, "y": 0}
	]

func set_targets_from_level(level_data):
	current_level_targets = []
	for t in level_data.target_slots:
		current_level_targets.append({"x": t.x, "y": t.y})

func is_occupied(x, y):
	for b in cluster:
		if center_x + b.x == x and center_y + b.y == y:
			return true
	return false

func will_collide(tx, ty, matrix):
	for r in range(matrix.size()):
		for c in range(matrix[r].size()):
			if matrix[r][c] == 1:
				var ax = tx + c
				var ay = ty + r
				if ax < 0 or ax >= cols:
					return true
				if floor(ay + 0.9) >= rows:
					return true
				if ay >= 0:
					if is_occupied(ax, floor(ay + 0.1)) or is_occupied(ax, floor(ay + 0.9)):
						return true
	return false

func piece_is_connected(piece_x, piece_y, matrix):
	for r in range(matrix.size()):
		for c in range(matrix[r].size()):
			if matrix[r][c] == 1:
				var ax = piece_x + c
				var ay = piece_y + r
				if is_occupied(ax + 1, ay) or is_occupied(ax - 1, ay) or is_occupied(ax, ay + 1) or is_occupied(ax, ay - 1):
					return true
	return false

func piece_fits_targets(piece_x, piece_y, matrix):
	for r in range(matrix.size()):
		for c in range(matrix[r].size()):
			if matrix[r][c] == 1:
				var rel_x = (piece_x + c) - center_x
				var rel_y = (piece_y + r) - center_y
				var is_target = false
				for t in current_level_targets:
					if t.x == rel_x and t.y == rel_y:
						is_target = true
						break
				if not is_target:
					return false
	return true

func commit_piece(piece_x, piece_y, matrix):
	var placed_abs = []
	for r in range(matrix.size()):
		for c in range(matrix[r].size()):
			if matrix[r][c] == 1:
				placed_abs.append(Vector2(piece_x + c, piece_y + r))
				cluster.append({"x": (piece_x + c) - center_x, "y": (piece_y + r) - center_y})
	return placed_abs

func calculate_completion_percent():
	if current_level_targets.is_empty():
		return 0.0
	var matched_count = 0
	for t in current_level_targets:
		for b in cluster:
			if b.x == t.x and b.y == t.y:
				matched_count += 1
				break
	return float(matched_count) / float(current_level_targets.size())

func rotate_core(dir):
	var new_cluster = []
	for b in cluster:
		var nx
		var ny
		if dir == 1:
			nx = -b.y - 1
			ny = b.x
		else:
			nx = b.y
			ny = -b.x - 1
		if center_x + nx < 0 or center_x + nx >= cols:
			return false
		new_cluster.append({"x": nx, "y": ny})

	var new_targets = []
	for t in current_level_targets:
		var nx
		var ny
		if dir == 1:
			nx = -t.y - 1
			ny = t.x
		else:
			nx = t.y
			ny = -t.x - 1
		new_targets.append({"x": nx, "y": ny})

	cluster = new_cluster
	current_level_targets = new_targets
	return true

func check_sim_occupied(x, y, test_cluster):
	for b in test_cluster:
		if center_x + b.x == x and center_y + b.y == y:
			return true
	return false

func check_sim_collision(tx, ty, matrix, test_cluster):
	for r in range(matrix.size()):
		for c in range(matrix[r].size()):
			if matrix[r][c] == 1:
				var ax = tx + c
				var ay = ty + r
				if ax < 0 or ax >= cols:
					return true
				if floor(ay + 0.9) >= rows:
					return true
				if ay >= 0:
					if check_sim_occupied(ax, floor(ay + 0.1), test_cluster) or check_sim_occupied(ax, floor(ay + 0.9), test_cluster):
						return true
	return false

func rotate_simulation_data(clus, targs):
	for b in clus:
		var nx = b.y
		var ny = -b.x - 1
		b.x = nx
		b.y = ny
	for t in targs:
		var nx = t.y
		var ny = -t.x - 1
		t.x = nx
		t.y = ny
