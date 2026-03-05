///|
fn edge_attr_non_empty(edge : @cgraph.Edge, name : String) -> Bool {
  match edge.get_attr(name) {
    Some(value) => value != ""
    None => false
  }
}

///|
priv struct PortLabelPosRemapInput {
  edge : @cgraph.Edge
  splines : Array[@geom.Spline]
  label_attr : String
  is_head : Bool
  fallback : @geom.Point?
  edge_port_label_pos_fn : (@cgraph.Edge, @geom.Spline, Bool) -> @geom.Point?
}

///|
fn remap_port_label_pos(
  input : PortLabelPosRemapInput,
) -> @geom.Point? {
  let edge = input.edge
  let splines = input.splines
  let label_attr = input.label_attr
  let is_head = input.is_head
  let fallback = input.fallback
  let edge_port_label_pos_fn = input.edge_port_label_pos_fn
  if !edge_attr_non_empty(edge, label_attr) {
    return None
  }
  if splines.length() == 0 {
    return fallback
  }
  let spline =
    if is_head {
      splines[splines.length() - 1]
    } else {
      splines[0]
    }
  match edge_port_label_pos_fn(edge, spline, is_head) {
    Some(pos) => Some(pos)
    None => fallback
  }
}

///|
/// Graphviz parity: routed edge output stays in original edge iteration order.
/// Do not change behavior without updating fixtures/tests.
fn collect_input_order_edge_ids(
  edges : Array[@cgraph.Edge],
  has_layout : (Int) -> Bool,
) -> Array[Int] {
  let ordered_ids : Array[Int] = []
  for edge in edges {
    let edge_id = edge.id()
    if has_layout(edge_id) {
      ordered_ids.push(edge_id)
    }
  }
  ordered_ids
}

///|
fn remap_edge_layout_edge(
  edge : @cgraph.Edge,
  layout : DotLayoutEdge,
  edge_port_label_pos_fn : (@cgraph.Edge, @geom.Spline, Bool) -> @geom.Point?,
) -> DotLayoutEdge {
  let label_pos =
    if edge_attr_non_empty(edge, "label") {
      layout.label_pos
    } else {
      None
    }
  let head_label_pos = remap_port_label_pos(
    {
      edge,
      splines: layout.splines,
      label_attr: "headlabel",
      is_head: true,
      fallback: layout.head_label_pos,
      edge_port_label_pos_fn,
    },
  )
  let tail_label_pos = remap_port_label_pos(
    {
      edge,
      splines: layout.splines,
      label_attr: "taillabel",
      is_head: false,
      fallback: layout.tail_label_pos,
      edge_port_label_pos_fn,
    },
  )
  let xlabel_pos =
    if edge_attr_non_empty(edge, "xlabel") {
      layout.xlabel_pos
    } else {
      None
    }
  {
    edge,
    splines: layout.splines,
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos,
  }
}

///|
/// Graphviz parity: duplicate regular-edge remap groups follow one-direction
/// parallel classes only.
/// Do not change behavior without updating fixtures/tests.
fn collect_parallel_remap_edge_ids(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
) -> Array[Array[Int]] {
  let groups : Map[String, Array[Int]] = Map::new()
  let group_first_direction : Map[String, String] = Map::new()
  let group_has_mixed_direction : Map[String, Bool] = Map::new()
  for edge in edges {
    if edge_has_label(edge) {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      continue
    }
    let tail_rank = ranks.get(tail).unwrap_or_default()
    let head_rank = ranks.get(head).unwrap_or_default()
    if tail_rank == head_rank {
      continue
    }
    let key = @edge_ops.edge_parallel_group_key(edge)
    let sameport_mark = @edge_ops.edge_has_sameport_mark(edge)
    let dir_key = match edge.get_attr("dir") {
      Some(value) => value.to_lower()
      None => "forward"
    }
    let sameport_tag = if sameport_mark { "sameport" } else { "plain" }
    let direction_key =
      "\{tail}|\{@dot_shared.port_key(edge.tail_port())}|\{head}|\{@dot_shared.port_key(edge.head_port())}|\{dir_key}|\{sameport_tag}"
    match groups.get(key) {
      Some(list) => list.push(edge.id())
      None => groups[key] = [edge.id()]
    }
    match group_first_direction.get(key) {
      Some(first_direction) =>
        if first_direction != direction_key {
          group_has_mixed_direction[key] = true
        }
      None => {
        group_first_direction[key] = direction_key
        group_has_mixed_direction[key] = false
      }
    }
  }
  let remap_groups : Array[Array[Int]] = []
  for key, ids in groups {
    if ids.length() <= 1 {
      continue
    }
    let mixed_direction = match group_has_mixed_direction.get(key) {
      Some(value) => value
      None => false
    }
    if mixed_direction {
      continue
    }
    ids.sort()
    remap_groups.push(ids)
  }
  remap_groups
}

