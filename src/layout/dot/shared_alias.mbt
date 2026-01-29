///|
type NodeSize = @dot_shared.NodeSize

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
