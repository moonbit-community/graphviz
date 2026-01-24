///|
priv struct GraphState {
  name : String?
  parent : Int?
  subgraphs_by_name : Map[String, Int]
  subgraphs : Array[Int]
  nodes : Array[Int]
  nodes_set : Map[Int, Bool]
  edges : Array[Int]
  edges_set : Map[Int, Bool]
  attrs : Map[String, String]
  defaults_graph : Map[String, String]
  defaults_node : Map[String, String]
  defaults_edge : Map[String, String]
}

///|
priv struct NodeState {
  name : String
  home_graph_id : Int
  attrs : Map[String, String]
}

///|
priv struct EdgeState {
  tail : Int
  head : Int
  name : String?
  tail_port : Port?
  head_port : Port?
  home_graph_id : Int
  attrs : Map[String, String]
}

///|
struct Root {
  kind : GraphKind
  strict : Bool
  graphs : Array[GraphState]
  nodes_by_name : Map[String, Int]
  nodes : Array[NodeState]
  edges : Array[EdgeState]
  edge_index : Map[String, Int]
  edge_pair_index : Map[String, Int]
}

///|
pub struct Graph {
  root : Root
  id : Int
}

///|
pub struct Node {
  root : Root
  id : Int
}

///|
pub struct Edge {
  root : Root
  id : Int
}

///|
fn empty_graph_state(name : String?, parent : Int?) -> GraphState {
  {
    name,
    parent,
    subgraphs_by_name: Map::new(),
    subgraphs: [],
    nodes: [],
    nodes_set: Map::new(),
    edges: [],
    edges_set: Map::new(),
    attrs: Map::new(),
    defaults_graph: Map::new(),
    defaults_node: Map::new(),
    defaults_edge: Map::new(),
  }
}

///|
fn edge_key(kind : GraphKind, tail : Int, head : Int, name : String?) -> String {
  let mut t = tail
  let mut h = head
  if kind is Undirected && t > h {
    let tmp = t
    t = h
    h = tmp
  }
  let suffix = match name {
    Some(value) => value
    None => ""
  }
  "\{t}:\{h}:\{suffix}"
}

///|
fn edge_pair_key(kind : GraphKind, tail : Int, head : Int) -> String {
  let mut t = tail
  let mut h = head
  if kind is Undirected && t > h {
    let tmp = t
    t = h
    h = tmp
  }
  "\{t}:\{h}"
}

///|
fn add_node_membership(root : Root, graph_id : Int, node_id : Int) -> Unit {
  if !root.graphs[graph_id].nodes_set.contains(node_id) {
    root.graphs[graph_id].nodes_set[node_id] = true
    root.graphs[graph_id].nodes.push(node_id)
  }
  match root.graphs[graph_id].parent {
    Some(parent_id) => add_node_membership(root, parent_id, node_id)
    None => ()
  }
}

///|
fn add_edge_membership(root : Root, graph_id : Int, edge_id : Int) -> Unit {
  if !root.graphs[graph_id].edges_set.contains(edge_id) {
    root.graphs[graph_id].edges_set[edge_id] = true
    root.graphs[graph_id].edges.push(edge_id)
  }
  match root.graphs[graph_id].parent {
    Some(parent_id) => add_edge_membership(root, parent_id, edge_id)
    None => ()
  }
}

///|
fn resolve_default(
  root : Root,
  graph_id : Int,
  kind : AttrKind,
  name : String,
) -> String? {
  let mut current : Int? = Some(graph_id)
  while current is Some(id) {
    let defaults = match kind {
      AttrKind::Graph => root.graphs[id].defaults_graph
      AttrKind::Node => root.graphs[id].defaults_node
      AttrKind::Edge => root.graphs[id].defaults_edge
    }
    let value = defaults.get(name)
    if value is Some(_) {
      return value
    }
    current = root.graphs[id].parent
  }
  None
}

///|
fn collect_defaults(
  root : Root,
  graph_id : Int,
  kind : AttrKind,
) -> Map[String, String] {
  let resolved : Map[String, String] = Map::new()
  let mut current : Int? = Some(graph_id)
  while current is Some(id) {
    let defaults = match kind {
      AttrKind::Graph => root.graphs[id].defaults_graph
      AttrKind::Node => root.graphs[id].defaults_node
      AttrKind::Edge => root.graphs[id].defaults_edge
    }
    for key, value in defaults {
      if resolved.get(key) is None {
        resolved[key] = value
      }
    }
    current = root.graphs[id].parent
  }
  resolved
}

