///|
/// Layer membership shared by the SVG graph, node, and edge emitters.
priv struct SvgLayerSelection {
  names : Array[String]
  separators : String
  list_separators : String
}

///|
fn SvgLayerSelection::cluster_visible(
  self : SvgLayerSelection,
  layer : Int,
  graph : @cgraph.Graph,
) -> Bool {
  guard self.names.length() > 1 else { true }
  let spec = graph.get_attr("layer").unwrap_or_default()
  guard !self.selected(layer, spec) else { true }
  guard spec == "" else { false }
  for node in graph.nodes() {
    if self.node_visible(layer, graph, node) {
      return true
    }
  }
  false
}

///|
fn layer_is_separator(ch : Char, separators : String) -> Bool {
  for separator in separators {
    if ch == separator {
      return true
    }
  }
  false
}

///|
fn layer_tokens(text : String, separators : String) -> Array[String] {
  let result : Array[String] = []
  let mut token = StringBuilder()
  for ch in text {
    if layer_is_separator(ch, separators) {
      let value = token.to_string()
      if value != "" {
        result.push(value)
      }
      token = StringBuilder()
    } else {
      token.write_char(ch)
    }
  }
  let value = token.to_string()
  if value != "" {
    result.push(value)
  }
  result
}

///|
fn SvgLayerSelection::new(
  names : String,
  separators : String,
  list_separators : String,
) -> SvgLayerSelection {
  let list_separators = for ch in separators {
    if layer_is_separator(ch, list_separators) {
      break ""
    }
  } nobreak {
    list_separators
  }
  { names: layer_tokens(names, separators), separators, list_separators, }
}

///|
fn SvgLayerSelection::index(
  self : SvgLayerSelection,
  name : String,
  all : Int,
) -> Int {
  guard name != "all" else { all }
  let numeric = for ch in name {
    if ch < '0' || ch > '9' {
      break false
    }
  } nobreak {
    name != ""
  }
  if numeric {
    return parse_double(name, -1.0).to_int()
  }
  for index, value in self.names {
    if name == value {
      return index + 1
    }
  }
  -1
}

///|
fn SvgLayerSelection::selected(
  self : SvgLayerSelection,
  layer : Int,
  spec : String,
) -> Bool {
  for part in layer_tokens(spec, self.list_separators) {
    let range = layer_tokens(part, self.separators)
    guard range.length() > 0 else { continue }
    if range.length() == 1 {
      if self.index(range[0], layer) == layer {
        return true
      }
    } else {
      let first = self.index(range[0], 0)
      let last = self.index(range[1], self.names.length())
      guard first >= 0 || last >= 0 else { continue }
      if (first <= layer && layer <= last) || (last <= layer && layer <= first) {
        return true
      }
    }
  }
  false
}

///|
test "SVG layer selection follows named numeric range and list semantics" {
  let selection = SvgLayerSelection::new("local+pvt+test+new+ofc", "+", ",")
  for layer in 1..<=5 {
    assert_true(selection.selected(layer, "all"))
    assert_true(selection.selected(layer, "pvt+ofc") == (layer >= 2))
    assert_true(selection.selected(layer, "ofc+pvt") == (layer >= 2))
    assert_true(selection.selected(layer, "pvt+all") == (layer >= 2))
    assert_true(selection.selected(layer, "3") == (layer == 3))
    assert_true(
      selection.selected(layer, "pvt,ofc") == (layer == 2 || layer == 5),
    )
    assert_false(selection.selected(layer, "missing"))
    assert_false(selection.selected(layer, ""))
  }
}

///|
fn SvgLayerSelection::node_visible(
  self : SvgLayerSelection,
  layer : Int,
  graph : @cgraph.Graph,
  node : @cgraph.Node,
) -> Bool {
  guard self.names.length() > 1 else { true }
  let spec = node.get_attr("layer").unwrap_or_default()
  guard !self.selected(layer, spec) else { true }
  guard spec == "" else { false }
  let adjacent = graph
    .edges()
    .filter(edge => {
      edge.tail().name() == node.name() || edge.head().name() == node.name()
    })
  guard adjacent.length() > 0 else { true }
  for edge in adjacent {
    let spec = edge.get_attr("layer").unwrap_or_default()
    if spec == "" || self.selected(layer, spec) {
      return true
    }
  }
  false
}

///|
fn SvgLayerSelection::edge_visible(
  self : SvgLayerSelection,
  layer : Int,
  edge : @cgraph.Edge,
) -> Bool {
  guard self.names.length() > 1 else { true }
  let spec = edge.get_attr("layer").unwrap_or_default()
  guard !self.selected(layer, spec) else { true }
  guard spec == "" else { false }
  for node in [edge.tail(), edge.head()] {
    let spec = node.get_attr("layer").unwrap_or_default()
    if spec == "" || self.selected(layer, spec) {
      return true
    }
  }
  false
}

///|
test "unassigned layer objects inherit visibility from incident attributes" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("layer", "2")
  let selection = SvgLayerSelection::new("first:second", ":", ",")
  assert_false(selection.node_visible(1, graph, a))
  assert_true(selection.node_visible(2, graph, a))
  assert_true(selection.node_visible(1, graph, graph.node("isolated")))
  edge.set_attr("layer", "")
  a.set_attr("layer", "2")
  b.set_attr("layer", "2")
  assert_false(selection.edge_visible(1, edge))
  assert_true(selection.edge_visible(2, edge))
  b.set_attr("layer", "")
  assert_true(selection.edge_visible(1, edge))
}
