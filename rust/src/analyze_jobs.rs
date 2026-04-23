use std::collections::HashMap;
use std::fs;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::PathBuf;
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc, Mutex, MutexGuard, OnceLock,
};
use std::thread;

use slimg_core::decode;

use crate::codec::format_to_string;
use crate::convert::run_preview_operation;
use crate::error::{panic_message, Result, SlimgBridgeError};
use crate::metrics::{compute_ms_ssim, compute_pixel_match_percentage, compute_ssimulacra2_score};
use crate::preview_artifacts::{preview_artifact_store, PreviewArtifact};
use crate::types::{
    AnalyzeFileJobHandle, AnalyzeFileJobSnapshot, AnalyzeFileRequest, AnalyzeSampleResult,
    BatchJobState,
};

static NEXT_JOB_ID: AtomicU64 = AtomicU64::new(1);
static JOBS: OnceLock<Mutex<HashMap<String, Arc<AnalyzeJobRecord>>>> = OnceLock::new();

struct AnalyzeJobRecord {
    cancel_requested: AtomicBool,
    dispose_requested: AtomicBool,
    snapshot: Mutex<AnalyzeFileJobSnapshot>,
    temp_dir: Mutex<Option<PathBuf>>,
    artifact_ids: Mutex<Vec<String>>,
}

pub(crate) fn start_analyze_file_job(request: AnalyzeFileRequest) -> Result<AnalyzeFileJobHandle> {
    if request.input_path.is_empty() {
        return Err(SlimgBridgeError::invalid_request(
            "input_path must not be empty",
        ));
    }
    if request.qualities.is_empty() {
        return Err(SlimgBridgeError::invalid_request(
            "qualities must contain at least one sample",
        ));
    }

    let job_id = format!("analyze-{}", NEXT_JOB_ID.fetch_add(1, Ordering::Relaxed));
    let record = Arc::new(AnalyzeJobRecord {
        cancel_requested: AtomicBool::new(false),
        dispose_requested: AtomicBool::new(false),
        snapshot: Mutex::new(AnalyzeFileJobSnapshot {
            job_id: job_id.clone(),
            state: BatchJobState::Running,
            total_count: request.qualities.len() as u32,
            completed_count: 0,
            current_quality: None,
            results: Vec::with_capacity(request.qualities.len()),
            error: None,
        }),
        temp_dir: Mutex::new(None),
        artifact_ids: Mutex::new(Vec::new()),
    });

    registry_lock()?.insert(job_id.clone(), record.clone());
    spawn_analyze_job(record, request);

    Ok(AnalyzeFileJobHandle { job_id })
}

pub(crate) fn get_analyze_file_job(job_id: String) -> Result<AnalyzeFileJobSnapshot> {
    Ok(find_job(&job_id)?.snapshot_lock()?.clone())
}

pub(crate) fn cancel_analyze_file_job(job_id: String) -> Result<()> {
    let record = find_job(&job_id)?;
    record.cancel_requested.store(true, Ordering::SeqCst);

    let mut snapshot = record.snapshot_lock()?;
    if matches!(snapshot.state, BatchJobState::Running) {
        snapshot.state = BatchJobState::CancelRequested;
    }

    Ok(())
}

pub(crate) fn dispose_analyze_file_job(job_id: String) -> Result<()> {
    let record = registry_lock()?
        .remove(&job_id)
        .ok_or_else(|| unknown_job(&job_id))?;
    record.cancel_requested.store(true, Ordering::SeqCst);
    record.dispose_requested.store(true, Ordering::SeqCst);
    if is_terminal(record.snapshot_lock()?.state) {
        cleanup_resources(&record);
    }
    Ok(())
}

fn spawn_analyze_job(record: Arc<AnalyzeJobRecord>, request: AnalyzeFileRequest) {
    thread::spawn(move || {
        let outcome = catch_unwind(AssertUnwindSafe(|| run_analyze_job(&record, request)));
        match outcome {
            Ok(Ok(())) => maybe_cleanup(&record),
            Ok(Err(error)) => {
                finish_failed(&record, error);
                maybe_cleanup(&record);
            }
            Err(payload) => {
                finish_failed(
                    &record,
                    SlimgBridgeError::Internal {
                        message: panic_message(payload),
                    },
                );
                maybe_cleanup(&record);
            }
        }
    });
}

