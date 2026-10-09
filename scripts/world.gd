extends Node3D
const Geo = preload("res://scripts/geometry.gd")
const DINER = preload("res://Blender models/ronalds.glb")
const PLAY_PLACE = preload("res://Blender models/PLay place.glb")
const APPLIANCES = preload("res://Blender models/appliances.glb")

# Landmarks use the new Blender map's coordinates (metres).
const SPAWN := Vector3(8, 0.3, -10)
const STALKER_SPAWN := Vector3(3, 0.12, -1)
const FUSE_POSITIONS := [Vector3(-16, 0.96, 2), Vector3(-12, 1.27, 14.5), Vector3(23.5, 0.99, 16)]
const FUSE_APPROACHES := [Vector3(-16, 0.12, -0.3), Vector3(-12, 0.12, 12.7), Vector3(21.4, 0.12, 16)]
const CELL_POSITIONS := [Vector3(0, 0.96, -4), Vector3(-19.3, 1.16, 16.2)]
const BREAKER_POSITION := Vector3(18.82, 1.6, 13.2)
const EXIT_POSITION := Vector3(-35.7, 1.5, 0)
const FREEZER_OFFSET := Vector3(47, 0, 0)

var obstacles: Array[AABB] = []
var nav := AStarGrid2D.new()
var exit_door: Node3D
var exit_light: OmniLight3D
var flicker_light: OmniLight3D
var batch_count := 0
var source_mesh_count := 0
var ball_count := 3600
var ball_instances: MultiMesh
var ball_origins: Array[Vector3] = []
var ball_positions: Array[Vector3] = []
var ball_active: Dictionary = {}
var powered_lights: Array[OmniLight3D] = []
var powered_fixtures: Array[MeshInstance3D] = []
var _groups: Dictionary = {}
var appliance_placements := 0
var appliance_layout: Array[Dictionary] = []

func _ready() -> void:
	name = "Diner"
	_import_diner()
	_import_appliances()
	_commit_batches()
	_shell_and_passages()
	_ball_pit()
	_decorate()
	_navigation()

func _process(delta: float) -> void:
	_animate_balls(delta)

