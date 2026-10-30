class_name BattleSession
extends RefCounted
## Local, renderer-independent session. Feed submit_action() from a future transport.
signal game_event(event: Dictionary)
const Rules = preload("res://scripts/tetris_rules.gd")
var speed_profile = preload("res://assets/speed_profile.tres")
var mode := "ffa"
var boards: Array = []
var elapsed := 0.0
var paused := false
var finished := false
var winner := -1
var charges: Array[int] = []
var turns: Array[int] = []
var gravity: Array[float] = []
var locks: Array[float] = []
var resets: Array[int] = []
var earned_locks: Array[int] = []
var sequence := 0

static func fall_interval(seconds: float) -> float:
	return maxf(0.065, 0.85 * exp(-maxf(0.0, seconds) / 110.0))

func reset(new_mode: String = "ffa", seed_value: int = -1) -> void:
	mode = new_mode
	boards.clear(); charges.clear(); turns.clear(); gravity.clear(); locks.clear(); resets.clear(); earned_locks.clear()
	elapsed = 0; paused = false; finished = false; winner = -1; sequence = 0
	for i in (2 if mode == "team" else 3):
		var r = Rules.new()
		r.width = 14 if mode == "team" else 10
		r.reset(seed_value)
		boards.append(r)
		charges.append(1); turns.append(0); gravity.append(0); locks.append(0); resets.append(0); earned_locks.append(0)

func emit(kind: String, index: int, extra: Dictionary = {}) -> void:
	sequence += 1
	var event := {"sequence": sequence, "kind": kind, "board": index, "time": elapsed}
	event.merge(extra)
	game_event.emit(event)

func tick(delta: float, soft_boards: Array = []) -> bool:
	if paused or finished or delta <= 0: return false
	elapsed += delta
	var changed := false
	for i in boards.size():
		var r = boards[i]
		if r.game_over: continue
		gravity[i] += delta
		var interval := minf(speed_profile.interval(elapsed), 0.035) if i in soft_boards else speed_profile.interval(elapsed)
		# Consume elapsed gravity deterministically, with an upper safety bound for stalled frames.
		var steps := 0
		while gravity[i] >= interval and steps < 64:
			gravity[i] -= interval; steps += 1
			if r.move(0, 1):
				if i in soft_boards: r.score += 1
				locks[i] = 0
				changed = true
			else: break
		if not r.valid(r.position + Vector2i.DOWN, r.rotation):
			locks[i] += delta
			if locks[i] >= 0.5:
				var before: int = r.lines
				var before_locks: int = r.successful_locks
				r.lock_piece()
				after_lock(i, before, before_locks)
				changed = true
		else: locks[i] = 0
	check_finished()
	return changed

func submit_action(index: int, action: String, column: int = -1) -> bool:
	if paused or finished or index < 0 or index >= boards.size(): return false
	var r = boards[index]
	if r.game_over: return false
	var changed := false
	match action:
		"left": changed = r.move(-1, 0)
		"right": changed = r.move(1, 0)
		"rotate": changed = r.rotate_piece(1)
		"rotate_back": changed = r.rotate_piece(-1)
		"soft":
			changed = r.move(0, 1)
			if changed: r.score += 1
		"hold":
			changed = r.hold_piece()
			if changed: gravity[index] = 0; locks[index] = 0; resets[index] = 0
		"drop":
			var before: int = r.lines
			var before_locks: int = r.successful_locks
			r.hard_drop()
			after_lock(index, before, before_locks)
			changed = true
		"attack_left", "attack_right":
			return attack(index, -1 if action == "attack_left" else 1, column)
	if changed:
		if action in ["left", "right", "rotate", "rotate_back"] and resets[index] < 15:
			locks[index] = 0; resets[index] += 1
		emit("action", index, {"action": action})
	check_finished()
	return changed

func after_lock(index: int, old_lines: int, old_locks: int) -> void:
	gravity[index] = 0; locks[index] = 0; resets[index] = 0
	var r = boards[index]
	if r.successful_locks <= old_locks: return
	var cleared: int = r.lines - old_lines
	earned_locks[index] += 1
	if cleared > 0 or earned_locks[index] >= 5:
		charges[index] = mini(3, charges[index] + 1)
		earned_locks[index] = 0
	if mode == "team": turns[index] = 1 - turns[index]
	emit("lock", index, {"cleared": cleared, "score": r.score, "next_seat": turns[index]})

func attack(index: int, direction: int, column: int) -> bool:
	if paused or finished or index < 0 or index >= boards.size() or direction not in [-1, 1]: return false
	if boards[index].game_over: return false
	var target := index + direction
	# Adjacency is spatial, never wraps across the outside edges.
	if target < 0 or target >= boards.size() or boards[target].game_over or charges[index] <= 0: return false
	if column < -1 or column >= boards[target].width: return false
	var col: int = int(boards[target].width / 2) if column == -1 else column
	if not boards[target].drop_interference(col) and not boards[target].game_over: return false
	charges[index] -= 1
	emit("attack", index, {"target": target, "column": col})
	check_finished()
	return true

func check_finished() -> void:
	if finished: return
	var alive: Array[int] = []
	for i in boards.size():
		if not boards[i].game_over: alive.append(i)
	if alive.size() <= 1:
		finished = true
		winner = alive[0] if alive.size() == 1 else -1
		emit("finished", winner)

func snapshot() -> Dictionary:
	var states: Array = []
	for i in boards.size():
		var r = boards[i]
		states.append({"width": r.width, "board": r.board.duplicate(true), "piece": r.current_type,
			"rotation": r.rotation, "position": r.position, "queue": r.queue.duplicate(), "hold": r.held_type,
			"score": r.score, "lines": r.lines, "out": r.game_over, "items": charges[i], "seat": turns[i]})
	return {"mode": mode, "elapsed": elapsed, "paused": paused, "finished": finished, "winner": winner, "sequence": sequence, "boards": states}
