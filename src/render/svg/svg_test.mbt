///|
test "render_svg emits svg" {
  let graph = @dot.parse_dot("digraph { a -> b; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("<polygon"))
}

///|
test "render_svg emits root background" {
  let graph = @dot.parse_dot("digraph { bgcolor=\"pink\"; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<rect"))
  assert_true(svg.contains("fill=\"pink\""))
}

///|
test "render_svg emits edge labels" {
  let graph = @dot.parse_dot("digraph { a -> b [label=\"edge\"]; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">edge</text>"))
}

///|
test "render_svg honors dashed and dotted styles" {
  let graph = @dot.parse_dot(
    "digraph { node [style=dotted]; a; b; a -> b [style=dashed]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("stroke-dasharray=\"1,5\""))
  assert_true(svg.contains("stroke-dasharray=\"5,2\""))
}

///|
test "render_svg draws polygon node shapes" {
  let graph = @dot.parse_dot(
    "digraph { a [shape=diamond]; b [shape=triangle]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<polygon"))
  assert_true(!svg.contains("<ellipse"))
}

///|
test "render_svg skips outlines for plaintext nodes" {
  let graph = @dot.parse_dot("digraph { a [shape=plaintext,label=\"hello\"]; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">hello</text>"))
  assert_true(!svg.contains("<ellipse"))
  assert_true(!svg.contains("<polygon"))
}

///|
test "render_svg renders record fields" {
  let graph = @dot.parse_dot(
    "digraph { node [shape=record]; a [label=\"<f0>left|<f1>right\"]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">left</text>"))
  assert_true(svg.contains(">right</text>"))
  assert_true(svg.contains("<line"))
}

///|
test "render_svg renders nested record fields" {
  let graph = @dot.parse_dot(
    "digraph { node [shape=record]; a [label=\"{a|{b|<here>c|d}|e}\"]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">a</text>"))
  assert_true(svg.contains(">b</text>"))
  assert_true(svg.contains(">c</text>"))
  assert_true(svg.contains(">d</text>"))
  assert_true(svg.contains(">e</text>"))
  assert_true(svg.contains("<line"))
}

///|
test "render_svg renders html-like labels" {
  let graph = @dot.parse_dot(
    "digraph { node [shape=plaintext]; a [label=<<TABLE CELLBORDER=\\\"1\\\" CELLSPACING=\\\"0\\\"><TR><TD>left</TD><TD>right</TD></TR></TABLE>>]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">left</text>"))
  assert_true(svg.contains(">right</text>"))
  assert_true(svg.contains("<rect"))
}

///|
test "render_svg renders html label alignment and colors" {
  let graph = @dot.parse_dot(
    "digraph { node [shape=plaintext]; a [label=<<TABLE BORDER=\\\"1\\\" CELLBORDER=\\\"1\\\" CELLSPACING=\\\"0\\\" BGCOLOR=\\\"yellow\\\"><TR><TD ALIGN=\\\"left\\\" BGCOLOR=\\\"red\\\">left</TD><TD ALIGN=\\\"right\\\">right</TD></TR><TR><TD COLSPAN=\\\"2\\\"><TABLE><TR><TD>inner</TD></TR></TABLE></TD></TR></TABLE>>]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">left</text>"))
  assert_true(svg.contains(">right</text>"))
  assert_true(svg.contains(">inner</text>"))
  assert_true(svg.contains("fill=\"yellow\""))
  assert_true(svg.contains("fill=\"red\""))
  assert_true(svg.contains("text-anchor=\"start\""))
  assert_true(svg.contains("text-anchor=\"end\""))
}

///|
test "render_svg emits cluster labels" {
  let graph = @dot.parse_dot_file("refs/graphviz/graphs/directed/clust.gv")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">hello world</text>"))
  assert_true(svg.contains(">MSDOT</text>"))
}

///|
test "render_svg fills cluster background" {
  let graph = @dot.parse_dot(
    "digraph { subgraph cluster_0 { style=filled; color=lightgrey; a; } }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("fill=\"lightgrey\""))
}

///|
test "render_svg emits graph labels" {
  let graph = @dot.parse_dot(
    "digraph { label=\"Root\"; labelloc=t; labeljust=r; a -> b; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">Root</text>"))
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
test "svg spot-check outputs" {
  let out_dir = "target/render/svg"
  ensure_dir("target")
  ensure_dir("target/render")
  ensure_dir(out_dir)
  let cases : Array[(String, String)] = [
    ("refs/graphviz/doc/dotguide/graph1.dot", "graph1"),
    ("refs/graphviz/graphs/directed/arrows.gv", "arrows"),
    ("refs/graphviz/graphs/directed/arr_none.gv", "arr_none"),
    ("refs/graphviz/graphs/directed/records.gv", "records"),
    ("refs/graphviz/graphs/directed/record2.gv", "record2"),
    ("refs/graphviz/graphs/directed/clust.gv", "clust"),
    ("refs/graphviz/graphs/directed/ctext.gv", "ctext"),
    ("refs/graphviz/graphs/directed/grammar.gv", "grammar"),
    ("refs/graphviz/graphs/directed/longflat.gv", "longflat"),
    ("refs/graphviz/graphs/directed/structs.gv", "structs"),
    ("tests/layout/dot/compound.dot", "compound"),
    ("tests/layout/dot/complex.dot", "complex"),
  ]
  for pair in cases {
    let (input_path, name) = pair
    let graph = @dot.parse_dot_file(input_path)
    let layout = @layout_dot.layout_dot(graph)
    let svg = render_svg(layout)
    let out_path = "\{out_dir}/\{name}.svg"
    @fs.write_string_to_file(out_path, svg)
    assert_true(svg.contains("<svg"))
    let baseline_path = "tests/render/svg/\{name}.svg"
    if @fs.path_exists(baseline_path) {
      let baseline = @fs.read_file_to_string(baseline_path)
      let normalized_svg = svg.trim(chars=" \n\r\t").to_string()
      let normalized_baseline = baseline.trim(chars=" \n\r\t").to_string()
      assert_eq(normalized_svg, normalized_baseline)
    }
  }
}
