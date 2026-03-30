import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'SPOTIFY_CLIENT_ID', obfuscate: true)
  static final String spotifyClientId = _Env.spotifyClientId;

  @EnviedField(varName: 'SPOTIFY_CLIENT_SECRET', obfuscate: true)
  static final String spotifyClientSecret = _Env.spotifyClientSecret;

  // 🚀 Secondary Spotify App (for high-volume search operations)
  @EnviedField(
      varName: 'SPOTIFY_CLIENT_ID_2', obfuscate: true, defaultValue: '')
  static final String spotifyClientId2 = _Env.spotifyClientId2;

  @EnviedField(
      varName: 'SPOTIFY_CLIENT_SECRET_2', obfuscate: true, defaultValue: '')
  static final String spotifyClientSecret2 = _Env.spotifyClientSecret2;

  @EnviedField(varName: 'DISCORD_APP_ID', obfuscate: true)
  static final String discordAppId = _Env.discordAppId;

  // 🚀 Firebase Config
  @EnviedField(varName: 'FIREBASE_API_KEY', obfuscate: true)
  static final String firebaseApiKey = _Env.firebaseApiKey;

  @EnviedField(varName: 'FIREBASE_AUTH_DOMAIN', obfuscate: true)
  static final String firebaseAuthDomain = _Env.firebaseAuthDomain;

  @EnviedField(varName: 'FIREBASE_PROJECT_ID', obfuscate: true)
  static final String firebaseProjectId = _Env.firebaseProjectId;

  @EnviedField(varName: 'FIREBASE_STORAGE_BUCKET', obfuscate: true)
  static final String firebaseStorageBucket = _Env.firebaseStorageBucket;

  @EnviedField(varName: 'FIREBASE_MESSAGING_SENDER_ID', obfuscate: true)
  static final String firebaseMessagingSenderId =
      _Env.firebaseMessagingSenderId;

  // Multi-Platform App IDs
  @EnviedField(varName: 'FIREBASE_APP_ID_WINDOWS', obfuscate: true)
  static final String firebaseAppIdWindows = _Env.firebaseAppIdWindows;

  @EnviedField(varName: 'FIREBASE_APP_ID_ANDROID', obfuscate: true)
  static final String firebaseAppIdAndroid = _Env.firebaseAppIdAndroid;

  @EnviedField(varName: 'FIREBASE_APP_ID_IOS', obfuscate: true)
  static final String firebaseAppIdIos = _Env.firebaseAppIdIos;

  @EnviedField(varName: 'FIREBASE_APP_ID_MACOS', obfuscate: true)
  static final String firebaseAppIdMacos = _Env.firebaseAppIdMacos;

  @EnviedField(varName: 'FIREBASE_MEASUREMENT_ID', obfuscate: true)
  static final String firebaseMeasurementId = _Env.firebaseMeasurementId;

  // 🚀 PocketBase Config
  @EnviedField(varName: 'POCKETBASE_URL', obfuscate: true)
  static final String pocketbaseUrl = _Env.pocketbaseUrl;

  @EnviedField(varName: 'POCKETBASE_ADMIN_EMAIL', obfuscate: true)
  static final String pocketbaseAdminEmail = _Env.pocketbaseAdminEmail;

  @EnviedField(varName: 'POCKETBASE_ADMIN_PASSWORD', obfuscate: true)
  static final String pocketbaseAdminPassword = _Env.pocketbaseAdminPassword;

  // 🚀 Qobuz Config
  @EnviedField(
      varName: 'QOBUZ_APP_ID', obfuscate: true, defaultValue: '798273057')
  static final String qobuzAppId = _Env.qobuzAppId;

  // 🚀 Remote Control Config
  @EnviedField(varName: 'REMOTE_CONTROL_URL', obfuscate: true)
  static final String remoteControlUrl = _Env.remoteControlUrl;

  // 🚀 Romaji API Config
  @EnviedField(varName: 'ROMAJI_API_URL', obfuscate: true)
  static final String romajiApiUrl = _Env.romajiApiUrl;

  // 🚀 Tidal API Config (Private Server)
  @EnviedField(varName: 'TIDAL_API_KEY', obfuscate: true, defaultValue: '')
  static final String tidalApiKey = _Env.tidalApiKey;

  // 🚀 Tidal API URL (Primary Server)
  @EnviedField(
      varName: 'TIDAL_API_URL',
      obfuscate: true,
      defaultValue: 'https://tidal-api.stephanus-dev.online')
  static final String tidalApiUrl = _Env.tidalApiUrl;
}
