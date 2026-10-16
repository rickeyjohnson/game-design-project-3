extends GutTest
## LegacyRoaming: Roaming's stand-in for the F5 game. The mock's Ronald walks
## where the Ruleset says, at its speed, and reports back on the board.


## The parts of the mock's Ronald (scripts/stalker.gd) the stand-in uses.
class FakeRonald:
	extends Node3D
	var active := false
	var driven := false
	var chasing := false
	var cinematic_turning: bool = false
	var walked := 0.0
	var approach := Vector3.ZERO
	func awaken() -> void:
		active = true
	func update_locomotion(distance: float, _delta: float) -> void:
		walked += distance
	func table_approach_target() -> Vector3:
		return approach


## A level with no walls: the route is a straight line, unless `short` cuts it.
class FakeWorld:
	extends Node3D
	const STALKER_SPAWN := Vector3(0, 0.12, 0)
	var short := 0.0 # metres the route stops short of the goal
	var blocked := false
	func route(from: Vector3, to: Vector3) -> PackedVector2Array:
		if blocked:
			return PackedVector2Array()
		var a := Vector2(from.x, from.z)
		var b := Vector2(to.x, to.z)
		if short > 0.0:
			b = b.move_toward(a, short)
		return PackedVector2Array([a, a.lerp(b, 0.5), b])


var board: Blackboard
var ronald: FakeRonald
var world: FakeWorld
var roaming: LegacyRoaming


func before_each() -> void:
	board = Blackboard.new()
	ronald = add_child_autofree(FakeRonald.new())
	ronald.global_position = Vector3(0, 0.12, 0)
	world = autofree(FakeWorld.new())
	roaming = autofree(LegacyRoaming.new())
	roaming.stalker = ronald
	roaming.world = world
	board.writer = roaming.system_id
	roaming.setup(board)
	board.writer = Blackboard.ANY


func _rules(mode: BoardTypes.Mode, target := Vector3.ZERO, speed := 2.0) -> void:
	board.ronald_mode = mode
	board.target_position = target
	board.move_speed = speed


func _tick(delta := 0.5) -> void:
	board.writer = roaming.system_id
	roaming.tick(board, delta)
	board.writer = Blackboard.ANY


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func test_setup_takes_over_the_mock_ronald_and_reports_where_he_is() -> void:
	assert_true(ronald.driven, "his own brain stays off")
	assert_eq(board.enemy_position, Vector3(0, 0.12, 0))


func test_cutscene_turn_and_voice_hold_the_actor_even_with_a_moving_board() -> void:
	_rules(BoardTypes.Mode.SEEK, Vector3(10, 0, 0), 2.0)
	ronald.cinematic_turning = true
	_tick(1.0)
	assert_eq(ronald.global_position, Vector3(0, 0.12, 0))
	assert_eq(board.enemy_velocity, Vector3.ZERO)
	assert_eq(ronald.walked, 0.0)
	ronald.cinematic_turning = false
	_tick(0.5)
	assert_gt(ronald.walked, 0.0)


func test_dormant_he_stays_asleep_and_still() -> void:
	_rules(BoardTypes.Mode.DORMANT, Vector3(5, 0, 0))
	_tick()
	assert_false(ronald.active)
	assert_eq(ronald.global_position, Vector3(0, 0.12, 0))


func test_wakes_up_when_the_rules_do_and_patrols_on_his_own() -> void:
	_rules(BoardTypes.Mode.PATROL, Vector3.ZERO, 1.4)
	_tick()
	assert_true(ronald.active)
	assert_gt(ronald.walked, 0.0, "he picks his own patrol spot and walks")
	assert_almost_eq(ronald.walked, 0.7, 0.01, "1.4 m/s for 0.5 s")
	assert_eq(board.enemy_position, ronald.global_position)


func test_walks_to_the_target_at_the_rules_speed() -> void:
	_rules(BoardTypes.Mode.INVESTIGATE, Vector3(10, 0, 0), 2.0)
	_tick(0.5)
	assert_almost_eq(ronald.global_position.x, 1.0, 0.01)
	assert_eq(board.enemy_position, ronald.global_position)
	assert_almost_eq(board.enemy_velocity.x, 2.0, 0.01)
	assert_false(board.at_target)
	assert_false(board.target_unreachable)


