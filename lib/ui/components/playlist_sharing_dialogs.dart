import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/playlist_provider.dart';
import '../../l10n/app_localizations.dart';

class SharePlaylistDialog extends ConsumerStatefulWidget {
  final String playlistId;
  final String playlistName;

  const SharePlaylistDialog({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  ConsumerState<SharePlaylistDialog> createState() => _SharePlaylistDialogState();
}

class _SharePlaylistDialogState extends ConsumerState<SharePlaylistDialog> {
  String? _shareCode;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    final code = await ref.read(playlistProvider.notifier).getShareCode(widget.playlistId);
    if (mounted) {
      setState(() {
        _shareCode = code;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSharing(bool enable) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    if (enable) {
      final code = await ref.read(playlistProvider.notifier).sharePlaylist(widget.playlistId);
      if (mounted) {
        setState(() {
          _shareCode = code;
          _isProcessing = false;
          if (code == null) {
            _errorMessage = l10n.failedEnableSharing;
          }
        });
      }
    } else {
      final success = await ref.read(playlistProvider.notifier).unsharePlaylist(widget.playlistId);
      if (mounted) {
        setState(() {
          if (success) {
            _shareCode = null;
          } else {
            _errorMessage = l10n.failedDisableSharing;
          }
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text(l10n.sharePlaylistTitle(widget.playlistName), style: TextStyle(color: textColor)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.publicSharing, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_shareCode != null 
                ? l10n.publicSharingDesc
                : l10n.publicSharingDisabledDesc),
              trailing: _isProcessing 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Switch(
                    value: _shareCode != null,
                    onChanged: (val) => _toggleSharing(val),
                  ),
            ),
            const Divider(),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            if (_shareCode != null)
              Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                    ),
                    child: Text(
                      _shareCode!,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _shareCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.codeCopied)),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.copyCode),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              l10n.disablingSharingWarning,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class ImportPlaylistDialog extends ConsumerStatefulWidget {
  const ImportPlaylistDialog({super.key});

  @override
  ConsumerState<ImportPlaylistDialog> createState() => _ImportPlaylistDialogState();
}

class _ImportPlaylistDialogState extends ConsumerState<ImportPlaylistDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _statusMessage;

  Future<void> _handleImport() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _statusMessage = "❌ ${l10n.codeMust6Digits}");
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "📡 ${l10n.fetchingPlaylist}";
    });

    final result = await ref.read(playlistProvider.notifier).importSharedPlaylist(
      code,
      onStatus: (key, {args}) {
        if (!mounted) return;
        final msg = _getLocalizedStatus(l10n, key, args);
        setState(() => _statusMessage = msg);
      },
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result != null) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      }
    }
  }

  String _getLocalizedStatus(AppLocalizations l10n, String key, Map<String, dynamic>? args) {
    switch (key) {
      case "fetchingSharedPlaylist": return "📡 ${l10n.fetchingSharedPlaylist}";
      case "playlistNotFoundOrError": return "❌ ${l10n.playlistNotFoundOrError}";
      case "parsingPlaylistData": return "📋 ${l10n.parsingPlaylistData}";
      case "importedPlaylistName": return "✅ ${l10n.importedPlaylistName(args?['name'] ?? '')}";
      case "importFailed": return "❌ ${l10n.importFailed(args?['error'] ?? '')}";
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Row(
        children: [
          Icon(Icons.share_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(l10n.importViaCode, style: TextStyle(color: textColor)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
            maxLength: 6,
            decoration: InputDecoration(
              hintText: "AAAAAA",
              counterText: "",
              helperText: l10n.enterShareCode,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              UpperCaseTextFormatter(),
            ],
          ),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusMessage!.startsWith("❌") 
                      ? Colors.red 
                      : _statusMessage!.startsWith("✅") 
                          ? Colors.green 
                          : Colors.grey,
                ),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleImport,
          child: Text(l10n.importChoice),
        ),
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
