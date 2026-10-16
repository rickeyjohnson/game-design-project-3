extends GutTest
## Ronald's core rules: patrol, investigate, chase, losing track.

var board: Blackboard
var rules: RonaldRules


func test_safe_table_hiding_abandons_the_chase_even_with_stale_sight() -> void:
	board.detection = BoardTypes.Detect.SEEN
	rules.step(board, 0.1)
	board.hide_state = BoardTypes.Hide.HIDDEN
	board.hide_spot = &"table_1"
	rules.step(board, 0.1)
	assert_eq(rules.mode, BoardTypes.Mode.PATROL)
	assert_eq(rules.speed, rules.tuning.patrol_speed)
	rules.step(board, 3.0)
	assert_eq(rules.mode, BoardTypes.Mode.PATROL)


func before_each() -> void:
	board = Blackboard.new() # writer is ANY: arrange freely
	rules = RonaldRules.new(RonaldTuning.new())
	board.player_position = Vector3(0, 0, 0)
	board.enemy_position = Vector3(10, 0, 0)
	board.fuses_collected = 1
	rules.step(board, 0.0) # wakes from DORMANT (one mode change per frame)


func test_starts_patrolling_at_patrol_speed() -> void:
	rules.step(board, 0.1)
	assert_eq(rules.mode, BoardTypes.Mode.PATROL)
	assert_eq(rules.speed, rules.tuning.patrol_speed)


func test_seen_means_chase_the_player_and_honk() -> void:
	board.detection = BoardTypes.Detect.SEEN
	rules.step(board, 0.1)
	assert_eq(rules.mode, BoardTypes.Mode.CHASE)
	assert_eq(rules.target, board.player_position)
	assert_eq(rules.speed, rules.tuning.chase_speed)
	assert_has(rules.cues, &"honk")


func test_honks_once_per_chase_not_every_frame() -> void:
	board.detection = BoardTypes.Detect.SEEN
	rules.step(board, 0.1)
	rules.step(board, 0.1)
	assert_does_not_have(rules.cues, &"honk")


func test_heard_means_investigate_the_last_known_position() -> void:
	board.detection = BoardTypes.Detect.HEARD
	board.last_known_position = Vector3(4, 0, 2)
	rules.step(board, 0.1)
	assert_eq(rules.mode, BoardTypes.Mode.INVESTIGATE)
	assert_eq(rules.target, Vector3(4, 0, 2))
	assert_eq(rules.speed, rules.tuning.search_speed)


func test_keeps_chasing_through_a_short_loss_of_sight() -> void:
	board.detection = BoardTypes.Detect.SEEN
	rules.step(board, 0.1)
	board.detection = BoardTypes.Detect.NONE
	rules.step(board, rules.tuning.lose_track_after - 0.5)
	assert_eq(rules.mode, BoardTypes.Mode.CHASE)


func test_loses_track_after_two_seconds_and_searches_the_last_known_position() -> void:
	board.detection = BoardTypes.Detect.SEEN
	board.last_known_position = Vector3(1, 0, 1)
	rules.step(board, 0.1)
	board.detection = BoardTypes.Detect.NONE
	rules.step(board, rules.tuning.lose_track_after)
	assert_eq(rules.mode, BoardTypes.Mode.INVESTIGATE)
	assert_eq(rules.target, Vector3(1, 0, 1))


func test_searches_for_five_seconds_after_arriving_then_patrols() -> void:
	board.detection = BoardTypes.Detect.HEARD
	rules.step(board, 0.1)
	board.detection = BoardTypes.Detect.NONE
	board.at_target = true
	rules.step(board, rules.tuning.search_time - 0.5)
	assert_eq(rules.mode, BoardTypes.Mode.INVESTIGATE)
	rules.step(board, 0.5)
	assert_eq(rules.mode, BoardTypes.Mode.PATROL)


func test_a_very_long_frame_changes_mode_only_once() -> void: # Review focus 1
	board.detection = BoardTypes.Detect.SEEN
	rules.step(board, 0.1)
	board.detection = BoardTypes.Detect.NONE
	rules.step(board, 30.0) # the browser tab was in the background
	assert_eq(rules.mode, BoardTypes.Mode.INVESTIGATE, "loses track, but doesn't skip ahead to patrol")
