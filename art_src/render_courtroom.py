"""경매 법정 배경 렌더 (1인칭 시점, 1920x1080)
사용: blender -b -P art_src/render_courtroom.py -- <출력.png>
구도: 입찰자석에 앉아 집행관 단상을 올려다보는 시점. 좌우 책상에 경쟁 입찰자.
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

wood_floor = B.material("wood_floor", (0.52, 0.38, 0.24), rough=0.6)
wood_wall = B.material("wood_wall", (0.70, 0.57, 0.42), rough=0.85)
wood_dark = B.material("wood_dark", (0.40, 0.27, 0.16), rough=0.7)
wood_bench = B.material("wood_bench", (0.46, 0.31, 0.18), rough=0.65)
gold = B.material("gold_trim", (0.88, 0.70, 0.34), rough=0.35)
cream = B.material("cream", (0.97, 0.93, 0.82), rough=0.9)
ceilmat = B.material("ceil", (0.30, 0.25, 0.21), rough=0.95)
lampmat = B.material("lamp", (1.0, 0.88, 0.6), emission=6.0)

# 바닥·벽·천장
B.box((16, 16, 0.2), (0, 0, -0.1), wood_floor, bevel=0.01)
B.box((16, 0.3, 7), (0, 5.2, 3.0), wood_wall, bevel=0.02)
B.box((16, 0.34, 1.4), (0, 5.18, 0.7), wood_dark, bevel=0.02)   # 하부 웨인스코팅
B.box((0.3, 16, 7), (-7.5, 0, 3.0), wood_dark, bevel=0.02)
B.box((0.3, 16, 7), (7.5, 0, 3.0), wood_dark, bevel=0.02)
B.box((16, 16, 0.3), (0, 0, 5.6), ceilmat, bevel=0.01)

# 벽 패널 세로 줄
for x in (-5.4, -3.2, 3.2, 5.4):
    B.box((0.18, 0.1, 4.2), (x, 5.05, 2.9), wood_dark, bevel=0.02)

# 금색 엠블럼 (단상 위 벽)
B.cyl(0.62, 0.07, (0, 5.02, 3.7), gold, vertices=48, rot=(math.radians(90), 0, 0))
B.cyl(0.48, 0.09, (0, 5.0, 3.7), cream, vertices=48, rot=(math.radians(90), 0, 0))
B.cyl(0.2, 0.11, (0, 4.98, 3.7), gold, vertices=48, rot=(math.radians(90), 0, 0))

# 집행관 단상 (연단)
B.box((6.2, 1.6, 1.0), (0, 3.0, 0.5), wood_dark, bevel=0.06)
B.box((5.2, 1.3, 1.6), (0, 2.7, 0.8), wood_bench, bevel=0.08)
B.box((5.6, 1.5, 0.16), (0, 2.7, 1.68), wood_dark, bevel=0.04)
B.box((4.6, 0.06, 0.2), (0, 2.02, 1.15), gold, bevel=0.02)      # 금색 트림
# 단상 위 명패 + 의사봉 받침
B.box((0.9, 0.08, 0.28), (-1.4, 2.1, 1.9), cream, bevel=0.02)
B.cyl(0.16, 0.06, (1.3, 2.35, 1.79), wood_dark, vertices=32)

# 집행관 캐릭터 (단상 뒤)
B.sd_character({"name": "of", "hair": (0.22, 0.19, 0.17), "hair_style": "short",
                "suit": (0.13, 0.15, 0.22), "accessory": "gavel"},
               origin=(0, 3.1, 1.3), char_scale=1.15)

# 좌우 입찰자 책상 + 경쟁 입찰자
B.box((2.0, 1.0, 0.95), (-2.9, 0.2, 0.48), wood_bench, bevel=0.06)
B.box((2.0, 1.0, 0.95), (2.9, 0.2, 0.48), wood_bench, bevel=0.06)
B.sd_character({"name": "b1", "hair": (0.22, 0.32, 0.55), "hair_style": "cap",
                "suit": (0.35, 0.48, 0.70), "accessory": ""},
               origin=(-2.85, 0.85, 0.42), char_scale=0.92)
B.sd_character({"name": "b2", "hair": (0.78, 0.78, 0.80), "hair_style": "bun",
                "suit": (0.63, 0.40, 0.42), "accessory": "glasses"},
               origin=(2.85, 0.85, 0.42), char_scale=0.92)

# 전경 난간 (DOF로 흐려질 요소)
B.box((9, 0.16, 0.12), (0, -3.0, 0.98), wood_dark, bevel=0.04)
for x in (-3.4, -1.2, 1.2, 3.4):
    B.cyl(0.06, 0.9, (x, -3.0, 0.5), wood_dark, vertices=12)

# 천장 랜턴 조명
for x in (-3.0, 3.0):
    B.cyl(0.03, 1.0, (x, 1.2, 5.0), wood_dark, vertices=8)
    B.ball(0.22, (x, 1.2, 4.4), lampmat)

# 카메라: 입찰자석 1인칭, 단상을 올려다봄
cam, target = B.camera((0.0, -4.6, 1.3), (0, 2.6, 1.8), lens=30, fstop=2.0)

# 조명
B.three_point_lights(target, key_energy=1.6)
bpy.ops.object.light_add(type="AREA", location=(0, 0.5, 5.2))
top = bpy.context.object
top.data.energy = 600
top.data.size = 7
top.data.color = (1.0, 0.9, 0.72)
top.constraints.new("TRACK_TO").target = target

B.setup_render(OUT, 1920, 1080, transparent=False, world_color=(0.05, 0.045, 0.06), world_strength=1.0)
bpy.ops.render.render(write_still=True)
print("RENDER DONE:", OUT)
