///|
fn assert_point_close(
  actual : @geom.Point?,
  expected : @geom.Point,
  eps? : Double = 0.000001,
) -> Unit raise {
  match actual {
    Some(value) => {
      assert_true(Double::is_close(value.x, expected.x, absolute_tolerance=eps))
      assert_true(Double::is_close(value.y, expected.y, absolute_tolerance=eps))
    }
    None => fail("expected point")
  }
}

///|
test "compute_nodes_bbox ignores nodes missing geometry and returns none when empty" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  ignore(a)
  ignore(b)

  let positions : Map[String, @geom.Point] = Map::new()
  positions["a"] = { x: 10.0, y: 20.0 }
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.node_size_from_points(8.0, 6.0)

  assert_eq(
    compute_nodes_bbox(graph, positions, sizes),
    Some({ llx: 6.0, lly: 17.0, urx: 14.0, ury: 23.0 }),
  )

  let empty_graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  assert_true(compute_nodes_bbox(empty_graph, Map::new(), Map::new()) is None)
}

///|
test "adjust_cluster_positions rounds cluster x bounds and shifts member nodes and vnodes" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  let a = cluster.node("a")
  ignore(a)

  let positions : Map[String, @geom.Point] = Map::new()
  positions["a"] = { x: 5.2, y: 5.0 }
  let vnode_positions : Map[String, @geom.Point] = Map::new()
  vnode_positions["v_cluster"] = { x: 8.0, y: 5.0 }
  vnode_positions["v_other"] = { x: 30.0, y: 5.0 }
  let vnode_clusters : Map[String, String] = Map::new()
  vnode_clusters["v_cluster"] = "cluster_0"
  vnode_clusters["v_other"] = "cluster_other"
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.node_size_from_points(10.0, 4.0)

  let bbox = adjust_cluster_positions({
    graph: cluster,
    positions,
    vnode_positions,
    vnode_clusters,
    sizes,
    cluster_margin_pt_for: _graph => 0.0,
    expand_cluster_label_bbox: (_graph, rect) => rect,
  })

  assert_eq(bbox, Some({ llx: 0.0, lly: 3.0, urx: 10.0, ury: 7.0 }))
  assert_point_close(positions.get("a"), { x: 5.0, y: 5.0 })
  assert_point_close(vnode_positions.get("v_cluster"), { x: 7.8, y: 5.0 })
  assert_point_close(vnode_positions.get("v_other"), { x: 30.0, y: 5.0 })
}

///|
test "adjust_cluster_positions merges child cluster bounds into the root bbox" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let root_node = root.node("root_node")
  let cluster = root.subgraph(name="cluster_0")
  let child_node = cluster.node("child_node")
  ignore(root_node)
  ignore(child_node)

  let positions : Map[String, @geom.Point] = Map::new()
  positions["root_node"] = { x: 20.0, y: 5.0 }
  positions["child_node"] = { x: 5.2, y: 5.0 }
  let vnode_positions : Map[String, @geom.Point] = Map::new()
  let vnode_clusters : Map[String, String] = Map::new()
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["root_node"] = @node_primitives.node_size_from_points(4.0, 4.0)
  sizes["child_node"] = @node_primitives.node_size_from_points(10.0, 4.0)

  let bbox = adjust_cluster_positions({
    graph: root,
    positions,
    vnode_positions,
    vnode_clusters,
    sizes,
    cluster_margin_pt_for: _graph => 0.0,
    expand_cluster_label_bbox: (_graph, rect) => rect,
  })

  assert_eq(bbox, Some({ llx: 0.0, lly: 3.0, urx: 22.0, ury: 7.0 }))
  assert_point_close(positions.get("root_node"), { x: 20.0, y: 5.0 })
  assert_point_close(positions.get("child_node"), { x: 5.0, y: 5.0 })
}
