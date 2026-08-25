/// Social sign-in configuration.
///
/// Google: create an OAuth Web Client ID in Google Cloud Console
/// (APIs & Services -> Credentials) and paste it below. Without it the
/// button still works on platforms where Google supplies a default,
/// otherwise it shows a friendly setup hint instead of failing silently.
class SocialConfig {
  SocialConfig._();

  static const String? googleServerClientId = null;
  static const bool facebookReady = true;
}
