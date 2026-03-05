///|
/// Rank direction for dot layout.
pub(all) enum RankDir {
  TB
  BT
  LR
  RL
} derive(Show, Eq)

///|
/// Node size in inches and points.
pub(all) struct NodeSize {
  width_in : Double
  height_in : Double
  width_pt : Double
  height_pt : Double
  left_pt : Double
  right_pt : Double
}

///|
pub const RECORD_BORDER_PT : Double = 0.5

///|
pub const EDGE_VNODE_PREFIX : String = "_mbt_edge_vn_"

///|
pub const CLUSTER_SKELETON_PREFIX : String = "_mbt_cluster_skel_"

///|
pub const CLUSTER_LN_PREFIX : String = "_mbt_cluster_ln_"

///|
pub const CLUSTER_RN_PREFIX : String = "_mbt_cluster_rn_"

///|
pub fn default_node_width_in() -> Double {
  0.75
}

///|
pub fn default_node_height_in() -> Double {
  0.5
}

///|
pub fn env_flag_enabled(
  value : String?,
  default_enabled : Bool,
) -> Bool {
  match value {
    Some(raw) => {
      let lower = raw.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => default_enabled
  }
}

///|
pub fn env_flag_enabled_nonempty(value : String?) -> Bool {
  match value {
    Some(raw) => {
      let lower = raw.to_lower()
      lower != "" && lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
}

///|
pub fn parse_double_or(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
pub fn node_size_from_points(
  width_pt : Double,
  height_pt : Double,
) -> NodeSize {
  let width_in = width_pt / 72.0
  let height_in = height_pt / 72.0
  let half = width_pt / 2.0
  { width_in, height_in, width_pt, height_pt, left_pt: half, right_pt: half }
}

///|
pub fn port_is_explicit(port : @cgraph.Port?) -> Bool {
  match port {
    Some(value) => value.name is Some(_) || value.compass is Some(_)
    None => false
  }
}

///|
pub fn port_key(port : @cgraph.Port?) -> String {
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
          let label = match compass {
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
            out = label
          } else {
            out = "\{out}:\{label}"
          }
        }
        None => ()
      }
      out
    }
  }
}

///|
pub fn edge_key(edge : @cgraph.Edge) -> String {
  let tail = edge.tail().name()
  let head = edge.head().name()
  let name = match edge.name() {
    Some(value) => value
    None => ""
  }
  let tail_port = port_key(edge.tail_port())
  let head_port = port_key(edge.head_port())
  "\{tail}|\{head}|\{name}|\{tail_port}|\{head_port}"
}

///|
pub fn edge_vnode_key(edge : @cgraph.Edge) -> String {
  let tail = edge.tail().name()
  let head = edge.head().name()
  let tail_port = port_key(edge.tail_port())
  let head_port = port_key(edge.head_port())
  let base = "\{tail}|\{head}|\{tail_port}|\{head_port}"
  let label = match edge.get_attr("label") {
    Some(value) => value
    None => ""
  }
  if label == "" {
    base
  } else {
    "\{base}|\{edge.id()}"
  }
}

///|
pub fn is_cluster_graph(graph : @cgraph.Graph) -> Bool {
  match graph.name() {
    Some(name) => name.has_prefix("cluster")
    None => false
  }
}

///|
pub fn graph_has_cluster(graph : @cgraph.Graph) -> Bool {
  for child in graph.subgraphs() {
    if is_cluster_graph(child) || graph_has_cluster(child) {
      return true
    }
  }
  false
}

