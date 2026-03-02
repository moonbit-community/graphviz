///|
fn spacing_parse_double(text : String, fallback : Double) -> Double {
  try @strconv.parse_double(text) catch {
    _ => fallback
  } noraise {
    value => value
  }
}

///|
fn spacing_parse_point(text : String) -> @geom.Point {
  let parts : Array[String] = []
  for part in text.split(",") {
    parts.push(part.to_string())
  }
  let x = if parts.length() > 0 {
    spacing_parse_double(parts[0], 0.0)
  } else {
    0.0
  }
  let y = if parts.length() > 1 {
    spacing_parse_double(parts[1], 0.0)
  } else {
    0.0
  }
  { x, y }
}

///|
struct SpacingRect {
  llx : Double
  lly : Double
  urx : Double
  ury : Double
}

///|
fn spacing_parse_rect(text : String) -> SpacingRect {
  let parts : Array[String] = []
  for part in text.split(",") {
    parts.push(part.to_string())
  }
  let llx = if parts.length() > 0 {
    spacing_parse_double(parts[0], 0.0)
  } else {
    0.0
  }
  let lly = if parts.length() > 1 {
    spacing_parse_double(parts[1], 0.0)
  } else {
    0.0
  }
  let urx = if parts.length() > 2 {
    spacing_parse_double(parts[2], 0.0)
  } else {
    0.0
  }
  let ury = if parts.length() > 3 {
    spacing_parse_double(parts[3], 0.0)
  } else {
    0.0
  }
  { llx, lly, urx, ury }
}

///|
fn spacing_node_pos(graph : @cgraph.Graph, name : String) -> @geom.Point raise {
  match graph.find_node(name) {
    Some(node) =>
      match node.get_attr("pos") {
        Some(value) => spacing_parse_point(value)
        None => fail("missing pos for node \{name}")
      }
    None => fail("missing node \{name}")
  }
}

///|
fn spacing_node_size_pt(
  graph : @cgraph.Graph,
  name : String,
) -> (Double, Double) raise {
  match graph.find_node(name) {
    Some(node) => {
      let width_in = match node.get_attr("width") {
        Some(value) => spacing_parse_double(value, 0.0)
        None => 0.0
      }
      let height_in = match node.get_attr("height") {
        Some(value) => spacing_parse_double(value, 0.0)
        None => 0.0
      }
      (width_in * 72.0, height_in * 72.0)
    }
    None => fail("missing node \{name}")
  }
}

///|
fn spacing_cluster(graph : @cgraph.Graph) -> @cgraph.Graph raise {
  let subgraphs = graph.subgraphs()
  if subgraphs.length() == 0 {
    fail("missing cluster subgraph")
  }
  subgraphs[0]
}

///|
fn spacing_find_subgraph(
  graph : @cgraph.Graph,
  name : String,
) -> @cgraph.Graph raise {
  for subgraph in graph.subgraphs() {
    match subgraph.name() {
      Some(value) => if value == name { return subgraph }
      None => ()
    }
  }
  fail("missing subgraph \{name}")
}

///|
test "cluster bbox includes margin and label padding" {
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=box,width=1,height=1,label=\"\"]; subgraph cluster_a { label=\"Cluster\"; a; } }",
  )
  let layout = layout_dot(graph)
  layout.apply()
  let cluster = spacing_cluster(graph)
  let bb_text = match cluster.get_attr("bb") {
    Some(value) => value
    None => fail("missing cluster bb")
  }
  let bbox = spacing_parse_rect(bb_text)
  let pos = spacing_node_pos(graph, "a")
  let (width_pt, height_pt) = spacing_node_size_pt(graph, "a")
  let margin = cluster_margin_pt(cluster)
  let label_height = match graph_label_metrics(cluster) {
    Some(metrics) => metrics.height_pt
    None => 0.0
  }
  let expected_left = pos.x - width_pt / 2.0 - margin
  let expected_right = pos.x + width_pt / 2.0 + margin
  let expected_bottom = pos.y - height_pt / 2.0 - margin
  let expected_top = pos.y +
    height_pt / 2.0 +
    margin +
    label_height +
    CLUSTER_LABEL_PAD_PT
  guard bbox.llx <= expected_left + 0.1 else {
    fail("cluster llx too large: \{bbox.llx} expected <= \{expected_left}")
  }
  guard bbox.urx >= expected_right - 0.1 else {
    fail("cluster urx too small: \{bbox.urx} expected >= \{expected_right}")
  }
  guard bbox.lly <= expected_bottom + 0.1 else {
    fail("cluster lly too large: \{bbox.lly} expected <= \{expected_bottom}")
  }
  guard bbox.ury >= expected_top - 0.1 else {
    fail("cluster ury too small: \{bbox.ury} expected >= \{expected_top}")
  }
}

