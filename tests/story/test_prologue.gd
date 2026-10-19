extends GutTest
## The prologue's steps complete in order from what the game reports.


func _p() -> Prologue:
	return Prologue.new()


func test_it_starts_at_the_siding_and_waits_for_the_player() -> void:
	var p := _p()
	assert_eq(p.current_id(), "arrive")
	assert_eq(p.update({}).size(), 0)
	p.acknowledge()
	assert_eq(p.update({}), ["arrive"] as Array[String])
	assert_eq(p.current_id(), "road")


func test_steps_finish_in_order_not_early() -> void:
	var p := _p()
	# Everything is true but the player hasn't looked around yet.
	var ctx := {"road": true, "store": {"door": true, "window": true, "exchange": true}, "houses": 3, "families": 3}
	assert_eq(p.update(ctx).size(), 0)
	p.acknowledge()
	var done := p.update(ctx)
	assert_eq(done, ["arrive", "road", "store", "houses", "families"] as Array[String])
	assert_eq(p.current_id(), "week")


func test_the_store_needs_all_three_things() -> void:
	var p := _p()
	p.acknowledge()
	p.update({"road": true})
	assert_eq(p.current_id(), "store")
	p.update({"store": {"door": true, "window": false, "exchange": true}})
	assert_eq(p.current_id(), "store")
	var list := p.checklist()
	assert_eq(list.size(), 3)
	assert_true(list[0]["done"] and not list[1]["done"] and list[2]["done"])
	p.update({"store": {"door": true, "window": true, "exchange": true}})
	assert_eq(p.current_id(), "houses")


func test_the_week_runs_until_the_dance_on_saturday() -> void:
	var p := _p()
	p.acknowledge()
	p.update({"road": true, "store": {"door": true, "window": true, "exchange": true}, "houses": 3, "families": 3})
	assert_eq(p.current_id(), "week")
	p.update({"day": 5, "minute": 1000, "dance_at": 5 * 1440 + 1170})
	assert_eq(p.current_id(), "week", "not yet 7:30 pm Saturday")
	p.update({"day": 5, "minute": 1170, "dance_at": 5 * 1440 + 1170})
	assert_eq(p.current_id(), "alert")


func test_the_case_closing_unlocks_the_lesson_and_then_the_town() -> void:
	var p := _p()
	p.acknowledge()
	p.update({"road": true, "store": {"door": true, "window": true, "exchange": true}, "houses": 3, "families": 3, "day": 5, "minute": 1200, "dance_at": 5 * 1440 + 1170, "case_open": true})
	assert_eq(p.current_id(), "solve")
	assert_true(p.is_locked("footpaths") and p.is_locked("street_lamps"))
	p.update({"case_done": true})
	assert_eq(p.current_id(), "lesson")
	assert_false(p.is_locked("footpaths"), "unlocked once the case is solved")
	p.acknowledge()
	p.update({})
	assert_true(p.finished)


func test_a_save_restores_where_the_player_was() -> void:
	var p := _p()
	p.acknowledge()
	p.update({"road": true})
	var q := _p()
	q.restore(p.snapshot())
	assert_eq(q.current_id(), "store")
	assert_eq(q.snapshot(), p.snapshot())
