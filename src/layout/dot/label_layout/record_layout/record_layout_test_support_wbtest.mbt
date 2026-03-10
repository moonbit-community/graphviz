///|
fn assert_close(actual : Double, expected : Double, tol : Double) -> Unit raise {
  let ok = Double::is_close(actual, expected, absolute_tolerance=tol)
  if !ok {
    fail("expected \{expected}, got \{actual}")
  }
}

///|
const ALL_PORT_SIDES : Int = @port_geometry.PORT_SIDE_TOP |
  @port_geometry.PORT_SIDE_BOTTOM |
  @port_geometry.PORT_SIDE_LEFT |
  @port_geometry.PORT_SIDE_RIGHT

///|
fn assert_rect_close(
  actual : @geom.Rect,
  llx : Double,
  lly : Double,
  urx : Double,
  ury : Double,
) -> Unit raise {
  assert_close(actual.llx, llx, 0.0001)
  assert_close(actual.lly, lly, 0.0001)
  assert_close(actual.urx, urx, 0.0001)
  assert_close(actual.ury, ury, 0.0001)
}

///|
fn record_layout_for_node(
  source : String,
  node_name : String,
) -> (@geom.Rect, Array[RecordLayoutNode]) raise {
  reset_record_layout_caches()
  let graph = @dot_parser.parse_dot(source)
  let orientation = @layout_prep.record_layout_orientation(
    @rankdir.graph_rankdir(graph),
  )
  let node = graph.node(node_name)
  let size = @node_geometry.node_size(node, orientation)
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let padding = @label_attrs.node_padding(node)
  let inner_rect : @geom.Rect = {
    llx: -size.width_pt / 2.0,
    lly: -size.height_pt / 2.0 + @record_geometry.RECORD_BORDER_PT,
    urx: size.width_pt / 2.0,
    ury: size.height_pt / 2.0 - @record_geometry.RECORD_BORDER_PT,
  }
  let layout = layout_record_tree(
    record_nodes(@label_attrs.label_text(node)),
    inner_rect,
    orientation,
    font,
    font_size_pt,
    padding.pad_x_pt,
    padding.pad_y_pt,
    ALL_PORT_SIDES,
  )
  (inner_rect, layout)
}
