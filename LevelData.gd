extends Resource
class_name LevelData

# This script defines the "Shape" of a level file.
@export var level_name: String = "New Level"
@export var sequence: Array[String] = ["O", "I"]
# We use Vector2i (Integer Vector) for grid coordinates
@export var target_slots: Array[Vector2i] = []
# Optional per-target piece typing.
# Key format: "x,y" (relative grid position), value: piece type ("T", "I", "S", "Z", "J", "L", "O").
@export var target_piece_map: Dictionary = {}
