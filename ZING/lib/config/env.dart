import 'package:firebase_core/firebase_core.dart';

/// Values injected at build time from the project-root `.env` file:
///
///   flutter run --dart-define-from-file=.env
///
/// See `.env.example` for the list of keys. Missing keys are empty strings.
class Env {
  Env._();

  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const googleTranslateApiKey = String.fromEnvironment('GOOGLE_TRANSLATE_API_KEY');
  static const googleDirectionsApiKey = String.fromEnvironment('GOOGLE_DIRECTIONS_API_KEY');

  static const _webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const _webAuthDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');
  static const _webProjectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');
  static const _webStorageBucket = String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET');
  static const _webMessagingSenderId = String.fromEnvironment('FIREBASE_WEB_MESSAGING_SENDER_ID');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _webMeasurementId = String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID');

  static bool get hasFirebaseWebConfig =>
      _webApiKey.isNotEmpty && _webAppId.isNotEmpty && _webProjectId.isNotEmpty;

  /// Firebase options for the web build. Android and iOS use
  /// google-services.json / GoogleService-Info.plist instead.
  static FirebaseOptions get firebaseWebOptions => FirebaseOptions(
        apiKey: _webApiKey,
        authDomain: _webAuthDomain,
        projectId: _webProjectId,
        storageBucket: _webStorageBucket,
        messagingSenderId: _webMessagingSenderId,
        appId: _webAppId,
        measurementId: _webMeasurementId.isEmpty ? null : _webMeasurementId,
      );
}
