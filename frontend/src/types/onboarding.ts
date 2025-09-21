// TypeScript representations of Rust onboarding types
// Mirrors src-tauri/src/onboarding.rs structures

export interface SystemRequirements {
  os_compatible: boolean;
  memory_sufficient: boolean;
  disk_space_sufficient: boolean;
  network_available: boolean;
  required_permissions: boolean;
}

export interface OnboardingConfig {
  is_completed: boolean;
  opencode_server_path: string | null;
  owner_account_created: boolean;
  owner_username: string | null;
  created_at: string; // ISO timestamp
  updated_at: string; // ISO timestamp
}

export interface OnboardingState {
  config: OnboardingConfig | null;
  system_requirements: SystemRequirements;
  opencode_detected: boolean;
  opencode_path: string | null;
}
