"""경매 법정 배경 렌더 (1인칭 앞줄 착석 시점, 1920x1080)
사용: blender -b -P art_src/render_courtroom.py -- <출력.png>
실제 법정 사진 기반 재현: 베이지 패널 벽, 천장 매입등 줄, 꿀색 나무 의자 열,
단상 뒤 나무 널판 벽 + 금색 법원 엠블럼 + 태극기, 우측 벽걸이 TV(개찰 중계).
"""
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import blocklib as B  # noqa: E402
import bpy  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "//courtroom.png"

B.reset()

carpet = B.material("carpet", (0.46, 0.45, 0.43), rough=1.0)
beige = B.material("beige_wall", (0.80, 0.76, 0.70), rough=0.95)
beige_dk = B.material("beige_seam", (0.68, 0.64, 0.58), rough=0.95)
ceil_w = B.material("ceil_white", (0.92, 0.92, 0.90), rough=0.95)
lightp = B.material("light_panel", (1.0, 0.98, 0.92), emission=5.0)
honey = B.material("honey_wood", (0.82, 0.60, 0.34), rough=0.6)
honey_dk = B.material("honey_dark", (0.66, 0.46, 0.25), rough=0.6)
slat = B.material("slat_wood", (0.78, 0.57, 0.32), rough=0.7)
gold = B.material("gold_emblem", (0.90, 0.72, 0.34), rough=0.35)
dark = B.material("dark_box", (0.13, 0.13, 0.15), rough=0.7)
screen = B.material("tv_screen", (0.65, 0.78, 0.92), emission=1.6, rough=0.3)
white = B.material("flag_white", (0.97, 0.96, 0.94), rough=0.9)
red = B.material("taeguk_red", (0.80, 0.15, 0.20), rough=0.8)
blue = B.material("taeguk_blue", (0.10, 0.22, 0.55), rough=0.8)

# 바닥(카펫)·벽·천장
B.box((16, 14, 0.2), (0, 0, -0.1), carpet, bevel=0.01)
B.box((16, 0.3, 4), (0, 5.4, 1.7), beige, bevel=0.02)
B.box((0.3, 14, 4), (-6.8, 0, 1.7), beige, bevel=0.02)
B.box((0.3, 14, 4), (6.8, 0, 1.7), beige, bevel=0.02)
B.box((16, 14, 0.2), (0, 0, 3.5), ceil_w, bevel=0.01)

# 벽 패널 세로 이음선
for x in (-5.2, -3.4, -1.6, 1.6, 3.4, 5.2):
    B.box((0.06, 0.05, 3.6), (x, 5.28, 1.7), beige_dk, bevel=0.01)
for y in (-3.5, -1.0, 1.5, 4.0):
    B.box((0.05, 0.06, 3.6), (-6.68, y, 1.7), beige_dk, bevel=0.01)
    B.box((0.05, 0.06, 3.6), (6.68, y, 1.7), beige_dk, bevel=0.01)

# 천장 매입등 (두 줄)
for y in (-2.4, -0.9, 0.6, 2.1, 3.6):
    for x in (-2.6, 0.0, 2.6):
        B.box((1.7, 0.55, 0.06), (x, y, 3.42), lightp, bevel=0.01)

# 단상 뒤 나무 널판 벽
B.box((8.5, 0.22, 2.9), (0, 5.25, 1.45), slat, bevel=0.02)
for x in (-3.4, -2.0, -0.7, 0.7, 2.0, 3.4):
    B.box((0.05, 0.06, 2.7), (x, 5.12, 1.45), honey_dk, bevel=0.01)

# 금색 법원 엠블럼 (널판 벽 상단)
B.cyl(0.42, 0.06, (-1.9, 5.10, 2.5), gold, vertices=48, rot=(math.radians(90), 0, 0))
B.cyl(0.30, 0.08, (-1.9, 5.08, 2.5), B.material("emb_in", (0.95, 0.90, 0.78), rough=0.5), vertices=48, rot=(math.radians(90), 0, 0))
B.cyl(0.12, 0.10, (-1.9, 5.06, 2.5), gold, vertices=48, rot=(math.radians(90), 0, 0))

# 태극기 (단상 우측)
B.cyl(0.035, 3.0, (1.9, 4.85, 1.5), B.material("pole", (0.75, 0.73, 0.70), rough=0.5), vertices=12)
B.ball(0.06, (1.9, 4.85, 3.05), gold)
B.box((0.85, 0.05, 0.55), (2.36, 4.82, 2.70), white, bevel=0.02)
B.ball(0.11, (2.33, 4.77, 2.75), red, scale=(1, 0.4, 1))
B.ball(0.11, (2.40, 4.77, 2.64), blue, scale=(1, 0.4, 1))

# 단상 (연단 + 꿀색 목재)
B.box((7.0, 1.5, 0.35), (0, 3.4, 0.17), honey_dk, bevel=0.04)
B.box((5.6, 1.2, 1.35), (0, 3.3, 0.85), honey, bevel=0.06)
B.box((6.0, 1.4, 0.12), (0, 3.3, 1.58), honey_dk, bevel=0.03)
B.box((4.6, 0.05, 0.16), (0, 2.68, 1.12), gold, bevel=0.02)

