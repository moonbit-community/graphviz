///|
priv struct EdgeVnodeInfo {
  vnode_ranks : Map[String, Int]
  vnode_sizes : Map[String, NodeSize]
  vnodes_by_rank : Map[Int, Array[String]]
  edge_vnodes : Map[String, Array[String]]
  vnode_clusters : Map[String, String]
}

///|
fn default_nodesep_in() -> Double {
  0.25
}

///|
fn default_ranksep_in() -> Double {
  0.5
}

///|
const BACKWARD_PENALTY : Int = 1
const CL_BACK : Int = 10
const VNODE_ENDPOINT_WEIGHT : Int = 1
const DEFAULT_VNODE_WEIGHT : Double = 1.0

///|
fn default_point_size_in() -> Double {
  0.05
}

///|
fn dot_trace(message : String) -> Unit {
  if @sys.get_env_var("DOT_TRACE") is Some(_) {
    println(message)
  }
}

///|
fn dot_trace_groups(label : String, groups : Map[Int, Array[String]]) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return ()
  }
  let ranks : Array[Int] = []
  for rank, _ in groups {
    ranks.push(rank)
  }
  ranks.sort()
  for rank in ranks {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let joined = names.join(" ")
    println("\{label} rank \{rank}: \{joined}")
  }
}

///|
fn dot_trace_positions(label : String, positions : Map[String, Double]) -> Unit {
  if @sys.get_env_var("DOT_TRACE_POS") is None {
    return ()
  }
  let keys : Array[String] = []
  for name, _ in positions {
    keys.push(name)
  }
  keys.sort()
  for name in keys {
    let value = match positions.get(name) {
      Some(pos) => pos
      None => 0.0
    }
    println("\{label} \{name}: \{value}")
  }
}

///|
fn dot_trace_edges(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_EDGES") is None {
    return ()
  }
  let mut idx = 0
  for edge in edges {
    let tail = if idx < edge_tail.length() { edge_tail[idx] } else {
      edge.tail().name()
    }
    let head = if idx < edge_head.length() { edge_head[idx] } else {
      edge.head().name()
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => 0
    }
    println("edge \{idx}: \{tail}(\{tail_rank}) -> \{head}(\{head_rank})")
    idx = idx + 1
  }
}

///|
fn dot_trace_route_points(
  edge : @cgraph.Edge,
  points : Array[@geom.Point],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_ROUTE") is None {
    return ()
  }
  let tail = edge.tail().name()
  let head = edge.head().name()
  let parts : Array[String] = []
  for point in points {
    parts.push("\{point.x},\{point.y}")
  }
  let joined = parts.join(" ")
  println("route \{tail} -> \{head}: \{joined}")
}

///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
fn parse_first_double(value : String, fallback : Double) -> Double {
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
  if !seen {
    fallback
  } else {
    parse_double(sb.to_string(), fallback)
  }
}

///|
fn validate_nonnegative_attr(
  owner : String,
  attr_name : String,
  raw_value : String,
  value : Double,
) -> Unit raise DotLayoutError {
  if value < 0.0 {
    raise DotLayoutError::InvalidGraph(
      message="\{owner} has negative \{attr_name}: \{raw_value}",
    )
  }
}

///|
fn validate_graph_spacing(graph : @cgraph.Graph) -> Unit raise DotLayoutError {
  match graph.get_attr("nodesep") {
    Some(value) =>
      validate_nonnegative_attr(
        "graph",
        "nodesep",
        value,
        parse_first_double(value, 0.0),
      )
    None => ()
  }
  match graph.get_attr("ranksep") {
    Some(value) =>
      validate_nonnegative_attr(
        "graph",
        "ranksep",
        value,
        parse_first_double(value, 0.0),
      )
    None => ()
  }
}

///|
fn validate_node_dimensions(graph : @cgraph.Graph) -> Unit raise DotLayoutError {
  for node in graph.nodes() {
    match node.get_attr("width") {
      Some(value) =>
        validate_nonnegative_attr(
          "node \{node.name()}",
          "width",
          value,
          parse_first_double(value, 0.0),
        )
      None => ()
    }
    match node.get_attr("height") {
      Some(value) =>
        validate_nonnegative_attr(
          "node \{node.name()}",
          "height",
          value,
          parse_first_double(value, 0.0),
        )
      None => ()
    }
  }
}

///|
fn validate_edge_attributes(graph : @cgraph.Graph) -> Unit raise DotLayoutError {
  for edge in graph.edges() {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let owner = "edge \{tail} -> \{head}"
    match edge.get_attr("minlen") {
      Some(value) =>
        validate_nonnegative_attr(
          owner,
          "minlen",
          value,
          parse_first_double(value, 0.0),
        )
      None => ()
    }
    match edge.get_attr("weight") {
      Some(value) =>
        validate_nonnegative_attr(
          owner,
          "weight",
          value,
          parse_first_double(value, 0.0),
        )
      None => ()
    }
  }
}

///|
fn validate_layout_graph(graph : @cgraph.Graph) -> Unit raise DotLayoutError {
  validate_graph_spacing(graph)
  validate_node_dimensions(graph)
  validate_edge_attributes(graph)
}

///|
fn parse_rankdir(value : String) -> RankDir? {
  match value.to_lower() {
    "tb" => Some(RankDir::TB)
    "bt" => Some(RankDir::BT)
    "lr" => Some(RankDir::LR)
    "rl" => Some(RankDir::RL)
    _ => None
  }
}

///|
fn graph_rankdir(graph : @cgraph.Graph) -> RankDir {
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
fn parse_splines(value : String) -> SplinesMode? {
  match value.to_lower() {
    "true" | "spline" | "splines" => Some(SplinesMode::Spline)
    "false" | "no" | "line" => Some(SplinesMode::Polyline)
    "none" | "" => Some(SplinesMode::None)
    "polyline" => Some(SplinesMode::Polyline)
    "ortho" => Some(SplinesMode::Ortho)
    "curved" => Some(SplinesMode::Curved)
    _ => None
  }
}

///|
priv enum OrderingMode {
  Out
  In
}

///|
fn parse_ordering_mode(value : String) -> OrderingMode? {
  match value.to_lower() {
    "out" => Some(OrderingMode::Out)
    "in" => Some(OrderingMode::In)
    _ => None
  }
}

///|
priv enum EdgeDir {
  Forward
  Back
  Both
  None
}

///|
fn parse_edge_dir(value : String) -> EdgeDir? {
  match value.to_lower() {
    "forward" | "f" => Some(EdgeDir::Forward)
    "back" | "b" => Some(EdgeDir::Back)
    "both" => Some(EdgeDir::Both)
    "none" => Some(EdgeDir::None)
    _ => None
  }
}

///|
fn edge_dir_for(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> EdgeDir {
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
const LINE_SPACING : Double = 1.2

///|
const TEXT_SCALE : Double = 0.9706

///|
const RECORD_TEXT_SCALE : Double = 0.97036

///|
const PAD_X_PT : Double = 16.0

///|
const PAD_Y_PT : Double = 8.0

const PERIPHERY_GAP_PT : Double = 4.0

///|
// Graphviz keeps edge-label ranks tight; use a fraction of nodesep on label ranks.
const EDGE_LABEL_NODESEP_PT : Double = 5.0

///|
const EDGE_LABEL_PAD_WIDTH_PT : Double = 100.0

///|
const ELLIPSE_LABEL_SCALE : Double = 1.0


///|
const EDGE_VNODE_PREFIX : String = "_mbt_edge_vn_"

///|
const MAX_XPOS_VNODES : Int = 100000

///|
const MAX_XPOS_REORDER_VNODES : Int = 5000

///|
const LARGE_SORT_THRESHOLD : Int = 128

///|
fn font_width_scale(font_name : String) -> Double {
  let lower = font_name.to_lower()
  if lower.contains("palatino") {
    1.02
  } else {
    1.0
  }
}

///|
fn is_monospace_font(font_name : String) -> Bool {
  let lower = font_name.to_lower()
  lower.contains("mono") || lower.contains("courier") || lower.contains("fixed")
}

///|
fn line_height_scale(font_name : String, font_size_pt : Double) -> Double {
  let lower = font_name.to_lower()
  if lower.contains("palatino") {
    1.125
  } else if lower.contains("times") {
    let min_size = 10.0
    let max_size = 14.0
    if font_size_pt <= min_size {
      1.125
    } else if font_size_pt >= max_size {
      1.1786
    } else {
      let t = (font_size_pt - min_size) / (max_size - min_size)
      1.125 + t * (1.1786 - 1.125)
    }
  } else {
    LINE_SPACING
  }
}

///|
fn text_line_height(font_name : String, font_size_pt : Double) -> Double {
  font_size_pt * line_height_scale(font_name, font_size_pt)
}

///|
fn char_width_units_base(ch : Char) -> Double {
  if @font_metrics.HAS_FONT_METRICS {
    let code = ch.to_int()
    if code >= 0 && code < @font_metrics.font_metrics.length() {
      let width = @font_metrics.font_metrics[code]
      if width > 0.0 {
        return width
      }
    }
  }
  match ch {
    ' ' => 250
    '\t' => 250
    '!' => 333
    '"' => 408
    '#' => 500
    '$' => 500
    '%' => 833
    '&' => 778
    '\'' => 180
    '(' | ')' | '[' | ']' => 333
    '*' => 500
    '+' | '<' | '=' | '>' => 564
    ',' | '.' => 250
    '-' => 333
    '/' | '\\' => 278
    '0'..='9' => 500
    ':' | ';' => 278
    '?' => 444
    '@' => 921
    'A' => 722
    'B' => 667
    'C' => 667
    'D' => 722
    'E' => 611
    'F' => 556
    'G' => 722
    'H' => 722
    'I' => 333
    'J' => 389
    'K' => 722
    'L' => 611
    'M' => 889
    'N' => 722
    'O' => 722
    'P' => 556
    'Q' => 722
    'R' => 667
    'S' => 556
    'T' => 611
    'U' => 722
    'V' => 722
    'W' => 944
    'X' => 722
    'Y' => 722
    'Z' => 611
    '^' => 469
    '_' => 500
    '`' => 333
    'a' => 444
    'b' => 500
    'c' => 444
    'd' => 500
    'e' => 444
    'f' => 333
    'g' => 500
    'h' => 500
    'i' => 278
    'j' => 278
    'k' => 500
    'l' => 278
    'm' => 778
    'n' => 500
    'o' => 500
    'p' => 500
    'q' => 500
    'r' => 333
    's' => 389
    't' => 278
    'u' => 500
    'v' => 500
    'w' => 722
    'x' => 500
    'y' => 500
    'z' => 444
    '{' => 480
    '|' => 200
    '}' => 480
    '~' => 541
    _ => 500
  }
}

///|
fn char_width_units(ch : Char, uppercase_boost : Bool) -> Double {
  let base = char_width_units_base(ch)
  if @font_metrics.HAS_FONT_METRICS {
    base
  } else if uppercase_boost && ch.is_ascii_uppercase() {
    base + 22.0
  } else if ch.is_ascii_lowercase() {
    base - 2.0
  } else {
    base
  }
}

///|
fn record_char_width_units(ch : Char) -> Double {
  if @font_metrics.HAS_FONT_METRICS {
    return char_width_units_base(ch)
  }
  let base =
    if ch == ' ' {
      276.0
    } else if ch.is_ascii_digit() {
      char_width_units_base(ch) - 4.0
    } else {
      char_width_units_base(ch)
    }
  if ch.is_ascii_lowercase() {
    base - 2.0
  } else {
    base
  }
}

///|
fn char_kerning_units(prev : Char, curr : Char) -> Double {
  if !@font_metrics.HAS_FONT_KERNING {
    return 0.0
  }
  if prev == ' ' && @font_metrics.HAS_SPACE_KERNING {
    let right = curr.to_int()
    if right >= 0 && right < @font_metrics.font_space_kerning.length() {
      return @font_metrics.font_space_kerning[right]
    }
  }
  let left = prev.to_int()
  let right = curr.to_int()
  if left >= 0 && left < 128 && right >= 0 && right < 128 {
    let idx = left * 128 + right
    if idx >= 0 && idx < @font_metrics.font_kerning.length() {
      return @font_metrics.font_kerning[idx]
    }
  }
  0.0
}

///|
fn split_label_lines(
  label : String,
  trim_trailing_break~ : Bool,
) -> Array[String] {
  let lines : Array[String] = []
  let mut sb = StringBuilder::new()
  let mut escaping = false
  let mut ended_with_break = false
  for ch in label {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        lines.push(sb.to_string())
        sb = StringBuilder::new()
        ended_with_break = true
      } else {
        sb.write_char(ch)
        ended_with_break = false
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      lines.push(sb.to_string())
      sb = StringBuilder::new()
      ended_with_break = true
    } else {
      sb.write_char(ch)
      ended_with_break = false
    }
  }
  if escaping {
    sb.write_char('\\')
    ended_with_break = false
  }
  lines.push(sb.to_string())
  if trim_trailing_break && ended_with_break && lines.length() > 1 {
    ignore(lines.pop())
  }
  lines
}

///|
fn try_multiline_textspan_override(
  label : String,
  font_name : String,
  font_size_pt : Double,
  trim_trailing_break~ : Bool,
) -> (Double, Double)? {
  let lines = split_label_lines(label, trim_trailing_break~)
  if lines.length() <= 1 {
    return None
  }
  let mut max_width = 0.0
  for line in lines {
    match @font_metrics.lookup_textspan_override(line, font_name, font_size_pt) {
      Some((width, _height)) => if width > max_width { max_width = width }
      None => return None
    }
  }
  let line_height = text_line_height(font_name, font_size_pt)
  Some((max_width, line_height * lines.length().to_double()))
}

///|
fn label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  if label == "" {
    return (0.0, 0.0)
  }
  match @font_metrics.lookup_textspan_override(
    label,
    font_name,
    font_size_pt,
  ) {
    Some((width, height)) => return (width, height)
    None => ()
  }
  match try_multiline_textspan_override(
    label,
    font_name,
    font_size_pt,
    trim_trailing_break=false,
  ) {
    Some((width, height)) => return (width, height)
    None => ()
  }
  let line_height = text_line_height(font_name, font_size_pt)
  if is_monospace_font(font_name) {
    let mut max_cols = 0
    let mut cols = 0
    let mut lines = 1
    let mut escaping = false
    for ch in label {
      if escaping {
        escaping = false
        if ch == 'n' || ch == 'l' || ch == 'r' {
          if cols > max_cols {
            max_cols = cols
          }
          cols = 0
          lines = lines + 1
        } else {
          cols = cols + 1
        }
        continue
      }
      if ch == '\\' {
        escaping = true
        continue
      }
      if ch == '\n' || ch == '\r' {
        if cols > max_cols {
          max_cols = cols
        }
        cols = 0
        lines = lines + 1
      } else {
        cols = cols + 1
      }
    }
    if escaping {
      cols = cols + 1
    }
    if cols > max_cols {
      max_cols = cols
    }
    let width_units = char_width_units_base('0')
    let width_scale = font_width_scale(font_name)
    let text_scale =
      if @font_metrics.HAS_FONT_METRICS { 1.0 } else { TEXT_SCALE }
    let width_pt = max_cols.to_double() *
      width_units *
      font_size_pt *
      text_scale *
      width_scale /
      1000.0
    let height_pt = lines.to_double() * line_height
    return (width_pt, height_pt)
  }
  let mut has_lowercase = false
  let mut scan_escape = false
  for ch in label {
    if scan_escape {
      scan_escape = false
      if ch != 'n' && ch != 'l' && ch != 'r' && ch.is_ascii_lowercase() {
        has_lowercase = true
        break
      }
      continue
    }
    if ch == '\\' {
      scan_escape = true
      continue
    }
    if ch.is_ascii_lowercase() {
      has_lowercase = true
      break
    }
  }
  let uppercase_boost = !has_lowercase
  let mut max_units = 0.0
  let mut current_units = 0.0
  let mut lines = 1
  let mut escaping = false
  let mut prev_char : Char? = None
  for ch in label {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        if current_units > max_units {
          max_units = current_units
        }
        current_units = 0
        lines = lines + 1
        prev_char = None
      } else {
        match prev_char {
          Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
          None => ()
        }
        current_units = current_units + char_width_units(ch, uppercase_boost)
        prev_char = Some(ch)
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      if current_units > max_units {
        max_units = current_units
      }
      current_units = 0
      lines = lines + 1
      prev_char = None
    } else {
      match prev_char {
        Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
        None => ()
      }
      current_units = current_units + char_width_units(ch, uppercase_boost)
      prev_char = Some(ch)
    }
  }
  if escaping {
    let ch = '\\'
    match prev_char {
      Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
      None => ()
    }
    current_units = current_units + char_width_units('\\', uppercase_boost)
    prev_char = Some('\\')
  }
  if current_units > max_units {
    max_units = current_units
  }
  let width_scale = font_width_scale(font_name)
  let text_scale = if @font_metrics.HAS_FONT_METRICS { 1.0 } else { TEXT_SCALE }
  let width_pt = max_units *
    font_size_pt *
    text_scale *
    width_scale /
    1000.0
  let height_pt = lines.to_double() * line_height
  (width_pt, height_pt)
}

///|
fn record_label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  if label == "" {
    return (0.0, 0.0)
  }
  match @font_metrics.lookup_textspan_override(
    label,
    font_name,
    font_size_pt,
  ) {
    Some((width, height)) => return (width, height)
    None => ()
  }
  match try_multiline_textspan_override(
    label,
    font_name,
    font_size_pt,
    trim_trailing_break=true,
  ) {
    Some((width, height)) => return (width, height)
    None => ()
  }
  let line_height = text_line_height(font_name, font_size_pt)
  if is_monospace_font(font_name) {
    let mut max_cols = 0
    let mut cols = 0
    let mut lines = 1
    let mut escaping = false
    let mut ended_with_break = false
    for ch in label {
      if escaping {
        escaping = false
        if ch == 'n' || ch == 'l' || ch == 'r' {
          if cols > max_cols {
            max_cols = cols
          }
          cols = 0
          lines = lines + 1
          ended_with_break = true
        } else {
          cols = cols + 1
          ended_with_break = false
        }
        continue
      }
      if ch == '\\' {
        escaping = true
        continue
      }
      if ch == '\n' || ch == '\r' {
        if cols > max_cols {
          max_cols = cols
        }
        cols = 0
        lines = lines + 1
        ended_with_break = true
      } else {
        cols = cols + 1
        ended_with_break = false
      }
    }
    if escaping {
      cols = cols + 1
      ended_with_break = false
    }
    if cols > max_cols {
      max_cols = cols
    }
    if ended_with_break && lines > 1 {
      lines = lines - 1
    }
    let width_units = record_char_width_units('0')
    let width_scale = font_width_scale(font_name)
    let text_scale =
      if @font_metrics.HAS_FONT_METRICS { 1.0 } else { RECORD_TEXT_SCALE }
    let width_pt = max_cols.to_double() *
      width_units *
      font_size_pt *
      text_scale *
      width_scale /
      1000.0
    let height_pt = lines.to_double() * line_height
    return (width_pt, height_pt)
  }
  let mut max_units = 0.0
  let mut current_units = 0.0
  let mut lines = 1
  let mut escaping = false
  let mut ended_with_break = false
  let mut prev_char : Char? = None
  for ch in label {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        if current_units > max_units {
          max_units = current_units
        }
        current_units = 0
        lines = lines + 1
        ended_with_break = true
        prev_char = None
      } else {
        match prev_char {
          Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
          None => ()
        }
        current_units = current_units + record_char_width_units(ch)
        ended_with_break = false
        prev_char = Some(ch)
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      if current_units > max_units {
        max_units = current_units
      }
      current_units = 0
      lines = lines + 1
      ended_with_break = true
      prev_char = None
    } else {
      match prev_char {
        Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
        None => ()
      }
      current_units = current_units + record_char_width_units(ch)
      ended_with_break = false
      prev_char = Some(ch)
    }
  }
  if escaping {
    let ch = '\\'
    match prev_char {
      Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
      None => ()
    }
    current_units = current_units + record_char_width_units(ch)
    ended_with_break = false
    prev_char = Some('\\')
  }
  if current_units > max_units {
    max_units = current_units
  }
  if ended_with_break && lines > 1 {
    lines = lines - 1
  }
  let width_scale = font_width_scale(font_name)
  let text_scale =
    if @font_metrics.HAS_FONT_METRICS { 1.0 } else { RECORD_TEXT_SCALE }
  let width_pt = max_units *
    font_size_pt *
    text_scale *
    width_scale /
    1000.0
  let height_pt = lines.to_double() * line_height
  (width_pt, height_pt)
}

///|
fn extract_numbers(value : String) -> Array[Double] {
  let sb = StringBuilder::new()
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
    } else {
      sb.write_char(' ')
    }
  }
  let normalized = sb.to_string()
  let numbers : Array[Double] = []
  for token in normalized.split(" ") {
    if token.length() == 0 {
      continue
    }
    numbers.push(parse_double(token.to_string(), 0.0))
  }
  numbers
}

///|
fn parse_margin(value : String) -> (Double, Double)? {
  let numbers = extract_numbers(value)
  if numbers.length() == 0 {
    return None
  }
  if numbers.length() == 1 {
    let val = if numbers[0] < 0.0 { 0.0 } else { numbers[0] }
    return Some((val, val))
  }
  let x = if numbers[0] < 0.0 { 0.0 } else { numbers[0] }
  let y = if numbers[1] < 0.0 { 0.0 } else { numbers[1] }
  Some((x, y))
}

///|
fn graph_margin_x_pt(graph : @cgraph.Graph) -> Double {
  match graph.get_attr("margin") {
    Some(value) =>
      match parse_margin(value) {
        Some((margin_x, _margin_y)) => margin_x * 72.0
        None => CLUSTER_MARGIN_PT
      }
    None => CLUSTER_MARGIN_PT
  }
}

///|
fn label_text(node : @cgraph.Node) -> String {
  match node.get_attr("label") {
    Some(value) => if value == "\\N" { node.name() } else { value }
    None => node.name()
  }
}

