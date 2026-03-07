///|
/// Stable edge/port/vnode identity helpers used to build layout maps and
/// generated virtual-node names across dot stages.

///|
pub const EDGE_VNODE_PREFIX : String = "_mbt_edge_vn_"

///|
pub fn unique_virtual_node_name(
  prefix : String,
  edge_index : Int,
  rank : Int,
  existing : Map[String, Bool],
) -> String {
  let mut candidate = "\{prefix}\{edge_index}_\{rank}"
  if existing.get(candidate) is None {
    existing[candidate] = true
    return candidate
  }
  let mut i = 1
  while true {
    candidate = "\{prefix}\{edge_index}_\{rank}_\{i}"
    if existing.get(candidate) is None {
      existing[candidate] = true
      return candidate
    }
    i = i + 1
  }
  ""
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

///|
pub fn edge_vnode_key(edge : @cgraph.Edge) -> String {
  let tail = edge.tail().name()
  let head = edge.head().name()
  let tail_port = port_key(edge.tail_port())
  let head_port = port_key(edge.head_port())
  let base = "\{tail}|\{head}|\{tail_port}|\{head_port}"
  let label = match edge.get_attr("label") {
    Some(value) => value
    None => ""
  }
  if label == "" {
    base
  } else {
    "\{base}|\{edge.id()}"
  }
}

///|
pub fn is_edge_vnode_name(name : String) -> Bool {
  name.has_prefix(EDGE_VNODE_PREFIX)
}
