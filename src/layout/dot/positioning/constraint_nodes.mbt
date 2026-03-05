///|
priv struct ConstraintNodeSeed {
  real_by_name : Map[String, @cgraph.Node]
  extra_rank : Map[String, Int]
  late_extra_nodes : Array[@ordering.ExtraConstraintNode]
}

///|
fn build_constraint_node_seed(
  nodes : Array[@cgraph.Node],
  extra_nodes : Array[@ordering.ExtraConstraintNode],
) -> ConstraintNodeSeed {
  let early_extra_nodes : Array[@ordering.ExtraConstraintNode] = []
  let late_extra_nodes : Array[@ordering.ExtraConstraintNode] = []
  for extra_node in extra_nodes {
    if @clustering.is_cluster_boundary_name(extra_node.name) {
      late_extra_nodes.push(extra_node)
    } else {
      early_extra_nodes.push(extra_node)
    }
  }
  let real_by_name : Map[String, @cgraph.Node] = Map::new()
  for node in nodes {
    real_by_name[node.name()] = node
  }
  let extra_rank : Map[String, Int] = Map::new()
  for extra_node in early_extra_nodes {
    extra_rank[extra_node.name] = extra_node.rank
  }
  { real_by_name, extra_rank, late_extra_nodes }
}

///|
fn build_constraint_ordered_names(
  nodes : Array[@cgraph.Node],
  nlist_order : Array[String],
  real_by_name : Map[String, @cgraph.Node],
  extra_rank : Map[String, Int],
) -> Array[String] {
  let ordered_names : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for name in nlist_order {
    if real_by_name.get(name) is Some(_) || extra_rank.get(name) is Some(_) {
      if seen.get(name) is None {
        ordered_names.push(name)
        seen[name] = true
      }
    }
  }
  for node in nodes {
    let name = node.name()
    if seen.get(name) is None {
      ordered_names.push(name)
      seen[name] = true
    }
  }
  for name, _rank in extra_rank {
    if seen.get(name) is None {
      ordered_names.push(name)
      seen[name] = true
    }
  }
  ordered_names
}

///|
pub fn constraint_node_kind(name : String) -> @network_simplex.NodeKind {
  if @shared.is_edge_vnode_name(name) {
    @network_simplex.NodeKind::Virtual
  } else if @clustering.is_cluster_boundary_name(name) {
    @network_simplex.NodeKind::Slack
  } else {
    @network_simplex.NodeKind::Normal
  }
}

///|
fn add_ordered_constraint_nodes(
  graph : @network_simplex.NsGraph,
  index : Map[String, Int],
  ordered_names : Array[String],
  real_by_name : Map[String, @cgraph.Node],
  extra_rank : Map[String, Int],
  base_positions : Map[String, Double],
  trunc_int : (Double) -> Int,
) -> Unit {
  for name in ordered_names {
    match real_by_name.get(name) {
      Some(node) => {
        let idx = @network_simplex.add_node(graph, node.name())
        index[name] = idx
        let pos = base_positions.get(name).unwrap_or_default()
        @network_simplex.set_node_rank(graph, idx, trunc_int(pos))
      }
      None =>
        match extra_rank.get(name) {
          Some(rank) => {
            let idx = @network_simplex.add_node(graph, name, kind=constraint_node_kind(name))
            index[name] = idx
            let pos = base_positions.get(name).unwrap_or(rank.to_double())
            @network_simplex.set_node_rank(graph, idx, trunc_int(pos))
          }
          None => ()
        }
    }
  }
}

///|
/// Graphviz parity: constraint-node setup preserves GD_nlist-preferred node
/// insertion order, then appends missing real nodes and early aux nodes.
pub(all) struct ConstraintNodesSetupInput {
  graph : @network_simplex.NsGraph
  nodes : Array[@cgraph.Node]
  extra_nodes : Array[@ordering.ExtraConstraintNode]
  nlist_order : Array[String]
  base_positions : Map[String, Double]
  trunc_int : (Double) -> Int
}

///|
/// Graphviz parity: cluster boundary helpers remain late-boundary nodes while
/// all other aux nodes are materialized in the initial constraint index.
pub(all) struct ConstraintNodesSetupOutput {
  index : Map[String, Int]
  real_by_name : Map[String, @cgraph.Node]
  late_extra_nodes : Array[@ordering.ExtraConstraintNode]
}

///|
pub fn build_constraint_nodes_setup(
  input : ConstraintNodesSetupInput,
) -> ConstraintNodesSetupOutput {
  let seed = build_constraint_node_seed(input.nodes, input.extra_nodes)
  let ordered_names =
    build_constraint_ordered_names(
      input.nodes,
      input.nlist_order,
      seed.real_by_name,
      seed.extra_rank,
    )
  let index : Map[String, Int] = Map::new()
  add_ordered_constraint_nodes(
    input.graph,
    index,
    ordered_names,
    seed.real_by_name,
    seed.extra_rank,
    input.base_positions,
    input.trunc_int,
  )
  {
    index,
    real_by_name: seed.real_by_name,
    late_extra_nodes: seed.late_extra_nodes,
  }
}

///|
pub(all) struct LateConstraintNodesInput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
  late_extra_nodes : Array[@ordering.ExtraConstraintNode]
}

///|
/// Graphviz parity: cluster boundary helpers enter the aux graph at rank 0
/// and are later positioned by constraints, not by seed x ranks.
pub fn append_late_constraint_nodes(input : LateConstraintNodesInput) -> Unit {
  for extra_node in input.late_extra_nodes {
    let idx = @network_simplex.add_node(
      input.graph,
      extra_node.name,
      kind=constraint_node_kind(extra_node.name),
    )
    input.index[extra_node.name] = idx
    @network_simplex.set_node_rank(input.graph, idx, 0)
  }
}
