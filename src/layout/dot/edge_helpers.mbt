///|
fn edge_is_constraint(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("constraint") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "false" && lower != "0" && lower != "no"
    }
    None => true
  }
}

///|
fn edge_weight(edge : @cgraph.Edge) -> Int {
  let weight_value = match edge.get_attr("weight") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let mut weight = weight_value.round().to_int()
  if weight < 0 {
    weight = 0
  }
  if !edge_is_constraint(edge) {
    return 0
  }
  let tail_group = match edge.tail().get_attr("group") {
    Some(value) => value
    None => ""
  }
  let head_group = match edge.head().get_attr("group") {
    Some(value) => value
    None => ""
  }
  if tail_group != "" && tail_group == head_group {
    weight = weight * 100
  }
  weight
}

///|
fn edge_xpenalty(edge : @cgraph.Edge) -> Int {
  let penalty_value = match edge.get_attr("xpenalty") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let mut penalty = penalty_value.round().to_int()
  if penalty < 0 {
    penalty = 0
  }
  if !edge_is_constraint(edge) {
    return 0
  }
  penalty
}

///|
fn edge_minlen(edge : @cgraph.Edge) -> Int {
  let minlen_value = match edge.get_attr("minlen") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let minlen = minlen_value.round().to_int()
  if minlen < 1 {
    1
  } else {
    minlen
  }
}

///|
fn edge_mid_label_text(edge : @cgraph.Edge) -> String? {
  match edge.get_attr("label") {
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
}

///|
fn edge_mid_label_width_pt(edge : @cgraph.Edge) -> Double {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  match edge_mid_label_text(edge) {
    Some(text) => {
      let (width, _height) = label_text_dimensions(text, font, font_size_pt)
      width
    }
    None => 0.0
  }
}

///|
fn edge_mid_label_metrics(edge : @cgraph.Edge) -> (Double, Double)? {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  match edge_mid_label_text(edge) {
    Some(text) => {
      let (width, height) = label_text_dimensions(text, font, font_size_pt)
      Some((width, height))
    }
    None => None
  }
}

///|
fn edge_label_height_pt(edge : @cgraph.Edge) -> Double {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  let mut max_height = 0.0
  let labels = ["label", "headlabel", "taillabel"]
  for name in labels {
    match edge.get_attr(name) {
      Some(text) =>
        if text != "" {
          let (_width, height) = label_text_dimensions(text, font, font_size_pt)
          if height > max_height {
            max_height = height
          }
        }
      None => ()
    }
  }
  max_height
}

///|
fn edge_has_label(edge : @cgraph.Edge) -> Bool {
  let labels = ["label", "headlabel", "taillabel"]
  for name in labels {
    match edge.get_attr(name) {
      Some(value) => if value != "" { return true }
      None => ()
    }
  }
  false
}

///|
fn graph_has_edge_labels(edges : Array[@cgraph.Edge]) -> Bool {
  for edge in edges {
    if edge_has_label(edge) {
      return true
    }
  }
  false
}

///|
fn self_edge_label_width_pt(edge : @cgraph.Edge, rankdir : RankDir) -> Double {
  match edge_mid_label_metrics(edge) {
    Some((width, height)) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        height
      } else {
        width
      }
    None => 0.0
  }
}

///|
fn edge_port_name(port : @cgraph.Port?) -> String? {
  match port {
    Some(value) => value.name
    None => None
  }
}

///|
fn endpoint_port_name(
  node_name : String,
  tail_name : String,
  head_name : String,
  tail_port : String?,
  head_port : String?,
) -> String? {
  if node_name == tail_name {
    tail_port
  } else if node_name == head_name {
    head_port
  } else {
    None
  }
}

///|
fn edge_endpoints_from_edges(
  edges : Array[@cgraph.Edge],
) -> (Array[String], Array[String], Array[Bool]) {
  let edge_tail : Array[String] = []
  let edge_head : Array[String] = []
  let edge_reversed : Array[Bool] = []
  for edge in edges {
    edge_tail.push(edge.tail().name())
    edge_head.push(edge.head().name())
    edge_reversed.push(false)
  }
  (edge_tail, edge_head, edge_reversed)
}
