extends GutTest

func test_f5_game_can_hide_at_a_real_dining_table() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var game: Node3D = packed.instantiate() as Node3D
	add_child_autofree(game)
	game.call("start_game")
	game.call("finish_intro")
	var hiding: HidingSystem = game.get("hiding") as HidingSystem
	assert_not_null(hiding, "F5 game must include HidingSystem")
	if hiding == null:
		return
	var director: Director = game.get("hiding_director") as Director
	game.set_physics_process(false)
	var player: CharacterBody3D = game.get("player") as CharacterBody3D
	var events: HorrorEvents = game.get("horror_events") as HorrorEvents
	events.flash_delay = 0.0
	events.call("_process", 0.01)
	assert_false(events.screen.visible, "No warning before Ronald spawns")
	var spawned: Node3D = game.get("stalker") as Node3D
	spawned.call("awaken")
	game.set("fuses", 1) # the Ruleset wakes Ronald at the first fuse (D-019)
	spawned.set_physics_process(false)
	var trial: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_value: int = 0
	while true:
		trial.seed = seed_value
		if trial.randf() < HorrorEvents.FLASH_CHANCE:
			events._rng.seed = seed_value
			break
		seed_value += 1
	events.call("_process", 0.01)
	assert_true(events.screen.visible)
	assert_eq(events.screen.words, "you better run")
	game.call("pause_game", true)
	assert_false(events.screen.visible, "Pausing cancels the face flash so the menu stays usable")
	assert_false(events.static_audio.playing)
	game.call("pause_game", false)
	player.set_physics_process(false)
	player.global_position = Vector3(13, 0.12, -2.5)
	player.rotation = Vector3.ZERO
	await wait_seconds(0.15)
	assert_not_null(hiding._nearby_spot(), "Real table must offer a hiding interaction")
	var press_e: InputEventKey = InputEventKey.new()
	press_e.keycode = KEY_E
	press_e.physical_keycode = KEY_E
	press_e.pressed = true
	game.call("_unhandled_input", press_e)
	director.step(0.5)
	assert_eq(director.board.hide_state, BoardTypes.Hide.HIDDEN)
	assert_true(hiding.hud.bar.visible)
	assert_true(bool(player.get("hiding_locked")))
	var spots: Array[Node] = get_tree().get_nodes_in_group(HideSpot.GROUP)
	assert_eq(spots.size(), 15, "Seven dining tables, five booth tables and three prep-counter covers")
	for node: Node in spots:
		assert_eq((node as HideSpot).spot_type, HideSpot.Kind.TABLE)
	assert_almost_eq(player.camera.global_position.y, 0.5, 0.001, "Eyes stay below the tabletop")
	assert_gt(absf(player.global_position.z + 4.0), 0.4, "Eyes must be clear of the center pedestal")
	var world: Node3D = game.get("world") as Node3D
	for bounds: AABB in world.get("obstacles"):
		assert_false(bounds.grow(0.025).has_point(player.camera.global_position), "Hiding camera cannot be inside level collision: %s" % bounds)
	var mouse: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse.relative = Vector2(100, 100)
	player.call("apply_mouse_look", mouse.relative)
	assert_eq(player.camera.rotation.x, 0.0)
	assert_false(is_equal_approx(player.rotation.y, PI), "Table mouse look must still turn left/right")
	var feedback: HorrorFeedback = game.get("horror_feedback") as HorrorFeedback
	var stalker: Node3D = game.get("stalker") as Node3D
	stalker.set_physics_process(false)
	stalker.set("active", true)
	stalker.set("grace", 0.0)
	player.call("set_flashlight", true)
	assert_false(bool(player.call("beam_hits", stalker.global_position + Vector3.UP * 1.55)), "Hidden flashlight has no effect on Ronald")
	stalker.global_position = player.global_position + Vector3(0.2, 0, 0)
	stalker.call("_physics_process", 0.0)
	assert_false(bool(stalker.get("frozen")), "He cannot be frozen while player is hidden")
	assert_eq(game.get("phase"), "play", "Ronald cannot catch an unexposed hiding player")
	# A few metres off, so "I see you" comes well before he arrives (Ruleset Q4).
	stalker.global_position = Vector3(13, 0.12, -0.5)
	director.step(0.0) # Roaming reports where he is now
	director.step(7.0)
	assert_true(director.board.location_leaked)
	feedback.observe(director.board.location_leaked, true)
	feedback.observe(director.board.location_leaked, true)
	assert_eq(feedback.leak_cue_count, 1, "Timeout voice plays once per leak")
	assert_eq(feedback.chase_started_count, 1, "Music starts once per chase")
	assert_not_null(feedback.voice.stream)
	assert_not_null(feedback.music.stream)
	assert_gt(feedback.voice.stream.get_length(), 0.5)
	assert_true(feedback.chasing)
	var cutscene: TimeoutCutscene = game.get("timeout_scene") as TimeoutCutscene
	var player_view: Transform3D = player.camera.transform
	stalker.global_position = Vector3(13, 0.12, -0.5)
	game.call("_physics_process", 0.0)
	assert_true(cutscene.active, "Actual hiding leak starts the cutaway")
	assert_false(bool(player.get("control_enabled")))
	var warning_position: Vector3 = stalker.global_position
	director.step(0.1)
	assert_eq(stalker.global_position, warning_position, "Board movement respects the cutscene turn")
	cutscene.tick(true, cutscene.TURN_SECONDS + 0.01)
	assert_eq(cutscene.voice_count, 1)
	director.step(5.0) # even after the rules' warning delay, the voice owns the actor
	assert_eq(stalker.global_position, warning_position, "Board movement respects the spoken warning")
	cutscene.tick(true, cutscene.voice_seconds)
	assert_true(bool(stalker.get("cinematic_sprinting")))
	stalker.call("_physics_process", 0.1)
	assert_eq(game.get("phase"), "play", "Cutaway sprint cannot kill while the camera is away")
	stalker.global_position = stalker.get("cinematic_target") as Vector3
	cutscene.tick(true, 0.51)
	assert_false(cutscene.active)
	assert_true(bool(player.get("control_enabled")))
	assert_true(player.camera.current)
	assert_eq(player.camera.transform, player_view)
	assert_almost_eq(float(stalker.call("movement_speed", false)), 3.3, 0.001)
	# Out of sight while the player leaves and the timer refills; with the
	# Ruleset in charge he'd otherwise see them and start the stare.
	stalker.global_position = Vector3(-30, 0.12, -10)
	director.step(0.0) # Roaming reports where he is now
	game.call("interact")
	director.step(0.0)
	assert_eq(director.board.hide_state, BoardTypes.Hide.EXPOSED)
	assert_false(bool(player.get("hiding_locked")))
	feedback.observe(false, false)
	assert_false(feedback.chasing)
	assert_false(feedback.music.playing)
	assert_eq(player.global_position, Vector3(13, 0.12, -2.5))
	director.step(14.0)
	assert_eq(hiding.timer.remaining, 7.0)
	# After the timer leaks, the actual main-game enemy can locate/catch us.
	hiding.interact_requested = true
	director.step(0.5)
	director.step(7.0)
	# Approach using the real navigation grid, rather than teleporting Ronald
	# beneath furniture. The table blocks his body from reaching touch range.
	stalker.global_position = Vector3(13, 0.12, -0.5)
	feedback.observe(director.board.location_leaked, true)
	assert_eq(feedback.leak_cue_count, 2, "A later hiding timeout gets a new voice cue")
	stalker.call("_physics_process", 0.0)
	assert_eq(game.get("phase"), "play", "Timeout reveals the player; Ronald must approach before catching")
	for frame: int in 400:
		var before_warning: Vector3 = stalker.global_position
		var holding_warning: bool = bool(stalker.get("cinematic_turning"))
		game.call("_physics_process", 0.1) # the Ruleset decides; the board walks him
		if holding_warning:
			assert_eq(stalker.global_position, before_warning, "Real board-driven Ronald stays still throughout the turn and voice")
		if game.get("phase") == "caught":
			break
	assert_eq(game.get("phase"), "caught", "Real spawned Ronald starts his catch cutscene")
	assert_lt(stalker.global_position.distance_to(player.global_position), 2.0, "Ronald must be within table reach")
	assert_false(feedback.chasing, "Game over stops chase music")
	var scares: HorrorEvents = game.get("horror_events") as HorrorEvents
	assert_false(scares.screen.visible, "Actual catch must not show the warning GUI")
	assert_eq(scares.scream_count, 1)
	var catch_scene: CatchCutscene = game.get("catch_scene") as CatchCutscene
	assert_true(catch_scene.active)
	assert_true(catch_scene.camera.current)
	catch_scene.advance(catch_scene.JUMP_SECONDS)
	assert_lt(catch_scene.head_position().distance_to(catch_scene.camera.global_position), 0.5)
	catch_scene.advance(catch_scene.HOLD_SECONDS + 0.01)
	assert_eq(game.get("phase"), "dead", "Death screen appears only after the leap cutscene")
	# The full imported diner reports null-material diagnostics in both renderers.
	# Track these explicitly; do not ignore script errors or unrelated engine errors.
	var material_diagnostics: int = 1 if DisplayServer.get_name() == "headless" else 4
	for diagnostic: int in range(material_diagnostics):
		assert_engine_error('Parameter "material" is null.')
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
