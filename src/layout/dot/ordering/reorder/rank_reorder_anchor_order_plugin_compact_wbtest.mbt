// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// External-anchor-order rank_reorder scenarios are split out so the
/// core wbtest file stays focused on non-anchor synthetic and clustered cases.
/// These compact cases cover single-direction plugin anchor ordering.

///|
test "rank_reorder uses external anchor order for plugin-style single-rank slices" {
  let input : MincrossInput = {
    case_id: 1007,
    graph: "plugin_single_rank_anchor_order",
    startpass: 2,
    flip: false,
    minrank: 0,
    maxrank: 0,
    nodes: [
      {
        id: 0,
        name: Some("bmp"),
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_bmp"],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: Some("jpg"),
        rank: 0,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_jpg"],
        in_all_neighbors: [],
      },
      {
        id: 2,
        name: Some("png"),
        rank: 0,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_png"],
        in_all_neighbors: [],
      },
      {
        id: 3,
        name: Some("tga"),
        rank: 0,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_tga"],
        in_all_neighbors: [],
      },
      {
        id: 4,
        name: Some("tif"),
        rank: 0,
        order: 4,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_tif"],
        in_all_neighbors: [],
      },
      {
        id: 5,
        name: Some("tiff"),
        rank: 0,
        order: 5,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: ["fmt_tiff"],
        in_all_neighbors: [],
      },
    ],
    edges: [],
    flat_edges: [],
    ranks: [[0, 1, 2, 3, 4, 5]],
  }
  let output : MincrossOutput = { case_id: 1007, ranks: [[5, 4, 0, 3, 1, 2]] }
  let name_order : Map[String, Int] = Map::new()
  name_order["fmt_tiff"] = 3
  name_order["fmt_tif"] = 4
  name_order["fmt_bmp"] = 5
  name_order["fmt_tga"] = 6
  name_order["fmt_jpg"] = 7
  name_order["fmt_png"] = 8

  run_mincross_case_with_name_order(input, output, name_order)
}

///|
test "rank_reorder uses external anchor order to break symmetric plugin fanout ties" {
  let input : MincrossInput = {
    case_id: 1008,
    graph: "plugin_fanout_anchor_order",
    startpass: 2,
    flip: false,
    minrank: 0,
    maxrank: 2,
    nodes: [
      {
        id: 0,
        name: Some("input"),
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [1],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: Some("router"),
        rank: 1,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [2, 3, 4, 5],
        in_neighbors: [0],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 2,
        name: Some("pdf"),
        rank: 2,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [1],
        out_all_neighbors: ["fmt_pdf"],
        in_all_neighbors: [],
      },
      {
        id: 3,
        name: Some("png"),
        rank: 2,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [1],
        out_all_neighbors: ["fmt_png"],
        in_all_neighbors: [],
      },
      {
        id: 4,
        name: Some("ps"),
        rank: 2,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [1],
        out_all_neighbors: ["fmt_ps"],
        in_all_neighbors: [],
      },
      {
        id: 5,
        name: Some("svg"),
        rank: 2,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [1],
        out_all_neighbors: ["fmt_svg"],
        in_all_neighbors: [],
      },
    ],
    edges: [
      {
        tail: 0,
        head: 1,
        xpenalty: 1,
        seq: 1,
        order: 0,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 1,
        head: 2,
        xpenalty: 1,
        seq: 2,
        order: 0,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 1,
        head: 3,
        xpenalty: 1,
        seq: 3,
        order: 1,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 1,
        head: 4,
        xpenalty: 1,
        seq: 4,
        order: 2,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 1,
        head: 5,
        xpenalty: 1,
        seq: 5,
        order: 3,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
    ],
    flat_edges: [],
    ranks: [[0], [1], [2, 3, 4, 5]],
  }
  let output : MincrossOutput = {
    case_id: 1008,
    ranks: [[0], [1], [3, 2, 5, 4]],
  }
  let name_order : Map[String, Int] = Map::new()
  name_order["fmt_png"] = 8
  name_order["fmt_pdf"] = 9
  name_order["fmt_svg"] = 15
  name_order["fmt_ps"] = 16

  run_mincross_case_with_name_order(input, output, name_order)
}
