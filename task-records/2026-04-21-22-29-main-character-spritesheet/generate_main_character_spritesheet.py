from pathlib import Path

from PIL import Image, ImageDraw


# Historical task-record recreation of the Pillow generator for this asset.
FRAME_W = 96
FRAME_H = 96
COLS = 3
ROWS = 4
SHEET_W = FRAME_W * COLS
SHEET_H = FRAME_H * ROWS

OUT = Path("assets/characters/main_character/main_character_walk_spritesheet.png")
OUT.parent.mkdir(parents=True, exist_ok=True)


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_color.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


P = {
    "outline": rgba("#1B1F2A", 235),
    "shadow": rgba("#0F1420", 120),
    "shadow_hi": rgba("#2A3145", 96),
    "hair": rgba("#3A2A24"),
    "skin": rgba("#E8B79F"),
    "hoodie": rgba("#7F8BA9"),
    "hoodie_dark": rgba("#67728E"),
    "shirt": rgba("#D8685C"),
    "pants": rgba("#2E344A"),
    "pants_dark": rgba("#24293A"),
    "shoe": rgba("#EEF2FF"),
    "shoe_dark": rgba("#9AA4C6"),
}

img = Image.new("RGBA", (SHEET_W, SHEET_H), (0, 0, 0, 0))


def translate(points, ox, oy):
    return [(int(round(x + ox)), int(round(y + oy))) for x, y in points]


def draw_poly(draw, pts, fill, outline=P["outline"]):
    draw.polygon(pts, fill=fill, outline=outline)


def diamond(cx, cy, half_w, half_h):
    return [(cx, cy - half_h), (cx + half_w, cy), (cx, cy + half_h), (cx - half_w, cy)]


def draw_arm(draw, shoulder_x, shoulder_y, hand_x, hand_y, sleeve_color):
    upper = [(shoulder_x - 3, shoulder_y - 1), (shoulder_x + 3, shoulder_y + 1), (hand_x + 2, hand_y - 7), (hand_x - 4, hand_y - 8)]
    lower = [(hand_x - 4, hand_y - 8), (hand_x + 2, hand_y - 7), (hand_x + 4, hand_y - 1), (hand_x - 2, hand_y)]
    draw_poly(draw, upper, sleeve_color)
    draw_poly(draw, lower, sleeve_color)
    draw.ellipse((hand_x - 4, hand_y - 4, hand_x + 4, hand_y + 4), fill=P["skin"], outline=P["outline"])


def draw_leg(draw, hip_x, hip_y, foot_x, foot_y, front_leg):
    knee_x = (hip_x + foot_x) // 2
    knee_y = (hip_y + foot_y) // 2 - 2
    thigh = [(hip_x - 3, hip_y), (hip_x + 3, hip_y), (knee_x + 2, knee_y + 3), (knee_x - 2, knee_y + 3)]
    shin = [(knee_x - 2, knee_y + 1), (knee_x + 2, knee_y + 1), (foot_x + 3, foot_y - 3), (foot_x - 3, foot_y - 3)]
    draw_poly(draw, thigh, P["pants"] if front_leg else P["pants_dark"])
    draw_poly(draw, shin, P["pants"] if front_leg else P["pants_dark"])
    shoe = [
        (foot_x - 7, foot_y - 1),
        (foot_x + 4, foot_y - 3),
        (foot_x + 8, foot_y + 1),
        (foot_x - 3, foot_y + 3),
    ]
    draw_poly(draw, shoe, P["shoe"] if front_leg else P["shoe_dark"])


