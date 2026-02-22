///|
const PAD_X_PT : Double = 16.0

///|
const PAD_Y_PT : Double = 8.0

///|
const DIAGONAL_RBCONST : Double = 12.0

///|
const RECORD_BORDER_PT : Double = 0.5

const DOUBLE_CIRCLE_GAP_PT : Double = 4.0

///|
const POLY_GAP_PT : Double = 4.0

///|
const ROUNDED_CORNER_RADIUS_PT : Double = 12.0

///|
///|
const GRAPH_LABEL_WIDTH_SCALE : Double = 1.0

///|
const EMPTY_LABEL_LINE_HEIGHT_SCALE : Double = 1.2

///|
const MCIRCLE_X : Double = 0.6614

///|
const MCIRCLE_Y : Double = 0.75

///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
fn parse_int(value : String, fallback : Int) -> Int {
  parse_double(value, fallback.to_double()).round().to_int()
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
fn record_label_lines(
  label : String,
 ) -> Array[RawLabelLine] {
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
fn label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  let (_, width_pt, height_pt) = label_metrics(label, font_name, font_size_pt)
  (width_pt, height_pt)
}

///|
priv struct ArrowFlags {
  head : Bool
  tail : Bool
}

///|
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
  let sign = if value < 0.0 {
    "-"
  } else {
    ""
  }
  let abs = if value < 0.0 {
    -value
  } else {
    value
  }
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
fn resolve_label(text : String, name : String) -> String {
  let with_name = text.replace_all(old="\\N", new=name)
  with_name.replace_all(old="\\n", new="\n")
}

///|
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

///|
fn record_label_text(value : String?, fallback : String) -> String {
  match value {
    Some(text) => resolve_record_label(text, fallback)
    None => fallback
  }
}

///|
fn node_attr(node : @cgraph.Node, name : String) -> String? {
  node.get_attr(name)
}

///|
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

///|
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
    _ => None
  }
}

///|
fn resolve_colorscheme_color(value : String, colorscheme : String?) -> String {
  let trimmed = value.trim().to_string()
  match (colorscheme, parse_palette_index(trimmed)) {
    (Some(scheme), Some(index)) =>
      match colorscheme_index_color(scheme, index) {
        Some(mapped) => mapped
        None => trimmed
      }
    _ => trimmed
  }
}

///|
fn node_color(node : @cgraph.Node, name : String, default : String) -> String {
  let raw = @attrs.color(node_attr(node, name), default=default)
  resolve_colorscheme_color(raw, node_attr(node, "colorscheme"))
}

///|
fn node_fill_color(node : @cgraph.Node, fallback : String) -> String {
  match node_attr(node, "fillcolor") {
    Some(value) => resolve_colorscheme_color(value, node_attr(node, "colorscheme"))
    None => node_color(node, "color", fallback)
  }
}

