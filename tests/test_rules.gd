extends SceneTree

const Rules = preload("res://scripts/tetris_rules.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_reset_and_bags()
	_test_configurable_width()
	_test_lock_rewards()
	_test_interference()
	_test_shapes_and_rotation()
	_test_collisions_and_kicks()
	_test_line_clears()
	_test_top_out()
	_test_hold()
	_test_drop_and_demo()
	print("Tetris rules: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _new_rules():
	var rules = Rules.new()
	rules.reset(713)
	return rules


func _test_reset_and_bags() -> void:
	var rules = _new_rules()
	var same = _new_rules()
	_check(rules.board.size() == 20 and rules.board[0].size() == 10, "Board dimensions")
	rules.board[0][0] = 2
	_check(rules.board[1][0] == -1, "Board rows are independently allocated")
	rules.reset(713)
	for bag_index in 10:
		var seen: Array[int] = []
		for index in 7:
			_check(rules.current_type == same.current_type, "Seeded bags are reproducible")
			seen.append(rules.current_type)
			_check(rules.queue.size() >= 5, "Five-piece preview is always available")
			rules.spawn_piece()
			same.spawn_piece()
		seen.sort()
		_check(seen == [0, 1, 2, 3, 4, 5, 6], "Every bag has all seven unique pieces")
	_check(rules.score == 0 and rules.lines == 0 and rules.level == 1, "Reset counters")
	_check(not rules.game_over and rules.held_type == -1, "Reset game/hold state")


func _test_shapes_and_rotation() -> void:
	var rules = _new_rules()
	for type in 7:
		rules.current_type = type
		rules.position = Vector2i(3, 5)
		rules.rotation = 0
		var original = rules.current_cells()
		for turn in 4:
			var offsets = rules.cells(type, turn)
			_check(offsets.size() == 4, "Each orientation contains four cells")
			var unique := {}
			for cell in offsets:
				unique[cell] = true
			_check(unique.size() == 4, "Each orientation contains four distinct cells")
			_check(rules.rotate_piece(), "Unblocked rotation succeeds")
		_check(rules.current_cells() == original, "Four clockwise turns restore geometry")
		_check(rules.rotate_piece(-1) and rules.rotation == 3, "Counterclockwise rotation wraps")
	_check(rules.cells(1, 0) == rules.cells(1, 3), "O rotates without translation")


func _test_collisions_and_kicks() -> void:
	var rules = _new_rules()
	rules.current_type = 1
	_check(rules.valid(Vector2i(-1, 2), 0), "Shape bounds allow negative origin")
	_check(not rules.valid(Vector2i(-2, 2), 0), "Left boundary")
	_check(not rules.valid(Vector2i(8, 2), 0), "Right boundary")
	_check(rules.valid(Vector2i(3, -1), 0), "Spawn space above board is legal")
	_check(not rules.valid(Vector2i(3, 19), 0), "Floor collision")
	rules.board[10][4] = 3
	_check(not rules.valid(Vector2i(3, 9), 0), "Settled block collision")
	rules.position = Vector2i(3, 8)
	var before: Vector2i = rules.position
	_check(not rules.move(0, 1) and rules.position == before, "Blocked movement is atomic")
	rules.reset(713)
	rules.current_type = 0
	rules.rotation = 1
	rules.position = Vector2i(-2, 4)
	_check(rules.valid(rules.position, rules.rotation), "I wall-kick starting position")
	_check(rules.rotate_piece(), "I rotation uses two-cell wall kick")
	_check(rules.position == Vector2i(0, 4) and rules.rotation == 2, "Correct I SRS wall-kick result")
	rules.current_type = 2
	rules.rotation = 0
	rules.position = Vector2i(3, 18)
	_check(rules.rotate_piece(), "T rotates at floor using floor kick")
	_check(rules.position == Vector2i(2, 17) and rules.rotation == 1, "Correct T SRS floor-kick result")
	rules.position = Vector2i(3, 5)
	rules.rotation = 0
	for row in rules.board:
		row.fill(6)
	for cell in rules.current_cells():
		rules.board[cell.y][cell.x] = -1
	before = rules.position
	_check(not rules.rotate_piece(), "All obstructed rotation kicks are rejected")
	_check(rules.position == before and rules.rotation == 0, "Failed rotation is atomic")


func _test_line_clears() -> void:
	var rules = _new_rules()
	rules.board[19].fill(5)
	for x in range(3, 7):
		rules.board[19][x] = -1
	rules.current_type = 0
	rules.rotation = 0
	rules.position = Vector2i(3, 18)
	_check(rules.lock_piece() == 1, "Single-line clear")
	_check(rules.lines == 1 and rules.score == 110, "Single-line score")
	_check(rules.board[19].count(-1) == 10, "Cleared row removed")
	rules.reset(713)
	for y in [18, 19]:
		rules.board[y].fill(3)
		for x in [4, 5]:
			rules.board[y][x] = -1
	rules.board[17][0] = 6
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(3, 18)
	_check(rules.lock_piece() == 2, "Double-line clear")
	_check(rules.score == 310 and rules.lines == 2, "Double-line score")
	_check(rules.board[19][0] == 6, "Rows above cleared lines fall two cells")
	_check(rules.board[0].count(-1) == 10 and rules.board[1].count(-1) == 10, "New empty rows inserted at top")
	rules.reset(713)
	for y in range(16, 20):
		rules.board[y].fill(4)
		rules.board[y][4] = -1
	rules.current_type = 0
	rules.rotation = 1
	rules.position = Vector2i(2, 16)
	rules.lines = 8
	_check(rules.lock_piece() == 4, "Four-line clear")
	_check(rules.score == 810 and rules.lines == 12 and rules.level == 2, "Clear uses pre-clear level and advances level")
	_check(rules.board.size() == 20, "Clearing preserves board height")
	rules.reset(713)
	for y in range(17, 20):
		rules.board[y].fill(4)
		rules.board[y][4] = -1
	rules.current_type = 0
	rules.rotation = 1
	rules.position = Vector2i(2, 16)
	rules.level = 2
	rules.lines = 10
	_check(rules.lock_piece() == 3, "Triple-line clear")
	_check(rules.score == 1010 and rules.successful_locks == 1, "Triple-line reward scales with level while lock bonus stays ten")


func _test_top_out() -> void:
	var rules = _new_rules()
	rules.current_type = 2
	rules.rotation = 0
	rules.position = Vector2i(3, -1)
	_check(rules.lock_piece() == 0 and rules.game_over, "Locking above board tops out")
	_check(rules.board[0].count(-1) == 10, "Top-out does not partially write board")
	_check(not rules.move(1, 0) and not rules.rotate_piece() and not rules.hold_piece(), "Game-over disables controls")
	_check(rules.hard_drop() == 0, "Game-over disables hard drop")
	rules.reset(713)
	rules.board[0].fill(1)
	rules.queue.push_front(2)
	rules.spawn_piece()
	_check(rules.game_over, "Spawn overlap tops out")
	rules.reset(713)
	_check(not rules.game_over and rules.score == 0, "Reset recovers from top-out")


func _test_hold() -> void:
	var rules = _new_rules()
	var original: int = rules.current_type
	var next: int = rules.queue[0]
	rules.move(1, 4)
	rules.rotate_piece()
	_check(rules.hold_piece(), "First hold succeeds")
	_check(rules.held_type == original and rules.current_type == next, "Empty hold consumes next queued piece")
	_check(rules.rotation == 0 and rules.position == Vector2i(3, -1), "Hold resets pose")
	_check(not rules.hold_piece(), "Cannot hold twice in one turn")
	rules.hard_drop()
	_check(not rules.hold_used, "Lock resets hold restriction")
	var outgoing: int = rules.current_type
	var preview = rules.queue.duplicate()
	_check(rules.hold_piece(), "Hold available on next piece")
	_check(rules.current_type == original and rules.held_type == outgoing, "Occupied hold swaps pieces")
	_check(rules.queue == preview, "Hold swap does not consume queue")


func _test_drop_and_demo() -> void:
	var rules = _new_rules()
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(3, -1)
	_check(rules.ghost_position() == Vector2i(3, 18), "Ghost lands on floor")
	_check(rules.position == Vector2i(3, -1), "Ghost query leaves active piece untouched")
	_check(rules.hard_drop() == 19, "Hard drop returns traveled distance")
	_check(rules.score == 48, "Hard drop awards two points per row plus successful lock")
	_check(rules.board[18][4] == 1 and rules.board[19][5] == 1, "Hard drop locks piece")
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(3, 0)
	_check(rules.ghost_position() == Vector2i(3, 16), "Ghost stops at settled blocks")
	rules.demo_setup()
	_check(not rules.game_over and rules.valid(rules.position, rules.rotation), "Demo active piece is valid")
	_check(rules.ghost_position().y > rules.position.y, "Demo has room to fall")
	for row in rules.board:
		_check(row.has(-1), "Demo has no pre-existing completed lines")
	var snapshot = rules.board.duplicate(true)
	rules.demo_setup()
	_check(rules.board == snapshot, "Demo layout is deterministic")


func _test_configurable_width() -> void:
	var rules = Rules.new(14)
	rules.reset(713)
	_check(Rules.WIDTH == 10 and rules.width == 14, "Default width constant remains compatible")
	for row in rules.board:
		_check(row.size() == 14, "Team board rows use configured width")
	_check(rules.position == Vector2i(5, -1), "Wide-board spawn is centered")
	rules.current_type = 1
	_check(rules.valid(Vector2i(11, 2), 0), "Wide-board rightmost legal origin")
	_check(not rules.valid(Vector2i(12, 2), 0), "Wide-board right boundary")
	rules.board[19].fill(5)
	for x in range(10, 14):
		rules.board[19][x] = -1
	rules.current_type = 0
	rules.rotation = 0
	rules.position = Vector2i(10, 18)
	_check(rules.lock_piece() == 1, "Line clearing covers every wide-board column")
	_check(rules.board[0].size() == 14 and rules.board[19].count(-1) == 14, "Clears insert correctly sized rows")
	_check(rules.score == 110 and rules.successful_locks == 1, "Wide-board clear includes lock reward")
	rules.hold_piece()
	_check(rules.position == Vector2i(5, -1), "Hold respawns at wide-board center")
	rules.demo_setup()
	_check(rules.width == 14 and rules.valid(rules.position, rules.rotation), "Demo preserves configured width and valid active piece")
	_check(rules.position == Vector2i(5, 5), "Demo active piece is centered for width")
	_check(rules.board[14][9] == 6 and rules.board[19][0] == -1 and rules.board[19][13] == -1, "Demo pattern is centered with empty wide margins")
	var snapshot = rules.board.duplicate(true)
	rules.demo_setup()
	_check(rules.board == snapshot, "Wide demo is deterministic")
	rules.reset(713, 10)
	_check(rules.width == 10 and rules.board[0].size() == 10 and rules.position == Rules.SPAWN, "Reset can restore default width")
	rules.width = 14
	rules.reset(713)
	_check(rules.board[0].size() == 14, "Width can be configured before reset")
	var narrow = Rules.new(1)
	narrow.reset(713)
	_check(narrow.width == 4 and narrow.valid(narrow.position, narrow.rotation), "Width is clamped to support every tetromino")


func _test_lock_rewards() -> void:
	var rules = _new_rules()
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(0, 18)
	_check(rules.lock_piece() == 0 and rules.score == 10, "Successful no-clear lock earns ten points")
	_check(rules.successful_locks == 1, "Successful lock counter increments without a clear")
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(6, 18)
	rules.lock_piece()
	_check(rules.score == 20 and rules.successful_locks == 2, "Each successful lock earns its own bonus")
	rules.current_type = 2
	rules.rotation = 0
	rules.position = Vector2i(3, -1)
	var snapshot = rules.board.duplicate(true)
	rules.lock_piece()
	_check(rules.game_over and rules.score == 20 and rules.successful_locks == 2, "Above-board lock-out earns no bonus or successful lock")
	_check(rules.board == snapshot, "Above-board lock-out preserves the full board atomically")
	rules.reset(713)
	_check(rules.score == 0 and rules.successful_locks == 0, "Reset clears successful locks and points")
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(3, 18)
	rules.board[18][4] = 6
	rules.lock_piece()
	_check(rules.game_over and rules.successful_locks == 0 and rules.score == 0, "Invalid overlapping lock earns no bonus")
	rules.reset(713)
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(3, -3)
	rules.board[1][4] = 6
	_check(rules.hard_drop() == 2, "Top-out hard drop still reports travel distance")
	_check(rules.game_over and rules.score == 0 and rules.successful_locks == 0, "Failed hard-drop lock earns no rewards")
	rules.reset(713)
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(0, 18)
	rules.queue.push_front(2)
	rules.board[0][4] = 6
	rules.lock_piece()
	_check(rules.game_over and rules.score == 10 and rules.successful_locks == 1, "Successful lock keeps bonus even when next spawn tops out")
	rules.reset(713)
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(3, 18)
	_check(not rules.move(0, 1) and rules.score == 0 and rules.successful_locks == 0, "Blocked movement does not award lock points")
	_check(rules.hard_drop() == 0 and rules.score == 10 and rules.successful_locks == 1, "Zero-distance hard drop still earns the successful lock bonus")


func _test_interference() -> void:
	var rules = _new_rules()
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(3, 4)
	var active = rules.current_cells()
	var preview = rules.queue.duplicate()
	_check(rules.drop_interference(0), "Interference enters an empty column")
	_check(rules.board[19][0] == Rules.INTERFERENCE_TYPE, "Interference lands on the floor")
	_check(rules.drop_interference(0) and rules.board[18][0] == Rules.INTERFERENCE_TYPE, "Repeated interference stacks vertically")
	rules.board[8][1] = 2
	rules.board[15][1] = 5
	_check(rules.drop_interference(1) and rules.board[7][1] == Rules.INTERFERENCE_TYPE, "Interference lands on the topmost settled obstruction")
	_check(rules.board[14][1] == -1, "Interference does not tunnel into gaps below settled obstructions")
	_check(rules.drop_interference(4) and rules.board[19][4] == Rules.INTERFERENCE_TYPE, "Instant interference lands against settled board below a higher active piece")
	_check(rules.board[3][4] == Rules.EMPTY, "Active cells never support a floating interference cube")
	_check(rules.current_cells() == active and rules.valid(rules.position, rules.rotation), "Interference preserves a valid, unchanged active piece")
	_check(rules.score == 0 and rules.lines == 0 and rules.level == 1 and rules.successful_locks == 0, "Interference awards no score, lines, levels, or lock count")
	_check(rules.queue == preview and not rules.hold_used, "Interference does not advance the player turn")
	var snapshot = rules.board.duplicate(true)
	_check(not rules.drop_interference(-1) and not rules.drop_interference(10), "Out-of-range interference is rejected")
	_check(rules.board == snapshot and not rules.game_over, "Invalid interference is atomic")
	rules.reset(713)
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(3, 18)
	snapshot = rules.board.duplicate(true)
	_check(not rules.drop_interference(4), "Interference defers when its floor landing overlaps an active cell")
	_check(not rules.game_over and rules.board == snapshot and rules.valid(rules.position, rules.rotation), "Deferred interference does not top out or mutate the board")
	rules.position = Vector2i(3, 9)
	rules.board[11][5] = 3
	snapshot = rules.board.duplicate(true)
	_check(not rules.drop_interference(5) and rules.board == snapshot, "Interference also defers at an occupied landing above the settled stack")
	rules.position = Vector2i(3, -1)
	_check(rules.drop_interference(4) and rules.board[19][4] == Rules.INTERFERENCE_TYPE, "Active spawn cells above an empty landing do not block instant insertion")
	_check(not rules.game_over and rules.valid(rules.position, rules.rotation), "Insertion beneath spawn preserves a legal active piece")
	rules.board[0][2] = 3
	snapshot = rules.board.duplicate(true)
	_check(not rules.drop_interference(2) and rules.game_over, "Settled obstruction at entry causes top-out")
	_check(rules.board == snapshot and rules.score == 0, "Interference top-out is atomic and unrewarded")
	_check(not rules.drop_interference(0) and rules.board == snapshot, "Game-over rejects later interference")
	rules.reset(713, 14)
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(3, 5)
	rules.board[19].fill(2)
	rules.board[19][13] = -1
	_check(rules.drop_interference(13), "Interference supports the last wide-board column")
	_check(not rules.board[19].has(-1) and rules.lines == 0 and rules.score == 0, "Interference leaves completed rows in place without rewards")
	rules.position = Vector2i(0, 17)
	_check(rules.lock_piece() == 1 and rules.lines == 1 and rules.score == 110, "Next successful player lock clears interference-completed rows normally")
	_check(rules.successful_locks == 1 and rules.board[0].size() == 14, "Deferred clear preserves wide rows and only counts the player lock")
