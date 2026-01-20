///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn write_input(path : String) -> Unit raise {
  @fs.write_string_to_file(path, "digraph { a -> b }")
}

test "cli smoke dot/xdot/svg" {
  ensure_dir("target")
  ensure_dir("target/cli")
  let input_path = "target/cli/input.dot"
  write_input(input_path)

  let dot_out = run_cli(["-Tdot", input_path])
  assert_true(dot_out.contains("pos="))

  let xdot_out = run_cli(["-Txdot", input_path])
  assert_true(xdot_out.contains("_draw_"))

  let svg_out = run_cli(["-Tsvg", input_path])
  assert_true(svg_out.contains("<svg"))
  assert_true(svg_out.contains("</svg>"))
}

test "cli smoke writes output file" {
  ensure_dir("target")
  ensure_dir("target/cli")
  let input_path = "target/cli/input.dot"
  write_input(input_path)
  let out_path = "target/cli/out.svg"
  let stdout = run_cli(["-Tsvg", "-o", out_path, input_path])
  assert_eq(stdout, "")
  let svg_out = @fs.read_file_to_string(out_path)
  assert_true(svg_out.contains("<svg"))
}
