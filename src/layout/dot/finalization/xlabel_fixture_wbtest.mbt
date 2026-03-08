///|
fn compute_finalized_xlabel_layout(
  graph : @cgraph.Graph,
) -> @shared.LayoutTree raise {
  let prep = match
    @input_stage.prepare_layout_prep(graph, {
      rankdir: None,
      nodesep: None,
      ranksep: None,
      splines: None,
    }) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let rank_stage = @rank_stage.compute_dot_rank_stage({ graph, prep })
  let positions_state = @positioning.compute_positions({
    graph,
    prep,
    rank_data: rank_stage.rank_data,
    rank_heights: rank_stage.rank_heights,
    cluster_meta: rank_stage.cluster_meta,
    ordering: rank_stage.ordering,
  })
  let routing_stage_output = @integration.compute_dot_routing_stage({
    graph,
    prep,
    rank_data: rank_stage.rank_data,
    rank_heights: rank_stage.rank_heights,
    cluster_meta: rank_stage.cluster_meta,
    ordering: rank_stage.ordering,
    positions_state,
  })
  finalize_layout_from_sources({
    graph,
    prep,
    rank_data: rank_stage.rank_data,
    rank_heights: rank_stage.rank_heights,
    positions_state,
    routing_stage_output,
  })
}

///|
fn load_tb_xlabel_layout() -> @shared.LayoutTree raise {
  compute_finalized_xlabel_layout(
    @dot_parser.parse_dot_file("tests/layout/dot/xlabels_tb.dot"),
  )
}

///|
fn find_node_layout(
  layout : @shared.LayoutTree,
  node_name : String,
) -> @shared.DotLayoutNode? {
  for node_layout in layout.nodes {
    if node_layout.node.name() == node_name {
      return Some(node_layout)
    }
  }
  for subgraph in layout.subgraphs {
    match find_node_layout(subgraph, node_name) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn find_edge_layout_by_label(
  layout : @shared.LayoutTree,
  tail : String,
  head : String,
  attr_name : String,
  label : String,
) -> @shared.DotLayoutEdge? {
  for edge_layout in layout.edges {
    let edge = edge_layout.edge
    if edge.tail().name() != tail || edge.head().name() != head {
      continue
    }
    if edge.get_attr(attr_name).unwrap_or_default() == label {
      return Some(edge_layout)
    }
  }
  for subgraph in layout.subgraphs {
    match find_edge_layout_by_label(subgraph, tail, head, attr_name, label) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn assert_float_eq(
  actual : Double,
  expected : Double,
  message : String,
) -> Unit raise {
  if actual != expected {
    fail(message)
  }
}

///|
fn assert_node_xlabel(
  layout : @shared.LayoutTree,
  node_name : String,
  label : String,
  pos_x : Double,
  pos_y : Double,
) -> Unit raise {
  let node_layout = match find_node_layout(layout, node_name) {
    Some(value) => value
    None => fail("missing node \{node_name} in xlabel smoke graph")
  }
  let actual_label = node_layout.node.get_attr("xlabel").unwrap_or_default()
  if actual_label != label {
    fail(
      "node xlabel mismatch for \{node_name} expected '\{label}' got '\{actual_label}'",
    )
  }
  let pos = match node_layout.xlabel_pos {
    Some(value) => value
    None => fail("missing node xlabel position for \{node_name}")
  }
  assert_float_eq(
    pos.x,
    pos_x,
    "node xlabel pos x mismatch \{node_name} got (\{pos.x}) expected (\{pos_x})",
  )
  assert_float_eq(
    pos.y,
    pos_y,
    "node xlabel pos y mismatch \{node_name} got (\{pos.y}) expected (\{pos_y})",
  )
}

///|
fn assert_edge_label_position(
  layout : @shared.LayoutTree,
  tail : String,
  head : String,
  attr_name : String,
  label : String,
  pos_x : Double,
  pos_y : Double,
) -> Unit raise {
  let edge_layout = match
    find_edge_layout_by_label(layout, tail, head, attr_name, label) {
    Some(value) => value
    None =>
      fail(
        "missing labeled edge \{tail}->\{head} '\{label}' for attr \{attr_name}",
      )
  }
  let pos = match attr_name {
    "xlabel" => edge_layout.xlabel_pos
    "headlabel" => edge_layout.head_label_pos
    "taillabel" => edge_layout.tail_label_pos
    _ => fail("unknown edge xlabel attr \{attr_name}")
  }
  match pos {
    Some(value) => {
      assert_float_eq(
        value.x,
        pos_x,
        "edge xlabel pos x mismatch \{attr_name} \{tail}->\{head} got (\{value.x}) expected (\{pos_x})",
      )
      assert_float_eq(
        value.y,
        pos_y,
        "edge xlabel pos y mismatch \{attr_name} \{tail}->\{head} got (\{value.y}) expected (\{pos_y})",
      )
    }
    None => fail("missing edge label position \{attr_name} \{tail}->\{head}")
  }
}

///|
test "node xlabels match finalized xlabels_tb smoke graph" {
  let layout = load_tb_xlabel_layout()

  assert_node_xlabel(layout, "a", "XA", 9.75, 116.25)
  assert_node_xlabel(layout, "b", "XB", 100.875, 116.25)
  assert_node_xlabel(layout, "c", "XC", 46.125, 8.25)
}

///|
test "edge xlabels match finalized xlabels_tb smoke graph" {
  let layout = load_tb_xlabel_layout()

  assert_edge_label_position(
    layout, "a", "c", "taillabel", "TAC", 41.898878574371338, 63.446624994277954,
  )
  assert_edge_label_position(
    layout, "a", "c", "headlabel", "HAC", 59.453485534624861, 44.354333682673882,
  )
  assert_edge_label_position(
    layout, "a", "c", "xlabel", "XAC", 78.806170404878173, 62.14077976829244,
  )
  assert_edge_label_position(
    layout, "b", "c", "taillabel", "TBC", 122.72612142562866, 63.446624994277954,
  )
  assert_edge_label_position(
    layout, "b", "c", "headlabel", "HBC", 105.17151446537514, 44.354333682673882,
  )
  assert_edge_label_position(
    layout, "b", "c", "xlabel", "XBC", 86.568829595121827, 45.64077976829244,
  )
}