///|
fn is_record_shape(node : @cgraph.Node) -> Bool {
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
fn node_padding(node : @cgraph.Node) -> (Double, Double) {
  let mut pad_x_pt = PAD_X_PT
  let mut pad_y_pt = PAD_Y_PT
  match node.get_attr("margin") {
    Some(value) =>
      match parse_margin(value) {
        Some((margin_x, margin_y)) => {
          pad_x_pt = margin_x * 72.0 * 2.0
          pad_y_pt = margin_y * 72.0 * 2.0
        }
        None => ()
      }
    None => ()
  }
  (pad_x_pt, pad_y_pt)
}

///|
priv struct RecordField {
  name : String?
  text : String
}

///|
priv struct RecordPort {
  center : @geom.Point
  size : NodeSize
}

///|
priv enum RecordOrientation {
  Horizontal
  Vertical
}

///|
fn record_layout_orientation(_rankdir : RankDir) -> RecordOrientation {
  match _rankdir {
    RankDir::LR | RankDir::RL => RecordOrientation::Vertical
    _ => RecordOrientation::Horizontal
  }
}

///|
priv enum RecordNode {
  Field(RecordField)
  Group(Array[RecordNode])
}

///|
let record_nodes_cache : Ref[Map[String, Array[RecordNode]]] =
  @ref.new(Map::new())

///|
let html_label_cache : Ref[Map[String, @html_label.HtmlLabel]] =
  @ref.new(Map::new())

///|
let record_ports_cache : Ref[Map[String, Map[String, RecordPort]]] =
  @ref.new(Map::new())

///|
let html_ports_cache : Ref[Map[String, Map[String, RecordPort]]] =
  @ref.new(Map::new())

///|
fn reset_label_caches() -> Unit {
  record_nodes_cache.val = Map::new()
  html_label_cache.val = Map::new()
  record_ports_cache.val = Map::new()
  html_ports_cache.val = Map::new()
}

///|
fn toggle_record_orientation(
  orientation : RecordOrientation,
) -> RecordOrientation {
  match orientation {
    RecordOrientation::Horizontal => RecordOrientation::Vertical
    RecordOrientation::Vertical => RecordOrientation::Horizontal
  }
}

///|
priv struct RecordParser {
  chars : Array[Char]
  mut index : Int
}

///|
fn parse_record_nodes(parser : RecordParser) -> Array[RecordNode] {
  let nodes : Array[RecordNode] = []
  let mut sb = StringBuilder::new()
  let mut escaping = false
  let mut in_port = false
  let mut segment_has_node = false
  while parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    if escaping {
      escaping = false
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '\\' {
      escaping = true
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '<' {
      in_port = true
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '>' {
      in_port = false
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if !in_port && ch == '{' {
      let text = sb.to_string()
      if text.trim(chars=" \n\r\t") != "" {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
        segment_has_node = true
      }
      sb = StringBuilder::new()
      parser.index = parser.index + 1
      let children = parse_record_nodes(parser)
      nodes.push(RecordNode::Group(children))
      segment_has_node = true
      continue
    }
    if !in_port && ch == '|' {
      let text = sb.to_string()
      if !segment_has_node {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
      }
      sb = StringBuilder::new()
      segment_has_node = false
      parser.index = parser.index + 1
      continue
    }
    if !in_port && ch == '}' {
      let text = sb.to_string()
      if !segment_has_node {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
      }
      sb = StringBuilder::new()
      parser.index = parser.index + 1
      return nodes
    }
    sb.write_char(ch)
    parser.index = parser.index + 1
  }
  let text = sb.to_string()
  if !segment_has_node {
    nodes.push(RecordNode::Field(record_field_from_text(text)))
  }
  nodes
}

///|
fn record_field_from_text(field : String) -> RecordField {
  let trimmed = field.trim(chars=" \n\r\t").to_string()
  let (port_name, raw_text) : (String?, String) = if trimmed.has_prefix("<") {
    match trimmed.find(">") {
      Some(pos) => {
        let name = if pos > 1 {
          trimmed.unsafe_substring(start=1, end=pos)
        } else {
          ""
        }
        let len = trimmed.length()
        let text = if pos + 1 < len {
          trimmed.unsafe_substring(start=pos + 1, end=len)
        } else {
          ""
        }
        let port_name : String? = if name == "" { None } else { Some(name) }
        (port_name, text)
      }
      None => (None, trimmed)
    }
  } else {
    (None, trimmed)
  }
  let normalized = normalize_record_text(raw_text).trim(chars=" \n\r\t").to_string()
  let text = if normalized == "" { " " } else { normalized }
  { name: port_name, text }
}

///|
fn normalize_record_text(text : String) -> String {
  let sb = StringBuilder::new()
  let mut escaping = false
  for ch in text {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        sb.write_char('\\')
        sb.write_char(ch)
      } else {
        sb.write_char(ch)
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    sb.write_char(ch)
  }
  if escaping {
    sb.write_char('\\')
  }
  sb.to_string()
}

///|
fn record_nodes(label : String) -> Array[RecordNode] {
  match record_nodes_cache.val.get(label) {
    Some(cached) => cached
    None => {
      let chars : Array[Char] = []
      for ch in label {
        chars.push(ch)
      }
      let parser = RecordParser::{ chars, index: 0 }
      let nodes = parse_record_nodes(parser)
      let flattened =
        if nodes.length() == 1 {
          match nodes[0] {
            RecordNode::Group(children) => children
            _ => nodes
          }
        } else {
          nodes
        }
      record_nodes_cache.val[label] = flattened
      flattened
    }
  }
}

///|
priv struct RecordNodeSize {
  width_pt : Double
  height_pt : Double
}

///|
fn record_nodes_sizes(
  nodes : Array[RecordNode],
  orientation : RecordOrientation,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> Array[RecordNodeSize] {
  let sizes : Array[RecordNodeSize] = []
  for node in nodes {
    match node {
      RecordNode::Field(field) => {
        let (text_width_pt, text_height_pt) = record_label_text_dimensions(
          field.text,
          font_name,
          font_size_pt,
        )
        let width_pt = text_width_pt + pad_x_pt
        let height_pt = text_height_pt + pad_y_pt
        sizes.push({ width_pt, height_pt })
      }
      RecordNode::Group(children) => {
        let size = record_group_size(
          children,
          toggle_record_orientation(orientation),
          font_name,
          font_size_pt,
          pad_x_pt,
          pad_y_pt,
        )
        sizes.push(size)
      }
    }
  }
  sizes
}

///|
fn record_group_size(
  nodes : Array[RecordNode],
  orientation : RecordOrientation,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> RecordNodeSize {
  let sizes = record_nodes_sizes(
    nodes, orientation, font_name, font_size_pt, pad_x_pt, pad_y_pt,
  )
  if sizes.length() == 0 {
    return { width_pt: 0.0, height_pt: 0.0 }
  }
  let mut width = 0.0
  let mut height = 0.0
  match orientation {
    RecordOrientation::Vertical =>
      for size in sizes {
        if size.width_pt > width {
          width = size.width_pt
        }
        height = height + size.height_pt
      }
    RecordOrientation::Horizontal =>
      for size in sizes {
        if size.height_pt > height {
          height = size.height_pt
        }
        width = width + size.width_pt
      }
  }
  { width_pt: width, height_pt: height }
}

///|
fn swap_node_size(size : NodeSize) -> NodeSize {
  let width_in = size.height_in
  let height_in = size.width_in
  let width_pt = size.height_pt
  let height_pt = size.width_pt
  let half = width_pt / 2.0
  { width_in, height_in, width_pt, height_pt, left_pt: half, right_pt: half }
}

///|
fn vnode_size_from_widths(left_pt : Double, right_pt : Double) -> NodeSize {
  let width_pt = left_pt + right_pt
  let width_in = width_pt / 72.0
  {
    width_in,
    height_in: 0.0,
    width_pt,
    height_pt: 0.0,
    left_pt,
    right_pt,
  }
}

///|
fn record_layout_nodes(
  nodes : Array[RecordNode],
  rect : @geom.Rect,
  orientation : RecordOrientation,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
  rects : Array[@geom.Rect],
  ports : Map[String, RecordPort],
) -> Unit {
  if nodes.length() == 0 {
    return ()
  }
  let sizes = record_nodes_sizes(
    nodes, orientation, font_name, font_size_pt, pad_x_pt, pad_y_pt,
  )
  let axis_sizes : Array[Double] = []
  let mut axis_sum = 0.0
  for size in sizes {
    let axis = match orientation {
      RecordOrientation::Vertical => size.height_pt
      RecordOrientation::Horizontal => size.width_pt
    }
    axis_sizes.push(axis)
    axis_sum = axis_sum + axis
  }
  let axis_total = match orientation {
    RecordOrientation::Vertical => rect.ury - rect.lly
    RecordOrientation::Horizontal => rect.urx - rect.llx
  }
  if axis_sizes.length() > 0 {
    // Match Graphviz resize_reclbl: distribute extra size evenly with int rounding.
    let delta = axis_total - axis_sum
    if delta != 0.0 {
      let inc = delta / axis_sizes.length().to_double()
      for i in 0..<axis_sizes.length() {
        let before = (i.to_double() * inc).trunc().to_int()
        let after = ((i + 1).to_double() * inc).trunc().to_int()
        let amt = after - before
        axis_sizes[i] = axis_sizes[i] + Double::from_int(amt)
      }
    }
  }
  let mut cursor = match orientation {
    RecordOrientation::Vertical => rect.ury
    RecordOrientation::Horizontal => rect.llx
  }
  for i in 0..<nodes.length() {
    let axis = axis_sizes[i]
    let child_rect = match orientation {
      RecordOrientation::Vertical => {
        let bottom = cursor - axis
        let child : @geom.Rect = {
          llx: rect.llx,
          lly: bottom,
          urx: rect.urx,
          ury: cursor,
        }
        cursor = bottom
        child
      }
      RecordOrientation::Horizontal => {
        let right = cursor + axis
        let child : @geom.Rect = {
          llx: cursor,
          lly: rect.lly,
          urx: right,
          ury: rect.ury,
        }
        cursor = right
        child
      }
    }
    match nodes[i] {
      RecordNode::Field(field) => {
        rects.push(child_rect)
        match field.name {
          Some(name) => {
            let center = @geom.Point::{
              x: (child_rect.llx + child_rect.urx) / 2.0,
              y: (child_rect.lly + child_rect.ury) / 2.0,
            }
            let field_size = node_size_from_points(
              child_rect.urx - child_rect.llx,
              child_rect.ury - child_rect.lly,
            )
            ports[name] = { center, size: field_size }
          }
          None => ()
        }
      }
      RecordNode::Group(children) =>
        record_layout_nodes(
          children,
          child_rect,
          toggle_record_orientation(orientation),
          font_name,
          font_size_pt,
          pad_x_pt,
          pad_y_pt,
          rects,
          ports,
        )
    }
  }
}

///|
fn record_rects(
  node : @cgraph.Node,
  pos : @geom.Point,
  size : NodeSize,
  orientation : RecordOrientation,
) -> Array[@geom.Rect] {
  let label = label_text(node)
  let nodes = record_nodes(label)
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let rects : Array[@geom.Rect] = []
  let ports : Map[String, RecordPort] = Map::new()
  let rect : @geom.Rect = {
    llx: pos.x - size.width_pt / 2.0,
    lly: pos.y - size.height_pt / 2.0,
    urx: pos.x + size.width_pt / 2.0,
    ury: pos.y + size.height_pt / 2.0,
  }
  let inner_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - RECORD_BORDER_PT,
  }
  record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    font,
    font_size_pt,
    pad_x_pt,
    pad_y_pt,
    rects,
    ports,
  )
  rects
}

///|
fn record_ports(
  node : @cgraph.Node,
  pos : @geom.Point,
  size : NodeSize,
  orientation : RecordOrientation,
) -> Map[String, RecordPort] {
  let is_origin = pos.x == 0.0 && pos.y == 0.0
  if is_origin {
    let name = node.name()
    match record_ports_cache.val.get(name) {
      Some(cached) => return cached
      None => ()
    }
  }
  let label = label_text(node)
  let nodes = record_nodes(label)
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let ports : Map[String, RecordPort] = Map::new()
  let rects : Array[@geom.Rect] = []
  let rect : @geom.Rect = {
    llx: pos.x - size.width_pt / 2.0,
    lly: pos.y - size.height_pt / 2.0,
    urx: pos.x + size.width_pt / 2.0,
    ury: pos.y + size.height_pt / 2.0,
  }
  let inner_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - RECORD_BORDER_PT,
  }
  record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    font,
    font_size_pt,
    pad_x_pt,
    pad_y_pt,
    rects,
    ports,
  )
  if is_origin {
    record_ports_cache.val[node.name()] = ports
  }
  ports
}

///|
fn record_port_padding_y(
  edges : Array[@cgraph.Edge],
  positions : Map[String, @geom.Point],
  label_ports_map : Map[String, Map[String, RecordPort]],
) -> (Double, Double) {
  let mut extra_below = 0.0
  let mut extra_above = 0.0
  let update_padding = (node_name : String, port : @cgraph.Port?) => {
    match port {
      Some(value) =>
        match value.name {
          Some(port_name) =>
            match label_ports_map.get(node_name) {
              Some(ports) =>
                match ports.get(port_name) {
                  Some(port_info) =>
                    match positions.get(node_name) {
                      Some(node_pos) => {
                        let dy = port_info.center.y - node_pos.y
                        let half_height =
                          port_info.size.height_pt / 2.0 -
                          RECORD_BORDER_PT / 2.0 -
                          0.01
                        let adjusted =
                          if half_height < 0.0 {
                          0.0
                        } else {
                          half_height * 0.5
                        }
                        if dy < 0.0 && adjusted > extra_below {
                          extra_below = adjusted
                        } else if dy > 0.0 && adjusted > extra_above {
                          extra_above = adjusted
                        }
                      }
                      None => ()
                    }
                  None => ()
                }
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  for edge in edges {
    if port_is_explicit(edge.tail_port()) && is_record_shape(edge.tail()) {
      update_padding(edge.tail().name(), edge.tail_port())
    }
    if port_is_explicit(edge.head_port()) && is_record_shape(edge.head()) {
      update_padding(edge.head().name(), edge.head_port())
    }
  }
  (extra_below, extra_above)
}

///|
///|
fn html_cell_content_size(
  content : @html_label.HtmlCellContent,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  match content {
    @html_label.HtmlCellContent::Text(text) =>
      label_text_dimensions(text, font_name, font_size_pt)
    @html_label.HtmlCellContent::Table(table) =>
      html_table_size(table, font_name, font_size_pt)
  }
}

///|
fn html_cell_size(
  table : @html_label.HtmlTable,
  cell : @html_label.HtmlCell,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  let (content_width, content_height) = html_cell_content_size(
    cell.content,
    font_name,
    font_size_pt,
  )
  let mut width = content_width
  let mut height = content_height
  match cell.min_width_pt {
    Some(value) => if value > width { width = value }
    None => ()
  }
  match cell.min_height_pt {
    Some(value) => if value > height { height = value }
    None => ()
  }
  width = width + table.cell_padding_pt * 2.0 + table.cell_border_pt * 2.0
  height = height + table.cell_padding_pt * 2.0 + table.cell_border_pt * 2.0
  (width, height)
}

///|
fn html_table_size(
  table : @html_label.HtmlTable,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  @html_label.html_table_size(table, cell => html_cell_size(
    table, cell, font_name, font_size_pt,
  ))
}

///|
fn html_table_layout(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  font_name : String,
  font_size_pt : Double,
) -> @html_label.HtmlTableLayout {
  @html_label.html_table_layout(table, rect, cell => html_cell_size(
    table, cell, font_name, font_size_pt,
  ))
}

///|
fn parse_html_label_cached(label : String) -> @html_label.HtmlLabel? {
  match html_label_cache.val.get(label) {
    Some(cached) => Some(cached)
    None =>
      match @html_label.parse_html_label(label) {
        Some(parsed) => {
          html_label_cache.val[label] = parsed
          Some(parsed)
        }
        None => None
      }
  }
}

///|
fn html_label_size(
  label : @html_label.HtmlLabel,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  match label {
    @html_label.HtmlLabel::Text(text) =>
      label_text_dimensions(text, font_name, font_size_pt)
    @html_label.HtmlLabel::Table(table) =>
      html_table_size(table, font_name, font_size_pt)
  }
}

///|
fn collect_html_ports(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  font_name : String,
  font_size_pt : Double,
  ports : Map[String, RecordPort],
) -> Unit {
  let layout = html_table_layout(table, rect, font_name, font_size_pt)
  for cell_layout in layout.cells {
    match cell_layout.cell.port {
      Some(name) => {
        let center = @geom.Point::{
          x: (cell_layout.rect.llx + cell_layout.rect.urx) / 2.0,
          y: (cell_layout.rect.lly + cell_layout.rect.ury) / 2.0,
        }
        let size = node_size_from_points(
          cell_layout.rect.urx - cell_layout.rect.llx,
          cell_layout.rect.ury - cell_layout.rect.lly,
        )
        ports[name] = { center, size }
      }
      None => ()
    }
    match cell_layout.cell.content {
      @html_label.HtmlCellContent::Table(nested) =>
        collect_html_ports(
          nested,
          cell_layout.rect,
          font_name,
          font_size_pt,
          ports,
        )
      _ => ()
    }
  }
}

///|
fn html_ports(
  node : @cgraph.Node,
  pos : @geom.Point,
  size : NodeSize,
) -> Map[String, RecordPort] {
  let label = label_text(node)
  let is_origin = pos.x == 0.0 && pos.y == 0.0
  if is_origin {
    let name = node.name()
    match html_ports_cache.val.get(name) {
      Some(cached) => return cached
      None => ()
    }
  }
  let ports : Map[String, RecordPort] = Map::new()
  match parse_html_label_cached(label) {
    Some(@html_label.HtmlLabel::Table(table)) => {
      let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
      let font = @attrs.font_name(node.get_attr("fontname"))
      let rect : @geom.Rect = {
        llx: pos.x - size.width_pt / 2.0,
        lly: pos.y - size.height_pt / 2.0,
        urx: pos.x + size.width_pt / 2.0,
        ury: pos.y + size.height_pt / 2.0,
      }
      collect_html_ports(table, rect, font, font_size_pt, ports)
    }
    _ => ()
  }
  if is_origin {
    html_ports_cache.val[node.name()] = ports
  }
  ports
}

///|
fn layout_port_offset(offset : @geom.Point, rankdir : RankDir) -> @geom.Point {
  match rankdir {
    RankDir::TB => offset
    RankDir::BT => { x: offset.x, y: -offset.y }
    RankDir::LR => { x: offset.y, y: -offset.x }
    RankDir::RL => { x: -offset.y, y: offset.x }
  }
}

///|
fn layout_ports_from_final(
  ports : Map[String, RecordPort],
  layout_pos : @geom.Point,
  rankdir : RankDir,
) -> Map[String, RecordPort] {
  let rotated : Map[String, RecordPort] = Map::new()
  for name, port in ports {
    let offset = layout_port_offset(port.center, rankdir)
    let center = @geom.Point::{
      x: layout_pos.x + offset.x,
      y: layout_pos.y + offset.y,
    }
    let size = match rankdir {
      RankDir::LR | RankDir::RL => swap_node_size(port.size)
      _ => port.size
    }
    rotated[name] = { center, size }
  }
  rotated
}

///|
fn port_side_anchor_from_raw(
  raw_port : RecordPort,
  node_size : NodeSize,
  node_pos : @geom.Point,
  target_pos : @geom.Point,
  rankdir : RankDir,
) -> @geom.Point? {
  let half_w = raw_port.size.width_pt / 2.0
  let half_h = raw_port.size.height_pt / 2.0
  let port_rect : @geom.Rect = {
    llx: raw_port.center.x - half_w,
    lly: raw_port.center.y - half_h,
    urx: raw_port.center.x + half_w,
    ury: raw_port.center.y + half_h,
  }
  let node_rect : @geom.Rect = {
    llx: -node_size.width_pt / 2.0,
    lly: -node_size.height_pt / 2.0,
    urx: node_size.width_pt / 2.0,
    ury: node_size.height_pt / 2.0,
  }
  let eps = if RECORD_BORDER_PT > 0.01 {
    RECORD_BORDER_PT + 0.01
  } else {
    0.01
  }
  let candidates : Array[(@geom.Point, @geom.Point)] = []
  let mid_x = (port_rect.llx + port_rect.urx) / 2.0
  let mid_y = (port_rect.lly + port_rect.ury) / 2.0
  if Double::abs(port_rect.llx - node_rect.llx) <= eps {
    candidates.push((point(port_rect.llx, mid_y), point(-1.0, 0.0)))
  }
  if Double::abs(port_rect.urx - node_rect.urx) <= eps {
    candidates.push((point(port_rect.urx, mid_y), point(1.0, 0.0)))
  }
  if Double::abs(port_rect.lly - node_rect.lly) <= eps {
    candidates.push((point(mid_x, port_rect.lly), point(0.0, -1.0)))
  }
  if Double::abs(port_rect.ury - node_rect.ury) <= eps {
    candidates.push((point(mid_x, port_rect.ury), point(0.0, 1.0)))
  }
  if candidates.length() == 0 || candidates.length() == 4 {
    return None
  }
  let convert = (p : @geom.Point) =>
    match rankdir {
      RankDir::TB => p
      RankDir::BT => point(p.x, -p.y)
      RankDir::LR => point(-p.y, p.x)
      RankDir::RL => point(p.y, p.x)
    }
  let target_conv = convert(target_pos)
  let mut best_pos = candidates[0].0
  let mut best_dist = 0.0
  let mut seen = false
  for pair in candidates {
    let (pos_final, _) = pair
    let pos_layout = point_add(node_pos, pos_final)
    let dist = point_dist2(convert(pos_layout), target_conv)
    if !seen || dist < best_dist {
      best_dist = dist
      best_pos = pos_final
      seen = true
    }
  }
  Some(point_add(node_pos, best_pos))
}

///|
fn port_rect_from_geometry(
  port : @cgraph.Port?,
  center : @geom.Point,
  size : NodeSize,
  node_size : NodeSize,
) -> @geom.Rect? {
  if !port_is_explicit(port) {
    return None
  }
  let eps = if RECORD_BORDER_PT > 0.01 {
    RECORD_BORDER_PT + 0.01
  } else {
    0.01
  }
  let is_port_rect =
    Double::abs(size.width_pt - node_size.width_pt) > eps ||
      Double::abs(size.height_pt - node_size.height_pt) > eps
  if !is_port_rect {
    return None
  }
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  Some({
    llx: center.x - half_w,
    lly: center.y - half_h,
    urx: center.x + half_w,
    ury: center.y + half_h,
  })
}

///|
fn port_geometry(
  node_name : String,
  port : @cgraph.Port?,
  label_ports_map : Map[String, Map[String, RecordPort]],
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> (@geom.Point, NodeSize) {
  match port {
    Some(value) =>
      match value.name {
        Some(name) =>
          match label_ports_map.get(node_name) {
            Some(ports) =>
              match ports.get(name) {
                Some(port_info) => (port_info.center, port_info.size)
                None => (node_pos, node_size)
              }
            None => (node_pos, node_size)
          }
        None => (node_pos, node_size)
      }
    None => (node_pos, node_size)
  }
}

///|
fn node_size(
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
) -> NodeSize {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  let regular_shape =
    shape == "msquare" ||
    shape == "mcircle" ||
    shape == "circle" ||
    shape == "doublecircle"
  let scale_ellipse = match shape {
    "box"
    | "rect"
    | "rectangle"
    | "record"
    | "mrecord"
    | "msquare"
    | "mdiamond"
    | "point"
    | "dot"
    | "plaintext"
    | "plain"
    | "none" => false
    _ => true
  }
  let (fallback_width, fallback_height) = if shape == "point" || shape == "dot" {
    (default_point_size_in(), default_point_size_in())
  } else if regular_shape {
    let height = default_node_height_in()
    (height, height)
  } else {
    (default_node_width_in(), default_node_height_in())
  }
  let base_width_in = match node.get_attr("width") {
    Some(value) => parse_double(value, fallback_width)
    None => fallback_width
  }
  let base_height_in = match node.get_attr("height") {
    Some(value) => parse_double(value, fallback_height)
    None => fallback_height
  }
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let base_width_pt = base_width_in * 72.0
  let base_height_pt = base_height_in * 72.0
  if shape == "point" || shape == "dot" {
    return node_size_from_points(base_width_pt, base_height_pt)
  }
  let label = label_text(node)
  if @html_label.is_html_label_text(label) {
    match parse_html_label_cached(label) {
      Some(html_label) => {
        let (html_width_pt, html_height_pt) = html_label_size(
          html_label, font, font_size_pt,
        )
        let width_pt = if html_width_pt > base_width_pt {
          html_width_pt
        } else {
          base_width_pt
        }
        let height_pt = if html_height_pt > base_height_pt {
          html_height_pt
        } else {
          base_height_pt
        }
        return node_size_from_points(width_pt, height_pt)
      }
      None => ()
    }
  }
  if is_record_shape(node) {
    let nodes = record_nodes(label)
    let record_size = record_group_size(
      nodes,
      record_orientation,
      font,
      font_size_pt,
      pad_x_pt,
      pad_y_pt,
    )
    let width_pt = if record_size.width_pt > base_width_pt {
      record_size.width_pt
    } else {
      base_width_pt
    }
    let height_pt = if record_size.height_pt > base_height_pt {
      record_size.height_pt
    } else {
      base_height_pt
    }
    let bordered_height = height_pt + RECORD_BORDER_PT * 2.0
    return node_size_from_points(width_pt, bordered_height)
  }
  let (text_width_pt, text_height_pt) = label_text_dimensions(
    label, font, font_size_pt,
  )
  let has_label = text_width_pt > 0.0 || text_height_pt > 0.0
  let label_width_pt = if has_label { text_width_pt + pad_x_pt } else { 0.0 }
  let label_height_pt = if has_label { text_height_pt + pad_y_pt } else { 0.0 }
  let mut scaled_label_width_pt = label_width_pt
  let mut scaled_label_height_pt = label_height_pt
  if shape == "mdiamond" && has_label {
    let sqrt2 = Double::sqrt(2.0)
    let temp = label_height_pt * sqrt2
    if base_height_pt > temp {
      let ratio = label_height_pt / base_height_pt
      let denom = 1.0 - ratio * ratio
      if denom > 0.0 {
        let scale = Double::sqrt(1.0 / denom)
        scaled_label_width_pt = label_width_pt * scale
      } else {
        scaled_label_width_pt = label_width_pt * sqrt2
        scaled_label_height_pt = temp
      }
    } else {
      scaled_label_width_pt = label_width_pt * sqrt2
      scaled_label_height_pt = temp
    }
    let cos_val = sqrt2 / 2.0
    scaled_label_width_pt = scaled_label_width_pt / cos_val
    scaled_label_height_pt = scaled_label_height_pt / cos_val
  } else if scale_ellipse && has_label {
    let sqrt2 = Double::sqrt(2.0)
    let temp = label_height_pt * sqrt2
    if base_height_pt > temp {
      let ratio = label_height_pt / base_height_pt
      let denom = 1.0 - ratio * ratio
      if denom > 0.0 {
        let scale = Double::sqrt(1.0 / denom)
        scaled_label_width_pt = label_width_pt * scale
      } else {
        scaled_label_width_pt = label_width_pt * sqrt2
        scaled_label_height_pt = temp
      }
    } else {
      scaled_label_width_pt = label_width_pt * sqrt2
      scaled_label_height_pt = temp
    }
    scaled_label_width_pt = scaled_label_width_pt * ELLIPSE_LABEL_SCALE
  }
  let scaled_label_width_in = scaled_label_width_pt / 72.0
  let scaled_label_height_in = scaled_label_height_pt / 72.0
  let mut width_in = if scaled_label_width_in > base_width_in {
    scaled_label_width_in
  } else {
    base_width_in
  }
  let mut height_in = if scaled_label_height_in > base_height_in {
    scaled_label_height_in
  } else {
    base_height_in
  }
  if regular_shape {
    let size_in = if width_in > height_in { width_in } else { height_in }
    width_in = size_in
    height_in = size_in
  }
  if shape == "doublecircle" {
    let gap_in = PERIPHERY_GAP_PT * 2.0 / 72.0
    width_in = width_in + gap_in
    height_in = height_in + gap_in
  }
  let width_pt = width_in * 72.0
  let half = width_pt / 2.0
  {
    width_in,
    height_in,
    width_pt,
    height_pt: height_in * 72.0,
    left_pt: half,
    right_pt: half,
  }
}

///|
fn clip_to_rect(
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
fn point_inside_bbox(point : @geom.Point, rect : @geom.Rect) -> Bool {
  point.x >= rect.llx &&
  point.x <= rect.urx &&
  point.y >= rect.lly &&
  point.y <= rect.ury
}

///|
fn clip_to_bbox(
  from : @geom.Point,
  rect : @geom.Rect,
  target : @geom.Point,
) -> @geom.Point {
  let dx = target.x - from.x
  let dy = target.y - from.y
  if dx == 0.0 && dy == 0.0 {
    return from
  }
  if point_inside_bbox(target, rect) {
    return target
  }
  let eps = 0.000001
  let mut best : Double? = None
  let consider = (t : Double) => {
    if t <= 0.0 || t > 1.0 + eps {
      return
    }
    let x = from.x + dx * t
    let y = from.y + dy * t
    if x + eps < rect.llx || x - eps > rect.urx {
      return
    }
    if y + eps < rect.lly || y - eps > rect.ury {
      return
    }
    match best {
      Some(value) =>
        if t < value {
        best = Some(t)
      }
      None => best = Some(t)
    }
  }
  if dx != 0.0 {
    consider((rect.llx - from.x) / dx)
    consider((rect.urx - from.x) / dx)
  }
  if dy != 0.0 {
    consider((rect.lly - from.y) / dy)
    consider((rect.ury - from.y) / dy)
  }
  match best {
    Some(t) => point(from.x + dx * t, from.y + dy * t)
    None => from
  }
}

///|
fn point_line_distance(
  point : @geom.Point,
  a : @geom.Point,
  b : @geom.Point,
) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  if dx == 0.0 && dy == 0.0 {
    return @math.hypot(point.x - a.x, point.y - a.y)
  }
  let t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy)
  let proj = @geom.Point::{ x: a.x + t * dx, y: a.y + t * dy }
  @math.hypot(point.x - proj.x, point.y - proj.y)
}

///|
fn segment_intersects_rect(
  start : @geom.Point,
  end : @geom.Point,
  rect : @geom.Rect,
  eps : Double,
) -> Bool {
  let dx = end.x - start.x
  let dy = end.y - start.y
  let mut t0 = 0.0
  let mut t1 = 1.0
  let update = (p : Double, q : Double) => {
    if Double::abs(p) < 0.0000001 {
      if q < 0.0 { return false } else { return true }
    }
    let r = q / p
    if p < 0.0 {
      if r > t1 { return false }
      if r > t0 { t0 = r }
    } else {
      if r < t0 { return false }
      if r < t1 { t1 = r }
    }
    true
  }
  if !update(-dx, start.x - rect.llx) { return false }
  if !update(dx, rect.urx - start.x) { return false }
  if !update(-dy, start.y - rect.lly) { return false }
  if !update(dy, rect.ury - start.y) { return false }
  if t1 < 0.0 || t0 > 1.0 {
    return false
  }
  let min_t = if t0 < 0.0 { 0.0 } else { t0 }
  let max_t = if t1 > 1.0 { 1.0 } else { t1 }
  if max_t <= eps || min_t >= 1.0 - eps {
    return false
  }
  true
}

///|
fn detour_polyline_for_rects(
  tail : @geom.Point,
  head : @geom.Point,
  tail_rect : @geom.Rect,
  head_rect : @geom.Rect,
  nodesep_pt : Double,
  rankdir : RankDir,
) -> Array[@geom.Point] {
  let detour_margin = max_double(nodesep_pt * 0.75, 8.0)
  let exit_base = max_double(nodesep_pt * 1.25, 16.0)
  let entry_base = max_double(nodesep_pt * 0.3, 5.71)
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let dy = head.y - tail.y
      let total = Double::abs(dy)
      let exit_turn = if total > 0.0 {
        min_double(exit_base, total / 2.0)
      } else {
        exit_base
      }
      let entry_turn = if total > 0.0 {
        min_double(entry_base, total / 2.0)
      } else {
        entry_base
      }
      let exit_y =
        if dy < 0.0 {
        tail_rect.lly - exit_turn
      } else {
        tail_rect.ury + exit_turn
      }
      let entry_y =
        if dy < 0.0 {
        head_rect.lly - entry_turn
      } else {
        head_rect.ury + entry_turn
      }
      let left_x = min_double(tail_rect.llx, head_rect.llx) - detour_margin
      let right_x = max_double(tail_rect.urx, head_rect.urx) + detour_margin
      let path_len = (detour_x : Double) => {
        Double::abs(tail.y - exit_y) +
        Double::abs(tail.x - detour_x) +
        Double::abs(exit_y - entry_y) +
        Double::abs(head.x - detour_x) +
        Double::abs(head.y - entry_y)
      }
      let detour_x =
        if path_len(left_x) <= path_len(right_x) { left_x } else { right_x }
      [
        tail,
        point(tail.x, exit_y),
        point(detour_x, exit_y),
        point(detour_x, entry_y),
        point(head.x, entry_y),
        head,
      ]
    }
    RankDir::LR | RankDir::RL => {
      let dx = head.x - tail.x
      let total = Double::abs(dx)
      let exit_turn = if total > 0.0 {
        min_double(exit_base, total / 2.0)
      } else {
        exit_base
      }
      let entry_turn = if total > 0.0 {
        min_double(entry_base, total / 2.0)
      } else {
        entry_base
      }
      let exit_x =
        if dx < 0.0 {
        tail_rect.llx - exit_turn
      } else {
        tail_rect.urx + exit_turn
      }
      let entry_x =
        if dx < 0.0 {
        head_rect.llx - entry_turn
      } else {
        head_rect.urx + entry_turn
      }
      let lower_y = min_double(tail_rect.lly, head_rect.lly) - detour_margin
      let upper_y = max_double(tail_rect.ury, head_rect.ury) + detour_margin
      let path_len = (detour_y : Double) => {
        Double::abs(tail.x - exit_x) +
        Double::abs(tail.y - detour_y) +
        Double::abs(exit_x - entry_x) +
        Double::abs(head.y - detour_y) +
        Double::abs(head.x - entry_x)
      }
      let detour_y =
        if path_len(lower_y) <= path_len(upper_y) { lower_y } else { upper_y }
      [
        tail,
        point(exit_x, tail.y),
        point(exit_x, detour_y),
        point(entry_x, detour_y),
        point(entry_x, head.y),
        head,
      ]
    }
  }
}

///|
///|
fn simplify_polyline(
  points : Array[@geom.Point],
  tol : Double,
) -> Array[@geom.Point] {
  if tol <= 0.0 || points.length() <= 2 {
    return points
  }
  let last = points.length() - 1
  let keep = Array::make(points.length(), false)
  keep[0] = true
  keep[last] = true
  let stack : Array[(Int, Int)] = []
  stack.push((0, last))
  while stack.length() > 0 {
    let top = stack.length() - 1
    let (start, end) = stack[top]
    let _ = stack.pop()
    if end - start <= 1 {
      continue
    }
    let mut max_dist = -1.0
    let mut max_idx = -1
    let start_point = points[start]
    let end_point = points[end]
    for i in (start + 1)..<end {
      let dist = point_line_distance(points[i], start_point, end_point)
      if dist > max_dist {
        max_dist = dist
        max_idx = i
      }
    }
    if max_idx != -1 && max_dist > tol {
      keep[max_idx] = true
      stack.push((start, max_idx))
      stack.push((max_idx, end))
    }
  }
  let out : Array[@geom.Point] = []
  for i in 0..<points.length() {
    if keep[i] {
      out.push(points[i])
    }
  }
  out
}

///|
///|
fn edge_polyline_points(
  edge : @cgraph.Edge,
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  vnode_positions : Map[String, @geom.Point],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  nodesep_pt : Double,
  label_width_pt : Double,
  dotted_weight : Double,
  use_cluster_tuning : Bool,
  split_label : Bool,
) -> Array[@geom.Point] {
  let points : Array[@geom.Point] = [tail_anchor]
  let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
    Some(list) => list
    None => []
  }
  let tail_rank_opt = ranks.get(edge.tail().name())
  let head_rank_opt = ranks.get(edge.head().name())
  if vnodes.length() > 0 {
    match (tail_rank_opt, head_rank_opt) {
      (Some(tail_rank), Some(head_rank)) => {
        let span = head_rank - tail_rank
        if span != 0 {
          let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
          let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
          let label_rank = if label_width_pt > 0.0 {
            (min_rank + max_rank) / 2
          } else {
            -1
          }
          let y_dir = if head_anchor.y < tail_anchor.y { 1.0 } else { -1.0 }
          let style_value = match edge.get_attr("style") {
            Some(value) => value.to_lower()
            None => ""
          }
          let is_dotted = style_value.contains("dotted")
          let has_explicit_port =
            port_is_explicit(edge.tail_port()) || port_is_explicit(edge.head_port())
          let same_local_cluster =
            node_local_cluster_key(edge.tail()) == node_local_cluster_key(edge.head())
          let base_vnode_weight =
            if use_cluster_tuning {
              if is_dotted {
                if same_local_cluster { dotted_weight * 0.7 } else { dotted_weight }
              } else if split_label {
                0.3
              } else if label_width_pt > 0.0 && !has_explicit_port {
                if same_local_cluster {
                  1.0
                } else {
                  0.4
                }
              } else {
                0.0
              }
            } else {
              DEFAULT_VNODE_WEIGHT
            }
          let span_f = Double::from_int(span)
          let push_point = (name : String) => {
            match vnode_positions.get(name) {
              Some(pos) =>
                match vnode_ranks.get(name) {
                  Some(rank) => {
                    let t_raw = Double::from_int(rank - tail_rank) / span_f
                    let t =
                      if use_cluster_tuning && !is_dotted && head_anchor.x >= tail_anchor.x {
                        if split_label && rank == label_rank {
                          t_raw
                        } else {
                          t_raw * t_raw
                        }
                      } else {
                        t_raw
                      }
                    let interp_x = tail_anchor.x + (head_anchor.x - tail_anchor.x) * t
                    let base_y = match rank_y.get(rank) {
                      Some(value) => value
                      None => pos.y
                    }
                    let base_offset = match rank_ht1.get(rank) {
                      Some(value) => value
                      None => 0.0
                    }
                    let y = base_y + base_offset
                    let vnode_weight = base_vnode_weight
                    let x = pos.x * vnode_weight + interp_x * (1.0 - vnode_weight)
                    if split_label && rank == label_rank {
                      let split_width = label_width_pt * 1.5
                      let split_x = x - nodesep_pt * 1.25
                      points.push({
                        x: split_x - nodesep_pt,
                        y: y + nodesep_pt * y_dir,
                      })
                      points.push({
                        x: split_x + split_width * 0.5,
                        y: y - nodesep_pt * y_dir,
                      })
                    } else {
                      points.push({ x, y })
                    }
                  }
                  None => ()
                }
              None => ()
            }
          }
          if tail_rank <= head_rank {
            for name in vnodes {
              push_point(name)
            }
          } else {
            let mut idx = vnodes.length()
            while idx > 0 {
              idx = idx - 1
              let name = vnodes[idx]
              push_point(name)
            }
          }
        }
      }
      _ => ()
    }
  }
  points.push(head_anchor)
  points
}

///|
fn adjust_intercluster_dotted_points(
  points : Array[@geom.Point],
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  head_size : NodeSize,
  nodesep_pt : Double,
) -> Array[@geom.Point] {
  if points.length() <= 2 {
    return points
  }
  let last_idx = points.length() - 2
  let head_left = head_anchor.x - head_size.width_pt / 2.0
  let head_right = head_anchor.x + head_size.width_pt / 2.0
  let offset = max_double(2.0, nodesep_pt * 0.5)
  let x = if head_anchor.x >= tail_anchor.x {
    head_left - offset
  } else {
    head_right + offset
  }
  let y = tail_anchor.y + (head_anchor.y - tail_anchor.y) * 0.5
  let adjusted = points.copy()
  adjusted[last_idx] = { x, y }
  adjusted
}

///|
fn adjust_intracluster_dotted_points(
  points : Array[@geom.Point],
) -> Array[@geom.Point] {
  if points.length() <= 3 {
    return points
  }
  let adjusted = points.copy()
  let last = points.length() - 1
  let mid = points.length() / 2
  let mid_y = (points[0].y + points[last].y) / 2.0
  let left_weight = 0.2
  let right_weight = 0.8
  if points.length() % 2 == 0 {
    let left = mid - 1
    if left > 0 && left < last {
      let avg_y = (points[left - 1].y + points[left + 1].y) / 2.0
      adjusted[left] = {
        x: points[left].x,
        y: points[left].y * (1.0 - left_weight) + avg_y * left_weight,
      }
    }
    if mid > 0 && mid < last {
      adjusted[mid] = {
        x: points[mid].x,
        y: points[mid].y * (1.0 - right_weight) + mid_y * right_weight,
      }
    }
  } else if mid > 0 && mid < last {
    adjusted[mid] = {
      x: points[mid].x,
      y: points[mid].y * (1.0 - right_weight) + mid_y * right_weight,
    }
  }
  adjusted
}

///|
fn ordered_nodes(graph : @cgraph.Graph) -> Array[@cgraph.Node] {
  graph.nodes()
}

///|
fn node_cluster_key(node : @cgraph.Node) -> String {
  let mut graph = node.graph()
  let mut key = ""
  while !graph.is_root() {
    if is_cluster_graph(graph) {
      match graph.name() {
        Some(name) => key = name
        None => key = ""
      }
    }
    match graph.parent() {
      Some(parent) => graph = parent
      None => break
    }
  }
  key
}

///|
fn node_local_cluster_key(node : @cgraph.Node) -> String {
  let mut graph = node.graph()
  while !graph.is_root() {
    if is_cluster_graph(graph) {
      match graph.name() {
        Some(name) => return name
        None => return ""
      }
    }
    match graph.parent() {
      Some(parent) => graph = parent
      None => break
    }
  }
  ""
}

///|
fn graph_cluster_key(graph : @cgraph.Graph) -> String {
  let mut current = graph
  let mut key = ""
  while !current.is_root() {
    if is_cluster_graph(current) {
      match current.name() {
        Some(name) => key = name
        None => key = ""
      }
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  key
}

///|
fn collect_edge_cluster_keys(
  graph : @cgraph.Graph,
  edge_cluster_keys : Map[String, String],
) -> Unit {
  for child in graph.subgraphs() {
    collect_edge_cluster_keys(child, edge_cluster_keys)
  }
  if !is_cluster_graph(graph) {
    return ()
  }
  let cluster_key = graph_cluster_key(graph)
  if cluster_key == "" {
    return ()
  }
  let child_edges : Map[String, Bool] = Map::new()
  for child in graph.subgraphs() {
    for edge in child.edges() {
      child_edges[edge_key(edge)] = true
    }
  }
  for edge in graph.edges() {
    let key = edge_key(edge)
    if child_edges.get(key) is None {
      edge_cluster_keys[key] = cluster_key
    }
  }
}

///|
fn intercluster_edge_key(
  tail_cluster : String,
  head_cluster : String,
  tail_rank : Int,
  head_rank : Int,
) -> String {
  "\{tail_cluster}@\{tail_rank}->\{head_cluster}@\{head_rank}"
}

///|
fn cluster_rank_key(cluster : String, rank : Int) -> String {
  "\{cluster}@\{rank}"
}

///|
fn edge_is_constraint(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("constraint") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "false" && lower != "0" && lower != "no"
    }
    None => true
  }
}

///|
fn edge_weight(edge : @cgraph.Edge) -> Int {
  let weight_value = match edge.get_attr("weight") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
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
fn edge_xpenalty(edge : @cgraph.Edge) -> Int {
  let penalty_value = match edge.get_attr("xpenalty") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
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
fn edge_minlen(edge : @cgraph.Edge) -> Int {
  let minlen_value = match edge.get_attr("minlen") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let minlen = minlen_value.round().to_int()
  if minlen < 1 {
    1
  } else {
    minlen
  }
}

///|
fn edge_mid_label_text(edge : @cgraph.Edge) -> String? {
  match edge.get_attr("label") {
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
}

///|
fn edge_mid_label_width_pt(edge : @cgraph.Edge) -> Double {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  match edge_mid_label_text(edge) {
    Some(text) => {
      let (width, _height) = label_text_dimensions(text, font, font_size_pt)
      width
    }
    None => 0.0
  }
}

///|
fn edge_mid_label_metrics(edge : @cgraph.Edge) -> (Double, Double)? {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  match edge_mid_label_text(edge) {
    Some(text) => {
      let (width, height) = label_text_dimensions(text, font, font_size_pt)
      Some((width, height))
    }
    None => None
  }
}

///|
fn edge_label_height_pt(edge : @cgraph.Edge) -> Double {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  let mut max_height = 0.0
  let labels = ["label", "headlabel", "taillabel"]
  for name in labels {
    match edge.get_attr(name) {
      Some(text) =>
        if text != "" {
          let (_width, height) = label_text_dimensions(text, font, font_size_pt)
          if height > max_height {
            max_height = height
          }
        }
      None => ()
    }
  }
  max_height
}

///|
fn edge_has_label(edge : @cgraph.Edge) -> Bool {
  let labels = ["label", "headlabel", "taillabel"]
  for name in labels {
    match edge.get_attr(name) {
      Some(value) => if value != "" { return true }
      None => ()
    }
  }
  false
}

///|
fn graph_has_edge_labels(edges : Array[@cgraph.Edge]) -> Bool {
  for edge in edges {
    if edge_has_label(edge) {
      return true
    }
  }
  false
}

///|
fn self_edge_label_half_heights(
  edges : Array[@cgraph.Edge],
) -> Map[String, Double] {
  let heights : Map[String, Double] = Map::new()
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail != head {
      continue
    }
    let half_height = edge_label_height_pt(edge) / 2.0
    let current = match heights.get(tail) {
      Some(value) => value
      None => 0.0
    }
    if half_height > current {
      heights[tail] = half_height
    }
  }
  heights
}

///|
fn node_half_height_pt(
  name : String,
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
) -> Double {
  let base_height = match sizes.get(name) {
    Some(value) => value.height_pt / 2.0
    None => 0.0
  }
  let label_height = match self_edge_labels.get(name) {
    Some(value) => value
    None => 0.0
  }
  if label_height > base_height {
    label_height
  } else {
    base_height
  }
}

///|
fn cluster_label_padding_pt(graph : @cgraph.Graph) -> (Double, Double) {
  match graph_label_metrics(graph) {
    Some((_width_pt, height_pt)) => {
      let loc = graph_label_loc(graph)
      let pad = CLUSTER_LABEL_PAD_PT
      match loc {
        LabelLoc::Top => (height_pt + pad, 0.0)
        LabelLoc::Bottom => (0.0, height_pt + pad)
      }
    }
    None => (0.0, 0.0)
  }
}

///|
priv struct ClusterHeights {
  min_rank : Int
  max_rank : Int
  ht1 : Double
  ht2 : Double
}

///|
fn collect_cluster_rank_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  seen : Map[String, Bool],
  rank_heights : Map[Int, Double],
  min_rank : Int?,
  max_rank : Int?,
) -> (Int?, Int?) {
  let mut next_min = min_rank
  let mut next_max = max_rank
  for node in graph.nodes() {
    let name = node.name()
    if seen.get(name) is Some(_) {
      continue
    }
    seen[name] = true
    match ranks.get(name) {
      Some(rank) => {
        let half_height = node_half_height_pt(name, sizes, self_edge_labels)
        let current = match rank_heights.get(rank) {
          Some(value) => value
          None => 0.0
        }
        if half_height > current {
          rank_heights[rank] = half_height
        }
        match next_min {
          Some(value) => if rank < value { next_min = Some(rank) }
          None => next_min = Some(rank)
        }
        match next_max {
          Some(value) => if rank > value { next_max = Some(rank) }
          None => next_max = Some(rank)
        }
      }
      None => ()
    }
  }
  for child in graph.subgraphs() {
    let (child_min, child_max) = collect_cluster_rank_heights(
      child, ranks, sizes, self_edge_labels, seen, rank_heights, next_min, next_max,
    )
    next_min = child_min
    next_max = child_max
  }
  (next_min, next_max)
}

///|
fn apply_cluster_rank_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> ClusterHeights? {
  let is_cluster = is_cluster_graph(graph)
  let children = graph.subgraphs()
  if !is_cluster {
    for child in children {
      let _ = apply_cluster_rank_heights(
        child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
      )

    }
    return None
  }
  let seen : Map[String, Bool] = Map::new()
  let rank_heights : Map[Int, Double] = Map::new()
  let (min_rank, max_rank) = collect_cluster_rank_heights(
    graph,
    ranks,
    sizes,
    self_edge_labels,
    seen,
    rank_heights,
    None,
    None,
  )
  let min_rank_value = match min_rank {
    Some(value) => value
    None => {
      for child in children {
        let _ = apply_cluster_rank_heights(
          child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
        )

      }
      return None
    }
  }
  let max_rank_value = match max_rank {
    Some(value) => value
    None => {
      for child in children {
        let _ = apply_cluster_rank_heights(
          child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
        )

      }
      return None
    }
  }
  let margin = cluster_margin_pt(graph)
  let base_top = match rank_heights.get(max_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let base_bottom = match rank_heights.get(min_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let mut ht1 = base_top + margin
  let mut ht2 = base_bottom + margin
  for child in children {
    match
      apply_cluster_rank_heights(
        child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
      ) {
      Some(info) => {
        if info.max_rank == max_rank_value {
          let candidate = info.ht1 + margin
          if candidate > ht1 {
            ht1 = candidate
          }
        }
        if info.min_rank == min_rank_value {
          let candidate = info.ht2 + margin
          if candidate > ht2 {
            ht2 = candidate
          }
        }
      }
      None => ()
    }
  }
  let (label_top, label_bottom) = cluster_label_padding_pt(graph)
  ht1 = ht1 + label_bottom
  ht2 = ht2 + label_top
  let current_top = match rank_ht1.get(max_rank_value) {
    Some(value) => value
    None => 0.0
  }
  if ht1 > current_top {
    rank_ht1[max_rank_value] = ht1
  }
  let current_bottom = match rank_ht2.get(min_rank_value) {
    Some(value) => value
    None => 0.0
  }
  if ht2 > current_bottom {
    rank_ht2[min_rank_value] = ht2
  }
  Some({ min_rank: min_rank_value, max_rank: max_rank_value, ht1, ht2 })
}

///|
fn collect_rank_extremes(
  subgraph : @cgraph.Graph,
  min_nodes : Map[String, Bool],
  max_nodes : Map[String, Bool],
) -> Unit {
  match subgraph.get_attr("rank") {
    Some(value) => {
      let lower = value.to_lower()
      if lower == "min" || lower == "source" {
        for node in subgraph.nodes() {
          min_nodes[node.name()] = true
        }
      } else if lower == "max" || lower == "sink" {
        for node in subgraph.nodes() {
          max_nodes[node.name()] = true
        }
      }
    }
    None => ()
  }
  for child in subgraph.subgraphs() {
    collect_rank_extremes(child, min_nodes, max_nodes)
  }
}

///|
fn apply_rank_extremes(
  ranks : Map[String, Int],
  min_nodes : Map[String, Bool],
  max_nodes : Map[String, Bool],
) -> Unit {
  if ranks.length() == 0 {
    return ()
  }
  let mut max_rank = 0
  let mut seen = false
  for _name, rank in ranks {
    if !seen {
      max_rank = rank
      seen = true
    } else if rank > max_rank {
      max_rank = rank
    }
  }
  if min_nodes.length() > 0 {
    for name, _ in min_nodes {
      match ranks.get(name) {
        Some(_) => ranks[name] = 0
        None => ()
      }
    }
  }
  if max_nodes.length() > 0 {
    for name, _ in max_nodes {
      match ranks.get(name) {
        Some(_) => ranks[name] = max_rank
        None => ()
      }
    }
  }
}

///|
fn add_rank_same_constraints(
  rank_graph : NsGraph,
  index : Map[String, Int],
  subgraph : @cgraph.Graph,
) -> Unit {
  match subgraph.get_attr("rank") {
    Some(value) =>
      if value.to_lower() == "same" {
        let nodes = subgraph.nodes()
        if nodes.length() > 1 {
          let mut i = 0
          while i < nodes.length() {
            let name_i = nodes[i].name()
            let idx_i = match index.get(name_i) {
              Some(value) => value
              None => -1
            }
            if idx_i >= 0 {
              let mut j = i + 1
              while j < nodes.length() {
                let name_j = nodes[j].name()
                let idx_j = match index.get(name_j) {
                  Some(value) => value
                  None => -1
                }
                if idx_j >= 0 {
                  let _ = add_edge(rank_graph, idx_i, idx_j, 0, 1000)
                  let _ = add_edge(rank_graph, idx_j, idx_i, 0, 1000)

                }
                j = j + 1
              }
            }
            i = i + 1
          }
        }
      }
    None => ()
  }
  for child in subgraph.subgraphs() {
    add_rank_same_constraints(rank_graph, index, child)
  }
}

///|
fn collect_rank_same_order(
  graph : @cgraph.Graph,
  group_ids : Map[String, Int],
  order_ids : Map[String, Int],
  next_group : Int,
) -> Int {
  let mut current_group = next_group
  match graph.get_attr("rank") {
    Some(value) =>
      if value.to_lower() == "same" {
        let group_id = current_group
        current_group = current_group + 1
        let mut idx = 0
        for node in graph.nodes() {
          if group_ids.get(node.name()) is None {
            group_ids[node.name()] = group_id
            order_ids[node.name()] = idx
          }
          idx = idx + 1
        }
      }
    None => ()
  }
  for child in graph.subgraphs() {
    current_group = collect_rank_same_order(
      child, group_ids, order_ids, current_group,
    )
  }
  current_group
}

///|
fn remove_edge_at(list : Array[Int], idx : Int) -> Unit {
  let mut i = idx
  while i + 1 < list.length() {
    list[i] = list[i + 1]
    i = i + 1
  }
  let _ = list.pop()
}

///|
fn acyclic_dfs(
  idx : Int,
  node_index : Map[String, Int],
  out_edges : Array[Array[Int]],
  edge_is_active : Array[Bool],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  marked : Array[Bool],
  onstack : Array[Bool],
) -> Unit {
  if marked[idx] {
    return ()
  }
  let stack : Array[(Int, Int)] = []
  marked[idx] = true
  onstack[idx] = true
  stack.push((idx, 0))
  while stack.length() > 0 {
    let top_idx = stack.length() - 1
    let (node_idx, edge_pos) = stack[top_idx]
    if edge_pos >= out_edges[node_idx].length() {
      onstack[node_idx] = false
      let _ = stack.pop()
      continue
    }
    let edge_idx = out_edges[node_idx][edge_pos]
    if !edge_is_active[edge_idx] {
      stack[top_idx] = (node_idx, edge_pos + 1)
      continue
    }
    let head_name = edge_head[edge_idx]
    let head_idx = match node_index.get(head_name) {
      Some(value) => value
      None => {
        stack[top_idx] = (node_idx, edge_pos + 1)
        continue
      }
    }
    if onstack[head_idx] {
      if head_idx == node_idx {
        stack[top_idx] = (node_idx, edge_pos + 1)
        continue
      }
      // Reverse the edge and update adjacency to match Graphviz's acyclic pass.
      let old_tail = edge_tail[edge_idx]
      edge_tail[edge_idx] = edge_head[edge_idx]
      edge_head[edge_idx] = old_tail
      edge_reversed[edge_idx] = !edge_reversed[edge_idx]
      remove_edge_at(out_edges[node_idx], edge_pos)
      out_edges[head_idx].push(edge_idx)
      continue
    }
    if !marked[head_idx] {
      stack[top_idx] = (node_idx, edge_pos + 1)
      marked[head_idx] = true
      onstack[head_idx] = true
      stack.push((head_idx, 0))
      continue
    }
    stack[top_idx] = (node_idx, edge_pos + 1)
  }
}

///|
fn acyclic_edge_directions(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> (Array[String], Array[String], Array[Bool]) {
  let node_index : Map[String, Int] = Map::new()
  for i in 0..<nodes.length() {
    node_index[nodes[i].name()] = i
  }
  let edge_tail : Array[String] = []
  let edge_head : Array[String] = []
  let edge_reversed : Array[Bool] = []
  let edge_is_active : Array[Bool] = []
  let out_edges : Array[Array[Int]] = []
  for _ in 0..<nodes.length() {
    out_edges.push([])
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    edge_tail.push(tail)
    edge_head.push(head)
    edge_reversed.push(false)
    let active = edge_is_constraint(edge)
    edge_is_active.push(active)
    if active {
      match node_index.get(tail) {
        Some(idx) => out_edges[idx].push(edge_tail.length() - 1)
        None => ()
      }
    }
  }
  let marked : Array[Bool] = []
  let onstack : Array[Bool] = []
  for _ in 0..<nodes.length() {
    marked.push(false)
    onstack.push(false)
  }
  for i in 0..<nodes.length() {
    if !marked[i] {
      acyclic_dfs(
        i,
        node_index,
        out_edges,
        edge_is_active,
        edge_tail,
        edge_head,
        edge_reversed,
        marked,
        onstack,
      )
    }
  }
  (edge_tail, edge_head, edge_reversed)
}

///|
fn acyclic_edge_directions_for_names(
  node_names : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_is_active : Array[Bool],
) -> (Array[String], Array[String], Array[Bool]) {
  let node_index : Map[String, Int] = Map::new()
  for i in 0..<node_names.length() {
    node_index[node_names[i]] = i
  }
  let tail = edge_tail.copy()
  let head = edge_head.copy()
  let edge_reversed : Array[Bool] = []
  let out_edges : Array[Array[Int]] = []
  for _ in 0..<node_names.length() {
    out_edges.push([])
  }
  for i in 0..<tail.length() {
    edge_reversed.push(false)
    if i < edge_is_active.length() && edge_is_active[i] {
      match node_index.get(tail[i]) {
        Some(idx) => out_edges[idx].push(i)
        None => ()
      }
    }
  }
  let marked : Array[Bool] = []
  let onstack : Array[Bool] = []
  for _ in 0..<node_names.length() {
    marked.push(false)
    onstack.push(false)
  }
  for i in 0..<node_names.length() {
    if !marked[i] {
      acyclic_dfs(
        i,
        node_index,
        out_edges,
        edge_is_active,
        tail,
        head,
        edge_reversed,
        marked,
        onstack,
      )
    }
  }
  (tail, head, edge_reversed)
}

///|
fn edge_endpoints_from_edges(
  edges : Array[@cgraph.Edge],
) -> (Array[String], Array[String], Array[Bool]) {
  let edge_tail : Array[String] = []
  let edge_head : Array[String] = []
  let edge_reversed : Array[Bool] = []
  for edge in edges {
    edge_tail.push(edge.tail().name())
    edge_head.push(edge.head().name())
    edge_reversed.push(false)
  }
  (edge_tail, edge_head, edge_reversed)
}

///|
fn compute_ranks_directed_base(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  _edge_reversed : Array[Bool],
) -> Map[String, Int] {
  let graph = new_graph()
  let index : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    index[name] = add_node(graph, name)
  }
  let merged_edges : Map[String, (Int, Int, Int, Int)] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    if !edge_is_constraint(edge) {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_idx = match index.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_idx = match index.get(head) {
      Some(value) => value
      None => 0
    }
    let minlen_value = edge_minlen(edge)
    let minlen = if has_edge_labels { minlen_value * 2 } else { minlen_value }
    let weight = edge_weight(edge)
    let key = "\{tail_idx}:\{head_idx}"
    match merged_edges.get(key) {
      Some(entry) => {
        let (_tail_idx, _head_idx, current_minlen, current_weight) = entry
        let next_minlen = if minlen > current_minlen { minlen } else { current_minlen }
        merged_edges[key] = (tail_idx, head_idx, next_minlen, current_weight + weight)
      }
      None => merged_edges[key] = (tail_idx, head_idx, minlen, weight)
    }

  }
  for _key, entry in merged_edges {
    let (tail_idx, head_idx, minlen, weight) = entry
    let _ = add_edge(graph, tail_idx, head_idx, minlen, weight)
  }
  add_rank_same_constraints(graph, index, source)
  network_simplex(graph, 0x7fffffff, BalanceMode::TB)
  let ranks : Map[String, Int] = Map::new()
  let mut min_rank = 0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    let rank = node_rank(graph, idx)
    if !seen {
      min_rank = rank
      seen = true
    } else if rank < min_rank {
      min_rank = rank
    }
  }
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    let rank = node_rank(graph, idx) - min_rank
    ranks[name] = rank
  }
  let min_nodes : Map[String, Bool] = Map::new()
  let max_nodes : Map[String, Bool] = Map::new()
  collect_rank_extremes(source, min_nodes, max_nodes)
  apply_rank_extremes(ranks, min_nodes, max_nodes)
  ranks
}

///|
fn compute_ranks_directed_with_clusters(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
) -> Map[String, Int] {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(source, None, cluster_graphs, cluster_parents)
  let root_cluster_name =
    if is_cluster_graph(source) {
    match source.name() {
      Some(value) => value
      None => ""
    }
  } else {
    ""
  }
  let top_clusters : Array[String] = []
  for name, parent in cluster_parents {
    match parent {
      None =>
        if name != root_cluster_name {
          top_clusters.push(name)
        }
      Some(_) => ()
    }
  }
  if top_clusters.length() == 0 {
    let (base_tail, base_head, base_reversed) =
      acyclic_edge_directions(nodes, edges)
    return compute_ranks_directed_base(
      source,
      nodes,
      edges,
      has_edge_labels,
      base_tail,
      base_head,
      base_reversed,
    )
  }
  let cluster_members = collect_cluster_members(cluster_graphs)
  let node_cluster : Map[String, String] = Map::new()
  for cluster_name in top_clusters {
    match cluster_members.get(cluster_name) {
      Some(members) =>
        for name, _ in members {
          node_cluster[name] = cluster_name
        }
      None => ()
    }
  }
  let local_ranks : Map[String, Int] = Map::new()
  let cluster_leaders : Map[String, String] = Map::new()
  for cluster_name in top_clusters {
    let members = match cluster_members.get(cluster_name) {
      Some(value) => value
      None => continue
    }
    let cluster_nodes : Array[@cgraph.Node] = []
    for node in nodes {
      if members.get(node.name()) is Some(_) {
        cluster_nodes.push(node)
      }
    }
    if cluster_nodes.length() == 0 {
      continue
    }
    let cluster_edges : Array[@cgraph.Edge] = []
    for edge in edges {
      let tail = edge.tail().name()
      let head = edge.head().name()
      if members.get(tail) is Some(_) && members.get(head) is Some(_) {
        cluster_edges.push(edge)
      }
    }
    let (cluster_tail, cluster_head, cluster_reversed) =
      acyclic_edge_directions(cluster_nodes, cluster_edges)
    let cluster_graph = match cluster_graphs.get(cluster_name) {
      Some(value) => value
      None => source
    }
    let cluster_ranks = compute_ranks_directed(
      cluster_graph,
      cluster_nodes,
      cluster_edges,
      has_edge_labels,
      cluster_tail,
      cluster_head,
      cluster_reversed,
    )
    for name, rank in cluster_ranks {
      local_ranks[name] = rank
    }
    let mut leader_name : String? = None
    for node in cluster_nodes {
      let name = node.name()
      match cluster_ranks.get(name) {
        Some(rank) =>
          if rank == 0 && leader_name is None {
            leader_name = Some(name)
          }
        None => ()
      }
    }
    let leader =
      match leader_name {
        Some(name) => name
        None => cluster_nodes[0].name()
      }
    cluster_leaders[cluster_name] = leader
  }
  let rank_graph = new_graph()
  let rank_index : Map[String, Int] = Map::new()
  let rank_names : Array[String] = []
  for node in nodes {
    let name = node.name()
    let cluster = match node_cluster.get(name) {
      Some(value) => value
      None => ""
    }
    let key =
      if cluster == "" {
        name
      } else {
        match cluster_leaders.get(cluster) {
          Some(value) => value
          None => name
        }
      }
    if rank_index.get(key) is None {
      rank_index[key] = add_node(rank_graph, key)
      rank_names.push(key)
    }
  }
  let direct_tail : Array[String] = []
  let direct_head : Array[String] = []
  let direct_minlen : Array[Int] = []
  let direct_weight : Array[Int] = []
  let direct_active : Array[Bool] = []
  let mut slack_id = 0
  for edge in edges {
    if !edge_is_constraint(edge) {
      continue
    }
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    let tail_cluster = match node_cluster.get(tail_name) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match node_cluster.get(head_name) {
      Some(value) => value
      None => ""
    }
    let minlen_value = edge_minlen(edge)
    let minlen = if has_edge_labels { minlen_value * 2 } else { minlen_value }
    let weight = edge_weight(edge)
    if tail_cluster == head_cluster {
      if tail_cluster == "" && tail_name != head_name {
        direct_tail.push(tail_name)
        direct_head.push(head_name)
        direct_minlen.push(minlen)
        direct_weight.push(weight)
        direct_active.push(true)
      }
      continue
    }
    let tail_leader =
      if tail_cluster == "" {
        tail_name
      } else {
        match cluster_leaders.get(tail_cluster) {
          Some(value) => value
          None => tail_name
        }
      }
    let head_leader =
      if head_cluster == "" {
        head_name
      } else {
        match cluster_leaders.get(head_cluster) {
          Some(value) => value
          None => head_name
        }
      }
    let tail_local = match local_ranks.get(tail_name) {
      Some(value) => value
      None => 0
    }
    let head_local = match local_ranks.get(head_name) {
      Some(value) => value
      None => 0
    }
    let offset = minlen + tail_local - head_local
    let (t_len, h_len) =
      if offset > 0 { (0, offset) } else { (-offset, 0) }
    let slack_name = "_mbt_rank_slack_\{slack_id}"
    slack_id = slack_id + 1
    let slack_idx = add_node(rank_graph, slack_name, kind=NodeKind::Slack)
    let tail_idx = match rank_index.get(tail_leader) {
      Some(value) => value
      None => continue
    }
    let head_idx = match rank_index.get(head_leader) {
      Some(value) => value
      None => continue
    }
    let _ = add_edge(rank_graph, slack_idx, tail_idx, t_len, weight * CL_BACK)
    let _ = add_edge(rank_graph, slack_idx, head_idx, h_len, weight)
  }
  let (direct_tail_final, direct_head_final, _direct_rev) =
    acyclic_edge_directions_for_names(
      rank_names,
      direct_tail,
      direct_head,
      direct_active,
    )
  let merged_edges : Map[String, (Int, Int, Int, Int)] = Map::new()
  for i in 0..<direct_tail_final.length() {
    let tail_name = direct_tail_final[i]
    let head_name = direct_head_final[i]
    if tail_name == head_name {
      continue
    }
    let tail_idx = match rank_index.get(tail_name) {
      Some(value) => value
      None => continue
    }
    let head_idx = match rank_index.get(head_name) {
      Some(value) => value
      None => continue
    }
    let minlen = direct_minlen[i]
    let weight = direct_weight[i]
    let key = "\{tail_idx}:\{head_idx}"
    match merged_edges.get(key) {
      Some(entry) => {
        let (_tail_idx, _head_idx, current_minlen, current_weight) = entry
        let next_minlen =
          if minlen > current_minlen { minlen } else { current_minlen }
        merged_edges[key] =
          (tail_idx, head_idx, next_minlen, current_weight + weight)
      }
      None => merged_edges[key] = (tail_idx, head_idx, minlen, weight)
    }
  }
  for _key, entry in merged_edges {
    let (tail_idx, head_idx, minlen, weight) = entry
    let _ = add_edge(rank_graph, tail_idx, head_idx, minlen, weight)
  }
  let _ = network_simplex_pre_balance(rank_graph, 0x7fffffff)
  let leader_ranks : Map[String, Int] = Map::new()
  for name, idx in rank_index {
    leader_ranks[name] = node_rank(rank_graph, idx)
  }
  let ranks : Map[String, Int] = Map::new()
  let mut min_rank = 0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let cluster = match node_cluster.get(name) {
      Some(value) => value
      None => ""
    }
    let base_rank =
      if cluster == "" {
        match leader_ranks.get(name) {
          Some(value) => value
          None => 0
        }
      } else {
        let leader = match cluster_leaders.get(cluster) {
          Some(value) => value
          None => name
        }
        let leader_rank = match leader_ranks.get(leader) {
          Some(value) => value
          None => 0
        }
        let local_rank = match local_ranks.get(name) {
          Some(value) => value
          None => 0
        }
        leader_rank + local_rank
      }
    if !seen {
      min_rank = base_rank
      seen = true
    } else if base_rank < min_rank {
      min_rank = base_rank
    }
    ranks[name] = base_rank
  }
  for name, rank in ranks {
    ranks[name] = rank - min_rank
  }
  let min_nodes : Map[String, Bool] = Map::new()
  let max_nodes : Map[String, Bool] = Map::new()
  collect_rank_extremes(source, min_nodes, max_nodes)
  apply_rank_extremes(ranks, min_nodes, max_nodes)
  ranks
}

///|
fn compute_ranks_directed(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
) -> Map[String, Int] {
  if graph_has_cluster(source) {
    return compute_ranks_directed_with_clusters(
      source,
      nodes,
      edges,
      has_edge_labels,
    )
  }
  compute_ranks_directed_base(
    source,
    nodes,
    edges,
    has_edge_labels,
    edge_tail,
    edge_head,
    edge_reversed,
  )
}

///|
fn dedup_ordering_edges(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (Array[@cgraph.Edge], Array[String], Array[String]) {
  let seen : Map[String, Bool] = Map::new()
  let out_edges : Array[@cgraph.Edge] = []
  let out_tail : Array[String] = []
  let out_head : Array[String] = []
  for i in 0..<edges.length() {
    let tail =
      if i < edge_tail.length() { edge_tail[i] } else { edges[i].tail().name() }
    let head =
      if i < edge_head.length() { edge_head[i] } else { edges[i].head().name() }
    let key = "\{tail}|\{head}"
    if seen.get(key) is Some(_) {
      continue
    }
    seen[key] = true
    out_edges.push(edges[i])
    out_tail.push(tail)
    out_head.push(head)
  }
  (out_edges, out_tail, out_head)
}

///| 
///|
fn build_ordering_flat_constraints(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
) -> (Map[String, Bool], Bool) {
  let flat_constraints : Map[String, Bool] = Map::new()
  let out_edges : Map[String, Array[(Int, Int)]] = Map::new()
  let in_edges : Map[String, Array[(Int, Int)]] = Map::new()
  for node in nodes {
    let name = node.name()
    out_edges[name] = []
    in_edges[name] = []
  }
  for i in 0..<edges.length() {
    let tail =
      if i < edge_tail.length() { edge_tail[i] } else { edges[i].tail().name() }
    let head =
      if i < edge_head.length() { edge_head[i] } else { edges[i].head().name() }
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if tail_cluster != head_cluster {
      continue
    }
    let edge_id = edges[i].id()
    match out_edges.get(tail) {
      Some(list) => list.push((edge_id, i))
      None => out_edges[tail] = [(edge_id, i)]
    }
    match in_edges.get(head) {
      Some(list) => list.push((edge_id, i))
      None => in_edges[head] = [(edge_id, i)]
    }
  }
  let apply_ordering = (name : String, mode : OrderingMode) => {
    let list = match mode {
      OrderingMode::Out => {
        match out_edges.get(name) {
          Some(items) => items
          None => []
        }
      }
      OrderingMode::In => {
        match in_edges.get(name) {
          Some(items) => items
          None => []
        }
      }
    }
    if list.length() <= 1 {
      return ()
    }
    let sorted = list.copy()
    sorted.sort_by((a, b) => {
      let (a_id, _a_idx) = a
      let (b_id, _b_idx) = b
      if a_id < b_id {
        -1
      } else if a_id > b_id {
        1
      } else {
        0
      }
    })
    let mut idx = 1
    while idx < sorted.length() {
      let (_prev_id, prev_idx) = sorted[idx - 1]
      let (_curr_id, curr_idx) = sorted[idx]
      let left = match mode {
        OrderingMode::Out =>
          if prev_idx < edge_head.length() {
          edge_head[prev_idx]
        } else {
          edges[prev_idx].head().name()
        }
        OrderingMode::In =>
          if prev_idx < edge_tail.length() {
          edge_tail[prev_idx]
        } else {
          edges[prev_idx].tail().name()
        }
      }
      let right = match mode {
        OrderingMode::Out =>
          if curr_idx < edge_head.length() {
          edge_head[curr_idx]
        } else {
          edges[curr_idx].head().name()
        }
        OrderingMode::In =>
          if curr_idx < edge_tail.length() {
          edge_tail[curr_idx]
        } else {
          edges[curr_idx].tail().name()
        }
      }
      if left != right {
        flat_constraints["\{left}|\{right}"] = true
      }
      idx = idx + 1
    }
  }
  let graph_ordering = match graph.get_attr("ordering") {
    Some(value) => parse_ordering_mode(value)
    None => None
  }
  let mut ordering_set = false
  match graph_ordering {
    Some(mode) => {
      ordering_set = true
      for node in nodes {
        apply_ordering(node.name(), mode)
      }
    }
    None => {
      for node in nodes {
        match node.get_attr("ordering") {
          Some(value) =>
            match parse_ordering_mode(value) {
              Some(mode) => {
                ordering_set = true
                apply_ordering(node.name(), mode)
              }
              None => ()
            }
          None => ()
        }
      }
    }
  }
  (flat_constraints, ordering_set)
}

///|
///|
fn build_edge_index_for_order(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let parents : Map[String, Array[String]] = Map::new()
  let children : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    parents[name] = []
    children[name] = []
  }
  for edge_idx in 0..<edges.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    match parents.get(head) {
      Some(list) => list.push(tail)
      None => parents[head] = [tail]
    }
    match children.get(tail) {
      Some(list) => list.push(head)
      None => children[tail] = [head]
    }
  }
  (parents, children)
}

///|
fn build_edge_index_for_order_with_vnodes(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let parents : Map[String, Array[String]] = Map::new()
  let children : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    parents[name] = []
    children[name] = []
  }
  for vnode, _ in vnode_ranks {
    parents[vnode] = []
    children[vnode] = []
  }
  for edge_idx in 0..<edges.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    let (low, high) = if tail_rank <= head_rank { (tail, head) } else { (head, tail) }
    let vnodes = match edge_vnodes.get(edge_vnode_key(edges[edge_idx])) {
      Some(list) => list
      None => []
    }
    let mut prev = low
    for vnode in vnodes {
      match parents.get(vnode) {
        Some(list) => list.push(prev)
        None => parents[vnode] = [prev]
      }
      match children.get(prev) {
        Some(list) => list.push(vnode)
        None => children[prev] = [vnode]
      }
      prev = vnode
    }
    match parents.get(high) {
      Some(list) => list.push(prev)
      None => parents[high] = [prev]
    }
    match children.get(prev) {
      Some(list) => list.push(high)
      None => children[prev] = [high]
    }
  }
  (parents, children)
}

