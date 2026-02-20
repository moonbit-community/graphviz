///|
priv struct HtmlParser {
  chars : Array[Char]
  mut index : Int
}

///|
priv enum HtmlTag {
  Start(String, Map[String, String], Bool)
  End(String)
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
const DEFAULT_BORDER_PT : Double = 1.0

///|
const DEFAULT_CELLPADDING_PT : Double = 2.0

///|
const DEFAULT_CELLSPACING_PT : Double = 2.0

///|
/// Graphviz parity: HTML table border defaults follow refs/graphviz/lib/common/htmltable.c.
/// Do not change behavior without updating fixtures/tests.
fn table_border_pt(table : HtmlTable) -> Double {
  if table.border_pt < 0.0 { DEFAULT_BORDER_PT } else { table.border_pt }
}

///|
pub fn is_html_label_text(label : String) -> Bool {
  let trimmed = label.trim(chars=" \n\r\t").to_string()
  trimmed.length() >= 3 && trimmed.has_prefix("<<") && trimmed.has_suffix(">")
}

///|
pub fn strip_html_wrappers(label : String) -> String? {
  let trimmed = label.trim(chars=" \n\r\t").to_string()
  if !is_html_label_text(trimmed) {
    return None
  }
  let len = trimmed.length()
  let inner = trimmed.unsafe_substring(start=1, end=len - 1)
  let unescaped = inner
    .replace_all(old="\\\"", new="\"")
    .replace_all(old="\\'", new="'")
  Some(unescaped)
}

///|
fn html_parser_peek(parser : HtmlParser) -> Char? {
  if parser.index < parser.chars.length() {
    Some(parser.chars[parser.index])
  } else {
    None
  }
}

///|
fn html_parser_advance(parser : HtmlParser) -> Char? {
  if parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    parser.index = parser.index + 1
    Some(ch)
  } else {
    None
  }
}

///|
fn html_parser_skip_whitespace(parser : HtmlParser) -> Unit {
  while parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    if ch.is_whitespace() {
      parser.index = parser.index + 1
    } else {
      break
    }
  }
}

///|
fn html_read_name(parser : HtmlParser) -> String {
  let sb = StringBuilder::new()
  while parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    if (ch.is_ascii_alphabetic() || ch.is_ascii_digit()) ||
      ch == '_' ||
      ch == '-' ||
      ch == ':' {
      sb.write_char(ch)
      parser.index = parser.index + 1
    } else {
      break
    }
  }
  sb.to_string().to_lower()
}

///|
fn html_read_attr_value(parser : HtmlParser) -> String {
  match html_parser_peek(parser) {
    Some('"') => {
      let _ = html_parser_advance(parser)
      let sb = StringBuilder::new()
      while parser.index < parser.chars.length() {
        let ch = parser.chars[parser.index]
        parser.index = parser.index + 1
        if ch == '"' {
          break
        }
        sb.write_char(ch)
      }
      sb.to_string()
    }
    Some('\'') => {
      let _ = html_parser_advance(parser)
      let sb = StringBuilder::new()
      while parser.index < parser.chars.length() {
        let ch = parser.chars[parser.index]
        parser.index = parser.index + 1
        if ch == '\'' {
          break
        }
        sb.write_char(ch)
      }
      sb.to_string()
    }
    _ => {
      let sb = StringBuilder::new()
      while parser.index < parser.chars.length() {
        let ch = parser.chars[parser.index]
        if ch.is_whitespace() || ch == '>' || ch == '/' {
          break
        }
        sb.write_char(ch)
        parser.index = parser.index + 1
      }
      sb.to_string()
    }
  }
}

