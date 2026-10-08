extends Node3D
const Geo = preload("res://scripts/geometry.gd")

var obstacles: Array[AABB] = []
var nav := AStarGrid2D.new()
var exit_door: Node3D
var exit_light: OmniLight3D
var flicker_light: OmniLight3D
var batch_count := 0
var source_mesh_count := 0

func _ready() -> void:
	name = "Diner"
	_import_diner()
	_collision()
	_ball_pit()
	_play_tubes()
	_decorate()
	_navigation()

func _import_diner() -> void:
	# The diner export contains the room, booths, counter and pit enclosure.
	# textures.glb duplicates this export; loading it again would overlap geometry.
	var imported: Node3D = preload("res://Blender models/diningn area.glb").instantiate()
	add_child(imported)
	var groups: Dictionary = {}
	for node in imported.find_children("*", "MeshInstance3D", true, false):
		source_mesh_count += 1
		if str(node.name).begins_with("Hidden_Depressor") or str(node.name).begins_with("FrontDoor"):
			continue
		var instance := node as MeshInstance3D
		for surface in instance.mesh.get_surface_count():
			var mat: Material = instance.get_active_material(surface)
			# Chunk by material and 6 m cell to retain useful frustum culling.
			var cell := Vector2i(floori(instance.global_position.x / 6.0), floori(instance.global_position.z / 6.0))
			var key := "%s_%s" % [mat.get_instance_id(), cell]
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				var aged := mat.duplicate() as StandardMaterial3D
				aged.roughness = maxf(aged.roughness, 0.65)
				aged.cull_mode = BaseMaterial3D.CULL_DISABLED
				st.set_material(aged)
				groups[key] = st
			groups[key].append_from(instance.mesh, surface, instance.global_transform)
	for key in groups:
		var combined := MeshInstance3D.new()
		combined.name = "StaticBatch_%d" % batch_count
		combined.mesh = groups[key].commit()
		add_child(combined)
		batch_count += 1
	remove_child(imported)
	imported.free()

func solid(pos: Vector3, size: Vector3, blocks_navigation: bool = true) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = pos
	body.add_child(shape)
	add_child(body)
	if blocks_navigation:
		obstacles.append(AABB(pos - size * 0.5, size))

func _collision() -> void:
	solid(Vector3(0, -0.15, 0), Vector3(24, 0.3, 18), false)
	solid(Vector3(-12, 2.8, 0), Vector3(0.25, 5.6, 18))
	solid(Vector3(12, 2.8, 0), Vector3(0.25, 5.6, 18))
	solid(Vector3(0, 2.8, -9), Vector3(24, 5.6, 0.25))
	solid(Vector3(0, 2.8, 9), Vector3(24, 5.6, 0.25))
	solid(Vector3(0, 5.7, 0), Vector3(24, 0.2, 18), false)
	solid(Vector3(0, 1.05, -6.6), Vector3(13.5, 2.1, 1.6))
	for x in [-6.2, 6.2]:
		for z in [5.8, 2.6, -0.6, -3.8]:
			solid(Vector3(x, 0.75, z), Vector3(1.65, 1.5, 1.25))
			# Right-hand booth groups are rotated 180 degrees in the GLB.
			var table_z: float = z + (0.92 if x > 0 else -0.92)
			solid(Vector3(x, 0.42, table_z), Vector3(1.35, 0.84, 0.78))
	# Hollow pit walls, with a lowered central opening and a walkable ramp.
	solid(Vector3(-3.08, 0.6, 4.4), Vector3(0.34, 1.2, 4.8))
	solid(Vector3(3.08, 0.6, 4.4), Vector3(0.34, 1.2, 4.8))
	solid(Vector3(0, 0.6, 6.64), Vector3(6.5, 1.2, 0.32))
	solid(Vector3(-1.98, 0.6, 2.16), Vector3(2.6, 1.2, 0.32))
	solid(Vector3(1.98, 0.6, 2.16), Vector3(2.6, 1.2, 0.32))
	solid(Vector3(0, 0.28, 4.4), Vector3(5.8, 0.56, 4.5), false)
	var ramp_body := StaticBody3D.new()
	var ramp_shape := CollisionShape3D.new()
	var ramp := ConvexPolygonShape3D.new()
	ramp.points = PackedVector3Array([Vector3(-0.68, 0, 0.7), Vector3(0.68, 0, 0.7), Vector3(-0.68, 0, 2.8), Vector3(0.68, 0, 2.8), Vector3(-0.68, 1.24, 2.3), Vector3(0.68, 1.24, 2.3), Vector3(-0.68, 0.56, 2.8), Vector3(0.68, 0.56, 2.8)])
	ramp_shape.shape = ramp
	ramp_body.add_child(ramp_shape)
	add_child(ramp_body)
	var ramp_surface := SurfaceTool.new()
	ramp_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0, 4, 1, 1, 4, 5, 4, 6, 5, 5, 6, 7]:
		ramp_surface.add_vertex(ramp.points[index])
	ramp_surface.generate_normals()
	var ramp_mesh := MeshInstance3D.new()
	ramp_mesh.mesh = ramp_surface.commit()
	ramp_mesh.material_override = Geo.material(Color("5c5143"))
	add_child(ramp_mesh)