///|
fn position_key(
  name : String,
  desired : Map[String, Double],
  x_positions : Map[String, Double],
) -> Double {
  match desired.get(name) {
    Some(value) => value
    None =>
      match x_positions.get(name) {
        Some(value) => value
        None => 0.0
      }
  }
}

///|
fn is_edge_vnode_name(name : String) -> Bool {
  name.has_prefix(EDGE_VNODE_PREFIX)
}

///|
priv struct PositionSortInfo {
  name : String
  key : Double
  is_vnode : Bool
  degree : Int
  secondary : Int
  penalty : Int
  ported : Bool
  node_order : Int
  original_index : Int
  port_order : Double?
  rank_same_group : Int?
  rank_same_order : Int
}

///|
fn sort_by_positions_fast(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  node_order : Map[String, Int],
  reverse_ties : Bool,
) -> Array[String] {
  let infos : Array[PositionSortInfo] = []
  for i in 0..<names.length() {
    let name = names[i]
    let key = position_key(name, desired, x_positions)
    let degree = match primary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let secondary_degree = match secondary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let penalty = match node_penalty.get(name) {
      Some(value) => value
      None => 0
    }
    let ported = port_edge_nodes.get(name) is Some(_)
    let is_vnode = is_edge_vnode_name(name)
    let order_value = match node_order.get(name) {
      Some(value) => value
      None => i
    }
    infos.push({
      name,
      key,
      is_vnode,
      degree,
      secondary: secondary_degree,
      penalty,
      ported,
      node_order: order_value,
      original_index: i,
      port_order: None,
      rank_same_group: None,
      rank_same_order: 0,
    })
  }
  let eps = 0.000001
  infos.sort_by((a, b) => {
    let diff = a.key - b.key
    if Double::abs(diff) > eps {
      if diff < 0.0 { -1 } else { 1 }
    } else if a.is_vnode != b.is_vnode {
      if a.is_vnode { -1 } else { 1 }
    } else if a.degree != b.degree {
      if a.degree > b.degree { -1 } else { 1 }
    } else if a.ported != b.ported {
      if a.ported { -1 } else { 1 }
    } else if a.secondary != b.secondary {
      if a.secondary > b.secondary { -1 } else { 1 }
    } else if a.penalty != b.penalty {
      if a.penalty > b.penalty { -1 } else { 1 }
    } else if a.node_order != b.node_order {
      if reverse_ties {
        if a.node_order < b.node_order { 1 } else { -1 }
      } else {
        if a.node_order < b.node_order { -1 } else { 1 }
      }
    } else if a.original_index != b.original_index {
      if reverse_ties {
        if a.original_index < b.original_index { 1 } else { -1 }
      } else {
        if a.original_index < b.original_index { -1 } else { 1 }
      }
    } else {
      0
    }
  })
  let sorted : Array[String] = []
  for info in infos {
    sorted.push(info.name)
  }
  sorted
}

