use std::sync::atomic::{AtomicBool, Ordering};

static TIMING_LOGS_ENABLED: AtomicBool = AtomicBool::new(false);

pub(crate) fn set_timing_logs_enabled(enabled: bool) {
    TIMING_LOGS_ENABLED.store(enabled, Ordering::Relaxed);
}

pub(crate) fn timing_logs_enabled() -> bool {
    TIMING_LOGS_ENABLED.load(Ordering::Relaxed)
}

pub(crate) fn timing_log(message: impl AsRef<str>) {
    if !timing_logs_enabled() {
        return;
    }

    eprintln!("[oimg][timing] {}", message.as_ref());
}
