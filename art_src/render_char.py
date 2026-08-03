"""SD 캐릭터 렌더 (흉상, 투명 배경 1024px)
사용: blender -b -P art_src/render_char.py -- <jiji|bidder1|bidder2|bidder3|bidder4> <출력.png>
"""
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import blocklib as B  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WHO = argv[0] if argv else "jiji"
OUT = argv[1] if len(argv) > 1 else f"//char_{WHO}.png"

CHARS = {
    "jiji":    {"name": "jiji", "hair": (0.35, 0.24, 0.16), "hair_style": "bob", "suit": (0.18, 0.23, 0.38), "accessory": "ribbon"},
    "bidder1": {"name": "b1", "hair": (0.22, 0.32, 0.55), "hair_style": "cap", "suit": (0.35, 0.48, 0.70), "accessory": ""},
    "bidder2": {"name": "b2", "hair": (0.78, 0.78, 0.80), "hair_style": "bun", "suit": (0.63, 0.40, 0.42), "accessory": "glasses"},
    "bidder3": {"name": "b3", "hair": (0.15, 0.13, 0.12), "hair_style": "short", "suit": (0.28, 0.40, 0.32), "accessory": "glasses"},
    "bidder4": {"name": "b4", "hair": (0.52, 0.33, 0.18), "hair_style": "short", "suit": (0.76, 0.53, 0.35), "accessory": ""},
    "officer": {"name": "of", "hair": (0.22, 0.19, 0.17), "hair_style": "short", "suit": (0.13, 0.15, 0.22), "accessory": "gavel"},
}

B.reset()
B.sd_character(CHARS[WHO])
cam, target = B.camera((0.35, -2.5, 1.25), (0, 0, 0.85), lens=55)
B.three_point_lights(target, key_energy=1.7)
B.setup_render(OUT, 1024, 1024, transparent=True)
import bpy  # noqa: E402
bpy.ops.render.render(write_still=True)
print("RENDER DONE:", OUT)