func _import_diner() -> void:
	var imported := DINER.instantiate()
	add_child(imported)
	for node in imported.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var title := str(instance.name)
		source_mesh_count += 1
		# Export helper volumes and the default cube are opaque in glTF.
		# Replace the closed room shell and selected walls with real doorways.
		if title in ["Cube", "FF_RoomShell", "DustVolume", "Freezer_FogVolume", "Wall_Kitchen_Front", "WalkIn_Freezer_Door", "Freezer_Wall_Left", "PlayGlass_0", "PlayGlass_1"] or title.begins_with("Bath_Sink") or title == "Bath_Mirror" or title.begins_with("StallDoor_"):
			continue
		if title.begins_with("PP_Ball") or title.begins_with("PP_Depressor"):
			continue
		# Flatten the exported sunken pit into a walkable shallow ball bed.
		if title.begins_with("PP_Pit"):
			continue
		if title.begins_with("Freezer_Box") or title.begins_with("Freezer_Shelf"):
			continue
		if title.begins_with("Freezer_"):
			instance.position += FREEZER_OFFSET
			if title == "Freezer_Floor":
				instance.position.y += 0.12
		# The separate appliance kit supplies all booths and kitchen equipment.
		if title.begins_with("BoothL_") or title.begins_with("BoothR_") or title.begins_with("KitchenPrep_") or title.begins_with("DeadRegister") or title.begins_with("DeepFryer_") or title.begins_with("FryerBasket_") or title.begins_with("FryerGlow_") or title in ["OrderingCounter", "FlatTop_Grill", "ExhaustHood"]:
			continue
		if title.begins_with("PlayGlass") or title.begins_with("Wall_Playplace_"):
			# glTF lost the Blender transmission shader; restore readable glass.
			var glass := Geo.material(Color(0.65, 0.78, 0.82, 0.065), 0.05)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.cull_mode = BaseMaterial3D.CULL_DISABLED
			glass.roughness = 0.08
			instance.material_override = glass
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if title in ["PP_Box_0", "PP_Box_2"]:
			var red_glass := Geo.material(Color(0.78, 0.22, 0.2, 0.2), 0.05)
			red_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			red_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
			instance.material_override = red_glass
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Net planes also lost their procedural cutouts. Keep the supporting frame.
		if title.begins_with("PP_Net"):
			continue
		_batch(instance)
		var bounds: AABB = instance.global_transform * instance.get_aabb()
		if title.begins_with("PP_ClimbPlat_"):
			# The highest two platforms were excluded by the generic ground-level rule.
			solid(Vector3(bounds.get_center().x, bounds.end.y - 0.015, bounds.get_center().z), Vector3(bounds.size.x, 0.03, bounds.size.z), false)
		if title.begins_with("PP_Pillar_"):
			# Leave walkable clearance beside the upper module supports.
			solid(bounds.get_center(), Vector3(0.3, bounds.size.y, 0.3), false)
		if title.begins_with("PP_Box_") and bounds.position.y > 2.0:
			# The tubes are hollow; only their bottom panels support the player.
			solid(Vector3(bounds.get_center().x, bounds.position.y + 0.04, bounds.get_center().z), Vector3(bounds.size.x, 0.08, bounds.size.z), false)
			if title in ["PP_Box_0", "PP_Box_2"]:
				Geo.box(self, Vector3(bounds.get_center().x, bounds.position.y + 0.015, bounds.get_center().z), Vector3(bounds.size.x, 0.03, bounds.size.z), Geo.material(Color("913b38")))
		var floor_mesh := title.contains("Floor") or title in ["Base_Carpet", "EntrancePad", "Main_BackHall_Strip", "OutsidePad_L", "OutsidePad_R"]
		if floor_mesh:
			if bounds.size.y < 0.02:
				bounds.position.y -= 0.08
				bounds.size.y = 0.08
			solid(bounds.get_center(), bounds.size, false)
		elif bounds.position.y < 2.5 and bounds.end.y > 0.35 and not title.begins_with("PlayGlass") and not title.begins_with("PP_ClimbPlat_") and not title.begins_with("PP_Pillar_") and not title.contains("Sign") and not title.contains("Mirror"):
			if title.begins_with("PP_ClimbRamp"):
				var body := StaticBody3D.new()
				var shape := CollisionShape3D.new()
				shape.shape = instance.mesh.create_trimesh_shape()
				body.transform = instance.global_transform
				body.add_child(shape)
				add_child(body)
				obstacles.append(bounds)
			else:
				solid(bounds.get_center(), bounds.size)
	remove_child(imported)
	imported.free()

func _commit_batches() -> void:
	for key in _groups:
		var combined := MeshInstance3D.new()
		combined.name = "MapBatch_%d" % batch_count
		combined.mesh = _groups[key].commit()
		add_child(combined)
		batch_count += 1
	_groups.clear()

