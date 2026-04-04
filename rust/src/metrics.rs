use dify::diff::get_results;
use fast_ssim2::{LinearRgbImage, compute_ssimulacra2, srgb_u8_to_linear};
use image::RgbaImage;
use slimg_core::codec::{EncodeOptions, get_codec};
use slimg_core::{Format, ImageData, decode};
use tjdistler_iqa::{ImageQualityAssessment, MsSsim};

use crate::types::{EncodedImageResult, PreviewQualityMetricsRequest};

const DIFY_DEFAULT_THRESHOLD: f32 = 35215.0 * 0.05 * 0.05;

pub(crate) fn compute_ms_ssim(reference: &ImageData, distorted: &ImageData) -> Option<f64> {
    if reference.width != distorted.width || reference.height != distorted.height {
        return None;
    }

    let width = usize::try_from(reference.width).ok()?;
    let height = usize::try_from(reference.height).ok()?;
    let reference_luma = rgba_to_luma(reference);
    let distorted_luma = rgba_to_luma(distorted);
    let scales = supported_ms_ssim_scales(width, height)?;
    let metric = MsSsim::builder().scales(scales).build();

    metric
        .assess(&reference_luma, &distorted_luma, width, height)
        .ok()
        .map(|result| result.value)
        .filter(|value| value.is_finite())
}

pub(crate) fn compute_ms_ssim_from_bytes(
    reference_bytes: &[u8],
    distorted_bytes: &[u8],
) -> Option<f64> {
    let (reference, _) = decode(reference_bytes).ok()?;
    let (distorted, _) = decode(distorted_bytes).ok()?;
    compute_ms_ssim(&reference, &distorted)
}

pub(crate) fn compute_ssimulacra2_score(
    reference: &ImageData,
    distorted: &ImageData,
) -> Option<f64> {
    if reference.width != distorted.width || reference.height != distorted.height {
        return None;
    }

    let width = usize::try_from(reference.width).ok()?;
    let height = usize::try_from(reference.height).ok()?;
    let reference_rgb = rgba_to_linear_rgb(reference, width, height);
    let distorted_rgb = rgba_to_linear_rgb(distorted, width, height);

    compute_ssimulacra2(reference_rgb, distorted_rgb)
        .ok()
        .filter(|value| value.is_finite())
}

pub(crate) fn compute_ssimulacra2_from_bytes(
    reference_bytes: &[u8],
    distorted_bytes: &[u8],
) -> Option<f64> {
    let (reference, _) = decode(reference_bytes).ok()?;
    let (distorted, _) = decode(distorted_bytes).ok()?;
    compute_ssimulacra2_score(&reference, &distorted)
}

pub(crate) fn compute_pixel_match_percentage(
    reference: &ImageData,
    distorted: &ImageData,
) -> Option<f64> {
    if reference.width != distorted.width || reference.height != distorted.height {
        return None;
    }

    let reference_image = rgba_image(reference)?;
    let distorted_image = rgba_image(distorted)?;
    let (width, height) = reference_image.dimensions();
    let total_pixels = f64::from(width) * f64::from(height);
    if total_pixels <= 0.0 {
        return None;
    }

    let diff_pixels = get_results(
        reference_image,
        distorted_image,
        DIFY_DEFAULT_THRESHOLD,
        true,
        Some(0.0),
        &None,
        &None,
    )
    .map(|(diffs, _)| diffs.max(0) as f64)?;

    Some(((total_pixels - diff_pixels) / total_pixels) * 100.0)
        .filter(|value| value.is_finite())
}

pub(crate) fn compute_pixel_match_percentage_from_bytes(
    reference_bytes: &[u8],
    distorted_bytes: &[u8],
) -> Option<f64> {
    let (reference, _) = decode(reference_bytes).ok()?;
    let (distorted, _) = decode(distorted_bytes).ok()?;
    compute_pixel_match_percentage(&reference, &distorted)
}

pub(crate) fn compute_difference_image(
    reference: &ImageData,
    distorted: &ImageData,
) -> Option<EncodedImageResult> {
    let diff = compute_difference_image_data(reference, distorted)?;
    let codec = get_codec(Format::Png);
    let encoded = codec
        .encode(
            &diff,
            &EncodeOptions {
                quality: 100,
                threads: None,
            },
        )
        .ok()?;
    let size_bytes = encoded.len() as u64;

    Some(EncodedImageResult {
        encoded_bytes: encoded,
        format: Format::Png.extension().to_string(),
        width: diff.width,
        height: diff.height,
        size_bytes,
    })
}