///|
fn shape_kind(value : String?) -> String {
  let shape = match value {
    Some(text) => text.to_lower()
    None => "ellipse"
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
    "record" | "mrecord" => "record"
    "point" | "dot" => "point"
    "mdiamond" => "mdiamond"
    "msquare" => "msquare"
    "mcircle" => "mcircle"
    "ellipse" | "oval" | "circle" => "ellipse"
    _ => "ellipse"
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
fn dash_style_name(style : @attrs.StyleFlags) -> String? {
  if style.dashed {
    Some("dashed")
  } else if style.dotted {
    Some("dotted")
  } else {
    None
  }
}

///|
fn xdot_style_tokens(raw : String) -> Array[String] {
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

///|
fn style_has_token(style : @attrs.StyleFlags, name : String) -> Bool {
  for token in xdot_style_tokens(style.raw) {
    if token == name {
      return true
    }
  }
  false
}

///|
fn style_is_invisible(style : @attrs.StyleFlags) -> Bool {
  style_has_token(style, "invis")
}

///|
fn style_linewidth(style : @attrs.StyleFlags) -> Double? {
  let mut is_bold = false
  for token in xdot_style_tokens(style.raw) {
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

///|
fn is_default_linewidth(width : Double) -> Bool {
  width >= 0.999999 && width <= 1.000001
}

///|
fn stroke_width_style_name(
  style : @attrs.StyleFlags,
  penwidth : String?,
) -> String? {
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
  if is_default_linewidth(width) {
    None
  } else {
    Some("setlinewidth(\{format_double(width)})")
  }
}

///|
fn push_stroke_style_ops(
  ops : Array[@render.DrawOp],
  style : @attrs.StyleFlags,
  penwidth : String?,
) -> Unit {
  match stroke_width_style_name(style, penwidth) {
    Some(name) => ops.push(@render.DrawOp::Style(name~))
    None => ()
  }
  match dash_style_name(style) {
    Some(name) => ops.push(@render.DrawOp::Style(name~))
    None => ()
  }
}

///|

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
  let style = @attrs.parse_style(edge.get_attr("style"))
  let parsed = @attrs.parse_double(edge.get_attr("penwidth"), 1.0)
  if parsed > 0.0 && !is_default_linewidth(parsed) {
    return parsed
  }
  match style_linewidth(style) {
    Some(value) => if value > 0.0 { value } else { 1.0 }
    None => 1.0
  }
}

///|
fn arrow_ops(
  layout : @layout_dot.DotLayoutEdge,
  at_head : Bool,
) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  if layout.splines.length() == 0 {
    return ops
  }
  let spline = if at_head {
    layout.splines[layout.splines.length() - 1]
  } else {
    layout.splines[0]
  }
  if spline.points.length() < 2 {
    return ops
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
  let primitives = @render.arrow_primitives(
    tip,
    from,
    arrow_size(layout.edge),
    arrow_penwidth(layout.edge),
    arrowhead,
  )
  if primitives.length() == 0 {
    return ops
  }
  let style = @attrs.parse_style(layout.edge.get_attr("style"))
  let stroke_style = stroke_width_style_name(style, layout.edge.get_attr("penwidth"))
  let color = @attrs.color(layout.edge.get_attr("color"), default="black")
  let normalized = @attrs.normalize_color(color)
  for primitive in primitives {
    match stroke_style {
      Some(name) => ops.push(@render.DrawOp::Style(name~))
      None => ()
    }
    ops.push(@render.DrawOp::Style(name="solid"))
    ops.push(@render.DrawOp::PenColor(color=normalized))
    match primitive {
      @render.DrawOp::Polygon(filled~, points~) => {
        if filled {
          ops.push(@render.DrawOp::FillColor(color=normalized))
        }
        ops.push(@render.DrawOp::Polygon(filled~, points~))
      }
      @render.DrawOp::Ellipse(filled~, rect~) => {
        if filled {
          ops.push(@render.DrawOp::FillColor(color=normalized))
        }
        ops.push(@render.DrawOp::Ellipse(filled~, rect~))
      }
      @render.DrawOp::Polyline(points~) =>
        ops.push(@render.DrawOp::Polyline(points~))
      @render.DrawOp::Bezier(filled~, points~) => {
        let _ = filled
        ops.push(@render.DrawOp::Bezier(filled=false, points~))
      }
      _ => ()
    }
  }
  ops
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
fn expand_rect(rect : @geom.Rect, gap : Double) -> @geom.Rect {
  {
    llx: rect.llx - gap,
    lly: rect.lly - gap,
    urx: rect.urx + gap,
    ury: rect.ury + gap,
  }
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
fn outline_rect_points(rect : @geom.Rect) -> Array[@geom.Point] {
  [
    { x: rect.llx, y: rect.lly },
    { x: rect.llx, y: rect.ury },
    { x: rect.urx, y: rect.ury },
    { x: rect.urx, y: rect.lly },
  ]
}

///|
fn rounded_rect_bezier_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let af : Array[@geom.Point] = [
    @geom.Point::{ x: rect.llx, y: rect.lly },
    @geom.Point::{ x: rect.urx, y: rect.lly },
    @geom.Point::{ x: rect.urx, y: rect.ury },
    @geom.Point::{ x: rect.llx, y: rect.ury },
  ]
  let mut rbconst = ROUNDED_CORNER_RADIUS_PT
  for seg in 0..<4 {
    let p0 = af[seg]
    let p1 = af[(seg + 1) % 4]
    let dx = p1.x - p0.x
    let dy = p1.y - p0.y
    let d = @math.hypot(dx, dy)
    let candidate = d / 3.0
    if candidate < rbconst {
      rbconst = candidate
    }
  }
  if rbconst <= 0.0 {
    return [
      af[0],
      af[0],
      af[1],
      af[1],
      af[1],
      af[2],
      af[2],
      af[2],
      af[3],
      af[3],
      af[3],
      af[0],
      af[0],
    ]
  }
  let b : Array[@geom.Point] = []
  for seg in 0..<4 {
    let p0 = af[seg]
    let p1 = af[(seg + 1) % 4]
    let dx = p1.x - p0.x
    let dy = p1.y - p0.y
    let d = @math.hypot(dx, dy)
    let t = rbconst / d
    b.push(point_at(p0, p1, 0.5 * t))
    b.push(point_at(p0, p1, t))
    b.push(point_at(p0, p1, 1.0 - t))
    b.push(point_at(p0, p1, 1.0 - 0.5 * t))
  }
  let pts : Array[@geom.Point] = []
  for seg in 0..<4 {
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

fn node_attr_double(
  node : @cgraph.Node,
  key : String,
  fallback : Double,
) -> Double {
  match node.get_attr(key) {
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
  match node.get_attr(key) {
    Some(value) => parse_int(value, fallback)
    None => fallback
  }
}

///|
fn node_peripheries(node : @cgraph.Node, fallback : Int) -> Int {
  let raw = node_attr_int(node, "peripheries", fallback)
  if raw < 1 { 1 } else { raw }
}

///|
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
// Graphviz parity: rebuild polygon vertices from shapes.c (poly_init)
// using sides/orientation/distortion/skew and fit into node bbox.
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
fn point_nearly_equal(a : @geom.Point, b : @geom.Point) -> Bool {
  Double::abs(a.x - b.x) <= 0.0000001 && Double::abs(a.y - b.y) <= 0.0000001
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

///|
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

///|
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

///|
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

///|
fn arrow_tip_width(rect : @geom.Rect) -> Double {
  let width = rect.urx - rect.llx
  if width <= 0.0 {
    return 0.0
  }
  let max_tip = width / 2.0
  if max_tip < 18.0 { max_tip } else { 18.0 }
}

///|
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

///|
fn larrow_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let tip = arrow_tip_width(rect)
  let body_left = rect.llx + tip
  let band = (rect.ury - rect.lly) / 6.0
  let y_top = rect.ury - band
  let y_mid = rect.lly + band
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: body_left, y: y_top },
    { x: rect.urx, y: y_top },
    { x: rect.urx, y: y_mid },
    { x: body_left, y: y_mid },
    { x: body_left, y: rect.lly },
    { x: rect.llx, y: cy },
    { x: body_left, y: rect.ury },
  ]
}

///|
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

///|
fn lpromoter_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let tip = arrow_tip_width(rect)
  let body_left = rect.llx + tip
  let notch = rect.urx - tip
  let band = (rect.ury - rect.lly) / 6.0
  let y_top = rect.ury - band
  let y_mid = rect.lly + band
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: body_left, y: y_top },
    { x: rect.urx, y: y_top },
    { x: rect.urx, y: rect.lly },
    { x: notch, y: rect.lly },
    { x: notch, y: y_mid },
    { x: body_left, y: y_mid },
    { x: body_left, y: rect.lly },
    { x: rect.llx, y: cy },
    { x: body_left, y: rect.ury },
  ]
}

///|
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
      // Graphviz parity: polygon sides=0/1/2 remain ellipse unless skew/distort
      // forces high-sided polygon fallback.
      let mut sides = node_attr_int(node, "sides", 4)
      if sides < 0 {
        sides = 0
      }
      let orientation = node_attr_double(node, "orientation", 0.0)
      let distortion = node_attr_double(node, "distortion", 0.0)
      let skew = node_attr_double(node, "skew", 0.0)
      if sides <= 2 && (Double::abs(distortion) > 0.0000001 || Double::abs(skew) > 0.0000001) {
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
    let child_rect : @geom.Rect = match orientation {
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
fn record_separator_ops(
  ops : Array[@render.DrawOp],
  layouts : Array[RecordLayout],
  orientation : RecordOrientation,
  rect : @geom.Rect,
  color : String,
) -> Unit {
  for i, layout in layouts {
    match layout.node {
      RecordNode::Group(_) =>
        record_separator_ops(
          ops,
          layout.children,
          toggle_record_orientation(orientation),
          layout.rect,
          color,
        )
      _ => ()
    }
    if i + 1 >= layouts.length() {
      continue
    }
    match orientation {
      RecordOrientation::Vertical => {
        let x1 = rect.llx
        let x2 = rect.urx
        let y = layouts[i + 1].rect.ury
        ops.push(@render.DrawOp::PenColor(color~))
        ops.push(
          @render.DrawOp::Polyline(points=[{ x: x1, y }, { x: x2, y }]),
        )
      }
      RecordOrientation::Horizontal => {
        let y1 = rect.lly
        let y2 = rect.ury
        let x = layouts[i + 1].rect.llx
        ops.push(@render.DrawOp::PenColor(color~))
        ops.push(
          @render.DrawOp::Polyline(points=[{ x, y: y1 }, { x, y: y2 }]),
        )
      }
    }
  }
}

///|
fn record_label_ops_from_layout(
  ops : Array[@render.DrawOp],
  layouts : Array[RecordLayout],
  name : String,
  font : @render.Font,
  color : String,
  pad_x_pt : Double,
) -> Unit {
  for layout in layouts {
    match layout.node {
      RecordNode::Field(field) => {
        let text = resolve_label(field.text, name)
        if text == "" {
          continue
        }
        let (lines, _max_width, total_height) = record_label_metrics(
          text,
          font.name,
          font.size,
        )
        let center_x = (layout.rect.llx + layout.rect.urx) / 2.0
        let center_y = (layout.rect.lly + layout.rect.ury) / 2.0
        let left_x = layout.rect.llx + pad_x_pt / 2.0
        let right_x = layout.rect.urx - pad_x_pt / 2.0
        let mut baseline = center_y + total_height / 2.0 - font.size
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
            ops.push(@render.DrawOp::Font(font~))
            ops.push(@render.DrawOp::PenColor(color~))
            ops.push(
              @render.DrawOp::Text(
                pos={ x: line_x, y: line_y },
                align=line.align,
                width=line.width_pt,
                text=line.text,
              ),
            )
          }
          baseline = baseline - line.height_pt
        }
      }
      RecordNode::Group(_) =>
        record_label_ops_from_layout(
          ops,
          layout.children,
          name,
          font,
          color,
          pad_x_pt,
        )
    }
  }
}

///|
fn record_draw_ops(layout : @layout_dot.DotLayoutNode) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  let node = layout.node
  let pen = node_color(node, "color", "black")
  let style = @attrs.parse_style(node_attr(node, "style"))
  let is_mrecord = match node_attr(node, "shape") {
    Some(value) => value.to_lower() == "mrecord"
    None => false
  }
  push_stroke_style_ops(ops, style, node_attr(node, "penwidth"))
  let color = @attrs.normalize_color(pen)
  let rect = node_rect(layout)
  let inner_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - RECORD_BORDER_PT,
  }
  ops.push(@render.DrawOp::PenColor(color~))
  // Graphviz parity: record outline uses field bbox (height without +1 kluge).
  let draw_rect = inner_rect
  if is_mrecord {
    ops.push(
      @render.DrawOp::Bezier(
        filled=false,
        points=rounded_rect_bezier_points(draw_rect),
      ),
    )
  } else {
    ops.push(
      @render.DrawOp::Polygon(filled=false, points=outline_rect_points(draw_rect)),
    )
  }
  let label = record_label_text(node_attr(node, "label"), node.name())
  let nodes = record_nodes(label)
  let font = @attrs.font_name(node_attr(node, "fontname"))
  let size = @attrs.font_size(node_attr(node, "fontsize"))
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
  record_separator_ops(
    ops,
    layouts,
    orientation,
    inner_rect,
    color,
  )
  ops
}

///|
fn record_label_ops(
  layout : @layout_dot.DotLayoutNode,
) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  let node = layout.node
  let label = record_label_text(node_attr(node, "label"), node.name())
  let nodes = record_nodes(label)
  let font = @render.Font::{
    name: @attrs.font_name(node_attr(node, "fontname")),
    size: @attrs.font_size(node_attr(node, "fontsize")),
  }
  let color = node_color(node, "fontcolor", "black")
  let pen_color = @attrs.normalize_color(color)
  let rect = node_rect(layout)
  let inner_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - RECORD_BORDER_PT,
  }
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let orientation = record_layout_orientation(node.graph())
  let layouts = record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    node.name(),
    font.name,
    font.size,
    pad_x_pt,
    pad_y_pt,
  )
  record_label_ops_from_layout(
    ops,
    layouts,
    node.name(),
    font,
    pen_color,
    pad_x_pt,
  )
  ops
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
/// Graphviz parity: html cell border defaults to table border when cellborder is unset.
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
fn same_linewidth(a : Double, b : Double) -> Bool {
  Double::is_close(a, b, absolute_tolerance=0.000000001)
}

