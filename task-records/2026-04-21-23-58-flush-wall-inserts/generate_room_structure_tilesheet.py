from pathlib import Path

from PIL import Image, ImageDraw


CELL_W = 128
CELL_H = 160
COLS = 4
ROWS = 4
SHEET_W = CELL_W * COLS
SHEET_H = CELL_H * ROWS
BASE_CENTER_X = CELL_W // 2
BASE_TOP_Y = 90
HALF_W = 64
HALF_H = 32
BASE_CENTER_Y = BASE_TOP_Y + HALF_H
BASE_BOTTOM_Y = BASE_CENTER_Y + HALF_H
WALL_H = 68

OUT = Path("assets/tiles/interiors/room_structure_tilesheet.png")
OUT.parent.mkdir(parents=True, exist_ok=True)


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_color.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


P = {
    "outline": rgba("#17202D", 235),
    "shadow": rgba("#10151D", 64),
    "floor_a": rgba("#6B5B53"),
    "floor_b": rgba("#806E63"),
    "wall_left": rgba("#9C8D83"),
    "wall_right": rgba("#85756B"),
    "wall_top": rgba("#B5A79D"),
    "trim": rgba("#4B403B"),
    "trim_dark": rgba("#352D29"),
    "window_glass": rgba("#8FB8D8", 210),
    "window_hi": rgba("#CAE4F2", 180),
    "door": rgba("#66472F"),
    "door_panel": rgba("#80583B"),
    "counter_top": rgba("#D4C6B2"),
    "counter_left": rgba("#8A7A67"),
    "counter_right": rgba("#736453"),
    "rug_main": rgba("#9E4B4E"),
    "rug_trim": rgba("#D2BC75"),
    "table_top": rgba("#7F5A3C"),
    "table_side": rgba("#654630"),
    "table_leg": rgba("#463223"),
    "frame": rgba("#CBA66B"),
    "art": rgba("#4E6E8A"),
    "pot": rgba("#7A5447"),
    "leaf_dark": rgba("#406D46"),
    "leaf_light": rgba("#5A955E"),
}


img = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))


def offset(points, ox, oy):
    return [(int(round(x + ox)), int(round(y + oy))) for x, y in points]


def draw_poly(draw, pts, fill, outline=P["outline"]):
    draw.polygon(pts, fill=fill, outline=outline)


def quad_from_lerp(quad, top_start, top_end, bottom_end, bottom_start):
    a, b, c, d = quad

    def lerp(p1, p2, t):
        return (p1[0] + (p2[0] - p1[0]) * t, p1[1] + (p2[1] - p1[1]) * t)

    return [
        lerp(a, b, top_start),
        lerp(a, b, top_end),
        lerp(d, c, bottom_end),
        lerp(d, c, bottom_start),
    ]


def inset_quad(quad, inset_top, inset_side, inset_bottom):
    return quad_from_lerp(
        quad,
        inset_side,
        1.0 - inset_side,
        1.0 - inset_side - inset_bottom,
        inset_side + inset_bottom,
    )


def base_points():
    return [
        (BASE_CENTER_X, BASE_TOP_Y),
        (BASE_CENTER_X + HALF_W, BASE_CENTER_Y),
        (BASE_CENTER_X, BASE_BOTTOM_Y),
        (BASE_CENTER_X - HALF_W, BASE_CENTER_Y),
    ]


def left_wall_face():
    return [
        (BASE_CENTER_X - HALF_W, BASE_CENTER_Y - WALL_H),
        (BASE_CENTER_X, BASE_TOP_Y - WALL_H),
        (BASE_CENTER_X, BASE_TOP_Y),
        (BASE_CENTER_X - HALF_W, BASE_CENTER_Y),
    ]


def right_wall_face():
    return [
        (BASE_CENTER_X, BASE_TOP_Y - WALL_H),
        (BASE_CENTER_X + HALF_W, BASE_CENTER_Y - WALL_H),
        (BASE_CENTER_X + HALF_W, BASE_CENTER_Y),
        (BASE_CENTER_X, BASE_TOP_Y),
    ]


def draw_base_floor(draw, ox, oy, alt=False):
    pts = offset(base_points(), ox, oy)
    shadow = [(x, y + 4) for x, y in pts]
    draw_poly(draw, shadow, P["shadow"], None)
    draw_poly(draw, pts, P["floor_b" if alt else "floor_a"])
    draw.line([pts[3], pts[0], pts[1], pts[2], pts[3]], fill=P["outline"], width=2)


