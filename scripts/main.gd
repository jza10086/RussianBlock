extends Node3D
const Rules = preload("res://scripts/tetris_rules.gd")
const RoundedCube = preload("res://scripts/rounded_cube.gd")
const COLORS = [Color("5dd9ee"),Color("f7cd64"),Color("b49afa"),Color("7cdfbd"),Color("fb8596"),Color("81a9ff"),Color("f7a66d")]
var rules = Rules.new()
var cube: ArrayMesh
var materials: Array[StandardMaterial3D] = []
var ghost_material: StandardMaterial3D
var blocks := Node3D.new()
var board_root := Node3D.new()
var previews: Array[SubViewportContainer] = []
var preview_signature := ""
var hud: Control
var score_label: Label
var level_label: Label
var lines_label: Label
var status_label: Label
var hold_label: Label
var overlay: Panel
var overlay_title: Label
var overlay_text: Label
var pause_button: Button
var elapsed := 0.0
@export var speed_profile: Resource = preload("res://assets/speed_profile.tres")
var gravity_time := 0.0
var lock_time := 0.0
var lock_resets := 0
var move_time := 0.0
var held_dir := 0
var paused := false
var demo := false
var flash_time := 0.0
var best := 0
var save_path := "user://best.cfg"

func _ready() -> void:
	cube = RoundedCube.create_mesh()
	for color in COLORS:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.38
		mat.metallic = 0.0
		mat.metallic_specular = 0.32
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials.append(mat)
	ghost_material = StandardMaterial3D.new()
	ghost_material.albedo_color = Color(0.43,0.8,0.9,0.15)
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	build_world()
	build_hud()
	var config := ConfigFile.new()
	if config.load(save_path) == OK:
		best = int(config.get_value("game", "best", 0))
	rules.reset()
	refresh()
	if "--demo" in OS.get_cmdline_user_args():
		set_demo()

func environment_for(parent:Node) -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("080f1d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b7c9ef")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	parent.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25,-30,0)
	key.light_color = Color("eff9ff")
	key.light_energy = 0.72
	key.shadow_enabled = true
	parent.add_child(key)

func build_world() -> void:
	environment_for(self)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24.0
	camera.position = Vector3(3.2,2.6,40)
	camera.look_at_from_position(camera.position,Vector3.ZERO)
	camera.current = true
	add_child(camera)
	var rim := OmniLight3D.new()
	rim.position = Vector3(8,6,7)
	rim.omni_range = 24
	rim.light_color = Color("749dff")
	rim.light_energy = 0.35
	add_child(rim)
	add_child(board_root)
	board_root.position.y = -0.65
	board_root.add_child(blocks)
	var back_mat := StandardMaterial3D.new()
	back_mat.albedo_color = Color("101d30")
	back_mat.roughness = 0.8
	box(board_root,Vector3(10.35,20.35,0.32),Vector3(0,0,-0.76),back_mat)
	var grid_mat := StandardMaterial3D.new()
	grid_mat.albedo_color = Color("23344c")
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for x in range(11):
		box(board_root,Vector3(0.015,20,0.012),Vector3(x-5,0,-0.585),grid_mat)
	for y in range(21):
		box(board_root,Vector3(10,0.015,0.012),Vector3(0,y-10,-0.585),grid_mat)
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color("48708a")
	edge.metallic = 0.65
	for x in [-5.18,5.18]:
		box(board_root,Vector3(0.09,20.45,0.4),Vector3(x,0,-0.45),edge)
	box(board_root,Vector3(10.45,0.10,0.4),Vector3(0,-10.2,-0.45),edge)

func box(parent:Node3D,size:Vector3,pos:Vector3,mat:Material) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = mat
	parent.add_child(mesh)

