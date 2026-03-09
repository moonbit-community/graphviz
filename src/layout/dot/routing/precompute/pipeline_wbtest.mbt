///|
test "select_path_groups prefers x groups then vnode groups then ordered groups" {
  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["x0"]
  let ordered_groups_with_vnodes : Map[Int, Array[String]] = Map::new()
  ordered_groups_with_vnodes[1] = ["v1"]
  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[2] = ["o2"]

  assert_eq(
    select_path_groups(x_groups, ordered_groups_with_vnodes, ordered_groups),
    x_groups,
  )
  assert_eq(
    select_path_groups(Map::new(), ordered_groups_with_vnodes, ordered_groups),
    ordered_groups_with_vnodes,
  )
  assert_eq(
    select_path_groups(Map::new(), Map::new(), ordered_groups),
    ordered_groups,
  )
}

///|
test "build_label_edge_counts counts only labeled edges per tail" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let ab1 = graph.edge(a, b)
  let ab2 = graph.edge(a, b, name="second")
  let cb = graph.edge(c, b)
  ab1.set_attr("fixture_mid_label", "1")
  cb.set_attr("fixture_mid_label", "1")

  let counts = build_label_edge_counts([ab1, ab2, cb], edge => {
    edge.get_attr("fixture_mid_label") is Some("1")
  })

  assert_eq(counts.get("a"), Some(1))
  assert_eq(counts.get("c"), Some(1))
  assert_eq(counts.length(), 2)
}

///|
test "complex_tuning_enabled follows DOT_COMPLEX_TUNING env flag" {
  let env_key = "DOT_COMPLEX_TUNING"
  let original = @sys.get_env_var(env_key)

  @sys.unset_env_var(env_key)
  let absent = complex_tuning_enabled()

  @sys.set_env_var(env_key, "1")
  let enabled = complex_tuning_enabled()

  @sys.set_env_var(env_key, "0")
  let disabled = complex_tuning_enabled()

  match original {
    Some(value) => @sys.set_env_var(env_key, value)
    None => @sys.unset_env_var(env_key)
  }

  assert_false(absent)
  assert_true(enabled)
  assert_false(disabled)
}

///|
test "resolve_routing_port_padding short-circuits unless port padding is needed" {
  let calls = Ref::new(0)
  let compute_padding = () => {
    calls.val = calls.val + 1
    (3.0, 5.0)
  }

  let clustered = resolve_routing_port_padding(true, true, compute_padding)
  let no_ports = resolve_routing_port_padding(false, false, compute_padding)
  let active = resolve_routing_port_padding(false, true, compute_padding)

  assert_eq(clustered, (0.0, 0.0))
  assert_eq(no_ports, (0.0, 0.0))
  assert_eq(active, (3.0, 5.0))
  assert_eq(calls.val, 1)
}
