class_name Juice
## UI 연출 유틸. 재트리거 시 트윈 누적을 막기 위해 노드 메타에 기존 트윈을 저장·kill 한다.

static func _tween_for(node: Control, key: String) -> Tween:
	var prev: Tween = node.get_meta(key) if node.has_meta(key) else null
	if prev:
		prev.kill()
	var tw := node.create_tween()
	node.set_meta(key, tw)
	return tw


## 버튼 호버/클릭 스케일 (한 번만 연결)
static func button(b: Button) -> void:
	b.pivot_offset = b.size / 2.0
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.mouse_entered.connect(_scale_to.bind(b, Vector2(1.05, 1.05)))
	b.mouse_exited.connect(_scale_to.bind(b, Vector2.ONE))
	b.button_down.connect(_scale_to.bind(b, Vector2(0.95, 0.95)))
	b.button_up.connect(_scale_to.bind(b, Vector2(1.05, 1.05)))


static func _scale_to(b: Control, target: Vector2) -> void:
	_tween_for(b, "_j_scale").tween_property(b, "scale", target, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 팝 등장 (결과창·팝업)
static func pop_in(c: Control) -> void:
	c.visible = true
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(0.92, 0.92)
	c.modulate.a = 0.0
	var tw := _tween_for(c, "_j_pop").set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.18)


## 펀치 (강조 순간)
static func punch(c: Control, strength := 1.12) -> void:
	c.pivot_offset = c.size / 2.0
	var tw := _tween_for(c, "_j_punch")
	tw.tween_property(c, "scale", Vector2.ONE * strength, 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 흔들림 (낙찰/충격 순간)
static func shake(c: Control, amount := 7.0, duration := 0.3) -> void:
	var origin: Vector2 = c.get_meta("_j_origin") if c.has_meta("_j_origin") else c.position
	c.set_meta("_j_origin", origin)
	var tw := _tween_for(c, "_j_shake")
	var steps := 8
	for i in steps:
		var decay := 1.0 - float(i) / steps
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * decay
		tw.tween_property(c, "position", origin + off, duration / steps)
	tw.tween_property(c, "position", origin, 0.05)


## 숫자 카운트업 (돈 연출) — setter(값)를 시간에 걸쳐 호출
static func count(node: Control, from: int, to: int, setter: Callable, dur := 0.6) -> void:
	var tw := _tween_for(node, "_j_count")
	tw.tween_method(func(v: float) -> void: setter.call(int(v)), float(from), float(to), dur) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
