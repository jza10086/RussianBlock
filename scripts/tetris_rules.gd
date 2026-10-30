class_name TetrisRules
extends RefCounted
## Pure board rules. Coordinates use +Y downward; rows above zero are spawn space.
## move() never auto-locks or adds soft-drop points. hard_drop() returns rows fallen.

const WIDTH := 10
const HEIGHT := 20
const EMPTY := -1
const INTERFERENCE_TYPE := 6
const SPAWN := Vector2i(3, -1)
# I, O, T, S, Z, J, L; all rotations use SRS origins.
const BASE_SHAPES := [
	[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	[Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
]
# Keys encode old_rotation * 4 + new_rotation; SRS Y signs are flipped for +Y down.
const JLSTZ_KICKS := {
	1: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	4: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	6: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, -2), Vector2i(1, -2)],
	9: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, 2), Vector2i(-1, 2)],
	11: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
	14: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	12: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, -2), Vector2i(-1, -2)],
	3: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, 2), Vector2i(1, 2)],
}
const I_KICKS := {
	1: [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(1, -2)],
	4: [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, -1), Vector2i(-1, 2)],
	6: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(2, 1)],
	9: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, 2), Vector2i(-2, -1)],
	11: [Vector2i(0, 0), Vector2i(2, 0), Vector2i(-1, 0), Vector2i(2, -1), Vector2i(-1, 2)],
	14: [Vector2i(0, 0), Vector2i(-2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(1, -2)],
	12: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-2, 0), Vector2i(1, 2), Vector2i(-2, -1)],
	3: [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-1, -2), Vector2i(2, 1)],
}

# Set before reset(), or pass a width to construction/reset; minimum is four.
var width: int = WIDTH
var board: Array = []
var current_type: int = 0
var rotation: int = 0
var position: Vector2i = SPAWN
var queue: Array[int] = []
var held_type: int = -1
var hold_used: bool = false
var score: int = 0
var successful_locks: int = 0
var lines: int = 0
var level: int = 1
var game_over: bool = false
var _rng := RandomNumberGenerator.new()


func _init(board_width: int = WIDTH) -> void:
	width = maxi(4, board_width)


func reset(seed_value: int = -1, board_width: int = -1) -> void:
	if board_width >= 0:
		width = board_width
	width = maxi(4, width)
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	board.clear()
	for y in HEIGHT:
		board.append(_empty_row())
	queue.clear()
	held_type = -1
	hold_used = false
	score = 0
	successful_locks = 0
	lines = 0
	level = 1
	game_over = false
	_refill_queue()
	spawn_piece()


func cells(type: int = -1, rot: int = -1) -> Array[Vector2i]:
	var piece_type: int = current_type if type == -1 else type
	var turn: int = rotation if rot == -1 else posmod(rot, 4)
	var result: Array[Vector2i] = []
	if piece_type < 0 or piece_type >= BASE_SHAPES.size():
		return result
	for base_cell: Vector2i in BASE_SHAPES[piece_type]:
		var cell := base_cell
		if piece_type != 1:
			var maximum: int = 3 if piece_type == 0 else 2
			for _step in turn:
				cell = Vector2i(maximum - cell.y, cell.x)
		result.append(cell)
	return result


func current_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells():
		result.append(position + cell)
	return result


func valid(pos: Vector2i, rot: int, type: int = -1) -> bool:
	var offsets := cells(type, rot)
	if offsets.size() != 4 or board.size() != HEIGHT:
		return false
	for offset in offsets:
		var cell := pos + offset
		if cell.x < 0 or cell.x >= width or cell.y >= HEIGHT:
			return false
		if cell.y >= 0 and board[cell.y][cell.x] != EMPTY:
			return false
	return true


func move(dx: int, dy: int) -> bool:
	if game_over:
		return false
	var target := position + Vector2i(dx, dy)
	if not valid(target, rotation):
		return false
	position = target
	return true


func rotate_piece(direction: int = 1) -> bool:
	if game_over or direction == 0:
		return false
	var next_rotation: int = posmod(rotation + (1 if direction > 0 else -1), 4)
	var kicks: Array = [Vector2i.ZERO]
	if current_type != 1:
		var table: Dictionary = I_KICKS if current_type == 0 else JLSTZ_KICKS
		kicks = table[rotation * 4 + next_rotation]
	for kick: Vector2i in kicks:
		var target := position + kick
		if valid(target, next_rotation):
			position = target
			rotation = next_rotation
			return true
	return false