///|
fn html_parse_tag(parser : HtmlParser) -> HtmlTag? {
  match html_parser_peek(parser) {
    Some('<') => ()
    _ => return None
  }
  let _ = html_parser_advance(parser)
  match html_parser_peek(parser) {
    Some('/') => {
      let _ = html_parser_advance(parser)
      html_parser_skip_whitespace(parser)
      let name = html_read_name(parser)
      while parser.index < parser.chars.length() {
        if parser.chars[parser.index] == '>' {
          parser.index = parser.index + 1
          break
        }
        parser.index = parser.index + 1
      }
      Some(HtmlTag::End(name))
    }
    _ => {
      let name = html_read_name(parser)
      let attrs : Map[String, String] = Map::new()
      let mut self_closing = false
      while parser.index < parser.chars.length() {
        html_parser_skip_whitespace(parser)
        match html_parser_peek(parser) {
          Some('/') => {
            self_closing = true
            let _ = html_parser_advance(parser)
            html_parser_skip_whitespace(parser)
            match html_parser_peek(parser) {
              Some('>') => {
                parser.index = parser.index + 1
                break
              }
              _ => ()
            }
          }
          Some('>') => {
            parser.index = parser.index + 1
            break
          }
          None => break
          _ => {
            let key = html_read_name(parser)
            if key == "" {
              let _ = html_parser_advance(parser)
              continue
            }
            html_parser_skip_whitespace(parser)
            match html_parser_peek(parser) {
              Some('=') => {
                let _ = html_parser_advance(parser)
                html_parser_skip_whitespace(parser)
                let value = html_read_attr_value(parser)
                attrs[key] = value
              }
              _ => attrs[key] = ""
            }
          }
        }
      }
      Some(HtmlTag::Start(name, attrs, self_closing))
    }
  }
}

///|
fn html_parse_text(parser : HtmlParser) -> String {
  let sb = StringBuilder::new()
  while parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    if ch == '<' {
      break
    }
    parser.index = parser.index + 1
    sb.write_char(ch)
  }
  sb.to_string()
}

///|
fn html_is_whitespace_only(text : String) -> Bool {
  for ch in text {
    if !ch.is_whitespace() {
      return false
    }
  }
  true
}

///|
fn html_collapse_whitespace(text : String) -> String {
  let sb = StringBuilder::new()
  let mut in_space = false
  for ch in text {
    if ch.is_whitespace() {
      if !in_space {
        sb.write_char(' ')
        in_space = true
      }
    } else {
      sb.write_char(ch)
      in_space = false
    }
  }
  let collapsed = sb.to_string()
  if html_is_whitespace_only(collapsed) {
    ""
  } else {
    let mut start = 0
    let mut end = collapsed.length()
    while start < end && collapsed[start] == ' ' {
      start = start + 1
    }
    while end > start && collapsed[end - 1] == ' ' {
      end = end - 1
    }
    if start == 0 && end == collapsed.length() {
      collapsed
    } else {
      collapsed.unsafe_substring(start~, end~)
    }
  }
}

///|
fn html_align_from(value : String?) -> HtmlAlign {
  match value {
    Some(text) =>
      match text.to_lower() {
        "left" => HtmlAlign::Left
        "right" => HtmlAlign::Right
        _ => HtmlAlign::Center
      }
    None => HtmlAlign::Center
  }
}

///|
fn html_valign_from(value : String?) -> HtmlVAlign {
  match value {
    Some(text) =>
      match text.to_lower() {
        "top" => HtmlVAlign::Top
        "bottom" => HtmlVAlign::Bottom
        _ => HtmlVAlign::Middle
      }
    None => HtmlVAlign::Middle
  }
}

///|
fn html_parse_int(value : String?, fallback : Int) -> Int {
  match value {
    Some(text) => {
      let parsed = parse_double(text, fallback.to_double()).round().to_int()
      if parsed <= 0 {
        fallback
      } else {
        parsed
      }
    }
    None => fallback
  }
}

///|
fn html_parse_double(value : String?, fallback : Double) -> Double {
  match value {
    Some(text) => parse_double(text, fallback)
    None => fallback
  }
}

///|
fn parse_html_cell_content(parser : HtmlParser) -> HtmlCellContent {
  let sb = StringBuilder::new()
  let mut nested : HtmlTable? = None
  while parser.index < parser.chars.length() {
    html_parser_skip_whitespace(parser)
    match html_parser_peek(parser) {
      Some('<') =>
        match html_parse_tag(parser) {
          Some(HtmlTag::End(name)) => if name == "td" || name == "th" { break }
          Some(HtmlTag::Start(name, attrs, _self_closing)) =>
            if name == "br" {
              sb.write_char('\n')
            } else if name == "table" {
              nested = Some(parse_html_table_from_attrs(parser, attrs))
            } else {
              // Ignore other tags.
            }
          None => {
            let text = html_parse_text(parser)
            if !html_is_whitespace_only(text) {
              sb.write_string(html_collapse_whitespace(text))
            }
          }
        }
      None => break
      _ => {
        let text = html_parse_text(parser)
        if !html_is_whitespace_only(text) {
          sb.write_string(html_collapse_whitespace(text))
        }
      }
    }
  }
  match nested {
    Some(table) => HtmlCellContent::Table(table)
    None => HtmlCellContent::Text(sb.to_string())
  }
}

