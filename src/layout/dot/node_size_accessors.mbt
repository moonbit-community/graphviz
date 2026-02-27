///|
type NodeSize = @dot_shared.NodeSize

///|
fn node_left_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.left_pt
    None => @dot_shared.default_node_width_in() * 72.0 / 2.0
  }
}

///|
fn node_right_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.right_pt
    None => @dot_shared.default_node_width_in() * 72.0 / 2.0
  }
}
