import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../constants/social_config.dart';

/// Wraps the google_sign_in plugin and returns an ID token for the backend.
class GoogleSignInService {
  GoogleSignIn _instance() => GoogleSignIn(
        serverClientId: SocialConfig.googleServerClientId,
        scopes: const ['email', 'profile'],
      );

  Future<String> getIdToken() async {
    try {
      final google = _instance();
      final account =
          await google.signIn().timeout(const Duration(seconds: 45));
      if (account == null) {
        throw ApiExceptionMessage('Google sign-in was cancelled');
      }
      final auth = await account.authentication;
      if ((auth.idToken ?? '').isEmpty) {
        throw ApiExceptionMessage(
          'No Google ID token returned. Add your Web Client ID in '
          'lib/core/constants/social_config.dart',
        );
      }
      return auth.idToken!;
    } catch (e) {
      if (e is ApiExceptionMessage) rethrow;
      throw ApiExceptionMessage(
        'Google sign-in unavailable on this device/config: ${e.toString()}',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _instance().signOut();
    } catch (_) {}
  }
}

class ApiExceptionMessage implements Exception {
  ApiExceptionMessage(this.message);

  final String message;

  @override
  String toString() => message;
}

bool get isMobileTarget =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
