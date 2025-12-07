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

use crate::api_client::{ApiClient, ModelConfig, ModelInfo};
use crate::error::AppError;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, RwLock};
use tokio::sync::RwLock as AsyncRwLock;

/// Model provider configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderConfig {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub enabled: bool,
    pub models: Vec<ModelConfig>,
    pub settings: ProviderSettings,
}

/// Provider-specific settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderSettings {
    pub api_base: Option<String>,
    pub api_version: Option<String>,
    pub supports_streaming: bool,
    pub supports_functions: bool,
    pub max_tokens: Option<u32>,
    pub temperature_range: Option<TemperatureRange>,
    pub default_temperature: Option<f32>,
}

/// Temperature range for a model
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemperatureRange {
    pub min: f32,
    pub max: f32,
    pub default: f32,
}

/// Model configuration with additional metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExtendedModelConfig {
    pub provider_id: String,
    pub model_id: String,
    pub name: String,
    pub description: Option<String>,
    pub context_length: Option<u32>,
    pub input_cost_per_1k: Option<f32>,
    pub output_cost_per_1k: Option<f32>,
    pub capabilities: ModelCapabilities,
    pub settings: ModelSettings,
}

/// Model capabilities
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelCapabilities {
    pub text_generation: bool,
    pub function_calling: bool,
    pub vision: bool,
    pub streaming: bool,
    pub json_mode: bool,
    pub parallel_tools: bool,
}

/// Model-specific settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelSettings {
    pub temperature: Option<f32>,
    pub max_tokens: Option<u32>,
    pub top_p: Option<f32>,
    pub frequency_penalty: Option<f32>,
    pub presence_penalty: Option<f32>,
    pub stop_sequences: Option<Vec<String>>,
}

/// User's model preferences
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ModelPreferences {
    pub default_provider: Option<String>,
    pub default_model: Option<String>,
    pub preferred_temperature: Option<f32>,
    pub preferred_max_tokens: Option<u32>,
    pub custom_settings: HashMap<String, ModelSettings>,
}

/// Model manager for handling model configurations and preferences
pub struct ModelManager {
    api_client: Arc<ApiClient>,
    config_dir: PathBuf,
    providers: Arc<AsyncRwLock<HashMap<String, ProviderConfig>>>,
    models: Arc<AsyncRwLock<HashMap<String, ExtendedModelConfig>>>,
    preferences: Arc<RwLock<ModelPreferences>>,
}

impl ModelManager {
    /// Create a new model manager
    pub fn new(api_client: Arc<ApiClient>, config_dir: PathBuf) -> Self {
        Self {
            api_client,
            config_dir,
            providers: Arc::new(AsyncRwLock::new(HashMap::new())),
            models: Arc::new(AsyncRwLock::new(HashMap::new())),
            preferences: Arc::new(RwLock::new(ModelPreferences::default())),
        }
    }

    /// Get providers file path
    fn get_providers_file_path(&self) -> PathBuf {
        self.config_dir.join("model_providers.json")
    }

    /// Get preferences file path
    fn get_preferences_file_path(&self) -> PathBuf {
        self.config_dir.join("model_preferences.json")
    }

    /// Load provider configurations from disk
    pub async fn load_providers(&self) -> Result<(), Box<dyn std::error::Error>> {
        let providers_file = self.get_providers_file_path();

        if !providers_file.exists() {
            // Create default configuration
            self.create_default_providers().await?;
            return Ok(());
        }

        let providers_json =
            std::fs::read_to_string(&providers_file).map_err(|e| AppError::FileSystemError {
                path: providers_file.to_string_lossy().to_string(),
                message: "Failed to read providers file".to_string(),
                details: e.to_string(),
            })?;

        let loaded_providers: HashMap<String, ProviderConfig> =
            serde_json::from_str(&providers_json).map_err(|e| AppError::ParseError {
                message: "Failed to parse providers file".to_string(),
                details: Some(e.to_string()),
            })?;

        let mut providers = self.providers.write().await;
        *providers = loaded_providers;

        Ok(())
    }

    /// Save provider configurations to disk
    pub async fn save_providers(&self) -> Result<(), Box<dyn std::error::Error>> {
        let providers = self.providers.read().await;
        let providers_json =
            serde_json::to_string_pretty(&*providers).map_err(|e| AppError::ParseError {
                message: "Failed to serialize providers".to_string(),
                details: Some(e.to_string()),
            })?;

        std::fs::write(self.get_providers_file_path(), providers_json).map_err(|e| {
            AppError::FileSystemError {
                path: self.get_providers_file_path().to_string_lossy().to_string(),
                message: "Failed to write providers file".to_string(),
                details: e.to_string(),
            }
        })?;

        Ok(())
    }

