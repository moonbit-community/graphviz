///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const CLUSTER_LABEL_PAD_PT : Double = 8.0

///|
const CLUSTER_COMPACT_WEIGHT : Int = 1

///|
const CLUSTER_LN_PREFIX : String = "_mbt_cluster_ln_"

///|
const CLUSTER_RN_PREFIX : String = "_mbt_cluster_rn_"

///|
priv struct ConstraintEdge {
  tail : String
  head : String
  minlen : Int
  weight : Int
  tail_port : String?
  head_port : String?
}

///|
fn round_int(value : Double) -> Int {
  if value >= 0.0 {
    (value + 0.5).floor().to_int()
  } else {
    (value - 0.5).ceil().to_int()
  }
}

///|
fn trunc_int(value : Double) -> Int {
  if value >= 0.0 {
    value.floor().to_int()
  } else {
    value.ceil().to_int()
  }
}

///|
fn nodesep_minlen(
  tail_name : String,
  head_name : String,
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
) -> Int {
  let tail_size = sizes.get(tail_name)
  let head_size = sizes.get(head_name)
  let tail_right = match tail_size {
    Some(value) => value.right_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
  let head_left = match head_size {
    Some(value) => value.left_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
  let sep = nodesep_pt
  let minlen = tail_right + head_left + sep
  if minlen <= 0.0 {
    0
  } else {
    round_int(minlen)
  }
}

///|
fn cluster_margin_pt(graph : @cgraph.Graph) -> Double {
  match graph.get_attr("margin") {
    Some(value) => {
      let margin = parse_first_double(value, CLUSTER_MARGIN_PT)
      if margin < 0.0 {
        CLUSTER_MARGIN_PT
      } else {
        margin
      }
    }
    None => CLUSTER_MARGIN_PT
  }
}

///|
fn unique_cluster_node_name(
  prefix : String,
  cluster_name : String,
  existing : Map[String, Bool],
) -> String {
  let mut candidate = "\{prefix}\{cluster_name}"
  if existing.get(candidate) is None {
    existing[candidate] = true
    return candidate
  }
  let mut i = 1
  while true {
    candidate = "\{prefix}\{cluster_name}_\{i}"
    if existing.get(candidate) is None {
      existing[candidate] = true
      return candidate
    }
    i = i + 1
  }
  ""
}

///|
fn collect_cluster_graphs(
  graph : @cgraph.Graph,
  parent : String?,
  clusters : Map[String, @cgraph.Graph],
  parents : Map[String, String?],
) -> Unit {
  let mut next_parent = parent
  if is_cluster_graph(graph) {
    match graph.name() {
      Some(name) => {
        clusters[name] = graph
        parents[name] = parent
        next_parent = Some(name)
      }
      None => ()
    }
  }
  for child in graph.subgraphs() {
    collect_cluster_graphs(child, next_parent, clusters, parents)
  }
}

///|
fn collect_graph_nodes(
  graph : @cgraph.Graph,
  nodes_out : Map[String, Bool],
) -> Unit {
  for node in graph.nodes() {
    nodes_out[node.name()] = true
  }
  for child in graph.subgraphs() {
    collect_graph_nodes(child, nodes_out)
  }
}

///|
fn collect_cluster_members(
  cluster_graphs : Map[String, @cgraph.Graph],
) -> Map[String, Map[String, Bool]] {
  let members : Map[String, Map[String, Bool]] = Map::new()
  for name, cluster_graph in cluster_graphs {
    let set : Map[String, Bool] = Map::new()
    collect_graph_nodes(cluster_graph, set)
    if set.length() > 0 {
      members[name] = set
    }
  }
  members
}

///|
///|
fn build_cluster_constraints(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  edge_vnodes : Map[String, Array[String]],
) -> (Array[(String, Int)], Array[ConstraintEdge]) {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  if cluster_graphs.length() == 0 {
    return ([], [])
  }
  let cluster_members = collect_cluster_members(cluster_graphs)
  if cluster_members.length() == 0 {
    return ([], [])
  }
  let cluster_related : Map[String, Map[String, Bool]] = Map::new()
  let cluster_edges : Map[String, Map[String, Bool]] = Map::new()
  for name, members in cluster_members {
    let related : Map[String, Bool] = Map::new()
    for node_name, _ in members {
      related[node_name] = true
    }
    cluster_related[name] = related
  }
  for name, cluster_graph in cluster_graphs {
    let child_edges : Map[String, Bool] = Map::new()
    for child in cluster_graph.subgraphs() {
      for edge in child.edges() {
        child_edges[edge_key(edge)] = true
      }
    }
    let edges_set : Map[String, Bool] = Map::new()
    for edge in cluster_graph.edges() {
      let key = edge_key(edge)
      if child_edges.get(key) is None {
        edges_set[key] = true
      }
    }
    cluster_edges[name] = edges_set
  }
  if edge_vnodes.length() > 0 {
    for edge in edges {
      let vnodes = match edge_vnodes.get(edge_key(edge)) {
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
        let edge_in_cluster = match cluster_edges.get(name) {
          Some(edges_set) => edges_set.get(edge_key(edge)) is Some(_)
          None => false
        }
        if edge_in_cluster || tail_in || head_in {
          match cluster_related.get(name) {
            Some(related) =>
              for vnode in vnodes {
                related[vnode] = true
              }
            None => ()
          }
        }
        if edge_in_cluster {
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
  let cluster_nodes : Map[String, (String, String)] = Map::new()
  let cluster_margins : Map[String, Double] = Map::new()
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_max_rank : Map[String, Int] = Map::new()
  let extra_nodes : Array[(String, Int)] = []
  let extra_edges : Array[ConstraintEdge] = []
  for name, cluster_graph in cluster_graphs {
    cluster_margins[name] = cluster_margin_pt(cluster_graph)
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
          let left_width = node_left_pt(node_name, sizes)
          let right_width = node_right_pt(node_name, sizes)
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
        let ln_name = unique_cluster_node_name(
          CLUSTER_LN_PREFIX,
          name,
          existing_names,
        )
        let rn_name = unique_cluster_node_name(
          CLUSTER_RN_PREFIX,
          name,
          existing_names,
        )
        cluster_nodes[name] = (ln_name, rn_name)
        let margin = match cluster_margins.get(name) {
          Some(value) => value
          None => CLUSTER_MARGIN_PT
        }
        extra_nodes.push((ln_name, trunc_int(left - margin)))
        extra_nodes.push((rn_name, trunc_int(right + margin)))
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
    return ([], [])
  }
  for name, pair in cluster_nodes {
    let (ln_name, rn_name) = pair
    match cluster_graphs.get(name) {
      Some(cluster_graph) =>
        match graph_label_metrics(cluster_graph) {
          Some((width_pt, _height_pt)) => {
            let label_width = width_pt + CLUSTER_LABEL_PAD_PT * 2.0
            let minlen = round_int(label_width)
            if minlen > 0 {
              extra_edges.push({
                tail: ln_name,
                head: rn_name,
                minlen,
                weight: 0,
                tail_port: None,
                head_port: None,
              })
            }
          }
          None => ()
        }
      None => ()
    }
    extra_edges.push({
      tail: ln_name,
      head: rn_name,
      minlen: 1,
      weight: CLUSTER_COMPACT_WEIGHT,
      tail_port: None,
      head_port: None,
    })
    let margin = match cluster_margins.get(name) {
      Some(value) => value
      None => CLUSTER_MARGIN_PT
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
            if members.get(node_name) is Some(_) {
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
          let left_minlen = round_int(
            node_left_pt(left_name, sizes) + margin,
          )
          extra_edges.push({
            tail: ln_name,
            head: left_name,
            minlen: left_minlen,
            weight: 0,
            tail_port: None,
            head_port: None,
          })
          let right_minlen = round_int(
            node_right_pt(right_name, sizes) + margin,
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
              let minlen = round_int(
                node_right_pt(outside, sizes) + margin,
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
              let minlen = round_int(
                node_left_pt(outside, sizes) + margin,
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
                let (parent_ln, parent_rn) = parent_pair
                let (child_ln, child_rn) = child_pair
                let margin = match cluster_margins.get(parent_name) {
                  Some(value) => value
                  None => CLUSTER_MARGIN_PT
                }
                let minlen = round_int(margin)
                extra_edges.push({
                  tail: parent_ln,
                  head: child_ln,
                  minlen,
                  weight: 0,
                  tail_port: None,
                  head_port: None,
                })
                extra_edges.push({
                  tail: child_rn,
                  head: parent_rn,
                  minlen,
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
  let root_margin = cluster_margin_pt(graph)
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
                                            let (_left_ln, left_rn) = left_pair
                                            let (right_ln, _right_rn) = right_pair
                                            let minlen = round_int(margin)
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
  (extra_nodes, extra_edges)
}

///|
fn port_offsets_for_nodes(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
) -> Map[String, Map[String, RecordPort]] {
  let offsets : Map[String, Map[String, RecordPort]] = Map::new()
  let rankdir = if nodes.length() > 0 {
    graph_rankdir(nodes[0].graph())
  } else {
    RankDir::TB
  }
  let record_orientation = record_layout_orientation(rankdir)
  let origin = @geom.Point::{ x: 0.0, y: 0.0 }
  for node in nodes {
    let name = node.name()
    let base_size = match output_sizes.get(name) {
      Some(value) => value
      None => node_size(node, record_orientation)
    }
    let label = label_text(node)
    let has_html = @html_label.is_html_label_text(label)
    let ports =
      if has_html {
        html_ports(node, origin, base_size)
      } else if is_record_shape(node) {
        record_ports(node, origin, base_size, record_orientation)
      } else {
        Map::new()
      }
    if ports.length() > 0 {
      let node_offsets : Map[String, RecordPort] = Map::new()
      for port_name, port_info in ports {
        let offset = layout_port_offset(port_info.center, rankdir)
        let size = match rankdir {
          RankDir::LR | RankDir::RL => swap_node_size(port_info.size)
          _ => port_info.size
        }
        node_offsets[port_name] = { center: offset, size }
      }
      offsets[name] = node_offsets
    }
  }
  offsets
}

///|
fn compass_port_offset(
  compass : @cgraph.Compass,
  node_name : String,
  sizes : Map[String, NodeSize],
) -> Double {
  match compass {
    @cgraph.Compass::E
    | @cgraph.Compass::NE
    | @cgraph.Compass::SE => node_right_pt(node_name, sizes)
    @cgraph.Compass::W
    | @cgraph.Compass::NW
    | @cgraph.Compass::SW => -node_left_pt(node_name, sizes)
    _ => 0.0
  }
}

///|
fn edge_port_offset(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
) -> Double {
  match port {
    Some(value) =>
      match value.name {
        Some(name) =>
          match offsets.get(node_name) {
            Some(node_offsets) =>
              match node_offsets.get(name) {
                Some(port_info) =>
                  match value.compass {
                    Some(compass) =>
                      match compass {
                        @cgraph.Compass::E
                        | @cgraph.Compass::NE
                        | @cgraph.Compass::SE => {
                          let half = port_info.size.width_pt / 2.0
                          port_info.center.x + half
                        }
                        @cgraph.Compass::W
                        | @cgraph.Compass::NW
                        | @cgraph.Compass::SW => {
                          let half = port_info.size.width_pt / 2.0
                          port_info.center.x - half
                        }
                        _ => port_info.center.x
                      }
                    None => port_info.center.x
                  }
                None =>
                  match value.compass {
                    Some(compass) => compass_port_offset(compass, node_name, sizes)
                    None => 0.0
                  }
              }
            None =>
              match value.compass {
                Some(compass) => compass_port_offset(compass, node_name, sizes)
                None => 0.0
              }
          }
        None =>
          match value.compass {
            Some(compass) => compass_port_offset(compass, node_name, sizes)
            None => 0.0
          }
      }
    None => 0.0
  }
}

///|
fn edge_port_offset_by_name(
  node_name : String,
  port_name : String?,
  offsets : Map[String, Map[String, RecordPort]],
) -> Double {
  match port_name {
    Some(name) =>
      match offsets.get(node_name) {
        Some(node_offsets) =>
          match node_offsets.get(name) {
            Some(port_info) => port_info.center.x
            None => 0.0
          }
        None => 0.0
      }
    None => 0.0
  }
}

///|
fn build_constraint_graph(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  output_sizes : Map[String, NodeSize],
  cluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  extra_nodes : Array[(String, Int)],
  extra_edges : Array[ConstraintEdge],
  extra_slack_edges : Array[ConstraintEdge],
  edge_vnodes : Map[String, Array[String]],
) -> (NsGraph, Map[String, Int]) {
  let graph = new_graph()
  let ordered_nodes = nodes
  let mut has_port_edges = false
  for edge in edges {
    if port_is_explicit(edge.tail_port()) || port_is_explicit(edge.head_port()) {
      has_port_edges = true
      break
    }
  }
  let port_offsets =
    if has_port_edges {
      port_offsets_for_nodes(ordered_nodes, output_sizes)
    } else {
      Map::new()
    }
  let actual_names : Map[String, Bool] = Map::new()
  for node in ordered_nodes {
    actual_names[node.name()] = true
  }
  let slack_edges : Array[Int] = []
  let intercluster_seen : Map[String, Bool] = Map::new()
  let skip_intercluster =
    @sys.get_env_var("DOT_SKIP_INTERCLUSTER_XPOS") is Some(_)
  let slack_edge_indices : Array[Int] = []
  let mut idx = 0
  while idx < edges.length() {
    slack_edge_indices.push(idx)
    idx = idx + 1
  }
  for edge_idx in slack_edge_indices {
    let edge = edges[edge_idx]
    let vnodes = match edge_vnodes.get(edge_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() > 0 {
      continue
    }
    let tail_name = if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
      edge.tail().name()
    }
    let head_name = if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
      edge.head().name()
    }
    let tail_cluster = match cluster_keys.get(tail_name) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head_name) {
      Some(value) => value
      None => ""
    }
    if skip_intercluster && tail_cluster != head_cluster &&
      (tail_cluster != "" || head_cluster != "") {
      continue
    }
    if tail_cluster != head_cluster && (tail_cluster != "" || head_cluster != "") {
      let tail_rank = match ranks.get(tail_name) {
        Some(value) => value
        None => 0
      }
      let head_rank = match ranks.get(head_name) {
        Some(value) => value
        None => 0
      }
      let key = intercluster_edge_key(
        tail_cluster,
        head_cluster,
        tail_rank,
        head_rank,
      )
      if intercluster_seen.get(key) is Some(_) {
        continue
      }
      intercluster_seen[key] = true
    }
    slack_edges.push(edge_idx)
  }
  let slack_indices : Array[Int] = []
  for _ in 0..<slack_edges.length() {
    slack_indices.push(0)
  }
  let mut slack_rev = slack_edges.length()
  while slack_rev > 0 {
    slack_rev = slack_rev - 1
    let slack_idx = add_node(graph, "", kind=NodeKind::Slack)
    slack_indices[slack_rev] = slack_idx
  }
  let base_positions = compute_rank_positions(
    rank_keys, groups, sizes, nodesep_pt, has_edge_labels,
  )
  let index : Map[String, Int] = Map::new()
  for node in ordered_nodes {
    let name = node.name()
    let idx = add_node(graph, name)
    index[name] = idx
    let pos = match base_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    set_node_rank(graph, idx, trunc_int(pos))
  }
  for pair in extra_nodes {
    let (name, rank) = pair
    let idx = add_node(graph, name)
    index[name] = idx
    let pos = match base_positions.get(name) {
      Some(value) => value
      None => rank.to_double()
    }
    set_node_rank(graph, idx, trunc_int(pos))
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let rank_nodesep = rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
    let mut i = 0
    while i + 1 < names.length() {
      let tail = names[i]
      let head = names[i + 1]
      let tail_idx = match index.get(tail) {
        Some(value) => value
        None => 0
      }
      let head_idx = match index.get(head) {
        Some(value) => value
        None => 0
      }
      let minlen = nodesep_minlen(
        tail,
        head,
        sizes,
        rank_nodesep,
      )
      let _ = add_edge(graph, tail_idx, head_idx, minlen, 0)
      i = i + 1
    }
  }
  ignore(ranks)
  for extra in extra_slack_edges {
    let (tail_node, use_tail_port) =
      (extra.tail, actual_names.get(extra.tail) is Some(_))
    let (head_node, use_head_port) =
      (extra.head, actual_names.get(extra.head) is Some(_))
    let tail_port = if use_tail_port { extra.tail_port } else { None }
    let head_port = if use_head_port { extra.head_port } else { None }
    let tail_idx = match index.get(tail_node) {
      Some(value) => value
      None => 0
    }
    let head_idx = match index.get(head_node) {
      Some(value) => value
      None => 0
    }
    let slack_idx = add_node(graph, "", kind=NodeKind::Slack)
    let tail_offset = edge_port_offset_by_name(
      tail_node,
      tail_port,
      port_offsets,
    )
    let head_offset = edge_port_offset_by_name(
      head_node,
      head_port,
      port_offsets,
    )
    let delta = head_offset - tail_offset
    let m0 = if delta > 0.0 { trunc_int(delta) } else { 0 }
    let m1 = if delta < 0.0 { trunc_int(-delta) } else { 0 }
    let tail_rank = node_rank(graph, tail_idx)
    let head_rank = node_rank(graph, head_idx)
    let minlen = if extra.minlen > 0 { extra.minlen } else { 1 }
    let base_tail = tail_rank - m0 - minlen
    let base_head = head_rank - m1 - minlen
    set_node_rank(
      graph,
      slack_idx,
      if base_tail < base_head { base_tail } else { base_head },
    )
    let _ = add_edge(graph, slack_idx, tail_idx, m0 + minlen, extra.weight)
    let _ = add_edge(graph, slack_idx, head_idx, m1 + minlen, extra.weight)
  }
  for i in 0..<slack_edges.length() {
    let edge_idx = slack_edges[i]
    let edge = edges[edge_idx]
    let tail_name = if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
      edge.tail().name()
    }
    let head_name = if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
      edge.head().name()
    }
    let (tail_node, use_tail_port) =
      (tail_name, actual_names.get(tail_name) is Some(_))
    let (head_node, use_head_port) =
      (head_name, actual_names.get(head_name) is Some(_))
    let tail_idx = match index.get(tail_node) {
      Some(value) => value
      None => 0
    }
    let head_idx = match index.get(head_node) {
      Some(value) => value
      None => 0
    }
    let slack_idx = slack_indices[i]
    let orig_tail = edge.tail().name()
    let orig_head = edge.head().name()
    let tail_port = if tail_name == orig_tail {
      edge.tail_port()
    } else {
      edge.head_port()
    }
    let head_port = if head_name == orig_head {
      edge.head_port()
    } else {
      edge.tail_port()
    }
    let tail_offset =
      if use_tail_port {
        edge_port_offset(
          tail_name,
          tail_port,
          port_offsets,
          sizes,
        )
      } else {
        0.0
      }
    let head_offset =
      if use_head_port {
        edge_port_offset(
          head_name,
          head_port,
          port_offsets,
          sizes,
        )
      } else {
        0.0
      }
    let delta = head_offset - tail_offset
    let m0 = if delta > 0.0 { trunc_int(delta) } else { 0 }
    let m1 = if delta < 0.0 { trunc_int(-delta) } else { 0 }
    let tail_rank = node_rank(graph, tail_idx)
    let head_rank = node_rank(graph, head_idx)
    let base_tail = tail_rank - m0 - 1
    let base_head = head_rank - m1 - 1
    set_node_rank(
      graph,
      slack_idx,
      if base_tail < base_head { base_tail } else { base_head },
    )
    let weight = edge_weight(edge)
    let _ = add_edge(graph, slack_idx, tail_idx, m0 + 1, weight)
    let _ = add_edge(graph, slack_idx, head_idx, m1 + 1, weight)

  }
  for edge in extra_edges {
    match index.get(edge.tail) {
      Some(tail_idx) =>
        match index.get(edge.head) {
          Some(head_idx) => {
            let _ = add_edge(
              graph,
              tail_idx,
              head_idx,
              edge.minlen,
              edge.weight,
            )

          }
          None => ()
        }
      None => ()
    }
  }
  (graph, index)
}

///|
fn x_positions_from_simplex(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  output_sizes : Map[String, NodeSize],
  cluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  extra_nodes : Array[(String, Int)],
  extra_edges : Array[ConstraintEdge],
  extra_slack_edges : Array[ConstraintEdge],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Double] {
  dot_trace("xpos: build constraint graph")
  let (graph, index) = build_constraint_graph(
    nodes,
    edges,
    edge_tail,
    edge_head,
    ranks,
    rank_keys,
    groups,
    sizes,
    output_sizes,
    cluster_keys,
    nodesep_pt,
    has_edge_labels,
    extra_nodes,
    extra_edges,
    extra_slack_edges,
    edge_vnodes,
  )
  dot_trace("xpos: constraint graph built")
  dot_trace("xpos: network simplex")
  network_simplex(graph, 0x7fffffff, BalanceMode::LR)
  dot_trace("xpos: network simplex done")
  let positions : Map[String, Double] = Map::new()
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    positions[name] = node_rank(graph, idx).to_double()
  }
  for pair in extra_nodes {
    let (name, _rank) = pair
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    positions[name] = node_rank(graph, idx).to_double()
  }
  positions
}

///|
fn compute_x_positions(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  output_sizes : Map[String, NodeSize],
  cluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  extra_nodes : Array[(String, Int)],
  edge_vnodes : Map[String, Array[String]],
  extra_slack_edges : Array[ConstraintEdge],
) -> Map[String, Double] {
  dot_trace("xpos: build cluster constraints")
  let (cluster_nodes, extra_edges) = build_cluster_constraints(
    graph, nodes, edges, ranks, rank_keys, groups, sizes, nodesep_pt, has_edge_labels,
    edge_vnodes,
  )
  dot_trace("xpos: cluster constraints done")
  let all_extra_nodes = extra_nodes.copy()
  for pair in cluster_nodes {
    all_extra_nodes.push(pair)
  }
  x_positions_from_simplex(
    nodes,
    edges,
    edge_tail,
    edge_head,
    ranks,
    rank_keys,
    groups,
    sizes,
    output_sizes,
    cluster_keys,
    nodesep_pt,
    has_edge_labels,
    all_extra_nodes,
    extra_edges,
    extra_slack_edges,
    edge_vnodes,
  )
}
