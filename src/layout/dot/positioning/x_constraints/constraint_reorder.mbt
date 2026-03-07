///|
/// Graphviz parity: GD_nlist after create_aux_edges prepends slack nodes in
/// reverse creation order, then preserves GD_nlist order for existing nodes.
pub(all) struct ConstraintReorderInput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
  nlist_order : Array[String]
}

///|
/// Graphviz parity: order mirrors position.c's auxiliary-graph sweep and keeps
/// slack helper nodes ahead of non-slack constraints.
fn build_constraint_reorder(input : ConstraintReorderInput) -> Array[Int] {
  let total = input.graph.nodes.length()
  let order : Array[Int] = []
  if total == 0 {
    return order
  }
  let seen : Array[Bool] = []
  for _ in 0..<total {
    seen.push(false)
  }
  let slack_indices : Array[Int] = []
  for i in 0..<total {
    if input.graph.nodes[i].kind == @network_simplex.NodeKind::Slack {
      slack_indices.push(i)
    }
  }
  let mut slack_idx = slack_indices.length()
  while slack_idx > 0 {
    slack_idx = slack_idx - 1
    let node_idx = slack_indices[slack_idx]
    order.push(node_idx)
    seen[node_idx] = true
  }
  let mut nlist_idx = input.nlist_order.length()
  while nlist_idx > 0 {
    nlist_idx = nlist_idx - 1
    let name = input.nlist_order[nlist_idx]
    match input.index.get(name) {
      Some(node_idx) =>
        if !seen[node_idx] {
          order.push(node_idx)
          seen[node_idx] = true
        }
      None => ()
    }
  }
  for i in 0..<total {
    if !seen[i] {
      order.push(i)
      seen[i] = true
    }
  }
  order
}

///|
pub(all) struct ReorderConstraintGraphInput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
  order : Array[Int]
}

///|
pub(all) struct ReorderConstraintGraphOutput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
}

///|
/// Graphviz parity: preserves node rank values while rewriting node ids to the
/// computed order vector consumed by network simplex.
fn reorder_constraint_graph(
  input : ReorderConstraintGraphInput,
) -> ReorderConstraintGraphOutput {
  let total = input.graph.nodes.length()
  if total == 0 || input.order.length() != total {
    return { graph: input.graph, index: input.index }
  }
  let new_graph = @network_simplex.new_graph()
  let old_to_new : Array[Int] = []
  for _ in 0..<total {
    old_to_new.push(-1)
  }
  for old_idx in input.order {
    let node = input.graph.nodes[old_idx]
    let new_idx = @network_simplex.add_node(new_graph, "", kind=node.kind)
    @network_simplex.set_node_rank(new_graph, new_idx, node.rank)
    old_to_new[old_idx] = new_idx
  }
  for edge in input.graph.edges {
    let tail = old_to_new[edge.tail]
    let head = old_to_new[edge.head]
    let _ = @network_simplex.add_edge(new_graph, tail, head, edge.minlen, edge.weight)
  }
  let new_index : Map[String, Int] = Map::new()
  for name, old_idx in input.index {
    let new_idx = old_to_new[old_idx]
    new_index[name] = new_idx
  }
  { graph: new_graph, index: new_index }
}
