import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../../l10n/app_localizations.dart';
import '../../data/schemas.dart';
import '../../utils/translation_service.dart';
import '../../providers/settings_provider.dart';

class MessageDetailDialog extends ConsumerStatefulWidget {
  final MailboxMessage message;

  const MessageDetailDialog({
    super.key,
    required this.message,
  });

  @override
  ConsumerState<MessageDetailDialog> createState() => _MessageDetailDialogState();
}

class _MessageDetailDialogState extends ConsumerState<MessageDetailDialog> {
  String? _translatedText;
  bool _isTranslating = false;

  Future<void> _translate() async {
    if (_isTranslating) return;
    
    setState(() => _isTranslating = true);
    
    final targetLang = ref.read(settingsProvider).appLocale;
    final result = await TranslationService.translateText(
      text: widget.message.message,
      targetLang: targetLang,
    );
    
    if (mounted) {
      setState(() {
        _translatedText = result;
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat('MMMM d, yyyy • h:mm a').format(widget.message.timestamp);
    final accentColor = ref.watch(settingsProvider).accentColor;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: GlassmorphicContainer(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.6,
          borderRadius: 24,
          blur: 25,
          alignment: Alignment.center,
          border: 2,
          linearGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
              (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            ],
          ),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.5),
              accentColor.withValues(alpha: 0.2),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mail_outline_rounded, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.globalMailbox,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Original Message
                      Text(
                        widget.message.message,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          letterSpacing: 0.3,
                        ),
                      ),
                      
                      if (_translatedText != null) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.translate_rounded, size: 16, color: accentColor),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.translateLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _translatedText!,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            fontStyle: FontStyle.italic,
                            color: (isDark ? Colors.blueGrey[100] : Colors.blueGrey[800]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    if (_translatedText == null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTranslating ? null : _translate,
                          icon: _isTranslating 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.translate_rounded, size: 18),
                          label: Text(AppLocalizations.of(context)!.translateLabel),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(AppLocalizations.of(context)!.close),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
