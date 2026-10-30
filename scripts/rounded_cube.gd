extends RefCounted
static func create_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples := [-0.48,-0.465,-0.44,-0.405,-0.34,0.0,0.34,0.405,0.44,0.465,0.48]
	var frames := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT],
		[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.RIGHT, Vector3.BACK, Vector3.DOWN]]
	for frame in frames:
		for i in range(samples.size()-1):
			for j in range(samples.size()-1):
				for ij in [Vector2i(i,j),Vector2i(i+1,j+1),Vector2i(i+1,j),Vector2i(i,j),Vector2i(i,j+1),Vector2i(i+1,j+1)]:
					var p: Vector3 = frame[0]*samples[ij.x] + frame[1]*samples[ij.y] + frame[2]*0.48
					var core := p.clamp(Vector3.ONE*-0.34, Vector3.ONE*0.34)
					var normal := (p-core).normalized()
					st.set_normal(normal)
					st.add_vertex(core+normal*0.14)
	st.index()
	return st.commit()