func _import_appliances() -> void:
	var source := APPLIANCES.instantiate()
	add_child(source)
	var y_scale := Vector3(1, 0.6, 1)
	# The supplied final plan has tables by the play place, a central booth row,
	# and customer drinks near the right end of the service wall.
	var fittings := [
		["Asset_BeverageSystem", Vector3(23, 0, 7), 0.0, y_scale],
		["Asset_SodaFountain", Vector3(28, 0, 7), 0.0, y_scale],
		# The hot cooking line runs along the rear wall of the staff kitchen.
		["Asset_ClamshellGrill", Vector3(-12, 0, 19), 0.0, y_scale],
		["Asset_ClamshellGrill", Vector3(-7, 0, 19), 0.0, y_scale],
		["Asset_DeepFryer", Vector3(-1, 0, 19), 0.0, y_scale],
		["Asset_DeepFryer", Vector3(2, 0, 19), 0.0, y_scale],
		["Asset_FryArchStation", Vector3(6, 0, 19), 0.0, y_scale],
		["Asset_CombiOven", Vector3(14, 0, 19), 0.0, y_scale],
		# Prep, holding, and drinks sit between the cook line and service wall.
		["Asset_AssemblyTable", Vector3(-12, 0, 14.5), 0.0, y_scale],
		["Asset_AssemblyTable", Vector3(-5, 0, 14.5), 0.0, y_scale],
		["Asset_AssemblyTable", Vector3(3, 0, 14.5), 0.0, y_scale],
		["Asset_UHC", Vector3(-6, 0, 11.5), 0.0, y_scale],
		["Asset_UHC", Vector3(2, 0, 11.5), 0.0, y_scale],
		["Asset_Microwave", Vector3(-5, 1.13, 14.5), 0.0, y_scale],
		["Asset_SodaFountain", Vector3(8, 0, 11.5), 0.0, y_scale],
		["Asset_SoftServeMachine", Vector3(13, 0, 11.5), 0.0, y_scale],
		["Asset_CoffeeBrewerUrns", Vector3(16, 0, 11.5), 0.0, y_scale],
		# The supplied floor plan puts the freezer to the right of the kitchen.
		["Asset_ReachInFridge", Vector3(21, 0, 18), 0.0, y_scale],
		["Asset_ReachInFridge", Vector3(25, 0, 18), 0.0, y_scale],
		["Asset_IceMachine", Vector3(27, 0, 14), PI / 2, y_scale],
		["Asset_WalkInDoorModule", Vector3(19, 0, 16), PI / 2, Vector3.ONE]
	]
	for x in [-16, -8, 0, 8, 16]:
		fittings.append(["Asset_Booth", Vector3(x, 0, 2), 0.0, Vector3.ONE])
	for at in [Vector3(-25, 0, -4), Vector3(-17, 0, -4), Vector3(-9, 0, -4), Vector3(0, 0, -4), Vector3(13, 0, -4), Vector3(20, 0, -4), Vector3(28, 0, -4)]:
		fittings.append(["Asset_Table", at, 0.0, Vector3.ONE])
		fittings.append(["Asset_Chair", at + Vector3(-1.2, 0, 0), PI / 2, Vector3.ONE])
		fittings.append(["Asset_Chair", at + Vector3(1.2, 0, 0), -PI / 2, Vector3.ONE])
	var assemblies: Dictionary = {}
	for group in source.get_children():
		if not str(group.name).begins_with("Asset_"):
			continue
		var meshes: Array[MeshInstance3D] = []
		var bounds := AABB()
		for child in group.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			if str(mesh.name).contains("_Label"):
				continue
			if str(group.name) == "Asset_WalkInDoorModule" and str(mesh.name).begins_with("Door"):
				continue
			if meshes.is_empty():
				bounds = mesh.global_transform * mesh.get_aabb()
			else:
				bounds = bounds.merge(mesh.global_transform * mesh.get_aabb())
			meshes.append(mesh)
		assemblies[str(group.name)] = {"meshes": meshes, "bounds": bounds}
	for fitting in fittings:
		appliance_layout.append({"asset": fitting[0], "position": fitting[1]})
		var assembly: Dictionary = assemblies[fitting[0]]
		var bounds: AABB = assembly.bounds
		var anchor := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var placement := Transform3D(Basis.IDENTITY, fitting[1]) * Transform3D(Basis(Vector3.UP, fitting[2]).scaled(fitting[3]), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -anchor)
		for original in assembly.meshes:
			var title := str(original.name)
			if fitting[0] == "Asset_WalkInDoorModule" and title.begins_with("Handle"):
				continue
			var placed := MeshInstance3D.new()
			placed.mesh = original.mesh
			placed.transform = placement * original.global_transform
			add_child(placed)
			_batch(placed)
			var physical: AABB = placed.global_transform * placed.get_aabb()
			if fitting[0] != "Asset_WalkInDoorModule" and physical.position.y < 2.5 and physical.end.y > 0.35 and physical.size.x > 0.2 and physical.size.z > 0.2:
				solid(physical.get_center(), physical.size)
			placed.queue_free()
			source_mesh_count += 1
		appliance_placements += 1
	remove_child(source)
	source.free()