pub(crate) fn compute_difference_image_from_bytes(
    reference_bytes: &[u8],
    distorted_bytes: &[u8],
) -> Option<EncodedImageResult> {
    let (reference, _) = decode(reference_bytes).ok()?;
    let (distorted, _) = decode(distorted_bytes).ok()?;
    compute_difference_image(&reference, &distorted)
}

pub(crate) fn compute_preview_pixel_match_percentage(
    request: PreviewQualityMetricsRequest,
) -> crate::error::Result<Option<f64>> {
    let original_bytes = std::fs::read(&request.input_path).ok();
    Ok(original_bytes.as_ref().and_then(|reference_bytes| {
        compute_pixel_match_percentage_from_bytes(
            reference_bytes,
            &request.preview_encoded_bytes,
        )
    }))
}

pub(crate) fn compute_preview_ms_ssim(
    request: PreviewQualityMetricsRequest,
) -> crate::error::Result<Option<f64>> {
    let original_bytes = std::fs::read(&request.input_path).ok();
    Ok(original_bytes.as_ref().and_then(|reference_bytes| {
        compute_ms_ssim_from_bytes(reference_bytes, &request.preview_encoded_bytes)
    }))
}

pub(crate) fn compute_preview_ssimulacra2(
    request: PreviewQualityMetricsRequest,
) -> crate::error::Result<Option<f64>> {
    let original_bytes = std::fs::read(&request.input_path).ok();
    Ok(original_bytes.as_ref().and_then(|reference_bytes| {
        compute_ssimulacra2_from_bytes(reference_bytes, &request.preview_encoded_bytes)
    }))
}

pub(crate) fn compute_preview_difference_image(
    request: PreviewQualityMetricsRequest,
) -> crate::error::Result<Option<EncodedImageResult>> {
    let original_bytes = std::fs::read(&request.input_path).ok();
    Ok(original_bytes.as_ref().and_then(|reference_bytes| {
        compute_difference_image_from_bytes(reference_bytes, &request.preview_encoded_bytes)
    }))
}

fn rgba_to_luma(image: &ImageData) -> Vec<u8> {
    image
        .data
        .chunks_exact(4)
        .map(|pixel| {
            let [r, g, b, a]: [u8; 4] = pixel.try_into().expect("pixel chunk should be RGBA");
            // Composite transparent pixels onto white so the grayscale value tracks
            // the effective visible color rather than raw channel bytes.
            let alpha = u32::from(a);
            let inv_alpha = 255 - alpha;
            let r = (u32::from(r) * alpha + 255 * inv_alpha) / 255;
            let g = (u32::from(g) * alpha + 255 * inv_alpha) / 255;
            let b = (u32::from(b) * alpha + 255 * inv_alpha) / 255;
            ((77 * r + 150 * g + 29 * b + 128) >> 8) as u8
        })
        .collect()
}

fn rgba_to_linear_rgb(image: &ImageData, width: usize, height: usize) -> LinearRgbImage {
    let data = image
        .data
        .chunks_exact(4)
        .map(|pixel| {
            let [r, g, b, a]: [u8; 4] = pixel.try_into().expect("pixel chunk should be RGBA");
            let [r, g, b] = composite_onto_white(r, g, b, a);
            [
                srgb_u8_to_linear(r),
                srgb_u8_to_linear(g),
                srgb_u8_to_linear(b),
            ]
        })
        .collect();
    LinearRgbImage::new(data, width, height)
}

fn rgba_image(image: &ImageData) -> Option<RgbaImage> {
    RgbaImage::from_raw(image.width, image.height, image.data.clone())
}

fn composite_onto_white(r: u8, g: u8, b: u8, a: u8) -> [u8; 3] {
    let alpha = u32::from(a);
    let inv_alpha = 255 - alpha;
    [
        ((u32::from(r) * alpha + 255 * inv_alpha) / 255) as u8,
        ((u32::from(g) * alpha + 255 * inv_alpha) / 255) as u8,
        ((u32::from(b) * alpha + 255 * inv_alpha) / 255) as u8,
    ]
}

