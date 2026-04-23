import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/player_provider.dart';
import '../../../services/pocketbase_service.dart';
import '../../../services/metrics_service.dart';
import '../../../env/env.dart';
import '../../../l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

class DeviceSelectorDialog extends ConsumerStatefulWidget {
  const DeviceSelectorDialog({super.key});

  @override
  ConsumerState<DeviceSelectorDialog> createState() => _DeviceSelectorDialogState();
}

class _DeviceSelectorDialogState extends ConsumerState<DeviceSelectorDialog> {
  Timer? _refreshTimer;
  List<dynamic> _devices = [];
  String? _activeDeviceId;
  String? _localDeviceId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshDevices());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    _localDeviceId = await MetricsService().getDeviceIdentifier();
    await _refreshDevices();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refreshDevices() async {
    final session = await PocketBaseService().getSessionData();
    if (session != null && mounted) {
      final rawDevices = session['available_devices'];
      List<dynamic> devices = [];
      if (rawDevices is List) {
        devices = rawDevices;
      } else if (rawDevices is String && rawDevices.isNotEmpty) {
        try {
          devices = jsonDecode(rawDevices) as List<dynamic>;
        } catch (_) {}
      }

      setState(() {
        _devices = devices;
        _activeDeviceId = session['active_device_id'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)!.connectToADevice,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              )
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_devices.isEmpty)
            _buildEmptyState()
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index] as Map<String, dynamic>;
                  final id = device['id'];
                  final name = device['name'] ?? "Unknown Device";
                  final isLocal = id == _localDeviceId;
                  final isActive = id == _activeDeviceId;
                  final isOnline = _isDeviceOnline(device['last_active']);

                  return _buildDeviceItem(
                    context,
                    name: name,
                    isLocal: isLocal,
                    isActive: isActive,
                    isOnline: isOnline,
                    onTap: () async {
                      if (isLocal) {
                        if (!isActive) {
                           ref.read(playerProvider.notifier).switchToThisDevice();
                           Navigator.pop(context);
                        }
                      } else {
                        // 🚀 REMOTE SWITCH: Command the other device to take over
                        await ref.read(playerProvider.notifier).switchToRemoteDevice(id, name);
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          _buildInfoNote(),
          const Divider(height: 32),
          _buildListeningPartyItem(context),
        ],
      ),
    );
  }

  Widget _buildListeningPartyItem(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(Icons.qr_code_2_rounded, color: colorScheme.primary),
      title: Text(
        l10n.listeningParty,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        l10n.scanToControlPlayback,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => _showRemotePairingDialog(l10n),
    );
  }

  void _showRemotePairingDialog(AppLocalizations l10n) async {
    try {
      final sessionId = await PocketBaseService().getUniqueSessionId();
      if (sessionId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorCouldNotCreateSession)),
          );
        }
        return;
      }

      final url = "${Env.remoteControlUrl}/?sid=$sessionId";

      if (!mounted) return;

      // 🚀 Close the bottom sheet first
      final navigator = Navigator.of(context);
      navigator.pop();

      showDialog(
        context: navigator.context,
        builder: (context) => AlertDialog(
          title: Text(l10n.listeningParty),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: url,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.scanToControlPlayback,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              SelectableText(
                l10n.session(sessionId),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("⚠️ Listening Party Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  /// Determine if a device is online based on its last heartbeat
  bool _isDeviceOnline(String? lastActiveStr) {
    if (lastActiveStr == null) return false;
    try {
      final lastActive = DateTime.parse(lastActiveStr);
      return DateTime.now().difference(lastActive).inSeconds < 60;
    } catch (_) {
      return false;
    }
  }

  Widget _buildDeviceItem(
    BuildContext context, {
    required String name,
    required bool isLocal,
    required bool isActive,
    required bool isOnline,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Determine subtitle text and color
    String subtitle;
    Color subtitleColor;
    if (isActive) {
      subtitle = "Connected";
      subtitleColor = colorScheme.primary;
    } else if (isLocal) {
      subtitle = "This device";
      subtitleColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    } else if (isOnline) {
      subtitle = "Online";
      subtitleColor = Colors.green;
    } else {
      subtitle = "Offline";
      subtitleColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isActive 
          ? colorScheme.primaryContainer.withValues(alpha: 0.3) 
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: colorScheme.primary.withValues(alpha: 0.5), width: 1.5) : null,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(
          isLocal ? Icons.phone_android : Icons.computer,
          color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          isLocal ? "$name (This device)" : name,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
          ),
        ),
        subtitle: Row(
          children: [
            if (!isActive && !isLocal)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? Colors.green : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ),
            Text(
              subtitle,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: isActive 
          ? _PlayingIndicator(color: colorScheme.primary)
          : (isLocal ? const Icon(Icons.arrow_forward_ios, size: 14) : null),
        onTap: onTap,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Icon(Icons.devices_other, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        const Text("No other active devices found."),
        const SizedBox(height: 8),
        Text(
          "Make sure your other devices are linked to the same account.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Switching devices will maintain your position and queue.",
              style: TextStyle(fontSize: 11, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayingIndicator extends StatelessWidget {
  final Color color;
  const _PlayingIndicator({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _bar(context, 1),
          _bar(context, 2),
          _bar(context, 3),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, int index) {
    return Container(
      width: 3,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
