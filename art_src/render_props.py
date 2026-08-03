"""물건 일러스트 3D 렌더 (Blender headless)
사용: blender -b -P art_src/render_props.py -- <apt|villa|shop|land> <출력.png> [cycles]

블록아웃 모델(베벨로 둥글린 파스텔 박스) + 3점 조명(웜 키 + 골드 림 + 필)
+ 로우앵글 카메라 + DOF + 투명 배경. 스타일: 통통하고 귀여운 SD 건물.
"""
import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
KIND = argv[0] if argv else "apt"
OUT = argv[1] if len(argv) > 1 else f"//render_{KIND}.png"
USE_CYCLES = len(argv) > 2 and argv[2] == "cycles"

# 파스텔 팔레트
COL = {
    "apt_body": (0.70, 0.77, 0.93), "apt_roof": (0.52, 0.60, 0.84),
    "villa_body": (0.96, 0.80, 0.62), "villa_roof": (0.87, 0.48, 0.40),
    "shop_body": (0.92, 0.86, 0.74), "shop_awning": (0.87, 0.48, 0.40),
    "shop_sign": (0.16, 0.20, 0.33),
    "window": (1.00, 0.95, 0.80), "door": (0.48, 0.34, 0.20),
    "ground": (0.70, 0.84, 0.52), "grass_dark": (0.55, 0.74, 0.42),
    "trunk": (0.50, 0.35, 0.20), "leaf": (0.52, 0.79, 0.42),
    "gold": (0.90, 0.74, 0.38), "sign_board": (1.0, 0.97, 0.88),
    "pink": (0.94, 0.55, 0.62),
}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def material(name, color, emission=0.0, rough=0.85):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    if emission > 0:
        b.inputs["Emission Color"].default_value = (*color, 1.0)
        b.inputs["Emission Strength"].default_value = emission
    return m


def box(size, loc, mat, bevel=0.06, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0], size[1], size[2])  # 단위큐브(1m) 기준 → scale = 실제 치수
    mod = o.modifiers.new("bevel", "BEVEL")
    mod.width = bevel
    mod.segments = 4
    o.data.materials.append(mat)
    return o


def cyl(radius, depth, loc, mat, vertices=24, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.data.materials.append(mat)
    return o


def ball(radius, loc, mat, squash=1.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=radius, location=loc)
    o = bpy.context.object
    o.scale.z = squash
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o


def cone4(radius, depth, loc, mat, rot_z=45):
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=radius, depth=depth, location=loc,
                                    rotation=(0, 0, math.radians(rot_z)))
    o = bpy.context.object
    mod = o.modifiers.new("bevel", "BEVEL")
    mod.width = 0.05
    mod.segments = 3
    o.data.materials.append(mat)
    return o


def window_grid(x0, z0, cols, rows, w, h, gap_x, gap_z, y, mat, depth=0.06):
    for c in range(cols):
        for r in range(rows):
            box((w, depth, h), (x0 + c * gap_x, y, z0 + r * gap_z), mat, bevel=0.02)


def tree(x, y, s=1.0):
    cyl(0.09 * s, 0.5 * s, (x, y, 0.25 * s), material("trunk", COL["trunk"]))
    ball(0.42 * s, (x, y, 0.72 * s), material("leaf", COL["leaf"]), squash=0.95)


def ground(radius=3.2):
    cyl(radius, 0.18, (0, 0, -0.09), material("ground", COL["ground"], rough=1.0), vertices=48)
    for gx, gy in [(-1.9, -1.2), (1.7, -1.5), (2.2, 0.6), (-2.3, 0.9)]:
        ball(0.16, (gx, gy, 0.08), material("grass_dark", COL["grass_dark"]), squash=0.6)


win = material("window", COL["window"], emission=0.7, rough=0.4)

if KIND == "apt":
    body = material("apt_body", COL["apt_body"])
    roof = material("apt_roof", COL["apt_roof"])
    box((1.7, 1.2, 4.2), (-0.55, 0, 2.1), body)
    box((1.85, 1.35, 0.28), (-0.55, 0, 4.3), roof)
    box((1.25, 1.0, 3.0), (1.15, 0.75, 1.5), body)
    box((1.4, 1.15, 0.24), (1.15, 0.75, 3.05), roof)
    window_grid(-1.05, 0.85, 3, 5, 0.34, 0.42, 0.5, 0.72, -0.62, win)
    window_grid(0.78, 0.7, 2, 3, 0.3, 0.38, 0.55, 0.8, 0.21, win)
    box((0.5, 0.1, 0.8), (-0.55, -0.62, 0.4), material("door", COL["door"]), bevel=0.03)
    ground()
    tree(-1.9, -0.7, 1.1)
    tree(1.0, -1.6, 0.9)
    cam_loc, cam_z, ortho = (5.2, -6.4, 2.6), 1.9, 7.4

