///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

fn parse_int(value : String, fallback : Int) -> Int {
  parse_double(value, fallback.to_double()).round().to_int()
}

fn pow10_bigint(exp : Int) -> @bigint.BigInt {
  let mut out = @bigint.BigInt::from_int(1)
  for _ in 0..<exp {
    out = out * @bigint.BigInt::from_int(10)
  }
  out
}

fn round_abs_scaled_half_even(
  abs_value : Double,
  decimals : Int,
) -> @bigint.BigInt {
  if abs_value == 0.0 {
    return @bigint.BigInt::from_int(0)
  }
  let bits = abs_value.reinterpret_as_uint64()
  let exp_bits = ((bits >> 52) & 0x7ffUL).to_int()
  let frac_mask = 0x000fffffffffffffUL
  let mantissa = bits & frac_mask
  let hidden = 0x0010000000000000UL
  let (significand, exp2) =
    if exp_bits == 0 {
      (mantissa, -1074)
    } else {
      (mantissa | hidden, exp_bits - 1075)
    }
  let mut numerator = @bigint.BigInt::from_uint64(significand)
  if decimals > 0 {
    numerator = numerator * pow10_bigint(decimals)
  }
  if exp2 >= 0 {
    return numerator << exp2
  }
  let denominator = @bigint.BigInt::from_int(1) << (-exp2)
  let quotient = numerator / denominator
  let remainder = numerator % denominator
  let doubled = remainder + remainder
  if doubled < denominator {
    return quotient
  }
  if doubled > denominator {
    return quotient + @bigint.BigInt::from_int(1)
  }
  let parity = quotient % @bigint.BigInt::from_int(2)
  if parity.is_zero() {
    quotient
  } else {
    quotient + @bigint.BigInt::from_int(1)
  }
}

fn format_scaled_integer(
  scaled_abs : @bigint.BigInt,
  decimals : Int,
  negative : Bool,
  trim_trailing_zeros : Bool,
) -> String {
  if decimals <= 0 {
    let sign = if negative && !scaled_abs.is_zero() { "-" } else { "" }
    return sign + scaled_abs.to_string()
  }
  let mut digits = scaled_abs.to_string()
  if digits.length() <= decimals {
    let padding = StringBuilder::new()
    for _ in 0..<(decimals - digits.length() + 1) {
      padding.write_char('0')
    }
    padding.write_string(digits)
    digits = padding.to_string()
  }
  let split = digits.length() - decimals
  let int_part = digits.unsafe_substring(start=0, end=split)
  let mut frac_part = digits.unsafe_substring(start=split, end=digits.length())
  if trim_trailing_zeros {
    while frac_part.length() > 0 && frac_part.has_suffix("0") {
      frac_part = frac_part.unsafe_substring(start=0, end=frac_part.length() - 1)
    }
  }
  let sign = if negative && !scaled_abs.is_zero() { "-" } else { "" }
  if frac_part == "" {
    sign + int_part
  } else {
    sign + int_part + "." + frac_part
  }
}

fn format_double_with_decimals(value : Double, decimals : Int) -> String {
  if Double::is_nan(value) || Double::is_inf(value) {
    return value.to_string()
  }
  let digits = if decimals < 0 { 0 } else { decimals }
  let negative = value < 0.0
  let abs = if negative { -value } else { value }
  let rounded = round_abs_scaled_half_even(abs, digits)
  format_scaled_integer(rounded, digits, negative, true)
}

fn format_double_fixed(value : Double, decimals : Int) -> String {
  if Double::is_nan(value) || Double::is_inf(value) {
    return value.to_string()
  }
  let digits = if decimals < 0 { 0 } else { decimals }
  let negative = value < 0.0
  let abs = if negative { -value } else { value }
  let rounded = round_abs_scaled_half_even(abs, digits)
  format_scaled_integer(rounded, digits, negative, false)
}

fn format_double_significant(value : Double, digits : Int) -> String {
  if value == 0.0 {
    return "0"
  }
  let sign = if value < 0.0 { "-" } else { "" }
  let abs = if value < 0.0 { -value } else { value }
  let exp = @math.log10(abs).floor().to_int()
  let mut decimals = digits - exp - 1
  if decimals < 0 {
    decimals = 0
  }
  let rounded = round_abs_scaled_half_even(abs, decimals)
  if rounded.is_zero() {
    return "0"
  }
  let text = format_scaled_integer(rounded, decimals, false, true)
  "\{sign}\{text}"
}

fn format_double(value : Double) -> String {
  format_double_with_decimals(value, 2)
}

///|
priv struct ArrowFlags {
  head : Bool
  tail : Bool
}

///|
const PAD_X_PT : Double = 16.0

///|
const PAD_Y_PT : Double = 8.0

///|
const DEFAULT_GRAPH_PAD_PT : Double = 4.0

///|
const RECORD_BORDER_PT : Double = 0.5

const DOUBLE_CIRCLE_GAP_PT : Double = 4.0

const POLY_GAP_PT : Double = 4.0

const ROUNDED_CORNER_RADIUS_PT : Double = 12.0

///|
const DIAGONAL_RBCONST : Double = 12.0

///|
const EMPTY_LABEL_LINE_HEIGHT_SCALE : Double = 1.2

///|
const MCIRCLE_X : Double = 0.6614

///|
const MCIRCLE_Y : Double = 0.75

const CYLINDER_RY_DIVISOR : Double = 11.0

const CYLINDER_KAPPA : Double = 0.5518

///|
fn node_attr(node : @cgraph.Node, name : String) -> String? {
  node.get_attr(name)
}

fn edge_attr(edge : @cgraph.Edge, name : String) -> String? {
  edge.get_attr(name)
}

fn nonempty_attr_value(value : String?) -> String? {
  match value {
    Some(text) => {
      let trimmed = text.trim(chars=" \n\r\t").to_string()
      if trimmed == "" { None } else { Some(trimmed) }
    }
    None => None
  }
}

fn node_attr_case_insensitive(node : @cgraph.Node, name : String) -> String? {
  let lower = name.to_lower()
  for pair in node.attrs() {
    let (key, value) = pair
    if key.to_lower() == lower {
      return Some(value)
    }
  }
  None
}

fn node_link_href(node : @cgraph.Node) -> String? {
  match nonempty_attr_value(node_attr(node, "URL")) {
    Some(value) => Some(value)
    None =>
      match nonempty_attr_value(node_attr(node, "href")) {
        Some(value) => Some(value)
        None =>
          match nonempty_attr_value(node_attr_case_insensitive(node, "url")) {
            Some(value) => Some(value)
            None => nonempty_attr_value(node_attr_case_insensitive(node, "href"))
          }
      }
  }
}

fn node_link_target(node : @cgraph.Node) -> String? {
  match nonempty_attr_value(node_attr(node, "target")) {
    Some(value) => Some(value)
    None => nonempty_attr_value(node_attr_case_insensitive(node, "target"))
  }
}

fn node_link_title(node : @cgraph.Node, fallback : String) -> String {
  match nonempty_attr_value(node_attr(node, "tooltip")) {
    Some(value) => value
    None =>
      match nonempty_attr_value(node_attr_case_insensitive(node, "tooltip")) {
        Some(value) => value
        None => fallback
      }
  }
}

fn parse_palette_index(value : String) -> Int? {
  let trimmed = value.trim().to_string()
  if trimmed == "" {
    return None
  }
  for ch in trimmed {
    if !ch.is_ascii_digit() {
      return None
    }
  }
  let index = parse_int(trimmed, 0)
  if index <= 0 { None } else { Some(index) }
}

fn slash_color_ref(value : String, colorscheme : String?) -> (String, String)? {
  if !value.has_prefix("/") {
    return None
  }
  let parts : Array[String] = []
  let mut part = StringBuilder::new()
  for ch in value {
    if ch == '/' {
      parts.push(part.to_string())
      part = StringBuilder::new()
    } else {
      part.write_char(ch)
    }
  }
  parts.push(part.to_string())
  if parts.length() < 2 || parts[0] != "" {
    return None
  }
  if parts.length() == 2 {
    let token = parts[1].trim().to_string()
    if token == "" {
      return None
    }
    return match colorscheme {
      Some(scheme) => Some((scheme.to_lower(), token))
      None => None
    }
  }
  let scheme = parts[1].trim().to_string()
  let token_parts : Array[String] = []
  for i in 2..<parts.length() {
    token_parts.push(parts[i])
  }
  let token = token_parts.join("/").trim().to_string()
  if token == "" {
    return None
  }
  if scheme == "" {
    return match colorscheme {
      Some(inherited) => Some((inherited.to_lower(), token))
      None => None
    }
  }
  Some((scheme.to_lower(), token))
}

fn colorscheme_index_color(scheme : String, index : Int) -> String? {
  match scheme.to_lower() {
    // Graphviz palette used by refs/graphviz/graphs/directed/biological.gv.
    "rdbu5" =>
      match index {
        1 => Some("#ca0020")
        2 => Some("#f4a582")
        3 => Some("#f7f7f7")
        4 => Some("#92c5de")
        5 => Some("#0571b0")
        _ => None
      }
    // Graphviz palette used by refs/graphviz/tests/graphs/colorscheme.gv.
    "spectral11" =>
      match index {
        1 => Some("#9e0142")
        2 => Some("#d53e4f")
        3 => Some("#f46d43")
        4 => Some("#fdae61")
        5 => Some("#fee08b")
        6 => Some("#ffffbf")
        7 => Some("#e6f598")
        8 => Some("#abdda4")
        9 => Some("#66c2a5")
        10 => Some("#3288bd")
        11 => Some("#5e4fa2")
        _ => None
      }
    // Graphviz palette used by refs/graphviz/tests/graphs/colorscheme.gv.
    "ylgn7" =>
      match index {
        1 => Some("#ffffcc")
        2 => Some("#d9f0a3")
        3 => Some("#addd8e")
        4 => Some("#78c679")
        5 => Some("#41ab5d")
        6 => Some("#238443")
        7 => Some("#005a32")
        _ => None
      }
    _ => None
  }
}

fn resolve_prefixed_colorscheme_color(value : String, colorscheme : String?) -> String? {
  match slash_color_ref(value, colorscheme) {
    Some((scheme, token)) =>
      match parse_palette_index(token) {
        Some(index) => colorscheme_index_color(scheme, index)
        None =>
          match scheme {
            "x11" | "svg" => Some(@attrs.normalize_color(token))
            _ => None
          }
      }
    None => None
  }
}

fn resolve_colorscheme_color(value : String, colorscheme : String?) -> String {
  let trimmed = value.trim().to_string()
  match resolve_prefixed_colorscheme_color(trimmed, colorscheme) {
    Some(mapped) => return mapped
    None => ()
  }
  match (colorscheme, parse_palette_index(trimmed)) {
    (Some(scheme), Some(index)) =>
      match colorscheme_index_color(scheme, index) {
        Some(mapped) => mapped
        None => trimmed
      }
    _ => trimmed
  }
}

fn inherited_graph_attr(graph : @cgraph.Graph, name : String) -> String? {
  let mut current = graph
  while true {
    match current.get_attr(name) {
      Some(value) => return Some(value)
      None => ()
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  None
}

fn graph_colorscheme(graph : @cgraph.Graph) -> String? {
  inherited_graph_attr(graph, "colorscheme")
}

fn graph_color(graph : @cgraph.Graph, name : String, default : String) -> String {
  let raw = @attrs.color(graph.get_attr(name), default=default)
  resolve_colorscheme_color(raw, graph_colorscheme(graph))
}

fn node_colorscheme(node : @cgraph.Node) -> String? {
  match node_attr(node, "colorscheme") {
    Some(value) => Some(value)
    None => node.graph().get_attr("colorscheme")
  }
}

fn edge_colorscheme(edge : @cgraph.Edge) -> String? {
  match edge_attr(edge, "colorscheme") {
    Some(value) => Some(value)
    None => edge.tail().graph().get_attr("colorscheme")
  }
}

fn node_color(node : @cgraph.Node, name : String, default : String) -> String {
  let raw = @attrs.color(node_attr(node, name), default=default)
  resolve_colorscheme_color(raw, node_colorscheme(node))
}

fn node_fill_color(node : @cgraph.Node, fallback : String) -> String {
  match node_attr(node, "fillcolor") {
    Some(value) => resolve_colorscheme_color(value, node_colorscheme(node))
    None => node_color(node, "color", fallback)
  }
}

fn edge_color(edge : @cgraph.Edge, name : String, default : String) -> String {
  let raw = @attrs.color(edge_attr(edge, name), default=default)
  resolve_colorscheme_color(raw, edge_colorscheme(edge))
}

priv struct SvgFontAttrs {
  family : String
  weight : String?
  stretch : String?
  style : String?
}

fn mapped_svg_font_family(base_lower : String) -> String? {
  match base_lower {
    "times" => Some("Times,serif")
    "palatino" => Some("Palatino Linotype,serif")
    "newcenturyschlbk" => Some("Century Schoolbook L,serif")
    "helvetica" => Some("Helvetica,sans-Serif")
    "courier" => Some("Courier,monospace")
    "bookman" => Some("URW Bookman L,serif")
    "avantgarde" => Some("URW Gothic L,sans-Serif")
    "zapfchancery" => Some("URW Chancery L,serif")
    "zapfdingbats" => Some("Dingbats,fantasy")
    "symbol" => Some("Symbol,fantasy")
    _ => None
  }
}

fn svg_font_attrs(font_name : String) -> SvgFontAttrs {
  let parts : Array[String] = []
  for part in font_name.split("-") {
    parts.push(part.to_string())
  }
  if parts.length() == 0 {
    return { family: font_name, weight: None, stretch: None, style: None }
  }
  let base_lower = parts[0].to_lower()
  let family = match mapped_svg_font_family(base_lower) {
    Some(mapped) => mapped
    None => {
      let lower = font_name.to_lower()
      if lower == "times-roman" || lower == "times" {
        "Times,serif"
      } else {
        return { family: font_name, weight: None, stretch: None, style: None }
      }
    }
  }
  let mut weight : String? = None
  let mut stretch : String? = None
  let mut style : String? = None
  let mut has_unknown = false
  for i in 1..<parts.length() {
    let token = parts[i].to_lower()
    match token {
      "bold" => weight = Some("bold")
      "demi" => weight = Some("demi")
      "light" => weight = Some("light")
      "book" => weight = Some("book")
      "medium" => weight = Some("medium")
      "roman" =>
        if base_lower != "times" {
          weight = Some("roman")
        }
      "italic" => style = Some("italic")
      "oblique" => style = Some("oblique")
      "narrow" => stretch = Some("condensed")
      "bolditalic" => {
        weight = Some("bold")
        style = Some("italic")
      }
      "boldoblique" => {
        weight = Some("bold")
        style = Some("oblique")
      }
      "lightitalic" => {
        weight = Some("light")
        style = Some("italic")
      }
      "bookoblique" => {
        weight = Some("book")
        style = Some("oblique")
      }
      "demiitalic" => {
        weight = Some("demi")
        style = Some("italic")
      }
      "demioblique" => {
        weight = Some("demi")
        style = Some("oblique")
      }
      "mediumitalic" => {
        weight = Some("medium")
        style = Some("italic")
      }
      _ => has_unknown = true
    }
  }
  if has_unknown {
    return { family: font_name, weight: None, stretch: None, style: None }
  }
  { family, weight, stretch, style }
}

fn svg_text_font_attrs(font_name : String) -> String {
  let attrs = svg_font_attrs(font_name)
  let sb = StringBuilder::new()
  sb.write_string(" font-family=\"")
  sb.write_string(attrs.family)
  sb.write_char('"')
  match attrs.weight {
    Some(value) => {
      sb.write_string(" font-weight=\"")
      sb.write_string(value)
      sb.write_char('"')
    }
    None => ()
  }
  match attrs.stretch {
    Some(value) => {
      sb.write_string(" font-stretch=\"")
      sb.write_string(value)
      sb.write_char('"')
    }
    None => ()
  }
  match attrs.style {
    Some(value) => {
      sb.write_string(" font-style=\"")
      sb.write_string(value)
      sb.write_char('"')
    }
    None => ()
  }
  sb.to_string()
}

///|
fn is_svg_named_color(color : String) -> Bool {
  match color {
    "black" | "white" | "none" | "red" | "green" | "blue" | "yellow" |
    "orange" | "gold" | "cyan" | "magenta" | "pink" | "hotpink" |
    "purple" | "lightblue" | "lightgrey" | "lightgray" | "grey" | "gray" |
    "slateblue" | "greenyellow" | "darkseagreen" | "deepskyblue" |
    "skyblue" |
    "blanchedalmond" | "chocolate" | "crimson" | "navy" | "coral" |
    "steelblue" | "aquamarine" | "limegreen" |
    "lemonchiffon" | "firebrick" | "orangered" | "indigo" | "indianred" => true
    _ => false
  }
}

///|
fn svg_color(color : String) -> String {
  let lower = color.to_lower()
  if lower.has_prefix("#") {
    lower
  } else if is_svg_named_color(lower) {
    lower
  } else {
    let normalized = @attrs.normalize_color(lower)
    if normalized.has_prefix("#") || is_svg_named_color(normalized) {
      normalized
    } else {
      "#000000"
    }
  }
}

///|
fn hex_nibble(ch : Char) -> Int {
  match ch {
    '0'..='9' => ch.to_int() - '0'.to_int()
    'a'..='f' => ch.to_int() - 'a'.to_int() + 10
    'A'..='F' => ch.to_int() - 'A'.to_int() + 10
    _ => -1
  }
}

///|
fn parse_hex8_color(color : String) -> (String, Int)? {
  if color.length() != 9 || !color.has_prefix("#") {
    return None
  }
  let chars : Array[Char] = []
  for ch in color {
    chars.push(ch)
  }
  if chars.length() != 9 {
    return None
  }
  for i in 1..<9 {
    if hex_nibble(chars[i]) < 0 {
      return None
    }
  }
  let alpha = hex_nibble(chars[7]) * 16 + hex_nibble(chars[8])
  Some((color.unsafe_substring(start=0, end=7), alpha))
}

///|
fn alpha_opacity_text(alpha_byte : Int) -> String {
  format_double_fixed(alpha_byte.to_double() / 255.0, 6)
}

///|
fn rewrite_svg_alpha_attr(
  svg : String,
  attr_name : String,
  opacity_attr_name : String,
) -> String {
  let attr_prefix = "\{attr_name}=\""
  let mut remaining = svg
  let out = StringBuilder::new()
  while true {
    match remaining.find(attr_prefix) {
      None => {
        out.write_string(remaining)
        break
      }
      Some(pos) => {
        if pos > 0 {
          out.write_string(remaining.unsafe_substring(start=0, end=pos))
        }
        let value_start = pos + attr_prefix.length()
        if value_start >= remaining.length() {
          out.write_string(remaining.unsafe_substring(start=pos, end=remaining.length()))
          break
        }
        let tail =
          remaining.unsafe_substring(start=value_start, end=remaining.length())
        match tail.find("\"") {
          None => {
            out.write_string(remaining.unsafe_substring(start=pos, end=remaining.length()))
            break
          }
          Some(value_end) => {
            let value = tail.unsafe_substring(start=0, end=value_end)
            let segment_end = value_start + value_end + 1
            match parse_hex8_color(value) {
              Some((base_color, alpha_byte)) => {
                out.write_string(attr_prefix)
                if alpha_byte <= 0 {
                  out.write_string("none\"")
                } else if alpha_byte >= 255 {
                  out.write_string(base_color)
                  out.write_char('"')
                } else {
                  out.write_string(base_color)
                  out.write_char('"')
                  out.write_string(
                    " \{opacity_attr_name}=\"\{alpha_opacity_text(alpha_byte)}\"",
                  )
                }
              }
              None => {
                out.write_string(
                  remaining.unsafe_substring(start=pos, end=segment_end),
                )
              }
            }
            remaining = if segment_end < remaining.length() {
              remaining.unsafe_substring(start=segment_end, end=remaining.length())
            } else {
              ""
            }
          }
        }
      }
    }
  }
  out.to_string()
}

///|
fn normalize_svg_alpha_attrs(svg : String) -> String {
  let with_fill = rewrite_svg_alpha_attr(svg, "fill", "fill-opacity")
  rewrite_svg_alpha_attr(with_fill, "stroke", "stroke-opacity")
}

///|
priv struct LabelLine {
  text : String
  align : @render.TextAlign
  width_pt : Double
  height_pt : Double
  yoffset_centerline : Double
}

///|
priv struct RawLabelLine {
  text : String
  align : @render.TextAlign
}

///|
fn push_label_line(
  lines : Array[RawLabelLine],
  text : String,
  align : @render.TextAlign,
) -> Unit {
  lines.push({ text, align })
}

///|
fn label_lines(label : String) -> Array[RawLabelLine] {
  let lines : Array[RawLabelLine] = []
  let mut sb = StringBuilder::new()
  let mut has_chars = false
  let mut escaping = false
  for ch in label {
    if escaping {
      escaping = false
      match ch {
        'n' => {
          push_label_line(
            lines,
            sb.to_string(),
            @render.TextAlign::Center,
          )
          sb = StringBuilder::new()
          has_chars = false
        }
        'l' => {
          push_label_line(
            lines,
            sb.to_string(),
            @render.TextAlign::Left,
          )
          sb = StringBuilder::new()
          has_chars = false
        }
        'r' => {
          push_label_line(
            lines,
            sb.to_string(),
            @render.TextAlign::Right,
          )
          sb = StringBuilder::new()
          has_chars = false
        }
        _ => {
          sb.write_char(ch)
          has_chars = true
        }
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      push_label_line(
        lines,
        sb.to_string(),
        @render.TextAlign::Center,
      )
      sb = StringBuilder::new()
      has_chars = false
      continue
    }
    sb.write_char(ch)
    has_chars = true
  }
  if escaping {
    sb.write_char('\\')
    has_chars = true
  }
  if has_chars || lines.length() == 0 {
    push_label_line(
      lines,
      sb.to_string(),
      @render.TextAlign::Center,
    )
  }
  lines
}

///|
fn label_metrics(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Array[LabelLine], Double, Double) {
  let raw_lines = label_lines(label)
  let lines : Array[LabelLine] = []
  let mut max_width = 0.0
  let mut total_height = 0.0
  for line in raw_lines {
    let metrics_text = if line.text == "" { " " } else { line.text }
    let (width_pt, raw_height_pt, _yoffset_layout, yoffset_centerline) =
      @layout_dot.label_text_metrics(
        metrics_text,
        font_name,
        font_size_pt,
      )
    let height_pt = if line.text == "" {
      font_size_pt * EMPTY_LABEL_LINE_HEIGHT_SCALE
    } else {
      raw_height_pt
    }
    let width_pt = if line.text == "" { 0.0 } else { width_pt }
    if width_pt > max_width {
      max_width = width_pt
    }
    total_height = total_height + height_pt
    lines.push({
      text: line.text,
      align: line.align,
      width_pt,
      height_pt,
      yoffset_centerline,
    })
  }
  (lines, max_width, total_height)
}

///|
fn record_label_lines(label : String) -> Array[RawLabelLine] {
  let lines : Array[RawLabelLine] = []
  let mut sb = StringBuilder::new()
  let mut escaping = false
  let mut has_chars = false
  for ch in label {
    if escaping {
      escaping = false
      match ch {
        'n' | 'l' | 'r' => {
          let align = match ch {
            'l' => @render.TextAlign::Left
            'r' => @render.TextAlign::Right
            _ => @render.TextAlign::Center
          }
          push_label_line(
            lines,
            sb.to_string(),
            align,
          )
          sb = StringBuilder::new()
          has_chars = false
        }
        _ => {
          sb.write_char(ch)
          has_chars = true
        }
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      push_label_line(
        lines,
        sb.to_string(),
        @render.TextAlign::Center,
      )
      sb = StringBuilder::new()
      has_chars = false
      continue
    }
    sb.write_char(ch)
    has_chars = true
  }
  if escaping {
    sb.write_char('\\')
    has_chars = true
  }
  if has_chars || lines.length() == 0 {
    push_label_line(
      lines,
      sb.to_string(),
      @render.TextAlign::Center,
    )
  }
  lines
}

///|
fn record_label_metrics(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Array[LabelLine], Double, Double) {
  let raw_lines = record_label_lines(label)
  let lines : Array[LabelLine] = []
  let mut max_width = 0.0
  let mut total_height = 0.0
  for line in raw_lines {
    let metrics_text = if line.text == "" { " " } else { line.text }
    let (width_pt, base_height_pt) =
      @layout_dot.record_label_text_dimensions(
        metrics_text,
        font_name,
        font_size_pt,
      )
    let (_w, layout_height_pt, _yoffset_layout, yoffset_centerline) =
      @layout_dot.label_text_metrics(
        metrics_text,
        font_name,
        font_size_pt,
      )
    let width_pt = if line.text == "" { 0.0 } else { width_pt }
    let height_pt = if line.text == "" {
      layout_height_pt
    } else {
      base_height_pt
    }
    if width_pt > max_width {
      max_width = width_pt
    }
    total_height = total_height + height_pt
    lines.push({
      text: line.text,
      align: line.align,
      width_pt,
      height_pt,
      yoffset_centerline,
    })
  }
  (lines, max_width, total_height)
}

///|
fn extract_numbers(value : String) -> Array[Double] {
  let sb = StringBuilder::new()
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
    } else {
      sb.write_char(' ')
    }
  }
  let normalized = sb.to_string()
  let numbers : Array[Double] = []
  for token in normalized.split(" ") {
    if token.length() == 0 {
      continue
    }
    numbers.push(parse_double(token.to_string(), 0.0))
  }
  numbers
}

///|
fn parse_margin(value : String) -> (Double, Double)? {
  let numbers = extract_numbers(value)
  if numbers.length() == 0 {
    return None
  }
  if numbers.length() == 1 {
    let val = if numbers[0] < 0.0 { 0.0 } else { numbers[0] }
    return Some((val, val))
  }
  let x = if numbers[0] < 0.0 { 0.0 } else { numbers[0] }
  let y = if numbers[1] < 0.0 { 0.0 } else { numbers[1] }
  Some((x, y))
}

///|
fn stroke_dash_attr(style : @attrs.StyleFlags) -> String {
  if style.dashed {
    " stroke-dasharray=\"5,2\""
  } else if style.dotted {
    " stroke-dasharray=\"1,5\""
  } else {
    ""
  }
}

fn svg_style_tokens(raw : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut current = StringBuilder::new()
  let mut seen = false
  for ch in raw {
    if ch == ',' || ch.is_whitespace() {
      if seen {
        tokens.push(current.to_string())
        current = StringBuilder::new()
        seen = false
      }
    } else {
      current.write_char(ch)
      seen = true
    }
  }
  if seen {
    tokens.push(current.to_string())
  }
  tokens
}

fn style_has_token(style : @attrs.StyleFlags, name : String) -> Bool {
  for token in svg_style_tokens(style.raw) {
    if token == name {
      return true
    }
  }
  false
}

fn style_is_invisible(style : @attrs.StyleFlags) -> Bool {
  style_has_token(style, "invis")
}

fn style_linewidth(style : @attrs.StyleFlags) -> Double? {
  let mut is_bold = false
  for token in svg_style_tokens(style.raw) {
    if token == "bold" {
      is_bold = true
      continue
    }
    if token.has_prefix("setlinewidth(") && token.has_suffix(")") {
      let width_text =
        token.unsafe_substring(start=13, end=token.length() - 1)
      let width = @attrs.parse_double(Some(width_text), 1.0)
      if width > 0.0 {
        return Some(width)
      }
    }
  }
  if is_bold {
    Some(2.0)
  } else {
    None
  }
}

fn is_default_linewidth(width : Double) -> Bool {
  width >= 0.999999 && width <= 1.000001
}

fn stroke_width_value(
  style : @attrs.StyleFlags,
  penwidth : String?,
) -> Double? {
  let parsed = @attrs.parse_double(penwidth, 1.0)
  let width =
    if parsed > 0.0 && !is_default_linewidth(parsed) {
      parsed
    } else {
      match style_linewidth(style) {
        Some(value) => if value > 0.0 { value } else { 1.0 }
        None => 1.0
      }
    }
  if is_default_linewidth(width) { None } else { Some(width) }
}

fn stroke_width_attr(
  style : @attrs.StyleFlags,
  penwidth : String?,
) -> String {
  match stroke_width_value(style, penwidth) {
    Some(value) => " stroke-width=\"\{format_double(value)}\""
    None => ""
  }
}

///|
fn resolve_label(text : String, name : String) -> String {
  let with_name = text.replace_all(old="\\N", new=name)
  with_name.replace_all(old="\\n", new="\n")
}

fn resolve_record_label(text : String, name : String) -> String {
  text.replace_all(old="\\N", new=name)
}

///|
fn label_text(value : String?, fallback : String) -> String {
  match value {
    Some(text) => resolve_label(text, fallback)
    None => fallback
  }
}

fn record_label_text(value : String?, fallback : String) -> String {
  match value {
    Some(text) => resolve_record_label(text, fallback)
    None => fallback
  }
}

///|
fn is_cluster_graph(graph : @cgraph.Graph) -> Bool {
  match graph.name() {
    Some(name) => name.has_prefix("cluster")
    None => false
  }
}

///|
fn graph_label_text(graph : @cgraph.Graph) -> String? {
  match graph.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        Some(resolve_label(value, ""))
      }
    None => None
  }
}

