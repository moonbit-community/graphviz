///|
fn clone_flat_node(
  graph : @cgraph.Graph,
  original : @cgraph.Node,
) -> @cgraph.Node {
  let node = graph.node(original.name())
  for (name, _) in original.attrs() {
    if original.get_attr_value(name) is Some(value) {
      node.set_attr_value(name, value)
    }
  }
  node
}

///|
fn clone_flat_edge(
  graph : @cgraph.Graph,
  tail : @cgraph.Node,
  head : @cgraph.Node,
  original : @cgraph.Edge,
) -> @cgraph.Edge {
  guard original.tail_port() is Some(tail_port) else {
    guard original.head_port() is Some(head_port) else {
      return graph.edge(tail, head)
    }
    return graph.edge(tail, head, head_port~)
  }
  guard original.head_port() is Some(head_port) else {
    return graph.edge(tail, head, tail_port~)
  }
  graph.edge(tail, head, tail_port~, head_port~)
}

///|
// dotsplines.c make_flat_adj_edges: solve an orthogonal auxiliary graph,
// reposition its ranks to the original horizontal span, then route it.
fn route_flat_adjacent_group(
  parent : @integration.DotRoutingStageInput,
  left : @cgraph.Node,
  right : @cgraph.Node,
  edges : Array[@cgraph.Edge],
  has_defined_ports : (@cgraph.Edge) -> Bool,
) -> Map[Int, @layout_tree.DotLayoutEdge] raise DotLayoutError {
  let flipped = parent.prep.rankdir == RankDir::LR ||
    parent.prep.rankdir == RankDir::RL
  let first = if flipped { right } else { left }
  let second = if flipped { left } else { right }
  let aux = @cgraph.Graph::new(parent.graph.kind(), name="auxg", strict=false)
  for name in ["charset", "dpi", "quantum"] {
    if parent.graph.get_attr_value(name) is Some(value) {
      aux.set_attr_value(name, value)
    }
  }
  for kind in [@cgraph.AttrKind::Node, @cgraph.AttrKind::Edge] {
    for (name, _) in parent.graph.default_attrs(kind) {
      if parent.graph.get_default_attr_value(kind, name) is Some(value) {
        aux.set_default_attr_value(kind, name, value)
      }
    }
  }
  let aux_rankdir = if flipped { RankDir::TB } else { RankDir::LR }
  aux.set_attr("rankdir", if flipped { "TB" } else { "LR" })
  let source = aux.subgraph(name="xxx")
  source.set_attr("rank", "source")
  let aux_tail = clone_flat_node(source, first)
  let aux_head = clone_flat_node(aux, second)
  let originals : Map[Int, @cgraph.Edge] = Map([])
  let mut heavy : @cgraph.Edge? = None
  for edge in edges {
    let forward = edge.tail().name() == first.name()
    let clone = clone_flat_edge(
      aux,
      if forward {
        aux_tail
      } else {
        aux_head
      },
      if forward {
        aux_head
      } else {
        aux_tail
      },
      edge,
    )
    for (name, _) in edge.attrs() {
      if edge.get_attr_value(name) is Some(value) {
        clone.set_attr_value(name, value)
      }
    }
    originals[clone.id()] = edge
    if heavy is None && !has_defined_ports(edge) {
      heavy = Some(clone)
    }
  }
  let heavy = heavy.unwrap_or_else(() => aux.edge(aux_tail, aux_head))
  heavy.set_attr("weight", "10000")
  @label_layout.reset_label_caches()
  let prep = match
    @input_stage.prepare_layout_prep(aux, {
      rankdir: Some(aux_rankdir),
      nodesep: Some(parent.prep.nodesep_in),
      ranksep: Some(parent.prep.ranksep_in),
      splines: Some(parent.prep.splines),
    }) {
    Ok(prep) => prep
    Err(message) => raise DotLayoutError::InvalidGraph(message~)
  }
  let stage = @rank_stage.compute_dot_rank_stage({ graph: aux, prep, })
  let positioned = @positioning.compute_positions({
    graph: aux,
    prep,
    rank_data: stage.rank_data,
    rank_heights: stage.rank_heights,
    cluster_meta: stage.cluster_meta,
    ordering: stage.ordering,
  })
  let left_pos = parent.positions_state.positions[left.name()]
  let right_pos = parent.positions_state.positions[right.name()]
  let first_pos = parent.positions_state.positions[first.name()]
  let second_pos = parent.positions_state.positions[second.name()]
  let first_size = parent.prep.sizes[first.name()]
  let second_size = parent.prep.sizes[second.name()]
  let middle_rank_y = (
      first_pos.x - first_size.right_pt + second_pos.x + second_size.left_pt
    ) /
    2.0
  let middle_x = (
      positioned.positions[first.name()].x +
      positioned.positions[second.name()].x
    ) /
    2.0
  let positions = positioned.positions.copy()
  positions[first.name()] = { x: middle_x, y: right_pos.x, }
  positions[second.name()] = { x: middle_x, y: left_pos.x, }
  let vnode_positions = positioned.vnode_positions.map((_, value) => {
    ..value,
    y: middle_rank_y,
  })
  let rank_y = positioned.rank_y.copy()
  for rank, _ in rank_y {
    rank_y[rank] = middle_rank_y
  }
  rank_y[stage.rank_data.ranks[first.name()]] = right_pos.x
  rank_y[stage.rank_data.ranks[second.name()]] = left_pos.x
  let routing = @integration.compute_dot_routing_stage({
    graph: aux,
    prep,
    rank_data: stage.rank_data,
    rank_heights: stage.rank_heights,
    cluster_meta: stage.cluster_meta,
    ordering: stage.ordering,
    positions_state: { ..positioned, positions, vnode_positions, rank_y, },
  })
  let transform : (@geom.Point) -> @geom.Point = p => {
    if flipped {
      { x: p.y, y: first_pos.y + middle_x - p.x, }
    } else {
      { x: left_pos.x + right_pos.x - p.y, y: first_pos.y + p.x - middle_x, }
    }
  }
  let output : Map[Int, @layout_tree.DotLayoutEdge] = Map([])
  for routed in routing.edges_out {
    guard originals.get(routed.edge.id()) is Some(original) else { continue }
    output[original.id()] = {
      edge: original,
      splines: routed.splines.map(spline => {
        start: spline.start.map(transform),
        end: spline.end.map(transform),
        points: spline.points.map(transform),
      }),
      label_pos: routed.label_pos.map(transform),
      head_label_pos: routed.head_label_pos.map(transform),
      tail_label_pos: routed.tail_label_pos.map(transform),
      xlabel_pos: routed.xlabel_pos.map(transform),
    }
  }
  @label_layout.reset_label_caches()
  output
}

