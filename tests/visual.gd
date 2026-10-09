extends SceneTree
## Rendered capture and frame-time sample; output lives in ignored reviews/.
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reviews/" + filename + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reviews"))
	var ignore := FileAccess.open("res://reviews/.gdignore", FileAccess.WRITE)
	ignore.close()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await create_timer(0.5).timeout
	await capture("00-home")
	game.hud.show_menu("options_home")
	await capture("00-options")
	game.hud.show_menu("home")
	game.start_game()
	await create_timer(2.0).timeout
	await capture("01-waking")
	await create_timer(4.0).timeout
	await capture("02-pocket")
	await create_timer(3.0).timeout
	game.pause_game(false)
	await capture("03-flashlight")
	game.player.position = Vector3(8, 0.12, -4)
	game.player.rotation = Vector3(0, PI, 0)
	game.player.camera.rotation.x = -0.08
	game.player.pitch = -0.08
	game.stalker.awaken()
	game.stalker.position = Vector3(8, 0.12, 1)
	game.show_performance = true
	await create_timer(1).timeout
	await capture("04-diner")
	var samples: Array[float] = []
	for i in 120:
		var start := Time.get_ticks_usec()
		await process_frame
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	samples.sort()
	print("RENDER SAMPLE: median %.2f ms; p95 %.2f ms; draw calls %d; primitives %d" % [samples[60], samples[114], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	game.set_quality(true)
	await create_timer(0.5).timeout
	await capture("05-low")
	game.stalker.active = false
	game.set_quality(false)
	game.show_performance = false
	var views := [
		["08-play-place", Vector3(8, 0.12, -3), Vector3(0, 2, -16)],
		["09-kitchen", Vector3(-2, 0.12, 17), Vector3(13, 1.8, 19)],
		["10-freezer", Vector3(21, 0.12, 16), Vector3(24, 1.3, 18)],
		["11-restrooms", Vector3(-23, 0.12, 12), Vector3(-23, 1.2, 18)],
		["12-dining", Vector3(-10, 0.12, 0), Vector3(9, 1.4, 3)],
		["13-beverages", Vector3(20, 0.12, 5), Vector3(26, 1.4, 7)],
		["14-service-counter", Vector3(-11, 0.12, 5.5), Vector3(2.5, 1.4, 8)],
		["15-ball-pit-down", Vector3(0, 0.12, -14), Vector3(0, 0.15, -14.8)],
		["16-kitchen-from-tables", Vector3(5, 0.12, -2.5), Vector3(5, 1.5, 13)],
		["17-play-glass-back", Vector3(0, 0.12, -14), Vector3(0, 1.5, -22)],
		["18-play-glass-left", Vector3(-15, 0.12, -14), Vector3(-21, 1.5, -14)],
		["19-bathroom-entrance", Vector3(-23, 0.12, 11), Vector3(-23, 1.2, 17)]
	]
	for view in views:
		game.player.position = view[1]
		game.player.velocity = Vector3.ZERO
		game.player.camera.look_at(view[2])
		game.player.pitch = game.player.camera.rotation.x
		await create_timer(0.2).timeout
		await capture(view[0])
	game.pause_game(true)
	await capture("06-pause")
	game.hud.show_menu("options_pause")
	await capture("07-pause-options")
	quit()