    /// Load user preferences from disk
    pub fn load_preferences(&self) -> Result<(), Box<dyn std::error::Error>> {
        let preferences_file = self.get_preferences_file_path();

        if !preferences_file.exists() {
            return Ok(()); // Use defaults
        }

        let preferences_json =
            std::fs::read_to_string(&preferences_file).map_err(|e| AppError::FileSystemError {
                path: preferences_file.to_string_lossy().to_string(),
                message: "Failed to read preferences file".to_string(),
                details: e.to_string(),
            })?;

        let loaded_preferences: ModelPreferences = serde_json::from_str(&preferences_json)
            .map_err(|e| AppError::ParseError {
                message: "Failed to parse preferences file".to_string(),
                details: Some(e.to_string()),
            })?;

        let mut preferences = self.preferences.write().unwrap();
        *preferences = loaded_preferences;

        Ok(())
    }

    /// Save user preferences to disk
    pub fn save_preferences(&self) -> Result<(), Box<dyn std::error::Error>> {
        let preferences = self.preferences.read().unwrap();
        let preferences_json =
            serde_json::to_string_pretty(&*preferences).map_err(|e| AppError::ParseError {
                message: "Failed to serialize preferences".to_string(),
                details: Some(e.to_string()),
            })?;

        std::fs::write(self.get_preferences_file_path(), preferences_json).map_err(|e| {
            AppError::FileSystemError {
                path: self
                    .get_preferences_file_path()
                    .to_string_lossy()
                    .to_string(),
                message: "Failed to write preferences file".to_string(),
                details: e.to_string(),
            }
        })?;

        Ok(())
    }

    /// Fetch available models from server
    pub async fn fetch_available_models(
        &self,
    ) -> Result<Vec<ModelInfo>, Box<dyn std::error::Error>> {
        self.api_client.get_available_models().await
    }

    /// Get all available models
    pub async fn get_available_models(
        &self,
    ) -> Result<Vec<ExtendedModelConfig>, Box<dyn std::error::Error>> {
        let models = self.models.read().await;
        Ok(models.values().cloned().collect())
    }

    /// Get models for a specific provider
    pub async fn get_provider_models(
        &self,
        provider_id: &str,
    ) -> Result<Vec<ExtendedModelConfig>, Box<dyn std::error::Error>> {
        let models = self.models.read().await;
        Ok(models
            .values()
            .filter(|m| m.provider_id == provider_id)
            .cloned()
            .collect())
    }

    /// Get model by ID
    pub async fn get_model(
        &self,
        model_id: &str,
    ) -> Result<Option<ExtendedModelConfig>, Box<dyn std::error::Error>> {
        let models = self.models.read().await;
        Ok(models.get(model_id).cloned())
    }

    /// Get default model configuration
    pub async fn get_default_model(
        &self,
    ) -> Result<Option<ModelConfig>, Box<dyn std::error::Error>> {
        let preferences = self.preferences.read().unwrap();

        if let (Some(provider_id), Some(model_id)) =
            (&preferences.default_provider, &preferences.default_model)
        {
            Ok(Some(ModelConfig {
                provider_id: provider_id.clone(),
                model_id: model_id.clone(),
            }))
        } else {
            // Fallback to first available model
            let models = self.models.read().await;
            if let Some((_, model)) = models.iter().next() {
                Ok(Some(ModelConfig {
                    provider_id: model.provider_id.clone(),
                    model_id: model.model_id.clone(),
                }))
            } else {
                Ok(None)
            }
        }
    }

    /// Set default model
    pub fn set_default_model(
        &self,
        provider_id: String,
        model_id: String,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut preferences = self.preferences.write().unwrap();
        preferences.default_provider = Some(provider_id);
        preferences.default_model = Some(model_id);
        drop(preferences);

        self.save_preferences()
    }

    /// Get model settings for a specific model
    pub fn get_model_settings(&self, model_id: &str) -> ModelSettings {
        let preferences = self.preferences.read().unwrap();
        preferences
            .custom_settings
            .get(model_id)
            .cloned()
            .unwrap_or_default()
    }

    /// Set model settings for a specific model
    pub fn set_model_settings(
        &self,
        model_id: String,
        settings: ModelSettings,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut preferences = self.preferences.write().unwrap();
        preferences
            .custom_settings
            .insert(model_id.clone(), settings);
        drop(preferences);

        self.save_preferences()
    }

