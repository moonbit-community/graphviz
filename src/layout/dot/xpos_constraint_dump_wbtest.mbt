///|
fn node_kind_name(kind : @network_simplex.NodeKind) -> String {
  match kind {
    @network_simplex.NodeKind::Normal => "normal"
    @network_simplex.NodeKind::Virtual => "virtual"
    @network_simplex.NodeKind::Slack => "slack"
  }
}

///|
test "dump xpos constraints" {
  let input = match @sys.get_env_var("DOT_DUMP_XPOS_CONSTRAINTS") {
    None => return ()
    Some(value) => value
  }
  let out_path = match @sys.get_env_var("DOT_DUMP_XPOS_CONSTRAINTS_OUT") {
    None => "/tmp/xpos_mbt.txt"
    Some(value) => value
  }
  let graph = @dot_parser.parse_dot_file(input)
  xpos_constraint_snapshot.val = None
  @sys.set_env_var("DOT_CAPTURE_XPOS_CONSTRAINTS", "1")
  let _ = layout_dot(graph)
  @sys.unset_env_var("DOT_CAPTURE_XPOS_CONSTRAINTS")
  let snapshot = match xpos_constraint_snapshot.val {
    Some(value) => value
    None => fail("missing xpos constraint snapshot")
  }
  let sb = StringBuilder::new()
  let mut idx = 0
  for node in snapshot.nodes {
    let name = match node.name {
      Some(value) => value
      None => ""
    }
    let kind = node_kind_name(node.kind)
    sb.write_string(
      "NODE id=\{idx} name=\{name} kind=\{kind} rank=\{node.rank} order=\{node.order} lw=\{node.left_pt} rw=\{node.right_pt} ht=\{node.height_pt}\n",
    )
    idx = idx + 1
  }
  for edge in snapshot.edges {
    sb.write_string(
      "EDGE tail=\{edge.tail} head=\{edge.head} minlen=\{edge.minlen} weight=\{edge.weight}\n",
    )
  }
  @fs.write_string_to_file(out_path, sb.to_string())
}