func _ball_pit() -> void:
	# 720 balls in one draw call; no hundreds of rigid bodies or script updates.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7319
	var balls := MultiMesh.new()
	balls.transform_format = MultiMesh.TRANSFORM_3D
	balls.use_colors = true
	# Reuse an actual Blender ball mesh, discarding the export's display layout.
	var ball_export: Node3D = preload("res://Blender models/ballpit.glb").instantiate()
	var source_ball := ball_export.find_child("Ball_000", true, false) as MeshInstance3D
	var sphere: Mesh = source_ball.mesh.duplicate()
	var mat := Geo.material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	sphere.surface_set_material(0, mat)
	balls.mesh = sphere
	ball_export.free()
	balls.instance_count = 720
	var colors := [Color("b64c3e"), Color("bba14e"), Color("336d8a"), Color("437f67"), Color("9b637f")]
	for i in balls.instance_count:
		var column := i % 30
		var row := i / 30
		var pos := Vector3(-2.76 + column * 0.19 + rng.randf_range(-0.04, 0.04), rng.randf_range(0.57, 0.76), 2.38 + row * 0.174 + rng.randf_range(-0.04, 0.04))
		balls.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.61), pos))
		balls.set_instance_color(i, colors[rng.randi_range(0, 4)])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = balls
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _play_tubes() -> void:
	var source: Node3D = preload("res://Blender models/tubes.glb").instantiate()
	# Overhead, wall-mounted play tubes leave the two side aisles navigable.
	var placements := {
		"01_Straight_Crawl_Tube": Vector3(-10.6, 3.65, 3.0),
		"02_90_Degree_Corner_Tube": Vector3(-10.6, 3.65, -2.0),
		"T_Main": Vector3(10.4, 3.65, 2.5),
		"T_Branch": Vector3(10.4, 3.65, 2.5),
		"T_Center_Collar": Vector3(10.4, 3.65, 2.5)
	}
	for node_name in placements:
		var original := source.find_child(node_name, true, false) as MeshInstance3D
		if original == null:
			continue
		var instance := MeshInstance3D.new()
		instance.mesh = original.mesh
		instance.position = placements[node_name]
		instance.scale = Vector3.ONE * 0.58
		instance.rotation.y = PI / 2
		add_child(instance)
	source.free()

func _decorate() -> void:
	var dark := Geo.material(Color("182125"), 0.4)
	var rust := Geo.material(Color("724435"))
	var cream := Geo.material(Color("b5b3a0"))
	Geo.label(self, "H A P P Y   B I R T H D A Y", Vector3(0, 4.75, -8.82), 62, Color("b5a684"))
	Geo.label(self, "RONALD'S  /  FAMILY DINER", Vector3(0, 4.04, -8.81), 26, Color("6c8882"))
	Geo.label(self, "PLAY NICE.", Vector3(-4.5, 4, -8.8), 25, Color("bb8c74"))
	Geo.label(self, "STAY FOREVER.", Vector3(4.5, 4, -8.8), 25, Color("bb8c74"))
	var exit_sign := Geo.label(self, "E X I T", Vector3(0, 3.48, 8.76), 48, Color("74bc9a"))
	exit_sign.rotation.y = PI
	exit_door = Node3D.new()
	exit_door.position = Vector3(-1.7, 0, 8.82)
	add_child(exit_door)
	Geo.box(exit_door, Vector3(1.7, 1.5, 0), Vector3(3.4, 3, 0.1), dark)
	Geo.box(exit_door, Vector3(1.7, 1.4, -0.12), Vector3(2.9, 0.08, 0.06), rust)
	exit_light = _light(Vector3(0, 3, 7.7), Color("79ba98"), 1.0, 5.0)
	_light(Vector3(0, 4.3, 4.4), Color("698399"), 0.8, 8.5)
	flicker_light = _light(Vector3(-7.8, 3.8, -3), Color("bdaa80"), 0.7, 7.0)
	_light(Vector3(8.6, 3.8, 2), Color("8a5951"), 0.7, 6.5)
	for x in [-8, 0, 8]:
		for z in [-4, 3]:
			Geo.box(self, Vector3(x, 5.55, z), Vector3(2.2, 0.13, 0.5), dark)
	# A few sparse details give the exported diner a lived-in silhouette.
	for i in 14:
		var x := -10.5 + i * 1.6
		var flag := Geo.box(self, Vector3(x, 3.9 + sin(i * 0.45) * 0.22, 1.0), Vector3(0.4, 0.46, 0.025), rust if i % 2 == 0 else cream)
		flag.rotation.z = sin(i) * 0.2
	var note := Geo.label(self, "CLOSING CHECKLIST\n\n3 fuses → breaker → front door\n\nKeep the light on him.", Vector3(-3.7, 1.65, -5.76), 20, Color("d0c3a3"))
	note.pixel_size = 0.004
	_exterior()

