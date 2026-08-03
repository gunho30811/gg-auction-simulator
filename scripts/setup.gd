extends Control
## 입찰 준비 화면: 지역(도→시→구) · 용도(계열→종) · 자본금 선택 → 물건 필터

const COL_CARD := Color("1b1e2a")
const COL_EDGE := Color("2b3044")
const COL_GOLD := Color("e0b95e")
const COL_MUTED := Color("9aa0b4")

const CAPITALS := [[50_000_000, "5,000만원 (소액 도전)"], [200_000_000, "2억원 (실전형)"],
	[500_000_000, "5억원 (여유형)"], [2_000_000_000, "20억원 (큰손)"]]

# 대한민국 17개 시·도 (정식 명칭, 물건 주소 토큰)
const SIDO := [["서울특별시", "서울"], ["부산광역시", "부산"], ["대구광역시", "대구"],
	["인천광역시", "인천"], ["광주광역시", "광주"], ["대전광역시", "대전"],
	["울산광역시", "울산"], ["세종특별자치시", "세종"], ["경기도", "경기"],
	["강원특별자치도", "강원"], ["충청북도", "충북"], ["충청남도", "충남"],
	["전북특별자치도", "전북"], ["전라남도", "전남"], ["경상북도", "경북"],
	["경상남도", "경남"], ["제주특별자치도", "제주"]]

var auctions: Array
var taxonomy: Dictionary

var capital_opt: OptionButton
var series_opt: OptionButton
var jong_opt: OptionButton
var region_opts: Array = []
var match_label: Label
var start_btn: Button


func _ready() -> void:
	auctions = JSON.parse_string(FileAccess.get_file_as_string("res://data/sample_auctions.json"))
	taxonomy = JSON.parse_string(FileAccess.get_file_as_string("res://data/usage_taxonomy.json"))
	taxonomy.erase("_comment")
	_build_ui()
	_refresh()


func _opt(label_text: String, parent: Control) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size.x = 110
	l.add_theme_color_override("font_color", COL_MUTED)
	row.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(o)
	return o


func _build_ui() -> void:
	var court := TextureRect.new()
	court.texture = load("res://assets/art/courtroom.png")
	court.set_anchors_preset(Control.PRESET_FULL_RECT)
	court.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	court.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(court)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.07, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COL_CARD.r, COL_CARD.g, COL_CARD.b, 0.96)
	style.set_corner_radius_all(16)
	style.set_border_width_all(1)
	style.border_color = COL_GOLD
	style.set_content_margin_all(26)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var title := Label.new()
	title.text = "입찰 준비"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", COL_GOLD)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "어디에, 무엇에, 얼마로 도전할까요?"
	sub.add_theme_color_override("font_color", COL_MUTED)
	box.add_child(sub)

	capital_opt = _opt("시작 자본금", box)
	for c in CAPITALS:
		capital_opt.add_item(c[1])
	capital_opt.select(3)

	# 지역: 도 → 시 → 구 (물건 주소에서 동적 생성)
	for i in 3:
		var o := _opt(["지역 (시·도)", "시·군·구", "구·읍·면"][i], box)
		o.item_selected.connect(func(_i: int) -> void: _on_region_change(i))
		region_opts.append(o)

	series_opt = _opt("용도 계열", box)
	series_opt.add_item("전체")
	for s in taxonomy.keys():
		series_opt.add_item(s)
	series_opt.item_selected.connect(func(_i: int) -> void: _refresh_jong())

	jong_opt = _opt("용도 종", box)
	jong_opt.item_selected.connect(func(_i: int) -> void: _refresh())

	match_label = Label.new()
	match_label.add_theme_color_override("font_color", COL_MUTED)
	box.add_child(match_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	box.add_child(btn_row)
	var back := Button.new()
	back.text = "뒤로"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/title.tscn"))
	btn_row.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(spacer)
	start_btn = Button.new()
	start_btn.text = "입찰하러 가기"
	var gold := StyleBoxFlat.new()
	gold.bg_color = COL_GOLD
	gold.set_corner_radius_all(8)
	gold.set_content_margin_all(10)
	gold.content_margin_left = 26
	gold.content_margin_right = 26
	start_btn.add_theme_stylebox_override("normal", gold)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		start_btn.add_theme_color_override(st, Color("1a1508"))
	start_btn.pressed.connect(_on_start)
	btn_row.add_child(start_btn)

	_refresh_region(0)
	_refresh_jong()


func _region_path(depth: int) -> PackedStringArray:
	var path: PackedStringArray = []
	for i in depth:
		var o: OptionButton = region_opts[i]
		if o.selected <= 0:
			break
		if i == 0:
			path.append(str(o.get_item_metadata(o.selected)))  # 시·도는 주소 토큰으로 매칭
		else:
			path.append(o.get_item_text(o.selected))
	return path


func _refresh_region(from_level: int) -> void:
	for lv in range(from_level, 3):
		var o: OptionButton = region_opts[lv]
		o.clear()
		o.add_item("전체")
		var prefix := _region_path(lv)
		if prefix.size() < lv:
			continue
		if lv == 0:
			# 17개 시·도 정식 명칭 + 보유 물건 수
			for s in SIDO:
				var cnt := 0
				for a in auctions:
					if str(a.get("address", "")).split(" ")[0] == s[1]:
						cnt += 1
				o.add_item("%s (%d건)" % [s[0], cnt])
				o.set_item_metadata(o.get_item_count() - 1, s[1])
				if cnt == 0:
					o.set_item_disabled(o.get_item_count() - 1, true)
			continue
		var seen := {}
		for a in auctions:
			var toks: PackedStringArray = str(a.get("address", "")).split(" ")
			if toks.size() <= lv:
				continue
			var ok := true
			for i in lv:
				if i >= prefix.size() or toks[i] != prefix[i]:
					ok = false
					break
			if ok and prefix.size() == lv and not seen.has(toks[lv]):
				seen[toks[lv]] = true
				o.add_item(toks[lv])


func _on_region_change(level: int) -> void:
	_refresh_region(level + 1)
	_refresh()


func _refresh_jong() -> void:
	jong_opt.clear()
	jong_opt.add_item("전체")
	var s := series_opt.get_item_text(series_opt.selected)
	if taxonomy.has(s):
		for j in taxonomy[s].keys():
			jong_opt.add_item(j)
	_refresh()


func _selected_kinds() -> Array:
	var s := series_opt.get_item_text(series_opt.selected)
	if not taxonomy.has(s):
		return []
	var j := jong_opt.get_item_text(jong_opt.selected)
	var out: Array = []
	if taxonomy[s].has(j):
		out.append(j)
		out.append_array(taxonomy[s][j])
	else:
		for jong in taxonomy[s].keys():
			out.append(jong)
			out.append_array(taxonomy[s][jong])
	return out


func _apply_to_game() -> void:
	Game.capital = CAPITALS[capital_opt.selected][0]
	Game.region = _region_path(3)
	Game.kinds = _selected_kinds()
	Game.series_label = series_opt.get_item_text(series_opt.selected)
	Game.jong_label = jong_opt.get_item_text(jong_opt.selected)


func _refresh() -> void:
	_apply_to_game()
	var n := Game.filter_auctions(auctions).size()
	match_label.text = "조건에 맞는 물건: %d건 / 전체 %d건" % [n, auctions.size()]
	if start_btn:
		start_btn.disabled = n == 0
	match_label.add_theme_color_override("font_color", Color("e0b95e") if n > 0 else Color("e06a5a"))


func _on_start() -> void:
	_apply_to_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")