    /// Get user preferences
    pub fn get_preferences(&self) -> ModelPreferences {
        self.preferences.read().unwrap().clone()
    }

    /// Update user preferences
    pub fn update_preferences(
        &self,
        updates: ModelPreferences,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut preferences = self.preferences.write().unwrap();
        *preferences = updates;
        drop(preferences);

        self.save_preferences()
    }

    /// Create default provider configurations
    async fn create_default_providers(&self) -> Result<(), Box<dyn std::error::Error>> {
        let mut providers = HashMap::new();

        // Anthropic provider
        providers.insert(
            "anthropic".to_string(),
            ProviderConfig {
                id: "anthropic".to_string(),
                name: "Anthropic".to_string(),
                description: Some("Claude models from Anthropic".to_string()),
                enabled: true,
                models: vec![
                    ModelConfig {
                        provider_id: "anthropic".to_string(),
                        model_id: "claude-3-5-sonnet-20241022".to_string(),
                    },
                    ModelConfig {
                        provider_id: "anthropic".to_string(),
                        model_id: "claude-3-opus-20240229".to_string(),
                    },
                ],
                settings: ProviderSettings {
                    api_base: Some("https://api.anthropic.com".to_string()),
                    api_version: Some("2023-06-01".to_string()),
                    supports_streaming: true,
                    supports_functions: true,
                    max_tokens: Some(4096),
                    temperature_range: Some(TemperatureRange {
                        min: 0.0,
                        max: 1.0,
                        default: 0.7,
                    }),
                    default_temperature: Some(0.7),
                },
            },
        );

        // OpenAI provider
        providers.insert(
            "openai".to_string(),
            ProviderConfig {
                id: "openai".to_string(),
                name: "OpenAI".to_string(),
                description: Some("GPT models from OpenAI".to_string()),
                enabled: true,
                models: vec![
                    ModelConfig {
                        provider_id: "openai".to_string(),
                        model_id: "gpt-4o".to_string(),
                    },
                    ModelConfig {
                        provider_id: "openai".to_string(),
                        model_id: "gpt-4-turbo".to_string(),
                    },
                ],
                settings: ProviderSettings {
                    api_base: Some("https://api.openai.com".to_string()),
                    api_version: Some("v1".to_string()),
                    supports_streaming: true,
                    supports_functions: true,
                    max_tokens: Some(4096),
                    temperature_range: Some(TemperatureRange {
                        min: 0.0,
                        max: 2.0,
                        default: 0.7,
                    }),
                    default_temperature: Some(0.7),
                },
            },
        );

        let mut provider_guard = self.providers.write().await;
        *provider_guard = providers;
        drop(provider_guard);

        self.save_providers().await
    }

    /// Update models from server information
    pub async fn update_models_from_server(
        &self,
        server_models: Vec<ModelInfo>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut models = HashMap::new();
        let providers = self.providers.read().await;

        for model_info in server_models {
            let provider_config = providers.get(&model_info.provider_id);

            let extended_model = ExtendedModelConfig {
                provider_id: model_info.provider_id.clone(),
                model_id: model_info.model_id.clone(),
                name: model_info.name,
                description: None,
                context_length: provider_config.and_then(|p| p.settings.max_tokens),
                input_cost_per_1k: None,
                output_cost_per_1k: None,
                capabilities: ModelCapabilities {
                    text_generation: true,
                    function_calling: provider_config
                        .map(|p| p.settings.supports_functions)
                        .unwrap_or(false),
                    vision: false, // Would need server info
                    streaming: provider_config
                        .map(|p| p.settings.supports_streaming)
                        .unwrap_or(false),
                    json_mode: true,       // Assume most models support this
                    parallel_tools: false, // Would need server info
                },
                settings: ModelSettings::default(),
            };

            models.insert(
                format!("{}/{}", model_info.provider_id, model_info.model_id),
                extended_model,
            );
        }

        let mut model_guard = self.models.write().await;
        *model_guard = models;
        drop(model_guard);

        Ok(())
    }

    /// Get all providers
    pub async fn get_providers(&self) -> Result<Vec<ProviderConfig>, Box<dyn std::error::Error>> {
        let providers = self.providers.read().await;
        Ok(providers.values().cloned().collect())
    }

