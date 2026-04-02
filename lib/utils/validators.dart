class Validators {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9._]+$');
  static final RegExp _hasUppercase = RegExp(r'[A-Z]');
  static final RegExp _hasLowercase = RegExp(r'[a-z]');
  static final RegExp _hasNumber = RegExp(r'[0-9]');
  static final RegExp _hasSpecial = RegExp(r'[^A-Za-z0-9]');
  static final RegExp _hasDigit = RegExp(r'\d');

  static String? validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Email is required';
    }
    if (!_emailPattern.hasMatch(text)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    final text = value.trim();
    if (text.length < 3) {
      return 'Name must be at least 3 characters';
    }
    if (_hasDigit.hasMatch(text)) {
      return 'Name cannot contain numbers';
    }
    return null;
  }

  static String? validateLoginIdentifier(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Username or email is required';
    }
    if (text.contains('@')) {
      return validateEmail(text);
    }
    if (text.length < 3) {
      return 'Username must be at least 3 characters';
    }
    return null;
  }

  static String? validateOptionalUsername(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    if (text.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (!_usernamePattern.hasMatch(text)) {
      return 'Use letters, numbers, dot or underscore';
    }
    return null;
  }

  static String? validatePassword(
    String? value, {
    int minLength = 8,
    bool requireSpecialCharacter = true,
  }) {
    final text = value ?? '';
    if (text.trim().isEmpty) {
      return 'Password is required';
    }
    if (text.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    if (!_hasUppercase.hasMatch(text)) {
      return 'Password must include an uppercase letter';
    }
    if (!_hasLowercase.hasMatch(text)) {
      return 'Password must include a lowercase letter';
    }
    if (!_hasNumber.hasMatch(text)) {
      return 'Password must include a number';
    }
    if (requireSpecialCharacter && !_hasSpecial.hasMatch(text)) {
      return 'Password must include a special character';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    final text = value ?? '';
    if (text.trim().isEmpty) {
      return 'Confirm password is required';
    }
    if (text != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? validateSignupPassword(String? value) {
    return validatePassword(value, minLength: 8, requireSpecialCharacter: true);
  }

  static String? validateLoginPassword(String? value) {
    return validatePassword(
      value,
      minLength: 6,
      requireSpecialCharacter: false,
    );
  }
}
