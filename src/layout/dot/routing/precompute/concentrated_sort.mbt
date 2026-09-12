// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn compare_concentrated_route_indices(
  indices : Array[Int],
  priorities : Array[Int],
  left : Int,
  right : Int,
) -> Int {
  priorities[indices[left]].compare(priorities[indices[right]])
}

///|
fn concentrated_route_median(
  indices : Array[Int],
  priorities : Array[Int],
  first : Int,
  second : Int,
  third : Int,
) -> Int {
  let first_second = compare_concentrated_route_indices(
    indices, priorities, first, second,
  )
  let second_third = compare_concentrated_route_indices(
    indices, priorities, second, third,
  )
  let first_third = compare_concentrated_route_indices(
    indices, priorities, first, third,
  )
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
fn swap_concentrated_route_ranges(
  indices : Array[Int],
  first : Int,
  second : Int,
  length : Int,
) -> Unit {
  for offset in 0..<length {
    indices.swap(first + offset, second + offset)
  }
}

///|
fn insertion_sort_concentrated_routes(
  indices : Array[Int],
  priorities : Array[Int],
  low : Int,
  high : Int,
) -> Unit {
  for current in (low + 1)..<high {
    for position = current {
      guard position > low &&
        compare_concentrated_route_indices(
          indices,
          priorities,
          position - 1,
          position,
        ) >
        0 else {
        break
      }
      indices.swap(position - 1, position)
      continue position - 1
    }
  }
}

///|
fn sort_concentrated_route_range(
  indices : Array[Int],
  priorities : Array[Int],
  low : Int,
  high : Int,
) -> Unit {
  let length = high - low
  guard length >= 7 else {
    insertion_sort_concentrated_routes(indices, priorities, low, high)
    return
  }
  let middle = low + length / 2
  let last = high - 1
  let pivot = if length > 40 {
    let offset = length / 8
    let first = concentrated_route_median(
      indices,
      priorities,
      low,
      low + offset,
      low + offset * 2,
    )
    let center = concentrated_route_median(
      indices,
      priorities,
      middle - offset,
      middle,
      middle + offset,
    )
    let end = concentrated_route_median(
      indices,
      priorities,
      last - offset * 2,
      last - offset,
      last,
    )
    concentrated_route_median(indices, priorities, first, center, end)
  } else {
    concentrated_route_median(indices, priorities, low, middle, last)
  }
  indices.swap(low, pivot)
  let pivot_value = priorities[indices[low]]
  let mut equal_left = low + 1
  let mut scan_left = low + 1
  let mut scan_right = high - 1
  let mut equal_right = high - 1
  let mut partition_swapped = false
  while scan_left <= scan_right {
    while scan_left <= scan_right &&
          priorities[indices[scan_left]] <= pivot_value {
      if priorities[indices[scan_left]] == pivot_value {
        indices.swap(equal_left, scan_left)
        equal_left = equal_left + 1
        partition_swapped = true
      }
      scan_left = scan_left + 1
    }
    while scan_left <= scan_right &&
          priorities[indices[scan_right]] >= pivot_value {
      if priorities[indices[scan_right]] == pivot_value {
        indices.swap(scan_right, equal_right)
        equal_right = equal_right - 1
        partition_swapped = true
      }
      scan_right = scan_right - 1
    }
    if scan_left <= scan_right {
      indices.swap(scan_left, scan_right)
      partition_swapped = true
      scan_left = scan_left + 1
      scan_right = scan_right - 1
    }
  }
  let left_equal_count = (equal_left - low).min(scan_left - equal_left)
  swap_concentrated_route_ranges(
    indices,
    low,
    scan_left - left_equal_count,
    left_equal_count,
  )
  let right_equal_count = (equal_right - scan_right).min(high - 1 - equal_right)
  swap_concentrated_route_ranges(
    indices,
    scan_left,
    high - right_equal_count,
    right_equal_count,
  )
  guard partition_swapped else {
    insertion_sort_concentrated_routes(indices, priorities, low, high)
    return
  }
  let less_end = low + scan_left - equal_left
  let greater_start = high - (equal_right - scan_right)
  sort_concentrated_route_range(indices, priorities, low, less_end)
  sort_concentrated_route_range(indices, priorities, greater_start, high)
}

///|
fn sort_concentrated_route_indices(priorities : Array[Int]) -> Array[Int] {
  let indices = priorities.mapi((index, _) => index)
  sort_concentrated_route_range(indices, priorities, 0, indices.length())
  indices
}
