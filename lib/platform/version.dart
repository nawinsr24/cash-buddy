/// Filled in by the GitHub build, so a phone can be matched to its APK. A
/// build made anywhere else says "dev".
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
