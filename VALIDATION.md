# Validation

Validated on November 10, 2026 using Xcode 26.0.1 (17A400), Swift 6.2, and an Apple Silicon Mac targeting macOS 26.

- Full package compiled successfully, including the live Foundation Models adapter and its guided-generation macros.
- `swift test`: 11 XCTest tests passed, 0 failures.
- Scripted executable ran successfully, selected `demo-visit-1`, and returned the expected synthetic scheduling response.
- Live inference was not run; model availability, output quality, and clinical safety are not established by these checks.
- Reviewed every published file and scanned for common credential patterns. No credentials or real patient data were found. Only synthetic fixtures and the standalone adaptation are included.

The default demo and all tests use scripted responses. They test program behavior, not model accuracy or effectiveness of medical screening.
