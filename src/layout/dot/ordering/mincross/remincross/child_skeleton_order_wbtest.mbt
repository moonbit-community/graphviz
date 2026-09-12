///|
test "local cluster cleanup keeps child skeletons before direct parent nodes" {
  let groups : Map[Int, Array[String]] = { 0: ["y", "x"] }
  reorder_groups_by_local_cluster(
    groups,
    { "x": "cluster_x", "y": "cluster_x" },
    { "x": "cluster_x", "y": "cluster_y" },
    { "cluster_x": 0, "cluster_y": 1 },
  )
  assert_true(groups.get(0) == Some(["y", "x"]))
}
