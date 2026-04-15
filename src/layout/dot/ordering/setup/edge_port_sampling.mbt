// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Ordering domain: edge endpoint projection and tail/head sampling helpers
/// shared by dot-stage edge-port preprocessing.

///|
/// Graphviz parity: edge endpoint projection caches tail/head names and ports
/// in edge traversal order shared by both x-offset and port-order passes.
/// Do not change behavior without updating fixtures/tests.
priv struct EdgeEndpointPortProjection {
  tail_names : Array[String]
  head_names : Array[String]
  tail_ports : Array[@cgraph.Port?]
  head_ports : Array[@cgraph.Port?]
}

///|
/// Graphviz parity: edge endpoint samples keep tail/head arrays aligned by edge
/// traversal order for both x-offset and port-order passes.
priv struct EdgeEndpointPortSamples {
  tail_values : Array[Double]
  head_values : Array[Double]
}

///|
/// Graphviz parity: edge-port sample bundle keeps x-offset and port-order
/// arrays aligned by edge traversal order for tie-break and median passes.
pub(all) struct EdgePortSampleBundle {
  tail_port_x : Array[Double]
  head_port_x : Array[Double]
  tail_port_order : Array[Double]
  head_port_order : Array[Double]
}

///|
/// Graphviz parity: edge endpoint projection caches tail/head names and ports
/// in edge traversal order shared by both x-offset and port-order passes.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_endpoint_port_projection(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> EdgeEndpointPortProjection {
  let tail_names : Array[String] = []
  let head_names : Array[String] = []
  let tail_ports : Array[@cgraph.Port?] = []
  let head_ports : Array[@cgraph.Port?] = []
  let mut endpoint_idx = 0
  while endpoint_idx < edges.length() {
    let edge = edges[endpoint_idx]
    let (tail_name, head_name) = @order_graph.edge_endpoints_at(
      edge, endpoint_idx, edge_tail, edge_head,
    )
    let tail_port = @order_graph.edge_tail_port_for_name(edge, tail_name)
    let head_port = @order_graph.edge_head_port_for_name(edge, head_name)
    tail_names.push(tail_name)
    head_names.push(head_name)
    tail_ports.push(tail_port)
    head_ports.push(head_port)
    endpoint_idx = endpoint_idx + 1
  }
  { tail_names, head_names, tail_ports, head_ports }
}

///|
/// Graphviz parity: tail/head samples are emitted in edge sequence order from
/// the precomputed endpoint-name/port projection.
fn sample_edge_endpoint_ports(
  projection : EdgeEndpointPortProjection,
  sample_fn : (String, @cgraph.Port?) -> Double,
) -> EdgeEndpointPortSamples {
  let tail_values : Array[Double] = []
  let head_values : Array[Double] = []
  let mut idx = 0
  while idx < projection.tail_names.length() {
    tail_values.push(
      sample_fn(projection.tail_names[idx], projection.tail_ports[idx]),
    )
    head_values.push(
      sample_fn(projection.head_names[idx], projection.head_ports[idx]),
    )
    idx = idx + 1
  }
  { tail_values, head_values }
}

///|
/// Graphviz parity: x-offset and port-order endpoint samples are computed from
/// the same endpoint projection for deterministic pairing.
pub fn build_edge_port_sample_bundle(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sample_x_fn : (String, @cgraph.Port?) -> Double,
  sample_order_fn : (String, @cgraph.Port?) -> Double,
) -> EdgePortSampleBundle {
  if edges.length() == 0 {
    return {
      tail_port_x: [],
      head_port_x: [],
      tail_port_order: [],
      head_port_order: [],
    }
  }
  let endpoint_projection = build_edge_endpoint_port_projection(
    edges, edge_tail, edge_head,
  )
  let x_samples = sample_edge_endpoint_ports(endpoint_projection, sample_x_fn)
  let order_samples = sample_edge_endpoint_ports(
    endpoint_projection, sample_order_fn,
  )
  {
    tail_port_x: x_samples.tail_values,
    head_port_x: x_samples.head_values,
    tail_port_order: order_samples.tail_values,
    head_port_order: order_samples.head_values,
  }
}

///|
pub(all) struct DedupOrderingEdgesOutput {
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
}

///|
fn dedup_ordering_edges(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> DedupOrderingEdgesOutput {
  let seen : Map[String, Bool] = Map::new()
  let out_edges : Array[@cgraph.Edge] = []
  let out_tail : Array[String] = []
  let out_head : Array[String] = []
  for i in 0..<edges.length() {
    let (tail, head) = @order_graph.edge_endpoints_at(
      edges[i],
      i,
      edge_tail,
      edge_head,
    )
    let key = "\{tail}|\{head}"
    if seen.get(key) is Some(_) {
      continue
    }
    seen[key] = true
    out_edges.push(edges[i])
    out_tail.push(tail)
    out_head.push(head)
  }
  {
    order_edges: out_edges,
    order_edge_tail: out_tail,
    order_edge_head: out_head,
  }
}

///|
/// Ordering domain: edge-port sampling outputs used by class2 preprocessing.

///|
pub(all) struct OrderingEdgePortData {
  edge_order : Map[String, Int]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
}

///|
/// Graphviz parity: edge-port sampling source bundle keeps full-edge and
/// endpoint-name snapshots grouped before dedup/order-edge replay.
pub(all) struct OrderingEdgePortDataSources {
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
}

///|
/// Graphviz parity: ordering edge-port data keeps dedup ordering-edge
/// extraction and endpoint port samples in Graphviz-compatible construction
/// order from grouped sources.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_edge_port_data_from_sources(
  sources : OrderingEdgePortDataSources,
  build_port_sample_bundle : (Array[@cgraph.Edge], Array[String], Array[String]) -> EdgePortSampleBundle,
) -> OrderingEdgePortData {
  let edge_port_samples = build_port_sample_bundle(
    sources.edges,
    sources.edge_tail,
    sources.edge_head,
  )
  let dedup_order_edges = dedup_ordering_edges(
    sources.edges,
    sources.edge_tail,
    sources.edge_head,
  )
  let order_edge_port_samples = build_port_sample_bundle(
    dedup_order_edges.order_edges,
    dedup_order_edges.order_edge_tail,
    dedup_order_edges.order_edge_head,
  )
  {
    edge_order: @order_graph.collect_edge_order(sources.edges),
    edge_tail_port_x: edge_port_samples.tail_port_x,
    edge_head_port_x: edge_port_samples.head_port_x,
    edge_tail_port_order: edge_port_samples.tail_port_order,
    edge_head_port_order: edge_port_samples.head_port_order,
    order_edges: dedup_order_edges.order_edges,
    order_edge_tail: dedup_order_edges.order_edge_tail,
    order_edge_head: dedup_order_edges.order_edge_head,
    order_edge_tail_port_x: order_edge_port_samples.tail_port_x,
    order_edge_head_port_x: order_edge_port_samples.head_port_x,
    order_edge_tail_port_order: order_edge_port_samples.tail_port_order,
    order_edge_head_port_order: order_edge_port_samples.head_port_order,
  }
}
