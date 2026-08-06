extends Control
## 낙찰자의 여정: 조사(시세 범위 좁히기·권리분석·임장) → 입찰(보증금) → 개찰 세리머니
## → 낙찰 시 잔금/포기 결정 → 명도 선택 → 한 줄씩 정산 → 3축 별점

const START_CASH := 2_000_000_000
const IMG_DIR := "res://data/images/"
const SFX_NAMES := ["click", "gavel", "win", "lose", "correct", "wrong", "coin",
	"nakchal", "drumroll", "stamp", "tear", "swoosh",
	"v_open", "v_last", "v_final",
	"v_rank1", "v_rank2", "v_rank3", "v_rank4", "v_rank5"]

# 개찰 리액션 캐릭터 (좌석 위치는 화면 비율 좌표, 발밑 기준)
const CHAR_TEX := ["res://assets/art/char_bidder1.png", "res://assets/art/char_bidder2.png",
	"res://assets/art/char_bidder3.png", "res://assets/art/char_bidder4.png"]
const SLOTS := [Vector2(0.14, 0.70), Vector2(0.33, 0.64), Vector2(0.67, 0.64), Vector2(0.86, 0.70)]

const COL_BG := Color("12141c")
const COL_CARD := Color("1b1e2a")
const COL_EDGE := Color("2b3044")
const COL_GOLD := Color("e0b95e")
const COL_MUTED := Color("9aa0b4")
const GOLD := "#e0b95e"
const MUTED := "#9aa0b4"

var pool: Array       # 조건에 맞는 물건 전부
var auctions: Array   # 이번 라운드에 볼 물건 (pool에서 라운드 수만큼 뽑음)
var rules: Dictionary
var idx := 0
var cash := START_CASH
var cash_shown := START_CASH
var wins := 0
var score_total := 0.0   # 판단 평가표 누적 점수
var cases_done := 0
var finished := false
var img_idx := 0
var busy := false

# 물건별 조사 상태
var quiz_state := 0  # 0=미응답 1=정답 2=오답
var crowd_state := 0  # 응찰자 수 예측: 0=미응답 1=정답 2=오답
var seen_tabs := {}
var market_factor := 1.0  # 훼손 감수 진행 시 시세 하락 반영
var event_override := ""  # 테스트용: "none"=이벤트 차단, 이벤트 id=강제 발동
var legal_events: Array = []
var views: PackedStringArray = []  # 액자 표시 목록: [일러스트, 실사...]

var sfx := {}
var sfx_player: AudioStreamPlayer
var sfx_pb: AudioStreamPlaybackPolyphonic
var reveal_line: Control   # 개찰 직후 금액 직선
var skip_fx := false      # 연출 건너뛰기 (아무 키·클릭)
var last_skip_ms := 0
var voice_player: AudioStreamPlayer
var drum_player: AudioStreamPlayer

var cash_label: Label
var photo: TextureRect
var photo_caption: Label
var info: RichTextLabel
var tab_row: HBoxContainer
var detail: RichTextLabel
var quiz_row: HBoxContainer
var crowd_row: HBoxContainer
var action_row: HBoxContainer
var range_label: Label
var bid_row: HBoxContainer
var bid_edit: LineEdit
var bid_preview: Label
var result: RichTextLabel
var court: TextureRect
var dim: ColorRect
var content: HBoxContainer
var call_bubble: PanelContainer
var call_label: Label
var sprite_layer: Control

# 기일입찰표 (작성→보증봉투→입찰봉투→수취증→투함 5단계)
var pending_bid := 0
var stamped := false
var form_step := 0
var form_layer: Control
var paper_panel: PanelContainer
var stamp_node: PanelContainer
var form_btn: Button
var form_cancel: Button
var small_env: PanelContainer
var big_env: PanelContainer
var receipt: PanelContainer
var form_front_box: VBoxContainer
var form_back_box: VBoxContainer
var form_btn_bar: HBoxContainer
var next_btn: Button
var speech: Label
var frame_panel: PanelContainer


func _ready() -> void:
	pool = JSON.parse_string(FileAccess.get_file_as_string("res://data/auctions.json"))
	var filtered: Array = Game.filter_auctions(pool)
	if not filtered.is_empty():
		pool = filtered
	auctions = Game.shuffled_for_play(pool)  # 조건에 맞는 풀에서 라운드 물건 수만큼 새로 뽑는다
	cash = Game.capital
	cash_shown = cash
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/cost_rules.json"))
	legal_events = JSON.parse_string(FileAccess.get_file_as_string("res://data/legal_events.json")).get("events", [])
	for n in SFX_NAMES:
		sfx[n] = _load_sound(n)
	# 폴리포닉 — 소리 하나가 앞 소리를 끊지 않는다 (수취증 찢는 소리가 도장 소리에 잘리던 문제)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = AudioStreamPolyphonic.new()
	add_child(sfx_player)
	sfx_player.play()
	sfx_pb = sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -1.0
	add_child(voice_player)
	drum_player = AudioStreamPlayer.new()
	drum_player.stream = null
	drum_player.volume_db = -11.0
	add_child(drum_player)
	_build_ui()
	_show_auction()