# 개찰대 (단상 앞 긴 테이블 — TV 중계에 잡히는 곳)
B.box((3.0, 0.9, 0.06), (0, 1.9, 0.75), honey, bevel=0.02)
B.box((2.8, 0.8, 0.7), (0, 1.9, 0.37), honey_dk, bevel=0.04)
B.box((0.5, 0.35, 0.25), (-0.8, 1.85, 0.9), white, bevel=0.02)   # 입찰함/서류
B.box((0.4, 0.3, 0.12), (0.7, 1.85, 0.84), beige_dk, bevel=0.02)

# 집행관 (단상 뒤)
B.sd_character({"name": "of", "hair": (0.22, 0.19, 0.17), "hair_style": "short",
                "suit": (0.13, 0.15, 0.22), "accessory": "gavel"},
               origin=(0, 3.55, 1.05), char_scale=1.15)

# 벽걸이 TV (정면 우측, 개찰대 중계 화면)
B.box((1.75, 0.12, 1.0), (4.6, 5.05, 2.5), dark, bevel=0.02)
B.box((1.58, 0.10, 0.85), (4.6, 4.98, 2.5), screen, bevel=0.01)
# 좌측 스피커
B.box((0.16, 0.35, 0.5), (-6.6, 2.5, 2.6), dark, bevel=0.02)
B.box((0.16, 0.35, 0.5), (6.6, -2.0, 2.6), dark, bevel=0.02)

# 방청석 의자 열 (꿀색 합판 의자)
def chair(x, y):
    B.box((0.56, 0.5, 0.06), (x, y, 0.46), honey, bevel=0.02)
    B.box((0.56, 0.06, 0.55), (x, y - 0.26, 0.70), honey, bevel=0.02)  # 등받이는 카메라 쪽
    B.box((0.5, 0.44, 0.4), (x, y, 0.22), honey_dk, bevel=0.03)

SEATS = []
for row_y in (0.4, -0.9):
    for cx in (-2.7, -1.5, -0.3, 0.9, 2.1, 3.3):
        chair(cx - 0.3, row_y)
        SEATS.append((cx - 0.3, row_y))

# 방청객 — 같이 개찰을 기다리는 입찰자들 (뒷모습, 좌석의 2/3 채움)
import random
random.seed(11)
HAIRS = [(0.15, 0.13, 0.12), (0.35, 0.24, 0.16), (0.55, 0.42, 0.28),
         (0.78, 0.78, 0.80), (0.10, 0.10, 0.12), (0.45, 0.30, 0.35)]
SUITS = [(0.35, 0.48, 0.70), (0.63, 0.40, 0.42), (0.28, 0.40, 0.32),
         (0.76, 0.53, 0.35), (0.50, 0.50, 0.55), (0.25, 0.28, 0.35), (0.85, 0.80, 0.70)]
STYLES = ["short", "bob", "bun", "cap"]
random.shuffle(SEATS)
for i, (sx, sy) in enumerate(SEATS[:8]):
    B.sd_character({"name": "crowd%d" % i, "hair": random.choice(HAIRS),
                    "hair_style": random.choice(STYLES), "suit": random.choice(SUITS)},
                   origin=(sx, sy + 0.05, 0.34), char_scale=0.78, face_dir=1)

# 내 옆자리 아저씨 (전경, DOF 블러)
B.sd_character({"name": "neighbor", "hair": (0.2, 0.17, 0.15), "hair_style": "cap",
                "suit": (0.30, 0.33, 0.40)}, origin=(-1.7, -3.35, 0.30), char_scale=0.9, face_dir=1)

# 내 앞줄 등받이 (착석 시점 전경 — DOF로 흐려짐)
for cx in (-2.1, -0.9, 0.3, 1.5):
    B.box((1.05, 0.07, 0.45), (cx, -3.45, 0.62), honey, bevel=0.03)

# 카메라: 앞줄 의자에 앉은 눈높이
cam, target = B.camera((0.0, -4.7, 1.28), (0, 3.0, 1.45), lens=24, fstop=2.0)

# 조명: 밝은 실내 (매입등 + 부드러운 키)
bpy.ops.object.light_add(type="AREA", location=(0, 0.5, 3.3))
top = bpy.context.object
top.data.energy = 420
top.data.size = 9
top.data.color = (1.0, 0.97, 0.90)
top.constraints.new("TRACK_TO").target = target

bpy.ops.object.light_add(type="SUN", location=(3, -3, 5))
key = bpy.context.object
key.data.energy = 0.6
key.data.color = (1.0, 0.96, 0.88)
key.data.angle = math.radians(25)
key.constraints.new("TRACK_TO").target = target

bpy.ops.object.light_add(type="AREA", location=(0, -4.5, 2.5))
fill = bpy.context.object
fill.data.energy = 90
fill.data.size = 6
fill.data.color = (0.9, 0.92, 1.0)
fill.constraints.new("TRACK_TO").target = target

B.setup_render(OUT, 1920, 1080, transparent=False, world_color=(0.5, 0.48, 0.45), world_strength=0.28)
bpy.ops.render.render(write_still=True)
print("RENDER DONE:", OUT)