///|
pub fn Graph::new(
  kind : GraphKind,
  name? : String,
  strict? : Bool = false,
) -> Graph {
  let root_state = empty_graph_state(name, None)
  let root : Root = {
    kind,
    strict,
    graphs: [root_state],
    nodes_by_name: Map::new(),
    nodes: [],
    edges: [],
    edge_index: Map::new(),
    edge_pair_index: Map::new(),
  }
  { root, id: 0 }
}

///|
pub fn Graph::name(self : Graph) -> String? {
  self.root.graphs[self.id].name
}

///|
pub fn Graph::kind(self : Graph) -> GraphKind {
  self.root.kind
}

///|
pub fn Graph::is_strict(self : Graph) -> Bool {
  self.root.strict
}

///|
pub fn Graph::parent(self : Graph) -> Graph? {
  match self.root.graphs[self.id].parent {
    Some(parent_id) => Some({ root: self.root, id: parent_id })
    None => None
  }
}

///|
pub fn Graph::is_root(self : Graph) -> Bool {
  self.id == 0
}

///|
pub fn Graph::subgraph(self : Graph, name? : String) -> Graph {
  match name {
    Some(label) => {
      let existing = self.root.graphs[self.id].subgraphs_by_name.get(label)
      match existing {
        Some(id) => { root: self.root, id }
        None => {
          let state = empty_graph_state(Some(label), Some(self.id))
          let new_id = self.root.graphs.length()
          self.root.graphs.push(state)
          self.root.graphs[self.id].subgraphs_by_name[label] = new_id
          self.root.graphs[self.id].subgraphs.push(new_id)
          { root: self.root, id: new_id }
        }
      }
    }
    None => {
      let state = empty_graph_state(None, Some(self.id))
      let new_id = self.root.graphs.length()
      self.root.graphs.push(state)
      self.root.graphs[self.id].subgraphs.push(new_id)
      { root: self.root, id: new_id }
    }
  }
}

///|
pub fn Graph::subgraphs(self : Graph) -> Array[Graph] {
  self.root.graphs[self.id].subgraphs.map(id => { root: self.root, id })
}

///|
pub fn Graph::node(self : Graph, name : String) -> Node {
  let existing = self.root.nodes_by_name.get(name)
  let node_id = match existing {
    Some(id) => id
    None => {
      let new_id = self.root.nodes.length()
      let attrs = collect_defaults(self.root, self.id, AttrKind::Node)
      let state : NodeState = {
        name,
        home_graph_id: self.id,
        attrs,
      }
      self.root.nodes.push(state)
      self.root.nodes_by_name[name] = new_id
      new_id
    }
  }
  add_node_membership(self.root, self.id, node_id)
  { root: self.root, id: node_id }
}

///|
pub fn Graph::find_node(self : Graph, name : String) -> Node? {
  match self.root.nodes_by_name.get(name) {
    Some(id) => Some({ root: self.root, id })
    None => None
  }
}

///|
pub fn Graph::nodes(self : Graph) -> Array[Node] {
  self.root.graphs[self.id].nodes.map(id => { root: self.root, id })
}

///|
pub fn Graph::edge(
  self : Graph,
  tail : Node,
  head : Node,
  name? : String,
  tail_port? : Port,
  head_port? : Port,
) -> Edge {
  let tail_id = tail.id
  let head_id = head.id
  let pair_key = edge_pair_key(self.root.kind, tail_id, head_id)
  let existing = if self.root.strict {
    self.root.edge_pair_index.get(pair_key)
  } else {
    match name {
      Some(label) => {
        let key = edge_key(self.root.kind, tail_id, head_id, Some(label))
        self.root.edge_index.get(key)
      }
      None => None
    }
  }
  let edge_id = match existing {
    Some(id) => id
    None => {
      let new_id = self.root.edges.length()
      let attrs = collect_defaults(self.root, self.id, AttrKind::Edge)
      let state : EdgeState = {
        tail: tail_id,
        head: head_id,
        name,
        tail_port,
        head_port,
        home_graph_id: self.id,
        attrs,
      }
      self.root.edges.push(state)
      if self.root.strict {
        self.root.edge_pair_index[pair_key] = new_id
      } else {
        match name {
          Some(label) => {
            let key = edge_key(self.root.kind, tail_id, head_id, Some(label))
            self.root.edge_index[key] = new_id
          }
          None => ()
        }
      }
      new_id
    }
  }
  add_edge_membership(self.root, self.id, edge_id)
  { root: self.root, id: edge_id }
}

