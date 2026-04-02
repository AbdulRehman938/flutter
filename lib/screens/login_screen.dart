import 'package:flutter/material.dart';
import 'package:my_app/routes/app_routes.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/otp_service.dart';
import 'package:my_app/utils/validators.dart';
import 'package:my_app/widgets/auth_scaffold.dart';
import 'package:my_app/widgets/top_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _otpService = OtpService();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isSendingVerificationOtp = false;
  bool _isFormValid = false;
  bool _showValidationErrors = false;
  String? _verificationEmail;

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(_updateFormValidity);
    _passwordController.addListener(_updateFormValidity);
  }

  void _updateFormValidity() {
    final hasIdentifierError =
        Validators.validateLoginIdentifier(_identifierController.text) != null;
    final hasPasswordError =
        Validators.validateLoginPassword(_passwordController.text) != null;
    final nextValid = !hasIdentifierError && !hasPasswordError;
    if (nextValid != _isFormValid) {
      setState(() {
        _isFormValid = nextValid;
      });
    }
  }

  void _showAuthError(String message) {
    TopToast.show(context, message);
  }

  @override
  void dispose() {
    _identifierController.removeListener(_updateFormValidity);
    _passwordController.removeListener(_updateFormValidity);
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
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
      final user = await _authService.login(
        identifier: _identifierController.text,
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _verificationEmail = null;
      });

      if (user != null) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    } on AuthServiceException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _verificationEmail = e.requiresVerification
            ? e.verificationEmail
            : null;
      });
      _showAuthError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      _showAuthError('Something went wrong. Try again.');
    }
  }

  Future<void> _verifyEmailNow() async {
    final email = _verificationEmail;
    if (email == null || email.isEmpty) {
      _showAuthError('Please verify your credentials again');
      return;
    }

    setState(() {
      _isSendingVerificationOtp = true;
    });

    try {
      await _otpService.sendOtp(email);
      if (!mounted) {
        return;
      }
      setState(() {
        _isSendingVerificationOtp = false;
      });
      Navigator.pushNamed(
        context,
        AppRoutes.otpVerification,
        arguments: {'email': email, 'flow': 'login'},
      );
    } on OtpServiceException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSendingVerificationOtp = false;
      });
      _showAuthError(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSendingVerificationOtp = false;
      });
      _showAuthError('Failed to send OTP. Try again');
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
                    Icons.lock_person_rounded,
                    size: 34,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue to your workspace.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _identifierController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email or Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: Validators.validateLoginIdentifier,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
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
                  validator: Validators.validateLoginPassword,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.forgotPassword);
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isFormValid && !_isSubmitting
                      ? _handleLogin
                      : null,
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
                      : const Text('Login'),
                ),
                if (_verificationEmail != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _isSendingVerificationOtp
                        ? null
                        : _verifyEmailNow,
                    child: _isSendingVerificationOtp
                        ? const Text('Sending OTP...')
                        : const Text('Verify Email'),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.signup);
                  },
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