func tile(parent:Node3D,pos:Vector3,type:int,ghost:bool=false,scale_value:float=1.0) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = cube
	mesh.material_override = ghost_material if ghost else materials[type]
	mesh.position = pos
	mesh.scale = Vector3.ONE * scale_value
	if ghost:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	label("ROUND / STACK",Vector2(180,88),34,Color("eff8ff"))
	label("THE SOFT EDGE OF TETRIS",Vector2(182,137),14,Color("6d879e"))
	label("01",Vector2(180,222),18,Color("64d9ea"))
	label("SOLO SESSION",Vector2(221,220),18,Color("9db0c6"))
	panel(Rect2(180,285,380,245),Color("101c2d"))
	label("SCORE",Vector2(212,310),16,Color("819ab2"))
	score_label = label("000000",Vector2(208,337),64,Color("f3f8fe"))
	label("LEVEL",Vector2(214,443),14,Color("819ab2"))
	level_label = label("01",Vector2(214,465),28,Color("eff8ff"))
	label("LINES",Vector2(380,443),14,Color("819ab2"))
	lines_label = label("00",Vector2(380,465),28,Color("eff8ff"))
	panel(Rect2(180,552,380,192),Color("101c2d"))
	label("HOLD",Vector2(212,575),16,Color("819ab2"))
	hold_label = label("C  /  SHIFT",Vector2(400,575),14,Color("526f89"))
	label("Keep one piece for later",Vector2(212,706),14,Color("526f89"))
	label("MOVE",Vector2(184,794),14,Color("69839d"))
	label("←  →",Vector2(361,788),24,Color("d2dfef"))
	label("ROTATE",Vector2(184,836),14,Color("69839d"))
	label("X     /     Z",Vector2(360,832),20,Color("d2dfef"))
	label("SOFT DROP",Vector2(184,878),14,Color("69839d"))
	label("↓",Vector2(361,871),24,Color("d2dfef"))
	label("HARD DROP",Vector2(184,920),14,Color("69839d"))
	label("↑ / SPACE",Vector2(361,918),18,Color("d2dfef"))
	label("CLASSIC 10 × 20",Vector2(740,39),17,Color("93abc3"))
	label("3D / SINGLE PLAYER",Vector2(1328,93),14,Color("6d879e"))
	panel(Rect2(1320,155,360,514),Color("101c2d"))
	label("UP NEXT",Vector2(1352,185),17,Color("b8cadd"))
	label("7–BAG RANDOMIZER",Vector2(1352,627),13,Color("526f89"))
	status_label = label("READY TO STACK",Vector2(1325,716),18,Color("6edeca"))
	label("Rounded forms. Classic rules.\nFind your rhythm, clear the rows.",Vector2(1325,754),17,Color("819ab2"))
	pause_button = button("PAUSE   /   ESC",Rect2(1320,845,360,58),toggle_pause)
	button("RESTART   /   R",Rect2(1320,917,360,58),restart)
	button("PARTY MODES",Rect2(180,220,380,48),func(): get_tree().change_scene_to_file("res://main.tscn"))
	label("PROTOTYPE 01",Vector2(181,1010),12,Color("415974"))
	label("F11  DEMO     ·     F12  SCREENSHOT",Vector2(1319,1010),12,Color("415974"))
	overlay = panel(Rect2(654,355,612,325),Color(0.03,0.07,0.12,0.97))
	overlay_title = label("PAUSED",Vector2(693,397),46,Color("eff8ff"))
	overlay_text = label("Take a breath.\nESC / P to resume",Vector2(698,478),22,Color("91acc4"))
	for item in [overlay_title,overlay_text]:
		var old_pos: Vector2 = item.position
		item.reparent(overlay)
		item.position = old_pos-overlay.position
	overlay.visible = false

