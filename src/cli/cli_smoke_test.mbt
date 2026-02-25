///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn write_input(path : String, contents : String) -> Unit raise {
  @fs.write_string_to_file(path, contents)
}

///|
test "cli smoke dot/xdot/svg" {
  ensure_dir("target")
  ensure_dir("target/cli")
  let input_path = "target/cli/input.dot"
  write_input(input_path, "digraph { a -> b }")
  let dot_out = run_cli(["-Tdot", input_path])
  assert_true(dot_out.contains("pos="))
  let xdot_out = run_cli(["-Txdot", input_path])
  assert_true(xdot_out.contains("_draw_"))
  let svg_out = run_cli(["-Tsvg", input_path])
  assert_true(svg_out.contains("<svg"))
  assert_true(svg_out.contains("</svg>"))
}

///|
test "cli smoke writes output file" {
  ensure_dir("target")
  ensure_dir("target/cli")
  let input_path = "target/cli/input.dot"
  write_input(input_path, "digraph { a -> b }")
  let out_path = "target/cli/out.svg"
  let stdout = run_cli(["-Tsvg", "-o", out_path, input_path])
  assert_eq(stdout, "")
  let svg_out = @fs.read_file_to_string(out_path)
  assert_true(svg_out.contains("<svg"))
}

///|
test "cli -Kdot overrides layout=neato" {
  ensure_dir("target")
  ensure_dir("target/cli")
  let input_path = "target/cli/layout_neato.dot"
  write_input(input_path, "graph { layout=neato; a -- b; }")
  let default_dot_output = run_cli(["-Tdot", input_path])
  let dot_frontend_output = run_cli(["-Kdot", "-Tdot", input_path])
  let neato_frontend_output = run_cli(["-Tdot", input_path], program="neato")
  assert_eq(default_dot_output, neato_frontend_output)
  assert_true(dot_frontend_output != neato_frontend_output)
}

///|
test "cli renders multiple graphs from one file" {
  ensure_dir("target")
  ensure_dir("target/cli")
  let input_path = "target/cli/multi_graphs.dot"
  write_input(input_path, "digraph { fear -> anger; }\n\ndigraph { anger -> hate; }\n")
  let dot_out = run_cli(["-Tdot", input_path])
  assert_true(dot_out.contains("fear -> anger"))
  assert_true(dot_out.contains("anger -> hate"))
  let svg_out = run_cli(["-Tsvg", input_path])
  assert_true(svg_out.contains("<g id=\"graph0\" class=\"graph\""))
  assert_true(svg_out.contains("<g id=\"page0,1_graph0\" class=\"graph\""))
}