///|
fn sort_by_positions_large(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  node_order : Map[String, Int],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  port_order_positions : Map[String, Double],
  reverse_ties : Bool,
) -> Array[String] {
  let infos : Array[PositionSortInfo] = []
  for i in 0..<names.length() {
    let name = names[i]
    let key = position_key(name, desired, x_positions)
    let degree = match primary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let secondary_degree = match secondary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let penalty = match node_penalty.get(name) {
      Some(value) => value
      None => 0
    }
    let ported = port_edge_nodes.get(name) is Some(_)
    let is_vnode = is_edge_vnode_name(name)
    let order_value = match node_order.get(name) {
      Some(value) => value
      None => i
    }
    let port_order = port_order_positions.get(name)
    let rank_group = rank_same_groups.get(name)
    let rank_order = match rank_same_order.get(name) {
      Some(value) => value
      None => 0
    }
    infos.push({
      name,
      key,
      is_vnode,
      degree,
      secondary: secondary_degree,
      penalty,
      ported,
      node_order: order_value,
      original_index: i,
      port_order,
      rank_same_group: rank_group,
      rank_same_order: rank_order,
    })
  }
  let eps = 0.000001
  infos.sort_by((a, b) => {
    let diff = a.key - b.key
    if Double::abs(diff) > eps {
      if diff < 0.0 { -1 } else { 1 }
    } else {
      let port_cmp = match a.port_order {
        Some(a_port) =>
          match b.port_order {
            Some(b_port) =>
              if a_port != b_port {
                if a_port < b_port { -1 } else { 1 }
              } else {
                0
              }
            None => 0
          }
        None => 0
      }
      if port_cmp != 0 {
        port_cmp
      } else if a.is_vnode != b.is_vnode {
        if a.is_vnode { -1 } else { 1 }
      } else if a.degree != b.degree {
        if a.degree > b.degree { -1 } else { 1 }
      } else if a.ported != b.ported {
        if a.ported { -1 } else { 1 }
      } else if a.secondary != b.secondary {
        if a.secondary > b.secondary { -1 } else { 1 }
      } else if a.penalty != b.penalty {
        if a.penalty > b.penalty { -1 } else { 1 }
      } else if a.ported && b.ported && a.node_order != b.node_order {
        if reverse_ties {
          if a.node_order < b.node_order { 1 } else { -1 }
        } else {
          if a.node_order < b.node_order { -1 } else { 1 }
        }
      } else {
        match a.rank_same_group {
          Some(group) =>
            match b.rank_same_group {
              Some(other_group) =>
                if group == other_group && a.rank_same_order != b.rank_same_order {
                  if a.rank_same_order < b.rank_same_order { -1 } else { 1 }
                } else if a.node_order != b.node_order {
                  if reverse_ties {
                    if a.node_order < b.node_order { 1 } else { -1 }
                  } else {
                    if a.node_order < b.node_order { -1 } else { 1 }
                  }
                } else if a.original_index != b.original_index {
                  if reverse_ties {
                    if a.original_index < b.original_index { 1 } else { -1 }
                  } else {
                    if a.original_index < b.original_index { -1 } else { 1 }
                  }
                } else {
                  0
                }
              None =>
                if a.node_order != b.node_order {
                  if reverse_ties {
                    if a.node_order < b.node_order { 1 } else { -1 }
                  } else {
                    if a.node_order < b.node_order { -1 } else { 1 }
                  }
                } else if a.original_index != b.original_index {
                  if reverse_ties {
                    if a.original_index < b.original_index { 1 } else { -1 }
                  } else {
                    if a.original_index < b.original_index { -1 } else { 1 }
                  }
                } else {
                  0
                }
            }
          None =>
            if a.node_order != b.node_order {
              if reverse_ties {
                if a.node_order < b.node_order { 1 } else { -1 }
              } else {
                if a.node_order < b.node_order { -1 } else { 1 }
              }
            } else if a.original_index != b.original_index {
              if reverse_ties {
                if a.original_index < b.original_index { 1 } else { -1 }
              } else {
                if a.original_index < b.original_index { -1 } else { 1 }
              }
            } else {
              0
            }
        }
      }
    }
  })
  let sorted : Array[String] = []
  for info in infos {
    sorted.push(info.name)
  }
  sorted
}

///|
fn sort_by_positions(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  parents_map : Map[String, Array[String]],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  edge_pair_order : Map[String, Int],
  port_order_positions : Map[String, Double],
  reverse_ties : Bool,
) -> Array[String] {
  let sorted = names.copy()
  if sorted.length() < 2 {
    return sorted
  }
  let mut has_port_order = false
  for _name, _ in port_order_positions {
    has_port_order = true
    break
  }
  let mut has_rank_same = false
  for _name, _ in rank_same_groups {
    has_rank_same = true
    break
  }
  let mut has_ported_nodes = false
  for _name, _ in port_edge_nodes {
    has_ported_nodes = true
    break
  }
  if sorted.length() >= LARGE_SORT_THRESHOLD {
    return sort_by_positions_large(
      sorted,
      desired,
      x_positions,
      primary,
      secondary,
      node_penalty,
      port_edge_nodes,
      node_order,
      rank_same_groups,
      rank_same_order,
      port_order_positions,
      reverse_ties,
    )
  }
  if sorted.length() >= 64 && !has_port_order && !has_rank_same && !has_ported_nodes {
    return sort_by_positions_fast(
      sorted,
      desired,
      x_positions,
      primary,
      secondary,
      node_penalty,
      port_edge_nodes,
      node_order,
      reverse_ties,
    )
  }
  let _ = edge_order
  let mut i = 1
  while i < sorted.length() {
    let current = sorted[i]
    let current_key = position_key(current, desired, x_positions)
    let mut j = i
    let current_degree = match primary.get(current) {
      Some(list) => list.length()
      None => 0
    }
    let current_secondary = match secondary.get(current) {
      Some(list) => list.length()
      None => 0
    }
    let current_penalty = match node_penalty.get(current) {
      Some(value) => value
      None => 0
    }
    while j > 0 {
      let prev = sorted[j - 1]
      let prev_has_desired = desired.get(prev) is Some(_)
      let current_has_desired = desired.get(current) is Some(_)
      if !prev_has_desired || !current_has_desired {
        break
      }
      let prev_key = position_key(prev, desired, x_positions)
      let diff = prev_key - current_key
      if diff < -0.000001 {
        break
      }
      if Double::abs(diff) <= 0.000001 {
        match port_order_positions.get(prev) {
          Some(prev_port) =>
            match port_order_positions.get(current) {
              Some(current_port) =>
                if prev_port != current_port {
                  if prev_port <= current_port {
                    break
                  }
                }
              None => ()
            }
          None => ()
        }
        let prev_vnode = is_edge_vnode_name(prev)
        let current_vnode = is_edge_vnode_name(current)
        if prev_vnode != current_vnode {
          if prev_vnode {
            break
          }
        }
        let prev_degree = match primary.get(prev) {
          Some(list) => list.length()
          None => 0
        }
        if prev_degree < current_degree {
          // move current left
        } else if prev_degree > current_degree {
          break
        } else {
          let prev_ported = port_edge_nodes.get(prev) is Some(_)
          let current_ported = port_edge_nodes.get(current) is Some(_)
          if prev_ported != current_ported {
            if !current_ported {
              break
            }
          } else {
            let prev_secondary = match secondary.get(prev) {
              Some(list) => list.length()
              None => 0
            }
            if prev_secondary < current_secondary {
              // move current left
            } else if prev_secondary > current_secondary {
              break
            } else {
              let prev_penalty = match node_penalty.get(prev) {
                Some(value) => value
                None => 0
              }
              if prev_penalty < current_penalty {
                // move current left
              } else if prev_penalty > current_penalty {
                break
              } else {
              let mut decided = false
              if prev_ported && current_ported {
                let prev_idx = match node_order.get(prev) {
                  Some(value) => value
                  None => 0
                }
                let current_idx = match node_order.get(current) {
                  Some(value) => value
                  None => 0
                }
                decided = true
                let keep_order =
                  if reverse_ties { prev_idx >= current_idx } else { prev_idx <= current_idx }
                if keep_order {
                  break
                }
              }
              if !decided {
                match rank_same_groups.get(prev) {
                  Some(prev_group) =>
                    match rank_same_groups.get(current) {
                      Some(current_group) =>
                        if prev_group == current_group {
                          let prev_idx = match rank_same_order.get(prev) {
                            Some(value) => value
                            None => 0
                          }
                          let current_idx = match rank_same_order.get(current) {
                            Some(value) => value
                            None => 0
                          }
                          decided = true
                          let keep_order = prev_idx <= current_idx
                          if keep_order {
                            break
                          }
                        }
                      None => ()
                    }
                  None => ()
                }
              }
              if !decided {
                let prev_parents = match parents_map.get(prev) {
                  Some(list) => list
                  None => []
                }
                let current_parents = match parents_map.get(current) {
                  Some(list) => list
                  None => []
                }
                for parent in prev_parents {
                  let mut shared = false
                  for candidate in current_parents {
                    if candidate == parent {
                      shared = true
                      break
                    }
                  }
                  if !shared {
                    continue
                  }
                  let prev_key = "\{parent}|\{prev}"
                  let current_key = "\{parent}|\{current}"
                  match edge_pair_order.get(prev_key) {
                    Some(prev_idx) =>
                      match edge_pair_order.get(current_key) {
                        Some(current_idx) => {
                          decided = true
                          let keep_order =
                            if reverse_ties {
                              prev_idx >= current_idx
                            } else {
                              prev_idx <= current_idx
                            }
                          if keep_order {
                            break
                          }
                        }
                        None => ()
                      }
                    None => ()
                  }
                  if decided {
                    break
                  }
                }
              }
              if !decided {
                if !reverse_ties {
                  break
                }
              }
              }
            }
          }
        }
      }
      sorted[j] = prev
      j = j - 1
    }
    sorted[j] = current
    i = i + 1
  }
  sorted
}

///|
fn median_value(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    return None
  }
  let sorted = values.copy()
  sorted.sort()
  let mid = sorted.length() / 2
  if sorted.length() % 2 == 0 {
    Some((sorted[mid - 1] + sorted[mid]) / 2.0)
  } else {
    Some(sorted[mid])
  }
}

///|
fn median_value_graphviz(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    return None
  }
  let sorted = values.copy()
  sorted.sort()
  if sorted.length() == 1 {
    return Some(sorted[0])
  }
  if sorted.length() == 2 {
    return Some((sorted[0] + sorted[1]) / 2.0)
  }
  let mid = sorted.length() / 2
  if sorted.length() % 2 == 1 {
    return Some(sorted[mid])
  }
  let rm = mid
  let lm = rm - 1
  let rspan = sorted[sorted.length() - 1] - sorted[rm]
  let lspan = sorted[lm] - sorted[0]
  if lspan == rspan {
    Some((sorted[lm] + sorted[rm]) / 2.0)
  } else {
    let weighted = sorted[lm] * rspan + sorted[rm] * lspan
    Some(weighted / (lspan + rspan))
  }
}

///|
///|
fn collect_edge_order(edges : Array[@cgraph.Edge]) -> Map[String, Int] {
  let order : Map[String, Int] = Map::new()
  let mut idx = 0
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    if order.get(tail) is None {
      order[tail] = idx
    }
    if order.get(head) is None {
      order[head] = idx
    }
    idx = idx + 1
  }
  order
}

///|
fn order_rank_by_cluster(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  parents_map : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  edge_pair_order : Map[String, Int],
  port_order_positions : Map[String, Double],
  reverse_ties : Bool,
) -> Array[String] {
  if names.length() < 2 {
    return names.copy()
  }
  let group_keys : Array[String] = []
  let group_nodes : Array[Array[String]] = []
  let group_order : Array[Int] = []
  let group_index : Map[String, Int] = Map::new()
  let mut next_index = 0
  for name in names {
    let cluster_key = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    let group_key = if cluster_key == "" { name } else { cluster_key }
    let idx = match group_index.get(group_key) {
      Some(value) => value
      None => {
        let index = next_index
        next_index = next_index + 1
        group_index[group_key] = index
        group_keys.push(group_key)
        group_nodes.push([])
        group_order.push(index)
        index
      }
    }
    group_nodes[idx].push(name)
  }
  let group_values : Array[Double] = []
  let group_secondary : Array[Int] = []
  for i in 0..<group_nodes.length() {
    let values : Array[Double] = []
    let mut secondary_total = 0
    for name in group_nodes[i] {
      match desired.get(name) {
        Some(value) => values.push(value)
        None =>
          match x_positions.get(name) {
            Some(value) => values.push(value)
            None => ()
          }
      }
      match secondary.get(name) {
        Some(list) => secondary_total = secondary_total + list.length()
        None => ()
      }
    }
    let value = match median_value(values) {
      Some(val) => val
      None => 0.0
    }
    group_values.push(value)
    group_secondary.push(secondary_total)
  }
  let order : Array[Int] = []
  for i in 0..<group_nodes.length() {
    order.push(i)
  }
  let mut i = 1
  while i < order.length() {
    let current = order[i]
    let current_val = group_values[current]
    let mut j = i
    while j > 0 {
      let prev = order[j - 1]
      let prev_val = group_values[prev]
      if prev_val < current_val {
        break
      }
      if prev_val == current_val {
        let prev_secondary = group_secondary[prev]
        let current_secondary = group_secondary[current]
        if prev_secondary < current_secondary {
          // move current left
        } else if prev_secondary > current_secondary {
          break
        } else {
          let keep_order =
            if reverse_ties {
              group_order[prev] >= group_order[current]
            } else {
              group_order[prev] <= group_order[current]
            }
          if keep_order {
            break
          }
        }
      }
      order[j] = prev
      j = j - 1
    }
    order[j] = current
    i = i + 1
  }
  let result : Array[String] = []
  for idx in order {
    let group = group_nodes[idx]
    let ordered_group = sort_by_positions(
      group, desired, x_positions, primary, secondary, node_penalty, parents_map,
      rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
      edge_pair_order, port_order_positions,
      reverse_ties,
    )
    for name in ordered_group {
      result.push(name)
    }
  }
  result
}

///|
fn left2right_constraint(
  left : String,
  right : String,
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
) -> Bool {
  let left_cluster = match cluster_keys.get(left) {
    Some(value) => value
    None => ""
  }
  let right_cluster = match cluster_keys.get(right) {
    Some(value) => value
    None => ""
  }
  if left_cluster != "" && right_cluster != "" && left_cluster != right_cluster {
    let left_skel = cluster_skeleton.get(left) == Some(true)
    let right_skel = cluster_skeleton.get(right) == Some(true)
    if !left_skel && !right_skel {
      return true
    }
  }
  let key = "\{left}|\{right}"
  flat_constraints.get(key) == Some(true)
}

///|
fn reorder_by_medians(
  names : Array[String],
  desired : Map[String, Double],
  reverse : Bool,
  hasfixed : Bool,
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
) -> Array[String] {
  let sorted = names.copy()
  if sorted.length() < 2 {
    return sorted
  }
  let mut ep = sorted.length()
  let mut nelt = sorted.length() - 1
  while nelt >= 0 {
    let mut lp = 0
    while lp < ep {
      while lp < ep && desired.get(sorted[lp]) is None {
        lp = lp + 1
      }
      if lp >= ep {
        break
      }
      let mut rp = lp + 1
      let mut muststay = false
      let mut sawclust = false
      while rp < ep {
        let mut rp_cluster = ""
        match cluster_keys.get(sorted[rp]) {
          Some(value) => rp_cluster = value
          None => ()
        }
        if sawclust && rp_cluster != "" {
          rp = rp + 1
          continue
        }
        if left2right_constraint(
          sorted[lp],
          sorted[rp],
          cluster_keys,
          cluster_skeleton,
          flat_constraints,
        ) {
          muststay = true
          break
        }
        if desired.get(sorted[rp]) is Some(_) {
          break
        }
        if rp_cluster != "" {
          sawclust = true
        }
        rp = rp + 1
      }
      if rp >= ep {
        break
      }
      if !muststay {
        let p1 = match desired.get(sorted[lp]) {
          Some(value) => value
          None => -1.0
        }
        let p2 = match desired.get(sorted[rp]) {
          Some(value) => value
          None => -1.0
        }
        if p1 > p2 || (p1 >= p2 && reverse) {
          let tmp = sorted[lp]
          sorted[lp] = sorted[rp]
          sorted[rp] = tmp
        }
      }
      lp = rp
    }
    if !hasfixed && !reverse {
      ep = ep - 1
    }
    nelt = nelt - 1
  }
  sorted
}

///|
fn compute_desired_positions(
  names : Array[String],
  neighbors : Map[String, Array[String]],
  x_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
) -> Map[String, Double] {
  let desired : Map[String, Double] = Map::new()
  for name in names {
    match preferred_positions.get(name) {
      Some(value) => {
        desired[name] = value
        continue
      }
      None => ()
    }
    match port_order_contrib.get(name) {
      Some(list) => {
        let mut sum = 0.0
        let mut count = 0
        for entry in list {
          let (anchor, offset) = entry
          match x_positions.get(anchor) {
            Some(anchor_pos) => {
              sum = sum + anchor_pos + offset
              count = count + 1
            }
            None => ()
          }
        }
        if count > 0 {
          desired[name] = sum / count.to_double()
          continue
        }
      }
      None => ()
    }
    let list = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    let values : Array[Double] = []
    for neighbor in list {
      match x_positions.get(neighbor) {
        Some(value) => values.push(value)
        None => ()
      }
    }
    match median_value(values) {
      Some(value) => desired[name] = value
      None => ()
    }
  }
  desired
}

///|
fn compute_desired_positions_graphviz(
  names : Array[String],
  neighbors : Map[String, Array[String]],
  x_positions : Map[String, Double],
) -> Map[String, Double] {
  let desired : Map[String, Double] = Map::new()
  for name in names {
    let list = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    let values : Array[Double] = []
    for neighbor in list {
      match x_positions.get(neighbor) {
        Some(value) => values.push(value)
        None => ()
      }
    }
    match median_value_graphviz(values) {
      Some(value) => desired[name] = value
      None => ()
    }
  }
  desired
}

///|
fn compute_desired_positions_with_rank_fallback(
  names : Array[String],
  children : Map[String, Array[String]],
  parents : Map[String, Array[String]],
  x_positions : Map[String, Double],
  ranks : Map[String, Int],
  rank_sizes : Map[Int, Int],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
) -> Map[String, Double] {
  let desired : Map[String, Double] = Map::new()
  for name in names {
    match preferred_positions.get(name) {
      Some(value) => {
        desired[name] = value
        continue
      }
      None => ()
    }
    match port_order_contrib.get(name) {
      Some(list) => {
        let mut sum = 0.0
        let mut count = 0
        for entry in list {
          let (anchor, offset) = entry
          match x_positions.get(anchor) {
            Some(anchor_pos) => {
              sum = sum + anchor_pos + offset
              count = count + 1
            }
            None => ()
          }
        }
        if count > 0 {
          desired[name] = sum / count.to_double()
          continue
        }
      }
      None => ()
    }
    let child_list = match children.get(name) {
      Some(value) => value
      None => []
    }
    let mut use_children = false
    for child in child_list {
      match ranks.get(child) {
        Some(rank) =>
          match rank_sizes.get(rank) {
            Some(size) =>
              if size > 1 {
                use_children = true
                break
              }
            None => ()
          }
        None => ()
      }
    }
    let primary = if use_children { children } else { parents }
    let fallback = if use_children { parents } else { children }
    let list = match primary.get(name) {
      Some(value) => value
      None => []
    }
    let values : Array[Double] = []
    for neighbor in list {
      match x_positions.get(neighbor) {
        Some(value) => values.push(value)
        None => ()
      }
    }
    match median_value(values) {
      Some(value) => desired[name] = value
      None => ()
    }
    if desired.get(name) is None {
      let fallback_list = match fallback.get(name) {
        Some(value) => value
        None => []
      }
      let fallback_values : Array[Double] = []
      for neighbor in fallback_list {
        match x_positions.get(neighbor) {
          Some(value) => fallback_values.push(value)
          None => ()
        }
      }
      match median_value(fallback_values) {
        Some(value) => desired[name] = value
        None => ()
      }
    }
  }
  desired
}

///|

///|
fn node_left_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.left_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

///|
fn node_right_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.right_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

///|
fn adjust_intercluster_alignment(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  x_positions : Map[String, Double],
  cluster_keys : Map[String, String],
  intercluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Unit {
  let cluster_rank_nodes : Map[String, Array[String]] = Map::new()
  let cluster_rank_value : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
      Some(value) => value
      None => continue
    }
    let key = cluster_rank_key(cluster, rank)
    cluster_rank_value[key] = rank
    match cluster_rank_nodes.get(key) {
      Some(list) => list.push(name)
      None => cluster_rank_nodes[key] = [name]
    }
  }
  let cluster_rank_targets : Map[String, Map[String, Bool]] = Map::new()
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_cluster = match intercluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match intercluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if tail_cluster == "" || tail_cluster == head_cluster {
      continue
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let key = cluster_rank_key(tail_cluster, tail_rank)
    match cluster_rank_targets.get(key) {
      Some(targets) => targets[head] = true
      None => {
        let targets : Map[String, Bool] = Map::new()
        targets[head] = true
        cluster_rank_targets[key] = targets
      }
    }
  }
  let eps = 0.01
  for key, names in cluster_rank_nodes {
    if names.length() < 2 {
      continue
    }
    let targets = match cluster_rank_targets.get(key) {
      Some(value) => value
      None => continue
    }
    if targets.length() != 1 {
      continue
    }
    let mut target_name = ""
    for name, _ in targets {
      target_name = name
      break
    }
    let target_x = match x_positions.get(target_name) {
      Some(value) => value
      None => continue
    }
    let mut aligned = false
    for name in names {
      match x_positions.get(name) {
        Some(value) =>
          if Double::abs(value - target_x) <= eps {
            aligned = true
            break
          }
        None => ()
      }
    }
    if !aligned {
      continue
    }
    let rank = match cluster_rank_value.get(key) {
      Some(value) => value
      None => continue
    }
    let shift = rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
    for name in names {
      match x_positions.get(name) {
        Some(value) => x_positions[name] = value - shift
        None => ()
      }
    }
  }
}