def draw_left_face_insert(draw, ox, oy, variant):
    face = left_wall_face()
    panel = inset_quad(face, 0.26, 0.22, 0.16)
    panel_pts = offset(panel, ox, oy)

    if variant == "window":
        frame_pts = offset(inset_quad(face, 0.23, 0.18, 0.12), ox, oy)
        glass_pts = offset(inset_quad(face, 0.29, 0.24, 0.18), ox, oy)
        draw_poly(draw, frame_pts, P["trim"])
        draw_poly(draw, glass_pts, P["window_glass"], P["trim_dark"])
        draw.line([glass_pts[0], glass_pts[2]], fill=P["window_hi"], width=2)
    elif variant == "door":
        jamb_pts = offset(quad_from_lerp(face, 0.56, 0.94, 0.92, 0.58), ox, oy)
        door_pts = offset(quad_from_lerp(face, 0.60, 0.90, 0.88, 0.62), ox, oy)
        draw_poly(draw, jamb_pts, P["trim"])
        draw_poly(draw, door_pts, P["door"], P["trim_dark"])
        panel = offset(quad_from_lerp(face, 0.66, 0.84, 0.80, 0.68), ox, oy)
        draw_poly(draw, panel, P["door_panel"], None)
        knob = (door_pts[1][0] - 7, door_pts[2][1] - 16)
        draw.ellipse([knob[0] - 2, knob[1] - 2, knob[0] + 2, knob[1] + 2], fill=P["frame"], outline=P["trim_dark"])
    elif variant == "picture":
        frame_pts = offset(inset_quad(face, 0.22, 0.28, 0.34), ox, oy)
        art_pts = offset(inset_quad(face, 0.27, 0.33, 0.39), ox, oy)
        draw_poly(draw, frame_pts, P["frame"], P["trim"])
        draw_poly(draw, art_pts, P["art"], None)
    else:
        draw_poly(draw, panel_pts, P["wall_left"], None)


def draw_right_face_insert(draw, ox, oy, variant):
    face = right_wall_face()
    panel = inset_quad(face, 0.26, 0.22, 0.16)
    panel_pts = offset(panel, ox, oy)

    if variant == "window":
        frame_pts = offset(inset_quad(face, 0.23, 0.18, 0.12), ox, oy)
        glass_pts = offset(inset_quad(face, 0.29, 0.24, 0.18), ox, oy)
        draw_poly(draw, frame_pts, P["trim"])
        draw_poly(draw, glass_pts, P["window_glass"], P["trim_dark"])
        draw.line([glass_pts[1], glass_pts[3]], fill=P["window_hi"], width=2)
    elif variant == "door":
        jamb_pts = offset(quad_from_lerp(face, 0.06, 0.44, 0.42, 0.08), ox, oy)
        door_pts = offset(quad_from_lerp(face, 0.10, 0.40, 0.38, 0.12), ox, oy)
        draw_poly(draw, jamb_pts, P["trim"])
        draw_poly(draw, door_pts, P["door_panel"], P["trim_dark"])
        panel = offset(quad_from_lerp(face, 0.16, 0.34, 0.32, 0.18), ox, oy)
        draw_poly(draw, panel, P["door"], None)
        knob = (door_pts[0][0] + 7, door_pts[3][1] - 16)
        draw.ellipse([knob[0] - 2, knob[1] - 2, knob[0] + 2, knob[1] + 2], fill=P["frame"], outline=P["trim_dark"])
    elif variant == "picture":
        frame_pts = offset(inset_quad(face, 0.22, 0.28, 0.34), ox, oy)
        art_pts = offset(inset_quad(face, 0.27, 0.33, 0.39), ox, oy)
        draw_poly(draw, frame_pts, P["frame"], P["trim"])
        draw_poly(draw, art_pts, P["art"], None)
    else:
        draw_poly(draw, panel_pts, P["wall_right"], None)