///|
/// Graphviz parity: remap groups are applied only when all grouped ids already
/// have routed layouts.
/// Do not change behavior without updating fixtures/tests.
fn collect_complete_parallel_remap_groups(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  has_layout : (Int) -> Bool,
) -> Array[Array[Int]] {
  let complete_groups : Array[Array[Int]] = []
  for ids in collect_parallel_remap_edge_ids(edges, ranks) {
    let mut all_present = true
    for edge_id in ids {
      if !has_layout(edge_id) {
        all_present = false
        break
      }
    }
    if all_present {
      complete_groups.push(ids)
    }
  }
  complete_groups
}

///|
priv struct ParallelRemapAssignment {
  target_edge_id : Int
  source_edge_id : Int
}

///|
/// Graphviz parity: each parallel remap group applies reversed source slots
/// to ascending target ids.
/// Do not change behavior without updating fixtures/tests.
fn build_parallel_remap_assignments(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  has_layout : (Int) -> Bool,
) -> Array[ParallelRemapAssignment] {
  let assignments : Array[ParallelRemapAssignment] = []
  for ids in collect_complete_parallel_remap_groups(edges, ranks, has_layout) {
    let mut out_idx = 0
    let mut src_idx = ids.length()
    while out_idx < ids.length() {
      src_idx = src_idx - 1
      assignments.push({
        target_edge_id: ids[out_idx],
        source_edge_id: ids[src_idx],
      })
      out_idx = out_idx + 1
    }
  }
  assignments
}

///|
/// Graphviz parity: duplicate regular-edge spline slots are assigned in
/// pair order after routing, but only within one-direction parallel classes.
/// Do not change behavior without updating fixtures/tests.
fn remap_parallel_edge_layouts(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  edges_out_by_id : Map[Int, DotLayoutEdge],
  edge_port_label_pos_fn : (@cgraph.Edge, @geom.Spline, Bool) -> @geom.Point?,
) -> Unit {
  let assignments =
    build_parallel_remap_assignments(
      edges,
      ranks,
      (edge_id) => edges_out_by_id.get(edge_id) is Some(_),
    )
  let remap_snapshot : Map[Int, DotLayoutEdge] = Map::new()
  for assignment in assignments {
    match edges_out_by_id.get(assignment.target_edge_id) {
      Some(layout) => remap_snapshot[assignment.target_edge_id] = layout
      None => ()
    }
    match edges_out_by_id.get(assignment.source_edge_id) {
      Some(layout) => remap_snapshot[assignment.source_edge_id] = layout
      None => ()
    }
  }
  for assignment in assignments {
    let target_layout = match remap_snapshot.get(assignment.target_edge_id) {
      Some(value) => value
      None => continue
    }
    let source_layout = match remap_snapshot.get(assignment.source_edge_id) {
      Some(value) => value
      None => continue
    }
    edges_out_by_id[assignment.target_edge_id] =
      remap_edge_layout_edge(
        target_layout.edge,
        source_layout,
        edge_port_label_pos_fn,
      )
  }
}

///|
/// Graphviz parity: final routed edge output keeps remap-then-input-order flow.
/// Do not change behavior without updating fixtures/tests.
pub fn finalize_routed_edges(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  edges_out_by_id : Map[Int, DotLayoutEdge],
  edge_port_label_pos_fn : (@cgraph.Edge, @geom.Spline, Bool) -> @geom.Point?,
) -> Array[DotLayoutEdge] {
  remap_parallel_edge_layouts(
    edges,
    ranks,
    edges_out_by_id,
    edge_port_label_pos_fn,
  )
  let ordered_output_edge_ids =
    collect_input_order_edge_ids(
      edges,
      (edge_id) => edges_out_by_id.get(edge_id) is Some(_),
    )
  let edges_out : Array[DotLayoutEdge] = []
  for edge_id in ordered_output_edge_ids {
    match edges_out_by_id.get(edge_id) {
      Some(value) => edges_out.push(value)
      None => ()
    }
  }
  edges_out
}
///|
