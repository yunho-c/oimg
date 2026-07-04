# OIMG

[OIMG](https://oimg.org) is a desktop application that helps you optimize your images using modern image formats. Save storage with OIMG!

https://github.com/user-attachments/assets/52e5a506-966d-4c02-8125-81023f0ecd5e

## Download

- [Windows](https://oimg.org/download/windows-x64) | `winget install oimg`
- [macOS](https://oimg.org/download/macos-arm64) | `brew install --cask yunho-c/tap/oimg`
- [Linux](https://oimg.org/download/linux-x64) | `curl -fsSL https://apt.oimg.org/install.sh | bash`

## Why OIMG

- OIMG bundles image encoding codecs with state-of-the-art efficiency, including `jpegli`, `oxipng`, and `libjxl`.
- OIMG integrates image quality assessment (IQA) right into your workflow, preventing over-compression.
- OIMG allows you to compare original/optimized images side-by-side and visualize errors (diffs).
- OIMG includes convenient file explorer shortcuts for one-click optimization/conversion.

## Supported Formats

- PNG
- JPEG
- WebP
- AVIF
- JPEG XL

## Architecture

OIMG is built using Flutter (frontend) and Rust (backend). It is built with SIMD optimizations enabled (for x86 and ARM CPUs) and utilizes multithreading wherever possible. 

## Contribute

OIMG is completely open source. Feel free to contribute by creating [issues](https://github.com/yunho-c/oimg/issues) or [pull requests](https://github.com/yunho-c/oimg/pulls)!
