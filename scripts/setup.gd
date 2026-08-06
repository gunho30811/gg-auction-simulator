extends Control
## 입찰 준비 화면 — 진행 축(자본금 · 목적 · 난이도 · 지역)으로 고르고,
## 지지옥션 용도 분류(계열→종→용도)는 '상세 용도 필터'로 접어둔다.

const COL_CARD := Color("1b1e2a")
const COL_EDGE := Color("2b3044")
const COL_GOLD := Color("e0b95e")
const COL_MUTED := Color("9aa0b4")

const CAPITALS := [[50_000_000, "5,000만원 (소액 도전)"], [200_000_000, "2억원 (실전형)"],
	[500_000_000, "5억원 (여유형)"], [2_000_000_000, "20억원 (큰손)"]]

const ROUNDS := [[10, "10건 (짧게)"], [20, "20건"], [30, "30건"], [50, "50건"],
	[100, "100건 (길게)"], [0, "제한 없음"]]

# 개찰 세리머니·정산 연출 속도. 반복 플레이에서 연출이 벌칙이 되지 않게.
const FX_SPEEDS := [[1.0, "보통 (연출 전부 감상)"], [0.45, "빠름"], [0.0, "즉시 (연출 건너뛰기)"]]

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
var round_opt: OptionButton
var fx_opt: OptionButton
var purpose_opt: OptionButton
var purpose_desc: Label
var diff_opt: OptionButton
var detail_btn: CheckButton
var detail_box: VBoxContainer
var series_opt: OptionButton
var jong_opt: OptionButton
var kind_opt: OptionButton
var region_opts: Array = []
var match_label: Label
var start_btn: Button


func _ready() -> void:
	auctions = JSON.parse_string(FileAccess.get_file_as_string("res://data/auctions.json"))
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
	capital_opt.item_selected.connect(func(_i: int) -> void: _refresh_axes())

	round_opt = _opt("라운드 물건 수", box)
	for r in ROUNDS:
		round_opt.add_item(r[1])
	round_opt.select(1)  # 20건
	round_opt.item_selected.connect(func(_i: int) -> void: _refresh())

	fx_opt = _opt("연출 속도", box)
	for f in FX_SPEEDS:
		fx_opt.add_item(f[1])
	fx_opt.item_selected.connect(func(i: int) -> void: Game.fx_speed = FX_SPEEDS[i][0])

	# 진행 축 1: 왜 사는가 / 2: 인수·명도 위험 (data/play_axes.json)
	purpose_opt = _opt("목적", box)
	purpose_opt.item_selected.connect(func(_i: int) -> void: _refresh_axes())
	purpose_desc = Label.new()
	purpose_desc.add_theme_color_override("font_color", COL_MUTED)
	purpose_desc.add_theme_font_size_override("font_size", 12)
	box.add_child(purpose_desc)

	diff_opt = _opt("난이도 (인수·명도 위험)", box)
	diff_opt.item_selected.connect(func(_i: int) -> void: _refresh_axes())

	# 지역: 도 → 시 → 구 (물건 주소에서 동적 생성)
	for i in 3:
		var o := _opt(["지역 (시·도)", "시·군·구", "구·읍·면"][i], box)
		o.item_selected.connect(func(_i: int) -> void: _on_region_change(i))
		region_opts.append(o)

	# 지지옥션 용도 분류(계열→종→용도)는 평소엔 접어두고 필요할 때만 편다
	detail_btn = CheckButton.new()
	detail_btn.text = "상세 용도 필터 (지지옥션 분류)"
	detail_btn.add_theme_color_override("font_color", COL_MUTED)
	detail_btn.toggled.connect(func(on: bool) -> void: _toggle_detail(on))
	box.add_child(detail_btn)

	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 12)
	detail_box.visible = false
	box.add_child(detail_box)

	series_opt = _opt("용도 계열", detail_box)
	series_opt.add_item("전체")
	for s in taxonomy.keys():
		series_opt.add_item(s)
	series_opt.item_selected.connect(func(_i: int) -> void: _refresh_jong())

	jong_opt = _opt("용도 종", detail_box)
	jong_opt.item_selected.connect(func(_i: int) -> void: _refresh_kind())

	kind_opt = _opt("용도", detail_box)
	kind_opt.item_selected.connect(func(_i: int) -> void: _refresh())

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
	_refresh_axes()


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
	_refresh_axes()  # 지역이 바뀌면 목적·난이도·용도 건수를 모두 다시 센다


## 목적·난이도 드롭다운을 건수와 함께 다시 채운다 (자본금·지역이 바뀌면 건수도 달라짐)
func _refresh_axes() -> void:
	Game.capital = CAPITALS[capital_opt.selected][0]
	Game.region = _region_path(3)

	var prev_p := _picked(purpose_opt)
	purpose_opt.clear()
	purpose_opt.add_item("전체")
	for p in (Game.axes.get("purposes", {}) as Dictionary):
		var n := _count(func(a: Dictionary) -> bool: return Game.purpose_of(a) == p)
		purpose_opt.add_item("%s (%d건)" % [p, n])
		purpose_opt.set_item_metadata(purpose_opt.get_item_count() - 1, p)
		if n == 0:
			purpose_opt.set_item_disabled(purpose_opt.get_item_count() - 1, true)
	_reselect(purpose_opt, prev_p)
	var picked_p := _picked(purpose_opt)
	purpose_desc.text = "" if picked_p == "" \
		else str(Game.axes["purposes"][picked_p].get("desc", ""))

	var prev_d := _picked(diff_opt)
	diff_opt.clear()
	diff_opt.add_item("전체")
	for lv in ["안전", "보통", "위험"]:
		var n := _count(func(a: Dictionary) -> bool:
			return Game.difficulty_of(a) == lv and (picked_p == "" or Game.purpose_of(a) == picked_p))
		diff_opt.add_item("%s (%d건)" % [lv, n])
		diff_opt.set_item_metadata(diff_opt.get_item_count() - 1, lv)
		if n == 0:
			diff_opt.set_item_disabled(diff_opt.get_item_count() - 1, true)
	_reselect(diff_opt, prev_d)
	_refresh_jong()


