import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

/// Wraps flutter_facebook_auth and returns an access token for the backend.
class FacebookSignInService {
  Future<String> getAccessToken() async {
    try {
      // On web, the plugin uses the JS SDK directly.
      // On mobile, it uses the native Facebook SDK.
      final result = await FacebookAuth.instance.login(
        permissions: const ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        final accessToken = result.accessToken;
        if (accessToken == null) {
          throw FacebookAuthException('No Facebook access token returned');
        }
        return accessToken.tokenString;
      } else if (result.status == LoginStatus.cancelled) {
        throw FacebookAuthException('Facebook sign-in was cancelled');
      } else {
        throw FacebookAuthException(
          result.message ?? 'Facebook sign-in failed',
        );
      }
    } catch (e) {
      if (e is FacebookAuthException) rethrow;
      throw FacebookAuthException(
        'Facebook sign-in unavailable: ${e.toString()}',
      );
    }
  }

  Future<void> logOut() async {
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
  }
}

class FacebookAuthException implements Exception {
  FacebookAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
