import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/db_service.dart';
import '../data/schemas.dart';
import '../services/pocketbase_service.dart';

final mailboxProvider = StateNotifierProvider<MailboxNotifier, List<MailboxMessage>>((ref) {
  return MailboxNotifier();
});

class MailboxNotifier extends StateNotifier<List<MailboxMessage>> {
  MailboxNotifier() : super([]) {
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final messages = await DBService().getMailboxMessages();
    state = messages;
  }

  Future<void> addMessage(String message, {String? remoteId, DateTime? timestamp}) async {
    await DBService().addMailboxMessage(message, remoteId: remoteId, timestamp: timestamp);
    await _loadMessages();
  }

  Future<void> syncWithRemote() async {
    final remoteMsgs = await PocketBaseService().fetchRecentBroadcasts();
    if (remoteMsgs.isEmpty) return;

    for (final raw in remoteMsgs) {
      final msg = raw['message'] as String?;
      if (msg == null || msg.isEmpty) continue; // Skip malformed
      
      final id = raw['id'] as String? ?? 'unknown';
      final time = DateTime.tryParse(raw['created'] ?? '') ?? DateTime.now();
      
      await DBService().addMailboxMessage(msg, remoteId: id, timestamp: time);
    }
    await _loadMessages();
  }

  Future<void> markAsRead(int id) async {
    await DBService().markMessageAsRead(id);
    await _loadMessages();
  }

  Future<void> deleteMessage(int id) async {
    await DBService().deleteMailboxMessage(id);
    await _loadMessages();
  }

  Future<void> clearAll() async {
    await DBService().clearMailbox();
    state = [];
  }

  int get unreadCount => state.where((m) => !m.isRead).length;
}
