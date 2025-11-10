# Mobile Client Security Model
**Project:** OpenCode Nexus - Mobile Client
**Version:** 1.0.0
**Last Updated:** 2025-11-06
**Status:** Client Connection Security

## 1. Client Security Principles

OpenCode Nexus mobile client implements a **security-first approach** focused on protecting user data during server connections, ensuring safe AI interactions, and maintaining privacy in a mobile environment.

### 1.1 Core Security Principles

- **Connection Trust:** Verify server authenticity before data transmission
- **Data Minimization:** Collect only necessary data for AI conversations
- **End-to-End Privacy:** Protect conversation data at rest and in transit
- **Mobile Security:** Leverage platform-specific security features
- **User Control:** Transparent security settings and user consent
- **Offline Protection:** Secure local data storage and synchronization

## 2. Threat Model for Mobile Client

### 2.1 Client-Side Attack Vectors

#### 2.1.1 Network Interception
- **Man-in-the-Middle (MITM):** Interception of client-server communications
- **DNS Spoofing:** Redirecting connections to malicious servers
- **SSL Stripping:** Downgrading HTTPS to HTTP connections
- **Certificate Attacks:** Fake or compromised SSL certificates

#### 2.1.2 Data Exposure Risks
- **Local Data Theft:** Unauthorized access to cached conversations
- **Device Compromise:** Malware accessing stored credentials
- **Sync Interception:** Compromised synchronization of offline data
- **Platform Vulnerabilities:** Exploits in iOS/Android security features

#### 2.1.3 AI Interaction Risks
- **Prompt Injection:** Malicious prompts affecting AI responses
- **Data Leakage:** Sensitive information in AI conversations
- **Server Impersonation:** Fake OpenCode servers collecting data
- **Response Manipulation:** Altered AI responses from compromised servers

### 2.2 Mobile-Specific Threats

#### 2.2.1 Platform Security Risks
- **App Sandbox Escape:** Breaking out of mobile app isolation
- **Keychain/KeyStore Compromise:** Accessing stored credentials
- **Background Process Attacks:** Exploiting background sync mechanisms
- **Biometric Bypass:** Circumventing device authentication

#### 2.2.2 Network Security Risks
- **Public WiFi Attacks:** Interception on unsecured networks
- **Cellular Network Attacks:** Mobile network interception
- **VPN Bypass:** Circumventing corporate security measures
- **Zero-Rating Exploits:** Malicious free data services

## 3. Connection Security Architecture

### 3.1 SSL/TLS Implementation

#### Certificate Validation
```rust
// Strict certificate validation
pub fn validate_server_certificate(cert: &Certificate) -> Result<(), SecurityError> {
    // Check certificate validity period
    let now = SystemTime::now();
    if cert.not_before > now || cert.not_after < now {
        return Err(SecurityError::CertificateExpired);
    }

    // Verify certificate chain
    cert.verify_chain(&self.trusted_roots)?;

    // Check certificate revocation
    if self.crl_check_enabled {
        self.check_certificate_revocation(cert)?;
    }

    Ok(())
}
```

#### SSL Pinning Strategy
```rust
// Certificate pinning for known servers
pub struct ServerCertificatePin {
    pub hostname: String,
    pub pin_type: PinType,
    pub pin_value: String,
}

impl ServerCertificatePin {
    pub fn verify_pin(&self, cert: &Certificate) -> Result<(), SecurityError> {
        match self.pin_type {
            PinType::SPKI => self.verify_spki_pin(cert)?,
            PinType::Certificate => self.verify_cert_pin(cert)?,
        }
        Ok(())
    }
}
```

### 3.2 Server Authentication

#### Server Identity Verification
- **Hostname Verification:** Strict hostname matching in certificates
- **Certificate Transparency:** Log verification for certificate issuance
- **Server Fingerprinting:** Optional server fingerprint verification
- **Trust-on-First-Use:** User verification for unknown servers

#### Connection Establishment
```typescript
// Secure connection establishment
async function establishSecureConnection(serverConfig: ServerConfig): Promise<Connection> {
    // DNS resolution with DNSSEC validation
    const addresses = await resolveDnsSecure(serverConfig.hostname);

    // TCP connection with timeout
    const socket = await createSecureSocket(addresses[0], {
        timeout: 10000,
        keepAlive: true
    });

    // SSL handshake with certificate validation
    const tlsConnection = await performTlsHandshake(socket, {
        servername: serverConfig.hostname,
        rejectUnauthorized: true,
        checkServerIdentity: validateServerIdentity
    });

    return new Connection(tlsConnection);
}
```

### 3.3 API Security

#### Request Authentication

OpenCode Nexus supports multiple authentication methods for connecting to OpenCode servers, allowing users to choose the security approach that matches their deployment setup.

