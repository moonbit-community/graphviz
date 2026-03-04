///|
/// Stage C Phase C2 split: seeded-group,
/// and early reorder-input materialization helpers.

///|
/// Graphviz parity: build_ranks seeding runs component-scoped ordering first,
/// then applies transpose when crossings remain (port-offset aware tie-breaks).
/// Do not change behavior without updating fixtures/tests.
fn build_seeded_reorder_groups(
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  order_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> Map[Int, Array[String]] {
  // Graphviz parity: seed build_ranks from component-scoped walk,
  // matching decompose/install traversal used by remincross with
  // cluster-expanded flat constraints.
  let seed_pass =
    if @sys.get_env_var("DOT_SEED_PASS1") is Some(_) { 1 } else { 0 }
  let seeded_groups = build_component_rank_groups(
    order_rank_keys,
    order_groups,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    order_node_order,
    order_cluster_keys,
    order_cluster_skeleton,
    seed_pass,
    order_flat_constraints,
    flip=graphviz_flip,
    graphviz_out_neighbors=graphviz_out_neighbors,
    graphviz_in_neighbors=graphviz_in_neighbors,
  )
  // Graphviz parity: build_ranks applies transpose if crossings remain;
  // crossing count uses endpoint port x offsets for tie-correct ordering.
  let seed_cross = @ordering.count_crossings_port_aware(
    seeded_groups,
    order_ranks,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    edge_tail_port_x=order_edge_tail_port_x,
    edge_head_port_x=order_edge_head_port_x,
  )
  if seed_cross > 0 {
    let transpose_seed_maps =
      @ordering.build_transpose_seed_maps(
        order_rank_keys,
        seeded_groups,
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
        order_ranks,
      )
    let _ = transpose_rank_groups_port(
      order_rank_keys,
      seeded_groups,
      order_ranks,
      transpose_seed_maps.edge_in,
      transpose_seed_maps.edge_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      transpose_seed_maps.edge_penalty,
      order_cluster_keys,
      order_cluster_skeleton,
      flat_rank_constraints,
      false,
      0,
    )
  }
  seeded_groups
}
