# pngquant Palette Compression Plan

## Goal

Incorporate pngquant-style palette PNG compression into OIMG, backed by `slimg`, and give users a way to assess whether a selected image is a good candidate for palette-based compression.

## Library Choice

The practical library target is `libimagequant`, exposed to Rust through the `imagequant` crate. It is the library behind pngquant and converts RGBA pixels into an 8-bit indexed palette with alpha support. It does not encode or decode PNG files by itself, so `slimg` would still need to provide PNG encoding and should continue running `oxipng` after palette encoding.

Important licensing caveat: `libimagequant` / `imagequant` is GPL-3.0-or-later unless used under a commercial license. Confirm that this is compatible with OIMG/slimg distribution before linking it directly.

## Proposed Architecture

1. Add palette PNG support in `slimg`.
   - Decode input to RGBA as today.
   - Run `imagequant` to generate a palette and indexed pixel buffer.
   - Encode an indexed PNG with `PLTE` and alpha information.
   - Run `oxipng` afterward, as the current PNG pipeline already does.

2. Expose the feature as a first-class PNG option.
   - Suggested setting: `png_quantization: off | auto | on`.
   - `off`: current lossless PNG pipeline.
   - `on`: force palette quantization for PNG output.
   - `auto`: use suitability analysis and/or candidate size comparison.

3. Surface the setting in OIMG.
   - Keep UI text short and product-facing, for example `Palette` with `Auto`, `On`, `Off`.
   - Avoid explaining implementation details in the UI.

4. Add image suitability analysis.
   - Compute fast color statistics during inspection or analysis.
   - Use those stats to recommend palette compression when it is likely to reduce size without unacceptable visual loss.

## Unique Color Count

Counting exact unique RGBA colors is useful and cheap enough for normal images. It can be implemented by hashing each pixel as a packed `u32`.

Recommended interpretation:

- `unique_colors <= 256`: strong candidate. Palette PNG can represent the image losslessly, apart from encoder metadata differences.
- `unique_colors` modestly above 256: possible candidate. Quantization may work well for icons, diagrams, UI screenshots, and flat artwork.
- Very high unique color count: weak signal. Photos, gradients, noise, and antialiasing can produce many unique colors even when a palette might still compress acceptably, or fail visually.

So unique color count is a good first-pass signal, but it should not be the only recommendation rule.

## Better Suitability Signals

Use a combined score rather than a single threshold:

- `unique_color_count`: detects exact-palette or near-palette assets.
- `top_256_color_coverage`: percentage of pixels represented by the 256 most frequent colors. High coverage suggests palette compression is likely suitable.
- `alpha_profile`: palette PNG can support alpha, but complex soft transparency may need quantization quality checks.
- `edge/flatness indicators`: images with large flat regions and sharp edges are usually better candidates than natural photos.
- `sampled quantization trial`: run `imagequant` on a downscaled or sampled image and use its reported quantization/remapping quality.
- `actual candidate encode`: encode both normal PNG and palette PNG, then recommend palette only if the palette result is smaller by a meaningful margin.
- Existing OIMG quality metrics: for user-facing analysis, compare the remapped palette output with Pixel Match, MS-SSIM, and SSIMULACRA 2.

The strongest scheme is:

1. Fast classify with color statistics.
2. For borderline images, run a cheap quantization trial.
3. For final decisions in `auto`, compare actual encoded output size and reject palette output when quality or savings is insufficient.

## Suggested Auto Policy

An initial conservative policy could be:

- Use palette losslessly when `unique_colors <= 256` and output is smaller after `oxipng`.
- For `unique_colors > 256`, try palette quantization only when either:
  - `top_256_color_coverage` is high, or
  - `imagequant` reports acceptable remapping quality on a sample.
- Keep the palette result only when:
  - output is smaller than the normal PNG by a minimum threshold, and
  - sampled or full-image quality metrics stay above the configured acceptance threshold.

## Implementation Notes

- `slimg` should own the encoding behavior so OIMG can remain a UI/planning layer.
- OIMG request types can carry a PNG quantization mode alongside quality and effort.
- Analysis results can include palette suitability fields, such as unique colors, dominant color coverage, and a recommendation enum.
- The recommendation should be advisory when shown to the user; `auto` should still verify by candidate encode before writing.

## References

- pngquant: https://pngquant.org/
- libimagequant: https://pngquant.org/lib/
- imagequant Rust docs: https://docs.rs/imagequant/latest/imagequant/
