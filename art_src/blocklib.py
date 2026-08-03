"""Blender 블록아웃 공용 라이브러리 — 귀여운 SD 스타일 (부드러운 파스텔 + 베벨)"""
import math

import bpy


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


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


def box(size, loc, mat, bevel=0.05, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    mod = o.modifiers.new("bevel", "BEVEL")
    mod.width = bevel
    mod.segments = 4
    o.data.materials.append(mat)
    return o


def ball(radius, loc, mat, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=radius, location=loc)
    o = bpy.context.object
    o.scale = scale
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o


def cyl(radius, depth, loc, mat, vertices=24, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.data.materials.append(mat)
    return o


SKIN = (1.0, 0.87, 0.76)
SKIN_BLUSH = (0.98, 0.62, 0.55)
EYE = (0.16, 0.12, 0.10)
MOUTH = (0.75, 0.32, 0.28)


def sd_character(cfg, origin=(0, 0, 0), char_scale=1.0, face_dir=-1):
    """통통한 SD 캐릭터 (흉상). cfg: hair(색), hair_style, suit(색), accessory
    face_dir: -1이면 -Y(카메라 정면)를 봄"""
    ox, oy, oz = origin
    s = char_scale
    fy = face_dir  # 얼굴 요소 y 부호

    def P(x, y, z):
        return (ox + x * s, oy + y * s, oz + z * s)

    skin = material("skin", SKIN, rough=0.7)
    hair = material("hair_%s" % cfg["name"], cfg["hair"], rough=0.75)
    suit = material("suit_%s" % cfg["name"], cfg["suit"], rough=0.9)
    white = material("shirt", (0.98, 0.97, 0.94), rough=0.9)
    eye = material("eye", EYE, rough=0.4)
    hl = material("eye_hl", (1, 1, 1), emission=0.8)
    blush = material("blush", SKIN_BLUSH, rough=1.0)
    mouth = material("mouth", MOUTH, rough=0.8)

    # 몸통 (정장) + 셔츠 + 팔
    box((0.66 * s, 0.44 * s, 0.6 * s), P(0, 0, 0.32), suit, bevel=0.12 * s)
    box((0.16 * s, 0.05 * s, 0.34 * s), P(0, fy * 0.225, 0.42), white, bevel=0.03 * s)
    ball(0.13 * s, P(-0.38, 0, 0.42), suit)
    ball(0.13 * s, P(0.38, 0, 0.42), suit)

    # 머리
    ball(0.5 * s, P(0, 0, 1.02), skin, scale=(1, 0.95, 0.95))

    # 헤어
    style = cfg.get("hair_style", "bob")
    if style == "bob":
        ball(0.54 * s, P(0, fy * -0.07, 1.10), hair, scale=(1, 0.95, 0.9))
        ball(0.16 * s, P(-0.44, fy * -0.02, 0.86), hair, scale=(0.7, 0.8, 1.4))
        ball(0.16 * s, P(0.44, fy * -0.02, 0.86), hair, scale=(0.7, 0.8, 1.4))
    elif style == "short":
        ball(0.53 * s, P(0, fy * -0.09, 1.13), hair, scale=(1, 0.9, 0.82))
    elif style == "bun":
        ball(0.53 * s, P(0, fy * -0.08, 1.11), hair, scale=(1, 0.92, 0.85))
        ball(0.17 * s, P(0, fy * -0.38, 1.42), hair)
    elif style == "cap":
        ball(0.53 * s, P(0, fy * -0.06, 1.14), hair, scale=(1, 0.95, 0.8))
        cyl(0.56 * s, 0.05 * s, P(0, fy * 0.18, 1.13), hair, rot=(math.radians(8 * fy), 0, 0))

    # 눈 + 하이라이트 + 볼터치 + 입
    for sx in (-1, 1):
        ball(0.055 * s, P(sx * 0.17, fy * 0.42, 1.06), eye, scale=(1, 0.6, 1.3))
        ball(0.018 * s, P(sx * 0.17 + 0.02, fy * 0.46, 1.10), hl)
        ball(0.06 * s, P(sx * 0.31, fy * 0.36, 0.94), blush, scale=(1, 0.5, 0.65))
    ball(0.045 * s, P(0, fy * 0.45, 0.90), mouth, scale=(1.5, 0.5, 0.7))

    # 액세서리
    acc = cfg.get("accessory", "")
    if acc == "glasses":
        dark = material("glass_rim", (0.25, 0.22, 0.2), rough=0.5)
        for sx in (-1, 1):
            o = cyl(0.11 * s, 0.02 * s, P(sx * 0.17, fy * 0.44, 1.06), dark, rot=(math.radians(90), 0, 0))
            o.scale.x = 1.0
        box((0.1 * s, 0.02 * s, 0.02 * s), P(0, fy * 0.44, 1.06), dark, bevel=0.005)
    elif acc == "gavel":
        wood = material("gavel_wood", (0.55, 0.36, 0.2), rough=0.7)
        cyl(0.035 * s, 0.5 * s, P(0.55, 0, 0.75), wood, rot=(0, math.radians(15), 0))
        cyl(0.11 * s, 0.3 * s, P(0.62, 0, 0.98), wood, rot=(math.radians(90), 0, 0))
    elif acc == "ribbon":
        rb = material("ribbon", (0.85, 0.31, 0.42), rough=0.8)
        ball(0.05 * s, P(0, fy * 0.23, 0.56), rb)
        ball(0.07 * s, P(-0.09, fy * 0.22, 0.57), rb, scale=(1.2, 0.5, 0.8))
        ball(0.07 * s, P(0.09, fy * 0.22, 0.57), rb, scale=(1.2, 0.5, 0.8))


def three_point_lights(target, key_energy=2.4):
    bpy.ops.object.light_add(type="SUN", location=(3, -2, 6))
    key = bpy.context.object
    key.data.energy = key_energy
    key.data.color = (1.0, 0.95, 0.86)
    key.data.angle = math.radians(15)
    key.constraints.new("TRACK_TO").target = target

    bpy.ops.object.light_add(type="AREA", location=(-4, 4.5, 4.5))
    rim = bpy.context.object
    rim.data.energy = 900
    rim.data.size = 5
    rim.data.color = (1.0, 0.82, 0.5)
    rim.constraints.new("TRACK_TO").target = target

    bpy.ops.object.light_add(type="AREA", location=(-3.5, -4.5, 2.5))
    fill = bpy.context.object
    fill.data.energy = 220
    fill.data.size = 6
    fill.data.color = (0.85, 0.9, 1.0)
    fill.constraints.new("TRACK_TO").target = target


def setup_render(out, res_x=2048, res_y=2048, transparent=True, world_color=(0.7, 0.75, 0.9), world_strength=0.5):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (*world_color, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = world_strength
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 64
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.film_transparent = transparent
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    scene.render.filepath = out


def camera(loc, target_loc, lens=42, fstop=0.0):
    bpy.ops.object.empty_add(location=target_loc)
    target = bpy.context.object
    bpy.ops.object.camera_add(location=loc)
    cam = bpy.context.object
    cam.constraints.new("TRACK_TO").target = target
    cam.data.lens = lens
    if fstop > 0:
        cam.data.dof.use_dof = True
        cam.data.dof.focus_object = target
        cam.data.dof.aperture_fstop = fstop
    bpy.context.scene.camera = cam
    return cam, target
