use std::any::Any;
use std::path::Path;

use slimg_core::{Error as CoreError, Format};

pub type Result<T> = std::result::Result<T, SlimgBridgeError>;

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum SlimgBridgeError {
    #[error("invalid request: {message}")]
    InvalidRequest { message: String },

    #[error("invalid path `{path}`: {message}")]
    InvalidPath { path: String, message: String },

    #[error("unsupported format: {format}")]
    UnsupportedFormat { format: String },

    #[error("unknown format: {detail}")]
    UnknownFormat { detail: String },

    #[error("decode error: {message}")]
    Decode { message: String },

    #[error("encode error: {message}")]
    Encode { message: String },

    #[error("resize error: {message}")]
    Resize { message: String },

    #[error("crop error: {message}")]
    Crop { message: String },

    #[error("extend error: {message}")]
    Extend { message: String },

    #[error("io error: {message}")]
    Io { message: String },

    #[error("internal error: {message}")]
    Internal { message: String },
}

impl SlimgBridgeError {
    pub(crate) fn invalid_request(message: impl Into<String>) -> Self {
        Self::InvalidRequest {
            message: message.into(),
        }
    }

    pub(crate) fn invalid_path(path: impl AsRef<Path>, message: impl Into<String>) -> Self {
        Self::InvalidPath {
            path: path.as_ref().to_string_lossy().into_owned(),
            message: message.into(),
        }
    }

    pub(crate) fn skipped_after_failure(path: impl AsRef<Path>) -> Self {
        Self::InvalidRequest {
            message: format!(
                "skipped `{}` because continue_on_error=false and an earlier item failed",
                path.as_ref().to_string_lossy()
            ),
        }
    }
}

impl From<std::io::Error> for SlimgBridgeError {
    fn from(value: std::io::Error) -> Self {
        Self::Io {
            message: value.to_string(),
        }
    }
}

impl From<CoreError> for SlimgBridgeError {
    fn from(value: CoreError) -> Self {
        match value {
            CoreError::UnsupportedFormat(format) | CoreError::EncodingNotSupported(format) => {
                Self::UnsupportedFormat {
                    format: format_id(format).to_string(),
                }
            }
            CoreError::UnknownFormat(detail) => Self::UnknownFormat { detail },
            CoreError::Decode(message) => Self::Decode { message },
            CoreError::Encode(message) => Self::Encode { message },
            CoreError::Resize(message) => Self::Resize { message },
            CoreError::Crop(message) => Self::Crop { message },
            CoreError::Extend(message) => Self::Extend { message },
            CoreError::Io(error) => Self::Io {
                message: error.to_string(),
            },
            CoreError::Image(error) => Self::Decode {
                message: error.to_string(),
            },
        }
    }
}

pub(crate) fn panic_message(payload: Box<dyn Any + Send>) -> String {
    if let Some(message) = payload.downcast_ref::<&str>() {
        return (*message).to_string();
    }
    if let Some(message) = payload.downcast_ref::<String>() {
        return message.clone();
    }
    "unexpected panic".to_string()
}

fn format_id(format: Format) -> &'static str {
    match format {
        Format::Jpeg => "jpeg",
        Format::Png => "png",
        Format::WebP => "webp",
        Format::Avif => "avif",
        Format::Jxl => "jxl",
        Format::Qoi => "qoi",
    }
}
