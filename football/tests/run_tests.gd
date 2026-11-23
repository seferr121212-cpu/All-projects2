extends SceneTree
## Headless test koşucu:
##   godot --headless --fixed-fps 120 -s res://tests/run_tests.gd
## (--fixed-fps 120 fizik testlerini gerçek zamandan bağımsız hızlı çalıştırır)

const TEST_FILES := [
	"res://tests/test_goal_detection.gd",
	"res://tests/test_ball_physics.gd",
	"res://tests/test_goal_scene.gd",
	"res://tests/test_pass_targeting.gd",
	"res://tests/test_player_movement.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var passed := 0
	var failed := 0
	for path in TEST_FILES:
		var suite: Node = load(path).new()
		root.add_child(suite)
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			suite.failures.clear()
			await suite.call(name)
			if suite.failures.is_empty():
				passed += 1
				print("  OK   %s::%s" % [path.get_file(), name])
			else:
				failed += 1
				print("  FAIL %s::%s" % [path.get_file(), name])
				for f in suite.failures:
					print("       - ", f)
		suite.queue_free()
	print("\nSonuç: %d geçti, %d başarısız" % [passed, failed])
	quit(1 if failed > 0 else 0)
