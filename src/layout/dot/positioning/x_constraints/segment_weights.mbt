///|
priv enum EndpointClass {
  Ordinary
  Singleton
  Virtual
}

///|
fn endpoint_class(
  name : String,
  node_degrees : Map[String, Int],
) -> EndpointClass {
  if @edge_identity.is_edge_vnode_name(name) {
    EndpointClass::Virtual
  } else {
    let degree = node_degrees.get(name).unwrap_or_default()
    if degree <= 1 {
      EndpointClass::Singleton
    } else {
      EndpointClass::Ordinary
    }
  }
}

///|
fn constraint_weight_scale(
  tail_class : EndpointClass,
  head_class : EndpointClass,
) -> Int {
  match (tail_class, head_class) {
    (EndpointClass::Virtual, EndpointClass::Virtual) => 4
    (EndpointClass::Singleton, EndpointClass::Singleton)
    | (EndpointClass::Singleton, EndpointClass::Virtual)
    | (EndpointClass::Virtual, EndpointClass::Singleton) => 2
    _ => 1
  }
}

///|
/// Graphviz parity: edge segment weights are amplified for virtual/singleton
/// endpoints so auxiliary chains remain tight in sparse local neighborhoods.
pub fn scaled_segment_edge_weight(
  base_weight : Int,
  tail_name : String,
  head_name : String,
  node_degrees : Map[String, Int],
) -> Int {
  if base_weight == 0 {
    0
  } else {
    let tail_class = endpoint_class(tail_name, node_degrees)
    let head_class = endpoint_class(head_name, node_degrees)
    base_weight * constraint_weight_scale(tail_class, head_class)
  }
}

///|
pub fn edge_tail_ordering_is_out_or_in(edge : @cgraph.Edge) -> Bool {
  match @clustering.root_graph_for_node(edge.tail()).get_attr("ordering") {
    Some(value) => {
      let lower = value.to_lower()
      lower == "out" || lower == "in"
    }
    None => false
  }
}
