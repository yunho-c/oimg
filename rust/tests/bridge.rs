use std::fs;

use oimg_rust::api::bridge::{
    self, BatchProcessRequest, ConvertOptions, CropOptions, CropSpec, ImageOperation,
    PreviewFileRequest, ProcessBytesRequest, ProcessFileRequest, ResizeOptions, ResizeSpec,
};
use slimg_core::{convert, decode, Format, ImageData, PipelineOptions};
use tempfile::tempdir;

fn test_image() -> ImageData {
    let (width, height) = (48, 32);
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

fn png_bytes() -> Vec<u8> {
    convert(
        &test_image(),
        &PipelineOptions {
            format: Format::Png,
            quality: 80,
            resize: None,
            crop: None,
            extend: None,
            fill_color: None,
        },
    )
    .unwrap()
    .data
}

#[test]
fn inspect_bytes_reports_png_dimensions() {
    let metadata = bridge::inspect_bytes(png_bytes()).unwrap();
    assert_eq!(metadata.width, 48);
    assert_eq!(metadata.height, 32);
    assert_eq!(metadata.format, "png");
    assert_eq!(metadata.file_size, None);
}

#[test]
fn process_bytes_converts_to_webp() {
    let result = bridge::process_bytes(ProcessBytesRequest {
        data: png_bytes(),
        operation: ImageOperation::Convert(ConvertOptions {
            target_format: "webp".to_string(),
            quality: 80,
        }),
    })
    .unwrap();

    assert_eq!(result.format, "webp");
    assert!(result.size_bytes > 0);
}

#[test]
fn preview_file_crops_without_writing() {
    let dir = tempdir().unwrap();
    let input_path = dir.path().join("source.png");
    fs::write(&input_path, png_bytes()).unwrap();

    let preview = bridge::preview_file(PreviewFileRequest {
        input_path: input_path.to_string_lossy().into_owned(),
        operation: ImageOperation::Crop(CropOptions {
            crop: CropSpec::AspectRatio {
                width: 1,
                height: 1,
            },
            target_format: None,
            quality: 80,
        }),
    })
    .unwrap();

    let (decoded, format) = decode(&preview.encoded_bytes).unwrap();
    assert_eq!(format, Format::Png);
    assert_eq!(decoded.width, 32);
    assert_eq!(decoded.height, 32);
}

#[test]
fn process_file_derives_suffixed_output_when_overwrite_is_false() {
    let dir = tempdir().unwrap();
    let input_path = dir.path().join("photo.png");
    fs::write(&input_path, png_bytes()).unwrap();

    let result = bridge::process_file(ProcessFileRequest {
        input_path: input_path.to_string_lossy().into_owned(),
        output_path: None,
        overwrite: false,
        operation: ImageOperation::Resize(ResizeOptions {
            resize: ResizeSpec::Width { value: 24 },
            target_format: None,
            quality: 80,
        }),
    })
    .unwrap();

    assert!(result.output_path.ends_with("photo.resized.png"));
    assert_eq!(result.width, 24);

    let written_bytes = fs::read(&result.output_path).unwrap();
    let (decoded, format) = decode(&written_bytes).unwrap();
    assert_eq!(format, Format::Png);
    assert_eq!(decoded.width, 24);
    assert_eq!(decoded.height, 16);
}

#[test]
fn process_files_returns_ordered_partial_failures() {
    let dir = tempdir().unwrap();
    let output_dir = dir.path().join("out");
    let first_path = dir.path().join("first.png");
    let third_path = dir.path().join("third.png");
    let missing_path = dir.path().join("missing.png");

    fs::write(&first_path, png_bytes()).unwrap();
    fs::write(&third_path, png_bytes()).unwrap();

    let results = bridge::process_files(BatchProcessRequest {
        input_paths: vec![
            first_path.to_string_lossy().into_owned(),
            missing_path.to_string_lossy().into_owned(),
            third_path.to_string_lossy().into_owned(),
        ],
        output_dir: Some(output_dir.to_string_lossy().into_owned()),
        overwrite: false,
        operation: ImageOperation::Convert(ConvertOptions {
            target_format: "webp".to_string(),
            quality: 80,
        }),
        continue_on_error: true,
    })
    .unwrap();

    assert_eq!(results.len(), 3);
    assert!(results[0].success);
    assert!(!results[1].success);
    assert!(results[2].success);
    assert_eq!(results[0].input_path, first_path.to_string_lossy());
    assert_eq!(results[1].input_path, missing_path.to_string_lossy());
    assert_eq!(results[2].input_path, third_path.to_string_lossy());
}
