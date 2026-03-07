///|
test "html_ports include td port names" {
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=plaintext]; a [label=<<TABLE><TR><TD PORT=\\\"p1\\\">one</TD></TR></TABLE>>]; }",
  )
  let record_orientation =
    @shared.record_layout_orientation(@rankdir.graph_rankdir(graph))
  let node = graph.node("a")
  let size = @node_geometry.node_size(node, record_orientation)
  let ports = @html_layout.html_ports(node, @label_attrs.label_text(node), @geom.Point::{ x: 0.0, y: 0.0 }, size)
  match ports.get("p1") {
    Some(port) => {
      let half_w = size.width_pt / 2.0
      let half_h = size.height_pt / 2.0
      assert_true(port.center.x >= -half_w && port.center.x <= half_w)
      assert_true(port.center.y >= -half_h && port.center.y <= half_h)
    }
    None => fail("missing html port")
  }
}
