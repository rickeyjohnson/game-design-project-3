extends Control

var game: Node3D
var font: Font = ThemeDB.fallback_font
var title_font := SystemFont.new()
var lens: ColorRect
var lens_material: ShaderMaterial
var home_panel: PanelContainer
var pause_panel: PanelContainer
var options_panel: PanelContainer
var quality_button: CheckButton
var menu_mode := ""
var draw_clock := 0.0
var ink := Color("f7e9c3")
var muted := Color("a1aaa2")
var gold := Color("e8b64b")
var red := Color("8c2e27")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_font.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])
	lens = ColorRect.new()
	lens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lens_material = ShaderMaterial.new()
	lens_material.shader = preload("res://shaders/lens.gdshader")
	lens.material = lens_material
	lens.show_behind_parent = true
	add_child(lens)
	_home_menu()
	_pause_menu()
	_options_menu()
	show_menu("home")

func _text(at: Vector2, words: String, size_px: int = 16, color: Color = ink, face: Font = null) -> void:
	draw_string(font if face == null else face, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _draw() -> void:
	if game == null or game.player == null:
		return
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1280, 720))
	if game.phase == "home":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.01, 0.01, 0.26))
		draw_rect(Rect2(0, 0, 475, 720), Color(0.045, 0.019, 0.017, 0.56))
		draw_rect(Rect2(48, 171, 7, 342), gold)
		_text(Vector2(73, 227), "R O N A L D ' S", 37, ink, title_font)
		_text(Vector2(75, 324), "THE LAST BIRTHDAY", 17, gold)
		_text(Vector2(75, 494), "RONALD'S FAMILY DINER", 16, ink)
		_text(Vector2(75, 523), "OPEN LATE. STAY FOREVER.", 13, gold)
	elif game.phase == "intro":
		if game.intro_time > 1.4 and game.intro_time < 6.3:
			_text(Vector2(54, 80), "R O N A L D ' S", 44, ink, title_font)
			_text(Vector2(57, 112), "T H E   L A S T   B I R T H D A Y", 12, gold)
	elif game.phase == "play":
		draw_rect(Rect2(38, 35, 390, 84), Color(0.035, 0.025, 0.021, 0.82))
		draw_line(Vector2(38, 35), Vector2(38, 119), gold, 3)
		_text(Vector2(55, 59), "R O N A L D ' S", 12, gold)
		_text(Vector2(55, 87), game.objective, 17)
		_text(Vector2(55, 108), "FUSES   %d / 3" % game.fuses, 11, muted)
		draw_circle(Vector2(640, 360), 2.0, Color(0.85, 0.87, 0.8, 0.7))
		if not game.prompt.is_empty():
			var width := font.get_string_size(game.prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_rect(Rect2(616 - width / 2, 414, width + 48, 40), Color(0.02, 0.03, 0.03, 0.86))
			_text(Vector2(640 - width / 2, 440), game.prompt, 16)
		if game.stalker.active and game.stalker.frozen:
			_text(Vector2(546, 391), "KEEP HIM IN THE LIGHT", 12, gold)
	if game.phase in ["won", "dead"]:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.023, 0.027, 0.94))
		_text(Vector2(95, 196), "R O N A L D ' S   /   T H E   L A S T   B I R T H D A Y", 13, gold)
		_text(Vector2(90, 308), "You made it outside." if game.phase == "won" else "The party never ends.", 53, ink, title_font)
		_text(Vector2(96, 359), "Behind you, a birthday song begins again." if game.phase == "won" else "Keep the beam on him. Run when you need to look away.", 20, muted)
		_text(Vector2(96, 448), "TIME  %02d:%02d     /     FUSES  %d / 3" % [int(game.elapsed) / 60, int(game.elapsed) % 60, game.fuses], 14, gold)
		_text(Vector2(96, 533), "ENTER  Play again       ESC  Quit", 17, ink)
	if menu_mode == "pause" or menu_mode == "options_pause":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.08, 0.025, 0.02, 0.53))
	if game.show_performance and game.phase == "play" and menu_mode.is_empty():
		draw_rect(Rect2(38, 132, 400, 90), Color(0, 0, 0, 0.85))
		_text(Vector2(51, 155), "%d FPS  /  %.1f ms  /  %s" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000, "LOW" if game.low_quality else "STANDARD"], 14)
		_text(Vector2(51, 180), "Draw calls: %d   |   Objects: %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)], 13, muted)
		_text(Vector2(51, 205), "F3  Toggle shadows / render scale", 13, gold)

func _process(delta: float) -> void:
	draw_clock += delta
	if draw_clock >= 0.1:
		draw_clock = 0
		queue_redraw()

func _menu_panel(left: float, top: float, right: float, bottom: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.set_anchor(SIDE_LEFT, left)
	panel.set_anchor(SIDE_TOP, top)
	panel.set_anchor(SIDE_RIGHT, right)
	panel.set_anchor(SIDE_BOTTOM, bottom)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("70271e")
	style.border_color = gold
	style.set_border_width_all(5)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel

func _column(panel: PanelContainer) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 17)
	panel.add_child(column)
	return column

func _heading(parent: Node, words: String, caption: String) -> void:
	var heading := Label.new()
	heading.text = words
	heading.add_theme_font_override("font", title_font)
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", ink)
	parent.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = caption
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", gold)
	parent.add_child(subtitle)
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 12)
	parent.add_child(divider)

