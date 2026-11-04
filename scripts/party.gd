extends "res://games/minigame/godot_party_default_russian_block/scripts/main.gd"
const Session = preload("res://games/minigame/godot_party_default_russian_block/scripts/battle_session.gd")
var session = Session.new()
var selected := 0
var aim_column := 4
var pane_blocks: Array[Node3D] = []
var pane_labels: Array[Label] = []
var selection_marks: Array[ColorRect] = []
var overall_score: Label
var score_state: Label
var key_guide: Label
var screenshot_path := ""
var repeat_timers := {}

func _ready() -> void:
	if "--classic" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://games/minigame/godot_party_default_russian_block/classic.tscn")
		return
	for layout: Node3D in [$FreeForAll, $Team]:
		var buttons: Array[Node] = layout.find_children("Select*", "Button", true, false)
		for index: int in buttons.size():
			buttons[index].pressed.connect(select_board.bind(index))
	session.speed_profile = speed_profile
	cube = RoundedCube.create_mesh()
	for color in COLORS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color; mat.roughness = 0.30; mat.metallic_specular = 0.42
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials.append(mat)
	ghost_material = StandardMaterial3D.new()
	ghost_material.albedo_color = Color(0.43,0.8,0.9,0.16)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	session.reset("team" if "--team" in OS.get_cmdline_user_args() else "ffa")
	build_hud()
	refresh()
	if "--demo" in OS.get_cmdline_user_args(): set_demo()

func build_hud() -> void:
	var team: bool = session.mode == "team"
	$Team.visible = team
	$Team/GameHUD.visible = team
	$FreeForAll.visible = not team
	$FreeForAll/GameHUD.visible = not team
	var layout: Node3D = $Team if team else $FreeForAll
	overall_score = layout.get_node("%OverallScore")
	score_state = layout.get_node("%ScoreState")
	key_guide = layout.get_node("%KeyGuide")
	pane_blocks.clear()
	pane_labels.clear()
	selection_marks.clear()
	for index: int in session.boards.size():
		var suffix: String = str(index + 1)
		pane_blocks.append(layout.get_node("Board" + suffix + "/Blocks"))
		pane_labels.append(layout.get_node("%Score" + suffix))
		selection_marks.append(layout.get_node("%Mark" + suffix))

func board_name(index: int) -> String:
	return ("A" if index == 0 else "B") if session.mode == "team" else "P%d" % (index + 1)

func select_board(index: int) -> void:
	if index >= session.boards.size(): return
	selected = index; aim_column = clampi(aim_column,0,session.boards[index].width-1)
	refresh()

func refresh() -> void:
	if pane_blocks.is_empty(): return
	for i in session.boards.size():
		var r = session.boards[i]
		var b := pane_blocks[i]
		for child in b.get_children(): child.free()
		for y in 20:
			for x in r.width:
				if r.board[y][x] >= 0: tile(b,Vector3(x-(r.width-1)/2.0,9.5-y,0),r.board[y][x])
		if not r.game_over:
			var ghost: Vector2i = r.ghost_position()
			for c in r.cells():
				var p: Vector2i = c+ghost
				if p.y >= 0: tile(b,Vector3(p.x-(r.width-1)/2.0,9.5-p.y,-0.02),r.current_type,true)
			for p in r.current_cells():
				if p.y >= 0: tile(b,Vector3(p.x-(r.width-1)/2.0,9.5-p.y,0.04),r.current_type)
		pane_labels[i].text = hud_text(&"hud.board_score", {"board": board_name(i), "score": "%06d" % r.score})
		pane_labels[i].modulate.a = 0.4 if r.game_over else 1.0
		selection_marks[i].visible = selected == i
	update_status()

func update_status() -> void:
	if not is_instance_valid(overall_score): return
	var ranked: Array = range(session.boards.size())
	ranked.sort_custom(func(a, b): return session.boards[a].score > session.boards[b].score if session.boards[a].score != session.boards[b].score else a < b)
	var rows := PackedStringArray()
	for i in ranked: rows.append(hud_text(&"hud.board_score", {"board": board_name(i), "score": "%06d" % session.boards[i].score}))
	overall_score.text = "\n".join(rows)
	score_state.text = ((board_name(session.winner)+" WINS") if session.winner >= 0 else "DRAW") if session.finished else ("PAUSED" if session.paused and not demo else "")
	key_guide.text = hud_text(&"hud.guide", {"third": " / 3" if session.mode == "ffa" else "", "aim": "%02d" % (aim_column + 1)})