func _toggle_detail(on: bool) -> void:
	detail_box.visible = on
	if not on:  # 접으면 용도 필터는 해제 — 목적·난이도만으로 고르게
		series_opt.select(0)
		_refresh_jong()
	else:
		_refresh()


## 현재 자본금·지역 조건 안에서 cond를 만족하는 물건 수
func _count(cond: Callable) -> int:
	var n := 0
	for a in auctions:
		if Game.affordable(a) and Game.region_match(str(a.get("address", ""))) and cond.call(a):
			n += 1
	return n


## 선택한 조건 안에서 해당 용도의 물건 수 (0건이면 고를 수 없게 막는다)
func _count_kinds(kinds: Array) -> int:
	var p := _picked(purpose_opt)
	var d := _picked(diff_opt)
	return _count(func(a: Dictionary) -> bool:
		return str(a.get("kind", "")) in kinds \
			and (p == "" or Game.purpose_of(a) == p) \
			and (d == "" or Game.difficulty_of(a) == d))


func _jong_kinds(series: String, jong: String) -> Array:
	if not taxonomy.has(series):
		return []
	if taxonomy[series].has(jong):
		return taxonomy[series][jong]
	var out: Array = []
	for j in taxonomy[series].keys():
		out.append_array(taxonomy[series][j])
	return out


## 목록을 다시 만들면 선택이 풀리므로, 같은 항목이 남아 있으면 되살린다
func _reselect(o: OptionButton, want: String) -> void:
	if want != "":
		for i in o.get_item_count():
			if str(o.get_item_metadata(i)) == want and not o.is_item_disabled(i):
				o.select(i)
				return
	o.select(0)


func _picked(o: OptionButton) -> String:
	return str(o.get_item_metadata(o.selected)) if o and o.selected > 0 else ""


func _refresh_jong() -> void:
	Game.region = _region_path(3)  # 건수를 현재 지역 기준으로 세기 위해 먼저 반영
	var prev := _picked(jong_opt)
	jong_opt.clear()
	jong_opt.add_item("전체")
	var s := series_opt.get_item_text(series_opt.selected)
	if taxonomy.has(s):
		for j in taxonomy[s].keys():
			var cnt := _count_kinds(taxonomy[s][j])
			jong_opt.add_item("%s (%d건)" % [j, cnt])
			jong_opt.set_item_metadata(jong_opt.get_item_count() - 1, j)
			if cnt == 0:
				jong_opt.set_item_disabled(jong_opt.get_item_count() - 1, true)
	_reselect(jong_opt, prev)
	_refresh_kind()


func _refresh_kind() -> void:
	Game.region = _region_path(3)
	var prev := _picked(kind_opt)
	kind_opt.clear()
	kind_opt.add_item("전체")
	for k in _jong_kinds(series_opt.get_item_text(series_opt.selected), _picked(jong_opt)):
		var cnt := _count_kinds([k])
		kind_opt.add_item("%s (%d건)" % [k, cnt])
		kind_opt.set_item_metadata(kind_opt.get_item_count() - 1, k)
		if cnt == 0:
			kind_opt.set_item_disabled(kind_opt.get_item_count() - 1, true)
	_reselect(kind_opt, prev)
	_refresh()


func _selected_kinds() -> Array:
	var s := series_opt.get_item_text(series_opt.selected)
	if not taxonomy.has(s):
		return []
	if _picked(kind_opt) != "":
		return [_picked(kind_opt)]
	return _jong_kinds(s, _picked(jong_opt))


func _apply_to_game() -> void:
	Game.capital = CAPITALS[capital_opt.selected][0]
	Game.round_size = ROUNDS[round_opt.selected][0]
	Game.fx_speed = FX_SPEEDS[fx_opt.selected][0]
	Game.region = _region_path(3)
	Game.purpose = _picked(purpose_opt)
	Game.difficulty = _picked(diff_opt)
	Game.kinds = _selected_kinds() if detail_btn.button_pressed else []
	Game.series_label = series_opt.get_item_text(series_opt.selected)
	Game.jong_label = _picked(jong_opt) if _picked(jong_opt) != "" else "전체"


func _refresh() -> void:
	_apply_to_game()
	var n := Game.filter_auctions(auctions).size()
	var play := n if Game.round_size <= 0 else mini(n, Game.round_size)
	match_label.text = "조건에 맞는 물건 %d건 / 전체 %d건  →  이번 라운드 %d건" % [n, auctions.size(), play]
	if n > 0 and n < Game.round_size:
		match_label.text += "  (조건에 맞는 게 적어 %d건만 진행됩니다)" % n
	if start_btn:
		start_btn.disabled = n == 0
	match_label.add_theme_color_override("font_color", Color("e0b95e") if n > 0 else Color("e06a5a"))


func _on_start() -> void:
	_apply_to_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")