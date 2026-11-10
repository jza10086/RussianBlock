extends Node3D
const Controls = preload("res://games/protocols/godot_party_default_protocol/solo_controls.gd")
const Settings = preload("res://games/minigame/gp_tetris/settings.gd")
var controls: Controls = Controls.new(Settings.schema())
var _active: bool = false
var _stopped: bool = false
var _text_source: RefCounted

signal completed(metrics: Dictionary)
const DefaultText: Translation = preload("res://games/minigame/gp_tetris/i18n/zh_Hans.po")
var _i18n: RefCounted

func hud_text(key: StringName, values: Dictionary) -> String:
	return DefaultText.get_message(key).format(values) if _i18n == null else _i18n.text(key, values)

var personal_best: int = 0
const Rules = preload("res://games/minigame/gp_tetris/scripts/tetris_rules.gd")
const RoundedCube = preload("res://games/minigame/gp_tetris/scripts/rounded_cube.gd")
const COLORS = [Color("5dd9ee"),Color("f7cd64"),Color("b49afa"),Color("7cdfbd"),Color("fb8596"),Color("81a9ff"),Color("f7a66d")]
var rules = Rules.new()
var cube: ArrayMesh
var materials: Array[StandardMaterial3D] = []
var ghost_material: StandardMaterial3D
var blocks: Node3D
var previews: Array[Control] = []
var preview_signature := ""
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
@export var speed_profile: Resource = preload("res://games/minigame/gp_tetris/assets/speed_profile.tres")
var gravity_time := 0.0
var lock_time := 0.0
var lock_resets := 0
var move_time := 0.0
var held_dir := 0
var paused := false
var demo := false
var flash_time := 0.0
var best := 0
var _completion_reported: bool = false

func _ready() -> void:
	_i18n = _text_source
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
	blocks = %Blocks
	previews = [%Next1, %Next2, %Next3]
	score_label = %ScoreLabel
	level_label = %LevelLabel
	lines_label = %LinesLabel
	status_label = %StatusLabel
	hold_label = %HoldLabel
	overlay = %Overlay
	overlay_title = %OverlayTitle
	overlay_text = %OverlayText
	pause_button = %PauseButton
	pause_button.pressed.connect(toggle_pause)
	pause_button.text = "暂停 / P" if controls.context != null else "暂停 / Esc / P"
	best = personal_best
	rules.reset()
	refresh()
	$GameHUD.hide()
	if controls.context == null:
		solo_start()
	if controls.context == null and "--demo" in OS.get_cmdline_user_args():
		set_demo()

func tile(parent:Node3D,pos:Vector3,type:int,ghost:bool=false,scale_value:float=1.0) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = cube
	mesh.material_override = ghost_material if ghost else materials[type]
	mesh.position = pos
	mesh.scale = Vector3.ONE * scale_value
	if ghost:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)

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
		for index: int in previews.size():
			update_preview(previews[index], rules.queue[index] if index < rules.queue.size() else -1)
		update_preview(%Hold, rules.held_type)
	score_label.text = "%06d" % rules.score
	level_label.text = "%02d" % rules.level
	lines_label.text = "%02d" % rules.lines
	hold_label.text = "USED THIS TURN" if rules.hold_used else "C / SHIFT"
	if rules.game_over:
		best = max(best,rules.score)
		overlay_title.text = "GAME OVER"
		overlay_text.text = hud_text(&"hud.result", {"score": rules.score, "best": best})
		overlay.show()
		status_label.text = "SESSION COMPLETE"
		if not _completion_reported:
			_completion_reported = true
			completed.emit({"score": rules.score, "lines": rules.lines})

func update_preview(slot: Control, piece_type: int) -> void:
	slot.visible = piece_type >= 0
	if slot.visible:
		slot.tint = COLORS[piece_type]
		slot.cells = rules.cells(piece_type, 0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not controls.allowed():
		return
	if controls.matches(event, &"block_restart"):
		restart()
		return
	if controls.matches(event, &"block_pause") or (controls.context == null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		toggle_pause()
		return
	if paused or rules.game_over:
		return
	var changed := false
	if controls.matches(event, &"block_left"):
		changed = rules.move(-1,0)
		held_dir = -1
		move_time = -0.14
	elif controls.matches(event, &"block_right"):
		changed = rules.move(1,0)
		held_dir = 1
		move_time = -0.14
	elif controls.matches(event, &"block_clockwise"):
		changed = rules.rotate_piece(1)
	elif controls.matches(event, &"block_counterclockwise"):
		changed = rules.rotate_piece(-1)
	elif controls.matches(event, &"block_hard_drop"):
		var old_lines: int = rules.lines
		rules.hard_drop()
		on_lock(old_lines)
		changed = true
	elif controls.matches(event, &"block_hold"):
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
	if not _active:
		return
	if flash_time > 0:
		flash_time -= delta
		if flash_time <= 0:
			status_label.text = "DEMO · R FOR NEW GAME" if demo else "READY TO STACK"
	if paused or rules.game_over:
		return
	elapsed += delta
	var dir := 0
	if controls.is_pressed(&"block_left"): dir -= 1
	if controls.is_pressed(&"block_right"): dir += 1
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
	var soft := controls.is_pressed(&"block_soft_drop")
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
	if not controls.allowed():
		return
	if rules.game_over: return
	paused = not paused
	overlay_title.text = "PAUSED"
	overlay_text.text = "Take a breath.\nP to resume · Esc opens menu" if controls.context != null else "Take a breath.\nESC / P to resume"
	overlay.visible = paused
	pause_button.text = "RESUME   /   P" if paused else "PAUSE   /   P"

func restart() -> void:
	_completion_reported = false
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
	pause_button.text = "PAUSE   /   P"
	status_label.text = "READY TO STACK"
	refresh()

func set_demo() -> void:
	restart()
	rules.demo_setup()
	demo = true
	status_label.text = "DEMO · R FOR NEW GAME"
	refresh()


func _notification(what:int) -> void:
	if controls.context == null and what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(overlay) and not paused and not rules.game_over:
		toggle_pause()

## Injected before entering the tree. F6 leaves the formal dependencies unset.
func solo_setup(input: PartyInput, text_source: RefCounted) -> void:
	controls.bind(input)
	_text_source = text_source


func solo_start() -> void:
	if _stopped:
		return
	_active = true
	controls.enabled = true
	$GameHUD.show()

func solo_stop() -> void:
	if _stopped:
		return
	_stopped = true
	_active = false
	controls.enabled = false
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)
	if not is_node_ready():
		return
	held_dir = 0
	move_time = 0.0
	$GameHUD.hide()

func solo_graphics_targets() -> Dictionary:
	return {"world": $WorldEnvironment1, "sun": $DirectionalLight3D2}

func solo_audio_target() -> PartyGameAudio:
	return null