**Authentication Types:**
1. **No Authentication:** Local development only (unsecured)
2. **Cloudflare Access Service Tokens:** For servers behind Cloudflare Tunnel
3. **API Key Authentication:** For reverse proxy setups (e.g., nginx, Caddy)
4. **Custom Header Authentication:** Extensible for custom security implementations

```rust
/// Authentication type for connecting to OpenCode servers
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum AuthType {
    None,
    CloudflareAccess,
    ApiKey,
    CustomHeader,
}

/// Authentication credentials for server connections
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AuthCredentials {
    None,
    CloudflareAccess {
        client_id: String,
        client_secret: String, // Encrypted at rest
    },
    ApiKey {
        key: String, // Encrypted at rest
    },
    CustomHeader {
        header_name: String,
        header_value: String, // Encrypted at rest
    },
}
```

**Authentication Header Injection:**
```rust
// Centralized authentication header injection in ApiClient
fn add_auth_headers(&self, request: RequestBuilder) -> RequestBuilder {
    match (&self.auth_type, &self.auth_credentials) {
        (AuthType::CloudflareAccess, AuthCredentials::CloudflareAccess { client_id, client_secret }) => {
            request
                .header("CF-Access-Client-Id", client_id)
                .header("CF-Access-Client-Secret", client_secret)
        }
        (AuthType::ApiKey, AuthCredentials::ApiKey { key }) => {
            request.header("X-API-Key", key)
        }
        (AuthType::CustomHeader, AuthCredentials::CustomHeader { header_name, header_value }) => {
            request.header(header_name, header_value)
        }
        _ => request, // No auth
    }
}
```

**Security Notes:**
- All sensitive credentials (secrets, API keys) are encrypted at rest using platform-specific secure storage
- Cloudflare Access Service Tokens provide device-based authentication without exposing user credentials
- API keys should be rotated regularly and stored in secure key management systems
- Custom headers allow integration with enterprise authentication systems (e.g., OAuth2 bearer tokens)

#### Rate Limiting Protection
- **Client-Side Rate Limiting:** Prevent excessive API calls
- **Exponential Backoff:** Intelligent retry with server signals
- **Request Queuing:** Offline request management
- **Server Quota Awareness:** Respect API rate limits

## 4. Data Protection

### 4.1 Local Data Encryption

#### Conversation Encryption
```typescript
// AES-256 encryption for cached conversations
class ConversationCrypto {
    private key: CryptoKey;

    async encryptConversation(conversation: Conversation): Promise<EncryptedData> {
        const jsonData = JSON.stringify(conversation);
        const encodedData = new TextEncoder().encode(jsonData);

        const encrypted = await crypto.subtle.encrypt(
            { name: 'AES-GCM', iv: this.generateIv() },
            this.key,
            encodedData
        );

        return {
            data: encrypted,
            iv: this.iv,
            timestamp: Date.now()
        };
    }
}
```

#### Secure Storage Integration

**iOS Keychain Integration:**
```swift
// iOS Keychain storage
func storeCredential(credential: Credential) {
    let query: [String: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: credential.username,
        kSecValueData: credential.password.data(using: .utf8)!,
        kSecAttrAccessControl: accessControl
    ]

    SecItemAdd(query as CFDictionary, nil)
}
```

**Android Keystore Integration:**
```kotlin
// Android Keystore storage
fun storeCredential(context: Context, credential: Credential) {
    val keystore = KeyStore.getInstance("AndroidKeyStore")
    keystore.load(null)

    val keyGenerator = KeyGenerator.getInstance(
        KeyProperties.KEY_ALGORITHM_AES,
        "AndroidKeyStore"
    )

    val keySpec = KeyGenParameterSpec.Builder(
        "conversation_key",
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
    )
    .setKeySize(256)
    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
    .build()

    keyGenerator.init(keySpec)
    keyGenerator.generateKey()
}
```

### 4.2 Synchronization Security

#### Secure Sync Protocol
```typescript
// End-to-end encrypted synchronization
class SyncManager {
    async syncConversations(): Promise<void> {
        // Establish secure channel
        const syncChannel = await this.establishSyncChannel();

        // Encrypt pending changes
        const encryptedChanges = await this.encryptPendingChanges();

        // Transmit securely
        await syncChannel.send(encryptedChanges);

        // Verify server response
        const response = await syncChannel.receive();
        await this.verifySyncResponse(response);
    }
}
```

#### Conflict Resolution
- **Last-Write-Wins:** Timestamp-based conflict resolution
- **User Notification:** Alert for conflicting changes
- **Manual Resolution:** User choice for complex conflicts
- **Audit Trail:** Sync operation logging

## 5. Mobile Platform Security

### 5.1 iOS Security Features

