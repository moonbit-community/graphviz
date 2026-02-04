///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const CLUSTER_LABEL_PAD_PT : Double = 8.0

///|
const CLUSTER_COMPACT_WEIGHT : Int = 128

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
priv struct XposConstraintNodeSnapshot {
  name : String?
  kind : NodeKind
  rank : Int
  order : Int
  left_pt : Double
  right_pt : Double
  height_pt : Double
}

///|
priv struct XposConstraintEdgeSnapshot {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
}

///|
priv struct XposConstraintSnapshot {
  nodes : Array[XposConstraintNodeSnapshot]
  edges : Array[XposConstraintEdgeSnapshot]
}

///|
priv enum EndpointClass {
  Ordinary
  Singleton
  Virtual
}

///|
fn endpoint_class(
  name : String,
  node_degrees : Map[String, Int],
  _cluster_keys : Map[String, String],
) -> EndpointClass {
  if is_edge_vnode_name(name) {
    EndpointClass::Virtual
  } else {
    let degree = match node_degrees.get(name) {
      Some(value) => value
      None => 0
    }
    if degree <= 1 {
      EndpointClass::Singleton
    } else {
      EndpointClass::Ordinary
    }
  }
}

///|
fn constraint_weight_scale(
  tail_class : EndpointClass,
  head_class : EndpointClass,
) -> Int {
  match (tail_class, head_class) {
    (EndpointClass::Virtual, EndpointClass::Virtual) => 4
    (EndpointClass::Singleton, EndpointClass::Singleton)
    | (EndpointClass::Singleton, EndpointClass::Virtual)
    | (EndpointClass::Virtual, EndpointClass::Singleton) => 2
    _ => 1
  }
}

///|
fn scaled_edge_weight(
  base_weight : Int,
  tail_class : EndpointClass,
  head_class : EndpointClass,
) -> Int {
  if base_weight == 0 {
    0
  } else {
    base_weight * constraint_weight_scale(tail_class, head_class)
  }
}

///|
let xpos_constraint_snapshot : Ref[XposConstraintSnapshot?] = Ref::new(None)

///|
fn should_capture_xpos_constraints(graph : @cgraph.Graph) -> Bool {
  match @sys.get_env_var("DOT_CAPTURE_XPOS_CONSTRAINTS") {
    None => false
    Some(value) => {
      if value == "" || value == "1" {
        return true
      }
      match graph.name() {
        Some(name) => name == value
        None => false
      }
    }
  }
}

///|
fn build_xpos_constraint_snapshot(
  graph : NsGraph,
  index : Map[String, Int],
  sizes : Map[String, NodeSize],
  order_index : Map[String, Int],
) -> XposConstraintSnapshot {
  let names : Array[String?] = []
  for _ in 0..<graph.nodes.length() {
    names.push(None)
  }
  for name, idx in index {
    names[idx] = Some(name)
  }
  let nodes : Array[XposConstraintNodeSnapshot] = []
  for i in 0..<graph.nodes.length() {
    let node = graph.nodes[i]
    let name = names[i]
    let mut left_pt = 1.0
    let mut right_pt = 1.0
    let mut height_pt = 1.0
    let mut order = 0
    match name {
      Some(value) =>
        match sizes.get(value) {
          Some(size) => {
            left_pt = size.left_pt
            right_pt = size.right_pt
            height_pt = size.height_pt
          }
          None => ()
        }
      None => ()
    }
    match name {
      Some(value) =>
        match order_index.get(value) {
          Some(value) => order = value
          None => ()
        }
      None => ()
    }
    nodes.push({
      name,
      kind: node.kind,
      rank: node.rank,
      order,
      left_pt,
      right_pt,
      height_pt,
    })
  }
  let edges : Array[XposConstraintEdgeSnapshot] = []
  for edge in graph.edges {
    edges.push({
      tail: edge.tail,
      head: edge.head,
      minlen: edge.minlen,
      weight: edge.weight,
    })
  }
  { nodes, edges }
}