func _load_sound(name: String) -> AudioStream:
	for ext in ["wav", "mp3"]:
		var p := "res://assets/sfx/%s.%s" % [name, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null


func _unhandled_input(e: InputEvent) -> void:
	# 연출 중 아무거나 누르면 현재 단계를 건너뛴다 (계속 누르면 계속 건너뜀)
	if busy and (e.is_action_pressed("ui_accept") or (e is InputEventMouseButton and e.pressed)):
		skip_fx = true
		last_skip_ms = Time.get_ticks_msec()


## 모든 연출 대기는 여기를 지난다 — 속도 설정 반영 + 스킵
func _beat(sec: float) -> void:
	var left := sec * Game.fx_speed
	while left > 0.0 and not skip_fx:
		left -= get_process_delta_time()
		await get_tree().process_frame


## 같은 소리를 수백 번 듣게 되므로 피치를 조금씩 흔든다 (청각 피로 방지).
## 법봉·낙찰 스팅어처럼 '한 번뿐인 큰 소리'는 pitch를 1.0으로 고정해 호출한다.
func _play(name: String, pitch := 0.0) -> void:
	if sfx_pb == null or sfx[name] == null:
		return
	sfx_pb.play_stream(sfx[name], 0.0, -4.0, pitch if pitch > 0.0 else randf_range(0.94, 1.06))


func _voice(name: String) -> void:
	voice_player.stream = sfx[name]
	voice_player.play()


func _update_cash() -> void:
	Juice.count(cash_label, cash_shown, cash, func(v: int) -> void:
		cash_label.text = "보유 자금  " + fmt(v))
	if cash != cash_shown:
		Juice.punch(cash_label)
	cash_shown = cash


func _card(bg: Color, edge: Color, radius := 12, border := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = edge
	s.set_content_margin_all(14)
	return s


func _style_button(b: Button, primary: bool) -> void:
	var bg := COL_GOLD if primary else COL_CARD
	var normal := _card(bg, COL_GOLD if primary else COL_EDGE, 8, 1)
	normal.set_content_margin_all(9)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("f0cd7a") if primary else Color("242a3c")
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("c9a44b") if primary else Color("161927")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	var fc := Color("1a1508") if primary else Color("e6e6ee")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, fc)
	Juice.button(b)


func _make_rich(font_size := 17) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	r.add_theme_color_override("default_color", Color("e6e6ee"))
	return r


func _build_ui() -> void:
	# 1인칭 경매 법정 배경 (art_src/render_courtroom.py 렌더)
	court = TextureRect.new()
	court.texture = load("res://assets/art/courtroom.png")
	court.set_anchors_preset(Control.PRESET_FULL_RECT)
	court.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	court.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(court)
	dim = ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.07, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	sprite_layer = Control.new()
	sprite_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sprite_layer)
	_make_dust()

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	var title := Label.new()
	title.text = "GG 경매 시뮬레이터"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COL_GOLD)
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "지지옥션 실데이터 기반"
	subtitle.add_theme_color_override("font_color", COL_MUTED)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(subtitle)
	var simple_chk := CheckButton.new()
	simple_chk.text = "간단 입찰"
	simple_chk.tooltip_text = "기일입찰표 작성 과정을 생략하고 바로 제출합니다"
	simple_chk.button_pressed = Game.simple_bid
	simple_chk.toggled.connect(func(on: bool) -> void: Game.simple_bid = on)
	header.add_child(simple_chk)
	var cash_card := PanelContainer.new()
	cash_card.add_theme_stylebox_override("panel", _card(COL_CARD, COL_GOLD, 10))
	header.add_child(cash_card)
	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 18)
	cash_label.add_theme_color_override("font_color", COL_GOLD)
	cash_card.add_child(cash_label)

	content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	# 액자 (사진 프레임)
	var frame_box := VBoxContainer.new()
	frame_box.add_theme_constant_override("separation", 6)
	content.add_child(frame_box)
	frame_panel = PanelContainer.new()
	var frame := frame_panel
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("efe7d4")
	frame_style.set_border_width_all(12)
	frame_style.border_color = Color("4a3222")
	frame_style.set_content_margin_all(14)
	frame_style.shadow_size = 12
	frame_style.shadow_color = Color(0, 0, 0, 0.45)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame_box.add_child(frame)
	photo = TextureRect.new()
	photo.custom_minimum_size = Vector2(380, 285)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_next_photo())
	frame.add_child(photo)
	photo_caption = Label.new()
	photo_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	photo_caption.add_theme_color_override("font_color", COL_MUTED)
	frame_box.add_child(photo_caption)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	content.add_child(right)

	var info_card := PanelContainer.new()
	info_card.add_theme_stylebox_override("panel", _card(COL_CARD, COL_EDGE))
	info_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(info_card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_card.add_child(scroll)
	var scroll_box := VBoxContainer.new()
	scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_box.add_theme_constant_override("separation", 10)
	scroll.add_child(scroll_box)

	info = _make_rich()
	scroll_box.add_child(info)

	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	scroll_box.add_child(tab_row)
	for tab in [["comps", "실거래·시세"], ["rights", "권리분석"], ["site", "현장조사"]]:
		var b := Button.new()
		b.text = tab[1]
		_style_button(b, false)
		b.pressed.connect(_show_tab.bind(tab[0]))
		tab_row.add_child(b)

	detail = _make_rich(16)
	scroll_box.add_child(detail)

	quiz_row = HBoxContainer.new()
	quiz_row.add_theme_constant_override("separation", 8)
	quiz_row.visible = false
	right.add_child(quiz_row)  # 스크롤 밖 고정 — 버튼이 밀려 안 보이는 문제 방지
	for q in [["인수된다 (내가 떠안음)", true], ["소멸된다 (배당으로 정리)", false]]:
		var b := Button.new()
		b.text = q[0]
		_style_button(b, false)
		b.pressed.connect(_answer_quiz.bind(q[1]))
		quiz_row.add_child(b)

	# 응찰자 수 예측 — 경쟁을 읽는 눈. 맞히면 시세 분석 범위가 더 좁아진다.
	crowd_row = HBoxContainer.new()
	crowd_row.add_theme_constant_override("separation", 8)
	crowd_row.visible = false
	right.add_child(crowd_row)
	for i in CROWD_BANDS.size():
		var b := Button.new()
		b.text = CROWD_BANDS[i][2]
		_style_button(b, false)
		b.pressed.connect(_answer_crowd.bind(i))
		crowd_row.add_child(b)

	result = _make_rich()
	result.visible = false
	scroll_box.add_child(result)

	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	action_row.visible = false
	right.add_child(action_row)  # 스크롤 밖 고정

	range_label = Label.new()
	range_label.add_theme_color_override("font_color", COL_MUTED)
	right.add_child(range_label)

	bid_row = HBoxContainer.new()
	bid_row.add_theme_constant_override("separation", 8)
	right.add_child(bid_row)
	for quick in [["최저가", "min"], ["분석 하한", "lo"], ["분석 상한", "hi"]]:
		var b := Button.new()
		b.text = quick[0]
		_style_button(b, false)
		b.pressed.connect(_quick_bid.bind(quick[1]))
		bid_row.add_child(b)
	bid_edit = LineEdit.new()
	bid_edit.placeholder_text = "만원 단위"
	bid_edit.custom_minimum_size.x = 140
	bid_edit.text_changed.connect(func(t: String) -> void:
		bid_preview.text = fmt(t.replace(",", "").to_int() * 10_000))
	bid_edit.text_submitted.connect(func(_t: String) -> void: _on_bid())
	bid_row.add_child(bid_edit)
	bid_preview = Label.new()
	bid_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bid_preview.add_theme_color_override("font_color", COL_GOLD)
	bid_row.add_child(bid_preview)
	var bid_btn := Button.new()
	bid_btn.text = "입찰하기"
	bid_btn.pressed.connect(_on_bid)
	_style_button(bid_btn, true)
	bid_row.add_child(bid_btn)
	var pass_btn := Button.new()
	pass_btn.text = "패스"
	pass_btn.pressed.connect(func() -> void: _ceremony(0, true))
	_style_button(pass_btn, false)
	bid_row.add_child(pass_btn)

	next_btn = Button.new()
	next_btn.text = "다음 물건 ▶"
	next_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	next_btn.visible = false
	next_btn.pressed.connect(_on_next)
	_style_button(next_btn, true)
	right.add_child(next_btn)

	# 캐릭터 '지지' + 말풍선
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	var jiji := TextureRect.new()
	jiji.texture = load("res://assets/characters/jiji3d.png")
	jiji.custom_minimum_size = Vector2(88, 88)
	jiji.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	jiji.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	footer.add_child(jiji)
	jiji.pivot_offset = Vector2(44, 60)
	var idle := jiji.create_tween().set_loops()
	idle.tween_property(jiji, "rotation", 0.05, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle.tween_property(jiji, "rotation", -0.05, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _card(COL_CARD, COL_GOLD, 14))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(bubble)
	speech = Label.new()
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speech.add_theme_color_override("font_color", Color("efe3c2"))
	bubble.add_child(speech)

	# 집행관 호명 말풍선 (단상 위, 개찰 때만)
	var call_center := CenterContainer.new()
	call_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	call_center.offset_top = 70
	call_center.offset_bottom = 200
	call_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(call_center)
	call_bubble = PanelContainer.new()
	var cb := _card(Color(0.08, 0.09, 0.14, 0.92), COL_GOLD, 18, 2)
	cb.set_content_margin_all(20)
	cb.content_margin_left = 34
	cb.content_margin_right = 34
	call_bubble.add_theme_stylebox_override("panel", cb)
	call_bubble.visible = false
	call_center.add_child(call_bubble)
	call_label = Label.new()
	call_label.add_theme_font_size_override("font_size", 30)
	call_label.add_theme_color_override("font_color", Color("f5e6bd"))
	call_bubble.add_child(call_label)


## 금가루 부유 파티클 — 공간에 깊이감
func _make_dust() -> void:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for x in 12:
		for y in 12:
			var d := Vector2(x - 5.5, y - 5.5).length() / 5.5
			img.set_pixel(x, y, Color(1.0, 0.85, 0.5, clampf(1.0 - d, 0.0, 1.0) * 0.5))
	var p := CPUParticles2D.new()
	p.texture = ImageTexture.create_from_image(img)
	p.amount = 26
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(700, 400)
	p.position = Vector2(640, 430)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.3
	p.modulate = Color(1, 1, 1, 0.4)
	add_child(p)


## 액자 유사 3D 틸트 — 마우스를 따라 기울어짐
func _process(_dt: float) -> void:
	if frame_panel == null:
		return
	var r := frame_panel.get_global_rect()
	frame_panel.pivot_offset = frame_panel.size / 2.0
	if r.has_point(get_global_mouse_position()):
		var m := (get_global_mouse_position() - r.position) / r.size - Vector2(0.5, 0.5)
		frame_panel.rotation = lerpf(frame_panel.rotation, m.x * 0.05, 0.15)
		frame_panel.scale = frame_panel.scale.lerp(Vector2(1.025, 1.025), 0.15)
	else:
		frame_panel.rotation = lerpf(frame_panel.rotation, 0.0, 0.12)
		frame_panel.scale = frame_panel.scale.lerp(Vector2.ONE, 0.12)


func _load_tex(path: String) -> Texture2D:
	# 물건 사진(.jpg)은 임포트하지 않고 원본 그대로 팩에 넣는다 (임포트 시간·용량 절약).
	# tools_import/keep_photos.py 가 .import를 importer="keep"으로 만들어 둠.
	if path.get_extension().to_lower() in ["jpg", "jpeg"]:
		var bytes := FileAccess.get_file_as_bytes(path)
		var jpg := Image.new()
		if bytes.size() > 0 and jpg.load_jpg_from_buffer(bytes) == OK:
			return ImageTexture.create_from_image(jpg)
		return null
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null


## 물건 종류별 3D 렌더 일러스트 (제작: art_src/render_props.py)
func _art_for(kind: String) -> String:
	if kind == "아파트":
		return "res://assets/art/apt.png"
	if kind in ["다세대", "연립", "단독주택", "주택", "빌라"]:
		return "res://assets/art/villa.png"
	if kind in ["상가", "오피스텔", "근린시설", "근린상가"]:
		return "res://assets/art/shop.png"
	return "res://assets/art/land.png"


func _view_caption() -> String:
	if views.size() == 1:
		return "일러스트"
	if img_idx == views.size() - 1:
		return "일러스트 (클릭해서 처음으로)"
	return "실사 %d/%d (클릭해서 넘기기)" % [img_idx + 1, views.size() - 1]


func _next_photo() -> void:
	if views.size() < 2:
		return
	_play("click")
	img_idx = (img_idx + 1) % views.size()
	photo.texture = _load_tex(views[img_idx])
	photo_caption.text = _view_caption()


func _deposit(a: Dictionary) -> int:
	return int(int(a["min_price"]) * float(rules.get("bid_deposit_rate", 0.1)))


## 조사할수록 좁아지는 시세 분석 범위 (정답은 절대 직접 노출하지 않음)
func _analysis_range(a: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(a["case_no"])
	var center := int(int(a["market_price"]) * rng.randf_range(0.96, 1.04))
	var widths := [0.25, 0.15, 0.10, 0.06]
	var w: float = widths[clampi(seen_tabs.size(), 0, 3)]
	return [int(center * (1.0 - w)), int(center * (1.0 + w))]


func _update_range() -> void:
	var r := _analysis_range(auctions[idx])
	range_label.text = "내 시세 분석: %s ~ %s  (조사 %d/3 — 조사할수록 좁아져요)" % [fmt(r[0]), fmt(r[1]), seen_tabs.size()]


func _show_auction() -> void:
	if idx >= auctions.size():
		_show_end()
		return
	var a: Dictionary = auctions[idx]
	_update_cash()
	quiz_state = 0
	seen_tabs = {}
	market_factor = 1.0
	if reveal_line != null:      # 지난 물건의 금액 직선 치우기
		reveal_line.queue_free()
		reveal_line = null

	img_idx = 0
	views.clear()
	for f in a.get("images", []):
		views.append(IMG_DIR + f)  # 실사 먼저 — 시각적 임팩트
	views.append(_art_for(a.get("kind", "")))
	photo.texture = _load_tex(views[0])
	photo_caption.text = _view_caption()

	var age := ""
	if a.get("built_date", "") != "":
		age = " | %s년 사용승인" % a["built_date"].substr(0, 4)
	# 토지 물건은 건물 전용면적이 없다 — 토지면적만 표시
	var area_txt := "전용 %.1f㎡ | 대지권 %.1f㎡" % [float(a["area_m2"]), float(a.get("land_share_m2", 0.0))]
	if float(a["area_m2"]) <= 0.0:
		area_txt = "토지 %.1f㎡" % float(a.get("land_share_m2", 0.0))
	info.text = ("[b]%s — %s[/b]  [color=%s](%d / %d)[/color]\n%s | %s\n%s%s | 점유: %s\n\n" +
		"감정가: [b][color=%s]%s[/color][/b]\n최저매각가격: [b][color=%s]%s[/color][/b]  (유찰 %d회)\n" +
		"입찰보증금(최저가 10%%): [b]%s[/b] — 낙찰 후 잔금 포기 시 몰수!\n매각기일: %s") % [
		a["case_no"], a["kind"], MUTED, idx + 1, auctions.size(),
		a["court"], a["address"], area_txt, age, a["occupancy"],
		GOLD, fmt(int(a["appraisal_price"])), GOLD, fmt(int(a["min_price"])),
		int(a["fail_count"]), fmt(_deposit(a)), a["sale_date"]]

	# 챕터 도입 — 라운드 n번째 물건에 걸린 게 있으면 먼저 보여준다 (data/story.json)
	var ch := Game.chapter_at(idx + 1)
	var head := ""
	if not ch.is_empty():
		head = "[b][color=%s]%s[/color][/b]\n[color=%s]%s[/color]\n\n" % [GOLD, ch["title"], MUTED, ch["body"]]
	detail.text = head + "[color=%s]입찰 전에 위 탭으로 조사하세요. 조사한 만큼 시세 분석 범위가 좁아지고, 권리 함정이 보입니다.[/color]" % MUTED
	_say(Game.line("prologue", Game.purpose if Game.purpose != "" else "전체") if idx == 0
		else Game.line("case_intro", Game.difficulty_of(a)))
	quiz_row.visible = false
	crowd_row.visible = true      # 입찰 전 경쟁 예측 — 응찰자 수 맞히기
	crowd_state = 0
	action_row.visible = false
	_update_range()
	if idx == 0:
		_say("알아두세요 — 입찰보증금은 '내 입찰가'가 아니라 '최저매각가격'의 10%예요 (민사집행규칙 63조). 얼마를 쓰든 보증금은 같답니다!")
	else:
		_say("입찰 전 조사가 반이에요. 조사를 건너뛰면 분석 범위가 넓어서 감으로 쓰게 돼요!")

	bid_edit.clear()
	bid_preview.text = ""
	bid_row.visible = true
	result.visible = false
	next_btn.visible = false
	busy = false


func _show_tab(which: String) -> void:
	if busy:
		return
	_play("click")
	seen_tabs[which] = true
	_update_range()
	var a: Dictionary = auctions[idx]
	quiz_row.visible = false
	crowd_row.visible = false
	match which:
		"comps":
			var t := "[b]■ 실거래·시세[/b]\n입찰가의 기준은 감정가가 아니라 '지금 시세'예요. 감정 시점은 과거입니다.\n\n"
			for c in a.get("comps", []):
				t += "  · %s — [color=%s]%s[/color] (%s)\n" % [c["label"], GOLD, fmt(int(c["price"])), c["date"]]
			# 국토교통부 실거래 자료로 잡은 시세 — 어디서 나온 값인지 그대로 보여준다
			if str(a.get("market_source", "")) != "":
				t += "  · 국토부 실거래 기준: [color=%s]%s[/color]\n" % [MUTED, a["market_source"]]
				t += "  · 전용/토지 %.1f㎡ 적용\n" % (float(a["area_m2"]) if float(a["area_m2"]) > 0 else float(a.get("land_share_m2", 0.0)))
			if a.get("price_index_note", "") != "":
				t += "  · 가격지수: %s\n" % a["price_index_note"]
			t += "\n[color=%s]→ 위 사례와 지수로 내 분석 범위가 좁아졌어요 (아래 확인).[/color]" % MUTED
			detail.text = t
		"rights":
			var t := "[b]■ 권리분석 (매각물건명세서)[/b]\n말소기준권리: [b]%s %s 설정[/b]\n" % [a.get("base_rights_date", "?"), a.get("base_rights_kind", "")]
			var tenants: Array = a.get("tenants", [])
			if tenants.is_empty():
				t += "\n등재된 임차인 없음 — 낙찰 시 모든 권리는 말소됩니다. 깨끗한 물건이에요."
				detail.text = t
			else:
				for tn in tenants:
					t += "\n[b]%s[/b]\n  보증금 [color=%s]%s[/color] | 전입 %s | 확정일자 %s | 배당요구 %s\n" % [
						tn["label"], GOLD, fmt(int(tn["deposit"])), tn["move_in"], tn["fixed_date"],
						"O" if tn.get("dividend_demand", false) else "X"]
					if tn.get("note", "") != "":
						t += "  ※ %s\n" % tn["note"]
				if quiz_state == 0:
					t += "\n[b][color=%s]Q. 이 임차인의 보증금, 낙찰자에게 인수될까요?[/color][/b]\n(힌트: 전입일과 말소기준권리 설정일을 비교하세요)" % GOLD
					quiz_row.visible = true
				else:
					t += "\n" + _quiz_explain(a)
				detail.text = t
		"site":
			var t := "[b]■ 현장조사 (임장)[/b]\n"
			t += "점유 현황: %s\n" % a["occupancy"]
			if int(a.get("unpaid_mgmt_fee", 0)) > 0:
				t += "미납 관리비: [color=%s]%s[/color] (공용부분은 매수인 인수 — 판례상 최근 3년)\n" % [GOLD, fmt(int(a["unpaid_mgmt_fee"]))]
			if a.get("site_notes", "") != "":
				t += "%s\n" % a["site_notes"]
			if a.get("notes", "") != "":
				t += "[color=orange]※ %s[/color]" % a["notes"]
			detail.text = t


func _quiz_explain(a: Dictionary) -> String:
	var tn: Dictionary = a["tenants"][0]
	var opposing := bool(a.get("tenant_opposing_power", false))
	var verdict := "[color=salmon][b]인수됩니다[/b][/color]" if opposing else "[color=lightgreen][b]소멸합니다[/b][/color]"
	var reason := ""
	if opposing:
		reason = "전입일(%s)이 말소기준권리(%s)보다 [b]빠르므로 대항력이 있어요[/b]. 배당으로 전액 변제되지 않으면 잔액을 낙찰자가 떠안습니다." % [tn["move_in"], a["base_rights_date"]]
	else:
		reason = "전입일(%s)이 말소기준권리(%s)보다 [b]늦어 대항력이 없어요[/b]. 보증금은 배당 절차에서 정리되고 낙찰자가 인수하지 않습니다." % [tn["move_in"], a["base_rights_date"]]
	var grade := "정답!" if quiz_state == 1 else "오답 —"
	return "[b]%s[/b] 보증금은 %s\n%s" % [grade, verdict, reason]


## 응찰자 수 구간. 실제 데이터에서 경쟁이 붙을수록 최저가 대비 낙찰 배수가 뚜렷이 오른다
## (1명 1.06배 → 2~3명 1.17 → 4~7명 1.27 → 8명 이상 1.35). 그래서 이건 감이 아니라 실력이다.
const CROWD_BANDS := [[1, 1, "1명 (나 혼자)"], [2, 3, "2~3명"], [4, 7, "4~7명"], [8, 9999, "8명 이상"]]


func _answer_crowd(band: int) -> void:
	if crowd_state != 0:
		return
	var n := int(auctions[idx]["bidder_count"])
	var truth := 0
	for i in CROWD_BANDS.size():
		if n >= int(CROWD_BANDS[i][0]) and n <= int(CROWD_BANDS[i][1]):
			truth = i
	crowd_state = 1 if band == truth else 2
	crowd_row.visible = false
	_play("correct" if crowd_state == 1 else "wrong")
	Game.bump("crowd_correct" if crowd_state == 1 else "crowd_wrong")
	_say("경쟁을 읽었네요. 응찰자가 많을수록 최저가 대비 높게 붙습니다." if crowd_state == 1
		else "빗나갔어요. 사진·입지·유찰 횟수를 보면 경쟁이 보입니다.")
	seen_tabs["crowd"] = true      # 맞히든 틀리든 조사 한 단계로 쳐서 분석 범위를 좁힌다
	var r := _analysis_range(auctions[idx])
	range_label.text = "내 시세 분석: %s ~ %s  (조사 %d/3 — 조사할수록 좁아져요)" % [fmt(r[0]), fmt(r[1]), seen_tabs.size()]


func _answer_quiz(said_assumed: bool) -> void:
	var a: Dictionary = auctions[idx]
	var truth := bool(a.get("tenant_opposing_power", false))
	quiz_state = 1 if said_assumed == truth else 2
	_play("correct" if quiz_state == 1 else "wrong")
	_say("정확해요! 권리분석이 몸에 배셨네요." if quiz_state == 1 else "아쉬워요. 전입일이 말소기준권리보다 빠른지만 보면 돼요!")
	_show_tab("rights")


func _quick_bid(kind: String) -> void:
	_play("click")
	var a: Dictionary = auctions[idx]
	var r := _analysis_range(a)
	var v := 0
	match kind:
		"min": v = int(a["min_price"])
		"lo": v = maxi(r[0], int(a["min_price"]))
		"hi": v = maxi(r[1], int(a["min_price"]))
	var man := ceili(v / 10_000.0)  # 내림하면 최저가 미만(무효)이 될 수 있어 올림
	bid_edit.text = str(man)
	bid_preview.text = fmt(man * 10_000)


func _on_bid() -> void:
	if busy:
		return
	var bid := bid_edit.text.replace(",", "").to_int() * 10_000
	var a: Dictionary = auctions[idx]
	if bid < int(a["min_price"]):
		bid_preview.text = "최저매각가격 미만 — 입찰 무효!"
		_play("wrong")
		return
	if bid > cash:
		bid_preview.text = "보유 자금 초과!"
		_play("wrong")
		return
	if bid >= int(a["appraisal_price"]) * 5:
		bid_preview.text = "입찰가를 다시 확인하세요 — '0' 하나 더 쓰면 보증금 몰수입니다!"
		_play("wrong")
		return
	pending_bid = bid
	if Game.simple_bid:
		_quick_submit()
	else:
		_show_bid_form()


## 개찰 세리머니: UI가 걷히고 법정이 줌인 — 집행관이 단상에서 금액을 호명
func _ceremony(my_bid: int, passed: bool) -> void:
	skip_fx = false
	busy = true
	bid_row.visible = false
	quiz_row.visible = false
	crowd_row.visible = false
	action_row.visible = false
	var a: Dictionary = auctions[idx]
	var actual := int(a["winning_bid"])
	var n := maxi(int(a["bidder_count"]), 1)

	var others: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()  # 경쟁자 구성은 매 회차 다르게 — 실제 2순위 금액만 아래에서 고정
	for i in n - 1:
		others.append(int(rng.randf_range(float(int(a["min_price"])), float(actual)) / 10_000.0) * 10_000)
	if others.size() > 0 and int(a.get("second_bid", 0)) > 0:
		others[0] = int(a["second_bid"])
	others.append(actual)
	others.sort()
	while others.size() > 4:
		others.pop_front()  # 호명은 상위 4명만

	var nicks: Array = ["강남 큰손", "이사비 전문 꾼", "첫 임장 새내기", "은퇴자금 방어전", "옆동네 중개사", "조용한 법인"]
	var entries: Array = []
	for amt in others:
		entries.append({"amt": amt, "who": nicks[rng.randi() % nicks.size()], "mine": false})
	if not passed:
		entries.append({"amt": my_bid, "who": "나 (지지)", "mine": true})
	entries.sort_custom(func(x, y) -> bool: return x["amt"] < y["amt"])

	# 캐릭터 스프라이트 배정 (호명 시 좌석에서 일어남) — 매 회차 얼굴·자리 무작위
	var pool := CHAR_TEX.duplicate()
	var seats := SLOTS.duplicate()
	pool.shuffle()
	seats.shuffle()
	var slot_i := 0
	for e in entries:
		if e["mine"]:
			e["tex"] = "res://assets/characters/jiji3d.png"
			e["pos"] = Vector2(0.5, 1.06)
			e["px"] = 250.0
		else:
			e["tex"] = pool[slot_i % pool.size()]
			e["pos"] = seats[slot_i % seats.size()]
			e["px"] = randf_range(148.0, 176.0)  # 앞뒤 줄 느낌으로 크기도 조금씩 다르게
			slot_i += 1
		e["spr"] = null

	# 법정 뷰로 전환: UI 걷고, 어둠 걷고, 방청객은 리액션 스프라이트로 교대
	content.visible = false
	range_label.visible = false
	result.visible = false
	court.texture = load("res://assets/art/courtroom_empty.png")
	court.pivot_offset = court.size * Vector2(0.5, 0.45)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "color:a", 0.08, 0.6)
	tw.tween_property(court, "scale", Vector2(1.14, 1.14), 4.5).set_trans(Tween.TRANS_SINE)
	_call("사건번호 %s — 개찰을 시작하겠습니다." % a["case_no"])
	var case_voice := "res://assets/sfx/case_%d.mp3" % idx
	var open_wait := 1.5
	if ResourceLoader.exists(case_voice):
		voice_player.stream = load(case_voice)
		voice_player.play()
		open_wait = minf(voice_player.stream.get_length() + 0.2, 3.2)
	else:
		_voice("v_open")
	_say("두구두구...")
	await _beat(open_wait)

	drum_player.stream = sfx["drumroll"]
	drum_player.play()
	for i in entries.size():
		var e: Dictionary = entries[i]
		var rank := entries.size() - i
		skip_fx = false   # 한 번 누르면 이 호명만, 계속 누르면 계속 건너뛴다
		if i == entries.size() - 1:
			_call("마지막 봉투입니다.")
			_voice("v_last")
			await _beat(0.8)
		_play("click")
		_voice("v_rank%d" % clampi(rank, 1, 5))
		await _call_amount(rank, str(e["who"]), int(e["amt"]))
		e["spr"] = _pop_char(e)
		await _beat(0.7)

	drum_player.stop()
	var top: Dictionary = entries[entries.size() - 1]
	top["win"] = true
	_play("nakchal")  # 땅!땅!땅! + 스팅어
	get_tree().create_timer(0.55).timeout.connect(_voice.bind("v_final"))  # "낙찰입니다! 축하합니다!"
	Juice.shake(self, 10.0)
	_call("낙찰입니다! 축하합니다, %s 님!" % top["who"])

	# 리액션: 낙찰자는 점프+별, 나머지는 시무룩하게 가라앉음
	for e in entries:
		var spr: TextureRect = e["spr"]
		if spr == null:
			continue
		if e.get("win", false):
			Juice.punch(spr, 1.3)
			Juice.stars_burst(self, spr.position + Vector2(float(e["px"]) / 2.0, 30.0), 14)
			var jump := spr.create_tween()
			jump.tween_property(spr, "position:y", spr.position.y - 45.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			jump.tween_property(spr, "position:y", spr.position.y, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		else:
			var sad := spr.create_tween().set_parallel(true)
			sad.tween_property(spr, "modulate", Color(0.5, 0.5, 0.58, 0.9), 0.45)
			sad.tween_property(spr, "position:y", spr.position.y + 28.0, 0.55)
	await _beat(1.8)  # 스팅어(3.2초) 여운

	# UI 복귀 — 스프라이트 퇴장, 방청객 배경 복귀
	for e in entries:
		if e["spr"] != null:
			var f: TextureRect = e["spr"]
			var out := f.create_tween()
			out.tween_property(f, "modulate:a", 0.0, 0.3)
			out.tween_callback(f.queue_free)
	court.texture = load("res://assets/art/courtroom.png")
	var back := create_tween().set_parallel(true)
	back.tween_property(dim, "color:a", 0.6, 0.45)
	back.tween_property(court, "scale", Vector2.ONE, 0.45)
	call_bubble.visible = false
	content.visible = true
	range_label.visible = true
	_show_reveal_line(a, my_bid, passed)   # 내 입찰가가 어디쯤이었는지 한 줄로

	if passed:
		_settle_passed()
	elif my_bid > actual:
		_confirmation(my_bid)
	else:
		_settle_lost(my_bid)


## 매각결정기일 (낙찰 7일 후) — 허가 여부와 법률 이벤트
func _confirmation(bid: int) -> void:
	busy = true
	result.text = "\n[b]매각결정기일[/b] — 낙찰 7일 후, 법원이 매각허가 여부를 결정합니다.\n"
	Juice.pop_in(result)
	await _beat(0.9)
	var ev := _roll_event("confirmation")
	if ev.is_empty():
		result.text += "매각허가결정 — 즉시항고 없이 확정되었습니다. 잔금(약 30일 내)을 준비하세요.\n"
		await _beat(0.8)
		_decision(bid)
		return
	_show_event(ev, bid, func() -> void: _decision(bid))


## ── 법률 랜덤 이벤트 엔진 (data/legal_events.json) ──
func _event_cond_ok(e: Dictionary, a: Dictionary) -> bool:
	var c: Dictionary = e.get("cond", {})
	if c.has("kinds") and not (str(a.get("kind", "")) in (c["kinds"] as Array)):
		return false
	if c.has("occupancy_not") and str(a.get("occupancy", "")) in (c["occupancy_not"] as Array):
		return false
	if c.has("share_sale") and bool(a.get("share_sale", false)) != bool(c["share_sale"]):
		return false
	if c.has("has_tenants"):
		var has: bool = not (a.get("tenants", []) as Array).is_empty()
		if has != bool(c["has_tenants"]):
			return false
	return true


func _roll_event(stage: String) -> Dictionary:
	if event_override == "none":
		return {}
	var a: Dictionary = auctions[idx]
	var rng := RandomNumberGenerator.new()
	rng.randomize()  # 돌발 사건은 매번 다르게 (같은 물건이라도 결과가 갈린다)
	for e in legal_events:
		if str(e.get("stage", "")) != stage:
			continue
		if not _event_cond_ok(e, a):
			continue
		if event_override == str(e.get("id", "")):
			return e
		if event_override == "" and rng.randf() < float(e.get("prob", 0.0)):
			return e
	return {}


func _show_event(e: Dictionary, bid: int, next_cb: Callable) -> void:
	Game.bump("legal_events")
	busy = true
	bid_row.visible = false
	quiz_row.visible = false
	crowd_row.visible = false
	result.visible = true
	await _impact("돌      발", "e07b2c", str(e.get("title", "")))
	result.text += "\n[color=orange][b][돌발] %s[/b][/color]\n%s\n" % [e.get("title", ""), e.get("body", "")]
	Juice.pop_in(result)
	_play("wrong")
	if e.has("jiji"):
		_say(str(e["jiji"]))
	var choices: Array = e.get("choices", [])
	if choices.is_empty():
		await _beat(1.7)
		_apply_effects(e.get("effects", {}), bid, next_cb)
		return
	var defs: Array = []
	for ch in choices:
		var eff: Dictionary = ch.get("effects", {})
		defs.append({"label": ch["label"], "primary": ch.get("primary", false),
			"cb": func() -> void: _apply_effects(eff, bid, next_cb)})
	_actions(defs)


func _apply_effects(fx: Dictionary, bid: int, next_cb: Callable) -> void:
	if fx.has("cash"):
		cash += int(fx["cash"])
		_update_cash()
		result.text += "[color=%s]비용 반영: %s[/color]\n" % [MUTED, fmt(int(fx["cash"]))]
	if fx.has("market_factor"):
		market_factor *= float(fx["market_factor"])
	match str(fx.get("outcome", "continue")):
		"skip_case":
			_finish_case("\n이번 입찰은 성립하지 않았습니다 — 보증금은 반환됩니다.", "disallowed", bid, 0, 0)
		"abort_refund":
			_withdrawn(bid, str(fx.get("reason", "매수인 지위 소멸 — 보증금 반환.")))
		"abort_forfeit":
			var dep := _deposit(auctions[idx])
			cash -= dep
			_update_cash()
			_finish_case("\n[color=salmon]보증금 %s 몰수! %s[/color]" % [fmt(dep), str(fx.get("reason", ""))],
				"forfeit", bid, 0, 0)
		_:
			next_cb.call()


## 취하 동의·허가취소 등으로 매수인 지위가 소멸 (보증금 반환)
func _withdrawn(bid: int, reason: String) -> void:
	var a: Dictionary = auctions[idx]
	var market := int(int(a["market_price"]) * market_factor)
	var would_net := market - bid - CostCalc.total(CostCalc.breakdown(a, bid, rules)) \
		- mini(int(CostCalc.eviction_options(a, rules)[0]["cost"]), int(CostCalc.eviction_options(a, rules)[1]["cost"]))
	var txt := "\n[b]%s[/b]\n" % reason
	if would_net < 0:
		txt += "[color=lightgreen]결과적으로 잘된 일 — 진행했다면 약 %s 손해였을 물건입니다.[/color]\n" % fmt(would_net)
		_play("correct")
	else:
		txt += "[color=salmon]아쉬움 — 진행했다면 약 +%s 수익이었을 물건입니다.[/color]\n" % fmt(would_net)
		_play("lose")
	_finish_case(txt, "withdrawn", bid, 0, would_net)


func _call(msg: String) -> void:
	call_bubble.visible = true
	call_label.text = msg
	Juice.punch(call_bubble)


## ── 기일입찰표 (실제 법원 양식 재현) ──────────────────
func _paper_label(txt: String, fsize := 14, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", Color("1d1d24"))
	return l


func _hline() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color("2a2a33")
	c.custom_minimum_size.y = 2
	return c


func _digit_row(parent: Control, title: String, amount: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var t := _paper_label(title, 13)
	t.custom_minimum_size.x = 70
	row.add_child(t)
	var units := ["천억", "백억", "십억", "억", "천만", "백만", "십만", "만", "천", "백", "십", "일"]
	var grid := GridContainer.new()
	grid.columns = units.size()
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 1)
	row.add_child(grid)
	for u in units:
		var h := _paper_label(u, 10, HORIZONTAL_ALIGNMENT_CENTER)
		h.add_theme_color_override("font_color", Color("777777"))
		grid.add_child(h)
	var s := str(amount)
	while s.length() < units.size():
		s = " " + s
	for i in units.size():
		var d := Label.new()
		d.text = "" if s[i] == " " else s[i]
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.custom_minimum_size = Vector2(30, 26)
		d.add_theme_color_override("font_color", Color("1d1d24"))
		d.add_theme_font_size_override("font_size", 15)
		var db := StyleBoxFlat.new()
		db.bg_color = Color(1, 1, 1, 0.75)
		db.set_border_width_all(1)
		db.border_color = Color("999999")
		d.add_theme_stylebox_override("normal", db)
		grid.add_child(d)
	row.add_child(_paper_label("원", 13))


func _make_stamp() -> PanelContainer:
	var s := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0)
	st.set_border_width_all(3)
	st.border_color = Color("c0392b")
	st.set_corner_radius_all(21)
	st.set_content_margin_all(4)
	s.add_theme_stylebox_override("panel", st)
	s.custom_minimum_size = Vector2(42, 42)
	var l := Label.new()
	l.text = "지지"
	l.add_theme_color_override("font_color", Color("c0392b"))
	l.add_theme_font_size_override("font_size", 13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	s.add_child(l)
	s.rotation = -0.1
	return s


func _show_bid_form() -> void:
	busy = true
	stamped = false
	form_step = 0
	small_env = null
	big_env = null
	if form_layer:
		form_layer.queue_free()
	form_layer = Control.new()
	form_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(form_layer)
	bid_row.visible = false
	range_label.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	form_layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	form_layer.add_child(center)
	var vwrap := VBoxContainer.new()
	vwrap.add_theme_constant_override("separation", 14)
	center.add_child(vwrap)

	paper_panel = PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("f7f3e8")
	ps.set_border_width_all(2)
	ps.border_color = Color("2a2a33")
	ps.set_content_margin_all(24)
	ps.shadow_size = 18
	ps.shadow_color = Color(0, 0, 0, 0.5)
	paper_panel.add_theme_stylebox_override("panel", ps)
	vwrap.add_child(paper_panel)

	var a: Dictionary = auctions[idx]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	paper_panel.add_child(box)
	form_front_box = box

	# 용지 뒷면 (위임장 서식) — 3D 플립 때 보임
	form_back_box = VBoxContainer.new()
	form_back_box.alignment = BoxContainer.ALIGNMENT_CENTER
	form_back_box.visible = false
	paper_panel.add_child(form_back_box)
	var back_title := _paper_label("위  임  장", 30, HORIZONTAL_ALIGNMENT_CENTER)
	back_title.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4, 0.5))
	form_back_box.add_child(back_title)
	var back_sub := _paper_label("(용지 뒷면 — 대리입찰 시 사용)", 12, HORIZONTAL_ALIGNMENT_CENTER)
	back_sub.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4, 0.4))
	form_back_box.add_child(back_sub)

	box.add_child(_paper_label("기  일  입  찰  표", 26, HORIZONTAL_ALIGNMENT_CENTER))
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(_paper_label("%s 집행관 귀하" % a["court"], 13))
	var hsp := Control.new()
	hsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hsp)
	head.add_child(_paper_label("입찰기일 : %s" % a["sale_date"], 13))
	box.add_child(_hline())

	var case_row := HBoxContainer.new()
	case_row.add_theme_constant_override("separation", 30)
	box.add_child(case_row)
	case_row.add_child(_paper_label("사건번호 :  %s 호" % a["case_no"], 15))
	case_row.add_child(_paper_label("물건번호 :  %d" % int(a.get("mul_no", 1)), 15))

	var bidder_row := HBoxContainer.new()
	bidder_row.add_theme_constant_override("separation", 8)
	box.add_child(bidder_row)
	bidder_row.add_child(_paper_label("입찰자 (본인)    성명 :  지 지", 15))
	var spot := PanelContainer.new()
	var sps := StyleBoxFlat.new()
	sps.bg_color = Color(0.85, 0.2, 0.2, 0.06)
	sps.set_border_width_all(2)
	sps.border_color = Color("d08080")
	sps.set_corner_radius_all(6)
	sps.set_content_margin_all(3)
	spot.add_theme_stylebox_override("panel", sps)
	spot.custom_minimum_size = Vector2(64, 64)
	var spot_hint := Label.new()
	spot_hint.text = "(인)"
	spot_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spot_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spot_hint.add_theme_color_override("font_color", Color("d08080"))
	spot.add_child(spot_hint)
	stamp_node = _make_stamp()
	stamp_node.custom_minimum_size = Vector2(58, 58)
	stamp_node.visible = false
	spot.add_child(stamp_node)
	bidder_row.add_child(spot)

	box.add_child(_paper_label("주민등록번호 :  9●●●●●-●●●●●●●          전화번호 :  010-****-****", 12))
	box.add_child(_paper_label("주　소 :  %s" % a["address"], 12))
	_digit_row(box, "입찰가격", pending_bid)
	_digit_row(box, "보증금액", _deposit(a))
	box.add_child(_paper_label("보증의 제공방법 :  [V] 현금·자기앞수표    [  ] 보증서", 13))
	box.add_child(_paper_label("※ 입찰가격은 수정할 수 없으므로, 수정을 요하는 때에는 새 용지를 사용하십시오.", 11))
	box.add_child(_hline())

	Juice.pop_in(paper_panel)

	# 진행 버튼 — 항상 현재 대상물(종이/봉투) 바로 아래를 따라다님
	form_btn_bar = HBoxContainer.new()
	form_btn_bar.add_theme_constant_override("separation", 12)
	form_layer.add_child(form_btn_bar)
	form_cancel = Button.new()
	form_cancel.text = "다시 쓰기"
	_style_button(form_cancel, false)
	form_cancel.pressed.connect(func() -> void:
		form_layer.queue_free()
		form_layer = null
		bid_row.visible = true
		range_label.visible = true
		busy = false)
	form_btn_bar.add_child(form_cancel)
	form_btn = Button.new()
	form_btn.text = "도장 찍기"
	_style_button(form_btn, true)
	form_btn.pressed.connect(_on_form_btn)
	form_btn_bar.add_child(form_btn)
	await get_tree().process_frame
	_place_form_btns_under(paper_panel)
	_say("입찰가격은 수정하면 무효예요! 꼼꼼히 확인하고 도장 찍으세요.")


