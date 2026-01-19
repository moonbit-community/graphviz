///|
/// Core graph kinds supported by DOT.
pub enum GraphKind {
  Directed
  Undirected
} derive(Show, Eq)

///|
/// Attribute scope kinds.
pub enum AttrKind {
  Graph
  Node
  Edge
} derive(Show, Eq)

///|
/// Compass ports used in node:port:compass syntax.
pub enum Compass {
  N
  NE
  E
  SE
  S
  SW
  W
  NW
  C
} derive(Show, Eq)

///|
/// Optional port name and compass reference.
pub struct Port {
  name : String?
  compass : Compass?
} derive(Show, Eq)

///|
#declaration_only
pub type Graph

///|
#declaration_only
pub type Node

///|
#declaration_only
pub type Edge

///|
/// Create a root graph.
#declaration_only
pub fn Graph::new(
  kind : GraphKind,
  name? : String,
  strict? : Bool = false,
) -> Graph {
  ...
}

///|
#declaration_only
pub fn Graph::name(self : Graph) -> String? {
  ...
}

///|
#declaration_only
pub fn Graph::kind(self : Graph) -> GraphKind {
  ...
}

///|
#declaration_only
pub fn Graph::is_strict(self : Graph) -> Bool {
  ...
}

///|
#declaration_only
pub fn Graph::parent(self : Graph) -> Graph? {
  ...
}

///|
#declaration_only
pub fn Graph::is_root(self : Graph) -> Bool {
  ...
}

///|
/// Create or get a named subgraph. Omit name for anonymous subgraph.
#declaration_only
pub fn Graph::subgraph(self : Graph, name? : String) -> Graph {
  ...
}

///|
#declaration_only
pub fn Graph::subgraphs(self : Graph) -> Array[Graph] {
  ...
}

///|
/// Create or get a node by name.
#declaration_only
pub fn Graph::node(self : Graph, name : String) -> Node {
  ...
}

///|
#declaration_only
pub fn Graph::find_node(self : Graph, name : String) -> Node? {
  ...
}

///|
#declaration_only
pub fn Graph::nodes(self : Graph) -> Array[Node] {
  ...
}

///|
/// Create or get an edge between tail/head. Optional name for multi-edges.
#declaration_only
pub fn Graph::edge(
  self : Graph,
  tail : Node,
  head : Node,
  name? : String,
  tail_port? : Port,
  head_port? : Port,
) -> Edge {
  ...
}

///|
#declaration_only
pub fn Graph::edges(self : Graph) -> Array[Edge] {
  ...
}

///|
#declaration_only
pub fn Node::name(self : Node) -> String {
  ...
}

///|
#declaration_only
pub fn Node::graph(self : Node) -> Graph {
  ...
}

///|
#declaration_only
pub fn Edge::tail(self : Edge) -> Node {
  ...
}

///|
#declaration_only
pub fn Edge::head(self : Edge) -> Node {
  ...
}

///|
#declaration_only
pub fn Edge::name(self : Edge) -> String? {
  ...
}

///|
#declaration_only
pub fn Edge::tail_port(self : Edge) -> Port? {
  ...
}

///|
#declaration_only
pub fn Edge::head_port(self : Edge) -> Port? {
  ...
}

///|
/// Declare an attribute and its default value if missing.
#declaration_only
pub fn Graph::declare_attr(
  self : Graph,
  kind : AttrKind,
  name : String,
  default? : String = "",
) -> Unit {
  ...
}

///|
#declaration_only
pub fn Graph::set_default_attr(
  self : Graph,
  kind : AttrKind,
  name : String,
  value : String,
) -> Unit {
  ...
}

///|
#declaration_only
pub fn Graph::get_default_attr(
  self : Graph,
  kind : AttrKind,
  name : String,
) -> String? {
  ...
}

///|
/// Set and read graph attributes. Missing attributes are created.
#declaration_only
pub fn Graph::set_attr(self : Graph, name : String, value : String) -> Unit {
  ...
}

///|
#declaration_only
pub fn Graph::get_attr(self : Graph, name : String) -> String? {
  ...
}

///|
/// Set and read node attributes. Missing attributes are created.
#declaration_only
pub fn Node::set_attr(self : Node, name : String, value : String) -> Unit {
  ...
}

///|
#declaration_only
pub fn Node::get_attr(self : Node, name : String) -> String? {
  ...
}

///|
/// Set and read edge attributes. Missing attributes are created.
#declaration_only
pub fn Edge::set_attr(self : Edge, name : String, value : String) -> Unit {
  ...
}

///|
#declaration_only
pub fn Edge::get_attr(self : Edge, name : String) -> String? {
  ...
}