///|
fn route_flat_adjacent_ports(
  input : @integration.DotRoutingStageInput,
  output : @integration.DotRoutingStageOutput,
) -> @integration.DotRoutingStageOutput raise DotLayoutError {
  guard input.prep.has_port_edges else { return output }
  guard input.prep.splines == @layout_prep.SplinesMode::Spline ||
    input.prep.splines == @layout_prep.SplinesMode::Polyline else {
    return output
  }
  let ports_equal = @position_ports.build_initial_node_port_comparator(
    input.prep.nodes,
    input.prep.output_sizes,
  )
  let has_defined_ports = (edge : @cgraph.Edge) => {
    !ports_equal(edge.tail(), edge.tail_port(), None) ||
    !ports_equal(edge.head(), edge.head_port(), None)
  }
  let adjacency : Map[(String, String), Bool] = Map([])
  for _, names in input.positions_state.x_groups {
    for i = 1; i < names.length(); i = i + 1 {
      adjacency[(names[i - 1], names[i])] = true
    }
  }
  let groups : Map[(String, String), Array[@cgraph.Edge]] = Map([])
  for edge in input.prep.edges {
    let tail = edge.tail()
    let head = edge.head()
    guard !@record_geometry.is_record_shape(tail) &&
      !@record_geometry.is_record_shape(head) else {
      continue
    }
    let pair = if adjacency.get((tail.name(), head.name())) is Some(_) {
      (tail.name(), head.name())
    } else {
      guard adjacency.get((head.name(), tail.name())) is Some(_) else {
        continue
      }
      (head.name(), tail.name())
    }
    let group = groups
      .get(pair)
      .unwrap_or_else(() => {
        let group = []
        groups[pair] = group
        group
      })
    group.push(edge)
  }
  let replacements : Map[Int, @layout_tree.DotLayoutEdge] = Map([])
  for (left, right), edges in groups {
    guard edges.any(has_defined_ports) else { continue }
    let routed = route_flat_adjacent_group(
      input,
      input.graph.node(left),
      input.graph.node(right),
      edges,
      has_defined_ports,
    )
    for id, edge in routed {
      replacements[id] = edge
    }
  }
  {
    ..output,
    edges_out: output.edges_out.map(edge => {
      replacements.get(edge.edge.id()).unwrap_or(edge)
    }),
  }
}
