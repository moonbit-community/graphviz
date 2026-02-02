///|
/// Graphviz textspan overrides for integration fixtures.
pub fn lookup_textspan_override(
  text : String,
  font : String,
  size : Double,
) -> (Double, Double)? {
  match lookup_textspan_metrics(text, font, size) {
    Some((width, height, _, _)) => Some((width, height))
    None => None
  }
}

///|
pub fn lookup_textspan_offsets(
  font : String,
  size : Double,
) -> (Double, Double)? {
  for entry in textspan_overrides_data {
    let (entry_font, entry_size, _entry_text, _width, _height, yoffset_layout, yoffset_centerline) =
      entry
    if entry_font == font &&
      Double::is_close(entry_size, size, absolute_tolerance=0.0001) {
      return Some((yoffset_layout, yoffset_centerline))
    }
  }
  None
}

///|
pub fn lookup_textspan_metrics(
  text : String,
  font : String,
  size : Double,
) -> (Double, Double, Double, Double)? {
  for entry in textspan_overrides_data {
    let (entry_font, entry_size, entry_text, width, height, yoffset_layout, yoffset_centerline) =
      entry
    if entry_font == font && entry_text == text &&
      Double::is_close(entry_size, size, absolute_tolerance=0.0001) {
      return Some((width, height, yoffset_layout, yoffset_centerline))
    }
  }
  None
}