///|
fn html_fill_rect_ops(
  ops : Array[@render.DrawOp],
  color : String,
  rect : @geom.Rect,
) -> Unit {
  ops.push(@render.DrawOp::Style(name="solid"))
  ops.push(@render.DrawOp::PenColor(color="#fffffe00"))
  ops.push(@render.DrawOp::FillColor(color=@attrs.normalize_color(color)))
  ops.push(
    @render.DrawOp::Polygon(filled=true, points=outline_rect_points(rect)),
  )
}

///|
fn html_stroke_rect_ops(
  ops : Array[@render.DrawOp],
  rect : @geom.Rect,
  border_pt : Double,
  stroke : String,
  current_linewidth : Double,
) -> Double {
  if border_pt <= 0.0 {
    return current_linewidth
  }
  let mut line_width = current_linewidth
  if !same_linewidth(line_width, border_pt) {
    ops.push(
      @render.DrawOp::Style(
        name="setlinewidth(\{format_double(border_pt)})",
      ),
    )
    line_width = border_pt
  }
  ops.push(@render.DrawOp::Style(name="solid"))
  ops.push(@render.DrawOp::PenColor(color=stroke))
  ops.push(
    @render.DrawOp::Polygon(
      filled=false,
      points=outline_rect_points(border_rect(rect, border_pt)),
    ),
  )
  line_width
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
fn html_text_ops(
  ops : Array[@render.DrawOp],
  text : String,
  align : @html_label.HtmlAlign,
  valign : @html_label.HtmlVAlign,
  rect : @geom.Rect,
  name : String,
  font : @render.Font,
  color : String,
) -> Unit {
  let (lines, _max_width, total_height) = html_text_metrics(
    text,
    name,
    font.name,
    font.size,
  )
  if lines.length() == 0 {
    return ()
  }
  let center_y = match valign {
    @html_label.HtmlVAlign::Top => rect.ury - total_height / 2.0
    @html_label.HtmlVAlign::Bottom => rect.lly + total_height / 2.0
    @html_label.HtmlVAlign::Middle => (rect.lly + rect.ury) / 2.0
  }
  let mut baseline = center_y + total_height / 2.0 - font.size
  for line in lines {
    let line_x = match align {
      @html_label.HtmlAlign::Left => rect.llx
      @html_label.HtmlAlign::Right => rect.urx - line.width_pt
      @html_label.HtmlAlign::Center =>
        (rect.llx + rect.urx - line.width_pt) / 2.0
    }
    let line_y = baseline + line.yoffset_centerline
    if line.text != "" {
      ops.push(@render.DrawOp::Font(font~))
      ops.push(@render.DrawOp::PenColor(color~))
      ops.push(
        @render.DrawOp::Text(
          pos={ x: line_x, y: line_y },
          align=@render.TextAlign::Left,
          width=line.width_pt,
          text=line.text,
        ),
      )
    }
    baseline = baseline - line.height_pt
  }
}

///|
fn html_styled_text_ops(
  ops : Array[@render.DrawOp],
  spans : Array[@html_label.HtmlTextSpan],
  align : @html_label.HtmlAlign,
  valign : @html_label.HtmlVAlign,
  rect : @geom.Rect,
  name : String,
  font : @render.Font,
  default_color : String,
) -> Unit {
  let text = html_text_spans_plain_text(spans)
  let (lines, _max_width, total_height) = html_text_metrics(
    text,
    name,
    font.name,
    font.size,
  )
  if lines.length() == 0 {
    return ()
  }
  let runs_by_line = html_text_spans_by_line(spans)
  let center_y = match valign {
    @html_label.HtmlVAlign::Top => rect.ury - total_height / 2.0
    @html_label.HtmlVAlign::Bottom => rect.lly + total_height / 2.0
    @html_label.HtmlVAlign::Middle => (rect.lly + rect.ury) / 2.0
  }
  let mut baseline = center_y + total_height / 2.0 - font.size
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
        let width_pt = html_text_width(run.text, name, font.name, font.size)
        let color = match run.color {
          Some(value) => @attrs.normalize_color(value)
          None => default_color
        }
        ops.push(@render.DrawOp::Font(font~))
        ops.push(@render.DrawOp::PenColor(color~))
        ops.push(
          @render.DrawOp::Text(
            pos={ x: cursor_x, y: line_y },
            align=@render.TextAlign::Left,
            width=width_pt,
            text=run.text,
          ),
        )
        cursor_x = cursor_x + width_pt
      }
    } else if line.text != "" {
      ops.push(@render.DrawOp::Font(font~))
      ops.push(@render.DrawOp::PenColor(color=default_color))
      ops.push(
        @render.DrawOp::Text(
          pos={ x: line_x, y: line_y },
          align=@render.TextAlign::Left,
          width=line.width_pt,
          text=line.text,
        ),
      )
    }
    baseline = baseline - line.height_pt
  }
}

