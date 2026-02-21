///|
fn assert_text_label(label : String, expected : String) -> Unit raise {
  match parse_html_label(label) {
    Some(HtmlLabel::Text(text)) => assert_eq(text, expected)
    Some(_) => fail("expected text label")
    None => fail("missing html label")
  }
}

///|
fn make_text_cell(text : String, col_span : Int, row_span : Int) -> HtmlCell {
  {
    content: HtmlCellContent::Text(text),
    port: None,
    col_span,
    row_span,
    align: HtmlAlign::Center,
    valign: HtmlVAlign::Middle,
    bg_color: None,
    min_width_pt: None,
    min_height_pt: None,
  }
}

///|
fn fixed_cell_size(_cell : HtmlCell) -> (Double, Double) {
  (10.0, 20.0)
}

///|
fn cell_size_from_min(table : HtmlTable, cell : HtmlCell) -> (Double, Double) {
  let mut width = 0.0
  let mut height = 0.0
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
fn find_cell_rect(cells : Array[HtmlCellLayout], text : String) -> @geom.Rect? {
  let mut found : @geom.Rect? = None
  for cell_layout in cells {
    match cell_layout.cell.content {
      HtmlCellContent::Text(value) =>
        if value == text {
          found = Some(cell_layout.rect)
        }
      _ => ()
    }
  }
  found
}

///|
fn row_span_table() -> HtmlTable {
  let tall = make_text_cell("Tall", 1, 2)
  let top = make_text_cell("Top", 1, 1)
  let bottom = make_text_cell("Bottom", 1, 1)
  let row0 = HtmlRow::{ cells: [tall, top] }
  let row1 = HtmlRow::{ cells: [bottom] }
  HtmlTable::{
    rows: [row0, row1],
    border_pt: 0.0,
    cell_border_pt: 0.0,
    cell_spacing_pt: 0.0,
    cell_padding_pt: 0.0,
    bg_color: None,
  }
}

///|
fn row_span_cell_size(cell : HtmlCell) -> (Double, Double) {
  match cell.content {
    HtmlCellContent::Text(text) =>
      if text == "Tall" {
        (10.0, 30.0)
      } else if text == "Top" {
        (20.0, 10.0)
      } else if text == "Bottom" {
        (20.0, 20.0)
      } else {
        (0.0, 0.0)
      }
    _ => (0.0, 0.0)
  }
}

///|
fn col_span_table() -> HtmlTable {
  let wide = make_text_cell("Wide", 2, 1)
  let left = make_text_cell("Left", 1, 1)
  let right = make_text_cell("Right", 1, 1)
  let row0 = HtmlRow::{ cells: [wide] }
  let row1 = HtmlRow::{ cells: [left, right] }
  HtmlTable::{
    rows: [row0, row1],
    border_pt: 0.0,
    cell_border_pt: 0.0,
    cell_spacing_pt: 0.0,
    cell_padding_pt: 0.0,
    bg_color: None,
  }
}

///|
fn col_span_cell_size(cell : HtmlCell) -> (Double, Double) {
  match cell.content {
    HtmlCellContent::Text(text) =>
      if text == "Wide" {
        (40.0, 10.0)
      } else if text == "Left" {
        (10.0, 20.0)
      } else if text == "Right" {
        (30.0, 20.0)
      } else {
        (0.0, 0.0)
      }
    _ => (0.0, 0.0)
  }
}

///|
test "html label unescapes quotes" {
  let label = "<<b>\\\"hi\\\"</b>>"
  match strip_html_wrappers(label) {
    Some(value) => assert_eq(value, "<b>\"hi\"</b>")
    None => fail("expected html wrapper")
  }
  assert_text_label(label, "\"hi\"")
}

///|
test "html label parses wrappers with inner whitespace" {
  let label = "<\n<table><tr><td>ok</td></tr></table>\n>"
  match parse_html_label(label) {
    Some(HtmlLabel::Table(table)) => {
      let cell = table.rows[0].cells[0]
      match cell.content {
        HtmlCellContent::Text(text) => assert_eq(text, "ok")
        _ => fail("expected text cell")
      }
    }
    _ => fail("expected table label")
  }
}

///|
test "html label parses table cell" {
  let label = "<<table><tr><td port=\"p1\">Hello</td></tr></table>>"
  match parse_html_label(label) {
    Some(HtmlLabel::Table(table)) => {
      assert_eq(table.rows.length(), 1)
      let row = table.rows[0]
      assert_eq(row.cells.length(), 1)
      let cell = row.cells[0]
      assert_eq(cell.port, Some("p1"))
      match cell.content {
        HtmlCellContent::Text(text) => assert_eq(text, "Hello")
        _ => fail("expected text cell")
      }
    }
    _ => fail("expected table label")
  }
}

///|
test "html label collapses whitespace" {
  let label = "<<b>  hello   world  </b>>"
  assert_text_label(label, "hello world")
}

///|
test "html label br creates newline" {
  let label = "<<table><tr><td>Line1<br/>Line2</td></tr></table>>"
  match parse_html_label(label) {
    Some(HtmlLabel::Table(table)) => {
      let cell = table.rows[0].cells[0]
      match cell.content {
        HtmlCellContent::Text(text) => assert_eq(text, "Line1\nLine2")
        _ => fail("expected text cell")
      }
    }
    _ => fail("expected table label")
  }
}

///|
test "html label parses nested table" {
  let label = "<<table><tr><td><table><tr><td>Inner</td></tr></table></td></tr></table>>"
  match parse_html_label(label) {
    Some(HtmlLabel::Table(table)) => {
      let cell = table.rows[0].cells[0]
      match cell.content {
        HtmlCellContent::Table(nested) => {
          assert_eq(nested.rows.length(), 1)
          let inner_cell = nested.rows[0].cells[0]
          match inner_cell.content {
            HtmlCellContent::Text(text) => assert_eq(text, "Inner")
            _ => fail("expected nested text cell")
          }
        }
        _ => fail("expected nested table")
      }
    }
    _ => fail("expected table label")
  }
}

///|
test "html label defaults spans when zero" {
  let label = "<<table><tr><td colspan=\"0\" rowspan=\"0\">Hi</td></tr></table>>"
  match parse_html_label(label) {
    Some(HtmlLabel::Table(table)) => {
      let cell = table.rows[0].cells[0]
      assert_eq(cell.col_span, 1)
      assert_eq(cell.row_span, 1)
    }
    _ => fail("expected table label")
  }
}

///|
test "html label parses sizing attributes" {
  let label = "<<table border=\"1\" cellborder=\"2\" cellpadding=\"3\" cellspacing=\"4\"><tr><td width=\"40\" height=\"50\">Hi</td></tr></table>>"
  match parse_html_label(label) {
    Some(HtmlLabel::Table(table)) => {
      assert_true(
        Double::is_close(table.border_pt, 1.0, absolute_tolerance=0.01),
      )
      assert_true(
        Double::is_close(table.cell_border_pt, 2.0, absolute_tolerance=0.01),
      )
      assert_true(
        Double::is_close(table.cell_padding_pt, 3.0, absolute_tolerance=0.01),
      )
      assert_true(
        Double::is_close(table.cell_spacing_pt, 4.0, absolute_tolerance=0.01),
      )
      let cell = table.rows[0].cells[0]
      match cell.min_width_pt {
        Some(value) =>
          assert_true(Double::is_close(value, 40.0, absolute_tolerance=0.01))
        None => fail("expected min width")
      }
      match cell.min_height_pt {
        Some(value) =>
          assert_true(Double::is_close(value, 50.0, absolute_tolerance=0.01))
        None => fail("expected min height")
      }
    }
    _ => fail("expected table label")
  }
}

///|
test "html table size includes border and spacing" {
  let cell = make_text_cell("x", 1, 1)
  let row = HtmlRow::{ cells: [cell, cell] }
  let table = HtmlTable::{
    rows: [row],
    border_pt: 1.0,
    cell_border_pt: 0.0,
    cell_spacing_pt: 2.0,
    cell_padding_pt: 0.0,
    bg_color: None,
  }
  let (width, height) = html_table_size(table, fixed_cell_size)
  assert_true(Double::is_close(width, 28.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(height, 26.0, absolute_tolerance=0.01))
}

///|
test "html table size respects colspan" {
  let cell = make_text_cell("x", 2, 1)
  let row = HtmlRow::{ cells: [cell] }
  let table = HtmlTable::{
    rows: [row],
    border_pt: 1.0,
    cell_border_pt: 0.0,
    cell_spacing_pt: 2.0,
    cell_padding_pt: 0.0,
    bg_color: None,
  }
  let cell_size = (_cell : HtmlCell) => (30.0, 20.0)
  let (width, height) = html_table_size(table, cell_size)
  assert_true(Double::is_close(width, 36.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(height, 26.0, absolute_tolerance=0.01))
}

///|
test "html table size includes padding and min size" {
  let label = "<<table border=\"1\" cellborder=\"1\" cellpadding=\"2\" cellspacing=\"0\"><tr><td width=\"40\" height=\"50\">Hi</td></tr></table>>"
  match parse_html_label(label) {
    Some(HtmlLabel::Table(table)) => {
      let (width, height) = html_table_size(table, cell => cell_size_from_min(
        table, cell,
      ))
      assert_true(Double::is_close(width, 48.0, absolute_tolerance=0.01))
      assert_true(Double::is_close(height, 58.0, absolute_tolerance=0.01))
    }
    _ => fail("expected table label")
  }
}

///|
test "html table layout scales cell rect" {
  let cell = make_text_cell("x", 1, 1)
  let row = HtmlRow::{ cells: [cell] }
  let table = HtmlTable::{
    rows: [row],
    border_pt: 0.0,
    cell_border_pt: 0.0,
    cell_spacing_pt: 0.0,
    cell_padding_pt: 0.0,
    bg_color: None,
  }
  let rect : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 20.0, ury: 40.0 }
  let layout = html_table_layout(table, rect, fixed_cell_size)
  assert_eq(layout.cells.length(), 1)
  assert_true(Double::is_close(layout.scale_x, 1.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(layout.scale_y, 1.0, absolute_tolerance=0.01))
  let cell_rect = layout.cells[0].rect
  assert_true(
    Double::is_close(cell_rect.llx, rect.llx, absolute_tolerance=0.01),
  )
  assert_true(
    Double::is_close(cell_rect.lly, rect.lly, absolute_tolerance=0.01),
  )
  assert_true(
    Double::is_close(cell_rect.urx, rect.urx, absolute_tolerance=0.01),
  )
  assert_true(
    Double::is_close(cell_rect.ury, rect.ury, absolute_tolerance=0.01),
  )
}

///|
test "html table metrics distribute rowspan heights" {
  let table = row_span_table()
  let metrics = html_table_metrics(table, row_span_cell_size)
  assert_eq(metrics.col_widths.length(), 2)
  assert_eq(metrics.row_heights.length(), 2)
  assert_true(
    Double::is_close(metrics.col_widths[0], 10.0, absolute_tolerance=0.01),
  )
  assert_true(
    Double::is_close(metrics.col_widths[1], 20.0, absolute_tolerance=0.01),
  )
  assert_true(
    Double::is_close(metrics.row_heights[0], 10.0, absolute_tolerance=0.01),
  )
  assert_true(
    Double::is_close(metrics.row_heights[1], 20.0, absolute_tolerance=0.01),
  )
  assert_true(
    Double::is_close(metrics.total_width, 30.0, absolute_tolerance=0.01),
  )
  assert_true(
    Double::is_close(metrics.total_height, 30.0, absolute_tolerance=0.01),
  )
}

///|
test "html table layout spans rows" {
  let table = row_span_table()
  let rect : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 30.0, ury: 35.0 }
  let layout = html_table_layout(table, rect, row_span_cell_size)
  match find_cell_rect(layout.cells, "Tall") {
    Some(cell_rect) => {
      assert_true(Double::is_close(cell_rect.llx, 0.0, absolute_tolerance=0.01))
      assert_true(Double::is_close(cell_rect.lly, 0.0, absolute_tolerance=0.01))
      assert_true(
        Double::is_close(cell_rect.urx, 10.0, absolute_tolerance=0.01),
      )
      assert_true(
        Double::is_close(cell_rect.ury, 35.0, absolute_tolerance=0.01),
      )
    }
    None => fail("missing Tall cell")
  }
}

///|
test "html table layout spans columns" {
  let table = col_span_table()
  let rect : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 50.0, ury: 30.0 }
  let layout = html_table_layout(table, rect, col_span_cell_size)
  match find_cell_rect(layout.cells, "Wide") {
    Some(cell_rect) => {
      assert_true(Double::is_close(cell_rect.llx, 0.0, absolute_tolerance=0.01))
      assert_true(
        Double::is_close(cell_rect.lly, 20.0, absolute_tolerance=0.01),
      )
      assert_true(
        Double::is_close(cell_rect.urx, 50.0, absolute_tolerance=0.01),
      )
      assert_true(
        Double::is_close(cell_rect.ury, 30.0, absolute_tolerance=0.01),
      )
    }
    None => fail("missing Wide cell")
  }
}
