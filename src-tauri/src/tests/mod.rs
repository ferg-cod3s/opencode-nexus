#[cfg(test)]
mod auth_tests;
mod server_tests;
mod process_tests;
mod config_tests;
mod tunnel_tests;

// Common test utilities and mocks
pub(crate) mod common {
    use std::sync::Once;
    static INIT: Once = Once::new();

    pub fn setup() {
        INIT.call_once(|| {
            // Setup code that should run once for all tests
        });
    }

    pub fn cleanup() {
        // Cleanup code that should run after each test
    }
}