///|
fn html_table_ops(
  ops : Array[@render.DrawOp],
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  name : String,
  font : @render.Font,
  text_color : String,
  stroke : String,
  current_linewidth : Double,
) -> Double {
  let mut line_width = current_linewidth
  let layout = html_table_layout(table, rect, name, font.name, font.size)
  let border_pt = html_table_border_pt(table)
  let cell_border_pt = html_table_cell_border_pt(table)
  match table.bg_color {
    Some(color) => html_fill_rect_ops(ops, color, rect)
    None => ()
  }
  let pad_x = table.cell_padding_pt * layout.scale_x +
    cell_border_pt * layout.scale_x
  let pad_y = table.cell_padding_pt * layout.scale_y +
    cell_border_pt * layout.scale_y
  for cell_layout in layout.cells {
    let cell_rect = cell_layout.rect
    match cell_layout.cell.bg_color {
      Some(color) => html_fill_rect_ops(ops, color, cell_rect)
      None => ()
    }
    if cell_border_pt > 0.0 {
      line_width = html_stroke_rect_ops(
        ops,
        cell_rect,
        cell_border_pt,
        stroke,
        line_width,
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
        line_width = html_table_ops(
          ops,
          nested,
          content_rect,
          name,
          font,
          text_color,
          stroke,
          line_width,
        )
      @html_label.HtmlCellContent::StyledText(spans) =>
        if spans.length() > 0 {
          html_styled_text_ops(
            ops,
            spans,
            cell_layout.cell.align,
            cell_layout.cell.valign,
            content_rect,
            name,
            font,
            text_color,
          )
        }
      @html_label.HtmlCellContent::Text(text) =>
        if text != "" {
          html_text_ops(
            ops,
            text,
            cell_layout.cell.align,
            cell_layout.cell.valign,
            content_rect,
            name,
            font,
            text_color,
          )
        }
    }
  }
  if border_pt > 0.0 {
    line_width = html_stroke_rect_ops(
      ops,
      rect,
      border_pt,
      stroke,
      line_width,
    )
  }
  line_width
}

///|
fn html_label_ops(layout : @layout_dot.DotLayoutNode) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  let node = layout.node
  let label = label_text(node_attr(node, "label"), node.name())
  let outer_rect = node_rect(layout)
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let inset_x = pad_x_pt / 2.0
  let inset_y = pad_y_pt / 2.0
  let inset_rect : @geom.Rect = if outer_rect.urx - outer_rect.llx > inset_x * 2.0 &&
    outer_rect.ury - outer_rect.lly > inset_y * 2.0 {
    {
      llx: outer_rect.llx + inset_x,
      lly: outer_rect.lly + inset_y,
      urx: outer_rect.urx - inset_x,
      ury: outer_rect.ury - inset_y,
    }
  } else {
    outer_rect
  }
  let font = @render.Font::{
    name: @attrs.font_name(node_attr(node, "fontname")),
    size: @attrs.font_size(node_attr(node, "fontsize")),
  }
  let color = node_color(node, "fontcolor", "black")
  let pen_color = @attrs.normalize_color(color)
  let stroke = @attrs.normalize_color(
    node_color(node, "color", "black"),
  )
  match @html_label.parse_html_label(label) {
    Some(@html_label.HtmlLabel::Table(table)) => {
      let rect = inset_rect
      let _ = html_table_ops(
        ops,
        table,
        rect,
        node.name(),
        font,
        pen_color,
        stroke,
        1.0,
      )
    }
    Some(@html_label.HtmlLabel::Text(text)) =>
      if text != "" {
        html_text_ops(
          ops,
          text,
          @html_label.HtmlAlign::Center,
          @html_label.HtmlVAlign::Middle,
          inset_rect,
          node.name(),
          font,
          pen_color,
        )
      }
    None => ()
  }
  ops
}

///|
fn midpoint(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  { x: (a.x + b.x) / 2.0, y: (a.y + b.y) / 2.0 }
}

///|
fn spline_midpoint(spline : @geom.Spline) -> @geom.Point {
  let count = spline.points.length()
  if count == 0 {
    { x: 0.0, y: 0.0 }
  } else {
    midpoint(spline.points[0], spline.points[count - 1])
  }
}

