import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/services/email_service.dart';

class OtpServiceException implements Exception {
  const OtpServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OtpService {
  OtpService({FirebaseFirestore? firestore, EmailService? emailService})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _emailService = emailService ?? EmailService();

  final FirebaseFirestore _firestore;
  final EmailService _emailService;

  Future<void> sendOtp(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final otp = _generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: 2));
    final otpRef = _firestore.collection('otp_codes').doc(normalizedEmail);

    await otpRef.set({
      'email': normalizedEmail,
      'otp': otp,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _emailService.sendOtpEmail(email: normalizedEmail, otp: otp);
    } catch (_) {
      await otpRef.delete();
      throw const OtpServiceException('Failed to send OTP. Try again');
    }
  }

  Future<void> resendOtp(String email) async {
    await sendOtp(email);
  }

  Future<void> verifyOtp({
    required String email,
    required String otp,
    bool consumeCode = true,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final inputOtp = otp.trim();

    try {
      final doc = await _firestore
          .collection('otp_codes')
          .doc(normalizedEmail)
          .get();
      final data = doc.data();

      if (data == null) {
        throw const OtpServiceException('OTP not found. Request a new code');
      }

      final savedOtp = (data['otp'] ?? '').toString().trim();
      final expiresAt = data['expiresAt'];

      if (savedOtp != inputOtp) {
        throw const OtpServiceException('Invalid OTP code');
      }

      if (expiresAt is! Timestamp) {
        throw const OtpServiceException('OTP has expired. Request a new code');
      }

      if (DateTime.now().isAfter(expiresAt.toDate())) {
        throw const OtpServiceException('OTP has expired. Request a new code');
      }

      if (consumeCode) {
        await _firestore.collection('otp_codes').doc(normalizedEmail).delete();
      }
    } on OtpServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      if (e.code.toLowerCase() == 'permission-denied') {
        throw const OtpServiceException(
          'Permission denied while verifying OTP. Deploy latest Firestore rules.',
        );
      }
      throw const OtpServiceException(
        'Unable to verify OTP right now. Try again',
      );
    } catch (_) {
      throw const OtpServiceException(
        'Unable to verify OTP right now. Try again',
      );
    }
  }

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }
}