func _place_form_btns_under(node: Control) -> void:
	if form_btn_bar == null or node == null:
		return
	var r := node.get_global_rect()
	form_btn_bar.position = Vector2(
		clampf(r.position.x + r.size.x / 2.0 - form_btn_bar.size.x / 2.0, 12.0, size.x - form_btn_bar.size.x - 12.0),
		minf(r.end.y + 14.0, size.y - form_btn_bar.size.y - 12.0))


func _envelope_panel(bg: String, border: String, title: String, sub: String, tcol: String) -> PanelContainer:
	var env := PanelContainer.new()
	var es := StyleBoxFlat.new()
	es.bg_color = Color(bg)
	es.set_border_width_all(2)
	es.border_color = Color(border)
	es.set_content_margin_all(24)
	es.shadow_size = 10
	es.shadow_color = Color(0, 0, 0, 0.4)
	env.add_theme_stylebox_override("panel", es)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	env.add_child(v)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color(tcol))
	t.add_theme_font_size_override("font_size", 19)
	v.add_child(t)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_color_override("font_color", Color(tcol))
		s.add_theme_font_size_override("font_size", 12)
		v.add_child(s)
	var seal := _make_stamp()
	seal.custom_minimum_size = Vector2(34, 34)
	var seal_wrap := CenterContainer.new()
	seal_wrap.add_child(seal)
	v.add_child(seal_wrap)
	return env


