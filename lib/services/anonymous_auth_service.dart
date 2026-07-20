import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../env/env.dart';
import 'pocketbase_service.dart';
import 'debug_log_service.dart';

/// Silent device-account authentication for users who don't sign in with
/// Google. On first launch, registers a `users` record with random
/// credentials; on subsequent launches, reuses the saved token. Existing
/// users (with `pb_user_id` from old anonymous-mode versions) auto-migrate
/// via the `claim` endpoint, which transfers their existing metrics record
/// ownership to the new auth account.
///
/// Custom endpoints used here are defined in:
///  backend/pocketbase/pb_hooks/anon_auth_endpoints.pb.js
class AnonymousAuthService {
  static final AnonymousAuthService _instance =
      AnonymousAuthService._internal();
  factory AnonymousAuthService() => _instance;
  AnonymousAuthService._internal();

  static const _prefsEmailKey = 'pb_anon_email';
  static const _prefsPasswordKey = 'pb_anon_password';
  static const _prefsClaimDoneKey = 'pb_anon_claim_done_v1';

  /// Public entry point. Resolves auth in this order:
  ///  1. OAuth session valid → no-op (already authed via AuthService)
  ///  2. Anonymous saved creds → login with them
  ///  3. Old version with pb_user_id → claim it
  ///  4. Fresh install → register new account
  ///
  /// Returns the auth user_id on success, null on failure (e.g. offline).
  Future<String?> ensureAuth() async {
    final pb = PocketBaseService().pb;
    final prefs = await SharedPreferences.getInstance();

    // 1. Already authenticated (OAuth or anon from earlier this session).
    if (pb.authStore.isValid) {
      final id = pb.authStore.record?.id;
      DebugLogService().info("🔐 anon: existing session valid, id=$id");
      return id;
    }

    // 2. Saved anon creds — try login.
    final savedEmail = prefs.getString(_prefsEmailKey);
    final savedPassword = prefs.getString(_prefsPasswordKey);
    if (savedEmail != null && savedPassword != null) {
      try {
        final result = await pb
            .collection('users')
            .authWithPassword(savedEmail, savedPassword);
        DebugLogService().info("🔐 anon: re-login ok id=${result.record.id}");
        return result.record.id;
      } catch (e) {
        DebugLogService().warning(
            "🔐 anon: saved creds invalid ($e), falling through to claim/register");
        // Fall through — credentials may have been wiped server-side.
      }
    }

    // 3. Old user_id (from pre-auth version) → claim.
    final oldUserId = prefs.getString('pb_user_id');
    final hasNotClaimed = !(prefs.getBool(_prefsClaimDoneKey) ?? false);
    if (oldUserId != null && hasNotClaimed) {
      final claimed = await _claim(oldUserId);
      if (claimed != null) {
        await prefs.setBool(_prefsClaimDoneKey, true);
        return claimed;
      }
      // If claim failed, mark done anyway so we don't retry forever — fall
      // through to register a fresh account instead.
      DebugLogService().warning(
          "🔐 anon: claim failed for old_id=$oldUserId, registering fresh");
      await prefs.setBool(_prefsClaimDoneKey, true);
    }

    // 4. Fresh install or unclaimable → register.
    return await _register();
  }

