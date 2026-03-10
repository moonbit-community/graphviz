///|
test "route_polyline_to_bezier matches Graphviz simple straight corridor fixture" {
  let polygon : Array[@geom.Point] = [
    point(110.23527602606173, 108.0),
    point(110.23527602606173, 82.0),
    point(110.23527602606173, 82.0),
    point(110.23527602606173, 74.0),
    point(110.23527602606173, 74.0),
    point(110.23527602606173, 26.0),
    point(-32.0, 26.0),
    point(-32.0, 74.0),
    point(-32.0, 74.0),
    point(-32.0, 82.0),
    point(-32.0, 82.0),
    point(-32.0, 108.0),
  ]
  let bezier = route_polyline_to_bezier(
    [point(47.0, 107.0), point(47.0, 27.0)],
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_eq(bezier, [
    point(47.0, 107.0),
    point(47.0, 107.0),
    point(47.0, 27.0),
    point(47.0, 27.0),
  ])
}

///|
test "route_polyline_to_bezier matches Graphviz long straight corridor fixture" {
  let polygon : Array[@geom.Point] = [
    point(1434.35693359375, 483.5),
    point(1434.35693359375, 457.0),
    point(1434.35693359375, 457.0),
    point(1434.35693359375, 447.0),
    point(1434.35693359375, 447.0),
    point(1434.35693359375, 446.0),
    point(1434.35693359375, 446.0),
    point(1434.35693359375, 428.0),
    point(1434.35693359375, 428.0),
    point(1434.35693359375, 409.5),
    point(-240.0, 409.5),
    point(-240.0, 428.0),
    point(-240.0, 428.0),
    point(-240.0, 446.0),
    point(-240.0, 446.0),
    point(-240.0, 447.0),
    point(-240.0, 447.0),
    point(-240.0, 457.0),
    point(511.0, 457.0),
    point(511.0, 483.5),
  ]
  let bezier = route_polyline_to_bezier(
    [point(824.0, 482.5), point(824.0, 410.5)],
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_eq(bezier, [
    point(824.0, 482.5),
    point(824.0, 482.5),
    point(824.0, 410.5),
    point(824.0, 410.5),
  ])
}

///|
test "route_polyline_to_bezier matches Graphviz stepped cluster corridor fit" {
  let shortest : Array[@geom.Point] = [
    point(83.0, 241.0),
    point(99.0, 188.0),
    point(99.0, 152.0),
    point(83.0, 27.0),
  ]
  let polygon : Array[@geom.Point] = [
    point(122.0, 242.0),
    point(122.0, 224.0),
    point(252.0, 224.0),
    point(252.0, 188.0),
    point(122.0, 188.0),
    point(122.0, 152.0),
    point(252.0, 152.0),
    point(252.0, 116.0),
    point(122.0, 116.0),
    point(122.0, 80.0),
    point(252.0, 80.0),
    point(252.0, 44.0),
    point(122.0, 44.0),
    point(122.0, 26.0),
    point(-80.0, 26.0),
    point(-80.0, 44.0),
    point(-80.0, 44.0),
    point(-80.0, 80.0),
    point(86.0, 80.0),
    point(86.0, 116.0),
    point(-80.0, 116.0),
    point(-80.0, 152.0),
    point(99.0, 152.0),
    point(99.0, 188.0),
    point(-80.0, 188.0),
    point(-80.0, 224.0),
    point(-80.0, 224.0),
    point(-80.0, 242.0),
  ]
  let bezier = route_polyline_to_bezier(
    shortest,
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_points_close(
    bezier,
    [
      point(83.0, 241.0),
      point(83.0, 241.0),
      point(95.40589554843454, 212.34162098046613),
      point(99.0, 188.0),
      point(109.50353269078028, 116.86322165635785),
      point(83.0, 27.0),
      point(83.0, 27.0),
    ],
    eps=0.0001,
  )
}

///|
test "route_polyline_to_bezier matches Graphviz routed multi-bend corridor fit" {
  let shortest : Array[@geom.Point] = [
    point(586.0, 818.5),
    point(542.0, 774.0),
    point(542.0, 699.0),
    point(598.0, 591.5),
  ]
  let polygon : Array[@geom.Point] = [
    point(1434.35693359375, 819.5),
    point(1434.35693359375, 801.0),
    point(1434.35693359375, 801.0),
    point(1434.35693359375, 783.0),
    point(582.0, 783.0),
    point(582.0, 782.0),
    point(1434.35693359375, 782.0),
    point(1434.35693359375, 774.0),
    point(542.0, 774.0),
    point(542.0, 699.0),
    point(1434.35693359375, 699.0),
    point(1434.35693359375, 689.0),
    point(585.0, 689.0),
    point(585.0, 675.0),
    point(1434.35693359375, 675.0),
    point(1434.35693359375, 667.0),
    point(746.0, 667.0),
    point(746.0, 590.5),
    point(487.0, 590.5),
    point(487.0, 667.0),
    point(-240.0, 667.0),
    point(-240.0, 675.0),
    point(164.0, 675.0),
    point(164.0, 689.0),
    point(-240.0, 689.0),
    point(-240.0, 699.0),
    point(246.0, 699.0),
    point(246.0, 774.0),
    point(-240.0, 774.0),
    point(-240.0, 782.0),
    point(-240.0, 782.0),
    point(-240.0, 783.0),
    point(-240.0, 783.0),
    point(-240.0, 801.0),
    point(-240.0, 801.0),
    point(-240.0, 819.5),
  ]
  let bezier = route_polyline_to_bezier(
    shortest,
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_points_close(
    bezier,
    [
      point(586.0, 818.5),
      point(586.0, 818.5),
      point(552.5710635809937, 799.7261124478645),
      point(542.0, 774.0),
      point(529.3309297474916, 743.1681046633828),
      point(534.0725117181763, 731.3769368633393),
      point(542.0, 699.0),
      point(554.8120463206794, 646.6738659121187),
      point(598.0, 591.5),
      point(598.0, 591.5),
    ],
    eps=0.0001,
  )
}

///|
test "route_polyline_to_bezier matches Graphviz states corridor fit" {
  let shortest : Array[@geom.Point] = [
    point(3.0, 456.62754832967426),
    point(6.0, 271.7068863473189),
    point(33.0, 28.0),
  ]
  let polygon : Array[@geom.Point] = [
    point(156.5, 457.62754832967426),
    point(156.5, 421.6303781210938),
    point(156.5, 421.6303781210938),
    point(156.5, 403.6303781210938),
    point(10.0, 403.6303781210938),
    point(10.0, 358.6303781210938),
    point(156.5, 358.6303781210938),
    point(156.5, 340.6303781210938),
    point(6.0, 340.6303781210938),
    point(6.0, 271.7068863473189),
    point(156.5, 271.7068863473189),
    point(156.5, 253.7068863473189),
    point(12.5, 253.7068863473189),
    point(12.5, 221.4568863473189),
    point(156.5, 221.4568863473189),
    point(156.5, 203.4568863473189),
    point(29.0, 203.4568863473189),
    point(29.0, 122.24999999999999),
    point(156.5, 122.24999999999999),
    point(156.5, 104.25),
    point(29.0, 104.25),
    point(29.0, 72.0),
    point(156.5, 72.0),
    point(156.5, 54.0),
    point(156.5, 54.0),
    point(156.5, 27.0),
    point(-127.0, 27.0),
    point(-127.0, 54.0),
    point(-127.0, 54.0),
    point(-127.0, 72.0),
    point(-127.0, 72.0),
    point(-127.0, 104.25),
    point(-127.0, 104.25),
    point(-127.0, 122.24999999999999),
    point(-127.0, 122.24999999999999),
    point(-127.0, 203.4568863473189),
    point(-127.0, 203.4568863473189),
    point(-127.0, 221.4568863473189),
    point(-127.0, 221.4568863473189),
    point(-127.0, 253.7068863473189),
    point(-127.0, 253.7068863473189),
    point(-127.0, 271.7068863473189),
    point(-127.0, 271.7068863473189),
    point(-127.0, 340.6303781210938),
    point(-127.0, 340.6303781210938),
    point(-127.0, 358.6303781210938),
    point(-127.0, 358.6303781210938),
    point(-127.0, 403.6303781210938),
    point(-127.0, 403.6303781210938),
    point(-127.0, 421.6303781210938),
    point(-127.0, 421.6303781210938),
    point(-127.0, 457.62754832967426),
  ]
  let bezier = route_polyline_to_bezier(
    shortest,
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_points_close(
    bezier,
    [
      point(3.0, 456.62754832967426),
      point(3.0, 456.62754832967426),
      point(0.8019706210878894, 353.74014062396253),
      point(6.0, 271.7068863473189),
      point(12.891488312610491, 162.94812954105947),
      point(33.0, 28.0),
      point(33.0, 28.0),
    ],
    eps=0.0001,
  )
}

///|
test "route_polyline_to_bezier reproduces the barrier-aware bend fit from Graphviz fixtures" {
  let shortest : Array[@geom.Point] = [
    point(780.0, 178.5),
    point(770.1103515625, 143.0),
    point(770.1103515625, 129.0),
    point(783.0, 43.5),
  ]
  let polygon : Array[@geom.Point] = [
    point(833.0, 179.5),
    point(833.0, 153.0),
    point(1434.35693359375, 153.0),
    point(1434.35693359375, 143.0),
    point(770.1103515625, 143.0),
    point(770.1103515625, 129.0),
    point(1434.35693359375, 129.0),
    point(1434.35693359375, 121.0),
    point(819.0, 121.0),
    point(819.0, 42.5),
    point(-240.0, 42.5),
    point(-240.0, 121.0),
    point(-240.0, 121.0),
    point(-240.0, 129.0),
    point(-240.0, 129.0),
    point(-240.0, 143.0),
    point(-240.0, 143.0),
    point(-240.0, 153.0),
    point(-240.0, 153.0),
    point(-240.0, 179.5),
  ]
  let route_barriers = bezier_test_polygon_edges(polygon)

  let bezier = route_polyline_to_bezier(
    shortest,
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers~,
  )

  assert_points_close(
    bezier,
    [
      point(780.0, 178.5),
      point(780.0, 178.5),
      point(772.3284867912414, 159.22768260618975),
      point(770.1103515625, 143.0),
      point(764.0713344784783, 98.81908117095833),
      point(783.0, 43.5),
      point(783.0, 43.5),
    ],
    eps=0.0001,
  )
}

///|
test "route_polyline_to_bezier matches Graphviz single-bend corridor fit" {
  let shortest : Array[@geom.Point] = [
    point(824.0, 265.5),
    point(788.896484375, 230.0),
    point(780.0, 180.5),
  ]
  let polygon : Array[@geom.Point] = [
    point(1434.35693359375, 266.5),
    point(1434.35693359375, 248.0),
    point(1434.35693359375, 248.0),
    point(1434.35693359375, 230.0),
    point(788.896484375, 230.0),
    point(788.896484375, 216.0),
    point(1434.35693359375, 216.0),
    point(1434.35693359375, 198.0),
    point(833.0, 198.0),
    point(833.0, 179.5),
    point(-240.0, 179.5),
    point(-240.0, 198.0),
    point(-240.0, 198.0),
    point(-240.0, 216.0),
    point(-240.0, 216.0),
    point(-240.0, 230.0),
    point(-240.0, 230.0),
    point(-240.0, 248.0),
    point(-240.0, 248.0),
    point(-240.0, 266.5),
  ]
  let bezier = route_polyline_to_bezier(
    shortest,
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_points_close(
    bezier,
    [
      point(824.0, 265.5),
      point(824.0, 265.5),
      point(799.11933711946494, 249.69366156435439),
      point(788.896484375, 230.0),
      point(778.59825726675103, 210.16113462139765),
      point(780.0, 180.5),
      point(780.0, 180.5),
    ],
    eps=0.0001,
  )
}

///|
test "route_polyline_to_bezier matches Graphviz multi-bend corridor fit" {
  let shortest : Array[@geom.Point] = [
    point(586.0, 724.5),
    point(631.0, 699.0),
    point(746.0, 667.0),
    point(823.0, 591.5),
  ]
  let polygon : Array[@geom.Point] = [
    point(631.0, 725.5),
    point(631.0, 699.0),
    point(1434.35693359375, 699.0),
    point(1434.35693359375, 689.0),
    point(832.5771484375, 689.0),
    point(832.5771484375, 675.0),
    point(1434.35693359375, 675.0),
    point(1434.35693359375, 667.0),
    point(908.0, 667.0),
    point(908.0, 590.5),
    point(746.0, 590.5),
    point(746.0, 667.0),
    point(-240.0, 667.0),
    point(-240.0, 675.0),
    point(595.0, 675.0),
    point(595.0, 689.0),
    point(-240.0, 689.0),
    point(-240.0, 699.0),
    point(537.0, 699.0),
    point(537.0, 725.5),
  ]
  let bezier = route_polyline_to_bezier(
    shortest,
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_points_close(
    bezier,
    [
      point(586.0, 724.5),
      point(586.0, 724.5),
      point(609.7687386985847, 707.8135116721695),
      point(631.0, 699.0),
      point(679.9988404072257, 678.659623339332),
      point(700.0516020945997, 693.5209730944704),
      point(746.0, 667.0),
      point(787.5101242690987, 643.0407557374377),
      point(823.0, 591.5),
      point(823.0, 591.5),
    ],
    eps=0.0001,
  )
}
