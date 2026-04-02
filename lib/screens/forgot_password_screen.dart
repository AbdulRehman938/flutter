import 'package:flutter/material.dart';
import 'package:my_app/routes/app_routes.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/utils/validators.dart';
import 'package:my_app/widgets/auth_scaffold.dart';
import 'package:my_app/widgets/top_toast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isSubmitting = false;
  bool _isFormValid = false;
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_updateFormValidity);
  }

  void _updateFormValidity() {
    final hasEmailError =
        Validators.validateEmail(_emailController.text) != null;
    final nextValid = !hasEmailError;
    if (nextValid != _isFormValid) {
      setState(() {
        _isFormValid = nextValid;
      });
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_updateFormValidity);
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _continueFlow() async {
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
      await _authService.sendPasswordResetEmail(_emailController.text);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      TopToast.show(context, 'Reset link sent to your email');
      Navigator.pushReplacementNamed(context, AppRoutes.login);
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
      TopToast.show(context, 'Something went wrong. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Card(
        elevation: 0,
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
                    Icons.key_rounded,
                    size: 34,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Forgot Password',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email to receive a reset link.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (_isFormValid && !_isSubmitting) {
                      _continueFlow();
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isFormValid && !_isSubmitting
                      ? _continueFlow
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
                      : const Text('Send Reset Link'),
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