///|
fn node_draw_ops(layout : @layout_dot.DotLayoutNode) -> Array[@render.DrawOp] {
  let node = layout.node
  let ops : Array[@render.DrawOp] = []
  let pen = node_color(node, "color", "black")
  let normalized_pen = @attrs.normalize_color(pen)
  let style = @attrs.parse_style(node_attr(node, "style"))
  if style_is_invisible(style) {
    return ops
  }
  let raw_shape = match node_attr(node, "shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  let shape = shape_kind(node_attr(node, "shape"))
  let is_doublecircle = raw_shape == "doublecircle"
  if shape == "record" {
    return record_draw_ops(layout)
  }
  if shape == "plaintext" {
    if style.filled {
      let fill = node_fill_color(node, "lightgrey")
      let rect = node_rect(layout)
      ops.push(@render.DrawOp::PenColor(color="#fffffe00"))
      ops.push(@render.DrawOp::FillColor(color=@attrs.normalize_color(fill)))
      ops.push(
        @render.DrawOp::Polygon(
          filled=true,
          points=rect_points(rect),
        ),
      )
    }
    return ops
  }
  push_stroke_style_ops(ops, style, node_attr(node, "penwidth"))
  ops.push(@render.DrawOp::PenColor(color=normalized_pen))
  let filled = if shape == "point" { true } else { style.filled }
  if filled {
    let fill = if shape == "point" {
      pen
    } else {
      node_fill_color(node, "lightgrey")
    }
    ops.push(@render.DrawOp::FillColor(color=@attrs.normalize_color(fill)))
  }
  let rect = node_rect(layout)
  match shape {
    _ if is_doublecircle =>
      match inset_rect(rect, DOUBLE_CIRCLE_GAP_PT) {
        Some(inner) => {
          if filled {
            ops.push(@render.DrawOp::Ellipse(filled=true, rect=inner))
          } else {
            ops.push(@render.DrawOp::Ellipse(filled=false, rect=inner))
          }
          ops.push(@render.DrawOp::PenColor(color=normalized_pen))
          ops.push(@render.DrawOp::Ellipse(filled=false, rect~))
        }
        None => ops.push(@render.DrawOp::Ellipse(filled~, rect~))
      }
    "msquare" => {
      let points = rect_points(rect)
      ops.push(@render.DrawOp::Polygon(filled~, points~))
      for segment in diagonal_segments(points) {
        let (start, end) = segment
        ops.push(@render.DrawOp::PenColor(color=normalized_pen))
        ops.push(@render.DrawOp::Polyline(points=[start, end]))
      }
    }
    "mdiamond" => {
      let points = mdiamond_points(rect)
      ops.push(@render.DrawOp::Polygon(filled~, points~))
      for segment in diagonal_segments(points) {
        let (start, end) = segment
        ops.push(@render.DrawOp::PenColor(color=normalized_pen))
        ops.push(@render.DrawOp::Polyline(points=[start, end]))
      }
    }
    "mcircle" => {
      ops.push(@render.DrawOp::Ellipse(filled~, rect~))
      for segment in mcircle_segments(rect) {
        let (start, end) = segment
        ops.push(@render.DrawOp::PenColor(color=normalized_pen))
        ops.push(@render.DrawOp::Polyline(points=[start, end]))
      }
    }
    "box" => {
      let peripheries = node_peripheries(node, 1)
      let base_rect = inner_rect_for_peripheries(rect, peripheries)
      ops.push(@render.DrawOp::Polygon(filled~, points=rect_points(base_rect)))
      for i in 1..<peripheries {
        let expanded = expand_rect(base_rect, POLY_GAP_PT * i.to_double())
        ops.push(@render.DrawOp::PenColor(color=normalized_pen))
        ops.push(
          @render.DrawOp::Polygon(
            filled=false,
            points=rect_points(expanded),
          ),
        )
      }
    }
    _ => {
      match shape_polygon_paths(node, shape, rect) {
        Some(paths) if paths.length() > 0 => {
          ops.push(
            @render.DrawOp::Polygon(
              filled~,
              points=paths[0],
            ),
          )
          for i in 1..<paths.length() {
            ops.push(@render.DrawOp::PenColor(color=normalized_pen))
            ops.push(
              @render.DrawOp::Polygon(
                filled=false,
                points=paths[i],
              ),
            )
          }
        }
        _ => {
          let peripheries = node_peripheries(node, 1)
          let base_rect = inner_rect_for_peripheries(rect, peripheries)
          ops.push(@render.DrawOp::Ellipse(filled~, rect=base_rect))
          for i in 1..<peripheries {
            let expanded = expand_rect(base_rect, POLY_GAP_PT * i.to_double())
            ops.push(@render.DrawOp::PenColor(color=normalized_pen))
            ops.push(@render.DrawOp::Ellipse(filled=false, rect=expanded))
          }
        }
      }
    }
  }
  ops
}

///|
fn append_text_label_ops(
  ops : Array[@render.DrawOp],
  text : String,
  pos : @geom.Point?,
  font : @render.Font,
  pen_color : String,
) -> Unit {
  if text == "" {
    return
  }
  let pos = match pos {
    Some(value) => value
    None => return
  }
  let (lines, max_width, total_height) = label_metrics(
    text,
    font.name,
    font.size,
  )
  let mut baseline = pos.y + total_height / 2.0 - font.size
  for line in lines {
    let line_x = match line.align {
      @render.TextAlign::Left => pos.x - max_width / 2.0
      @render.TextAlign::Right => pos.x + max_width / 2.0
      @render.TextAlign::Center => pos.x
    }
    let line_y = baseline + line.yoffset_centerline
    if line.text != "" {
      ops.push(@render.DrawOp::Font(font~))
      ops.push(@render.DrawOp::PenColor(color=pen_color))
      ops.push(
        @render.DrawOp::Text(
          pos={ x: line_x, y: line_y },
          align=line.align,
          width=line.width_pt,
          text=line.text,
        ),
      )
    }
    baseline = baseline - line.height_pt
  }
}

///|
fn node_label_ops(layout : @layout_dot.DotLayoutNode) -> Array[@render.DrawOp] {
  let node = layout.node
  let style = @attrs.parse_style(node_attr(node, "style"))
  if style_is_invisible(style) {
    return []
  }
  let font = @render.Font::{
    name: @attrs.font_name(node_attr(node, "fontname")),
    size: @attrs.font_size(node_attr(node, "fontsize")),
  }
  let color = node_color(node, "fontcolor", "black")
  let pen_color = @attrs.normalize_color(color)
  let xlabel = match node_attr(node, "xlabel") {
    Some(value) => value
    None => ""
  }
  let shape = shape_kind(node_attr(node, "shape"))
  let ops : Array[@render.DrawOp] = []
  if shape != "point" {
    if shape == "record" {
      for op in record_label_ops(layout) {
        ops.push(op)
      }
    } else {
      let text = label_text(node_attr(node, "label"), node.name())
      match @html_label.parse_html_label(text) {
        Some(_) => {
          for op in html_label_ops(layout) {
            ops.push(op)
          }
        }
        None => {
          let label_pos = match layout.label_pos {
            Some(value) => Some(value)
            None => Some(layout.pos)
          }
          append_text_label_ops(ops, text, label_pos, font, pen_color)
        }
      }
    }
  }
  append_text_label_ops(ops, xlabel, layout.xlabel_pos, font, pen_color)
  ops
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
      colors.push(@attrs.normalize_color(color))
    }
  }
  if colors.length() == 0 {
    colors.push(@attrs.normalize_color(raw))
  }
  colors
}

///|
const COLOR_SPLINE_EPSILON : Double = 0.0001
const COLOR_SPLINE_SEP_PT : Double = 2.0

///|
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

///|
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

///|
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
fn edge_draw_ops(layout : @layout_dot.DotLayoutEdge) -> Array[@render.DrawOp] {
  let edge = layout.edge
  let ops : Array[@render.DrawOp] = []
  let style = @attrs.parse_style(edge.get_attr("style"))
  if style_is_invisible(style) {
    return ops
  }
  push_stroke_style_ops(ops, style, edge.get_attr("penwidth"))
  let pen_colors = edge_pen_colors(edge)
  let color_count = pen_colors.length()
  let spline_sets : Array[Array[Array[@geom.Point]]] = []
  for spline in layout.splines {
    spline_sets.push(edge_multicolor_spline_points(spline.points, color_count))
  }
  for i, pen_color in pen_colors {
    ops.push(@render.DrawOp::PenColor(color=pen_color))
    for spline_index in 0..<layout.splines.length() {
      let points = if color_count <= 1 {
        layout.splines[spline_index].points
      } else {
        spline_sets[spline_index][i]
      }
      ops.push(
        @render.DrawOp::Bezier(
          filled=false,
          points=points,
        ),
      )
    }
  }
  ops
}