///|
fn parse_html_cell_from_attrs(
  parser : HtmlParser,
  attrs : Map[String, String],
) -> HtmlCell {
  let port : String? = match attrs.get("port") {
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
  let col_span = html_parse_int(attrs.get("colspan"), 1)
  let row_span = html_parse_int(attrs.get("rowspan"), 1)
  let align = html_align_from(attrs.get("align"))
  let valign = html_valign_from(attrs.get("valign"))
  let bg_color = attrs.get("bgcolor")
  let min_width_pt = match attrs.get("width") {
    Some(value) => Some(parse_double(value, 0.0))
    None => None
  }
  let min_height_pt = match attrs.get("height") {
    Some(value) => Some(parse_double(value, 0.0))
    None => None
  }
  let content = parse_html_cell_content(parser)
  {
    content,
    port,
    col_span,
    row_span,
    align,
    valign,
    bg_color,
    min_width_pt,
    min_height_pt,
  }
}

///|
fn parse_html_row(parser : HtmlParser) -> HtmlRow {
  let cells : Array[HtmlCell] = []
  while parser.index < parser.chars.length() {
    html_parser_skip_whitespace(parser)
    match html_parser_peek(parser) {
      Some('<') =>
        match html_parse_tag(parser) {
          Some(HtmlTag::End(name)) => if name == "tr" { break }
          Some(HtmlTag::Start(name, attrs, _self_closing)) =>
            if name == "td" || name == "th" {
              cells.push(parse_html_cell_from_attrs(parser, attrs))
            } else if name == "tr" {
              break
            } else {
              // Ignore other tags.
            }
          None => {
            let _ = html_parse_text(parser)

          }
        }
      None => break
      _ => {
        let _ = html_parse_text(parser)

      }
    }
  }
  HtmlRow::{ cells, }
}

///|
fn parse_html_table_from_attrs(
  parser : HtmlParser,
  attrs : Map[String, String],
) -> HtmlTable {
  let border_pt = match attrs.get("border") {
    Some(value) => parse_double(value, DEFAULT_BORDER_PT)
    None => -1.0
  }
  let cell_border_pt = match attrs.get("cellborder") {
    Some(value) => parse_double(value, 0.0)
    None => -1.0
  }
  let cell_spacing_pt =
    html_parse_double(attrs.get("cellspacing"), DEFAULT_CELLSPACING_PT)
  let cell_padding_pt =
    html_parse_double(attrs.get("cellpadding"), DEFAULT_CELLPADDING_PT)
  let bg_color = attrs.get("bgcolor")
  let rows : Array[HtmlRow] = []
  while parser.index < parser.chars.length() {
    html_parser_skip_whitespace(parser)
    match html_parser_peek(parser) {
      Some('<') =>
        match html_parse_tag(parser) {
          Some(HtmlTag::End(name)) => if name == "table" { break }
          Some(HtmlTag::Start(name, attrs, _self_closing)) =>
            if name == "tr" {
              rows.push(parse_html_row(parser))
            } else if name == "table" {
              let _ = parse_html_table_from_attrs(parser, attrs)

            } else {
              // Ignore other tags.
            }
          None => {
            let _ = html_parse_text(parser)

          }
        }
      None => break
      _ => {
        let _ = html_parse_text(parser)

      }
    }
  }
  {
    rows,
    border_pt,
    cell_border_pt,
    cell_spacing_pt,
    cell_padding_pt,
    bg_color,
  }
}

///|
pub fn parse_html_label(label : String) -> HtmlLabel? {
  match strip_html_wrappers(label) {
    Some(value) => {
      let chars : Array[Char] = []
      for ch in value {
        chars.push(ch)
      }
      let parser = HtmlParser::{ chars, index: 0 }
      html_parser_skip_whitespace(parser)
      match html_parse_tag(parser) {
        Some(HtmlTag::Start(name, attrs, _self_closing)) =>
          if name == "table" {
            Some(HtmlLabel::Table(parse_html_table_from_attrs(parser, attrs)))
          } else if name == "br" {
            Some(HtmlLabel::Text("\n"))
          } else {
            let mut text = html_parse_text(parser)
            if html_is_whitespace_only(text) {
              text = ""
            } else {
              text = html_collapse_whitespace(text)
            }
            Some(HtmlLabel::Text(text))
          }
        _ => {
          let text = html_parse_text(parser)
          if html_is_whitespace_only(text) {
            Some(HtmlLabel::Text(""))
          } else {
            Some(HtmlLabel::Text(html_collapse_whitespace(text)))
          }
        }
      }
    }
    None => None
  }
}

///|
fn html_table_placements(
  table : HtmlTable,
) -> (Array[HtmlCellPlacement], Int, Int) {
  let placements : Array[HtmlCellPlacement] = []
  let mut col_count = 0
  let mut row_index = 0
  let row_spans : Array[Int] = []
  for row in table.rows {
    let mut col_index = 0
    for cell in row.cells {
      while col_index < row_spans.length() && row_spans[col_index] > 0 {
        col_index = col_index + 1
      }
      let needed = col_index + cell.col_span
      while row_spans.length() < needed {
        row_spans.push(0)
      }
      placements.push({ cell, row: row_index, col: col_index })
      if cell.row_span > 1 {
        for i in col_index..<needed {
          row_spans[i] = cell.row_span
        }
      }
      let end_col = col_index + cell.col_span
      if end_col > col_count {
        col_count = end_col
      }
      col_index = col_index + cell.col_span
    }
    for i in 0..<row_spans.length() {
      if row_spans[i] > 0 {
        row_spans[i] = row_spans[i] - 1
      }
    }
    row_index = row_index + 1
  }
  (placements, table.rows.length(), col_count)
}

///|
pub fn html_table_metrics(
  table : HtmlTable,
  cell_size : (HtmlCell) -> (Double, Double),
) -> HtmlTableMetrics {
  let (placements, row_count, col_count) = html_table_placements(table)
  let col_widths : Array[Double] = []
  for _ in 0..<col_count {
    col_widths.push(0.0)
  }
  let row_heights : Array[Double] = []
  for _ in 0..<row_count {
    row_heights.push(0.0)
  }
  let cell_sizes : Array[(Double, Double)] = []
  for placement in placements {
    let cell = placement.cell
    let _ = cell.align
    let _ = cell.valign
    let _ = cell.bg_color
    let _ = cell.port
    cell_sizes.push(cell_size(cell))
  }
  // Graphviz parity: set single-column widths before processing colspans.
  for i in 0..<placements.length() {
    let placement = placements[i]
    let (cell_width, _cell_height) = cell_sizes[i]
    if placement.cell.col_span <= 1 {
      let col = placement.col
      if col < col_widths.length() && cell_width > col_widths[col] {
        col_widths[col] = cell_width
      }
    }
  }
  // Graphviz parity: widen spanned columns after base widths are known.
  for i in 0..<placements.length() {
    let placement = placements[i]
    let (cell_width, _cell_height) = cell_sizes[i]
    let cell = placement.cell
    if cell.col_span <= 1 {
      continue
    }
    let start = placement.col
    let end = placement.col + cell.col_span
    let mut current = 0.0
    for j in start..<end {
      if j < col_widths.length() {
        current = current + col_widths[j]
      }
    }
    let spacing = table.cell_spacing_pt * (cell.col_span - 1).to_double()
    if cell_width > current + spacing && cell.col_span > 0 {
      let extra =
        (cell_width - spacing - current) / cell.col_span.to_double()
      for j in start..<end {
        if j < col_widths.length() {
          col_widths[j] = col_widths[j] + extra
        }
      }
    }
  }
  // Graphviz parity: set single-row heights before processing rowspans.
  for i in 0..<placements.length() {
    let placement = placements[i]
    let (_cell_width, cell_height) = cell_sizes[i]
    if placement.cell.row_span <= 1 {
      let row = placement.row
      if row < row_heights.length() && cell_height > row_heights[row] {
        row_heights[row] = cell_height
      }
    }
  }
  // Graphviz parity: heighten spanned rows after base heights are known.
  for i in 0..<placements.length() {
    let placement = placements[i]
    let (_cell_width, cell_height) = cell_sizes[i]
    let cell = placement.cell
    if cell.row_span <= 1 {
      continue
    }
    let start = placement.row
    let end = placement.row + cell.row_span
    let mut current = 0.0
    for j in start..<end {
      if j < row_heights.length() {
        current = current + row_heights[j]
      }
    }
    let spacing = table.cell_spacing_pt * (cell.row_span - 1).to_double()
    if cell_height > current + spacing && cell.row_span > 0 {
      let extra =
        (cell_height - spacing - current) / cell.row_span.to_double()
      for j in start..<end {
        if j < row_heights.length() {
          row_heights[j] = row_heights[j] + extra
        }
      }
    }
  }
  let border_pt = table_border_pt(table)
  let mut total_width = border_pt * 2.0
  let mut total_height = border_pt * 2.0
  if col_widths.length() > 0 {
    total_width = total_width +
      table.cell_spacing_pt * (col_widths.length() + 1).to_double()
    for width in col_widths {
      total_width = total_width + width
    }
  }
  if row_heights.length() > 0 {
    total_height = total_height +
      table.cell_spacing_pt * (row_heights.length() + 1).to_double()
    for height in row_heights {
      total_height = total_height + height
    }
  }
  { placements, col_widths, row_heights, total_width, total_height }
}

///|
pub fn html_table_size(
  table : HtmlTable,
  cell_size : (HtmlCell) -> (Double, Double),
) -> (Double, Double) {
  let metrics = html_table_metrics(table, cell_size)
  (metrics.total_width, metrics.total_height)
}

///|
fn round_half_up(value : Double) -> Int {
  if value >= 0.0 {
    (value + 0.5).floor().to_int()
  } else {
    (value - 0.5).ceil().to_int()
  }
}

///|
pub fn html_table_layout(
  table : HtmlTable,
  rect : @geom.Rect,
  cell_size : (HtmlCell) -> (Double, Double),
) -> HtmlTableLayout {
  let metrics = html_table_metrics(table, cell_size)
  if metrics.total_width <= 0.0 || metrics.total_height <= 0.0 {
    return { cells: [], scale_x: 1.0, scale_y: 1.0 }
  }
  let border_pt = table_border_pt(table)
  let spacing = table.cell_spacing_pt
  let mut delx = rect.urx - rect.llx - metrics.total_width
  if delx < 0.0 {
    delx = 0.0
  }
  let mut dely = rect.ury - rect.lly - metrics.total_height
  if dely < 0.0 {
    dely = 0.0
  }
  let col_count = metrics.col_widths.length()
  let row_count = metrics.row_heights.length()
  let extra_x = if col_count > 0 {
    delx / col_count.to_double()
  } else {
    0.0
  }
  let plus_x = if col_count > 0 {
    round_half_up(delx - extra_x * col_count.to_double())
  } else {
    0
  }
  let extra_y = if row_count > 0 {
    dely / row_count.to_double()
  } else {
    0.0
  }
  let plus_y = if row_count > 0 {
    round_half_up(dely - extra_y * row_count.to_double())
  } else {
    0
  }
  let col_positions : Array[(Double, Double)] = []
  let mut cursor_x = rect.llx + border_pt + spacing
  for i in 0..<metrics.col_widths.length() {
    let width = metrics.col_widths[i]
    let sized = width + extra_x + (if i < plus_x { 1.0 } else { 0.0 })
    let start = cursor_x
    let end = start + sized
    col_positions.push((start, end))
    cursor_x = end + spacing
  }
  let row_positions : Array[(Double, Double)] = []
  let mut cursor_y = rect.ury - border_pt - spacing
  for i in 0..<metrics.row_heights.length() {
    let height = metrics.row_heights[i]
    let sized = height + extra_y + (if i < plus_y { 1.0 } else { 0.0 })
    let top = cursor_y
    let bottom = top - sized
    row_positions.push((top, bottom))
    cursor_y = bottom - spacing
  }
  let cells : Array[HtmlCellLayout] = []
  for placement in metrics.placements {
    let start_col = placement.col
    let end_col = placement.col + placement.cell.col_span - 1
    let start_row = placement.row
    let end_row = placement.row + placement.cell.row_span - 1
    if start_col >= col_positions.length() || end_col >= col_positions.length() {
      continue
    }
    if start_row >= row_positions.length() || end_row >= row_positions.length() {
      continue
    }
    let llx = col_positions[start_col].0
    let urx = col_positions[end_col].1
    let ury = row_positions[start_row].0
    let lly = row_positions[end_row].1
    cells.push({ rect: { llx, lly, urx, ury }, cell: placement.cell })
  }
  { cells, scale_x: 1.0, scale_y: 1.0 }
}