///|
pub fn Graph::edges(self : Graph) -> Array[Edge] {
  self.root.graphs[self.id].edges.map(id => { root: self.root, id })
}

///|
pub fn Node::name(self : Node) -> String {
  self.root.nodes[self.id].name
}

///|
pub fn Node::graph(self : Node) -> Graph {
  let home = self.root.nodes[self.id].home_graph_id
  { root: self.root, id: home }
}

///|
pub fn Edge::tail(self : Edge) -> Node {
  { root: self.root, id: self.root.edges[self.id].tail }
}

///|
pub fn Edge::head(self : Edge) -> Node {
  { root: self.root, id: self.root.edges[self.id].head }
}

///|
pub fn Edge::name(self : Edge) -> String? {
  self.root.edges[self.id].name
}

///|
pub fn Edge::tail_port(self : Edge) -> Port? {
  self.root.edges[self.id].tail_port
}

///|
pub fn Edge::head_port(self : Edge) -> Port? {
  self.root.edges[self.id].head_port
}

///|
pub fn Graph::declare_attr(
  self : Graph,
  kind : AttrKind,
  name : String,
  default? : String = "",
) -> Unit {
  let defaults = match kind {
    AttrKind::Graph => self.root.graphs[self.id].defaults_graph
    AttrKind::Node => self.root.graphs[self.id].defaults_node
    AttrKind::Edge => self.root.graphs[self.id].defaults_edge
  }
  if defaults.get(name) is None {
    defaults[name] = default
  }
}

///|
pub fn Graph::set_default_attr(
  self : Graph,
  kind : AttrKind,
  name : String,
  value : String,
) -> Unit {
  let defaults = match kind {
    AttrKind::Graph => self.root.graphs[self.id].defaults_graph
    AttrKind::Node => self.root.graphs[self.id].defaults_node
    AttrKind::Edge => self.root.graphs[self.id].defaults_edge
  }
  defaults[name] = value
}

///|
pub fn Graph::get_default_attr(
  self : Graph,
  kind : AttrKind,
  name : String,
) -> String? {
  resolve_default(self.root, self.id, kind, name)
}

///|
pub fn Graph::set_attr(self : Graph, name : String, value : String) -> Unit {
  self.root.graphs[self.id].attrs[name] = value
}

///|
pub fn Graph::get_attr(self : Graph, name : String) -> String? {
  let value = self.root.graphs[self.id].attrs.get(name)
  match value {
    Some(_) => value
    None => resolve_default(self.root, self.id, AttrKind::Graph, name)
  }
}

///|
pub fn Node::set_attr(self : Node, name : String, value : String) -> Unit {
  self.root.nodes[self.id].attrs[name] = value
}

///|
pub fn Node::get_attr(self : Node, name : String) -> String? {
  self.root.nodes[self.id].attrs.get(name)
}

///|
pub fn Edge::set_attr(self : Edge, name : String, value : String) -> Unit {
  self.root.edges[self.id].attrs[name] = value
}

///|
pub fn Edge::get_attr(self : Edge, name : String) -> String? {
  self.root.edges[self.id].attrs.get(name)
}

///|
pub fn Graph::attrs(self : Graph) -> Array[(String, String)] {
  self.root.graphs[self.id].attrs.to_array()
}

///|
pub fn Graph::default_attrs(
  self : Graph,
  kind : AttrKind,
) -> Array[(String, String)] {
  let defaults = match kind {
    AttrKind::Graph => self.root.graphs[self.id].defaults_graph
    AttrKind::Node => self.root.graphs[self.id].defaults_node
    AttrKind::Edge => self.root.graphs[self.id].defaults_edge
  }
  defaults.to_array()
}

///|
pub fn Node::attrs(self : Node) -> Array[(String, String)] {
  self.root.nodes[self.id].attrs.to_array()
}

///|
pub fn Edge::attrs(self : Edge) -> Array[(String, String)] {
  self.root.edges[self.id].attrs.to_array()
}
