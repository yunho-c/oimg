use std::sync::Arc;

use dify::diff::get_results;
use fast_ssim2::{compute_ssimulacra2, srgb_u8_to_linear, LinearRgbImage};
use image::RgbaImage;
use tjdistler_iqa::{ImageQualityAssessment, MsSsim};

use crate::error::SlimgBridgeError;
use crate::preview_artifacts::{preview_artifact_store, PreviewArtifact};
use crate::types::{PreviewArtifactRequest, RawImageResult};

const DIFY_DEFAULT_THRESHOLD: f32 = 35215.0 * 0.05 * 0.05;

pub(crate) fn compute_ms_ssim(
    reference_width: u32,
    reference_height: u32,
    reference_rgba: &[u8],
    distorted_width: u32,
    distorted_height: u32,
    distorted_rgba: &[u8],
) -> Option<f64> {
    if reference_width != distorted_width || reference_height != distorted_height {
        return None;
    }

    let width = usize::try_from(reference_width).ok()?;
    let height = usize::try_from(reference_height).ok()?;
    validate_rgba_len(reference_width, reference_height, reference_rgba)?;
    validate_rgba_len(distorted_width, distorted_height, distorted_rgba)?;
    let reference_luma = rgba_to_luma(reference_rgba);
    let distorted_luma = rgba_to_luma(distorted_rgba);
    let scales = supported_ms_ssim_scales(width, height)?;
    let metric = MsSsim::builder().scales(scales).build();

    metric
        .assess(&reference_luma, &distorted_luma, width, height)
        .ok()
        .map(|result| result.value)
        .filter(|value| value.is_finite())
}

pub(crate) fn compute_ssimulacra2_score(
    reference_width: u32,
    reference_height: u32,
    reference_rgba: &[u8],
    distorted_width: u32,
    distorted_height: u32,
    distorted_rgba: &[u8],
) -> Option<f64> {
    if reference_width != distorted_width || reference_height != distorted_height {
        return None;
    }

    let width = usize::try_from(reference_width).ok()?;
    let height = usize::try_from(reference_height).ok()?;
    validate_rgba_len(reference_width, reference_height, reference_rgba)?;
    validate_rgba_len(distorted_width, distorted_height, distorted_rgba)?;
    let reference_rgb = rgba_to_linear_rgb(reference_rgba, width, height);
    let distorted_rgb = rgba_to_linear_rgb(distorted_rgba, width, height);

    compute_ssimulacra2(reference_rgb, distorted_rgb)
        .ok()
        .filter(|value| value.is_finite())
}

