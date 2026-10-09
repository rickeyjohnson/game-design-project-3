extends SceneTree
## Run with: godot --headless --path . --script tests/smoke.gd
var game: Node3D
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		push_error("FAIL: " + label)
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func aim_at(target: Vector3) -> void:
	game.player.camera.look_at(target)
	game.player.pitch = game.player.camera.rotation.x

func asset_in_zone(asset: String, zone: String) -> bool:
	for placement in game.world.appliance_layout:
		if placement.asset != asset:
			continue
		var pos: Vector3 = placement.position
		if zone == "dining" and pos.z < 9 and pos.z > -9:
			return true
		if zone == "kitchen" and pos.z > 9 and pos.z < 22 and pos.x > -18 and pos.x < 19:
			return true
		if zone == "freezer" and pos.x > 19 and pos.x < 28 and pos.z > 12 and pos.z < 20:
			return true
	return false

func walk_to(destination: Vector3) -> bool:
	# Exercise the actual controller/colliders along the planned route.
	var route: PackedVector2Array = game.world.route(game.player.position, destination)
	if route.is_empty():
		return false
	Input.action_press("move_forward")
	for waypoint in route:
		var reached := false
		for tick in 120:
			var offset := waypoint - Vector2(game.player.position.x, game.player.position.z)
			if offset.length() < 0.15:
				reached = true
				break
			game.player.rotation.y = atan2(-offset.x, -offset.y)
			await physics_frame
		if not reached:
			Input.action_release("move_forward")
			print("Blocked at ", game.player.position, " toward ", waypoint)
			return false
	Input.action_release("move_forward")
	await frames(8)
	return game.player.position.y > -0.1

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(3)
	check(game.phase == "home" and game.hud.menu_mode == "home", "Home screen shown at startup")
	check(game.ambient.stream is AudioStreamMP3 and game.ambient.stream.loop, "Supplied soundtrack loads and loops")
	check(game.world.find_children("*", "Label3D", true, false).is_empty(), "Closing checklist sign is removed")
	check(game.sounds.has("pickup") and game.sounds.pickup.stream != null, "Menu pickup click sound is loaded")
	check(game.sounds.has("land") and game.sounds.land.stream is AudioStreamWAV, "Landing effect is loaded")
	check(game.hud.home_panel.visible and game.hud.home_panel.find_children("*", "Button", true, false).size() == 3, "Home has Play, Options, Exit game")
	game.hud.show_menu("options_home")
	check(game.hud.options_panel.visible and game.hud.quality_button != null, "Home Options shows settings")
	game.hud.show_menu("home")
	game.start_game()
	check(game.phase == "intro" and not game.player.control_enabled, "Opening locks movement")
	check(game.player.animation.has_animation("wake_up"), "Wake/pocket animation exists")
	check(game.world.source_mesh_count > 1400 and game.world.batch_count < 300, "Diner and appliance models imported and batched")
	check(game.world.appliance_placements >= 30, "Furniture and appliance kit populates the map")
	check(game.world.powered_lights.all(func(light: OmniLight3D) -> bool: return not light.visible), "Building lights start off")
	check(is_equal_approx(game.player.camera.position.y, 0.25), "Opening starts at floor level")
	for asset in ["Asset_Chair", "Asset_Booth", "Asset_Table", "Asset_BeverageSystem", "Asset_SodaFountain"]:
		check(asset_in_zone(asset, "dining"), "%s placed in dining area" % asset)
	for asset in ["Asset_ClamshellGrill", "Asset_DeepFryer", "Asset_UHC", "Asset_CombiOven", "Asset_Microwave", "Asset_CoffeeBrewerUrns", "Asset_SodaFountain", "Asset_SoftServeMachine", "Asset_FryArchStation", "Asset_AssemblyTable"]:
		check(asset_in_zone(asset, "kitchen"), "%s placed in kitchen" % asset)
	for asset in ["Asset_ReachInFridge", "Asset_IceMachine"]:
		check(asset_in_zone(asset, "freezer"), "%s placed in freezer" % asset)
	await create_timer(8.7).timeout
	check(game.phase == "play" and game.player.control_enabled, "Opening finishes and unlocks movement")
	check(game.player.camera.position.y < 1.1, "Player eye height fits the tables")
	check(game.player.flashlight_on, "Opening automatically turns on flashlight")
	check(game.player.hand.position.distance_to(game.player.hand_home) < 0.01, "Flashlight settles in hand")
	await key(KEY_F)
	check(not game.player.flashlight_on, "F switches flashlight off")
	var battery: float = game.player.battery
	await frames(30)
	check(is_equal_approx(battery, game.player.battery), "Battery does not drain while off")
	await key(KEY_F)
	await frames(30)
	check(game.player.battery < battery, "Battery drains while on")
	game.player.battery = 0.002
	await frames(3)
	check(game.player.battery == 0 and not game.player.flashlight_on, "Empty battery switches beam off")
	await key(KEY_R)
	check(game.spare_cells == 1 and game.player.battery > 99 and game.player.flashlight_on, "R replaces empty cell")
	var before: Vector3 = game.player.position
	game.pause_game(true)
	await create_timer(0.2, true).timeout
	check(game.player.position == before, "Pause freezes player")
	check(game.hud.menu_mode == "pause" and game.hud.pause_panel.find_children("*", "Button", true, false).size() == 3, "Escape menu has Resume, Options, Exit game")
	game.hud.show_menu("options_pause")
	check(game.hud.options_panel.visible and game.hud.menu_mode == "options_pause", "Pause Options opens while paused")
	await key(KEY_ESCAPE)
	check(game.hud.menu_mode == "pause" and game.get_tree().paused, "Escape returns from Options to pause menu")
	await key(KEY_ESCAPE)
	check(not game.get_tree().paused and game.hud.menu_mode.is_empty(), "Escape resumes paused game")
	await key(KEY_ESCAPE)
	check(game.get_tree().paused and game.hud.menu_mode == "pause", "Escape opens pause menu")
	game.pause_game(false)
	var landing_impacts: Array[float] = []
	game.player.landed.connect(func(impact_speed: float): landing_impacts.append(impact_speed))
	await frames(5)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(75)
	check(landing_impacts.size() == 1 and landing_impacts[0] > 3.0, "Jump makes one landing sound")
	landing_impacts.clear()
	game.player.position = Vector3(5, 3.0, -1)
	game.player.velocity = Vector3.ZERO
	await frames(80)
	check(landing_impacts.size() == 1 and landing_impacts[0] > 7.0, "Fall makes one stronger landing sound")
	game.player.position = before
	game.player.velocity = Vector3.ZERO
	await frames(5)
	game.player.rotation = Vector3(0, PI, 0)
	Input.action_press("move_forward")
	await frames(150)
	Input.action_release("move_forward")
	await frames(12)
	check(game.player.position.z > -5 and game.player.position.y > -0.1, "Player walks out of ball pit over entry")
	var saved_position: Vector3 = game.player.position
	var nearby_ball := 2700
	var ball_position: Vector3 = game.world.ball_origins[nearby_ball]
	var before_ball: Vector3 = game.world.ball_positions[nearby_ball]
	game.player.position = Vector3(ball_position.x + 0.3, 0.12, ball_position.z)
	game.player.velocity = Vector3(2, 0, 0)
	game.world._animate_balls(0.2)
	check(game.world.ball_positions[nearby_ball].distance_to(before_ball) > 0.01, "Balls move as the player moves through the pit")
	game.player.position = saved_position
	game.player.velocity = Vector3.ZERO
	var upper_hit: Dictionary = game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 3.4, -18), Vector3(0, 1.8, -18), 1))
	check(not upper_hit.is_empty() and upper_hit.position.y > 2.5, "Upper play area has supporting collision")
	game.player.position = Vector3(16.2, 2.86, -17)
	game.player.velocity = Vector3.ZERO
	await frames(30)
	check(game.player.position.y > 2.55, "Player stands on the upper climb platform")
	game.player.position = Vector3(0, 2.85, -18)
	game.player.velocity = Vector3.ZERO
	await frames(30)
	check(game.player.position.y > 2.5, "Player stands inside the upper play modules")
	game.player.position = Vector3(14.5, 0.12, -6.4)
	game.player.velocity = Vector3.ZERO
	game.player.rotation.y = 0
	Input.action_press("move_forward")
	await frames(100)
	Input.action_release("move_forward")
	check(game.player.position.z < -8.5 and game.player.position.y > 0.45, "Player walks onto the climbing ramp from the pit")
	game.player.position = Vector3(-10, 2.85, -18.72)
	game.player.velocity = Vector3.ZERO
	Input.action_press("move_right")
	await frames(180)
	Input.action_release("move_right")
	check(game.player.position.x > -4 and game.player.position.y > 2.5, "Player crosses the upper play modules without falling")
	game.player.position = saved_position
	game.player.velocity = Vector3.ZERO
	# Collect the real items through the game's aim/distance/occlusion check.
	var approaches = game.world.FUSE_APPROACHES
	for destination in approaches + [Vector3(-23, 0.12, 14), Vector3(17.2, 0.12, 13.2), Vector3(-34, 0.12, 0)]:
		check(not game.world.route(game.world.SPAWN, destination).is_empty(), "New map route reaches %s" % destination)
	check(await walk_to(Vector3(23, 0.12, 5.4)), "Player can reach dining beverage system")
	check(await walk_to(Vector3(28, 0.12, 5.4)), "Player can reach dining soda fountain")
	for i in 3:
		check(await walk_to(approaches[i]), "Player walks to fuse %d through map collisions" % (i + 1))
		aim_at(game.items[i].node.global_position)
		await key(KEY_E)
		check(game.fuses == i + 1, "Fuse %d reachable and collectible" % (i + 1))
		game.stalker.active = false
	var cell_approaches := [Vector3(0, 0.12, -2.4), Vector3(-21, 0.12, 16.2)]
	for i in 2:
		check(await walk_to(cell_approaches[i]), "Player walks to spare battery %d" % (i + 1))
		aim_at(game.items[3 + i].node.global_position)
		await key(KEY_E)
		check(game.items[3 + i].taken, "Spare battery %d is reachable" % (i + 1))
	check(await walk_to(Vector3(-23, 0.12, 16.5)), "Player can enter the bathroom")
	check(await walk_to(Vector3(-23, 0.12, 18.6)), "Player can enter a bathroom stall")
	check(await walk_to(Vector3(17.2, 0.12, 13.2)), "Player walks to the kitchen breaker")
	aim_at(game.items[5].node.global_position)
	await key(KEY_E)
	check(game.power_on, "Three fuses restore breaker power")
	check(game.world.powered_lights.all(func(light: OmniLight3D) -> bool: return light.visible), "Breaker turns building lights on")
	check(not game.world.route(game.world.STALKER_SPAWN, Vector3(-34, 0.12, 0)).is_empty(), "Stalker can route around pit to exit")
	check(await walk_to(Vector3(-34, 0.12, 0)), "Player walks back to the west exit")
	aim_at(game.items[6].node.global_position)
	await key(KEY_E)
	check(game.phase == "won", "Powered exit completes game")
	game.phase = "play"
	game.player.control_enabled = true
	game.player.position = Vector3(0, 0.12, -2)
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	game.player.pitch = 0
	game.stalker.position = Vector3(0, 0.12, -4)
	game.stalker.active = true
	game.stalker.grace = 0
	game.player.set_flashlight(true)
	await frames(4)
	check(game.stalker.frozen, "Flashlight freezes visible stalker")
	game.player.set_flashlight(false)
	await frames(4)
	check(not game.stalker.frozen, "Stalker resumes when light switches off")
	game.stalker.position = game.player.position + Vector3(0, 0, -0.5)
	await frames(4)
	check(game.phase == "dead", "Stalker contact triggers failure")
	game.restart()
	await frames(5)
	check(current_scene.phase == "home" and current_scene.fuses == 0, "Restart clears progress and returns home")
	print("SMOKE RESULT: ", failures, " failures")
	quit(1 if failures else 0)
