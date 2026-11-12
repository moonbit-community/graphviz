// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Horizontal alignment for HTML-like labels.
#derive(Debug, Eq)
pub(all) enum HtmlAlign {
  Left
  Center
  Right
}

///|
pub extend HtmlAlign with Debug::{to_repr}

///|
pub extend HtmlAlign with Eq::{not_equal, equal}

///|
/// Vertical alignment for HTML-like labels.
#derive(Debug, Eq)
pub(all) enum HtmlVAlign {
  Top
  Middle
  Bottom
}

///|
pub extend HtmlVAlign with Debug::{to_repr}

///|
pub extend HtmlVAlign with Eq::{not_equal, equal}

///|
/// Text span for HTML-like labels.
#derive(Debug, Eq)
pub(all) struct HtmlTextSpan {
  text : String
  color : String?
  font_name : String?
  font_size_pt : Double?
  break_alignment : HtmlAlign?
}

///|
pub extend HtmlTextSpan with Debug::{to_repr}

///|
pub extend HtmlTextSpan with Eq::{not_equal, equal}

///|
/// Cell content for HTML-like labels.
#derive(Debug, Eq)
pub(all) enum HtmlCellContent {
  Text(String)
  StyledText(Array[HtmlTextSpan])
  Table(HtmlTable)
}

///|
pub extend HtmlCellContent with Debug::{to_repr}

///|
pub extend HtmlCellContent with Eq::{not_equal, equal}

///|
/// HTML-like table cell.
#derive(Debug, Eq)
pub(all) struct HtmlCell {
  href : String?
  tooltip : String?
  target : String?
  content : HtmlCellContent
  port : String?
  col_span : Int32
  row_span : Int32
  align : HtmlAlign
  valign : HtmlVAlign
  bg_color : String?
  border_pt : Double?
  style : String?
  gradient_angle : String?
  sides : String?
  vruled : Bool
  min_width_pt : Double?
  min_height_pt : Double?
}

///|
pub extend HtmlCell with Debug::{to_repr}

///|
pub extend HtmlCell with Eq::{not_equal, equal}

///|
/// HTML-like table row.
#derive(Debug, Eq)
pub(all) struct HtmlRow {
  cells : Array[HtmlCell]
  ruled : Bool
}

///|
pub extend HtmlRow with Debug::{to_repr}

///|
pub extend HtmlRow with Eq::{not_equal, equal}

///|
/// HTML-like table.
#derive(Debug, Eq)
pub(all) struct HtmlTable {
  port : String?
  href : String?
  tooltip : String?
  target : String?
  rows : Array[HtmlRow]
  border_pt : Double
  cell_border_pt : Double
  cell_spacing_pt : Double
  cell_padding_pt : Double
  bg_color : String?
  style : String?
  gradient_angle : String?
  hruled : Bool
  vruled : Bool
  rounded : Bool
}

///|
pub extend HtmlTable with Debug::{to_repr}

///|
pub extend HtmlTable with Eq::{not_equal, equal}

///|
/// HTML-like label.
#derive(Debug, Eq)
pub(all) enum HtmlLabel {
  Text(String)
  StyledText(Array[HtmlTextSpan])
  Table(HtmlTable)
}

///|
pub extend HtmlLabel with Debug::{to_repr}

///|
pub extend HtmlLabel with Eq::{not_equal, equal}

///|
/// Table cell placement in the grid.
#derive(Debug, Eq)
pub(all) struct HtmlCellPlacement {
  cell : HtmlCell
  row : Int32
  col : Int32
}

///|
pub extend HtmlCellPlacement with Debug::{to_repr}

///|
pub extend HtmlCellPlacement with Eq::{not_equal, equal}

///|
/// Table metrics for layout.
#derive(Debug, Eq)
pub(all) struct HtmlTableMetrics {
  placements : Array[HtmlCellPlacement]
  col_widths : Array[Double]
  row_heights : Array[Double]
  total_width : Double
  total_height : Double
}

///|
pub extend HtmlTableMetrics with Debug::{to_repr}

///|
pub extend HtmlTableMetrics with Eq::{not_equal, equal}

///|
/// Table cell layout output.
#derive(Debug, Eq)
pub(all) struct HtmlCellLayout {
  rect : @geom.Rect
  cell : HtmlCell
  row : Int32
  col : Int32
  hruled : Bool
}

///|
pub extend HtmlCellLayout with Debug::{to_repr}

///|
pub extend HtmlCellLayout with Eq::{not_equal, equal}

///|
/// Table layout output.
#derive(Debug, Eq)
pub(all) struct HtmlTableLayout {
  cells : Array[HtmlCellLayout]
  row_count : Int32
  col_count : Int32
  scale_x : Double
  scale_y : Double
}

///|
pub extend HtmlTableLayout with Debug::{to_repr}

///|
pub extend HtmlTableLayout with Eq::{not_equal, equal}

///|
/// Check if a label uses HTML-like syntax.
#declaration_only
pub fn is_html_label_text(label : String) -> Bool {
  ...
}

///|
/// Strip `<<` and `>>` wrappers from an HTML-like label.
#declaration_only
pub fn strip_html_wrappers(label : String, html? : Bool?) -> String? {
  ...
}

///|
/// Parse an HTML-like label string.
#declaration_only
pub fn parse_html_label(label : String, html? : Bool?) -> HtmlLabel? {
  ...
}

///|
/// Compute table metrics using the provided cell sizing callback.
#declaration_only
pub fn html_table_metrics(
  table : HtmlTable,
  cell_size : (HtmlCell) -> (Double, Double),
) -> HtmlTableMetrics {
  ...
}

///|
/// Compute the table size using the provided cell sizing callback.
#declaration_only
pub fn html_table_size(
  table : HtmlTable,
  cell_size : (HtmlCell) -> (Double, Double),
) -> (Double, Double) {
  ...
}

///|
/// Compute the table layout inside a rect using the cell sizing callback.
#declaration_only
pub fn html_table_layout(
  table : HtmlTable,
  rect : @geom.Rect,
  cell_size : (HtmlCell) -> (Double, Double),
) -> HtmlTableLayout {
  ...
}