fn compute_difference_image_data(reference: &ImageData, distorted: &ImageData) -> Option<ImageData> {
    if reference.width != distorted.width || reference.height != distorted.height {
        return None;
    }

    let data = reference
        .data
        .chunks_exact(4)
        .zip(distorted.data.chunks_exact(4))
        .flat_map(|(reference_pixel, distorted_pixel)| {
            let [reference_r, reference_g, reference_b, reference_a]: [u8; 4] =
                reference_pixel.try_into().expect("pixel chunk should be RGBA");
            let [distorted_r, distorted_g, distorted_b, distorted_a]: [u8; 4] =
                distorted_pixel.try_into().expect("pixel chunk should be RGBA");
            let reference_rgb = premultiply_rgb(reference_r, reference_g, reference_b, reference_a);
            let distorted_rgb = premultiply_rgb(distorted_r, distorted_g, distorted_b, distorted_a);
            [
                distorted_rgb[0].abs_diff(reference_rgb[0]),
                distorted_rgb[1].abs_diff(reference_rgb[1]),
                distorted_rgb[2].abs_diff(reference_rgb[2]),
                255,
            ]
        })
        .collect();

    Some(ImageData::new(reference.width, reference.height, data))
}

fn premultiply_rgb(r: u8, g: u8, b: u8, a: u8) -> [u8; 3] {
    [
        premultiply_channel(r, a),
        premultiply_channel(g, a),
        premultiply_channel(b, a),
    ]
}

fn premultiply_channel(value: u8, alpha: u8) -> u8 {
    ((u32::from(value) * u32::from(alpha) + 127) / 255) as u8
}

