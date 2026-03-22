use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};

use serde::{Deserialize, Serialize};

use crate::error::panic_message;
use crate::types::{BatchProcessRequest, ImageOperation, OptimizeOptions};

const SERVICE_QUALITY: u8 = 80;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
enum CompressionAction {
    Compress,
    CompressKeepOriginal,
}

#[derive(Debug, Deserialize)]
struct CompressionServiceRequest {
    action: CompressionAction,
    paths: Vec<String>,
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

    let batch_request = BatchProcessRequest {
        input_paths: request.paths,
        output_dir: None,
        overwrite: matches!(request.action, CompressionAction::Compress),
        operation: ImageOperation::Optimize(OptimizeOptions {
            quality: SERVICE_QUALITY,
            write_only_if_smaller: true,
        }),
        continue_on_error: true,
    };

    match crate::convert::process_files(batch_request) {
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
