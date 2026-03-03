///|
/// Graphviz parity: recover_slack consumes vnodes in edge rank direction.
/// Do not change behavior without updating fixtures/tests.
fn ordered_vnodes_for_edge(base : EdgeRouteBase) -> Array[String] {
  if base.tail_rank <= base.head_rank {
    base.vnodes.copy()
  } else {
    let reversed : Array[String] = []
    let mut idx = base.vnodes.length()
    while idx > 0 {
      idx = idx - 1
      reversed.push(base.vnodes[idx])
    }
    reversed
  }
}

///|
/// Graphviz parity: pathplan recover_slack runs with limitBoxes before vnode updates.
/// Do not change behavior without updating fixtures/tests.
pub fn recover_pathplan_slack(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  spline_result : EdgeSplineResult,
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_positions : Map[String, @geom.Point],
  vnode_sizes : Map[String, @dot_shared.NodeSize],
  path_adjacency : @routesplines.PathAdjacency,
  recover_edge_id_by_key : Map[String, Int],
  recovered_slack_keys : Map[String, Bool],
  recover_slack_vnodes : (
    @cgraph.Edge,
    Array[String],
    Array[@geom.Rect],
    Map[String, Int],
    Map[String, Int],
    Map[Int, Double],
    Map[String, @geom.Point],
    Map[String, @dot_shared.NodeSize],
    @routesplines.PathAdjacency,
  ) -> Unit,
) -> Unit {
  if !spline_result.using_pathplan {
    return ()
  }
  let recover_key = recover_slack_key_for_edge(edge)
  match recover_edge_id_by_key.get(recover_key) {
    Some(recover_edge_id) =>
      if recover_edge_id != edge.id() {
        return ()
      }
    None => ()
  }
  if recovered_slack_keys.get(recover_key) is Some(_) {
    return ()
  }
  if spline_result.pathplan_segments.length() > 0 {
    let mut did_recover = false
    // Graphviz parity: straight_path recovers slack per routed segment.
    for segment in spline_result.pathplan_segments {
      if segment.vnodes.length() == 0 || segment.boxes.length() == 0 {
        continue
      }
      let ordered_vnodes =
        if base.tail_rank <= base.head_rank {
          segment.vnodes.copy()
        } else {
          let reversed : Array[String] = []
          let mut idx = segment.vnodes.length()
          while idx > 0 {
            idx = idx - 1
            reversed.push(segment.vnodes[idx])
          }
          reversed
        }
      recover_slack_vnodes(
        edge,
        ordered_vnodes,
        segment.boxes,
        ranks,
        vnode_ranks,
        rank_y,
        vnode_positions,
        vnode_sizes,
        path_adjacency,
      )
      did_recover = true
    }
    if did_recover {
      recovered_slack_keys[recover_key] = true
    }
    return ()
  }
  if spline_result.pathplan_boxes.length() == 0 ||
    spline_result.raw_bezier.length() < 4 {
    return ()
  }
  let limited_boxes =
    @routesplines.limit_boxes_for_spline(
      spline_result.pathplan_boxes,
      spline_result.raw_bezier,
      fallback_polyline=spline_result.pathplan_points,
    )
  let ordered_vnodes = ordered_vnodes_for_edge(base)
  recover_slack_vnodes(
    edge,
    ordered_vnodes,
    limited_boxes,
    ranks,
    vnode_ranks,
    rank_y,
    vnode_positions,
    vnode_sizes,
    path_adjacency,
  )
  recovered_slack_keys[recover_key] = true
}
