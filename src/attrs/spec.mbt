///|
/// Parsed style flags from the style attribute.
pub(all) struct StyleFlags {
  raw : String
  filled : Bool
  dashed : Bool
  dotted : Bool
} derive(Show, Eq)

///|
/// Parse a numeric attribute as Double with a fallback value.
#declaration_only
pub fn parse_double(value : String?, fallback : Double) -> Double {
  ...
}

///|
/// Resolve font family name with default fallback.
#declaration_only
pub fn font_name(value : String?, default? : String = "Times-Roman") -> String {
  ...
}

///|
/// Resolve font size in points with default fallback.
#declaration_only
pub fn font_size(value : String?, default? : Double = 14.0) -> Double {
  ...
}

///|
/// Resolve a color attribute with default fallback.
#declaration_only
pub fn color(value : String?, default? : String = "black") -> String {
  ...
}

///|
/// Normalize color names to hex where applicable.
#declaration_only
pub fn normalize_color(value : String) -> String {
  ...
}

///|
/// Parse style attribute into flags.
#declaration_only
pub fn parse_style(value : String?, default? : String = "solid") -> StyleFlags {
  ...
}
