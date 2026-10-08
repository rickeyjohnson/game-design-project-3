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
	game.player.position = Vector3(0, 0, -0.5)
	game.player.camera.rotation.x = -0.08
	game.player.pitch = -0.08
	game.stalker.awaken()
	game.stalker.position = Vector3(0, 0, -4.6)
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
	game.pause_game(true)
	await capture("06-pause")
	game.hud.show_menu("options_pause")
	await capture("07-pause-options")
	quit()
