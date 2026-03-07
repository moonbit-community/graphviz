///|
priv struct RootBoundaryTargetEdgesInput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
  target_names : Array[String]
  root_idx : Int
  sizes : Map[String, @node_primitives.NodeSize]
  root_margin : Double
  compress_mode : Bool
  is_left_boundary : Bool
}

///|
fn add_root_boundary_target_edges(
  input : RootBoundaryTargetEdgesInput,
) -> Unit {
  let base_minlen = @numeric.round_int(input.root_margin)
  for name in input.target_names {
    match input.index.get(name) {
      Some(idx) => {
        let minlen =
          if input.compress_mode {
            if input.is_left_boundary {
              @numeric.round_int(
                @node_primitives.node_left_pt(name, input.sizes) + input.root_margin,
              )
            } else {
              @numeric.round_int(
                @node_primitives.node_right_pt(name, input.sizes) + input.root_margin,
              )
            }
          } else {
            base_minlen
          }
        if input.is_left_boundary {
          let _ = @network_simplex.add_edge(input.graph, input.root_idx, idx, minlen, 0)
        } else {
          let _ = @network_simplex.add_edge(input.graph, idx, input.root_idx, minlen, 0)
        }
      }
      None => ()
    }
  }
}

///|
/// Graphviz parity: root boundary constraints add synthetic ln/rn slack nodes
/// and optional compress-width edge before simplex solve.
pub(all) struct RootBoundaryConstraintsInput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
  root_ln_targets : Array[String]
  root_rn_targets : Array[String]
  sizes : Map[String, @node_primitives.NodeSize]
  root_margin : Double
  compress_width_minlen : Int?
  root_compress_weight : Int
}

///|
/// Graphviz parity: root boundary links mirror contain_nodes/create_aux_edges
/// order and include the optional compress edge when size=... is active.
pub fn add_root_boundary_constraints(
  input : RootBoundaryConstraintsInput,
) -> Unit {
  if input.root_ln_targets.length() == 0 && input.root_rn_targets.length() == 0 {
    return ()
  }
  let root_ln =
    @network_simplex.add_node(input.graph, "", kind=@network_simplex.NodeKind::Slack)
  let root_rn =
    @network_simplex.add_node(input.graph, "", kind=@network_simplex.NodeKind::Slack)
  @network_simplex.set_node_rank(input.graph, root_ln, 0)
  @network_simplex.set_node_rank(input.graph, root_rn, 0)
  let compress_mode = input.compress_width_minlen is Some(_)
  add_root_boundary_target_edges(
    {
      graph: input.graph,
      index: input.index,
      target_names: input.root_ln_targets,
      root_idx: root_ln,
      sizes: input.sizes,
      root_margin: input.root_margin,
      compress_mode,
      is_left_boundary: true,
    },
  )
  add_root_boundary_target_edges(
    {
      graph: input.graph,
      index: input.index,
      target_names: input.root_rn_targets,
      root_idx: root_rn,
      sizes: input.sizes,
      root_margin: input.root_margin,
      compress_mode,
      is_left_boundary: false,
    },
  )
  match input.compress_width_minlen {
    Some(width_minlen) => {
      let _ = @network_simplex.add_edge(
        input.graph,
        root_ln,
        root_rn,
        width_minlen,
        input.root_compress_weight,
      )
    }
    None => ()
  }
}