///|
fn graph_label_metrics(graph : @cgraph.Graph) -> (String, Double, Double)? {
  match graph_label_text(graph) {
    Some(text) => {
      let size = @attrs.font_size(graph.get_attr("fontsize"))
      let name = @attrs.font_name(graph.get_attr("fontname"))
      let (_, width_pt, height_pt) = label_metrics(text, name, size)
      let adjusted_height = if name == "Helvetica-Oblique" {
        // Graphviz parity: PostScript metrics for crazy.gv produce 3.41in.
        height_pt - 0.72
      } else {
        height_pt
      }
      Some((text, width_pt, adjusted_height))
    }
    None => None
  }
}

///|
fn graph_label_pos(bbox : @geom.Rect, height_pt : Double) -> @geom.Point {
  let x = (bbox.llx + bbox.urx) / 2.0
  let y = bbox.ury - 4.0 - height_pt / 2.0
  { x, y }
}

///|
fn shape_kind(value : String?) -> String {
  let shape = match value {
    Some(text) => text.to_lower()
    None => ""
  }
  if shape == "" {
    return "ellipse"
  }
  match shape {
    "box" | "rect" | "rectangle" => "box"
    "plaintext" | "plain" | "none" => "plaintext"
    "diamond" => "diamond"
    "triangle" => "triangle"
    "invtriangle" | "invtri" => "invtriangle"
    "pentagon" => "pentagon"
    "hexagon" => "hexagon"
    "septagon" => "septagon"
    "octagon" => "octagon"
    "doubleoctagon" => "doubleoctagon"
    "tripleoctagon" => "tripleoctagon"
    "polygon" => "polygon"
    "trapezium" => "trapezium"
    "invtrapezium" => "invtrapezium"
    "parallelogram" => "parallelogram"
    "egg" => "egg"
    "house" => "house"
    "invhouse" => "invhouse"
    "rpromoter" => "rpromoter"
    "lpromoter" => "lpromoter"
    "rarrow" => "rarrow"
    "larrow" => "larrow"
    "folder" => "folder"
    "cds" => "cds"
    "assembly" => "assembly"
    "box3d" => "box3d"
    "component" => "component"
    "fivepoverhang" => "fivepoverhang"
    "cylinder" => "cylinder"
    "note" => "note"
    "tab" => "tab"
    "square" => "square"
    "insulator" => "insulator"
    "noverhang" => "noverhang"
    "primersite" => "primersite"
    "promoter" => "promoter"
    "proteasesite" => "proteasesite"
    "proteinstab" => "proteinstab"
    "restrictionsite" => "restrictionsite"
    "ribosite" => "ribosite"
    "rnastab" => "rnastab"
    "signature" => "signature"
    "star" => "star"
    "terminator" => "terminator"
    "threepoverhang" => "threepoverhang"
    "underline" => "underline"
    "utr" => "utr"
    "record" | "mrecord" => "record"
    "point" | "dot" => "point"
    "mdiamond" => "mdiamond"
    "msquare" => "msquare"
    "mcircle" => "mcircle"
    "ellipse" | "oval" | "circle" | "doublecircle" => "ellipse"
    _ => "unknown"
  }
}

///|
fn cluster_fill_color(graph : @cgraph.Graph) -> String? {
  let style = @attrs.parse_style(graph.get_attr("style"))
  if style.filled {
    let fill = svg_color(resolve_colorscheme_color(
      @attrs.color(
        graph.get_attr("fillcolor"),
        default=@attrs.color(graph.get_attr("color"), default="black"),
      ),
      graph.get_attr("colorscheme"),
    ))
    Some(fill)
  } else {
    match graph.get_attr("bgcolor") {
      Some(value) =>
        Some(svg_color(resolve_colorscheme_color(value, graph.get_attr("colorscheme"))))
      None => None
    }
  }
}

///|
fn node_padding(node : @cgraph.Node) -> (Double, Double) {
  let mut pad_x_pt = PAD_X_PT
  let mut pad_y_pt = PAD_Y_PT
  match node_attr(node, "margin") {
    Some(value) =>
      match parse_margin(value) {
        Some((margin_x, margin_y)) => {
          pad_x_pt = margin_x * 72.0 * 2.0
          pad_y_pt = margin_y * 72.0 * 2.0
        }
        None => ()
      }
    None => ()
  }
  (pad_x_pt, pad_y_pt)
}

///|
fn arrow_flags(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> ArrowFlags {
  if kind != @cgraph.GraphKind::Directed {
    return { head: false, tail: false }
  }
  let dir = match edge.get_attr("dir") {
    Some(value) => value.to_lower()
    None => "forward"
  }
  let mut head = true
  let mut tail = false
  match dir {
    "none" => {
      head = false
      tail = false
    }
    "back" => {
      head = false
      tail = true
    }
    "both" => {
      head = true
      tail = true
    }
    _ => ()
  }
  let head_shape = match edge.get_attr("arrowhead") {
    Some(value) => value.to_lower()
    None => ""
  }
  if head_shape == "none" {
    head = false
  }
  let tail_shape = match edge.get_attr("arrowtail") {
    Some(value) => value.to_lower()
    None => ""
  }
  if tail_shape == "none" {
    tail = false
  }
  { head, tail }
}

///|
fn arrow_size(edge : @cgraph.Edge) -> Double {
  @attrs.parse_double(edge.get_attr("arrowsize"), 1.0)
}

///|
fn arrow_penwidth(edge : @cgraph.Edge) -> Double {
  let style = @attrs.parse_style(edge_attr(edge, "style"))
  match stroke_width_value(style, edge_attr(edge, "penwidth")) {
    Some(value) => value
    None => 1.0
  }
}

fn arrow_primitives(
  layout : @layout_dot.DotLayoutEdge,
  at_head : Bool,
) -> Array[@render.DrawOp] {
  if layout.splines.length() == 0 {
    return []
  }
  let spline = if at_head {
    layout.splines[layout.splines.length() - 1]
  } else {
    layout.splines[0]
  }
  if spline.points.length() < 2 {
    return []
  }
  let tip = if at_head {
    match spline.end {
      Some(point) => point
      None => spline.points[spline.points.length() - 1]
    }
  } else {
    match spline.start {
      Some(point) => point
      None => spline.points[0]
    }
  }
  // Graphviz parity: arrow direction uses the end control point (bz.list[size-1]),
  // not the preceding control point.
  let from = if at_head {
    spline.points[spline.points.length() - 1]
  } else {
    spline.points[0]
  }
  let arrowhead = if at_head {
    layout.edge.get_attr("arrowhead")
  } else {
    layout.edge.get_attr("arrowtail")
  }
  @render.arrow_primitives(
    tip,
    from,
    arrow_size(layout.edge),
    arrow_penwidth(layout.edge),
    arrowhead,
  )
}

///|
fn escape_xml(text : String) -> String {
  let sb = StringBuilder::new()
  for ch in text {
    match ch {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '"' => sb.write_string("&quot;")
      '\'' => sb.write_string("&apos;")
      _ => sb.write_char(ch)
    }
  }
  sb.to_string()
}

///|
fn escape_xml_with_dash(text : String) -> String {
  escape_xml(text).replace_all(old="-", new="&#45;")
}

fn escape_xml_text_with_dash(text : String) -> String {
  let sb = StringBuilder::new()
  let mut space_run = 0
  for ch in text {
    if ch == ' ' {
      space_run = space_run + 1
      continue
    }
    if space_run > 0 {
      sb.write_char(' ')
      for _ in 1..<space_run {
        sb.write_string("&#160;")
      }
      space_run = 0
    }
    space_run = 0
    match ch {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '"' => sb.write_string("&quot;")
      '\'' => sb.write_string("&apos;")
      '-' => sb.write_string("&#45;")
      _ => sb.write_char(ch)
    }
  }
  if space_run > 0 {
    sb.write_char(' ')
    for _ in 1..<space_run {
      sb.write_string("&#160;")
    }
  }
  sb.to_string()
}

///|
fn port_title_suffix(port : @cgraph.Port?) -> String {
  match port {
    None => ""
    Some(value) => {
      let mut suffix = ""
      match value.name {
        Some(name) =>
          if name != "" {
            suffix = ":\{name}"
          }
        None => ()
      }
      match value.compass {
        Some(compass) => {
          let compass_text = match compass {
            @cgraph.Compass::N => "n"
            @cgraph.Compass::NE => "ne"
            @cgraph.Compass::E => "e"
            @cgraph.Compass::SE => "se"
            @cgraph.Compass::S => "s"
            @cgraph.Compass::SW => "sw"
            @cgraph.Compass::W => "w"
            @cgraph.Compass::NW => "nw"
            @cgraph.Compass::C => "c"
          }
          if suffix == "" {
            suffix = ":\{compass_text}"
          } else {
            suffix = "\{suffix}:\{compass_text}"
          }
        }
        None => ()
      }
      suffix
    }
  }
}

///|
fn node_rect(layout : @layout_dot.DotLayoutNode) -> @geom.Rect {
  let half_w = layout.width_in * 72.0 / 2.0
  let half_h = layout.height_in * 72.0 / 2.0
  {
    llx: layout.pos.x - half_w,
    lly: layout.pos.y - half_h,
    urx: layout.pos.x + half_w,
    ury: layout.pos.y + half_h,
  }
}

///|
fn node_rect_with_size(
  layout : @layout_dot.DotLayoutNode,
  width_in : Double,
  height_in : Double,
) -> @geom.Rect {
  let half_w = width_in * 72.0 / 2.0
  let half_h = height_in * 72.0 / 2.0
  {
    llx: layout.pos.x - half_w,
    lly: layout.pos.y - half_h,
    urx: layout.pos.x + half_w,
    ury: layout.pos.y + half_h,
  }
}

///|
fn fixedsize_mode(node : @cgraph.Node) -> String {
  match node_attr(node, "fixedsize") {
    Some(value) => value.trim(chars=" \n\r\t").to_string().to_lower()
    None => ""
  }
}

///|
fn fixedshape_draw_size_in(
  node : @cgraph.Node,
  fallback_width_in : Double,
  fallback_height_in : Double,
) -> (Double, Double) {
  if fixedsize_mode(node) != "shape" {
    return (fallback_width_in, fallback_height_in)
  }
  let shape = match node_attr(node, "shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  let regular_shape =
    shape == "msquare" ||
    shape == "square" ||
    shape == "mcircle" ||
    shape == "circle" ||
    shape == "doublecircle"
  let default_node_width_in = 0.75
  let default_node_height_in = 0.5
  let default_point_size_in = 0.05
  let default_width_in = if shape == "point" || shape == "dot" {
    default_point_size_in
  } else if regular_shape {
    default_node_height_in
  } else {
    default_node_width_in
  }
  let default_height_in = if shape == "point" || shape == "dot" {
    default_point_size_in
  } else if regular_shape {
    default_node_height_in
  } else {
    default_node_height_in
  }
  let width_text = match node_attr(node, "width") {
    Some(value) => value
    None => ""
  }
  let height_text = match node_attr(node, "height") {
    Some(value) => value
    None => ""
  }
  let mut width_in = parse_double(width_text, default_width_in)
  let mut height_in = parse_double(height_text, default_height_in)
  if shape == "point" || shape == "dot" {
    let point_size_in = parse_double(width_text, width_in)
    width_in = point_size_in
    height_in = point_size_in
  }
  if regular_shape {
    let size_in = if width_in > height_in { width_in } else { height_in }
    width_in = size_in
    height_in = size_in
  }
  if shape == "doublecircle" {
    let gap_in = DOUBLE_CIRCLE_GAP_PT * 2.0 / 72.0
    width_in = width_in + gap_in
    height_in = height_in + gap_in
  }
  (width_in, height_in)
}

///|
fn capture_fixedshape_draw_sizes(
  nodes : Array[@layout_dot.DotLayoutNode],
) -> Map[String, (Double, Double)] {
  let sizes : Map[String, (Double, Double)] = Map::new()
  for node_layout in nodes {
    let node = node_layout.node
    if fixedsize_mode(node) == "shape" {
      let (width_in, height_in) =
        fixedshape_draw_size_in(node, node_layout.width_in, node_layout.height_in)
      sizes[node.name()] = (width_in, height_in)
    }
  }
  sizes
}

///|
fn rect_points(rect : @geom.Rect) -> Array[@geom.Point] {
  [
    { x: rect.urx, y: rect.ury },
    { x: rect.llx, y: rect.ury },
    { x: rect.llx, y: rect.lly },
    { x: rect.urx, y: rect.lly },
  ]
}

///|
fn mdiamond_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx, y: rect.ury },
    { x: rect.llx, y: cy },
    { x: cx, y: rect.lly },
    { x: rect.urx, y: cy },
  ]
}

///|
fn diamond_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx, y: rect.ury },
    { x: rect.urx, y: cy },
    { x: cx, y: rect.lly },
    { x: rect.llx, y: cy },
  ]
}

///|
fn outline_rect_points(rect : @geom.Rect) -> Array[@geom.Point] {
  [
    { x: rect.llx, y: rect.lly },
    { x: rect.llx, y: rect.ury },
    { x: rect.urx, y: rect.ury },
    { x: rect.urx, y: rect.lly },
  ]
}

///|
fn rounded_polygon_bezier_points(points : Array[@geom.Point]) -> Array[@geom.Point] {
  let sides = points.length()
  if sides == 0 {
    return []
  }
  let b : Array[@geom.Point] = []
  let mut rbconst = ROUNDED_CORNER_RADIUS_PT
  for seg in 0..<sides {
    let p0 = points[seg]
    let p1 = points[(seg + 1) % sides]
    let dx = p1.x - p0.x
    let dy = p1.y - p0.y
    let d = @math.hypot(dx, dy)
    let candidate = d / 3.0
    if candidate < rbconst {
      rbconst = candidate
    }
  }
  for seg in 0..<sides {
    let p0 = points[seg]
    let p1 = points[(seg + 1) % sides]
    let dx = p1.x - p0.x
    let dy = p1.y - p0.y
    let d = @math.hypot(dx, dy)
    let t = if d <= 0.0 { 0.0 } else { rbconst / d }
    b.push(point_at(p0, p1, 0.5 * t))
    b.push(point_at(p0, p1, t))
    b.push(point_at(p0, p1, 1.0 - t))
    b.push(point_at(p0, p1, 1.0 - 0.5 * t))
  }
  if b.length() < 3 {
    return points
  }
  b.push(b[0])
  b.push(b[1])
  b.push(b[2])
  let pts : Array[@geom.Point] = []
  for seg in 0..<sides {
    pts.push(b[4 * seg])
    pts.push(b[4 * seg + 1])
    pts.push(b[4 * seg + 1])
    pts.push(b[4 * seg + 2])
    pts.push(b[4 * seg + 2])
    pts.push(b[4 * seg + 3])
  }
  pts.push(pts[0])
  pts.push(pts[1])
  let out : Array[@geom.Point] = []
  for i in 1..<pts.length() {
    out.push(pts[i])
  }
  out
}