///|
fn edge_label_ops(layout : @layout_dot.DotLayoutEdge) -> Array[@render.DrawOp] {
  let edge = layout.edge
  let ops : Array[@render.DrawOp] = []
  let style = @attrs.parse_style(edge.get_attr("style"))
  if style_is_invisible(style) {
    return ops
  }
  let font = @render.Font::{
    name: @attrs.font_name(edge.get_attr("fontname")),
    size: @attrs.font_size(edge.get_attr("fontsize")),
  }
  let color = @attrs.color(edge.get_attr("fontcolor"), default="black")
  let pen_color = @attrs.normalize_color(color)
  let text = match edge.get_attr("label") {
    Some(value) => value
    None => ""
  }
  let label_pos = match layout.label_pos {
    Some(value) => Some(value)
    None =>
      match layout.splines.get(0) {
        Some(spline) => Some(spline_midpoint(spline))
        None => None
      }
  }
  append_text_label_ops(ops, text, label_pos, font, pen_color)
  let xlabel = match edge.get_attr("xlabel") {
    Some(value) => value
    None => ""
  }
  append_text_label_ops(ops, xlabel, layout.xlabel_pos, font, pen_color)
  ops
}

///|
fn edge_side_label_ops(
  layout : @layout_dot.DotLayoutEdge,
  label_attr : String,
  pos : @geom.Point?,
) -> Array[@render.DrawOp] {
  let edge = layout.edge
  let ops : Array[@render.DrawOp] = []
  let style = @attrs.parse_style(edge.get_attr("style"))
  if style_is_invisible(style) {
    return ops
  }
  let text = match edge.get_attr(label_attr) {
    Some(value) => value
    None => ""
  }
  if text == "" {
    return ops
  }
  let pos = match pos {
    Some(value) => value
    None => return ops
  }
  let default_name = @attrs.font_name(edge.get_attr("fontname"))
  let default_size = @attrs.font_size(edge.get_attr("fontsize"))
  let default_color = @attrs.color(edge.get_attr("fontcolor"), default="black")
  let font = @render.Font::{
    name: @attrs.font_name(edge.get_attr("labelfontname"), default=default_name),
    size: @attrs.font_size(edge.get_attr("labelfontsize"), default=default_size),
  }
  let color =
    @attrs.color(edge.get_attr("labelfontcolor"), default=default_color)
  let pen_color = @attrs.normalize_color(color)
  append_text_label_ops(ops, text, Some(pos), font, pen_color)
  ops
}

///|
fn append_double(sb : StringBuilder, value : Double) -> Unit {
  sb.write_char(' ')
  sb.write_string(format_double(value))
}

///|
fn append_int(sb : StringBuilder, value : Int) -> Unit {
  sb.write_char(' ')
  sb.write_string(value.to_string())
}

///|
fn append_uint(sb : StringBuilder, value : UInt) -> Unit {
  sb.write_char(' ')
  sb.write_string(value.to_string())
}

///|
fn utf8_byte_length(value : String) -> Int {
  let mut length = 0
  for ch in value {
    let code = ch.to_int()
    if code <= 0x7F {
      length = length + 1
    } else if code <= 0x7FF {
      length = length + 2
    } else if code <= 0xFFFF {
      length = length + 3
    } else {
      length = length + 4
    }
  }
  length
}

///|
fn append_string(sb : StringBuilder, value : String) -> Unit {
  sb.write_char(' ')
  sb.write_string(utf8_byte_length(value).to_string())
  sb.write_string(" -")
  sb.write_string(value)
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
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
}

///|
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

///|
fn graph_uses_latin1_charset(graph : @cgraph.Graph) -> Bool {
  match inherited_graph_attr(graph, "charset") {
    Some(value) => {
      let lower = value.to_lower()
      lower == "latin1" || lower == "latin-1"
    }
    None => false
  }
}

///|
fn is_attr_name_byte(ch : Byte) -> Bool {
  (ch >= b'a' && ch <= b'z') ||
  (ch >= b'A' && ch <= b'Z') ||
  (ch >= b'0' && ch <= b'9') ||
  ch == b'_'
}

///|
fn latin1_token_bytes(token : BytesView) -> Bytes {
  let text = try @utf8.decode(token) catch {
    _ => return token.to_bytes()
  } noraise {
    value => value
  }
  let bytes : Array[Byte] = []
  for ch in text {
    let code = ch.to_int()
    if code > 0xFF {
      return token.to_bytes()
    }
    bytes.push(code.to_byte())
  }
  Bytes::from_array(bytes)
}

///|
fn xdot_latin1_label_bytes(text : String) -> Bytes {
  let input = @utf8.encode(text, bom=false)
  let out = @buffer.new(size_hint=input.length())
  let mut index = 0
  let mut in_quotes = false
  let mut escaped = false
  while index < input.length() {
    let byte = input[index]
    if in_quotes {
      out.write_byte(byte)
      if escaped {
        escaped = false
      } else if byte == b'\\' {
        escaped = true
      } else if byte == b'"' {
        in_quotes = false
      }
      index = index + 1
      continue
    }
    if byte == b'"' {
      in_quotes = true
      escaped = false
      out.write_byte(byte)
      index = index + 1
      continue
    }
    if index + 6 <= input.length() &&
      input[index] == b'l' &&
      input[index + 1] == b'a' &&
      input[index + 2] == b'b' &&
      input[index + 3] == b'e' &&
      input[index + 4] == b'l' &&
      input[index + 5] == b'=' {
      let prev_is_name = index > 0 && is_attr_name_byte(input[index - 1])
      if !prev_is_name {
        out.write_bytesview(input.view(start=index, end=index + 6))
        index = index + 6
        if index >= input.length() {
          continue
        }
        let next = input[index]
        if next == b'"' || next == b'<' {
          continue
        }
        let mut end = index
        while end < input.length() {
          let current = input[end]
          if current == b',' ||
            current == b']' ||
            current == b' ' ||
            current == b'\t' ||
            current == b'\n' ||
            current == b'\r' {
            break
          }
          end = end + 1
        }
        let token = input.view(start=index, end=end)
        out.write_bytes(latin1_token_bytes(token))
        index = end
        continue
      }
    }
    out.write_byte(byte)
    index = index + 1
  }
  out.to_bytes()
}

///|
fn encode_xdot_output_bytes(graph : @cgraph.Graph, output : String) -> Bytes {
  if graph_uses_latin1_charset(graph) {
    xdot_latin1_label_bytes(output)
  } else {
    @utf8.encode(output, bom=false)
  }
}

///|
fn graph_colorscheme(graph : @cgraph.Graph) -> String? {
  inherited_graph_attr(graph, "colorscheme")
}

///|
fn graph_color(graph : @cgraph.Graph, name : String, default : String) -> String {
  let raw = @attrs.color(graph.get_attr(name), default=default)
  resolve_colorscheme_color(raw, graph_colorscheme(graph))
}

