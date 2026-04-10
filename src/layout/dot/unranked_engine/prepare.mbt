// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Shared entry/prep helpers for unranked engines: prune handling, graph
/// cloning, neato validation, and the public neato/noop prepare entry points.
/// Geometry parsing, neato solve, and layout-tree assembly live in
/// package-local owner files.
fn prune_keep_set(graph : @cgraph.Graph) -> Map[String, Bool] {
  let nodes = graph.nodes()
  let degree : Map[String, Int] = Map::new()
  let neighbors : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    degree[name] = 0
    neighbors[name] = []
  }
  for edge in graph.edges() {
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      let current = match degree.get(tail) {
        Some(value) => value
        None => 0
      }
      degree[tail] = current + 2
      continue
    }
    let tail_degree = match degree.get(tail) {
      Some(value) => value
      None => 0
    }
    degree[tail] = tail_degree + 1
    let head_degree = match degree.get(head) {
      Some(value) => value
      None => 0
    }
    degree[head] = head_degree + 1
    let tail_neighbors = match neighbors.get(tail) {
      Some(value) => value
      None => []
    }
    tail_neighbors.push(head)
    neighbors[tail] = tail_neighbors
    let head_neighbors = match neighbors.get(head) {
      Some(value) => value
      None => []
    }
    head_neighbors.push(tail)
    neighbors[head] = head_neighbors
  }
  let removed : Map[String, Bool] = Map::new()
  let queue : Array[String] = []
  for node in nodes {
    let name = node.name()
    let node_degree = match degree.get(name) {
      Some(value) => value
      None => 0
    }
    if node_degree <= 1 {
      queue.push(name)
    }
  }
  while queue.length() > 0 {
    let name = queue[queue.length() - 1]
    ignore(queue.pop())
    if removed.get(name) is Some(_) {
      continue
    }
    removed[name] = true
    let adjacent = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    for next in adjacent {
      if removed.get(next) is Some(_) {
        continue
      }
      let node_degree = match degree.get(next) {
        Some(value) => value
        None => 0
      }
      let reduced = node_degree - 1
      degree[next] = reduced
      if reduced <= 1 {
        queue.push(next)
      }
    }
  }
  let keep : Map[String, Bool] = Map::new()
  for node in nodes {
    let name = node.name()
    if removed.get(name) is None {
      keep[name] = true
    }
  }
  keep
}

///|
fn clone_edge_with_optional_name_ports(
  graph : @cgraph.Graph,
  tail : @cgraph.Node,
  head : @cgraph.Node,
  name : String?,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
) -> @cgraph.Edge {
  match name {
    Some(label) =>
      match (tail_port, head_port) {
        (Some(tail_value), Some(head_value)) =>
          graph.edge(
            tail,
            head,
            name=label,
            tail_port=tail_value,
            head_port=head_value,
          )
        (Some(tail_value), None) =>
          graph.edge(tail, head, name=label, tail_port=tail_value)
        (None, Some(head_value)) =>
          graph.edge(tail, head, name=label, head_port=head_value)
        (None, None) => graph.edge(tail, head, name=label)
      }
    None =>
      match (tail_port, head_port) {
        (Some(tail_value), Some(head_value)) =>
          graph.edge(tail, head, tail_port=tail_value, head_port=head_value)
        (Some(tail_value), None) => graph.edge(tail, head, tail_port=tail_value)
        (None, Some(head_value)) => graph.edge(tail, head, head_port=head_value)
        (None, None) => graph.edge(tail, head)
      }
  }
}

///|
fn copy_graph_attrs_and_defaults(
  source : @cgraph.Graph,
  target : @cgraph.Graph,
) -> Unit {
  for pair in source.attrs() {
    let (key, value) = pair
    target.set_attr(key, value)
  }
  for pair in source.default_attrs(@cgraph.AttrKind::Graph) {
    let (key, value) = pair
    target.set_default_attr(@cgraph.AttrKind::Graph, key, value)
  }
  for pair in source.default_attrs(@cgraph.AttrKind::Node) {
    let (key, value) = pair
    target.set_default_attr(@cgraph.AttrKind::Node, key, value)
  }
  for pair in source.default_attrs(@cgraph.AttrKind::Edge) {
    let (key, value) = pair
    target.set_default_attr(@cgraph.AttrKind::Edge, key, value)
  }
}

