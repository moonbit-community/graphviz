// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn assert_scale_factors(
  actual : RatioFillScaleFactors?,
  expected_sx : Double,
  expected_sy : Double,
) -> Unit raise {
  match actual {
    Some(value) => {
      assert_eq(value.sx, expected_sx)
      assert_eq(value.sy, expected_sy)
    }
    None => fail("expected scale factors")
  }
}

///|
test "ratio_fill_scale_factors handles direct, flipped, clamped, and invalid cases" {
  let direct = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  direct.set_attr("ratio", "fill")
  direct.set_attr("size", "2,1")
  let bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 72.0, ury: 36.0 }
  assert_scale_factors(
    ratio_fill_scale_factors(direct, bbox, RankDir::TB),
    2.0,
    2.0,
  )
  assert_scale_factors(
    ratio_fill_scale_factors(direct, bbox, RankDir::LR),
    1.0,
    4.0,
  )

  let clamped = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  clamped.set_attr("ratio", "fill")
  clamped.set_attr("size", "1,2")
  let wide_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 144.0, ury: 36.0 }
  assert_scale_factors(
    ratio_fill_scale_factors(clamped, wide_bbox, RankDir::TB),
    1.0,
    8.0,
  )

  let missing_ratio = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    strict=false,
  )
  missing_ratio.set_attr("size", "2,1")
  let invalid_size = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    strict=false,
  )
  invalid_size.set_attr("ratio", "fill")
  invalid_size.set_attr("size", "0,1")
  let non_fill = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  non_fill.set_attr("ratio", "compress")
  non_fill.set_attr("size", "2,1")
  let flat_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 0.0, ury: 10.0 }

  assert_true(
    ratio_fill_scale_factors(missing_ratio, bbox, RankDir::TB) is None,
  )
  assert_true(ratio_fill_scale_factors(invalid_size, bbox, RankDir::TB) is None)
  assert_true(ratio_fill_scale_factors(non_fill, bbox, RankDir::TB) is None)
  assert_true(ratio_fill_scale_factors(direct, flat_bbox, RankDir::TB) is None)
}

///|
test "ratio_fill_scale_factors normalizes ratio text before RL flip handling" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("ratio", " Fill ")
  graph.set_attr("size", "2,1")
  let bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 72.0, ury: 36.0 }

  assert_scale_factors(
    ratio_fill_scale_factors(graph, bbox, RankDir::RL),
    1.0,
    4.0,
  )
}