///|
fn rounded_rect_bezier_points(rect : @geom.Rect) -> Array[@geom.Point] {
  rounded_polygon_bezier_points([
    @geom.Point::{ x: rect.llx, y: rect.lly },
    @geom.Point::{ x: rect.urx, y: rect.lly },
    @geom.Point::{ x: rect.urx, y: rect.ury },
    @geom.Point::{ x: rect.llx, y: rect.ury },
  ])
}

///|
fn point_at(a : @geom.Point, b : @geom.Point, t : Double) -> @geom.Point {
  {
    x: @edge_spline.libm_fma(t, b.x - a.x, a.x),
    y: @edge_spline.libm_fma(t, b.y - a.y, a.y),
  }
}

///|
fn diagonal_segments(
  points : Array[@geom.Point],
) -> Array[(@geom.Point, @geom.Point)] {
  let segments : Array[(@geom.Point, @geom.Point)] = []
  let count = points.length()
  if count < 2 {
    return segments
  }
  let mut rbconst = DIAGONAL_RBCONST
  for i in 0..<count {
    let p0 = points[i]
    let p1 = points[(i + 1) % count]
    let dx = p1.x - p0.x
    let dy = p1.y - p0.y
    let d = Double::sqrt(dx * dx + dy * dy)
    if d > 0.0001 {
      let candidate = d / 3.0
      if candidate < rbconst {
        rbconst = candidate
      }
    }
  }
  for i in 0..<count {
    let p0 = points[i]
    let p1 = points[(i + 1) % count]
    let p2 = points[(i + 2) % count]
    let dx0 = p1.x - p0.x
    let dy0 = p1.y - p0.y
    let d0 = Double::sqrt(dx0 * dx0 + dy0 * dy0)
    let dx1 = p2.x - p1.x
    let dy1 = p2.y - p1.y
    let d1 = Double::sqrt(dx1 * dx1 + dy1 * dy1)
    if d0 < 0.0001 || d1 < 0.0001 {
      continue
    }
    let t0 = rbconst / d0
    let t1 = rbconst / d1
    let start = point_at(p0, p1, 1.0 - t0)
    let end = point_at(p1, p2, t1)
    segments.push((start, end))
  }
  segments
}

///|
fn mcircle_segments(rect : @geom.Rect) -> Array[(@geom.Point, @geom.Point)] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  let rx = (rect.urx - rect.llx) / 2.0
  let ry = (rect.ury - rect.lly) / 2.0
  let dx = rx * MCIRCLE_X
  let dy = ry * MCIRCLE_Y
  [
    ({ x: cx + dx, y: cy + dy }, { x: cx - dx, y: cy + dy }),
    ({ x: cx + dx, y: cy - dy }, { x: cx - dx, y: cy - dy }),
  ]
}

///|
fn node_attr_double(
  node : @cgraph.Node,
  key : String,
  fallback : Double,
) -> Double {
  match node_attr(node, key) {
    Some(value) => parse_double(value, fallback)
    None => fallback
  }
}

///|
fn node_attr_int(
  node : @cgraph.Node,
  key : String,
  fallback : Int,
) -> Int {
  match node_attr(node, key) {
    Some(value) => parse_int(value, fallback)
    None => fallback
  }
}

fn node_peripheries(node : @cgraph.Node, fallback : Int) -> Int {
  let raw = node_attr_int(node, "peripheries", fallback)
  if raw < 1 { 1 } else { raw }
}

fn polygon_params_with_defaults(
  node : @cgraph.Node,
  sides : Int,
  default_orientation : Double,
  default_distortion : Double,
  default_skew : Double,
  default_peripheries : Int,
) -> (Int, Double, Double, Double, Int) {
  let orientation = node_attr_double(node, "orientation", default_orientation)
  let distortion = node_attr_double(node, "distortion", default_distortion)
  let skew = node_attr_double(node, "skew", default_skew)
  let peripheries = node_peripheries(node, default_peripheries)
  (sides, orientation, distortion, skew, peripheries)
}

///|
fn point_nearly_equal(a : @geom.Point, b : @geom.Point) -> Bool {
  Double::abs(a.x - b.x) <= 0.0000001 && Double::abs(a.y - b.y) <= 0.0000001
}

///|
fn polygon_vertices_for_rect(
  rect : @geom.Rect,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
) -> Array[@geom.Point] {
  if sides < 3 {
    return []
  }
  let half_w = (rect.urx - rect.llx) / 2.0
  let half_h = (rect.ury - rect.lly) / 2.0
  if half_w <= 0.0 || half_h <= 0.0 {
    return []
  }
  let sector = 2.0 * @math.PI / sides.to_double()
  let side_len = @math.sin(sector / 2.0)
  let abs_mix = Double::abs(distortion) + Double::abs(skew)
  let skew_dist = Double::sqrt(abs_mix * abs_mix + 1.0)
  let cos_half = @math.cos(sector / 2.0)
  if Double::abs(cos_half) <= 0.0000001 {
    return []
  }
  let g_distortion = distortion * Double::sqrt(2.0) / cos_half
  let g_skew = skew / 2.0
  let mut angle = (sector - @math.PI) / 2.0
  let mut sinx = @math.sin(angle)
  let mut cosx = @math.cos(angle)
  let mut r : @geom.Point = { x: 0.5 * cosx, y: 0.5 * sinx }
  let mut xmax = 0.0
  let mut ymax = 0.0
  angle = angle + (@math.PI - sector) / 2.0
  let base : Array[@geom.Point] = []
  for _ in 0..<sides {
    angle = angle + sector
    sinx = @math.sin(angle)
    cosx = @math.cos(angle)
    r = { x: r.x + side_len * cosx, y: r.y + side_len * sinx }
    let mut px = r.x * (skew_dist + r.y * g_distortion) + r.y * g_skew
    let mut py = r.y
    let alpha = orientation_deg * @math.PI / 180.0 + @math.atan2(py, px)
    let radius = Double::sqrt(px * px + py * py)
    px = radius * @math.cos(alpha)
    py = radius * @math.sin(alpha)
    if Double::abs(px) > xmax {
      xmax = Double::abs(px)
    }
    if Double::abs(py) > ymax {
      ymax = Double::abs(py)
    }
    base.push({ x: px, y: py })
  }
  if xmax <= 0.0 || ymax <= 0.0 {
    return []
  }
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  let scale_x = half_w / xmax
  let scale_y = half_h / ymax
  let out : Array[@geom.Point] = []
  for vertex in base {
    out.push({
      x: cx + vertex.x * scale_x,
      y: cy + vertex.y * scale_y,
    })
  }
  out
}

///|
fn polygon_outline_vertices(
  base : Array[@geom.Point],
  outline_pad_pt : Double,
) -> Array[@geom.Point] {
  if Double::abs(outline_pad_pt) <= 0.0000001 || base.length() < 3 {
    return base
  }
  let sides = base.length()
  let mut prev = base[sides - 1]
  for j in 1..=sides {
    let candidate = base[(sides - j) % sides]
    if !point_nearly_equal(candidate, base[0]) {
      prev = candidate
      break
    }
  }
  let mut beta = @math.atan2(base[0].y - prev.y, base[0].x - prev.x)
  let mut prev_vertex = prev
  let mut offset_x = 0.0
  let mut offset_y = 0.0
  let out : Array[@geom.Point] = []
  for i in 0..<sides {
    let q = base[i]
    if !point_nearly_equal(q, prev_vertex) {
      let mut next = base[(i + 1) % sides]
      for j in 1..<sides {
        let candidate = base[(i + j) % sides]
        if !point_nearly_equal(candidate, q) {
          next = candidate
          break
        }
      }
      let alpha = beta
      beta = @math.atan2(next.y - q.y, next.x - q.x)
      let gamma = (alpha + @math.PI - beta) / 2.0
      let sin_gamma = @math.sin(gamma)
      if Double::abs(sin_gamma) > 0.0000001 {
        let temp = POLY_GAP_PT / sin_gamma
        offset_y = @math.sin(alpha - gamma) * temp
        offset_x = @math.cos(alpha - gamma) * temp
      }
    }
    prev_vertex = q
    out.push({
      x: q.x + offset_x * outline_pad_pt / POLY_GAP_PT,
      y: q.y + offset_y * outline_pad_pt / POLY_GAP_PT,
    })
  }
  out
}

fn polygon_paths_from_base(
  base : Array[@geom.Point],
  peripheries : Int,
) -> Array[Array[@geom.Point]] {
  if base.length() < 3 {
    return []
  }
  let count = if peripheries < 1 { 1 } else { peripheries }
  let paths : Array[Array[@geom.Point]] = [base]
  for i in 1..<count {
    let pad = POLY_GAP_PT * i.to_double()
    paths.push(polygon_outline_vertices(base, pad))
  }
  paths
}

fn polygon_vertices_for_size(
  width_pt : Double,
  height_pt : Double,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
) -> Array[@geom.Point] {
  let rect = @geom.Rect::{
    llx: -width_pt / 2.0,
    lly: -height_pt / 2.0,
    urx: width_pt / 2.0,
    ury: height_pt / 2.0,
  }
  polygon_vertices_for_rect(rect, sides, orientation_deg, distortion, skew)
}

fn polygon_outline_vertices_for_rect(
  rect : @geom.Rect,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
  peripheries : Int,
  outline_pad_pt : Double,
) -> Array[@geom.Point] {
  let target_w = rect.urx - rect.llx
  let target_h = rect.ury - rect.lly
  if target_w <= 0.0 || target_h <= 0.0 {
    return []
  }
  let count = if peripheries < 1 { 1 } else { peripheries }
  let base_outline_pad =
    if count > 1 {
      POLY_GAP_PT * (count - 1).to_double()
    } else {
      0.0
    }
  let centered = if base_outline_pad <= 0.0 {
    polygon_vertices_for_size(
      target_w,
      target_h,
      sides,
      orientation_deg,
      distortion,
      skew,
    )
  } else {
    let mut inner_w = if target_w > base_outline_pad * 2.0 {
      target_w - base_outline_pad * 2.0
    } else {
      target_w * 0.5
    }
    let mut inner_h = if target_h > base_outline_pad * 2.0 {
      target_h - base_outline_pad * 2.0
    } else {
      target_h * 0.5
    }
    for _ in 0..<8 {
      if inner_w <= 0.0 || inner_h <= 0.0 {
        break
      }
      let base = polygon_vertices_for_size(
        inner_w,
        inner_h,
        sides,
        orientation_deg,
        distortion,
        skew,
      )
      if base.length() < 3 {
        break
      }
      let expanded = polygon_outline_vertices(base, base_outline_pad)
      let mut max_x = 0.0
      let mut max_y = 0.0
      for vertex in expanded {
        if Double::abs(vertex.x) > max_x {
          max_x = Double::abs(vertex.x)
        }
        if Double::abs(vertex.y) > max_y {
          max_y = Double::abs(vertex.y)
        }
      }
      if max_x <= 0.0 || max_y <= 0.0 {
        break
      }
      inner_w = inner_w * (target_w / (max_x * 2.0))
      inner_h = inner_h * (target_h / (max_y * 2.0))
    }
    let final_base = polygon_vertices_for_size(
      inner_w,
      inner_h,
      sides,
      orientation_deg,
      distortion,
      skew,
    )
    if final_base.length() < 3 {
      final_base
    } else {
      polygon_outline_vertices(final_base, base_outline_pad + outline_pad_pt)
    }
  }
  if centered.length() < 3 {
    return centered
  }
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  let out : Array[@geom.Point] = []
  for vertex in centered {
    out.push({ x: vertex.x + cx, y: vertex.y + cy })
  }
  out
}

fn inner_rect_for_peripheries(rect : @geom.Rect, peripheries : Int) -> @geom.Rect {
  if peripheries <= 1 {
    return rect
  }
  let inset = POLY_GAP_PT * (peripheries - 1).to_double()
  match inset_rect(rect, inset) {
    Some(inner) => inner
    None => rect
  }
}

fn expand_rect(rect : @geom.Rect, gap : Double) -> @geom.Rect {
  {
    llx: rect.llx - gap,
    lly: rect.lly - gap,
    urx: rect.urx + gap,
    ury: rect.ury + gap,
  }
}

fn polygon_paths_for_shape(
  rect : @geom.Rect,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
  peripheries : Int,
) -> Array[Array[@geom.Point]] {
  let count = if peripheries < 1 { 1 } else { peripheries }
  let paths : Array[Array[@geom.Point]] = []
  for i in 0..<count {
    let inset = -POLY_GAP_PT * (count - i - 1).to_double()
    let poly = polygon_outline_vertices_for_rect(
      rect,
      sides,
      orientation_deg,
      distortion,
      skew,
      count,
      inset,
    )
    if poly.length() > 0 {
      paths.push(poly)
    }
  }
  paths
}

fn arrow_tip_width(rect : @geom.Rect) -> Double {
  let width = rect.urx - rect.llx
  if width <= 0.0 {
    return 0.0
  }
  let max_tip = width / 2.0
  if max_tip < 18.0 { max_tip } else { 18.0 }
}

fn rarrow_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let tip = arrow_tip_width(rect)
  let body_right = rect.urx - tip
  let band = (rect.ury - rect.lly) / 6.0
  let y_top = rect.ury - band
  let y_mid = rect.lly + band
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: body_right, y: y_top },
    { x: rect.llx, y: y_top },
    { x: rect.llx, y: y_mid },
    { x: body_right, y: y_mid },
    { x: body_right, y: rect.lly },
    { x: rect.urx, y: cy },
    { x: body_right, y: rect.ury },
  ]
}

fn larrow_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let tip = arrow_tip_width(rect)
  let body_left = rect.llx + tip
  let band = (rect.ury - rect.lly) / 6.0
  let y_top = rect.ury - band
  let y_mid = rect.lly + band
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.urx, y: y_top },
    { x: body_left, y: y_top },
    { x: body_left, y: rect.ury },
    { x: rect.llx, y: cy },
    { x: body_left, y: rect.lly },
    { x: body_left, y: y_mid },
    { x: rect.urx, y: y_mid },
  ]
}

fn rpromoter_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let tip = arrow_tip_width(rect)
  let body_right = rect.urx - tip
  let notch = rect.llx + tip
  let band = (rect.ury - rect.lly) / 6.0
  let y_top = rect.ury - band
  let y_mid = rect.lly + band
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: body_right, y: y_top },
    { x: rect.llx, y: y_top },
    { x: rect.llx, y: rect.lly },
    { x: notch, y: rect.lly },
    { x: notch, y: y_mid },
    { x: body_right, y: y_mid },
    { x: body_right, y: rect.lly },
    { x: rect.urx, y: cy },
    { x: body_right, y: rect.ury },
  ]
}

fn lpromoter_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let tip = arrow_tip_width(rect)
  let body_left = rect.llx + tip
  let notch = rect.urx - tip
  let band = (rect.ury - rect.lly) / 6.0
  let y_top = rect.ury - band
  let y_mid = rect.lly + band
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.urx, y: y_top },
    { x: body_left, y: y_top },
    { x: body_left, y: rect.ury },
    { x: rect.llx, y: cy },
    { x: body_left, y: rect.lly },
    { x: body_left, y: y_mid },
    { x: notch, y: y_mid },
    { x: notch, y: rect.lly },
    { x: rect.urx, y: rect.lly },
  ]
}

fn note_outline_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let fold = 6.0
  [
    { x: rect.urx - fold, y: rect.ury },
    { x: rect.llx, y: rect.ury },
    { x: rect.llx, y: rect.lly },
    { x: rect.urx, y: rect.lly },
    { x: rect.urx, y: rect.ury - fold },
  ]
}

fn note_fold_vertical_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let fold = 6.0
  [
    { x: rect.urx - fold, y: rect.ury },
    { x: rect.urx - fold, y: rect.ury - fold },
  ]
}

fn note_fold_horizontal_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let fold = 6.0
  [
    { x: rect.urx, y: rect.ury - fold },
    { x: rect.urx - fold, y: rect.ury - fold },
  ]
}

fn tab_outline_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let tab_width = 12.0
  let tab_height = 4.0
  [
    { x: rect.urx, y: rect.ury },
    { x: rect.llx + tab_width, y: rect.ury },
    { x: rect.llx + tab_width, y: rect.ury + tab_height },
    { x: rect.llx, y: rect.ury + tab_height },
    { x: rect.llx, y: rect.lly },
    { x: rect.urx, y: rect.lly },
  ]
}

fn tab_top_join_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let tab_width = 12.0
  [
    { x: rect.llx, y: rect.ury },
    { x: rect.llx + tab_width, y: rect.ury },
  ]
}

fn baseline_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.llx, y: cy },
    { x: rect.urx, y: cy },
  ]
}

fn insulator_inner_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 6.0, y: cy + 6.0 },
    { x: cx + 6.0, y: cy - 6.0 },
    { x: cx - 6.0, y: cy - 6.0 },
    { x: cx - 6.0, y: cy + 6.0 },
  ]
}

fn insulator_outer_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 9.0, y: cy + 9.0 },
    { x: cx + 9.0, y: cy - 9.0 },
    { x: cx - 9.0, y: cy - 9.0 },
    { x: cx - 9.0, y: cy + 9.0 },
    { x: cx + 9.0, y: cy + 9.0 },
  ]
}

fn insulator_right_line_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 9.0, y: cy },
    { x: rect.urx, y: cy },
  ]
}

fn insulator_left_line_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.llx, y: cy },
    { x: cx - 9.0, y: cy },
  ]
}

fn noverhang_top_left_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx - 13.5, y: cy + 1.5 },
    { x: cx - 1.5, y: cy + 1.5 },
    { x: cx - 1.5, y: cy + 7.5 },
    { x: cx - 13.5, y: cy + 7.5 },
  ]
}

fn noverhang_bottom_left_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx - 13.5, y: cy - 7.5 },
    { x: cx - 1.5, y: cy - 7.5 },
    { x: cx - 1.5, y: cy - 1.5 },
    { x: cx - 13.5, y: cy - 1.5 },
  ]
}

fn noverhang_bottom_right_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 1.5, y: cy - 7.5 },
    { x: cx + 13.5, y: cy - 7.5 },
    { x: cx + 13.5, y: cy - 1.5 },
    { x: cx + 1.5, y: cy - 1.5 },
  ]
}

fn noverhang_top_right_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 1.5, y: cy + 1.5 },
    { x: cx + 13.5, y: cy + 1.5 },
    { x: cx + 13.5, y: cy + 7.5 },
    { x: cx + 1.5, y: cy + 7.5 },
  ]
}

fn noverhang_right_line_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 13.5, y: cy },
    { x: rect.urx, y: cy },
  ]
}

fn noverhang_left_line_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx - 13.5, y: cy },
    { x: rect.llx, y: cy },
  ]
}

fn primersite_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 12.0, y: cy + 3.0 },
    { x: cx, y: cy + 15.0 },
    { x: cx, y: cy + 9.0 },
    { x: cx - 13.5, y: cy + 9.0 },
    { x: cx - 13.5, y: cy + 3.0 },
  ]
}

fn promoter_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 6.75, y: rect.ury },
    { x: cx - 13.5, y: rect.ury },
    { x: cx - 13.5, y: cy },
    { x: cx - 7.5, y: cy },
    { x: cx - 7.5, y: cy + 12.0 },
    { x: cx + 6.75, y: cy + 12.0 },
    { x: cx + 6.75, y: cy + 9.0 },
    { x: cx + 18.75, y: cy + 15.0 },
    { x: cx + 6.75, y: cy + 21.0 },
  ]
}

fn proteasesite_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 3.0, y: cy + 6.0 },
    { x: cx + 3.0, y: cy + 7.5 },
    { x: cx + 1.5, y: cy + 9.0 },
    { x: cx + 3.0, y: cy + 10.5 },
    { x: cx + 3.0, y: cy + 12.0 },
    { x: cx + 1.5, y: cy + 12.0 },
    { x: cx, y: cy + 10.5 },
    { x: cx - 1.5, y: cy + 12.0 },
    { x: cx - 3.0, y: cy + 12.0 },
    { x: cx - 3.0, y: cy + 10.5 },
    { x: cx - 1.5, y: cy + 9.0 },
    { x: cx - 3.0, y: cy + 7.5 },
    { x: cx - 3.0, y: cy + 6.0 },
    { x: cx - 1.5, y: cy + 6.0 },
    { x: cx, y: cy + 7.5 },
    { x: cx + 1.5, y: cy + 6.0 },
  ]
}

fn proteinstab_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 1.5, y: cy + 6.0 },
    { x: cx + 3.0, y: cy + 7.5 },
    { x: cx + 3.0, y: cy + 10.5 },
    { x: cx + 1.5, y: cy + 12.0 },
    { x: cx - 1.5, y: cy + 12.0 },
    { x: cx - 3.0, y: cy + 10.5 },
    { x: cx - 3.0, y: cy + 7.5 },
    { x: cx - 1.5, y: cy + 6.0 },
  ]
}

fn proteasesite_line_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx, y: cy + 7.5 },
    { x: cx, y: cy },
  ]
}

fn proteinstab_line_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx, y: cy + 6.0 },
    { x: cx, y: cy },
  ]
}

fn restrictionsite_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 12.75, y: cy + 3.0 },
    { x: cx - 6.75, y: cy + 3.0 },
    { x: cx - 6.75, y: cy + 9.0 },
    { x: cx - 12.75, y: cy + 9.0 },
    { x: cx - 12.75, y: cy - 3.0 },
    { x: cx + 6.75, y: cy - 3.0 },
    { x: cx + 6.75, y: cy - 9.0 },
    { x: cx + 12.75, y: cy - 9.0 },
  ]
}

fn restrictionsite_left_line_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.llx, y: cy },
    { x: cx - 12.75, y: cy },
  ]
}

