///|
/// Extracted from layout_pipeline_stage_c_phase_c5_remincross_reorder_execute_helpers.mbt
/// to keep Stage C ReMincross tracing helpers separate from reorder execution.

///|
/// Debug trace: dump selected ReMincross per-tail edge lists when
/// DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_remincross_order_edges_by_tail(
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  match rem_order_edges_by_tail.get("arbiter_vadam") {
    Some(list) => {
      let mut idx = 0
      while idx < list.length() {
        let (t, h, _pen, _c, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) = list[idx]
        println("remincross arbiter edge \{idx}: \{t} -> \{h}")
        idx = idx + 1
      }
    }
    None => ()
  }
  let debug_tails : Array[String] = ["front_end_jz", "others"]
  for name in debug_tails {
    match rem_order_edges_by_tail.get(name) {
      Some(list) => {
        let mut idx = 0
        while idx < list.length() {
          let (t, h, _pen, _c, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) = list[idx]
          println("remincross out \{name} \{idx}: \{t} -> \{h}")
          idx = idx + 1
        }
      }
      None => ()
    }
  }
}

///|
/// Debug trace: dump materialized ReMincross edges (high-pen and selected
/// endpoints) when DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_remincross_materialized_edges(
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  let mut idx = 0
  while idx < rem_edges_out.length() {
    let edge = rem_edges_out[idx]
    let pen = edge_xpenalty(edge)
    if pen >= CL_CROSS {
      let tail = rem_edge_tail_out[idx]
      let head = rem_edge_head_out[idx]
      println("remincross high-pen edge \{tail} -> \{head} pen=\{pen}")
    }
    idx = idx + 1
  }
  let mut edge_idx = 0
  while edge_idx < rem_edge_tail_out.length() {
    let tail = rem_edge_tail_out[edge_idx]
    let head = rem_edge_head_out[edge_idx]
    if tail == "z_req" || tail == "z_req1" || head == "z_req" ||
      head == "z_req1" {
      println("remincross edge \{edge_idx}: \{tail} -> \{head}")
    }
    edge_idx = edge_idx + 1
  }
}
