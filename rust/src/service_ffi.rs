use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::codec::parse_format;
use crate::error::panic_message;
use crate::types::{
    ConvertOptions, ImageOperation, OptimizeOptions, ProcessFileBatchRequest, ProcessFileRequest,
};

#[derive(Debug, Deserialize, Clone, Copy)]
#[serde(rename_all = "snake_case")]
enum CompressionAction {
    Compress,
    CompressKeepOriginal,
}

#[derive(Debug, Deserialize)]
struct CompressionServiceRequest {
    action: CompressionAction,
    paths: Vec<String>,
    settings: CompressionServiceSettings,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CompressionServiceSettings {
    compression_method: CompressionMethod,
    compression_priority: CompressionPriority,
    advanced_mode: bool,
    preferred_codec: PreferredCodec,
    quality: u8,
}

#[derive(Debug, Deserialize, Clone, Copy)]
#[serde(rename_all = "snake_case")]
enum CompressionMethod {
    Lossless,
    Lossy,
}

#[derive(Debug, Deserialize, Clone, Copy)]
#[serde(rename_all = "snake_case")]
enum CompressionPriority {
    Compatibility,
    Efficiency,
}

#[derive(Debug, Deserialize, Clone, Copy)]
#[serde(rename_all = "snake_case")]
enum PreferredCodec {
    Png,
    Jpeg,
    Webp,
    Avif,
    Jxl,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
struct CompressionServiceResponse {
    success_count: usize,
    failure_count: usize,
    items: Vec<CompressionServiceItem>,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
struct CompressionServiceItem {
    input_path: String,
    output_path: Option<String>,
    error: Option<String>,
}

#[no_mangle]
pub extern "C" fn oimg_service_run_request(request_json: *const c_char) -> *mut c_char {
    let response = catch_unwind(AssertUnwindSafe(|| run_request_json(request_json)))
        .unwrap_or_else(|payload| CompressionServiceResponse {
            success_count: 0,
            failure_count: 1,
            items: vec![CompressionServiceItem {
                input_path: String::new(),
                output_path: None,
                error: Some(format!("internal error: {}", panic_message(payload))),
            }],
        });

    match serde_json::to_string(&response)
        .ok()
        .and_then(|json| CString::new(json).ok())
    {
        Some(value) => value.into_raw(),
        None => CString::new(
            r#"{"success_count":0,"failure_count":1,"items":[{"input_path":"","output_path":null,"error":"internal error: failed to serialize service response"}]}"#,
        )
        .expect("valid fallback JSON")
        .into_raw(),
    }
}

#[no_mangle]
pub extern "C" fn oimg_service_free_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        drop(CString::from_raw(value));
    }
}

fn run_request_json(request_json: *const c_char) -> CompressionServiceResponse {
    if request_json.is_null() {
        return invalid_response("request JSON must not be null");
    }

    let request_json = match unsafe { CStr::from_ptr(request_json) }.to_str() {
        Ok(value) => value,
        Err(_) => return invalid_response("request JSON must be valid UTF-8"),
    };

    let request = match serde_json::from_str::<CompressionServiceRequest>(request_json) {
        Ok(value) => value,
        Err(error) => {
            return invalid_response(format!("invalid request JSON: {error}"));
        }
    };

    if request.paths.is_empty() {
        return invalid_response("paths must contain at least one file");
    }

    let batch_request = match build_batch_request(request) {
        Ok(value) => value,
        Err(error) => return invalid_response(error.to_string()),
    };

    match crate::convert::process_file_batch(batch_request) {
        Ok(results) => {
            let mut success_count = 0;
            let mut failure_count = 0;
            let mut items = Vec::with_capacity(results.len());

            for item in results {
                if item.success {
                    success_count += 1;
                } else {
                    failure_count += 1;
                }

                items.push(CompressionServiceItem {
                    input_path: item.input_path,
                    output_path: item.result.map(|result| result.output_path),
                    error: item.error.map(|error| error.to_string()),
                });
            }

            CompressionServiceResponse {
                success_count,
                failure_count,
                items,
            }
        }
        Err(error) => invalid_response(error.to_string()),
    }
}

fn build_batch_request(
    request: CompressionServiceRequest,
) -> crate::error::Result<ProcessFileBatchRequest> {
    let CompressionServiceRequest {
        action,
        paths,
        settings,
    } = request;
    let target_codec = settings.effective_codec();
    let mut requests = Vec::with_capacity(paths.len());

    for input_path in paths {
        let metadata = crate::convert::inspect_file(input_path.clone())?;
        let source_format = metadata.format;
        let same_format = source_format == target_codec;
        let output_path = if same_format {
            None
        } else {
            Some(
                sibling_optimized_path(&input_path, &target_codec)
                    .to_string_lossy()
                    .into_owned(),
            )
        };

        let overwrite = if same_format {
            matches!(action, CompressionAction::Compress)
        } else {
            true
        };

        let operation = if same_format {
            ImageOperation::Optimize(OptimizeOptions {
                quality: settings.quality,
                write_only_if_smaller: true,
            })
        } else {
            ImageOperation::Convert(ConvertOptions {
                target_format: target_codec.clone(),
                quality: settings.quality,
            })
        };

        requests.push(ProcessFileRequest {
            input_path,
            output_path,
            overwrite,
            operation,
        });
    }

    Ok(ProcessFileBatchRequest {
        requests,
        continue_on_error: true,
    })
}

fn sibling_optimized_path(input_path: &str, target_format: &str) -> PathBuf {
    let input = Path::new(input_path);
    let stem = input
        .file_stem()
        .and_then(|value| value.to_str())
        .filter(|value| !value.is_empty())
        .unwrap_or("output");
    let extension = parse_format(target_format)
        .expect("service uses supported target formats")
        .extension();
    input.with_file_name(format!("{stem}.optimized.{extension}"))
}

fn invalid_response(message: impl Into<String>) -> CompressionServiceResponse {
    CompressionServiceResponse {
        success_count: 0,
        failure_count: 1,
        items: vec![CompressionServiceItem {
            input_path: String::new(),
            output_path: None,
            error: Some(message.into()),
        }],
    }
}

impl CompressionServiceSettings {
    fn effective_codec(&self) -> String {
        if self.advanced_mode {
            return self.preferred_codec.id().to_string();
        }

        match (&self.compression_method, &self.compression_priority) {
            (CompressionMethod::Lossless, CompressionPriority::Compatibility) => "png",
            (CompressionMethod::Lossless, CompressionPriority::Efficiency) => "jxl",
            (CompressionMethod::Lossy, CompressionPriority::Compatibility) => "jpeg",
            (CompressionMethod::Lossy, CompressionPriority::Efficiency) => "avif",
        }
        .to_string()
    }
}

impl PreferredCodec {
    fn id(&self) -> &'static str {
        match self {
            Self::Png => "png",
            Self::Jpeg => "jpeg",
            Self::Webp => "webp",
            Self::Avif => "avif",
            Self::Jxl => "jxl",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    use slimg_core::{convert, Format, ImageData, PipelineOptions};
    use tempfile::tempdir;

    fn test_image() -> ImageData {
        let (width, height) = (32, 24);
        let mut data = vec![0_u8; (width * height * 4) as usize];
        for y in 0..height {
            for x in 0..width {
                let index = ((y * width + x) * 4) as usize;
                data[index] = (x * 255 / width) as u8;
                data[index + 1] = (y * 255 / height) as u8;
                data[index + 2] = 128;
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
                threads: None,
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
    fn compress_keep_original_returns_successful_result() {
        let dir = tempdir().unwrap();
        let input_path = dir.path().join("sample.png");
        fs::write(&input_path, png_bytes()).unwrap();

        let request = serde_json::json!({
            "action": "compress_keep_original",
            "paths": [input_path.to_string_lossy()],
            "settings": {
                "compressionMethod": "lossless",
                "compressionPriority": "compatibility",
                "advancedMode": true,
                "preferredCodec": "png",
                "quality": 80
            }
        });
        let request = CString::new(request.to_string()).unwrap();
        let response = oimg_service_run_request(request.as_ptr());
        let response_json = unsafe { CStr::from_ptr(response) }
            .to_str()
            .unwrap()
            .to_string();
        oimg_service_free_string(response);

        let response: CompressionServiceResponse = serde_json::from_str(&response_json).unwrap();
        assert_eq!(response.success_count, 1);
        assert_eq!(response.failure_count, 0);
        let output_path = response.items[0].output_path.as_ref().unwrap();
        assert!(
            output_path.ends_with("sample.optimized.png") || output_path.ends_with("sample.png")
        );
    }

    #[test]
    fn compress_uses_sibling_output_when_codec_changes() {
        let dir = tempdir().unwrap();
        let input_path = dir.path().join("sample.png");
        fs::write(&input_path, png_bytes()).unwrap();

        let request = serde_json::json!({
            "action": "compress",
            "paths": [input_path.to_string_lossy()],
            "settings": {
                "compressionMethod": "lossy",
                "compressionPriority": "compatibility",
                "advancedMode": false,
                "preferredCodec": "png",
                "quality": 80
            }
        });
        let request = CString::new(request.to_string()).unwrap();
        let response = oimg_service_run_request(request.as_ptr());
        let response_json = unsafe { CStr::from_ptr(response) }
            .to_str()
            .unwrap()
            .to_string();
        oimg_service_free_string(response);

        let response: CompressionServiceResponse = serde_json::from_str(&response_json).unwrap();
        assert_eq!(response.success_count, 1);
        assert_eq!(response.failure_count, 0);
        let output_path = response.items[0].output_path.as_ref().unwrap();
        assert!(output_path.ends_with("sample.optimized.jpg"));
        assert!(input_path.exists());
    }

    #[test]
    fn invalid_json_returns_error_response() {
        let request = CString::new("{").unwrap();
        let response = oimg_service_run_request(request.as_ptr());
        let response_json = unsafe { CStr::from_ptr(response) }
            .to_str()
            .unwrap()
            .to_string();
        oimg_service_free_string(response);

        let response: CompressionServiceResponse = serde_json::from_str(&response_json).unwrap();
        assert_eq!(response.success_count, 0);
        assert_eq!(response.failure_count, 1);
        assert!(response.items[0].error.is_some());
    }
}
