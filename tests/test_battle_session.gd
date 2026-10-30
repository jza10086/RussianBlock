extends SceneTree

const Session = preload("res://scripts/battle_session.gd")
const Rules = preload("res://scripts/tetris_rules.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_reset_modes()
	_test_time_and_pause()
	_test_locks_turns_and_charges()
	_test_attack_validation()
	_test_direct_attack_guards()
	_test_finished_and_events()
	_test_snapshot_copies()
	print("Battle session: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _session(mode: String = "ffa"):
	var session = Session.new()
	session.reset(mode, 713)
	return session


func _events(session) -> Array:
	var events: Array = []
	session.game_event.connect(func(event: Dictionary): events.append(event.duplicate(true)))
	return events


func _floor_piece(session, index: int = 0) -> void:
	var rules = session.boards[index]
	for row in rules.board:
		row.fill(Rules.EMPTY)
	rules.current_type = 1
	rules.rotation = 0
	rules.position = Vector2i(0, 18)


func _single_clear(session, index: int = 0) -> void:
	_floor_piece(session, index)
	var rules = session.boards[index]
	rules.board[19].fill(4)
	for x in range(3, 7):
		rules.board[19][x] = Rules.EMPTY
	rules.current_type = 0
	rules.position = Vector2i(3, 18)


func _test_reset_modes() -> void:
	var session = _session()
	_check(session.mode == "ffa" and session.boards.size() == 3, "Free-for-all reset creates three boards")
	for rules in session.boards:
		_check(rules.width == 10 and rules.board.size() == 20 and rules.board[0].size() == 10, "Free-for-all boards are 10 by 20")
		_check(rules.current_type == session.boards[0].current_type and rules.queue == session.boards[0].queue, "Seeded competitors receive the same starting bag")
		_check(rules.score == 0 and rules.successful_locks == 0 and not rules.game_over, "Fresh boards reset game counters")
	session.boards[0].board[19][0] = 5
	_check(session.boards[1].board[19][0] == Rules.EMPTY, "Competitors have independent boards")
	_check(session.charges == [1, 1, 1] and session.turns == [0, 0, 0], "FFA starts with one item and initial seat")
	_check(session.gravity == [0.0, 0.0, 0.0] and session.locks == [0.0, 0.0, 0.0], "FFA timers start empty")
	_check(session.resets == [0, 0, 0] and session.earned_locks == [0, 0, 0], "FFA lock resets and charge progress start empty")
	session.elapsed = 45.0
	session.paused = true
	session.finished = true
	session.winner = 2
	session.sequence = 12
	session.reset("team", 713)
	_check(session.mode == "team" and session.boards.size() == 2, "Team reset creates two shared boards")
	for rules in session.boards:
		_check(rules.width == 14 and rules.board[0].size() == 14, "Team boards are 14 columns wide")
		_check(rules.position == Vector2i(5, -1), "Team spawn is centered")
	_check(session.elapsed == 0 and not session.paused and not session.finished and session.winner == -1 and session.sequence == 0, "Mode reset clears time and terminal state")
	_check(session.charges == [1, 1] and session.turns == [0, 0] and session.earned_locks == [0, 0], "Team reset replaces mode-sized item and seat state")
	session.reset("ffa", 713)
	_check(session.boards.size() == 3 and session.boards[2].width == 10 and session.charges.size() == 3, "Returning to FFA restores all three narrow boards")


func _test_time_and_pause() -> void:
	var session = _session()
	_check(is_equal_approx(Session.fall_interval(0), 0.85), "Gravity starts at 0.85 seconds per row")
	_check(Session.fall_interval(110) < Session.fall_interval(50) and Session.fall_interval(50) < Session.fall_interval(0), "Gravity accelerates as match time increases")
	_check(is_equal_approx(Session.fall_interval(1000000), 0.065), "Time ramp has a safe minimum interval")
	_check(is_equal_approx(Session.fall_interval(-10), Session.fall_interval(0)), "Negative curve input clamps to match start")
	for seconds in [0.0, 50.0, 110.0, 1000000.0]:
		_check(is_equal_approx(session.speed_profile.interval(seconds), Session.fall_interval(seconds)), "Configured speed resource agrees with the session default curve")
	var start: Vector2i = session.boards[0].position
	_check(not session.tick(0.5) and session.boards[0].position == start, "Fractional gravity time accumulates without premature movement")
	_check(session.tick(0.4) and session.boards[0].position.y == start.y + 1, "Accumulated time moves a piece exactly one row")
	_check(is_equal_approx(session.elapsed, 0.9), "Elapsed match time accumulates")
	_check(session.boards[1].position.y == start.y + 1 and session.boards[2].position.y == start.y + 1, "Every live board advances with shared match time")
	_check(session.boards[0].score == 0, "Natural gravity grants no soft-drop points")
	session.paused = true
	var frozen = session.snapshot()
	var gravity = session.gravity.duplicate()
	var locks = session.locks.duplicate()
	_check(not session.tick(20, [0]) and not session.submit_action(0, "drop") and not session.submit_action(0, "attack_right", 0), "Pause rejects ticks and actions including attacks")
	_check(session.snapshot() == frozen and session.gravity == gravity and session.locks == locks, "Pause preserves every gameplay field and timer")
	session.paused = false
	_check(session.submit_action(0, "soft") and session.boards[0].score == 1, "Resumed manual soft drop grants one point")
	var early = _session()
	var late = _session()
	late.elapsed = 220
	early.tick(0.3)
	late.tick(0.3)
	_check(late.boards[0].position.y > early.boards[0].position.y, "Actual gravity uses the accelerated match-time curve")
	var custom = _session()
	custom.speed_profile = custom.speed_profile.duplicate()
	custom.speed_profile.start_interval = 0.1
	var standard = _session()
	custom.tick(0.3)
	standard.tick(0.3)
	_check(custom.boards[0].position.y > standard.boards[0].position.y and standard.boards[0].position == Vector2i(3, -1), "Tick uses the assigned speed-profile resource rather than the static default helper")
	_check(is_equal_approx(Session.fall_interval(0), 0.85) and is_equal_approx(standard.speed_profile.start_interval, 0.85), "Duplicating and tuning one speed profile preserves the default helper and other sessions")
	var soft = _session()
	soft.tick(0.105, [0])
	_check(soft.boards[0].position.y > soft.boards[1].position.y and soft.boards[0].score > 0, "Soft-board input accelerates only the selected board and grants distance points")
	session.reset("ffa", 713)
	_check(session.elapsed == 0 and session.gravity == [0.0, 0.0, 0.0], "Restart resets the acceleration clock and accumulated gravity")
	session.gravity[0] = 0.4
	session.locks[0] = 0.3
	frozen = session.snapshot()
	gravity = session.gravity.duplicate()
	locks = session.locks.duplicate()
	_check(not session.tick(-1) and not session.tick(0), "Nonpositive tick durations are ignored")
	_check(session.snapshot() == frozen and session.gravity == gravity and session.locks == locks, "Negative and zero ticks cannot reverse elapsed time, gravity, or lock progress")


func _test_locks_turns_and_charges() -> void:
	var session = _session("team")
	_check(session.submit_action(0, "left") and session.turns[0] == 0, "Movement leaves the current teammate active")
	_check(session.submit_action(0, "rotate") and session.turns[0] == 0, "Rotation leaves the current teammate active")
	_check(session.submit_action(0, "hold") and session.turns[0] == 0, "Hold does not pass the teammate turn")
	for lock_index in 5:
		_floor_piece(session)
		_check(session.submit_action(0, "drop"), "A floor hard drop is accepted")
		_check(session.boards[0].score == (lock_index + 1) * 10, "Each zero-distance successful lock grants ten points")
		_check(session.boards[0].successful_locks == lock_index + 1, "Session preserves the rules successful lock counter")
		_check(session.turns[0] == (lock_index + 1) % 2 and session.turns[1] == 0, "Successful lock swaps only its own team seat")
		_check(session.charges[0] == (2 if lock_index == 4 else 1), "Five no-clear locks earn one item")
	_check(session.earned_locks[0] == 0, "Five-lock reward resets charge progress")
	_single_clear(session)
	_check(session.submit_action(0, "drop") and session.charges[0] == 3, "A line clear earns an item immediately")
	_check(session.boards[0].score == 160 and session.boards[0].lines == 1, "Lock points remain additive with normal clear rewards")
	_single_clear(session)
	session.submit_action(0, "drop")
	_check(session.charges[0] == 3 and session.earned_locks[0] == 0, "Items stay capped at three even after another clear")
	session.charges[0] = 1
	session.earned_locks[0] = 4
	_single_clear(session)
	session.submit_action(0, "drop")
	_check(session.charges[0] == 2 and session.earned_locks[0] == 0, "A clear on the fifth lock awards one item and resets progress without double counting")
	var ffa = _session()
	_floor_piece(ffa)
	ffa.submit_action(0, "drop")
	_check(ffa.turns == [0, 0, 0], "FFA locks do not alternate seats")
	var timed = _session("team")
	_floor_piece(timed)
	timed.tick(0.25)
	_check(timed.turns[0] == 0 and timed.boards[0].score == 0, "Resting piece waits through the lock delay")
	timed.tick(0.25)
	_check(timed.turns[0] == 1 and timed.boards[0].score == 10, "Gravity lock delay completion passes the team turn once")
	var failed = _session("team")
	var events = _events(failed)
	var rules = failed.boards[0]
	rules.current_type = 2
	rules.rotation = 0
	rules.position = Vector2i(5, -1)
	rules.board[1][5] = 6
	failed.submit_action(0, "drop")
	_check(rules.game_over and rules.score == 0 and rules.successful_locks == 0, "Failed top-out lock earns no points")
	_check(failed.turns[0] == 0 and failed.earned_locks[0] == 0 and failed.charges[0] == 1, "Failed lock does not swap seats or earn charge progress")
	_check(events.size() == 2 and events[0].kind == "action" and events[1].kind == "finished", "Failed lock produces no successful-lock event")


func _test_attack_validation() -> void:
	var session = _session()
	var before = session.snapshot()
	_check(not session.submit_action(-1, "attack_right", 0) and not session.submit_action(3, "attack_left", 0), "Invalid attacker indices are rejected")
	_check(not session.submit_action(0, "attack_left", 0) and not session.submit_action(2, "attack_right", 0), "Outside attacks never wrap to the opposite edge")
	_check(not session.submit_action(0, "attack_right", -2) and not session.submit_action(0, "attack_right", 10), "Invalid destination columns are rejected")
	_check(not session.submit_action(0, "unknown"), "Unknown public actions are rejected")
	_check(session.snapshot() == before, "Invalid attacks and actions consume nothing and emit nothing")
	_check(session.submit_action(0, "attack_right", 0), "Left board can attack its immediate right neighbor")
	_check(session.charges == [0, 1, 1] and session.boards[1].board[19][0] == Rules.INTERFERENCE_TYPE, "Successful attack consumes one item and adds one target cube")
	_check(session.boards[0].board[19][0] == Rules.EMPTY and session.boards[2].board[19][0] == Rules.EMPTY, "Attack changes only the adjacent target board")
	before = session.snapshot()
	_check(not session.submit_action(0, "attack_right", 1) and session.snapshot() == before, "No-charge attack is rejected atomically")
	_check(session.submit_action(2, "attack_left", 1), "Right board can attack its immediate left neighbor")
	_check(session.boards[1].board[19][1] == Rules.INTERFERENCE_TYPE, "Right-side attack targets the center board")
	var center = _session()
	_check(center.submit_action(1, "attack_left", 0) and center.boards[0].board[19][0] == Rules.INTERFERENCE_TYPE, "Center board can attack the immediate left board")
	center.charges[1] = 1
	_check(center.submit_action(1, "attack_right", 0) and center.boards[2].board[19][0] == Rules.INTERFERENCE_TYPE, "Center board can attack the immediate right board")
	var deferred = _session("team")
	var target = deferred.boards[1]
	target.current_type = 1
	target.rotation = 0
	target.position = Vector2i(5, 18)
	before = deferred.snapshot()
	_check(not deferred.submit_action(0, "attack_right", 6), "Active target occupying the settled-board landing safely defers an attack")
	_check(deferred.snapshot() == before and not target.game_over, "Deferred attack consumes no item and does not top out the target")
	target.position.y = 5
	_check(deferred.submit_action(0, "attack_right"), "Omitted column defaults to the target board center")
	_check(target.board[19][7] == Rules.INTERFERENCE_TYPE and target.valid(target.position, target.rotation), "Attack inserts beneath a higher active piece without overlap or floating support")
	var eliminated = _session()
	eliminated.boards[1].game_over = true
	before = eliminated.snapshot()
	_check(not eliminated.submit_action(0, "attack_right", 0) and eliminated.snapshot() == before, "Eliminated adjacent target is not skipped over or charged")
	_check(not eliminated.submit_action(1, "attack_left", 0) and eliminated.snapshot() == before, "Eliminated attacker cannot submit actions")


func _test_finished_and_events() -> void:
	var session = _session("team")
	var events = _events(session)
	_floor_piece(session)
	session.submit_action(0, "drop")
	_check(events.size() == 2 and events[0].kind == "lock" and events[1].kind == "action", "Successful drop emits lock before action")
	_check(events[0].sequence == 1 and events[1].sequence == 2 and session.sequence == 2, "Events use monotonic session sequence numbers")
	_check(events[0].board == 0 and events[0].cleared == 0 and events[0].score == 10 and events[0].next_seat == 1, "Lock event carries finalized score, clear count, and next seat")
	session.elapsed = 12.5
	session.boards[1].board[0][0] = 5
	_check(session.submit_action(0, "attack_right", 0), "Settled top-entry obstruction resolves as an accepted lethal attack")
	_check(session.charges[0] == 0 and session.boards[1].game_over and session.finished and session.winner == 0, "Lethal attack consumes a charge and declares the surviving team winner")
	_check(events.size() == 4 and events[2].kind == "attack" and events[3].kind == "finished", "Lethal attack emits attack before finished")
	_check(events[2].sequence == 3 and events[3].sequence == 4 and events[2].target == 1 and events[2].column == 0, "Attack event preserves ordered target and column metadata")
	_check(events[2].time == 12.5 and events[3].time == 12.5 and events[3].board == 0, "Finish event includes match time and winner")
	var frozen = session.snapshot()
	var gravity = session.gravity.duplicate()
	var locks = session.locks.duplicate()
	_check(not session.tick(100, [0]) and not session.submit_action(0, "drop") and not session.submit_action(0, "attack_right", 1), "Finished sessions reject every gameplay entry point")
	session.check_finished()
	_check(session.snapshot() == frozen and session.gravity == gravity and session.locks == locks and events.size() == 4, "Finished state and events remain frozen on repeated updates")
	session.reset("ffa", 713)
	_check(session.sequence == 0 and not session.finished and session.winner == -1, "Restart clears winner and event sequencing")
	session.submit_action(0, "left")
	_check(events[-1].sequence == 1 and events[-1].kind == "action", "Events restart sequencing after reset")
	var ffa = _session()
	ffa.boards[1].board[0][0] = 6
	_check(ffa.submit_action(0, "attack_right", 0) and not ffa.finished, "FFA continues after the first elimination with two boards alive")
	ffa.boards[2].game_over = true
	ffa.check_finished()
	_check(ffa.finished and ffa.winner == 0, "FFA ends once only one board remains")
	var tie = _session("team")
	for rules in tie.boards:
		rules.game_over = true
	tie.check_finished()
	_check(tie.finished and tie.winner == -1, "Simultaneous elimination resolves as a draw")


func _test_snapshot_copies() -> void:
	var session = _session("team")
	var snapshot = session.snapshot()
	_check(snapshot.mode == "team" and snapshot.boards.size() == 2 and snapshot.boards[0].width == 14, "Snapshot describes current mode and dynamic board dimensions")
	_check(snapshot.boards[0].items == 1 and snapshot.boards[0].seat == 0 and snapshot.boards[0].hold == -1, "Snapshot exposes items, team seat, and hold")
	snapshot.boards[0].board[19][0] = 6
	snapshot.boards[0].queue[0] = 100
	snapshot.boards[0].position = Vector2i(99, 99)
	snapshot.boards[0].score = 999
	snapshot.boards[0].items = 999
	_check(session.boards[0].board[19][0] == Rules.EMPTY and session.boards[0].queue[0] != 100, "Snapshot nested board rows and queues are deep copies")
	_check(session.boards[0].position == Vector2i(5, -1) and session.boards[0].score == 0 and session.charges[0] == 1, "Snapshot metadata cannot mutate the live session")
	var old = session.snapshot()
	_floor_piece(session)
	session.submit_action(0, "drop")
	_check(old.boards[0].score == 0 and old.boards[0].board[19][1] == Rules.EMPTY and old.sequence == 0, "A retained snapshot stays unchanged after live gameplay")


func _test_direct_attack_guards() -> void:
	var session = _session()
	var before = session.snapshot()
	_check(not session.attack(-1, 1, 0) and not session.attack(3, -1, 0), "Direct attack rejects invalid source indices")
	_check(not session.attack(0, 0, 0) and not session.attack(0, 2, 0) and not session.attack(2, -2, 0), "Direct attack rejects self-target and non-adjacent direction values")
	_check(session.snapshot() == before, "Rejected direct attack arguments leave every board and charge unchanged")
	session.paused = true
	before = session.snapshot()
	_check(not session.attack(0, 1, 0) and session.snapshot() == before, "Direct attack cannot bypass pause")
	session.paused = false
	session.finished = true
	before = session.snapshot()
	_check(not session.attack(0, 1, 0) and session.snapshot() == before, "Direct attack cannot bypass finished state")
	session.finished = false
	session.boards[0].game_over = true
	before = session.snapshot()
	_check(not session.attack(0, 1, 0) and session.snapshot() == before, "Direct attack rejects an eliminated source")
	session.boards[0].game_over = false
	_check(session.attack(0, 1, 0) and session.charges[0] == 0 and session.boards[1].board[19][0] == Rules.INTERFERENCE_TYPE, "Valid direct adjacent attack still resolves normally")
