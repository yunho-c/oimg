use crate::convert;
use crate::error::Result;
use crate::types::{PreviewFileRequest, PreviewResult};

pub(crate) fn preview_file(request: PreviewFileRequest) -> Result<PreviewResult> {
    convert::preview_file(request)
}
