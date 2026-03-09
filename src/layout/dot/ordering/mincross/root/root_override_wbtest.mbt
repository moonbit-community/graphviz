///|
test "reorder_names_by_override keeps only present override names once and preserves unmatched order" {
  let reordered = reorder_names_by_override(["a", "b", "c", "d"], [
    "c", "missing", "a", "c",
  ])

  assert_eq(reordered, ["c", "a", "b", "d"])
}

///|
test "root override skeleton helpers keep the last skeleton per cluster and attach members in input order" {
  let skel_a_0 = @cluster_identity.cluster_skeleton_name("cluster_a", 0)
  let skel_a_1 = @cluster_identity.cluster_skeleton_name("cluster_a", 1)
  let names = [skel_a_0, "a0", skel_a_1, "a1", "b0"]
  let skeleton_for_cluster = build_skeleton_for_clusters(names, name => {
    @cluster_identity.cluster_key_from_skeleton(name).unwrap_or_default()
  })

  assert_eq(skeleton_for_cluster.get("cluster_a"), Some(skel_a_1))
  assert_eq(skeleton_for_cluster.get("cluster_b"), None)

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a0"] = "cluster_a"
  cluster_keys["a1"] = "cluster_a"
  cluster_keys["b0"] = "cluster_b"

  let attached_by_skeleton = build_attached_by_skeleton(
    names,
    cluster_keys,
    skeleton_for_cluster,
    name => @cluster_identity.cluster_key_from_skeleton(name) is Some(_),
  )

  assert_eq(attached_by_skeleton.get(skel_a_1), Some(["a0", "a1"]))
  assert_eq(attached_by_skeleton.get("missing"), None)

  let target = [skel_a_1]
  let seen : Map[String, Bool] = Map::new()
  seen[skel_a_1] = true
  seen["a0"] = true
  append_attached_by_skeleton(target, seen, attached_by_skeleton, skel_a_1)

  assert_eq(target, [skel_a_1, "a1"])
}

///|
test "build_root_override_rank_names reattaches clustered members behind skeletons only in flip mode" {
  let skel_a = @cluster_identity.cluster_skeleton_name("cluster_a", 0)
  let skel_b = @cluster_identity.cluster_skeleton_name("cluster_b", 0)
  let names = ["a1", skel_a, "root", "b1", skel_b, "loose"]
  let override_names = ["root", skel_b, skel_a]

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a1"] = "cluster_a"
  cluster_keys["b1"] = "cluster_b"

  assert_eq(
    build_root_override_rank_names(names, override_names, cluster_keys, false),
    ["root", skel_b, skel_a, "a1", "b1", "loose"],
  )
  assert_eq(
    build_root_override_rank_names(names, override_names, cluster_keys, true),
    ["root", skel_b, "b1", skel_a, "a1", "loose"],
  )
}

///|
test "rebuild_root_override_names keeps orphan clustered names in place and reattaches only clusters with skeletons" {
  let skel_a = @cluster_identity.cluster_skeleton_name("cluster_a", 0)
  let rank_names = ["a1", "orphan", skel_a, "free", "a2"]

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a1"] = "cluster_a"
  cluster_keys["a2"] = "cluster_a"
  cluster_keys["orphan"] = "cluster_orphan"

  let rebuilt = rebuild_root_override_names(rank_names, cluster_keys)

  assert_eq(rebuilt, ["orphan", skel_a, "a1", "a2", "free"])
}

///|
test "should_merge_root_positions requires a root-then-skeleton pair with exactly one attachment" {
  let skeletons : Map[String, Bool] = Map::new()
  skeletons["skel_a"] = true
  skeletons["skel_b"] = true

  let attached_by_skeleton : Map[String, Array[String]] = Map::new()
  attached_by_skeleton["skel_a"] = ["a0"]
  attached_by_skeleton["skel_b"] = ["b0", "b1"]

  assert_true(
    should_merge_root_positions(
      ["root_a", "skel_a"],
      skeletons,
      attached_by_skeleton,
    ),
  )
  assert_false(
    should_merge_root_positions(
      ["skel_a", "root_a"],
      skeletons,
      attached_by_skeleton,
    ),
  )
  assert_false(
    should_merge_root_positions(
      ["root_b", "skel_b"],
      skeletons,
      attached_by_skeleton,
    ),
  )
  assert_false(
    should_merge_root_positions(["root_only"], skeletons, attached_by_skeleton),
  )
}