///|
test "nested clusters include parent margin" {
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=box,width=1,height=1,label=\"\"]; subgraph cluster_outer { label=\"Outer\"; subgraph cluster_inner { label=\"Inner\"; a; } } }",
  )
  let layout = layout_dot(graph)
  layout.apply()
  let outer = spacing_find_subgraph(graph, "cluster_outer")
  let inner = spacing_find_subgraph(outer, "cluster_inner")
  let outer_bb = match outer.get_attr("bb") {
    Some(value) => spacing_parse_rect(value)
    None => fail("missing outer cluster bb")
  }
  let inner_bb = match inner.get_attr("bb") {
    Some(value) => spacing_parse_rect(value)
    None => fail("missing inner cluster bb")
  }
  let margin = cluster_margin_pt(outer)
  guard outer_bb.llx <= inner_bb.llx - margin + 0.1 else {
    fail("outer llx too large: \{outer_bb.llx} expected <= \{inner_bb.llx - margin}")
  }
  guard outer_bb.lly <= inner_bb.lly - margin + 0.1 else {
    fail("outer lly too large: \{outer_bb.lly} expected <= \{inner_bb.lly - margin}")
  }
  guard outer_bb.urx >= inner_bb.urx + margin - 0.1 else {
    fail("outer urx too small: \{outer_bb.urx} expected >= \{inner_bb.urx + margin}")
  }
  guard outer_bb.ury >= inner_bb.ury + margin - 0.1 else {
    fail("outer ury too small: \{outer_bb.ury} expected >= \{inner_bb.ury + margin}")
  }
}

///|
test "empty clusters do not receive layout bbox attrs" {
  let graph = @dot_parser.parse_dot(
    "digraph { subgraph cluster_empty { label=\"empty\"; } subgraph cluster_full { label=\"full\"; a; } }",
  )
  let layout = layout_dot(graph)
  layout.apply()
  let empty = spacing_find_subgraph(graph, "cluster_empty")
  let full = spacing_find_subgraph(graph, "cluster_full")
  guard empty.get_attr("bb") is None else {
    fail("empty cluster should not receive bb")
  }
  guard full.get_attr("bb") is Some(_) else {
    fail("non-empty cluster should receive bb")
  }
}

///|
test "edge labels expand rank spacing" {
  let with_label = @dot_parser.parse_dot(
    "digraph { node [shape=box,width=1,height=1,label=\"\"]; a -> b [label=\"EdgeLabel\"]; }",
  )
  let layout_label = layout_dot(with_label)
  layout_label.apply()
  let pos_a = spacing_node_pos(with_label, "a")
  let pos_b = spacing_node_pos(with_label, "b")
  let dist_label = Double::abs(pos_a.y - pos_b.y)
  let edges = with_label.edges()
  guard edges.length() > 0 else { fail("missing labeled edge") }
  let edge = edges[0]
  let label_height = edge_label_height_pt(edge)
  let without_label = @dot_parser.parse_dot(
    "digraph { node [shape=box,width=1,height=1,label=\"\"]; a -> b; }",
  )
  let layout_plain = layout_dot(without_label)
  layout_plain.apply()
  let pos_plain_a = spacing_node_pos(without_label, "a")
  let pos_plain_b = spacing_node_pos(without_label, "b")
  let dist_plain = Double::abs(pos_plain_a.y - pos_plain_b.y)
  guard dist_label > dist_plain else {
    fail("expected labeled edge to increase rank spacing")
  }
  guard dist_label >= dist_plain + label_height - 0.1 else {
    fail("expected label height to contribute to spacing")
  }
}
