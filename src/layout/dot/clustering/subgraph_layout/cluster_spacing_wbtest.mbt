// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn spacing_parse_double(text : String, fallback : Double) -> Double {
  @numeric.parse_double_or(text, fallback)
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
test "cluster spacing honors bbox margin, nesting, and empty cluster suppression" {
  let single_cluster = @dot_parser.parse_dot(
    "digraph { node [shape=box,width=1,height=1,label=\"\"]; subgraph cluster_a { label=\"Cluster\"; a; } }",
  )
  let single_cluster_layout = @dot_layout.layout_dot(single_cluster)
  single_cluster_layout.apply()
  let cluster = spacing_cluster(single_cluster)
  let bb_text = match cluster.get_attr("bb") {
    Some(value) => value
    None => fail("missing cluster bb")
  }
  let bbox = spacing_parse_rect(bb_text)
  let pos = spacing_node_pos(single_cluster, "a")
  let (width_pt, height_pt) = spacing_node_size_pt(single_cluster, "a")
  let margin = @clustering.cluster_margin_pt(cluster)
  let label_height = match @label_metrics.graph_label_metrics(cluster) {
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
    @cluster_geometry.CLUSTER_LABEL_PAD_PT
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

  let nested_graph = @dot_parser.parse_dot(
    "digraph { node [shape=box,width=1,height=1,label=\"\"]; subgraph cluster_outer { label=\"Outer\"; subgraph cluster_inner { label=\"Inner\"; a; } } }",
  )
  let nested_layout = @dot_layout.layout_dot(nested_graph)
  nested_layout.apply()
  let outer = spacing_find_subgraph(nested_graph, "cluster_outer")
  let inner = spacing_find_subgraph(outer, "cluster_inner")
  let outer_bb = match outer.get_attr("bb") {
    Some(value) => spacing_parse_rect(value)
    None => fail("missing outer cluster bb")
  }
  let inner_bb = match inner.get_attr("bb") {
    Some(value) => spacing_parse_rect(value)
    None => fail("missing inner cluster bb")
  }
  let outer_margin = @clustering.cluster_margin_pt(outer)
  guard outer_bb.llx <= inner_bb.llx - outer_margin + 0.1 else {
    fail(
      "outer llx too large: \{outer_bb.llx} expected <= \{inner_bb.llx - outer_margin}",
    )
  }
  guard outer_bb.lly <= inner_bb.lly - outer_margin + 0.1 else {
    fail(
      "outer lly too large: \{outer_bb.lly} expected <= \{inner_bb.lly - outer_margin}",
    )
  }
  guard outer_bb.urx >= inner_bb.urx + outer_margin - 0.1 else {
    fail(
      "outer urx too small: \{outer_bb.urx} expected >= \{inner_bb.urx + outer_margin}",
    )
  }
  guard outer_bb.ury >= inner_bb.ury + outer_margin - 0.1 else {
    fail(
      "outer ury too small: \{outer_bb.ury} expected >= \{inner_bb.ury + outer_margin}",
    )
  }

  let empty_graph = @dot_parser.parse_dot(
    "digraph { subgraph cluster_empty { label=\"empty\"; } subgraph cluster_full { label=\"full\"; a; } }",
  )
  let empty_layout = @dot_layout.layout_dot(empty_graph)
  empty_layout.apply()
  let empty = spacing_find_subgraph(empty_graph, "cluster_empty")
  let full = spacing_find_subgraph(empty_graph, "cluster_full")
  guard empty.get_attr("bb") is None else {
    fail("empty cluster should not receive bb")
  }
  guard full.get_attr("bb") is Some(_) else {
    fail("non-empty cluster should receive bb")
  }
}
