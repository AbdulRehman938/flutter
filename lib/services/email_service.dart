import 'dart:convert';

import 'package:http/http.dart' as http;

class EmailService {
  static const String _serviceId = 'service_psmajs8';
  static const String _templateId = 'template_piyymhg';
  static const String _publicKey = 'HxFEStoXHJRYmuPHN';

  Future<void> sendOtpEmail({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {'to_email': email, 'otp': otp},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send OTP email');
    }
  }
}
