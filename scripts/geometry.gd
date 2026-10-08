extends RefCounted
## Small shared builders. No per-frame geometry or materials are allocated.

static func material(color: Color, metal: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.72
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, mat)

static func sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 16
	shape.rings = 8
	return mesh(parent, shape, pos, mat)

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	return mesh(parent, shape, pos, mat)

static func label(parent: Node3D, words: String, pos: Vector3, font_size: int, color: Color) -> Label3D:
	var node := Label3D.new()
	node.text = words
	node.position = pos
	node.font_size = font_size
	node.pixel_size = 0.008
	node.modulate = color
	node.outline_size = 2
	parent.add_child(node)
	return node
