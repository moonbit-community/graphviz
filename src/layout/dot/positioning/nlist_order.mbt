///|
fn is_edge_vnode_name_for_xpos(name : String) -> Bool {
  @shared.is_edge_vnode_name(name)
}

///|
/// Graphviz parity: xpos nlist order keeps clustered reverse-rank traversal,
/// vnode-first ordering, and LR/RL source-order fast path aligned with
/// position.c/create_aux_edges.
pub(all) struct XposNlistOrderInput {
  rankdir : @shared.RankDir
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  cluster_keys : Map[String, String]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
}

///|
/// Graphviz parity: class2/decompose creation order is consumed in reverse for
/// clustered xpos (except LR/RL), with virtual nodes visited before rank peers.
pub fn build_xpos_nlist_order(
  input : XposNlistOrderInput,
) -> Array[String] {
  let nlist_source =
    if input.gdnlist_order.length() > 0 {
      input.gdnlist_order
    } else {
      input.nlist_order
    }
  let nlist_reversed : Array[String] = []
  let mut nlist_idx = nlist_source.length()
  while nlist_idx > 0 {
    nlist_idx = nlist_idx - 1
    nlist_reversed.push(nlist_source[nlist_idx])
  }
  let xpos_nlist_order : Array[String] = []
  let cluster_order : Array[String] = []
  let cluster_seen : Map[String, Bool] = Map::new()
  let prefer_source_for_lr =
    input.rankdir == @shared.RankDir::LR || input.rankdir == @shared.RankDir::RL
  for name in nlist_reversed {
    let cluster = input.cluster_keys.get(name).unwrap_or_default()
    if cluster != "" && cluster_seen.get(cluster) is None {
      cluster_seen[cluster] = true
      cluster_order.push(cluster)
    }
  }
  if prefer_source_for_lr || cluster_order.length() == 0 {
    for name in nlist_source {
      xpos_nlist_order.push(name)
    }
    return xpos_nlist_order
  }
  let xpos_seen : Map[String, Bool] = Map::new()
  for cluster in cluster_order {
    let mut rank_idx = input.rank_keys.length()
    while rank_idx > 0 {
      rank_idx = rank_idx - 1
      let rank = input.rank_keys[rank_idx]
      let names = input.groups.get(rank).unwrap_or_default()
      // Graphviz parity: decompose-created virtual nodes are visited before
      // their rank peers in clustered GD_nlist traversals.
      let mut name_idx = names.length()
      while name_idx > 0 {
        name_idx = name_idx - 1
        let name = names[name_idx]
        if !is_edge_vnode_name_for_xpos(name) {
          continue
        }
        let name_cluster = input.cluster_keys.get(name).unwrap_or_default()
        if name_cluster == cluster && xpos_seen.get(name) is None {
          xpos_nlist_order.push(name)
          xpos_seen[name] = true
        }
      }
      name_idx = names.length()
      while name_idx > 0 {
        name_idx = name_idx - 1
        let name = names[name_idx]
        if is_edge_vnode_name_for_xpos(name) {
          continue
        }
        let name_cluster = input.cluster_keys.get(name).unwrap_or_default()
        if name_cluster == cluster && xpos_seen.get(name) is None {
          xpos_nlist_order.push(name)
          xpos_seen[name] = true
        }
      }
    }
  }
  for name in nlist_reversed {
    if xpos_seen.get(name) is None {
      xpos_nlist_order.push(name)
      xpos_seen[name] = true
    }
  }
  xpos_nlist_order
}
