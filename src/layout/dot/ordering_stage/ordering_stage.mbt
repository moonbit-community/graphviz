///|
type RankDir = @rankdir.RankDir
type NodeSize = @node_primitives.NodeSize
type ClusterMetadata = @ordering.DotClusterMetadata

///|
/// Graphviz parity: ordering stage payload keeps rank and order-context maps
/// grouped so Stage C wiring stays explicit and stable.
pub(all) struct OrderingStageInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  rankdir : RankDir
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
type OrderingResult = @ordering.OrderingResult

///|
/// Graphviz parity: ordering stage output keeps cluster metadata and final
/// ordering snapshots paired so downstream stages consume the same Stage C
/// boundary artifacts from one package entry.
pub(all) struct OrderingStageOutput {
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Root Stage C boundary stays in `ordering_stage`; owner-internal clustered and
/// non-clustered dispatch orchestration now lives under `ordering/integration`.

///|
/// Graphviz parity: ordering + vnode expansion aligned to refs/graphviz/lib/dotgen/mincross.c + dotgen/flat.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn compute_ordering_stage(
  input : OrderingStageInput,
) -> OrderingStageOutput {
  let pipeline_output =
    @integration.compute_ordering_pipeline(
      {
        graph: input.graph,
        nodes: input.nodes,
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        edge_reversed: input.edge_reversed,
        edge_out_order: input.edge_out_order,
        ranks: input.ranks,
        groups: input.groups,
        rank_keys: input.rank_keys,
        node_order: input.node_order,
        order_sizes: input.order_sizes,
        nodesep_pt: input.nodesep_pt,
        has_edge_labels: input.has_edge_labels,
        rankdir: input.rankdir,
        port_order_positions: input.port_order_positions,
        port_order_contrib: input.port_order_contrib,
      },
    )
  {
    cluster_meta: pipeline_output.cluster_meta,
    ordering: pipeline_output.ordering,
  }
}
