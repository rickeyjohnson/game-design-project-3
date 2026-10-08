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
	check(game.hud.home_panel.visible and game.hud.home_panel.find_children("*", "Button", true, false).size() == 3, "Home has Play, Options, Exit game")
	game.hud.show_menu("options_home")
	check(game.hud.options_panel.visible and game.hud.quality_button != null, "Home Options shows settings")
	game.hud.show_menu("home")
	game.start_game()
	check(game.phase == "intro" and not game.player.control_enabled, "Opening locks movement")
	check(game.player.animation.has_animation("wake_up"), "Wake/pocket animation exists")
	check(game.world.batch_count < 80, "Imported diner merged into fewer than 80 batches")
	await create_timer(8.7).timeout
	check(game.phase == "play" and game.player.control_enabled, "Opening finishes and unlocks movement")
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
	game.player.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	await frames(150)
	Input.action_release("move_forward")
	await frames(12)
	check(game.player.position.z < 0.8 and game.player.position.y > -0.1, "Player walks out of ball pit over entry")
	# Collect the real items through the game's aim/distance/occlusion check.
	var approaches := [Vector3(-6.2, 0, -2.65), Vector3(6.2, 0, 4.6), Vector3(9.8, 0, -4.7)]
	for i in 3:
		game.player.position = approaches[i]
		game.player.velocity = Vector3.ZERO
		await frames(3)
		aim_at(game.items[i].node.global_position)
		await key(KEY_E)
		check(game.fuses == i + 1, "Fuse %d reachable and collectible" % (i + 1))
		game.stalker.active = false
	game.player.position = Vector3(10.2, 0, -5.6)
	await frames(3)
	aim_at(game.items[5].node.global_position)
	await key(KEY_E)
	check(game.power_on, "Three fuses restore breaker power")
	check(not game.world.route(Vector3(3.5, 0, -4.4), Vector3(0, 0, 7.8)).is_empty(), "Stalker can route around pit to exit")
	game.player.position = Vector3(0, 0, 7.5)
	await frames(3)
	aim_at(game.items[6].node.global_position)
	await key(KEY_E)
	check(game.phase == "won", "Powered exit completes game")
	game.phase = "play"
	game.player.control_enabled = true
	game.player.position = Vector3(0, 0, -2)
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	game.player.pitch = 0
	game.stalker.position = Vector3(0, 0, -4)
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
