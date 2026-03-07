///|
/// Label layout boundary helpers: cache reset and raw label-port dispatch
/// across record and HTML implementations.

type RecordOrientation = @shared.RecordOrientation
type NodeSize = @shared.NodeSize
type RecordPort = @record_geometry.RecordPort

///|
pub fn reset_label_caches() -> Unit {
  @record_layout.reset_record_layout_caches()
  @html_layout.reset_html_label_caches()
}

///|
/// Graphviz parity: raw label-port extraction resolves html first, then record
/// shape ports, and returns empty for other node kinds.
/// Do not change behavior without updating fixtures/tests.
pub fn raw_label_ports_for_node(
  node : @cgraph.Node,
  origin : @geom.Point,
  base_size : NodeSize,
  record_orientation : RecordOrientation,
) -> Map[String, RecordPort] {
  let label = @label_attrs.label_text(node)
  if @html_label.is_html_label_text(label) {
    @html_layout.html_ports(node, label, origin, base_size)
  } else if @record_geometry.is_record_shape(node) {
    @record_layout.record_ports(node, origin, base_size, record_orientation)
  } else {
    Map::new()
  }
}
