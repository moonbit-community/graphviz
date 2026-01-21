///|
/// Horizontal alignment for HTML-like labels.
pub(all) enum HtmlAlign {
  Left
  Center
  Right
} derive(Show, Eq)

///|
/// Vertical alignment for HTML-like labels.
pub(all) enum HtmlVAlign {
  Top
  Middle
  Bottom
} derive(Show, Eq)

///|
/// Cell content for HTML-like labels.
pub(all) enum HtmlCellContent {
  Text(String)
  Table(HtmlTable)
} derive(Show, Eq)

///|
/// HTML-like table cell.
pub(all) struct HtmlCell {
  content : HtmlCellContent
  port : String?
  col_span : Int
  row_span : Int
  align : HtmlAlign
  valign : HtmlVAlign
  bg_color : String?
  min_width_pt : Double?
  min_height_pt : Double?
} derive(Show, Eq)

///|
/// HTML-like table row.
pub(all) struct HtmlRow {
  cells : Array[HtmlCell]
} derive(Show, Eq)

///|
/// HTML-like table.
pub(all) struct HtmlTable {
  rows : Array[HtmlRow]
  border_pt : Double
  cell_border_pt : Double
  cell_spacing_pt : Double
  cell_padding_pt : Double
  bg_color : String?
} derive(Show, Eq)

///|
/// HTML-like label.
pub(all) enum HtmlLabel {
  Text(String)
  Table(HtmlTable)
} derive(Show, Eq)

///|
/// Table cell placement in the grid.
pub(all) struct HtmlCellPlacement {
  cell : HtmlCell
  row : Int
  col : Int
} derive(Show, Eq)

///|
/// Table metrics for layout.
pub(all) struct HtmlTableMetrics {
  placements : Array[HtmlCellPlacement]
  col_widths : Array[Double]
  row_heights : Array[Double]
  total_width : Double
  total_height : Double
} derive(Show, Eq)

///|
/// Table cell layout output.
pub(all) struct HtmlCellLayout {
  rect : @geom.Rect
  cell : HtmlCell
} derive(Show, Eq)

///|
/// Table layout output.
pub(all) struct HtmlTableLayout {
  cells : Array[HtmlCellLayout]
  scale_x : Double
  scale_y : Double
} derive(Show, Eq)

///|
/// Check if a label uses HTML-like syntax.
#declaration_only
pub fn is_html_label_text(label : String) -> Bool {
  ...
}

///|
/// Strip `<<` and `>>` wrappers from an HTML-like label.
#declaration_only
pub fn strip_html_wrappers(label : String) -> String? {
  ...
}

///|
/// Parse an HTML-like label string.
#declaration_only
pub fn parse_html_label(label : String) -> HtmlLabel? {
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
