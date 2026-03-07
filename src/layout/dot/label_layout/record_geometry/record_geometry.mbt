///|
/// Record-shape geometry primitives shared across label layout, routing, and
/// input-stage handling.

///|
/// Record/html label port geometry in layout coordinates.
pub(all) struct RecordPort {
  center : @geom.Point
  size : @node_primitives.NodeSize
  sides : Int
}

///|
pub const RECORD_BORDER_PT : Double = 0.5

///|
/// Graphviz parity: record-shape detection follows shape attr values
/// recognized by dot (`record` / `mrecord`).
/// Do not change behavior without updating fixtures/tests.
pub fn is_record_shape(node : @cgraph.Node) -> Bool {
  match node.get_attr("shape") {
    Some(value) =>
      match value.to_lower() {
        "record" | "mrecord" => true
        _ => false
      }
    None => false
  }
}
