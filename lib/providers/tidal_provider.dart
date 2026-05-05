import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tidal_service.dart';
import '../services/pocketbase_service.dart'; // 🔒 OFFLINE MODE

class TidalStatusState {
  final TidalApiStatus status;
  final String? version;
  final String? tokenExpires;
  final String? server;

  TidalStatusState({
    required this.status,
    this.version,
    this.tokenExpires,
    this.server,
  });

  TidalStatusState copyWith({
    TidalApiStatus? status,
    String? version,
    String? tokenExpires,
    String? server,
  }) {
    return TidalStatusState(
      status: status ?? this.status,
      version: version ?? this.version,
      tokenExpires: tokenExpires ?? this.tokenExpires,
      server: server ?? this.server,
    );
  }
}

class TidalStatusNotifier extends AsyncNotifier<TidalStatusState> {
  Timer? _timer;
  final _tidalService = TidalService();

  @override
  FutureOr<TidalStatusState> build() async {
    // Start polling when provider is initialized
    _startPolling();
    
    // Stop polling when provider is disposed
    ref.onDispose(() {
      _timer?.cancel();
    });

    return _fetchStatus();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _fetchStatus());
    });
  }

  Future<TidalStatusState> _fetchStatus() async {
    // 🔒 OFFLINE MODE
    if (PocketBaseService.isOffline) {
      return TidalStatusState(status: TidalApiStatus.offlineStatus);
    }

    // 1. Check Internet Connectivity First
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      final isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (!isOnline) {
        return TidalStatusState(status: TidalApiStatus.noInternet);
      }
    } catch (_) {
      return TidalStatusState(status: TidalApiStatus.noInternet);
    }

    // 2. Fetch Server Status
    final result = await _tidalService.getOverallStatus();
    return TidalStatusState(
      status: result['status'] as TidalApiStatus,
      version: result['version'] as String?,
      tokenExpires: result['tokenExpires'] as String?,
      server: result['server'] as String?,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchStatus());
  }
}

final tidalStatusProvider = AsyncNotifierProvider<TidalStatusNotifier, TidalStatusState>(() {
  return TidalStatusNotifier();
});
