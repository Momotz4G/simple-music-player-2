// lib/ui/components/download_fab_widget.dart

// Floating download button for mobile.
// Animates in when downloads are active, opens a panel with the queue.

import 'package:flutter/material.dart';

import '../../models/download_progress.dart';
import '../../services/bulk_download_service.dart';
import '../../services/download_queue_service.dart';

import 'package:simple_music_player_2/l10n/app_localizations.dart';

import 'download_progress_widget.dart';
import 'smart_art.dart';

class DownloadFabWidget extends StatefulWidget {
  const DownloadFabWidget({super.key});

  @override
  State<DownloadFabWidget> createState() => _DownloadFabWidgetState();
}

class _DownloadFabWidgetState extends State<DownloadFabWidget>
    with SingleTickerProviderStateMixin {
  bool _isPanelOpen = false;
  late final AnimationController _fabController;
  late final Animation<double> _fabScale;
  late final Animation<double> _fabRotation;

  // Track whether anything is active so we can show/hide the FAB
  bool _hasActiveDownloads = false;

  @override
  void initState() {
    super.initState();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fabScale = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeIn,
    );

    _fabRotation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOut),
    );

    // Listen to all download sources
    DownloadQueueService().queueNotifier.addListener(_onQueueChanged);
    BulkDownloadService().progressNotifier.addListener(_onAnyChanged);

    _onQueueChanged();
  }

  @override
  void dispose() {
    DownloadQueueService().queueNotifier.removeListener(_onQueueChanged);
    BulkDownloadService().progressNotifier.removeListener(_onAnyChanged);
    _fabController.dispose();
    super.dispose();
  }

  void _onQueueChanged() => _onAnyChanged();

  void _onAnyChanged() {
    final queue = DownloadQueueService().queueNotifier.value;
    final hasQueue = queue.any((i) =>
        i.status == DownloadQueueStatus.queued ||
        i.status == DownloadQueueStatus.downloading);
    final hasBulk = BulkDownloadService().progressNotifier.value != null;

    final active = hasQueue || hasBulk;

    if (active != _hasActiveDownloads) {
      setState(() => _hasActiveDownloads = active);
      if (active) {
        _fabController.forward();
      } else {
        // Close panel first, then hide FAB
        if (_isPanelOpen) {
          setState(() => _isPanelOpen = false);
        }
        _fabController.reverse();
      }
    }
  }

  void _togglePanel() {
    setState(() => _isPanelOpen = !_isPanelOpen);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Stack(
      children: [
        // ── Panel ──────────────────────────────────────────────────────────────
        if (_isPanelOpen)
          Positioned(
            right: 16,
            bottom: 160, // above player bar
            width: 320,
            child: _DownloadPanel(
              isDark: isDark,
              accent: accent,
              onClose: () => setState(() => _isPanelOpen = false),
            ),
          ),

        // ── FAB ────────────────────────────────────────────────────────────────
        Positioned(
          right: 16,
          bottom: 140, // just above player bar
          child: ScaleTransition(
            scale: _fabScale,
            child: _DownloadFab(
              isOpen: _isPanelOpen,
              rotation: _fabRotation,
              accent: accent,
              onTap: _togglePanel,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── FAB button ───────────────────────────────────────────────────────────────

class _DownloadFab extends StatelessWidget {
  final bool isOpen;
  final Animation<double> rotation;
  final Color accent;
  final VoidCallback onTap;

  const _DownloadFab({
    required this.isOpen,
    required this.rotation,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<DownloadQueueItem>>(
      valueListenable: DownloadQueueService().queueNotifier,
      builder: (context, queue, _) {
        final activeCount = queue
            .where((i) =>
                i.status == DownloadQueueStatus.queued ||
                i.status == DownloadQueueStatus.downloading)
            .length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Pulsing ring when downloading
            if (activeCount > 0)
              Positioned.fill(
                child: _PulsingRing(color: accent),
              ),

            FloatingActionButton.small(
              heroTag: 'download_fab',
              backgroundColor: accent,
              onPressed: onTap,
              child: RotationTransition(
                turns: rotation,
                child: Icon(
                  isOpen ? Icons.close : Icons.download_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),

            // Badge: number of active items
            if (activeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$activeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Pulsing ring animation ───────────────────────────────────────────────────

class _PulsingRing extends StatefulWidget {
  final Color color;
  const _PulsingRing({required this.color});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _scale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _opacity.value),
          ),
        ),
      ),
    );
  }
}

// ─── Download panel ───────────────────────────────────────────────────────────

class _DownloadPanel extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final VoidCallback onClose;

  const _DownloadPanel({
    required this.isDark,
    required this.accent,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bg = isDark
        ? Colors.grey[900]!.withValues(alpha: 0.97)
        : Colors.white.withValues(alpha: 0.97);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 480),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.download_rounded, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.downloads,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  // Clear finished button
                  ValueListenableBuilder<List<DownloadQueueItem>>(
                    valueListenable: DownloadQueueService().queueNotifier,
                    builder: (context, queue, _) {
                      final hasFinished = queue.any((i) =>
                          i.status == DownloadQueueStatus.completed ||
                          i.status == DownloadQueueStatus.failed ||
                          i.status == DownloadQueueStatus.cancelled);
                      if (!hasFinished) return const SizedBox.shrink();
                      return TextButton(
                        onPressed: () => DownloadQueueService().clearFinished(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Clear',
                          style: TextStyle(color: accent, fontSize: 12),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    iconSize: 18,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Single-song queue ──────────────────────────────────
                    ValueListenableBuilder<List<DownloadQueueItem>>(
                      valueListenable: DownloadQueueService().queueNotifier,
                      builder: (context, queue, _) {
                        if (queue.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (queue.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)!.songQueueTitle,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (queue.any((i) =>
                                        i.status ==
                                            DownloadQueueStatus.downloading ||
                                        i.status == DownloadQueueStatus.queued))
                                      TextButton(
                                        onPressed: () =>
                                            DownloadQueueService().cancelAll(),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor: Colors.redAccent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        child: Text(
                                          AppLocalizations.of(context)!.cancelAllBtn,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ...queue.map((item) => _QueueItemTile(
                                  item: item,
                                  isDark: isDark,
                                  accent: accent,
                                )),
                          ],
                        );
                      },
                    ),

                    // ── Bulk download progress ─────────────────────────────
                    ValueListenableBuilder<DownloadProgress?>(
                      valueListenable: BulkDownloadService().progressNotifier,
                      builder: (context, progress, _) {
                        if (progress == null) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                'Album / Playlist',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            DownloadProgressWidget(
                              progress: progress,
                              onCancel: () =>
                                  BulkDownloadService().cancelDownload(),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Queue item tile ──────────────────────────────────────────────────────────

class _QueueItemTile extends StatefulWidget {
  final DownloadQueueItem item;
  final bool isDark;
  final Color accent;

  const _QueueItemTile({
    required this.item,
    required this.isDark,
    required this.accent,
  });

  @override
  State<_QueueItemTile> createState() => _QueueItemTileState();
}

class _QueueItemTileState extends State<_QueueItemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    final accent = widget.accent;

    final textColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    // ── Status colour + icon ──────────────────────────────────────────────────
    Color statusColor;
    IconData statusIcon;
    switch (item.status) {
      case DownloadQueueStatus.downloading:
        statusColor = accent;
        statusIcon = Icons.download_rounded;
        break;
      case DownloadQueueStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case DownloadQueueStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error_rounded;
        break;
      case DownloadQueueStatus.cancelled:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel_rounded;
        break;
      case DownloadQueueStatus.queued:
        statusColor = subColor;
        statusIcon = Icons.schedule_rounded;
        break;
    }

    // ── Can this item be cancelled? ───────────────────────────────────────────
    final canCancel = item.status == DownloadQueueStatus.queued ||
        item.status == DownloadQueueStatus.downloading;

    // ── MB label ─────────────────────────────────────────────────────────────
    String? mbLabel;
    if (item.status == DownloadQueueStatus.downloading && item.totalMB > 0) {
      mbLabel =
          '${item.receivedMB.toStringAsFixed(1)} MB / ${item.totalMB.toStringAsFixed(1)} MB';
    }

    // ── Speed label ───────────────────────────────────────────────────────────
    String? speedLabel;
    if (item.status == DownloadQueueStatus.downloading &&
        item.speedMBps != null &&
        item.speedMBps! > 0) {
      speedLabel = '${item.speedMBps!.toStringAsFixed(1)} MB/s';
    }

    // ── Trailing widget ───────────────────────────────────────────────────────
    // Desktop: show cancel on hover for queued items, status icon otherwise
    // Mobile: always show cancel button for queued items
    final isMobile = Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

    Widget trailing;
    if (canCancel) {
      // Always show cancel on mobile; show on hover on desktop
      final showCancel = isMobile || _hovered;
      trailing = AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: showCancel
            ? SizedBox(
                key: const ValueKey('cancel'),
                width: 26,
                height: 26,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.12),
                    foregroundColor: Colors.red,
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: () => DownloadQueueService().cancelItem(item.id),
                  tooltip: 'Cancel',
                ),
              )
            : Icon(
                key: const ValueKey('schedule'),
                statusIcon,
                size: 16,
                color: statusColor,
              ),
      );
    } else {
      // Hide trailing icon for cancelled/failed to avoid confusing it with an active button
      if (item.status == DownloadQueueStatus.cancelled || item.status == DownloadQueueStatus.failed) {
        trailing = const SizedBox.shrink();
      } else {
        trailing = Icon(statusIcon, size: 18, color: statusColor);
      }
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovered
            ? (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03))
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            // ── Art ──────────────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: item.artUrl != null
                  ? SmartArt(
                      path: item.artUrl!,
                      onlineArtUrl:
                          item.artUrl!.startsWith('http') ? item.artUrl : null,
                      size: 40,
                      borderRadius: 6)
                  : Container(
                      width: 40,
                      height: 40,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(Icons.music_note,
                          size: 20,
                          color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
            ),
            const SizedBox(width: 10),

            // ── Text + progress ───────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  if (item.status == DownloadQueueStatus.downloading) ...[
                    // Progress bar
                    LinearProgressIndicator(
                      value: item.progress > 0 ? item.progress : null,
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                      borderRadius: BorderRadius.circular(2),
                      minHeight: 3,
                    ),
                    const SizedBox(height: 3),

                    // MB row + speed
                    Row(
                      children: [
                        if (mbLabel != null)
                          Text(
                            mbLabel,
                            style: TextStyle(fontSize: 10, color: subColor),
                          ),
                        if (mbLabel != null && speedLabel != null)
                          Text(
                            '  ·  ',
                            style: TextStyle(fontSize: 10, color: subColor),
                          ),
                        if (speedLabel != null)
                          Text(
                            speedLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        // Fallback: show status label if no MB info yet
                        if (mbLabel == null)
                          Text(
                            item.statusLabel,
                            style: TextStyle(fontSize: 10, color: subColor),
                          ),
                      ],
                    ),
                  ] else
                    // Non-downloading states: just show status label
                    Text(
                      item.statusLabel,
                      style: TextStyle(fontSize: 10, color: statusColor),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Trailing ─────────────────────────────────────────────────────
            trailing,
          ],
        ),
      ),
    );
  }
}
