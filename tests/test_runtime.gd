extends SceneTree
var failures := 0
var checks := 0
func check(condition:bool,message:String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func key(game:Node,code:int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	game._unhandled_key_input(e)
func run() -> void:
	var game = load("res://classic.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check(game.rules.lines == 0,"Fresh game lines")
	check(game.blocks.get_child_count() > 0,"3D pieces rendered")
	var pos:Vector2i = game.rules.position
	key(game,KEY_LEFT)
	check(game.rules.position.x == pos.x-1,"Input movement")
	key(game,KEY_X)
	check(game.rules.rotation == 1,"Input rotation")
	key(game,KEY_C)
	check(game.rules.held_type >= 0,"Input hold")
	var held:int = game.rules.held_type
	key(game,KEY_C)
	check(game.rules.held_type == held,"Input repeated hold blocked")
	key(game,KEY_ESCAPE)
	check(game.paused and game.overlay.visible,"Pause overlay visible")
	pos = game.rules.position
	game._process(3)
	key(game,KEY_SPACE)
	check(game.rules.position == pos and game.rules.score == 0,"Pause freezes gameplay")
	key(game,KEY_P)
	check(not game.paused and not game.overlay.visible,"Resume")
	key(game,KEY_SPACE)
	check(game.rules.score > 0 and not game.rules.hold_used,"Hard drop locks and renews hold")
	check(game.score_label.text == "%06d" % game.rules.score,"Score HUD synchronized")
	key(game,KEY_F11)
	check(game.demo and game.rules.score > 0,"Demo setup")
	key(game,KEY_R)
	check(not game.demo and game.rules.score == 0 and game.rules.held_type == -1,"Restart clears demo and hold")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused,"Focus loss pauses")
	key(game,KEY_R)
	check(not game.paused,"Restart while paused resumes")
	game.rules.game_over = true
	game.refresh()
	check(game.overlay.visible and game.overlay_title.text == "GAME OVER","Game over overlay")
	key(game,KEY_R)
	check(not game.rules.game_over and not game.overlay.visible,"Restart from game over")
	var arrays:Array = game.cube.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_VERTEX].size() > 100,"Rounded cube real subdivided geometry")
	var normal:Vector3 = arrays[Mesh.ARRAY_NORMAL][0]
	check(abs(normal.length()-1.0) < 0.01,"Smooth unit normals")
	await process_frame
	game.queue_free()
	await process_frame
	print("Runtime checks: %d passed, %d failed" % [checks-failures,failures])
	quit(1 if failures else 0)
