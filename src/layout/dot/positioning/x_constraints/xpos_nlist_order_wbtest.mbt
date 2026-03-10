///|
test "build_xpos_nlist_order visits clustered ranks in reverse with vnodes first" {
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster0"
  cluster_keys["b"] = "cluster0"
  cluster_keys["v"] = "cluster0"

  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[1] = ["v", "x"]

  let order = build_xpos_nlist_order({
    rankdir: @rankdir.RankDir::TB,
    nlist_order: ["unused"],
    gdnlist_order: ["a", "b", "v", "x"],
    cluster_keys,
    rank_keys: [0, 1],
    groups,
  })

  assert_eq(order, ["v", "b", "a", "x"])
}

///|
test "build_xpos_nlist_order keeps source order for LR and uncluttered fallback" {
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster0"
  cluster_keys["b"] = "cluster0"
  cluster_keys["v"] = "cluster0"

  let grouped : Map[Int, Array[String]] = Map::new()
  grouped[0] = ["a", "b"]
  grouped[1] = ["v", "x"]

  let lr_order = build_xpos_nlist_order({
    rankdir: @rankdir.RankDir::LR,
    nlist_order: ["unused"],
    gdnlist_order: ["a", "b", "v", "x"],
    cluster_keys,
    rank_keys: [0, 1],
    groups: grouped,
  })

  let no_cluster_groups : Map[Int, Array[String]] = Map::new()
  no_cluster_groups[0] = ["m", "n"]
  let source_fallback = build_xpos_nlist_order({
    rankdir: @rankdir.RankDir::TB,
    nlist_order: ["m", "n"],
    gdnlist_order: [],
    cluster_keys: Map::new(),
    rank_keys: [0],
    groups: no_cluster_groups,
  })

  assert_eq(lr_order, ["a", "b", "v", "x"])
  assert_eq(source_fallback, ["m", "n"])
}

///|
test "build_xpos_nlist_order processes multiple clusters from reversed source discovery before unclustered leftovers" {
  let vnode_a = "\{@edge_identity.EDGE_VNODE_PREFIX}a"
  let vnode_b = "\{@edge_identity.EDGE_VNODE_PREFIX}b"
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a1"] = "clusterA"
  cluster_keys[vnode_a] = "clusterA"
  cluster_keys["b1"] = "clusterB"
  cluster_keys[vnode_b] = "clusterB"

  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a1", "b1", "u"]
  groups[1] = [vnode_a, vnode_b]

  let order = build_xpos_nlist_order({
    rankdir: @rankdir.RankDir::TB,
    nlist_order: ["unused"],
    gdnlist_order: ["a1", "u", vnode_a, "b1", vnode_b],
    cluster_keys,
    rank_keys: [0, 1],
    groups,
  })

  assert_eq(order, [vnode_b, "b1", vnode_a, "a1", "u"])
}
