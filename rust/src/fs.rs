use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

use slimg_core::Format;
use tempfile::NamedTempFile;

use crate::error::{Result, SlimgBridgeError};
use crate::types::ImageOperation;

pub(crate) fn derive_output_path(
    input: &Path,
    explicit_output: Option<&Path>,
    output_dir: Option<&Path>,
    overwrite: bool,
    operation: &ImageOperation,
    target_format: Format,
) -> Result<PathBuf> {
    let file_name = derived_file_name(input, target_format, operation);
    let derived = match explicit_output {
        Some(path) if path.is_dir() => path.join(&file_name),
        Some(path) => path.to_path_buf(),
        None => match output_dir {
            Some(dir) => dir.join(&file_name),
            None => match operation {
                ImageOperation::Optimize(_) if !overwrite => {
                    sibling_with_suffix(input, "optimized", target_format.extension())
                }
                _ => input.with_extension(target_format.extension()),
            },
        },
    };

    if explicit_output.is_some() && !overwrite && derived == input {
        return Err(SlimgBridgeError::invalid_request(
            "explicit output path matches the input path while overwrite=false",
        ));
    }

    if explicit_output.is_none() && !overwrite && derived == input {
        return Ok(sibling_with_suffix(
            input,
            operation.suffix(),
            target_format.extension(),
        ));
    }

    Ok(derived)
}

pub(crate) fn safe_write_bytes(path: &Path, bytes: &[u8], overwrite: bool) -> Result<()> {
    if path.exists() {
        if path.is_dir() {
            return Err(SlimgBridgeError::invalid_path(
                path,
                "output path points to a directory",
            ));
        }
        if !overwrite {
            return Err(SlimgBridgeError::invalid_path(
                path,
                "output already exists and overwrite=false",
            ));
        }
    }

    let parent = match path.parent() {
        Some(parent) if !parent.as_os_str().is_empty() => parent,
        _ => Path::new("."),
    };
    fs::create_dir_all(parent)?;

    let mut temp = NamedTempFile::new_in(parent)?;
    temp.write_all(bytes)?;
    temp.flush()?;

    #[cfg(target_family = "windows")]
    if overwrite && path.exists() {
        fs::remove_file(path)?;
    }

    temp.persist(path).map_err(|error| SlimgBridgeError::Io {
        message: error.error.to_string(),
    })?;
    Ok(())
}

pub(crate) fn to_path_buf(value: &str, field_name: &str) -> Result<PathBuf> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(SlimgBridgeError::invalid_request(format!(
            "{field_name} must not be empty"
        )));
    }
    Ok(PathBuf::from(trimmed))
}

fn derived_file_name(input: &Path, target_format: Format, operation: &ImageOperation) -> String {
    if matches!(operation, ImageOperation::Optimize(_)) {
        return sibling_with_suffix(input, "optimized", target_format.extension())
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("output")
            .to_string();
    }

    let stem = file_stem(input);
    format!("{stem}.{}", target_format.extension())
}

fn sibling_with_suffix(input: &Path, suffix: &str, extension: &str) -> PathBuf {
    let stem = file_stem(input);
    input.with_file_name(format!("{stem}.{suffix}.{extension}"))
}

fn file_stem(input: &Path) -> String {
    input
        .file_stem()
        .and_then(|stem| stem.to_str())
        .filter(|stem| !stem.is_empty())
        .unwrap_or("output")
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::{ConvertOptions, OptimizeOptions};

    #[test]
    fn optimize_uses_sibling_name() {
        let path = derive_output_path(
            Path::new("/tmp/photo.jpg"),
            None,
            None,
            false,
            &ImageOperation::Optimize(OptimizeOptions {
                quality: 80,
                write_only_if_smaller: true,
            }),
            Format::Jpeg,
        )
        .unwrap();
        assert_eq!(path, PathBuf::from("/tmp/photo.optimized.jpg"));
    }

    #[test]
    fn convert_changes_extension() {
        let path = derive_output_path(
            Path::new("/tmp/photo.jpg"),
            None,
            None,
            false,
            &ImageOperation::Convert(ConvertOptions {
                target_format: "webp".to_string(),
                quality: 80,
            }),
            Format::WebP,
        )
        .unwrap();
        assert_eq!(path, PathBuf::from("/tmp/photo.webp"));
    }

    #[test]
    fn derived_non_overwrite_collision_gets_suffix() {
        let path = derive_output_path(
            Path::new("/tmp/photo.jpg"),
            None,
            None,
            false,
            &ImageOperation::Resize(crate::types::ResizeOptions {
                resize: crate::types::ResizeSpec::Width { value: 100 },
                target_format: None,
                quality: 80,
            }),
            Format::Jpeg,
        )
        .unwrap();
        assert_eq!(path, PathBuf::from("/tmp/photo.resized.jpg"));
    }
}
