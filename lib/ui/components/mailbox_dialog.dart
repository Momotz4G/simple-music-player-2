import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/mailbox_provider.dart';
import '../../data/schemas.dart';
import 'message_detail_dialog.dart';

class MailboxDialog extends ConsumerWidget {
  const MailboxDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(mailboxProvider);
    final notifier = ref.read(mailboxProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: GlassmorphicContainer(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          borderRadius: 20,
          blur: 20,
          alignment: Alignment.bottomCenter,
          border: 2,
          linearGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              ],
              stops: const [
                0.1,
                1,
              ]),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFffffff).withValues(alpha: 0.5),
              const Color((0xFFFFFFFF)).withValues(alpha: 0.5),
            ],
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.all_inbox_rounded, color: Colors.blueAccent),
                        SizedBox(width: 12),
                        Text(
                          AppLocalizations.of(context)!.globalMailbox,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (messages.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _showClearConfirmation(context, notifier),
                        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                        label: Text(AppLocalizations.of(context)!.clearAll, style: const TextStyle(color: Colors.redAccent)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Message List
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mark_email_read_rounded, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(AppLocalizations.of(context)!.noMessages, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          return _MailboxItem(
                            message: msg,
                            onTap: () {
                              notifier.markAsRead(msg.id);
                              showDialog(
                                context: context,
                                builder: (context) => MessageDetailDialog(message: msg),
                              );
                            },
                            onDelete: () => notifier.deleteMessage(msg.id),
                          );
                        },
                      ),
              ),
              
              // Footer
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppLocalizations.of(context)!.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, MailboxNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.emptyMailboxTitle),
        content: Text(AppLocalizations.of(context)!.emptyMailboxDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              notifier.clearAll();
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.clearAll, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _MailboxItem extends StatelessWidget {
  final MailboxMessage message;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MailboxItem({
    required this.message,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat('MMM d, h:mm a').format(message.timestamp);
    
    // User requested: darken if read, lighten if not.
    // We'll use opacity and background color to achieve this.
    final double opacity = message.isRead ? 0.4 : 0.85;
    final Color itemColor = isDark 
        ? Colors.white.withValues(alpha: message.isRead ? 0.05 : 0.1)
        : Colors.black.withValues(alpha: message.isRead ? 0.05 : 0.1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: itemColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Indicator
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: message.isRead ? Colors.transparent : Colors.blueAccent,
                  border: message.isRead 
                    ? Border.all(color: Colors.grey.withValues(alpha: 0.5))
                    : null,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Opacity(
                opacity: opacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: message.isRead ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Delete Action
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.close_rounded, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: Colors.grey.withValues(alpha: 0.5),
              hoverColor: Colors.redAccent.withValues(alpha: 0.1),
            ),
          ],
        ),
      ),
    );
  }
}
