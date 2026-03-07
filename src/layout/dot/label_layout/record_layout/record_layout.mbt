///|
/// Record-label parsing, sizing, layout, and port helpers for dot record
/// shapes and record-port routing behavior.

type RankDir = @shared.RankDir
type RecordOrientation = @shared.RecordOrientation
type NodeSize = @shared.NodeSize
type RecordPort = @shared.RecordPort
type SizePt = @shared.GraphSizePt

pub(all) struct RecordField {
  name : String?
  text : String
}

///|
pub(all) enum RecordNode {
  Field(RecordField)
  Group(Array[RecordNode])
}

///|
let record_nodes_cache : Ref[Map[String, Array[RecordNode]]] =
  @ref.new(Map::new())

///|
let record_ports_cache : Ref[Map[String, Map[String, RecordPort]]] =
  @ref.new(Map::new())

///|
pub fn reset_record_layout_caches() -> Unit {
  record_nodes_cache.val = Map::new()
  record_ports_cache.val = Map::new()
}

///|
pub fn toggle_record_orientation(
  orientation : RecordOrientation,
) -> RecordOrientation {
  match orientation {
    RecordOrientation::Horizontal => RecordOrientation::Vertical
    RecordOrientation::Vertical => RecordOrientation::Horizontal
  }
}

///|
pub(all) struct RecordParser {
  chars : Array[Char]
  mut index : Int
}

///|
pub fn parse_record_nodes(parser : RecordParser) -> Array[RecordNode] {
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
  let (port_name, raw_text) : (String?, String) = if trimmed.has_prefix("<") {
    match trimmed.find(">") {
      Some(pos) => {
        let name = if pos > 1 {
          trimmed.unsafe_substring(start=1, end=pos)
        } else {
          ""
        }
        let len = trimmed.length()
        let text = if pos + 1 < len {
          trimmed.unsafe_substring(start=pos + 1, end=len)
        } else {
          ""
        }
        let port_name : String? = if name == "" { None } else { Some(name) }
        (port_name, text)
      }
      None => (None, trimmed)
    }
  } else {
    (None, trimmed)
  }
  let normalized = normalize_record_text(raw_text).trim(chars=" \n\r\t").to_string()
  let text = if normalized == "" { " " } else { normalized }
  { name: port_name, text }
}

///|
fn normalize_record_text(text : String) -> String {
  let sb = StringBuilder::new()
  let mut escaping = false
  for ch in text {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        sb.write_char('\\')
        sb.write_char(ch)
      } else {
        sb.write_char(ch)
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    sb.write_char(ch)
  }
  if escaping {
    sb.write_char('\\')
  }
  sb.to_string()
}

///|
pub fn record_nodes(label : String) -> Array[RecordNode] {
  match record_nodes_cache.val.get(label) {
    Some(cached) => cached
    None => {
      let chars : Array[Char] = []
      for ch in label {
        chars.push(ch)
      }
      let parser = RecordParser::{ chars, index: 0 }
      // Graphviz parity: preserve outer braces as an explicit group.
      // Do not flatten a single top-level group; it flips field orientation.
      let nodes = parse_record_nodes(parser)
      record_nodes_cache.val[label] = nodes
      nodes
    }
  }
}
///|
/// Record-field sizing, rectangle layout, and port geometry helpers used by
/// label/edge routing and vnode preparation paths.


