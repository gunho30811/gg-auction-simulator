extends Node
## 게임 설정 싱글톤 (autoload: Game) — 입찰 준비 화면에서 채워짐

var capital := 2_000_000_000
var round_size := 20    # 한 라운드에 볼 물건 수
var simple_bid := false  # 기일입찰표 상세 과정 생략
var fx_speed := 1.0      # 연출 속도: 1.0 보통 / 0.45 빠름 / 0.0 즉시
var region: PackedStringArray = []  # 주소 앞 토큰 경로 (예: ["인천", "남동구"]). 빈 배열 = 전체
var kinds: Array = []               # 허용 용도 문자열 (빈 = 전체). 상세 필터에서만 채워짐
var purpose := ""                   # 진행 축 1: 왜 사는가 (빈 = 전체)
var difficulty := ""                # 진행 축 2: 인수·명도 위험 (빈 = 전체)
var series_label := "전체"
var jong_label := "전체"

var axes: Dictionary = {}
var story: Dictionary = {}

# 칭호용 누적 기록 — 라운드를 다시 시작해도 계속 쌓인다 (main.gd의 라운드 변수와 분리)
var stats: Dictionary = {}
var titles_def: Array = []
var earned: Array = []
var _seen_kinds: Dictionary = {}
var _seen_regions: Dictionary = {}


func _ready() -> void:
	axes = JSON.parse_string(FileAccess.get_file_as_string("res://data/play_axes.json"))
	story = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	titles_def = JSON.parse_string(FileAccess.get_file_as_string("res://data/titles.json")).get("titles", [])


func bump(key: String, by := 1.0) -> void:
	stats[key] = stat(key) + by


func peak(key: String, v: float) -> void:
	stats[key] = maxf(stat(key), v)


func trough(key: String, v: float) -> void:
	stats[key] = minf(stat(key), v)


func stat(key: String) -> float:
	return float(stats.get(key, 0.0))


func saw(kind: String, address: String) -> void:
	_seen_kinds[kind] = true
	_seen_regions[address.split(" ")[0]] = true
	stats["kinds_seen"] = float(_seen_kinds.size())
	stats["regions_seen"] = float(_seen_regions.size())


## 조건을 다 만족하면서 아직 안 받은 칭호만 돌려준다
func new_titles() -> Array:
	if stat("cases_done") > 0:
		stats["avg_score"] = stat("score_sum") / stat("cases_done")
	var out: Array = []
	for t in titles_def:
		if str(t["id"]) in earned:
			continue
		var ok := true
		for c in (t["cond"] as Array):
			var a := stat(str(c["stat"]))
			var b := float(c["value"])
			match str(c["op"]):
				">=": ok = a >= b
				"<=": ok = a <= b
				">": ok = a > b
				"<": ok = a < b
				"==": ok = is_equal_approx(a, b)
				_: ok = false
			if not ok:
				break
		if ok:
			earned.append(str(t["id"]))
			out.append(t)
	return out


## story.json의 배열에서 한 줄 무작위 (없으면 빈 문자열)
func line(section: String, key: String) -> String:
	var arr: Array = (story.get(section, {}) as Dictionary).get(key, [])
	return str(arr[randi() % arr.size()]) if not arr.is_empty() else ""


func chapter_at(n: int) -> Dictionary:
	for c in (story.get("chapter", []) as Array):
		if int(c["at"]) == n:
			return c
	return {}


## 물건의 목적 축 — 용도로 판정
func purpose_of(a: Dictionary) -> String:
	var kind := str(a.get("kind", ""))
	for p in (axes.get("purposes", {}) as Dictionary):
		if kind in (axes["purposes"][p]["kinds"] as Array):
			return p
	return ""


## 난이도 축 — 게임이 실제로 계산하는 인수·명도 부담과 같은 기준 (data/play_axes.json 참고)
func difficulty_of(a: Dictionary) -> String:
	if bool(a.get("tenant_opposing_power", false)) or str(a.get("occupancy", "")) == "유치권신고":
		return "위험"
	if str(a.get("occupancy", "")) == "공실":
		return "안전"
	return "보통"


func region_match(address: String) -> bool:
	if region.is_empty():
		return true
	var toks := address.split(" ")
	for i in region.size():
		if i >= toks.size() or toks[i] != region[i]:
			return false
	return true


func kind_allowed(kind: String) -> bool:
	# usage_taxonomy의 잎 = 물건의 kind 와 같은 이름이라 정확히 일치만 본다
	return kinds.is_empty() or kind in kinds


## 자본금으로 입찰 자체가 불가능한 물건은 빼준다 (최저매각가격도 못 내는 경우)
func affordable(a: Dictionary) -> bool:
	return int(a.get("min_price", 0)) <= capital


func matches(a: Dictionary) -> bool:
	# 실거래 시세를 못 구한 물건은 손익 정산 기준이 없어 제외한다
	return int(a.get("market_price", 0)) > 0 \
		and kind_allowed(str(a.get("kind", ""))) \
		and region_match(str(a.get("address", ""))) \
		and (purpose == "" or purpose_of(a) == purpose) \
		and (difficulty == "" or difficulty_of(a) == difficulty) \
		and affordable(a)


func filter_auctions(auctions: Array) -> Array:
	var out: Array = []
	for a in auctions:
		if matches(a):
			out.append(a)
	return out


## 실제 시장 비율에 가깝게 섞는다 — 지금 데이터는 용도 균등이라 그냥 셔플하면
## 목욕시설이 아파트만큼 나온다. 목적별 목표 비중으로 가중 셔플 (Efraimidis-Spirakis).
func shuffled_for_play(auctions: Array) -> Array:
	var weight: Dictionary = axes.get("market_weight", {})
	var count: Dictionary = {}
	for a in auctions:
		var p := purpose_of(a)
		count[p] = int(count.get(p, 0)) + 1
	var keyed: Array = []
	for a in auctions:
		var p := purpose_of(a)
		var w: float = float(weight.get(p, 1.0)) / maxf(1.0, float(count.get(p, 1)))
		# w가 0이면 절대 안 나오므로 아주 작은 값으로 살려둔다
		keyed.append([pow(randf(), 1.0 / maxf(w, 1e-9)), a])
	keyed.sort_custom(func(x, y) -> bool: return x[0] > y[0])
	var out: Array = []
	for k in keyed:
		out.append(k[1])
	return out if round_size <= 0 else out.slice(0, round_size)
