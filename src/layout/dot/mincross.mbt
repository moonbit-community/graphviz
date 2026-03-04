///|
let capture_pass0_flat_seed_groups_enabled : Ref[Bool] = Ref::new(false)

///|
let capture_pass0_flat_seed_groups_value : Ref[Map[Int, Array[String]]?] = Ref::new(None)

///|
fn maybe_capture_seed_groups(
  pass : Int,
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
) -> Unit {
  if !capture_pass0_flat_seed_groups_enabled.val || pass != 0 {
    return
  }
  if capture_pass0_flat_seed_groups_value.val is Some(_) {
    return
  }
  let snapshot : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match ordered.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    snapshot[rank] = names
  }
  capture_pass0_flat_seed_groups_value.val = Some(snapshot)
}

///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/mincross.c and flat.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn reorder_rank_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_out_neighbors? : Map[String, Array[String]] = Map::new(),
  graphviz_in_neighbors? : Map[String, Array[String]] = Map::new(),
  fixed_positions? : Map[String, Double] = Map::new(),
  fixed_ranks? : Map[String, Int] = Map::new(),
  graphviz_flip? : Bool = false,
  coalesce_parallel_edges? : Bool = false,
  startpass? : Int = 0,
  startpass_init_infinite? : Bool = false,
  remincross_mode? : Bool = false,
) -> Map[Int, Array[String]] {
  let _ = sizes
  let _ = nodesep_pt
  let _ = has_edge_labels
  let startpass =
    if startpass < 0 { 0 } else if startpass > 2 { 2 } else { startpass }
  let mut ordered : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    ordered[rank] = names
  }
  let rank_sizes : Map[Int, Int] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    rank_sizes[rank] = names.length()
  }
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = @dot_shared.port_is_explicit(edge.tail_port()) ||
      @dot_shared.port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  let edge_pair_order : Map[String, Int] = Map::new()
  let mut edge_idx = 0
  for _edge in edges {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    edge_pair_order["\{tail}|\{head}"] = edge_idx
    edge_idx = edge_idx + 1
  }
  let node_penalty : Map[String, Int] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let penalty = @dot_shared.edge_xpenalty(edge)
    if penalty <= 0 {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_sum = match node_penalty.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_sum = match node_penalty.get(head) {
      Some(value) => value
      None => 0
    }
    node_penalty[tail] = tail_sum + penalty
    node_penalty[head] = head_sum + penalty
  }
  let node_ranks = @ordering.build_node_ranks(ordered)
  // Graphviz parity: cluster-local mincross uses merged rank map including
  // virtual nodes that may not be in the local rank groups.
  for name, rank in fixed_ranks {
    if node_ranks.get(name) is None {
      node_ranks[name] = rank
    }
  }
  let mut best_ordered = @ordering.clone_rank_groups(ordered)
  let mut order_positions = @ordering.order_positions_from_groups(ordered)
  let fixed_order : Map[String, Int] = Map::new()
  for name, pos in fixed_positions {
    fixed_order[name] = pos.to_int()
  }
  let merge_fixed_positions = () => {
    // Graphviz parity: current ND_order snapshot (fixed_positions) must win.
    for name, pos in fixed_positions {
      if order_positions.get(name) is None {
        order_positions[name] = pos
      }
    }
    // Graphviz parity: startpass=2 median lookups may still reference names
    // missing from fixed_positions (e.g. fixture-only anchors).
    if startpass > 1 {
      for name, idx in node_order {
        if order_positions.get(name) is None {
          order_positions[name] = idx.to_double()
        }
      }
    }
  }
  merge_fixed_positions()
  let mut has_port_order = false
  for _name, _ in port_order_positions {
    has_port_order = true
    break
  }
  let mut has_preferred = false
  for name, _ in preferred_positions {
    // Graphviz parity: vnode ordering hints should not disable
    // mincross graphviz-style passes.
    if !name.has_prefix(EDGE_VNODE_PREFIX) {
      has_preferred = true
      break
    }
  }
  // Graphviz parity: port order hints do not switch mincross out of
  // graphviz-style passes (mincross.c still uses in/out port x ties).
  let graphviz_style = !has_preferred
  let median_parents : Map[String, Array[(String, Double)]] = Map::new()
  let median_children : Map[String, Array[(String, Double)]] = Map::new()
  let edge_penalty : Array[Int] = []
  let edge_in : Map[String, Array[Int]] = Map::new()
  let edge_out : Map[String, Array[Int]] = Map::new()
  let mut has_graphviz_neighbor_hints = false
  let mut has_external_in_anchor = false
  let mut has_external_out_anchor = false
  for rank in rank_keys {
    let names = match ordered.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      if graphviz_style {
        median_parents[name] = []
        median_children[name] = []
      }
      edge_in[name] = []
      edge_out[name] = []
    }
  }
  let coalesced_edge_index : Map[String, Int] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let base_penalty = @dot_shared.edge_xpenalty(edge)
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let mut penalty = base_penalty
    if coalesce_parallel_edges && base_penalty > 0 && @dot_shared.edge_is_constraint(edge) {
      let tail_port_order =
        if edge_idx < edge_tail_port_order.length() { edge_tail_port_order[edge_idx] } else {
          0.5
        }
      let head_port_order =
        if edge_idx < edge_head_port_order.length() { edge_head_port_order[edge_idx] } else {
          0.5
        }
      let merge_key =
        "\{tail}|\{head}|\{tail_port_order.to_string()}|\{head_port_order.to_string()}"
      match coalesced_edge_index.get(merge_key) {
        Some(first_idx) => {
          let prev = edge_penalty[first_idx]
          edge_penalty[first_idx] = prev + base_penalty
          penalty = 0
        }
        None => coalesced_edge_index[merge_key] = edge_idx
      }
    }
    edge_penalty.push(penalty)
    if penalty <= 0 || !@dot_shared.edge_is_constraint(edge) {
      continue
    }
    let tail_rank = match node_ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match node_ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    if graphviz_style {
      // Graphviz parity: median neighbor positions include compass-port order
      // fractions (VAL/MC_SCALE tie-breaking in mincross.c).
      let tail_port_order =
        if edge_idx < edge_tail_port_order.length() { edge_tail_port_order[edge_idx] } else {
          0.5
        }
      let head_port_order =
        if edge_idx < edge_head_port_order.length() { edge_head_port_order[edge_idx] } else {
          0.5
        }
      match median_parents.get(head) {
        Some(list) => list.push((tail, tail_port_order))
        None => median_parents[head] = [(tail, tail_port_order)]
      }
      match median_children.get(tail) {
        Some(list) => list.push((head, head_port_order))
        None => median_children[tail] = [(head, head_port_order)]
      }
    }
    match edge_out.get(tail) {
      Some(list) => list.push(edge_idx)
      None => edge_out[tail] = [edge_idx]
    }
    match edge_in.get(head) {
      Some(list) => list.push(edge_idx)
      None => edge_in[head] = [edge_idx]
    }
  }
  if graphviz_style && startpass > 1 && rank_keys.length() <= 3 {
    for rank in rank_keys {
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      for name in names {
        let in_neighbors = match graphviz_in_neighbors.get(name) {
          Some(list) => list
          None => []
        }
        if in_neighbors.length() > 0 {
          has_graphviz_neighbor_hints = true
          for other in in_neighbors {
            if node_ranks.get(other) is None {
              has_external_in_anchor = true
              break
            }
          }
          match median_parents.get(name) {
            Some(list) =>
              for other in in_neighbors {
                list.push((other, 0.0))
              }
            None =>
              if in_neighbors.length() > 0 {
                let list : Array[(String, Double)] = []
                for other in in_neighbors {
                  list.push((other, 0.0))
                }
                median_parents[name] = list
              }
          }
        }
        let out_neighbors = match graphviz_out_neighbors.get(name) {
          Some(list) => list
          None => []
        }
        if out_neighbors.length() > 0 {
          has_graphviz_neighbor_hints = true
          for other in out_neighbors {
            if node_ranks.get(other) is None {
              has_external_out_anchor = true
              break
            }
          }
          match median_children.get(name) {
            Some(list) =>
              for other in out_neighbors {
                list.push((other, 0.0))
              }
            None =>
              if out_neighbors.length() > 0 {
                let list : Array[(String, Double)] = []
                for other in out_neighbors {
                  list.push((other, 0.0))
                }
                median_children[name] = list
              }
          }
        }
      }
    }
  }
  // Graphviz parity: initial passes should always allow acceptance of
  // improved orderings before final crossing baseline is established.
  let mut best_cross =
    if graphviz_style && startpass > 1 && startpass_init_infinite {
    2147483647
  } else if graphviz_style && startpass <= 1 {
    2147483647
  } else if graphviz_style {
    @ordering.count_crossings_port_aware(
      ordered,
      node_ranks,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x=edge_tail_port_x,
      edge_head_port_x=edge_head_port_x,
      fixed_order=fixed_order,
    )
  } else {
    @ordering.count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
  }
  if !graphviz_style && rank_keys.length() > 1 {
    ordered = @ordering.build_component_rank_groups(
      rank_keys,
      groups,
      edge_tail,
      edge_head,
      node_ranks,
      node_order,
      cluster_keys,
      cluster_skeleton,
      0,
      flat_constraints,
      flip=graphviz_flip,
      graphviz_out_neighbors=graphviz_out_neighbors,
      graphviz_in_neighbors=graphviz_in_neighbors,
    )
    ordered = @ordering.flat_reorder_rank_groups(
      rank_keys,
      ordered,
      node_ranks,
      flat_constraints,
      graphviz_flip,
    )
    order_positions = @ordering.order_positions_from_groups(ordered)
    merge_fixed_positions()
    let seed_cross =
      @ordering.count_crossings_port_aware(
        ordered,
        node_ranks,
        edges,
        edge_tail,
        edge_head,
        edge_tail_port_x=edge_tail_port_x,
        edge_head_port_x=edge_head_port_x,
        fixed_order=fixed_order,
      )
    if seed_cross > 0 {
      let _ = @ordering.transpose_rank_groups_port(
        rank_keys,
        ordered,
        node_ranks,
        fixed_order=fixed_order,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_tail_port_x,
        edge_head_port_x,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        false,
        0,
        remincross_mode=remincross_mode,
      )
      order_positions = @ordering.order_positions_from_groups(ordered)
      merge_fixed_positions()
    }
    best_ordered = @ordering.clone_rank_groups(ordered)
    best_cross = @ordering.count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
  }
  if graphviz_style && rank_keys.length() == 1 {
    let max_iter = 24
    let min_quit = 8
    let convergence = 0.995
    let rank = rank_keys[0]
    let single_names = match ordered.get(rank) {
      Some(list) => list
      None => []
    }
    if !@ordering.has_single_rank_incidents(
      single_names,
      edge_tail,
      edge_head,
      edge_penalty,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
    ) {
      return ordered
    }
    let compute_single_cross = () => {
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      @ordering.count_rank_crossings_port(
        rank,
        names,
        node_ranks,
        fixed_order,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_tail_port_x,
        edge_head_port_x,
        edge_penalty,
      )
    }
    let mut force_single_rank_probe = false
    if startpass > 1 {
      best_cross = compute_single_cross()
      best_ordered = @ordering.clone_rank_groups(ordered)
      if best_cross == 0 && has_graphviz_neighbor_hints {
        // Graphviz parity: ND_in/ND_out driven medians can still reorder even
        // when local crossing count is zero.
        force_single_rank_probe = true
        best_cross = 1
      }
    } else {
      best_cross = 2147483647
    }
    let mut cur_cross = best_cross
    let mut pass = startpass
    while pass <= 2 {
      let max_this_pass =
        if pass <= 1 {
        if max_iter < 4 { max_iter } else { 4 }
      } else {
        max_iter
      }
      if pass <= 1 {
        ordered = @ordering.build_component_rank_groups(
          rank_keys,
          groups,
          edge_tail,
          edge_head,
          node_ranks,
          node_order,
          cluster_keys,
          cluster_skeleton,
          pass,
          flat_constraints,
          flip=graphviz_flip,
          graphviz_out_neighbors=graphviz_out_neighbors,
          graphviz_in_neighbors=graphviz_in_neighbors,
        )
        let seed_cross = compute_single_cross()
        if seed_cross > 0 {
          let _ = @ordering.transpose_rank_groups_port(
            rank_keys,
            ordered,
            node_ranks,
            fixed_order=fixed_order,
            edge_in,
            edge_out,
            edge_tail,
            edge_head,
            edge_tail_port_x,
            edge_head_port_x,
            edge_penalty,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            false,
            0,
            remincross_mode=remincross_mode,
          )
        }
        ordered = @ordering.flat_reorder_rank_groups(
          rank_keys,
          ordered,
          node_ranks,
          flat_constraints,
          graphviz_flip,
        )
        maybe_capture_seed_groups(pass, rank_keys, ordered)
        order_positions = @ordering.order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross = compute_single_cross()
        if cur_cross <= best_cross {
          best_cross = cur_cross
          best_ordered = @ordering.clone_rank_groups(ordered)
        }
      } else {
        if cur_cross > best_cross {
          for rank in rank_keys {
            let names = match best_ordered.get(rank) {
              Some(list) => list.copy()
              None => []
            }
            ordered[rank] = names
          }
          order_positions = @ordering.order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        cur_cross = best_cross
      }
      let mut trying = 0
      let mut iter = 0
      let min_probe_iters = if force_single_rank_probe { 2 } else { 0 }
      while iter < max_this_pass {
        if trying >= min_quit || (cur_cross == 0 && iter >= min_probe_iters) {
          break
        }
        trying = trying + 1
        let reverse = iter % 4 < 2
        let names = match ordered.get(rank) {
          Some(list) => list
          None => []
        }
        if names.length() > 1 {
          let desired =
            if iter % 2 == 0 {
              @ordering.compute_scaled_medians(
                names,
                median_parents,
                order_positions,
              )
            } else {
              @ordering.compute_scaled_medians(
                names,
                median_children,
                order_positions,
              )
            }
          let hasfixed = @ordering.apply_flat_mvals(
            names,
            desired,
            edge_in,
            edge_out,
            flat_constraints,
          )
          ordered[rank] = @ordering.reorder_by_medians(
            names,
            desired,
            reverse,
            hasfixed,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            remincross_mode=remincross_mode,
          )
          order_positions = @ordering.order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        let _ = @ordering.transpose_rank_groups_port(
          rank_keys,
          ordered,
          node_ranks,
          fixed_order=fixed_order,
          edge_in,
          edge_out,
          edge_tail,
          edge_head,
          edge_tail_port_x,
          edge_head_port_x,
          edge_penalty,
          cluster_keys,
          cluster_skeleton,
          flat_constraints,
          !reverse,
          0,
          remincross_mode=remincross_mode,
        )
        order_positions = @ordering.order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross = compute_single_cross()
        if cur_cross <= best_cross {
          let prev_best = best_cross
          best_cross = cur_cross
          best_ordered = @ordering.clone_rank_groups(ordered)
          if prev_best > 0 &&
            cur_cross.to_double() < convergence * prev_best.to_double() {
            trying = 0
          }
        }
        iter = iter + 1
      }
      if cur_cross == 0 {
        break
      }
      pass = pass + 1
    }
    if cur_cross > best_cross {
      for rank in rank_keys {
        let names = match best_ordered.get(rank) {
          Some(list) => list.copy()
          None => []
        }
        ordered[rank] = names
      }
      order_positions = @ordering.order_positions_from_groups(ordered)
      merge_fixed_positions()
    }
    if best_cross > 0 {
      let _ = @ordering.transpose_rank_groups_port(
        rank_keys,
        ordered,
        node_ranks,
        fixed_order=fixed_order,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_tail_port_x,
        edge_head_port_x,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        false,
        0,
        remincross_mode=remincross_mode,
      )
    }
    return ordered
  }
  if graphviz_style && rank_keys.length() > 1 {
    let max_iter = 24
    let min_quit = 8
    let convergence = 0.995
    let mut force_graphviz_probe = false
    if startpass > 1 && rank_keys.length() <= 3 && best_cross == 0 &&
      has_graphviz_neighbor_hints {
      // Graphviz parity: ND_in/ND_out medians may drive reorder despite a
      // zero local crossing baseline.
      force_graphviz_probe = true
      best_cross = 1
    }
    let mut cur_cross = best_cross
    let mut pass = startpass
    while pass <= 2 {
      let max_this_pass =
        if pass <= 1 {
        if max_iter < 4 { max_iter } else { 4 }
      } else {
        max_iter
      }
      if pass <= 1 {
        ordered = @ordering.build_component_rank_groups(
          rank_keys,
          groups,
          edge_tail,
          edge_head,
          node_ranks,
          node_order,
          cluster_keys,
          cluster_skeleton,
          pass,
          flat_constraints,
          flip=graphviz_flip,
          graphviz_out_neighbors=graphviz_out_neighbors,
          graphviz_in_neighbors=graphviz_in_neighbors,
        )
        // Graphviz parity: seed transpose probe runs before flat reorder in
        // each graphviz-style pass, independent of port-order hints.
        let seed_cross =
          @ordering.count_crossings_port_aware(
            ordered,
            node_ranks,
            edges,
            edge_tail,
            edge_head,
            edge_tail_port_x=edge_tail_port_x,
            edge_head_port_x=edge_head_port_x,
            fixed_order=fixed_order,
          )
        if seed_cross > 0 {
          let _ = @ordering.transpose_rank_groups_port(
            rank_keys,
            ordered,
            node_ranks,
            fixed_order=fixed_order,
            edge_in,
            edge_out,
            edge_tail,
            edge_head,
            edge_tail_port_x,
            edge_head_port_x,
            edge_penalty,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            false,
            0,
            remincross_mode=remincross_mode,
          )
        }
        ordered = @ordering.flat_reorder_rank_groups(
          rank_keys,
          ordered,
          node_ranks,
          flat_constraints,
          graphviz_flip,
        )
        maybe_capture_seed_groups(pass, rank_keys, ordered)
        order_positions = @ordering.order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross =
          @ordering.count_crossings_port_aware(
            ordered,
            node_ranks,
            edges,
            edge_tail,
            edge_head,
            edge_tail_port_x=edge_tail_port_x,
            edge_head_port_x=edge_head_port_x,
            fixed_order=fixed_order,
          )
        if cur_cross <= best_cross {
          best_cross = cur_cross
          best_ordered = @ordering.clone_rank_groups(ordered)
        }
      } else {
        if cur_cross > best_cross {
          for rank in rank_keys {
            let names = match best_ordered.get(rank) {
              Some(list) => list.copy()
              None => []
            }
            ordered[rank] = names
          }
          order_positions = @ordering.order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        cur_cross = best_cross
      }
      let mut trying = 0
      let mut iter = 0
      let min_probe_iters = if force_graphviz_probe { 2 } else { 0 }
      let use_full_rank_sweeps = force_graphviz_probe
      let include_min_rank = use_full_rank_sweeps || has_external_in_anchor
      let include_max_rank = use_full_rank_sweeps || has_external_out_anchor
      while iter < max_this_pass {
        if trying >= min_quit || (cur_cross == 0 && iter >= min_probe_iters) {
          break
        }
        trying = trying + 1
        let reverse = iter % 4 < 2
        let use_sweep_snapshot = startpass > 1 && pass > 1 &&
          has_graphviz_neighbor_hints && iter % 2 == 0
        let sweep_positions =
          if use_sweep_snapshot { order_positions.copy() } else { order_positions }
        if iter % 2 == 0 {
          let mut idx = if include_min_rank { 0 } else { 1 }
          while idx < rank_keys.length() {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired_positions =
                if use_sweep_snapshot { sweep_positions } else { order_positions }
              let desired = @ordering.compute_scaled_medians(
                names,
                median_parents,
                desired_positions,
              )
              let hasfixed = @ordering.apply_flat_mvals(
                names,
                desired,
                edge_in,
                edge_out,
                flat_constraints,
              )
              ordered[rank] = @ordering.reorder_by_medians(
                names,
                desired,
                reverse,
                hasfixed,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode=remincross_mode,
              )
              if !use_sweep_snapshot {
                order_positions = @ordering.order_positions_from_groups(ordered)
                merge_fixed_positions()
              }
            }
            idx = idx + 1
          }
        } else {
          let mut idx =
            if include_max_rank {
              rank_keys.length() - 1
            } else {
              rank_keys.length() - 2
            }
          while true {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired_positions =
                if use_sweep_snapshot { sweep_positions } else { order_positions }
              let desired = @ordering.compute_scaled_medians(
                names,
                median_children,
                desired_positions,
              )
              let hasfixed = @ordering.apply_flat_mvals(
                names,
                desired,
                edge_in,
                edge_out,
                flat_constraints,
              )
              ordered[rank] = @ordering.reorder_by_medians(
                names,
                desired,
                reverse,
                hasfixed,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode=remincross_mode,
              )
              if !use_sweep_snapshot {
                order_positions = @ordering.order_positions_from_groups(ordered)
                merge_fixed_positions()
              }
            }
            if idx == 0 {
              break
            }
            idx = idx - 1
          }
        }
        if use_sweep_snapshot {
          order_positions = @ordering.order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        // Graphviz parity: transpose remains active with port-order hints;
        // ties are resolved by in/out port x during crossing checks.
        let _ = @ordering.transpose_rank_groups_port(
          rank_keys,
          ordered,
          node_ranks,
          fixed_order=fixed_order,
          edge_in,
          edge_out,
          edge_tail,
          edge_head,
          edge_tail_port_x,
          edge_head_port_x,
          edge_penalty,
          cluster_keys,
          cluster_skeleton,
          flat_constraints,
          !reverse,
          0,
          remincross_mode=remincross_mode,
        )
        order_positions = @ordering.order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross =
          @ordering.count_crossings_port_aware(
            ordered,
            node_ranks,
            edges,
            edge_tail,
            edge_head,
            edge_tail_port_x=edge_tail_port_x,
            edge_head_port_x=edge_head_port_x,
            fixed_order=fixed_order,
          )
        if cur_cross <= best_cross {
          let prev_best = best_cross
          best_cross = cur_cross
          best_ordered = @ordering.clone_rank_groups(ordered)
          if prev_best > 0 &&
            cur_cross.to_double() < convergence * prev_best.to_double() {
            trying = 0
          }
        }
        iter = iter + 1
      }
      if cur_cross == 0 {
        break
      }
      pass = pass + 1
    }
    if cur_cross > best_cross {
      for rank in rank_keys {
        let names = match best_ordered.get(rank) {
          Some(list) => list.copy()
          None => []
        }
        ordered[rank] = names
      }
      order_positions = @ordering.order_positions_from_groups(ordered)
      merge_fixed_positions()
    }
    if best_cross > 0 {
      let _ = @ordering.transpose_rank_groups_port(
        rank_keys,
        ordered,
        node_ranks,
        fixed_order=fixed_order,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_tail_port_x,
        edge_head_port_x,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        false,
        0,
        remincross_mode=remincross_mode,
      )
    }
    return ordered
  }
  if !graphviz_style && rank_keys.length() > 1 {
    let iterations = if rank_keys.length() > 2 { 2 } else { 1 }
    let mut iter = 0
    while iter < iterations {
      let reverse_ties = iter % 2 == 1
      if graphviz_style {
        if iter % 2 == 0 {
          let mut idx = 1
          while idx < rank_keys.length() {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = @ordering.compute_scaled_medians(
                names,
                median_parents,
                order_positions,
              )
              ordered[rank] = @ordering.reorder_by_medians(
                names,
                desired,
                reverse_ties,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode=remincross_mode,
              )
              order_positions = @ordering.order_positions_from_groups(ordered)
              merge_fixed_positions()
            }
            idx = idx + 1
          }
        } else {
          let mut idx = rank_keys.length() - 2
          while true {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = @ordering.compute_scaled_medians(
                names,
                median_children,
                order_positions,
              )
              ordered[rank] = @ordering.reorder_by_medians(
                names,
                desired,
                reverse_ties,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode=remincross_mode,
              )
              order_positions = @ordering.order_positions_from_groups(ordered)
              merge_fixed_positions()
            }
            if idx == 0 {
              break
            }
            idx = idx - 1
          }
        }
        if !has_port_order {
          let _ = @ordering.transpose_rank_groups_port(
            rank_keys,
            ordered,
            node_ranks,
            fixed_order=fixed_order,
            edge_in,
            edge_out,
            edge_tail,
            edge_head,
            edge_tail_port_x,
            edge_head_port_x,
            edge_penalty,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            !reverse_ties,
            0,
            remincross_mode=remincross_mode,
          )
          order_positions = @ordering.order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        let cross =
          @ordering.count_crossings_port_aware(
            ordered,
            node_ranks,
            edges,
            edge_tail,
            edge_head,
            edge_tail_port_x=edge_tail_port_x,
            edge_head_port_x=edge_head_port_x,
            fixed_order=fixed_order,
          )
        if cross <= best_cross {
          best_cross = cross
          best_ordered = @ordering.clone_rank_groups(ordered)
        }
      } else {
        let mut idx = rank_keys.length() - 1
        while idx > 0 {
          let rank = rank_keys[idx - 1]
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = @ordering.compute_desired_positions(
              names,
              parents,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = @ordering.order_rank_by_cluster(
              names, desired, order_positions, parents, children, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = @ordering.order_positions_from_groups(ordered)
            merge_fixed_positions()
          }
          idx = idx - 1
        }
        if !has_port_order {
          let _ = @ordering.transpose_rank_groups_limited(
            rank_keys, ordered, parents, children, node_ranks, true, 2,
          )
        }
        for rank in rank_keys {
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = @ordering.compute_desired_positions(
              names,
              parents,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = @ordering.order_rank_by_cluster(
              names, desired, order_positions, parents, children, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = @ordering.order_positions_from_groups(ordered)
            merge_fixed_positions()
          }
        }
        let down_cross = @ordering.count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
        if down_cross < best_cross {
          best_cross = down_cross
          best_ordered = @ordering.clone_rank_groups(ordered)
        }
        let mut j = 1
        while j < rank_keys.length() {
          let rank = rank_keys[j]
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = @ordering.compute_desired_positions(
              names,
              children,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = @ordering.order_rank_by_cluster(
              names, desired, order_positions, children, parents, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = @ordering.order_positions_from_groups(ordered)
            merge_fixed_positions()
          }
          j = j + 1
        }
        if !has_port_order {
          let _ = @ordering.transpose_rank_groups_limited(
            rank_keys, ordered, parents, children, node_ranks, false, 2,
          )
        }
        for rank in rank_keys {
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = @ordering.compute_desired_positions(
              names,
              children,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = @ordering.order_rank_by_cluster(
              names, desired, order_positions, children, parents, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = @ordering.order_positions_from_groups(ordered)
            merge_fixed_positions()
          }
        }
        let up_cross = @ordering.count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
        if up_cross < best_cross {
          best_cross = up_cross
          best_ordered = @ordering.clone_rank_groups(ordered)
        }
      }
      iter = iter + 1
    }
  }
  best_ordered
}