///|
pub fn record_nodes_sizes(
  nodes : Array[RecordNode],
  orientation : RecordOrientation,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> Array[SizePt] {
  let sizes : Array[SizePt] = []
  for node in nodes {
    match node {
      RecordNode::Field(field) => {
        let (text_width_pt, text_height_pt) = @label_metrics.record_label_text_dimensions(
          field.text,
          font_name,
          font_size_pt,
        )
        let width_pt = text_width_pt + pad_x_pt
        let height_pt = text_height_pt + pad_y_pt
        sizes.push({ width_pt, height_pt })
      }
      RecordNode::Group(children) => {
        let size = record_group_size(
          children,
          toggle_record_orientation(orientation),
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
pub fn record_group_size(
  nodes : Array[RecordNode],
  orientation : RecordOrientation,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> SizePt {
  let sizes = record_nodes_sizes(
    nodes, orientation, font_name, font_size_pt, pad_x_pt, pad_y_pt,
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
fn record_layout_nodes(
  nodes : Array[RecordNode],
  rect : @geom.Rect,
  orientation : RecordOrientation,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
  sides : Int,
  rects : Array[@geom.Rect],
  ports : Map[String, RecordPort],
) -> Unit {
  if nodes.length() == 0 {
    return ()
  }
  let sizes = record_nodes_sizes(
    nodes, orientation, font_name, font_size_pt, pad_x_pt, pad_y_pt,
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
  let mut cursor = match orientation {
    RecordOrientation::Vertical => rect.ury
    RecordOrientation::Horizontal => rect.llx
  }
  let last = nodes.length() - 1
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
    let child_sides =
      if sides == 0 {
      0
    } else {
      let mut mask = 0
      match orientation {
        RecordOrientation::Horizontal =>
          if i == 0 {
            if i == last {
              mask =
                @port_geometry.PORT_SIDE_TOP |
                @port_geometry.PORT_SIDE_BOTTOM |
                @port_geometry.PORT_SIDE_LEFT |
                @port_geometry.PORT_SIDE_RIGHT
            } else {
              mask = @port_geometry.PORT_SIDE_TOP | @port_geometry.PORT_SIDE_BOTTOM | @port_geometry.PORT_SIDE_LEFT
            }
          } else if i == last {
            mask = @port_geometry.PORT_SIDE_TOP | @port_geometry.PORT_SIDE_BOTTOM | @port_geometry.PORT_SIDE_RIGHT
          } else {
            mask = @port_geometry.PORT_SIDE_TOP | @port_geometry.PORT_SIDE_BOTTOM
          }
        RecordOrientation::Vertical =>
          if i == 0 {
            if i == last {
              mask =
                @port_geometry.PORT_SIDE_TOP |
                @port_geometry.PORT_SIDE_BOTTOM |
                @port_geometry.PORT_SIDE_LEFT |
                @port_geometry.PORT_SIDE_RIGHT
            } else {
              mask = @port_geometry.PORT_SIDE_TOP | @port_geometry.PORT_SIDE_LEFT | @port_geometry.PORT_SIDE_RIGHT
            }
          } else if i == last {
            mask = @port_geometry.PORT_SIDE_LEFT | @port_geometry.PORT_SIDE_BOTTOM | @port_geometry.PORT_SIDE_RIGHT
          } else {
            mask = @port_geometry.PORT_SIDE_LEFT | @port_geometry.PORT_SIDE_RIGHT
          }
      }
      sides & mask
    }
    match nodes[i] {
      RecordNode::Field(field) => {
        rects.push(child_rect)
        match field.name {
          Some(name) => {
            let center = @geom.Point::{
              x: (child_rect.llx + child_rect.urx) / 2.0,
              y: (child_rect.lly + child_rect.ury) / 2.0,
            }
            let field_size = @shared.node_size_from_points(
              child_rect.urx - child_rect.llx,
              child_rect.ury - child_rect.lly,
            )
            ports[name] = {
              center,
              size: field_size,
              sides: child_sides,
            }
          }
          None => ()
        }
      }
      RecordNode::Group(children) =>
        record_layout_nodes(
          children,
          child_rect,
          toggle_record_orientation(orientation),
          font_name,
          font_size_pt,
          pad_x_pt,
          pad_y_pt,
          child_sides,
          rects,
          ports,
        )
    }
  }
}

///|
pub fn record_rects(
  node : @cgraph.Node,
  pos : @geom.Point,
  size : NodeSize,
  orientation : RecordOrientation,
) -> Array[@geom.Rect] {
  let label = @label_attrs.label_text(node)
  let nodes = record_nodes(label)
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let padding = @label_attrs.node_padding(node)
  let rects : Array[@geom.Rect] = []
  let ports : Map[String, RecordPort] = Map::new()
  let rect : @geom.Rect = {
    llx: pos.x - size.width_pt / 2.0,
    lly: pos.y - size.height_pt / 2.0,
    urx: pos.x + size.width_pt / 2.0,
    ury: pos.y + size.height_pt / 2.0,
  }
  let inner_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + @shared.RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - @shared.RECORD_BORDER_PT,
  }
  record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    font,
    font_size_pt,
    padding.pad_x_pt,
    padding.pad_y_pt,
    @port_geometry.PORT_SIDE_TOP | @port_geometry.PORT_SIDE_BOTTOM | @port_geometry.PORT_SIDE_LEFT | @port_geometry.PORT_SIDE_RIGHT,
    rects,
    ports,
  )
  rects
}

///|
pub fn record_ports(
  node : @cgraph.Node,
  pos : @geom.Point,
  size : NodeSize,
  orientation : RecordOrientation,
) -> Map[String, RecordPort] {
  let is_origin = pos.x == 0.0 && pos.y == 0.0
  if is_origin {
    let name = node.name()
    match record_ports_cache.val.get(name) {
      Some(cached) => return cached
      None => ()
    }
  }
  let label = @label_attrs.label_text(node)
  let nodes = record_nodes(label)
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let padding = @label_attrs.node_padding(node)
  let ports : Map[String, RecordPort] = Map::new()
  let rects : Array[@geom.Rect] = []
  let rect : @geom.Rect = {
    llx: pos.x - size.width_pt / 2.0,
    lly: pos.y - size.height_pt / 2.0,
    urx: pos.x + size.width_pt / 2.0,
    ury: pos.y + size.height_pt / 2.0,
  }
  let inner_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + @shared.RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - @shared.RECORD_BORDER_PT,
  }
  record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    font,
    font_size_pt,
    padding.pad_x_pt,
    padding.pad_y_pt,
    @port_geometry.PORT_SIDE_TOP | @port_geometry.PORT_SIDE_BOTTOM | @port_geometry.PORT_SIDE_LEFT | @port_geometry.PORT_SIDE_RIGHT,
    rects,
    ports,
  )
  if is_origin {
    record_ports_cache.val[node.name()] = ports
  }
  ports
}

///|
/// Graphviz parity: record_path field selection aligned to refs/graphviz/lib/common/shapes.c.
/// Do not change behavior without updating fixtures/tests.
fn record_top_level_rects(
  nodes : Array[RecordNode],
  rect : @geom.Rect,
  orientation : RecordOrientation,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> Array[@geom.Rect] {
  if nodes.length() == 0 {
    return []
  }
  let sizes = record_nodes_sizes(
    nodes,
    orientation,
    font_name,
    font_size_pt,
    pad_x_pt,
    pad_y_pt,
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
  let rects : Array[@geom.Rect] = []
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
    rects.push(child_rect)
  }
  rects
}

///|
/// Graphviz parity: record_path boxes aligned to refs/graphviz/lib/common/shapes.c.
/// Do not change behavior without updating fixtures/tests.
pub fn record_port_path_box(
  node : @cgraph.Node,
  port : @cgraph.Port?,
  pos : @geom.Point,
  size : NodeSize,
  rankdir : RankDir,
) -> @geom.Rect? {
  if !@shared.port_is_explicit(port) {
    return None
  }
  if !@shared.is_record_shape(node) {
    return None
  }
  let orientation = @shared.record_layout_orientation(rankdir)
  let raw_ports = record_ports(node, { x: 0.0, y: 0.0 }, size, orientation)
  let name = match @port_geometry.resolve_label_port_name(port, raw_ports) {
    Some(value) => value
    None => return None
  }
  let port_info = match raw_ports.get(name) {
    Some(value) => value
    None => return None
  }
  let label = @label_attrs.label_text(node)
  let nodes = record_nodes(label)
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let padding = @label_attrs.node_padding(node)
  let node_rect : @geom.Rect = {
    llx: -size.width_pt / 2.0,
    lly: -size.height_pt / 2.0,
    urx: size.width_pt / 2.0,
    ury: size.height_pt / 2.0,
  }
  let inner_rect : @geom.Rect = {
    llx: node_rect.llx,
    lly: node_rect.lly + @shared.RECORD_BORDER_PT,
    urx: node_rect.urx,
    ury: node_rect.ury - @shared.RECORD_BORDER_PT,
  }
  let top_rects =
    record_top_level_rects(
      nodes,
      inner_rect,
      orientation,
      font,
      font_size_pt,
      padding.pad_x_pt,
      padding.pad_y_pt,
    )
  let port_x = port_info.center.x
  let mut chosen : @geom.Rect? = None
  for rect in top_rects {
    let hit = match orientation {
      RecordOrientation::Horizontal =>
        port_x >= rect.llx && port_x <= rect.urx
      RecordOrientation::Vertical =>
        port_x >= rect.lly && port_x <= rect.ury
    }
    if hit {
      chosen = Some(rect)
      break
    }
  }
  let field_rect = match chosen {
    Some(value) => value
    None => return None
  }
  let path_rect_local : @geom.Rect = match orientation {
    RecordOrientation::Horizontal => {
      llx: field_rect.llx,
      lly: node_rect.lly,
      urx: field_rect.urx,
      ury: node_rect.ury,
    }
    RecordOrientation::Vertical => {
      llx: node_rect.llx,
      lly: field_rect.lly,
      urx: node_rect.urx,
      ury: field_rect.ury,
    }
  }
  let corners : Array[@geom.Point] = [
    @edge_spline.point(path_rect_local.llx, path_rect_local.lly),
    @edge_spline.point(path_rect_local.llx, path_rect_local.ury),
    @edge_spline.point(path_rect_local.urx, path_rect_local.lly),
    @edge_spline.point(path_rect_local.urx, path_rect_local.ury),
  ]
  let mut minx = 1.0e308
  let mut miny = 1.0e308
  let mut maxx = -1.0e308
  let mut maxy = -1.0e308
  for corner in corners {
    let offset = @port_geometry.layout_port_offset(corner, rankdir)
    let abs = @edge_spline.point(pos.x + offset.x, pos.y + offset.y)
    if abs.x < minx { minx = abs.x }
    if abs.x > maxx { maxx = abs.x }
    if abs.y < miny { miny = abs.y }
    if abs.y > maxy { maxy = abs.y }
  }
  Some({ llx: minx, lly: miny, urx: maxx, ury: maxy })
}
///|
/// Graphviz parity: record label-port padding reserves extra half-heights for
/// explicit record ports near node borders.
/// Do not change behavior without updating fixtures/tests.
pub fn record_port_padding_y(
  edges : Array[@cgraph.Edge],
  positions : Map[String, @geom.Point],
  label_ports_map : Map[String, Map[String, RecordPort]],
) -> RecordPortPaddingY {
  let mut extra_below = 0.0
  let mut extra_above = 0.0
  let update_padding = (node_name : String, port : @cgraph.Port?) => {
    match port {
      Some(value) =>
        match value.name {
          Some(port_name) =>
            match label_ports_map.get(node_name) {
              Some(ports) =>
                match ports.get(port_name) {
                  Some(port_info) =>
                    match positions.get(node_name) {
                      Some(node_pos) => {
                        let dy = port_info.center.y - node_pos.y
                        let half_height =
                          port_info.size.height_pt / 2.0 -
                          @shared.RECORD_BORDER_PT / 2.0 -
                          0.01
                        let adjusted =
                          if half_height < 0.0 {
                          0.0
                        } else {
                          half_height * 0.5
                        }
                        if dy < 0.0 && adjusted > extra_below {
                          extra_below = adjusted
                        } else if dy > 0.0 && adjusted > extra_above {
                          extra_above = adjusted
                        }
                      }
                      None => ()
                    }
                  None => ()
                }
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  for edge in edges {
    if @shared.port_is_explicit(edge.tail_port()) &&
      @shared.is_record_shape(edge.tail()) {
      update_padding(edge.tail().name(), edge.tail_port())
    }
    if @shared.port_is_explicit(edge.head_port()) &&
      @shared.is_record_shape(edge.head()) {
      update_padding(edge.head().name(), edge.head_port())
    }
  }
  { below: extra_below, above: extra_above }
}

///|
pub(all) struct RecordPortPaddingY {
  below : Double
  above : Double
}
