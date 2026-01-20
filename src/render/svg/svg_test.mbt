///|
test "render_svg emits svg" {
  let graph = @dot.parse_dot("digraph { a -> b; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(
    layout,
    options={
      pretty: Some(false),
      include_xml_decl: Some(false),
    },
  )
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("<polygon"))
}

test "render_svg emits edge labels" {
  let graph = @dot.parse_dot("digraph { a -> b [label=\"edge\"]; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(
    layout,
    options={
      pretty: Some(false),
      include_xml_decl: Some(false),
    },
  )
  assert_true(svg.contains(">edge</text>"))
}

test "render_svg emits cluster labels" {
  let graph = @dot.parse_dot_file("refs/graphviz/graphs/directed/clust.gv")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(
    layout,
    options={
      pretty: Some(false),
      include_xml_decl: Some(false),
    },
  )
  assert_true(svg.contains(">hello world</text>"))
  assert_true(svg.contains(">MSDOT</text>"))
}

test "render_svg emits graph labels" {
  let graph = @dot.parse_dot("digraph { label=\"Root\"; labelloc=t; labeljust=r; a -> b; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(
    layout,
    options={
      pretty: Some(false),
      include_xml_decl: Some(false),
    },
  )
  assert_true(svg.contains(">Root</text>"))
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

test "svg spot-check outputs" {
  let out_dir = "target/render/svg"
  ensure_dir("target")
  ensure_dir("target/render")
  ensure_dir(out_dir)
  let cases : Array[(String, String)] = [
    ("refs/graphviz/doc/dotguide/graph1.dot", "graph1"),
    ("refs/graphviz/graphs/directed/clust.gv", "clust"),
    ("refs/graphviz/graphs/directed/ctext.gv", "ctext"),
    ("refs/graphviz/graphs/directed/grammar.gv", "grammar"),
  ]
  for pair in cases {
    let (input_path, name) = pair
    let graph = @dot.parse_dot_file(input_path)
    let layout = @layout_dot.layout_dot(graph)
    let svg = render_svg(
      layout,
      options={
        pretty: Some(false),
        include_xml_decl: Some(false),
      },
    )
    let out_path = "\{out_dir}/\{name}.svg"
    @fs.write_string_to_file(out_path, svg)
    assert_true(svg.contains("<svg"))
  }
}