pub(crate) fn compute_pixel_match_percentage(
    reference_width: u32,
    reference_height: u32,
    reference_rgba: &[u8],
    distorted_width: u32,
    distorted_height: u32,
    distorted_rgba: &[u8],
) -> Option<f64> {
    if reference_width != distorted_width || reference_height != distorted_height {
        return None;
    }

    let reference_image = rgba_image(reference_width, reference_height, reference_rgba)?;
    let distorted_image = rgba_image(distorted_width, distorted_height, distorted_rgba)?;
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

pub(crate) fn compute_difference_image(
    reference_width: u32,
    reference_height: u32,
    reference_rgba: &[u8],
    distorted_width: u32,
    distorted_height: u32,
    distorted_rgba: &[u8],
) -> Option<RawImageResult> {
    let rgba_bytes = compute_difference_image_data(
        reference_width,
        reference_height,
        reference_rgba,
        distorted_width,
        distorted_height,
        distorted_rgba,
    )?;
    Some(RawImageResult {
        rgba_bytes,
        width: reference_width,
        height: reference_height,
    })
}

pub(crate) fn compute_preview_pixel_match_percentage(
    request: PreviewArtifactRequest,
) -> crate::error::Result<Option<f64>> {
    let artifact = request_artifact(&request)?;
    Ok(compute_pixel_match_percentage(
        artifact.original_width,
        artifact.original_height,
        &artifact.original_rgba_bytes,
        artifact.preview_width,
        artifact.preview_height,
        &artifact.preview_rgba_bytes,
    ))
}

pub(crate) fn compute_preview_ms_ssim(
    request: PreviewArtifactRequest,
) -> crate::error::Result<Option<f64>> {
    let artifact = request_artifact(&request)?;
    Ok(compute_ms_ssim(
        artifact.original_width,
        artifact.original_height,
        &artifact.original_rgba_bytes,
        artifact.preview_width,
        artifact.preview_height,
        &artifact.preview_rgba_bytes,
    ))
}

pub(crate) fn compute_preview_ssimulacra2(
    request: PreviewArtifactRequest,
) -> crate::error::Result<Option<f64>> {
    let artifact = request_artifact(&request)?;
    Ok(compute_ssimulacra2_score(
        artifact.original_width,
        artifact.original_height,
        &artifact.original_rgba_bytes,
        artifact.preview_width,
        artifact.preview_height,
        &artifact.preview_rgba_bytes,
    ))
}

pub(crate) fn compute_preview_difference_image(
    request: PreviewArtifactRequest,
) -> crate::error::Result<Option<RawImageResult>> {
    let artifact = request_artifact(&request)?;
    Ok(compute_difference_image(
        artifact.original_width,
        artifact.original_height,
        &artifact.original_rgba_bytes,
        artifact.preview_width,
        artifact.preview_height,
        &artifact.preview_rgba_bytes,
    ))
}

fn request_artifact(
    request: &PreviewArtifactRequest,
) -> crate::error::Result<Arc<PreviewArtifact>> {
    preview_artifact_store()
        .get(&request.artifact_id)
        .ok_or_else(|| {
            SlimgBridgeError::invalid_request(format!(
                "unknown preview artifact `{}`",
                request.artifact_id
            ))
        })
}

fn rgba_to_luma(image: &[u8]) -> Vec<u8> {
    image
        .chunks_exact(4)
        .map(|pixel| {
            let [r, g, b, a]: [u8; 4] = pixel.try_into().expect("pixel chunk should be RGBA");
            let alpha = u32::from(a);
            let inv_alpha = 255 - alpha;
            let r = (u32::from(r) * alpha + 255 * inv_alpha) / 255;
            let g = (u32::from(g) * alpha + 255 * inv_alpha) / 255;
            let b = (u32::from(b) * alpha + 255 * inv_alpha) / 255;
            ((77 * r + 150 * g + 29 * b + 128) >> 8) as u8
        })
        .collect()
}

fn rgba_to_linear_rgb(image: &[u8], width: usize, height: usize) -> LinearRgbImage {
    let data = image
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

fn rgba_image(width: u32, height: u32, rgba_bytes: &[u8]) -> Option<RgbaImage> {
    validate_rgba_len(width, height, rgba_bytes)?;
    RgbaImage::from_raw(width, height, rgba_bytes.to_vec())
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

fn compute_difference_image_data(
    reference_width: u32,
    reference_height: u32,
    reference_rgba: &[u8],
    distorted_width: u32,
    distorted_height: u32,
    distorted_rgba: &[u8],
) -> Option<Vec<u8>> {
    if reference_width != distorted_width || reference_height != distorted_height {
        return None;
    }
    validate_rgba_len(reference_width, reference_height, reference_rgba)?;
    validate_rgba_len(distorted_width, distorted_height, distorted_rgba)?;

    Some(
        reference_rgba
            .chunks_exact(4)
            .zip(distorted_rgba.chunks_exact(4))
            .flat_map(|(reference_pixel, distorted_pixel)| {
                let [reference_r, reference_g, reference_b, reference_a]: [u8; 4] =
                    reference_pixel.try_into().expect("pixel chunk should be RGBA");
                let [distorted_r, distorted_g, distorted_b, distorted_a]: [u8; 4] =
                    distorted_pixel.try_into().expect("pixel chunk should be RGBA");
                let reference_rgb =
                    premultiply_rgb(reference_r, reference_g, reference_b, reference_a);
                let distorted_rgb =
                    premultiply_rgb(distorted_r, distorted_g, distorted_b, distorted_a);
                [
                    distorted_rgb[0].abs_diff(reference_rgb[0]),
                    distorted_rgb[1].abs_diff(reference_rgb[1]),
                    distorted_rgb[2].abs_diff(reference_rgb[2]),
                    255,
                ]
            })
            .collect(),
    )
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

fn validate_rgba_len(width: u32, height: u32, rgba_bytes: &[u8]) -> Option<()> {
    let expected_len = width as usize * height as usize * 4;
    (rgba_bytes.len() == expected_len).then_some(())
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
    use slimg_core::ImageData;

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
        let value = compute_ms_ssim(
            image.width,
            image.height,
            &image.data,
            image.width,
            image.height,
            &image.data,
        )
        .expect("metric should compute");
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

        let reference_value = compute_ms_ssim(
            reference.width,
            reference.height,
            &reference.data,
            reference.width,
            reference.height,
            &reference.data,
        )
        .expect("reference metric should compute");
        let degraded_value = compute_ms_ssim(
            reference.width,
            reference.height,
            &reference.data,
            degraded.width,
            degraded.height,
            &degraded.data,
        )
        .expect("degraded metric should compute");

        assert!(
            degraded_value < reference_value,
            "expected degraded image to score lower, got degraded={degraded_value} reference={reference_value}"
        );
    }

    #[test]
    fn identical_images_have_high_ssimulacra2() {
        let image = gradient_image(64, 64);
        let value = compute_ssimulacra2_score(
            image.width,
            image.height,
            &image.data,
            image.width,
            image.height,
            &image.data,
        )
        .expect("metric should compute");
        assert!(value > 99.9, "expected near-perfect similarity, got {value}");
    }

    #[test]
    fn identical_images_have_full_pixel_match() {
        let image = gradient_image(64, 64);
        let value = compute_pixel_match_percentage(
            image.width,
            image.height,
            &image.data,
            image.width,
            image.height,
            &image.data,
        )
        .expect("metric should compute");
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

        let reference_value = compute_ssimulacra2_score(
            reference.width,
            reference.height,
            &reference.data,
            reference.width,
            reference.height,
            &reference.data,
        )
        .expect("reference metric should compute");
        let degraded_value = compute_ssimulacra2_score(
            reference.width,
            reference.height,
            &reference.data,
            degraded.width,
            degraded.height,
            &degraded.data,
        )
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

        let reference_value = compute_pixel_match_percentage(
            reference.width,
            reference.height,
            &reference.data,
            reference.width,
            reference.height,
            &reference.data,
        )
        .expect("reference metric should compute");
        let degraded_value = compute_pixel_match_percentage(
            reference.width,
            reference.height,
            &reference.data,
            degraded.width,
            degraded.height,
            &degraded.data,
        )
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
        let value = compute_ssimulacra2_score(
            reference.width,
            reference.height,
            &reference.data,
            degraded.width,
            degraded.height,
            &degraded.data,
        )
        .expect("metric should compute");
        assert!(value.is_finite());
    }

    #[test]
    fn alpha_images_allow_pixel_match_percentage() {
        let mut reference = gradient_image(64, 64);
        for pixel in reference.data.chunks_exact_mut(4) {
            pixel[3] = 128;
        }
        let degraded = reference.clone();
        let value = compute_pixel_match_percentage(
            reference.width,
            reference.height,
            &reference.data,
            degraded.width,
            degraded.height,
            &degraded.data,
        )
        .expect("metric should compute");
        assert!(value.is_finite());
    }

    #[test]
    fn identical_images_produce_black_difference_image() {
        let image = gradient_image(16, 16);
        let diff = compute_difference_image_data(
            image.width,
            image.height,
            &image.data,
            image.width,
            image.height,
            &image.data,
        )
        .expect("diff should compute");
        for pixel in diff.chunks_exact(4) {
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

        let diff = compute_difference_image_data(
            reference.width,
            reference.height,
            &reference.data,
            distorted.width,
            distorted.height,
            &distorted.data,
        )
        .expect("diff should compute");
        assert!(
            diff.chunks_exact(4)
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

        let diff = compute_difference_image_data(
            reference.width,
            reference.height,
            &reference.data,
            reference.width,
            reference.height,
            &reference.data,
        )
        .expect("diff should compute");
        assert_eq!(diff.len(), 16 * 16 * 4);
    }

    #[test]
    fn dimension_mismatch_returns_none_for_ssimulacra2() {
        let reference = gradient_image(64, 64);
        let distorted = gradient_image(32, 64);
        assert_eq!(
            compute_ssimulacra2_score(
                reference.width,
                reference.height,
                &reference.data,
                distorted.width,
                distorted.height,
                &distorted.data,
            ),
            None
        );
    }

    #[test]
    fn dimension_mismatch_returns_none_for_pixel_match_percentage() {
        let reference = gradient_image(64, 64);
        let distorted = gradient_image(32, 64);
        assert_eq!(
            compute_pixel_match_percentage(
                reference.width,
                reference.height,
                &reference.data,
                distorted.width,
                distorted.height,
                &distorted.data,
            ),
            None
        );
    }

    #[test]
    fn dimension_mismatch_returns_none_for_difference_image() {
        let reference = gradient_image(64, 64);
        let distorted = gradient_image(32, 64);
        assert!(compute_difference_image_data(
            reference.width,
            reference.height,
            &reference.data,
            distorted.width,
            distorted.height,
            &distorted.data,
        )
        .is_none());
    }
}
