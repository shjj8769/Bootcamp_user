/// One place for the FastAPI origin used throughout the app.
///
/// Physical devices default to the development Mac's LAN IP. For the Android
/// emulator, launch with `--dart-define=API_BASE_URL=http://10.0.2.2:8000`.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.20.68:8000',
  );
}
