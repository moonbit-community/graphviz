///|
#skip
test "ldbx debug snapshot" {
  let input_path = "refs/graphviz/graphs/directed/ldbxtried.gv"
  let expected_path = "tests/layout/dot/ldbxtried.gv.dot"
  let graph = @dot_parser.parse_dot_file(input_path)
  let layout = layout_dot(graph)
  layout.apply()
  let actual = @dot_parser.write_dot(graph)
  @fs.write_string_to_file("/tmp/mbt-ldbx-actual.dot", actual)
  @fs.write_string_to_file(
    "/tmp/mbt-ldbx-expected.dot",
    @fs.read_file_to_string(expected_path),
  )
  assert_snapshot_nodes_only(
    input_path,
    expected_path,
    0.01,
  )
}
