@tool
extends TileMapLayer

# Drag your Level00.tres, Level01.tres, etc. here in the Inspector!
@export var game_levels: Array[Resource] = []

# --- CONTROLS ---
@export var load_level_index: int = 0

# These are "Fake Buttons". Click the checkbox to trigger the action.
@export var _LOAD_LEVEL_NOW: bool = false:
	set(val):
		if val:
			_LOAD_LEVEL_NOW = false # Reset the checkbox immediately
			load_level_from_disk()

@export var _SAVE_LEVEL_NOW: bool = false:
	set(val):
		if val:
			_SAVE_LEVEL_NOW = false # Reset the checkbox immediately
			save_level_to_disk()

const PIECE_TYPE_TO_ALT = {
	"": 0,
	"T": 1,
	"I": 2,
	"S": 3,
	"Z": 4,
	"J": 5,
	"L": 6,
	"O": 7
}

const ALT_TO_PIECE_TYPE = {
	0: "",
	1: "T",
	2: "I",
	3: "S",
	4: "Z",
	5: "J",
	6: "L",
	7: "O"
}

func _coord_key(v: Vector2i) -> String:
	return str(v.x) + "," + str(v.y)

func _piece_to_alt(piece_type: String) -> int:
	if PIECE_TYPE_TO_ALT.has(piece_type):
		return PIECE_TYPE_TO_ALT[piece_type]
	return 0

func _alt_to_piece(alt: int) -> String:
	if ALT_TO_PIECE_TYPE.has(alt):
		return ALT_TO_PIECE_TYPE[alt]
	return ""

# --- LOGIC ---
func load_level_from_disk():
	if game_levels.is_empty():
		print("Designer Error: No levels in the 'Game Levels' array!")
		return
		
	if load_level_index < 0 or load_level_index >= game_levels.size():
		print("Designer Error: Invalid Level Index!")
		return
	
	print("--- DEBUG LOADING LEVEL ", load_level_index, " ---")
	clear() # Clear current tiles
	
	var data = game_levels[load_level_index]
	
	# DEBUG: Tell us exactly what is in the file
	if data and "target_slots" in data:
		print("Found ", data.target_slots.size(), " blocks in file.")
		var piece_map = data.get("target_piece_map")
		if piece_map == null:
			piece_map = {}
		
		if data.target_slots.size() == 0:
			print("WARNING: Level file is valid but EMPTY.")
		
		for coord in data.target_slots:
			var v = Vector2i(coord.x, coord.y)
			var required_piece = piece_map.get(_coord_key(v), "")
			var alt = _piece_to_alt(required_piece)
			# Source 0, Atlas (0,0), Alternative tile encodes required piece type/color.
			set_cell(v, 0, Vector2i(0,0), alt)
	else:
		print("ERROR: Level Data is null or missing 'target_slots'")
	
	print("Finished Loading.")

func save_level_to_disk():
	if game_levels.is_empty(): return
	
	print("--- SAVING LEVEL ", load_level_index, " ---")
	var data = game_levels[load_level_index]
	
	# 1. Get all tiles currently drawn on screen
	var used_cells = get_used_cells()
	var new_targets = []
	var new_target_piece_map = {}
	
	# 2. Convert them to Vector2 (which is what your game uses)
	for cell in used_cells:
		var v = Vector2i(cell.x, cell.y)
		new_targets.append(v)
		var alt = get_cell_alternative_tile(v)
		var piece_type = _alt_to_piece(alt)
		if piece_type != "":
			new_target_piece_map[_coord_key(v)] = piece_type
	
	# 3. Save to the Resource file
	data.target_slots = new_targets
	data.target_piece_map = new_target_piece_map
	ResourceSaver.save(data, data.resource_path)
	
	print("Saved ", new_targets.size(), " blocks to ", data.resource_path, " (typed targets: ", new_target_piece_map.size(), ")")
