import 'package:flutter/material.dart';
import 'package:my_app/routes/app_routes.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/otp_service.dart';
import 'package:my_app/utils/validators.dart';
import 'package:my_app/widgets/auth_scaffold.dart';
import 'package:my_app/widgets/top_toast.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _otpService = OtpService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _isFormValid = false;
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateFormValidity);
    _usernameController.addListener(_updateFormValidity);
    _emailController.addListener(_updateFormValidity);
    _passwordController.addListener(_updateFormValidity);
    _confirmPasswordController.addListener(_updateFormValidity);
  }

  void _updateFormValidity() {
    final hasNameError = Validators.validateName(_nameController.text) != null;
    final hasUsernameError =
        Validators.validateOptionalUsername(_usernameController.text) != null;
    final hasEmailError =
        Validators.validateEmail(_emailController.text) != null;
    final hasPasswordError =
        Validators.validateSignupPassword(_passwordController.text) != null;
    final hasConfirmPasswordError =
        Validators.validateConfirmPassword(
          _confirmPasswordController.text,
          _passwordController.text,
        ) !=
        null;
    final nextValid =
        !hasNameError &&
        !hasUsernameError &&
        !hasEmailError &&
        !hasPasswordError &&
        !hasConfirmPasswordError;

    if (nextValid != _isFormValid) {
      setState(() {
        _isFormValid = nextValid;
      });
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_updateFormValidity);
    _usernameController.removeListener(_updateFormValidity);
    _emailController.removeListener(_updateFormValidity);
    _passwordController.removeListener(_updateFormValidity);
    _confirmPasswordController.removeListener(_updateFormValidity);
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_showValidationErrors) {
      setState(() {
        _showValidationErrors = true;
      });
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = await _authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
        username: _usernameController.text,
      );

      if (!mounted) {
        return;
      }

      if (user != null) {
        await _otpService.sendOtp(_emailController.text);
        if (!mounted) {
          return;
        }
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.otpVerification,
          arguments: {
            'email': _emailController.text.trim(),
            'flow': 'signup',
          },
        );
        return;
      }

      setState(() {
        _isSubmitting = false;
      });
      TopToast.show(context, 'Unable to create account. Try again.');
    } on AuthServiceException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      TopToast.show(context, e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      TopToast.show(context, 'Failed to send OTP. Try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Card(
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: _showValidationErrors
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 34,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Set up your account in a few steps.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: Validators.validateName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username (Optional)',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: Validators.validateOptionalUsername,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: Validators.validateSignupPassword,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_isSubmitting) {
                      _createAccount();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => Validators.validateConfirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: !_isSubmitting ? _createAccount : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  },
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
