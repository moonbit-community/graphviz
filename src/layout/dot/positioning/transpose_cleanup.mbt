///|
/// Graphviz parity: xpos transpose cleanup inputs keep vnode-expanded edge
/// index sources grouped so both forward/reverse limited transpose passes use
/// the same parent/child snapshots.
pub struct XposTransposeCleanupInput {
  nodes : Array[@cgraph.Node]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
}

///|
pub fn build_xpos_transpose_cleanup_input(
  nodes : Array[@cgraph.Node],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> XposTransposeCleanupInput {
  {
    nodes,
    order_edges,
    order_edge_tail,
    order_edge_head,
    ranks,
    edge_vnodes,
    vnode_ranks,
  }
}

///|
/// Graphviz parity: transpose cleanup performs two limited passes in fixed
/// order (forward then reverse), matching Graphviz fixture behavior.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_xpos_transpose_cleanup(
  x_groups : Map[Int, Array[String]],
  input : XposTransposeCleanupInput,
  max_passes : Int,
) -> Unit {
  let edge_index_data = @ordering.build_edge_index_with_vnodes(
    input.nodes,
    input.order_edges,
    input.order_edge_tail,
    input.order_edge_head,
    input.ranks,
    input.edge_vnodes,
    input.vnode_ranks,
  )
  let parents = edge_index_data.parents
  let children = edge_index_data.children
  let tmp_rank_keys = @ordering.collect_rank_keys(x_groups)
  let tmp_ranks = @ordering.build_node_ranks(x_groups)
  let _ = @ordering.transpose_rank_groups_limited(
    tmp_rank_keys,
    x_groups,
    parents,
    children,
    tmp_ranks,
    false,
    max_passes,
  )
  let _ = @ordering.transpose_rank_groups_limited(
    tmp_rank_keys,
    x_groups,
    parents,
    children,
    tmp_ranks,
    true,
    max_passes,
  )
}
