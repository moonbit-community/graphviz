// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Shared HTML parsing and intrinsic dimensions for all label owners.
type SizePt = @numeric.GraphSizePt

///|
let html_label_cache : Ref[Map[(String, Bool?), @html_label.HtmlLabel]] = @ref.new(
  Map([]),
)

///|
pub fn reset_html_label_cache() -> Unit {
  html_label_cache.val = Map([])
}

///|
pub fn parse_html_label_cached(
  label : String,
  html? : Bool? = None,
) -> @html_label.HtmlLabel? {
  guard html != Some(false) else { return None }
  let key = (label, html)
  if html_label_cache.val.get(key) is Some(cached) {
    return Some(cached)
  }
  @html_label.parse_html_label(label, html~).map(parsed => {
    html_label_cache.val[key] = parsed
    parsed
  })
}

///|
fn html_cell_content_size(
  content : @html_label.HtmlCellContent,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  match content {
    @html_label.HtmlCellContent::Text(text) => {
      let (width_pt, height_pt) = label_text_dimensions(
        text, font_name, font_size_pt,
      )
      { width_pt, height_pt, }
    }
    @html_label.HtmlCellContent::StyledText(spans) => {
      let metrics = html_styled_text_metrics(spans, "", font_name, font_size_pt)
      { width_pt: metrics.width_pt, height_pt: metrics.height_pt, }
    }
    @html_label.HtmlCellContent::Table(table) =>
      html_table_size(table, font_name, font_size_pt)
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
pub fn html_cell_border_pt(
  table : @html_label.HtmlTable,
  cell : @html_label.HtmlCell,
) -> Double {
  cell.border_pt.unwrap_or(html_table_cell_border_pt(table))
}

///|
pub fn html_cell_size(
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
  let cell_border_pt = html_cell_border_pt(table, cell)
  let width = content_size.width_pt +
    table.cell_padding_pt * 2.0 +
    cell_border_pt * 2.0
  let height = content_size.height_pt +
    table.cell_padding_pt * 2.0 +
    cell_border_pt * 2.0
  {
    width_pt: Double::max(width, cell.min_width_pt.unwrap_or(width)),
    height_pt: Double::max(height, cell.min_height_pt.unwrap_or(height)),
  }
}

///|
pub fn html_table_size(
  table : @html_label.HtmlTable,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  let (width_pt, height_pt) = @html_label.html_table_size(table, cell => {
    let cell_size = html_cell_size(table, cell, font_name, font_size_pt)
    (cell_size.width_pt, cell_size.height_pt)
  })
  { width_pt, height_pt, }
}

///|
pub fn html_label_size(
  label : @html_label.HtmlLabel,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  match label {
    @html_label.HtmlLabel::StyledText(spans) => {
      let metrics = html_styled_text_metrics(spans, "", font_name, font_size_pt)
      { width_pt: metrics.width_pt, height_pt: metrics.height_pt, }
    }
    @html_label.HtmlLabel::Text(text) => {
      let (width_pt, height_pt) = label_text_dimensions(
        text, font_name, font_size_pt,
      )
      { width_pt, height_pt, }
    }
    @html_label.HtmlLabel::Table(table) =>
      html_table_size(table, font_name, font_size_pt)
  }
}
