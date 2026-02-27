///|
priv struct RankGroupComponentDiscoveryPrepared {
  ordered_nodes : Array[String]
  out_neighbors : Map[String, Array[String]]
  in_neighbors : Map[String, Array[String]]
  flat_out : Map[String, Array[String]]
  flat_in : Map[String, Array[String]]
  cluster_skeleton_nodes : Map[String, Array[String]]
}