///|
pub fn collect_cluster_graphs(
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
pub fn collect_cluster_names(
  graph : @cgraph.Graph,
  out : Map[String, Bool],
) -> Unit {
  if is_cluster_graph(graph) {
    match graph.name() {
      Some(name) => out[name] = true
      None => ()
    }
  }
  for child in graph.subgraphs() {
    collect_cluster_names(child, out)
  }
}

///|
pub fn collect_graph_nodes(
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
/// Graphviz mapbool() parity for edge `constraint` handling.
pub fn edge_is_constraint(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("constraint") {
    Some(value) => {
      // Graphviz mapbool() parity:
      // - empty string keeps default (constraint=true)
      // - unknown non-empty tokens map to false
      let trimmed = value.trim()
      if trimmed == "" {
        true
      } else {
        let lower = trimmed.to_lower()
        if lower == "false" || lower == "no" {
          false
        } else if lower == "true" || lower == "yes" {
          true
        } else {
          match lower.get_char(0) {
            Some(c) =>
              if c.is_ascii_digit() {
                let mut acc = 0
                let mut seen = false
                for ch in lower {
                  if ch.is_ascii_digit() {
                    seen = true
                    acc = acc * 10 + (ch.to_int() - '0'.to_int())
                  } else {
                    break
                  }
                }
                seen && acc != 0
              } else {
                false
              }
            None => true
          }
        }
      }
    }
    None => true
  }
}

///|
pub fn edge_weight(edge : @cgraph.Edge) -> Int {
  let weight_value = @attrs.parse_double(edge.get_attr("weight"), 1.0)
  let mut weight = weight_value.round().to_int()
  if weight < 0 {
    weight = 0
  }
  if !edge_is_constraint(edge) {
    return 0
  }
  let tail_group = match edge.tail().get_attr("group") {
    Some(value) => value
    None => ""
  }
  let head_group = match edge.head().get_attr("group") {
    Some(value) => value
    None => ""
  }
  if tail_group != "" && tail_group == head_group {
    weight = weight * 100
  }
  weight
}

///|
pub fn edge_minlen(edge : @cgraph.Edge) -> Int {
  let minlen_value = @attrs.parse_double(edge.get_attr("minlen"), 1.0)
  let minlen = minlen_value.round().to_int()
  if minlen < 1 {
    1
  } else {
    minlen
  }
}

///|
pub fn edge_xpenalty(edge : @cgraph.Edge) -> Int {
  let penalty_value = @attrs.parse_double(edge.get_attr("xpenalty"), 1.0)
  let mut penalty = penalty_value.round().to_int()
  if penalty < 0 {
    penalty = 0
  }
  if !edge_is_constraint(edge) {
    return 0
  }
  penalty
}

///|
pub fn parse_flat_constraint_key(key : String) -> (String, String)? {
  match key.find("|") {
    Some(pos) => {
      let len = key.length()
      let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else { "" }
      let head =
        if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
          ""
        }
      Some((tail, head))
    }
    None => None
  }
}

///|
/// Graphviz parity: approximate decompose DFS order over fast graph edges.
/// Do not change behavior without updating fixtures/tests.
pub fn build_graphviz_nlist_order_from_edges(
  tail_order : Array[String],
  order_nodes : Array[String],
  edge_creation : Array[(String, String)],
  flat_constraints : Map[String, Bool],
) -> Array[String] {
  let out_neighbors : Map[String, Array[String]] = Map::new()
  let in_neighbors : Map[String, Array[String]] = Map::new()
  let flat_out : Map[String, Array[String]] = Map::new()
  let flat_in : Map[String, Array[String]] = Map::new()
  for name in order_nodes {
    out_neighbors[name] = []
    in_neighbors[name] = []
    flat_out[name] = []
    flat_in[name] = []
  }
  for edge in edge_creation {
    let (tail, head) = edge
    match out_neighbors.get(tail) {
      Some(list) => list.push(head)
      None => out_neighbors[tail] = [head]
    }
    match in_neighbors.get(head) {
      Some(list) => list.push(tail)
      None => in_neighbors[head] = [tail]
    }
  }
  // Graphviz parity: ND_out/ND_in lists follow edge sequence (AGSEQ) order
  // within a fixed tail/head, so preserve edge_creation insertion order.
  // Do not change behavior without updating fixtures/tests.
  for key, _ in flat_constraints {
    match parse_flat_constraint_key(key) {
      Some((tail, head)) => {
        match flat_out.get(tail) {
          Some(list) => list.push(head)
          None => flat_out[tail] = [head]
        }
        match flat_in.get(head) {
          Some(list) => list.push(tail)
          None => flat_in[head] = [tail]
        }
      }
      None => ()
    }
  }
  let visited : Map[String, Bool] = Map::new()
  for name in order_nodes {
    visited[name] = false
  }
  let nlist : Array[String] = []
  let stack : Array[String] = []
  let push_neighbors = (list : Array[String]) => {
    let mut idx = list.length()
    while idx > 0 {
      idx = idx - 1
      let other = list[idx]
      if visited.get(other) != Some(true) {
        stack.push(other)
      }
    }
  }
  let visit_from = (start : String) => {
    if visited.get(start) == Some(true) {
      return ()
    }
    stack.push(start)
    while stack.length() > 0 {
      let current = stack[stack.length() - 1]
      let _ = stack.pop()
      if visited.get(current) == Some(true) {
        continue
      }
      visited[current] = true
      nlist.push(current)
      let fin = match flat_in.get(current) {
        Some(list) => list
        None => []
      }
      let fout = match flat_out.get(current) {
        Some(list) => list
        None => []
      }
      let inn = match in_neighbors.get(current) {
        Some(list) => list
        None => []
      }
      let out = match out_neighbors.get(current) {
        Some(list) => list
        None => []
      }
      push_neighbors(fin)
      push_neighbors(fout)
      push_neighbors(inn)
      push_neighbors(out)
    }
  }
  // Graphviz parity: agfstnode iteration follows creation order.
  for start in tail_order {
    visit_from(start)
  }
  if nlist.length() < order_nodes.length() {
    for name in order_nodes {
      if visited.get(name) != Some(true) {
        nlist.push(name)
        visited[name] = true
      }
    }
  }
  nlist
}

///|
/// Graphviz parity: rank=same merges nodes into one representative set.
/// Do not change behavior without updating fixtures/tests.
pub fn build_rank_same_reps(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
) -> Map[String, String] {
  let parent : Map[String, String] = Map::new()
  for node in nodes {
    let name = node.name()
    parent[name] = name
  }
  let find = (name : String) => {
    let mut current = name
    let mut next = match parent.get(current) {
      Some(value) => value
      None => current
    }
    while next != current {
      current = next
      next = match parent.get(current) {
        Some(value) => value
        None => current
      }
    }
    // Path compression
    let mut cursor = name
    let mut parent_name = match parent.get(cursor) {
      Some(value) => value
      None => cursor
    }
    while parent_name != current {
      parent[cursor] = current
      cursor = parent_name
      parent_name = match parent.get(cursor) {
        Some(value) => value
        None => current
      }
    }
    current
  }
  let union = (a : String, b : String) => {
    let ra = find(a)
    let rb = find(b)
    if ra != rb {
      parent[rb] = ra
    }
  }
  let stack : Array[@cgraph.Graph] = [graph]
  while stack.length() > 0 {
    let current = stack[stack.length() - 1]
    let _ = stack.pop()
    match current.get_attr("rank") {
      Some(value) => {
        let rank_value = value.to_lower()
        if rank_value == "same" ||
          rank_value == "min" ||
          rank_value == "max" ||
          rank_value == "source" ||
          rank_value == "sink" {
          // Graphviz parity: collapse_rankset merges same/min/max/source/sink
          // subgraph members into one representative before ranking.
          let members = current.nodes()
          let mut leader : String? = None
          for node in members {
            let name = node.name()
            if parent.get(name) is None {
              continue
            }
            match leader {
              Some(lead) => union(lead, name)
              None => leader = Some(name)
            }
          }
          // Graphviz parity: rankset edge statements imply endpoint membership;
          // include their endpoints when explicit node statements are omitted.
          for edge in current.edges() {
            let tail_name = edge.tail().name()
            if parent.get(tail_name) is Some(_) {
              match leader {
                Some(lead) => union(lead, tail_name)
                None => leader = Some(tail_name)
              }
            }
            let head_name = edge.head().name()
            if parent.get(head_name) is Some(_) {
              match leader {
                Some(lead) => union(lead, head_name)
                None => leader = Some(head_name)
              }
            }
          }
        }
      }
      None => ()
    }
    for child in current.subgraphs() {
      stack.push(child)
    }
  }
  let reps : Map[String, String] = Map::new()
  for name, _ in parent {
    reps[name] = find(name)
  }
  reps
}
