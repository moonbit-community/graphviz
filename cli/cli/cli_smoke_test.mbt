// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
async fn with_cli_test_dir(f : async (String) -> Unit) -> Unit {
  @async.with_task_group() <| group => {
    let test_dir = @fs.tmpdir(prefix="graphviz-cli-test")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @fs.rmdir(test_dir, recursive=true))
    }
    f(test_dir)
  }
}

///|
async fn write_input(path : String, contents : String) -> Unit {
  @fs.write_file(path, contents, create_mode=@fs.CreateOrTruncate)
}

///|
async test "cli smoke dot/xdot/svg" {
  with_cli_test_dir(test_dir => {
    let input_path = "\{test_dir}/input.dot"
    write_input(input_path, "digraph { a -> b }")
    let dot_out = run_cli(["-Tdot", input_path])
    assert_true(dot_out.contains("pos="))
    let xdot_out = run_cli(["-Txdot", input_path])
    assert_true(xdot_out.contains("_draw_"))
    let svg_out = run_cli(["-Tsvg", input_path])
    assert_true(svg_out.contains("<svg"))
    assert_true(svg_out.contains("</svg>"))
  })
}

///|
async test "cli smoke writes output file" {
  with_cli_test_dir(test_dir => {
    let input_path = "\{test_dir}/input.dot"
    write_input(input_path, "digraph { a -> b }")
    let out_path = "\{test_dir}/out.svg"
    let stdout = run_cli(["-Tsvg", "-o", out_path, input_path])
    assert_eq(stdout, "")
    let svg_out = @fs.read_file(out_path).text()
    assert_true(svg_out.contains("<svg"))
  })
}

///|
async test "cli -Kdot overrides layout=neato" {
  with_cli_test_dir(test_dir => {
    let input_path = "\{test_dir}/layout_neato.dot"
    write_input(input_path, "graph { layout=neato; a -- b; }")
    let default_dot_output = run_cli(["-Tdot", input_path])
    let dot_frontend_output = run_cli(["-Kdot", "-Tdot", input_path])
    let neato_frontend_output = run_cli(["-Tdot", input_path], program="neato")
    assert_eq(default_dot_output, neato_frontend_output)
    assert_true(dot_frontend_output != neato_frontend_output)
  })
}

///|
async test "cli renders multiple graphs from one file" {
  with_cli_test_dir(test_dir => {
    let input_path = "\{test_dir}/multi_graphs.dot"
    write_input(
      input_path, "digraph { fear -> anger; }\n\ndigraph { anger -> hate; }\n",
    )
    let dot_out = run_cli(["-Tdot", input_path])
    assert_true(dot_out.contains("fear -> anger"))
    assert_true(dot_out.contains("anger -> hate"))
    let svg_out = run_cli(["-Tsvg", input_path])
    assert_true(svg_out.contains("<g id=\"graph0\" class=\"graph\""))
    assert_true(svg_out.contains("<g id=\"page0,1_graph0\" class=\"graph\""))
  })
}
