use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

use crate::types::RawImageResult;

#[derive(Debug)]
pub(crate) struct PreviewArtifact {
    pub original_width: u32,
    pub original_height: u32,
    pub preview_width: u32,
    pub preview_height: u32,
    pub original_rgba_bytes: Arc<[u8]>,
    pub preview_rgba_bytes: Arc<[u8]>,
    pub decoded_pixels_equal: OnceLock<bool>,
    pub pixel_match_percentage: OnceLock<Option<f64>>,
    pub ms_ssim: OnceLock<Option<f64>>,
    pub ssimulacra2: OnceLock<Option<f64>>,
    pub difference_image: OnceLock<Option<RawImageResult>>,
}

impl PreviewArtifact {
    pub(crate) fn new(
        original_width: u32,
        original_height: u32,
        preview_width: u32,
        preview_height: u32,
        original_rgba_bytes: Arc<[u8]>,
        preview_rgba_bytes: Arc<[u8]>,
    ) -> Self {
        Self {
            original_width,
            original_height,
            preview_width,
            preview_height,
            original_rgba_bytes,
            preview_rgba_bytes,
            decoded_pixels_equal: OnceLock::new(),
            pixel_match_percentage: OnceLock::new(),
            ms_ssim: OnceLock::new(),
            ssimulacra2: OnceLock::new(),
            difference_image: OnceLock::new(),
        }
    }

    pub(crate) fn decoded_pixels_equal(&self) -> bool {
        *self.decoded_pixels_equal.get_or_init(|| {
            self.original_width == self.preview_width
                && self.original_height == self.preview_height
                && self.original_rgba_bytes.as_ref() == self.preview_rgba_bytes.as_ref()
        })
    }
}

#[derive(Debug, Default)]
pub(crate) struct PreviewArtifactStore {
    next_id: AtomicU64,
    artifacts: Mutex<HashMap<String, Arc<PreviewArtifact>>>,
}

impl PreviewArtifactStore {
    pub(crate) fn insert(&self, artifact: PreviewArtifact) -> String {
        let artifact_id = format!(
            "preview-artifact-{}",
            self.next_id.fetch_add(1, Ordering::Relaxed) + 1
        );
        self.artifacts
            .lock()
            .expect("preview artifact store lock poisoned")
            .insert(artifact_id.clone(), Arc::new(artifact));
        artifact_id
    }

    pub(crate) fn get(&self, artifact_id: &str) -> Option<Arc<PreviewArtifact>> {
        self.artifacts
            .lock()
            .expect("preview artifact store lock poisoned")
            .get(artifact_id)
            .cloned()
    }

    pub(crate) fn remove(&self, artifact_id: &str) {
        self.artifacts
            .lock()
            .expect("preview artifact store lock poisoned")
            .remove(artifact_id);
    }
}

pub(crate) fn preview_artifact_store() -> &'static PreviewArtifactStore {
    static STORE: OnceLock<PreviewArtifactStore> = OnceLock::new();
    STORE.get_or_init(PreviewArtifactStore::default)
}
