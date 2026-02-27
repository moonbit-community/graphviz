///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const CLUSTER_LABEL_PAD_PT : Double = 8.0

///|
const CLUSTER_COMPACT_WEIGHT : Int = 128

///|
const ROOT_COMPRESS_WEIGHT : Int = 1000

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
fn touch_xpos_constraint_snapshot_fields(snapshot : XposConstraintSnapshot) -> Unit {
  let _ = snapshot.nodes
  let _ = snapshot.edges
  for node in snapshot.nodes {
    let _ = node.name
    let _ = node.kind
    let _ = node.rank
    let _ = node.order
    let _ = node.left_pt
    let _ = node.right_pt
    let _ = node.height_pt
  }
  for edge in snapshot.edges {
    let _ = edge.tail
    let _ = edge.head
    let _ = edge.minlen
    let _ = edge.weight
  }
}

///|
priv struct SlackSegment {
  tail : String
  head : String
  weight : Int
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
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
  let snapshot = { nodes, edges }
  touch_xpos_constraint_snapshot_fields(snapshot)
  snapshot
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
  let new_graph = @network_simplex.new_graph()
  let old_to_new : Array[Int] = []
  for _ in 0..<total {
    old_to_new.push(-1)
  }
  for old_idx in order {
    let node = graph.nodes[old_idx]
    let new_idx = @network_simplex.add_node(new_graph, "", kind=node.kind)
    @network_simplex.set_node_rank(new_graph, new_idx, node.rank)
    old_to_new[old_idx] = new_idx
  }
  for edge in graph.edges {
    let tail = old_to_new[edge.tail]
    let head = old_to_new[edge.head]
    let _ = @network_simplex.add_edge(new_graph, tail, head, edge.minlen, edge.weight)
  }
  let new_index : Map[String, Int] = Map::new()
  for name, old_idx in index {
    let new_idx = old_to_new[old_idx]
    new_index[name] = new_idx
  }
  (new_graph, new_index)
}
///|
/// Graphviz parity: GD_nlist after create_aux_edges prepends slack nodes in
/// reverse creation order, then preserves GD_nlist order for existing nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_constraint_reorder(
  graph : NsGraph,
  index : Map[String, Int],
  nlist_order : Array[String],
) -> Array[Int] {
  let total = graph.nodes.length()
  let order : Array[Int] = []
  if total == 0 {
    return order
  }
  let seen : Array[Bool] = []
  for _ in 0..<total {
    seen.push(false)
  }
  let slack_indices : Array[Int] = []
  for i in 0..<total {
    if graph.nodes[i].kind == NodeKind::Slack {
      slack_indices.push(i)
    }
  }
  let mut slack_idx = slack_indices.length()
  while slack_idx > 0 {
    slack_idx = slack_idx - 1
    let node_idx = slack_indices[slack_idx]
    order.push(node_idx)
    seen[node_idx] = true
  }
  let mut nlist_idx = nlist_order.length()
  while nlist_idx > 0 {
    nlist_idx = nlist_idx - 1
    let name = nlist_order[nlist_idx]
    match index.get(name) {
      Some(node_idx) =>
        if !seen[node_idx] {
          order.push(node_idx)
          seen[node_idx] = true
        }
      None => ()
    }
  }
  for i in 0..<total {
    if !seen[i] {
      order.push(i)
      seen[i] = true
    }
  }
  order
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
    None => @dot_shared.default_node_width_in() * 72.0 / 2.0
  }
  let head_left = match head_size {
    Some(value) => value.left_pt
    None => @dot_shared.default_node_width_in() * 72.0 / 2.0
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
/// Graphviz parity: ratio=compress detection aligned to refs/graphviz/lib/dotgen/dotinit.c.
fn graph_ratio_is_compress(graph : @cgraph.Graph) -> Bool {
  match graph.get_attr("ratio") {
    Some(value) => value.trim().to_lower() == "compress"
    None => false
  }
}

///|
/// Graphviz parity: size parsing aligned to refs/graphviz/lib/common/input.c
/// and dotgen/position.c (compress_graph input width).
fn parse_graph_size_pt_for_compress(graph : @cgraph.Graph) -> (Double, Double)? {
  match graph.get_attr("size") {
    Some(value) => {
      let parts : Array[String] = []
      for part in value.split(",") {
        let cleaned = part.trim(chars=" \n\r\t!").to_string()
        if cleaned != "" {
          parts.push(cleaned)
        }
      }
      if parts.length() == 0 {
        return None
      }
      let width_in = parse_double(parts[0], -1.0)
      let height_in =
        if parts.length() > 1 {
          parse_double(parts[1], -1.0)
        } else {
          width_in
        }
      if width_in <= 0.0 || height_in <= 0.0 {
        return None
      }
      Some((width_in * 72.0, height_in * 72.0))
    }
    None => None
  }
}

///|
/// Graphviz parity: compress_graph width clamp aligned to
/// refs/graphviz/lib/dotgen/position.c (MIN(size, USHRT_MAX)).
fn compress_width_minlen_pt(
  graph : @cgraph.Graph,
  rankdir : RankDir,
) -> Int? {
  if !graph_ratio_is_compress(graph) {
    return None
  }
  let (size_w, size_h) = match parse_graph_size_pt_for_compress(graph) {
    Some(value) => value
    None => return None
  }
  let width_pt = match rankdir {
    RankDir::LR | RankDir::RL => size_h
    _ => size_w
  }
  if width_pt <= 1.0 {
    return None
  }
  let clamped = if width_pt > 65535.0 { 65535.0 } else { width_pt }
  Some(round_int(clamped))
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

fn collect_graph_nodes_for_cluster_members(
  graph : @cgraph.Graph,
  nodes_out : Map[String, Bool],
) -> Unit {
  for node in graph.nodes() {
    if graph_contains_node(graph, node) {
      nodes_out[node.name()] = true
    }
  }
  for child in graph.subgraphs() {
    collect_graph_nodes_for_cluster_members(child, nodes_out)
  }
}

fn collect_cluster_members_for_xpos(
  cluster_graphs : Map[String, @cgraph.Graph],
) -> Map[String, Map[String, Bool]] {
  let members : Map[String, Map[String, Bool]] = Map::new()
  for name, cluster_graph in cluster_graphs {
    let set : Map[String, Bool] = Map::new()
    collect_graph_nodes_for_cluster_members(cluster_graph, set)
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
  @dot_shared.collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  if cluster_graphs.length() == 0 {
    return ([], [], [], [])
  }
  let cluster_members = collect_cluster_members_for_xpos(cluster_graphs)
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
  // Graphviz parity: in LR/RL, cluster label height becomes horizontal border
  // slack in x-constraints (post-flip label geometry).
  let flip = {
    let rankdir = graph_rankdir(graph)
    rankdir == RankDir::LR || rankdir == RankDir::RL
  }
  if edge_vnodes.length() > 0 {
    for edge in edges {
      let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
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
  let cluster_border_left : Map[String, Double] = Map::new()
  let cluster_border_right : Map[String, Double] = Map::new()
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_max_rank : Map[String, Int] = Map::new()
  let extra_nodes : Array[(String, Int)] = []
  let extra_edges : Array[ConstraintEdge] = []
  for name, cluster_graph in cluster_graphs {
    cluster_margins[name] = cluster_margin_pt(cluster_graph)
    let mut left_border = 0.0
    let mut right_border = 0.0
    if flip {
      match graph_label_metrics(cluster_graph) {
        Some((_width_pt, height_pt)) => {
          let border = height_pt + CLUSTER_LABEL_PAD_PT
          match graph_label_loc(cluster_graph) {
            LabelLoc::Top => right_border = border
            LabelLoc::Bottom => left_border = border
          }
        }
        None => ()
      }
    }
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
        let left_border = match cluster_border_left.get(name) {
          Some(value) => value
          None => 0.0
        }
        let right_border = match cluster_border_right.get(name) {
          Some(value) => value
          None => 0.0
        }
        extra_nodes.push((ln_name, trunc_int(left - margin - left_border)))
        extra_nodes.push((rn_name, trunc_int(right + margin + right_border)))
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
    // Graphviz parity: LR/RL handles cluster label extents via left/right
    // border slack, so do not add standalone label minlen here.
    if !flip {
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
              cluster_key_from_skeleton_name(node_name) is None {
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
            node_left_pt(left_name, sizes) + margin + left_border,
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
            node_right_pt(right_name, sizes) + margin + right_border,
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
              let minlen = round_int(node_right_pt(outside, sizes) + margin)
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
              let minlen = round_int(node_left_pt(outside, sizes) + margin)
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
                let parent_left_border = match cluster_border_left.get(parent_name) {
                  Some(value) => value
                  None => 0.0
                }
                let parent_right_border = match cluster_border_right.get(parent_name) {
                  Some(value) => value
                  None => 0.0
                }
                let left_minlen = round_int(margin + parent_left_border)
                let right_minlen = round_int(margin + parent_right_border)
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
                                      if cluster_key_from_skeleton_name(node_name)
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
fn fallback_compass_size() -> NodeSize {
  let width_pt = @dot_shared.default_node_width_in() * 72.0
  let height_pt = @dot_shared.default_node_height_in() * 72.0
  let half = width_pt / 2.0
  {
    width_in: width_pt / 72.0,
    height_in: height_pt / 72.0,
    width_pt,
    height_pt,
    left_pt: half,
    right_pt: half,
  }
}

///|
fn node_size_for_compass(
  node_name : String,
  sizes : Map[String, NodeSize],
) -> NodeSize {
  match sizes.get(node_name) {
    Some(value) => value
    None => fallback_compass_size()
  }
}

///|
fn compass_uses_shape_clipping(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" | "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      true
    "diamond"
    | "mdiamond"
    | "triangle"
    | "invtriangle"
    | "trapezium"
    | "invtrapezium"
    | "parallelogram"
    | "egg"
    | "house"
    | "invhouse"
    | "pentagon"
    | "hexagon"
    | "septagon"
    | "octagon"
    | "doubleoctagon"
    | "tripleoctagon" =>
      true
    "polygon" => {
      let (sides, _peripheries, orientation, distortion, skew, _regular) =
        polygon_shape_attrs(node)
      if sides < 3 {
        true
      } else {
        !polygon_is_box_like(sides, orientation, distortion, skew)
      }
    }
    _ => false
  }
}

fn compass_port_point(
  node_name : String,
  node : @cgraph.Node?,
  compass : @cgraph.Compass,
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
) -> @geom.Point {
  let base_size = node_size_for_compass(node_name, sizes)
  let half_height = base_size.height_pt / 2.0
  let left = -base_size.left_pt
  let right = base_size.right_pt
  let top = half_height
  let bottom = -half_height
  let base_point = match compass {
    @cgraph.Compass::C => @geom.Point::{ x: 0.0, y: 0.0 }
    _ =>
      match node {
        Some(value) =>
          if compass_uses_shape_clipping(value) {
            @edge_spline.compass_port_point_on_shape(
              value,
              @edge_spline.point(0.0, 0.0),
              base_size,
              compass,
              rankdir,
            )
          } else {
            match compass {
              @cgraph.Compass::N => @geom.Point::{ x: 0.0, y: top }
              @cgraph.Compass::NE => @geom.Point::{ x: right, y: top }
              @cgraph.Compass::E => @geom.Point::{ x: right, y: 0.0 }
              @cgraph.Compass::SE => @geom.Point::{ x: right, y: bottom }
              @cgraph.Compass::S => @geom.Point::{ x: 0.0, y: bottom }
              @cgraph.Compass::SW => @geom.Point::{ x: left, y: bottom }
              @cgraph.Compass::W => @geom.Point::{ x: left, y: 0.0 }
              @cgraph.Compass::NW => @geom.Point::{ x: left, y: top }
              @cgraph.Compass::C => @geom.Point::{ x: 0.0, y: 0.0 }
            }
          }
        None =>
          match compass {
            @cgraph.Compass::N => @geom.Point::{ x: 0.0, y: top }
            @cgraph.Compass::NE => @geom.Point::{ x: right, y: top }
            @cgraph.Compass::E => @geom.Point::{ x: right, y: 0.0 }
            @cgraph.Compass::SE => @geom.Point::{ x: right, y: bottom }
            @cgraph.Compass::S => @geom.Point::{ x: 0.0, y: bottom }
            @cgraph.Compass::SW => @geom.Point::{ x: left, y: bottom }
            @cgraph.Compass::W => @geom.Point::{ x: left, y: 0.0 }
            @cgraph.Compass::NW => @geom.Point::{ x: left, y: top }
            @cgraph.Compass::C => @geom.Point::{ x: 0.0, y: 0.0 }
          }
      }
  }
  layout_port_offset(base_point, rankdir)
}

///|
fn compass_port_offset(
  compass : @cgraph.Compass,
  node_name : String,
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  let node = nodes_by_name.get(node_name)
  let unrotated = compass_port_point(node_name, node, compass, sizes, RankDir::TB)
  match node {
    Some(value) =>
      if is_record_shape(value) || @html_label.is_html_label_text(label_text(value)) {
        // Preserve record/html order behavior for explicit label ports.
        unrotated.x
      } else {
        // Graphviz parity: make_edge_pairs consumes compassPort rankdir-rotated
        // ED_{tail,head}_port.p.x for non-record compass-only endpoints.
        layout_port_offset(unrotated, rankdir).x
      }
    None => layout_port_offset(unrotated, rankdir).x
  }
}

///|
fn edge_port_offset(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
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
                    Some(compass) =>
                      compass_port_offset(
                        compass,
                        node_name,
                        sizes,
                        rankdir,
                        nodes_by_name,
                      )
                    None => 0.0
                  }
              }
            None =>
              match value.compass {
                Some(compass) =>
                  compass_port_offset(
                    compass,
                    node_name,
                    sizes,
                    rankdir,
                    nodes_by_name,
                  )
                None => 0.0
              }
          }
        None =>
          match value.compass {
            Some(compass) =>
              compass_port_offset(
                compass,
                node_name,
                sizes,
                rankdir,
                nodes_by_name,
              )
            None => 0.0
          }
      }
    None => 0.0
  }
}

///|
/// Graphviz parity: port order uses compassPort angle quantization
/// (MC_SCALE=256) for mincross medians (shapes.c + mincross.c).
/// Do not change behavior without updating fixtures/tests.
fn port_order_fraction(point : @geom.Point) -> Double {
  if point.x == 0.0 && point.y == 0.0 {
    return 0.5
  }
  let two_pi = 2.0 * @math.PI
  let mut angle = @edge_spline.libm_atan2(point.y, point.x) + 1.5 * @math.PI
  if angle >= two_pi {
    angle = angle - two_pi
  }
  let scaled = (256.0 * angle / two_pi).trunc()
  scaled / 256.0
}

///|
fn record_port_point(
  port_info : RecordPort,
  compass : @cgraph.Compass?,
) -> @geom.Point {
  let center = port_info.center
  let half_w = port_info.size.width_pt / 2.0
  let half_h = port_info.size.height_pt / 2.0
  match compass {
    Some(value) =>
      match value {
        @cgraph.Compass::N => { x: center.x, y: center.y + half_h }
        @cgraph.Compass::NE => { x: center.x + half_w, y: center.y + half_h }
        @cgraph.Compass::E => { x: center.x + half_w, y: center.y }
        @cgraph.Compass::SE => { x: center.x + half_w, y: center.y - half_h }
        @cgraph.Compass::S => { x: center.x, y: center.y - half_h }
        @cgraph.Compass::SW => { x: center.x - half_w, y: center.y - half_h }
        @cgraph.Compass::W => { x: center.x - half_w, y: center.y }
        @cgraph.Compass::NW => { x: center.x - half_w, y: center.y + half_h }
        @cgraph.Compass::C => center
      }
    None => center
  }
}

///|
fn edge_port_order(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  if !@dot_shared.port_is_explicit(port) {
    // Graphviz parity: absent ports contribute neutral 0.0 offset/order.
    return 0.0
  }
  match port {
    Some(value) =>
      match value.name {
        Some(name) =>
          match offsets.get(node_name) {
            Some(node_offsets) =>
              match node_offsets.get(name) {
                Some(port_info) =>
                  port_order_fraction(record_port_point(port_info, value.compass))
                None =>
                  match value.compass {
                    Some(compass) =>
                      port_order_fraction(
                        compass_port_point(
                          node_name,
                          nodes_by_name.get(node_name),
                          compass,
                          sizes,
                          rankdir,
                        ),
                      )
                    None => 0.5
                  }
              }
            None =>
              match value.compass {
                Some(compass) =>
                  port_order_fraction(
                    compass_port_point(
                      node_name,
                      nodes_by_name.get(node_name),
                      compass,
                      sizes,
                      rankdir,
                    ),
                  )
                None => 0.5
              }
          }
        None =>
          match value.compass {
            Some(compass) =>
              port_order_fraction(
                compass_port_point(
                  node_name,
                  nodes_by_name.get(node_name),
                  compass,
                  sizes,
                  rankdir,
                ),
              )
            None => 0.5
          }
      }
    None => 0.5
  }
}

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
/// Graphviz parity: constraint graph uses GD_nlist order for existing
/// nodes and appends aux slack/cluster nodes per create_aux_edges.
/// Do not change behavior without updating fixtures/tests.
fn build_constraint_graph(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
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
  compress_width_minlen : Int?,
) -> (NsGraph, Map[String, Int]) {
  let _ = extra_slack_edges
  let graph = @network_simplex.new_graph()
  let ordered_nodes = nodes
  let mut has_port_edges = false
  for edge in edges {
    if @dot_shared.port_is_explicit(edge.tail_port()) || @dot_shared.port_is_explicit(edge.head_port()) {
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
  let rankdir =
    if nodes.length() > 0 { graph_rankdir(nodes[0].graph()) } else { RankDir::TB }
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
  let real_by_name : Map[String, @cgraph.Node] = Map::new()
  for node in nodes {
    real_by_name[node.name()] = node
  }
  let extra_rank : Map[String, Int] = Map::new()
  for pair in early_extra_nodes {
    let (name, rank) = pair
    extra_rank[name] = rank
  }
  let ordered_names : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  let base_order =
    if gdnlist_order.length() > 0 { gdnlist_order } else { nlist_order }
  for name in base_order {
    if real_by_name.get(name) is Some(_) || extra_rank.get(name) is Some(_) {
      if seen.get(name) is None {
        ordered_names.push(name)
        seen[name] = true
      }
    }
  }
  for node in nodes {
    let name = node.name()
    if seen.get(name) is None {
      ordered_names.push(name)
      seen[name] = true
    }
  }
  for name, _rank in extra_rank {
    if seen.get(name) is None {
      ordered_names.push(name)
      seen[name] = true
    }
  }
  let index : Map[String, Int] = Map::new()
  for name in ordered_names {
    match real_by_name.get(name) {
      Some(node) => {
        let idx = @network_simplex.add_node(graph, node.name())
        index[name] = idx
        let pos = match base_positions.get(name) {
          Some(value) => value
          None => 0.0
        }
        @network_simplex.set_node_rank(graph, idx, trunc_int(pos))
      }
      None =>
        match extra_rank.get(name) {
          Some(rank) => {
            let idx = @network_simplex.add_node(graph, name, kind=extra_node_kind(name))
            index[name] = idx
            let pos = match base_positions.get(name) {
              Some(value) => value
              None => rank.to_double()
            }
            @network_simplex.set_node_rank(graph, idx, trunc_int(pos))
          }
          None => ()
        }
    }
  }
  let rank_adj_constraints : Map[String, (String, String, Int, Int)] = Map::new()
  let rank_adj_order : Array[String] = []
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
      let minlen = nodesep_minlen(
        tail,
        head,
        sizes,
        rank_nodesep,
      )
      let key = "\{tail}|\{head}"
      rank_adj_constraints[key] = (tail, head, minlen, 0)
      rank_adj_order.push(key)
      i = i + 1
    }
  }
  let order_in_rank : Map[String, Int] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    for i in 0..<names.length() {
      order_in_rank[names[i]] = i
    }
  }
  let segments_by_tail : Map[String, Array[SlackSegment]] = Map::new()
  let flat_minlen_constraints : Map[String, (String, String, Int, Int)] = Map::new()
  let merged_edge_weight_bonus : Map[Int, Int] = Map::new()
  let merged_edge_skip : Map[Int, Bool] = Map::new()
  let port_merge_key = (port : @cgraph.Port?) => {
    match port {
      None => ""
      Some(value) => {
        let mut out = ""
        match value.name {
          Some(name) => out = name
          None => ()
        }
        match value.compass {
          Some(compass) => {
            let side = match compass {
              @cgraph.Compass::N => "n"
              @cgraph.Compass::NE => "ne"
              @cgraph.Compass::E => "e"
              @cgraph.Compass::SE => "se"
              @cgraph.Compass::S => "s"
              @cgraph.Compass::SW => "sw"
              @cgraph.Compass::W => "w"
              @cgraph.Compass::NW => "nw"
              @cgraph.Compass::C => "c"
            }
            if out == "" {
              out = side
            } else {
              out = "\{out}:\{side}"
            }
          }
          None => ()
        }
        out
      }
    }
  }
  let merge_key = (
    tail : String,
    head : String,
    tail_port : @cgraph.Port?,
    head_port : @cgraph.Port?,
  ) => {
    "\{tail}|\{head}|\{port_merge_key(tail_port)}|\{port_merge_key(head_port)}"
  }
  let forward_rep_by_key : Map[String, Int] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    if edge_mid_label_metrics(edge) is Some(_) {
      continue
    }
    if edge.tail().name() == edge.head().name() {
      continue
    }
    let oriented_tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let oriented_head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let is_reversed =
      oriented_tail == edge.head().name() &&
      oriented_head == edge.tail().name()
    if is_reversed {
      continue
    }
    let key =
      merge_key(
        edge.tail().name(),
        edge.head().name(),
        edge.tail_port(),
        edge.head_port(),
      )
    if forward_rep_by_key.get(key) is None {
      forward_rep_by_key[key] = edge_idx
    }
  }
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    if edge_mid_label_metrics(edge) is Some(_) {
      continue
    }
    if edge.tail().name() == edge.head().name() {
      continue
    }
    let oriented_tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let oriented_head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let is_reversed =
      oriented_tail == edge.head().name() &&
      oriented_head == edge.tail().name()
    if !is_reversed {
      continue
    }
    let key =
      merge_key(
        edge.head().name(),
        edge.tail().name(),
        edge.tail_port(),
        edge.head_port(),
      )
    match forward_rep_by_key.get(key) {
      Some(rep_idx) => {
        if rep_idx == edge_idx {
          continue
        }
        merged_edge_skip[edge_idx] = true
        let prev_bonus = match merged_edge_weight_bonus.get(rep_idx) {
          Some(value) => value
          None => 0
        }
        merged_edge_weight_bonus[rep_idx] = prev_bonus + @dot_shared.edge_weight(edge)
      }
      None => ()
    }
  }
  let add_segment = (
    seg_tail : String,
    seg_head : String,
    weight : Int,
    tail_port : @cgraph.Port?,
    head_port : @cgraph.Port?,
  ) => {
    let entry = { tail: seg_tail, head: seg_head, weight, tail_port, head_port }
    match segments_by_tail.get(seg_tail) {
      Some(list) => list.push(entry)
      None => segments_by_tail[seg_tail] = [entry]
    }
  }
  let record_edge_segments = (edge_idx : Int, edge : @cgraph.Edge) => {
    if merged_edge_skip.get(edge_idx) is Some(_) {
      return ()
    }
    let tail_name =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head_name =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
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
      ()
    } else {
      match (ranks.get(tail_name), ranks.get(head_name)) {
        (Some(tail_rank), Some(head_rank)) =>
          if tail_name == head_name {
            // Graphviz parity: make_edge_pairs skips self-edges (handled via ND_other).
            ()
          } else {
            let weight_bonus = match merged_edge_weight_bonus.get(edge_idx) {
              Some(value) => value
              None => 0
            }
            if tail_rank == head_rank && @dot_shared.edge_is_constraint(edge) &&
              edge_mid_label_metrics(edge) is None {
              let (left, right) =
                match (order_in_rank.get(tail_name), order_in_rank.get(head_name)) {
                  (Some(tail_order), Some(head_order)) =>
                    if tail_order <= head_order {
                      (tail_name, head_name)
                    } else {
                      (head_name, tail_name)
                    }
                  _ =>
                    if tail_name <= head_name {
                      (tail_name, head_name)
                    } else {
                      (head_name, tail_name)
                    }
                }
                let width = node_right_pt(left, sizes) + node_left_pt(right, sizes)
                let mut minlen_value =
                  Double::from_int(@dot_shared.edge_minlen(edge)) * nodesep_pt + width
                let is_invis = match edge.get_attr("style") {
                  Some(style) => style.to_lower().contains("invis")
                  None => false
                }
                let has_ordering =
                  match root_graph_for_node(edge.tail()).get_attr("ordering") {
                  Some(value) => {
                    let lower = value.to_lower()
                    lower == "out" || lower == "in"
                  }
                  None => false
                }
                if is_invis && has_ordering {
                  minlen_value = minlen_value + nodesep_pt
                }
                let minlen = trunc_int(minlen_value)
                let weight = @dot_shared.edge_weight(edge)
                let flat_key = "\{left}|\{right}"
                match rank_adj_constraints.get(flat_key) {
                  Some(entry) => {
                  let (tail, head, prev_minlen, prev_weight) = entry
                  let next_minlen = if minlen > prev_minlen { minlen } else { prev_minlen }
                  let next_weight = if weight > prev_weight { weight } else { prev_weight }
                  rank_adj_constraints[flat_key] = (tail, head, next_minlen, next_weight)
                }
                None =>
                  match flat_minlen_constraints.get(flat_key) {
                    Some(entry) => {
                      let (_prev_left, _prev_right, prev_minlen, prev_weight) = entry
                      let next_minlen = if minlen > prev_minlen { minlen } else { prev_minlen }
                      let next_weight = if weight > prev_weight { weight } else { prev_weight }
                      flat_minlen_constraints[flat_key] =
                        (left, right, next_minlen, next_weight)
                    }
                    None => flat_minlen_constraints[flat_key] =
                      (left, right, minlen, weight)
                  }
              }
            } else {
              let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
                Some(list) => list
                None => []
              }
              let ordered_vnodes =
                if tail_rank <= head_rank {
                vnodes
              } else {
                let reversed : Array[String] = []
                let mut idx = vnodes.length()
                while idx > 0 {
                  idx = idx - 1
                  reversed.push(vnodes[idx])
                }
                reversed
              }
              let chain : Array[String] = []
              chain.push(tail_name)
              for vnode in ordered_vnodes {
                chain.push(vnode)
              }
                if tail_name != head_name || ordered_vnodes.length() == 0 {
                  chain.push(head_name)
                }
                let base_weight = @dot_shared.edge_weight(edge)
                let orig_tail = edge.tail().name()
                let orig_head = edge.head().name()
              let mut idx = 0
              while idx + 1 < chain.length() {
                let seg_tail = chain[idx]
                let seg_head = chain[idx + 1]
                idx = idx + 1
                let seg_base_weight =
                  if is_edge_vnode_name(seg_tail) || is_edge_vnode_name(seg_head) {
                  let tail_class = endpoint_class(seg_tail, node_degrees, cluster_keys)
                  let head_class = endpoint_class(seg_head, node_degrees, cluster_keys)
                  scaled_edge_weight(base_weight, tail_class, head_class)
                } else {
                  base_weight
                }
                let weight = seg_base_weight + weight_bonus
                let mut tail_port =
                  if seg_tail == orig_tail {
                  edge.tail_port()
                } else if seg_tail == orig_head {
                  edge.head_port()
                } else {
                  None
                }
                let mut head_port =
                  if seg_head == orig_head {
                  edge.head_port()
                } else if seg_head == orig_tail {
                  edge.tail_port()
                } else {
                  None
                }
                if tail_rank == head_rank &&
                  edge_mid_label_metrics(edge) is Some(_) &&
                  !@dot_shared.port_is_explicit(edge.tail_port()) &&
                  !@dot_shared.port_is_explicit(edge.head_port()) &&
                  (match root_graph_for_node(edge.tail()).get_attr("ordering") {
                    Some(value) => {
                      let lower = value.to_lower()
                      lower == "out" || lower == "in"
                    }
                    None => false
                  }) &&
                  seg_tail == orig_tail &&
                  is_edge_vnode_name(seg_head) {
                  let forward =
                    match (order_in_rank.get(seg_tail), order_in_rank.get(seg_head)) {
                      (Some(tail_order), Some(head_order)) => tail_order <= head_order
                      _ => seg_tail <= seg_head
                    }
                  if forward {
                    tail_port = Some({ name: None, compass: Some(@cgraph.Compass::E) })
                    head_port = Some({ name: None, compass: Some(@cgraph.Compass::W) })
                  } else {
                    tail_port = Some({ name: None, compass: Some(@cgraph.Compass::W) })
                    head_port = Some({ name: None, compass: Some(@cgraph.Compass::E) })
                  }
                }
                add_segment(seg_tail, seg_head, weight, tail_port, head_port)
              }
            }
          }
        _ => ()
      }
    }
  }
  let seen_edges : Map[Int, Bool] = Map::new()
  for tail_name in nlist_order {
    let indices = match edge_out_order.get(tail_name) {
      Some(list) => list
      None => []
    }
    for edge_idx in indices {
      if edge_idx < 0 || edge_idx >= edges.length() {
        continue
      }
      seen_edges[edge_idx] = true
      record_edge_segments(edge_idx, edges[edge_idx])
    }
  }
  if seen_edges.length() < edges.length() {
    for edge_idx in 0..<edges.length() {
      if seen_edges.get(edge_idx) is None {
        record_edge_segments(edge_idx, edges[edge_idx])
      }
    }
  }
  for key in rank_adj_order {
    match rank_adj_constraints.get(key) {
      Some(entry) => {
        let (tail, head, minlen, weight) = entry
        match index.get(tail) {
          Some(tail_idx) =>
            match index.get(head) {
              Some(head_idx) => {
                let _ = @network_simplex.add_edge(graph, tail_idx, head_idx, minlen, weight)
              }
              None => ()
            }
          None => ()
        }
      }
      None => ()
    }
  }
  for _flat_key, entry in flat_minlen_constraints {
    let (left, right, minlen, weight) = entry
    match index.get(left) {
      Some(tail_idx) =>
        match index.get(right) {
          Some(head_idx) => {
            let _ = @network_simplex.add_edge(graph, tail_idx, head_idx, minlen, weight)
          }
          None => ()
        }
      None => ()
    }
  }
  let tail_seen : Map[String, Bool] = Map::new()
  for tail_name in nlist_order {
    let segments = match segments_by_tail.get(tail_name) {
      Some(list) => list
      None => []
    }
    for seg in segments {
      let tail_idx = match index.get(seg.tail) {
        Some(value) => value
        None => continue
      }
      let head_idx = match index.get(seg.head) {
        Some(value) => value
        None => continue
      }
      let tail_offset = edge_port_offset(
        seg.tail,
        seg.tail_port,
        port_offsets,
        sizes,
        rankdir,
        real_by_name,
      )
      let head_offset = edge_port_offset(
        seg.head,
        seg.head_port,
        port_offsets,
        sizes,
        rankdir,
        real_by_name,
      )
      let delta = head_offset - tail_offset
      let m0 = if delta > 0.0 { trunc_int(delta) } else { 0 }
      let m1 = if delta < 0.0 { trunc_int(-delta) } else { 0 }
      // Graphviz parity: make_edge_pairs applies to each virtual edge segment.
      let slack_idx = @network_simplex.add_node(graph, "", kind=NodeKind::Slack)
      let tail_rank = @network_simplex.node_rank(graph, tail_idx)
      let head_rank = @network_simplex.node_rank(graph, head_idx)
      let base_tail = tail_rank - m0 - 1
      let base_head = head_rank - m1 - 1
      @network_simplex.set_node_rank(
        graph,
        slack_idx,
        if base_tail < base_head { base_tail } else { base_head },
      )
      let _ = @network_simplex.add_edge(graph, slack_idx, tail_idx, m0 + 1, seg.weight)
      let _ = @network_simplex.add_edge(graph, slack_idx, head_idx, m1 + 1, seg.weight)
    }
    tail_seen[tail_name] = true
  }
  for tail_name, segments in segments_by_tail {
    if tail_seen.get(tail_name) is None {
      for seg in segments {
        let tail_idx = match index.get(seg.tail) {
          Some(value) => value
          None => continue
        }
        let head_idx = match index.get(seg.head) {
          Some(value) => value
          None => continue
        }
        let tail_offset = edge_port_offset(
          seg.tail,
          seg.tail_port,
          port_offsets,
          sizes,
          rankdir,
          real_by_name,
        )
        let head_offset = edge_port_offset(
          seg.head,
          seg.head_port,
          port_offsets,
          sizes,
          rankdir,
          real_by_name,
        )
        let delta = head_offset - tail_offset
        let m0 = if delta > 0.0 { trunc_int(delta) } else { 0 }
        let m1 = if delta < 0.0 { trunc_int(-delta) } else { 0 }
        let slack_idx = @network_simplex.add_node(graph, "", kind=NodeKind::Slack)
        let tail_rank = @network_simplex.node_rank(graph, tail_idx)
        let head_rank = @network_simplex.node_rank(graph, head_idx)
        let base_tail = tail_rank - m0 - 1
        let base_head = head_rank - m1 - 1
        @network_simplex.set_node_rank(
          graph,
          slack_idx,
          if base_tail < base_head { base_tail } else { base_head },
        )
        let _ = @network_simplex.add_edge(graph, slack_idx, tail_idx, m0 + 1, seg.weight)
        let _ = @network_simplex.add_edge(graph, slack_idx, head_idx, m1 + 1, seg.weight)
      }
    }
  }
  for pair in late_extra_nodes {
    let (name, _rank) = pair
    let idx = @network_simplex.add_node(graph, name, kind=extra_node_kind(name))
    index[name] = idx
    // Graphviz parity: cluster boundary helpers enter the aux graph at rank 0
    // and are later positioned by constraints, not by seed x ranks.
    @network_simplex.set_node_rank(graph, idx, 0)
  }
  if root_ln_targets.length() > 0 || root_rn_targets.length() > 0 {
    let root_ln = @network_simplex.add_node(graph, "", kind=NodeKind::Slack)
    let root_rn = @network_simplex.add_node(graph, "", kind=NodeKind::Slack)
    @network_simplex.set_node_rank(graph, root_ln, 0)
    @network_simplex.set_node_rank(graph, root_rn, 0)
    let root_margin = if nodes.length() > 0 {
      cluster_margin_pt(nodes[0].graph())
    } else {
      CLUSTER_MARGIN_PT
    }
    let compress_mode = compress_width_minlen is Some(_)
    for name in root_ln_targets {
      match index.get(name) {
        Some(idx) => {
          let minlen =
            if compress_mode {
              round_int(node_left_pt(name, sizes) + root_margin)
            } else {
              round_int(root_margin)
            }
          let _ = @network_simplex.add_edge(graph, root_ln, idx, minlen, 0)
        }
        None => ()
      }
    }
    for name in root_rn_targets {
      match index.get(name) {
        Some(idx) => {
          let minlen =
            if compress_mode {
              round_int(node_right_pt(name, sizes) + root_margin)
            } else {
              round_int(root_margin)
            }
          let _ = @network_simplex.add_edge(graph, idx, root_rn, minlen, 0)
        }
        None => ()
      }
    }
    match compress_width_minlen {
      Some(width_minlen) => {
        let _ = @network_simplex.add_edge(
          graph,
          root_ln,
          root_rn,
          width_minlen,
          ROOT_COMPRESS_WEIGHT,
        )
      }
      None => ()
    }
  }
  for edge in extra_edges {
    let _ = edge.tail_port
    let _ = edge.head_port
    match index.get(edge.tail) {
      Some(tail_idx) =>
        match index.get(edge.head) {
          Some(head_idx) => {
            let _ = @network_simplex.add_edge(
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
  edge_out_order : Map[String, Array[Int]],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
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
  compress_width_minlen : Int?,
) -> Map[String, Double] {
  dot_trace("xpos: build constraint graph")
  // Graphviz parity: class2/decompose creation order is the reverse of
  // GD_nlist iteration order consumed by create_aux_edges/position.
  let nlist_source =
    if gdnlist_order.length() > 0 {
      gdnlist_order
    } else {
      nlist_order
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
  let rankdir = graph_rankdir(graph_root)
  let prefer_source_for_lr =
    rankdir == RankDir::LR || rankdir == RankDir::RL
  for name in nlist_reversed {
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster != "" && cluster_seen.get(cluster) is None {
      cluster_seen[cluster] = true
      cluster_order.push(cluster)
    }
  }
  if prefer_source_for_lr || cluster_order.length() == 0 {
    for name in nlist_source {
      xpos_nlist_order.push(name)
    }
  } else {
    let xpos_seen : Map[String, Bool] = Map::new()
    for cluster in cluster_order {
      let mut rank_idx = rank_keys.length()
      while rank_idx > 0 {
        rank_idx = rank_idx - 1
        let rank = rank_keys[rank_idx]
        let names = match groups.get(rank) {
          Some(list) => list
          None => []
        }
        // Graphviz parity: decompose-created virtual nodes are visited before
        // their rank peers in clustered GD_nlist traversals.
        let mut name_idx = names.length()
        while name_idx > 0 {
          name_idx = name_idx - 1
          let name = names[name_idx]
          if !is_edge_vnode_name(name) {
            continue
          }
          let name_cluster = match cluster_keys.get(name) {
            Some(value) => value
            None => ""
          }
          if name_cluster == cluster && xpos_seen.get(name) is None {
            xpos_nlist_order.push(name)
            xpos_seen[name] = true
          }
        }
        let mut name_idx = names.length()
        while name_idx > 0 {
          name_idx = name_idx - 1
          let name = names[name_idx]
          if is_edge_vnode_name(name) {
            continue
          }
          let name_cluster = match cluster_keys.get(name) {
            Some(value) => value
            None => ""
          }
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
  }
  let order_index = build_order_index(groups)
  let (graph, index) = build_constraint_graph(
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    xpos_nlist_order,
    xpos_nlist_order,
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
    compress_width_minlen,
  )
  // Graphviz parity: constraint graph reorder follows GD_nlist sequence.
  let order = build_constraint_reorder(graph, index, xpos_nlist_order)
  let (graph, index) = reorder_constraint_graph(graph, index, order)
  if should_capture_xpos_constraints(graph_root) {
    xpos_constraint_snapshot.val = Some(
      build_xpos_constraint_snapshot(graph, index, sizes, order_index),
    )
  }
  dot_trace("xpos: constraint graph built")
  dot_trace("xpos: network simplex")
  @network_simplex.network_simplex(graph, 0x7fffffff, BalanceMode::LR)
  dot_trace("xpos: network simplex done")
  let positions : Map[String, Double] = Map::new()
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    positions[name] = @network_simplex.node_rank(graph, idx).to_double()
  }
  for pair in extra_nodes {
    let (name, _rank) = pair
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    positions[name] = @network_simplex.node_rank(graph, idx).to_double()
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
  edge_out_order : Map[String, Array[Int]],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
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
  let rankdir = graph_rankdir(graph)
  let compress_width_minlen = compress_width_minlen_pt(graph, rankdir)
  let all_root_ln_targets = root_ln_targets.copy()
  let all_root_rn_targets = root_rn_targets.copy()
  match compress_width_minlen {
    Some(_) => {
      // Graphviz parity: contain_nodes constrains per-rank leftmost/rightmost
      // nodes against root ln/rn before adding the compress edge.
      let ln_seen : Map[String, Bool] = Map::new()
      let rn_seen : Map[String, Bool] = Map::new()
      for name in all_root_ln_targets {
        ln_seen[name] = true
      }
      for name in all_root_rn_targets {
        rn_seen[name] = true
      }
      for rank in rank_keys {
        let names = match groups.get(rank) {
          Some(value) => value
          None => []
        }
        if names.length() == 0 {
          continue
        }
        let left_name = names[0]
        let right_name = names[names.length() - 1]
        if ln_seen.get(left_name) is None {
          all_root_ln_targets.push(left_name)
          ln_seen[left_name] = true
        }
        if rn_seen.get(right_name) is None {
          all_root_rn_targets.push(right_name)
          rn_seen[right_name] = true
        }
      }
    }
    None => ()
  }
  x_positions_from_simplex(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    nlist_order,
    gdnlist_order,
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
    all_root_ln_targets,
    all_root_rn_targets,
    compress_width_minlen,
  )
}
