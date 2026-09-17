// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// HTML label parsing, sizing, and port extraction helpers shared by node
/// geometry and raw label-port preparation.
type NodeSize = @node_primitives.NodeSize

///|
type RecordPort = @record_geometry.RecordPort

///|
type SizePt = @numeric.GraphSizePt

///|
let html_ports_cache : Ref[Map[String, Map[String, RecordPort]]] = @ref.new(
  Map([]),
)

///|
pub fn reset_html_label_caches() -> Unit {
  @label_metrics.reset_html_label_cache()
  html_ports_cache.val = Map([])
}

///|
fn html_table_layout(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  font_name : String,
  font_size_pt : Double,
) -> @html_label.HtmlTableLayout {
  @html_label.html_table_layout(table, rect, cell => {
    let cell_size = @label_metrics.html_cell_size(
      table, cell, font_name, font_size_pt,
    )
    (cell_size.width_pt, cell_size.height_pt)
  })
}

///|
pub fn parse_html_label_cached(
  label : String,
  html? : Bool? = None,
) -> @html_label.HtmlLabel? {
  @label_metrics.parse_html_label_cached(label, html~)
}

///|
pub fn html_label_size(
  label : @html_label.HtmlLabel,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  @label_metrics.html_label_size(label, font_name, font_size_pt)
}

///|
fn collect_html_ports(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  inherited_sides : Int,
  font_name : String,
  font_size_pt : Double,
  ports : Map[String, RecordPort],
) -> Unit {
  let dimensions = @label_metrics.html_table_size(
    table, font_name, font_size_pt,
  )
  let center_x = (rect.llx + rect.urx) / 2.0
  let center_y = (rect.lly + rect.ury) / 2.0
  let rect : @geom.Rect = {
    llx: center_x - dimensions.width_pt / 2.0,
    lly: center_y - dimensions.height_pt / 2.0,
    urx: center_x + dimensions.width_pt / 2.0,
    ury: center_y + dimensions.height_pt / 2.0,
  }
  if table.port is Some(name) {
    ports[name] = {
      center: { x: center_x, y: center_y, },
      size: @node_primitives.node_size_from_points(
        dimensions.width_pt,
        dimensions.height_pt,
      ),
      sides: inherited_sides,
    }
  }
  let layout = html_table_layout(table, rect, font_name, font_size_pt)
  for cell_layout in layout.cells {
    let cell = cell_layout.cell
    let mut sides = 0
    if cell_layout.col == 0 {
      sides = sides | @port_geometry.PORT_SIDE_LEFT
    }
    if cell_layout.row == 0 {
      sides = sides | @port_geometry.PORT_SIDE_TOP
    }
    if cell_layout.col + cell.col_span == layout.col_count {
      sides = sides | @port_geometry.PORT_SIDE_RIGHT
    }
    if cell_layout.row + cell.row_span == layout.row_count {
      sides = sides | @port_geometry.PORT_SIDE_BOTTOM
    }
    let sides = sides & inherited_sides
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
        ports[name] = { center, size, sides, }
      }
      None => ()
    }
    match cell_layout.cell.content {
      @html_label.HtmlCellContent::Table(nested) => {
        let padding = table.cell_padding_pt +
          @label_metrics.html_cell_border_pt(table, cell)
        let content_rect : @geom.Rect = {
          llx: cell_layout.rect.llx + padding,
          lly: cell_layout.rect.lly + padding,
          urx: cell_layout.rect.urx - padding,
          ury: cell_layout.rect.ury - padding,
        }
        collect_html_ports(
          nested, content_rect, sides, font_name, font_size_pt, ports,
        )
      }
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
  let ports : Map[String, RecordPort] = Map([])
  match
    parse_html_label_cached(
      label,
      html=node
        .get_attr_value("label")
        .map(value => value is @cgraph.AttrValue::Html(_)),
    ) {
    Some(@html_label.HtmlLabel::Table(table)) => {
      let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
      let font = @attrs.font_name(node.get_attr("fontname"))
      let rect : @geom.Rect = {
        llx: pos.x - size.width_pt / 2.0,
        lly: pos.y - size.height_pt / 2.0,
        urx: pos.x + size.width_pt / 2.0,
        ury: pos.y + size.height_pt / 2.0,
      }
      collect_html_ports(
        table,
        rect,
        @port_geometry.PORT_SIDE_ALL,
        font,
        font_size_pt,
        ports,
      )
    }
    _ => ()
  }
  if is_origin {
    html_ports_cache.val[node.name()] = ports
  }
  ports
}
