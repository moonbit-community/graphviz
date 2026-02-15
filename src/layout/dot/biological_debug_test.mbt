#skip
test "biological debug snapshot" {
  let input_path = "refs/graphviz/graphs/directed/biological.gv"
  let expected_path = "tests/layout/dot/biological.gv.dot"
  let graph = @dot_parser.parse_dot_file(input_path)
  let layout = layout_dot(graph)
  layout.apply()
  let actual = @dot_parser.write_dot(graph)
  @fs.write_string_to_file("/tmp/mbt-biological-actual.dot", actual)
  @fs.write_string_to_file(
    "/tmp/mbt-biological-expected.dot",
    @fs.read_file_to_string(expected_path),
  )
}