///|
fn rank_nodesep_pt(
  rank : Int,
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Double {
  if has_edge_labels && rank % 2 != 0 {
    EDGE_LABEL_NODESEP_PT
  } else {
    nodesep_pt
  }
}

///|
fn compute_rank_positions(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Map[String, Double] {
  let positions : Map[String, Double] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    if names.length() == 0 {
      continue
    }
    let first = names[0]
    positions[first] = 0.0
    let mut current = 0
    let mut prev = first
    let mut i = 1
    let rank_nodesep = rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
    while i < names.length() {
      let name = names[i]
      let tail_right = node_right_pt(prev, sizes)
      let head_left = node_left_pt(name, sizes)
      let width = tail_right + head_left + rank_nodesep
      current = trunc_int(current.to_double() + width)
      positions[name] = current.to_double()
      prev = name
      i = i + 1
    }
  }
  positions
}

///|
fn unique_virtual_node_name(
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
fn build_vnode_order_keys(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  order_index : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> Map[String, Double] {
  let keys : Map[String, Double] = Map::new()
  let mut edge_idx = 0
  for edge in edges {
    let current_idx = edge_idx
    edge_idx = edge_idx + 1
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail = if current_idx < edge_tail.length() { edge_tail[current_idx] } else {
      edge.tail().name()
    }
    let head = if current_idx < edge_head.length() { edge_head[current_idx] } else {
      edge.head().name()
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let tail_order = match order_index.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_order = match order_index.get(head) {
      Some(value) => value
      None => 0
    }
    let (low_rank, high_rank, low_order, high_order) = if tail_rank <= head_rank {
      (tail_rank, head_rank, tail_order, head_order)
    } else {
      (head_rank, tail_rank, head_order, tail_order)
    }
    let span = high_rank - low_rank
    if span <= 0 {
      continue
    }
    let span_f = Double::from_int(span)
    let low_order_f = Double::from_int(low_order)
    let high_order_f = Double::from_int(high_order)
    let same_order = low_order == high_order
    let offset = if same_order { 0.01 } else { 0.0 }
    let reversed =
      if current_idx < edge_reversed.length() { edge_reversed[current_idx] } else { false }
    for vnode in vnodes {
      let vnode_rank = match vnode_ranks.get(vnode) {
        Some(value) => value
        None => continue
      }
      let t = Double::from_int(vnode_rank - low_rank) / span_f
      let base_key =
        if same_order {
          low_order_f - offset + t * offset * 2.0
        } else {
          low_order_f + (high_order_f - low_order_f) * t
        }
      let key = if reversed { base_key + 0.5 } else { base_key }
      keys[vnode] = key
    }
  }
  keys
}

///|
fn vnode_positions_from_endpoints(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  node_positions : Map[String, Double],
  rank_y : Map[Int, Double],
) -> Map[String, @geom.Point] {
  let positions : Map[String, @geom.Point] = Map::new()
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
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let tail_pos = match node_positions.get(tail) {
      Some(value) => value
      None => 0.0
    }
    let head_pos = match node_positions.get(head) {
      Some(value) => value
      None => 0.0
    }
    let (low_rank, high_rank, low_pos, high_pos) = if tail_rank <= head_rank {
      (tail_rank, head_rank, tail_pos, head_pos)
    } else {
      (head_rank, tail_rank, head_pos, tail_pos)
    }
    let span = high_rank - low_rank
    if span <= 0 {
      continue
    }
    let span_f = Double::from_int(span)
    for vnode in vnodes {
      let vnode_rank = match vnode_ranks.get(vnode) {
        Some(value) => value
        None => continue
      }
      let t = Double::from_int(vnode_rank - low_rank) / span_f
      let pos_x = low_pos + (high_pos - low_pos) * t
      let pos_y = match rank_y.get(vnode_rank) {
        Some(value) => value
        None => 0.0
      }
      positions[vnode] = { x: pos_x, y: pos_y }
    }
  }
  positions
}
///|
///|
fn build_edge_vnodes(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  nodesep_pt : Double,
  existing_names : Map[String, Bool],
  edge_cluster_keys : Map[String, String],
) -> EdgeVnodeInfo {
  let vnode_ranks : Map[String, Int] = Map::new()
  let vnode_sizes : Map[String, NodeSize] = Map::new()
  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  let vnode_clusters : Map[String, String] = Map::new()
  let mut edge_index = 0
  let plain_width = 1.0 + nodesep_pt / 2.0
  for edge in edges {
    let key = edge_vnode_key(edge)
    match edge_vnodes.get(key) {
      Some(list) => {
        let delta = nodesep_pt / 2.0
        for name in list {
          match vnode_sizes.get(name) {
            Some(size) =>
              vnode_sizes[name] = vnode_size_from_widths(
                size.left_pt + delta,
                size.right_pt + delta,
              )
            None => ()
          }
        }
        edge_index = edge_index + 1
        continue
      }
      None => ()
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_cluster = node_cluster_key(edge.tail())
    let head_cluster = node_cluster_key(edge.head())
    let edge_cluster = match edge_cluster_keys.get(edge_key(edge)) {
      Some(value) => value
      None => ""
    }
    let use_cluster_plain =
      edge_cluster != "" && tail_cluster == edge_cluster && head_cluster == edge_cluster
    let plain_width_for_edge = if use_cluster_plain { 1.0 } else { plain_width }
    let vnode_cluster =
      if tail_cluster != "" && tail_cluster == head_cluster {
        tail_cluster
      } else if edge_cluster != "" &&
        tail_cluster == edge_cluster &&
        head_cluster == edge_cluster {
        edge_cluster
      } else {
        ""
      }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => {
        edge_index = edge_index + 1
        continue
      }
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => {
        edge_index = edge_index + 1
        continue
      }
    }
    let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    if max_rank - min_rank <= 1 {
      edge_index = edge_index + 1
      continue
    }
    let label_width = edge_mid_label_width_pt(edge)
    let label_rank = if label_width > 0.0 {
      (min_rank + max_rank) / 2
    } else {
      -1
    }
    let names : Array[String] = []
    let mut rank = min_rank + 1
    while rank < max_rank {
      let (left_pt, right_pt) =
        if rank == label_rank && label_width > 0.0 {
          (nodesep_pt, label_width)
        } else {
          (plain_width_for_edge, plain_width_for_edge)
        }
      let name = unique_virtual_node_name(
        EDGE_VNODE_PREFIX,
        edge_index,
        rank,
        existing_names,
      )
      vnode_ranks[name] = rank
      vnode_sizes[name] = vnode_size_from_widths(left_pt, right_pt)
      vnode_clusters[name] = vnode_cluster
      match vnodes_by_rank.get(rank) {
        Some(list) => list.push(name)
        None => vnodes_by_rank[rank] = [name]
      }
      names.push(name)
      rank = rank + 1
    }
    if names.length() > 0 {
      match edge_vnodes.get(key) {
        Some(list) =>
          for name in names {
            list.push(name)
          }
        None => edge_vnodes[key] = names
      }
    }
    edge_index = edge_index + 1
  }
  { vnode_ranks, vnode_sizes, vnodes_by_rank, edge_vnodes, vnode_clusters }
}

///|
///|
fn build_node_singletons(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> Map[String, Bool] {
  let counts : Map[String, Int] = Map::new()
  for node in nodes {
    counts[node.name()] = 0
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_count = match counts.get(tail) {
      Some(value) => value
      None => 0
    }
    counts[tail] = tail_count + 1
    let head_count = match counts.get(head) {
      Some(value) => value
      None => 0
    }
    counts[head] = head_count + 1
  }
  let singletons : Map[String, Bool] = Map::new()
  for name, count in counts {
    if count <= 1 {
      singletons[name] = true
    }
  }
  singletons
}

///|
fn virtual_endpoint_class(
  name : String,
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
) -> Int {
  if vnode_ranks.get(name) is Some(_) {
    2
  } else if node_singletons.get(name) is Some(_) {
    1
  } else {
    0
  }
}

///|
fn virtual_weight_scale(
  tail : String,
  head : String,
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
) -> Int {
  let tail_class = virtual_endpoint_class(tail, vnode_ranks, node_singletons)
  let head_class = virtual_endpoint_class(head, vnode_ranks, node_singletons)
  if tail_class == 0 {
    1
  } else if tail_class == 1 {
    if head_class == 0 { 1 } else { 2 }
  } else {
    if head_class == 2 {
      4
    } else if head_class == 1 {
      2
    } else {
      1
    }
  }
}

///|
fn edge_port_name(port : @cgraph.Port?) -> String? {
  match port {
    Some(value) => value.name
    None => None
  }
}

///|
fn endpoint_port_name(
  node_name : String,
  tail_name : String,
  head_name : String,
  tail_port : String?,
  head_port : String?,
) -> String? {
  if node_name == tail_name {
    tail_port
  } else if node_name == head_name {
    head_port
  } else {
    None
  }
}

///|
fn build_virtual_slack_edges(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
  cluster_keys : Map[String, String],
) -> Array[ConstraintEdge] {
  let extra : Array[ConstraintEdge] = []
  let mut edge_idx = 0
  for edge in edges {
    let current_idx = edge_idx
    edge_idx = edge_idx + 1
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail = if current_idx < edge_tail.length() { edge_tail[current_idx] } else {
      edge.tail().name()
    }
    let head = if current_idx < edge_head.length() { edge_head[current_idx] } else {
      edge.head().name()
    }
    let orig_tail = edge.tail().name()
    let orig_head = edge.head().name()
    let tail_port_name =
      if tail == orig_tail {
      edge_port_name(edge.tail_port())
    } else {
      edge_port_name(edge.head_port())
    }
    let head_port_name =
      if head == orig_head {
      edge_port_name(edge.head_port())
    } else {
      edge_port_name(edge.tail_port())
    }
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let low = if tail_rank <= head_rank { tail } else { head }
    let high = if tail_rank <= head_rank { head } else { tail }
    let base_weight = edge_weight(edge)
    let reversed = current_idx < edge_reversed.length() && edge_reversed[current_idx]
    let mut prev = low
    for vnode in vnodes {
      let scale = virtual_weight_scale(prev, vnode, vnode_ranks, node_singletons)
      let tail_port = endpoint_port_name(
        prev,
        tail,
        head,
        tail_port_name,
        head_port_name,
      )
      let head_port = endpoint_port_name(
        vnode,
        tail,
        head,
        tail_port_name,
        head_port_name,
      )
      let mut weight = base_weight * scale
      if vnode_ranks.get(prev) is None && vnode_ranks.get(vnode) is Some(_) {
        weight = weight * VNODE_ENDPOINT_WEIGHT
        if reversed {
          weight = weight * BACKWARD_PENALTY
        }
      }
      extra.push({
        tail: prev,
        head: vnode,
        minlen: 1,
        weight,
        tail_port,
        head_port,
      })
      prev = vnode
    }
    let scale = virtual_weight_scale(prev, high, vnode_ranks, node_singletons)
    let tail_port = endpoint_port_name(
      prev,
      tail,
      head,
      tail_port_name,
      head_port_name,
    )
    let head_port = endpoint_port_name(
      high,
      tail,
      head,
      tail_port_name,
      head_port_name,
    )
    let mut weight = base_weight * scale
    if vnode_ranks.get(prev) is Some(_) && vnode_ranks.get(high) is None {
      weight = weight * VNODE_ENDPOINT_WEIGHT
      if reversed {
        weight = weight * BACKWARD_PENALTY
      }
    }
    extra.push({
      tail: prev,
      head: high,
      minlen: 1,
      weight,
      tail_port,
      head_port,
    })
  }
  extra
}

///|
fn merge_sizes_with_vnodes(
  sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
) -> Map[String, NodeSize] {
  let merged : Map[String, NodeSize] = Map::new()
  for name, size in sizes {
    merged[name] = size
  }
  for name, size in vnode_sizes {
    merged[name] = size
  }
  merged
}

///|
fn sort_rank_items(items : Array[(Double, Int, String)]) -> Array[String] {
  let sorted = items.copy()
  if sorted.length() > 1 {
    let eps = 0.000001
    sorted.sort_by((a, b) => {
      let (a_key, a_tie, _a_name) = a
      let (b_key, b_tie, _b_name) = b
      let diff = a_key - b_key
      if Double::abs(diff) <= eps {
        if a_tie < b_tie {
          -1
        } else if a_tie > b_tie {
          1
        } else {
          0
        }
      } else if diff < 0.0 {
        -1
      } else {
        1
      }
    })
  }
  let names : Array[String] = []
  for item in sorted {
    let (_key, _tie, name) = item
    names.push(name)
  }
  names
}

///|
fn build_x_groups_with_vnodes(
  ordered_groups : Map[Int, Array[String]],
  order_index : Map[String, Int],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys : Map[String, Double],
) -> Map[Int, Array[String]] {
  let result : Map[Int, Array[String]] = Map::new()
  let rank_set : Map[Int, Bool] = Map::new()
  for rank, _names in ordered_groups {
    rank_set[rank] = true
  }
  for rank, _names in vnodes_by_rank {
    rank_set[rank] = true
  }
  let ranks : Array[Int] = []
  for rank, _ in rank_set {
    ranks.push(rank)
  }
  ranks.sort()
  for rank in ranks {
    let names = match ordered_groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    let vnodes = match vnodes_by_rank.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    if vnodes.length() == 0 {
      if names.length() > 0 {
        result[rank] = names
      }
      continue
    }
    let items : Array[(Double, Int, String)] = []
    let mut idx = 0
    for name in names {
      let key = match order_index.get(name) {
        Some(value) => value.to_double()
        None => idx.to_double()
      }
      items.push((key, idx, name))
      idx = idx + 1
    }
    let tie_offset = names.length() + 1
    let mut v_idx = 0
    for name in vnodes {
      let key = match vnode_order_keys.get(name) {
        Some(value) => value
        None => 0.0
      }
      items.push((key, tie_offset + v_idx, name))
      v_idx = v_idx + 1
    }
    result[rank] = sort_rank_items(items)
  }
  result
}

///|
fn collect_rank_keys(groups : Map[Int, Array[String]]) -> Array[Int] {
  let keys : Array[Int] = []
  for rank, _ in groups {
    keys.push(rank)
  }
  keys.sort()
  keys
}

///|
fn build_vnode_extra_nodes(
  vnode_ranks : Map[String, Int],
) -> Array[(String, Int)] {
  let extra : Array[(String, Int)] = []
  for name, rank in vnode_ranks {
    extra.push((name, rank))
  }
  extra
}

///|
fn clone_rank_groups(
  groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let cloned : Map[Int, Array[String]] = Map::new()
  for rank, names in groups {
    cloned[rank] = names.copy()
  }
  cloned
}

///|
fn build_node_ranks(groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let ranks : Map[String, Int] = Map::new()
  for rank, names in groups {
    for name in names {
      ranks[name] = rank
    }
  }
  ranks
}

///|
fn build_order_index(groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let order : Map[String, Int] = Map::new()
  for _rank, names in groups {
    for i in 0..<names.length() {
      order[names[i]] = i
    }
  }
  order
}

///|
fn order_positions_from_groups(
  groups : Map[Int, Array[String]],
) -> Map[String, Double] {
  let positions : Map[String, Double] = Map::new()
  for _rank, names in groups {
    for i in 0..<names.length() {
      positions[names[i]] = i.to_double()
    }
  }
  positions
}

///|
fn count_inversions(values : Array[Int]) -> Int {
  let n = values.length()
  if n < 2 {
    return 0
  }
  let mut src = values.copy()
  let mut dst = Array::make(n, 0)
  let mut size = 1
  let mut total = 0
  while size < n {
    let mut i = 0
    while i < n {
      let left = i
      let mid = {
        let next = i + size
        if next < n { next } else { n }
      }
      let right = {
        let next = i + size + size
        if next < n { next } else { n }
      }
      let mut a = left
      let mut b = mid
      let mut k = left
      while a < mid && b < right {
        if src[a] <= src[b] {
          dst[k] = src[a]
          a = a + 1
        } else {
          dst[k] = src[b]
          b = b + 1
          total = total + (mid - a)
        }
        k = k + 1
      }
      while a < mid {
        dst[k] = src[a]
        a = a + 1
        k = k + 1
      }
      while b < right {
        dst[k] = src[b]
        b = b + 1
        k = k + 1
      }
      i = i + size + size
    }
    let tmp = src
    src = dst
    dst = tmp
    size = size + size
  }
  total
}

///|
fn count_crossings(
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Int {
  let order = build_order_index(groups)
  let edge_groups : Map[(Int, Int), Array[(Int, Int)]] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    if !edge_is_constraint(edge) {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    if tail_rank == head_rank {
      continue
    }
    let low_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let high_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    let low_node = if tail_rank < head_rank { tail } else { head }
    let high_node = if tail_rank < head_rank { head } else { tail }
    let low_order = match order.get(low_node) {
      Some(value) => value
      None => continue
    }
    let high_order = match order.get(high_node) {
      Some(value) => value
      None => continue
    }
    let key = (low_rank, high_rank)
    match edge_groups.get(key) {
      Some(list) => list.push((low_order, high_order))
      None => edge_groups[key] = [(low_order, high_order)]
    }
  }
  let mut crossings = 0
  for _key, list in edge_groups {
    if list.length() < 2 {
      continue
    }
    list.sort_by((a, b) => {
      let (a0, a1) = a
      let (b0, b1) = b
      if a0 == b0 { a1 - b1 } else { a0 - b0 }
    })
    let heads : Array[Int] = []
    for pair in list {
      let (_, h) = pair
      heads.push(h)
    }
    crossings = crossings + count_inversions(heads)
  }
  crossings
}

///|
fn count_crossings_graphviz(
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Int {
  let order = build_order_index(groups)
  let rank_keys : Array[Int] = []
  for rank, _ in groups {
    rank_keys.push(rank)
  }
  if rank_keys.length() == 0 {
    return 0
  }
  rank_keys.sort()
  let edge_out : Map[String, Array[Int]] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      edge_out[name] = []
    }
  }
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    if !edge_is_constraint(edge) {
      continue
    }
    if edge_xpenalty(edge) <= 0 {
      continue
    }
    let tail = edge_tail[edge_idx]
    match edge_out.get(tail) {
      Some(list) => list.push(edge_idx)
      None => edge_out[tail] = [edge_idx]
    }
  }
  let mut crossings = 0
  let mut idx = 0
  while idx + 1 < rank_keys.length() {
    let rank = rank_keys[idx]
    let next_rank = rank_keys[idx + 1]
    let top_nodes = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let next_nodes = match groups.get(next_rank) {
      Some(list) => list
      None => []
    }
    let count = Array::make(next_nodes.length() + 1, 0)
    let mut max_order = 0
    for top in top_nodes {
      let outs = match edge_out.get(top) {
        Some(list) => list
        None => []
      }
      if max_order > 0 {
        for edge_idx in outs {
          let head = edge_head[edge_idx]
          if ranks.get(head) != Some(next_rank) {
            continue
          }
          let inv = match order.get(head) {
            Some(value) => value
            None => continue
          }
          let penalty = edge_xpenalty(edges[edge_idx])
          if penalty <= 0 {
            continue
          }
          let mut k = inv + 1
          while k <= max_order {
            crossings = crossings + count[k] * penalty
            k = k + 1
          }
        }
      }
      for edge_idx in outs {
        let head = edge_head[edge_idx]
        if ranks.get(head) != Some(next_rank) {
          continue
        }
        let inv = match order.get(head) {
          Some(value) => value
          None => continue
        }
        let penalty = edge_xpenalty(edges[edge_idx])
        if penalty <= 0 {
          continue
        }
        if inv > max_order {
          max_order = inv
        }
        count[inv] = count[inv] + penalty
      }
    }
    idx = idx + 1
  }
  crossings
}

///|
fn count_pairs_greater(left : Array[Int], right : Array[Int]) -> Int {
  if left.length() == 0 || right.length() == 0 {
    return 0
  }
  let mut count = 0
  let mut j = 0
  for i in 0..<left.length() {
    let l = left[i]
    while j < right.length() && right[j] < l {
      j = j + 1
    }
    count = count + j
  }
  count
}

///|
fn build_neighbor_order_index(
  names : Array[String],
  neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order : Map[String, Int],
  target_rank : Int,
) -> Map[String, Array[Int]] {
  let result : Map[String, Array[Int]] = Map::new()
  for name in names {
    let orders : Array[Int] = []
    let list = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    for neighbor in list {
      if ranks.get(neighbor) != Some(target_rank) {
        continue
      }
      match order.get(neighbor) {
        Some(idx) => orders.push(idx)
        None => ()
      }
    }
    if orders.length() > 1 {
      orders.sort()
    }
    result[name] = orders
  }
  result
}

///|
fn crossing_for_pair(
  left : String,
  right : String,
  parent_orders : Map[String, Array[Int]],
  child_orders : Map[String, Array[Int]],
) -> Int {
  let left_parents = match parent_orders.get(left) {
    Some(value) => value
    None => []
  }
  let right_parents = match parent_orders.get(right) {
    Some(value) => value
    None => []
  }
  let left_children = match child_orders.get(left) {
    Some(value) => value
    None => []
  }
  let right_children = match child_orders.get(right) {
    Some(value) => value
    None => []
  }
  count_pairs_greater(left_parents, right_parents) +
    count_pairs_greater(left_children, right_children)
}

///|
fn transpose_rank(
  rank : Int,
  names : Array[String],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  ranks : Map[String, Int],
  order : Map[String, Int],
  reverse : Bool,
) -> Bool {
  let mut changed = false
  let parent_orders =
    build_neighbor_order_index(names, parents, ranks, order, rank - 1)
  let child_orders =
    build_neighbor_order_index(names, children, ranks, order, rank + 1)
  let mut i = 0
  while i + 1 < names.length() {
    let left = names[i]
    let right = names[i + 1]
    let c0 = crossing_for_pair(
      left, right, parent_orders, child_orders,
    )
    let c1 = crossing_for_pair(
      right, left, parent_orders, child_orders,
    )
    if c1 < c0 || (reverse && c1 == c0 && c0 > 0) {
      names[i] = right
      names[i + 1] = left
      order[left] = i + 1
      order[right] = i
      changed = true
    }
    i = i + 1
  }
  changed
}

///|
fn transpose_rank_groups_limited(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  ranks : Map[String, Int],
  reverse : Bool,
  max_passes : Int,
) -> Bool {
  let mut changed_any = false
  let mut changed = true
  let mut passes = 0
  while changed {
    if passes >= max_passes {
      break
    }
    passes = passes + 1
    changed = false
    let order = build_order_index(ordered)
    for rank in rank_keys {
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      if names.length() < 2 {
        continue
      }
      if transpose_rank(rank, names, parents, children, ranks, order, reverse) {
        ordered[rank] = names
        changed = true
        changed_any = true
      }
    }
  }
  changed_any
}

///|
fn in_cross_graphviz(
  left : String,
  right : String,
  rank : Int,
  ranks : Map[String, Int],
  order : Map[String, Int],
  edge_in : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_penalty : Array[Int],
) -> Int {
  let right_in = match edge_in.get(right) {
    Some(value) => value
    None => []
  }
  let left_in = match edge_in.get(left) {
    Some(value) => value
    None => []
  }
  let mut cross = 0
  for edge_idx in right_in {
    let cnt = edge_penalty[edge_idx]
    if cnt <= 0 {
      continue
    }
    let tail_rank = match ranks.get(edge_tail[edge_idx]) {
      Some(value) => value
      None => rank - 1
    }
    if tail_rank != rank - 1 {
      continue
    }
    let inv = match order.get(edge_tail[edge_idx]) {
      Some(value) => value
      None => 0
    }
    for edge_idx2 in left_in {
      let weight = edge_penalty[edge_idx2]
      if weight <= 0 {
        continue
      }
      let tail_rank2 = match ranks.get(edge_tail[edge_idx2]) {
        Some(value) => value
        None => rank - 1
      }
      if tail_rank2 != rank - 1 {
        continue
      }
      let tail_order = match order.get(edge_tail[edge_idx2]) {
        Some(value) => value
        None => 0
      }
      let t = tail_order - inv
      if t > 0 {
        cross = cross + weight * cnt
      }
    }
  }
  cross
}

///|
fn out_cross_graphviz(
  left : String,
  right : String,
  rank : Int,
  ranks : Map[String, Int],
  order : Map[String, Int],
  edge_out : Map[String, Array[Int]],
  edge_head : Array[String],
  edge_penalty : Array[Int],
) -> Int {
  let right_out = match edge_out.get(right) {
    Some(value) => value
    None => []
  }
  let left_out = match edge_out.get(left) {
    Some(value) => value
    None => []
  }
  let mut cross = 0
  for edge_idx in right_out {
    let cnt = edge_penalty[edge_idx]
    if cnt <= 0 {
      continue
    }
    let head_rank = match ranks.get(edge_head[edge_idx]) {
      Some(value) => value
      None => rank + 1
    }
    if head_rank != rank + 1 {
      continue
    }
    let inv = match order.get(edge_head[edge_idx]) {
      Some(value) => value
      None => 0
    }
    for edge_idx2 in left_out {
      let weight = edge_penalty[edge_idx2]
      if weight <= 0 {
        continue
      }
      let head_rank2 = match ranks.get(edge_head[edge_idx2]) {
        Some(value) => value
        None => rank + 1
      }
      if head_rank2 != rank + 1 {
        continue
      }
      let head_order = match order.get(edge_head[edge_idx2]) {
        Some(value) => value
        None => 0
      }
      let t = head_order - inv
      if t > 0 {
        cross = cross + weight * cnt
      }
    }
  }
  cross
}

///|
fn transpose_rank_graphviz(
  rank : Int,
  ranks : Map[String, Int],
  names : Array[String],
  order : Map[String, Int],
  edge_in : Map[String, Array[Int]],
  edge_out : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_penalty : Array[Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  reverse : Bool,
) -> (Int, Bool) {
  let mut changed = false
  let mut delta = 0
  let mut i = 0
  while i + 1 < names.length() {
    let left = names[i]
    let right = names[i + 1]
    if left2right_constraint(
      left,
      right,
      cluster_keys,
      cluster_skeleton,
      flat_constraints,
    ) {
      i = i + 1
      continue
    }
    let mut c0 = 0
    let mut c1 = 0
    c0 = c0 + in_cross_graphviz(
      left, right, rank, ranks, order, edge_in, edge_tail, edge_penalty,
    )
    c1 = c1 + in_cross_graphviz(
      right, left, rank, ranks, order, edge_in, edge_tail, edge_penalty,
    )
    c0 = c0 + out_cross_graphviz(
      left, right, rank, ranks, order, edge_out, edge_head, edge_penalty,
    )
    c1 = c1 + out_cross_graphviz(
      right, left, rank, ranks, order, edge_out, edge_head, edge_penalty,
    )
    if c1 < c0 || (reverse && c1 == c0 && c0 > 0) {
      names[i] = right
      names[i + 1] = left
      order[left] = i + 1
      order[right] = i
      changed = true
      delta = delta + (c0 - c1)
    }
    i = i + 1
  }
  (delta, changed)
}

///|
fn transpose_rank_groups_graphviz(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edge_in : Map[String, Array[Int]],
  edge_out : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_penalty : Array[Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  reverse : Bool,
  max_passes : Int,
) -> Bool {
  let mut changed_any = false
  let mut passes = 0
  let rank_len = rank_keys.length()
  let candidate = Array::make(rank_len, true)
  while true {
    if max_passes > 0 && passes >= max_passes {
      break
    }
    passes = passes + 1
    let order = build_order_index(ordered)
    let mut delta = 0
    let mut idx = 0
    while idx < rank_len {
      if !candidate[idx] {
        idx = idx + 1
        continue
      }
      candidate[idx] = false
      let rank = rank_keys[idx]
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      if names.length() < 2 {
        idx = idx + 1
        continue
      }
      let (rank_delta, changed) = transpose_rank_graphviz(
        rank,
        ranks,
        names,
        order,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        reverse,
      )
      if changed {
        ordered[rank] = names
        changed_any = true
        candidate[idx] = true
        if idx > 0 {
          candidate[idx - 1] = true
        }
        if idx + 1 < rank_len {
          candidate[idx + 1] = true
        }
      }
      delta = delta + rank_delta
      idx = idx + 1
    }
    if delta < 1 {
      break
    }
  }
  changed_any
}

///|
fn build_rank_groups_graphviz(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  pass : Int,
) -> Map[Int, Array[String]] {
  let ordered : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    ordered[rank] = []
  }
  let nodes : Array[String] = []
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      nodes.push(name)
    }
  }
  let fallback_order : Map[String, Int] = Map::new()
  for i, name in nodes {
    fallback_order[name] = i
  }
  let nlist = nodes.copy()
  if nlist.length() > 1 {
    nlist.sort_by((a, b) => {
      let a_idx = match node_order.get(a) {
        Some(value) => value
        None =>
          match fallback_order.get(a) {
            Some(value) => value
            None => 0
          }
      }
      let b_idx = match node_order.get(b) {
        Some(value) => value
        None =>
          match fallback_order.get(b) {
            Some(value) => value
            None => 0
          }
      }
      if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else {
        0
      }
    })
  }
  let out_neighbors : Map[String, Array[String]] = Map::new()
  let in_neighbors : Map[String, Array[String]] = Map::new()
  for name in nlist {
    out_neighbors[name] = []
    in_neighbors[name] = []
  }
  for edge_idx in 0..<edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    match out_neighbors.get(tail) {
      Some(list) => list.push(head)
      None => out_neighbors[tail] = [head]
    }
    match in_neighbors.get(head) {
      Some(list) => list.push(tail)
      None => in_neighbors[head] = [tail]
    }
  }
  let cluster_nodes : Map[String, Array[String]] = Map::new()
  let cluster_has_skeleton : Map[String, Bool] = Map::new()
  for name in nlist {
    if cluster_skeleton.get(name) == Some(true) {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster != "" {
        cluster_has_skeleton[cluster] = true
      }
    }
  }
  for name in nlist {
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster != "" && cluster_has_skeleton.get(cluster) == Some(true) {
      match cluster_nodes.get(cluster) {
        Some(list) => list.push(name)
        None => cluster_nodes[cluster] = [name]
      }
    }
  }
  for _key, list in cluster_nodes {
    if list.length() > 1 {
      list.sort_by((a, b) => {
        let a_rank = match node_ranks.get(a) {
          Some(value) => value
          None => 0
        }
        let b_rank = match node_ranks.get(b) {
          Some(value) => value
          None => 0
        }
        if a_rank < b_rank {
          -1
        } else if a_rank > b_rank {
          1
        } else {
          let a_idx = match node_order.get(a) {
            Some(value) => value
            None =>
              match fallback_order.get(a) {
                Some(value) => value
                None => 0
              }
          }
          let b_idx = match node_order.get(b) {
            Some(value) => value
            None =>
              match fallback_order.get(b) {
                Some(value) => value
                None => 0
              }
          }
          if a_idx < b_idx {
            -1
          } else if a_idx > b_idx {
            1
          } else {
            0
          }
        }
      })
    }
  }
  let installed : Map[String, Bool] = Map::new()
  let marks : Map[String, Bool] = Map::new()
  let installed_clusters : Map[String, Bool] = Map::new()
  for node in nlist {
    let other =
      if pass == 0 {
        match in_neighbors.get(node) {
          Some(list) => list
          None => []
        }
      } else {
        match out_neighbors.get(node) {
          Some(list) => list
          None => []
        }
      }
    if other.length() > 0 {
      continue
    }
    if marks.get(node) == Some(true) {
      continue
    }
    marks[node] = true
    let queue : Array[String] = [node]
    let mut q_idx = 0
    while q_idx < queue.length() {
      let current = queue[q_idx]
      q_idx = q_idx + 1
      if cluster_skeleton.get(current) == Some(true) {
        let cluster = match cluster_keys.get(current) {
          Some(value) => value
          None => ""
        }
        if cluster != "" && installed_clusters.get(cluster) != Some(true) {
          installed_clusters[cluster] = true
          let cluster_list = match cluster_nodes.get(cluster) {
            Some(list) => list
            None => []
          }
          for cluster_node in cluster_list {
            if installed.get(cluster_node) != Some(true) {
              let rank = match node_ranks.get(cluster_node) {
                Some(value) => value
                None => 0
              }
              match ordered.get(rank) {
                Some(list) => list.push(cluster_node)
                None => ordered[rank] = [cluster_node]
              }
              installed[cluster_node] = true
            }
            marks[cluster_node] = true
          }
          for cluster_node in cluster_list {
            let neighbors =
              if pass == 0 {
                match out_neighbors.get(cluster_node) {
                  Some(list) => list
                  None => []
                }
              } else {
                match in_neighbors.get(cluster_node) {
                  Some(list) => list
                  None => []
                }
              }
            for neighbor in neighbors {
              if marks.get(neighbor) != Some(true) {
                marks[neighbor] = true
                queue.push(neighbor)
              }
            }
          }
        }
        continue
      }
      if installed.get(current) != Some(true) {
        let rank = match node_ranks.get(current) {
          Some(value) => value
          None => 0
        }
        match ordered.get(rank) {
          Some(list) => list.push(current)
          None => ordered[rank] = [current]
        }
        installed[current] = true
      }
      let neighbors =
        if pass == 0 {
          match out_neighbors.get(current) {
            Some(list) => list
            None => []
          }
        } else {
          match in_neighbors.get(current) {
            Some(list) => list
            None => []
          }
        }
      for neighbor in neighbors {
        if marks.get(neighbor) != Some(true) {
          marks[neighbor] = true
          queue.push(neighbor)
        }
      }
    }
  }
  for name in nlist {
    if installed.get(name) != Some(true) {
      let rank = match node_ranks.get(name) {
        Some(value) => value
        None => 0
      }
      match ordered.get(rank) {
        Some(list) => list.push(name)
        None => ordered[rank] = [name]
      }
      installed[name] = true
    }
  }
  ordered
}

///|
fn reorder_rank_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let mut ordered : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    ordered[rank] = names
  }
  let rank_sizes : Map[Int, Int] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    rank_sizes[rank] = names.length()
  }
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = port_is_explicit(edge.tail_port()) ||
      port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  let mut has_ported_nodes = false
  for _name, _ in port_edge_nodes {
    has_ported_nodes = true
    break
  }
  let edge_pair_order : Map[String, Int] = Map::new()
  let mut edge_idx = 0
  for _edge in edges {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    edge_pair_order["\{tail}|\{head}"] = edge_idx
    edge_idx = edge_idx + 1
  }
  let node_penalty : Map[String, Int] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let penalty = edge_xpenalty(edge)
    if penalty <= 0 {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_sum = match node_penalty.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_sum = match node_penalty.get(head) {
      Some(value) => value
      None => 0
    }
    node_penalty[tail] = tail_sum + penalty
    node_penalty[head] = head_sum + penalty
  }
  let node_ranks = build_node_ranks(ordered)
  let mut best_ordered = clone_rank_groups(ordered)
  let mut order_positions = order_positions_from_groups(ordered)
  let mut has_port_order = false
  for _name, _ in port_order_positions {
    has_port_order = true
    break
  }
  let mut has_rank_same = false
  for _name, _ in rank_same_groups {
    has_rank_same = true
    break
  }
  let mut has_preferred = false
  for _name, _ in preferred_positions {
    has_preferred = true
    break
  }
  let mut has_port_contrib = false
  for _name, _ in port_order_contrib {
    has_port_contrib = true
    break
  }
  let graphviz_style = !has_rank_same && !has_port_order && !has_ported_nodes &&
    !has_preferred && !has_port_contrib
  let median_parents : Map[String, Array[String]] = Map::new()
  let median_children : Map[String, Array[String]] = Map::new()
  let edge_penalty : Array[Int] = []
  let edge_in : Map[String, Array[Int]] = Map::new()
  let edge_out : Map[String, Array[Int]] = Map::new()
  for rank in rank_keys {
    let names = match ordered.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      if graphviz_style {
        median_parents[name] = []
        median_children[name] = []
      }
      edge_in[name] = []
      edge_out[name] = []
    }
  }
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let penalty = edge_xpenalty(edge)
    edge_penalty.push(penalty)
    if penalty <= 0 || !edge_is_constraint(edge) {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match node_ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match node_ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    if graphviz_style {
      match median_parents.get(head) {
        Some(list) => list.push(tail)
        None => median_parents[head] = [tail]
      }
      match median_children.get(tail) {
        Some(list) => list.push(head)
        None => median_children[tail] = [head]
      }
    }
    match edge_out.get(tail) {
      Some(list) => list.push(edge_idx)
      None => edge_out[tail] = [edge_idx]
    }
    match edge_in.get(head) {
      Some(list) => list.push(edge_idx)
      None => edge_in[head] = [edge_idx]
    }
  }
  let mut best_cross =
    if graphviz_style {
    count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
  } else {
    count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
  }
  if !graphviz_style && rank_keys.length() > 1 {
    ordered = build_rank_groups_graphviz(
      rank_keys,
      groups,
      edge_tail,
      edge_head,
      node_ranks,
      node_order,
      cluster_keys,
      cluster_skeleton,
      0,
    )
    order_positions = order_positions_from_groups(ordered)
    let seed_cross =
      count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
    if seed_cross > 0 {
      let _ = transpose_rank_groups_graphviz(
        rank_keys,
        ordered,
        node_ranks,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        false,
        0,
      )
      order_positions = order_positions_from_groups(ordered)
    }
    best_ordered = clone_rank_groups(ordered)
    best_cross = count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
  }
  if graphviz_style && rank_keys.length() > 1 {
    let max_iter = 24
    let min_quit = 8
    let convergence = 0.995
    let mut cur_cross = best_cross
    let mut pass = 0
    while pass <= 2 {
      let max_this_pass =
        if pass <= 1 {
        if max_iter < 4 { max_iter } else { 4 }
      } else {
        max_iter
      }
      if pass <= 1 {
        ordered = build_rank_groups_graphviz(
          rank_keys,
          groups,
          edge_tail,
          edge_head,
          node_ranks,
          node_order,
          cluster_keys,
          cluster_skeleton,
          pass,
        )
        order_positions = order_positions_from_groups(ordered)
        if !has_port_order {
          let cross =
            count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
          if cross > 0 {
            let _ = transpose_rank_groups_graphviz(
              rank_keys,
              ordered,
              node_ranks,
              edge_in,
              edge_out,
              edge_tail,
              edge_head,
              edge_penalty,
              cluster_keys,
              cluster_skeleton,
              flat_constraints,
              false,
              0,
            )
            order_positions = order_positions_from_groups(ordered)
          }
        }
        cur_cross =
          count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
        if cur_cross <= best_cross {
          best_cross = cur_cross
          best_ordered = clone_rank_groups(ordered)
        }
      } else {
        if cur_cross > best_cross {
          for rank in rank_keys {
            let names = match best_ordered.get(rank) {
              Some(list) => list.copy()
              None => []
            }
            ordered[rank] = names
          }
          order_positions = order_positions_from_groups(ordered)
        }
        cur_cross = best_cross
      }
      let mut trying = 0
      let mut iter = 0
      while iter < max_this_pass {
        if trying >= min_quit || cur_cross == 0 {
          break
        }
        trying = trying + 1
        let reverse = iter % 4 < 2
        if iter % 2 == 0 {
          let mut idx = 1
          while idx < rank_keys.length() {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = compute_desired_positions_graphviz(
                names,
                median_parents,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
              )
              order_positions = order_positions_from_groups(ordered)
            }
            idx = idx + 1
          }
        } else {
          let mut idx = rank_keys.length() - 2
          while true {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = compute_desired_positions_graphviz(
                names,
                median_children,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
              )
              order_positions = order_positions_from_groups(ordered)
            }
            if idx == 0 {
              break
            }
            idx = idx - 1
          }
        }
        if !has_port_order {
          let _ = transpose_rank_groups_graphviz(
            rank_keys,
            ordered,
            node_ranks,
            edge_in,
            edge_out,
            edge_tail,
            edge_head,
            edge_penalty,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            !reverse,
            0,
          )
          order_positions = order_positions_from_groups(ordered)
        }
        cur_cross =
          count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
        if cur_cross <= best_cross {
          let prev_best = best_cross
          best_cross = cur_cross
          best_ordered = clone_rank_groups(ordered)
          if prev_best > 0 &&
            cur_cross.to_double() < convergence * prev_best.to_double() {
            trying = 0
          }
        }
        iter = iter + 1
      }
      if cur_cross == 0 {
        break
      }
      pass = pass + 1
    }
    if cur_cross > best_cross {
      for rank in rank_keys {
        let names = match best_ordered.get(rank) {
          Some(list) => list.copy()
          None => []
        }
        ordered[rank] = names
      }
      order_positions = order_positions_from_groups(ordered)
    }
    if best_cross > 0 && !has_port_order {
      let _ = transpose_rank_groups_graphviz(
        rank_keys,
        ordered,
        node_ranks,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        false,
        0,
      )
    }
    return clone_rank_groups(ordered)
  }
  if !graphviz_style && rank_keys.length() > 1 {
    let iterations = if rank_keys.length() > 2 { 2 } else { 1 }
    let mut iter = 0
    while iter < iterations {
      let reverse_ties = iter % 2 == 1
      if graphviz_style {
        if iter % 2 == 0 {
          let mut idx = 1
          while idx < rank_keys.length() {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = compute_desired_positions_graphviz(
                names,
                median_parents,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse_ties,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
              )
              order_positions = order_positions_from_groups(ordered)
            }
            idx = idx + 1
          }
        } else {
          let mut idx = rank_keys.length() - 2
          while true {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = compute_desired_positions_graphviz(
                names,
                median_children,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse_ties,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
              )
              order_positions = order_positions_from_groups(ordered)
            }
            if idx == 0 {
              break
            }
            idx = idx - 1
          }
        }
        if !has_port_order {
          let _ = transpose_rank_groups_graphviz(
            rank_keys,
            ordered,
            node_ranks,
            edge_in,
            edge_out,
            edge_tail,
            edge_head,
            edge_penalty,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            !reverse_ties,
            0,
          )
          order_positions = order_positions_from_groups(ordered)
        }
        let cross =
          count_crossings_graphviz(ordered, node_ranks, edges, edge_tail, edge_head)
        if cross <= best_cross {
          best_cross = cross
          best_ordered = clone_rank_groups(ordered)
        }
      } else {
        let mut idx = rank_keys.length() - 1
        while idx > 0 {
          let rank = rank_keys[idx - 1]
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              parents,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, parents, children, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
          }
          idx = idx - 1
        }
        if !has_port_order {
          let _ = transpose_rank_groups_limited(
            rank_keys, ordered, parents, children, node_ranks, true, 2,
          )
        }
        for rank in rank_keys {
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              parents,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, parents, children, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
          }
        }
        let down_cross = count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
        if down_cross < best_cross {
          best_cross = down_cross
          best_ordered = clone_rank_groups(ordered)
        }
        let mut j = 1
        while j < rank_keys.length() {
          let rank = rank_keys[j]
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              children,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, children, parents, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
          }
          j = j + 1
        }
        if !has_port_order {
          let _ = transpose_rank_groups_limited(
            rank_keys, ordered, parents, children, node_ranks, false, 2,
          )
        }
        for rank in rank_keys {
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              children,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, children, parents, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
          }
        }
        let up_cross = count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
        if up_cross < best_cross {
          best_cross = up_cross
          best_ordered = clone_rank_groups(ordered)
        }
      }
      iter = iter + 1
    }
  }
  clone_rank_groups(best_ordered)
}

