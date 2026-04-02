import 'package:flutter/material.dart';
import 'package:my_app/routes/app_routes.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/utils/validators.dart';
import 'package:my_app/widgets/auth_scaffold.dart';
import 'package:my_app/widgets/top_toast.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _isFormValid = false;
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_updateFormValidity);
    _confirmPasswordController.addListener(_updateFormValidity);
  }

  void _updateFormValidity() {
    final hasPasswordError =
        Validators.validateSignupPassword(_newPasswordController.text) != null;
    final hasConfirmPasswordError =
        Validators.validateConfirmPassword(
          _confirmPasswordController.text,
          _newPasswordController.text,
        ) !=
        null;

    final nextValid = !hasPasswordError && !hasConfirmPasswordError;
    if (nextValid != _isFormValid) {
      setState(() {
        _isFormValid = nextValid;
      });
    }
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_updateFormValidity);
    _confirmPasswordController.removeListener(_updateFormValidity);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
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

    final code = _resolveResetCode();
    if (code == null || code.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      TopToast.show(context, 'Open reset link from your email first');
      return;
    }

    try {
      await _authService.confirmPasswordReset(
        code: code,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      TopToast.show(context, 'Password updated successfully');
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

  String? _resolveResetCode() {
    final fromUrl = Uri.base.queryParameters['oobCode'];
    if (fromUrl != null && fromUrl.isNotEmpty) {
      return fromUrl;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final code = args['oobCode'] as String?;
      if (code != null && code.isNotEmpty) {
        return code;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    String identifier = '';

    if (args is String) {
      identifier = args;
    } else if (args is Map) {
      identifier = (args['email'] ?? '').toString();
    }

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
                    Icons.lock_reset,
                    size: 34,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Create New Password',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  identifier.isEmpty
                      ? 'Open your email reset link, then set a new password.'
                      : 'Open the reset link from $identifier, then set a new password.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                      icon: Icon(
                        _obscureNewPassword
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
                    if (_isFormValid && !_isSubmitting) {
                      _savePassword();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
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
                    _newPasswordController.text,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isFormValid && !_isSubmitting
                      ? _savePassword
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
                      : const Text('Save Password'),
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