func _batch(instance: MeshInstance3D) -> void:
	for surface in instance.mesh.get_surface_count():
		var mat := instance.get_active_material(surface)
		var cell := Vector2i(floori(instance.global_position.x / 8), floori(instance.global_position.z / 8))
		var key := "%s_%s" % [mat.get_instance_id() if mat else 0, cell]
		if not _groups.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var aged := mat.duplicate() as StandardMaterial3D if mat else StandardMaterial3D.new()
			if aged:
				aged.roughness = maxf(aged.roughness, 0.65)
				aged.cull_mode = BaseMaterial3D.CULL_DISABLED
				st.set_material(aged)
			_groups[key] = st
		_groups[key].append_from(instance.mesh, surface, instance.global_transform)

func solid(pos: Vector3, size: Vector3, blocks_navigation: bool = true) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size.max(Vector3.ONE * 0.015)
	shape.shape = box
	body.position = pos
	body.add_child(shape)
	add_child(body)
	if blocks_navigation:
		obstacles.append(AABB(pos - size * 0.5, size))

func _wall(pos: Vector3, size: Vector3, mat: Material) -> void:
	Geo.box(self, pos, size, mat)
	solid(pos, size)

func _shell_and_passages() -> void:
	var purple := Geo.material(Color("382b40"))
	var tile := Geo.material(Color("6f91a7"))
	var freezer := Geo.material(Color("a7b5b9"))
	_wall(Vector3(36, 2.7, 0), Vector3(0.2, 5.4, 50), purple)
	_wall(Vector3(0, 2.7, -25), Vector3(72, 5.4, 0.2), purple)
	_wall(Vector3(0, 2.7, 25), Vector3(72, 5.4, 0.2), purple)
	# Front entrance is on the west wall, matching EntrancePad in the export.
	_wall(Vector3(-36, 2.7, -13.4), Vector3(0.2, 5.4, 23.2), purple)
	_wall(Vector3(-36, 2.7, 13.4), Vector3(0.2, 5.4, 23.2), purple)
	_wall(Vector3(-36, 4.35, 0), Vector3(0.2, 2.1, 3.6), purple)
	Geo.box(self, Vector3(0, 5.45, 0), Vector3(72, 0.1, 50), Geo.material(Color("45444b")))
	solid(Vector3(0, -0.1, 0), Vector3(72, 0.2, 50), false)
	# Staff opening to the left of the counter, 3 metres wide.
	_wall(Vector3(-15.75, 1.65, 9), Vector3(4.5, 3.3, 0.18), tile)
	# An open service window shows the kitchen over the counter.
	_wall(Vector3(-8, 1.65, 9), Vector3(5, 3.3, 0.18), tile)
	_wall(Vector3(2.5, 0.55, 9), Vector3(16, 1.1, 0.18), tile)
	_wall(Vector3(2.5, 3.05, 9), Vector3(16, 0.5, 0.18), tile)
	_wall(Vector3(22.25, 1.65, 9), Vector3(23.5, 3.3, 0.18), tile)
	_wall(Vector3(-12, 3.1, 9), Vector3(3, 0.4, 0.18), tile)
	# Service counter shown across the dining/kitchen boundary in the final plan.
	var counter := Geo.material(Color("85878b"))
	_wall(Vector3(2.5, 0.52, 7.8), Vector3(16, 1.04, 1.1), counter)
	Geo.box(self, Vector3(2.5, 1.08, 7.8), Vector3(16.3, 0.08, 1.3), Geo.material(Color("c3c1b8")))
	# The export overlapped the bathroom and freezer. The final floor plan
	# puts cold storage on the right side of the kitchen, with a west entry.
	_wall(Vector3(19, 1.65, 13.25), Vector3(0.14, 3.3, 2.5), freezer)
	_wall(Vector3(19, 1.65, 18.75), Vector3(0.14, 3.3, 2.5), freezer)
	_wall(Vector3(19, 3.1, 16), Vector3(0.14, 0.4, 3), freezer)
	# This solid return hides the freezer from the customer service window.
	_wall(Vector3(19, 1.65, 10.5), Vector3(0.14, 3.3, 3), freezer)
	# The original bathroom vanity blocked its entrance across the room.
	_wall(Vector3(-23, 0.02, 11.3), Vector3(8.8, 0.04, 5.5), tile)
	# Front wall and an open door leave a clear entrance into the bathroom.
	_wall(Vector3(-26.25, 1.55, 14), Vector3(3.5, 3.1, 0.16), tile)
	_wall(Vector3(-19.75, 1.55, 14), Vector3(3.5, 3.1, 0.16), tile)
	_wall(Vector3(-23, 2.75, 14), Vector3(3, 0.7, 0.16), tile)
	var door_mat := Geo.material(Color("c4c7c0"))
	Geo.box(self, Vector3(-24.42, 1.1, 14.9), Vector3(0.07, 2.1, 1.8), door_mat)
	_wall(Vector3(-19.3, 0.5, 16.2), Vector3(0.8, 1.0, 2.8), Geo.material(Color("777f84")))
	for z in [15.4, 16.2, 17.0]:
		Geo.sphere(self, Vector3(-19.3, 1.04, z), 0.2, Geo.material(Color("d2d3cf")))
	Geo.box(self, Vector3(-18.95, 1.65, 16.2), Vector3(0.06, 1.0, 2.8), Geo.material(Color("aebcbf"), 0.55))
	# Imported stall doors were closed across every opening. Show them swung in.
	for x in [-26.4, -23.7, -21.0]:
		Geo.box(self, Vector3(x, 1.15, 18.63), Vector3(0.06, 2.1, 1.4), door_mat)
	# Booth seats run behind the row of tables, beside the plan's half wall.
	var divider := Geo.material(Color("59626a"))
	_wall(Vector3(-17.25, 0.55, 4.7), Vector3(7.5, 1.1, 0.18), divider)
	_wall(Vector3(4.25, 0.55, 4.7), Vector3(29.5, 1.1, 0.18), divider)
	# The new pit has a low padded rim and an open central walk-out.
	var vinyl := Geo.material(Color(0.7, 0.16, 0.13, 0.22))
	vinyl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vinyl.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wall(Vector3(0, 0.23, -20.5), Vector3(31, 0.46, 0.3), vinyl)
	_wall(Vector3(-15.5, 0.23, -13.25), Vector3(0.3, 0.46, 14.5), vinyl)
	_wall(Vector3(15.5, 0.23, -13.25), Vector3(0.3, 0.46, 14.5), vinyl)
	_wall(Vector3(-4.5, 0.23, -6), Vector3(22, 0.46, 0.3), vinyl)
	_wall(Vector3(12.5, 0.23, -6), Vector3(6, 0.46, 0.3), vinyl)
	# Bridge the small joins between the imported upper play modules.
	solid(Vector3(0, 2.69, -18.05), Vector3(27.2, 0.08, 1.6), false)
	solid(Vector3(12.5, 2.9, -19.15), Vector3(2.2, 0.08, 1.6), false)
	Geo.box(self, Vector3(12.5, 2.9, -19.15), Vector3(2.2, 0.08, 1.6), Geo.material(Color("375c81")))
	# A shallow entry ramp reaches the first imported climbing platform.
	var entry_center := Vector3(14.5, 0.55, -7.22)
	var entry_size := Vector3(1.9, 0.14, 2.0)
	var entry_angle := atan2(0.94, 1.9)
	var entry_mesh := Geo.box(self, entry_center, entry_size, Geo.material(Color("375c81")))
	entry_mesh.rotation.x = entry_angle
	var entry_body := StaticBody3D.new()
	entry_body.position = entry_center
	entry_body.rotation.x = entry_angle
	var entry_shape := CollisionShape3D.new()
	var entry_box := BoxShape3D.new()
	entry_box.size = entry_size
	entry_shape.shape = entry_box
	entry_body.add_child(entry_shape)
	add_child(entry_body)
	# Maintenance crate inside the freezer supports the third fuse.
	_wall(Vector3(23.5, 0.46, 16), Vector3(1.2, 0.84, 0.9), Geo.material(Color("665d47")))