func change_mode(mode: String) -> void:
	session.reset(mode); selected = 0; aim_column = 6 if mode=="team" else 4; demo = false; repeat_timers.clear()
	build_hud(); refresh()

func restart() -> void:
	change_mode(session.mode)

func toggle_pause() -> void:
	if session.finished: return
	session.paused = not session.paused; update_status()

func set_demo() -> void:
	restart()
	for i in session.boards.size():
		var r = session.boards[i]
		r.demo_setup()
		# Different silhouettes for the paused, seeded showcase.
		if i==1:
			for y in range(15,20): r.board[y].reverse()
		r.position = Vector2i(int((r.width-4)/2),4+i)
		r.score = 2480+i*360
		session.charges[i] = 2
		session.turns[i] = i%2
	session.elapsed = 96; session.paused = true; demo = true
	refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var code: int = event.keycode
	if code == KEY_F12: capture(); return
	if code == KEY_F11: set_demo(); return
	if code == KEY_F1: change_mode("ffa"); return
	if code == KEY_F2: change_mode("team"); return
	if code == KEY_R: restart(); return
	if code in [KEY_ESCAPE,KEY_P]: toggle_pause(); return
	if code in [KEY_1,KEY_2,KEY_3]: select_board(code-KEY_1); return
	if code == KEY_TAB: select_board((selected+1)%session.boards.size()); return
	if code in [KEY_COMMA,KEY_PERIOD]:
		aim_column = clampi(aim_column+(-1 if code==KEY_COMMA else 1),0,session.boards[selected].width-1); update_status(); return
	var common := {KEY_LEFT:"left",KEY_RIGHT:"right",KEY_UP:"drop",KEY_SPACE:"drop",KEY_X:"rotate",KEY_Z:"rotate_back",KEY_C:"hold",KEY_Q:"attack_left",KEY_E:"attack_right"}
	if common.has(code):
		apply_action(selected,common[code]); return
	var maps := [{KEY_A:"left",KEY_D:"right",KEY_W:"drop",KEY_F:"rotate",KEY_G:"hold",KEY_H:"attack_right"},{KEY_J:"left",KEY_L:"right",KEY_I:"drop",KEY_O:"rotate",KEY_U:"hold",KEY_Y:"attack_left"},{KEY_KP_4:"left",KEY_KP_6:"right",KEY_KP_8:"drop",KEY_KP_5:"rotate",KEY_KP_0:"hold",KEY_KP_7:"attack_left"}]
	for i in session.boards.size():
		if maps[i].has(code): apply_action(i,maps[i][code]); return

func apply_action(index: int, action: String) -> void:
	if session.submit_action(index,action,aim_column): refresh()

func _process(delta: float) -> void:
	if pane_blocks.is_empty(): return
	var soft: Array = []
	if Input.is_physical_key_pressed(KEY_DOWN): soft.append(selected)
	for pair in [[0,KEY_S],[1,KEY_K],[2,KEY_KP_2]]:
		if pair[0]<session.boards.size() and Input.is_physical_key_pressed(pair[1]): soft.append(pair[0])
	if not session.paused and not session.finished:
		for binding in [[selected,KEY_LEFT,"left"],[selected,KEY_RIGHT,"right"],[0,KEY_A,"left"],[0,KEY_D,"right"],[1,KEY_J,"left"],[1,KEY_L,"right"],[2,KEY_KP_4,"left"],[2,KEY_KP_6,"right"]]:
			var keycode: int = binding[1]
			if binding[0]>=session.boards.size(): continue
			if Input.is_physical_key_pressed(keycode):
				repeat_timers[keycode] = float(repeat_timers.get(keycode,0))+delta
				if repeat_timers[keycode]>0.19:
					session.submit_action(binding[0],binding[2]); repeat_timers[keycode] = 0.135; refresh()
			else: repeat_timers.erase(keycode)
	if session.tick(delta,soft): refresh()
	update_status()

func capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://games/minigame/godot_party_default_russian_block/screenshots"))
	screenshot_path = "res://games/minigame/godot_party_default_russian_block/screenshots/02_ffa.png" if session.mode=="ffa" else "res://games/minigame/godot_party_default_russian_block/screenshots/03_team.png"
	var result := get_viewport().get_texture().get_image().save_png(screenshot_path)
	print("Screenshot: ",ProjectSettings.globalize_path(screenshot_path)," result=",result)

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(overall_score) and not session.finished:
		session.paused = true; update_status()