def draw_upper_left_wall(draw, ox, oy, variant="plain"):
    face = left_wall_face()
    cap = [
        (BASE_CENTER_X - HALF_W, BASE_CENTER_Y - WALL_H),
        (BASE_CENTER_X, BASE_TOP_Y - WALL_H),
        (BASE_CENTER_X - 6, BASE_TOP_Y - WALL_H - 10),
        (BASE_CENTER_X - HALF_W - 6, BASE_CENTER_Y - WALL_H - 6),
    ]
    draw_poly(draw, offset(face, ox, oy), P["wall_left"])
    draw_poly(draw, offset(cap, ox, oy), P["wall_top"])
    draw.line(offset([(BASE_CENTER_X - HALF_W + 6, BASE_CENTER_Y - 6), (BASE_CENTER_X - 2, BASE_TOP_Y + 6)], ox, oy), fill=P["trim"], width=3)
    if variant != "plain":
        draw_left_face_insert(draw, ox, oy, variant)


def draw_upper_right_wall(draw, ox, oy, variant="plain"):
    face = right_wall_face()
    cap = [
        (BASE_CENTER_X, BASE_TOP_Y - WALL_H),
        (BASE_CENTER_X + HALF_W, BASE_CENTER_Y - WALL_H),
        (BASE_CENTER_X + HALF_W + 6, BASE_CENTER_Y - WALL_H - 6),
        (BASE_CENTER_X + 6, BASE_TOP_Y - WALL_H - 10),
    ]
    draw_poly(draw, offset(face, ox, oy), P["wall_right"])
    draw_poly(draw, offset(cap, ox, oy), P["wall_top"])
    draw.line(offset([(BASE_CENTER_X + 2, BASE_TOP_Y + 6), (BASE_CENTER_X + HALF_W - 6, BASE_CENTER_Y - 6)], ox, oy), fill=P["trim"], width=3)
    if variant != "plain":
        draw_right_face_insert(draw, ox, oy, variant)


def draw_corner_wall(draw, ox, oy):
    draw_upper_left_wall(draw, ox, oy, "plain")
    draw_upper_right_wall(draw, ox, oy, "plain")
    pillar = offset(
        [
            (BASE_CENTER_X - 6, BASE_TOP_Y - WALL_H - 14),
            (BASE_CENTER_X + 6, BASE_TOP_Y - WALL_H - 8),
            (BASE_CENTER_X + 6, BASE_TOP_Y + 4),
            (BASE_CENTER_X - 6, BASE_TOP_Y - 2),
        ],
        ox,
        oy,
    )
    draw_poly(draw, pillar, P["wall_top"])


def draw_rug(draw, ox, oy, accent=False):
    outer = offset(
        [
            (BASE_CENTER_X, BASE_TOP_Y + 10),
            (BASE_CENTER_X + (36 if accent else 48), BASE_CENTER_Y),
            (BASE_CENTER_X, BASE_BOTTOM_Y - 10),
            (BASE_CENTER_X - (36 if accent else 48), BASE_CENTER_Y),
        ],
        ox,
        oy,
    )
    inner = offset(
        [
            (BASE_CENTER_X, BASE_TOP_Y + 16),
            (BASE_CENTER_X + (28 if accent else 40), BASE_CENTER_Y),
            (BASE_CENTER_X, BASE_BOTTOM_Y - 16),
            (BASE_CENTER_X - (28 if accent else 40), BASE_CENTER_Y),
        ],
        ox,
        oy,
    )
    main = rgba("#5D6C85") if accent else P["rug_main"]
    draw_poly(draw, outer, P["rug_trim"])
    draw_poly(draw, inner, main, P["rug_trim"])
    draw.line([inner[3], inner[1]], fill=P["rug_trim"], width=2)
    draw.line([inner[0], inner[2]], fill=P["rug_trim"], width=2)