func _ball_pit() -> void:
	var source := PLAY_PLACE.instantiate()
	var source_ball := source.find_child("Ball_0000", true, false) as MeshInstance3D
	var mesh := source_ball.mesh.duplicate() as Mesh
	var material := Geo.material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)
	var balls := MultiMesh.new()
	balls.transform_format = MultiMesh.TRANSFORM_3D
	balls.use_colors = true
	balls.mesh = mesh
	balls.instance_count = ball_count
	var rng := RandomNumberGenerator.new()
	rng.seed = 7319
	var colors := [Color("b64c3e"), Color("c7aa3f"), Color("3364a0")]
	for i in ball_count:
		var layer := i / 1800
		var cell := i % 1800
		var pos := Vector3(-14.85 + (cell % 60) * 0.5 + layer * 0.24, 0.18 + layer * 0.24 + rng.randf_range(-0.02, 0.02), -20.1 + (cell / 60) * 0.46 + layer * 0.22)
		pos.x += rng.randf_range(-0.045, 0.045)
		pos.z += rng.randf_range(-0.045, 0.045)
		ball_origins.append(pos)
		ball_positions.append(pos)
		balls.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.97), pos))
		balls.set_instance_color(i, colors[rng.randi_range(0, 2)])
	var instance := MultiMeshInstance3D.new()
	instance.name = "BlenderPlayPlaceBalls"
	instance.multimesh = balls
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	ball_instances = balls
	source.free()

