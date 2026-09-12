///|
#borrow(indices, ranks)
extern "C" fn qsort_indices_by_ranks_ffi(
  indices : FixedArray[Int],
  ranks : FixedArray[Int],
  len : Int,
) -> Unit = "gv_qsort_indices_by_ranks"

///|
fn sort_nodes_by_rank_via_native_qsort(
  graph : NsGraph,
  nodes : Array[Int],
) -> Bool {
  if nodes.length() <= 1 {
    return true
  }
  let rank_values : Array[Int] = []
  for node in graph.nodes {
    rank_values.push(node.rank)
  }
  let sorted = FixedArray::from_array(nodes)
  let ranks = FixedArray::from_array(rank_values)
  qsort_indices_by_ranks_ffi(sorted, ranks, nodes.length())
  for i in 0..<nodes.length() {
    nodes[i] = sorted[i]
  }
  true
}