def draw_table(draw, ox, oy, small=False):
    top_w = 28 if small else 42
    top_h = 14 if small else 18
    top_y = BASE_CENTER_Y - 18
    top = offset(
        [
            (BASE_CENTER_X, top_y - top_h),
            (BASE_CENTER_X + top_w, top_y),
            (BASE_CENTER_X, top_y + top_h),
            (BASE_CENTER_X - top_w, top_y),
        ],
        ox,
        oy,
    )
    left = offset(
        [
            (BASE_CENTER_X - top_w, top_y),
            (BASE_CENTER_X, top_y + top_h),
            (BASE_CENTER_X, top_y + top_h + 12),
            (BASE_CENTER_X - top_w, top_y + 12),
        ],
        ox,
        oy,
    )
    right = offset(
        [
            (BASE_CENTER_X, top_y + top_h),
            (BASE_CENTER_X + top_w, top_y),
            (BASE_CENTER_X + top_w, top_y + 12),
            (BASE_CENTER_X, top_y + top_h + 12),
        ],
        ox,
        oy,
    )
    draw_poly(draw, left, P["table_side"])
    draw_poly(draw, right, P["table_leg"])
    draw_poly(draw, top, P["table_top"])
    legs = [(-top_w + 6, top_y + 12), (top_w - 6, top_y + 12), (0, top_y + top_h + 10)]
    for lx, ly in legs:
        draw.line(offset([(BASE_CENTER_X + lx, ly), (BASE_CENTER_X + lx, ly + (18 if not small else 10))], ox, oy), fill=P["table_leg"], width=3)


def draw_counter(draw, ox, oy, corner=False):
    if corner:
        top = offset([(BASE_CENTER_X - 40, BASE_CENTER_Y - 20), (BASE_CENTER_X + 16, BASE_CENTER_Y - 4), (BASE_CENTER_X + 16, BASE_CENTER_Y + 20), (BASE_CENTER_X - 40, BASE_CENTER_Y + 4)], ox, oy)
        left = offset([(BASE_CENTER_X - 40, BASE_CENTER_Y - 20), (BASE_CENTER_X - 8, BASE_CENTER_Y - 10), (BASE_CENTER_X - 8, BASE_CENTER_Y + 16), (BASE_CENTER_X - 40, BASE_CENTER_Y + 4)], ox, oy)
        right = offset([(BASE_CENTER_X - 8, BASE_CENTER_Y - 10), (BASE_CENTER_X + 16, BASE_CENTER_Y - 4), (BASE_CENTER_X + 16, BASE_CENTER_Y + 20), (BASE_CENTER_X - 8, BASE_CENTER_Y + 16)], ox, oy)
    else:
        top = offset([(BASE_CENTER_X, BASE_CENTER_Y - 22), (BASE_CENTER_X + 36, BASE_CENTER_Y - 10), (BASE_CENTER_X, BASE_CENTER_Y + 2), (BASE_CENTER_X - 36, BASE_CENTER_Y - 10)], ox, oy)
        left = offset([(BASE_CENTER_X - 36, BASE_CENTER_Y - 10), (BASE_CENTER_X, BASE_CENTER_Y + 2), (BASE_CENTER_X, BASE_CENTER_Y + 26), (BASE_CENTER_X - 36, BASE_CENTER_Y + 14)], ox, oy)
        right = offset([(BASE_CENTER_X, BASE_CENTER_Y + 2), (BASE_CENTER_X + 36, BASE_CENTER_Y - 10), (BASE_CENTER_X + 36, BASE_CENTER_Y + 14), (BASE_CENTER_X, BASE_CENTER_Y + 26)], ox, oy)
    draw_poly(draw, left, P["counter_left"])
    draw_poly(draw, right, P["counter_right"])
    draw_poly(draw, top, P["counter_top"])
    for index in range(2):
        x = ox + BASE_CENTER_X - 18 + index * 18
        draw.line([(x, oy + BASE_CENTER_Y + 8), (x, oy + BASE_CENTER_Y + 24)], fill=P["trim"], width=2)