  /// Try to claim an existing metrics record by old user_id. Returns the
  /// new auth user_id on success, null on failure.
  Future<String?> _claim(String oldUserId) async {
    final pb = PocketBaseService().pb;
    final prefs = await SharedPreferences.getInstance();

    try {
      final body = jsonEncode({'device_user_id': oldUserId});
      final resp = await http
          .post(
            Uri.parse('${Env.pocketbaseUrl}/api/smpv2/anon/claim'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final email = data['email'] as String?;
        final password = data['password'] as String?;
        final userId = data['user_id'] as String?;
        if (email == null || password == null || userId == null) {
          DebugLogService().warning("🔐 anon: claim 200 but missing fields");
          return null;
        }
        // Save creds and authenticate.
        await prefs.setString(_prefsEmailKey, email);
        await prefs.setString(_prefsPasswordKey, password);
        final result =
            await pb.collection('users').authWithPassword(email, password);
        DebugLogService().success(
            "🔐 anon: CLAIM ok new_id=$userId moved=${data['claimed_records']}");
        return result.record.id;
      } else if (resp.statusCode == 409) {
        // Already claimed before (likely because this device was uninstalled
        // and reinstalled with prefs lost). The new app has no password to
        // authenticate, so we need to register a fresh account instead.
        DebugLogService()
            .info("🔐 anon: claim 409 (already claimed), will register fresh");
        return null;
      } else {
        DebugLogService().warning(
            "🔐 anon: claim returned ${resp.statusCode}: ${resp.body}");
        return null;
      }
    } catch (e) {
      DebugLogService().warning("🔐 anon: claim error $e");
      return null;
    }
  }

  /// Register a brand-new anonymous account.
  Future<String?> _register() async {
    final pb = PocketBaseService().pb;
    final prefs = await SharedPreferences.getInstance();

    try {
      final resp = await http
          .post(
            Uri.parse('${Env.pocketbaseUrl}/api/smpv2/anon/register'),
            headers: {'Content-Type': 'application/json'},
            body: '{}',
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        DebugLogService().warning(
            "🔐 anon: register returned ${resp.statusCode}: ${resp.body}");
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final email = data['email'] as String?;
      final password = data['password'] as String?;
      final userId = data['user_id'] as String?;
      if (email == null || password == null || userId == null) {
        DebugLogService().warning("🔐 anon: register 200 but missing fields");
        return null;
      }

      await prefs.setString(_prefsEmailKey, email);
      await prefs.setString(_prefsPasswordKey, password);
      final result =
          await pb.collection('users').authWithPassword(email, password);
      DebugLogService().success("🔐 anon: REGISTER ok id=$userId");
      return result.record.id;
    } catch (e) {
      DebugLogService().warning("🔐 anon: register error $e");
      return null;
    }
  }

  /// Migrate the current anon session's data to a Google OAuth account.
  /// Called after `auth_service.signInWithGoogle()` succeeds.
  /// `oauthUserId` is the OAuth users.id (pb_linked_user_id).
  /// Returns the count of records moved, or -1 on failure.
  Future<int> migrateLinkToOAuth(String oauthUserId) async {
    final pb = PocketBaseService().pb;
    final prefs = await SharedPreferences.getInstance();

    // We need the old anonymous user_id. Stored implicitly as the auth record
    // id at the time of this call, BEFORE OAuth replaces it. So caller must
    // capture pre-OAuth id and pass it here, OR we read from saved email.
    // For simplicity, read auth.record.id (the new OAuth id) and from-id from
    // the prefs anon email — derive the previous auth id by fetching the
    // record matching the saved anon email.

    final anonEmail = prefs.getString(_prefsEmailKey);
    if (anonEmail == null) return 0; // no anon to migrate

    // Fetch the anon user record to get its id.
    String? anonUserId;
    try {
      // We need to be authed as that anon user to look it up via the API.
      // If we're already OAuth-authed, the lookup below would fail; in that
      // case we use saved anon password to re-auth temporarily.
      final savedPassword = prefs.getString(_prefsPasswordKey);
      if (savedPassword == null) {
        DebugLogService()
            .warning("🔐 migrate-link: no saved anon password, skipping");
        return 0;
      }

      // Save current OAuth token so we can restore it after.
      final oauthToken = pb.authStore.token;
      final oauthRecord = pb.authStore.record;

      final anonAuth = await pb
          .collection('users')
          .authWithPassword(anonEmail, savedPassword);
      anonUserId = anonAuth.record.id;

      if (anonUserId == oauthUserId) {
        DebugLogService()
            .info("🔐 migrate-link: anon and OAuth ids equal, no-op");
        // Restore OAuth.
        if (oauthRecord != null) pb.authStore.save(oauthToken, oauthRecord);
        return 0;
      }

      // Call migrate-link with the anon token (which is now in pb.authStore).
      final resp = await http
          .post(
            Uri.parse('${Env.pocketbaseUrl}/api/smpv2/anon/migrate-link'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': pb.authStore.token,
            },
            body: jsonEncode({
              'from_user_id': anonUserId,
              'to_user_id': oauthUserId,
            }),
          )
          .timeout(const Duration(seconds: 8));

      // Restore OAuth session regardless of outcome.
      if (oauthRecord != null) pb.authStore.save(oauthToken, oauthRecord);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final moved = (data['moved'] as int?) ?? 0;
        DebugLogService().success(
            "🔐 migrate-link: moved $moved records from anon to OAuth");

        // Clear old anon creds (they're useless now that we're OAuth).
        await prefs.remove(_prefsEmailKey);
        await prefs.remove(_prefsPasswordKey);
        return moved;
      } else {
        DebugLogService().warning(
            "🔐 migrate-link: returned ${resp.statusCode}: ${resp.body}");
        return -1;
      }
    } catch (e) {
      DebugLogService().warning("🔐 migrate-link error: $e");
      return -1;
    }
  }
}