func _button(parent: Node, words: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = words
	button.custom_minimum_size.y = 62
	button.add_theme_font_override("font", title_font)
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", Color("61251d"))
	button.add_theme_color_override("font_hover_color", Color("fff1c3"))
	button.add_theme_color_override("font_pressed_color", Color("fff1c3"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("f0d28a")
	normal.border_color = Color("a95530")
	normal.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", normal)
	var hovered := normal.duplicate() as StyleBoxFlat
	hovered.bg_color = Color("b53d2b")
	button.add_theme_stylebox_override("hover", hovered)
	button.add_theme_stylebox_override("pressed", hovered)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func():
		game.sound("pickup")
		callback.call()
	)
	parent.add_child(button)
	return button

func _home_menu() -> void:
	home_panel = _menu_panel(0.68, 0.18, 0.965, 0.82)
	var column := _column(home_panel)
	_heading(column, "RONALD'S", "FAMILY DINER  •  THE LAST BIRTHDAY")
	_button(column, "PLAY", func(): game.start_game())
	_button(column, "OPTIONS", func(): show_menu("options_home"))
	_button(column, "EXIT GAME", func(): get_tree().quit())

func _pause_menu() -> void:
	pause_panel = _menu_panel(0.355, 0.20, 0.645, 0.79)
	var column := _column(pause_panel)
	_heading(column, "Paused", "TAKE A BREAK  •  THE PARTY WAITS")
	_button(column, "Resume", func(): game.pause_game(false))
	_button(column, "Options", func(): show_menu("options_pause"))
	_button(column, "Exit game", func(): get_tree().quit())

func _options_menu() -> void:
	options_panel = _menu_panel(0.32, 0.11, 0.68, 0.9)
	var column := _column(options_panel)
	_heading(column, "Options", "MAKE YOURSELF AT HOME")
	var volume := Label.new()
	volume.text = "VOLUME"
	column.add_child(volume)
	var volume_slider := HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 1
	volume_slider.step = 0.05
	volume_slider.value = 0.8
	volume_slider.value_changed.connect(func(value: float): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.001))))
	volume_slider.drag_started.connect(func(): game.sound("pickup"))
	column.add_child(volume_slider)
	var sensitivity := Label.new()
	sensitivity.text = "MOUSE SENSITIVITY"
	column.add_child(sensitivity)
	var slider := HSlider.new()
	slider.min_value = 0.0006
	slider.max_value = 0.005
	slider.step = 0.0001
	slider.value = game.player.sensitivity
	slider.value_changed.connect(func(value: float): game.player.sensitivity = value)
	slider.drag_started.connect(func(): game.sound("pickup"))
	column.add_child(slider)
	var motion := CheckButton.new()
	motion.text = "Reduce camera motion"
	motion.toggled.connect(func(enabled: bool):
		game.sound("pickup")
		game.player.reduce_motion = enabled
	)
	column.add_child(motion)
	quality_button = CheckButton.new()
	quality_button.text = "Low graphics"
	quality_button.toggled.connect(func(enabled: bool):
		game.sound("pickup")
		game.set_quality(enabled)
	)
	column.add_child(quality_button)
	_button(column, "BACK", func(): show_menu("home" if menu_mode == "options_home" else "pause"))

func show_menu(next_mode: String) -> void:
	menu_mode = next_mode
	home_panel.visible = next_mode == "home"
	pause_panel.visible = next_mode == "pause"
	options_panel.visible = next_mode in ["options_home", "options_pause"]
	queue_redraw()
