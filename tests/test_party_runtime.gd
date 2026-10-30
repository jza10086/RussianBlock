extends SceneTree
var failures := 0
var checks := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func key(game: Node, code: int) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.pressed = true
	game._unhandled_key_input(event)
func check_compact_layout(game: Node) -> void:
	var previous_right := -1.0
	for i in game.pane_views.size():
		var view: SubViewport = game.pane_views[i]
		var container: SubViewportContainer = view.get_parent()
		var camera: Camera3D = view.get_camera_3d()
		var bounds := Rect2(camera.unproject_position(Vector3(-game.session.boards[i].width/2.0,-10,0)),Vector2.ZERO)
		for x_edge in [-game.session.boards[i].width/2.0,game.session.boards[i].width/2.0]:
			for y_edge in [-10.0,10.0]:
				bounds = bounds.expand(camera.unproject_position(Vector3(x_edge,y_edge,0)))
		var board_height := bounds.size.y
		var board_width := bounds.size.x
		var left := container.position.x+bounds.position.x
		var top := container.position.y+bounds.position.y
		print("Projected ",game.session.mode," board ",i,": ",bounds)
		check(camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"True perspective camera, not orthographic")
		check(camera.rotation.is_zero_approx(),"Straight front camera has zero pitch, yaw and roll")
		for x_edge in [-game.session.boards[i].width/2.0-0.14,game.session.boards[i].width/2.0+0.14]:
			for y_edge in [-10.14,10.14]:
				for z_edge in [-0.8,0.54]:
					var projected := camera.unproject_position(Vector3(x_edge,y_edge,z_edge))
					check(projected.x>=7 and projected.x<=container.size.x-7 and projected.y>=11 and projected.y<=container.size.y-11,"Complete board frame and cube volume remain inside perspective viewport")

		check(camera.keep_aspect==Camera3D.KEEP_HEIGHT,"Perspective preserves model proportions via KEEP_HEIGHT")
		check(board_height>=850.0,"Straight front perspective preserves large readable playfields within the complete volume fit")
		check(container.size.x>=board_width+12.0,"Enlarged board retains horizontal projection margin")
		check(container.position.y+container.size.y<=1080.0,"Viewport remains inside screen bottom")
		check(top>=game.pane_labels[i].position.y+45.0,"Board scores remain above playfield")
		check(left>game.key_guide.position.x+game.key_guide.get_minimum_size().x+12.0,"Left controls remain clear of enlarged playfields")
		check(left+board_width<game.overall_score.position.x-12.0,"Upper-right standings remain clear of playfields")
		if previous_right>=0.0:
			check(left-previous_right>=12.0 and left-previous_right<=60.0,"Visible board gap is narrow without overlapping")
		previous_right = left+board_width
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game); await process_frame; game.set_process(false)
	check(game.session.boards.size()==3,"Default three FFA boards")
	check(game.pane_blocks.size()==3,"Three true 3D board renderers")
	check(game.session.boards[0].width==10,"FFA width")
	check_compact_layout(game)
	for board_root in game.pane_roots:
		check(board_root.get_child_count()==2 and board_root.has_node("PlayfieldFrame"),"Blocks plus requested 3D board frame and divisions")
	for control in game.hud.get_children():
		if control is Panel:
			check(control.get_theme_stylebox("panel") is StyleBoxEmpty,"No enclosing HUD panel or dialog chrome")
		if control is Button:
			check(control.get_theme_stylebox("normal") is StyleBoxEmpty,"Board selection has no button boxes")
	var allowed_labels: Array = [game.overall_score,game.score_state,game.key_guide]
	allowed_labels.append_array(game.pane_labels)
	for control in game.hud.get_children():
		if control is Label: check(control in allowed_labels,"All text belongs to one of the three allowed HUD regions")
		if control is Button: check(control.text.is_empty(),"No textual navigation or action buttons")
	check(game.overall_score.position.x>=1500 and game.overall_score.position.y<100,"Overall scores upper right")
	check(game.key_guide.position.x<100 and game.key_guide.text.count("\n")>=10,"Key guide vertically stacked on left")
	check(game.key_guide.text.contains("F1") and game.key_guide.text.contains("F2") and game.key_guide.text.contains("R  RESTART") and game.key_guide.text.contains("P / ESC"),"Mode, restart and pause keys remain discoverable")
	check(game.selection_marks[0].visible and not game.selection_marks[1].visible,"Nontext selection indicator")
	for blocks in game.pane_blocks: check(blocks.get_child_count()>0,"Each board draws pieces")
	var p0: Vector2i = game.session.boards[0].position
	var p1: Vector2i = game.session.boards[1].position
	key(game,KEY_2); key(game,KEY_LEFT)
	check(game.selected==1,"Select board 2")
	check(game.selection_marks[1].visible and not game.selection_marks[0].visible,"Selection marker follows keyboard selection")
	check(game.session.boards[0].position==p0,"Selected controls isolated")
	check(game.session.boards[1].position==p1+Vector2i.LEFT,"Selected controls move board2")
	key(game,KEY_UP)
	check(game.session.boards[1].successful_locks==1,"Up hard drops and locks")
	check(game.session.boards[1].rotation==0,"Up does not also rotate")
	check(game.session.boards[1].score>=10,"Successful hard drop scores")
	check(game.overall_score.text.begins_with("P2"),"Overall scoreboard sorted highest score first")
	check(game.pane_labels[1].text=="P2   %06d" % game.session.boards[1].score,"Board score updates on hard drop")
	check(game.session.boards[0].score==0,"Other board unaffected by score")
	key(game,KEY_X)
	check(game.session.boards[1].rotation==1,"X remains rotation")
	key(game,KEY_C); check(game.session.boards[1].hold_used,"C holds selected board")
	key(game,KEY_A); check(game.session.boards[0].position==p0+Vector2i.LEFT,"Independent P1 mapping")
	key(game,KEY_I); check(game.session.boards[1].successful_locks==2,"Independent P2 mapping")
	key(game,KEY_KP_8); check(game.session.boards[2].successful_locks==1,"Independent P3 mapping")
	key(game,KEY_P)
	check(game.session.paused and game.score_state.text=="PAUSED","Pause confined to overall scoreboard")
	var before: float = game.session.elapsed
	var score: int = game.session.boards[1].score
	game._process(5); key(game,KEY_UP)
	check(game.session.elapsed==before and game.session.boards[1].score==score,"Pause freezes clock and input")
	key(game,KEY_P); game._process(2)
	check(game.session.elapsed>before,"Resume clock")
	key(game,KEY_R)
	check(game.session.elapsed==0 and not game.session.paused,"Restart resets timer and pause")
	check(game.session.boards[0].score==0 and game.session.charges[0]==1,"Restart reset score/items")
	key(game,KEY_F2)
	check(game.session.mode=="team" and game.session.boards.size()==2,"F2 team mode")
	check(game.session.boards[0].width==14 and game.pane_blocks.size()==2,"Wider team boards")
	check_compact_layout(game)
	check(game.session.turns[0]==0 and game.pane_labels[0].text=="A   000000","Team score shown without seat text")
	key(game,KEY_UP)
	check(game.session.turns[0]==1,"Seat turns after lock even without seat label")
	key(game,KEY_3); check(game.selected==0,"Invalid team selection ignored")
	key(game,KEY_F11)
	check(game.demo and game.session.paused,"Demo explicitly paused")
	check(game.score_state.text.is_empty(),"Seeded showcase has no demo text or dialog")
	check(game.session.boards[0].width==14,"Demo preserves team width")
	check(game.overall_score.text=="B    002840\nA    002480","Team overall scoreboard has both ranked scores")
	key(game,KEY_R)
	check(not game.demo and game.session.elapsed==0,"Restart exits demo")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.session.paused,"Focus loss freezes all boards")
	key(game,KEY_F1)
	check(game.session.mode=="ffa" and not game.session.paused,"Mode change fresh match")
	key(game,KEY_COMMA); check(game.aim_column==3,"Aim column key")
	key(game,KEY_PERIOD); check(game.aim_column==4,"Aim other direction")
	game.aim_column=0; key(game,KEY_E)
	check(game.session.charges[0]==0,"E sends item right")
	check(game.session.boards[1].board[19][0]>=0,"Item occupies targeted neighbor column")
	check(game.key_guide.text.contains("AIM 01"),"Attack target column stays inside key guide")
	game.session.boards[0].game_over=true; game.session.boards[1].game_over=true
	game.session.check_finished(); game.refresh()
	check(game.score_state.text=="P3 WINS","Winner confined to overall scoreboard")
	check(game.pane_labels[2].modulate.a==1.0 and game.pane_labels[0].modulate.a<1.0,"Eliminated board scores dimmed without extra status text")
	key(game,KEY_R); check(not game.session.finished and game.score_state.text.is_empty(),"Restart clears end state")
	game.queue_free(); await process_frame
	print("Party runtime checks: %d passed, %d failed" % [checks-failures,failures])
	quit(1 if failures else 0)
