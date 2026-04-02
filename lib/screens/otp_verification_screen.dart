import 'package:flutter/material.dart';
import 'dart:async';
import 'package:my_app/routes/app_routes.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/otp_service.dart';
import 'package:my_app/widgets/auth_scaffold.dart';
import 'package:my_app/widgets/top_toast.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _otpService = OtpService();
  final _authService = AuthService();

  bool _isSubmitting = false;
  bool _isResending = false;
  bool _isFormValid = false;
  bool _showValidationErrors = false;
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_updateFormValidity);
  }

  void _updateFormValidity() {
    final nextValid = _otpController.text.trim().length == 6;
    if (nextValid != _isFormValid) {
      setState(() {
        _isFormValid = nextValid;
      });
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.removeListener(_updateFormValidity);
    _otpController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() {
      _resendSecondsLeft = 120;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _resendSecondsLeft = 0;
        });
        return;
      }

      setState(() {
        _resendSecondsLeft -= 1;
      });
    });
  }

  String _resendButtonText() {
    if (_isResending) {
      return 'Resending...';
    }

    if (_resendSecondsLeft > 0) {
      final minutes = _resendSecondsLeft ~/ 60;
      final seconds = (_resendSecondsLeft % 60).toString().padLeft(2, '0');
      return 'Resend OTP ($minutes:$seconds)';
    }

    return 'Resend OTP';
  }

  Future<void> _verifyOtp(String email, String flow) async {
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
      await _otpService.verifyOtp(
        email: email,
        otp: _otpController.text.trim(),
        consumeCode: flow == 'signup',
      );

      if (flow == 'forgot') {
        if (!mounted) {
          return;
        }
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.resetPassword,
          arguments: {
            'email': email,
            'verifiedByOtp': true,
            'otp': _otpController.text.trim(),
          },
        );
        return;
      }

      await _authService.markEmailVerified(email);

      if (!mounted) {
        return;
      }
      TopToast.show(context, 'Email verified successfully');
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } on OtpServiceException catch (e) {
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
      TopToast.show(context, 'Failed to verify OTP. Try again');
    }
  }

  Future<void> _resendOtp(String email) async {
    setState(() {
      _isResending = true;
    });

    try {
      await _otpService.resendOtp(email);
      if (!mounted) {
        return;
      }
      setState(() {
        _isResending = false;
      });
      _startResendCooldown();
      TopToast.show(context, 'OTP resent successfully');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isResending = false;
      });
      TopToast.show(context, 'Failed to send OTP. Try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    String email = '';
    String flow = 'signup';

    if (args is String) {
      email = args.trim();
    } else if (args is Map<String, dynamic>) {
      email = ((args['email'] as String?) ?? '').trim();
      flow = ((args['flow'] as String?) ?? 'signup').trim();
    }

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
                    Icons.verified_user_outlined,
                    size: 34,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Verify Email',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  email.isEmpty
                      ? 'Enter the 6-digit OTP sent to your email.'
                      : 'Enter the 6-digit OTP sent to $email',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'OTP Code',
                    prefixIcon: Icon(Icons.lock_outline),
                    counterText: '',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return 'OTP is required';
                    }
                    if (text.length != 6) {
                      return 'Enter a valid 6-digit OTP';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: email.isNotEmpty && _isFormValid && !_isSubmitting
                      ? () => _verifyOtp(email, flow)
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
                      : const Text('Verify OTP'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed:
                      email.isNotEmpty &&
                          !_isResending &&
                          _resendSecondsLeft == 0
                      ? () => _resendOtp(email)
                      : null,
                  child: Text(_resendButtonText()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
