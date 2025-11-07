// Simple test
console.log('🔍 LOGIN.JS: Script is executing!');

  private bindEvents() {
    this.form.addEventListener('submit', (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.handleSubmit(e).catch(console.error);
      return false;
    });
    this.passwordToggle.addEventListener('click', this.togglePasswordVisibility.bind(this));

    // Real-time validation
    this.usernameField.addEventListener('input', () => this.validateField('username'));
    this.passwordField.addEventListener('input', () => this.validateField('password'));

    // Clear errors on focus
    this.usernameField.addEventListener('focus', () => this.clearFieldError('username'));
    this.passwordField.addEventListener('focus', () => this.clearFieldError('password'));

    // Global alert dismiss
    document.addEventListener('click', (e) => {
      if (e.target && e.target.closest('.alert-dismiss')) {
        this.dismissAlert();
      }
    });
  }

  private async checkAuthConfiguration() {
    try {
      console.log('🔍 LoginManager: Checking environment...');
      const env = checkEnvironment();
      console.log('🔍 LoginManager: Environment check:', env);

      if (!env.canAuthenticate) {
        console.log('🔍 LoginManager: Unsupported environment detected');
        this.updateSystemStatus('⚠️', 'Running in unsupported environment', 'error');
        return;
      }

      console.log('🔍 LoginManager: Checking auth configuration...');
      const isConfigured = await invoke('is_auth_configured');
      console.log('🔍 LoginManager: Auth configured:', isConfigured);

      // Check if account is locked
      console.log('🔍 LoginManager: Checking account lockout status...');
      const lockoutStatus = await invoke('is_account_locked');
      console.log('🔍 LoginManager: Account lockout status:', lockoutStatus);

      if (lockoutStatus.locked) {
        this.showAccountLocked(lockoutStatus.unlockTime);
        return;
      }

      if (!isConfigured) {
        console.log('🔍 LoginManager: Auth not configured, redirecting to /onboarding');
        this.showAlert(
          'Authentication not configured. Please complete the setup wizard first.',
          'warning',
          '⚠️'
        );

        // Redirect to onboarding after a delay
        setTimeout(() => {
          window.location.href = '/onboarding';
        }, 3000);
        return;
      }

      console.log('🔍 LoginManager: Auth configured successfully');
      this.updateSystemStatus('✓', 'Authentication configured', 'success');
    } catch (error) {
      console.error('❌ LoginManager: Failed to check auth configuration:', error);
      this.updateSystemStatus('⚠️', 'Unable to check authentication status', 'error');
    }
  }

  private async handleSubmit(event) {
    console.log('🔍 LoginManager: handleSubmit called');
    event.preventDefault();

    const username = this.usernameField.value.trim();
    const password = this.passwordField.value;

    // Validate form
    if (!this.validateForm()) {
      return;
    }

    this.setLoading(true);

    try {
      const isAuthenticated = await invoke('authenticate_user', {
        username,
        password
      });

      if (isAuthenticated) {
        console.log('🔍 LoginManager: Authentication successful for user:', username);
        this.showAlert('Login successful! Redirecting to dashboard...', 'success', '✅');

        // Store authentication state
        sessionStorage.setItem('authenticated', 'true');
        sessionStorage.setItem('username', username);

        // Redirect to dashboard
        setTimeout(() => {
          console.log('🔍 LoginManager: Redirecting to /dashboard');
          window.location.href = '/dashboard';
        }, 1500);
      } else {
        console.log('🔍 LoginManager: Authentication failed - invalid credentials');
        this.showLoginError('Invalid credentials. Please check your username and password.');
        this.setFieldError('password', 'Invalid credentials');
        this.passwordField.focus();
      }
    } catch (error) {
      console.error('Authentication error:', error);
      const errorMessage = error.toString();

      if (errorMessage.includes('Account is temporarily locked') || errorMessage.includes('Account locked')) {
        this.showAccountLocked();
      } else {
        this.showAlert(
          'Authentication failed. Please try again or contact support.',
          'error',
          '❌'
        );
      }
    } finally {
      this.setLoading(false);
    }
  }

  private validateForm() {
    let isValid = true;

    if (!this.validateField('username')) {
      isValid = false;
    }

    if (!this.validateField('password')) {
      isValid = false;
    }

    return isValid;
  }

  private validateField(fieldName) {
    const field = fieldName === 'username' ? this.usernameField : this.passwordField;
    const value = field.value.trim();

    this.clearFieldError(fieldName);

    if (!value) {
      this.setFieldError(fieldName, `${fieldName === 'username' ? 'Username' : 'Password'} is required`);
      return false;
    }

    if (fieldName === 'username' && value.length < 3) {
      this.setFieldError('username', 'Username must be at least 3 characters long');
      return false;
    }

    if (fieldName === 'password' && value.length < 8) {
      this.setFieldError('password', 'Password must be at least 8 characters long');
      return false;
    }

    return true;
  }

  private setFieldError(fieldName, message) {
    const field = fieldName === 'username' ? this.usernameField : this.passwordField;
    const errorElement = document.getElementById(`${fieldName}-error`);

    field.setAttribute('aria-invalid', 'true');
    field.classList.add('error');

    if (errorElement) {
      errorElement.textContent = message;
    }
  }

  private clearFieldError(fieldName) {
    const field = fieldName === 'username' ? this.usernameField : this.passwordField;
    const errorElement = document.getElementById(`${fieldName}-error`);

    field.setAttribute('aria-invalid', 'false');
    field.classList.remove('error');

    if (errorElement) {
      errorElement.textContent = '';
    }
  }

  private togglePasswordVisibility() {
    this.isPasswordVisible = !this.isPasswordVisible;

    this.passwordField.type = this.isPasswordVisible ? 'text' : 'password';
    this.passwordToggle.setAttribute('aria-label', this.isPasswordVisible ? 'Hide password' : 'Show password');

    const toggleIcon = this.passwordToggle.querySelector('.toggle-icon');
    if (toggleIcon) {
      toggleIcon.textContent = this.isPasswordVisible ? '🙈' : '👁️';
    }
  }

  private setLoading(loading) {
    this.loginButton.disabled = loading;
    this.loginButton.classList.toggle('loading', loading);

    if (loading) {
      this.loginButton.setAttribute('aria-busy', 'true');
    } else {
      this.loginButton.removeAttribute('aria-busy');
    }
  }

  private showAlert(message, type = 'info', icon = 'ℹ️') {
    const alertElement = document.getElementById('global-alert');
    const messageElement = alertElement?.querySelector('.alert-message');
    const iconElement = alertElement?.querySelector('.alert-icon');

    if (!alertElement || !messageElement || !iconElement) return;

    messageElement.textContent = message;
    iconElement.textContent = icon;

    alertElement.className = `global-alert ${type}`;
    alertElement.style.display = 'block';

    // Auto-dismiss after 5 seconds for success messages
    if (type === 'success') {
      setTimeout(() => this.dismissAlert(), 5000);
    }
  }

  private dismissAlert() {
    const alertElement = document.getElementById('global-alert');
    if (alertElement) {
      alertElement.style.display = 'none';
    }
  }

  private showLoginError(message) {
    const errorElement = document.getElementById('login-error');
    if (errorElement) {
      errorElement.textContent = message;
      errorElement.style.display = 'block';
      errorElement.setAttribute('aria-live', 'polite');
    }
  }

  private showAccountLocked(unlockTime) {
    const lockoutElement = document.createElement('div');
    lockoutElement.id = 'account-locked';
    lockoutElement.setAttribute('data-testid', 'account-locked');
    lockoutElement.className = 'error-message';
    lockoutElement.setAttribute('role', 'alert');
    lockoutElement.setAttribute('aria-live', 'assertive');

    let message = 'Account is temporarily locked due to too many failed attempts.';

    if (unlockTime) {
      const unlockDate = new Date(unlockTime);
      const timeLeft = Math.ceil((unlockDate.getTime() - Date.now()) / (60 * 1000));
      message += ` Try again in ${timeLeft} minutes.`;
    } else {
      message += ' Please wait 30 minutes before trying again.';
    }

    lockoutElement.textContent = message;

    // Disable login form
    const form = document.getElementById('login-form');
    if (form) {
      form.classList.add('locked');
      this.loginButton.disabled = true;
      this.usernameField.disabled = true;
      this.passwordField.disabled = true;
      form.parentNode?.insertBefore(lockoutElement, form.nextSibling);
    }

    // Add timer display
    const timerElement = document.createElement('div');
    timerElement.id = 'lockout-timer';
    timerElement.setAttribute('data-testid', 'lockout-timer');
    timerElement.className = 'lockout-timer';
    timerElement.textContent = '30:00';
    lockoutElement.appendChild(timerElement);

    // Start countdown timer
    this.startLockoutTimer(timerElement, unlockTime);
  }

  private startLockoutTimer(timerElement, unlockTime) {
    const endTime = unlockTime ? new Date(unlockTime).getTime() : Date.now() + (30 * 60 * 1000);

    const updateTimer = () => {
      const now = Date.now();
      const timeLeft = Math.max(0, endTime - now);

      const minutes = Math.floor(timeLeft / (60 * 1000));
      const seconds = Math.floor((timeLeft % (60 * 1000)) / 1000);

      timerElement.textContent = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;

      if (timeLeft > 0) {
        setTimeout(updateTimer, 1000);
      } else {
        // Timer expired, reload page to allow login again
        window.location.reload();
      }
    };

    updateTimer();
  }

  private updateSystemStatus(icon, message, type = 'info') {
    const iconElement = document.getElementById('auth-status-icon');
    const textElement = document.getElementById('auth-status-text');

    if (iconElement) iconElement.textContent = icon;
    if (textElement) {
      textElement.textContent = message;
      textElement.className = `status-text ${type}`;
    }
  }

  private focusFirstField() {
    // Focus the first empty field
    if (!this.usernameField.value) {
      this.usernameField.focus();
    } else if (!this.passwordField.value) {
      this.passwordField.focus();
    }
  }
}

// Initialize login manager when page loads
document.addEventListener('DOMContentLoaded', () => {
  console.log('🔍 Login page: DOMContentLoaded event fired');
  new LoginManager();
});

// Also try to initialize immediately if elements are already available
if (document.readyState === 'loading') {
  console.log('🔍 Login page: Document still loading, waiting for DOMContentLoaded');
  document.addEventListener('DOMContentLoaded', () => {
    console.log('🔍 Login page: DOMContentLoaded in loading state');
    if (document.getElementById('login-form')) {
      console.log('🔍 Login page: Login form found, initializing LoginManager');
      new LoginManager();
    } else {
      console.log('🔍 Login page: Login form not found');
    }
  });
} else {
  // DOM already loaded
  console.log('🔍 Login page: Document already loaded');
  if (document.getElementById('login-form')) {
    console.log('🔍 Login page: Login form found, initializing LoginManager immediately');
    new LoginManager();
  } else {
    console.log('🔍 Login page: Login form not found on immediate check');
  }
}