func ghost_position() -> Vector2i:
	var landing := position
	if game_over or not valid(landing, rotation):
		return landing
	while valid(landing + Vector2i.DOWN, rotation):
		landing.y += 1
	return landing


func hard_drop() -> int:
	if game_over:
		return 0
	var landing := ghost_position()
	var distance: int = landing.y - position.y
	position = landing
	var previous_locks := successful_locks
	lock_piece()
	if successful_locks > previous_locks:
		score += distance * 2
	return distance


func lock_piece() -> int:
	if game_over:
		return 0
	if not valid(position, rotation):
		game_over = true
		return 0
	var occupied := current_cells()
	# Lock-out: any part still above the visible field ends the game atomically.
	for cell in occupied:
		if cell.y < 0:
			game_over = true
			return 0
	for cell in occupied:
		board[cell.y][cell.x] = current_type
	successful_locks += 1
	score += 10
	var remaining: Array = []
	var cleared := 0
	for row: Array in board:
		if row.has(EMPTY):
			remaining.append(row)
		else:
			cleared += 1
	for _row in cleared:
		remaining.push_front(_empty_row())
	board = remaining
	if cleared > 0:
		var rewards: Array[int] = [0, 100, 300, 500, 800]
		score += rewards[mini(cleared, 4)] * level
		lines += cleared
		level = 1 + int(lines / 10.0)
	spawn_piece()
	return cleared


## Insert one cube where it would land against the settled board in this column.
## This attack is instantaneous: active cells higher in the column are ignored,
## never used as support for a floating block. If the settled-board landing cell
## overlaps the active piece, defer the attack safely. Full rows wait for a player
## lock to clear; a settled block at row zero causes top-out. False places no cube.
func drop_interference(column: int) -> bool:
	if game_over or column < 0 or column >= width or board.size() != HEIGHT:
		return false
	var obstruction := HEIGHT
	for y in HEIGHT:
		if board[y][column] != EMPTY:
			obstruction = y
			break
	if obstruction == 0:
		game_over = true
		return false
	var landing := Vector2i(column, obstruction - 1)
	if landing in current_cells():
		return false
	board[landing.y][landing.x] = INTERFERENCE_TYPE
	return true


func hold_piece() -> bool:
	if game_over or hold_used:
		return false
	var outgoing := current_type
	if held_type == -1:
		held_type = outgoing
		spawn_piece()
	else:
		var incoming := held_type
		held_type = outgoing
		_activate_piece(incoming)
	hold_used = true
	return true


func spawn_piece() -> void:
	if game_over:
		return
	_refill_queue()
	var incoming: int = queue.pop_front()
	_refill_queue()
	hold_used = false
	_activate_piece(incoming)


func demo_setup() -> void:
	reset(2026)
	var rows: Array[String] = [
		".......6..", "..2....66.", ".22...566.",
		"122...554.", "1126..4444", "0116..3222",
	]
	var left_padding := maxi(0, int((width - WIDTH) / 2.0))
	for y in rows.size():
		for x in width:
			var source_x := x - left_padding
			if source_x < 0 or source_x >= rows[y].length():
				continue
			var symbol: String = rows[y].substr(source_x, 1)
			board[HEIGHT - rows.size() + y][x] = EMPTY if symbol == "." else int(symbol)
	current_type = 2
	rotation = 0
	position = Vector2i(_spawn_position().x, 5)
	held_type = 0
	hold_used = false
	queue.assign([6, 3, 0, 1, 4, 5, 2])
	score = 2480
	lines = 18
	level = 2
	game_over = false


func _empty_row() -> Array[int]:
	var row: Array[int] = []
	row.resize(width)
	row.fill(EMPTY)
	return row


func _refill_queue() -> void:
	while queue.size() < 7:
		var bag: Array[int] = [0, 1, 2, 3, 4, 5, 6]
		for index in range(6, 0, -1):
			var other := _rng.randi_range(0, index)
			var temporary := bag[index]
			bag[index] = bag[other]
			bag[other] = temporary
		queue.append_array(bag)


func _spawn_position() -> Vector2i:
	return Vector2i(int((width - 4) / 2.0), SPAWN.y)


func _activate_piece(type: int) -> void:
	current_type = type
	rotation = 0
	position = _spawn_position()
	if not valid(position, rotation):
		game_over = true