///|
fn reorder_groups_by_cluster_order(
  groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
  cluster_order_base : Map[String, Int],
) -> Unit {
  let mut has_order = false
  for _name, _ in cluster_order_base {
    has_order = true
    break
  }
  if !has_order {
    return ()
  }
  for _rank, names in groups {
    if names.length() <= 1 {
      continue
    }
    let mut all_cluster = true
    for name in names {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" || cluster_order_base.get(cluster) is None {
        all_cluster = false
        break
      }
    }
    if !all_cluster {
      continue
    }
    let original_index : Map[String, Int] = Map::new()
    for i in 0..<names.length() {
      original_index[names[i]] = i
    }
    names.sort_by((a, b) => {
      let a_cluster = match cluster_keys.get(a) {
        Some(value) => value
        None => ""
      }
      let b_cluster = match cluster_keys.get(b) {
        Some(value) => value
        None => ""
      }
      let a_order = match cluster_order_base.get(a_cluster) {
        Some(value) => value
        None => 0
      }
      let b_order = match cluster_order_base.get(b_cluster) {
        Some(value) => value
        None => 0
      }
      if a_order < b_order {
        -1
      } else if a_order > b_order {
        1
      } else {
        let a_idx = match original_index.get(a) {
          Some(value) => value
          None => 0
        }
        let b_idx = match original_index.get(b) {
          Some(value) => value
          None => 0
        }
        if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
          1
        } else {
          0
        }
      }
    })
  }
}

///|
fn build_rank_groups(
  nodes : Array[@cgraph.Node],
  ranks : Map[String, Int],
) -> Map[Int, Array[String]] {
  let groups : Map[Int, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match groups.get(rank) {
      Some(list) => list.push(name)
      None => groups[rank] = [name]
    }
  }
  groups
}

///|
fn pow10_int(exp : Int) -> Int {
  if exp <= 0 {
    return 1
  }
  let mut result = 1
  for _ in 0..<exp {
    result = result * 10
  }
  result
}

///|
fn pow10_double(exp : Int) -> Double {
  @math.pow(10.0, exp.to_double())
}

///|
fn trim_trailing_zeros(text : String) -> String {
  if !text.contains(".") {
    return text
  }
  let mut result = text
  while result.length() > 0 && result.has_suffix("0") {
    let next_len = result.length() - 1
    result = result.unsafe_substring(start=0, end=next_len)
  }
  if result.has_suffix(".") {
    let next_len = result.length() - 1
    result = result.unsafe_substring(start=0, end=next_len)
  }
  result
}

///|
fn format_fixed(value : Double, decimals : Int) -> String {
  if decimals <= 0 {
    return "\{value.round().to_int()}"
  }
  let scale = pow10_int(decimals)
  let scaled = (value * scale.to_double()).round().to_int()
  let int_part = scaled / scale
  let mut frac = scaled % scale
  if frac < 0 {
    frac = -frac
  }
  let mut frac_str = frac.to_string()
  while frac_str.length() < decimals {
    frac_str = "0\{frac_str}"
  }
  "\{int_part}.\{frac_str}"
}

///|
fn format_fixed_trim(value : Double, decimals : Int) -> String {
  trim_trailing_zeros(format_fixed(value, decimals))
}

///|
fn round_to(value : Double, decimals : Int) -> Double {
  if decimals <= 0 {
    return value.round()
  }
  let scale = pow10_double(decimals)
  (value * scale).round() / scale
}

///|
fn format_scientific(abs : Double, exp : Int, precision : Int, sign : String) -> String {
  let mut exp_mut = exp
  let mantissa = abs / pow10_double(exp_mut)
  let decimals = precision - 1
  let mut rounded = round_to(mantissa, decimals)
  if rounded >= 10.0 {
    rounded = rounded / 10.0
    exp_mut = exp_mut + 1
  }
  let mantissa_str = format_fixed_trim(rounded, decimals)
  let exp_sign = if exp_mut < 0 {
    "-"
  } else {
    "+"
  }
  let exp_abs = if exp_mut < 0 {
    -exp_mut
  } else {
    exp_mut
  }
  let exp_str =
    if exp_abs < 10 {
    "0\{exp_abs}"
  } else {
    "\{exp_abs}"
  }
  "\{sign}\{mantissa_str}e\{exp_sign}\{exp_str}"
}

///|
fn format_float(value : Double) -> String {
  if value == 0.0 {
    return "0"
  }
  let sign = if value < 0.0 {
    "-"
  } else {
    ""
  }
  let abs = if value < 0.0 {
    -value
  } else {
    value
  }
  let precision = 5
  let exp = @math.log10(abs).floor().to_int()
  if exp < -4 || exp >= precision {
    return format_scientific(abs, exp, precision, sign)
  }
  let decimals = precision - exp - 1
  let rounded = round_to(abs, decimals)
  if rounded != 0.0 {
    let new_exp = @math.log10(rounded).floor().to_int()
    if new_exp >= precision {
      return format_scientific(rounded, new_exp, precision, sign)
    }
  }
  "\{sign}\{format_fixed_trim(rounded, decimals)}"
}

///|
fn format_dim(value : Double) -> String {
  format_float(value)
}

///|
fn format_point(point : @geom.Point) -> String {
  "\{format_float(point.x)},\{format_float(point.y)}"
}

///|
fn format_rect(rect : @geom.Rect) -> String {
  "\{format_float(rect.llx)},\{format_float(rect.lly)},\{format_float(rect.urx)},\{format_float(rect.ury)}"
}

///|
fn format_rects(rects : Array[@geom.Rect]) -> String {
  let parts : Array[String] = []
  for rect in rects {
    parts.push(format_rect(rect))
  }
  parts.join(" ")
}

///|
fn spline_bbox(points : Array[@geom.Point]) -> @geom.Rect? {
  if points.length() == 0 {
    return None
  }
  let mut min_x = points[0].x
  let mut max_x = points[0].x
  let mut min_y = points[0].y
  let mut max_y = points[0].y
  let update = (p : @geom.Point) => {
    if p.x < min_x { min_x = p.x }
    if p.x > max_x { max_x = p.x }
    if p.y < min_y { min_y = p.y }
    if p.y > max_y { max_y = p.y }
  }
  if points.length() % 3 != 1 {
    for p in points {
      update(p)
    }
    return Some({ llx: min_x, lly: min_y, urx: max_x, ury: max_y })
  }
  let mut i = 1
  while i + 2 < points.length() {
    let p1 = points[i]
    let p2 = points[i + 1]
    let mid = point((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0)
    update(mid)
    update(points[i + 2])
    i = i + 3
  }
  Some({ llx: min_x, lly: min_y, urx: max_x, ury: max_y })
}

///|
fn compute_bbox(
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
) -> @geom.Rect {
  let mut bbox_set = false
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut min_y = 0.0
  let mut max_y = 0.0
  for node in nodes {
    let half_w = node.width_in * 72.0 / 2.0
    let half_h = node.height_in * 72.0 / 2.0
    let left = node.pos.x - half_w
    let right = node.pos.x + half_w
    let bottom = node.pos.y - half_h
    let top = node.pos.y + half_h
    if !bbox_set {
      min_x = left
      max_x = right
      min_y = bottom
      max_y = top
      bbox_set = true
    } else {
      if left < min_x {
        min_x = left
      }
      if right > max_x {
        max_x = right
      }
      if bottom < min_y {
        min_y = bottom
      }
      if top > max_y {
        max_y = top
      }
    }
  }
  for edge in edges {
    for spline in edge.splines {
      let update = (p : @geom.Point) => {
        if !bbox_set {
          min_x = p.x
          max_x = p.x
          min_y = p.y
          max_y = p.y
          bbox_set = true
        } else {
          if p.x < min_x { min_x = p.x }
          if p.x > max_x { max_x = p.x }
          if p.y < min_y { min_y = p.y }
          if p.y > max_y { max_y = p.y }
        }
      }
      match spline.start {
        Some(point) => update(point)
        None => ()
      }
      match spline.end {
        Some(point) => update(point)
        None => ()
      }
      match spline_bbox(spline.points) {
        Some(rect) => {
          update({ x: rect.llx, y: rect.lly })
          update({ x: rect.urx, y: rect.ury })
        }
        None => ()
      }
    }
  }
  if bbox_set {
    { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
  } else {
    { llx: 0.0, lly: 0.0, urx: 0.0, ury: 0.0 }
  }
}

///|
fn merge_bbox(base : @geom.Rect, other : @geom.Rect) -> @geom.Rect {
  {
    llx: if base.llx < other.llx {
      base.llx
    } else {
      other.llx
    },
    lly: if base.lly < other.lly {
      base.lly
    } else {
      other.lly
    },
    urx: if base.urx > other.urx {
      base.urx
    } else {
      other.urx
    },
    ury: if base.ury > other.ury {
      base.ury
    } else {
      other.ury
    },
  }
}

///|
fn round_bbox(bbox : @geom.Rect) -> @geom.Rect {
  {
    llx: bbox.llx.round(),
    lly: bbox.lly,
    urx: bbox.urx.round(),
    ury: bbox.ury,
  }
}

///|
fn expand_bbox_with_subgraphs(
  bbox : @geom.Rect,
  subgraphs : Array[DotLayoutGraph],
) -> @geom.Rect {
  let mut result = bbox
  for subgraph in subgraphs {
    result = merge_bbox(result, subgraph.bbox)
    if subgraph.subgraphs.length() > 0 {
      result = expand_bbox_with_subgraphs(result, subgraph.subgraphs)
    }
  }
  result
}

///|
fn transform_point(
  point : @geom.Point,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Point {
  match rankdir {
    RankDir::TB => point
    RankDir::BT => { x: point.x, y: bbox.lly + bbox.ury - point.y }
    RankDir::LR => { x: bbox.lly + bbox.ury - point.y, y: point.x }
    RankDir::RL => { x: point.y, y: bbox.llx + bbox.urx - point.x }
  }
}

///|
fn transform_optional_point(
  point : @geom.Point?,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Point? {
  match point {
    Some(value) => Some(transform_point(value, bbox, rankdir))
    None => None
  }
}

///|
fn transform_spline(
  spline : @geom.Spline,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(transform_point(point, bbox, rankdir))
  }
  {
    start: transform_optional_point(spline.start, bbox, rankdir),
    end: transform_optional_point(spline.end, bbox, rankdir),
    points,
  }
}

///|
fn shift_point(point : @geom.Point, dx : Double, dy : Double) -> @geom.Point {
  { x: point.x + dx, y: point.y + dy }
}

///|
fn shift_optional_point(
  point : @geom.Point?,
  dx : Double,
  dy : Double,
) -> @geom.Point? {
  match point {
    Some(value) => Some(shift_point(value, dx, dy))
    None => None
  }
}

///|
fn shift_spline(
  spline : @geom.Spline,
  dx : Double,
  dy : Double,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(shift_point(point, dx, dy))
  }
  {
    start: shift_optional_point(spline.start, dx, dy),
    end: shift_optional_point(spline.end, dx, dy),
    points,
  }
}

///|
fn shift_layout_graph(
  layout : DotLayoutGraph,
  dx : Double,
  dy : Double,
) -> DotLayoutGraph {
  let shifted_nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    shifted_nodes.push({
      node: node_layout.node,
      pos: shift_point(node_layout.pos, dx, dy),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: shift_optional_point(node_layout.label_pos, dx, dy),
    })
  }
  let shifted_edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(shift_spline(spline, dx, dy))
    }
    shifted_edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: shift_optional_point(edge_layout.label_pos, dx, dy),
      head_label_pos: shift_optional_point(edge_layout.head_label_pos, dx, dy),
      tail_label_pos: shift_optional_point(edge_layout.tail_label_pos, dx, dy),
    })
  }
  let shifted_subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    shifted_subgraphs.push(shift_layout_graph(subgraph, dx, dy))
  }
  let shifted_bbox : @geom.Rect = {
    llx: layout.bbox.llx + dx,
    lly: layout.bbox.lly + dy,
    urx: layout.bbox.urx + dx,
    ury: layout.bbox.ury + dy,
  }
  {
    graph: layout.graph,
    bbox: shifted_bbox,
    label_pos: shift_optional_point(layout.label_pos, dx, dy),
    nodes: shifted_nodes,
    edges: shifted_edges,
    subgraphs: shifted_subgraphs,
  }
}

///|
fn transform_layout(
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> (Array[DotLayoutNode], Array[DotLayoutEdge], @geom.Rect) {
  let transformed_nodes : Array[DotLayoutNode] = []
  for node_layout in nodes {
    transformed_nodes.push({
      node: node_layout.node,
      pos: transform_point(node_layout.pos, bbox, rankdir),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: transform_optional_point(node_layout.label_pos, bbox, rankdir),
    })
  }
  let transformed_edges : Array[DotLayoutEdge] = []
  for edge_layout in edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(transform_spline(spline, bbox, rankdir))
    }
    transformed_edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: transform_optional_point(edge_layout.label_pos, bbox, rankdir),
      head_label_pos: transform_optional_point(
        edge_layout.head_label_pos,
        bbox,
        rankdir,
      ),
      tail_label_pos: transform_optional_point(
        edge_layout.tail_label_pos,
        bbox,
        rankdir,
      ),
    })
  }
  let transformed_bbox = compute_bbox(transformed_nodes, transformed_edges)
  if transformed_bbox.llx == 0.0 && transformed_bbox.lly == 0.0 {
    (transformed_nodes, transformed_edges, transformed_bbox)
  } else {
    let dx = -transformed_bbox.llx
    let dy = -transformed_bbox.lly
    let shifted_nodes : Array[DotLayoutNode] = []
    for node_layout in transformed_nodes {
      shifted_nodes.push({
        node: node_layout.node,
        pos: shift_point(node_layout.pos, dx, dy),
        width_in: node_layout.width_in,
        height_in: node_layout.height_in,
        label_pos: shift_optional_point(node_layout.label_pos, dx, dy),
      })
    }
    let shifted_edges : Array[DotLayoutEdge] = []
    for edge_layout in transformed_edges {
      let splines : Array[@geom.Spline] = []
      for spline in edge_layout.splines {
        splines.push(shift_spline(spline, dx, dy))
      }
      shifted_edges.push({
        edge: edge_layout.edge,
        splines,
        label_pos: shift_optional_point(edge_layout.label_pos, dx, dy),
        head_label_pos: shift_optional_point(edge_layout.head_label_pos, dx, dy),
        tail_label_pos: shift_optional_point(edge_layout.tail_label_pos, dx, dy),
      })
    }
    let shifted_bbox = compute_bbox(shifted_nodes, shifted_edges)
    (shifted_nodes, shifted_edges, shifted_bbox)
  }
}

///|
fn is_cluster_graph(graph : @cgraph.Graph) -> Bool {
  match graph.name() {
    Some(name) => name.has_prefix("cluster")
    None => false
  }
}

///|
fn graph_has_cluster(graph : @cgraph.Graph) -> Bool {
  for subgraph in graph.subgraphs() {
    if is_cluster_graph(subgraph) {
      return true
    }
    if graph_has_cluster(subgraph) {
      return true
    }
  }
  false
}

///|
priv enum LabelLoc {
  Top
  Bottom
}

///|
priv enum LabelJust {
  Left
  Center
  Right
}

///|
fn parse_label_loc(value : String?, default_loc : LabelLoc) -> LabelLoc {
  match value {
    Some(text) => {
      let lower = text.to_lower()
      match lower {
        "t" | "top" => LabelLoc::Top
        "b" | "bottom" => LabelLoc::Bottom
        _ => default_loc
      }
    }
    None => default_loc
  }
}

///|
fn parse_label_just(value : String?) -> LabelJust {
  match value {
    Some(text) => {
      let lower = text.to_lower()
      match lower {
        "l" | "left" => LabelJust::Left
        "r" | "right" => LabelJust::Right
        "c" | "center" => LabelJust::Center
        _ => LabelJust::Center
      }
    }
    None => LabelJust::Center
  }
}

///|
fn graph_label_loc(graph : @cgraph.Graph) -> LabelLoc {
  let default_loc = if graph.is_root() {
    LabelLoc::Bottom
  } else {
    LabelLoc::Top
  }
  parse_label_loc(graph.get_attr("labelloc"), default_loc)
}

///|
fn graph_label_just(graph : @cgraph.Graph) -> LabelJust {
  parse_label_just(graph.get_attr("labeljust"))
}

///|
fn graph_label_metrics(graph : @cgraph.Graph) -> (Double, Double)? {
  match graph.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        let font_size_pt = @attrs.font_size(graph.get_attr("fontsize"))
        let font = @attrs.font_name(graph.get_attr("fontname"))
        let (width_pt, height_pt) = label_text_dimensions(
          value, font, font_size_pt,
        )
        Some((width_pt, height_pt))
      }
    None => None
  }
}

///|
fn graph_label_pos(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
  just : LabelJust,
) -> @geom.Point {
  let x = match just {
    LabelJust::Left => bbox.llx + label_width_pt / 2.0
    LabelJust::Right => bbox.urx - label_width_pt / 2.0
    LabelJust::Center => (bbox.llx + bbox.urx) / 2.0
  }
  let y = match loc {
    LabelLoc::Top => bbox.ury - label_height_pt / 2.0
    LabelLoc::Bottom => bbox.lly + label_height_pt / 2.0
  }
  { x, y }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b { a } else { b }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b { a } else { b }
}

///|
fn rect_center(rect : @geom.Rect) -> @geom.Point {
  { x: (rect.llx + rect.urx) / 2.0, y: (rect.lly + rect.ury) / 2.0 }
}

///|
fn rect_from_center(
  center : @geom.Point,
  width : Double,
  height : Double,
  pad : Double,
) -> @geom.Rect {
  let half_w = width / 2.0 + pad
  let half_h = height / 2.0 + pad
  {
    llx: center.x - half_w,
    lly: center.y - half_h,
    urx: center.x + half_w,
    ury: center.y + half_h,
  }
}

///|
priv struct EdgeLabelEntry {
  key : String
  pos : @geom.Point
  base_axis : Double
  half_axis : Double
}

///|
fn rect_overlap_amount(
  a : @geom.Rect,
  b : @geom.Rect,
) -> (Double, Double)? {
  let overlap_x = min_double(a.urx, b.urx) - max_double(a.llx, b.llx)
  let overlap_y = min_double(a.ury, b.ury) - max_double(a.lly, b.lly)
  if overlap_x > 0.0 && overlap_y > 0.0 {
    Some((overlap_x, overlap_y))
  } else {
    None
  }
}

///|
fn nudge_label_rect(
  label_pos : @geom.Point,
  label_rect : @geom.Rect,
  other_rect : @geom.Rect,
  label_width : Double,
  label_height : Double,
  pad : Double,
) -> (@geom.Point, @geom.Rect) {
  match rect_overlap_amount(label_rect, other_rect) {
    Some((overlap_x, overlap_y)) => {
      let other_center = rect_center(other_rect)
      if overlap_x < overlap_y {
        let dir = if label_pos.x < other_center.x { -1.0 } else { 1.0 }
        let shift = overlap_x + pad
        let new_pos : @geom.Point = {
          x: label_pos.x + dir * shift,
          y: label_pos.y,
        }
        (new_pos, rect_from_center(new_pos, label_width, label_height, pad))
      } else {
        let dir = if label_pos.y < other_center.y { -1.0 } else { 1.0 }
        let shift = overlap_y + pad
        let new_pos : @geom.Point = {
          x: label_pos.x,
          y: label_pos.y + dir * shift,
        }
        (new_pos, rect_from_center(new_pos, label_width, label_height, pad))
      }
    }
    None => (label_pos, label_rect)
  }
}

///|
fn edge_tail_point(edge_layout : DotLayoutEdge) -> @geom.Point? {
  match edge_layout.splines.get(0) {
    Some(spline) =>
      match spline.start {
        Some(point) => Some(point)
        None =>
          if spline.points.length() > 0 { Some(spline.points[0]) } else { None }
      }
    None => None
  }
}

///|
fn bezier_point(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
  t : Double,
) -> @geom.Point {
  let p01 = point_lerp(p0, p1, t)
  let p12 = point_lerp(p1, p2, t)
  let p23 = point_lerp(p2, p3, t)
  let p012 = point_lerp(p01, p12, t)
  let p123 = point_lerp(p12, p23, t)
  point_lerp(p012, p123, t)
}

///|
///|
fn sample_spline_points(
  points : Array[@geom.Point],
  steps : Int,
) -> Array[@geom.Point] {
  let samples : Array[@geom.Point] = []
  if points.length() == 0 || steps <= 0 {
    return samples
  }
  samples.push(points[0])
  let mut index = 0
  let step_count = steps.to_double()
  while index + 3 < points.length() {
    let p0 = points[index]
    let p1 = points[index + 1]
    let p2 = points[index + 2]
    let p3 = points[index + 3]
    for step in 1..=steps {
      let t = step.to_double() / step_count
      samples.push(bezier_point(p0, p1, p2, p3, t))
    }
    index = index + 3
  }
  samples
}

///|
fn downsample_every_other(
  points : Array[@geom.Point],
) -> Array[@geom.Point] {
  let sampled : Array[@geom.Point] = []
  let mut idx = 0
  while idx < points.length() {
    sampled.push(points[idx])
    idx = idx + 2
  }
  sampled
}

///|
fn polyline_point_with_dir(
  points : Array[@geom.Point],
  target_len : Double,
) -> (@geom.Point, @geom.Point)? {
  if points.length() == 0 {
    return None
  }
  if points.length() == 1 {
    return Some((points[0], point(1.0, 0.0)))
  }
  let mut remaining = target_len
  let mut last_dir = point(1.0, 0.0)
  let mut last_pos = points[points.length() - 1]
  for i in 0..<(points.length() - 1) {
    let a = points[i]
    let b = points[i + 1]
    let seg_len = segment_length(a, b)
    if seg_len > 0.0 {
      let delta = point_sub(b, a)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      if len > 0.0 {
        last_dir = point_scale(delta, 1.0 / len)
        last_pos = b
      }
    }
    if seg_len <= 0.0 {
      continue
    }
    if remaining <= seg_len {
      let t = remaining / seg_len
      let pos = point_lerp(a, b, t)
      let delta = point_sub(b, a)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      let dir =
        if len <= 0.0 { point(1.0, 0.0) } else { point_scale(delta, 1.0 / len) }
      return Some((pos, dir))
    }
    remaining = remaining - seg_len
  }
  Some((last_pos, last_dir))
}

///|
fn polyline_point_at_axis(
  points : Array[@geom.Point],
  axis_value : Double,
  axis_is_x : Bool,
) -> (@geom.Point, @geom.Point)? {
  if points.length() == 0 {
    return None
  }
  if points.length() == 1 {
    return Some((points[0], point(1.0, 0.0)))
  }
  let total_len = polyline_length(points)
  let target = if total_len <= 0.0 { 0.0 } else { total_len / 2.0 }
  let epsilon = 0.000001
  let mut traveled = 0.0
  let mut best_pos : @geom.Point? = None
  let mut best_dir : @geom.Point? = None
  let mut best_dist = 0.0
  for i in 0..<(points.length() - 1) {
    let a = points[i]
    let b = points[i + 1]
    let seg_len = segment_length(a, b)
    let a_axis = if axis_is_x { a.x } else { a.y }
    let b_axis = if axis_is_x { b.x } else { b.y }
    let min_axis = if a_axis < b_axis { a_axis } else { b_axis }
    let max_axis = if a_axis < b_axis { b_axis } else { a_axis }
    if axis_value < min_axis || axis_value > max_axis {
      traveled = traveled + seg_len
      continue
    }
    let delta_axis = b_axis - a_axis
    let t =
      if Double::abs(delta_axis) <= epsilon {
        0.5
      } else {
        (axis_value - a_axis) / delta_axis
      }
    let pos = point_lerp(a, b, t)
    let delta = point_sub(b, a)
    let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
    let dir =
      if len <= 0.0 { point(1.0, 0.0) } else { point_scale(delta, 1.0 / len) }
    let cross_len = traveled + seg_len * t
    let dist = Double::abs(cross_len - target)
    if best_pos is None || dist < best_dist {
      best_pos = Some(pos)
      best_dir = Some(dir)
      best_dist = dist
    }
    traveled = traveled + seg_len
  }
  match best_pos {
    Some(pos) =>
      match best_dir {
        Some(dir) => Some((pos, dir))
        None => None
      }
    None => None
  }
}

///|
fn spline_label_pos_with_dir_samples(
  samples : Array[@geom.Point],
) -> (@geom.Point, @geom.Point)? {
  if samples.length() == 0 {
    return None
  }
  let total_len = polyline_length(samples)
  let target = if total_len <= 0.0 { 0.0 } else { total_len / 2.0 }
  polyline_point_with_dir(samples, target)
}

///|
fn spline_label_pos_at_axis_samples(
  samples : Array[@geom.Point],
  axis_value : Double,
  axis_is_x : Bool,
) -> (@geom.Point, @geom.Point)? {
  if samples.length() == 0 {
    return None
  }
  polyline_point_at_axis(samples, axis_value, axis_is_x)
}

///|
fn edge_label_rank_info(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
) -> (Int, Int)? {
  if edge_mid_label_width_pt(edge) <= 0.0 {
    return None
  }
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
  let span = max_rank - min_rank
  if span <= 1 {
    return None
  }
  let label_rank = (min_rank + max_rank) / 2
  Some((label_rank, span))
}

///|
fn edge_label_rank_y(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
) -> Double? {
  match edge_label_rank_info(edge, ranks) {
    Some((label_rank, _span)) => rank_y.get(label_rank)
    None => None
  }
}

///|
fn edge_label_rank_x(
  edge : @cgraph.Edge,
  label_rank : Int,
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_positions : Map[String, @geom.Point],
) -> Double? {
  match edge_vnodes.get(edge_vnode_key(edge)) {
    Some(vnodes) =>
      for name in vnodes {
        match vnode_ranks.get(name) {
          Some(rank) =>
            if rank == label_rank {
              match vnode_positions.get(name) {
                Some(pos) => return Some(pos.x)
                None => ()
              }
            }
          None => ()
        }
      }
    None => ()
  }
  None
}

///|
fn edge_label_pos(
  edge : @cgraph.Edge,
  spline : @geom.Spline,
  tail_clip : @geom.Point,
  head_clip : @geom.Point,
  rankdir : RankDir,
  label_rank_y : Double?,
  label_rank_x : Double?,
  apply_label_pad : Bool,
  nodesep_pt : Double,
  label_pad_boost : Double,
) -> @geom.Point? {
  let samples = sample_spline_points(spline.points, 96)
  let fallback = match spline_label_pos_with_dir_samples(samples) {
    Some((pos, tangent)) => (pos, tangent)
    None => {
      let mid = point(
        (tail_clip.x + head_clip.x) / 2.0,
        (tail_clip.y + head_clip.y) / 2.0,
      )
      let delta = point_sub(head_clip, tail_clip)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      let tangent =
        if len <= 0.0 { point(1.0, 0.0) } else { point_scale(delta, 1.0 / len) }
      (mid, tangent)
    }
  }
  let (raw_pos, dir) = match label_rank_y {
    Some(axis) =>
      match spline_label_pos_at_axis_samples(
        downsample_every_other(samples),
        axis,
        false,
      ) {
        Some((pos, tangent)) => (pos, tangent)
        None => fallback
      }
    None => fallback
  }
  let base_pos =
    match label_rank_x {
      Some(value) =>
        match rankdir {
          RankDir::LR | RankDir::RL => point(raw_pos.x, value)
          _ => point(value, raw_pos.y)
        }
      None => raw_pos
    }
  if edge.tail().name() == edge.head().name() {
    return Some(base_pos)
  }
  match label_rank_y {
    Some(_) =>
      match edge_mid_label_metrics(edge) {
        Some((width, height)) => {
          let mut pad = label_pad_boost
          if apply_label_pad {
            pad = pad + nodesep_pt * 0.22
          } else if label_rank_x is None && width >= EDGE_LABEL_PAD_WIDTH_PT {
            pad = pad + nodesep_pt * 0.22
          }
          let half_extent = match rankdir {
            RankDir::LR | RankDir::RL => height / 2.0
            _ => width / 2.0
          }
          let sign = match rankdir {
            RankDir::RL => -1.0
            _ => 1.0
          }
          Some(point(base_pos.x + sign * (half_extent + pad), base_pos.y))
        }
        None => Some(base_pos)
      }
    None => {
      let (width, height) = match edge_mid_label_metrics(edge) {
        Some((w, h)) => (w, h)
        None => return Some(base_pos)
      }
      let normal = point(-dir.y, dir.x)
      let axis_threshold = 0.1
      let abs_dx = Double::abs(dir.x)
      let abs_dy = Double::abs(dir.y)
      if spline.points.length() > 4 &&
        abs_dx > axis_threshold &&
        abs_dy > axis_threshold {
        return Some(base_pos)
      }
      let offset =
        if abs_dx <= axis_threshold {
          width / 2.0
        } else if abs_dy <= axis_threshold {
          height / 2.0
        } else {
          0.0
        }
      if offset <= 0.0 {
        Some(base_pos)
      } else {
        let pad = label_pad_boost
        Some(point_add(base_pos, point_scale(normal, offset + pad)))
      }
    }
  }
}

///|
fn collect_cluster_label_rects(
  graphs : Array[DotLayoutGraph],
  pad : Double,
) -> Array[@geom.Rect] {
  let rects : Array[@geom.Rect] = []
  for subgraph in graphs {
    match subgraph.label_pos {
      Some(pos) =>
        match graph_label_metrics(subgraph.graph) {
          Some((width, height)) => rects.push(rect_from_center(pos, width, height, pad))
          None => ()
        }
      None => ()
    }
    let nested = collect_cluster_label_rects(subgraph.subgraphs, pad)
    for rect in nested {
      rects.push(rect)
    }
  }
  rects
}

///|
fn adjust_edge_label_positions(
  edges : Array[DotLayoutEdge],
  label_rects : Array[@geom.Rect],
  pad : Double,
) -> (Array[DotLayoutEdge], Map[String, @geom.Point]) {
  let adjusted : Array[DotLayoutEdge] = []
  let updates : Map[String, @geom.Point] = Map::new()
  for edge_layout in edges {
    let mut label_pos = edge_layout.label_pos
    match label_pos {
      Some(pos) =>
        match edge_mid_label_metrics(edge_layout.edge) {
          Some((width, height)) => {
            let mut current_pos = pos
            let mut current_rect = rect_from_center(current_pos, width, height, pad)
            for rect in label_rects {
              let (next_pos, next_rect) = nudge_label_rect(
                current_pos,
                current_rect,
                rect,
                width,
                height,
                pad,
              )
              current_pos = next_pos
              current_rect = next_rect
            }
            label_pos = Some(current_pos)
          }
          None => ()
        }
      None => ()
    }
    match label_pos {
      Some(pos) => updates[edge_key(edge_layout.edge)] = pos
      None => ()
    }
    adjusted.push({
      edge: edge_layout.edge,
      splines: edge_layout.splines,
      label_pos,
      head_label_pos: edge_layout.head_label_pos,
      tail_label_pos: edge_layout.tail_label_pos,
    })
  }
  (adjusted, updates)
}

///|
fn apply_edge_label_updates(
  graphs : Array[DotLayoutGraph],
  updates : Map[String, @geom.Point],
) -> Array[DotLayoutGraph] {
  let updated : Array[DotLayoutGraph] = []
  for graph in graphs {
    let edges : Array[DotLayoutEdge] = []
    for edge_layout in graph.edges {
      let label_pos = match updates.get(edge_key(edge_layout.edge)) {
        Some(pos) => Some(pos)
        None => edge_layout.label_pos
      }
      edges.push({
        edge: edge_layout.edge,
        splines: edge_layout.splines,
        label_pos,
        head_label_pos: edge_layout.head_label_pos,
        tail_label_pos: edge_layout.tail_label_pos,
      })
    }
    let subgraphs = apply_edge_label_updates(graph.subgraphs, updates)
    updated.push({
      graph: graph.graph,
      bbox: graph.bbox,
      label_pos: graph.label_pos,
      nodes: graph.nodes,
      edges,
      subgraphs,
    })
  }
  updated
}

///|
fn adjust_edge_labels_for_cluster_labels(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
) -> DotLayoutGraph {
  let pad = if nodesep_pt * 0.2 < 2.0 { 2.0 } else { nodesep_pt * 0.2 }
  let label_rects : Array[@geom.Rect] = []
  match layout.label_pos {
    Some(pos) =>
      match graph_label_metrics(layout.graph) {
        Some((width, height)) =>
          label_rects.push(rect_from_center(pos, width, height, pad))
        None => ()
      }
    None => ()
  }
  let subgraph_rects = collect_cluster_label_rects(layout.subgraphs, pad)
  for rect in subgraph_rects {
    label_rects.push(rect)
  }
  if label_rects.length() == 0 {
    let subgraphs : Array[DotLayoutGraph] = []
    for subgraph in layout.subgraphs {
      subgraphs.push(
        adjust_edge_labels_for_cluster_labels(subgraph, nodesep_pt),
      )
    }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs,
    }
  } else {
    let (edges, updates) = adjust_edge_label_positions(
      layout.edges,
      label_rects,
      pad,
    )
    let updated_subgraphs = apply_edge_label_updates(layout.subgraphs, updates)
    let subgraphs : Array[DotLayoutGraph] = []
    for subgraph in updated_subgraphs {
      subgraphs.push(
        adjust_edge_labels_for_cluster_labels(subgraph, nodesep_pt),
      )
    }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges,
      subgraphs,
    }
  }
}

