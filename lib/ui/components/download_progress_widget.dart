import 'package:flutter/material.dart';
import '../../services/update_service.dart';

class DownloadProgressWidget extends StatelessWidget {
  final DownloadProgress progress;

  const DownloadProgressWidget({
    super.key,
    required this.progress,
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
              Text(
                progress.status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
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
          Text(
            "${progress.receivedMB.toStringAsFixed(1)} MB / ${progress.totalMB.toStringAsFixed(1)} MB",
            style: TextStyle(
              fontSize: 11,
              color: textColor?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
