use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, OnceLock};

#[derive(Debug)]
pub(crate) struct PreviewArtifact {
    pub original_width: u32,
    pub original_height: u32,
    pub preview_width: u32,
    pub preview_height: u32,
    pub original_rgba_bytes: Vec<u8>,
    pub preview_rgba_bytes: Vec<u8>,
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
