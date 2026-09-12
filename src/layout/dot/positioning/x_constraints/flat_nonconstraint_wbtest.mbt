///|
test "nonconstraint flat edges retain label-scaled horizontal minlen" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let flat = graph.edge(a, b)
  flat.set_attr("constraint", "false")
  flat.set_attr("minlen", "3")
  let labeled = graph.edge(b, c)
  for has_label in [false, true] {
    labeled.set_attr("label", if has_label { "label" } else { "" })
    let output = build_constraint_segment_pass({
      edges: [flat, labeled],
      edge_tail: [],
      edge_head: [],
      edge_out_order: { "a": [0], "b": [1] },
      nlist_order: ["a", "b", "c"],
      ranks: { "a": 0, "b": 0, "c": 1 },
      cluster_keys: {},
      edge_vnodes: {},
      order_in_rank: { "a": 0, "b": 1, "c": 0 },
      nodesep_pt: 10.0,
      sizes: build_constraint_builder_test_sizes(),
      skip_intercluster: false,
      rank_adj_constraints: {},
      edge_has_mid_label: edge => {
        edge.get_attr("label").unwrap_or_default() != ""
      },
      edge_degree_increment: _ => 1,
    })
    guard output.flat_minlen_constraints.get("a|b") is Some(constraint) else {
      fail("missing flat horizontal constraint")
    }
    assert_eq(constraint.minlen, if has_label { 70 } else { 40 })
  }
}