///|
fn clone_pruned_graph(
  graph : @cgraph.Graph,
  keep : Map[String, Bool],
) -> @cgraph.Graph {
  let cloned = match graph.name() {
    Some(name) =>
      @cgraph.Graph::new(graph.kind(), name~, strict=graph.is_strict())
    None => @cgraph.Graph::new(graph.kind(), strict=graph.is_strict())
  }
  copy_graph_attrs_and_defaults(graph, cloned)
  for node in graph.nodes() {
    let name = node.name()
    if keep.get(name) is None {
      continue
    }
    let new_node = cloned.node(name)
    for pair in node.attrs() {
      let (key, value) = pair
      new_node.set_attr(key, value)
    }
  }
  for edge in graph.edges() {
    let tail = edge.tail()
    let head = edge.head()
    let tail_name = tail.name()
    let head_name = head.name()
    if keep.get(tail_name) is None || keep.get(head_name) is None {
      continue
    }
    let new_tail = cloned.node(tail_name)
    let new_head = cloned.node(head_name)
    let new_edge = clone_edge_with_optional_name_ports(
      cloned,
      new_tail,
      new_head,
      edge.name(),
      edge.tail_port(),
      edge.head_port(),
    )
    for pair in edge.attrs() {
      let (key, value) = pair
      new_edge.set_attr(key, value)
    }
  }
  cloned
}

///|
fn active_graph_for_prune(graph : @cgraph.Graph, prune : Bool) -> @cgraph.Graph {
  if prune {
    let keep = prune_keep_set(graph)
    clone_pruned_graph(graph, keep)
  } else {
    graph
  }
}

///|
fn neato_nodesep_pt(graph : @cgraph.Graph) -> Double {
  let nodesep_in = match graph.get_attr("nodesep") {
    Some(value) =>
      @numeric.parse_double_or(value, @input_stage.DEFAULT_NODESEP_IN)
    None => @input_stage.DEFAULT_NODESEP_IN
  }
  nodesep_in * 72.0
}

///|
fn validate_neato_edge_lengths(graph : @cgraph.Graph) -> Result[Unit, String] {
  for edge in graph.edges() {
    match edge.get_attr("len") {
      Some(value) =>
        if @numeric.parse_first_double(value, 0.0) < 0.0 {
          return Err(
            "edge \{edge.tail().name()} -> \{edge.head().name()} has negative len: \{value}",
          )
        }
      None => ()
    }
  }
  Ok(())
}

///|
/// Graphviz parity: unranked neato entry prep keeps prune, shared graph
/// validation, len validation, and default nodesep resolution with the owning
/// unranked engine package so the root API boundary stays thin.
pub fn prepare_neato_layout_tree(
  graph : @cgraph.Graph,
  scale : Double,
  prune : Bool,
) -> Result[LayoutTree, String] {
  let active_graph = active_graph_for_prune(graph, prune)
  match @input_stage.validate_layout_graph(active_graph) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match validate_neato_edge_lengths(active_graph) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(
    build_neato_layout_tree(active_graph, scale, neato_nodesep_pt(active_graph)),
  )
}

///|
/// Graphviz parity: noop entry prep keeps prune handling with the owning
/// unranked engine package before fixed-position layout-tree assembly.
pub fn prepare_noop_layout_tree(
  graph : @cgraph.Graph,
  no_op_level : Int,
  scale : Double,
  prune : Bool,
) -> Result[LayoutTree, String] {
  let active_graph = active_graph_for_prune(graph, prune)
  build_noop_layout_tree(active_graph, no_op_level, scale)
}
