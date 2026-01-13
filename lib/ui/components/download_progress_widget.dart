import 'package:flutter/material.dart';
import '../../models/download_progress.dart';

class DownloadProgressWidget extends StatelessWidget {
  final DownloadProgress progress;
  final VoidCallback? onCancel;

  const DownloadProgressWidget({
    super.key,
    required this.progress,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey[400] : Colors.grey[700];
    final accentColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  progress.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (onCancel != null) ...[
                SizedBox(
                  height: 24,
                  width: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: onCancel,
                    tooltip: "Cancel Download",
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                "${(progress.progress * 100).toInt()}%",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.progress,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            borderRadius: BorderRadius.circular(2),
            minHeight: 4,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progress.details ??
                    "${progress.receivedMB.toStringAsFixed(1)} MB / ${progress.totalMB.toStringAsFixed(1)} MB",
                style: TextStyle(
                  fontSize: 11,
                  color: textColor?.withOpacity(0.7),
                ),
              ),
              // 🚀 Speed display
              if (progress.speedMBps != null && progress.speedMBps! > 0)
                Text(
                  "${progress.speedMBps!.toStringAsFixed(1)} MB/s",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
