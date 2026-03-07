///|
/// Rank direction for dot layout.
pub(all) enum RankDir {
  TB
  BT
  LR
  RL
} derive(Show, Eq)

///|
pub fn parse_rankdir(value : String) -> RankDir? {
  match value.to_lower() {
    "tb" => Some(RankDir::TB)
    "bt" => Some(RankDir::BT)
    "lr" => Some(RankDir::LR)
    "rl" => Some(RankDir::RL)
    _ => None
  }
}

///|
pub fn graph_rankdir(graph : @cgraph.Graph) -> RankDir {
  let mut current = graph
  while true {
    match current.get_attr("rankdir") {
      Some(value) =>
        match parse_rankdir(value) {
          Some(parsed) => return parsed
          None => ()
        }
      None => ()
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  RankDir::TB
}

///|
/// Node size in inches and points.
pub(all) struct NodeSize {
  width_in : Double
  height_in : Double
  width_pt : Double
  height_pt : Double
  left_pt : Double
  right_pt : Double
}


///|
pub(all) struct GraphSizePt {
  width_pt : Double
  height_pt : Double
}


///|
pub const CLUSTER_SKELETON_PREFIX : String = "_mbt_cluster_skel_"

///|
pub const CLUSTER_LN_PREFIX : String = "_mbt_cluster_ln_"

///|
pub const CLUSTER_RN_PREFIX : String = "_mbt_cluster_rn_"

///|
pub const CL_BACK : Int = 10

///|
pub const VNODE_HEIGHT_PT : Double = 1.0

///|
pub fn default_node_width_in() -> Double {
  0.75
}

///|
pub fn default_node_height_in() -> Double {
  0.5
}

///|
pub fn default_point_size_in() -> Double {
  0.05
}

///|
pub fn env_flag_enabled(
  value : String?,
  default_enabled : Bool,
) -> Bool {
  match value {
    Some(raw) => {
      let lower = raw.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => default_enabled
  }
}

///|
pub fn env_flag_enabled_nonempty(value : String?) -> Bool {
  match value {
    Some(raw) => {
      let lower = raw.to_lower()
      lower != "" && lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
}
///|
pub fn parse_double_or(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
/// Graphviz ROUND macro parity (round half away from zero).
pub fn round_int(value : Double) -> Int {
  if value >= 0.0 {
    (value + 0.5).floor().to_int()
  } else {
    (value - 0.5).ceil().to_int()
  }
}

///|
pub fn trunc_int(value : Double) -> Int {
  if value >= 0.0 {
    value.floor().to_int()
  } else {
    value.ceil().to_int()
  }
}

///|
fn first_numeric_token(value : String) -> String? {
  let sb = StringBuilder::new()
  let mut seen = false
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
      seen = true
    } else if seen {
      break
    }
  }
  if seen {
    Some(sb.to_string())
  } else {
    None
  }
}

///|
pub fn parse_first_double(value : String, fallback : Double) -> Double {
  match first_numeric_token(value) {
    Some(token) => parse_double_or(token, fallback)
    None => fallback
  }
}

///|
pub fn parse_first_double_optional(value : String) -> Double? {
  match first_numeric_token(value) {
    Some(token) =>
      try @strconv.parse_double(token) catch {
        _ => None
      } noraise {
        parsed => Some(parsed)
      }
    None => None
  }
}

///|
pub fn parse_attr_double(value : String, fallback : Double, min : Double) -> Double {
  match parse_first_double_optional(value) {
    Some(parsed) => if parsed < min { min } else { parsed }
    None => fallback
  }
}

///|
/// Graphviz parity: size parsing aligned to refs/graphviz/lib/common/input.c.
pub fn parse_graph_size_pt_attr(graph : @cgraph.Graph) -> GraphSizePt? {
  match graph.get_attr("size") {
    Some(value) => {
      let parts : Array[String] = []
      for part in value.split(",") {
        let cleaned = part.trim(chars=" \n\r\t!").to_string()
        if cleaned != "" {
          parts.push(cleaned)
        }
      }
      if parts.length() == 0 {
        return None
      }
      let width_in = parse_double_or(parts[0], -1.0)
      let height_in =
        if parts.length() > 1 {
          parse_double_or(parts[1], -1.0)
        } else {
          width_in
        }
      if width_in <= 0.0 || height_in <= 0.0 {
        return None
      }
      Some({ width_pt: width_in * 72.0, height_pt: height_in * 72.0 })
    }
    None => None
  }
}

///|
pub fn node_size_from_points(
  width_pt : Double,
  height_pt : Double,
) -> NodeSize {
  let width_in = width_pt / 72.0
  let height_in = height_pt / 72.0
  let half = width_pt / 2.0
  { width_in, height_in, width_pt, height_pt, left_pt: half, right_pt: half }
}

///|
pub fn swap_node_size(size : NodeSize) -> NodeSize {
  let width_in = size.height_in
  let height_in = size.width_in
  let width_pt = size.height_pt
  let height_pt = size.width_pt
  let half = width_pt / 2.0
  { width_in, height_in, width_pt, height_pt, left_pt: half, right_pt: half }
}

///|
pub fn vnode_size_from_widths(left_pt : Double, right_pt : Double) -> NodeSize {
  let width_pt = left_pt + right_pt
  let width_in = width_pt / 72.0
  let height_pt = 1.0
  let height_in = height_pt / 72.0
  {
    width_in,
    height_in,
    width_pt,
    height_pt,
    left_pt,
    right_pt,
  }
}

///|
pub fn vnode_size_from_widths_with_h(
  left_pt : Double,
  right_pt : Double,
  height_pt : Double,
) -> NodeSize {
  let width_pt = left_pt + right_pt
  let width_in = width_pt / 72.0
  let height_in = height_pt / 72.0
  { width_in, height_in, width_pt, height_pt, left_pt, right_pt }
}

///|
pub fn node_left_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.left_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

///|
pub fn node_right_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.right_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

///|
pub fn clip_to_rect(
  center : @geom.Point,
  size : NodeSize,
  target : @geom.Point,
) -> @geom.Point {
  let dx = target.x - center.x
  let dy = target.y - center.y
  if dx == 0.0 && dy == 0.0 {
    return center
  }
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  let tx = if dx == 0.0 { 1000000000.0 } else { half_w / Double::abs(dx) }
  let ty = if dy == 0.0 { 1000000000.0 } else { half_h / Double::abs(dy) }
  let t = if tx < ty { tx } else { ty }
  { x: center.x + dx * t, y: center.y + dy * t }
}