func _center_in_form(node: Control, y_off := 0.0) -> void:
	form_layer.add_child(node)
	await get_tree().process_frame
	node.position = (form_layer.size - node.size) / 2.0 + Vector2(0, y_off)
	Juice.pop_in(node)


## 실제 절차 (민사집행규칙·생활법령): 작성·날인 → 보증봉투 → 입찰봉투 → 수취증 → 투함
func _on_form_btn() -> void:
	match form_step:
		0:
			_stamp()
		1:
			_pack_deposit_env()
		2:
			_pack_bid_env()
		3:
			_take_receipt_and_drop()


func _stamp() -> void:
	if form_step != 0:
		return
	form_step = 1
	stamped = true
	# 도장이 위에서 크게 내리찍힘
	stamp_node.visible = true
	stamp_node.pivot_offset = stamp_node.custom_minimum_size / 2.0
	stamp_node.scale = Vector2(3.4, 3.4)
	stamp_node.modulate.a = 0.3
	stamp_node.rotation = 0.4
	var tw := stamp_node.create_tween().set_parallel(true)
	tw.tween_property(stamp_node, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.tween_property(stamp_node, "modulate:a", 1.0, 0.18)
	tw.tween_property(stamp_node, "rotation", -0.1, 0.22)
	tw.chain().tween_callback(func() -> void:
		_play("stamp")
		Juice.shake(paper_panel, 9.0, 0.25)
		Juice.punch(stamp_node, 1.15))
	form_btn.text = "보증금 봉투에 담기"
	form_cancel.visible = false  # 날인 후엔 돌이킬 수 없음
	_say("쾅! 이제 보증금 수표를 흰 소봉투에 담아요.")


func _pack_deposit_env() -> void:
	if form_step != 1:
		return
	form_step = 2
	_play("click")
	var a: Dictionary = auctions[idx]
	small_env = _envelope_panel("fdfcf7", "9a9a9a", "매수신청보증봉투",
		"사건번호 %s 호   물건번호 %d\n소재지 : %s\n수표 %s 재중 · 봉함 후 날인" % [
			a["case_no"], int(a.get("mul_no", 1)), a["address"], fmt(_deposit(a))], "3a3a44")
	_center_in_form(small_env, 40.0)
	paper_panel.modulate.a = 0.55
	form_btn.text = "입찰봉투에 넣기"
	_say("흰 소봉투에 보증금 수표를 넣고 봉했어요. 이제 입찰표와 함께 큰 봉투로!")


func _pack_bid_env() -> void:
	if form_step != 2:
		return
	form_step = 3
	var a: Dictionary = auctions[idx]
	# 1) 3D 플립 — 종이가 뒤로 돌아 뒷면(위임장 서식)이 보임
	paper_panel.pivot_offset = paper_panel.size / 2.0
	_play("swoosh")
	var flip1 := paper_panel.create_tween()
	flip1.tween_property(paper_panel, "scale:x", 0.03, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip1.parallel().tween_property(paper_panel, "modulate", Color(0.8, 0.8, 0.85), 0.13)
	await flip1.finished
	form_front_box.visible = false
	form_back_box.visible = true
	var flip2 := paper_panel.create_tween()
	flip2.tween_property(paper_panel, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flip2.parallel().tween_property(paper_panel, "modulate", Color(0.94, 0.94, 0.96), 0.15)
	await flip2.finished
	await _beat(0.18)

	# 2) 스르륵 — 반 접힌 채 소봉투와 함께 봉투 속으로 말려 들어감
	_play("swoosh")
	var tw := create_tween().set_parallel(true)
	tw.tween_property(paper_panel, "rotation", TAU * 1.25, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(paper_panel, "scale", Vector2(0.04, 0.04), 0.45).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tw.tween_property(paper_panel, "modulate:a", 0.0, 0.42)
	if small_env:
		small_env.pivot_offset = small_env.size / 2.0
		tw.tween_property(small_env, "rotation", -TAU, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_property(small_env, "scale", Vector2(0.04, 0.04), 0.45).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		tw.tween_property(small_env, "modulate:a", 0.0, 0.42)
	await tw.finished
	paper_panel.visible = false
	if small_env:
		small_env.visible = false
	big_env = _envelope_panel("e6d3a3", "8a6f42", "기 일 입 찰 봉 투",
		("%s 집행관 귀하 · 매각기일 %s\n사건번호 %s 호   물건번호 %d\n소재지 : %s\n" +
		"─ ─ 절취선 (입찰자용 수취증 · 집행관인) ─ ─\n입찰표 + 보증봉투 재중 · 제출자: 지지 (인)\n" +
		"접는선을 접어 스테이플러(찍개)로 봉함") % [
			a["court"], a["sale_date"], a["case_no"], int(a.get("mul_no", 1)), a["address"]], "5a4326")
	_center_in_form(big_env)
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if big_env:
			Juice.punch(big_env, 1.12))
	await get_tree().process_frame
	await get_tree().process_frame
	_place_form_btns_under(big_env)
	form_btn.text = "수취증 받고 투함"
	_say("사건번호가 안 보이게 접어서 찍개로 콱! 참, 봉투 뒷면엔 '절대로 풀칠 금지'라고 쓰여 있어요 ㅎㅎ")


func _take_receipt_and_drop() -> void:
	if form_step != 3 or big_env == null:
		return
	form_step = 4
	form_btn_bar.visible = false
	# 수취증이 봉투 상단에 붙어 있다가 — 들썩들썩, 북— 찢어짐
	receipt = _envelope_panel("efe7cf", "8a6f42", "입찰자용 수취증",
		"사건번호 %s 호   물건번호 %d\n보증금 반환 시 제시 · 집행관 날인" % [
			auctions[idx]["case_no"], int(auctions[idx].get("mul_no", 1))], "5a4326")
	form_layer.add_child(receipt)
	await get_tree().process_frame
	receipt.pivot_offset = Vector2(0, receipt.size.y)
	receipt.position = big_env.position + Vector2(big_env.size.x * 0.12, -receipt.size.y * 0.5)
	var wob := receipt.create_tween()
	wob.tween_property(receipt, "rotation", -0.06, 0.06)
	wob.tween_property(receipt, "rotation", 0.05, 0.06)
	wob.tween_property(receipt, "rotation", -0.04, 0.05)
	await wob.finished
	_play("tear")
	Juice.shake(big_env, 6.0, 0.18)
	var rip := receipt.create_tween().set_parallel(true)
	rip.tween_property(receipt, "rotation", -0.38, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rip.tween_property(receipt, "position", receipt.position + Vector2(-45, -55), 0.11)
	await rip.finished
	# 구석에 보관
	var keep := receipt.create_tween().set_parallel(true)
	keep.tween_property(receipt, "position", Vector2(30, form_layer.size.y - 150), 0.35).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	keep.tween_property(receipt, "rotation", -0.1, 0.35)
	keep.tween_property(receipt, "scale", Vector2(0.72, 0.72), 0.35)
	await _beat(0.35)
	# 입찰봉투 투함 (휘릭 기울며 낙하)
	_play("swoosh")
	big_env.pivot_offset = big_env.size / 2.0
	var drop := big_env.create_tween().set_parallel(true)
	drop.tween_property(big_env, "rotation", 0.5, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(big_env, "position:y", big_env.position.y + 360.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(big_env, "modulate:a", 0.0, 0.4)
	await drop.finished
	_play("stamp")
	form_layer.queue_free()
	form_layer = null
	_form_submitted()


## 명도 완료 — 점유자가 보따리를 메고 화면을 가로질러 떠남
func _mover_leaves() -> void:
	var mv := TextureRect.new()
	mv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mv.texture = load("res://assets/art/char_mover.png")
	mv.size = Vector2(150, 150)
	mv.pivot_offset = Vector2(75, 150)
	mv.position = Vector2(size.x * 0.34, size.y - 190)
	mv.modulate.a = 0.0
	sprite_layer.add_child(mv)
	var walk := mv.create_tween().set_parallel(true)
	walk.tween_property(mv, "modulate:a", 1.0, 0.3)
	walk.tween_property(mv, "position:x", -180.0, 2.6).set_trans(Tween.TRANS_SINE)
	walk.chain().tween_callback(mv.queue_free)
	# 걸음 흔들림
	var bob := mv.create_tween().set_loops(6)
	bob.tween_property(mv, "position:y", mv.position.y - 9.0, 0.22).set_trans(Tween.TRANS_SINE)
	bob.tween_property(mv, "position:y", mv.position.y, 0.22).set_trans(Tween.TRANS_SINE)


## 간단 입찰: 입찰표 과정을 생략하고 봉투만 슉 —
func _quick_submit() -> void:
	busy = true
	bid_row.visible = false
	quiz_row.visible = false
	crowd_row.visible = false
	var env := _envelope_panel("e6d3a3", "8a6f42", "기 일 입 찰 봉 투",
		"%s · 보증금 재중 (간단 제출)" % fmt(pending_bid), "5a4326")
	add_child(env)
	await get_tree().process_frame
	env.position = (size - env.size) / 2.0
	Juice.pop_in(env)
	_play("click")
	await _beat(0.45)
	_play("swoosh")
	env.pivot_offset = env.size / 2.0
	var drop := env.create_tween().set_parallel(true)
	drop.tween_property(env, "rotation", 0.45, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(env, "position:y", env.position.y + 320.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(env, "modulate:a", 0.0, 0.38)
	await drop.finished
	env.queue_free()
	_play("stamp")
	_form_submitted()


func _form_submitted() -> void:
	result.text = ""
	var ev := _roll_event("bid_day")
	if not ev.is_empty():
		result.visible = true
		_show_event(ev, pending_bid, func() -> void: _ceremony(pending_bid, false))
		return
	_ceremony(pending_bid, false)


## 좌석에서 벌떡 일어나는 캐릭터 스프라이트
func _pop_char(e: Dictionary) -> TextureRect:
	var px: float = e["px"]
	var spr := TextureRect.new()
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # size 설정 전에! (안 그러면 텍스처 크기로 클램프)
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.texture = load(e["tex"])
	spr.size = Vector2(px, px)
	spr.pivot_offset = Vector2(px / 2.0, px)
	var base := Vector2(size.x * e["pos"].x - px / 2.0, size.y * e["pos"].y - px)
	spr.position = base + Vector2(0, 80)
	spr.modulate.a = 0.0
	sprite_layer.add_child(spr)
	var tw := spr.create_tween().set_parallel(true)
	tw.tween_property(spr, "position", base, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "modulate:a", 1.0, 0.22)
	return spr


## 낙찰! — 잔금을 낼 것인가, 보증금을 버릴 것인가
func _decision(bid: int) -> void:
	var a: Dictionary = auctions[idx]
	var items := CostCalc.breakdown(a, bid, rules)
	var tot := CostCalc.total(items)
	var evict := CostCalc.eviction_options(a, rules)
	var evict_min := mini(int(evict[0]["cost"]), int(evict[1]["cost"]))
	var dep := _deposit(a)

	var txt := "\n[color=%s][b]★ 최고가매수신고인![/b][/color] 내 입찰가: [b]%s[/b]\n" % [GOLD, fmt(bid)]
	txt += "[color=%s]감정가 %s | 최저가 %s[/color]\n\n" % [MUTED, fmt(int(a["appraisal_price"])), fmt(int(a["min_price"]))]
	txt += "[b]잔금 납부 전 최종 점검[/b] (매각허가 후 약 40일 내 납부)\n"
	txt += "  세금·등기 등 부대비용: %s\n" % fmt(tot)
	txt += "  예상 명도비: %s~\n" % fmt(evict_min)
	var r := _analysis_range(a)
	txt += "  내 시세 분석: %s ~ %s\n\n" % [fmt(r[0]), fmt(r[1])]
	txt += "잔금을 포기하면 보증금 [color=salmon]%s[/color]을 몰수당합니다." % fmt(dep)
	result.text = txt
	_say("낙찰 축하해요! 그런데... 정산이 남았죠. 잔금, 내실 건가요?")

	_actions([
		{"label": "잔금 납부하기", "primary": true, "cb": func() -> void: _pay_balance(bid)},
		{"label": "포기 (보증금 %s 몰수)" % fmt(dep), "primary": false, "cb": func() -> void: _forfeit(bid)},
	])


func _actions(defs: Array) -> void:
	for c in action_row.get_children():
		c.queue_free()
	for d in defs:
		var b := Button.new()
		b.text = d["label"]
		_style_button(b, d["primary"])
		b.pressed.connect(func() -> void:
			action_row.visible = false
			d["cb"].call())
		action_row.add_child(b)
	action_row.visible = true


func _pay_balance(bid: int) -> void:
	_play("click")
	var ev := _roll_event("possession")
	if not ev.is_empty():
		_show_event(ev, bid, func() -> void: _eviction_stage(bid))
		return
	_eviction_stage(bid)


func _eviction_stage(bid: int) -> void:
	var a: Dictionary = auctions[idx]
	if int(rules["eviction"].get(a.get("occupancy", "공실"), {}).get("negotiate", 0)) == 0 \
			and int(rules["eviction"].get(a.get("occupancy", "공실"), {}).get("enforce", 0)) == 0:
		_settle_won(bid, 0, "공실 — 즉시 인도", 0)
		return
	var opts := CostCalc.eviction_options(a, rules)
	await _impact("명 도 발 생", "c0392b", "점유자: %s" % str(a["occupancy"]), "gavel")
	var txt := "\n[b]명도 — 점유자(%s)를 내보내야 합니다[/b]\n" % a["occupancy"]
	for o in opts:
		txt += "  · %s: %s, 약 %d개월%s\n" % [o["label"], fmt(int(o["cost"])), int(o["months"]),
			("  ← " + o["note"]) if o["note"] != "" else ""]
	result.text = txt
	_say("명도는 돈이냐 시간이냐의 선택이에요. 배당받는 임차인은 명도확인서가 필요해서 협상이 쉽죠.")
	_actions([
		{"label": "%s (%s)" % [opts[0]["label"], fmt(int(opts[0]["cost"]))], "primary": true,
			"cb": func() -> void:
				Game.bump("negotiates")
				_negotiate(bid, opts)},
		{"label": "%s (%s)" % [opts[1]["label"], fmt(int(opts[1]["cost"]))], "primary": false,
			"cb": func() -> void:
				Game.bump("enforces")
				_settle_won(bid, int(opts[1]["cost"]), opts[1]["label"], int(opts[1]["months"]))},
	])


## 명도 협상 — 랜덤 사건: 점유자가 이사비 증액을 요구할 수 있다
func _negotiate(bid: int, opts: Array) -> void:
	var a: Dictionary = auctions[idx]
	var rng := RandomNumberGenerator.new()
	rng.randomize()  # 이사비 증액 요구도 매번 다르게
	var cost := int(opts[0]["cost"])
	if cost > 0 and rng.randf() < 0.35:
		var demand := int(cost * 1.8 / 10_000) * 10_000
		await _impact("말 이   바 뀌 었 다", "e07b2c", "\"%s는 주셔야 나갑니다\"" % fmt(demand))
		result.text = "\n[b]협상 난항![/b] 점유자: \"이사비 [color=%s]%s[/color]는 주셔야 나갑니다.\"" % [GOLD, fmt(demand)]
		Juice.pop_in(result)
		_play("wrong")
		_say("도장 찍기 직전에 말을 바꾸네요. 여기서 밀리면 다음엔 더 부릅니다.")
		_actions([
			{"label": "요구 수락 (%s)" % fmt(demand), "primary": false,
				"cb": func() -> void: _settle_won(bid, demand, "이사비 협상 (증액 수락)", int(opts[0]["months"]) + 1)},
			{"label": "협상 결렬 — 강제집행 (%s)" % fmt(int(opts[1]["cost"])), "primary": true,
				"cb": func() -> void:
				Game.bump("enforces")
				_settle_won(bid, int(opts[1]["cost"]), opts[1]["label"], int(opts[1]["months"]))},
		])
		return
	if cost > 0:
		_say("점유자가 순순히 도장을 찍었어요. 협상 성공!")
	_settle_won(bid, cost, opts[0]["label"], int(opts[0]["months"]))


func _forfeit(bid: int) -> void:
	var a: Dictionary = auctions[idx]
	await _impact("보 증 금 몰 수", "8e2c2c", "재매각 · 나는 재입찰 금지", "lose")
	var dep := _deposit(a)
	cash -= dep
	var market := int(int(a["market_price"]) * market_factor)
	var full_net := market - bid - CostCalc.total(CostCalc.breakdown(a, bid, rules)) \
		- mini(int(CostCalc.eviction_options(a, rules)[0]["cost"]), int(CostCalc.eviction_options(a, rules)[1]["cost"]))
	var good := full_net < -dep
	var txt := "\n[b]잔금 포기[/b] — 보증금 [color=salmon]-%s[/color] 몰수. 재매각 절차로 넘어가며, 나는 재입찰 금지.\n" % fmt(dep)
	if good:
		txt += "[color=lightgreen]손절 성공: 잔금을 냈다면 약 %s 손해였어요. 몰수가 오히려 쌌습니다.[/color]\n" % fmt(full_net)
		_say("아프지만 옳은 결정! 실전에서도 낙찰 후 함정을 발견하면 보증금을 버리는 게 나을 때가 있어요.")
		_play("correct")
	else:
		txt += "[color=salmon]아까운 포기: 잔금을 냈다면 약 %s 손익이었어요.[/color]\n" % fmt(full_net)
		_say("이 물건은 진행해도 괜찮았어요. 조사가 부족하면 낙찰하고도 겁이 나죠.")
		_play("lose")
	_finish_case(txt, "forfeit", bid, 0, full_net)


func _settle_won(bid: int, evict_cost: int, evict_label: String, months: int) -> void:
	_play("click")
	busy = true
	var a: Dictionary = auctions[idx]
	wins += 1
	var items := CostCalc.breakdown(a, bid, rules)
	var market := int(int(a["market_price"]) * market_factor)
	var tot := CostCalc.total(items) + evict_cost
	var net := market - bid - tot
	cash += net

	if months > 0 or evict_cost > 0:
		_mover_leaves()
	result.text = "\n[b]정산[/b] — 낙찰가 %s, 명도: %s (%d개월)\n" % [fmt(bid), evict_label, months]
	var lines: Array = []
	for it in items:
		lines.append("  %s: -%s" % [it["name"], fmt(int(it["amount"]))])
	if evict_cost > 0:
		lines.append("  명도비 (%s): -%s" % [evict_label, fmt(evict_cost)])
	lines.append("  [b]총 취득원가: %s[/b]" % fmt(bid + tot))
	lines.append("  시세 매각: +%s" % fmt(market))
	for line in lines:
		await _beat(0.18)
		_play("click")
		result.text += line + "\n"
	await _beat(0.5)
	var color := "lightgreen" if net >= 0 else "salmon"
	var txt := "[color=%s][b]순손익: %s%s[/b][/color]\n" % [color, "+" if net >= 0 else "", fmt(net)]
	_play("win" if net >= 0 else "lose")
	if net >= 0:
		get_tree().create_timer(0.7).timeout.connect(_play.bind("coin"))
		Juice.stars_burst(self, Vector2(size.x * 0.62, size.y * 0.45))
	_update_cash()
	_say("낙~찰! 수익까지 완벽해요!" if net >= 0 else "낙찰은 됐지만 정산하면 손해예요. 인수 금액과 세금까지 계산했어야 해요!")
	_finish_case(txt, "won", bid, net, net)


func _settle_lost(bid: int) -> void:
	var a: Dictionary = auctions[idx]
	var actual := int(a["winning_bid"])
	# 1% 이내로 놓쳤으면 그 아픔을 크게 보여준다
	if absf(bid - actual) <= actual * 0.01:
		await _impact("간   발   의   차", "5b6b8a", "%s 차이" % fmt(absf(actual - bid)), "lose")
	var diff := actual - bid
	var acc := 100.0 - absf(bid - actual) * 100.0 / actual
	var would_net := int(a["market_price"]) - actual - CostCalc.total(CostCalc.breakdown(a, actual, rules))
	var txt := "\n[b]패찰[/b] — 실제 낙찰가 [color=%s]%s[/color], 차액 [b]%s[/b] (정확도 %.1f%%)\n" % [
		GOLD, fmt(actual), fmt(diff), acc]
	txt += "낙찰가율: 감정가 대비 %.1f%% | 응찰 %d명\n" % [actual * 100.0 / int(a["appraisal_price"]), int(a["bidder_count"])]
	if would_net < 0:
		txt += "[color=%s]실제 낙찰자는 정산하면 약 %s 손해 — 무리하지 않은 당신이 이겼습니다.[/color]\n" % [MUTED, fmt(would_net)]
		_say("이건 승자의 저주 물건이었어요. 패찰이 곧 수익이죠!")
	else:
		txt += "[color=%s]실제 낙찰자 예상 손익: 약 +%s[/color]\n" % [MUTED, fmt(would_net)]
		_say("%s만 더 썼으면 내 물건이었네요. 다음엔 분석 범위 상단을 노려봐요!" % fmt(diff))

	# 차순위매수신고 자격: 내 입찰가 ≥ 최고가 − 보증금 (민사집행법 제114조)
	var dep := _deposit(a)
	if bid >= actual - dep and bid >= int(a["min_price"]):
		txt += "\n[color=%s]내 입찰가가 '최고가 − 보증금' 이상 → 차순위매수신고 자격이 있습니다 (민사집행법 제114조).[/color]" % MUTED
		result.text = txt
		Juice.pop_in(result)
		_play("lose")
		_say("최고가매수인이 잔금을 안 내면 내 차례가 와요. 대신 그때까지 보증금이 묶입니다.")
		_actions([
			{"label": "차순위매수신고", "primary": false, "cb": func() -> void: _second_bidder(bid, would_net)},
			{"label": "신고 안 함 (보증금 즉시 반환)", "primary": true,
				"cb": func() -> void: _finish_case("\n차순위 신고 없이 종료 — 보증금은 즉시 반환됩니다.", "lost", bid, 0, would_net)},
		])
		return
	_play("lose")
	_finish_case(txt, "lost", bid, 0, would_net)


## 차순위매수신고 결과 (민사집행법 114조): 최고가매수인 미납 시 지위 승계
func _second_bidder(bid: int, would_net: int) -> void:
	Game.bump("second_bidder")
	var a: Dictionary = auctions[idx]
	var rng := RandomNumberGenerator.new()
	rng.randomize()  # 최고가매수인의 잔금 미납 여부도 매번 다르게
	result.text += "\n차순위매수신고 접수 — 최고가매수인의 잔금 납부를 기다립니다...\n"
	await _beat(1.0)
	if rng.randf() < 0.15:
		result.text += "[color=%s][b]최고가매수인이 잔금을 미납![/b][/color] 차순위인 내가 매수인 지위를 승계합니다.\n" % GOLD
		_say("이런 일이 진짜 있어요! 이제 내 가격으로 이 물건을 삽니다.")
		_play("correct")
		await _beat(0.8)
		_decision(bid)
	else:
		result.text += "최고가매수인이 잔금을 납부했습니다. 내 보증금은 약 40일 묶였다가 반환되었습니다.\n"
		_say("아쉽지만 경험치! 실무에선 자금이 묶여서 차순위 신고를 잘 안 하기도 해요.")
		_play("lose")
		_finish_case("", "lost", bid, 0, would_net)


func _settle_passed() -> void:
	var a: Dictionary = auctions[idx]
	var actual := int(a["winning_bid"])
	var would_net := int(a["market_price"]) - actual - CostCalc.total(CostCalc.breakdown(a, actual, rules))
	var txt := "\n[b]입찰 포기[/b] — 실제 낙찰가 [color=%s]%s[/color] (감정가 대비 %.1f%%, 응찰 %d명)\n" % [
		GOLD, fmt(actual), actual * 100.0 / int(a["appraisal_price"]), int(a["bidder_count"])]
	if would_net < 0:
		txt += "[color=lightgreen]좋은 판단 — 낙찰자는 정산하면 약 %s 손해였을 물건.[/color]\n" % fmt(would_net)
		_say("함정을 피했네요. 프로다워요!")
		_play("correct")
	else:
		txt += "[color=salmon]아까운 패스 — 낙찰자는 약 +%s 수익.[/color]\n" % fmt(would_net)
		_say("신중한 것도 실력이지만, 이건 기회였어요.")
		_play("lose")
	_finish_case(txt, "passed", 0, 0, would_net)


const GRADES := [[90.0, "S"], [80.0, "A"], [70.0, "B"], [60.0, "C"], [50.0, "D"], [-1.0, "F"]]


func _grade_of(score: float) -> String:
	for g in GRADES:
		if score >= float(g[0]):
			return str(g[1])
	return "F"


func _bar(score: float) -> String:
	var on := clampi(int(round(score / 10.0)), 0, 10)
	return "[color=%s]%s[/color][color=%s]%s[/color]" % [
		GOLD, "■".repeat(on), MUTED, "□".repeat(10 - on)]


## 조사 축 — 얼마나 들여다봤나
func _score_investigate(a: Dictionary) -> Array:
	var has_quiz: bool = not (a.get("tenants", []) as Array).is_empty()
	var tabs := mini(seen_tabs.size(), 3)
	var note := "조사 탭 %d/3" % tabs
	if not has_quiz:
		return [tabs * 100.0 / 3.0, note + " · 임차인 없음(권리 판정 생략)"]
	var quiz := 40.0 if quiz_state == 1 else 0.0
	note += " · 권리 판정 " + ("정답" if quiz_state == 1 else ("오답" if quiz_state == -1 else "미응답"))
	return [tabs * 20.0 + quiz, note]


## 분석 축 — 실제 낙찰가를 얼마나 맞췄나 (오차 25%면 0점)
func _score_analyze(a: Dictionary, bid: int, would_net: int) -> Array:
	var actual := int(a["winning_bid"])
	if bid <= 0:
		return [100.0, "입찰 포기 — 실제 낙찰자도 손해 본 물건"] if would_net < 0 \
			else [30.0, "입찰 포기 — 실제로는 수익이 났던 물건"]
	var err := absf(bid - actual) * 100.0 / maxf(1.0, float(actual))
	return [clampf(100.0 - err * 4.0, 0.0, 100.0),
		"입찰 %s / 실제 %s (오차 %.1f%%)" % [fmt(bid), fmt(actual), err]]


## 재무 축 — 돈이 남았나, 무리하지 않았나
func _score_finance(a: Dictionary, kind: String, bid: int, net: int, would_net: int) -> Array:
	match kind:
		"won":
			var roi := float(net) * 100.0 / maxf(1.0, float(bid))
			return [clampf(50.0 + roi * 3.0, 0.0, 100.0),
				"순손익 %s%s (투입 대비 %+.1f%%)" % ["+" if net >= 0 else "", fmt(net), roi]]
		"lost":
			if would_net < 0:
				return [100.0, "승자의 저주를 피했다 — 낙찰자는 %s 손해" % fmt(would_net)]
			if bid <= _analysis_range(a)[1]:
				return [70.0, "분석 범위 안에서 합리적으로 썼지만 놓쳤다"]
			return [40.0, "범위를 벗어난 입찰 — 근거 없이 질렀다"]
		"passed":
			return [100.0, "피한 게 정답 — 낙찰자는 %s 손해" % fmt(would_net)] if would_net < 0 \
				else [30.0, "기회를 놓쳤다 — 낙찰자는 +%s 수익" % fmt(would_net)]
		"forfeit":
			return [10.0 if would_net < -_deposit(a) else 0.0,
				"보증금 %s 몰수" % fmt(_deposit(a))]
	return [60.0, "내 판단 밖의 사유로 종결 — 재무 평가 보류"]


## 판단 평가표 — 조사 / 분석 / 재무를 100점 만점으로 채점
func _finish_case(txt: String, kind: String, bid: int, net: int, would_net: int) -> void:
	var a: Dictionary = auctions[idx]
	var rows := [
		["조사", _score_investigate(a), 0.3],
		["분석", _score_analyze(a, bid, would_net), 0.4],
		["재무", _score_finance(a, kind, bid, net, would_net), 0.3],
	]
	var total := 0.0
	txt += "\n\n[b]■ 판단 평가표[/b]\n"
	for r in rows:
		var s: float = float(r[1][0])
		total += s * float(r[2])
		txt += "  %s  %s [b]%3d[/b]  [color=%s]%s[/color]\n" % [r[0], _bar(s), int(round(s)), MUTED, r[1][1]]

	var grade := _grade_of(total)
	score_total += total
	cases_done += 1
	var avg := score_total / cases_done
	txt += "  [color=%s]─────────────────────────────[/color]\n" % MUTED
	txt += "  종합  [b]%d점[/b]  등급 [color=%s][b]%s[/b][/color]   [color=%s]누적 %s (%d건 평균 %d점)[/color]" % [
		int(round(total)), GOLD, grade, MUTED, _grade_of(avg), cases_done, int(round(avg))]

	_record(a, kind, bid, net, would_net, total)
	txt += _title_lines()

	# 결과 한 줄은 story.json에서 (같은 말이 반복되지 않게 매번 무작위)
	var mood := str({"won": "won_profit" if net >= 0 else "won_loss",
		"lost": "lost_curse" if would_net < 0 else "lost_miss",
		"passed": "passed_right" if would_net < 0 else "passed_wrong",
		"forfeit": "forfeit"}.get(kind, ""))
	var say := Game.line("outcome", mood) if mood != "" else ""
	if grade in ["S", "A"]:
		Juice.stars_burst(self, Vector2(size.x * 0.5, size.y * 0.6), 16)
		say = "등급 %s! %s" % [grade, say]
	if say != "":
		_say(say)
	result.text += txt
	Juice.pop_in(result)
	next_btn.visible = true
	busy = false


## 칭호용 누적 기록 (Game에 쌓아 라운드를 다시 시작해도 유지된다)
func _record(a: Dictionary, kind: String, bid: int, net: int, would_net: int, score: float) -> void:
	var actual := int(a["winning_bid"])
	Game.bump("cases_done")
	Game.bump("score_sum", score)
	Game.peak("best_score", score)
	Game.saw(str(a["kind"]), str(a["address"]))
	if seen_tabs.size() >= 3:
		Game.bump("tabs_full")
	if quiz_state == 1:
		Game.bump("rights_correct")
	elif quiz_state == -1:
		Game.bump("rights_wrong")
	if bid > 0 and actual > 0:
		Game.peak("best_accuracy", 100.0 - absf(bid - actual) * 100.0 / actual)
	match kind:
		"won":
			Game.bump("wins")
			Game.bump("total_net", float(net))
			Game.peak("max_net", float(net))
			Game.trough("min_net", float(net))
			Game.bump("wins_" + {"내 집 마련": "home", "월세 받기": "rent",
				"토지 장기보유": "land", "큰 판": "big"}.get(Game.purpose_of(a), "home"))
			if Game.difficulty_of(a) == "위험":
				Game.bump("wins_risky")
		"lost":
			Game.bump("losses")
			if would_net < 0:
				Game.bump("winners_curse_avoided")
			if actual > 0 and absf(bid - actual) <= actual * 0.01:
				Game.bump("near_miss")
		"passed":
			Game.bump("passes")
			if would_net < 0:
				Game.bump("winners_curse_avoided")
		"forfeit":
			Game.bump("forfeits")
			Game.bump("total_net", float(net))
			Game.trough("min_net", float(net))


## 개찰 직후 "내가 어디쯤이었나"를 한 줄 위에 찍어 보여준다.
## 숫자 표보다 거리가 먼저 눈에 들어와야 배움이 남는다.
func _show_reveal_line(a: Dictionary, my_bid: int, passed: bool) -> void:
	if reveal_line != null:
		reveal_line.queue_free()
	var marks: Array = [
		{"v": int(a["min_price"]), "t": "최저가", "c": MUTED, "up": false},
		{"v": int(a["appraisal_price"]), "t": "감정가", "c": "8ca0c8", "up": false},
		{"v": int(a["winning_bid"]), "t": "실제 낙찰", "c": GOLD, "up": true},
	]
	if int(a.get("second_bid", 0)) > 0:
		marks.append({"v": int(a["second_bid"]), "t": "2순위", "c": "9aa0b4", "up": true})
	if int(a.get("market_price", 0)) > 0:
		marks.append({"v": int(a["market_price"]), "t": "시세", "c": "7fb389", "up": false})
	if not passed:
		marks.append({"v": my_bid, "t": "내 입찰", "c": "e8734a", "up": true})

	var lo := marks[0]["v"] as int
	var hi := lo
	for m in marks:
		lo = mini(lo, int(m["v"]))
		hi = maxi(hi, int(m["v"]))
	if hi <= lo:
		hi = lo + 1

	reveal_line = Control.new()
	reveal_line.custom_minimum_size = Vector2(0, 108)
	reveal_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := get_theme_default_font()
	reveal_line.draw.connect(func() -> void:
		var w := reveal_line.size.x - 24.0
		var y := 58.0
		reveal_line.draw_line(Vector2(12, y), Vector2(12 + w, y), Color(MUTED), 2.0)
		for m in marks:
			var x := 12.0 + w * float(int(m["v"]) - lo) / float(hi - lo)
			var up: bool = m["up"]
			var col := Color(m["c"])
			reveal_line.draw_line(Vector2(x, y), Vector2(x, y + (-16.0 if up else 16.0)), col, 2.0)
			reveal_line.draw_circle(Vector2(x, y), 4.0, col)
			var label := "%s\n%s" % [m["t"], fmt(int(m["v"]))]
			var ty := y - 40.0 if up else y + 30.0
			for i in 2:
				var line := label.split("\n")[i]
				var tw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				reveal_line.draw_string(font, Vector2(clampf(x - tw / 2.0, 0, reveal_line.size.x - tw), ty + i * 13.0),
					line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col))
	result.get_parent().add_child(reveal_line)
	result.get_parent().move_child(reveal_line, result.get_index())
	Juice.pop_in(reveal_line)


## 금액을 억 → 만 → 원 순서로 끊어 부른다. 마지막 자리 앞에서 한 박자 뜸을 들여
## "8억... 2,300만... 5천원!" 처럼 실제 개찰의 호흡을 만든다.
func _call_amount(rank: int, who: String, amt: int) -> void:
	var parts := fmt(amt).trim_suffix("원").split(" ", false)
	var shown := ""
	for i in parts.size():
		var last := i == parts.size() - 1
		if last and parts.size() > 1:
			await _beat(0.42)
			_play("click", 1.08)
		shown += ("" if shown == "" else " ") + parts[i]
		_call("%d순위 — %s, %s%s" % [rank, who, shown, "원!" if last else "..."])
		if not last:
			await _beat(0.36)


## 화면 한복판을 때리는 임팩트 컷 — 큰 사건은 확실히 각인시킨다
## _impact("명 도 발 생", "d94a3d", "점유자가 버티고 있습니다")
func _impact(text: String, col: String, sub := "", sound := "wrong") -> void:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	# 좌우로 쫙 벌어지는 색 띠
	var band := ColorRect.new()
	band.color = Color(col)
	band.color.a = 0.92
	band.size = Vector2(size.x, 132.0)
	band.position = Vector2(0, size.y * 0.40)
	band.pivot_offset = band.size / 2.0
	band.scale = Vector2(0.0, 0.18)
	layer.add_child(band)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)

	var big := Label.new()
	big.text = text
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 68)
	big.add_theme_color_override("font_color", Color("fdfdfd"))
	big.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	big.add_theme_constant_override("outline_size", 12)
	box.add_child(big)
	if sub != "":
		var small := Label.new()
		small.text = sub
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		small.add_theme_font_size_override("font_size", 20)
		small.add_theme_color_override("font_color", Color("fdfdfd"))
		small.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		small.add_theme_constant_override("outline_size", 8)
		box.add_child(small)

	box.pivot_offset = size / 2.0
	box.scale = Vector2(2.9, 2.9)
	box.modulate.a = 0.0
	box.rotation = -0.07

	_play(sound)
	var tin := create_tween().set_parallel(true)
	tin.tween_property(band, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tin.tween_property(dim, "color", Color(0, 0, 0, 0.45), 0.13)
	tin.tween_property(box, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tin.tween_property(box, "rotation", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tin.tween_property(box, "modulate:a", 1.0, 0.10)
	await tin.finished
	Juice.shake(self, 11.0, 0.28)

	await _beat(0.78)
	var tout := create_tween().set_parallel(true)
	tout.tween_property(band, "scale", Vector2(1.0, 0.0), 0.16).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tout.tween_property(dim, "color", Color(0, 0, 0, 0.0), 0.20)
	tout.tween_property(box, "scale", Vector2(1.35, 1.35), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tout.tween_property(box, "modulate:a", 0.0, 0.20)
	await tout.finished
	layer.queue_free()


## 라운드 종료 화면에 지금까지 모은 칭호를 보여준다
func _earned_summary() -> String:
	if Game.earned.is_empty():
		return "[color=%s]아직 얻은 칭호가 없어요. 계속 입찰해 보세요.[/color]" % MUTED
	var names: Array = []
	for t in Game.titles_def:
		if str(t["id"]) in Game.earned:
			names.append("[color=%s]%s[/color]" % [GOLD, t["name"]])
	return "[b]칭호 %d / %d[/b]\n%s" % [names.size(), Game.titles_def.size(), "  ·  ".join(names)]


## 이번 물건으로 새로 얻은 칭호 (여러 개가 한 번에 터질 수 있어 한 덩어리로 보여준다)
func _title_lines() -> String:
	var got := Game.new_titles()
	if got.is_empty():
		return ""
	_play("coin")
	var t := "\n\n[b][color=%s]★ 새 칭호[/color][/b]\n" % GOLD
	for g in got:
		t += "  [color=%s][b]%s[/b][/color] (T%d) — %s\n" % [GOLD, g["name"], int(g["tier"]), g["desc"]]
		if str(g.get("flavor", "")) != "":
			t += "     [color=%s]%s[/color]\n" % [MUTED, g["flavor"]]
	return t


func _on_next() -> void:
	# 연출 건너뛰려고 누른 클릭이 '다음 물건'까지 눌러버리는 사고 방지
	if busy or Time.get_ticks_msec() - last_skip_ms < 250:
		return
	_play("click")
	if finished:
		idx = 0
		cash = Game.capital
		wins = 0
		score_total = 0.0
		cases_done = 0
		auctions = Game.shuffled_for_play(pool)  # 다시 시작하면 풀에서 새로 뽑는다
		finished = false
		next_btn.text = "다음 물건 ▶"
		_show_auction()
		return
	idx += 1
	_show_auction()


func _show_end() -> void:
	finished = true
	var net := cash - Game.capital
	var avg := score_total / maxi(cases_done, 1)
	var grade := _grade_of(avg)
	var color := "lightgreen" if net >= 0 else "salmon"
	info.text = ("[b]라운드 종료[/b]\n\n낙찰 %d건 / 진행 %d건\n평균 판단 점수: [color=%s]%d점[/color]  %s\n" +
		"최종 자산: [b][color=%s]%s[/color][/b]\n[color=%s][b]총 손익: %s%s[/b][/color]\n\n" +
		"[b]최종 등급: [color=%s]%s[/color][/b]") % [
		wins, cases_done, GOLD, int(round(avg)), _bar(avg),
		GOLD, fmt(cash), color, "+" if net >= 0 else "", fmt(net), GOLD, grade]
	detail.text = "[color=%s]%s[/color]\n\n%s" % [MUTED, Game.line("epilogue", grade), _earned_summary()]
	range_label.text = ""
	photo.texture = null
	photo_caption.text = ""
	bid_row.visible = false
	quiz_row.visible = false
	crowd_row.visible = false
	action_row.visible = false
	result.visible = false
	next_btn.text = "다시 시작"
	next_btn.visible = true
	_play("win" if grade in ["S", "A"] else "lose")
	_say("등급 %s! 수고했어요. 조사 → 판단 → 입찰 → 정산, 실전 경매도 똑같아요." % grade)


func _say(msg: String) -> void:
	speech.text = msg


static func fmt(n: int) -> String:
	var sign := "-" if n < 0 else ""
	n = absi(n)
	var eok := n / 100_000_000
	var man := (n % 100_000_000) / 10_000
	var rest := n % 10_000
	var parts: PackedStringArray = []
	if eok > 0:
		parts.append("%d억" % eok)
	if man > 0:
		parts.append("%s만" % _comma(man))
	if rest > 0 or parts.is_empty():
		parts.append(_comma(rest))
	return sign + " ".join(parts) + "원"


static func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
