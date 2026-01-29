///|
/// Rank direction for dot layout.
pub(all) enum RankDir {
  TB
  BT
  LR
  RL
} derive(Show, Eq)

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
pub const RECORD_BORDER_PT : Double = 0.5

///|
pub fn default_node_width_in() -> Double {
  0.75
}

///|
pub fn default_node_height_in() -> Double {
  0.5
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
pub fn port_is_explicit(port : @cgraph.Port?) -> Bool {
  match port {
    Some(value) => value.name is Some(_) || value.compass is Some(_)
    None => false
  }
}

///|
pub fn port_key(port : @cgraph.Port?) -> String {
  match port {
    None => ""
    Some(value) => {
      let mut out = ""
      match value.name {
        Some(name) => out = name
        None => ()
      }
      match value.compass {
        Some(compass) => {
          let label = match compass {
            @cgraph.Compass::N => "n"
            @cgraph.Compass::NE => "ne"
            @cgraph.Compass::E => "e"
            @cgraph.Compass::SE => "se"
            @cgraph.Compass::S => "s"
            @cgraph.Compass::SW => "sw"
            @cgraph.Compass::W => "w"
            @cgraph.Compass::NW => "nw"
            @cgraph.Compass::C => "c"
          }
          if out == "" {
            out = label
          } else {
            out = "\{out}:\{label}"
          }
        }
        None => ()
      }
      out
    }
  }
}

///|
pub fn edge_key(edge : @cgraph.Edge) -> String {
  let tail = edge.tail().name()
  let head = edge.head().name()
  let name = match edge.name() {
    Some(value) => value
    None => ""
  }
  let tail_port = port_key(edge.tail_port())
  let head_port = port_key(edge.head_port())
  "\{tail}|\{head}|\{name}|\{tail_port}|\{head_port}"
}