fn supported_ms_ssim_scales(width: usize, height: usize) -> Option<usize> {
    const GAUSSIAN_WINDOW_SIZE: usize = 11;
    const MAX_SCALES: usize = 5;

    let min_dim = width.min(height);
    if min_dim < GAUSSIAN_WINDOW_SIZE {
        return None;
    }

    let mut scales = 1;
    let mut required_size = GAUSSIAN_WINDOW_SIZE;
    while scales < MAX_SCALES && min_dim >= required_size * 2 {
        required_size *= 2;
        scales += 1;
    }

    Some(scales)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn gradient_image(width: u32, height: u32) -> ImageData {
        let mut data = vec![0_u8; (width * height * 4) as usize];
        for y in 0..height {
            for x in 0..width {
                let index = ((y * width + x) * 4) as usize;
                data[index] = (x * 255 / width) as u8;
                data[index + 1] = (y * 255 / height) as u8;
                data[index + 2] = 96;
                data[index + 3] = 255;
            }
        }
        ImageData::new(width, height, data)
    }

    #[test]
    fn identical_images_have_near_perfect_ms_ssim() {
        let image = gradient_image(64, 64);
        let value = compute_ms_ssim(&image, &image).expect("metric should compute");
        assert!(value > 0.999, "expected near-perfect similarity, got {value}");
    }

    #[test]
    fn degraded_image_has_lower_ms_ssim() {
        let reference = gradient_image(64, 64);
        let mut degraded = reference.clone();
        for pixel in degraded.data.chunks_exact_mut(4) {
            pixel[0] = pixel[0].saturating_add(48);
            pixel[1] = pixel[1].saturating_sub(24);
            pixel[2] = pixel[2].saturating_add(12);
        }

        let reference_value =
            compute_ms_ssim(&reference, &reference).expect("reference metric should compute");
        let degraded_value =
            compute_ms_ssim(&reference, &degraded).expect("degraded metric should compute");

        assert!(
            degraded_value < reference_value,
            "expected degraded image to score lower, got degraded={degraded_value} reference={reference_value}"
        );
    }

    #[test]
    fn identical_images_have_high_ssimulacra2() {
        let image = gradient_image(64, 64);
        let value = compute_ssimulacra2_score(&image, &image).expect("metric should compute");
        assert!(value > 99.9, "expected near-perfect similarity, got {value}");
    }

    #[test]
    fn identical_images_have_full_pixel_match() {
        let image = gradient_image(64, 64);
        let value =
            compute_pixel_match_percentage(&image, &image).expect("metric should compute");
        assert_eq!(value, 100.0);
    }

    #[test]
    fn degraded_image_has_lower_ssimulacra2() {
        let reference = gradient_image(64, 64);
        let mut degraded = reference.clone();
        for pixel in degraded.data.chunks_exact_mut(4) {
            pixel[0] = pixel[0].saturating_add(48);
            pixel[1] = pixel[1].saturating_sub(24);
            pixel[2] = pixel[2].saturating_add(12);
        }

        let reference_value = compute_ssimulacra2_score(&reference, &reference)
            .expect("reference metric should compute");
        let degraded_value = compute_ssimulacra2_score(&reference, &degraded)
            .expect("degraded metric should compute");

        assert!(
            degraded_value < reference_value,
            "expected degraded image to score lower, got degraded={degraded_value} reference={reference_value}"
        );
    }

    #[test]
    fn degraded_image_has_lower_pixel_match_percentage() {
        let reference = gradient_image(64, 64);
        let mut degraded = reference.clone();
        for pixel in degraded.data.chunks_exact_mut(4) {
            pixel[0] = pixel[0].saturating_add(48);
            pixel[1] = pixel[1].saturating_sub(24);
            pixel[2] = pixel[2].saturating_add(12);
        }

        let reference_value = compute_pixel_match_percentage(&reference, &reference)
            .expect("reference metric should compute");
        let degraded_value = compute_pixel_match_percentage(&reference, &degraded)
            .expect("degraded metric should compute");

        assert!(
            degraded_value < reference_value,
            "expected degraded image to score lower, got degraded={degraded_value} reference={reference_value}"
        );
    }

    #[test]
    fn alpha_compositing_allows_metric_computation() {
        let mut reference = gradient_image(64, 64);
        for pixel in reference.data.chunks_exact_mut(4) {
            pixel[3] = 128;
        }
        let degraded = reference.clone();
        let value =
            compute_ssimulacra2_score(&reference, &degraded).expect("metric should compute");
        assert!(value.is_finite());
    }

    #[test]
    fn alpha_images_allow_pixel_match_percentage() {
        let mut reference = gradient_image(64, 64);
        for pixel in reference.data.chunks_exact_mut(4) {
            pixel[3] = 128;
        }
        let degraded = reference.clone();
        let value = compute_pixel_match_percentage(&reference, &degraded)
            .expect("metric should compute");
        assert!(value.is_finite());
    }

    #[test]
    fn identical_images_produce_black_difference_image() {
        let image = gradient_image(16, 16);
        let diff = compute_difference_image_data(&image, &image).expect("diff should compute");
        for pixel in diff.data.chunks_exact(4) {
            assert_eq!(pixel, [0, 0, 0, 255]);
        }
    }

    #[test]
    fn changed_images_produce_non_black_difference_image() {
        let reference = gradient_image(16, 16);
        let mut distorted = reference.clone();
        for pixel in distorted.data.chunks_exact_mut(4) {
            pixel[0] = pixel[0].saturating_add(32);
        }

        let diff = compute_difference_image_data(&reference, &distorted).expect("diff should compute");
        assert!(
            diff.data
                .chunks_exact(4)
                .any(|pixel| pixel[0] > 0 || pixel[1] > 0 || pixel[2] > 0),
            "expected at least one visible difference pixel"
        );
    }

    #[test]
    fn alpha_images_allow_difference_image_computation() {
        let mut reference = gradient_image(16, 16);
        for pixel in reference.data.chunks_exact_mut(4) {
            pixel[3] = 128;
        }

        let diff = compute_difference_image_data(&reference, &reference).expect("diff should compute");
        assert_eq!(diff.width, 16);
        assert_eq!(diff.height, 16);
    }

    #[test]
    fn dimension_mismatch_returns_none_for_ssimulacra2() {
        let reference = gradient_image(64, 64);
        let distorted = gradient_image(32, 64);
        assert_eq!(compute_ssimulacra2_score(&reference, &distorted), None);
    }

    #[test]
    fn dimension_mismatch_returns_none_for_pixel_match_percentage() {
        let reference = gradient_image(64, 64);
        let distorted = gradient_image(32, 64);
        assert_eq!(compute_pixel_match_percentage(&reference, &distorted), None);
    }

    #[test]
    fn dimension_mismatch_returns_none_for_difference_image() {
        let reference = gradient_image(64, 64);
        let distorted = gradient_image(32, 64);
        assert!(compute_difference_image_data(&reference, &distorted).is_none());
    }
}
