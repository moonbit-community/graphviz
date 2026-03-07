///|
/// Rank direction for dot layout.
pub(all) enum RankDir {
  TB
  BT
  LR
  RL
} derive(Show, Eq)

///|
/// Edge direction for directed edge endpoint markers and routing behavior.
pub(all) enum EdgeDir {
  Forward
  Back
  Both
  None
} derive(Show, Eq)

///|
pub fn parse_rankdir(value : String) -> RankDir? {
  match value.to_lower() {
    "tb" => Some(RankDir::TB)
    "bt" => Some(RankDir::BT)
    "lr" => Some(RankDir::LR)
    "rl" => Some(RankDir::RL)
    _ => None
  }
}

///|
pub fn graph_rankdir(graph : @cgraph.Graph) -> RankDir {
  let mut current = graph
  while true {
    match current.get_attr("rankdir") {
      Some(value) =>
        match parse_rankdir(value) {
          Some(parsed) => return parsed
          None => ()
        }
      None => ()
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  RankDir::TB
}

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
/// Record/html label port geometry in layout coordinates.
pub(all) struct RecordPort {
  center : @geom.Point
  size : NodeSize
  sides : Int
}

///|
pub(all) struct GraphSizePt {
  width_pt : Double
  height_pt : Double
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
pub const CL_BACK : Int = 10

///|
pub const VNODE_HEIGHT_PT : Double = 1.0

///|
pub fn default_node_width_in() -> Double {
  0.75
}

///|
pub fn default_node_height_in() -> Double {
  0.5
}

///|
pub fn default_point_size_in() -> Double {
  0.05
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
pub fn parse_edge_dir(value : String) -> EdgeDir? {
  match value.to_lower() {
    "forward" | "f" => Some(EdgeDir::Forward)
    "back" | "b" => Some(EdgeDir::Back)
    "both" => Some(EdgeDir::Both)
    "none" => Some(EdgeDir::None)
    _ => None
  }
}

///|
pub fn edge_dir_for(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> EdgeDir {
  if kind == @cgraph.GraphKind::Undirected {
    return EdgeDir::None
  }
  match edge.get_attr("dir") {
    Some(value) =>
      match parse_edge_dir(value) {
        Some(dir) => dir
        None => EdgeDir::Forward
      }
    None => EdgeDir::Forward
  }
}

///|
pub fn arrow_attr_is_none(value : String?) -> Bool {
  match value {
    Some(raw) => raw.trim().to_lower() == "none"
    None => false
  }
}

///|
pub fn edge_has_head_marker(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> Bool {
  match edge_dir_for(edge, kind) {
    EdgeDir::Forward | EdgeDir::Both => !arrow_attr_is_none(edge.get_attr("arrowhead"))
    _ => false
  }
}

///|
pub fn edge_has_tail_marker(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> Bool {
  match edge_dir_for(edge, kind) {
    EdgeDir::Back | EdgeDir::Both => !arrow_attr_is_none(edge.get_attr("arrowtail"))
    _ => false
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
/// Graphviz ROUND macro parity (round half away from zero).
pub fn round_int(value : Double) -> Int {
  if value >= 0.0 {
    (value + 0.5).floor().to_int()
  } else {
    (value - 0.5).ceil().to_int()
  }
}

///|
pub fn trunc_int(value : Double) -> Int {
  if value >= 0.0 {
    value.floor().to_int()
  } else {
    value.ceil().to_int()
  }
}

///|
fn first_numeric_token(value : String) -> String? {
  let sb = StringBuilder::new()
  let mut seen = false
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
      seen = true
    } else if seen {
      break
    }
  }
  if seen {
    Some(sb.to_string())
  } else {
    None
  }
}

///|
pub fn parse_first_double(value : String, fallback : Double) -> Double {
  match first_numeric_token(value) {
    Some(token) => parse_double_or(token, fallback)
    None => fallback
  }
}

///|
pub fn parse_first_double_optional(value : String) -> Double? {
  match first_numeric_token(value) {
    Some(token) =>
      try @strconv.parse_double(token) catch {
        _ => None
      } noraise {
        parsed => Some(parsed)
      }
    None => None
  }
}

///|
pub fn parse_attr_double(value : String, fallback : Double, min : Double) -> Double {
  match parse_first_double_optional(value) {
    Some(parsed) => if parsed < min { min } else { parsed }
    None => fallback
  }
}

///|
/// Graphviz parity: size parsing aligned to refs/graphviz/lib/common/input.c.
pub fn parse_graph_size_pt_attr(graph : @cgraph.Graph) -> GraphSizePt? {
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
      let width_in = parse_double_or(parts[0], -1.0)
      let height_in =
        if parts.length() > 1 {
          parse_double_or(parts[1], -1.0)
        } else {
          width_in
        }
      if width_in <= 0.0 || height_in <= 0.0 {
        return None
      }
      Some({ width_pt: width_in * 72.0, height_pt: height_in * 72.0 })
    }
    None => None
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
pub fn swap_node_size(size : NodeSize) -> NodeSize {
  let width_in = size.height_in
  let height_in = size.width_in
  let width_pt = size.height_pt
  let height_pt = size.width_pt
  let half = width_pt / 2.0
  { width_in, height_in, width_pt, height_pt, left_pt: half, right_pt: half }
}

///|
pub fn vnode_size_from_widths(left_pt : Double, right_pt : Double) -> NodeSize {
  let width_pt = left_pt + right_pt
  let width_in = width_pt / 72.0
  let height_pt = 1.0
  let height_in = height_pt / 72.0
  {
    width_in,
    height_in,
    width_pt,
    height_pt,
    left_pt,
    right_pt,
  }
}

///|
pub fn vnode_size_from_widths_with_h(
  left_pt : Double,
  right_pt : Double,
  height_pt : Double,
) -> NodeSize {
  let width_pt = left_pt + right_pt
  let width_in = width_pt / 72.0
  let height_in = height_pt / 72.0
  { width_in, height_in, width_pt, height_pt, left_pt, right_pt }
}

///|
pub fn unique_virtual_node_name(
  prefix : String,
  edge_index : Int,
  rank : Int,
  existing : Map[String, Bool],
) -> String {
  let mut candidate = "\{prefix}\{edge_index}_\{rank}"
  if existing.get(candidate) is None {
    existing[candidate] = true
    return candidate
  }
  let mut i = 1
  while true {
    candidate = "\{prefix}\{edge_index}_\{rank}_\{i}"
    if existing.get(candidate) is None {
      existing[candidate] = true
      return candidate
    }
    i = i + 1
  }
  ""
}

///|
pub fn node_left_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.left_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

///|
pub fn node_right_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.right_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

///|
pub fn clip_to_rect(
  center : @geom.Point,
  size : NodeSize,
  target : @geom.Point,
) -> @geom.Point {
  let dx = target.x - center.x
  let dy = target.y - center.y
  if dx == 0.0 && dy == 0.0 {
    return center
  }
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  let tx = if dx == 0.0 { 1000000000.0 } else { half_w / Double::abs(dx) }
  let ty = if dy == 0.0 { 1000000000.0 } else { half_h / Double::abs(dy) }
  let t = if tx < ty { tx } else { ty }
  { x: center.x + dx * t, y: center.y + dy * t }
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
pub fn is_edge_vnode_name(name : String) -> Bool {
  name.has_prefix(EDGE_VNODE_PREFIX)
}

///|
pub fn edge_is_self(edge : @cgraph.Edge) -> Bool {
  edge.tail().name() == edge.head().name()
}

///|
pub fn edge_has_label(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("label") {
    Some(value) => value != ""
    None => false
  }
}

///|
pub fn edge_attr_non_empty(edge : @cgraph.Edge, name : String) -> Bool {
  match edge.get_attr(name) {
    Some(value) => value != ""
    None => false
  }
}

///|
pub fn edge_attr_or_empty(edge : @cgraph.Edge, name : String) -> String {
  match edge.get_attr(name) {
    Some(value) => value
    None => ""
  }
}

///|
pub(all) struct EdgeRankSpan {
  min_rank : Int
  max_rank : Int
}

///|
/// Graphviz parity: edge rank span is resolved from tail/head node ranks
/// before long-edge label and vnode rank-based adjustments.
/// Do not change behavior without updating fixtures/tests.
pub fn edge_rank_span(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
) -> EdgeRankSpan? {
  let tail_rank = match ranks.get(edge.tail().name()) {
    Some(value) => value
    None => return None
  }
  let head_rank = match ranks.get(edge.head().name()) {
    Some(value) => value
    None => return None
  }
  let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
  let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
  Some({ min_rank, max_rank })
}

///|
/// Graphviz parity: record-shape detection follows shape attr values
/// recognized by dot (`record` / `mrecord`).
/// Do not change behavior without updating fixtures/tests.
pub fn is_record_shape(node : @cgraph.Node) -> Bool {
  match node.get_attr("shape") {
    Some(value) =>
      match value.to_lower() {
        "record" | "mrecord" => true
        _ => false
      }
    None => false
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