fn run_analyze_job(record: &Arc<AnalyzeJobRecord>, request: AnalyzeFileRequest) -> Result<()> {
    let input_path = PathBuf::from(&request.input_path);
    let input_bytes = fs::read(&input_path).map_err(|error| SlimgBridgeError::Io {
        message: format!("unable to read `{}`: {error}", input_path.display()),
    })?;
    let (source_image, source_format) = decode(&input_bytes)?;
    let source_rgba = Arc::<[u8]>::from(source_image.data.clone());

    let temp_dir =
        std::env::temp_dir().join(format!("oimg-analyze-{}", record.snapshot_lock()?.job_id));
    fs::create_dir_all(&temp_dir)?;
    *record.temp_dir_lock()? = Some(temp_dir.clone());

    for quality in &request.qualities {
        if record.cancel_requested.load(Ordering::SeqCst) {
            let mut snapshot = record.snapshot_lock()?;
            snapshot.current_quality = None;
            snapshot.state = BatchJobState::Canceled;
            return Ok(());
        }

        {
            let mut snapshot = record.snapshot_lock()?;
            snapshot.current_quality = Some(*quality);
            if !matches!(snapshot.state, BatchJobState::CancelRequested) {
                snapshot.state = BatchJobState::Running;
            }
        }

        let operation = request.operation.with_quality(*quality);
        let output = run_preview_operation(&source_image, source_format, &operation, None)?;
        let pixel_match = compute_pixel_match_percentage(
            source_image.width,
            source_image.height,
            &source_rgba,
            output.width,
            output.height,
            &output.preview_rgba_bytes,
        );
        let ssimulacra2 = compute_ssimulacra2_score(
            source_image.width,
            source_image.height,
            &source_rgba,
            output.width,
            output.height,
            &output.preview_rgba_bytes,
        );
        let ms_ssim = compute_ms_ssim(
            source_image.width,
            source_image.height,
            &source_rgba,
            output.width,
            output.height,
            &output.preview_rgba_bytes,
        );

        let artifact = PreviewArtifact::new(
            source_image.width,
            source_image.height,
            output.width,
            output.height,
            source_rgba.clone(),
            Arc::<[u8]>::from(output.preview_rgba_bytes),
        );
        let _ = artifact.pixel_match_percentage.set(pixel_match);
        let _ = artifact.ms_ssim.set(ms_ssim);
        let _ = artifact.ssimulacra2.set(ssimulacra2);
        let artifact_id = preview_artifact_store().insert(artifact);
        record.artifact_ids_lock()?.push(artifact_id.clone());

        let format = format_to_string(output.format);
        let temp_output_path = temp_dir.join(format!("quality-{:03}.{format}", quality));
        fs::write(&temp_output_path, &output.data)?;

        let result = AnalyzeSampleResult {
            quality: *quality,
            temp_output_path: temp_output_path.to_string_lossy().into_owned(),
            encoded_bytes: output.data.clone(),
            format,
            width: output.width,
            height: output.height,
            size_bytes: output.data.len() as u64,
            pixel_match,
            ms_ssim,
            ssimulacra2,
            artifact_id,
        };

        let mut snapshot = record.snapshot_lock()?;
        snapshot.results.push(result);
        snapshot.completed_count = snapshot.results.len() as u32;
    }

    let mut snapshot = record.snapshot_lock()?;
    snapshot.current_quality = None;
    snapshot.state = if snapshot.state == BatchJobState::CancelRequested {
        BatchJobState::Canceled
    } else {
        BatchJobState::Completed
    };
    Ok(())
}

fn finish_failed(record: &AnalyzeJobRecord, error: SlimgBridgeError) {
    if let Ok(mut snapshot) = record.snapshot.lock() {
        snapshot.state = BatchJobState::Failed;
        snapshot.current_quality = None;
        snapshot.error = Some(error);
    }
}

fn maybe_cleanup(record: &AnalyzeJobRecord) {
    if record.dispose_requested.load(Ordering::SeqCst) {
        cleanup_resources(record);
    }
}

fn cleanup_resources(record: &AnalyzeJobRecord) {
    if let Ok(mut artifact_ids) = record.artifact_ids.lock() {
        for artifact_id in artifact_ids.drain(..) {
            preview_artifact_store().remove(&artifact_id);
        }
    }

    if let Ok(mut temp_dir) = record.temp_dir.lock() {
        if let Some(path) = temp_dir.take() {
            let _ = fs::remove_dir_all(path);
        }
    }
}

fn find_job(job_id: &str) -> Result<Arc<AnalyzeJobRecord>> {
    registry_lock()?
        .get(job_id)
        .cloned()
        .ok_or_else(|| unknown_job(job_id))
}

fn registry_lock() -> Result<MutexGuard<'static, HashMap<String, Arc<AnalyzeJobRecord>>>> {
    jobs()
        .lock()
        .map_err(|_| registry_poisoned("analyze job registry"))
}

impl AnalyzeJobRecord {
    fn snapshot_lock(&self) -> Result<MutexGuard<'_, AnalyzeFileJobSnapshot>> {
        self.snapshot
            .lock()
            .map_err(|_| registry_poisoned("analyze job snapshot"))
    }

    fn temp_dir_lock(&self) -> Result<MutexGuard<'_, Option<PathBuf>>> {
        self.temp_dir
            .lock()
            .map_err(|_| registry_poisoned("analyze job temp dir"))
    }

    fn artifact_ids_lock(&self) -> Result<MutexGuard<'_, Vec<String>>> {
        self.artifact_ids
            .lock()
            .map_err(|_| registry_poisoned("analyze job artifacts"))
    }
}

fn jobs() -> &'static Mutex<HashMap<String, Arc<AnalyzeJobRecord>>> {
    JOBS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn is_terminal(state: BatchJobState) -> bool {
    matches!(
        state,
        BatchJobState::Completed | BatchJobState::Canceled | BatchJobState::Failed
    )
}

fn unknown_job(job_id: &str) -> SlimgBridgeError {
    SlimgBridgeError::invalid_request(format!("unknown analyze job `{job_id}`"))
}

fn registry_poisoned(target: &str) -> SlimgBridgeError {
    SlimgBridgeError::Internal {
        message: format!("{target} is unavailable"),
    }
}
