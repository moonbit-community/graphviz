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
    col_span: col_span,
    row_span: row_span,
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
test "html label unescapes quotes" {
  let label = "<<b>\\\"hi\\\"</b>>"
  match strip_html_wrappers(label) {
    Some(value) => assert_eq(value, "<b>\"hi\"</b>")
    None => fail("expected html wrapper")
  }
  assert_text_label(label, "\"hi\"")
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

test "html label collapses whitespace" {
  let label = "<<b>  hello   world  </b>>"
  assert_text_label(label, "hello world")
}

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

test "html label parses nested table" {
  let label =
    "<<table><tr><td><table><tr><td>Inner</td></tr></table></td></tr></table>>"
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
  assert_true(Double::is_close(width, 24.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(height, 22.0, absolute_tolerance=0.01))
}

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
  assert_true(Double::is_close(width, 34.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(height, 22.0, absolute_tolerance=0.01))
}

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
  assert_true(Double::is_close(layout.scale_x, 2.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(layout.scale_y, 2.0, absolute_tolerance=0.01))
  let cell_rect = layout.cells[0].rect
  assert_true(Double::is_close(cell_rect.llx, rect.llx, absolute_tolerance=0.01))
  assert_true(Double::is_close(cell_rect.lly, rect.lly, absolute_tolerance=0.01))
  assert_true(Double::is_close(cell_rect.urx, rect.urx, absolute_tolerance=0.01))
  assert_true(Double::is_close(cell_rect.ury, rect.ury, absolute_tolerance=0.01))
}
