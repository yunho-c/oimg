use std::panic::{catch_unwind, AssertUnwindSafe};

pub use crate::error::SlimgBridgeError;
pub use crate::types::{
    BatchItemResult, BatchProcessRequest, ConvertOptions, CropOptions, CropSpec,
    EncodedImageResult, ExtendOptions, ExtendSpec, FillSpec, FormatInfo, ImageMetadata,
    ImageOperation, OptimizeOptions, PreviewFileRequest, PreviewResult, ProcessBytesRequest,
    ProcessFileBatchRequest, ProcessFileRequest, ProcessResult, ResizeOptions, ResizeSpec,
};

use crate::error::{panic_message, Result};

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[flutter_rust_bridge::frb(sync)]
pub fn version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

#[flutter_rust_bridge::frb(sync)]
pub fn supported_formats() -> Vec<FormatInfo> {
    crate::codec::format_info()
}

pub fn inspect_file(input_path: String) -> Result<ImageMetadata> {
    with_internal(|| crate::convert::inspect_file(input_path))
}

pub fn inspect_bytes(data: Vec<u8>) -> Result<ImageMetadata> {
    with_internal(|| crate::convert::inspect_bytes(data))
}

pub fn preview_file(request: PreviewFileRequest) -> Result<PreviewResult> {
    with_internal(|| crate::preview::preview_file(request))
}

pub fn process_file(request: ProcessFileRequest) -> Result<ProcessResult> {
    with_internal(|| crate::convert::process_file(request))
}

pub fn process_bytes(request: ProcessBytesRequest) -> Result<EncodedImageResult> {
    with_internal(|| crate::convert::process_bytes(request))
}

pub fn process_files(request: BatchProcessRequest) -> Result<Vec<BatchItemResult>> {
    with_internal(|| crate::convert::process_files(request))
}

pub fn process_file_batch(request: ProcessFileBatchRequest) -> Result<Vec<BatchItemResult>> {
    with_internal(|| crate::convert::process_file_batch(request))
}

fn with_internal<T, F>(func: F) -> Result<T>
where
    F: FnOnce() -> Result<T>,
{
    catch_unwind(AssertUnwindSafe(func)).map_err(|payload| SlimgBridgeError::Internal {
        message: panic_message(payload),
    })?
}
