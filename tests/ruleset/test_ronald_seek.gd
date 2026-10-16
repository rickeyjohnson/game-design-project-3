extends GutTest
## "I see you": a whisper, at least 5 s of warning, then he comes to the spot (Q4).

var board: Blackboard
var rules: RonaldRules


func before_each() -> void:
	board = Blackboard.new()
	rules = RonaldRules.new(RonaldTuning.new())
	board.fuses_collected = 1
	rules.step(board, 0.0) # wakes from DORMANT (one mode change per frame)
	board.enemy_position = Vector3(20, 0, 0)


func _hide_and_leak(spot: StringName) -> void:
	board.hide_state = BoardTypes.Hide.HIDDEN
	board.hide_spot = spot
	board.location_leaked = true


func test_a_leak_whispers_and_seeks_the_spot() -> void:
	_hide_and_leak(&"booth_2")
	rules.step(board, 0.1)
	assert_eq(rules.mode, BoardTypes.Mode.SEEK)
	assert_eq(rules.target, board.player_position)
	assert_has(rules.cues, &"whisper")


func test_waits_so_the_whisper_comes_at_least_five_seconds_before_he_arrives() -> void:
	board.enemy_position = Vector3(2, 0, 0) # 1 s away at 2 m/s
	_hide_and_leak(&"booth_2")
	rules.step(board, 0.1)
	assert_eq(rules.speed, 0.0, "waits instead of arriving in 1 s")
	rules.step(board, 4.0)
	assert_eq(rules.speed, 0.0, "warning finishes before he starts walking")
	rules.step(board, 1.0)
	assert_eq(rules.speed, rules.tuning.search_speed)


func test_distant_ronald_also_waits_before_approaching() -> void:
	_hide_and_leak(&"table_1")
	rules.step(board, 0.1)
	assert_eq(rules.speed, 0.0)
	rules.step(board, 4.9)
	assert_eq(rules.speed, 0.0)
	rules.step(board, 0.1)
	assert_eq(rules.speed, rules.tuning.search_speed)


func test_already_beside_the_spot_he_still_waits_out_the_warning() -> void:
	board.enemy_position = Vector3(1.5, 0, 0) # at the table's open side
	_hide_and_leak(&"table_3")
	rules.step(board, 0.1) # the whisper
	board.target_unreachable = true # as close as he gets: under the table is out of reach
	rules.step(board, 4.5)
	assert_eq(rules.mode, BoardTypes.Mode.SEEK, "not before 5 s")
	rules.step(board, 0.5)
	assert_eq(rules.mode, BoardTypes.Mode.CATCH)


func test_still_in_the_spot_when_he_arrives_means_caught() -> void:
	_hide_and_leak(&"booth_2")
	rules.step(board, 0.1)
	rules.step(board, 5.0) # the warning, then the walk
	board.at_target = true
	rules.step(board, 0.1)
	assert_eq(rules.mode, BoardTypes.Mode.CATCH)


func test_an_empty_spot_when_he_arrives_means_he_searches_it() -> void:
	_hide_and_leak(&"booth_2")
	rules.step(board, 0.1)
	rules.step(board, 5.0) # the warning, then the walk
	board.hide_state = BoardTypes.Hide.EXPOSED
	board.hide_spot = &""
	board.location_leaked = false
	board.at_target = true
	rules.step(board, 0.1)
	assert_eq(rules.mode, BoardTypes.Mode.INVESTIGATE)


func test_whispers_once_per_visit() -> void:
	_hide_and_leak(&"booth_2")
	rules.step(board, 0.1)
	rules.step(board, 0.1)
	assert_does_not_have(rules.cues, &"whisper")


func test_a_new_visit_can_leak_again() -> void:
	_hide_and_leak(&"booth_2")
	rules.step(board, 0.1)
	board.hide_state = BoardTypes.Hide.EXPOSED
	board.location_leaked = false
	rules.step(board, 0.1)
	_hide_and_leak(&"booth_3")
	rules.step(board, 0.1)
	assert_has(rules.cues, &"whisper")


func test_moving_straight_to_another_spot_counts_as_a_new_visit() -> void:
	_hide_and_leak(&"booth_2")
	rules.step(board, 0.1)
	_hide_and_leak(&"booth_3") # never came out in between
	rules.step(board, 0.1)
	assert_has(rules.cues, &"whisper")
