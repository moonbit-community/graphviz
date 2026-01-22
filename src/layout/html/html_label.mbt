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
pub fn is_html_label_text(label : String) -> Bool {
  label.length() >= 4 && label.has_prefix("<<") && label.has_suffix(">>")
}

///|
pub fn strip_html_wrappers(label : String) -> String? {
  if !is_html_label_text(label) {
    return None
  }
  let len = label.length()
  let inner = label.unsafe_substring(start=1, end=len - 1)
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
  let border_pt = html_parse_double(attrs.get("border"), 0.0)
  let cell_border_pt = html_parse_double(attrs.get("cellborder"), 0.0)
  let cell_spacing_pt = html_parse_double(attrs.get("cellspacing"), 2.0)
  let cell_padding_pt = html_parse_double(attrs.get("cellpadding"), 2.0)
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
  let _ = table.bg_color
  for placement in placements {
    let cell = placement.cell
    let _ = cell.align
    let _ = cell.valign
    let _ = cell.bg_color
    let _ = cell.port
    let (cell_width, cell_height) = cell_size(cell)
    if cell.col_span <= 1 {
      let col = placement.col
      if col < col_widths.length() && cell_width > col_widths[col] {
        col_widths[col] = cell_width
      }
    } else {
      let start = placement.col
      let end = placement.col + cell.col_span
      let mut current = 0.0
      for i in start..<end {
        if i < col_widths.length() {
          current = current + col_widths[i]
        }
      }
      if cell_width > current && cell.col_span > 0 {
        let extra = (cell_width - current) / cell.col_span.to_double()
        for i in start..<end {
          if i < col_widths.length() {
            col_widths[i] = col_widths[i] + extra
          }
        }
      }
    }
    if cell.row_span <= 1 {
      let row = placement.row
      if row < row_heights.length() && cell_height > row_heights[row] {
        row_heights[row] = cell_height
      }
    } else {
      let start = placement.row
      let end = placement.row + cell.row_span
      let mut current = 0.0
      for i in start..<end {
        if i < row_heights.length() {
          current = current + row_heights[i]
        }
      }
      if cell_height > current && cell.row_span > 0 {
        let extra = (cell_height - current) / cell.row_span.to_double()
        for i in start..<end {
          if i < row_heights.length() {
            row_heights[i] = row_heights[i] + extra
          }
        }
      }
    }
  }
  let mut total_width = table.border_pt * 2.0
  let mut total_height = table.border_pt * 2.0
  if col_widths.length() > 0 {
    total_width = total_width +
      table.cell_spacing_pt * (col_widths.length() - 1).to_double()
    for width in col_widths {
      total_width = total_width + width
    }
  }
  if row_heights.length() > 0 {
    total_height = total_height +
      table.cell_spacing_pt * (row_heights.length() - 1).to_double()
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
pub fn html_table_layout(
  table : HtmlTable,
  rect : @geom.Rect,
  cell_size : (HtmlCell) -> (Double, Double),
) -> HtmlTableLayout {
  let metrics = html_table_metrics(table, cell_size)
  if metrics.total_width <= 0.0 || metrics.total_height <= 0.0 {
    return { cells: [], scale_x: 1.0, scale_y: 1.0 }
  }
  let scale_x = (rect.urx - rect.llx) / metrics.total_width
  let scale_y = (rect.ury - rect.lly) / metrics.total_height
  let border_x = table.border_pt * scale_x
  let border_y = table.border_pt * scale_y
  let spacing_x = table.cell_spacing_pt * scale_x
  let spacing_y = table.cell_spacing_pt * scale_y
  let col_positions : Array[(Double, Double)] = []
  let mut cursor_x = rect.llx + border_x
  for width in metrics.col_widths {
    let scaled = width * scale_x
    let start = cursor_x
    let end = start + scaled
    col_positions.push((start, end))
    cursor_x = end + spacing_x
  }
  let row_positions : Array[(Double, Double)] = []
  let mut cursor_y = rect.ury - border_y
  for height in metrics.row_heights {
    let scaled = height * scale_y
    let top = cursor_y
    let bottom = top - scaled
    row_positions.push((top, bottom))
    cursor_y = bottom - spacing_y
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
  { cells, scale_x, scale_y }
}
