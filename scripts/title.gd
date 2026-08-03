extends Control
## 타이틀 화면

const COL_BG := Color("12141c")
const COL_GOLD := Color("e0b95e")
const COL_MUTED := Color("9aa0b4")


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/bg.gdshader")
	bg.material = mat
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var jiji := TextureRect.new()
	jiji.texture = load("res://assets/characters/jiji.svg")
	jiji.custom_minimum_size = Vector2(220, 220)
	jiji.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	jiji.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(jiji)
	jiji.pivot_offset = Vector2(110, 150)
	var idle := jiji.create_tween().set_loops()
	idle.tween_property(jiji, "rotation", 0.04, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle.tween_property(jiji, "rotation", -0.04, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var title := Label.new()
	title.text = "GG 경매 시뮬레이터"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "실제 경매 데이터로 배우는 낙찰의 기술 — 지지옥션"
	subtitle.add_theme_color_override("font_color", COL_MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	box.add_child(spacer)

	var start := Button.new()
	start.text = "입찰하러 가기"
	start.custom_minimum_size = Vector2(260, 52)
	var s := StyleBoxFlat.new()
	s.bg_color = COL_GOLD
	s.set_corner_radius_all(10)
	start.add_theme_stylebox_override("normal", s)
	var sh: StyleBoxFlat = s.duplicate()
	sh.bg_color = Color("f0cd7a")
	start.add_theme_stylebox_override("hover", sh)
	var sp: StyleBoxFlat = s.duplicate()
	sp.bg_color = Color("c9a44b")
	start.add_theme_stylebox_override("pressed", sp)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		start.add_theme_color_override(state, Color("1a1508"))
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_on_start)
	box.add_child(start)

	var quit := Button.new()
	quit.text = "종료"
	quit.custom_minimum_size = Vector2(260, 44)
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)

	# 페이드 인
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _on_start() -> void:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://assets/sfx/gavel.wav")
	add_child(player)
	player.play()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