///|
fn reorder_constraint_graph(
  graph : NsGraph,
  index : Map[String, Int],
  order : Array[Int],
) -> (NsGraph, Map[String, Int]) {
  let total = graph.nodes.length()
  if total == 0 || order.length() != total {
    return (graph, index)
  }
  let new_graph = new_graph()
  let old_to_new : Array[Int] = []
  for _ in 0..<total {
    old_to_new.push(-1)
  }
  for old_idx in order {
    let node = graph.nodes[old_idx]
    let new_idx = add_node(new_graph, "", kind=node.kind)
    set_node_rank(new_graph, new_idx, node.rank)
    old_to_new[old_idx] = new_idx
  }
  for edge in graph.edges {
    let tail = old_to_new[edge.tail]
    let head = old_to_new[edge.head]
    let _ = add_edge(new_graph, tail, head, edge.minlen, edge.weight)
  }
  let new_index : Map[String, Int] = Map::new()
  for name, old_idx in index {
    let new_idx = old_to_new[old_idx]
    new_index[name] = new_idx
  }
  (new_graph, new_index)
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
/// Graphviz parity: cluster constraints aligned to refs/graphviz/lib/dotgen/position.c
/// (contain_nodes, keepout_othernodes, contain_subclust, separate_subclust).
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_constraints(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  cluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  edge_vnodes : Map[String, Array[String]],
) -> (Array[(String, Int)], Array[ConstraintEdge], Array[String], Array[String]) {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  if cluster_graphs.length() == 0 {
    return ([], [], [], [])
  }
  let cluster_members = collect_cluster_members(cluster_graphs)
  if cluster_members.length() == 0 {
    return ([], [], [], [])
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
        match cluster_key_from_skeleton_name(name) {
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
  if edge_vnodes.length() > 0 {
    for edge in edges {
      let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
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
      (Some(_), Some(_)) => {
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
        extra_nodes.push((ln_name, 0))
        extra_nodes.push((rn_name, 0))
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
    return ([], [], [], [])
  }
  for name, pair in cluster_nodes {
    let (ln_name, rn_name) = pair
    let mut label_minlen : Int? = None
    match cluster_graphs.get(name) {
      Some(cluster_graph) =>
        match graph_label_metrics(cluster_graph) {
          Some((width_pt, _height_pt)) => {
            let label_width = width_pt + CLUSTER_LABEL_PAD_PT * 2.0
            let minlen = round_int(label_width)
            if minlen > 0 {
              label_minlen = Some(minlen)
            }
          }
          None => ()
        }
      None => ()
    }
    match label_minlen {
      Some(minlen) =>
        extra_edges.push({
          tail: ln_name,
          head: rn_name,
          minlen,
          weight: CLUSTER_COMPACT_WEIGHT,
          tail_port: None,
          head_port: None,
        })
      None =>
        extra_edges.push({
          tail: ln_name,
          head: rn_name,
          minlen: 1,
          weight: CLUSTER_COMPACT_WEIGHT,
          tail_port: None,
          head_port: None,
        })
    }
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
  let root_ln_targets : Array[String] = []
  let root_rn_targets : Array[String] = []
  for name, parent in cluster_parents {
    if parent is None {
      match cluster_nodes.get(name) {
        Some((ln_name, rn_name)) => {
          root_ln_targets.push(ln_name)
          root_rn_targets.push(rn_name)
        }
        None => ()
      }
    }
  }
  (extra_nodes, extra_edges, root_ln_targets, root_rn_targets)
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
        node_offsets[port_name] = { center: offset, size, sides: port_info.sides }
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
fn extra_node_kind(name : String) -> NodeKind {
  if name.has_prefix(EDGE_VNODE_PREFIX) {
    NodeKind::Virtual
  } else if name.has_prefix(CLUSTER_LN_PREFIX) || name.has_prefix(CLUSTER_RN_PREFIX) {
    NodeKind::Slack
  } else {
    NodeKind::Normal
  }
}

///|
fn is_cluster_extra_node(name : String) -> Bool {
  name.has_prefix(CLUSTER_LN_PREFIX) || name.has_prefix(CLUSTER_RN_PREFIX)
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
  root_ln_targets : Array[String],
  root_rn_targets : Array[String],
) -> (NsGraph, Map[String, Int]) {
  let graph = new_graph()
  let ordered_nodes : Array[@cgraph.Node] = []
  let mut idx = nodes.length() - 1
  if nodes.length() > 0 {
    while true {
      ordered_nodes.push(nodes[idx])
      if idx == 0 {
        break
      }
      idx = idx - 1
    }
  }
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
  let node_degrees : Map[String, Int] = Map::new()
  for edge in edges {
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    let dir = edge_dir_for(edge, edge.tail().graph().kind())
    let inc = if dir is EdgeDir::Both { 2 } else { 1 }
    let tail_degree = match node_degrees.get(tail_name) {
      Some(value) => value
      None => 0
    }
    node_degrees[tail_name] = tail_degree + inc
    let head_degree = match node_degrees.get(head_name) {
      Some(value) => value
      None => 0
    }
    node_degrees[head_name] = head_degree + inc
  }
  let skip_intercluster =
    @sys.get_env_var("DOT_SKIP_INTERCLUSTER_XPOS") is Some(_)
  let base_positions = compute_rank_positions(
    rank_keys, groups, sizes, nodesep_pt, has_edge_labels,
  )
  let early_extra_nodes : Array[(String, Int)] = []
  let late_extra_nodes : Array[(String, Int)] = []
  for pair in extra_nodes {
    let (name, _rank) = pair
    if is_cluster_extra_node(name) {
      late_extra_nodes.push(pair)
    } else {
      early_extra_nodes.push(pair)
    }
  }
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
  for pair in early_extra_nodes {
    let (name, rank) = pair
    let idx = add_node(graph, name, kind=extra_node_kind(name))
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
  let mut edge_pair_idx = 0
  for edge in edges {
    let tail_name =
      if edge_pair_idx < edge_tail.length() { edge_tail[edge_pair_idx] } else {
        edge.tail().name()
      }
    let head_name =
      if edge_pair_idx < edge_head.length() { edge_head[edge_pair_idx] } else {
        edge.head().name()
      }
    edge_pair_idx = edge_pair_idx + 1
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
    let tail_rank = match ranks.get(tail_name) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head_name) {
      Some(value) => value
      None => continue
    }
    let low = if tail_rank <= head_rank { tail_name } else { head_name }
    let high = if tail_rank <= head_rank { head_name } else { tail_name }
    let orig_tail = edge.tail().name()
    let orig_head = edge.head().name()
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() > 0 && extra_slack_edges.length() > 0 {
      continue
    }
    let chain : Array[String] = []
    chain.push(low)
    for vnode in vnodes {
      chain.push(vnode)
    }
    if low != high || vnodes.length() == 0 {
      chain.push(high)
    }
    let base_weight = edge_weight(edge)
    let mut idx = 0
    while idx + 1 < chain.length() {
      let seg_tail = chain[idx]
      let seg_head = chain[idx + 1]
      idx = idx + 1
      let tail_class = endpoint_class(seg_tail, node_degrees, cluster_keys)
      let head_class = endpoint_class(seg_head, node_degrees, cluster_keys)
      let weight = scaled_edge_weight(base_weight, tail_class, head_class)
      let tail_idx = match index.get(seg_tail) {
        Some(value) => value
        None => continue
      }
      let head_idx = match index.get(seg_head) {
        Some(value) => value
        None => continue
      }
      let tail_port =
        if seg_tail == orig_tail {
        edge.tail_port()
      } else if seg_tail == orig_head {
        edge.head_port()
      } else {
        None
      }
      let head_port =
        if seg_head == orig_head {
        edge.head_port()
      } else if seg_head == orig_tail {
        edge.tail_port()
      } else {
        None
      }
      let tail_offset = edge_port_offset(
        seg_tail,
        tail_port,
        port_offsets,
        sizes,
      )
      let head_offset = edge_port_offset(
        seg_head,
        head_port,
        port_offsets,
        sizes,
      )
      let delta = head_offset - tail_offset
      let m0 = if delta > 0.0 { trunc_int(delta) } else { 0 }
      let m1 = if delta < 0.0 { trunc_int(-delta) } else { 0 }
      let slack_idx = add_node(graph, "", kind=NodeKind::Slack)
      let tail_rank = node_rank(graph, tail_idx)
      let head_rank = node_rank(graph, head_idx)
      let base_tail = tail_rank - m0 - 1
      let base_head = head_rank - m1 - 1
      set_node_rank(
        graph,
        slack_idx,
        if base_tail < base_head { base_tail } else { base_head },
      )
      let _ = add_edge(graph, slack_idx, tail_idx, m0 + 1, weight)
      let _ = add_edge(graph, slack_idx, head_idx, m1 + 1, weight)
    }
  }
  for edge in extra_slack_edges {
    let tail_idx = match index.get(edge.tail) {
      Some(value) => value
      None => continue
    }
    let head_idx = match index.get(edge.head) {
      Some(value) => value
      None => continue
    }
    let tail_offset = edge_port_offset_by_name(
      edge.tail,
      edge.tail_port,
      port_offsets,
    )
    let head_offset = edge_port_offset_by_name(
      edge.head,
      edge.head_port,
      port_offsets,
    )
    let delta = head_offset - tail_offset
    let m0 = if delta > 0.0 { trunc_int(delta) } else { 0 }
    let m1 = if delta < 0.0 { trunc_int(-delta) } else { 0 }
    let slack_idx = add_node(graph, "", kind=NodeKind::Slack)
    let tail_rank = node_rank(graph, tail_idx)
    let head_rank = node_rank(graph, head_idx)
    let base_tail = tail_rank - m0 - 1
    let base_head = head_rank - m1 - 1
    set_node_rank(
      graph,
      slack_idx,
      if base_tail < base_head { base_tail } else { base_head },
    )
    let _ = add_edge(graph, slack_idx, tail_idx, m0 + 1, edge.weight)
    let _ = add_edge(graph, slack_idx, head_idx, m1 + 1, edge.weight)
  }
  for pair in late_extra_nodes {
    let (name, rank) = pair
    let idx = add_node(graph, name, kind=extra_node_kind(name))
    index[name] = idx
    let pos = match base_positions.get(name) {
      Some(value) => value
      None => rank.to_double()
    }
    set_node_rank(graph, idx, trunc_int(pos))
  }
  if root_ln_targets.length() > 0 || root_rn_targets.length() > 0 {
    let root_ln = add_node(graph, "", kind=NodeKind::Slack)
    let root_rn = add_node(graph, "", kind=NodeKind::Slack)
    set_node_rank(graph, root_ln, 0)
    set_node_rank(graph, root_rn, 0)
    let root_margin = if nodes.length() > 0 {
      cluster_margin_pt(nodes[0].graph())
    } else {
      CLUSTER_MARGIN_PT
    }
    let minlen = round_int(root_margin)
    for name in root_ln_targets {
      match index.get(name) {
        Some(idx) => {
          let _ = add_edge(graph, root_ln, idx, minlen, 0)
        }
        None => ()
      }
    }
    for name in root_rn_targets {
      match index.get(name) {
        Some(idx) => {
          let _ = add_edge(graph, idx, root_rn, minlen, 0)
        }
        None => ()
      }
    }
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
  graph_root : @cgraph.Graph,
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
  root_ln_targets : Array[String],
  root_rn_targets : Array[String],
) -> Map[String, Double] {
  dot_trace("xpos: build constraint graph")
  let order_index = build_order_index(groups)
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
    root_ln_targets,
    root_rn_targets,
  )
  let order : Array[Int] = []
  if graph.nodes.length() > 0 {
    let mut idx = graph.nodes.length() - 1
    while true {
      order.push(idx)
      if idx == 0 {
        break
      }
      idx = idx - 1
    }
  }
  let (graph, index) = reorder_constraint_graph(graph, index, order)
  if should_capture_xpos_constraints(graph_root) {
    xpos_constraint_snapshot.val = Some(
      build_xpos_constraint_snapshot(graph, index, sizes, order_index),
    )
  }
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
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/position.c + cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
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
  flat_label_edges : Array[ConstraintEdge],
  edge_vnodes : Map[String, Array[String]],
  extra_slack_edges : Array[ConstraintEdge],
) -> Map[String, Double] {
  dot_trace("xpos: build cluster constraints")
  let (cluster_nodes, extra_edges, root_ln_targets, root_rn_targets) =
    build_cluster_constraints(
    graph,
    nodes,
    edges,
    ranks,
    rank_keys,
    groups,
    sizes,
    cluster_keys,
    nodesep_pt,
    has_edge_labels,
    edge_vnodes,
  )
  dot_trace("xpos: cluster constraints done")
  let all_extra_nodes = extra_nodes.copy()
  for pair in cluster_nodes {
    all_extra_nodes.push(pair)
  }
  let all_extra_edges = extra_edges.copy()
  for edge in flat_label_edges {
    all_extra_edges.push(edge)
  }
  x_positions_from_simplex(
    graph,
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
    all_extra_edges,
    extra_slack_edges,
    edge_vnodes,
    root_ln_targets,
    root_rn_targets,
  )
}