def draw_plant(draw, ox, oy):
    pot_top = offset([(BASE_CENTER_X, BASE_CENTER_Y - 10), (BASE_CENTER_X + 14, BASE_CENTER_Y - 6), (BASE_CENTER_X, BASE_CENTER_Y - 2), (BASE_CENTER_X - 14, BASE_CENTER_Y - 6)], ox, oy)
    pot_left = offset([(BASE_CENTER_X - 14, BASE_CENTER_Y - 6), (BASE_CENTER_X, BASE_CENTER_Y - 2), (BASE_CENTER_X, BASE_CENTER_Y + 16), (BASE_CENTER_X - 12, BASE_CENTER_Y + 12)], ox, oy)
    pot_right = offset([(BASE_CENTER_X, BASE_CENTER_Y - 2), (BASE_CENTER_X + 14, BASE_CENTER_Y - 6), (BASE_CENTER_X + 12, BASE_CENTER_Y + 12), (BASE_CENTER_X, BASE_CENTER_Y + 16)], ox, oy)
    draw_poly(draw, pot_left, P["pot"])
    draw_poly(draw, pot_right, rgba("#624238"))
    draw_poly(draw, pot_top, rgba("#926556"))
    stems = [
        ((BASE_CENTER_X, BASE_CENTER_Y - 4), (BASE_CENTER_X - 16, BASE_CENTER_Y - 46)),
        ((BASE_CENTER_X, BASE_CENTER_Y - 6), (BASE_CENTER_X + 18, BASE_CENTER_Y - 50)),
        ((BASE_CENTER_X, BASE_CENTER_Y - 8), (BASE_CENTER_X, BASE_CENTER_Y - 58)),
    ]
    for start, end in stems:
        draw.line(offset([start, end], ox, oy), fill=P["leaf_dark"], width=3)
    leaves = [
        [(BASE_CENTER_X - 22, BASE_CENTER_Y - 52), (BASE_CENTER_X - 8, BASE_CENTER_Y - 44), (BASE_CENTER_X - 18, BASE_CENTER_Y - 30)],
        [(BASE_CENTER_X + 24, BASE_CENTER_Y - 54), (BASE_CENTER_X + 6, BASE_CENTER_Y - 44), (BASE_CENTER_X + 18, BASE_CENTER_Y - 28)],
        [(BASE_CENTER_X, BASE_CENTER_Y - 64), (BASE_CENTER_X + 12, BASE_CENTER_Y - 46), (BASE_CENTER_X - 12, BASE_CENTER_Y - 46)],
        [(BASE_CENTER_X - 10, BASE_CENTER_Y - 38), (BASE_CENTER_X - 30, BASE_CENTER_Y - 26), (BASE_CENTER_X - 10, BASE_CENTER_Y - 18)],
        [(BASE_CENTER_X + 10, BASE_CENTER_Y - 40), (BASE_CENTER_X + 30, BASE_CENTER_Y - 28), (BASE_CENTER_X + 12, BASE_CENTER_Y - 16)],
    ]
    for index, leaf in enumerate(leaves):
        draw_poly(draw, offset(leaf, ox, oy), P["leaf_light"] if index % 2 == 0 else P["leaf_dark"])


def render_tile(index: int, drawer, alt=False):
    ox = (index % COLS) * CELL_W
    oy = (index // COLS) * CELL_H
    draw = ImageDraw.Draw(img)
    draw_base_floor(draw, ox, oy, alt=alt)
    drawer(draw, ox, oy)


render_tile(0, lambda d, ox, oy: draw_upper_left_wall(d, ox, oy, "plain"))
render_tile(1, lambda d, ox, oy: draw_upper_left_wall(d, ox, oy, "window"), alt=True)
render_tile(2, lambda d, ox, oy: draw_upper_left_wall(d, ox, oy, "door"))
render_tile(3, lambda d, ox, oy: draw_upper_left_wall(d, ox, oy, "picture"), alt=True)
render_tile(4, lambda d, ox, oy: draw_upper_right_wall(d, ox, oy, "plain"), alt=True)
render_tile(5, lambda d, ox, oy: draw_upper_right_wall(d, ox, oy, "window"))
render_tile(6, lambda d, ox, oy: draw_upper_right_wall(d, ox, oy, "door"), alt=True)
render_tile(7, lambda d, ox, oy: draw_upper_right_wall(d, ox, oy, "picture"))
render_tile(8, lambda d, ox, oy: draw_corner_wall(d, ox, oy))
render_tile(9, lambda d, ox, oy: draw_counter(d, ox, oy, False), alt=True)
render_tile(10, lambda d, ox, oy: draw_rug(d, ox, oy, accent=False))
render_tile(11, lambda d, ox, oy: draw_table(d, ox, oy, False), alt=True)
render_tile(12, lambda d, ox, oy: draw_plant(d, ox, oy))
render_tile(13, lambda d, ox, oy: draw_counter(d, ox, oy, True), alt=True)
render_tile(14, lambda d, ox, oy: draw_table(d, ox, oy, True))
render_tile(15, lambda d, ox, oy: draw_rug(d, ox, oy, accent=True), alt=True)

img.save(OUT)
print(OUT)
print(f"{SHEET_W}x{SHEET_H}")
