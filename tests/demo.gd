extends SceneTree
## 자동 플레이 데모 (스크린샷·영상 캡처용): godot --path . -s res://tests/demo.gd

func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._show_tab("comps")
	main._show_tab("rights")
	main._answer_quiz(true)
	main._show_tab("site")
	main.bid_edit.text = "5000"
	main._on_bid()  # 이후 개찰 세리머니가 자동 진행
