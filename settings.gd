extends RefCounted
## Local bindings shared by formal input and F6 defaults. Reading does not persist them.
static func schema() -> Dictionary:
	var fields: Dictionary = {
		"block_left": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_LEFT, "physical": true}, {"kind": "key", "code": KEY_A, "physical": true}],
			"title": "向左", "action": "block_left", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"block_right": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_RIGHT, "physical": true}, {"kind": "key", "code": KEY_D, "physical": true}],
			"title": "向右", "action": "block_right", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"block_soft_drop": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_DOWN, "physical": true}, {"kind": "key", "code": KEY_S, "physical": true}],
			"title": "软降", "action": "block_soft_drop", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"block_hard_drop": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_UP, "physical": true}, {"kind": "key", "code": KEY_SPACE, "physical": true}],
			"title": "硬降", "action": "block_hard_drop", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"block_clockwise": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_X, "physical": true}],
			"title": "顺时针旋转", "action": "block_clockwise", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"block_counterclockwise": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_Z, "physical": true}],
			"title": "逆时针旋转", "action": "block_counterclockwise", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"block_hold": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_C, "physical": true}, {"kind": "key", "code": KEY_SHIFT, "physical": true}],
			"title": "暂存", "action": "block_hold", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"block_restart": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_R, "physical": true}],
			"title": "重新开始", "action": "block_restart", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"block_pause": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_P, "physical": true}],
			"title": "暂停", "action": "block_pause", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false}
	}
	var layout: Array[Dictionary] = []
	for key: String in fields:
		layout.append({"field": key})
	return {"schema_format": 3, "settings_version": 1, "fields": fields, "layout": layout}