///|
test "build_rank_attached_by_skeleton attaches non-mincross clustered members to the last skeleton of that cluster" {
  let skel_a_0 = "skel_a_0"
  let skel_a_1 = "skel_a_1"
  let names = ["a0", skel_a_0, "root", "a1", skel_a_1, "b0", "loose"]

  let order_cluster_keys : Map[String, String] = Map::new()
  order_cluster_keys["a0"] = "cluster_a"
  order_cluster_keys["a1"] = "cluster_a"
  order_cluster_keys[skel_a_0] = "cluster_a"
  order_cluster_keys[skel_a_1] = "cluster_a"
  order_cluster_keys["b0"] = "cluster_b"

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton[skel_a_0] = true
  order_cluster_skeleton[skel_a_1] = true

  let mincross_nodes : Map[String, Bool] = Map::new()
  mincross_nodes[skel_a_0] = true
  mincross_nodes[skel_a_1] = true
  mincross_nodes["root"] = true

  let attached = build_rank_attached_by_skeleton(
    names, order_cluster_keys, order_cluster_skeleton, mincross_nodes,
  )

  assert_eq(attached.get(skel_a_1), Some(["a0", "a1"]))
  assert_eq(attached.get(skel_a_0), None)
  assert_eq(attached.get("cluster_b"), None)
}

///|
test "merge_rank_with_positional_replacements rewrites only mincross member slots" {
  let mincross_nodes : Map[String, Bool] = Map::new()
  mincross_nodes["cluster_a"] = true
  mincross_nodes["root"] = true

  let merged = merge_rank_with_positional_replacements(
    ["left", "cluster_a", "middle", "root", "right"],
    ["root", "cluster_a"],
    mincross_nodes,
  )

  assert_eq(merged, ["left", "root", "middle", "cluster_a", "right"])
}

///|
test "merge_rank_with_attached_skeleton_replacements inserts attached members after skeleton replacements before replaying remaining names" {
  let skel_a = "skel_a"
  let names = ["left", "a0", skel_a, "tail", "a1"]
  let replacements = ["root", skel_a]

  let attached_by_skeleton : Map[String, Array[String]] = Map::new()
  attached_by_skeleton[skel_a] = ["a0", "a1"]

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton[skel_a] = true

  let merged = merge_rank_with_attached_skeleton_replacements(
    names, replacements, attached_by_skeleton, order_cluster_skeleton,
  )

  assert_eq(merged, ["root", skel_a, "a0", "a1", "left", "tail"])
}

///|
test "merge_root_mincross_groups uses positional merge when one attached member should stay in front of the root-skeleton pair" {
  let seeded_groups : Map[Int, Array[String]] = Map::new()
  seeded_groups[0] = ["member", "skel_a", "root", "tail"]
  seeded_groups[1] = ["untouched"]

  let ordered_mincross : Map[Int, Array[String]] = Map::new()
  ordered_mincross[0] = ["root", "skel_a"]

  let mincross_nodes : Map[String, Bool] = Map::new()
  mincross_nodes["root"] = true
  mincross_nodes["skel_a"] = true

  let order_cluster_keys : Map[String, String] = Map::new()
  order_cluster_keys["member"] = "cluster_a"
  order_cluster_keys["skel_a"] = "cluster_a"

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton["skel_a"] = true

  let merged = merge_root_mincross_groups(
    [0, 1],
    seeded_groups,
    ordered_mincross,
    mincross_nodes,
    order_cluster_keys,
    order_cluster_skeleton,
  )

  assert_eq(merged.get(0), Some(["member", "root", "skel_a", "tail"]))
  assert_eq(merged.get(1), Some(["untouched"]))
}

///|
test "merge_root_mincross_groups uses attached-skeleton merge when a skeleton has multiple attached members" {
  let seeded_groups : Map[Int, Array[String]] = Map::new()
  seeded_groups[0] = ["member1", "skel_a", "root", "tail", "member2"]

  let ordered_mincross : Map[Int, Array[String]] = Map::new()
  ordered_mincross[0] = ["root", "skel_a"]

  let mincross_nodes : Map[String, Bool] = Map::new()
  mincross_nodes["root"] = true
  mincross_nodes["skel_a"] = true

  let order_cluster_keys : Map[String, String] = Map::new()
  order_cluster_keys["member1"] = "cluster_a"
  order_cluster_keys["member2"] = "cluster_a"
  order_cluster_keys["skel_a"] = "cluster_a"

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton["skel_a"] = true

  let merged = merge_root_mincross_groups(
    [0],
    seeded_groups,
    ordered_mincross,
    mincross_nodes,
    order_cluster_keys,
    order_cluster_skeleton,
  )

  assert_eq(
    merged.get(0),
    Some(["root", "skel_a", "member1", "member2", "tail"]),
  )
}
