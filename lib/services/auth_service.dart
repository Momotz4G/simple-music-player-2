import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pocketbase_service.dart';
import 'debug_log_service.dart';
import 'package:pocketbase/pocketbase.dart';
import '../env/env.dart';

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
          
          // Silently refresh the token to extend its life by another 14 days!
          try {
            await pb.collection('users').authRefresh();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('pb_auth_token', pb.authStore.token);
          } catch (_) {
            // Ignore refresh errors (offline, etc)
          }
        } else {
          // Token expired — clear ONLY the token, NOT the identity link.
          await _clearExpiredToken();
          // Keep identity state so the user stays "linked" but needs re-auth
          _isLinked = true;
          _linkedEmail = savedEmail;
          _linkedUserId = savedUserId;
          DebugLogService().info("🔐 AuthService: Token expired for $_linkedEmail, identity preserved. Re-auth needed.");
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

      // NATIVE WINDOWS CRASH FIX (Exit -1):
      // Unsubscribe from ALL other realtime topics (broadcasts, etc.) before starting OAuth.
      // On Windows, having multiple active SSE streams during the OAuth redirect phase 
      // often causes a native IOCP thread collision when the SDK tries to close or update 
      // the @oauth2 stream. A clean slate here ensures stability!
      await pb.realtime.unsubscribe();

      // PocketBase SDK handles the full OAuth2 flow:
      final authResultFuture = pb.collection('users').authWithOAuth2(
        'google',
        (url) async {
          // This callback is called with the OAuth2 URL to open
          DebugLogService().info("🔐 Opening Google OAuth URL...");
          final uri = Uri.parse(url.toString());

          bool launched = false;
          // 1. Try Chrome Custom Tabs / In-App Browser View first (keeps app in foreground stack so SSE doesn't drop)
          try {
            launched = await launchUrl(
              uri,
              mode: LaunchMode.inAppBrowserView,
            );
          } catch (_) {}

          // 2. Fallback to external application (e.g. Chrome browser)
          if (!launched) {
            try {
              launched = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            } catch (e) {
              DebugLogService().error("⚠️ Cannot launch OAuth URL: $e");
            }
          }

          if (!launched) {
            DebugLogService().error("⚠️ Failed to launch OAuth URL in any mode");
          }
        },
      );

      // Add a 60-second timeout so authWithOAuth2 NEVER hangs indefinitely if SSE drops
      final authResult = await authResultFuture.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          DebugLogService().error("⚠️ Google OAuth timed out after 60 seconds.");
          throw TimeoutException("OAuth authentication timed out. Please try again.");
        },
      );

      // Success! Extract user info
      final userId = authResult.record.id;
      String? email = authResult.record.data['email'] as String?;
      final token = pb.authStore.token;

      final metaEmail = authResult.meta['email'] as String?;
      if (metaEmail != null && metaEmail.isNotEmpty && (email == null || email.endsWith('@anon.local'))) {
        debugPrint("🔐 OAuth: Detected anonymous email ($email). Updating user record with Google email: $metaEmail");
        try {
          final adminPb = PocketBase(Env.pocketbaseUrl);
          await adminPb.collection('_superusers').authWithPassword(
                Env.pocketbaseAdminEmail,
                Env.pocketbaseAdminPassword,
              );
          await adminPb.collection('users').update(userId, body: {
            'email': metaEmail,
            'verified': true,
          });
          email = metaEmail;

          final model = pb.authStore.record;
          if (model != null) {
            try {
              model.data['email'] = metaEmail;
            } catch (_) {}
          }

          DebugLogService().success("🔐 OAuth: Successfully updated user email to $metaEmail");
        } catch (e) {
          DebugLogService().error("⚠️ OAuth: Failed to update user email to Google email: $e");
        }
      }

      if (email != null) {
        _isLinked = true;
        _linkedEmail = email;
        _linkedUserId = userId;

        // Persist session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pb_auth_token', token);
        await prefs.setString('pb_linked_email', email);
        await prefs.setString('pb_linked_user_id', userId);

        DebugLogService().success("✅ Google OAuth success: $email (ID: $userId)");
        
        // NATIVE WINDOWS STABILIZATION:
        // Brief pause for background socket cleanup
        await Future.delayed(const Duration(milliseconds: 500));
        
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

      await _clearFullSession();
      DebugLogService().info("🔐 Signed out, reverted to anonymous mode");
    } catch (e) {
      DebugLogService().error("⚠️ Sign out error: $e");
    }
  }

  /// 🔒 Soft clear: Only remove the expired JWT token.
  /// Preserves pb_linked_user_id so identity doesn't revert to hardware hash.
  Future<void> _clearExpiredToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pb_auth_token');
    // NOTE: pb_linked_email and pb_linked_user_id are intentionally KEPT
    // so the next startup still resolves to the correct user identity.
  }

  /// 🗑️ Hard clear: Remove ALL auth state (explicit sign-out only).
  Future<void> _clearFullSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pb_auth_token');
    await prefs.remove('pb_linked_email');
    await prefs.remove('pb_linked_user_id');
  }
}
