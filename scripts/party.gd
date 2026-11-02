extends "res://games/minigame/godot_party_default_russian_block/scripts/main.gd"
const Session = preload("res://games/minigame/godot_party_default_russian_block/scripts/battle_session.gd")
var session = Session.new()
var selected := 0
var aim_column := 4
var pane_roots: Array[Node3D] = []
var pane_blocks: Array[Node3D] = []
var pane_labels: Array[Label] = []
var selection_marks: Array[ColorRect] = []
var pane_views: Array[SubViewport] = []
var accents := [Color("63dbe9"),Color("b89bff"),Color("ffc774")]
var overall_score: Label
var score_state: Label
var key_guide: Label
var screenshot_path := ""
var repeat_timers := {}

func _ready() -> void:
	blocks.free(); board_root.free()
	if "--classic" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://games/minigame/godot_party_default_russian_block/classic.tscn")
		return
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
	if is_instance_valid(hud): hud.get_parent().free()
	pane_roots.clear(); pane_blocks.clear(); pane_labels.clear(); selection_marks.clear(); pane_views.clear()
	var layer := CanvasLayer.new(); add_child(layer)
	hud = Control.new(); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(hud)
	var bg := ColorRect.new(); bg.color = Color("080f1d"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.add_child(bg)
	# The only HUD regions: upper-right standings, board scores, left key guide.
	overall_score = label("",Vector2(1694,42),22,Color("d9e6f1"))
	overall_score.size.x = 188; overall_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	overall_score.add_theme_constant_override("line_spacing",9)
	score_state = label("",Vector2(1694,166),15,Color("8095aa"))
	score_state.size.x = 188; score_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_guide = label("",Vector2(48,265),18,Color("8193a7"))
	key_guide.add_theme_constant_override("line_spacing",19)
	for i in session.boards.size(): build_pane(i)
	# Quiet separators between playfields, not enclosing HUD cards.
	for i in range(1, session.boards.size()):
		var divider := ColorRect.new(); divider.name = "BoardDivider%d" % i
		divider.color = Color("29384a")
		divider.position = Vector2(986 if session.mode == "team" else 296 + i * 460, 145)
		divider.size = Vector2(1, 887); divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(divider)

func board_name(index: int) -> String:
	return ("A" if index == 0 else "B") if session.mode == "team" else "P%d" % (index+1)

func build_pane(index: int) -> void:
	var team: bool = session.mode == "team"
	# Use nearly the full screen height and pack viewports closely together.
	# Reserve a narrow left key column and right standings column; neither
	# sits over a playfield. Camera KEEP_HEIGHT keeps cube proportions intact.
	var w := 652.0 if team else 460.0
	var x := 333.0 + index * 654.0 if team else 296.0 + index * 460.0
	var scores := label("",Vector2(x,60),26,Color("d9e6f1")); scores.size.x = w; scores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pane_labels.append(scores)
	var mark := ColorRect.new(); mark.color = accents[index]; mark.position = Vector2(x+w/2-13,105); mark.size = Vector2(26,3); mark.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(mark); selection_marks.append(mark)
	var container := SubViewportContainer.new()
	container.position = Vector2(x,102); container.size = Vector2(w,968)
	container.stretch = true; container.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud.add_child(container)
	var viewport := SubViewport.new(); viewport.size = Vector2i(w,968); viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X; container.add_child(viewport); pane_views.append(viewport)
	var world := Node3D.new(); viewport.add_child(world); environment_for(world)
	var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect = Camera3D.KEEP_HEIGHT; camera.fov = 18.0
	camera.near = 0.1; camera.far = 150.0; world.add_child(camera)
	var root := Node3D.new(); world.add_child(root); pane_roots.append(root)
	var b := Node3D.new(); root.add_child(b); pane_blocks.append(b)
	var width: int = session.boards[index].width
	# A recessed, lit playfield receives the blocks' shadows. Thin 3D rails
	# enclose the legal cells; low-contrast cell divisions clarify alignment.
	var backing := Node3D.new(); backing.name = "PlayfieldFrame"; root.add_child(backing)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("142237"); mat.roughness = 0.88
	box(backing,Vector3(width+0.20,20.20,0.18),Vector3(0,0,-0.70),mat)
	var grid := StandardMaterial3D.new(); grid.albedo_color = Color("22334a")
	grid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for x_cell in range(1,width):
		box(backing,Vector3(0.012,20,0.012),Vector3(x_cell-width/2.0,0,-0.598),grid)
	for y_cell in range(1,20):
		box(backing,Vector3(width,0.012,0.012),Vector3(0,y_cell-10,-0.598),grid)
	var rail := StandardMaterial3D.new(); rail.albedo_color = Color("68849c")
	rail.metallic = 0.32; rail.roughness = 0.34
	for side in [-1,1]:
		box(backing,Vector3(0.10,20.20,0.48),Vector3(side*(width/2.0+0.05),0,-0.39),rail)
		box(backing,Vector3(width+0.20,0.10,0.48),Vector3(0,side*10.05,-0.39),rail)
	var fill := OmniLight3D.new(); fill.position = Vector3(5,3,8)
	fill.light_color = Color("8cacdf"); fill.light_energy = 0.30; fill.omni_range = 26; world.add_child(fill)
	fit_perspective_camera(camera,width,Vector2(w,968))
	# Clicking the board keeps pointer selection without a separate SELECT button.
	var hit := Button.new(); hit.position = container.position; hit.size = container.size
	for state in ["normal","hover","pressed","focus"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	hit.focus_mode = Control.FOCUS_NONE; hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.pressed.connect(func(): select_board(index)); hud.add_child(hit)

# Fit all eight corners of the complete board volume, including frontmost
# cubes and rear frame. Keep a genuine pinhole camera centered straight
# ahead with zero pitch, yaw and roll; depth still changes projected size.
func fit_perspective_camera(camera: Camera3D, width: int, viewport_size: Vector2) -> void:
	var direction := Vector3.BACK
	var tan_half := tan(deg_to_rad(camera.fov)*0.5)
	var aspect := viewport_size.x / viewport_size.y
	var distance := 25.0
	for attempt in 1600:
		camera.look_at_from_position(direction*distance,Vector3.ZERO)
		var fits := true
		for x_edge in [-width/2.0-0.14,width/2.0+0.14]:
			for y_edge in [-10.14,10.14]:
				for z_edge in [-0.8,0.54]:
					var local := camera.global_transform.affine_inverse()*Vector3(x_edge,y_edge,z_edge)
					var half_height := -local.z*tan_half
					if abs(local.x)>half_height*aspect*(1.0-16.0/viewport_size.x) or abs(local.y)>half_height*(1.0-24.0/viewport_size.y):
						fits = false
		if fits: break
		distance += 0.05

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
		pane_labels[i].text = "%s   %06d" % [board_name(i),r.score]
		pane_labels[i].modulate.a = 0.4 if r.game_over else 1.0
		selection_marks[i].visible = selected == i
		pane_views[i].render_target_update_mode = SubViewport.UPDATE_ALWAYS
	update_status()

func update_status() -> void:
	if not is_instance_valid(overall_score): return
	var ranked: Array = range(session.boards.size())
	ranked.sort_custom(func(a, b): return session.boards[a].score > session.boards[b].score if session.boards[a].score != session.boards[b].score else a < b)
	var rows := PackedStringArray()
	for i in ranked: rows.append("%s    %06d" % [board_name(i),session.boards[i].score])
	overall_score.text = "\n".join(rows)
	score_state.text = ((board_name(session.winner)+" WINS") if session.winner >= 0 else "DRAW") if session.finished else ("PAUSED" if session.paused and not demo else "")
	key_guide.text = "1 / 2%s  SELECT\nTAB  NEXT BOARD\n← / →  MOVE\n↑ / SPACE  DROP\nX / Z  ROTATE\n↓  SOFT DROP\nC  HOLD\nQ / E  ATTACK\n, / .  AIM %02d\nP / ESC  PAUSE\nR  RESTART\nF1  FREE FOR ALL\nF2  TEAM" % [" / 3" if session.mode == "ffa" else "",aim_column+1]

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
