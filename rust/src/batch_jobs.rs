use std::collections::HashMap;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::{
    atomic::{AtomicBool, AtomicU64, Ordering},
    Arc, Mutex, MutexGuard, OnceLock,
};
use std::thread;

use crate::error::{panic_message, Result, SlimgBridgeError};
use crate::types::{BatchJobHandle, BatchJobSnapshot, BatchJobState, ProcessFileBatchRequest};

static NEXT_JOB_ID: AtomicU64 = AtomicU64::new(1);
static JOBS: OnceLock<Mutex<HashMap<String, Arc<BatchJobRecord>>>> = OnceLock::new();

struct BatchJobRecord {
    cancel_requested: AtomicBool,
    snapshot: Mutex<BatchJobSnapshot>,
}

pub(crate) fn start_process_file_batch_job(
    request: ProcessFileBatchRequest,
) -> Result<BatchJobHandle> {
    if request.requests.is_empty() {
        return Err(SlimgBridgeError::invalid_request(
            "requests must contain at least one file request",
        ));
    }

    let job_id = format!("job-{}", NEXT_JOB_ID.fetch_add(1, Ordering::Relaxed));
    let record = Arc::new(BatchJobRecord {
        cancel_requested: AtomicBool::new(false),
        snapshot: Mutex::new(BatchJobSnapshot {
            job_id: job_id.clone(),
            state: BatchJobState::Running,
            total_count: request.requests.len() as u32,
            completed_count: 0,
            current_input_path: None,
            results: Vec::with_capacity(request.requests.len()),
            error: None,
        }),
    });

    registry_lock()?.insert(job_id.clone(), record.clone());
    spawn_batch_job(record, request);

    Ok(BatchJobHandle { job_id })
}

pub(crate) fn get_process_file_batch_job(job_id: String) -> Result<BatchJobSnapshot> {
    Ok(find_job(&job_id)?.snapshot_lock()?.clone())
}

pub(crate) fn cancel_process_file_batch_job(job_id: String) -> Result<()> {
    let record = find_job(&job_id)?;
    record.cancel_requested.store(true, Ordering::SeqCst);

    let mut snapshot = record.snapshot_lock()?;
    if matches!(snapshot.state, BatchJobState::Running) {
        snapshot.state = BatchJobState::CancelRequested;
    }

    Ok(())
}

pub(crate) fn dispose_process_file_batch_job(job_id: String) -> Result<()> {
    let removed = registry_lock()?.remove(&job_id);
    if removed.is_none() {
        return Err(unknown_job(&job_id));
    }
    Ok(())
}

fn spawn_batch_job(record: Arc<BatchJobRecord>, request: ProcessFileBatchRequest) {
    thread::spawn(move || {
        let outcome = catch_unwind(AssertUnwindSafe(|| run_batch_job(&record, request)));
        match outcome {
            Ok(Ok(())) => {}
            Ok(Err(error)) => finish_failed(&record, error),
            Err(payload) => finish_failed(
                &record,
                SlimgBridgeError::Internal {
                    message: panic_message(payload),
                },
            ),
        }
    });
}

fn run_batch_job(record: &Arc<BatchJobRecord>, request: ProcessFileBatchRequest) -> Result<()> {
    let continue_on_error = request.continue_on_error;
    let items = crate::execution::build_work_items_for_process_file_batch(request)?;
    let outcome = crate::execution::execute_batch_items_with_events(
        items,
        continue_on_error,
        || record.cancel_requested.load(Ordering::SeqCst),
        |input_path| {
            if let Ok(mut snapshot) = record.snapshot_lock() {
                snapshot.current_input_path = Some(input_path.to_string());
                if !matches!(snapshot.state, BatchJobState::CancelRequested) {
                    snapshot.state = BatchJobState::Running;
                }
            }
        },
        |item| {
            if let Ok(mut snapshot) = record.snapshot_lock() {
                snapshot.results.push(item.clone());
                snapshot.completed_count = snapshot.results.len() as u32;
                snapshot.current_input_path = None;
            }
        },
    )?;

    let mut snapshot = record.snapshot_lock()?;
    snapshot.current_input_path = None;
    snapshot.state = if outcome.canceled {
        BatchJobState::Canceled
    } else {
        BatchJobState::Completed
    };
    Ok(())
}

fn finish_failed(record: &BatchJobRecord, error: SlimgBridgeError) {
    if let Ok(mut snapshot) = record.snapshot.lock() {
        snapshot.state = BatchJobState::Failed;
        snapshot.current_input_path = None;
        snapshot.error = Some(error);
    }
}

fn find_job(job_id: &str) -> Result<Arc<BatchJobRecord>> {
    registry_lock()?
        .get(job_id)
        .cloned()
        .ok_or_else(|| unknown_job(job_id))
}

fn registry_lock() -> Result<MutexGuard<'static, HashMap<String, Arc<BatchJobRecord>>>> {
    jobs()
        .lock()
        .map_err(|_| registry_poisoned("batch job registry"))
}

impl BatchJobRecord {
    fn snapshot_lock(&self) -> Result<MutexGuard<'_, BatchJobSnapshot>> {
        self.snapshot
            .lock()
            .map_err(|_| registry_poisoned("batch job snapshot"))
    }
}

fn jobs() -> &'static Mutex<HashMap<String, Arc<BatchJobRecord>>> {
    JOBS.get_or_init(|| Mutex::new(HashMap::new()))
}

fn unknown_job(job_id: &str) -> SlimgBridgeError {
    SlimgBridgeError::invalid_request(format!("unknown batch job `{job_id}`"))
}

fn registry_poisoned(target: &str) -> SlimgBridgeError {
    SlimgBridgeError::Internal {
        message: format!("{target} is unavailable"),
    }
}
