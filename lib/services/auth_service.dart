import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pocketbase_service.dart';
import 'debug_log_service.dart';

/// Handles Google OAuth authentication via PocketBase's built-in users collection.
/// Manages session persistence and account linking/unlinking.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _initialized = false;

  // Auth state
  bool _isLinked = false;
  String? _linkedEmail;
  String? _linkedUserId;

  bool get isLinked => _isLinked;
  String? get linkedEmail => _linkedEmail;
  String? get linkedUserId => _linkedUserId;

  /// Initialize: restore any saved auth session from SharedPreferences
  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('pb_auth_token');
      final savedEmail = prefs.getString('pb_linked_email');
      final savedUserId = prefs.getString('pb_linked_user_id');

      if (savedToken != null && savedEmail != null && savedUserId != null) {
        // Restore the auth store
        final pb = PocketBaseService().pb;
        pb.authStore.save(savedToken, null);

        // Verify token is still valid
        if (pb.authStore.isValid) {
          _isLinked = true;
          _linkedEmail = savedEmail;
          _linkedUserId = savedUserId;
          DebugLogService().info("🔐 AuthService: Restored session for $_linkedEmail");
        } else {
          // Token expired, clear
          await _clearSavedSession();
          DebugLogService().info("🔐 AuthService: Saved token expired, cleared");
        }
      }
    } catch (e) {
      DebugLogService().error("⚠️ AuthService init error: $e");
    }

    _initialized = true;
  }

  /// Sign in with Google via PocketBase OAuth2
  /// Returns: the new PocketBase users record ID on success, or null on failure
  Future<String?> signInWithGoogle() async {
    try {
      final pb = PocketBaseService().pb;
      DebugLogService().info("🔐 Starting Google OAuth sign-in...");

      // 🚀 NATIVE WINDOWS CRASH FIX (Exit -1):
      // Unsubscribe from ALL other realtime topics (broadcasts, etc.) before starting OAuth.
      // On Windows, having multiple active SSE streams during the OAuth redirect phase 
      // often causes a native IOCP thread collision when the SDK tries to close or update 
      // the @oauth2 stream. A clean slate here ensures stability!
      await pb.realtime.unsubscribe();

      // PocketBase SDK handles the full OAuth2 flow:
      final authResult = await pb.collection('users').authWithOAuth2(
        'google',
        (url) async {
          // This callback is called with the OAuth2 URL to open
          DebugLogService().info("🔐 Opening Google OAuth URL...");
          final uri = Uri.parse(url.toString());
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            DebugLogService().error("⚠️ Cannot launch URL: $url");
          }
        },
      );

      // Success! Extract user info
      final userId = authResult.record.id;
      final email = authResult.record.data['email'] as String?;
      final token = pb.authStore.token;

      if (userId != null && email != null) {
        _isLinked = true;
        _linkedEmail = email;
        _linkedUserId = userId;

        // Persist session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pb_auth_token', token);
        await prefs.setString('pb_linked_email', email);
        await prefs.setString('pb_linked_user_id', userId);

        DebugLogService().success("✅ Google OAuth success: $email (ID: $userId)");
        
        // 🚀 NATIVE WINDOWS STABILIZATION:
        // Give the SDK's internal background SSE teardown a moment to breathe 
        // before returning control to the UI. This prevents the "Exit -1" crash.
        await Future.delayed(const Duration(seconds: 2));
        
        return userId;
      } else {
        DebugLogService().error("⚠️ OAuth succeeded but missing user data");
        return null;
      }
    } catch (e) {
      DebugLogService().error("⚠️ Google OAuth error: $e");
      debugPrint("⚠️ Google OAuth error: $e");
      return null;
    }
  }

  /// Sign out and revert to anonymous mode
  Future<void> signOut() async {
    try {
      final pb = PocketBaseService().pb;
      pb.authStore.clear();
      
      _isLinked = false;
      _linkedEmail = null;
      _linkedUserId = null;

      await _clearSavedSession();
      DebugLogService().info("🔐 Signed out, reverted to anonymous mode");
    } catch (e) {
      DebugLogService().error("⚠️ Sign out error: $e");
    }
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pb_auth_token');
    await prefs.remove('pb_linked_email');
    await prefs.remove('pb_linked_user_id');
  }
}
