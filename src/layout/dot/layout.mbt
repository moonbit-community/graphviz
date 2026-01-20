///|
priv struct NodeSize {
  width_in : Double
  height_in : Double
  width_pt : Double
  height_pt : Double
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
fn default_node_width_in() -> Double {
  0.75
}

///|
fn default_node_height_in() -> Double {
  0.5
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
fn parse_splines(value : String) -> SplinesMode? {
  match value.to_lower() {
    "true" | "spline" | "splines" => Some(SplinesMode::Spline)
    "false" | "none" | "" => Some(SplinesMode::None)
    "polyline" => Some(SplinesMode::Polyline)
    "ortho" => Some(SplinesMode::Ortho)
    "curved" => Some(SplinesMode::Curved)
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
    Some(value) => match parse_edge_dir(value) {
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
const PAD_X_PT : Double = 16.0
///|
const PAD_Y_PT : Double = 8.0

///|
fn char_width_units(ch : Char) -> Int {
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
fn label_text_dimensions(label : String, font_size_pt : Double) -> (Double, Double) {
  let mut max_units = 0
  let mut current_units = 0
  let mut lines = 1
  let mut escaping = false
  for ch in label {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        if current_units > max_units {
          max_units = current_units
        }
        current_units = 0
        lines = lines + 1
      } else {
        current_units = current_units + char_width_units(ch)
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
    } else {
      current_units = current_units + char_width_units(ch)
    }
  }
  if escaping {
    current_units = current_units + char_width_units('\\')
  }
  if current_units > max_units {
    max_units = current_units
  }
  let width_pt = max_units.to_double() * font_size_pt * TEXT_SCALE / 1000.0
  let height_pt = lines.to_double() * font_size_pt * LINE_SPACING
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
fn label_text(node : @cgraph.Node) -> String {
  match node.get_attr("label") {
    Some(value) => {
      if value == "" || value == "\\N" {
        node.name()
      } else {
        value
      }
    }
    None => node.name()
  }
}

///|
fn node_size(node : @cgraph.Node) -> NodeSize {
  let base_width_in = match node.get_attr("width") {
    Some(value) => parse_double(value, default_node_width_in())
    None => default_node_width_in()
  }
  let base_height_in = match node.get_attr("height") {
    Some(value) => parse_double(value, default_node_height_in())
    None => default_node_height_in()
  }
  let font_size_pt = match node.get_attr("fontsize") {
    Some(value) => parse_double(value, 14.0)
    None => 14.0
  }
  let label = label_text(node)
  let (text_width_pt, text_height_pt) =
    label_text_dimensions(label, font_size_pt)
  let mut pad_x_pt = PAD_X_PT
  let mut pad_y_pt = PAD_Y_PT
  match node.get_attr("margin") {
    Some(value) => {
      match parse_margin(value) {
        Some((margin_x, margin_y)) => {
          pad_x_pt = margin_x * 72.0 * 2.0
          pad_y_pt = margin_y * 72.0 * 2.0
        }
        None => ()
      }
    }
    None => ()
  }
  let has_label = text_width_pt > 0.0 || text_height_pt > 0.0
  let label_width_pt = if has_label { text_width_pt + pad_x_pt } else { 0.0 }
  let label_height_pt = if has_label { text_height_pt + pad_y_pt } else { 0.0 }
  let label_width_in = label_width_pt / 72.0
  let label_height_in = label_height_pt / 72.0
  let width_in = if label_width_in > base_width_in {
    label_width_in
  } else {
    base_width_in
  }
  let height_in = if label_height_in > base_height_in {
    label_height_in
  } else {
    base_height_in
  }
  {
    width_in,
    height_in,
    width_pt: width_in * 72.0,
    height_pt: height_in * 72.0,
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
fn ordered_nodes(graph : @cgraph.Graph) -> Array[@cgraph.Node] {
  graph.nodes()
}

///|
fn compute_ranks_directed(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> Map[String, Int] {
  let indegree : Map[String, Int] = Map::new()
  let outgoing : Map[String, Array[String]] = Map::new()
  let names : Array[String] = []
  for node in nodes {
    let name = node.name()
    indegree[name] = 0
    outgoing[name] = []
    names.push(name)
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let count = match indegree.get(head) {
      Some(value) => value
      None => 0
    }
    indegree[head] = count + 1
    match outgoing.get(tail) {
      Some(list) => list.push(head)
      None => outgoing[tail] = [head]
    }
  }
  let queue : Array[String] = []
  for name in names {
    let count = match indegree.get(name) {
      Some(value) => value
      None => 0
    }
    if count == 0 {
      queue.push(name)
    }
  }
  let ranks : Map[String, Int] = Map::new()
  let max_parent : Map[String, Int] = Map::new()
  let mut index = 0
  while index < queue.length() {
    let name = queue[index]
    index = index + 1
    let rank = match max_parent.get(name) {
      Some(value) => value
      None => 0
    }
    ranks[name] = rank
    match outgoing.get(name) {
      Some(list) => {
        for head in list {
          let remaining = match indegree.get(head) {
            Some(value) => value - 1
            None => 0
          }
          indegree[head] = remaining
          let candidate = rank + 1
          let current = match max_parent.get(head) {
            Some(value) => value
            None => 0
          }
          if candidate > current {
            max_parent[head] = candidate
          }
          if remaining == 0 {
            queue.push(head)
          }
        }
      }
      None => ()
    }
  }
  for name in names {
    if ranks.get(name) is None {
      ranks[name] = 0
    }
  }
  ranks
}

///|
fn build_edge_index(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let parents : Map[String, Array[String]] = Map::new()
  let children : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    parents[name] = []
    children[name] = []
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
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
fn median_positions(
  names : Array[String],
  x_positions : Map[String, Double],
) -> Double? {
  let values : Array[Double] = []
  for name in names {
    match x_positions.get(name) {
      Some(value) => values.push(value)
      None => ()
    }
  }
  if values.length() == 0 {
    None
  } else {
    values.sort()
    let mid = values.length() / 2
    if values.length() % 2 == 0 {
      Some((values[mid - 1] + values[mid]) / 2.0)
    } else {
      Some(values[mid])
    }
  }
}

///|
fn compute_desired_positions(
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
    match median_positions(list, x_positions) {
      Some(value) => desired[name] = value
      None => ()
    }
  }
  desired
}

///|
fn node_width_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.width_pt
    None => default_node_width_in() * 72.0
  }
}

///|
fn adjust_rank_positions(
  names : Array[String],
  x_positions : Map[String, Double],
  sizes : Map[String, NodeSize],
  desired : Map[String, Double],
  nodesep_pt : Double,
) -> Unit {
  let len = names.length()
  if len == 0 {
    return ()
  }
  let widths : Array[Double] = []
  let targets : Array[Double] = []
  let cumulative : Array[Double] = []
  let mut cum = 0.0
  for i in 0..<len {
    let name = names[i]
    let width = node_width_pt(name, sizes)
    widths.push(width)
    let fallback = match x_positions.get(name) {
      Some(value) => value
      None => width / 2.0
    }
    let target = match desired.get(name) {
      Some(value) => (value + fallback) / 2.0
      None => fallback
    }
    targets.push(target)
    if i == 0 {
      cum = 0.0
    } else {
      let prev_width = widths[i - 1]
      let sep = (prev_width + width) / 2.0 + nodesep_pt
      cum = cum + sep
    }
    cumulative.push(cum)
  }
  let block_values : Array[Double] = []
  let block_weights : Array[Int] = []
  let block_counts : Array[Int] = []
  for i in 0..<len {
    let t = targets[i] - cumulative[i]
    block_values.push(t)
    block_weights.push(1)
    block_counts.push(1)
    while block_values.length() >= 2 {
      let last = block_values.length() - 1
      let prev = last - 1
      if block_values[prev] <= block_values[last] {
        break
      }
      let weight = block_weights[prev] + block_weights[last]
      let left = block_values[prev] * block_weights[prev].to_double()
      let right = block_values[last] * block_weights[last].to_double()
      let value = (left + right) / weight.to_double()
      let count = block_counts[prev] + block_counts[last]
      block_values[prev] = value
      block_weights[prev] = weight
      block_counts[prev] = count
      let _ = block_values.pop()
      let _ = block_weights.pop()
      let _ = block_counts.pop()
    }
  }
  let y_values : Array[Double] = []
  for i in 0..<block_values.length() {
    let value = block_values[i]
    let count = block_counts[i]
    for _j in 0..<count {
      y_values.push(value)
    }
  }
  for i in 0..<len {
    let name = names[i]
    let x = y_values[i] + cumulative[i]
    x_positions[name] = x
  }
}

///|
fn normalize_x_positions(
  nodes : Array[@cgraph.Node],
  x_positions : Map[String, Double],
  sizes : Map[String, NodeSize],
) -> Unit {
  let mut min_x = 0.0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let width = node_width_pt(name, sizes)
    let pos = match x_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    let left = pos - width / 2.0
    if !seen {
      min_x = left
      seen = true
    } else if left < min_x {
      min_x = left
    }
  }
  if seen && min_x != 0.0 {
    for node in nodes {
      let name = node.name()
      match x_positions.get(name) {
        Some(value) => x_positions[name] = value - min_x
        None => ()
      }
    }
  }
}

///|
fn compute_rank_positions(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
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
    while i < names.length() {
      let name = names[i]
      let tail_width = node_width_pt(prev, sizes)
      let head_width = node_width_pt(name, sizes)
      let width = tail_width / 2.0 + head_width / 2.0 + nodesep_pt
      current = trunc_int(current.to_double() + width)
      positions[name] = current.to_double()
      prev = name
      i = i + 1
    }
  }
  positions
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
fn format_float(value : Double) -> String {
  let mut scaled = (value * 100.0).round().to_int()
  if scaled == 0 {
    return "0"
  }
  let mut sign = ""
  if scaled < 0 {
    sign = "-"
    scaled = -scaled
  }
  let int_part = scaled / 100
  let frac = scaled % 100
  if frac == 0 {
    return "\{sign}\{int_part}"
  }
  let frac_str = if frac < 10 { "0\{frac}" } else { "\{frac}" }
  "\{sign}\{int_part}.\{frac_str}"
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
fn port_key(port : @cgraph.Port?) -> String {
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
fn edge_key(edge : @cgraph.Edge) -> String {
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
      match spline.start {
        Some(point) => {
          if !bbox_set {
            min_x = point.x
            max_x = point.x
            min_y = point.y
            max_y = point.y
            bbox_set = true
          } else {
            if point.x < min_x {
              min_x = point.x
            }
            if point.x > max_x {
              max_x = point.x
            }
            if point.y < min_y {
              min_y = point.y
            }
            if point.y > max_y {
              max_y = point.y
            }
          }
        }
        None => ()
      }
      match spline.end {
        Some(point) => {
          if !bbox_set {
            min_x = point.x
            max_x = point.x
            min_y = point.y
            max_y = point.y
            bbox_set = true
          } else {
            if point.x < min_x {
              min_x = point.x
            }
            if point.x > max_x {
              max_x = point.x
            }
            if point.y < min_y {
              min_y = point.y
            }
            if point.y > max_y {
              max_y = point.y
            }
          }
        }
        None => ()
      }
      for point in spline.points {
        if !bbox_set {
          min_x = point.x
          max_x = point.x
          min_y = point.y
          max_y = point.y
          bbox_set = true
        } else {
          if point.x < min_x {
            min_x = point.x
          }
          if point.x > max_x {
            max_x = point.x
          }
          if point.y < min_y {
            min_y = point.y
          }
          if point.y > max_y {
            max_y = point.y
          }
        }
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
fn shift_optional_point(point : @geom.Point?, dx : Double, dy : Double) -> @geom.Point? {
  match point {
    Some(value) => Some(shift_point(value, dx, dy))
    None => None
  }
}

///|
fn shift_spline(spline : @geom.Spline, dx : Double, dy : Double) -> @geom.Spline {
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
      head_label_pos: transform_optional_point(edge_layout.head_label_pos, bbox, rankdir),
      tail_label_pos: transform_optional_point(edge_layout.tail_label_pos, bbox, rankdir),
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
        sub_edges.push(edge_layout)
      }
    }
    let bbox = compute_bbox(sub_nodes, sub_edges)
    let sub_subgraphs = layout_subgraphs(subgraph, nodes_out, edges_out)
    result.push({
      graph: subgraph,
      bbox,
      label_pos: None,
      nodes: sub_nodes,
      edges: sub_edges,
      subgraphs: sub_subgraphs,
    })
  }
  result
}

///|
fn spline_for_edge(
  tail : @geom.Point,
  head : @geom.Point,
  start : @geom.Point?,
  end : @geom.Point?,
) -> @geom.Spline {
  let mid_y = (tail.y + head.y) / 2.0
  let points : Array[@geom.Point] = [
    tail,
    { x: tail.x, y: mid_y },
    { x: head.x, y: mid_y },
    head,
  ]
  { start, end, points }
}

///|
pub fn DotLayoutOptions::default() -> DotLayoutOptions {
  {
    rankdir: Some(RankDir::TB),
    nodesep: Some(default_nodesep_in()),
    ranksep: Some(default_ranksep_in()),
    splines: Some(SplinesMode::Spline),
  }
}

///|
pub fn layout_dot(
  graph : @cgraph.Graph,
  options? : DotLayoutOptions = DotLayoutOptions::default(),
) -> DotLayoutGraph raise DotLayoutError {
  let opts = options
  let rankdir = match opts.rankdir {
    Some(value) => value
    None => match graph.get_attr("rankdir") {
      Some(value) => match parse_rankdir(value) {
        Some(parsed) => parsed
        None => RankDir::TB
      }
      None => RankDir::TB
    }
  }
  let nodesep_in = match opts.nodesep {
    Some(value) => value
    None => match graph.get_attr("nodesep") {
      Some(value) => parse_first_double(value, default_nodesep_in())
      None => default_nodesep_in()
    }
  }
  let ranksep_in = match opts.ranksep {
    Some(value) => value
    None => match graph.get_attr("ranksep") {
      Some(value) => parse_first_double(value, default_ranksep_in())
      None => default_ranksep_in()
    }
  }
  let splines = match opts.splines {
    Some(value) => value
    None => match graph.get_attr("splines") {
      Some(value) => match parse_splines(value) {
        Some(parsed) => parsed
        None => SplinesMode::Spline
      }
      None => SplinesMode::Spline
    }
  }
  if splines != SplinesMode::Spline {
    raise DotLayoutError::UnsupportedFeature(
      message="splines mode not supported yet",
    )
  }
  let nodes = ordered_nodes(graph)
  let edges = graph.edges()
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    sizes[node.name()] = node_size(node)
  }
  let ranks = if graph.kind() == @cgraph.GraphKind::Directed {
    compute_ranks_directed(nodes, edges)
  } else {
    let base : Map[String, Int] = Map::new()
    for node in nodes {
      base[node.name()] = 0
    }
    base
  }
  let groups = build_rank_groups(nodes, ranks)
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  let rank_heights : Map[Int, Double] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut max_height = 0.0
    for name in names {
      let size = match sizes.get(name) {
        Some(value) => value
        None => node_size(graph.node(name))
      }
      if size.height_pt > max_height {
        max_height = size.height_pt
      }
    }
    rank_heights[rank] = max_height
  }
  let nodesep_pt = nodesep_in * 72.0
  let ranksep_pt = ranksep_in * 72.0
  let y_positions : Map[String, Double] = Map::new()
  let mut total_height = 0.0
  for i in 0..<rank_keys.length() {
    let rank = rank_keys[i]
    let height = match rank_heights.get(rank) {
      Some(value) => value
      None => 0.0
    }
    total_height = total_height + height
    if i + 1 < rank_keys.length() {
      total_height = total_height + ranksep_pt
    }
  }
  let mut current_y = total_height
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let max_height = match rank_heights.get(rank) {
      Some(value) => value
      None => 0.0
    }
    let pos_y = current_y - max_height / 2.0
    for name in names {
      y_positions[name] = pos_y
    }
    current_y = current_y - max_height - ranksep_pt
  }
  let ordering = match graph.get_attr("ordering") {
    Some(value) => parse_ordering(value)
    None => None
  }
  let x_positions = compute_x_positions(
    nodes,
    edges,
    ranks,
    rank_keys,
    groups,
    sizes,
    nodesep_pt,
    ordering,
  )
  normalize_x_positions(nodes, x_positions, sizes)
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
  let nodes_out : Array[DotLayoutNode] = []
  for node in nodes {
    let name = node.name()
    let pos = match positions.get(name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size = match sizes.get(name) {
      Some(value) => value
      None => node_size(node)
    }
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
    })
  }
  let edges_out : Array[DotLayoutEdge] = []
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
      None => node_size(edge.tail())
    }
    let head_size = match sizes.get(head_name) {
      Some(value) => value
      None => node_size(edge.head())
    }
    let tail_clip = clip_to_rect(tail_pos, tail_size, head_pos)
    let head_clip = clip_to_rect(head_pos, head_size, tail_pos)
    let spline = spline_for_edge(tail_clip, head_clip, Some(tail_clip), Some(head_clip))
    let label_pos : @geom.Point? = match edge.get_attr("label") {
      Some(value) => {
        if value == "" {
          None
        } else {
          Some({ x: (tail_clip.x + head_clip.x) / 2.0, y: (tail_clip.y + head_clip.y) / 2.0 })
        }
      }
      None => None
    }
    let head_label_pos : @geom.Point? = match edge.get_attr("headlabel") {
      Some(value) => {
        if value == "" {
          None
        } else {
          Some(head_clip)
        }
      }
      None => None
    }
    let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
      Some(value) => {
        if value == "" {
          None
        } else {
          Some(tail_clip)
        }
      }
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
  let base_bbox = compute_bbox(nodes_out, edges_out)
  let (final_nodes, final_edges, bbox) = if rankdir == RankDir::TB {
    (nodes_out, edges_out, base_bbox)
  } else {
    transform_layout(nodes_out, edges_out, base_bbox, rankdir)
  }
  {
    graph,
    bbox,
    label_pos: None,
    nodes: final_nodes,
    edges: final_edges,
    subgraphs: layout_subgraphs(graph, final_nodes, final_edges),
  }
}

///|
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  let mut write_bb = self.graph.is_root()
  if !write_bb {
    match self.graph.name() {
      Some(name) => {
        if name.has_prefix("cluster") {
          write_bb = true
        }
      }
      None => ()
    }
  }
  if write_bb {
    self.graph.set_attr("bb", format_rect(self.bbox))
  }
  for node_layout in self.nodes {
    let node = node_layout.node
    node.set_attr("pos", format_point(node_layout.pos))
    node.set_attr("width", format_float(node_layout.width_in))
    node.set_attr("height", format_float(node_layout.height_in))
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
