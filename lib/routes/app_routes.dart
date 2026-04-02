import 'package:flutter/material.dart';
import 'package:my_app/screens/dashboard_screen.dart';
import 'package:my_app/screens/forgot_password_screen.dart';
import 'package:my_app/screens/login_screen.dart';
import 'package:my_app/screens/otp_verification_screen.dart';
import 'package:my_app/screens/reset_password_screen.dart';
import 'package:my_app/screens/signup_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String otpVerification = '/otp-verification';

  static final Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    dashboard: (context) => const DashboardScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    resetPassword: (context) => const ResetPasswordScreen(),
    otpVerification: (context) => const OtpVerificationScreen(),
  };
}