elif KIND == "villa":
    body = material("villa_body", COL["villa_body"])
    box((2.3, 1.5, 2.3), (0, 0, 1.15), body)
    cone4(1.95, 1.3, (0, 0, 2.85), material("villa_roof", COL["villa_roof"]))
    window_grid(-0.62, 1.05, 2, 2, 0.42, 0.4, 1.24, 0.78, -0.78, win)
    box((0.55, 0.1, 0.95), (0, -0.78, 0.48), material("door", COL["door"]), bevel=0.03)
    box((0.7, 0.12, 0.06), (0, -0.85, 0.06), material("gold", COL["gold"]), bevel=0.02)
    ground(2.9)
    tree(-1.75, -0.8, 1.0)
    ball(0.14, (0.95, -0.95, 0.1), material("pink", COL["pink"]))
    ball(0.11, (1.25, -0.75, 0.08), material("gold", COL["gold"]))
    cam_loc, cam_z, ortho = (4.6, -5.8, 2.4), 1.5, 6.0

elif KIND == "shop":
    body = material("shop_body", COL["shop_body"])
    box((3.2, 1.5, 2.0), (0, 0, 1.0), body)
    box((3.0, 0.2, 0.55), (0, -0.72, 2.35), material("shop_sign", COL["shop_sign"]), bevel=0.04)
    box((1.6, 0.1, 0.18), (-0.3, -0.85, 2.35), material("gold", COL["gold"]), bevel=0.02)
    ball(0.12, (1.05, -0.85, 2.35), material("gold", COL["gold"]))
    # 차양 (줄무늬)
    for i in range(6):
        c = COL["shop_awning"] if i % 2 == 0 else (1.0, 0.96, 0.88)
        box((0.48, 0.75, 0.1), (-1.25 + i * 0.5, -0.85, 1.78), material(f"awn{i % 2}", c, rough=0.9),
            bevel=0.02, rot=(math.radians(18), 0, 0))
    box((1.5, 0.1, 1.05), (-0.7, -0.78, 0.62), win, bevel=0.03)
    box((0.6, 0.1, 1.3), (1.05, -0.78, 0.65), material("door", COL["door"]), bevel=0.03)
    ground(3.0)
    tree(-2.2, -0.6, 0.95)
    cam_loc, cam_z, ortho = (4.8, -6.2, 2.3), 1.3, 6.6

else:  # land
    ground(3.2)
    # 필지 울타리
    for i in range(10):
        a = i / 10.0 * 2 * math.pi
        cyl(0.06, 0.5, (1.9 * math.cos(a), 1.9 * math.sin(a), 0.25), material("sign_board", COL["sign_board"]), vertices=10)
    box((1.5, 0.14, 0.9), (0.6, -0.4, 1.5), material("sign_board", COL["sign_board"]), bevel=0.05)
    box((1.2, 0.06, 0.16), (0.6, -0.5, 1.62), material("gold", COL["gold"]), bevel=0.02)
    cyl(0.08, 1.1, (0.6, -0.35, 0.55), material("trunk", COL["trunk"]))
    tree(-1.2, 0.5, 1.25)
    ball(0.14, (-0.4, -1.2, 0.1), material("pink", COL["pink"]))
    ball(0.12, (1.6, 0.9, 0.09), material("gold", COL["gold"]))
    cam_loc, cam_z, ortho = (4.6, -5.6, 3.0), 0.9, 6.4

# ── 카메라 (로우앵글 + DOF) ──────────────────────────────
bpy.ops.object.empty_add(location=(0, 0, cam_z))
target = bpy.context.object
bpy.ops.object.camera_add(location=cam_loc)
cam = bpy.context.object
tr = cam.constraints.new("TRACK_TO")
tr.target = target
cam.data.lens = 42
cam.data.dof.use_dof = True
cam.data.dof.focus_object = target
cam.data.dof.aperture_fstop = 2.8
scene.camera = cam

# ── 3점 조명: 웜 키 + 골드 림 + 필 ───────────────────────
bpy.ops.object.light_add(type="SUN", location=(3, -2, 6))
key = bpy.context.object
key.data.energy = 2.4
key.data.color = (1.0, 0.95, 0.86)
key.data.angle = math.radians(15)
kc = key.constraints.new("TRACK_TO"); kc.target = target

bpy.ops.object.light_add(type="AREA", location=(-4, 4.5, 4.5))
rim = bpy.context.object
rim.data.energy = 900
rim.data.size = 5
rim.data.color = (1.0, 0.82, 0.5)
rc = rim.constraints.new("TRACK_TO"); rc.target = target

bpy.ops.object.light_add(type="AREA", location=(-3.5, -4.5, 2.5))
fill = bpy.context.object
fill.data.energy = 220
fill.data.size = 6
fill.data.color = (0.85, 0.9, 1.0)
fc = fill.constraints.new("TRACK_TO"); fc.target = target

world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.75, 0.9, 1.0)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.5

# ── 렌더 설정 ────────────────────────────────────────────
if USE_CYCLES:
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 128
    scene.cycles.device = "GPU"
else:
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 64
scene.render.resolution_x = 2048
scene.render.resolution_y = 2048
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
try:
    scene.view_settings.view_transform = "Standard"  # 파스텔 채도 유지 (AgX는 물빠짐)
except TypeError:
    pass
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("RENDER DONE:", OUT)
