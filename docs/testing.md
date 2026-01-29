# Testing Notes

## Skipped integration tests

These tests are skipped with `#skip` while base-function parity work is in progress. To re-enable, remove the `#skip` line immediately above the test.

- `src/layout/dot/snapshot_test.mbt`: test "dot layout tier2 snapshots"
- `src/layout/dot/complex_test.mbt`: all tests in this file
- `src/layout/dot/splines_test.mbt`: tests "layout_dot accepts non-spline modes" and "layout_dot ortho adds more control points than polyline"
- `src/render/xdot/snapshot_test.mbt`: test "xdot snapshot parity"
- `src/render/xdot/xdot_wbtest.mbt`: test "render_xdot matches graphviz edge label positions"
- `src/render/svg/svg_test.mbt`: tests "svg spot-check outputs" and "render_svg cluster boxes match graphviz"
- `src/render/svg/svg_wbtest.mbt`: all tests in this file