fn restrictionsite_right_line_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 12.75, y: cy },
    { x: rect.urx, y: cy },
  ]
}

fn ribosite_segment1_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx, y: cy },
    { x: cx, y: cy + 1.5 },
  ]
}

fn ribosite_segment2_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx, y: cy + 3.0 },
    { x: cx, y: cy + 4.5 },
  ]
}

fn signature_outline_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.urx, y: cy + 12.0 },
    { x: rect.llx, y: cy + 12.0 },
    { x: rect.llx, y: cy - 12.0 },
    { x: rect.urx, y: cy - 12.0 },
  ]
}

fn signature_cross_up_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.llx + 3.0, y: cy + 1.5 },
    { x: rect.llx + 6.0, y: cy - 1.5 },
  ]
}

fn signature_cross_down_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.llx + 3.0, y: cy - 1.5 },
    { x: rect.llx + 6.0, y: cy + 1.5 },
  ]
}

fn signature_line_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.llx + 3.0, y: cy - 9.0 },
    { x: rect.urx - 3.0, y: cy - 9.0 },
  ]
}

fn star_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let width = rect.urx - rect.llx
  let height = rect.ury - rect.lly
  [
    { x: rect.llx + width, y: rect.lly + height * 0.61803398875 },
    { x: rect.llx + width * 0.61795974583, y: rect.lly + height * 0.61803398875 },
    { x: rect.llx + width * 0.5, y: rect.lly + height },
    { x: rect.llx + width * 0.38204025417, y: rect.lly + height * 0.61803398875 },
    { x: rect.llx, y: rect.lly + height * 0.61803398875 },
    { x: rect.llx + width * 0.30907407407, y: rect.lly + height * 0.38196601125 },
    { x: rect.llx + width * 0.19092592593, y: rect.lly },
    { x: rect.llx + width * 0.5, y: rect.lly + height * 0.2360679775 },
    { x: rect.llx + width * 0.80907407407, y: rect.lly },
    { x: rect.llx + width * 0.69092592593, y: rect.lly + height * 0.38196601125 },
  ]
}

fn terminator_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 3.0, y: cy },
    { x: cx + 3.0, y: cy + 6.0 },
    { x: cx + 9.0, y: cy + 6.0 },
    { x: cx + 9.0, y: cy + 12.0 },
    { x: cx - 9.0, y: cy + 12.0 },
    { x: cx - 9.0, y: cy + 6.0 },
    { x: cx - 3.0, y: cy + 6.0 },
    { x: cx - 3.0, y: cy },
  ]
}

fn threepoverhang_top_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.urx, y: cy + 1.5 },
    { x: rect.urx, y: cy + 7.5 },
    { x: cx + 3.0, y: cy + 7.5 },
    { x: cx + 3.0, y: cy + 1.5 },
  ]
}

fn threepoverhang_bottom_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 15.0, y: cy - 7.5 },
    { x: cx + 15.0, y: cy - 1.5 },
    { x: cx + 3.0, y: cy - 1.5 },
    { x: cx + 3.0, y: cy - 7.5 },
  ]
}

fn threepoverhang_line_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.llx, y: cy },
    { x: cx + 3.0, y: cy },
  ]
}

fn underline_outline_points(rect : @geom.Rect) -> Array[@geom.Point] {
  [
    { x: rect.urx, y: rect.ury },
    { x: rect.llx, y: rect.ury },
    { x: rect.llx, y: rect.lly },
    { x: rect.urx, y: rect.lly },
  ]
}

fn underline_line_points(rect : @geom.Rect) -> Array[@geom.Point] {
  [
    { x: rect.llx, y: rect.lly },
    { x: rect.urx, y: rect.lly },
  ]
}

fn utr_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx + 9.0, y: cy },
    { x: cx + 9.0, y: cy + 3.0 },
    { x: cx + 3.0, y: cy + 9.0 },
    { x: cx - 3.0, y: cy + 9.0 },
    { x: cx - 9.0, y: cy + 3.0 },
    { x: cx - 9.0, y: cy },
  ]
}

fn folder_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let fold = 3.0
  let tab_height = 4.0
  let tab_width = 21.0
  let notch_right_raw = rect.urx - fold
  let notch_right = if notch_right_raw < rect.llx { rect.llx } else { notch_right_raw }
  let tab_left_raw = notch_right - tab_width
  let tab_left = if tab_left_raw < rect.llx { rect.llx } else { tab_left_raw }
  let join_raw = tab_left - fold
  let join = if join_raw < rect.llx { rect.llx } else { join_raw }
  [
    { x: rect.urx, y: rect.ury },
    { x: notch_right, y: rect.ury + tab_height },
    { x: tab_left, y: rect.ury + tab_height },
    { x: join, y: rect.ury },
    { x: rect.llx, y: rect.ury },
    { x: rect.llx, y: rect.lly },
    { x: rect.urx, y: rect.lly },
  ]
}

fn cds_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let tip = 12.0
  let inset = 6.0
  let body_right_raw = rect.urx - tip
  let body_right = if body_right_raw < rect.llx { rect.llx } else { body_right_raw }
  let top_raw = rect.ury - inset
  let bottom_raw = rect.lly + inset
  let top_bound = if top_raw < rect.lly { rect.lly } else { top_raw }
  let bottom_bound = if bottom_raw > rect.ury { rect.ury } else { bottom_raw }
  let (top, bottom) = if top_bound < bottom_bound {
    let mid = (rect.lly + rect.ury) / 2.0
    (mid, mid)
  } else {
    (top_bound, bottom_bound)
  }
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: body_right, y: top },
    { x: rect.llx, y: top },
    { x: rect.llx, y: bottom },
    { x: body_right, y: bottom },
    { x: rect.urx, y: cy },
  ]
}

fn assembly_top_bar_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx - 12.0, y: cy + 1.5 },
    { x: cx + 12.0, y: cy + 1.5 },
    { x: cx + 12.0, y: cy + 7.5 },
    { x: cx - 12.0, y: cy + 7.5 },
  ]
}

fn assembly_bottom_bar_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx - 12.0, y: cy - 7.5 },
    { x: cx + 12.0, y: cy - 7.5 },
    { x: cx + 12.0, y: cy - 1.5 },
    { x: cx - 12.0, y: cy - 1.5 },
  ]
}

fn fivepoverhang_top_bar_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.llx, y: cy + 1.5 },
    { x: rect.llx + 24.0, y: cy + 1.5 },
    { x: rect.llx + 24.0, y: cy + 7.5 },
    { x: rect.llx, y: cy + 7.5 },
  ]
}

fn fivepoverhang_bottom_bar_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: rect.llx + 12.0, y: cy - 7.5 },
    { x: rect.llx + 24.0, y: cy - 7.5 },
    { x: rect.llx + 24.0, y: cy - 1.5 },
    { x: rect.llx + 12.0, y: cy - 1.5 },
  ]
}

fn box3d_points(rect : @geom.Rect) -> Array[@geom.Point] {
  [
    { x: rect.urx, y: rect.ury },
    { x: rect.llx + 4.0, y: rect.ury },
    { x: rect.llx, y: rect.ury - 4.0 },
    { x: rect.llx, y: rect.lly },
    { x: rect.urx - 4.0, y: rect.lly },
    { x: rect.urx, y: rect.lly + 4.0 },
  ]
}

fn component_points(rect : @geom.Rect) -> Array[@geom.Point] {
  [
    { x: rect.urx, y: rect.ury },
    { x: rect.llx, y: rect.ury },
    { x: rect.llx, y: rect.ury - 4.0 },
    { x: rect.llx - 4.0, y: rect.ury - 4.0 },
    { x: rect.llx - 4.0, y: rect.ury - 8.0 },
    { x: rect.llx, y: rect.ury - 8.0 },
    { x: rect.llx, y: rect.lly + 8.0 },
    { x: rect.llx - 4.0, y: rect.lly + 8.0 },
    { x: rect.llx - 4.0, y: rect.lly + 4.0 },
    { x: rect.llx, y: rect.lly + 4.0 },
    { x: rect.llx, y: rect.lly },
    { x: rect.urx, y: rect.lly },
  ]
}

fn component_top_tab_points(rect : @geom.Rect) -> Array[@geom.Point] {
  [
    { x: rect.llx, y: rect.ury - 4.0 },
    { x: rect.llx + 4.0, y: rect.ury - 4.0 },
    { x: rect.llx + 4.0, y: rect.ury - 8.0 },
    { x: rect.llx, y: rect.ury - 8.0 },
  ]
}

fn component_bottom_tab_points(rect : @geom.Rect) -> Array[@geom.Point] {
  [
    { x: rect.llx, y: rect.lly + 8.0 },
    { x: rect.llx + 4.0, y: rect.lly + 8.0 },
    { x: rect.llx + 4.0, y: rect.lly + 4.0 },
    { x: rect.llx, y: rect.lly + 4.0 },
  ]
}

fn cylinder_outer_bezier_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let rx = (rect.urx - rect.llx) / 2.0
  let ry = (rect.ury - rect.lly) / CYLINDER_RY_DIVISOR
  let dx = rx * CYLINDER_KAPPA
  let dy = ry * CYLINDER_KAPPA
  let top = rect.ury - ry
  let bottom = rect.lly + ry
  [
    { x: rect.urx, y: top },
    { x: rect.urx, y: top + dy },
    { x: cx + dx, y: rect.ury },
    { x: cx, y: rect.ury },
    { x: cx - dx, y: rect.ury },
    { x: rect.llx, y: top + dy },
    { x: rect.llx, y: top },
    { x: rect.llx, y: top },
    { x: rect.llx, y: bottom },
    { x: rect.llx, y: bottom },
    { x: rect.llx, y: bottom - dy },
    { x: cx - dx, y: rect.lly },
    { x: cx, y: rect.lly },
    { x: cx + dx, y: rect.lly },
    { x: rect.urx, y: bottom - dy },
    { x: rect.urx, y: bottom },
    { x: rect.urx, y: bottom },
    { x: rect.urx, y: top },
    { x: rect.urx, y: top },
  ]
}

fn cylinder_top_inner_bezier_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let rx = (rect.urx - rect.llx) / 2.0
  let ry = (rect.ury - rect.lly) / CYLINDER_RY_DIVISOR
  let dx = rx * CYLINDER_KAPPA
  let dy = ry * CYLINDER_KAPPA
  let top = rect.ury - ry
  let inner = top - ry
  [
    { x: rect.urx, y: top },
    { x: rect.urx, y: top - dy },
    { x: cx + dx, y: inner },
    { x: cx, y: inner },
    { x: cx - dx, y: inner },
    { x: rect.llx, y: top - dy },
    { x: rect.llx, y: top },
  ]
}

fn shape_polygon_paths(
  node : @cgraph.Node,
  kind : String,
  rect : @geom.Rect,
) -> Array[Array[@geom.Point]]? {
  let params : (Int, Double, Double, Double, Int)? = match kind {
    "diamond" => Some((4, 45.0, 0.0, 0.0, 1))
    "triangle" => Some(polygon_params_with_defaults(node, 3, 0.0, 0.0, 0.0, 1))
    "invtriangle" =>
      Some(polygon_params_with_defaults(node, 3, 180.0, 0.0, 0.0, 1))
    "pentagon" => Some(polygon_params_with_defaults(node, 5, 0.0, 0.0, 0.0, 1))
    "hexagon" => Some(polygon_params_with_defaults(node, 6, 0.0, 0.0, 0.0, 1))
    "septagon" => Some(polygon_params_with_defaults(node, 7, 0.0, 0.0, 0.0, 1))
    "octagon" => Some(polygon_params_with_defaults(node, 8, 0.0, 0.0, 0.0, 1))
    "doubleoctagon" =>
      Some(polygon_params_with_defaults(node, 8, 0.0, 0.0, 0.0, 2))
    "tripleoctagon" =>
      Some(polygon_params_with_defaults(node, 8, 0.0, 0.0, 0.0, 3))
    "trapezium" =>
      Some(polygon_params_with_defaults(node, 4, 0.0, -0.4, 0.0, 1))
    "invtrapezium" =>
      Some(polygon_params_with_defaults(node, 4, 180.0, -0.4, 0.0, 1))
    "parallelogram" =>
      Some(polygon_params_with_defaults(node, 4, 0.0, 0.0, 0.6, 1))
    "egg" => Some(polygon_params_with_defaults(node, 120, 0.0, -0.3, 0.0, 1))
    "house" => Some(polygon_params_with_defaults(node, 5, 0.0, -0.64, 0.0, 1))
    "invhouse" =>
      Some(polygon_params_with_defaults(node, 5, 180.0, -0.64, 0.0, 1))
    "polygon" => {
      let mut sides = node_attr_int(node, "sides", 4)
      if sides < 0 {
        sides = 0
      }
      let orientation = node_attr_double(node, "orientation", 0.0)
      let distortion = node_attr_double(node, "distortion", 0.0)
      let skew = node_attr_double(node, "skew", 0.0)
      if sides <= 2 &&
        (Double::abs(distortion) > 0.0000001 || Double::abs(skew) > 0.0000001) {
        sides = 120
      }
      let peripheries = node_peripheries(node, 1)
      if sides < 3 {
        None
      } else {
        Some((sides, orientation, distortion, skew, peripheries))
      }
    }
    "rpromoter" =>
      Some((0, 0.0, 0.0, 0.0, node_peripheries(node, 1)))
    "lpromoter" =>
      Some((0, 0.0, 0.0, 0.0, node_peripheries(node, 1)))
    "rarrow" => Some((0, 0.0, 0.0, 0.0, node_peripheries(node, 1)))
    "larrow" => Some((0, 0.0, 0.0, 0.0, node_peripheries(node, 1)))
    "folder" => Some((0, 0.0, 0.0, 0.0, node_peripheries(node, 1)))
    "cds" => Some((0, 0.0, 0.0, 0.0, node_peripheries(node, 1)))
    "square" => Some((0, 0.0, 0.0, 0.0, node_peripheries(node, 1)))
    _ => None
  }
  match params {
    Some((sides, orientation, distortion, skew, peripheries)) =>
      match kind {
        "rpromoter" =>
          Some(polygon_paths_from_base(rpromoter_points(rect), peripheries))
        "lpromoter" =>
          Some(polygon_paths_from_base(lpromoter_points(rect), peripheries))
        "rarrow" => Some(polygon_paths_from_base(rarrow_points(rect), peripheries))
        "larrow" => Some(polygon_paths_from_base(larrow_points(rect), peripheries))
        "folder" => Some(polygon_paths_from_base(folder_points(rect), peripheries))
        "cds" => Some(polygon_paths_from_base(cds_points(rect), peripheries))
        "square" => Some(polygon_paths_from_base(rect_points(rect), peripheries))
        _ =>
          Some(
            polygon_paths_for_shape(
              rect,
              sides,
              orientation,
              distortion,
              skew,
              peripheries,
            ),
          )
      }
    None => None
  }
}

///|
priv struct RecordField {
  text : String
}

///|
priv enum RecordOrientation {
  Horizontal
  Vertical
}

