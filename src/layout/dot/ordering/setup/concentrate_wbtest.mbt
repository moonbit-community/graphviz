// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "concentrate uses the retained endpoint port after resolving aliases" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let head = graph.node("head")
  let a = graph.node("a")
  let c = graph.node("c")
  let normal : @cgraph.Port = { name: Some("Normal"), compass: None, }
  let target : @cgraph.Port = { name: Some("Target"), compass: None, }
  let kept_edge = graph.edge(a, head, head_port=normal)
  let absorbed_edge = graph.edge(a, head, head_port=target)
  let other_edge = graph.edge(c, head, head_port=target)
  let ranks : Map[String, Int] = { "a": 0, "c": 0, "head": 2 }
  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let kept = edge_vnode_chain_for_test(vnode_info, kept_edge)[0]
  let absorbed = edge_vnode_chain_for_test(vnode_info, absorbed_edge)[0]
  let other = edge_vnode_chain_for_test(vnode_info, other_edge)[0]
  let aliases : Map[String, String] = Map([(absorbed, kept)])
  merge_adjacent_vnode_run(
    [absorbed_edge, other_edge],
    [kept_edge, absorbed_edge, other_edge],
    ranks,
    vnode_info,
    false,
    0,
    { 1: [kept, other] },
    aliases,
  )
  assert_true(aliases.get(other) is None)
  merge_adjacent_vnode_run(
    [absorbed_edge, other_edge],
    [kept_edge, absorbed_edge, other_edge],
    ranks,
    vnode_info,
    false,
    0,
    { 1: [kept, other] },
    aliases,
    node_ports_equal=(_, _, _) => true,
  )
  assert_eq(aliases.get(other), Some(kept))
}

///|
test "concentrate absorbs the right virtual chain sharing a head port" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("concentrate", "true")
  let tail = graph.node("tail")
  let head = graph.node("head")
  let in_port : @cgraph.Port = { name: Some("In"), compass: None, }
  let normal = graph.edge(
    tail,
    head,
    tail_port={ name: Some("Normal"), compass: None, },
    head_port=in_port,
  )
  let target = graph.edge(
    tail,
    head,
    tail_port={ name: Some("Target"), compass: None, },
    head_port=in_port,
  )
  let ranks : Map[String, Int] = { "tail": 0, "head": 3 }
  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let normal_chain = edge_vnode_chain_for_test(vnode_info, normal)
  let target_chain = edge_vnode_chain_for_test(vnode_info, target)
  let ordered_groups : Map[Int, Array[String]] = {
    1: [normal_chain[0], target_chain[0]],
    2: [normal_chain[1], target_chain[1]],
  }

  let concentrated = concentrate_vnode_data(
    graph,
    [normal, target],
    ranks,
    vnode_info,
    ordered_groups,
  )

  assert_eq(normal.get_attr("_concentrated_absorbed"), Some("false"))
  assert_eq(target.get_attr("_concentrated_absorbed"), Some("true"))
  assert_eq(
    edge_vnode_chain_for_test(concentrated.vnode_info, normal),
    edge_vnode_chain_for_test(concentrated.vnode_info, target),
  )
  assert_eq(concentrated.vnode_info.vnode_ranks.length(), 2)
}

///|
test "concentrate does not reuse a representative that already branches" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let left_head = graph.node("left_head")
  let right_head = graph.node("right_head")
  let left_edge = graph.edge(tail, left_head)
  let right_edge = graph.edge(tail, right_head)
  let ranks : Map[String, Int] = { "tail": 0, "left_head": 2, "right_head": 2 }
  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let left_vnode = edge_vnode_chain_for_test(vnode_info, left_edge)[0]
  let right_vnode = edge_vnode_chain_for_test(vnode_info, right_edge)[0]
  let aliases : Map[String, String] = Map([])
  aliases[right_vnode] = left_vnode

  let degrees = build_concentrated_vnode_degrees(
    [left_edge, right_edge],
    ranks,
    vnode_info,
    aliases,
  )

  assert_false(is_concentrate_candidate(left_vnode, degrees))
}

