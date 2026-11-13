// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// A CanvasRenderingContext2D or OffscreenCanvasRenderingContext2D supplied by
/// the application. No DOM, canvas element or font loader is created here.
#external
pub type Context2D

///|
#external
priv type RawMetrics

///|
pub struct Canvas {
  context : Context2D
  cache : Map[(String, Double, String), @text.Metrics]
}

///|
pub fn Canvas::new(context : Context2D) -> Canvas {
  { context, cache: Map([]), }
}

///|
/// After font loading changes, clear this cache and request a fresh layout.
/// Existing geometry is not retroactively changed by clearing measurements.
pub fn Canvas::clear_cache(self : Canvas) -> Unit {
  self.cache.clear()
}

///|
extern "js" fn measure_run(
  context : Context2D,
  font : String,
  stretch : String,
  text : String,
) -> RawMetrics =
  #| (ctx, font, stretch, text) => {
  #|   ctx.save();
  #|   try {
  #|     ctx.font = font;
  #|     ctx.fontStretch = stretch;
  #|     ctx.fontKerning = "auto";
  #|     ctx.fontVariantCaps = "normal";
  #|     ctx.letterSpacing = "0px";
  #|     ctx.wordSpacing = "0px";
  #|     ctx.textRendering = "auto";
  #|     ctx.textAlign = "left";
  #|     ctx.textBaseline = "alphabetic";
  #|     ctx.direction = "ltr";
  #|     const metrics = ctx.measureText(text);
  #|     for (const key of ["width", "fontBoundingBoxAscent", "fontBoundingBoxDescent",
  #|                        "actualBoundingBoxLeft", "actualBoundingBoxRight",
  #|                        "actualBoundingBoxAscent", "actualBoundingBoxDescent"]) {
  #|       if (!Number.isFinite(metrics[key])) {
  #|         throw new TypeError("Canvas TextMetrics requires " + key);
  #|       }
  #|     }
  #|     return metrics;
  #|   } finally {
  #|     ctx.restore();
  #|   }
  #| }

///|
extern "js" fn metric(metrics : RawMetrics, field : Int32) -> Double =
  #| (m, i) => m[["width", "fontBoundingBoxAscent", "fontBoundingBoxDescent",
  #|              "actualBoundingBoxLeft", "actualBoundingBoxRight",
  #|              "actualBoundingBoxAscent", "actualBoundingBoxDescent"][i]] * (72 / 96)

///|
pub extend Canvas with @text.Measurer::{measure}

///|
pub impl @text.Measurer for Canvas with fn measure(self, font, text) {
  let key = (font.name, font.size_pt, text)
  if self.cache.get(key) is Some(metrics) {
    return metrics
  }
  let resolved = @text.resolve_font(font.name)
  let weight = match resolved.weight {
    Some("demi") => "600"
    Some("light") => "300"
    Some("medium") => "500"
    Some("book") | Some("roman") | None => "normal"
    Some(weight) => weight
  }
  let style = resolved.style.unwrap_or("normal")
  let size_px = font.size_pt * 96.0 / 72.0
  let css_font = "\{style} \{weight} \{size_px}px \{resolved.family}"
  let raw = measure_run(
    self.context,
    css_font,
    resolved.stretch.unwrap_or("normal"),
    text,
  )
  let ascent_pt = metric(raw, 1)
  let descent_pt = metric(raw, 2)
  let metrics : @text.Metrics = {
    width_pt: metric(raw, 0),
    height_pt: ascent_pt + descent_pt,
    ascent_pt,
    descent_pt,
    ink: Some({
      left_pt: -metric(raw, 3),
      right_pt: metric(raw, 4),
      ascent_pt: metric(raw, 5),
      descent_pt: metric(raw, 6),
    }),
  }
  self.cache[key] = metrics
  metrics
}
