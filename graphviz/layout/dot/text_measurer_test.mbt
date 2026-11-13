///|
struct RecordingMeasurer {
  calls : Array[(@text.Font, String)]
}

///|
impl @text.Measurer for RecordingMeasurer with fn measure(self, font, text) {
  self.calls.push((font, text))
  {
    width_pt: 37.125,
    height_pt: 15.625,
    ascent_pt: 12.25,
    descent_pt: 3.375,
    ink: None,
  }
}

///|
test "injected measurements retain fractions without replacing the layout baseline by ascent" {
  let recorder = RecordingMeasurer::{ calls: [], }
  let context = @text_layout.Context::new(recorder)
  @test.assert_eq(
    @label_metrics.label_text_metrics(
      "AVffi",
      "Web Font",
      14.0,
      text_context=context,
    ),
    (37.125, 15.625, 0.0, 1.4000000000000001),
  )
  @test.assert_eq(recorder.calls.length(), 1)
  @test.assert_eq(recorder.calls[0].1, "AVffi")
}

///|
test "one bound service is used by all labels and both renderers" {
  let recorder = RecordingMeasurer::{ calls: [], }
  let context = @text_layout.Context::new(recorder)
  let graph = @dot_parser.parse_dot(
    (
      #|digraph {
      #|  label="graph run";
      #|  subgraph cluster_c {
      #|    label="cluster run";
      #|    a [shape=record, label="{record run|second field}"];
      #|    b [label=<<TABLE><TR><TD><FONT FACE="Web Font" POINT-SIZE="11.5">HTML run</FONT></TD></TR></TABLE>>, xlabel="node external"];
      #|  }
      #|  c [label="first run\nsecond run"];
      #|  a -> b [label="edge run", headlabel="head run", taillabel="tail run", xlabel="edge external"];
      #|}
    ),
  )
  let layout = @dot.layout_dot(graph, text_context=context)
  for
    text in [
      "graph run", "cluster run", "record run", "second field", "HTML run", "node external",
      "first run", "second run", "edge run", "head run", "tail run", "edge external",
    ] {
    @test.assert_eq(recorder.calls.any(call => call.1 == text), true)
  }
  @test.assert_eq(
    recorder.calls.any(call => call.1 == "first run\\nsecond run"),
    false,
  )
  @test.assert_eq(
    recorder.calls.any(call => {
      call.1 == "HTML run" &&
      call.0.name == "Web Font" &&
      call.0.size_pt == 11.5
    }),
    true,
  )
  let after_layout = recorder.calls.length()
  ignore(@svg.render_svg(layout))
  @test.assert_eq(recorder.calls.length() > after_layout, true)
  let after_svg = recorder.calls.length()
  ignore(@xdot.render_xdot(layout))
  @test.assert_eq(recorder.calls.length() > after_svg, true)
}
