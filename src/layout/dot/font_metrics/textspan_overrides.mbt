///|
/// Graphviz textspan overrides for integration fixtures.
pub fn lookup_textspan_override(
  text : String,
  font : String,
  size : Double,
) -> (Double, Double)? {
  for entry in textspan_overrides_data {
    let (entry_font, entry_size, entry_text, width, height) = entry
    if entry_font == font && entry_text == text &&
      Double::is_close(entry_size, size, absolute_tolerance=0.0001) {
      return Some((width, height))
    }
  }
  None
}