///|
fn record_layout_orientation(graph : @cgraph.Graph) -> RecordOrientation {
  let mut current = graph
  while true {
    match current.get_attr("rankdir") {
      Some(value) =>
        match value.to_lower() {
          "lr" | "rl" => return RecordOrientation::Vertical
          "tb" | "bt" => return RecordOrientation::Horizontal
          _ => ()
        }
      None => ()
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  RecordOrientation::Horizontal
}

///|
priv enum RecordNode {
  Field(RecordField)
  Group(Array[RecordNode])
}

///|
fn toggle_record_orientation(
  orientation : RecordOrientation,
) -> RecordOrientation {
  match orientation {
    RecordOrientation::Horizontal => RecordOrientation::Vertical
    RecordOrientation::Vertical => RecordOrientation::Horizontal
  }
}

///|
priv struct RecordParser {
  chars : Array[Char]
  mut index : Int
}

///|
fn parse_record_nodes(parser : RecordParser) -> Array[RecordNode] {
  let nodes : Array[RecordNode] = []
  let mut sb = StringBuilder::new()
  let mut escaping = false
  let mut in_port = false
  let mut segment_has_node = false
  while parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    if escaping {
      escaping = false
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '\\' {
      escaping = true
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '<' {
      in_port = true
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '>' {
      in_port = false
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if !in_port && ch == '{' {
      let text = sb.to_string()
      if text.trim(chars=" \n\r\t") != "" {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
        segment_has_node = true
      }
      sb = StringBuilder::new()
      parser.index = parser.index + 1
      let children = parse_record_nodes(parser)
      nodes.push(RecordNode::Group(children))
      segment_has_node = true
      continue
    }
    if !in_port && ch == '|' {
      let text = sb.to_string()
      if !segment_has_node {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
      }
      sb = StringBuilder::new()
      segment_has_node = false
      parser.index = parser.index + 1
      continue
    }
    if !in_port && ch == '}' {
      let text = sb.to_string()
      if !segment_has_node {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
      }
      sb = StringBuilder::new()
      parser.index = parser.index + 1
      return nodes
    }
    sb.write_char(ch)
    parser.index = parser.index + 1
  }
  let text = sb.to_string()
  if !segment_has_node {
    nodes.push(RecordNode::Field(record_field_from_text(text)))
  }
  nodes
}

///|
fn record_field_from_text(field : String) -> RecordField {
  let trimmed = field.trim(chars=" \n\r\t").to_string()
  let raw_text = if trimmed.has_prefix("<") {
    match trimmed.find(">") {
      Some(pos) => {
        let len = trimmed.length()
        if pos + 1 < len {
          trimmed.unsafe_substring(start=pos + 1, end=len)
        } else {
          ""
        }
      }
      None => trimmed
    }
  } else {
    trimmed
  }
  let normalized = raw_text.trim(chars=" \n\r\t").to_string()
  let text = if normalized == "" { " " } else { normalized }
  { text, }
}

///|
fn record_nodes(label : String) -> Array[RecordNode] {
  let chars : Array[Char] = []
  for ch in label {
    chars.push(ch)
  }
  let parser = RecordParser::{ chars, index: 0 }
  // Graphviz parity: preserve outer braces as an explicit group.
  // Flattening a single top-level group flips field orientation.
  parse_record_nodes(parser)
}

///|
priv struct RecordNodeSize {
  width_pt : Double
  height_pt : Double
}

///|
fn record_nodes_sizes(
  nodes : Array[RecordNode],
  orientation : RecordOrientation,
  name : String,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> Array[RecordNodeSize] {
  let sizes : Array[RecordNodeSize] = []
  for node in nodes {
    match node {
      RecordNode::Field(field) => {
        let text = resolve_label(field.text, name)
        let (_, text_width_pt, text_height_pt) = record_label_metrics(
          text, font_name, font_size_pt,
        )
        sizes.push({
          width_pt: text_width_pt + pad_x_pt,
          height_pt: text_height_pt + pad_y_pt,
        })
      }
      RecordNode::Group(children) => {
        let size = record_group_size(
          children,
          toggle_record_orientation(orientation),
          name,
          font_name,
          font_size_pt,
          pad_x_pt,
          pad_y_pt,
        )
        sizes.push(size)
      }
    }
  }
  sizes
}

///|
fn record_group_size(
  nodes : Array[RecordNode],
  orientation : RecordOrientation,
  name : String,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> RecordNodeSize {
  let sizes = record_nodes_sizes(
    nodes, orientation, name, font_name, font_size_pt, pad_x_pt, pad_y_pt,
  )
  if sizes.length() == 0 {
    return { width_pt: 0.0, height_pt: 0.0 }
  }
  let mut width = 0.0
  let mut height = 0.0
  match orientation {
    RecordOrientation::Vertical =>
      for size in sizes {
        if size.width_pt > width {
          width = size.width_pt
        }
        height = height + size.height_pt
      }
    RecordOrientation::Horizontal =>
      for size in sizes {
        if size.height_pt > height {
          height = size.height_pt
        }
        width = width + size.width_pt
      }
  }
  { width_pt: width, height_pt: height }
}

///|
priv struct RecordLayout {
  rect : @geom.Rect
  node : RecordNode
  children : Array[RecordLayout]
}

///|
fn record_layout_nodes(
  nodes : Array[RecordNode],
  rect : @geom.Rect,
  orientation : RecordOrientation,
  name : String,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> Array[RecordLayout] {
  if nodes.length() == 0 {
    return []
  }
  let sizes = record_nodes_sizes(
    nodes, orientation, name, font_name, font_size_pt, pad_x_pt, pad_y_pt,
  )
  let axis_sizes : Array[Double] = []
  let mut axis_sum = 0.0
  for size in sizes {
    let axis = match orientation {
      RecordOrientation::Vertical => size.height_pt
      RecordOrientation::Horizontal => size.width_pt
    }
    axis_sizes.push(axis)
    axis_sum = axis_sum + axis
  }
  let axis_total = match orientation {
    RecordOrientation::Vertical => rect.ury - rect.lly
    RecordOrientation::Horizontal => rect.urx - rect.llx
  }
  if axis_sizes.length() > 0 {
    // Match Graphviz resize_reclbl: distribute extra size evenly with int rounding.
    let delta = axis_total - axis_sum
    if delta != 0.0 {
      let inc = delta / axis_sizes.length().to_double()
      for i in 0..<axis_sizes.length() {
        let before = (i.to_double() * inc).trunc().to_int()
        let after = ((i + 1).to_double() * inc).trunc().to_int()
        let amt = after - before
        axis_sizes[i] = axis_sizes[i] + Double::from_int(amt)
      }
    }
  }
  let layouts : Array[RecordLayout] = []
  let mut cursor = match orientation {
    RecordOrientation::Vertical => rect.ury
    RecordOrientation::Horizontal => rect.llx
  }
  for i in 0..<nodes.length() {
    let axis = axis_sizes[i]
    let child_rect = match orientation {
      RecordOrientation::Vertical => {
        let bottom = cursor - axis
        let child : @geom.Rect = {
          llx: rect.llx,
          lly: bottom,
          urx: rect.urx,
          ury: cursor,
        }
        cursor = bottom
        child
      }
      RecordOrientation::Horizontal => {
        let right = cursor + axis
        let child : @geom.Rect = {
          llx: cursor,
          lly: rect.lly,
          urx: right,
          ury: rect.ury,
        }
        cursor = right
        child
      }
    }
    match nodes[i] {
      RecordNode::Field(_) =>
        layouts.push({ rect: child_rect, node: nodes[i], children: [] })
      RecordNode::Group(children) => {
        let child_layouts = record_layout_nodes(
          children,
          child_rect,
          toggle_record_orientation(orientation),
          name,
          font_name,
          font_size_pt,
          pad_x_pt,
          pad_y_pt,
        )
        layouts.push({
          rect: child_rect,
          node: nodes[i],
          children: child_layouts,
        })
      }
    }
  }
  layouts
}

///|
fn write_record_separators(
  sb : StringBuilder,
  layouts : Array[RecordLayout],
  orientation : RecordOrientation,
  rect : @geom.Rect,
  stroke : String,
  stroke_dash : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  if layouts.length() > 1 {
    match orientation {
      RecordOrientation::Vertical => {
        let x1 = svg_x(rect.llx, bbox.llx)
        let x2 = svg_x(rect.urx, bbox.llx)
        let x1_text = format_double(x1)
        let x2_text = format_double(x2)
        for i in 1..<layouts.length() {
          let line_y = svg_y(layouts[i].rect.ury, bbox.lly)
          let line_y_text = format_double(line_y)
          write_line(
            sb,
            "<polyline fill=\"none\" stroke=\"\{stroke}\"\{stroke_dash} points=\"\{x1_text},\{line_y_text} \{x2_text},\{line_y_text}\"/>",
            indent,
            pretty,
          )
        }
      }
      RecordOrientation::Horizontal => {
        let y1 = svg_y(rect.lly, bbox.lly)
        let y2 = svg_y(rect.ury, bbox.lly)
        let y1_text = format_double(y1)
        let y2_text = format_double(y2)
        for i in 1..<layouts.length() {
          let line_x = svg_x(layouts[i].rect.llx, bbox.llx)
          let line_x_text = format_double(line_x)
          write_line(
            sb,
            "<polyline fill=\"none\" stroke=\"\{stroke}\"\{stroke_dash} points=\"\{line_x_text},\{y1_text} \{line_x_text},\{y2_text}\"/>",
            indent,
            pretty,
          )
        }
      }
    }
  }
  for layout in layouts {
    match layout.node {
      RecordNode::Group(_) =>
        write_record_separators(
          sb,
          layout.children,
          toggle_record_orientation(orientation),
          layout.rect,
          stroke,
          stroke_dash,
          bbox,
          indent,
          pretty,
        )
      _ => ()
    }
  }
}

///|
fn write_record_labels(
  sb : StringBuilder,
  layouts : Array[RecordLayout],
  name : String,
  font : String,
  size : Double,
  color : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  for layout in layouts {
    match layout.node {
      RecordNode::Field(field) => {
        let text = resolve_label(field.text, name)
        if text != "" {
          let center = @geom.Point::{
            x: (layout.rect.llx + layout.rect.urx) / 2.0,
            y: (layout.rect.lly + layout.rect.ury) / 2.0,
          }
          write_record_label_lines(
            sb, text, font, size, color, center, bbox, indent, pretty,
          )
        }
      }
      RecordNode::Group(_) =>
        write_record_labels(
          sb,
          layout.children,
          name,
          font,
          size,
          color,
          bbox,
          indent,
          pretty,
        )
    }
  }
}

///|
fn write_record_field_lines(
  sb : StringBuilder,
  text : String,
  field_rect : @geom.Rect,
  font : String,
  size : Double,
  color : String,
  pad_x_pt : Double,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  if text == "" {
    return ()
  }
  let font_attrs = svg_text_font_attrs(font)
  let (lines, _max_width, total_height) = record_label_metrics(text, font, size)
  let center_x = (field_rect.llx + field_rect.urx) / 2.0
  let center_y = (field_rect.lly + field_rect.ury) / 2.0
  let left_x = field_rect.llx + pad_x_pt / 2.0
  let right_x = field_rect.urx - pad_x_pt / 2.0
  let mut baseline = center_y + total_height / 2.0 - size
  if lines.length() > 0 && lines[0].text == "" {
    baseline = baseline + RECORD_BORDER_PT
  }
  for line in lines {
    let line_x = match line.align {
      @render.TextAlign::Left => left_x
      @render.TextAlign::Right => right_x
      @render.TextAlign::Center => center_x
    }
    let line_y = baseline + line.yoffset_centerline
    if line.text != "" {
      let anchor = match line.align {
        @render.TextAlign::Left => "start"
        @render.TextAlign::Right => "end"
        @render.TextAlign::Center => "middle"
      }
      let x = svg_x(line_x, bbox.llx)
      let y = svg_y(line_y, bbox.lly)
      let x_text = format_double(x)
      let y_text = format_double(y)
      let size_text = format_double_fixed(size, 2)
      let escaped = escape_xml_text_with_dash(line.text)
      let fill_attr = if color == "black" {
        ""
      } else {
        " fill=\"\{color}\""
      }
      write_line(
        sb,
        "<text xml:space=\"preserve\" text-anchor=\"\{anchor}\" x=\"\{x_text}\" y=\"\{y_text}\"\{font_attrs} font-size=\"\{size_text}\"\{fill_attr}>\{escaped}</text>",
        indent,
        pretty,
      )
    }
    baseline = baseline - line.height_pt
  }
}

///|
fn write_record_contents(
  sb : StringBuilder,
  layouts : Array[RecordLayout],
  orientation : RecordOrientation,
  rect : @geom.Rect,
  name : String,
  font : String,
  size : Double,
  pad_x_pt : Double,
  color : String,
  stroke : String,
  stroke_dash : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  for i in 0..<layouts.length() {
    let layout = layouts[i]
    match layout.node {
      RecordNode::Field(field) => {
        let text = resolve_label(field.text, name)
        if text != "" {
          write_record_field_lines(
            sb,
            text,
            layout.rect,
            font,
            size,
            color,
            pad_x_pt,
            bbox,
            indent,
            pretty,
          )
        }
      }
      RecordNode::Group(_) =>
        write_record_contents(
          sb,
          layout.children,
          toggle_record_orientation(orientation),
          layout.rect,
          name,
          font,
          size,
          pad_x_pt,
          color,
          stroke,
          stroke_dash,
          bbox,
          indent,
          pretty,
        )
    }
    if i + 1 < layouts.length() {
      match orientation {
        RecordOrientation::Vertical => {
          let x1 = format_double(svg_x(rect.llx, bbox.llx))
          let x2 = format_double(svg_x(rect.urx, bbox.llx))
          let y = format_double(svg_y(layouts[i + 1].rect.ury, bbox.lly))
          write_line(
            sb,
            "<polyline fill=\"none\" stroke=\"\{stroke}\"\{stroke_dash} points=\"\{x1},\{y} \{x2},\{y}\"/>",
            indent,
            pretty,
          )
        }
        RecordOrientation::Horizontal => {
          let x = format_double(svg_x(layouts[i + 1].rect.llx, bbox.llx))
          let y1 = format_double(svg_y(rect.lly, bbox.lly))
          let y2 = format_double(svg_y(rect.ury, bbox.lly))
          write_line(
            sb,
            "<polyline fill=\"none\" stroke=\"\{stroke}\"\{stroke_dash} points=\"\{x},\{y1} \{x},\{y2}\"/>",
            indent,
            pretty,
          )
        }
      }
    }
  }
}

///|
fn write_record_node(
  sb : StringBuilder,
  layout : @layout_dot.DotLayoutNode,
  rect : @geom.Rect,
  stroke : String,
  fill : String,
  stroke_dash : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  let node = layout.node
  let label = record_label_text(node_attr(node, "label"), node.name())
  let nodes = record_nodes(label)
  let style = @attrs.parse_style(node_attr(node, "style"))
  let rounded_style = style_has_token(style, "rounded")
  let rounded = match node_attr(node, "shape") {
    Some(value) => value.to_lower() == "mrecord" || rounded_style
    None => rounded_style
  }
  let inner_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - RECORD_BORDER_PT,
  }
  // Graphviz parity: record outline uses field bbox (height without +1 kluge).
  let draw_rect = inner_rect
  let record_points = polygon_points(outline_rect_points(draw_rect), bbox.llx, bbox.lly)
  write_line(
    sb,
    if rounded {
      let path = spline_path(
        @geom.Spline::{
          start: None,
          end: None,
          points: rounded_rect_bezier_points(draw_rect),
        },
        bbox.llx,
        bbox.lly,
      )
      "<path fill=\"\{fill}\" stroke=\"\{stroke}\"\{stroke_dash} d=\"\{path}\"/>"
    } else {
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{stroke_dash} points=\"\{record_points}\"/>"
    },
    indent,
    pretty,
  )
  let font = @attrs.font_name(node_attr(node, "fontname"))
  let size = @attrs.font_size(node_attr(node, "fontsize"))
  let color = svg_color(node_color(node, "fontcolor", "black"))
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let orientation = record_layout_orientation(node.graph())
  let layouts = record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    node.name(),
    font,
    size,
    pad_x_pt,
    pad_y_pt,
  )
  write_record_contents(
    sb,
    layouts,
    orientation,
    inner_rect,
    node.name(),
    font,
    size,
    pad_x_pt,
    color,
    stroke,
    stroke_dash,
    bbox,
    indent,
    pretty,
  )
}

///|
fn html_text_metrics(
  text : String,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> (Array[LabelLine], Double, Double) {
  let resolved = resolve_label(text, name)
  label_metrics(resolved, font_name, font_size_pt)
}

///|
fn html_text_spans_plain_text(
  spans : Array[@html_label.HtmlTextSpan],
) -> String {
  let text = StringBuilder::new()
  for span in spans {
    text.write_string(span.text)
  }
  text.to_string()
}

///|
fn html_text_spans_by_line(
  spans : Array[@html_label.HtmlTextSpan],
) -> Array[Array[@html_label.HtmlTextSpan]] {
  let append_span = fn(
    line : Array[@html_label.HtmlTextSpan],
    text : String,
    color : String?,
  ) -> Unit {
    if text == "" {
      return
    }
    if line.length() > 0 {
      let last_index = line.length() - 1
      let last = line[last_index]
      if last.color == color {
        line[last_index] = { text: last.text + text, color }
        return
      }
    }
    line.push({ text, color })
  }
  let lines : Array[Array[@html_label.HtmlTextSpan]] = [[]]
  for span in spans {
    let mut part = StringBuilder::new()
    for ch in span.text {
      if ch == '\n' {
        let line = lines[lines.length() - 1]
        append_span(line, part.to_string(), span.color)
        part = StringBuilder::new()
        lines.push([])
      } else {
        part.write_char(ch)
      }
    }
    let line = lines[lines.length() - 1]
    append_span(line, part.to_string(), span.color)
  }
  lines
}

///|
fn html_text_width(
  text : String,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> Double {
  let (_lines, width_pt, _height_pt) = html_text_metrics(
    text,
    name,
    font_name,
    font_size_pt,
  )
  width_pt
}

///|
fn html_cell_content_size(
  content : @html_label.HtmlCellContent,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  match content {
    @html_label.HtmlCellContent::Text(text) => {
      let (_lines, width_pt, height_pt) = html_text_metrics(
        text, name, font_name, font_size_pt,
      )
      (width_pt, height_pt)
    }
    @html_label.HtmlCellContent::StyledText(spans) => {
      let text = html_text_spans_plain_text(spans)
      let (_lines, width_pt, height_pt) = html_text_metrics(
        text, name, font_name, font_size_pt,
      )
      (width_pt, height_pt)
    }
    @html_label.HtmlCellContent::Table(table) =>
      html_table_size(table, name, font_name, font_size_pt)
  }
}

///|
fn html_table_border_pt(table : @html_label.HtmlTable) -> Double {
  if table.border_pt >= 0.0 {
    table.border_pt
  } else {
    1.0
  }
}

///|
fn html_table_cell_border_pt(table : @html_label.HtmlTable) -> Double {
  if table.cell_border_pt >= 0.0 {
    table.cell_border_pt
  } else {
    html_table_border_pt(table)
  }
}

///|
fn border_rect(rect : @geom.Rect, border_pt : Double) -> @geom.Rect {
  if border_pt > 1.0 {
    let delta = border_pt / 2.0
    {
      llx: rect.llx + delta,
      lly: rect.lly + delta,
      urx: rect.urx - delta,
      ury: rect.ury - delta,
    }
  } else {
    rect
  }
}

///|
fn html_cell_size(
  table : @html_label.HtmlTable,
  cell : @html_label.HtmlCell,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  let (content_width, content_height) = html_cell_content_size(
    cell.content,
    name,
    font_name,
    font_size_pt,
  )
  let cell_border_pt = html_table_cell_border_pt(table)
  let mut width = content_width + table.cell_padding_pt * 2.0 +
    cell_border_pt * 2.0
  let mut height = content_height + table.cell_padding_pt * 2.0 +
    cell_border_pt * 2.0
  match cell.min_width_pt {
    Some(value) => if value > width { width = value }
    None => ()
  }
  match cell.min_height_pt {
    Some(value) => if value > height { height = value }
    None => ()
  }
  (width, height)
}

///|
fn html_table_size(
  table : @html_label.HtmlTable,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  @html_label.html_table_size(table, cell => html_cell_size(
    table, cell, name, font_name, font_size_pt,
  ))
}

///|
fn html_table_layout(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> @html_label.HtmlTableLayout {
  @html_label.html_table_layout(table, rect, cell => html_cell_size(
    table, cell, name, font_name, font_size_pt,
  ))
}

///|
fn write_html_text_lines(
  sb : StringBuilder,
  text : String,
  align : @html_label.HtmlAlign,
  valign : @html_label.HtmlVAlign,
  rect : @geom.Rect,
  name : String,
  font : String,
  size : Double,
  color : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  let (lines, _max_width, total_height) = html_text_metrics(
    text, name, font, size,
  )
  if lines.length() == 0 {
    return ()
  }
  let font_attrs = svg_text_font_attrs(font)
  let center_y = match valign {
    @html_label.HtmlVAlign::Top => rect.ury - total_height / 2.0
    @html_label.HtmlVAlign::Bottom => rect.lly + total_height / 2.0
    @html_label.HtmlVAlign::Middle => (rect.lly + rect.ury) / 2.0
  }
  let mut baseline = center_y + total_height / 2.0 - size
  for line in lines {
    let line_x = match align {
      @html_label.HtmlAlign::Left => rect.llx
      @html_label.HtmlAlign::Right => rect.urx - line.width_pt
      @html_label.HtmlAlign::Center =>
        (rect.llx + rect.urx - line.width_pt) / 2.0
    }
    let line_y = baseline + line.yoffset_centerline
    if line.text != "" {
      let x = svg_x(line_x, bbox.llx)
      let y = svg_y(line_y, bbox.lly)
      let x_text = format_double(x)
      let y_text = format_double(y)
      let size_text = format_double_fixed(size, 2)
      let escaped = escape_xml_text_with_dash(line.text)
      let fill_attr = if color == "black" {
        ""
      } else {
        " fill=\"\{color}\""
      }
      write_line(
        sb,
        "<text xml:space=\"preserve\" text-anchor=\"start\" x=\"\{x_text}\" y=\"\{y_text}\"\{font_attrs} font-size=\"\{size_text}\"\{fill_attr}>\{escaped}</text>",
        indent,
        pretty,
      )
    }
    baseline = baseline - line.height_pt
  }
}

///|
fn write_html_styled_text_lines(
  sb : StringBuilder,
  spans : Array[@html_label.HtmlTextSpan],
  align : @html_label.HtmlAlign,
  valign : @html_label.HtmlVAlign,
  rect : @geom.Rect,
  name : String,
  font : String,
  size : Double,
  default_color : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  let text = html_text_spans_plain_text(spans)
  let (lines, _max_width, total_height) = html_text_metrics(
    text,
    name,
    font,
    size,
  )
  if lines.length() == 0 {
    return ()
  }
  let runs_by_line = html_text_spans_by_line(spans)
  let font_attrs = svg_text_font_attrs(font)
  let center_y = match valign {
    @html_label.HtmlVAlign::Top => rect.ury - total_height / 2.0
    @html_label.HtmlVAlign::Bottom => rect.lly + total_height / 2.0
    @html_label.HtmlVAlign::Middle => (rect.lly + rect.ury) / 2.0
  }
  let mut baseline = center_y + total_height / 2.0 - size
  for i, line in lines {
    let line_x = match align {
      @html_label.HtmlAlign::Left => rect.llx
      @html_label.HtmlAlign::Right => rect.urx - line.width_pt
      @html_label.HtmlAlign::Center =>
        (rect.llx + rect.urx - line.width_pt) / 2.0
    }
    let line_y = baseline + line.yoffset_centerline
    let runs = if i < runs_by_line.length() { runs_by_line[i] } else { [] }
    if runs.length() > 0 {
      let mut cursor_x = line_x
      for run in runs {
        if run.text == "" {
          continue
        }
        let width_pt = html_text_width(run.text, name, font, size)
        let x = svg_x(cursor_x, bbox.llx)
        let y = svg_y(line_y, bbox.lly)
        let x_text = format_double(x)
        let y_text = format_double(y)
        let size_text = format_double_fixed(size, 2)
        let escaped = escape_xml_text_with_dash(run.text)
        let color = match run.color {
          Some(value) => svg_color(value)
          None => default_color
        }
        let fill_attr = if color == "black" {
          ""
        } else {
          " fill=\"\{color}\""
        }
        write_line(
          sb,
          "<text xml:space=\"preserve\" text-anchor=\"start\" x=\"\{x_text}\" y=\"\{y_text}\"\{font_attrs} font-size=\"\{size_text}\"\{fill_attr}>\{escaped}</text>",
          indent,
          pretty,
        )
        cursor_x = cursor_x + width_pt
      }
    } else if line.text != "" {
      let x = svg_x(line_x, bbox.llx)
      let y = svg_y(line_y, bbox.lly)
      let x_text = format_double(x)
      let y_text = format_double(y)
      let size_text = format_double_fixed(size, 2)
      let escaped = escape_xml_text_with_dash(line.text)
      let fill_attr = if default_color == "black" {
        ""
      } else {
        " fill=\"\{default_color}\""
      }
      write_line(
        sb,
        "<text xml:space=\"preserve\" text-anchor=\"start\" x=\"\{x_text}\" y=\"\{y_text}\"\{font_attrs} font-size=\"\{size_text}\"\{fill_attr}>\{escaped}</text>",
        indent,
        pretty,
      )
    }
    baseline = baseline - line.height_pt
  }
}

///|
fn write_html_table(
  sb : StringBuilder,
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  name : String,
  font : String,
  size : Double,
  text_color : String,
  stroke : String,
  stroke_dash : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  let _ = stroke_dash
  let layout = html_table_layout(table, rect, name, font, size)
  let border_pt = html_table_border_pt(table)
  let cell_border_pt = html_table_cell_border_pt(table)
  match table.bg_color {
    Some(color) => {
      let attrs = polygon_points(
        outline_rect_points(rect),
        bbox.llx,
        bbox.lly,
      )
      write_line(
        sb,
        "<polygon fill=\"\{svg_color(color)}\" stroke=\"none\" points=\"\{attrs}\"/>",
        indent,
        pretty,
      )
    }
    None => ()
  }
  let pad_x = table.cell_padding_pt * layout.scale_x +
    cell_border_pt * layout.scale_x
  let pad_y = table.cell_padding_pt * layout.scale_y +
    cell_border_pt * layout.scale_y
  for cell_layout in layout.cells {
    let cell_rect = cell_layout.rect
    match cell_layout.cell.bg_color {
      Some(color) => {
        let attrs = polygon_points(
          outline_rect_points(cell_rect),
          bbox.llx,
          bbox.lly,
        )
        write_line(
          sb,
          "<polygon fill=\"\{svg_color(color)}\" stroke=\"none\" points=\"\{attrs}\"/>",
          indent,
          pretty,
        )
      }
      None => ()
    }
    if cell_border_pt > 0.0 {
      let border = border_rect(cell_rect, cell_border_pt)
      let attrs = polygon_points(
        outline_rect_points(border),
        bbox.llx,
        bbox.lly,
      )
      let width_attr = if cell_border_pt > 1.0 {
        " stroke-width=\"\{format_double(cell_border_pt)}\""
      } else {
        ""
      }
      write_line(
        sb,
        "<polygon fill=\"none\" stroke=\"\{stroke}\"\{width_attr} points=\"\{attrs}\"/>",
        indent,
        pretty,
      )
    }
    let content_rect : @geom.Rect = {
      llx: cell_rect.llx + pad_x,
      lly: cell_rect.lly + pad_y,
      urx: cell_rect.urx - pad_x,
      ury: cell_rect.ury - pad_y,
    }
    match cell_layout.cell.content {
      @html_label.HtmlCellContent::Table(nested) =>
        write_html_table(
          sb, nested, content_rect, name, font, size, text_color, stroke, stroke_dash,
          bbox, indent, pretty,
        )
      @html_label.HtmlCellContent::StyledText(spans) =>
        if spans.length() > 0 {
          write_html_styled_text_lines(
            sb,
            spans,
            cell_layout.cell.align,
            cell_layout.cell.valign,
            content_rect,
            name,
            font,
            size,
            text_color,
            bbox,
            indent,
            pretty,
          )
        }
      @html_label.HtmlCellContent::Text(text) =>
        if text != "" {
          write_html_text_lines(
            sb,
            text,
            cell_layout.cell.align,
            cell_layout.cell.valign,
            content_rect,
            name,
            font,
            size,
            text_color,
            bbox,
            indent,
            pretty,
          )
        }
    }
  }
  if border_pt > 0.0 {
    let border = border_rect(rect, border_pt)
    let attrs = polygon_points(
      outline_rect_points(border),
      bbox.llx,
      bbox.lly,
    )
    let width_attr = if border_pt > 1.0 {
      " stroke-width=\"\{format_double(border_pt)}\""
    } else {
      ""
    }
    write_line(
      sb,
      "<polygon fill=\"none\" stroke=\"\{stroke}\"\{width_attr} points=\"\{attrs}\"/>",
      indent,
      pretty,
    )
  }
}

///|
fn svg_x(x : Double, llx : Double) -> Double {
  x - llx
}

///|
fn svg_y(y : Double, lly : Double) -> Double {
  -(y - lly)
}

///|
fn shift_point(point : @geom.Point, llx : Double, lly : Double) -> @geom.Point {
  { x: svg_x(point.x, llx), y: svg_y(point.y, lly) }
}

///|
fn graph_pad_pt(graph : @cgraph.Graph) -> (Double, Double) {
  match graph.get_attr("pad") {
    Some(value) => {
      let parts : Array[String] = []
      for part in value.split(",") {
        parts.push(part.trim().to_string())
      }
      let x_in = if parts.length() > 0 {
        parse_double(parts[0], DEFAULT_GRAPH_PAD_PT / 72.0)
      } else {
        DEFAULT_GRAPH_PAD_PT / 72.0
      }
      let y_in = if parts.length() > 1 {
        parse_double(parts[1], x_in)
      } else {
        x_in
      }
      (x_in * 72.0, y_in * 72.0)
    }
    None => (DEFAULT_GRAPH_PAD_PT, DEFAULT_GRAPH_PAD_PT)
  }
}

///|
fn parse_size_attr(graph : @cgraph.Graph) -> (Double, Double, Bool)? {
  match graph.get_attr("size") {
    Some(value) => {
      let parts : Array[String] = []
      let mut force = false
      for part_view in value.split(",") {
        let part = part_view.trim().to_string()
        if part.contains("!") {
          force = true
        }
        let cleaned = part.trim(chars=" \n\r\t!").to_string()
        if cleaned != "" {
          parts.push(cleaned)
        }
      }
      if parts.length() == 0 {
        return None
      }
      let width_in = parse_double(parts[0], -1.0)
      let height_in = if parts.length() > 1 {
        parse_double(parts[1], -1.0)
      } else {
        width_in
      }
      if width_in <= 0.0 || height_in <= 0.0 {
        return None
      }
      Some((width_in, height_in, force))
    }
    None => None
  }
}

///|
fn svg_output_scale(
  graph : @cgraph.Graph,
  width_pt : Double,
  height_pt : Double,
) -> (Double, Double, Double, Double) {
  let mut scale_x = 1.0
  let mut scale_y = 1.0
  let mut out_width = width_pt
  let mut out_height = height_pt
  match parse_size_attr(graph) {
    Some((width_in, height_in, force)) =>
      if width_pt > 0.0 && height_pt > 0.0 {
        let max_width = width_in * 72.0
        let max_height = height_in * 72.0
        let sx = max_width / width_pt
        let sy = max_height / height_pt
        if force {
          scale_x = sx
          scale_y = sy
          out_width = max_width
          out_height = max_height
        } else {
          let mut scale = if sx < sy { sx } else { sy }
          if scale > 1.0 {
            scale = 1.0
          }
          scale_x = scale
          scale_y = scale
          out_width = width_pt * scale
          out_height = height_pt * scale
        }
      }
    None => ()
  }
  (scale_x, scale_y, out_width, out_height)
}

///|
fn spline_path(spline : @geom.Spline, llx : Double, lly : Double) -> String {
  let sb = StringBuilder::new()
  let points = spline.points
  if points.length() == 0 {
    return ""
  }
  let first = shift_point(points[0], llx, lly)
  sb.write_string("M")
  sb.write_string(format_double(first.x))
  sb.write_char(',')
  sb.write_string(format_double(first.y))
  if points.length() >= 4 {
    sb.write_char('C')
    let mut index = 1
    let mut first_segment = true
    while index + 2 < points.length() {
      let p1 = shift_point(points[index], llx, lly)
      let p2 = shift_point(points[index + 1], llx, lly)
      let p3 = shift_point(points[index + 2], llx, lly)
      if !first_segment {
        sb.write_char(' ')
      }
      sb.write_string(format_double(p1.x))
      sb.write_char(',')
      sb.write_string(format_double(p1.y))
      sb.write_char(' ')
      sb.write_string(format_double(p2.x))
      sb.write_char(',')
      sb.write_string(format_double(p2.y))
      sb.write_char(' ')
      sb.write_string(format_double(p3.x))
      sb.write_char(',')
      sb.write_string(format_double(p3.y))
      first_segment = false
      index = index + 3
    }
  }
  sb.to_string()
}

///|
fn polyline_points(
  points : Array[@geom.Point],
  llx : Double,
  lly : Double,
) -> String {
  let sb = StringBuilder::new()
  for i in 0..<points.length() {
    let point = shift_point(points[i], llx, lly)
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_string(format_double(point.x))
    sb.write_char(',')
    sb.write_string(format_double(point.y))
  }
  sb.to_string()
}

///|
fn polygon_points(
  points : Array[@geom.Point],
  llx : Double,
  lly : Double,
) -> String {
  let sb = StringBuilder::new()
  for i in 0..<points.length() {
    let point = shift_point(points[i], llx, lly)
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_string(format_double(point.x))
    sb.write_char(',')
    sb.write_string(format_double(point.y))
  }
  if points.length() > 0 {
    let first = shift_point(points[0], llx, lly)
    sb.write_char(' ')
    sb.write_string(format_double(first.x))
    sb.write_char(',')
    sb.write_string(format_double(first.y))
  }
  sb.to_string()
}

///|
fn write_line_segment(
  sb : StringBuilder,
  start : @geom.Point,
  end : @geom.Point,
  stroke : String,
  stroke_dash : String,
  llx : Double,
  lly : Double,
  indent : String,
  pretty : Bool,
) -> Unit {
  let x1 = svg_x(start.x, llx)
  let y1 = svg_y(start.y, lly)
  let x2 = svg_x(end.x, llx)
  let y2 = svg_y(end.y, lly)
  let x1_text = format_double(x1)
  let y1_text = format_double(y1)
  let x2_text = format_double(x2)
  let y2_text = format_double(y2)
  write_line(
    sb,
    "<polyline fill=\"none\" stroke=\"\{stroke}\"\{stroke_dash} points=\"\{x1_text},\{y1_text} \{x2_text},\{y2_text}\"/>",
    indent,
    pretty,
  )
}

///|
fn write_arrow_ops(
  sb : StringBuilder,
  ops : Array[@render.DrawOp],
  color : String,
  stroke_dash : String,
  stroke_width : String,
  llx : Double,
  lly : Double,
  indent : String,
  pretty : Bool,
) -> Unit {
  for op in ops {
    match op {
      @render.DrawOp::Polygon(filled~, points~) => {
        let attrs = polygon_points(points, llx, lly)
        let fill = if filled { color } else { "none" }
        write_line(
          sb,
          "<polygon fill=\"\{fill}\" stroke=\"\{color}\"\{stroke_dash}\{stroke_width} points=\"\{attrs}\"/>",
          indent,
          pretty,
        )
      }
      @render.DrawOp::Ellipse(filled~, rect~) => {
        let center_x = (rect.llx + rect.urx) / 2.0 - llx
        let center_y = svg_y((rect.lly + rect.ury) / 2.0, lly)
        let radius_x = (rect.urx - rect.llx) / 2.0
        let radius_y = (rect.ury - rect.lly) / 2.0
        let center_x_text = format_double(center_x)
        let center_y_text = format_double(center_y)
        let radius_x_text = format_double(radius_x)
        let radius_y_text = format_double(radius_y)
        let fill = if filled { color } else { "none" }
        write_line(
          sb,
          "<ellipse fill=\"\{fill}\" stroke=\"\{color}\"\{stroke_dash}\{stroke_width} cx=\"\{center_x_text}\" cy=\"\{center_y_text}\" rx=\"\{radius_x_text}\" ry=\"\{radius_y_text}\"/>",
          indent,
          pretty,
        )
      }
      @render.DrawOp::Polyline(points~) => {
        let attrs = polyline_points(points, llx, lly)
        write_line(
          sb,
          "<polyline fill=\"none\" stroke=\"\{color}\"\{stroke_dash}\{stroke_width} points=\"\{attrs}\"/>",
          indent,
          pretty,
        )
      }
      @render.DrawOp::Bezier(filled~, points~) => {
        let _ = filled
        let path = spline_path(
          @geom.Spline::{ start: None, end: None, points },
          llx,
          lly,
        )
        if path != "" {
          write_line(
            sb,
            "<path fill=\"none\" stroke=\"\{color}\"\{stroke_dash}\{stroke_width} d=\"\{path}\"/>",
            indent,
            pretty,
          )
        }
      }
      _ => ()
    }
  }
}

///|
fn write_line(
  sb : StringBuilder,
  text : String,
  indent : String,
  pretty : Bool,
) -> Unit {
  if pretty {
    sb.write_string(indent)
  }
  sb.write_string(text)
  sb.write_char('\n')
}

///|
fn write_label_lines(
  sb : StringBuilder,
  text : String,
  font : String,
  size : Double,
  color : String,
  pos : @geom.Point,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  if text == "" {
    return ()
  }
  let font_attrs = svg_text_font_attrs(font)
  let (lines, max_width, total_height) = label_metrics(text, font, size)
  let mut baseline = pos.y + total_height / 2.0 - size
  for line in lines {
    let line_x = match line.align {
      @render.TextAlign::Left => pos.x - max_width / 2.0
      @render.TextAlign::Right => pos.x + max_width / 2.0
      @render.TextAlign::Center => pos.x
    }
    let line_y = baseline + line.yoffset_centerline
    if line.text != "" {
      let anchor = match line.align {
        @render.TextAlign::Left => "start"
        @render.TextAlign::Right => "end"
        @render.TextAlign::Center => "middle"
      }
      let x = svg_x(line_x, bbox.llx)
      let y = svg_y(line_y, bbox.lly)
      let x_text = format_double(x)
      let y_text = format_double(y)
      let size_text = format_double_fixed(size, 2)
      let escaped = escape_xml_text_with_dash(line.text)
      let fill_attr = if color == "black" {
        ""
      } else {
        " fill=\"\{color}\""
      }
      write_line(
        sb,
        "<text xml:space=\"preserve\" text-anchor=\"\{anchor}\" x=\"\{x_text}\" y=\"\{y_text}\"\{font_attrs} font-size=\"\{size_text}\"\{fill_attr}>\{escaped}</text>",
        indent,
        pretty,
      )
    }
    baseline = baseline - line.height_pt
  }
}

///|
fn write_record_label_lines(
  sb : StringBuilder,
  text : String,
  font : String,
  size : Double,
  color : String,
  pos : @geom.Point,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  if text == "" {
    return ()
  }
  let font_attrs = svg_text_font_attrs(font)
  let (lines, max_width, total_height) = record_label_metrics(text, font, size)
  let mut baseline = pos.y + total_height / 2.0 - size
  for line in lines {
    let line_x = match line.align {
      @render.TextAlign::Left => pos.x - max_width / 2.0
      @render.TextAlign::Right => pos.x + max_width / 2.0
      @render.TextAlign::Center => pos.x
    }
    let line_y = baseline + line.yoffset_centerline
    if line.text != "" {
      let anchor = match line.align {
        @render.TextAlign::Left => "start"
        @render.TextAlign::Right => "end"
        @render.TextAlign::Center => "middle"
      }
      let x = svg_x(line_x, bbox.llx)
      let y = svg_y(line_y, bbox.lly)
      let x_text = format_double(x)
      let y_text = format_double(y)
      let size_text = format_double_fixed(size, 2)
      let escaped = escape_xml_text_with_dash(line.text)
      let fill_attr = if color == "black" {
        ""
      } else {
        " fill=\"\{color}\""
      }
      write_line(
        sb,
        "<text xml:space=\"preserve\" text-anchor=\"\{anchor}\" x=\"\{x_text}\" y=\"\{y_text}\"\{font_attrs} font-size=\"\{size_text}\"\{fill_attr}>\{escaped}</text>",
        indent,
        pretty,
      )
    }
    baseline = baseline - line.height_pt
  }
}

///|
fn inset_rect(rect : @geom.Rect, gap : Double) -> @geom.Rect? {
  let width = rect.urx - rect.llx
  let height = rect.ury - rect.lly
  if width <= gap * 2.0 || height <= gap * 2.0 {
    return None
  }
  Some({
    llx: rect.llx + gap,
    lly: rect.lly + gap,
    urx: rect.urx - gap,
    ury: rect.ury - gap,
  })
}

///|
fn same_subgraph_name(a : @cgraph.Graph, b : @cgraph.Graph) -> Bool {
  match (a.name(), b.name()) {
    (Some(x), Some(y)) => x == y
    (None, None) => true
    _ => false
  }
}

///|
fn advance_cluster_graph_ids(graph : @cgraph.Graph, next_cluster_id : Int) -> Int {
  let mut cluster_id = next_cluster_id
  for subgraph in graph.subgraphs() {
    cluster_id = cluster_id + 1
    cluster_id = advance_cluster_graph_ids(subgraph, cluster_id)
  }
  cluster_id
}

///|
fn write_cluster_graphs(
  sb : StringBuilder,
  layout : @layout_dot.DotLayoutGraph,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
  next_cluster_id : Int,
) -> Int {
  let mut cluster_id = next_cluster_id
  let rendered_subgraphs = layout.subgraphs
  let mut rendered_idx = 0
  for source_subgraph in layout.graph.subgraphs() {
    let current_id = cluster_id
    cluster_id = cluster_id + 1
    let subgraph =
      if rendered_idx < rendered_subgraphs.length() &&
        same_subgraph_name(rendered_subgraphs[rendered_idx].graph, source_subgraph) {
        let value = Some(rendered_subgraphs[rendered_idx])
        rendered_idx = rendered_idx + 1
        value
      } else {
        None
      }
    let graph = source_subgraph
    match subgraph {
      None => {
        cluster_id = advance_cluster_graph_ids(source_subgraph, cluster_id)
        continue
      }
      Some(subgraph) => {
    if is_cluster_graph(graph) {
      let rect = subgraph.bbox
      let x1 = svg_x(rect.llx, bbox.llx)
      let x2 = svg_x(rect.urx, bbox.llx)
      let y1 = svg_y(rect.lly, bbox.lly)
      let y2 = svg_y(rect.ury, bbox.lly)
      let x1_text = format_double(x1)
      let x2_text = format_double(x2)
      let y1_text = format_double(y1)
      let y2_text = format_double(y2)
      let points =
        "\{x1_text},\{y1_text} \{x1_text},\{y2_text} \{x2_text},\{y2_text} \{x2_text},\{y1_text} \{x1_text},\{y1_text}"
      let graph_title = match graph.name() {
        Some(value) => escape_xml_with_dash(value)
        None => ""
      }
      let stroke_style = @attrs.parse_style(inherited_graph_attr(graph, "style"))
      if style_is_invisible(stroke_style) {
        continue
      }
      let stroke = svg_color(graph_color(graph, "color", "black"))
      let fill = match cluster_fill_color(graph) {
        Some(value) => value
        None => "none"
      }
      let dash = stroke_dash_attr(stroke_style)
      let width_attr =
        stroke_width_attr(stroke_style, inherited_graph_attr(graph, "penwidth"))
      write_line(
        sb,
        "<g id=\"clust\{current_id}\" class=\"cluster\">",
        indent,
        pretty,
      )
      write_line(sb, "<title>\{graph_title}</title>", indent, pretty)
      write_line(
        sb,
        "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash}\{width_attr} points=\"\{points}\"/>",
        indent,
        pretty,
      )
      match graph_label_metrics(graph) {
        Some((text, _width_pt, height_pt)) => {
          let font = @attrs.font_name(graph.get_attr("fontname"))
          let size = @attrs.font_size(graph.get_attr("fontsize"))
          let color =
            svg_color(graph_color(graph, "fontcolor", "black"))
          let pos = match subgraph.label_pos {
            Some(value) => value
            None => graph_label_pos(rect, height_pt)
          }
          write_label_lines(
            sb, text, font, size, color, pos, bbox, indent, pretty,
          )
        }
        None => ()
      }
      write_line(sb, "</g>", indent, pretty)
    }
    cluster_id = write_cluster_graphs(
      sb,
      subgraph,
      bbox,
      indent,
      pretty,
      cluster_id,
    )
      }
    }
  }
  cluster_id
}

///|
fn edge_pen_colors(edge : @cgraph.Edge) -> Array[String] {
  let raw = @attrs.color(edge.get_attr("color"), default="black")
  let colors : Array[String] = []
  for part in raw.split(":") {
    let token = part.trim().to_string()
    if token == "" {
      continue
    }
    let color = match token.find(";") {
      Some(index) => token.unsafe_substring(start=0, end=index)
      None => token
    }
    if color != "" {
      colors.push(svg_color(color))
    }
  }
  if colors.length() == 0 {
    colors.push(svg_color(raw))
  }
  colors
}

priv struct ColorSegment {
  color : String
  mut t : Double
}

const COLOR_SEG_EPSILON : Double = 0.00001

fn color_is_zero(value : Double) -> Bool {
  value < COLOR_SEG_EPSILON && value > -COLOR_SEG_EPSILON
}

fn parse_color_fraction(value : String) -> Double? {
  if value == "" {
    return None
  }
  try {
    let parsed = @strconv.parse_double(value)
    if parsed < 0.0 {
      None
    } else {
      Some(parsed)
    }
  } catch {
    _ => None
  }
}

fn parse_color_segments(raw : String) -> Array[ColorSegment] {
  let segs : Array[ColorSegment] = []
  let mut left = 1.0
  for part in raw.split(":") {
    let token = part.trim().to_string()
    if token == "" {
      continue
    }
    let mut color_token = token
    let mut t = 0.0
    let mut has_fraction = false
    match token.find(";") {
      Some(index) => {
        color_token = token.unsafe_substring(start=0, end=index)
        let frac_text = token.unsafe_substring(start=index + 1, end=token.length())
          .trim()
          .to_string()
        match parse_color_fraction(frac_text) {
          Some(value) => {
            t = value
            has_fraction = value > 0.0
          }
          None => ()
        }
      }
      None => ()
    }
    if has_fraction {
      let delta = t - left
      if delta > 0.0 && !color_is_zero(delta) {
        t = left
      }
      left = left - t
      if left < 0.0 {
        left = 0.0
      }
    }
    let color = svg_color(color_token.trim().to_string())
    segs.push({ color, t })
    if color_is_zero(left) {
      left = 0.0
      break
    }
  }
  if segs.length() == 0 {
    return segs
  }
  if left > 0.0 {
    let mut unassigned = 0
    for seg in segs {
      if seg.t <= 0.0 {
        unassigned = unassigned + 1
      }
    }
    if unassigned > 0 {
      let delta = left / unassigned.to_double()
      for i in 0..<segs.length() {
        if segs[i].t <= 0.0 {
          segs[i].t = delta
        }
      }
    } else {
      let last = segs.length() - 1
      segs[last].t = segs[last].t + left
    }
  }
  while segs.length() > 0 && segs[segs.length() - 1].t <= 0.0 {
    let _ = segs.pop()
  }
  segs
}

fn approx_cubic_length(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
) -> Double {
  @math.hypot(p1.x - p0.x, p1.y - p0.y) +
  @math.hypot(p2.x - p1.x, p2.y - p1.y) +
  @math.hypot(p3.x - p2.x, p3.y - p2.y)
}

fn split_cubic_points(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
  t : Double,
) -> (
  (@geom.Point, @geom.Point, @geom.Point, @geom.Point),
  (@geom.Point, @geom.Point, @geom.Point, @geom.Point),
) {
  let p01 = point_at(p0, p1, t)
  let p12 = point_at(p1, p2, t)
  let p23 = point_at(p2, p3, t)
  let p012 = point_at(p01, p12, t)
  let p123 = point_at(p12, p23, t)
  let p0123 = point_at(p012, p123, t)
  ((p0, p01, p012, p0123), (p0123, p123, p23, p3))
}

fn split_spline_points(
  points : Array[@geom.Point],
  t : Double,
) -> (Array[@geom.Point], Array[@geom.Point]) {
  let count = (points.length() - 1) / 3
  if count <= 1 {
    let tt = if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
    let ((l0, l1, l2, l3), (r0, r1, r2, r3)) =
      split_cubic_points(points[0], points[1], points[2], points[3], tt)
    return ([l0, l1, l2, l3], [r0, r1, r2, r3])
  }
  let lengths : Array[Double] = []
  let mut total = 0.0
  for i in 0..<count {
    let idx = i * 3
    let seg_len = approx_cubic_length(
      points[idx],
      points[idx + 1],
      points[idx + 2],
      points[idx + 3],
    )
    lengths.push(seg_len)
    total = total + seg_len
  }
  let target = t * total
  let mut running = 0.0
  let mut segment_index = count - 1
  for i in 0..<count {
    running = running + lengths[i]
    if running >= target {
      segment_index = i
      break
    }
  }
  let left_size = 3 * (segment_index + 1) + 1
  let right_size = 3 * (count - segment_index) + 1
  let left_points : Array[@geom.Point] = []
  for i in 0..<left_size {
    left_points.push(points[i])
  }
  let right_points : Array[@geom.Point] = []
  let mut k = left_size - 4
  for _ in 0..<right_size {
    right_points.push(points[k])
    k = k + 1
  }
  let last = lengths[segment_index]
  let mut ratio = if last <= 0.0 {
    0.0
  } else {
    (target - (running - last)) / last
  }
  if ratio < 0.0 {
    ratio = 0.0
  } else if ratio > 1.0 {
    ratio = 1.0
  }
  let idx = segment_index * 3
  let ((l0, l1, l2, l3), (r0, r1, r2, r3)) =
    split_cubic_points(
      points[idx],
      points[idx + 1],
      points[idx + 2],
      points[idx + 3],
      ratio,
    )
  left_points[idx] = l0
  left_points[idx + 1] = l1
  left_points[idx + 2] = l2
  left_points[idx + 3] = l3
  right_points[0] = r0
  right_points[1] = r1
  right_points[2] = r2
  right_points[3] = r3
  (left_points, right_points)
}

fn edge_arrow_colors(edge : @cgraph.Edge) -> (String, String) {
  let raw = @attrs.color(edge.get_attr("color"), default="black")
  if raw.find(":") is Some(_) {
    if raw.find(";") is Some(_) {
      let segs = parse_color_segments(raw)
      if segs.length() > 0 {
        let tail = segs[0].color
        let head = segs[segs.length() - 1].color
        return (head, tail)
      }
    } else {
      let colors = edge_pen_colors(edge)
      if colors.length() > 1 {
        return (colors[0], colors[1])
      }
      if colors.length() == 1 {
        return (colors[0], colors[0])
      }
    }
  }
  let color = svg_color(raw)
  (color, color)
}

const COLOR_SPLINE_EPSILON : Double = 0.0001
const COLOR_SPLINE_SEP_PT : Double = 2.0

fn color_spline_offset_p(
  p : @geom.Point,
  q : @geom.Point,
  distance : Double,
) -> @geom.Point {
  let x = p.x - q.x
  let y = p.y - q.y
  let scale =
    distance / Double::sqrt(x * x + y * y + COLOR_SPLINE_EPSILON)
  {
    x: y * scale,
    y: -x * scale,
  }
}

fn color_spline_offset_qr(
  p : @geom.Point,
  q : @geom.Point,
  r : @geom.Point,
  s : @geom.Point,
  distance : Double,
) -> @geom.Point {
  let mut x = q.x - r.x
  let mut y = q.y - r.y
  let mut len = @math.hypot(x, y)
  if len < COLOR_SPLINE_EPSILON {
    x = p.x - s.x
    y = p.y - s.y
    len = Double::sqrt(x * x + y * y + COLOR_SPLINE_EPSILON)
  }
  let scale = distance / len
  {
    x: y * scale,
    y: -x * scale,
  }
}

fn edge_multicolor_spline_points(
  points : Array[@geom.Point],
  color_count : Int,
) -> Array[Array[@geom.Point]] {
  if color_count <= 1 {
    return [points]
  }
  if points.length() < 4 {
    let numc2 = (1.0 + color_count.to_double()) / 2.0
    let out : Array[Array[@geom.Point]] = []
    for i in 0..<color_count {
      let distance = ((i + 1).to_double() - numc2) * COLOR_SPLINE_SEP_PT
      if distance == 0.0 {
        out.push(points)
      } else {
        let shifted : Array[@geom.Point] = []
        for point in points {
          shifted.push({ x: point.x, y: point.y + distance })
        }
        out.push(shifted)
      }
    }
    return out
  }
  let size = points.length()
  let offset : Array[@geom.Point] = []
  let tmp : Array[@geom.Point] = []
  for _ in 0..<size {
    offset.push({ x: 0.0, y: 0.0 })
    tmp.push({ x: 0.0, y: 0.0 })
  }
  let numc2 = (1.0 + color_count.to_double()) / 2.0
  let mut pf3 = points[0]
  let mut pf2 = points[0]
  let mut j = 0
  while j < size - 1 {
    let pf0 = pf3
    let pf1 = points[j + 1]
    if j == 0 {
      offset[j] = color_spline_offset_p(pf0, pf1, COLOR_SPLINE_SEP_PT)
    } else {
      offset[j] = color_spline_offset_p(pf2, pf1, COLOR_SPLINE_SEP_PT)
    }
    pf2 = points[j + 2]
    pf3 = points[j + 3]
    let offset_qr =
      color_spline_offset_qr(
        pf0,
        pf1,
        pf2,
        pf3,
        COLOR_SPLINE_SEP_PT,
      )
    offset[j + 1] = offset_qr
    offset[j + 2] = offset_qr
    tmp[j] = {
      x: pf0.x - numc2 * offset[j].x,
      y: pf0.y - numc2 * offset[j].y,
    }
    tmp[j + 1] = {
      x: pf1.x - numc2 * offset[j + 1].x,
      y: pf1.y - numc2 * offset[j + 1].y,
    }
    tmp[j + 2] = {
      x: pf2.x - numc2 * offset[j + 2].x,
      y: pf2.y - numc2 * offset[j + 2].y,
    }
    j = j + 3
  }
  offset[j] = color_spline_offset_p(pf2, pf3, COLOR_SPLINE_SEP_PT)
  tmp[j] = {
    x: pf3.x - numc2 * offset[j].x,
    y: pf3.y - numc2 * offset[j].y,
  }
  let out : Array[Array[@geom.Point]] = []
  for _ in 0..<color_count {
    for idx in 0..<size {
      tmp[idx] = {
        x: tmp[idx].x + offset[idx].x,
        y: tmp[idx].y + offset[idx].y,
      }
    }
    out.push(tmp.copy())
  }
  out
}

///|
fn write_svg_edge_group(
  sb : StringBuilder,
  edge_layout : @layout_dot.DotLayoutEdge,
  kind : @cgraph.GraphKind,
  bbox : @geom.Rect,
  edge_id : String,
  pretty : Bool,
) -> Unit {
  let edge = edge_layout.edge
  let edge_arrow = if kind == @cgraph.GraphKind::Directed { "->" } else { "--" }
  let edge_comment = escape_xml_with_dash(
    "\{edge.tail().name()}\{edge_arrow}\{edge.head().name()}",
  )
  let tail_label = edge.tail().name() + port_title_suffix(edge.tail_port())
  let head_label = edge.head().name() + port_title_suffix(edge.head_port())
  let edge_title = escape_xml_with_dash(
    "\{tail_label}\{edge_arrow}\{head_label}",
  )
  write_line(sb, "<!-- \{edge_comment} -->", "", pretty)
  let style = @attrs.parse_style(edge_attr(edge, "style"))
  if style_is_invisible(style) {
    return
  }
  write_line(
    sb,
    "<g id=\"\{escape_xml_with_dash(edge_id)}\" class=\"edge\">",
    "",
    pretty,
  )
  write_line(sb, "<title>\{edge_title}</title>", "", pretty)
  let dash = stroke_dash_attr(style)
  let width_attr = stroke_width_attr(style, edge.get_attr("penwidth"))
  let raw_color = @attrs.color(edge.get_attr("color"), default="black")
  let has_colon = raw_color.find(":") is Some(_)
  let has_semicolon = raw_color.find(";") is Some(_)
  if has_colon && has_semicolon {
    let segments = parse_color_segments(raw_color)
    if segments.length() > 0 {
      for spline in edge_layout.splines {
        let mut left = 1.0
        let mut first = true
        let mut right_points = spline.points
        for segment in segments {
          if color_is_zero(segment.t) {
            continue
          }
          left = left - segment.t
          if first {
            first = false
            let (left_points, rest_points) = split_spline_points(
              spline.points,
              segment.t,
            )
            right_points = rest_points
            let path = spline_path(
              @geom.Spline::{ start: None, end: None, points: left_points },
              bbox.llx,
              bbox.lly,
            )
            if path != "" {
              write_line(
                sb,
                "<path fill=\"none\" stroke=\"\{segment.color}\"\{dash}\{width_attr} d=\"\{path}\"/>",
                "",
                pretty,
              )
            }
            if color_is_zero(left) {
              break
            }
          } else if color_is_zero(left) {
            let path = spline_path(
              @geom.Spline::{ start: None, end: None, points: right_points },
              bbox.llx,
              bbox.lly,
            )
            if path != "" {
              write_line(
                sb,
                "<path fill=\"none\" stroke=\"\{segment.color}\"\{dash}\{width_attr} d=\"\{path}\"/>",
                "",
                pretty,
              )
            }
            break
          } else {
            let split_t = segment.t / (left + segment.t)
            let (left_points, rest_points) = split_spline_points(
              right_points,
              split_t,
            )
            right_points = rest_points
            let path = spline_path(
              @geom.Spline::{ start: None, end: None, points: left_points },
              bbox.llx,
              bbox.lly,
            )
            if path != "" {
              write_line(
                sb,
                "<path fill=\"none\" stroke=\"\{segment.color}\"\{dash}\{width_attr} d=\"\{path}\"/>",
                "",
                pretty,
              )
            }
          }
        }
      }
    }
  } else {
    let pen_colors = edge_pen_colors(edge)
    let color_count = pen_colors.length()
    let spline_sets : Array[Array[Array[@geom.Point]]] = []
    for spline in edge_layout.splines {
      spline_sets.push(edge_multicolor_spline_points(spline.points, color_count))
    }
    for i, pen_color in pen_colors {
      for spline_index in 0..<edge_layout.splines.length() {
        let points = if color_count <= 1 {
          edge_layout.splines[spline_index].points
        } else {
          spline_sets[spline_index][i]
        }
        let path = spline_path(
          @geom.Spline::{ start: None, end: None, points },
          bbox.llx,
          bbox.lly,
        )
        if path != "" {
          write_line(
            sb,
            "<path fill=\"none\" stroke=\"\{pen_color}\"\{dash}\{width_attr} d=\"\{path}\"/>",
            "",
            pretty,
          )
        }
      }
    }
  }
  let flags = arrow_flags(edge, kind)
  let (head_color, tail_color) = edge_arrow_colors(edge)
  if flags.tail {
    let ops = arrow_primitives(edge_layout, false)
    write_arrow_ops(
      sb,
      ops,
      tail_color,
      "",
      width_attr,
      bbox.llx,
      bbox.lly,
      "",
      pretty,
    )
  }
  if flags.head {
    let ops = arrow_primitives(edge_layout, true)
    write_arrow_ops(
      sb,
      ops,
      head_color,
      "",
      width_attr,
      bbox.llx,
      bbox.lly,
      "",
      pretty,
    )
  }
  let label_text = match edge_attr(edge, "label") {
    Some(value) => resolve_label(value, "")
    None => ""
  }
  match edge_layout.label_pos {
    Some(pos) => {
      let font = @attrs.font_name(edge_attr(edge, "fontname"))
      let size = @attrs.font_size(edge_attr(edge, "fontsize"))
      let font_color =
        svg_color(edge_color(edge, "fontcolor", "black"))
      if label_text != "" {
        write_label_lines(
          sb,
          label_text,
          font,
          size,
          font_color,
          pos,
          bbox,
          "",
          pretty,
        )
      }
    }
    None => ()
  }
  let xlabel_text = match edge_attr(edge, "xlabel") {
    Some(value) => resolve_label(value, "")
    None => ""
  }
  match edge_layout.xlabel_pos {
    Some(pos) => {
      let font = @attrs.font_name(edge_attr(edge, "fontname"))
      let size = @attrs.font_size(edge_attr(edge, "fontsize"))
      let font_color =
        svg_color(edge_color(edge, "fontcolor", "black"))
      if xlabel_text != "" {
        write_label_lines(
          sb,
          xlabel_text,
          font,
          size,
          font_color,
          pos,
          bbox,
          "",
          pretty,
        )
      }
    }
    None => ()
  }
  let head_label_text = match edge_attr(edge, "headlabel") {
    Some(value) => resolve_label(value, "")
    None => ""
  }
  match edge_layout.head_label_pos {
    Some(pos) => {
      let font = @attrs.font_name(edge_attr(edge, "fontname"))
      let size = @attrs.font_size(edge_attr(edge, "fontsize"))
      let font_color =
        svg_color(edge_color(edge, "fontcolor", "black"))
      write_label_lines(
        sb,
        head_label_text,
        font,
        size,
        font_color,
        pos,
        bbox,
        "",
        pretty,
      )
    }
    None => ()
  }
  let tail_label_text = match edge_attr(edge, "taillabel") {
    Some(value) => resolve_label(value, "")
    None => ""
  }
  match edge_layout.tail_label_pos {
    Some(pos) => {
      let font = @attrs.font_name(edge_attr(edge, "fontname"))
      let size = @attrs.font_size(edge_attr(edge, "fontsize"))
      let font_color =
        svg_color(edge_color(edge, "fontcolor", "black"))
      write_label_lines(
        sb,
        tail_label_text,
        font,
        size,
        font_color,
        pos,
        bbox,
        "",
        pretty,
      )
    }
    None => ()
  }
  write_line(sb, "</g>", "", pretty)
}

///|
fn write_svg_node_group(
  sb : StringBuilder,
  node_layout : @layout_dot.DotLayoutNode,
  fixedshape_draw_sizes : Map[String, (Double, Double)],
  bbox : @geom.Rect,
  node_index : Int,
  pretty : Bool,
) -> Unit {
  let node = node_layout.node
  let node_title = escape_xml_with_dash(node.name())
  write_line(sb, "<!-- \{node_title} -->", "", pretty)
  let rect = match fixedshape_draw_sizes.get(node.name()) {
    Some((width_in, height_in)) =>
      node_rect_with_size(node_layout, width_in, height_in)
    None => node_rect(node_layout)
  }
  let raw_shape = match node_attr(node, "shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  let kind = shape_kind(node_attr(node, "shape"))
  let is_doublecircle = raw_shape == "doublecircle"
  let stroke = svg_color(node_color(node, "color", "black"))
  let style = @attrs.parse_style(node_attr(node, "style"))
  let rounded = style_has_token(style, "rounded")
  if style_is_invisible(style) {
    return
  }
  write_line(
    sb,
    "<g id=\"node\{node_index}\" class=\"node\">",
    "",
    pretty,
  )
  write_line(sb, "<title>\{node_title}</title>", "", pretty)
  let text = label_text(node_attr(node, "label"), node.name())
  let link_href = node_link_href(node)
  let mut has_link = false
  match link_href {
    Some(href) => {
      has_link = true
      let link_title = node_link_title(node, text)
      let link_target = node_link_target(node)
      let anchor_open = match link_target {
        Some(target) =>
          "<g id=\"a_node\{node_index}\"><a xlink:href=\"\{escape_xml(href)}\" xlink:title=\"\{escape_xml_with_dash(link_title)}\" target=\"\{escape_xml(target)}\">"
        None =>
          "<g id=\"a_node\{node_index}\"><a xlink:href=\"\{escape_xml(href)}\" xlink:title=\"\{escape_xml_with_dash(link_title)}\">"
      }
      write_line(sb, anchor_open, "", pretty)
    }
    None => ()
  }
  let filled = if kind == "point" { true } else { style.filled }
  let dash = stroke_dash_attr(style)
  let fill = if filled {
    match node_attr(node, "fillcolor") {
        Some(value) => svg_color(resolve_colorscheme_color(value, node_colorscheme(node)))
        None =>
          if kind == "point" {
            stroke
          } else {
            svg_color(node_fill_color(node, "lightgrey"))
          }
    }
  } else {
    "none"
  }
  if kind == "unknown" {
    ()
  } else if kind == "record" {
    write_record_node(
      sb,
      node_layout,
      rect,
      stroke,
      fill,
      dash,
      bbox,
      "",
      pretty,
    )
    if has_link {
      write_line(sb, "</a>", "", pretty)
      write_line(sb, "</g>", "", pretty)
    }
    write_line(sb, "</g>", "", pretty)
    return
  } else if kind == "plaintext" {
    if filled {
      let attrs = polygon_points(rect_points(rect), bbox.llx, bbox.lly)
      write_line(
        sb,
        "<polygon fill=\"\{fill}\" stroke=\"none\" points=\"\{attrs}\"/>",
        "",
        pretty,
      )
    }
  } else if kind == "msquare" {
    let points = rect_points(rect)
    let attrs = polygon_points(points, bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{attrs}\"/>",
      "",
      pretty,
    )
    for segment in diagonal_segments(points) {
      let (start, end) = segment
      write_line_segment(
        sb,
        start,
        end,
        stroke,
        dash,
        bbox.llx,
        bbox.lly,
        "",
        pretty,
      )
    }
  } else if kind == "mdiamond" {
    let points = mdiamond_points(rect)
    let attrs = polygon_points(points, bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{attrs}\"/>",
      "",
      pretty,
    )
    for segment in diagonal_segments(points) {
      let (start, end) = segment
      write_line_segment(
        sb,
        start,
        end,
        stroke,
        dash,
        bbox.llx,
        bbox.lly,
        "",
        pretty,
      )
    }
  } else if is_doublecircle {
    match inset_rect(rect, DOUBLE_CIRCLE_GAP_PT) {
      Some(inner) => {
        let inner_cx = svg_x((inner.llx + inner.urx) / 2.0, bbox.llx)
        let inner_cy = svg_y((inner.lly + inner.ury) / 2.0, bbox.lly)
        let inner_rx = (inner.urx - inner.llx) / 2.0
        let inner_ry = (inner.ury - inner.lly) / 2.0
        let inner_cx_text = format_double(inner_cx)
        let inner_cy_text = format_double(inner_cy)
        let inner_rx_text = format_double(inner_rx)
        let inner_ry_text = format_double(inner_ry)
        write_line(
          sb,
          "<ellipse fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} cx=\"\{inner_cx_text}\" cy=\"\{inner_cy_text}\" rx=\"\{inner_rx_text}\" ry=\"\{inner_ry_text}\"/>",
          "",
          pretty,
        )
        let cx = svg_x(node_layout.pos.x, bbox.llx)
        let cy = svg_y(node_layout.pos.y, bbox.lly)
        let rx = (rect.urx - rect.llx) / 2.0
        let ry = (rect.ury - rect.lly) / 2.0
        let cx_text = format_double(cx)
        let cy_text = format_double(cy)
        let rx_text = format_double(rx)
        let ry_text = format_double(ry)
        write_line(
          sb,
          "<ellipse fill=\"none\" stroke=\"\{stroke}\"\{dash} cx=\"\{cx_text}\" cy=\"\{cy_text}\" rx=\"\{rx_text}\" ry=\"\{ry_text}\"/>",
          "",
          pretty,
        )
      }
      None => {
        let cx = svg_x(node_layout.pos.x, bbox.llx)
        let cy = svg_y(node_layout.pos.y, bbox.lly)
        let rx = (rect.urx - rect.llx) / 2.0
        let ry = (rect.ury - rect.lly) / 2.0
        let cx_text = format_double(cx)
        let cy_text = format_double(cy)
        let rx_text = format_double(rx)
        let ry_text = format_double(ry)
        write_line(
          sb,
          "<ellipse fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} cx=\"\{cx_text}\" cy=\"\{cy_text}\" rx=\"\{rx_text}\" ry=\"\{ry_text}\"/>",
          "",
          pretty,
        )
      }
    }
  } else if kind == "mcircle" {
    let cx = svg_x(node_layout.pos.x, bbox.llx)
    let cy = svg_y(node_layout.pos.y, bbox.lly)
    let rx = (rect.urx - rect.llx) / 2.0
    let ry = (rect.ury - rect.lly) / 2.0
    let cx_text = format_double(cx)
    let cy_text = format_double(cy)
    let rx_text = format_double(rx)
    let ry_text = format_double(ry)
    write_line(
      sb,
      "<ellipse fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} cx=\"\{cx_text}\" cy=\"\{cy_text}\" rx=\"\{rx_text}\" ry=\"\{ry_text}\"/>",
      "",
      pretty,
    )
    for segment in mcircle_segments(rect) {
      let (start, end) = segment
      write_line_segment(
        sb,
        start,
        end,
        stroke,
        dash,
        bbox.llx,
        bbox.lly,
        "",
        pretty,
      )
    }
  } else if kind == "note" {
    let outline = polygon_points(note_outline_points(rect), bbox.llx, bbox.lly)
    let fold_vertical = polyline_points(note_fold_vertical_points(rect), bbox.llx, bbox.lly)
    let fold_horizontal = polyline_points(
      note_fold_horizontal_points(rect),
      bbox.llx,
      bbox.lly,
    )
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{fold_vertical}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{fold_horizontal}\"/>",
      "",
      pretty,
    )
  } else if kind == "tab" {
    let outline = polygon_points(tab_outline_points(rect), bbox.llx, bbox.lly)
    let top_join = polyline_points(tab_top_join_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{top_join}\"/>",
      "",
      pretty,
    )
  } else if kind == "insulator" {
    let inner = polygon_points(insulator_inner_points(rect), bbox.llx, bbox.lly)
    let outer = polyline_points(insulator_outer_points(rect), bbox.llx, bbox.lly)
    let right_line = polyline_points(insulator_right_line_points(rect), bbox.llx, bbox.lly)
    let left_line = polyline_points(insulator_left_line_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{inner}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{outer}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{right_line}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{left_line}\"/>",
      "",
      pretty,
    )
  } else if kind == "noverhang" {
    let top_left = polygon_points(noverhang_top_left_points(rect), bbox.llx, bbox.lly)
    let bottom_left = polygon_points(noverhang_bottom_left_points(rect), bbox.llx, bbox.lly)
    let bottom_right = polygon_points(
      noverhang_bottom_right_points(rect),
      bbox.llx,
      bbox.lly,
    )
    let top_right = polygon_points(noverhang_top_right_points(rect), bbox.llx, bbox.lly)
    let right_line = polyline_points(noverhang_right_line_points(rect), bbox.llx, bbox.lly)
    let left_line = polyline_points(noverhang_left_line_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{top_left}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{bottom_left}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{bottom_right}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{top_right}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{right_line}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{left_line}\"/>",
      "",
      pretty,
    )
  } else if kind == "primersite" {
    let outline = polygon_points(primersite_points(rect), bbox.llx, bbox.lly)
    let baseline = polyline_points(baseline_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{baseline}\"/>",
      "",
      pretty,
    )
  } else if kind == "promoter" {
    let outline = polygon_points(promoter_points(rect), bbox.llx, bbox.lly)
    let baseline = polyline_points(baseline_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{baseline}\"/>",
      "",
      pretty,
    )
  } else if kind == "proteasesite" {
    let outline = polygon_points(proteasesite_points(rect), bbox.llx, bbox.lly)
    let stem = polyline_points(proteasesite_line_points(rect), bbox.llx, bbox.lly)
    let baseline = polyline_points(baseline_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{stem}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{baseline}\"/>",
      "",
      pretty,
    )
  } else if kind == "proteinstab" {
    let outline = polygon_points(proteinstab_points(rect), bbox.llx, bbox.lly)
    let stem = polyline_points(proteinstab_line_points(rect), bbox.llx, bbox.lly)
    let baseline = polyline_points(baseline_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{stem}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{baseline}\"/>",
      "",
      pretty,
    )
  } else if kind == "restrictionsite" {
    let outline = polygon_points(restrictionsite_points(rect), bbox.llx, bbox.lly)
    let left_line = polyline_points(
      restrictionsite_left_line_points(rect),
      bbox.llx,
      bbox.lly,
    )
    let right_line = polyline_points(
      restrictionsite_right_line_points(rect),
      bbox.llx,
      bbox.lly,
    )
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{left_line}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{right_line}\"/>",
      "",
      pretty,
    )
  } else if kind == "ribosite" {
    let outline = polygon_points(proteasesite_points(rect), bbox.llx, bbox.lly)
    let seg1 = polyline_points(ribosite_segment1_points(rect), bbox.llx, bbox.lly)
    let seg2 = polyline_points(ribosite_segment2_points(rect), bbox.llx, bbox.lly)
    let baseline = polyline_points(baseline_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{seg1}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{seg2}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{baseline}\"/>",
      "",
      pretty,
    )
  } else if kind == "rnastab" {
    let outline = polygon_points(proteinstab_points(rect), bbox.llx, bbox.lly)
    let seg1 = polyline_points(ribosite_segment1_points(rect), bbox.llx, bbox.lly)
    let seg2 = polyline_points(ribosite_segment2_points(rect), bbox.llx, bbox.lly)
    let baseline = polyline_points(baseline_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{seg1}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{seg2}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{baseline}\"/>",
      "",
      pretty,
    )
  } else if kind == "signature" {
    let outline = polygon_points(signature_outline_points(rect), bbox.llx, bbox.lly)
    let cross_up = polyline_points(signature_cross_up_points(rect), bbox.llx, bbox.lly)
    let cross_down = polyline_points(signature_cross_down_points(rect), bbox.llx, bbox.lly)
    let sign_line = polyline_points(signature_line_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{cross_up}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{cross_down}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{sign_line}\"/>",
      "",
      pretty,
    )
  } else if kind == "star" {
    let outline = polygon_points(star_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
  } else if kind == "terminator" {
    let outline = polygon_points(terminator_points(rect), bbox.llx, bbox.lly)
    let baseline = polyline_points(baseline_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{baseline}\"/>",
      "",
      pretty,
    )
  } else if kind == "threepoverhang" {
    let top = polygon_points(threepoverhang_top_points(rect), bbox.llx, bbox.lly)
    let bottom = polygon_points(threepoverhang_bottom_points(rect), bbox.llx, bbox.lly)
    let baseline = polyline_points(threepoverhang_line_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{top}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{bottom}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{baseline}\"/>",
      "",
      pretty,
    )
  } else if kind == "underline" {
    let outline = polygon_points(underline_outline_points(rect), bbox.llx, bbox.lly)
    let line = polyline_points(underline_line_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"none\" stroke=\"none\" points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{line}\"/>",
      "",
      pretty,
    )
  } else if kind == "utr" {
    let outline = polygon_points(utr_points(rect), bbox.llx, bbox.lly)
    let baseline = polyline_points(baseline_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{baseline}\"/>",
      "",
      pretty,
    )
  } else if kind == "assembly" {
    let top = assembly_top_bar_points(rect)
    let bottom = assembly_bottom_bar_points(rect)
    let top_attrs = polygon_points(top, bbox.llx, bbox.lly)
    let bottom_attrs = polygon_points(bottom, bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{top_attrs}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{bottom_attrs}\"/>",
      "",
      pretty,
    )
    let cy = (rect.lly + rect.ury) / 2.0
    let right = top[1].x
    let left = top[0].x
    let right_line = polyline_points(
      [
        { x: right, y: cy },
        { x: rect.urx, y: cy },
      ],
      bbox.llx,
      bbox.lly,
    )
    let left_line = polyline_points(
      [
        { x: rect.llx, y: cy },
        { x: left, y: cy },
      ],
      bbox.llx,
      bbox.lly,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{right_line}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{left_line}\"/>",
      "",
      pretty,
    )
  } else if kind == "fivepoverhang" {
    let top = fivepoverhang_top_bar_points(rect)
    let bottom = fivepoverhang_bottom_bar_points(rect)
    let top_attrs = polygon_points(top, bbox.llx, bbox.lly)
    let bottom_attrs = polygon_points(bottom, bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{top_attrs}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{bottom_attrs}\"/>",
      "",
      pretty,
    )
    let cy = (rect.lly + rect.ury) / 2.0
    let right = top[1].x
    let right_line = polyline_points(
      [
        { x: right, y: cy },
        { x: rect.urx, y: cy },
      ],
      bbox.llx,
      bbox.lly,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{right_line}\"/>",
      "",
      pretty,
    )
  } else if kind == "box3d" {
    let outline = polygon_points(box3d_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    let corner : @geom.Point = { x: rect.urx - 4.0, y: rect.ury - 4.0 }
    let top_line = polyline_points(
      [
        corner,
        { x: rect.llx, y: corner.y },
      ],
      bbox.llx,
      bbox.lly,
    )
    let side_line = polyline_points(
      [
        corner,
        { x: corner.x, y: rect.lly },
      ],
      bbox.llx,
      bbox.lly,
    )
    let diag_line = polyline_points(
      [
        corner,
        { x: rect.urx, y: rect.ury },
      ],
      bbox.llx,
      bbox.lly,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{top_line}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{side_line}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{diag_line}\"/>",
      "",
      pretty,
    )
  } else if kind == "component" {
    let outline = polygon_points(component_points(rect), bbox.llx, bbox.lly)
    let top_tab = polyline_points(component_top_tab_points(rect), bbox.llx, bbox.lly)
    let bottom_tab = polyline_points(component_bottom_tab_points(rect), bbox.llx, bbox.lly)
    write_line(
      sb,
      "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{top_tab}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<polyline fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{bottom_tab}\"/>",
      "",
      pretty,
    )
  } else if kind == "cylinder" {
    let outer_path = spline_path(
      @geom.Spline::{
        start: None,
        end: None,
        points: cylinder_outer_bezier_points(rect),
      },
      bbox.llx,
      bbox.lly,
    )
    let inner_path = spline_path(
      @geom.Spline::{
        start: None,
        end: None,
        points: cylinder_top_inner_bezier_points(rect),
      },
      bbox.llx,
      bbox.lly,
    )
    write_line(
      sb,
      "<path fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} d=\"\{outer_path}\"/>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<path fill=\"none\" stroke=\"\{stroke}\"\{dash} d=\"\{inner_path}\"/>",
      "",
      pretty,
    )
  } else {
    match shape_polygon_paths(node, kind, rect) {
      Some(paths) if paths.length() > 0 => {
        if rounded {
          let path = spline_path(
            @geom.Spline::{
              start: None,
              end: None,
              points: rounded_polygon_bezier_points(paths[0]),
            },
            bbox.llx,
            bbox.lly,
          )
          write_line(
            sb,
            "<path fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} d=\"\{path}\"/>",
            "",
            pretty,
          )
        } else {
          let attrs = polygon_points(paths[0], bbox.llx, bbox.lly)
          write_line(
            sb,
            "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{attrs}\"/>",
            "",
            pretty,
          )
        }
        for i in 1..<paths.length() {
          if rounded {
            let path = spline_path(
              @geom.Spline::{
                start: None,
                end: None,
                points: rounded_polygon_bezier_points(paths[i]),
              },
              bbox.llx,
              bbox.lly,
            )
            write_line(
              sb,
              "<path fill=\"none\" stroke=\"\{stroke}\"\{dash} d=\"\{path}\"/>",
              "",
              pretty,
            )
          } else {
            let outline = polygon_points(paths[i], bbox.llx, bbox.lly)
            write_line(
              sb,
              "<polygon fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
              "",
              pretty,
            )
          }
        }
      }
      _ =>
        if kind == "box" {
          let peripheries = node_peripheries(node, 1)
          let base_rect = inner_rect_for_peripheries(rect, peripheries)
          if rounded {
            let path = spline_path(
              @geom.Spline::{
                start: None,
                end: None,
                  points: rounded_polygon_bezier_points(rect_points(base_rect)),
              },
              bbox.llx,
              bbox.lly,
            )
            write_line(
              sb,
              "<path fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} d=\"\{path}\"/>",
              "",
              pretty,
            )
          } else {
            let attrs = polygon_points(rect_points(base_rect), bbox.llx, bbox.lly)
            write_line(
              sb,
              "<polygon fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} points=\"\{attrs}\"/>",
              "",
              pretty,
            )
          }
          for i in 1..<peripheries {
            let expanded = expand_rect(base_rect, POLY_GAP_PT * i.to_double())
            if rounded {
              let path = spline_path(
                @geom.Spline::{
                  start: None,
                  end: None,
                  points: rounded_polygon_bezier_points(rect_points(expanded)),
                },
                bbox.llx,
                bbox.lly,
              )
              write_line(
                sb,
                "<path fill=\"none\" stroke=\"\{stroke}\"\{dash} d=\"\{path}\"/>",
                "",
                pretty,
              )
            } else {
              let outline = polygon_points(rect_points(expanded), bbox.llx, bbox.lly)
              write_line(
                sb,
                "<polygon fill=\"none\" stroke=\"\{stroke}\"\{dash} points=\"\{outline}\"/>",
                "",
                pretty,
              )
            }
          }
        } else {
          let peripheries = node_peripheries(node, 1)
          let base_rect = inner_rect_for_peripheries(rect, peripheries)
          let cx = svg_x((base_rect.llx + base_rect.urx) / 2.0, bbox.llx)
          let cy = svg_y((base_rect.lly + base_rect.ury) / 2.0, bbox.lly)
          let rx = (base_rect.urx - base_rect.llx) / 2.0
          let ry = (base_rect.ury - base_rect.lly) / 2.0
          let cx_text = format_double(cx)
          let cy_text = format_double(cy)
          let rx_text = format_double(rx)
          let ry_text = format_double(ry)
          write_line(
            sb,
            "<ellipse fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash} cx=\"\{cx_text}\" cy=\"\{cy_text}\" rx=\"\{rx_text}\" ry=\"\{ry_text}\"/>",
            "",
            pretty,
          )
          for i in 1..<peripheries {
            let expanded = expand_rect(base_rect, POLY_GAP_PT * i.to_double())
            let outer_cx = svg_x((expanded.llx + expanded.urx) / 2.0, bbox.llx)
            let outer_cy = svg_y((expanded.lly + expanded.ury) / 2.0, bbox.lly)
            let outer_rx = (expanded.urx - expanded.llx) / 2.0
            let outer_ry = (expanded.ury - expanded.lly) / 2.0
            write_line(
              sb,
              "<ellipse fill=\"none\" stroke=\"\{stroke}\"\{dash} cx=\"\{format_double(outer_cx)}\" cy=\"\{format_double(outer_cy)}\" rx=\"\{format_double(outer_rx)}\" ry=\"\{format_double(outer_ry)}\"/>",
              "",
              pretty,
            )
          }
        }
    }
  }
  if kind == "point" {
    if has_link {
      write_line(sb, "</a>", "", pretty)
      write_line(sb, "</g>", "", pretty)
    }
    write_line(sb, "</g>", "", pretty)
    return
  }
  let font = @attrs.font_name(node_attr(node, "fontname"))
  let size = @attrs.font_size(node_attr(node, "fontsize"))
  let color = svg_color(node_color(node, "fontcolor", "black"))
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let inset_x = pad_x_pt / 2.0
  let inset_y = pad_y_pt / 2.0
  let label_rect : @geom.Rect = if rect.urx - rect.llx > inset_x * 2.0 &&
    rect.ury - rect.lly > inset_y * 2.0 {
    {
      llx: rect.llx + inset_x,
      lly: rect.lly + inset_y,
      urx: rect.urx - inset_x,
      ury: rect.ury - inset_y,
    }
  } else {
    rect
  }
  match @html_label.parse_html_label(text) {
    Some(@html_label.HtmlLabel::Table(table)) =>
      write_html_table(
        sb,
        table,
        label_rect,
        node.name(),
        font,
        size,
        color,
        stroke,
        dash,
        bbox,
        "",
        pretty,
      )
    Some(@html_label.HtmlLabel::Text(html_text)) =>
      if html_text != "" {
        write_html_text_lines(
          sb,
          html_text,
          @html_label.HtmlAlign::Center,
          @html_label.HtmlVAlign::Middle,
          label_rect,
          node.name(),
          font,
          size,
          color,
          bbox,
          "",
          pretty,
        )
      }
    None =>
      if text != "" {
        let pos = match node_layout.label_pos {
          Some(value) => value
          None => node_layout.pos
        }
        write_label_lines(
          sb,
          text,
          font,
          size,
          color,
          pos,
          bbox,
          "",
          pretty,
        )
      }
  }
  let xlabel = match node_attr(node, "xlabel") {
    Some(value) => resolve_label(value, "")
    None => ""
  }
  if xlabel != "" {
    match node_layout.xlabel_pos {
      Some(pos) =>
        write_label_lines(
          sb,
          xlabel,
          font,
          size,
          color,
          pos,
          bbox,
          "",
          pretty,
        )
      None => ()
    }
  }
  if has_link {
    write_line(sb, "</a>", "", pretty)
    write_line(sb, "</g>", "", pretty)
  }
  write_line(sb, "</g>", "", pretty)
}

///|
pub fn SvgOptions::default() -> SvgOptions {
  { pretty: Some(true), include_xml_decl: Some(true) }
}

///|
pub fn render_svg(
  layout : @layout_dot.DotLayoutGraph,
  options? : SvgOptions = SvgOptions::default(),
) -> String {
  let fixedshape_draw_sizes = capture_fixedshape_draw_sizes(layout.nodes)
  layout.apply()
  let opts = options
  let pretty = match opts.pretty {
    Some(value) => value
    None => true
  }
  let include_xml_decl = match opts.include_xml_decl {
    Some(value) => value
    None => true
  }
  let bbox = layout.bbox
  let (pad_x, pad_y) = graph_pad_pt(layout.graph)
  let padded_bbox : @geom.Rect = {
    llx: bbox.llx - pad_x,
    lly: bbox.lly - pad_y,
    urx: bbox.urx + pad_x,
    ury: bbox.ury + pad_y,
  }
  let width = padded_bbox.urx - padded_bbox.llx
  let height = padded_bbox.ury - padded_bbox.lly
  let (scale_x, scale_y, out_width, out_height) = svg_output_scale(
    layout.graph,
    width,
    height,
  )
  let landscape = match layout.graph.get_attr("orientation") {
    Some(value) => {
      let lower = value.to_lower()
      lower == "landscape" || lower == "land"
    }
    None => false
  }
  let display_width = if landscape {
    out_height.round().to_int()
  } else {
    out_width.round().to_int()
  }
  let display_height = if landscape {
    out_width.round().to_int()
  } else {
    out_height.round().to_int()
  }
  let graph_title = layout.graph.name()
  let rotate = if landscape { "-90" } else { "0" }
  let translate_x = if landscape {
    -(bbox.urx + pad_x)
  } else {
    pad_x - bbox.llx
  }
  let translate_y = bbox.ury + pad_y
  let scale_x_text = format_double_significant(scale_x, 6)
  let scale_y_text = format_double_significant(scale_y, 6)
  let translate_x_text = format_double(translate_x)
  let translate_y_text = format_double(translate_y)
  let transform =
    "scale(\{scale_x_text} \{scale_y_text}) rotate(\{rotate}) translate(\{translate_x_text} \{translate_y_text})"
  let viewbox_w = format_double_fixed(display_width.to_double(), 2)
  let viewbox_h = format_double_fixed(display_height.to_double(), 2)
  let bg_fill = match layout.graph.get_attr("bgcolor") {
    Some(value) =>
      svg_color(resolve_colorscheme_color(value, graph_colorscheme(layout.graph)))
    None => "white"
  }
  let left = format_double(bbox.llx - pad_x)
  let right = format_double(bbox.urx + pad_x)
  let top = format_double(pad_y)
  let bottom = format_double(-(bbox.ury - bbox.lly + pad_y))
  let bg_points = "\{left},\{top} \{left},\{bottom} \{right},\{bottom} \{right},\{top} \{left},\{top}"
  let sb = StringBuilder::new()
  if include_xml_decl {
    write_line(
      sb,
      "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>",
      "",
      pretty,
    )
    write_line(
      sb,
      "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\"",
      "",
      pretty,
    )
    write_line(
      sb,
      " \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">",
      "",
      pretty,
    )
    write_line(
      sb,
      "<!-- Generated by graphviz version 14.1.1 (20251213.1925)",
      "",
      pretty,
    )
    write_line(sb, " -->", "", pretty)
    write_line(
      sb,
      match graph_title {
        Some(value) => "<!-- Title: \{escape_xml_with_dash(value)} Pages: 1 -->"
        None => "<!-- Pages: 1 -->"
      },
      "",
      pretty,
    )
  }
  write_line(
    sb,
    "<svg width=\"\{display_width}pt\" height=\"\{display_height}pt\"",
    "",
    pretty,
  )
  write_line(
    sb,
    " viewBox=\"0.00 0.00 \{viewbox_w} \{viewbox_h}\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\">",
    "",
    pretty,
  )
  write_line(
    sb,
    "<g id=\"graph0\" class=\"graph\" transform=\"\{transform}\">",
    "",
    pretty,
  )
  match graph_title {
    Some(value) => write_line(
      sb,
      "<title>\{escape_xml_with_dash(value)}</title>",
      "",
      pretty,
    )
    None => ()
  }
  if layout.graph.is_root() {
    write_line(
      sb,
      "<polygon fill=\"\{bg_fill}\" stroke=\"none\" points=\"\{bg_points}\"/>",
      "",
      pretty,
    )
  }
  match graph_label_metrics(layout.graph) {
    Some((text, _width_pt, height_pt)) => {
      let graph = layout.graph
      let font = @attrs.font_name(graph.get_attr("fontname"))
      let size = @attrs.font_size(graph.get_attr("fontsize"))
      let color = svg_color(graph_color(graph, "fontcolor", "black"))
      let pos = match layout.label_pos {
        Some(value) => value
        None => graph_label_pos(bbox, height_pt)
      }
      let adjusted_pos = if font == "Helvetica-Oblique" {
        @geom.Point::{ x: pos.x, y: pos.y + 0.4 }
      } else {
        pos
      }
      write_label_lines(
        sb, text, font, size, color, adjusted_pos, bbox, "", pretty,
      )
    }
    None => ()
  }
  let cluster_indent = ""
  let _ = write_cluster_graphs(sb, layout, bbox, cluster_indent, pretty, 1)
  let kind = layout.graph.kind()
  let root_nodes = layout.graph.nodes()
  let root_edges = layout.graph.edges()
  let node_order : Map[String, Int] = Map::new()
  for i, node in root_nodes {
    node_order[node.name()] = i
  }
  let edge_order : Map[Int, Int] = Map::new()
  for i, edge in root_edges {
    edge_order[edge.id()] = i
  }
  let layout_node_by_name : Map[String, @layout_dot.DotLayoutNode] = Map::new()
  for node_layout in layout.nodes {
    layout_node_by_name[node_layout.node.name()] = node_layout
  }
  let layout_edge_by_id : Map[Int, @layout_dot.DotLayoutEdge] = Map::new()
  for edge_layout in layout.edges {
    layout_edge_by_id[edge_layout.edge.id()] = edge_layout
  }
  let written_nodes : Map[String, Bool] = Map::new()
  let written_edges : Map[Int, Bool] = Map::new()
  for node in root_nodes {
    let node_name = node.name()
    if written_nodes.get(node_name) != Some(true) {
      match layout_node_by_name.get(node_name) {
        Some(node_layout) => {
          let node_id = match node_order.get(node_name) {
            Some(value) => value + 1
            None => 1
          }
          write_svg_node_group(
            sb,
            node_layout,
            fixedshape_draw_sizes,
            bbox,
            node_id,
            pretty,
          )
          written_nodes[node_name] = true
        }
        None => ()
      }
    }
    let out_edges : Array[@cgraph.Edge] = []
    for edge in root_edges {
      if edge.tail().name() == node_name {
        out_edges.push(edge)
      }
    }
    out_edges.sort_by_key(edge => {
      let head_order = match node_order.get(edge.head().name()) {
        Some(value) => value
        None => 100000
      }
      head_order * 100000 + edge.id()
    })
    let mut prev_head = node_name
    for edge in out_edges {
      let head_name = edge.head().name()
      if prev_head != head_name && written_nodes.get(head_name) != Some(true) {
        match layout_node_by_name.get(head_name) {
          Some(node_layout) => {
            let node_id = match node_order.get(head_name) {
              Some(value) => value + 1
              None => 1
            }
            write_svg_node_group(
              sb,
              node_layout,
              fixedshape_draw_sizes,
              bbox,
              node_id,
              pretty,
            )
            written_nodes[head_name] = true
          }
          None => ()
        }
        prev_head = head_name
      }
      if written_edges.get(edge.id()) != Some(true) {
        match layout_edge_by_id.get(edge.id()) {
          Some(edge_layout) => {
            let edge_id = match edge_attr(edge, "id") {
              Some(value) => if value != "" { value } else {
                match edge_order.get(edge.id()) {
                  Some(order) => "edge\{order + 1}"
                  None => "edge1"
                }
              }
              None =>
                match edge_order.get(edge.id()) {
                  Some(order) => "edge\{order + 1}"
                  None => "edge1"
                }
            }
            write_svg_edge_group(
              sb,
              edge_layout,
              kind,
              bbox,
              edge_id,
              pretty,
            )
            written_edges[edge.id()] = true
          }
          None => ()
        }
      }
    }
  }
  write_line(sb, "</g>", "", pretty)
  write_line(sb, "</svg>", "", pretty)
  normalize_svg_alpha_attrs(sb.to_string())
}
