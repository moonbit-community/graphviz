///|
/// A resolved HTML text run shared by geometry and renderers.
pub struct HtmlTextRun {
  text : String
  color : String?
  font_name : String
  font_size_pt : Double
  width_pt : Double
  height_pt : Double
  yoffset_centerline : Double
}

///|
/// A line's baseline advance follows Graphviz size_html_txt.
pub struct HtmlTextLine {
  alignment : @html_label.HtmlAlign?
  runs : Array[HtmlTextRun]
  width_pt : Double
  baseline_advance : Double
}

///|
/// Measured HTML text with baseline positions and resolved font attributes.
pub struct HtmlTextMetrics {
  lines : Array[HtmlTextLine]
  width_pt : Double
  height_pt : Double
  simple : Bool
}

///|
/// Measures each HTML run in its own font, retaining explicit line breaks.
pub fn html_styled_text_metrics(
  spans : Array[@html_label.HtmlTextSpan],
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> HtmlTextMetrics {
  let rows : Array[Array[HtmlTextRun]] = [[]]
  let alignments : Array[@html_label.HtmlAlign?] = [None]
  for span in spans {
    let font = span.font_name.unwrap_or(font_name)
    let size = span.font_size_pt.unwrap_or(font_size_pt)
    let resolved = span.text.replace_all(old="\\N", new=name)
    let parts = resolved.split("\n")
    for index, part in parts {
      if index > 0 {
        alignments[alignments.length() - 1] = span.break_alignment
        rows.push([])
        alignments.push(None)
      }
      let text = part.to_owned()
      guard text != "" else { continue }
      let (width_pt, height_pt, _, yoffset_centerline) = label_text_metrics(
        text, font, size,
      )
      rows[rows.length() - 1].push({
        text,
        color: span.color,
        font_name: font,
        font_size_pt: size,
        width_pt,
        height_pt,
        yoffset_centerline,
      })
    }
  }
  if rows.length() > 1 && rows[rows.length() - 1].length() == 0 {
    let _ = rows.pop()
    let _ = alignments.pop()
  }
  // An explicit empty line still has the enclosing font's height.
  for row in rows {
    if row.length() == 0 {
      let (_, height_pt, _, yoffset_centerline) = label_text_metrics(
        " ", font_name, font_size_pt,
      )
      row.push({
        text: "",
        color: None,
        font_name,
        font_size_pt,
        width_pt: 0.0,
        height_pt,
        yoffset_centerline,
      })
    }
  }
  let first = rows[0][0]
  let simple = rows.all(row => {
    row.length() == 1 &&
    row[0].font_name == first.font_name &&
    row[0].font_size_pt == first.font_size_pt
  })
  let lines : Array[HtmlTextLine] = []
  let mut width_pt = 0.0
  let mut height_pt = 0.0
  let mut baseline = 0.0
  for index, runs in rows {
    let mut width = 0.0
    let mut max_size = 0.0
    let mut max_height = 0.0
    let mut max_offset = 0.0
    for run in runs {
      width += run.width_pt
      if run.font_size_pt > max_size {
        max_size = run.font_size_pt
      }
      if run.height_pt > max_height {
        max_height = run.height_pt
      }
      if run.yoffset_centerline > max_offset {
        max_offset = run.yoffset_centerline
      }
    }
    let baseline_advance = if simple {
      if index == 0 {
        max_size
      } else {
        max_height
      }
    } else {
      max_size + height_pt - baseline - max_offset
    }
    baseline += baseline_advance
    height_pt += if simple || rows.length() == 1 {
      max_height
    } else {
      max_size
    }
    if width > width_pt {
      width_pt = width
    }
    lines.push({
      runs,
      width_pt: width,
      baseline_advance,
      alignment: alignments[index],
    })
  }
  { lines, width_pt, height_pt, simple, }
}