func _exterior() -> void:
	# This is the live diner facade seen from the home camera, not a flat menu image.
	var brick := Geo.material(Color("743c35"))
	var trim := Geo.material(Color("d4a344"), 0.18)
	var glass := Geo.material(Color("182b30"), 0.28)
	var pavement := Geo.material(Color("303334"))
	Geo.box(self, Vector3(0, -0.09, 15.6), Vector3(25, 0.18, 13.3), pavement)
	Geo.box(self, Vector3(0, 4.58, 9.24), Vector3(23.7, 1.55, 0.2), brick)
	Geo.box(self, Vector3(0, 3.81, 9.37), Vector3(24, 0.12, 0.34), trim)
	Geo.box(self, Vector3(0, 5.37, 9.33), Vector3(24, 0.16, 0.33), trim)
	for x in [-8.4, 8.4]:
		Geo.box(self, Vector3(x, 2.18, 9.27), Vector3(5.4, 2.75, 0.12), trim)
		Geo.box(self, Vector3(x, 2.18, 9.35), Vector3(5.1, 2.46, 0.07), glass)
		Geo.box(self, Vector3(x, 2.18, 9.44), Vector3(0.12, 2.46, 0.09), trim)
		Geo.box(self, Vector3(x, 2.18, 9.45), Vector3(5.1, 0.12, 0.09), trim)
		Geo.box(self, Vector3(x, 3.51, 9.48), Vector3(5.7, 0.27, 0.65), brick)
	Geo.box(self, Vector3(0, 3.28, 9.48), Vector3(4.15, 0.17, 0.58), trim)
	Geo.box(self, Vector3(0, 2.81, 9.42), Vector3(4.2, 0.12, 0.25), brick)
	Geo.box(self, Vector3(-2.18, 1.52, 9.43), Vector3(0.19, 3.17, 0.23), trim)
	Geo.box(self, Vector3(2.18, 1.52, 9.43), Vector3(0.19, 3.17, 0.23), trim)
	Geo.box(self, Vector3(-1.05, 1.52, 9.53), Vector3(1.93, 2.83, 0.08), glass)
	Geo.box(self, Vector3(1.05, 1.52, 9.53), Vector3(1.93, 2.83, 0.08), glass)
	Geo.box(self, Vector3(0, 1.52, 9.62), Vector3(0.12, 2.92, 0.15), trim)
	Geo.box(self, Vector3(-0.17, 1.48, 9.64), Vector3(0.13, 0.6, 0.17), trim)
	Geo.box(self, Vector3(0.17, 1.48, 9.64), Vector3(0.13, 0.6, 0.17), trim)
	Geo.label(self, "R O N A L D ' S", Vector3(0, 4.63, 9.39), 72, Color("f7e6aa"))
	Geo.label(self, "F A M I L Y   D I N E R", Vector3(0, 4.10, 9.46), 25, Color("efd7a3"))
	Geo.label(self, "OPEN LATE     •     SINCE 1987", Vector3(0, 3.48, 9.89), 23, Color("f4dea3"))
	for x in [-10.6, -8.4, -6.2, -4.0, 4.0, 6.2, 8.4, 10.6]:
		Geo.sphere(self, Vector3(x, 3.6, 9.63), 0.066, Geo.material(Color("e5b959"), 0, 1.6))
	_light(Vector3(0, 4.6, 12.5), Color("e6ac65"), 1.1, 15.0)
	_light(Vector3(-8, 3.4, 11.8), Color("d4a170"), 0.55, 8.0)

func _light(pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	add_child(light)
	return light

func _navigation() -> void:
	nav.region = Rect2i(-23, -17, 47, 35)
	nav.cell_size = Vector2(0.5, 0.5)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for x in range(-23, 24):
		for z in range(-17, 18):
			var point := Vector3(x * 0.5, 0.7, z * 0.5)
			for obstacle in obstacles:
				if obstacle.grow(0.36).has_point(point):
					nav.set_point_solid(Vector2i(x, z))
					break
	# Enemy stays out of the starting pit; it can route around both sides.
	for x in range(-6, 7):
		for z in range(4, 14):
			nav.set_point_solid(Vector2i(x, z))

func route(from: Vector3, to: Vector3) -> PackedVector2Array:
	var a := Vector2i(roundi(from.x * 2), roundi(from.z * 2))
	var b := Vector2i(roundi(to.x * 2), roundi(to.z * 2))
	if not nav.is_in_boundsv(a) or not nav.is_in_boundsv(b) or nav.is_point_solid(a) or nav.is_point_solid(b):
		return PackedVector2Array()
	return nav.get_point_path(a, b)