func label(text:String,pos:Vector2,size:int,color:Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	hud.add_child(l)
	return l

func panel(rect:Rect2,color:Color) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(18)
	style.set_border_width_all(1)
	style.border_color = Color("20314a")
	p.add_theme_stylebox_override("panel",style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(p)
	return p

func button(text:String,rect:Rect2,action:Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",17)
	for state in ["normal","hover","pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("14283b") if state == "normal" else Color("25455f")
		style.set_corner_radius_all(10)
		style.set_border_width_all(1)
		style.border_color = Color("35516c")
		b.add_theme_stylebox_override(state,style)
	b.pressed.connect(action)
	hud.add_child(b)
	return b

func refresh() -> void:
	for child in blocks.get_children():
		child.free()
	for y in range(20):
		for x in range(10):
			if rules.board[y][x] >= 0:
				tile(blocks,Vector3(x-4.5,9.5-y,0),rules.board[y][x])
	if not rules.game_over:
		var ghost: Vector2i = rules.ghost_position()
		for cell in rules.cells():
			var p: Vector2i = cell+ghost
			if p.y >= 0:
				tile(blocks,Vector3(p.x-4.5,9.5-p.y,-0.02),rules.current_type,true)
		for p in rules.current_cells():
			if p.y >= 0:
				tile(blocks,Vector3(p.x-4.5,9.5-p.y,0.04),rules.current_type)
	var signature := str(rules.queue.slice(0,3))+str(rules.held_type)
	if signature != preview_signature:
		preview_signature = signature
		for container in previews:
			container.queue_free()
		previews.clear()
		for i in range(min(3,rules.queue.size())):
			preview_piece(rules.queue[i],Vector2(1500,285+i*132),1.0 if i==0 else 0.85)
		if rules.held_type >= 0:
			preview_piece(rules.held_type,Vector2(365,655),0.95)
	score_label.text = "%06d" % rules.score
	level_label.text = "%02d" % rules.level
	lines_label.text = "%02d" % rules.lines
	hold_label.text = "USED THIS TURN" if rules.hold_used else "C / SHIFT"
	if rules.game_over:
		best = max(best,rules.score)
		var config := ConfigFile.new()
		config.set_value("game","best",best)
		config.save(save_path)
		overlay_title.text = "GAME OVER"
		overlay_text.text = "Score %d  ·  Best %d\nPress R to play again" % [rules.score,best]
		overlay.show()
		status_label.text = "SESSION COMPLETE"

func preview_piece(type:int,pixel:Vector2,s:float) -> void:
	var container := SubViewportContainer.new()
	container.position = pixel-Vector2(110,50)
	container.size = Vector2(220,100)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(container)
	previews.append(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(440,200)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)
	environment_for(root)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.2
	camera.position = Vector3(0.9,0.6,10)
	camera.look_at_from_position(camera.position,Vector3.ZERO)
	root.add_child(camera)
	var cells: Array = rules.cells(type,0)
	var avg := Vector2.ZERO
	for c in cells:
		avg += Vector2(c)
	avg /= 4.0
	for c in cells:
		tile(root,Vector3((c.x-avg.x)*s,-(c.y-avg.y)*s,0),type,false,s)

func _unhandled_key_input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F12:
		capture()
		return
	if event.keycode == KEY_F11:
		set_demo()
		return
	if event.keycode == KEY_R:
		restart()
		return
	if event.keycode in [KEY_ESCAPE,KEY_P]:
		toggle_pause()
		return
	if paused or rules.game_over:
		return
	var changed := false
	if event.keycode in [KEY_LEFT,KEY_A]:
		changed = rules.move(-1,0)
		held_dir = -1
		move_time = -0.14
	elif event.keycode in [KEY_RIGHT,KEY_D]:
		changed = rules.move(1,0)
		held_dir = 1
		move_time = -0.14
	elif event.keycode == KEY_X:
		changed = rules.rotate_piece(1)
	elif event.keycode == KEY_Z:
		changed = rules.rotate_piece(-1)
	elif event.keycode in [KEY_UP,KEY_SPACE]:
		var old_lines: int = rules.lines
		rules.hard_drop()
		on_lock(old_lines)
		changed = true
	elif event.keycode in [KEY_C,KEY_SHIFT]:
		changed = rules.hold_piece()
		if changed:
			gravity_time = 0
			lock_time = 0
			lock_resets = 0
	if changed:
		if lock_resets < 15:
			lock_time = 0
			lock_resets += 1
		refresh()

func _process(delta:float) -> void:
	if flash_time > 0:
		flash_time -= delta
		if flash_time <= 0:
			status_label.text = "DEMO · R FOR NEW GAME" if demo else "READY TO STACK"
	if paused or rules.game_over:
		return
	elapsed += delta
	var dir := 0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A): dir -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D): dir += 1
	if dir != held_dir:
		held_dir = dir
		move_time = -0.14
	if dir != 0:
		move_time += delta
		if move_time >= 0.055:
			move_time = 0
			if rules.move(dir,0):
				if lock_resets < 15:
					lock_time = 0
					lock_resets += 1
				refresh()
	var soft := Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)
	gravity_time += delta
	var interval:float = speed_profile.interval(elapsed)
	if soft: interval = 0.035
	if gravity_time >= interval:
		gravity_time = 0
		if rules.move(0,1):
			if soft: rules.score += 1
			lock_time = 0
			refresh()
	if not rules.valid(rules.position+Vector2i.DOWN,rules.rotation):
		lock_time += delta
		if lock_time >= 0.5:
			var old_lines: int = rules.lines
			rules.lock_piece()
			on_lock(old_lines)
			refresh()
	else:
		lock_time = 0

func on_lock(old_lines:int) -> void:
	gravity_time = 0
	lock_time = 0
	lock_resets = 0
	var cleared: int = rules.lines-old_lines
	if cleared > 0:
		status_label.text = ["","SINGLE","DOUBLE","TRIPLE","TETRIS"][cleared]+" · LINE CLEAR"
		flash_time = 1.8

func toggle_pause() -> void:
	if rules.game_over: return
	paused = not paused
	overlay_title.text = "PAUSED"
	overlay_text.text = "Take a breath.\nESC / P to resume"
	overlay.visible = paused
	pause_button.text = "RESUME   /   ESC" if paused else "PAUSE   /   ESC"

func restart() -> void:
	elapsed = 0
	rules.reset()
	paused = false
	demo = false
	gravity_time = 0
	lock_time = 0
	lock_resets = 0
	held_dir = 0
	flash_time = 0
	overlay.hide()
	pause_button.text = "PAUSE   /   ESC"
	status_label.text = "READY TO STACK"
	refresh()

func set_demo() -> void:
	restart()
	rules.demo_setup()
	demo = true
	status_label.text = "DEMO · R FOR NEW GAME"
	refresh()

func capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var path := "res://screenshots/01_gameplay.png"
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("Screenshot: ",ProjectSettings.globalize_path(path)," result=",err)

func _notification(what:int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(overlay) and not paused and not rules.game_over:
		toggle_pause()
