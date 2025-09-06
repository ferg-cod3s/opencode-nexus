// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    // Initialize Sentry for error monitoring
    let _guard = sentry::init((
        "https://27a3e3d68747cda91305b45e394f768e@sentry.fergify.work/14",
        sentry::ClientOptions {
            release: sentry::release_name!(),
            environment: Some("production".into()),
            send_default_pii: false,
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
                                if filename_str.contains("/Users/") || filename_str.contains("\\Users\\") ||
                                   filename_str.contains("/home/") {
                                    frame.filename = Some("[USER_DIR]/sanitized_path".to_string());
                                }
                            }
                        }
                    }
                }

                Some(event)
            })),
            ..Default::default()
        }
    ));

    // Add context for better error reporting
    sentry::configure_scope(|scope| {
        scope.set_tag("app", "opencode-nexus");
        scope.set_tag("component", "backend");
        scope.set_tag("os", std::env::consts::OS);
        scope.set_tag("arch", std::env::consts::ARCH);
    });

    src_tauri_lib::run()
}
