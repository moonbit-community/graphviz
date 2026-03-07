///|
/// X-position cluster-constraint builders for simplex input preparation.

///|
pub(all) struct ClusterConstraintBuild {
  extra_nodes : Array[@ordering.ExtraConstraintNode]
  extra_edges : Array[ConstraintEdge]
  root_ln_targets : Array[String]
  root_rn_targets : Array[String]
}

///|
pub(all) struct ClusterConstraintLabelDeps {
  cluster_label_borders_for : (
    @cgraph.Graph,
    @shared.RankDir,
  ) -> (Double, Double)
  cluster_label_width_with_pad_for : (@cgraph.Graph) -> Double?
  cluster_compact_weight : Int
}

///|
priv struct ClusterBoundaryNodes {
  left_node : String
  right_node : String
}

///|
/// Graphviz parity: cluster constraints aligned to refs/graphviz/lib/dotgen/position.c
/// (contain_nodes, keepout_othernodes, contain_subclust, separate_subclust).
/// Do not change behavior without updating fixtures/tests.
pub fn build_cluster_constraints(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, @node_primitives.NodeSize],
  cluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  edge_vnodes : Map[String, Array[String]],
  deps : ClusterConstraintLabelDeps,
) -> ClusterConstraintBuild {
  let cluster_maps = @cluster_graph.collect_cluster_graph_maps(graph)
  let cluster_graphs = cluster_maps.cluster_graphs
  let cluster_parents = cluster_maps.cluster_parents
  if cluster_graphs.length() == 0 {
    return {
      extra_nodes: [],
      extra_edges: [],
      root_ln_targets: [],
      root_rn_targets: [],
    }
  }
  let cluster_members = @clustering.collect_cluster_members(cluster_graphs)
  if cluster_members.length() == 0 {
    return {
      extra_nodes: [],
      extra_edges: [],
      root_ln_targets: [],
      root_rn_targets: [],
    }
  }
  for node_name, cluster_key in cluster_keys {
    if cluster_key == "" {
      continue
    }
    match cluster_members.get(cluster_key) {
      Some(members) => members[node_name] = true
      None => ()
    }
  }
  if cluster_members.length() > 0 {
    for _rank, names in groups {
      for name in names {
        match @cluster_identity.cluster_key_from_skeleton(name) {
          Some(cluster_key) =>
            match cluster_members.get(cluster_key) {
              Some(members) => members[name] = true
              None => ()
            }
          None => ()
        }
      }
    }
  }
  let cluster_related : Map[String, Map[String, Bool]] = Map::new()
  for name, members in cluster_members {
    let related : Map[String, Bool] = Map::new()
    for node_name, _ in members {
      related[node_name] = true
    }
    cluster_related[name] = related
  }
  // Graphviz parity: in LR/RL, cluster label height becomes horizontal border
  // slack in x-constraints (post-flip label geometry).
  let rankdir = @shared.graph_rankdir(graph)
  let flip = rankdir == @shared.RankDir::LR || rankdir == @shared.RankDir::RL
  if edge_vnodes.length() > 0 {
    for edge in edges {
      let vnodes = match edge_vnodes.get(@edge_identity.edge_vnode_key(edge)) {
        Some(list) => list
        None => []
      }
      if vnodes.length() == 0 {
        continue
      }
      let tail = edge.tail().name()
      let head = edge.head().name()
      for name, members in cluster_members {
        let tail_in = members.get(tail) is Some(_)
        let head_in = members.get(head) is Some(_)
        if tail_in || head_in {
          match cluster_related.get(name) {
            Some(related) =>
              for vnode in vnodes {
                related[vnode] = true
              }
            None => ()
          }
        }
        // Graphviz parity: vnodes for edges with both endpoints in a cluster
        // participate in cluster containment (see keepout/contain logic).
        if tail_in && head_in {
          for vnode in vnodes {
            members[vnode] = true
          }
        }
      }
    }
  }
  let node_in_any_cluster : Map[String, Bool] = Map::new()
  for _name, members in cluster_members {
    for node_name, _ in members {
      node_in_any_cluster[node_name] = true
    }
  }
  let base_positions = compute_rank_positions(
    rank_keys, groups, sizes, nodesep_pt, has_edge_labels,
  )
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  let cluster_nodes : Map[String, ClusterBoundaryNodes] = Map::new()
  let cluster_margins : Map[String, Double] = Map::new()
  let cluster_border_left : Map[String, Double] = Map::new()
  let cluster_border_right : Map[String, Double] = Map::new()
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_max_rank : Map[String, Int] = Map::new()
  let extra_nodes : Array[@ordering.ExtraConstraintNode] = []
  let extra_edges : Array[ConstraintEdge] = []
  for name, cluster_graph in cluster_graphs {
    cluster_margins[name] = @clustering.cluster_margin_pt(cluster_graph)
    let (left_border, right_border) =
      (deps.cluster_label_borders_for)(cluster_graph, rankdir)
    cluster_border_left[name] = left_border
    cluster_border_right[name] = right_border
  }
  for name, members in cluster_members {
    let mut min_rank : Int? = None
    let mut max_rank : Int? = None
    let mut min_left : Double? = None
    let mut max_right : Double? = None
    for node_name, _ in members {
      match ranks.get(node_name) {
        Some(value) => {
          match min_rank {
            Some(current) => if value < current { min_rank = Some(value) }
            None => min_rank = Some(value)
          }
          match max_rank {
            Some(current) => if value > current { max_rank = Some(value) }
            None => max_rank = Some(value)
          }
        }
        None => ()
      }
      match base_positions.get(node_name) {
        Some(pos) => {
          let left_width = @node_primitives.node_left_pt(node_name, sizes)
          let right_width = @node_primitives.node_right_pt(node_name, sizes)
          let left = pos - left_width
          let right = pos + right_width
          match min_left {
            Some(current) => if left < current { min_left = Some(left) }
            None => min_left = Some(left)
          }
          match max_right {
            Some(current) => if right > current { max_right = Some(right) }
            None => max_right = Some(right)
          }
        }
        None => ()
      }
    }
    match (min_left, max_right) {
      (Some(left), Some(right)) => {
        let ln_name = @cluster_identity.unique_cluster_boundary_name(
          @cluster_identity.cluster_left_boundary_name(name),
          existing_names,
        )
        let rn_name = @cluster_identity.unique_cluster_boundary_name(
          @cluster_identity.cluster_right_boundary_name(name),
          existing_names,
        )
        cluster_nodes[name] = { left_node: ln_name, right_node: rn_name }
        let margin = match cluster_margins.get(name) {
          Some(value) => value
          None => CLUSTER_MARGIN_PT
        }
        let left_border = match cluster_border_left.get(name) {
          Some(value) => value
          None => 0.0
        }
        let right_border = match cluster_border_right.get(name) {
          Some(value) => value
          None => 0.0
        }
        extra_nodes.push({
          name: ln_name,
          rank: @numeric.trunc_int(left - margin - left_border),
        })
        extra_nodes.push({
          name: rn_name,
          rank: @numeric.trunc_int(right + margin + right_border),
        })
        match min_rank {
          Some(value) => cluster_min_rank[name] = value
          None => ()
        }
        match max_rank {
          Some(value) => cluster_max_rank[name] = value
          None => ()
        }
      }
      _ => ()
    }
  }
  if cluster_nodes.length() == 0 {
    return {
      extra_nodes: [],
      extra_edges: [],
      root_ln_targets: [],
      root_rn_targets: [],
    }
  }
  for name, pair in cluster_nodes {
    let ln_name = pair.left_node
    let rn_name = pair.right_node
    let mut label_minlen : Int? = None
    // Graphviz parity: LR/RL handles cluster label extents via left/right
    // border slack, so do not add standalone label minlen here.
    if !flip {
      match cluster_graphs.get(name) {
        Some(cluster_graph) =>
          match (deps.cluster_label_width_with_pad_for)(cluster_graph) {
            Some(label_width) => {
              let minlen = @numeric.round_int(label_width)
              if minlen > 0 {
                label_minlen = Some(minlen)
              }
            }
            None => ()
          }
        None => ()
      }
    }
    match label_minlen {
      Some(minlen) =>
        extra_edges.push({
          tail: ln_name,
          head: rn_name,
          minlen,
          weight: deps.cluster_compact_weight,
          tail_port: None,
          head_port: None,
        })
      None =>
        extra_edges.push({
          tail: ln_name,
          head: rn_name,
          minlen: 1,
          weight: deps.cluster_compact_weight,
          tail_port: None,
          head_port: None,
        })
    }
    let margin = match cluster_margins.get(name) {
      Some(value) => value
      None => CLUSTER_MARGIN_PT
    }
    let left_border = match cluster_border_left.get(name) {
      Some(value) => value
      None => 0.0
    }
    let right_border = match cluster_border_right.get(name) {
      Some(value) => value
      None => 0.0
    }
    match (cluster_members.get(name), cluster_related.get(name)) {
      (Some(members), Some(related)) =>
        for rank in rank_keys {
          let names = match groups.get(rank) {
            Some(list) => list
            None => []
          }
          let mut left_idx = -1
          let mut right_idx = -1
          let mut i = 0
          while i < names.length() {
            let node_name = names[i]
            if members.get(node_name) is Some(_) &&
              @cluster_identity.cluster_key_from_skeleton(node_name) is None {
              if left_idx < 0 {
                left_idx = i
              }
              right_idx = i
            }
            i = i + 1
          }
          if left_idx < 0 {
            continue
          }
          let left_name = names[left_idx]
          let right_name = names[right_idx]
          let left_minlen = @numeric.round_int(
            @node_primitives.node_left_pt(left_name, sizes) + margin + left_border,
          )
          extra_edges.push({
            tail: ln_name,
            head: left_name,
            minlen: left_minlen,
            weight: 0,
            tail_port: None,
            head_port: None,
          })
          let right_minlen = @numeric.round_int(
            @node_primitives.node_right_pt(right_name, sizes) + margin + right_border,
          )
          extra_edges.push({
            tail: right_name,
            head: rn_name,
            minlen: right_minlen,
            weight: 0,
            tail_port: None,
            head_port: None,
          })
          let mut j = left_idx - 1
          while j >= 0 {
            let outside = names[j]
            if related.get(outside) is None {
              // Graphviz parity (keepout_othernodes): outside-node separation
              // from cluster ln/rn uses only cluster margin, not label border.
              let minlen = @numeric.round_int(
                @node_primitives.node_right_pt(outside, sizes) + margin,
              )
              extra_edges.push({
                tail: outside,
                head: ln_name,
                minlen,
                weight: 0,
                tail_port: None,
                head_port: None,
              })
              break
            }
            j = j - 1
          }
          j = right_idx + 1
          while j < names.length() {
            let outside = names[j]
            if related.get(outside) is None {
              // Graphviz parity (keepout_othernodes): outside-node separation
              // from cluster ln/rn uses only cluster margin, not label border.
              let minlen = @numeric.round_int(
                @node_primitives.node_left_pt(outside, sizes) + margin,
              )
              extra_edges.push({
                tail: rn_name,
                head: outside,
                minlen,
                weight: 0,
                tail_port: None,
                head_port: None,
              })
              break
            }
            j = j + 1
          }
        }
      _ => ()
    }
  }
  for name, parent in cluster_parents {
    match parent {
      Some(parent_name) =>
        match cluster_nodes.get(parent_name) {
          Some(parent_pair) =>
            match cluster_nodes.get(name) {
              Some(child_pair) => {
                let parent_ln = parent_pair.left_node
                let parent_rn = parent_pair.right_node
                let child_ln = child_pair.left_node
                let child_rn = child_pair.right_node
                let margin = match cluster_margins.get(parent_name) {
                  Some(value) => value
                  None => CLUSTER_MARGIN_PT
                }
                let parent_left_border = match cluster_border_left.get(parent_name) {
                  Some(value) => value
                  None => 0.0
                }
                let parent_right_border = match cluster_border_right.get(parent_name) {
                  Some(value) => value
                  None => 0.0
                }
                let left_minlen = @numeric.round_int(
                  margin + parent_left_border,
                )
                let right_minlen = @numeric.round_int(
                  margin + parent_right_border,
                )
                extra_edges.push({
                  tail: parent_ln,
                  head: child_ln,
                  minlen: left_minlen,
                  weight: 0,
                  tail_port: None,
                  head_port: None,
                })
                extra_edges.push({
                  tail: child_rn,
                  head: parent_rn,
                  minlen: right_minlen,
                  weight: 0,
                  tail_port: None,
                  head_port: None,
                })
              }
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  let parent_children : Map[String, Array[String]] = Map::new()
  for name, parent in cluster_parents {
    let key = match parent {
      Some(value) => value
      None => ""
    }
    match parent_children.get(key) {
      Some(list) => list.push(name)
      None => parent_children[key] = [name]
    }
  }
  let root_margin = @clustering.cluster_margin_pt(graph)
  for parent_key, children in parent_children {
    let margin = if parent_key == "" {
      root_margin
    } else {
      match cluster_margins.get(parent_key) {
        Some(value) => value
        None => CLUSTER_MARGIN_PT
      }
    }
    let mut i = 0
    while i + 1 < children.length() {
      let name_i = children[i]
      match cluster_min_rank.get(name_i) {
        None => {
          i = i + 1
          continue
        }
        Some(min_i) =>
          match cluster_max_rank.get(name_i) {
            None => {
              i = i + 1
              continue
            }
            Some(max_i) =>
              match cluster_members.get(name_i) {
                None => {
                  i = i + 1
                  continue
                }
                Some(members_i) => {
                  let mut j = i + 1
                  while j < children.length() {
                    let name_j = children[j]
                    match cluster_min_rank.get(name_j) {
                      None => {
                        j = j + 1
                        continue
                      }
                      Some(min_j) =>
                        match cluster_max_rank.get(name_j) {
                          None => {
                            j = j + 1
                            continue
                          }
                          Some(max_j) =>
                            if min_i <= max_j && min_j <= max_i {
                              match cluster_members.get(name_j) {
                                None => {
                                  j = j + 1
                                  continue
                                }
                                Some(members_j) => {
                                  let start = if min_i > min_j {
                                    min_i
                                  } else {
                                    min_j
                                  }
                                  let end = if max_i < max_j {
                                    max_i
                                  } else {
                                    max_j
                                  }
                                  let mut chosen_first_i = -1
                                  let mut chosen_first_j = -1
                                  let mut r = start
                                  while r <= end {
                                    let names = match groups.get(r) {
                                      Some(list) => list
                                      None => []
                                    }
                                    let mut idx = 0
                                    let mut first_i = -1
                                    let mut first_j = -1
                                    while idx < names.length() &&
                                          (first_i < 0 || first_j < 0) {
                                      let node_name = names[idx]
                                      if @cluster_identity.cluster_key_from_skeleton(node_name)
                                        is Some(_) {
                                        idx = idx + 1
                                        continue
                                      }
                                      if first_i < 0 &&
                                        members_i.get(node_name) is Some(_) {
                                        first_i = idx
                                      }
                                      if first_j < 0 &&
                                        members_j.get(node_name) is Some(_) {
                                        first_j = idx
                                      }
                                      idx = idx + 1
                                    }
                                    if first_i >= 0 && first_j >= 0 {
                                      chosen_first_i = first_i
                                      chosen_first_j = first_j
                                      break
                                    }
                                    r = r + 1
                                  }
                                  if chosen_first_i >= 0 && chosen_first_j >= 0 {
                                    let (left_name, right_name) = if chosen_first_i <
                                      chosen_first_j {
                                      (name_i, name_j)
                                    } else {
                                      (name_j, name_i)
                                    }
                                    match cluster_nodes.get(left_name) {
                                      None => {
                                        j = j + 1
                                        continue
                                      }
                                      Some(left_pair) =>
                                        match cluster_nodes.get(right_name) {
                                          None => {
                                            j = j + 1
                                            continue
                                          }
                                          Some(right_pair) => {
                                            let left_rn = left_pair.right_node
                                            let right_ln = right_pair.left_node
                                            let minlen = @numeric.round_int(margin)
                                            extra_edges.push({
                                              tail: left_rn,
                                              head: right_ln,
                                              minlen,
                                              weight: 0,
                                              tail_port: None,
                                              head_port: None,
                                            })
                                          }
                                        }
                                    }
                                  }
                                }
                              }
                            }
                        }
                    }
                    j = j + 1
                  }
                }
              }
          }
      }
      i = i + 1
    }
  }
  let root_ln_targets : Array[String] = []
  let root_rn_targets : Array[String] = []
  for name, parent in cluster_parents {
    if parent is None {
      match cluster_nodes.get(name) {
        Some(pair) => {
          root_ln_targets.push(pair.left_node)
          root_rn_targets.push(pair.right_node)
        }
        None => ()
      }
    }
  }
  {
    extra_nodes,
    extra_edges,
    root_ln_targets,
    root_rn_targets,
  }
}
