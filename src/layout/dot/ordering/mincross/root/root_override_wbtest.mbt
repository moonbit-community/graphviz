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
