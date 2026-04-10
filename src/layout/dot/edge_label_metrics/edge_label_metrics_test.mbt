// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
test "edge mid label helpers treat missing and empty labels as absent" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)

  assert_eq(edge_mid_label_text(edge), None)
  match edge_mid_label_metrics(edge) {
    None => ()
    Some(_) => fail("expected no mid label metrics")
  }
  assert_eq(edge_mid_label_width_pt(edge), 0.0)
  assert_eq(edge_label_height_pt(edge), 0.0)

  edge.set_attr("label", "")
  assert_eq(edge_mid_label_text(edge), None)
  match edge_mid_label_metrics(edge) {
    None => ()
    Some(_) => fail("expected empty label to stay absent")
  }
}

///|
test "graph_has_edge_labels only tracks non-empty mid labels" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let unlabeled = graph.edge(a, b)
  let head_only = graph.edge(b, c)
  head_only.set_attr("headlabel", "head")
  let labeled = graph.edge(c, a)
  labeled.set_attr("label", "mid")

  assert_false(graph_has_edge_labels([unlabeled, head_only]))
  assert_true(graph_has_edge_labels([unlabeled, head_only, labeled]))
}

///|
test "edge_label_height_pt takes the maximum height across mid head and tail labels" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("label", "mid")
  edge.set_attr("headlabel", "head")
  edge.set_attr("taillabel", "tail tail")

  let mid = match edge_label_metrics_for_attr(edge, "label", false) {
    Some(value) => value
    None => fail("expected mid label metrics")
  }
  let head = match edge_label_metrics_for_attr(edge, "headlabel", true) {
    Some(value) => value
    None => fail("expected head label metrics")
  }
  let tail = match edge_label_metrics_for_attr(edge, "taillabel", true) {
    Some(value) => value
    None => fail("expected tail label metrics")
  }
  let expected = if mid.height > head.height {
    if mid.height > tail.height {
      mid.height
    } else {
      tail.height
    }
  } else if head.height > tail.height {
    head.height
  } else {
    tail.height
  }

  assert_close(edge_label_height_pt(edge), expected)
}

///|
test "self edge label width and height swap across rank directions" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  let edge = graph.edge(node, node)
  edge.set_attr("label", "wide self label")

  let metrics = match edge_mid_label_metrics(edge) {
    Some(value) => value
    None => fail("expected self-edge metrics")
  }
  assert_close(
    self_edge_label_width_pt(edge, @rankdir.RankDir::TB),
    metrics.width,
  )
  assert_close(
    self_edge_label_height_pt(edge, @rankdir.RankDir::TB),
    metrics.height,
  )
  assert_close(
    self_edge_label_width_pt(edge, @rankdir.RankDir::LR),
    metrics.height,
  )
  assert_close(
    self_edge_label_height_pt(edge, @rankdir.RankDir::LR),
    metrics.width,
  )
}