///|
fn adjust_edge_labels_for_label_overlaps(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
  rankdir : RankDir,
) -> DotLayoutGraph {
  let axis_is_x = match rankdir {
    RankDir::TB | RankDir::BT => true
    RankDir::LR | RankDir::RL => false
  }
  let tail_pad = max_double(2.0, nodesep_pt * 0.3)
  let gap = max_double(4.0, nodesep_pt * 0.8)
  let groups : Map[String, Array[EdgeLabelEntry]] = Map::new()
  for edge_layout in layout.edges {
    match edge_layout.label_pos {
      Some(pos) =>
        match edge_mid_label_metrics(edge_layout.edge) {
          Some((width, height)) => {
            let pos_axis = if axis_is_x { pos.x } else { pos.y }
            let tail_axis = match edge_tail_point(edge_layout) {
              Some(point) => if axis_is_x { point.x } else { point.y }
              None => pos_axis
            }
            let base_axis =
              if tail_axis + tail_pad > pos_axis { tail_axis + tail_pad } else { pos_axis }
            let half_axis = if axis_is_x { width / 2.0 } else { height / 2.0 }
            let entry = {
              key: edge_key(edge_layout.edge),
              pos,
              base_axis,
              half_axis,
            }
            let tail_name = edge_layout.edge.tail().name()
            let list = match groups.get(tail_name) {
              Some(value) => value
              None => []
            }
            list.push(entry)
            groups[tail_name] = list
          }
          None => ()
        }
      None => ()
    }
  }
  let updates : Map[String, @geom.Point] = Map::new()
  for _, entries in groups {
    if entries.length() < 2 {
      continue
    }
    entries.sort_by((a, b) => Double::compare(a.base_axis, b.base_axis))
    let mut last_axis = 0.0
    let mut last_half = 0.0
    let mut first = true
    for entry in entries {
      let mut axis_value = entry.base_axis
      if !first {
        let min_axis = last_axis + last_half + entry.half_axis + gap
        if axis_value < min_axis {
          axis_value = min_axis
        }
      }
      let new_pos : @geom.Point =
        if axis_is_x {
        { x: axis_value, y: entry.pos.y }
      } else {
        { x: entry.pos.x, y: axis_value }
      }
      if new_pos.x != entry.pos.x || new_pos.y != entry.pos.y {
        updates[entry.key] = new_pos
      }
      last_axis = axis_value
      last_half = entry.half_axis
      first = false
    }
  }
  if updates.length() == 0 {
    let subgraphs : Array[DotLayoutGraph] = []
    for subgraph in layout.subgraphs {
      subgraphs.push(
        adjust_edge_labels_for_label_overlaps(subgraph, nodesep_pt, rankdir),
      )
    }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs,
    }
  } else {
    let edges : Array[DotLayoutEdge] = []
    for edge_layout in layout.edges {
      let label_pos = match updates.get(edge_key(edge_layout.edge)) {
        Some(pos) => Some(pos)
        None => edge_layout.label_pos
      }
      edges.push({
        edge: edge_layout.edge,
        splines: edge_layout.splines,
        label_pos,
        head_label_pos: edge_layout.head_label_pos,
        tail_label_pos: edge_layout.tail_label_pos,
      })
    }
    let updated_subgraphs = apply_edge_label_updates(layout.subgraphs, updates)
    let subgraphs : Array[DotLayoutGraph] = []
    for subgraph in updated_subgraphs {
      subgraphs.push(
        adjust_edge_labels_for_label_overlaps(subgraph, nodesep_pt, rankdir),
      )
    }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges,
      subgraphs,
    }
  }
}

///|
fn expand_bbox_for_label(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
) -> @geom.Rect {
  let pad = 8.0
  let mut llx = bbox.llx
  let mut lly = bbox.lly
  let mut urx = bbox.urx
  let mut ury = bbox.ury
  match loc {
    LabelLoc::Top => ury = ury + label_height_pt + pad
    LabelLoc::Bottom => lly = lly - label_height_pt - pad
  }
  let label_width = label_width_pt + pad * 2.0
  let current_width = urx - llx
  if label_width > current_width {
    let extra = label_width - current_width
    llx = llx - extra / 2.0
    urx = urx + extra / 2.0
  }
  { llx, lly, urx, ury }
}

///|
fn compute_nodes_bbox(
  graph : @cgraph.Graph,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
) -> @geom.Rect? {
  let mut bbox_set = false
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut min_y = 0.0
  let mut max_y = 0.0
  for node in graph.nodes() {
    let name = node.name()
    let pos = match positions.get(name) {
      Some(value) => value
      None => continue
    }
    let size = match sizes.get(name) {
      Some(value) => value
      None => continue
    }
    let half_w = size.width_pt / 2.0
    let half_h = size.height_pt / 2.0
    let left = pos.x - half_w
    let right = pos.x + half_w
    let bottom = pos.y - half_h
    let top = pos.y + half_h
    if !bbox_set {
      min_x = left
      max_x = right
      min_y = bottom
      max_y = top
      bbox_set = true
    } else {
      if left < min_x {
        min_x = left
      }
      if right > max_x {
        max_x = right
      }
      if bottom < min_y {
        min_y = bottom
      }
      if top > max_y {
        max_y = top
      }
    }
  }
  if bbox_set {
    Some({ llx: min_x, lly: min_y, urx: max_x, ury: max_y })
  } else {
    None
  }
}