    /// Enable/disable a provider
    pub async fn set_provider_enabled(
        &self,
        provider_id: &str,
        enabled: bool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut providers = self.providers.write().await;

        if let Some(provider) = providers.get_mut(provider_id) {
            provider.enabled = enabled;
            drop(providers);

            self.save_providers().await
        } else {
            Err(AppError::ValidationError {
                field: "provider_id".to_string(),
                message: format!("Provider '{}' not found", provider_id),
            }
            .into())
        }
    }
}

impl Default for ModelPreferences {
    fn default() -> Self {
        Self {
            default_provider: None,
            default_model: None,
            preferred_temperature: Some(0.7),
            preferred_max_tokens: Some(2048),
            custom_settings: HashMap::new(),
        }
    }
}

impl Default for ModelSettings {
    fn default() -> Self {
        Self {
            temperature: None,
            max_tokens: None,
            top_p: None,
            frequency_penalty: None,
            presence_penalty: None,
            stop_sequences: None,
        }
    }
}

impl Default for ModelCapabilities {
    fn default() -> Self {
        Self {
            text_generation: true,
            function_calling: false,
            vision: false,
            streaming: false,
            json_mode: true,
            parallel_tools: false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api_client::ApiClient;
    use tempfile::TempDir;

    fn create_test_model_manager() -> (ModelManager, TempDir) {
        let temp_dir = TempDir::new().expect("Failed to create temp dir");
        let config_path = temp_dir.path().to_path_buf();
        let api_client = Arc::new(ApiClient::new().expect("Failed to create ApiClient"));
        let manager = ModelManager::new(api_client, config_path);
        (manager, temp_dir)
    }

    #[tokio::test]
    async fn test_model_manager_creation() {
        let (manager, _temp) = create_test_model_manager();

        // Should be able to load preferences (creates defaults if not exists)
        let result = manager.load_preferences();
        assert!(result.is_ok(), "Should load preferences");
    }

    #[tokio::test]
    async fn test_default_providers_creation() {
        let (manager, _temp) = create_test_model_manager();

        // Create default providers
        manager
            .create_default_providers()
            .await
            .expect("Should create default providers");

        // Check providers exist
        let providers = manager.get_providers().await.expect("Should get providers");
        assert!(providers.len() >= 2); // At least Anthropic and OpenAI

        let provider_ids: Vec<String> = providers.iter().map(|p| p.id.clone()).collect();
        assert!(provider_ids.contains(&"anthropic".to_string()));
        assert!(provider_ids.contains(&"openai".to_string()));
    }

    #[test]
    fn test_model_preferences_serialization() {
        let preferences = ModelPreferences {
            default_provider: Some("anthropic".to_string()),
            default_model: Some("claude-3-5-sonnet-20241022".to_string()),
            preferred_temperature: Some(0.8),
            preferred_max_tokens: Some(4096),
            custom_settings: {
                let mut settings = HashMap::new();
                settings.insert(
                    "anthropic/claude-3-5-sonnet-20241022".to_string(),
                    ModelSettings {
                        temperature: Some(0.9),
                        max_tokens: Some(8192),
                        top_p: None,
                        frequency_penalty: None,
                        presence_penalty: None,
                        stop_sequences: None,
                    },
                );
                settings
            },
        };

        let json = serde_json::to_string(&preferences).expect("Should serialize preferences");
        assert!(json.contains("anthropic"));
        assert!(json.contains("claude-3-5-sonnet-20241022"));

        let deserialized: ModelPreferences =
            serde_json::from_str(&json).expect("Should deserialize preferences");
        assert_eq!(deserialized.default_provider, Some("anthropic".to_string()));
        assert_eq!(deserialized.preferred_temperature, Some(0.8));
    }

    #[test]
    fn test_provider_config_serialization() {
        let config = ProviderConfig {
            id: "test-provider".to_string(),
            name: "Test Provider".to_string(),
            description: Some("A test provider".to_string()),
            enabled: true,
            models: vec![ModelConfig {
                provider_id: "test-provider".to_string(),
                model_id: "test-model".to_string(),
            }],
            settings: ProviderSettings {
                api_base: Some("https://api.test.com".to_string()),
                api_version: Some("v1".to_string()),
                supports_streaming: true,
                supports_functions: false,
                max_tokens: Some(2048),
                temperature_range: Some(TemperatureRange {
                    min: 0.0,
                    max: 1.0,
                    default: 0.5,
                }),
                default_temperature: Some(0.5),
            },
        };

        let json = serde_json::to_string(&config).expect("Should serialize ProviderConfig");
        assert!(json.contains("test-provider"));
        assert!(json.contains("Test Provider"));

        let deserialized: ProviderConfig =
            serde_json::from_str(&json).expect("Should deserialize ProviderConfig");
        assert_eq!(deserialized.id, "test-provider");
        assert_eq!(deserialized.name, "Test Provider");
        assert!(deserialized.enabled);
    }

    #[tokio::test]
    async fn test_default_model_selection() {
        let (manager, _temp) = create_test_model_manager();

        // Initially no default model
        let default = manager
            .get_default_model()
            .await
            .expect("Should get default model");
        assert!(default.is_none());

        // Set default model
        manager
            .set_default_model(
                "anthropic".to_string(),
                "claude-3-5-sonnet-20241022".to_string(),
            )
            .expect("Should set default model");

        // Should now have default model
        let default = manager
            .get_default_model()
            .await
            .expect("Should get default model");
        assert!(default.is_some());

        let model_config = default.unwrap();
        assert_eq!(model_config.provider_id, "anthropic");
        assert_eq!(model_config.model_id, "claude-3-5-sonnet-20241022");
    }

    #[tokio::test]
    async fn test_model_settings_management() {
        let (manager, _temp) = create_test_model_manager();

        let model_id = "test-model";

        // Initially default settings
        let settings = manager.get_model_settings(model_id);
        assert!(settings.temperature.is_none());
        assert!(settings.max_tokens.is_none());

        // Set custom settings
        let custom_settings = ModelSettings {
            temperature: Some(0.9),
            max_tokens: Some(4096),
            top_p: Some(0.95),
            frequency_penalty: Some(0.1),
            presence_penalty: Some(0.1),
            stop_sequences: Some(vec!["</stop>".to_string()]),
        };

        manager
            .set_model_settings(model_id.to_string(), custom_settings.clone())
            .expect("Should set model settings");

        // Should get custom settings
        let retrieved_settings = manager.get_model_settings(model_id);
        assert_eq!(retrieved_settings.temperature, Some(0.9));
        assert_eq!(retrieved_settings.max_tokens, Some(4096));
        assert_eq!(retrieved_settings.top_p, Some(0.95));
    }

    #[tokio::test]
    async fn test_provider_models_filtering() {
        let (manager, _temp) = create_test_model_manager();

        // Create some test models
        let mut models = HashMap::new();
        models.insert(
            "anthropic/claude-3-5-sonnet".to_string(),
            ExtendedModelConfig {
                provider_id: "anthropic".to_string(),
                model_id: "claude-3-5-sonnet".to_string(),
                name: "Claude 3.5 Sonnet".to_string(),
                description: None,
                context_length: None,
                input_cost_per_1k: None,
                output_cost_per_1k: None,
                capabilities: ModelCapabilities::default(),
                settings: ModelSettings::default(),
            },
        );

        models.insert(
            "openai/gpt-4".to_string(),
            ExtendedModelConfig {
                provider_id: "openai".to_string(),
                model_id: "gpt-4".to_string(),
                name: "GPT-4".to_string(),
                description: None,
                context_length: None,
                input_cost_per_1k: None,
                output_cost_per_1k: None,
                capabilities: ModelCapabilities::default(),
                settings: ModelSettings::default(),
            },
        );

        let mut model_guard = manager.models.write().await;
        *model_guard = models;
        drop(model_guard);

        // Get Anthropic models
        let anthropic_models = manager
            .get_provider_models("anthropic")
            .await
            .expect("Should get Anthropic models");
        assert_eq!(anthropic_models.len(), 1);
        assert_eq!(anthropic_models[0].provider_id, "anthropic");

        // Get OpenAI models
        let openai_models = manager
            .get_provider_models("openai")
            .await
            .expect("Should get OpenAI models");
        assert_eq!(openai_models.len(), 1);
        assert_eq!(openai_models[0].provider_id, "openai");
    }

    #[test]
    fn test_model_capabilities_default() {
        let capabilities = ModelCapabilities::default();
        assert!(capabilities.text_generation);
        assert!(!capabilities.function_calling);
        assert!(!capabilities.vision);
        assert!(!capabilities.streaming);
        assert!(capabilities.json_mode);
        assert!(!capabilities.parallel_tools);
    }

    #[test]
    fn test_temperature_range() {
        let range = TemperatureRange {
            min: 0.0,
            max: 1.0,
            default: 0.7,
        };

        assert_eq!(range.min, 0.0);
        assert_eq!(range.max, 1.0);
        assert_eq!(range.default, 0.7);
    }
}
