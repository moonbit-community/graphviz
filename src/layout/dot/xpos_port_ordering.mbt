///|
/// X-position port ordering and slack minlen helpers.

///|
fn edge_port_order(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  @positioning.edge_port_order(
    node_name,
    port,
    offsets,
    compass =>
      compass_port_point_for_layout(
        node_name,
        nodes_by_name.get(node_name),
        compass,
        sizes,
        rankdir,
      ),
  )
}
