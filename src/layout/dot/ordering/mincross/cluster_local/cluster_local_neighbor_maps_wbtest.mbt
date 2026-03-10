///|
test "normalize_external_neighbor_name collapses unresolved external clusters but preserves local expanded and unclustered neighbors" {
  let expanded_clusters : Map[String, Bool] = Map::new()
  expanded_clusters["cluster_done"] = true

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["local"] = "cluster_a"
  intercluster_keys["pending"] = "cluster_pending"
  intercluster_keys["done"] = "cluster_done"

  assert_eq(
    normalize_external_neighbor_name(
      "local", "cluster_a", expanded_clusters, intercluster_keys, "%0",
    ),
    "local",
  )
  assert_eq(
    normalize_external_neighbor_name(
      "pending", "cluster_a", expanded_clusters, intercluster_keys, "%0",
    ),
    "%0",
  )
  assert_eq(
    normalize_external_neighbor_name(
      "done", "cluster_a", expanded_clusters, intercluster_keys, "%0",
    ),
    "done",
  )
  assert_eq(
    normalize_external_neighbor_name(
      "plain", "cluster_a", expanded_clusters, intercluster_keys, "%0",
    ),
    "plain",
  )
}

///|
test "has_source_external_anchor detects source neighbors outside the active cluster from either direction" {
  let cluster_node_set : Map[String, Bool] = Map::new()
  cluster_node_set["a"] = true
  cluster_node_set["b"] = true

  let source_out_neighbors : Map[String, Array[String]] = Map::new()
  source_out_neighbors["a"] = ["b"]
  source_out_neighbors["b"] = ["outside_out"]
  let source_in_neighbors : Map[String, Array[String]] = Map::new()
  source_in_neighbors["a"] = ["outside_in"]
  source_in_neighbors["b"] = ["a"]

  assert_true(
    has_source_external_anchor(
      "a", cluster_node_set, source_out_neighbors, source_in_neighbors,
    ),
  )
  assert_true(
    has_source_external_anchor(
      "b", cluster_node_set, source_out_neighbors, source_in_neighbors,
    ),
  )
  assert_false(
    has_source_external_anchor(
      "missing", cluster_node_set, source_out_neighbors, source_in_neighbors,
    ),
  )
}

///|
test "append_raw_neighbors_with_external_anchor skips synthetic names, dedupes local names, and keeps one anchor per unresolved external cluster" {
  let merge_context : LocalNeighborMergeContext = {
    cluster: "cluster_a",
    cluster_node_set: { "a": true, "b": true },
    expanded_clusters: { "cluster_done": true },
    neighbor_sources: {
      source_out_neighbors: Map::new(),
      source_in_neighbors: Map::new(),
      raw_out_neighbors: Map::new(),
      raw_in_neighbors: Map::new(),
    },
    intercluster_keys: {
      "a": "cluster_a",
      "b": "cluster_a",
      "pending_1": "cluster_pending",
      "pending_2": "cluster_pending",
      "other_pending": "cluster_other",
      "done": "cluster_done",
    },
    allow_raw_neighbors: true,
    external_anchor_name: "%0",
  }

  let neighbors = ["a"]
  append_raw_neighbors_with_external_anchor(
    neighbors,
    [
      "a",
      "pending_1",
      "pending_2",
      "other_pending",
      "done",
      "\{@edge_identity.EDGE_VNODE_PREFIX}0",
      @cluster_identity.cluster_skeleton_name("cluster_skip", 0),
    ],
    merge_context,
  )

  assert_eq(neighbors, ["a", "%0", "%0", "done"])
}

///|
test "build_local_neighbor_maps merges raw agseq neighbors only when source lists stay local" {
  let neighbor_sources : ClusterLocalNeighborSources = {
    source_out_neighbors: { "a": ["b"], "b": ["outside_from_source"] },
    source_in_neighbors: { "a": [], "b": ["a"] },
    raw_out_neighbors: {
      "a": [
        "b",
        "pending_1",
        "pending_2",
        "done",
        "\{@edge_identity.EDGE_VNODE_PREFIX}0",
      ],
      "b": ["raw_only_should_not_merge"],
    },
    raw_in_neighbors: {
      "a": ["done", "other_pending"],
      "b": ["raw_in_should_not_merge"],
    },
  }

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["a"] = "cluster_a"
  intercluster_keys["b"] = "cluster_a"
  intercluster_keys["pending_1"] = "cluster_pending"
  intercluster_keys["pending_2"] = "cluster_pending"
  intercluster_keys["other_pending"] = "cluster_other"
  intercluster_keys["done"] = "cluster_done"

  let merged = build_local_neighbor_maps(
    "cluster_a",
    { "cluster_done": true },
    ["a", "b"],
    neighbor_sources,
    intercluster_keys,
    true,
  )

  assert_eq(merged.graphviz_out_neighbors.get("a"), Some(["b", "%0", "done"]))
  assert_eq(merged.graphviz_in_neighbors.get("a"), Some(["done", "%0"]))
  assert_eq(
    merged.graphviz_out_neighbors.get("b"),
    Some(["outside_from_source"]),
  )
  assert_eq(merged.graphviz_in_neighbors.get("b"), Some(["a"]))
}
