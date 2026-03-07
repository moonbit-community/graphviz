///|
/// HTML label parsing, sizing, and port extraction helpers shared by node
/// geometry and raw label-port preparation.

type NodeSize = @node_primitives.NodeSize
type RecordPort = @record_geometry.RecordPort
type SizePt = @numeric.GraphSizePt

///|
let html_label_cache : Ref[Map[String, @html_label.HtmlLabel]] =
  @ref.new(Map::new())

///|
let html_ports_cache : Ref[Map[String, Map[String, RecordPort]]] =
  @ref.new(Map::new())

///|
pub fn reset_html_label_caches() -> Unit {
  html_label_cache.val = Map::new()
  html_ports_cache.val = Map::new()
}

///|
///|
fn html_cell_content_size(
  content : @html_label.HtmlCellContent,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  match content {
    @html_label.HtmlCellContent::Text(text) => {
      let (width_pt, height_pt) =
        @label_metrics.label_text_dimensions(text, font_name, font_size_pt)
      { width_pt, height_pt }
    }
    @html_label.HtmlCellContent::StyledText(spans) => {
      let text = StringBuilder::new()
      for span in spans {
        text.write_string(span.text)
      }
      let (width_pt, height_pt) =
        @label_metrics.label_text_dimensions(text.to_string(), font_name, font_size_pt)
      { width_pt, height_pt }
    }
    @html_label.HtmlCellContent::Table(table) => {
      html_table_size(table, font_name, font_size_pt)
    }
  }
}

///|
/// Graphviz parity: html cell border defaults to table border when cellborder is unset.
fn html_table_cell_border_pt(table : @html_label.HtmlTable) -> Double {
  if table.cell_border_pt >= 0.0 {
    table.cell_border_pt
  } else if table.border_pt >= 0.0 {
    table.border_pt
  } else {
    1.0
  }
}

///|
fn html_cell_size(
  table : @html_label.HtmlTable,
  cell : @html_label.HtmlCell,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  let content_size = html_cell_content_size(
    cell.content,
    font_name,
    font_size_pt,
  )
  let cell_border_pt = html_table_cell_border_pt(table)
  let mut width =
    content_size.width_pt + table.cell_padding_pt * 2.0 + cell_border_pt * 2.0
  let mut height =
    content_size.height_pt + table.cell_padding_pt * 2.0 + cell_border_pt * 2.0
  match cell.min_width_pt {
    Some(value) => if value > width { width = value }
    None => ()
  }
  match cell.min_height_pt {
    Some(value) => if value > height { height = value }
    None => ()
  }
  { width_pt: width, height_pt: height }
}

///|
fn html_table_size(
  table : @html_label.HtmlTable,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  let (width_pt, height_pt) =
    @html_label.html_table_size(table, cell => {
      let cell_size = html_cell_size(table, cell, font_name, font_size_pt)
      (cell_size.width_pt, cell_size.height_pt)
    })
  { width_pt, height_pt }
}

///|
fn html_table_layout(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  font_name : String,
  font_size_pt : Double,
) -> @html_label.HtmlTableLayout {
  @html_label.html_table_layout(table, rect, cell => {
    let cell_size = html_cell_size(table, cell, font_name, font_size_pt)
    (cell_size.width_pt, cell_size.height_pt)
  })
}

///|
pub fn parse_html_label_cached(label : String) -> @html_label.HtmlLabel? {
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
pub fn html_label_size(
  label : @html_label.HtmlLabel,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  match label {
    @html_label.HtmlLabel::Text(text) => {
      let (width_pt, height_pt) =
        @label_metrics.label_text_dimensions(text, font_name, font_size_pt)
      { width_pt, height_pt }
    }
    @html_label.HtmlLabel::Table(table) =>
      html_table_size(table, font_name, font_size_pt)
  }
}

///|
fn collect_html_ports(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  node_rect : @geom.Rect,
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
        let size = @node_primitives.node_size_from_points(
          cell_layout.rect.urx - cell_layout.rect.llx,
          cell_layout.rect.ury - cell_layout.rect.lly,
        )
        let sides = @port_geometry.port_side_mask_from_rects(cell_layout.rect, node_rect)
        ports[name] = { center, size, sides }
      }
      None => ()
    }
    match cell_layout.cell.content {
      @html_label.HtmlCellContent::Table(nested) =>
        collect_html_ports(
          nested,
          cell_layout.rect,
          node_rect,
          font_name,
          font_size_pt,
          ports,
        )
      _ => ()
    }
  }
}

///|
pub fn html_ports(
  node : @cgraph.Node,
  label : String,
  pos : @geom.Point,
  size : NodeSize,
) -> Map[String, RecordPort] {
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
      collect_html_ports(table, rect, rect, font, font_size_pt, ports)
    }
    _ => ()
  }
  if is_origin {
    html_ports_cache.val[node.name()] = ports
  }
  ports
}
