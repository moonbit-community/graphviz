import json
import re
from pathlib import Path


repo_root = Path(__file__).resolve().parents[1]
xdot_dir = repo_root / "tests" / "render" / "xdot"
output_path = repo_root / "tests" / "fixtures" / "graphviz" / "textspan.jsonl"

draw_attr_re = re.compile(r'_(?:l|h|t)?draw_="')
float_re = re.compile(r"[+-]?(?:\d+\.\d*|\d*\.\d+|\d+)(?:[eE][+-]?\d+)?")
int_re = re.compile(r"[+-]?\d+")


def skip_ws(text: str, index: int) -> int:
    while index < len(text) and text[index].isspace():
        index += 1
    return index


def parse_int(text: str, index: int):
    index = skip_ws(text, index)
    match = int_re.match(text, index)
    if not match:
        return None, index
    return int(match.group(0)), match.end()


def parse_real(text: str, index: int):
    index = skip_ws(text, index)
    match = float_re.match(text, index)
    if not match:
        return None, index
    return float(match.group(0)), match.end()


def parse_string(text: str, index: int):
    count, index = parse_int(text, index)
    if count is None or count <= 0:
        return None, index
    index = skip_ws(text, index)
    while index < len(text) and text[index] != "-":
        index += 1
    if index >= len(text):
        return None, index
    index += 1
    out = []
    accounted = 0
    while index < len(text) and accounted < count:
        ch = text[index]
        if ch == "\\":
            if index + 1 < len(text):
                index += 1
                out.append(text[index])
            else:
                out.append(ch)
            accounted += 1
            index += 1
            continue
        out.append(ch)
        accounted += 1
        index += 1
    return "".join(out), index


def parse_rect(text: str, index: int):
    _, index = parse_real(text, index)
    _, index = parse_real(text, index)
    _, index = parse_real(text, index)
    _, index = parse_real(text, index)
    return index


def parse_polyline(text: str, index: int):
    count, index = parse_int(text, index)
    if count is None:
        return index
    for _ in range(count * 2):
        _, index = parse_real(text, index)
    return index


def parse_draw_ops(draw: str):
    index = 0
    font_name = None
    font_size = None
    spans = []
    while index < len(draw):
        index = skip_ws(draw, index)
        if index >= len(draw):
            break
        cmd = draw[index]
        index += 1
        if cmd in ("E", "e"):
            index = parse_rect(draw, index)
        elif cmd in ("P", "p", "L", "B", "b"):
            index = parse_polyline(draw, index)
        elif cmd in ("c", "C", "S"):
            _, index = parse_string(draw, index)
        elif cmd == "F":
            size, index = parse_real(draw, index)
            font, index = parse_string(draw, index)
            if size is not None and font is not None:
                font_size = size
                font_name = font
        elif cmd == "T":
            _, index = parse_real(draw, index)
            _, index = parse_real(draw, index)
            _, index = parse_int(draw, index)
            width, index = parse_real(draw, index)
            text, index = parse_string(draw, index)
            if text is not None and width is not None:
                spans.append((font_name or "Times-Roman", font_size or 14.0, text, width))
        elif cmd == "I":
            index = parse_rect(draw, index)
            _, index = parse_string(draw, index)
        elif cmd == "t":
            _, index = parse_int(draw, index)
        elif cmd == "\0":
            break
        else:
            break
    return spans


def extract_draw_strings(content: str):
    strings = []
    index = 0
    while True:
        match = draw_attr_re.search(content, index)
        if not match:
            break
        index = match.end()
        buf = []
        while index < len(content):
            ch = content[index]
            if ch == '"':
                index += 1
                break
            if ch == "\\":
                if index + 1 < len(content):
                    nxt = content[index + 1]
                    if nxt == "\n":
                        index += 2
                        continue
                    if nxt == "\r":
                        index += 2
                        if index < len(content) and content[index] == "\n":
                            index += 1
                        continue
                    buf.append(ch)
                    buf.append(nxt)
                    index += 2
                    continue
            buf.append(ch)
            index += 1
        strings.append("".join(buf))
    return strings


def line_height_scale(font_name: str, font_size: float) -> float:
    lower = font_name.lower()
    if "palatino" in lower:
        return 1.125
    if "times" in lower:
        min_size = 10.0
        max_size = 14.0
        if font_size <= min_size:
            return 1.125
        if font_size >= max_size:
            return 1.1786
        t = (font_size - min_size) / (max_size - min_size)
        return 1.125 + t * (1.1786 - 1.125)
    return 1.2


entries = {}
if output_path.exists():
    for line in output_path.read_text(encoding="utf-8").splitlines():
        if not line:
            continue
        data = json.loads(line)
        key = (data["font"], float(data["size"]), data["text"])
        has_capture = (
            float(data.get("yoffset_layout", 0.0)) != 0.0
            or float(data.get("yoffset_centerline", 0.0)) != 0.0
        )
        entries[key] = {
            "width": float(data["width"]),
            "height": float(data["height"]),
            "flags": int(data.get("flags", 0)),
            "yoffset_layout": float(data.get("yoffset_layout", 0.0)),
            "yoffset_centerline": float(data.get("yoffset_centerline", 0.0)),
            "has_capture": has_capture,
        }
for path in sorted(xdot_dir.glob("*.xdot")):
    content = path.read_text(encoding="utf-8")
    for draw in extract_draw_strings(content):
        for font, size, text, width in parse_draw_ops(draw):
            key = (font, float(size), text)
            height = float(size) * line_height_scale(font, float(size))
            prev = entries.get(key)
            if prev is None:
                entries[key] = {
                    "width": width,
                    "height": height,
                    "flags": 0,
                    "yoffset_layout": 0.0,
                    "yoffset_centerline": 0.0,
                    "has_capture": False,
                    "xdot_width": width,
                    "xdot_height": height,
                }
            else:
                prev["xdot_width"] = max(prev.get("xdot_width", width), width)
                prev["xdot_height"] = max(prev.get("xdot_height", height), height)
                if not prev.get("has_capture", False):
                    prev["width"] = max(prev["width"], width)
                    prev["height"] = max(prev["height"], height)


output_path.parent.mkdir(parents=True, exist_ok=True)
with output_path.open("w", encoding="ascii") as handle:
    for (font, size, text), entry in sorted(entries.items()):
        width = entry.get("xdot_width", entry["width"])
        height = entry.get("xdot_height", entry["height"])
        data = {
            "font": font,
            "size": size,
            "flags": entry.get("flags", 0),
            "text": text,
            "width": width,
            "height": height,
            "yoffset_layout": entry.get("yoffset_layout", 0.0),
            "yoffset_centerline": entry.get("yoffset_centerline", 0.0),
        }
        handle.write(json.dumps(data, ensure_ascii=True))
        handle.write("\n")
