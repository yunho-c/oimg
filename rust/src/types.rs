use crate::error::SlimgBridgeError;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FormatInfo {
    pub id: String,
    pub extension: String,
    pub can_encode: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ImageMetadata {
    pub width: u32,
    pub height: u32,
    pub format: String,
    pub file_size: Option<u64>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PreviewResult {
    pub encoded_bytes: Vec<u8>,
    pub source_rgba_bytes: Vec<u8>,
    pub preview_rgba_bytes: Vec<u8>,
    pub format: String,
    pub width: u32,
    pub height: u32,
    pub size_bytes: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PreviewQualityMetricsRequest {
    pub original_rgba_bytes: Vec<u8>,
    pub original_width: u32,
    pub original_height: u32,
    pub preview_rgba_bytes: Vec<u8>,
    pub preview_width: u32,
    pub preview_height: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EncodedImageResult {
    pub encoded_bytes: Vec<u8>,
    pub format: String,
    pub width: u32,
    pub height: u32,
    pub size_bytes: u64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RawImageResult {
    pub rgba_bytes: Vec<u8>,
    pub width: u32,
    pub height: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProcessResult {
    pub output_path: String,
    pub format: String,
    pub width: u32,
    pub height: u32,
    pub original_size: u64,
    pub new_size: u64,
    pub did_write: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BatchItemResult {
    pub input_path: String,
    pub success: bool,
    pub result: Option<ProcessResult>,
    pub error: Option<SlimgBridgeError>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BatchJobHandle {
    pub job_id: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BatchJobState {
    Running,
    CancelRequested,
    Completed,
    Canceled,
    Failed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BatchJobSnapshot {
    pub job_id: String,
    pub state: BatchJobState,
    pub total_count: u32,
    pub completed_count: u32,
    pub current_input_path: Option<String>,
    pub results: Vec<BatchItemResult>,
    pub error: Option<SlimgBridgeError>,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ImageOperation {
    Convert(ConvertOptions),
    Optimize(OptimizeOptions),
    Resize(ResizeOptions),
    Crop(CropOptions),
    Extend(ExtendOptions),
}

#[derive(Debug, Clone, PartialEq)]
pub struct ProcessFileRequest {
    pub input_path: String,
    pub output_path: Option<String>,
    pub overwrite: bool,
    pub operation: ImageOperation,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ProcessBytesRequest {
    pub data: Vec<u8>,
    pub operation: ImageOperation,
}

#[derive(Debug, Clone, PartialEq)]
pub struct BatchProcessRequest {
    pub input_paths: Vec<String>,
    pub output_dir: Option<String>,
    pub overwrite: bool,
    pub operation: ImageOperation,
    pub continue_on_error: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ProcessFileBatchRequest {
    pub requests: Vec<ProcessFileRequest>,
    pub continue_on_error: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PreviewFileRequest {
    pub input_path: String,
    pub operation: ImageOperation,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConvertOptions {
    pub target_format: String,
    pub quality: u8,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OptimizeOptions {
    pub quality: u8,
    pub write_only_if_smaller: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ResizeSpec {
    Width { value: u32 },
    Height { value: u32 },
    Exact { width: u32, height: u32 },
    Fit { max_width: u32, max_height: u32 },
    Scale { factor: f64 },
}

#[derive(Debug, Clone, PartialEq)]
pub struct ResizeOptions {
    pub resize: ResizeSpec,
    pub target_format: Option<String>,
    pub quality: u8,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CropSpec {
    Region {
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    },
    AspectRatio {
        width: u32,
        height: u32,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CropOptions {
    pub crop: CropSpec,
    pub target_format: Option<String>,
    pub quality: u8,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ExtendSpec {
    AspectRatio { width: u32, height: u32 },
    Size { width: u32, height: u32 },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FillSpec {
    Solid { r: u8, g: u8, b: u8, a: u8 },
    Transparent,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExtendOptions {
    pub extend: ExtendSpec,
    pub fill: Option<FillSpec>,
    pub target_format: Option<String>,
    pub quality: u8,
}

impl ImageOperation {
    pub(crate) fn suffix(&self) -> &'static str {
        match self {
            Self::Convert(_) => "converted",
            Self::Optimize(_) => "optimized",
            Self::Resize(_) => "resized",
            Self::Crop(_) => "cropped",
            Self::Extend(_) => "extended",
        }
    }
}
