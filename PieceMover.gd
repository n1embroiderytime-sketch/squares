extends Node
var falling_piece = null
var lock_timer = 0.0
var is_hard_dropping = false

func spawn_piece(piece_type, shapes, cols):
	var matrix = shapes[piece_type]
	var spawn_x = floor(cols / 2) - ceil(matrix[0].size() / 2.0)
	falling_piece = {"matrix": matrix, "type": piece_type, "x": spawn_x, "y": -4}
	lock_timer = 0.0

func rotate_matrix_data(m):
	var new_m = []
	var n = m.size()
	var m_w = m[0].size()
	for i in range(m_w):
		new_m.append([])
		for _j in range(n):
			new_m[i].append(0)
	for i in range(m_w):
		for j in range(n):
			new_m[i][j] = m[n - 1 - j][i]
	return new_m

func move_horizontal(dir, board):
	if falling_piece == null:
		return false
	var new_x = falling_piece.x + dir
	if not board.will_collide(new_x, floor(falling_piece.y), falling_piece.matrix):
		falling_piece.x = new_x
		lock_timer = 0.0
		return true
	return false

func rotate_piece(dir, board):
	if falling_piece == null:
		return false
	var m = falling_piece.matrix
	var new_m = rotate_matrix_data(m)
	if dir == -1:
		new_m = rotate_matrix_data(rotate_matrix_data(rotate_matrix_data(m)))
	if not board.will_collide(falling_piece.x, floor(falling_piece.y), new_m):
		falling_piece.matrix = new_m
		lock_timer = 0.0
		return true
	return false

func gravity_step(delta, fall_speed, board):
	if falling_piece == null:
		return false
	var move_amount = fall_speed * delta
	if board.will_collide(falling_piece.x, falling_piece.y + move_amount, falling_piece.matrix):
		lock_timer += delta
		return true
	falling_piece.y += move_amount
	lock_timer = 0.0
	return false

func should_lock(lock_delay_time):
	return lock_timer > lock_delay_time

func reset_lock_timer():
	lock_timer = 0.0

func hard_drop(board, offset_x, grid_size):
	var result = {
		"score_gained": 0,
		"start_y": 0.0,
		"end_y": 0.0,
		"draw_x": 0.0,
		"matrix_w": 0.0,
		"matrix_h": 0.0
	}
	if falling_piece == null:
		return result

	falling_piece.y = floor(falling_piece.y)
	result.start_y = falling_piece.y * grid_size

	while not board.will_collide(falling_piece.x, falling_piece.y + 1, falling_piece.matrix):
		falling_piece.y += 1
		result.score_gained += 2

	result.matrix_w = falling_piece.matrix[0].size() * grid_size
	result.matrix_h = falling_piece.matrix.size() * grid_size
	result.draw_x = offset_x + (falling_piece.x * grid_size)
	result.end_y = falling_piece.y * grid_size
	return result
