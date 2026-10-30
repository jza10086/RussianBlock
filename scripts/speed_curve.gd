extends Control
var elapsed := 0.0
var profile = preload("res://assets/speed_profile.tres")
const Session = preload("res://scripts/battle_session.gd")
func _draw() -> void:
	var points := PackedVector2Array()
	for i in 101:
		var t := i * 4.0
		points.append(Vector2(i * size.x / 100.0, size.y * profile.interval(t) / profile.start_interval))
	draw_line(Vector2(0,size.y),size,Color("304259"),1)
	draw_polyline(points,Color("68e4c6"),2.5,true)
	var x := minf(elapsed / 400, 1) * size.x
	var y: float = size.y * profile.interval(elapsed) / profile.start_interval
	draw_circle(Vector2(x,y),5,Color("f5d17c"))