func _animate_balls(delta: float) -> void:
	if ball_instances == null:
		return
	var player := get_parent().get("player") as CharacterBody3D
	if player == null:
		return
	var p := player.global_position
	var stirring := p.x > -15.2 and p.x < 15.2 and p.z > -20.5 and p.z < -6.0 and p.y < 1.1 and Vector2(player.velocity.x, player.velocity.z).length() > 0.2
	if stirring:
		var col := clampi(roundi((p.x + 14.85) / 0.5), 0, 59)
		var row := clampi(roundi((p.z + 20.1) / 0.46), 0, 29)
		for layer in 2:
			for z in range(maxi(0, row - 4), mini(29, row + 4) + 1):
				for x in range(maxi(0, col - 4), mini(59, col + 4) + 1):
					ball_active[layer * 1800 + z * 60 + x] = true
	var settled: Array[int] = []
	for index in ball_active:
		var i: int = index
		var origin := ball_origins[i]
		var delta_xz := Vector2(origin.x - p.x, origin.z - p.z)
		var distance := delta_xz.length()
		var target := origin
		if stirring and distance < 1.45:
			var push := delta_xz.normalized() * (1.45 - distance) * 0.2
			target += Vector3(push.x, sin(Time.get_ticks_msec() * 0.012 + i) * 0.08, push.y)
		var next_pos := ball_positions[i].lerp(target, minf(1.0, delta * 9.0))
		ball_positions[i] = next_pos
		ball_instances.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.97), next_pos))
		if not stirring or distance >= 1.45:
			if next_pos.distance_to(origin) < 0.01:
				settled.append(i)
	for i in settled:
		ball_active.erase(i)

