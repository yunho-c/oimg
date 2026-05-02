use std::env;
use std::fs;
use std::path::PathBuf;

use serde_json::{json, Value};

const DEFAULT_SETTINGS: &str = r#"{"compressionMethod":"lossy","compressionPriority":"compatibility","advancedMode":false,"preferredCodec":"jpeg","quality":80}"#;

fn main() {
    let mut args = env::args().skip(1);
    let Some(command) = args.next() else {
        print_usage_and_exit();
    };

    let paths = args.collect::<Vec<_>>();
    if paths.is_empty() {
        print_usage_and_exit();
    }

    let (action, settings) = match command.as_str() {
        "compress" => ("compress", load_settings()),
        "compress-lossless" => (
            "compress",
            json!({
                "compressionMethod": "lossless",
                "compressionPriority": "compatibility",
                "advancedMode": false,
                "preferredCodec": "png",
                "quality": 100,
            }),
        ),
        _ => print_usage_and_exit(),
    };

    let request = json!({
        "action": action,
        "paths": paths,
        "settings": settings,
    });
    let response = oimg_rust::service_ffi::run_request_json(&request.to_string());
    println!("{response}");

    let success = serde_json::from_str::<Value>(&response)
        .ok()
        .and_then(|value| value.get("failure_count").and_then(Value::as_u64))
        .is_some_and(|failure_count| failure_count == 0);
    if !success {
        std::process::exit(1);
    }
}

fn print_usage_and_exit() -> ! {
    eprintln!("usage: oimg-service <compress|compress-lossless> <image> [image...]");
    std::process::exit(2);
}

fn load_settings() -> Value {
    let Some(path) = settings_path() else {
        return default_settings();
    };
    let Ok(raw_preferences) = fs::read_to_string(path) else {
        return default_settings();
    };
    let Ok(preferences) = serde_json::from_str::<Value>(&raw_preferences) else {
        return default_settings();
    };
    let Some(raw_settings) = preferences.get("app_settings").and_then(Value::as_str) else {
        return default_settings();
    };

    serde_json::from_str(raw_settings).unwrap_or_else(|_| default_settings())
}

fn default_settings() -> Value {
    serde_json::from_str(DEFAULT_SETTINGS).expect("default settings JSON should be valid")
}

fn settings_path() -> Option<PathBuf> {
    if let Some(data_home) = env::var_os("XDG_DATA_HOME") {
        return Some(PathBuf::from(data_home).join("oimg/shared_preferences.json"));
    }

    env::var_os("HOME")
        .map(PathBuf::from)
        .map(|home| home.join(".local/share/oimg/shared_preferences.json"))
}
