///|
fn make_sizes(
  names : Array[String],
  width_pt : Double,
  height_pt : Double,
) -> Map[String, @node_primitives.NodeSize] {
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  for name in names {
    sizes[name] = @node_primitives.node_size_from_points(width_pt, height_pt)
  }
  sizes
}

///|
fn make_existing_names(names : Array[String]) -> Map[String, Bool] {
  let existing_names : Map[String, Bool] = Map::new()
  for name in names {
    existing_names[name] = true
  }
  existing_names
}

///|
fn empty_vnode_info() -> @setup.EdgeVnodeInfo {
  let vnode_ranks : Map[String, Int] = Map::new()
  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  let vnode_clusters : Map[String, String] = Map::new()
  { vnode_ranks, vnode_sizes, vnodes_by_rank, edge_vnodes, vnode_clusters }
}

///|
fn single_edge_graph(label : String) -> (@cgraph.Graph, @cgraph.Edge) {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("a")
  let head = graph.node("b")
  let edge = graph.edge(tail, head)
  edge.set_attr("label", label)
  (graph, edge)
}

///|
test "flat_label_adjacent checks neighbor distance inside a rank" {
  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[3] = ["a", "b", "c"]

  assert_true(flat_label_adjacent(3, "a", "b", ordered_groups))
  assert_true(flat_label_adjacent(3, "b", "c", ordered_groups))
  assert_true(flat_label_adjacent(3, "b", "b", ordered_groups))
  assert_false(flat_label_adjacent(3, "a", "c", ordered_groups))
  assert_false(flat_label_adjacent(2, "a", "b", ordered_groups))
  assert_false(flat_label_adjacent(3, "a", "missing", ordered_groups))
}

///|
test "collect_vnode_out_heads follows edge direction after rank normalization" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let up = graph.edge(a, b)
  let down = graph.edge(b, a)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 2
  ranks["b"] = 0

  let up1 = "\{@edge_identity.EDGE_VNODE_PREFIX}u1"
  let up2 = "\{@edge_identity.EDGE_VNODE_PREFIX}u2"
  let down1 = "\{@edge_identity.EDGE_VNODE_PREFIX}d1"
  let down2 = "\{@edge_identity.EDGE_VNODE_PREFIX}d2"
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(up)] = [up1, up2]
  edge_vnodes[@edge_identity.edge_vnode_key(down)] = [down1, down2]

  let out_heads = collect_vnode_out_heads(
    [up, down],
    ["a", "b"],
    ["b", "a"],
    ranks,
    edge_vnodes,
  )

  assert_eq(out_heads.get(up2).unwrap_or([]), [up1])
  assert_eq(out_heads.get(up1).unwrap_or([]), ["b"])
  assert_eq(out_heads.get(down1).unwrap_or([]), [down2])
  assert_eq(out_heads.get(down2).unwrap_or([]), ["a"])
}

///|
test "adjacent flat edge adds one direct constraint without injecting a vnode" {
  let (_graph, edge) = single_edge_graph("adjacent")
  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = ["a", "b"]
  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a", "b"]
  let sizes = make_sizes(["a", "b"], 10.0, 10.0)
  let vnode_info = empty_vnode_info()
  let metrics = match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => value
    None => fail("expected edge label metrics")
  }

  let result = build_flat_label_vnodes_for_positioning(
    [edge],
    ["a"],
    ["b"],
    ranks,
    ordered_groups,
    20.0,
    @rankdir.RankDir::LR,
    sizes,
    Map::new(),
    Map::new(),
    make_existing_names(["a", "b"]),
    vnode_info,
    x_groups,
  )

  assert_eq(result.flat_label_ranks.length(), 0)
  assert_eq(result.flat_label_edge_vnodes.length(), 0)
  assert_eq(result.x_groups.get(0).unwrap_or([]), ["a", "b"])
  assert_eq(result.flat_label_edges.length(), 1)

  let actual = result.flat_label_edges[0]
  let label_width = metrics.height
  let expected_minlen = @numeric.round_int(10.0 + 20.0 + label_width + 1.0)
  assert_eq(actual.tail, "a")
  assert_eq(actual.head, "b")
  assert_eq(actual.minlen, expected_minlen)
  assert_eq(actual.weight, 1)
}

///|
test "adjacent flat edge keeps base minlen when it already exceeds label spacing" {
  let (_graph, edge) = single_edge_graph("wide-gap")
  edge.set_attr("minlen", "5")

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = ["a", "b"]
  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a", "b"]
  let sizes = make_sizes(["a", "b"], 10.0, 10.0)
  let vnode_info = empty_vnode_info()
  let metrics = match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => value
    None => fail("expected edge label metrics")
  }

  let result = build_flat_label_vnodes_for_positioning(
    [edge],
    ["a"],
    ["b"],
    ranks,
    ordered_groups,
    20.0,
    @rankdir.RankDir::TB,
    sizes,
    Map::new(),
    Map::new(),
    make_existing_names(["a", "b"]),
    vnode_info,
    x_groups,
  )

  assert_eq(result.flat_label_ranks.length(), 0)
  assert_eq(result.flat_label_edge_vnodes.length(), 0)
  assert_eq(result.flat_label_edges.length(), 1)

  let actual = result.flat_label_edges[0]
  let label_minlen = @numeric.round_int(10.0 + 20.0 + metrics.width)
  let base_minlen = @numeric.round_int(5.0 * 20.0 + 10.0)
  assert_true(base_minlen > label_minlen)
  assert_eq(actual.tail, "a")
  assert_eq(actual.head, "b")
  assert_eq(actual.minlen, base_minlen)
  assert_eq(actual.weight, 1)
}
