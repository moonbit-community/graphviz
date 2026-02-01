///|
type NodeSize = @dot_shared.NodeSize

///|
const RECORD_BORDER_PT : Double = @dot_shared.RECORD_BORDER_PT

///|
fn default_node_width_in() -> Double {
  @dot_shared.default_node_width_in()
}

///|
fn default_node_height_in() -> Double {
  @dot_shared.default_node_height_in()
}

///|
fn node_size_from_points(width_pt : Double, height_pt : Double) -> NodeSize {
  @dot_shared.node_size_from_points(width_pt, height_pt)
}

///|
fn node_left_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.left_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

///|
fn node_right_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.right_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

///|
fn port_is_explicit(port : @cgraph.Port?) -> Bool {
  @dot_shared.port_is_explicit(port)
}

///|
fn port_key(port : @cgraph.Port?) -> String {
  @dot_shared.port_key(port)
}

///|
fn edge_key(edge : @cgraph.Edge) -> String {
  @dot_shared.edge_key(edge)
}

///|
fn edge_vnode_key(edge : @cgraph.Edge) -> String {
  @dot_shared.edge_vnode_key(edge)
}
