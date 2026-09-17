///|
fn compare_nodes_by_rank(
  graph : NsGraph,
  nodes : Array[Int],
  left : Int,
  right : Int,
) -> Int {
  graph.nodes[nodes[left]].rank.compare(graph.nodes[nodes[right]].rank)
}

///|
fn node_rank_median(
  graph : NsGraph,
  nodes : Array[Int],
  first : Int,
  second : Int,
  third : Int,
) -> Int {
  let first_second = compare_nodes_by_rank(graph, nodes, first, second)
  let second_third = compare_nodes_by_rank(graph, nodes, second, third)
  let first_third = compare_nodes_by_rank(graph, nodes, first, third)
  if first_second < 0 {
    if second_third < 0 {
      second
    } else if first_third < 0 {
      third
    } else {
      first
    }
  } else if second_third > 0 {
    second
  } else if first_third < 0 {
    first
  } else {
    third
  }
}

///|
fn swap_node_rank_ranges(
  nodes : Array[Int],
  first : Int,
  second : Int,
  length : Int,
) -> Unit {
  for offset in 0..<length {
    nodes.swap(first + offset, second + offset)
  }
}

///|
fn insertion_sort_nodes_by_rank(
  graph : NsGraph,
  nodes : Array[Int],
  low : Int,
  high : Int,
) -> Unit {
  for current in (low + 1)..<high {
    for position = current {
      guard position > low &&
        compare_nodes_by_rank(graph, nodes, position - 1, position) > 0 else {
        break
      }
      nodes.swap(position - 1, position)
      continue position - 1
    }
  }
}

///|
fn sort_node_rank_range(
  graph : NsGraph,
  nodes : Array[Int],
  low : Int,
  high : Int,
) -> Unit {
  let length = high - low
  guard length >= 7 else {
    insertion_sort_nodes_by_rank(graph, nodes, low, high)
    return
  }
  let middle = low + length / 2
  let last = high - 1
  let pivot = if length > 40 {
    let offset = length / 8
    let first = node_rank_median(
      graph,
      nodes,
      low,
      low + offset,
      low + offset * 2,
    )
    let center = node_rank_median(
      graph,
      nodes,
      middle - offset,
      middle,
      middle + offset,
    )
    let end = node_rank_median(
      graph,
      nodes,
      last - offset * 2,
      last - offset,
      last,
    )
    node_rank_median(graph, nodes, first, center, end)
  } else {
    node_rank_median(graph, nodes, low, middle, last)
  }
  nodes.swap(low, pivot)
  let pivot_rank = graph.nodes[nodes[low]].rank
  let mut equal_left = low + 1
  let mut scan_left = low + 1
  let mut scan_right = high - 1
  let mut equal_right = high - 1
  let mut partition_swapped = false
  while scan_left <= scan_right {
    while scan_left <= scan_right &&
          graph.nodes[nodes[scan_left]].rank <= pivot_rank {
      if graph.nodes[nodes[scan_left]].rank == pivot_rank {
        nodes.swap(equal_left, scan_left)
        equal_left = equal_left + 1
        partition_swapped = true
      }
      scan_left = scan_left + 1
    }
    while scan_left <= scan_right &&
          graph.nodes[nodes[scan_right]].rank >= pivot_rank {
      if graph.nodes[nodes[scan_right]].rank == pivot_rank {
        nodes.swap(scan_right, equal_right)
        equal_right = equal_right - 1
        partition_swapped = true
      }
      scan_right = scan_right - 1
    }
    if scan_left <= scan_right {
      nodes.swap(scan_left, scan_right)
      partition_swapped = true
      scan_left = scan_left + 1
      scan_right = scan_right - 1
    }
  }
  let left_equal_count = (equal_left - low).min(scan_left - equal_left)
  swap_node_rank_ranges(
    nodes,
    low,
    scan_left - left_equal_count,
    left_equal_count,
  )
  let right_equal_count = (equal_right - scan_right).min(high - 1 - equal_right)
  swap_node_rank_ranges(
    nodes,
    scan_left,
    high - right_equal_count,
    right_equal_count,
  )
  guard partition_swapped else {
    insertion_sort_nodes_by_rank(graph, nodes, low, high)
    return
  }
  let less_end = low + scan_left - equal_left
  let greater_start = high - (equal_right - scan_right)
  sort_node_rank_range(graph, nodes, low, less_end)
  sort_node_rank_range(graph, nodes, greater_start, high)
}

///|
fn sort_nodes_by_rank_via_native_qsort(
  graph : NsGraph,
  nodes : Array[Int],
) -> Bool {
  sort_node_rank_range(graph, nodes, 0, nodes.length())
  true
}
