import 'dart:convert';
import 'package:http/http.dart' as http;
import 'debug_log_service.dart';

enum TidalApiStatus {
  online,
  unauthorize,
  offlineStatus, // Avoid conflict with potential 'offline' keywords/variables
  noInternet,
  loading,
}

class TidalService {
  static final TidalService _instance = TidalService._internal();
  factory TidalService() => _instance;
  TidalService._internal();

  final http.Client _client = http.Client();
  final DebugLogService _logger = DebugLogService();

  /// List of known Tidal API servers.
  /// Ideally this should stay in sync with FlacDownloaderService.
  List<String> getServers() {
    return [
      'https://tidal-api.stephanus-dev.online', // Cloudflare domain (Primary)
      'https://triton.squid.wtf', // Priority Fallback
      'https://tnm.ngrok.app', // ngrok proxy
      'https://api.mizu.moe', // mizu.moe instance
      'https://l.yokai.ee/api', // yokai api
      'https://arran.monochrome.tf', // monochrome node
      'https://tidal-api.binimum.org',
      'https://tidal.squid.wtf',
      'https://api.monochrome.tf',
      'https://eu-central.monochrome.tf',
    ];
  }

  /// Checks the status of a specific server.
  Future<Map<String, dynamic>> checkServerStatus(String serverUrl) async {
    try {
      final uri = Uri.parse(serverUrl);
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'status': data['status'] == 'authorized'
              ? TidalApiStatus.online
              : TidalApiStatus.unauthorize,
          'version': data['version'],
          'tokenExpires': data['tokenExpires'],
        };
      } else {
        return {'status': TidalApiStatus.offlineStatus};
      }
    } catch (e) {
      _logger.warning('⚠️ Tidal Status Check failed for $serverUrl: $e');
      return {'status': TidalApiStatus.offlineStatus};
    }
  }

  /// Gets the status of the first healthy server.
  Future<Map<String, dynamic>> getOverallStatus() async {
    final servers = getServers();
    for (final server in servers) {
      final status = await checkServerStatus(server);
      if (status['status'] != TidalApiStatus.offlineStatus) {
        status['server'] = server;
        return status;
      }
    }
    return {'status': TidalApiStatus.offlineStatus};
  }
}
