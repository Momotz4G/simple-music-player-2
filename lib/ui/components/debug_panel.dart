import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/debug_log_service.dart';

/// A floating debug button that shows a debug panel when clicked
class DebugFloatingButton extends StatefulWidget {
  final Widget child;

  const DebugFloatingButton({super.key, required this.child});

  @override
  State<DebugFloatingButton> createState() => _DebugFloatingButtonState();
}

class _DebugFloatingButtonState extends State<DebugFloatingButton> {
  bool _isPanelOpen = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Ignore the child since we're just overlaying on the parent Stack
        if (widget.child is! SizedBox) widget.child,

        // Floating Debug Button
        Positioned(
          right: 16,
          bottom: 130,
          child: FloatingActionButton.small(
            heroTag: 'debug_fab',
            backgroundColor: Colors.orange.withOpacity(0.9),
            onPressed: () {
              setState(() {
                _isPanelOpen = !_isPanelOpen;
              });
            },
            child: Icon(
              _isPanelOpen ? Icons.close : Icons.bug_report,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),

        // Debug Panel
        if (_isPanelOpen)
          Positioned(
            left: 16,
            right: 16,
            bottom: 160,
            child: DebugPanel(
              onClose: () {
                setState(() {
                  _isPanelOpen = false;
                });
              },
            ),
          ),
      ],
    );
  }
}

/// The debug panel that shows log entries
class DebugPanel extends StatefulWidget {
  final VoidCallback onClose;

  const DebugPanel({super.key, required this.onClose});

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  final DebugLogService _debugService = DebugLogService();
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _debugService.addListener(_onLogUpdate);
  }

  @override
  void dispose() {
    _debugService.removeListener(_onLogUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogUpdate() {
    if (mounted) {
      setState(() {});
      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  Color _getLogColor(DebugLogLevel level) {
    switch (level) {
      case DebugLogLevel.info:
        return Colors.white70;
      case DebugLogLevel.success:
        return Colors.greenAccent;
      case DebugLogLevel.warning:
        return Colors.orangeAccent;
      case DebugLogLevel.error:
        return Colors.redAccent;
    }
  }

  IconData _getLogIcon(DebugLogLevel level) {
    switch (level) {
      case DebugLogLevel.info:
        return Icons.info_outline;
      case DebugLogLevel.success:
        return Icons.check_circle_outline;
      case DebugLogLevel.warning:
        return Icons.warning_amber_outlined;
      case DebugLogLevel.error:
        return Icons.error_outline;
    }
  }

  void _copyLogsToClipboard() {
    final logsText = _debugService.logs.map((log) {
      return '[${log.formattedTime}] [${log.level.name.toUpperCase()}] ${log.message}';
    }).join('\n');

    Clipboard.setData(ClipboardData(text: logsText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _debugService.logs;

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Debug Console',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                // Auto-scroll toggle
                IconButton(
                  icon: Icon(
                    _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
                    color: _autoScroll ? Colors.greenAccent : Colors.grey,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _autoScroll = !_autoScroll;
                    });
                  },
                  tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // Copy button
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                  onPressed: _copyLogsToClipboard,
                  tooltip: 'Copy logs',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // Clear button
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.white70, size: 18),
                  onPressed: () {
                    _debugService.clear();
                  },
                  tooltip: 'Clear logs',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // Close button
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white70, size: 18),
                  onPressed: widget.onClose,
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Log entries
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'No logs yet. Try downloading or streaming a song.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.formattedTime,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _getLogIcon(log.level),
                              size: 12,
                              color: _getLogColor(log.level),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                log.message,
                                style: TextStyle(
                                  color: _getLogColor(log.level),
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Footer with stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${logs.length} entries',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                Text(
                  'BlueStacks Debug Mode',
                  style: TextStyle(
                    color: Colors.orange.withOpacity(0.5),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
