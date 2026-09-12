// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
#borrow(indices, priorities)
extern "C" fn concentrated_qsort(
  indices : FixedArray[Int],
  priorities : FixedArray[Int],
  length : Int,
) -> Unit = "gv_concentrated_route_sort"

///|
fn sort_concentrated_route_indices(priorities : Array[Int]) -> Array[Int] {
  let indices = priorities.mapi((index, _) => index)
  let fixed = FixedArray::from_array(indices)
  concentrated_qsort(
    fixed,
    FixedArray::from_array(priorities),
    indices.length(),
  )
  for index in 0..<indices.length() {
    indices[index] = fixed[index]
  }
  indices
}