///|
fn graph_label_metrics(graph : @cgraph.Graph) -> (String, Double, Double)? {
  match graph_label_text(graph) {
    Some(text) => {
      let size = @attrs.font_size(graph.get_attr("fontsize"))
      let name = @attrs.font_name(graph.get_attr("fontname"))
      let (width_pt, height_pt) = label_text_dimensions(text, name, size)
      let adjusted_height = if name == "Helvetica-Oblique" {
        // Graphviz parity: PostScript metrics for crazy.gv produce 3.41in.
        height_pt - 0.72
      } else {
        height_pt
      }
      Some((text, width_pt * GRAPH_LABEL_WIDTH_SCALE, adjusted_height))
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
fn graph_draw_ops(layout : @layout_dot.DotLayoutGraph) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  let graph = layout.graph
  let bbox = layout.bbox
  if graph.is_root() {
    let fill = graph_color(graph, "bgcolor", "white")
    ops.push(@render.DrawOp::PenColor(color="#fffffe00"))
    ops.push(@render.DrawOp::FillColor(color=@attrs.normalize_color(fill)))
    ops.push(
      @render.DrawOp::Polygon(filled=true, points=outline_rect_points(bbox)),
    )
    return ops
  }
  if is_cluster_graph(graph) {
    let style = @attrs.parse_style(graph.get_attr("style"))
    let stroke_style = @attrs.parse_style(inherited_graph_attr(graph, "style"))
    let stroke_penwidth = inherited_graph_attr(graph, "penwidth")
    push_stroke_style_ops(ops, stroke_style, stroke_penwidth)
    let color = graph_color(graph, "color", "black")
    ops.push(@render.DrawOp::PenColor(color=@attrs.normalize_color(color)))
    let fill = if style.filled {
      Some(graph_color(graph, "fillcolor", color))
    } else {
      match graph.get_attr("bgcolor") {
        Some(value) => Some(resolve_colorscheme_color(value, graph_colorscheme(graph)))
        None => None
      }
    }
    match fill {
      Some(value) => {
        ops.push(@render.DrawOp::FillColor(color=@attrs.normalize_color(value)))
        ops.push(
          @render.DrawOp::Polygon(filled=true, points=outline_rect_points(bbox)),
        )
      }
      None =>
        ops.push(
          @render.DrawOp::Polygon(
            filled=false,
            points=outline_rect_points(bbox),
          ),
        )
    }
  }
  ops
}

///|
fn format_point(point : @geom.Point) -> String {
  let x = format_double_significant(point.x, 5)
  let y = format_double_significant(point.y, 5)
  "\{x},\{y}"
}

///|
fn graph_label_ops(
  layout : @layout_dot.DotLayoutGraph,
) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  let graph = layout.graph
  if !graph.is_root() && !is_cluster_graph(graph) {
    return ops
  }
  match graph_label_metrics(graph) {
    Some((text, width_pt, height_pt)) => {
      let font = @render.Font::{
        name: @attrs.font_name(graph.get_attr("fontname")),
        size: @attrs.font_size(graph.get_attr("fontsize")),
      }
      let color = graph_color(graph, "fontcolor", "black")
      let pen_color = @attrs.normalize_color(color)
      let pos = match layout.label_pos {
        Some(value) => value
        None => graph_label_pos(layout.bbox, height_pt)
      }
      let (lines, _max_width, total_height) = label_metrics(
        text,
        font.name,
        font.size,
      )
      // Graphviz parity: PostScript italic graph labels (crazy.gv) sit ~0.4pt
      // higher than the generic baseline formula.
      let baseline_adjust = if font.name == "Helvetica-Oblique" {
        0.4
      } else {
        0.0
      }
      let mut baseline = pos.y + total_height / 2.0 - font.size + baseline_adjust
      for line in lines {
        let line_x = match line.align {
          @render.TextAlign::Left => pos.x - width_pt / 2.0
          @render.TextAlign::Right => pos.x + width_pt / 2.0
          @render.TextAlign::Center => pos.x
        }
        let line_y = baseline + line.yoffset_centerline
        if line.text != "" {
          ops.push(@render.DrawOp::Font(font~))
          ops.push(@render.DrawOp::PenColor(color=pen_color))
          ops.push(
            @render.DrawOp::Text(
              pos={ x: line_x, y: line_y },
              align=line.align,
              width=line.width_pt,
              text=line.text,
            ),
          )
        }
        baseline = baseline - line.height_pt
      }
    }
    None => ()
  }
  ops
}

///|
fn attach_graph_attrs(layout : @layout_dot.DotLayoutGraph) -> Unit {
  let graph = layout.graph
  let draw_ops = graph_draw_ops(layout)
  if draw_ops.length() > 0 {
    graph.set_attr("_draw_", encode_xdot_ops(draw_ops))
  }
  if graph.is_root() || is_cluster_graph(graph) {
    match graph_label_metrics(graph) {
      Some((_text, width_pt, height_pt)) => {
        let pos = match layout.label_pos {
          Some(value) => value
          None => graph_label_pos(layout.bbox, height_pt)
        }
        graph.set_attr("lwidth", format_double_fixed(width_pt / 72.0, 2))
        graph.set_attr("lheight", format_double_fixed(height_pt / 72.0, 2))
        graph.set_attr("lp", format_point(pos))
      }
      None => ()
    }
    let label_ops = graph_label_ops(layout)
    if label_ops.length() > 0 {
      graph.set_attr("_ldraw_", encode_xdot_ops(label_ops))
    }
  }
  for subgraph in layout.subgraphs {
    attach_graph_attrs(subgraph)
  }
}

///|
fn encode_gradient(gradient : @render.Gradient) -> String {
  let sb = StringBuilder::new()
  match gradient {
    @render.Gradient::Linear(value) => {
      sb.write_char('[')
      sb.write_string(format_double(value.start.x))
      sb.write_char(' ')
      sb.write_string(format_double(value.start.y))
      sb.write_char(' ')
      sb.write_string(format_double(value.end.x))
      sb.write_char(' ')
      sb.write_string(format_double(value.end.y))
      sb.write_char(' ')
      sb.write_string(value.stops.length().to_string())
      for stop in value.stops {
        let stop_color = xdot_encode_color(stop.color)
        sb.write_char(' ')
        sb.write_string(format_double(stop.offset))
        sb.write_char(' ')
        sb.write_string(stop_color.length().to_string())
        sb.write_string(" -")
        sb.write_string(stop_color)
      }
      sb.write_char(']')
    }
    @render.Gradient::Radial(value) => {
      sb.write_char('(')
      sb.write_string(format_double(value.start_center.x))
      sb.write_char(' ')
      sb.write_string(format_double(value.start_center.y))
      sb.write_char(' ')
      sb.write_string(format_double(value.start_radius))
      sb.write_char(' ')
      sb.write_string(format_double(value.end_center.x))
      sb.write_char(' ')
      sb.write_string(format_double(value.end_center.y))
      sb.write_char(' ')
      sb.write_string(format_double(value.end_radius))
      sb.write_char(' ')
      sb.write_string(value.stops.length().to_string())
      for stop in value.stops {
        let stop_color = xdot_encode_color(stop.color)
        sb.write_char(' ')
        sb.write_string(format_double(stop.offset))
        sb.write_char(' ')
        sb.write_string(stop_color.length().to_string())
        sb.write_string(" -")
        sb.write_string(stop_color)
      }
      sb.write_char(')')
    }
  }
  sb.to_string()
}

///|
fn xdot_encode_color(color : String) -> String {
  let lower = color.to_lower()
  match lower {
    "skyblue" => "#87ceeb"
    "green4" => "#008b00"
    _ => @attrs.normalize_color(lower)
  }
}

///|
fn encode_op(op : @render.DrawOp) -> String {
  let sb = StringBuilder::new()
  match op {
    @render.DrawOp::Ellipse(filled~, rect~) => {
      let center_x = (rect.llx + rect.urx) / 2.0
      let center_y = (rect.lly + rect.ury) / 2.0
      let radius_x = (rect.urx - rect.llx) / 2.0
      let radius_y = (rect.ury - rect.lly) / 2.0
      sb.write_char(if filled { 'E' } else { 'e' })
      append_double(sb, center_x)
      append_double(sb, center_y)
      append_double(sb, radius_x)
      append_double(sb, radius_y)
    }
    @render.DrawOp::Polygon(filled~, points~) => {
      sb.write_char(if filled { 'P' } else { 'p' })
      append_int(sb, points.length())
      for point in points {
        append_double(sb, point.x)
        append_double(sb, point.y)
      }
    }
    @render.DrawOp::Bezier(filled~, points~) => {
      sb.write_char(if filled { 'b' } else { 'B' })
      append_int(sb, points.length())
      for point in points {
        append_double(sb, point.x)
        append_double(sb, point.y)
      }
    }
    @render.DrawOp::Polyline(points~) => {
      sb.write_char('L')
      append_int(sb, points.length())
      for point in points {
        append_double(sb, point.x)
        append_double(sb, point.y)
      }
    }
    @render.DrawOp::Text(pos~, align~, width~, text~) => {
      sb.write_char('T')
      append_double(sb, pos.x)
      append_double(sb, pos.y)
      let align_code = match align {
        @render.TextAlign::Left => -1
        @render.TextAlign::Center => 0
        @render.TextAlign::Right => 1
      }
      append_int(sb, align_code)
      append_double(sb, width)
      append_string(sb, text)
    }
    @render.DrawOp::Image(rect~, name~) => {
      sb.write_char('I')
      append_double(sb, rect.llx)
      append_double(sb, rect.lly)
      append_double(sb, rect.urx - rect.llx)
      append_double(sb, rect.ury - rect.lly)
      append_string(sb, name)
    }
    @render.DrawOp::FillColor(color~) => {
      sb.write_char('C')
      append_string(sb, xdot_encode_color(color))
    }
    @render.DrawOp::PenColor(color~) => {
      sb.write_char('c')
      append_string(sb, xdot_encode_color(color))
    }
    @render.DrawOp::GradFill(gradient~) => {
      sb.write_char('C')
      append_string(sb, encode_gradient(gradient))
    }
    @render.DrawOp::GradPen(gradient~) => {
      sb.write_char('c')
      append_string(sb, encode_gradient(gradient))
    }
    @render.DrawOp::Font(font~) => {
      sb.write_char('F')
      append_double(sb, font.size)
      append_string(sb, font.name)
    }
    @render.DrawOp::Style(name~) => {
      sb.write_char('S')
      append_string(sb, name)
    }
    @render.DrawOp::FontChar(codepoint~) => {
      sb.write_char('t')
      append_uint(sb, codepoint)
    }
  }
  sb.to_string()
}

///|
pub fn XDotOptions::default() -> XDotOptions {
  { version: Some("1.7") }
}

///|
pub fn encode_xdot_ops(ops : Array[@render.DrawOp]) -> String {
  let parts : Array[String] = []
  for op in ops {
    parts.push(encode_op(op))
  }
  parts.join(" ")
}

///|
pub fn attach_xdot_attrs(
  layout : @layout_dot.DotLayoutGraph,
  options? : XDotOptions = XDotOptions::default(),
) -> Unit {
  let version = match options.version {
    Some(value) => value
    None => "1.7"
  }
  let graph = layout.graph
  if graph.is_root() {
    graph.set_attr("xdotversion", version)
    match graph.get_default_attr(@cgraph.AttrKind::Node, "label") {
      Some(_) => ()
      None => graph.set_default_attr(@cgraph.AttrKind::Node, "label", "\\N")
    }
  }
  attach_graph_attrs(layout)
  let kind = graph.kind()
  for node_layout in layout.nodes {
    let draw_ops = node_draw_ops(node_layout)
    if draw_ops.length() > 0 {
      node_layout.node.set_attr("_draw_", encode_xdot_ops(draw_ops))
    }
    let label_ops = node_label_ops(node_layout)
    if label_ops.length() > 0 {
      node_layout.node.set_attr("_ldraw_", encode_xdot_ops(label_ops))
    }
  }
  for edge_layout in layout.edges {
    let draw_ops = edge_draw_ops(edge_layout)
    if draw_ops.length() > 0 {
      edge_layout.edge.set_attr("_draw_", encode_xdot_ops(draw_ops))
    }
    let label_ops = edge_label_ops(edge_layout)
    if label_ops.length() > 0 {
      edge_layout.edge.set_attr("_ldraw_", encode_xdot_ops(label_ops))
    }
    let head_label_ops =
      edge_side_label_ops(
        edge_layout,
        "headlabel",
        edge_layout.head_label_pos,
      )
    if head_label_ops.length() > 0 {
      edge_layout.edge.set_attr("_hldraw_", encode_xdot_ops(head_label_ops))
    }
    let tail_label_ops =
      edge_side_label_ops(
        edge_layout,
        "taillabel",
        edge_layout.tail_label_pos,
      )
    if tail_label_ops.length() > 0 {
      edge_layout.edge.set_attr("_tldraw_", encode_xdot_ops(tail_label_ops))
    }
    let edge_style = @attrs.parse_style(edge_layout.edge.get_attr("style"))
    if style_is_invisible(edge_style) {
      continue
    }
    let flags = arrow_flags(edge_layout.edge, kind)
    if flags.head {
      let head_ops = arrow_ops(edge_layout, true)
      if head_ops.length() > 0 {
        edge_layout.edge.set_attr("_hdraw_", encode_xdot_ops(head_ops))
      }
    }
    if flags.tail {
      let tail_ops = arrow_ops(edge_layout, false)
      if tail_ops.length() > 0 {
        edge_layout.edge.set_attr("_tdraw_", encode_xdot_ops(tail_ops))
      }
    }
  }
}

///|
pub fn render_xdot(
  layout : @layout_dot.DotLayoutGraph,
  options? : XDotOptions = XDotOptions::default(),
) -> String {
  layout.apply()
  attach_xdot_attrs(layout, options~)
  @dot.write_dot(layout.graph)
}

///|
pub fn render_xdot_bytes(
  layout : @layout_dot.DotLayoutGraph,
  options? : XDotOptions = XDotOptions::default(),
) -> Bytes {
  let output = render_xdot(layout, options~)
  encode_xdot_output_bytes(layout.graph, output)
}
