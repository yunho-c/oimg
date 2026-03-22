use slimg_core::Format;

use crate::error::{Result, SlimgBridgeError};
use crate::types::FormatInfo;

pub(crate) fn parse_format(value: &str) -> Result<Format> {
    match value.trim().to_ascii_lowercase().as_str() {
        "jpeg" | "jpg" => Ok(Format::Jpeg),
        "png" => Ok(Format::Png),
        "webp" => Ok(Format::WebP),
        "avif" => Ok(Format::Avif),
        "jxl" => Ok(Format::Jxl),
        "qoi" => Ok(Format::Qoi),
        other => Err(SlimgBridgeError::UnsupportedFormat {
            format: other.to_string(),
        }),
    }
}

pub(crate) fn format_to_string(format: Format) -> String {
    match format {
        Format::Jpeg => "jpeg",
        Format::Png => "png",
        Format::WebP => "webp",
        Format::Avif => "avif",
        Format::Jxl => "jxl",
        Format::Qoi => "qoi",
    }
    .to_string()
}

pub(crate) fn format_info() -> Vec<FormatInfo> {
    [
        Format::Jpeg,
        Format::Png,
        Format::WebP,
        Format::Avif,
        Format::Jxl,
        Format::Qoi,
    ]
    .into_iter()
    .map(|format| FormatInfo {
        id: format_to_string(format),
        extension: format.extension().to_string(),
        can_encode: format.can_encode(),
    })
    .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_known_format() {
        assert_eq!(parse_format("webp").unwrap(), Format::WebP);
        assert_eq!(parse_format("JPG").unwrap(), Format::Jpeg);
    }

    #[test]
    fn parse_unknown_format() {
        let error = parse_format("gif").unwrap_err();
        assert!(matches!(
            error,
            SlimgBridgeError::UnsupportedFormat { format } if format == "gif"
        ));
    }
}
