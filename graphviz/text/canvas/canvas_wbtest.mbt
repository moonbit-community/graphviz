///|
extern "js" fn mock_context() -> Context2D =
  #| () => ({
  #|   font: "application font",
  #|   calls: [],
  #|   save() { this.savedFont = this.font; },
  #|   restore() { this.font = this.savedFont; },
  #|   measureText(text) {
  #|     this.calls.push([this.font, text]);
  #|     return {
  #|       width: 17.125,
  #|       fontBoundingBoxAscent: 12.5, fontBoundingBoxDescent: 3.25,
  #|       actualBoundingBoxLeft: 0.25, actualBoundingBoxRight: 16.75,
  #|       actualBoundingBoxAscent: 10.5, actualBoundingBoxDescent: 2.25,
  #|     };
  #|   }
  #| })

///|
extern "js" fn call_count(context : Context2D) -> Int32 =
  #| ctx => ctx.calls.length

///|
extern "js" fn measured_text(context : Context2D) -> String =
  #| ctx => ctx.calls[0][1]

///|
extern "js" fn measured_font(context : Context2D) -> String =
  #| ctx => ctx.calls[0][0]

///|
extern "js" fn current_font(context : Context2D) -> String =
  #| ctx => ctx.font

///|
test "Canvas measures a full run in CSS pixels, caches it, and restores the context" {
  let raw = mock_context()
  let canvas = Canvas::new(raw)
  let font : @text.Font = { name: "Times-BoldItalic", size_pt: 10.5, }
  let metrics = canvas.measure(font, "AVffi é")
  @test.assert_eq(measured_text(raw), "AVffi é")
  @test.assert_eq(measured_font(raw), "italic bold 14px Times,serif")
  @test.assert_eq(current_font(raw), "application font")
  @test.assert_eq(metrics.width_pt, 12.84375)
  @test.assert_eq(metrics.height_pt, 11.8125)
  @test.assert_eq(metrics.ascent_pt, 9.375)
  @test.assert_eq(
    metrics.ink,
    Some({
      left_pt: -0.1875,
      right_pt: 12.5625,
      ascent_pt: 7.875,
      descent_pt: 1.6875,
    }),
  )
  @test.assert_eq(canvas.measure(font, "AVffi é"), metrics)
  @test.assert_eq(call_count(raw), 1)
  ignore(canvas.measure(font, "different run"))
  @test.assert_eq(call_count(raw), 2)
  canvas.clear_cache()
  @test.assert_eq(canvas.measure(font, "AVffi é"), metrics)
  @test.assert_eq(call_count(raw), 3)
}