func test_a_long_frame_walks_past_several_waypoints() -> void:
	_rules(BoardTypes.Mode.INVESTIGATE, Vector3(10, 0, 0), 2.0)
	_tick(4.0)
	assert_almost_eq(ronald.global_position.x, 8.0, 0.01)


func test_reports_arriving() -> void:
	_rules(BoardTypes.Mode.INVESTIGATE, Vector3(3, 0, 0), 2.0)
	for i in 4:
		_tick(0.5)
	assert_true(board.at_target)
	assert_false(board.target_unreachable)
	assert_almost_eq(_flat(ronald.global_position, Vector3(3, 0, 0)), 0.0, 0.01)


func test_reports_unreachable_at_the_end_of_a_route_that_stops_short() -> void:
	world.short = 3.0
	_rules(BoardTypes.Mode.SEEK, Vector3(10, 0, 0), 2.0)
	_tick(2.0)
	assert_false(board.target_unreachable, "still walking")
	_tick(2.0)
	assert_almost_eq(ronald.global_position.x, 7.0, 0.01, "as close as the route goes")
	assert_false(board.at_target)
	assert_true(board.target_unreachable)


func test_no_route_at_all_is_unreachable_at_once() -> void:
	world.blocked = true
	_rules(BoardTypes.Mode.INVESTIGATE, Vector3(10, 0, 0), 2.0)
	_tick()
	assert_true(board.target_unreachable)
	assert_eq(ronald.global_position, Vector3(0, 0.12, 0))


func test_a_hidden_player_is_reached_from_the_open_side_of_the_table() -> void:
	board.hide_state = BoardTypes.Hide.HIDDEN
	board.player_position = Vector3(4, 0.12, 0)
	ronald.approach = Vector3(4, 0.12, 1.5)
	_rules(BoardTypes.Mode.SEEK, Vector3(4, 0.12, 0), 2.0)
	for i in 8:
		_tick(0.5)
	assert_almost_eq(_flat(ronald.global_position, ronald.approach), 0.0, 0.01)
	assert_false(board.at_target, "he can't get under the table")
	assert_true(board.target_unreachable, "so the rules treat this as arriving")


func test_speed_zero_stands_still_facing_the_target() -> void:
	_rules(BoardTypes.Mode.CATCH, Vector3(0, 0.12, 3), 0.0)
	_tick()
	assert_eq(ronald.global_position, Vector3(0, 0.12, 0))
	var facing := -ronald.global_basis.z
	assert_almost_eq(facing.z, 1.0, 0.01, "the stare: he faces the player")


func test_poses_where_he_stands() -> void:
	_rules(BoardTypes.Mode.POSE, Vector3(8, 0, 8), 1.4)
	_tick()
	assert_true(board.at_target)
	assert_eq(ronald.global_position, Vector3(0, 0.12, 0))


func test_chasing_is_flagged_for_the_chase_music() -> void:
	_rules(BoardTypes.Mode.CHASE, Vector3(10, 0, 0), 4.6)
	_tick()
	assert_true(ronald.chasing)
	_rules(BoardTypes.Mode.PATROL, Vector3.ZERO, 1.4)
	_tick()
	assert_false(ronald.chasing)


func test_stops_when_the_run_is_over() -> void:
	_rules(BoardTypes.Mode.CHASE, Vector3(10, 0, 0), 4.6)
	board.game_state = BoardTypes.Game.CAUGHT
	_tick()
	assert_eq(ronald.global_position, Vector3(0, 0.12, 0))
	assert_false(ronald.chasing)
	assert_eq(board.enemy_velocity, Vector3.ZERO)


func test_wakes_him_once_and_never_drags_him_back_to_his_spawn() -> void:
	_rules(BoardTypes.Mode.INVESTIGATE, Vector3(10, 0, 0), 2.0)
	_tick()
	ronald.active = false # the game took him out of play
	var at := ronald.global_position
	_tick()
	assert_false(ronald.active, "not woken again")
	assert_eq(ronald.global_position, at, "and he stays where he is")
	assert_eq(board.enemy_velocity, Vector3.ZERO)
