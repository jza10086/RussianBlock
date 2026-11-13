## Lightweight catalog data. Do not load gameplay scenes or scripts here.
extends RefCounted

static func party_definition() -> Dictionary:
	return {"player_counts": [1], "controls": {"block_left": "向左", "block_right": "向右", "block_soft_drop": "软降", "block_hard_drop": "硬降", "block_clockwise": "顺时针旋转", "block_counterclockwise": "逆时针旋转", "block_hold": "暂存", "block_restart": "重新开始", "block_pause": "暂停"}}
