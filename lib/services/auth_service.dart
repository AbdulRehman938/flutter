import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_app/firebase_options.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(
    this.message, {
    this.requiresVerification = false,
    this.verificationEmail,
  });

  final String message;
  final bool requiresVerification;
  final String? verificationEmail;

  @override
  String toString() => message;
}

class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.username,
    required this.createdAt,
  });

  final String fullName;
  final String email;
  final String? username;
  final DateTime? createdAt;
}

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<User?> signUp({
    required String email,
    required String password,
    required String fullName,
    String? username,
  }) async {
    User? createdUser;

    try {
      await _ensureFirebaseInitialized();

      final normalizedEmail = email.trim().toLowerCase();
      final usernameValue = username?.trim() ?? '';
      final normalizedUsername = usernameValue.isEmpty
          ? null
          : usernameValue.toLowerCase();

      if (normalizedUsername != null) {
        final usernameDoc = await _firestore
            .collection('usernames')
            .doc(normalizedUsername)
            .get();
        if (usernameDoc.exists) {
          throw const AuthServiceException('Username already exists');
        }
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return null;
      }
      createdUser = user;

      final userRef = _firestore.collection('users').doc(user.uid);
      final emailRef = _firestore.collection('emails').doc(normalizedEmail);
      final usernameRef = normalizedUsername == null
          ? null
          : _firestore.collection('usernames').doc(normalizedUsername);

      await _firestore.runTransaction((transaction) async {
        final existingEmail = await transaction.get(emailRef);
        if (existingEmail.exists) {
          throw const AuthServiceException('Email already exists');
        }

        if (usernameRef != null) {
          final existingUsername = await transaction.get(usernameRef);
          if (existingUsername.exists) {
            throw const AuthServiceException('Username already exists');
          }
        }

        transaction.set(userRef, {
          'uid': user.uid,
          'fullName': fullName.trim(),
          'email': normalizedEmail,
          'username': usernameValue.isEmpty ? null : usernameValue,
          'usernameLower': normalizedUsername,
          'isEmailVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(emailRef, {
          'uid': user.uid,
          'email': normalizedEmail,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (usernameRef != null) {
          transaction.set(usernameRef, {
            'uid': user.uid,
            'username': usernameValue,
            'usernameLower': normalizedUsername,
            'email': normalizedEmail,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      return user;
    } on AuthServiceException {
      await _safeDeleteUser(createdUser);
      rethrow;
    } on FirebaseAuthException catch (e) {
      await _safeDeleteUser(createdUser);
      throw AuthServiceException(_mapFirebaseAuthError(e.code));
    } on FirebaseException catch (e) {
      await _safeDeleteUser(createdUser);
      throw AuthServiceException(_mapFirestoreError(e.code));
    } catch (_) {
      await _safeDeleteUser(createdUser);
      throw const AuthServiceException('Something went wrong. Try again.');
    }
  }

  Future<User?> login({
    required String identifier,
    required String password,
  }) async {
    try {
      await _ensureFirebaseInitialized();

      final loginIdentifier = identifier.trim();
      String emailToUse;

      if (loginIdentifier.contains('@')) {
        emailToUse = loginIdentifier.toLowerCase();
      } else {
        final usernameDoc = await _firestore
            .collection('usernames')
            .doc(loginIdentifier.toLowerCase())
            .get();

        if (!usernameDoc.exists) {
          throw const AuthServiceException('No account found');
        }

        final resolvedEmail = (usernameDoc.data()?['email'] as String?)?.trim();
        if (resolvedEmail == null || resolvedEmail.isEmpty) {
          throw const AuthServiceException('No account found');
        }

        emailToUse = resolvedEmail;
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return null;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final isEmailVerified = userData?['isEmailVerified'] == true;

      if (!isEmailVerified) {
        await _auth.signOut();
        throw AuthServiceException(
          'Please verify your email first',
          requiresVerification: true,
          verificationEmail: emailToUse,
        );
      }
      return user;
    } on AuthServiceException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapFirebaseAuthError(e.code));
    } catch (_) {
      throw const AuthServiceException('Something went wrong. Try again.');
    }
  }

  Future<void> logout() async {
    await _ensureFirebaseInitialized();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _ensureFirebaseInitialized();
      final normalizedEmail = email.trim().toLowerCase();

      bool emailExists = false;

      try {
        final emailDoc = await _firestore
            .collection('emails')
            .doc(normalizedEmail)
            .get();
        emailExists = emailDoc.exists;
      } on FirebaseException {
        throw const AuthServiceException(
          'Email does not exist, please sign up',
        );
      }

      if (!emailExists) {
        throw const AuthServiceException(
          'Email does not exist, please sign up',
        );
      }

      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on AuthServiceException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapFirebaseAuthError(e.code));
    } catch (_) {
      throw const AuthServiceException('Something went wrong. Try again.');
    }
  }

  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _ensureFirebaseInitialized();

      final email = await _auth.verifyPasswordResetCode(code);
      final isSameAsOldPassword = await _isSameAsCurrentPassword(
        email: email,
        candidatePassword: newPassword,
      );

      if (isSameAsOldPassword) {
        throw const AuthServiceException(
          'New password must be different from your old password',
        );
      }

      await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
    } on AuthServiceException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapFirebaseAuthError(e.code));
    } catch (_) {
      throw const AuthServiceException('Something went wrong. Try again.');
    }
  }

  Future<bool> _isSameAsCurrentPassword({
    required String email,
    required String candidatePassword,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: candidatePassword,
      );

      if (credential.user != null) {
        await _auth.signOut();
        return true;
      }

      return false;
    } on FirebaseAuthException catch (e) {
      final code = e.code.toLowerCase();

      if (code == 'wrong-password' ||
          code == 'invalid-credential' ||
          code == 'invalid-login-credentials' ||
          code == 'user-not-found' ||
          code == 'invalid-email' ||
          code == 'user-disabled' ||
          code == 'too-many-requests') {
        return false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _ensureFirebaseInitialized();
      final callable = _functions.httpsCallable('resetPasswordWithOtp');
      await callable.call({
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      final code = e.code.toLowerCase();
      switch (code) {
        case 'not-found':
          throw const AuthServiceException('OTP not found. Request a new code');
        case 'permission-denied':
          throw const AuthServiceException('Invalid OTP code');
        case 'failed-precondition':
          throw const AuthServiceException(
            'OTP has expired. Request a new code',
          );
        case 'invalid-argument':
          throw const AuthServiceException(
            'Email, OTP and password are required',
          );
        case 'unavailable':
          throw const AuthServiceException(
            'Reset service is unavailable. Deploy Cloud Functions or use reset link flow.',
          );
        default:
          throw const AuthServiceException(
            'Failed to reset password. Try again',
          );
      }
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      if (errorText.contains('cors') ||
          errorText.contains('xmlhttprequest error') ||
          errorText.contains('failed to fetch')) {
        throw const AuthServiceException(
          'Cannot reach reset service from web. Deploy Cloud Functions on Blaze or use reset link flow.',
        );
      }
      throw const AuthServiceException('Failed to reset password. Try again');
    }
  }

  Future<void> markEmailVerified(String email) async {
    await _ensureFirebaseInitialized();
    final normalizedEmail = email.trim().toLowerCase();

    final emailDoc = await _firestore
        .collection('emails')
        .doc(normalizedEmail)
        .get();
    final uid = emailDoc.data()?['uid'] as String?;
    if (uid == null || uid.isEmpty) {
      throw const AuthServiceException('No account found');
    }

    await _firestore.collection('users').doc(uid).update({
      'isEmailVerified': true,
    });
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    await _ensureFirebaseInitialized();

    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();

    final fullNameFromDb = (data?['fullName'] as String?)?.trim();
    final emailFromDb = (data?['email'] as String?)?.trim();
    final usernameFromDb = (data?['username'] as String?)?.trim();
    final createdAtValue = data?['createdAt'];

    DateTime? createdAt;
    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    }

    final fullName = (fullNameFromDb != null && fullNameFromDb.isNotEmpty)
        ? fullNameFromDb
        : 'User';
    final email = (emailFromDb != null && emailFromDb.isNotEmpty)
        ? emailFromDb
        : (user.email ?? 'No email available');

    return UserProfile(
      fullName: fullName,
      email: email,
      username: usernameFromDb,
      createdAt: createdAt,
    );
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  Future<void> _safeDeleteUser(User? user) async {
    if (user == null) {
      return;
    }
    try {
      await user.delete();
    } catch (_) {}
  }

  String _mapFirestoreError(String code) {
    switch (code.toLowerCase()) {
      case 'permission-denied':
        return 'Signup is currently unavailable. Please try again later.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please try again.';
      default:
        return 'Something went wrong. Try again.';
    }
  }

  String _mapFirebaseAuthError(String code) {
    final normalizedCode = code.toLowerCase();

    switch (normalizedCode) {
      case 'email-already-in-use':
        return 'Email already exists';
      case 'weak-password':
        return 'Password is too weak';
      case 'user-not-found':
        return 'No account found';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Invalid email or password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'invalid-action-code':
        return 'Reset link is invalid. Request a new one.';
      case 'expired-action-code':
        return 'Reset link has expired. Request a new one.';
      default:
        return 'Something went wrong. Try again.';
    }
  }
}
