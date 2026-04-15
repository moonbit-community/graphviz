// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "rank_reorder preserves initial tie order for symmetric fixed case" {
  let input : MincrossInput = {
    case_id: 1001,
    graph: "fixed_case",
    startpass: 0,
    flip: false,
    minrank: 0,
    maxrank: 1,
    nodes: [
      {
        id: 0,
        name: None,
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [1, 3],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: None,
        rank: 1,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [0, 2],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 2,
        name: None,
        rank: 0,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [1, 3],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 3,
        name: None,
        rank: 1,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [0, 2],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
    ],
    edges: [
      {
        tail: 0,
        head: 1,
        xpenalty: 1,
        seq: 3,
        order: 0,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 0,
        head: 3,
        xpenalty: 1,
        seq: 4,
        order: 1,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 2,
        head: 1,
        xpenalty: 1,
        seq: 1,
        order: 2,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 2,
        head: 3,
        xpenalty: 1,
        seq: 2,
        order: 3,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
    ],
    flat_edges: [],
    ranks: [[0, 2], [1, 3]],
  }
  let output : MincrossOutput = { case_id: 1001, ranks: [[0, 2], [1, 3]] }

  run_fixed_rank_reorder_case(input, output)
}

///|
test "rank_reorder recovers nlist tie order from reversed seed" {
  let input : MincrossInput = {
    case_id: 1002,
    graph: "fixed_case_reversed_seed",
    startpass: 0,
    flip: false,
    minrank: 0,
    maxrank: 1,
    nodes: [
      {
        id: 0,
        name: None,
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [1, 3],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: None,
        rank: 1,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [0, 2],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 2,
        name: None,
        rank: 0,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [1, 3],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 3,
        name: None,
        rank: 1,
        order: 3,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [0, 2],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
    ],
    edges: [
      {
        tail: 0,
        head: 1,
        xpenalty: 1,
        seq: 3,
        order: 0,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 0,
        head: 3,
        xpenalty: 1,
        seq: 4,
        order: 1,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 2,
        head: 1,
        xpenalty: 1,
        seq: 1,
        order: 2,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
      {
        tail: 2,
        head: 3,
        xpenalty: 1,
        seq: 2,
        order: 3,
        tail_port_x: 0.0,
        head_port_x: 0.0,
        tail_port_order: 0.0,
        head_port_order: 0.0,
      },
    ],
    flat_edges: [],
    ranks: [[2, 0], [1, 3]],
  }
  let output : MincrossOutput = { case_id: 1002, ranks: [[0, 2], [1, 3]] }

  run_fixed_rank_reorder_case(input, output)
}

///|
test "rank_reorder keeps flip-enabled single chains stable" {
  let input : MincrossInput = {
    case_id: 1003,
    graph: "xlabels_lr_direct",
    startpass: 0,
    flip: true,
    minrank: 0,
    maxrank: 1,
    nodes: [
      {
        id: 0,
        name: Some("a"),
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
        name: Some("b"),
        rank: 1,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [0],
        out_all_neighbors: [],
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
    ],
    flat_edges: [],
    ranks: [[0], [1]],
  }
  let output : MincrossOutput = { case_id: 1003, ranks: [[0], [1]] }

  run_mincross_case_with_name_order(input, output, Map::new())
}

///|
test "rank_reorder keeps total flat-label constraints in source order" {
  let input : MincrossInput = {
    case_id: 1004,
    graph: "flat_label_direct",
    startpass: 0,
    flip: false,
    minrank: 0,
    maxrank: 0,
    nodes: [
      {
        id: 0,
        name: Some("a"),
        rank: 0,
        order: 0,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 1,
        name: Some("b"),
        rank: 0,
        order: 1,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
      {
        id: 2,
        name: Some("c"),
        rank: 0,
        order: 2,
        cluster: None,
        cluster_skeleton: false,
        out_neighbors: [],
        in_neighbors: [],
        out_all_neighbors: [],
        in_all_neighbors: [],
      },
    ],
    edges: [],
    flat_edges: [
      { tail: 0, head: 1 },
      { tail: 0, head: 2 },
      { tail: 1, head: 2 },
    ],
    ranks: [[0, 1, 2]],
  }
  let output : MincrossOutput = { case_id: 1004, ranks: [[0, 1, 2]] }

  run_mincross_case_with_name_order(input, output, Map::new())
}
