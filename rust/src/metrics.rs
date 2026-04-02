use slimg_core::{decode, ImageData};
use tjdistler_iqa::{ImageQualityAssessment, MsSsim};

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
}