///|
fn collect_cluster_names(
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
fn shift_graph_positions(
  graph : @cgraph.Graph,
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_clusters : Map[String, String],
  dx : Double,
  dy : Double,
) -> Unit {
  let members : Map[String, Bool] = Map::new()
  collect_graph_nodes(graph, members)
  for name, _ in members {
    match positions.get(name) {
      Some(pos) => positions[name] = shift_point(pos, dx, dy)
      None => ()
    }
  }
  let clusters : Map[String, Bool] = Map::new()
  collect_cluster_names(graph, clusters)
  for vnode, key in vnode_clusters {
    if clusters.get(key) is Some(_) {
      match vnode_positions.get(vnode) {
        Some(pos) => vnode_positions[vnode] = shift_point(pos, dx, dy)
        None => ()
      }
    }
  }
}

///|
fn adjust_cluster_positions_for_rounding(
  graph : @cgraph.Graph,
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_clusters : Map[String, String],
  sizes : Map[String, NodeSize],
) -> @geom.Rect? {
  let mut bbox = compute_nodes_bbox(graph, positions, sizes)
  for child in graph.subgraphs() {
    match adjust_cluster_positions_for_rounding(
      child,
      positions,
      vnode_positions,
      vnode_clusters,
      sizes,
    ) {
      Some(child_bbox) =>
        bbox = Some(match bbox {
          Some(current) => merge_bbox(current, child_bbox)
          None => child_bbox
        })
      None => ()
    }
  }
  let mut current = match bbox {
    Some(value) => value
    None => return None
  }
  if is_cluster_graph(graph) {
    let pad = cluster_margin_pt(graph)
    current = {
      llx: current.llx - pad,
      lly: current.lly - pad,
      urx: current.urx + pad,
      ury: current.ury + pad,
    }
    match graph_label_metrics(graph) {
      Some((width_pt, height_pt)) => {
        let loc = graph_label_loc(graph)
        current = expand_bbox_for_label(current, width_pt, height_pt, loc)
      }
      None => ()
    }
    let rounded = round_bbox(current)
    let center_shift = (rounded.llx + rounded.urx) / 2.0 -
      (current.llx + current.urx) / 2.0
    if center_shift != 0.0 {
      shift_graph_positions(
        graph,
        positions,
        vnode_positions,
        vnode_clusters,
        center_shift,
        0.0,
      )
      current = {
        llx: current.llx + center_shift,
        lly: current.lly,
        urx: current.urx + center_shift,
        ury: current.ury,
      }
    }
    return Some(round_bbox(current))
  }
  Some(current)
}

///|
fn layout_subgraphs(
  graph : @cgraph.Graph,
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
) -> Array[DotLayoutGraph] {
  let result : Array[DotLayoutGraph] = []
  for subgraph in graph.subgraphs() {
    let node_set : Map[String, Bool] = Map::new()
    for node in subgraph.nodes() {
      node_set[node.name()] = true
    }
    let edge_set : Map[String, Bool] = Map::new()
    for edge in subgraph.edges() {
      edge_set[edge_key(edge)] = true
    }
    let sub_nodes : Array[DotLayoutNode] = []
    for node_layout in nodes_out {
      if node_set.get(node_layout.node.name()) is Some(_) {
        sub_nodes.push(node_layout)
      }
    }
    let sub_edges : Array[DotLayoutEdge] = []
    for edge_layout in edges_out {
      if edge_set.get(edge_key(edge_layout.edge)) is Some(_) {
        let tail_name = edge_layout.edge.tail().name()
        let head_name = edge_layout.edge.head().name()
        if node_set.get(tail_name) is Some(_) &&
          node_set.get(head_name) is Some(_) {
          sub_edges.push(edge_layout)
        }
      }
    }
    let mut bbox = compute_bbox(sub_nodes, sub_edges)
    let mut label_pos : @geom.Point? = None
    let mut label_info : (Double, Double, LabelLoc, LabelJust)? = None
    let sub_subgraphs = layout_subgraphs(subgraph, nodes_out, edges_out)
    if sub_subgraphs.length() > 0 {
      bbox = expand_bbox_with_subgraphs(bbox, sub_subgraphs)
    }
    if is_cluster_graph(subgraph) {
      let pad = cluster_margin_pt(subgraph)
      let llx = bbox.llx - pad
      let lly = bbox.lly - pad
      let urx = bbox.urx + pad
      let ury = bbox.ury + pad
      bbox = { llx, lly, urx, ury }
      match graph_label_metrics(subgraph) {
        Some((width_pt, height_pt)) => {
          let loc = graph_label_loc(subgraph)
          let just = graph_label_just(subgraph)
          bbox = expand_bbox_for_label(bbox, width_pt, height_pt, loc)
          label_info = Some((width_pt, height_pt, loc, just))
        }
        None => ()
      }
      bbox = round_bbox(bbox)
    }
    match label_info {
      Some((width_pt, height_pt, loc, just)) =>
        label_pos = Some(graph_label_pos(bbox, width_pt, height_pt, loc, just))
      None => ()
    }
    result.push({
      graph: subgraph,
      bbox,
      label_pos,
      nodes: sub_nodes,
      edges: sub_edges,
      subgraphs: sub_subgraphs,
    })
  }
  result
}

///|
fn collect_cluster_bboxes(
  subgraphs : Array[DotLayoutGraph],
  out : Map[String, @geom.Rect],
) -> Unit {
  for layout in subgraphs {
    if is_cluster_graph(layout.graph) {
      match layout.graph.name() {
        Some(name) => out[name] = layout.bbox
        None => ()
      }
    }
    if layout.subgraphs.length() > 0 {
      collect_cluster_bboxes(layout.subgraphs, out)
    }
  }
}

///|

///|
pub fn DotLayoutOptions::default() -> DotLayoutOptions {
  { rankdir: None, nodesep: None, ranksep: None, splines: None }
}

///|
pub fn layout_dot(
  graph : @cgraph.Graph,
  options? : DotLayoutOptions = DotLayoutOptions::default(),
) -> DotLayoutGraph raise DotLayoutError {
  let opts = options
  validate_layout_graph(graph)
  reset_label_caches()
  let rankdir = match opts.rankdir {
    Some(value) => value
    None =>
      match graph.get_attr("rankdir") {
        Some(value) =>
          match parse_rankdir(value) {
            Some(parsed) => parsed
            None => RankDir::TB
          }
        None => RankDir::TB
      }
  }
  let nodesep_in = match opts.nodesep {
    Some(value) => value
    None =>
      match graph.get_attr("nodesep") {
        Some(value) => parse_first_double(value, default_nodesep_in())
        None => default_nodesep_in()
      }
  }
  let ranksep_in = match opts.ranksep {
    Some(value) => value
    None =>
      match graph.get_attr("ranksep") {
        Some(value) => parse_first_double(value, default_ranksep_in())
        None => default_ranksep_in()
      }
  }
  if nodesep_in < 0.0 {
    raise DotLayoutError::InvalidGraph(message="nodesep must be non-negative")
  }
  if ranksep_in < 0.0 {
    raise DotLayoutError::InvalidGraph(message="ranksep must be non-negative")
  }
  let splines = match opts.splines {
    Some(value) => value
    None =>
      match graph.get_attr("splines") {
        Some(value) =>
          match parse_splines(value) {
            Some(parsed) => parsed
            None => SplinesMode::Spline
          }
        None => SplinesMode::Spline
      }
  }
  let _ = splines
  let nodes = ordered_nodes(graph)
  let edges = graph.edges()
  dot_trace("layout_dot: start nodes=\{nodes.length()} edges=\{edges.length()}")
  let mut has_dotted_edges = false
  let mut has_port_edges = false
  for edge in edges {
    match edge.get_attr("style") {
      Some(value) =>
        if value.to_lower().contains("dotted") {
          has_dotted_edges = true
        }
      None => ()
    }
    if !has_port_edges {
      let tail_port = port_is_explicit(edge.tail_port())
      let head_port = port_is_explicit(edge.head_port())
      if tail_port || head_port {
        has_port_edges = true
      }
    }
  }
  let has_edge_labels = graph_has_edge_labels(edges)
  let node_order : Map[String, Int] = Map::new()
  for i in 0..<nodes.length() {
    node_order[nodes[i].name()] = i
  }
  if rankdir == RankDir::RL {
    let total = nodes.length()
    for node in nodes {
      let name = node.name()
      let base = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      node_order[name] = total - 1 - base
    }
  }
  let layout_rankdir = RankDir::TB
  let record_orientation = record_layout_orientation(rankdir)
  let output_sizes : Map[String, NodeSize] = Map::new()
  let order_sizes : Map[String, NodeSize] = Map::new()
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    let size = node_size(node, record_orientation)
    output_sizes[node.name()] = size
    order_sizes[node.name()] = size
    sizes[node.name()] =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
      swap_node_size(size)
    } else {
      size
    }
  }
  let port_order_positions : Map[String, Double] = Map::new()
  let port_order_contrib : Map[String, Array[(String, Double)]] = Map::new()
  if (rankdir == RankDir::LR || rankdir == RankDir::RL) && has_port_edges {
    let record_port_order : Map[String, Map[String, Double]] = Map::new()
    for node in nodes {
      let label = label_text(node)
      let has_html = @html_label.is_html_label_text(label)
      if has_html || is_record_shape(node) {
        let name = node.name()
        let size = match output_sizes.get(name) {
          Some(value) => value
          None => node_size(node, record_orientation)
        }
        let raw_ports =
          if has_html {
            html_ports(node, { x: 0.0, y: 0.0 }, size)
          } else {
            record_ports(node, { x: 0.0, y: 0.0 }, size, record_orientation)
          }
        let order_map : Map[String, Double] = Map::new()
        for port_name, port in raw_ports {
          let offset = layout_port_offset(port.center, rankdir)
          order_map[port_name] = offset.x
        }
        record_port_order[name] = order_map
      }
    }
    let order_sum : Map[String, (Double, Int)] = Map::new()
    let update_order = (target : String, anchor : String, port : @cgraph.Port?) => {
      match port {
        Some(value) =>
          match value.name {
            Some(port_name) =>
              match record_port_order.get(anchor) {
                Some(ports) =>
                  match ports.get(port_name) {
                    Some(order) => {
                      let (sum, count) = match order_sum.get(target) {
                        Some(value) => value
                        None => (0.0, 0)
                      }
                      order_sum[target] = (sum + order, count + 1)
                      match port_order_contrib.get(target) {
                        Some(list) => list.push((anchor, order))
                        None => port_order_contrib[target] = [(anchor, order)]
                      }
                    }
                    None => ()
                  }
                None => ()
              }
            None => ()
          }
        None => ()
      }
    }
    for edge in edges {
      let tail_name = edge.tail().name()
      let head_name = edge.head().name()
      if port_is_explicit(edge.tail_port()) && is_record_shape(edge.tail()) {
        update_order(head_name, tail_name, edge.tail_port())
      }
      if port_is_explicit(edge.head_port()) && is_record_shape(edge.head()) {
        update_order(tail_name, head_name, edge.head_port())
      }
    }
  for name, entry in order_sum {
    let (sum, count) = entry
    if count > 0 {
    port_order_positions[name] = sum / count.to_double()
  }
}
}
  let (edge_tail, edge_head, edge_reversed) =
    if graph.kind() == @cgraph.GraphKind::Directed {
    acyclic_edge_directions(nodes, edges)
  } else {
    edge_endpoints_from_edges(edges)
  }
  let ranks = if graph.kind() == @cgraph.GraphKind::Directed {
    compute_ranks_directed(
      graph,
      nodes,
      edges,
      has_edge_labels,
      edge_tail,
      edge_head,
      edge_reversed,
    )
  } else {
    let base : Map[String, Int] = Map::new()
    for node in nodes {
      base[node.name()] = 0
    }
    base
  }
  dot_trace("layout_dot: ranks computed")
  dot_trace_edges(edges, edge_tail, edge_head, ranks)
  let groups = build_rank_groups(nodes, ranks)
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  let all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let min_rank = rank_keys[0]
    let max_rank = rank_keys[rank_keys.length() - 1]
    for rank in min_rank..=max_rank {
      all_ranks.push(rank)
    }
  }
  let self_edge_labels = self_edge_label_half_heights(edges)
  let rank_pht : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    rank_pht[rank] = 0.0
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut max_half = 0.0
    for name in names {
      let half_height = node_half_height_pt(name, sizes, self_edge_labels)
      if half_height > max_half {
        max_half = half_height
      }
    }
    rank_pht[rank] = max_half
  }
  if has_edge_labels {
    for edge in edges {
      if !edge_has_label(edge) {
        continue
      }
      let tail = edge.tail().name()
      let head = edge.head().name()
      let tail_rank = match ranks.get(tail) {
        Some(value) => value
        None => continue
      }
      let head_rank = match ranks.get(head) {
        Some(value) => value
        None => continue
      }
      let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
      let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
      if max_rank - min_rank <= 1 {
        continue
      }
      let label_rank = (min_rank + max_rank) / 2
      let half_height = edge_label_height_pt(edge) / 2.0
      let current = match rank_pht.get(label_rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current {
        rank_pht[label_rank] = half_height
      }
    }
  }
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    let half_height = match rank_pht.get(rank) {
      Some(value) => value
      None => 0.0
    }
    rank_ht1[rank] = half_height
    rank_ht2[rank] = half_height
  }
  let _ = apply_cluster_rank_heights(
    graph, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
  )
  let nodesep_pt = nodesep_in * 72.0
  let has_clusters = graph_has_cluster(graph)
  let mut ranksep_pt = ranksep_in * 72.0
  if has_edge_labels {
    ranksep_pt = (ranksep_pt + 1.0) / 2.0
  }
  let y_positions : Map[String, Double] = Map::new()
  let rank_y : Map[Int, Double] = Map::new()
  if all_ranks.length() > 0 {
    let max_rank = all_ranks[all_ranks.length() - 1]
    let start_y = match rank_ht1.get(max_rank) {
      Some(value) => value
      None => 0.0
    }
    rank_y[max_rank] = start_y
    let mut idx = all_ranks.length() - 1
    while idx > 0 {
      let upper = all_ranks[idx]
      let lower = all_ranks[idx - 1]
      let upper_pht = match rank_pht.get(upper) {
        Some(value) => value
        None => 0.0
      }
      let lower_pht = match rank_pht.get(lower) {
        Some(value) => value
        None => 0.0
      }
      let upper_ht2 = match rank_ht2.get(upper) {
        Some(value) => value
        None => 0.0
      }
      let lower_ht1 = match rank_ht1.get(lower) {
        Some(value) => value
        None => 0.0
      }
      let d0 = upper_pht + lower_pht + ranksep_pt
      let d1 = upper_ht2 + lower_ht1 + CLUSTER_MARGIN_PT
      let delta = if d0 > d1 { d0 } else { d1 }
      let base_y = match rank_y.get(upper) {
        Some(value) => value
        None => 0.0
      }
      rank_y[lower] = base_y + delta
      idx = idx - 1
    }
    for rank in rank_keys {
      let names = match groups.get(rank) {
        Some(list) => list
        None => []
      }
      let pos_y = match rank_y.get(rank) {
        Some(value) => value
        None => 0.0
      }
      for name in names {
        y_positions[name] = pos_y
      }
    }
  }
  let cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    cluster_keys[node.name()] = node_cluster_key(node)
  }
  let cluster_skeleton : Map[String, Bool] = Map::new()
  let cluster_rep_rank : Map[String, Int] = Map::new()
  let cluster_rep : Map[String, String] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match cluster_rep_rank.get(cluster) {
      Some(current) =>
        if rank < current {
          cluster_rep_rank[cluster] = rank
          cluster_rep[cluster] = name
        }
      None => {
        cluster_rep_rank[cluster] = rank
        cluster_rep[cluster] = name
      }
    }
  }
  for _cluster, name in cluster_rep {
    cluster_skeleton[name] = true
  }
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_first_order : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match cluster_min_rank.get(cluster) {
      Some(current) => if rank < current { cluster_min_rank[cluster] = rank }
      None => cluster_min_rank[cluster] = rank
    }
    if cluster_first_order.get(cluster) is None {
      let order_value = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      cluster_first_order[cluster] = order_value
    }
  }
  let cluster_order_list : Array[(String, Int, Int)] = []
  for cluster, rank in cluster_min_rank {
    let order = match cluster_first_order.get(cluster) {
      Some(value) => value
      None => 0
    }
    cluster_order_list.push((cluster, rank, order))
  }
  let cluster_order_base : Map[String, Int] = Map::new()
  if cluster_order_list.length() > 1 {
    cluster_order_list.sort_by((a, b) => {
      let (_name_a, rank_a, order_a) = a
      let (_name_b, rank_b, order_b) = b
      if order_a < order_b {
        -1
      } else if order_a > order_b {
        1
      } else if rank_a < rank_b {
        -1
      } else if rank_a > rank_b {
        1
      } else {
        0
      }
    })
    let step = nodes.length() + 1
    let mut base = 0
    for entry in cluster_order_list {
      let (cluster, _rank, _order) = entry
      cluster_order_base[cluster] = base
      base = base + step
    }
    for node in nodes {
      let name = node.name()
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      let base_order = match cluster_order_base.get(cluster) {
        Some(value) => value
        None => 0
      }
      let inner = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      node_order[name] = base_order + inner
    }
  }
  let intercluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    intercluster_keys[node.name()] = node_local_cluster_key(node)
  }
  let rank_same_groups : Map[String, Int] = Map::new()
  let rank_same_order : Map[String, Int] = Map::new()
  let _ = collect_rank_same_order(graph, rank_same_groups, rank_same_order, 0)
  let edge_order = collect_edge_order(edges)
  let (order_edges, order_edge_tail, order_edge_head) =
    dedup_ordering_edges(edges, edge_tail, edge_head)
  let (flat_constraints, ordering_set) = build_ordering_flat_constraints(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    cluster_keys,
  )
  let (parents, children) =
    build_edge_index_for_order(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      ranks,
    )
  let ordered_groups = reorder_rank_groups(
    rank_keys,
    groups,
    order_edges,
    order_edge_tail,
    order_edge_head,
    parents,
    children,
    cluster_keys,
    rank_same_groups,
    rank_same_order,
    edge_order,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    Map::new(),
    cluster_skeleton,
    flat_constraints,
  )
  dot_trace("layout_dot: rank order computed")
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(graph, edge_cluster_keys)
  let vnode_info = build_edge_vnodes(
    edges,
    ranks,
    nodesep_pt,
    existing_names,
    edge_cluster_keys,
  )
  let vnode_count = vnode_info.vnode_ranks.length()
  let use_vnodes_for_xpos =
    has_edge_labels || has_port_edges || vnode_count <= MAX_XPOS_VNODES
  let allow_xpos_reorder =
    !use_vnodes_for_xpos || vnode_count <= MAX_XPOS_REORDER_VNODES
  dot_trace("layout_dot: vnodes built count=\{vnode_count}")
  let virtual_slack_edges =
    if use_vnodes_for_xpos {
      let node_singletons = build_node_singletons(nodes, edges)
      let edges_out = build_virtual_slack_edges(
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        ranks,
        vnode_info.edge_vnodes,
        vnode_info.vnode_ranks,
        node_singletons,
        cluster_keys,
      )
      dot_trace("layout_dot: virtual slack edges=\{edges_out.length()}")
      edges_out
    } else {
      dot_trace("layout_dot: virtual slack edges=0 (skipped)")
      []
    }
  let order_index = build_order_index(ordered_groups)
  let vnode_order_keys =
    if use_vnodes_for_xpos {
      build_vnode_order_keys(
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        ranks,
        order_index,
        vnode_info.edge_vnodes,
        vnode_info.vnode_ranks,
      )
    } else {
      Map::new()
    }
  let mut has_vnode_order = false
  for _name, _ in vnode_order_keys {
    has_vnode_order = true
    break
  }
  let x_sizes =
    if use_vnodes_for_xpos {
      merge_sizes_with_vnodes(order_sizes, vnode_info.vnode_sizes)
    } else {
      order_sizes
    }
  let mut x_groups =
    if use_vnodes_for_xpos {
      build_x_groups_with_vnodes(
        ordered_groups,
        order_index,
        vnode_info.vnodes_by_rank,
        vnode_order_keys,
      )
    } else {
      ordered_groups
    }
  let x_cluster_keys : Map[String, String] = Map::new()
  for name, key in cluster_keys {
    x_cluster_keys[name] = key
  }
  if use_vnodes_for_xpos {
    for name, key in vnode_info.vnode_clusters {
      x_cluster_keys[name] = key
    }
  }
  if allow_xpos_reorder && !ordering_set && !has_vnode_order && !has_clusters {
    let (parents, children) = build_edge_index_for_order_with_vnodes(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      ranks,
      vnode_info.edge_vnodes,
      vnode_info.vnode_ranks,
    )
    let tmp_rank_keys = collect_rank_keys(x_groups)
    x_groups = reorder_rank_groups(
      tmp_rank_keys,
      x_groups,
      order_edges,
      order_edge_tail,
      order_edge_head,
      parents,
      children,
      x_cluster_keys,
      rank_same_groups,
      rank_same_order,
      edge_order,
      node_order,
      x_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      Map::new(),
      cluster_skeleton,
      flat_constraints,
    )
  }
  dot_trace_groups("x-groups", x_groups)
  if !has_edge_labels && use_vnodes_for_xpos && !has_vnode_order &&
    allow_xpos_reorder && !ordering_set {
    let (parents, children) = build_edge_index_for_order_with_vnodes(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      ranks,
      vnode_info.edge_vnodes,
      vnode_info.vnode_ranks,
    )
    let tmp_rank_keys = collect_rank_keys(x_groups)
    let tmp_ranks = build_node_ranks(x_groups)
    let _ = transpose_rank_groups_limited(
      tmp_rank_keys,
      x_groups,
      parents,
      children,
      tmp_ranks,
      false,
      4,
    )
    let _ = transpose_rank_groups_limited(
      tmp_rank_keys,
      x_groups,
      parents,
      children,
      tmp_ranks,
      true,
      4,
    )
  }
  let x_rank_keys = collect_rank_keys(x_groups)
  let x_ranks = build_node_ranks(x_groups)
  let vnode_extra_nodes =
    if use_vnodes_for_xpos {
      build_vnode_extra_nodes(vnode_info.vnode_ranks)
    } else {
      []
    }
  let x_edge_vnodes =
    if use_vnodes_for_xpos {
      vnode_info.edge_vnodes
    } else {
      Map::new()
    }
  let x_slack_edges =
    if use_vnodes_for_xpos {
      virtual_slack_edges
    } else {
      []
    }
  let x_positions = compute_x_positions(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    x_ranks,
    x_rank_keys,
    x_groups,
    x_sizes,
    output_sizes,
    x_cluster_keys,
    nodesep_pt,
    has_edge_labels,
    vnode_extra_nodes,
    x_edge_vnodes,
    x_slack_edges,
  )
  dot_trace("layout_dot: x positions computed")
  dot_trace_positions("xpos", x_positions)
  if has_clusters && has_dotted_edges {
    adjust_intercluster_alignment(
      nodes,
      edges,
      ranks,
      x_positions,
      cluster_keys,
      intercluster_keys,
      nodesep_pt,
      has_edge_labels,
    )
  }
  let vnode_names : Array[String] = []
  for pair in vnode_extra_nodes {
    let (name, _rank) = pair
    vnode_names.push(name)
  }
  // Let the final bounding-box translation handle normalization, matching Graphviz.
  let vnode_positions =
    if use_vnodes_for_xpos {
      let positions : Map[String, @geom.Point] = Map::new()
      for name, rank in vnode_info.vnode_ranks {
        let pos_x = match x_positions.get(name) {
          Some(value) => value
          None => 0.0
        }
        let pos_y = match rank_y.get(rank) {
          Some(value) => value
          None => 0.0
        }
        positions[name] = { x: pos_x, y: pos_y }
      }
      positions
    } else {
      vnode_positions_from_endpoints(
        edges,
        ranks,
        vnode_info.vnode_ranks,
        vnode_info.edge_vnodes,
        x_positions,
        rank_y,
      )
    }
  let positions : Map[String, @geom.Point] = Map::new()
  for node in nodes {
    let name = node.name()
    let pos_x = match x_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    let pos_y = match y_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    positions[name] = { x: pos_x, y: pos_y }
  }
  if has_clusters {
    let _ = adjust_cluster_positions_for_rounding(
      graph,
      positions,
      vnode_positions,
      vnode_info.vnode_clusters,
      sizes,
    )
  }
  let nodes_out : Array[DotLayoutNode] = []
  for node in nodes {
    let name = node.name()
    let pos = match positions.get(name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size = match output_sizes.get(name) {
      Some(value) => value
      None => node_size(node, record_orientation)
    }
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
    })
  }
  let label_ports_map : Map[String, Map[String, RecordPort]] = Map::new()
  let label_ports_raw : Map[String, Map[String, RecordPort]] = Map::new()
  if has_port_edges {
    for node_layout in nodes_out {
      let name = node_layout.node.name()
      let final_size = match output_sizes.get(name) {
        Some(value) => value
        None => node_size(node_layout.node, record_orientation)
      }
      let label = label_text(node_layout.node)
      let has_html = @html_label.is_html_label_text(label)
      if has_html {
        let raw_ports = html_ports(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
        )
        label_ports_raw[name] = raw_ports
        let ports =
          layout_ports_from_final(raw_ports, node_layout.pos, rankdir)
        label_ports_map[name] = ports
      } else if is_record_shape(node_layout.node) {
        let raw_ports = record_ports(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
          record_orientation,
        )
        label_ports_raw[name] = raw_ports
        let ports =
          layout_ports_from_final(raw_ports, node_layout.pos, rankdir)
        label_ports_map[name] = ports
      }
    }
  }
  let cluster_bboxes : Map[String, @geom.Rect] = Map::new()
  if graph_has_cluster(graph) {
    let cluster_layouts = layout_subgraphs(graph, nodes_out, [])
    collect_cluster_bboxes(cluster_layouts, cluster_bboxes)
  }
  let label_edge_counts : Map[String, Int] = Map::new()
  for edge in edges {
    if edge_mid_label_text(edge) is Some(_) {
      let tail = edge.tail().name()
      let current = match label_edge_counts.get(tail) {
        Some(value) => value
        None => 0
      }
      label_edge_counts[tail] = current + 1
    }
  }
  let enable_complex_tuning = has_clusters && has_dotted_edges
  let (port_pad_below, port_pad_above) =
    if has_clusters || !has_port_edges {
    (0.0, 0.0)
  } else {
    record_port_padding_y(edges, positions, label_ports_map)
  }
  let head_port_counts : Map[String, Int] = Map::new()
  let head_port_min_dist : Map[String, Double] = Map::new()
  let head_port_max_dist : Map[String, Double] = Map::new()
  if enable_complex_tuning {
    for edge in edges {
      let tail_name = edge.tail().name()
      let head_name = edge.head().name()
      let head_port = port_key(edge.head_port())
      let key =
        if head_port == "" {
        if is_record_shape(edge.head()) { head_name } else { "" }
      } else {
        "\{head_name}:\{head_port}"
      }
      if key == "" {
        continue
      }
      let tail_pos = match positions.get(tail_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let head_pos = match positions.get(head_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let tail_size = match sizes.get(tail_name) {
        Some(value) => value
        None => node_size(edge.tail(), record_orientation)
      }
      let head_size = match sizes.get(head_name) {
        Some(value) => value
        None => node_size(edge.head(), record_orientation)
      }
      let (tail_anchor, _) = port_geometry(
        tail_name,
        edge.tail_port(),
        label_ports_map,
        tail_pos,
        tail_size,
      )
      let (head_anchor, _) = port_geometry(
        head_name,
        edge.head_port(),
        label_ports_map,
        head_pos,
        head_size,
      )
      let dx = head_anchor.x - tail_anchor.x
      let dy = head_anchor.y - tail_anchor.y
      let dist = Double::sqrt(dx * dx + dy * dy)
      let current = match head_port_counts.get(key) {
        Some(value) => value
        None => 0
      }
      head_port_counts[key] = current + 1
      let mut min_dist = match head_port_min_dist.get(key) {
        Some(value) => value
        None => dist
      }
      let mut max_dist = match head_port_max_dist.get(key) {
        Some(value) => value
        None => dist
      }
      if dist < min_dist {
        min_dist = dist
      }
      if dist > max_dist {
        max_dist = dist
      }
      head_port_min_dist[key] = min_dist
      head_port_max_dist[key] = max_dist
    }
  }
  let edges_out : Array[DotLayoutEdge] = []
  dot_trace("layout_dot: routing edges")
  for edge in edges {
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    let tail_pos = match positions.get(tail_name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let head_pos = match positions.get(head_name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let tail_size = match sizes.get(tail_name) {
      Some(value) => value
      None => node_size(edge.tail(), record_orientation)
    }
    let head_size = match sizes.get(head_name) {
      Some(value) => value
      None => node_size(edge.head(), record_orientation)
    }
    let (raw_tail_anchor, raw_tail_anchor_size) = port_geometry(
      tail_name,
      edge.tail_port(),
      label_ports_map,
      tail_pos,
      tail_size,
    )
    let (raw_head_anchor, raw_head_anchor_size) = port_geometry(
      head_name,
      edge.head_port(),
      label_ports_map,
      head_pos,
      head_size,
    )
    let tail_port_rect = port_rect_from_geometry(
      edge.tail_port(),
      raw_tail_anchor,
      raw_tail_anchor_size,
      tail_size,
    )
    let head_port_rect = port_rect_from_geometry(
      edge.head_port(),
      raw_head_anchor,
      raw_head_anchor_size,
      head_size,
    )
    let tail_port_sides = match tail_port_rect {
      Some(rect) => port_side_count(rect, tail_pos, tail_size)
      None => 0
    }
    let head_port_sides = match head_port_rect {
      Some(rect) => port_side_count(rect, head_pos, head_size)
      None => 0
    }
    let force_segmented = tail_port_sides >= 3 || head_port_sides >= 3
    let tail_anchor_size = raw_tail_anchor_size
    let head_anchor_size = raw_head_anchor_size
    let tail_cluster_name = match edge.get_attr("ltail") {
      Some(value) => value
      None => ""
    }
    let head_cluster_name = match edge.get_attr("lhead") {
      Some(value) => value
      None => ""
    }
    let tail_rank = match ranks.get(tail_name) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head_name) {
      Some(value) => value
      None => 0
    }
    let is_flat_edge = tail_rank == head_rank
    let has_cluster = tail_cluster_name != "" || head_cluster_name != ""
    let vnodes = match vnode_info.edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    let has_vnodes = vnodes.length() > 0
    let use_pathplan = match @sys.get_env_var("DOT_USE_PATHPLAN") {
      Some(value) => {
        let lower = value.to_lower()
        lower != "0" && lower != "false" && lower != "no"
      }
      None => true
    }
    let allow_offset =
      !is_flat_edge &&
      !has_cluster &&
      !port_is_explicit(edge.tail_port()) &&
      !port_is_explicit(edge.head_port()) &&
      !(use_pathplan && has_vnodes)
    let (tail_offset, head_offset) = if allow_offset {
      (
        layout_port_offset(point(0.0, -1.0), layout_rankdir),
        layout_port_offset(point(0.0, 1.0), layout_rankdir),
      )
    } else {
      (point(0.0, 0.0), point(0.0, 0.0))
    }
    let tail_cluster_bbox : @geom.Rect? =
      if tail_cluster_name == "" {
      None
    } else {
      cluster_bboxes.get(tail_cluster_name)
    }
    let head_cluster_bbox : @geom.Rect? =
      if head_cluster_name == "" {
      None
    } else {
      cluster_bboxes.get(head_cluster_name)
    }
    let tail_side_anchor =
      if is_record_shape(edge.tail()) {
      (None : @geom.Point?)
    } else {
      match (edge.tail_port(), label_ports_raw.get(tail_name)) {
        (Some(port), Some(raw_ports)) =>
          match port.compass {
            Some(_) => (None : @geom.Point?)
            None =>
              match port.name {
                Some(port_name) =>
                  match raw_ports.get(port_name) {
                    Some(raw_port) =>
                      port_side_anchor_from_raw(
                        raw_port,
                        match output_sizes.get(tail_name) {
                          Some(value) => value
                          None => tail_size
                        },
                        tail_pos,
                        head_pos,
                        layout_rankdir,
                      )
                    None => (None : @geom.Point?)
                  }
                None => (None : @geom.Point?)
              }
          }
        _ => (None : @geom.Point?)
      }
    }
    let head_side_anchor =
      if is_record_shape(edge.head()) {
      (None : @geom.Point?)
    } else {
      match (edge.head_port(), label_ports_raw.get(head_name)) {
        (Some(port), Some(raw_ports)) =>
          match port.compass {
            Some(_) => (None : @geom.Point?)
            None =>
              match port.name {
                Some(port_name) =>
                  match raw_ports.get(port_name) {
                    Some(raw_port) =>
                      port_side_anchor_from_raw(
                        raw_port,
                        match output_sizes.get(head_name) {
                          Some(value) => value
                          None => head_size
                        },
                        head_pos,
                        tail_pos,
                        layout_rankdir,
                      )
                    None => (None : @geom.Point?)
                  }
                None => (None : @geom.Point?)
              }
          }
        _ => (None : @geom.Point?)
      }
    }
    let tail_anchor_base = match tail_side_anchor {
      Some(pos) => pos
      None => raw_tail_anchor
    }
    let head_anchor_base = match head_side_anchor {
      Some(pos) => pos
      None => raw_head_anchor
    }
    let tail_anchor = point_add(tail_anchor_base, tail_offset)
    let head_anchor = point_add(head_anchor_base, head_offset)
    let tail_clip_center = raw_tail_anchor
    let tail_clip_size = tail_anchor_size
    let head_clip_center = raw_head_anchor
    let head_clip_size = head_anchor_size
    let tail_target = match tail_port_rect {
      Some(_) => head_pos
      None => head_anchor
    }
    let head_target = match head_port_rect {
      Some(_) => tail_pos
      None => tail_anchor
    }
    let tail_slope = endpoint_slope_for_anchor(
      edge.tail_port(),
      tail_anchor,
      tail_pos,
      tail_size,
      tail_target,
      layout_rankdir,
      true,
      tail_port_rect,
    )
    let head_slope = endpoint_slope_for_anchor(
      edge.head_port(),
      head_anchor,
      head_pos,
      head_size,
      head_target,
      layout_rankdir,
      false,
      head_port_rect,
    )
    let tail_clip_target =
      if port_is_explicit(edge.tail_port()) &&
        (tail_slope.x != 0.0 || tail_slope.y != 0.0) {
        point_add(tail_clip_center, tail_slope)
      } else {
        head_anchor
      }
    let head_clip_target =
      if port_is_explicit(edge.head_port()) &&
        (head_slope.x != 0.0 || head_slope.y != 0.0) {
        point_add(head_clip_center, head_slope)
      } else {
        tail_anchor
      }
    let tail_clip = match tail_cluster_bbox {
      Some(rect) => clip_to_bbox(tail_anchor, rect, head_anchor)
      None =>
        match tail_side_anchor {
          Some(pos) => pos
          None => clip_to_rect(tail_clip_center, tail_clip_size, tail_clip_target)
        }
    }
    let head_clip = match head_cluster_bbox {
      Some(rect) => clip_to_bbox(head_anchor, rect, tail_anchor)
      None =>
        match head_side_anchor {
          Some(pos) => pos
          None => clip_to_rect(head_clip_center, head_clip_size, head_clip_target)
        }
    }
    let dir = edge_dir_for(edge, graph.kind())
    let include_tail = match dir {
      EdgeDir::Back | EdgeDir::Both => true
      _ => false
    }
    let include_head = match dir {
      EdgeDir::Forward | EdgeDir::Both => true
      _ => false
    }
    let arrow_len_override : Double? =
      if include_tail || include_head {
      if tail_cluster_bbox is Some(_) || head_cluster_bbox is Some(_) {
        let base = arrow_length_for_edge(edge)
        let span = point_dist(tail_clip, head_clip)
        let max_len = span * 0.25
        if max_len > 0.0 && max_len < base {
          Some(max_len)
        } else {
          None
        }
      } else {
        None
      }
    } else {
      None
    }
    let mut label_pad_boost = 0.0
    let spline = match splines {
      SplinesMode::None | SplinesMode::Polyline =>
        edge_spline_for_polyline(
          edge,
          tail_clip_center,
          head_clip_center,
          tail_clip_size,
          head_clip_size,
          tail_clip,
          head_clip,
          layout_rankdir,
          false,
          include_tail,
          include_head,
          arrow_len_override=arrow_len_override,
          tail_cluster_bbox=tail_cluster_bbox,
          head_cluster_bbox=head_cluster_bbox,
        )
      SplinesMode::Ortho =>
        edge_spline_for_polyline(
          edge,
          tail_clip_center,
          head_clip_center,
          tail_clip_size,
          head_clip_size,
          tail_clip,
          head_clip,
          layout_rankdir,
          true,
          include_tail,
          include_head,
          arrow_len_override=arrow_len_override,
          tail_cluster_bbox=tail_cluster_bbox,
          head_cluster_bbox=head_cluster_bbox,
        )
      _ => {
        let label_width_pt = edge_mid_label_width_pt(edge)
        let has_explicit_port =
          port_is_explicit(edge.tail_port()) || port_is_explicit(edge.head_port())
        let abs_dx = Double::abs(head_anchor.x - tail_anchor.x)
        let same_outer_cluster =
          node_cluster_key(edge.tail()) == node_cluster_key(edge.head())
        let diff_local_cluster =
          node_local_cluster_key(edge.tail()) != node_local_cluster_key(edge.head())
        let split_label = enable_complex_tuning &&
          label_width_pt > 0.0 &&
          same_outer_cluster &&
          diff_local_cluster &&
          abs_dx > label_width_pt
        if split_label {
          label_pad_boost = nodesep_pt * 1.2
        }
        let dotted_weight = if enable_complex_tuning { 1.0 } else { 0.8 }
        let guide_points = edge_polyline_points(
          edge,
          tail_anchor,
          head_anchor,
          ranks,
          vnode_info.edge_vnodes,
          vnode_info.vnode_ranks,
          vnode_positions,
          rank_y,
          rank_ht1,
          nodesep_pt,
          label_width_pt,
          dotted_weight,
          enable_complex_tuning,
          split_label,
        )
        let use_pathplan = use_pathplan
        let mut route_barriers : Array[(@geom.Point, @geom.Point)] = []
        let (points, using_pathplan) =
          if use_pathplan && has_vnodes && !is_flat_edge {
          match @routesplines.edge_pathplan_polyline(
            edge,
            tail_name,
            head_name,
            tail_anchor,
            head_anchor,
            layout_rankdir,
            ranks,
            vnode_info.vnode_ranks,
            vnode_info.edge_vnodes,
            positions,
            vnode_positions,
            sizes,
            vnode_info.vnode_sizes,
            cluster_keys,
            vnode_info.vnode_clusters,
            cluster_bboxes,
            x_groups,
            rank_y,
            rank_ht1,
            rank_ht2,
            nodesep_pt,
          ) {
            Some((path_points, barriers)) => {
              route_barriers = barriers
              (path_points, true)
            }
            None => (guide_points, false)
          }
        } else {
          (
            guide_points,
            false,
          )
        }
        let mut points = points
        let touch_eps = max_double(RECORD_BORDER_PT + 0.01, 1.5)
        let head_lr_touch =
          match head_port_rect {
            Some(rect) => {
              let node_rect = port_side_rect(head_pos, head_size)
              Double::abs(rect.llx - node_rect.llx) <= touch_eps ||
                Double::abs(rect.urx - node_rect.urx) <= touch_eps
            }
            None => false
          }
        let head_tb_touch =
          match head_port_rect {
            Some(rect) => {
              let node_rect = port_side_rect(head_pos, head_size)
              Double::abs(rect.lly - node_rect.lly) <= touch_eps ||
                Double::abs(rect.ury - node_rect.ury) <= touch_eps
            }
            None => false
          }
        let detour_ok =
          match layout_rankdir {
            RankDir::TB | RankDir::BT => head_tb_touch && !head_lr_touch
            RankDir::LR | RankDir::RL => head_lr_touch && !head_tb_touch
          }
        if points.length() <= 2 && has_explicit_port && detour_ok {
          let tail_rect = port_side_rect(tail_pos, tail_size)
          let head_rect = port_side_rect(head_pos, head_size)
          let anchor_eps = 0.02
          let needs_detour =
            segment_intersects_rect(
              tail_anchor,
              head_anchor,
              head_rect,
              anchor_eps,
            )
          if needs_detour {
            points =
              detour_polyline_for_rects(
                tail_anchor,
                head_anchor,
                tail_rect,
                head_rect,
                nodesep_pt,
                layout_rankdir,
              )
          }
        }
        let style_value = if enable_complex_tuning {
          match edge.get_attr("style") {
            Some(value) => value.to_lower()
            None => ""
          }
        } else {
          ""
        }
        let is_dotted = enable_complex_tuning && style_value.contains("dotted")
        if is_dotted && !same_outer_cluster && !using_pathplan {
          points = adjust_intercluster_dotted_points(
            points,
            tail_anchor,
            head_anchor,
            head_anchor_size,
            nodesep_pt,
          )
        }
        dot_trace_route_points(edge, points)
        let has_side_anchor =
          tail_side_anchor is Some(_) || head_side_anchor is Some(_)
        if has_explicit_port && has_side_anchor && points.length() <= 2 {
          let offset = max_double(4.0, nodesep_pt * 0.5)
          let kinked : Array[@geom.Point] = [tail_anchor]
          if tail_slope.x != 0.0 || tail_slope.y != 0.0 {
            kinked.push(point_add(tail_anchor, point_scale(tail_slope, offset)))
          }
          if head_slope.x != 0.0 || head_slope.y != 0.0 {
            kinked.push(point_add(head_anchor, point_scale(head_slope, -offset)))
          }
          kinked.push(head_anchor)
          points = kinked
        }
        let curve_offset_for = () => {
          let mut curve_offset = 0.0
          let mut curve_skew = 1.0
          if enable_complex_tuning {
            let head_port = port_key(edge.head_port())
            let key =
              if head_port == "" {
              if is_record_shape(edge.head()) { head_name } else { "" }
            } else {
              "\{head_name}:\{head_port}"
            }
            if key != "" {
              let count = match head_port_counts.get(key) {
                Some(value) => value
                None => 0
              }
              if count > 1 {
                let dx = head_anchor.x - tail_anchor.x
                let dy = head_anchor.y - tail_anchor.y
                let dist = Double::sqrt(dx * dx + dy * dy)
                let min_dist = match head_port_min_dist.get(key) {
                  Some(value) => value
                  None => dist
                }
                let max_dist = match head_port_max_dist.get(key) {
                  Some(value) => value
                  None => dist
                }
                let span = max_dist - min_dist
                if span > 0.0 {
                  let t = (dist - min_dist) / span
                  let label_factor = if label_width_pt > 0.0 { 1.0 } else { 0.5 }
                  let port_scale = if head_port == "" { 0.6 } else { 0.6 }
                  curve_offset = nodesep_pt * t * t * label_factor * port_scale
                  if head_port != "" {
                    match rankdir {
                      RankDir::TB | RankDir::BT =>
                        if dx < 0.0 {
                          curve_skew = 0.5
                        }
                      RankDir::LR | RankDir::RL =>
                        if dy < 0.0 {
                          curve_skew = 0.5
                        }
                    }
                  }
                }
              }
            }
          }
          (curve_offset, curve_skew)
        }
        let (curve_offset, curve_skew) = curve_offset_for()
        if points.length() > 2 {
          let clipped = points
          let simplify_tol = nodesep_pt * 0.8
          let tail_label_edges = match label_edge_counts.get(tail_name) {
            Some(value) => value > 1
            None => false
          }
        let keep_label_kink =
          label_width_pt > 0.0 &&
          (has_explicit_port ||
            (same_outer_cluster &&
                (abs_dx < nodesep_pt || (tail_label_edges && abs_dx < label_width_pt))))
          let simplified =
            if using_pathplan {
              clipped
            } else if enable_complex_tuning &&
              has_vnodes &&
              !split_label &&
              !keep_label_kink {
              simplify_polyline(clipped, simplify_tol)
            } else {
              clipped
            }
          let adjusted =
            if !using_pathplan && is_dotted && same_outer_cluster {
              adjust_intracluster_dotted_points(simplified)
            } else {
              simplified
            }
          if adjusted.length() <= 2 {
            let tail_slope_line =
              if port_is_explicit(edge.tail_port()) {
                tail_slope
              } else {
                point(0.0, 0.0)
              }
            let head_slope_line =
              if port_is_explicit(edge.head_port()) {
                head_slope
              } else {
                point(0.0, 0.0)
              }
            let record_port_edge =
              (is_record_shape(edge.tail()) && port_is_explicit(edge.tail_port())) ||
                (is_record_shape(edge.head()) && port_is_explicit(edge.head_port()))
            let needs_record_detour =
              !is_flat_edge &&
              record_port_edge &&
              (match layout_rankdir {
                RankDir::TB | RankDir::BT =>
                  Double::abs(tail_slope_line.x) > 0.01 ||
                    Double::abs(head_slope_line.x) > 0.01
                RankDir::LR | RankDir::RL =>
                  Double::abs(tail_slope_line.y) > 0.01 ||
                    Double::abs(head_slope_line.y) > 0.01
              })
            if needs_record_detour {
              let tail_rect = port_side_rect(tail_clip_center, tail_clip_size)
              let head_rect = port_side_rect(head_clip_center, head_clip_size)
              let detour_offset = nodesep_pt * 0.5
              let detour_points =
                match layout_rankdir {
                  RankDir::TB | RankDir::BT => {
                    let mut side = tail_clip.x - tail_clip_center.x
                    if Double::abs(side) <= 0.01 {
                      side = head_clip.x - head_clip_center.x
                    }
                    if Double::abs(side) <= 0.01 {
                      side = head_clip.x - tail_clip.x
                    }
                    let detour_x =
                      if side < 0.0 {
                        min_double(tail_rect.llx, head_rect.llx) - detour_offset
                      } else {
                        max_double(tail_rect.urx, head_rect.urx) + detour_offset
                      }
                    [
                      tail_clip,
                      point(detour_x, tail_clip.y),
                      point(detour_x, head_clip.y),
                      head_clip,
                    ]
                  }
                  RankDir::LR | RankDir::RL => {
                    let mut side = tail_clip.y - tail_clip_center.y
                    if Double::abs(side) <= 0.01 {
                      side = head_clip.y - head_clip_center.y
                    }
                    if Double::abs(side) <= 0.01 {
                      side = head_clip.y - tail_clip.y
                    }
                    let detour_y =
                      if side < 0.0 {
                        min_double(tail_rect.lly, head_rect.lly) - detour_offset
                      } else {
                        max_double(tail_rect.ury, head_rect.ury) + detour_offset
                      }
                    [
                      tail_clip,
                      point(tail_clip.x, detour_y),
                      point(head_clip.x, detour_y),
                      head_clip,
                    ]
                  }
                }
              edge_spline_for_points(
                edge,
                detour_points,
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_line,
                head_slope_line,
                true,
                include_tail,
                include_head,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
              )
            } else {
              edge_spline_for_line(
                edge,
                adjusted[0],
                adjusted[adjusted.length() - 1],
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_line,
                head_slope_line,
                include_tail,
                include_head,
                layout_rankdir,
                curve_offset,
                curve_skew,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
              )
            }
          } else {
            let tail_slope_for =
              if port_is_explicit(edge.tail_port()) {
                tail_slope
              } else {
                point(0.0, 0.0)
              }
            let head_slope_for =
              if port_is_explicit(edge.head_port()) {
                head_slope
              } else {
                point(0.0, 0.0)
              }
            let edge_force_segmented = force_segmented
            let spline =
              edge_spline_for_points(
                edge,
                adjusted,
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_for,
                head_slope_for,
                edge_force_segmented,
                include_tail,
                include_head,
                route_barriers=route_barriers,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
              )
            if is_dotted && !same_outer_cluster && spline.points.length() > 1 {
              let tuned = spline.points.copy()
              let tail_bias = 0.7
              tuned[1] = {
                x: tuned[1].x,
                y: tuned[1].y * (1.0 - tail_bias) + tail_anchor.y * tail_bias,
              }
              let head_bias = 0.7
              let last = tuned.length() - 2
              tuned[last] = {
                x: tuned[last].x,
                y: tuned[last].y * (1.0 - head_bias) + head_anchor.y * head_bias,
              }
              { start: spline.start, end: spline.end, points: tuned }
            } else {
              spline
            }
          }
        } else {
          let tail_slope_line =
            if port_is_explicit(edge.tail_port()) {
              tail_slope
            } else {
              point(0.0, 0.0)
            }
          let head_slope_line =
            if port_is_explicit(edge.head_port()) {
              head_slope
            } else {
              point(0.0, 0.0)
            }
          let record_port_edge =
            (is_record_shape(edge.tail()) && port_is_explicit(edge.tail_port())) ||
              (is_record_shape(edge.head()) && port_is_explicit(edge.head_port()))
          let needs_record_detour =
            !is_flat_edge &&
            record_port_edge &&
            (match layout_rankdir {
              RankDir::TB | RankDir::BT =>
                Double::abs(tail_slope_line.x) > 0.01 ||
                  Double::abs(head_slope_line.x) > 0.01
              RankDir::LR | RankDir::RL =>
                Double::abs(tail_slope_line.y) > 0.01 ||
                  Double::abs(head_slope_line.y) > 0.01
            })
          if needs_record_detour {
            let tail_rect = port_side_rect(tail_clip_center, tail_clip_size)
            let head_rect = port_side_rect(head_clip_center, head_clip_size)
            let detour_offset = nodesep_pt * 0.5
            let detour_points =
              match layout_rankdir {
                RankDir::TB | RankDir::BT => {
                  let mut side = tail_clip.x - tail_clip_center.x
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.x - head_clip_center.x
                  }
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.x - tail_clip.x
                  }
                  let detour_x =
                    if side < 0.0 {
                      min_double(tail_rect.llx, head_rect.llx) - detour_offset
                    } else {
                      max_double(tail_rect.urx, head_rect.urx) + detour_offset
                    }
                  [
                    tail_clip,
                    point(detour_x, tail_clip.y),
                    point(detour_x, head_clip.y),
                    head_clip,
                  ]
                }
                RankDir::LR | RankDir::RL => {
                  let mut side = tail_clip.y - tail_clip_center.y
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.y - head_clip_center.y
                  }
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.y - tail_clip.y
                  }
                  let detour_y =
                    if side < 0.0 {
                      min_double(tail_rect.lly, head_rect.lly) - detour_offset
                    } else {
                      max_double(tail_rect.ury, head_rect.ury) + detour_offset
                    }
                  [
                    tail_clip,
                    point(tail_clip.x, detour_y),
                    point(head_clip.x, detour_y),
                    head_clip,
                  ]
                }
              }
            edge_spline_for_points(
              edge,
              detour_points,
              tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_line,
              head_slope_line,
              true,
              include_tail,
              include_head,
              route_barriers=route_barriers,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
            )
          } else {
            let line_start =
              if using_pathplan && points.length() >= 2 {
                points[0]
              } else {
                tail_anchor
              }
            let line_end =
              if using_pathplan && points.length() >= 2 {
                points[points.length() - 1]
              } else {
                head_anchor
              }
            edge_spline_for_line(
              edge,
              line_start,
              line_end,
              tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_line,
              head_slope_line,
              include_tail,
              include_head,
              layout_rankdir,
              curve_offset,
              curve_skew,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
            )
          }
        }
      }
    }
    let label_rank_info = edge_label_rank_info(edge, ranks)
    let label_rank_y = edge_label_rank_y(edge, ranks, rank_y)
    let label_rank_x = match label_rank_info {
      Some((label_rank, span)) =>
        if span > 1 {
          edge_label_rank_x(
            edge,
            label_rank,
            vnode_info.vnode_ranks,
            vnode_info.edge_vnodes,
            vnode_positions,
          )
        } else {
          None
        }
      None => None
    }
    let apply_label_pad = has_clusters
    let label_pos : @geom.Point? = match edge.get_attr("label") {
      Some(value) =>
        if value == "" {
          None
        } else {
          match (label_rank_x, label_rank_y, edge_mid_label_metrics(edge)) {
            (Some(rank_x), Some(rank_y), Some((width, height))) => {
              let offset = match layout_rankdir {
                RankDir::LR | RankDir::RL => height / 2.0
                _ => width / 2.0
              }
              Some(point(rank_x + offset, rank_y))
            }
            _ =>
              if is_flat_edge {
                match edge_mid_label_metrics(edge) {
                  Some((_width, height)) => {
                    let lbl_space = 6.0
                    let left_end = tail_pos.x + tail_size.right_pt
                    let right_end = head_pos.x - head_size.left_pt
                    let ctrx = (left_end + right_end) / 2.0
                    let ctry = tail_pos.y + (height + lbl_space) / 2.0
                    Some(point(ctrx, ctry))
                  }
                  None =>
                    edge_label_pos(
                      edge,
                      spline,
                      tail_clip,
                      head_clip,
                      layout_rankdir,
                      label_rank_y,
                      label_rank_x,
                      apply_label_pad,
                      nodesep_pt,
                      label_pad_boost,
                    )
                }
              } else {
                edge_label_pos(
                  edge,
                  spline,
                  tail_clip,
                  head_clip,
                  layout_rankdir,
                  label_rank_y,
                  label_rank_x,
                  apply_label_pad,
                  nodesep_pt,
                  label_pad_boost,
                )
              }
          }
        }
      None => None
    }
    let head_label_pos : @geom.Point? = match edge.get_attr("headlabel") {
      Some(value) => if value == "" { None } else { Some(head_clip) }
      None => None
    }
    let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
      Some(value) => if value == "" { None } else { Some(tail_clip) }
      None => None
    }
  edges_out.push({
      edge,
      splines: [spline],
      label_pos,
      head_label_pos,
      tail_label_pos,
    })
  }
  dot_trace("layout_dot: edges routed")
  let base_bbox = compute_bbox(nodes_out, edges_out)
  let (final_nodes, final_edges, bbox) = if rankdir == RankDir::TB {
    (nodes_out, edges_out, base_bbox)
  } else {
    transform_layout(nodes_out, edges_out, base_bbox, rankdir)
  }
  let subgraphs = layout_subgraphs(graph, final_nodes, final_edges)
  let mut final_bbox = if subgraphs.length() > 0 {
    expand_bbox_with_subgraphs(bbox, subgraphs)
  } else {
    bbox
  }
  let (root_cluster_pad_top, root_cluster_pad_bottom) =
    if graph.is_root() && graph_has_cluster(graph) && all_ranks.length() > 0 {
    let min_rank = all_ranks[0]
    let max_rank = all_ranks[all_ranks.length() - 1]
    let mut cluster_at_min = false
    let mut cluster_at_max = false
    for node in nodes {
      let cluster_key = node_local_cluster_key(node)
      if cluster_key == "" {
        continue
      }
      match ranks.get(node.name()) {
        Some(rank) => {
          if rank == min_rank {
            cluster_at_min = true
          }
          if rank == max_rank {
            cluster_at_max = true
          }
        }
        None => ()
      }
      if cluster_at_min && cluster_at_max {
        break
      }
    }
    let pad = cluster_margin_pt(graph)
    (
      if cluster_at_min { pad } else { 0.0 },
      if cluster_at_max { pad } else { 0.0 },
    )
  } else {
    (0.0, 0.0)
  }
  if graph.is_root() && (rankdir == RankDir::TB || rankdir == RankDir::BT) {
    if port_pad_below > 0.0 || port_pad_above > 0.0 {
      final_bbox = {
        llx: final_bbox.llx,
        lly: final_bbox.lly - port_pad_below,
        urx: final_bbox.urx,
        ury: final_bbox.ury + port_pad_above,
      }
    }
  }
  let mut label_pos : @geom.Point? = None
  if graph.is_root() {
    match graph_label_metrics(graph) {
      Some((width_pt, height_pt)) => {
        let loc = graph_label_loc(graph)
        let just = graph_label_just(graph)
        final_bbox = expand_bbox_for_label(final_bbox, width_pt, height_pt, loc)
        label_pos = Some(
          graph_label_pos(final_bbox, width_pt, height_pt, loc, just),
        )
      }
      None => ()
    }
  }
  if graph.is_root() {
    let margin_x = if graph_has_cluster(graph) {
      graph_margin_x_pt(graph)
    } else {
      0.0
    }
    if margin_x > 0.0 {
      final_bbox = {
        llx: final_bbox.llx - margin_x,
        lly: final_bbox.lly,
        urx: final_bbox.urx + margin_x,
        ury: final_bbox.ury,
      }
    }
  }
  let layout = {
    graph,
    bbox: final_bbox,
    label_pos,
    nodes: final_nodes,
    edges: final_edges,
    subgraphs,
  }
  let adjusted_for_clusters =
    adjust_edge_labels_for_cluster_labels(layout, nodesep_pt)
  let adjusted = adjust_edge_labels_for_label_overlaps(
    adjusted_for_clusters,
    nodesep_pt,
    rankdir,
  )
  if graph.is_root() {
    let dx = -adjusted.bbox.llx
    let dy = -adjusted.bbox.lly
    let shifted =
      if dx != 0.0 || dy != 0.0 {
      shift_layout_graph(adjusted, dx, dy)
    } else {
      adjusted
    }
    if root_cluster_pad_top > 0.0 || root_cluster_pad_bottom > 0.0 {
      let padded = shift_layout_graph(shifted, 0.0, root_cluster_pad_bottom)
      let padded_bbox : @geom.Rect = {
        llx: shifted.bbox.llx,
        lly: shifted.bbox.lly,
        urx: shifted.bbox.urx,
        ury: shifted.bbox.ury + root_cluster_pad_bottom + root_cluster_pad_top,
      }
      let label_pos = match graph_label_metrics(graph) {
        Some((width_pt, height_pt)) => {
          let loc = graph_label_loc(graph)
          let just = graph_label_just(graph)
          Some(graph_label_pos(padded_bbox, width_pt, height_pt, loc, just))
        }
        None => padded.label_pos
      }
      {
        graph: padded.graph,
        bbox: padded_bbox,
        label_pos,
        nodes: padded.nodes,
        edges: padded.edges,
        subgraphs: padded.subgraphs,
      }
    } else {
      shifted
    }
  } else {
    adjusted
  }
}

///|
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  let mut write_bb = self.graph.is_root()
  if !write_bb {
    match self.graph.name() {
      Some(name) => if name.has_prefix("cluster") { write_bb = true }
      None => ()
    }
  }
  let record_orientation =
    record_layout_orientation(graph_rankdir(self.graph))
  if write_bb {
    self.graph.set_attr("bb", format_rect(self.bbox))
  }
  match self.label_pos {
    Some(pos) => self.graph.set_attr("lp", format_point(pos))
    None => ()
  }
  for node_layout in self.nodes {
    let node = node_layout.node
    node.set_attr("pos", format_point(node_layout.pos))
    node.set_attr("width", format_dim(node_layout.width_in))
    node.set_attr("height", format_dim(node_layout.height_in))
    if is_record_shape(node) && !@html_label.is_html_label_text(label_text(node)) {
      let size = node_size_from_points(
        node_layout.width_in * 72.0,
        node_layout.height_in * 72.0,
      )
      let rects = record_rects(
        node,
        node_layout.pos,
        size,
        record_orientation,
      )
      if rects.length() > 0 {
        node.set_attr("rects", format_rects(rects))
      }
    }
    match node_layout.label_pos {
      Some(pos) => node.set_attr("lp", format_point(pos))
      None => ()
    }
  }
  for edge_layout in self.edges {
    let edge = edge_layout.edge
    let dir = edge_dir_for(edge, self.graph.kind())
    let include_tail = match dir {
      EdgeDir::Back | EdgeDir::Both => true
      _ => false
    }
    let include_head = match dir {
      EdgeDir::Forward | EdgeDir::Both => true
      _ => false
    }
    let segments : Array[String] = []
    for spline in edge_layout.splines {
      let parts : Array[String] = []
      if include_tail {
        match spline.start {
          Some(point) => parts.push("s,\{format_point(point)}")
          None => ()
        }
      }
      if include_head {
        match spline.end {
          Some(point) => parts.push("e,\{format_point(point)}")
          None => ()
        }
      }
      for point in spline.points {
        parts.push(format_point(point))
      }
      segments.push(parts.join(" "))
    }
    let pos = segments.join(";")
    edge.set_attr("pos", pos)
    match edge_layout.label_pos {
      Some(pos) => edge.set_attr("lp", format_point(pos))
      None => ()
    }
    match edge_layout.head_label_pos {
      Some(pos) => edge.set_attr("head_lp", format_point(pos))
      None => ()
    }
    match edge_layout.tail_label_pos {
      Some(pos) => edge.set_attr("tail_lp", format_point(pos))
      None => ()
    }
  }
  for subgraph in self.subgraphs {
    subgraph.apply()
  }
}