///|
test "concentrate excludes opposite chains only when initial ports match" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let low = graph.node("low")
  let high = graph.node("high")
  let forward = graph.edge(low, high)
  let backward = graph.edge(high, low)
  let ranks : Map[String, Int] = { "low": 0, "high": 3 }
  let unmatched = concentrate_opposite_edges([forward, backward], ranks, (_, _) => {
    false
  })
  let matched = concentrate_opposite_edges([forward, backward], ranks, (_, _) => {
    true
  })
  assert_eq(unmatched.length(), 0)
  assert_eq(matched.get(@edge_identity.edge_vnode_key(forward)), Some(true))
  assert_eq(matched.get(@edge_identity.edge_vnode_key(backward)), Some(true))
  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let candidates = build_concentrate_edge_groups(
    [forward, backward],
    ranks,
    vnode_info,
    true,
    excluded_edges=matched,
  )
  assert_eq(candidates.length(), 0)
}

///|
test "concentrate groups backward edges by rank-oriented endpoints" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let high = graph.node("high")
  let low_a = graph.node("low_a")
  let low_b = graph.node("low_b")
  let first = graph.edge(high, low_a)
  let second = graph.edge(high, low_b)
  let ranks : Map[String, Int] = { "high": 3, "low_a": 0, "low_b": 0 }
  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let downward = build_concentrate_edge_groups(
    [first, second],
    ranks,
    vnode_info,
    true,
  )
  let upward = build_concentrate_edge_groups(
    [first, second],
    ranks,
    vnode_info,
    false,
  )
  assert_eq(downward.length(), 2)
  assert_eq(upward.length(), 1)
}

///|
test "concentrate requires the same live predecessor beyond the first rank" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let first_head = graph.node("first")
  let second_head = graph.node("second")
  let first = graph.edge(tail, first_head)
  let second = graph.edge(tail, second_head)
  let ranks : Map[String, Int] = { "tail": 0, "first": 3, "second": 3 }
  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let first_chain = edge_vnode_chain_for_test(vnode_info, first)
  let second_chain = edge_vnode_chain_for_test(vnode_info, second)
  let aliases : Map[String, String] = Map([])
  merge_adjacent_vnode_run(
    [first, second],
    [first, second],
    ranks,
    vnode_info,
    true,
    1,
    { 2: [first_chain[1], second_chain[1]] },
    aliases,
  )
  assert_true(aliases.get(second_chain[1]) is None)
  aliases[second_chain[0]] = first_chain[0]
  merge_adjacent_vnode_run(
    [first, second],
    [first, second],
    ranks,
    vnode_info,
    true,
    1,
    { 2: [first_chain[1], second_chain[1]] },
    aliases,
  )
  assert_eq(aliases.get(second_chain[1]), Some(first_chain[1]))
}

///|
test "concentrate degrees follow rank direction for shared opposite edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let low = graph.node("low")
  let high = graph.node("high")
  let forward = graph.edge(low, high)
  let backward = graph.edge(high, low)
  let ranks : Map[String, Int] = { "low": 0, "high": 2 }
  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let forward_vnode = edge_vnode_chain_for_test(vnode_info, forward)[0]
  let backward_vnode = edge_vnode_chain_for_test(vnode_info, backward)[0]
  let aliases : Map[String, String] = Map([])
  aliases[backward_vnode] = forward_vnode
  let degrees = build_concentrated_vnode_degrees(
    [forward, backward],
    ranks,
    vnode_info,
    aliases,
  )
  assert_true(is_concentrate_candidate(forward_vnode, degrees))
  assert_eq(degrees.incoming[forward_vnode].get("low"), Some(true))
  assert_eq(degrees.outgoing[forward_vnode].get("high"), Some(true))
}

///|
test "concentrate considers branches outside the common endpoint group" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let head = graph.node("head")
  let other = graph.node("other")
  let first = graph.edge(a, head)
  let second = graph.edge(b, head)
  let branch = graph.edge(a, other)
  let ranks : Map[String, Int] = { "a": 0, "b": 0, "head": 2, "other": 2 }
  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let first_vnode = edge_vnode_chain_for_test(vnode_info, first)[0]
  let second_vnode = edge_vnode_chain_for_test(vnode_info, second)[0]
  let branch_vnode = edge_vnode_chain_for_test(vnode_info, branch)[0]
  let aliases : Map[String, String] = Map([])
  aliases[branch_vnode] = first_vnode

  merge_adjacent_vnode_run(
    [first, second],
    [first, second, branch],
    ranks,
    vnode_info,
    false,
    0,
    { 1: [first_vnode, second_vnode, branch_vnode] },
    aliases,
  )

  assert_true(aliases.get(second_vnode) is None)
}