func _decorate() -> void:
	var dark := Geo.material(Color("18262a"), 0.3)
	exit_door = Node3D.new()
	exit_door.position = Vector3(-35.88, 0, -1.7)
	add_child(exit_door)
	Geo.box(exit_door, Vector3(0, 1.6, 1.7), Vector3(0.13, 3.2, 3.4), dark)
	Geo.box(exit_door, Vector3(0.1, 1.4, 1.7), Vector3(0.08, 0.08, 2.9), Geo.material(Color("bf9b50"), 0.6))
	solid(Vector3(-35.9, 1.6, 0), Vector3(0.15, 3.2, 3.4))
	exit_light = _light(Vector3(-33.8, 3, 0), Color("79ba98"), 1.5, 8)
	flicker_light = _light(Vector3(-10, 3.9, 1), Color("c7a77d"), 1.1, 13)
	_light(Vector3(10, 4, -12), Color("6c9db9"), 1.5, 15)
	_light(Vector3(-8, 4, -16), Color("b67d63"), 1.0, 12)
	_light(Vector3(13, 4, 2), Color("d7aa70"), 1.1, 13)
	_light(Vector3(23.5, 2.8, 16), Color("90c5d9"), 1.5, 8)
	_light(Vector3(-23, 3.8, 6), Color("819fa2"), 0.85, 10)
	_light(Vector3(-23, 3.4, 18), Color("94b5a3"), 1.1, 9)
	for x in [-9, 8, 26]:
		_light(Vector3(x, 4.2, 16), Color("abbdaf"), 1.05, 12)
	for x in [-12, 0, 12, 26]:
		for z in [-2, 16]:
			powered_fixtures.append(Geo.box(self, Vector3(x, 5.34, z), Vector3(2.8, 0.12, 0.6), Geo.material(Color("777a78"))))
	# A readable entrance facade for the home camera, aligned with the new map.
	var brick := Geo.material(Color("743c35"))
	var gold := Geo.material(Color("c99b43"), 0.2)
	Geo.box(self, Vector3(-40, -0.09, 0), Vector3(8, 0.18, 24), Geo.material(Color("303334")))
	Geo.box(self, Vector3(-36.2, 4.35, 0), Vector3(0.2, 1.6, 23), brick)
	Geo.box(self, Vector3(-36.35, 3.52, 0), Vector3(0.5, 0.15, 24), gold)
	for z in [-8, 8]:
		Geo.box(self, Vector3(-36.2, 2, z), Vector3(0.12, 2.4, 6), gold)
		Geo.box(self, Vector3(-36.3, 2, z), Vector3(0.08, 2.15, 5.7), dark)
		Geo.box(self, Vector3(-36.4, 2, z), Vector3(0.1, 2.15, 0.12), gold)
	_light(Vector3(-40, 4, 0), Color("e6ac65"), 2.8, 18)

func _light(pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	light.visible = false
	add_child(light)
	powered_lights.append(light)
	return light

func set_powered(enabled: bool) -> void:
	for light in powered_lights:
		light.visible = enabled
	for fixture in powered_fixtures:
		fixture.material_override = Geo.material(Color("d3d0bd"), 0, 0.7) if enabled else Geo.material(Color("777a78"))

func _navigation() -> void:
	nav.region = Rect2i(-71, -49, 143, 99)
	nav.cell_size = Vector2(0.5, 0.5)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for obstacle in obstacles:
		# Project anything intersecting the creature's body onto the floor grid.
		if obstacle.end.y < 0.2 or obstacle.position.y > 2.25:
			continue
		var bounds := obstacle.grow(0.38)
		for x in range(floori(bounds.position.x * 2), ceili(bounds.end.x * 2) + 1):
			for z in range(floori(bounds.position.z * 2), ceili(bounds.end.z * 2) + 1):
				var cell := Vector2i(x, z)
				if nav.is_in_boundsv(cell):
					nav.set_point_solid(cell)

func _nearest_open(cell: Vector2i) -> Vector2i:
	if nav.is_in_boundsv(cell) and not nav.is_point_solid(cell):
		return cell
	for radius in range(1, 5):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, z)
				if nav.is_in_boundsv(candidate) and not nav.is_point_solid(candidate):
					return candidate
	return cell

func route(from: Vector3, to: Vector3) -> PackedVector2Array:
	var a := _nearest_open(Vector2i(roundi(from.x * 2), roundi(from.z * 2)))
	var b := _nearest_open(Vector2i(roundi(to.x * 2), roundi(to.z * 2)))
	if not nav.is_in_boundsv(a) or not nav.is_in_boundsv(b) or nav.is_point_solid(a) or nav.is_point_solid(b):
		return PackedVector2Array()
	return nav.get_point_path(a, b)
