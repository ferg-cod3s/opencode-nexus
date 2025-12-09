// MIT License
//
// Copyright (c) 2025 OpenCode Nexus Contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    // Initialize Sentry for error monitoring
    let _guard = sentry::init((
        "https://f7ded2177f996e519be91651f05d38a3@sentry.fergify.work/16",
        sentry::ClientOptions {
            release: sentry::release_name!(),
            environment: Some("production".into()),
            send_default_pii: true,
            // Privacy filtering - remove sensitive data
            before_send: Some(std::sync::Arc::new(|mut event| {
                // Remove potentially sensitive information
                event.server_name = None;
                event.user = None;

                // Sanitize any file paths that might contain user data
                for exception in &mut event.exception {
                    if let Some(ref mut stacktrace) = exception.stacktrace {
                        for frame in &mut stacktrace.frames {
                            // Remove or sanitize file paths
                            if let Some(ref filename) = frame.filename {
                                let filename_str = filename.as_str();
                                // Replace user home directory with generic placeholder
                                if filename_str.contains("/Users/")
                                    || filename_str.contains("\\Users\\")
                                    || filename_str.contains("/home/")
                                {
                                    frame.filename = Some("[USER_DIR]/sanitized_path".to_string());
                                }
                            }
                        }
                    }
                }

                Some(event)
            })),
            ..Default::default()
        },
    ));

    // Add context for better error reporting
    sentry::configure_scope(|scope| {
        scope.set_tag("app", "opencode-nexus");
        scope.set_tag("component", "backend");
        scope.set_tag("os", std::env::consts::OS);
        scope.set_tag("arch", std::env::consts::ARCH);
    });

    // Setup custom panic hook for crash reporting
    src_tauri_lib::setup_panic_hook();

    src_tauri_lib::run()
}