#### App Transport Security (ATS)
```xml
<!-- iOS Info.plist ATS configuration -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
    <false/>
</dict>
```

#### Biometric Authentication
```swift
// Face ID/Touch ID integration
func authenticateWithBiometrics() async throws -> Bool {
    let context = LAContext()
    context.localizedReason = "Access your AI conversations"

    return try await context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: context.localizedReason
    )
}
```

### 5.2 Android Security Features (Planned)

#### Network Security Configuration
```xml
<!-- Android network security config -->
<network-security-config>
    <domain-config>
        <domain includeSubdomains="true">opencode.example.com</domain>
        <pin-set>
            <pin digest="SHA-256">pin1</pin>
            <pin digest="SHA-256">pin2</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

#### BiometricPrompt Integration
```kotlin
// Android biometric authentication
fun authenticateWithBiometrics(activity: AppCompatActivity) {
    val biometricPrompt = BiometricPrompt(activity,
        ContextCompat.getMainExecutor(activity),
        object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                // Authentication successful
                unlockConversations()
            }
        })

    val promptInfo = BiometricPrompt.PromptInfo.Builder()
        .setTitle("Unlock Conversations")
        .setSubtitle("Use your biometric credential")
        .setNegativeButtonText("Use password")
        .build()

    biometricPrompt.authenticate(promptInfo)
}
```

## 6. Privacy Protection

### 6.1 Data Collection Minimization

#### Minimal Data Collection
- **No Analytics Without Consent:** Optional usage analytics
- **Local Processing:** AI conversations processed locally when possible
- **Data Retention Limits:** Automatic cleanup of old conversations
- **User Data Control:** Clear data export and deletion options

#### Privacy Settings
```typescript
// Granular privacy controls
interface PrivacySettings {
    analyticsEnabled: boolean;
    crashReportingEnabled: boolean;
    conversationSyncEnabled: boolean;
    biometricUnlockEnabled: boolean;
    dataRetentionDays: number;
}
```

### 6.2 Compliance Requirements

#### GDPR Compliance
- **Data Portability:** Export conversation data in standard formats
- **Right to Deletion:** Complete data removal on request
- **Consent Management:** Clear opt-in/opt-out for data collection
- **Data Processing Transparency:** Clear privacy policy and data usage

#### Accessibility Compliance
- **Security for All:** Biometric alternatives for motor impairments
- **Screen Reader Security:** Secure access to sensitive information
- **Time Extension:** No timeouts for security-sensitive operations

## 7. Incident Response

### 7.1 Security Incident Handling

#### Breach Detection
```typescript
// Security monitoring
class SecurityMonitor {
    async detectAnomalies(): Promise<SecurityAlert[]> {
        const alerts: SecurityAlert[] = [];

        // Check for unusual connection patterns
        if (await this.detectUnusualConnections()) {
            alerts.push({
                type: 'unusual_connections',
                severity: 'medium',
                message: 'Unusual connection pattern detected'
            });
        }

        // Check for certificate changes
        if (await this.detectCertificateChanges()) {
            alerts.push({
                type: 'certificate_change',
                severity: 'high',
                message: 'Server certificate has changed'
            });
        }

        return alerts;
    }
}
```

#### Incident Response Plan
1. **Detection:** Automated monitoring and user reports
2. **Assessment:** Security team evaluation of incident scope
3. **Containment:** Disable compromised connections and features
4. **Recovery:** Restore secure connections and user data
5. **Communication:** Transparent user notification and guidance

### 7.2 User Communication

#### Security Notifications
- **Certificate Warnings:** Clear explanation of SSL issues
- **Connection Failures:** Helpful troubleshooting guidance
- **Security Updates:** Notification of security improvements
- **Privacy Changes:** Updates to privacy policy and practices

## 8. Security Testing

### 8.1 Automated Security Testing

#### SSL/TLS Testing
```bash
# SSL certificate validation testing
openssl s_client -connect opencode.example.com:443 -servername opencode.example.com
```

#### Penetration Testing
```bash
# Mobile app security testing
mobfs scan --apk OpenCode-Nexus.apk --output security-report.json
```

### 8.2 Security Monitoring

#### Runtime Security Monitoring
```typescript
// Runtime security checks
class RuntimeSecurity {
    async performSecurityChecks(): Promise<void> {
        // Check for jailbreak/root detection
        if (await this.detectJailbreak()) {
            await this.handleCompromisedDevice();
        }

        // Verify app integrity
        if (await this.detectAppTampering()) {
            await this.handleAppTampering();
        }

        // Check for debugging attempts
        if (await this.detectDebugger()) {
            await this.handleDebugDetection();
        }
    }
}
```

---

**Security Status:** Client connection security model established
**Implementation Priority:** SSL validation and local encryption</content>
<parameter name="filePath">docs/client/SECURITY.md