def draw_frame(draw, ox, oy, facing_index, frame_index):
    mirror = 1 if facing_index in (0, 3) else -1
    back_view = facing_index in (2, 3)
    stride = (-1, 0, 1)[frame_index]
    bob = (1, 0, 2)[frame_index]

    cx = ox + FRAME_W // 2
    ground_y = oy + 78 + bob
    shadow_pts = diamond(cx, ground_y + 6, 16, 5)
    inner_shadow = diamond(cx, ground_y + 6, 9, 3)
    draw_poly(draw, shadow_pts, P["shadow"], None)
    draw_poly(draw, inner_shadow, P["shadow_hi"], None)

    hip_y = ground_y - 12
    shoulder_y = hip_y - 24
    torso_left = cx - 10
    torso_right = cx + 10
    chest_shift = mirror * (2 if facing_index in (0, 1) else -1)
    torso = [
        (torso_left - mirror * 1, shoulder_y + 2),
        (torso_right + chest_shift, shoulder_y - 1),
        (cx + 10, hip_y + 6),
        (cx - 10, hip_y + 6),
    ]
    hood = [
        (cx - 11, shoulder_y - 4),
        (cx + 4 * mirror, shoulder_y - 7),
        (cx + 12, shoulder_y + 4),
        (cx - 8, shoulder_y + 8),
    ]
    chest = [
        (cx - 4, shoulder_y + 2),
        (cx + 7 * mirror, shoulder_y + 1),
        (cx + 5 * mirror, hip_y - 2),
        (cx - 4, hip_y),
    ]

    draw_poly(draw, hood, P["hoodie_dark"])
    draw_poly(draw, torso, P["hoodie_dark"] if back_view else P["hoodie"])
    if not back_view:
        draw_poly(draw, chest, P["shirt"], None)

    rear_foot_x = cx - 5 * mirror - stride * 4
    front_foot_x = cx + 5 * mirror + stride * 5
    rear_foot_y = ground_y + 6 - abs(stride)
    front_foot_y = ground_y + 5 + abs(stride)
    draw_leg(draw, cx - 3 * mirror, hip_y + 4, rear_foot_x, rear_foot_y, False)
    draw_leg(draw, cx + 3 * mirror, hip_y + 4, front_foot_x, front_foot_y, True)

    rear_hand_x = cx - 14 * mirror - stride * 3
    rear_hand_y = shoulder_y + 18 + abs(stride)
    front_hand_x = cx + 14 * mirror + stride * 4
    front_hand_y = shoulder_y + 17 + (0 if stride == 0 else 1)
    draw_arm(draw, cx - 8 * mirror, shoulder_y + 6, rear_hand_x, rear_hand_y, P["hoodie_dark"])
    draw_arm(draw, cx + 8 * mirror, shoulder_y + 6, front_hand_x, front_hand_y, P["hoodie"])

    head_cx = cx + mirror * (1 if back_view else 0)
    head_cy = shoulder_y - 7
    draw.ellipse((head_cx - 10, head_cy - 10, head_cx + 10, head_cy + 10), fill=P["skin"], outline=P["outline"])

    hair = [
        (head_cx - 10, head_cy - 2),
        (head_cx - 8, head_cy - 10),
        (head_cx + 2, head_cy - 11),
        (head_cx + 10, head_cy - 6),
        (head_cx + 8, head_cy + 1),
        (head_cx - 2, head_cy + 2),
    ]
    if mirror < 0:
        hair = [(2 * head_cx - x, y) for x, y in hair]
    draw_poly(draw, hair, P["hair"])

    if not back_view:
        nose_x = head_cx + 4 * mirror
        draw.line([(nose_x, head_cy + 1), (nose_x + 2 * mirror, head_cy + 3)], fill=P["outline"], width=1)
        eye_x = head_cx + 1 * mirror
        draw.line([(eye_x, head_cy - 1), (eye_x + 2 * mirror, head_cy - 1)], fill=P["outline"], width=1)
    else:
        hood_back = [
            (head_cx - 9, head_cy - 2),
            (head_cx, head_cy - 7),
            (head_cx + 10, head_cy - 1),
            (head_cx + 5, head_cy + 8),
            (head_cx - 6, head_cy + 7),
        ]
        draw_poly(draw, hood_back, P["hoodie_dark"], None)


for row in range(ROWS):
    for col in range(COLS):
        draw = ImageDraw.Draw(img)
        draw_frame(draw, col * FRAME_W, row * FRAME_H, row, col)


img.save(OUT)
print(OUT)
print(f"{SHEET_W}x{SHEET_H}")
