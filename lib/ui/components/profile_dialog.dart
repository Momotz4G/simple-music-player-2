import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/profile_provider.dart';
import '../../providers/library_presentation_provider.dart';

import '../../services/metrics_service.dart';
import 'avatar_picker_dialog.dart';
import 'title_picker_dialog.dart';
import '../../utils/stats_utils.dart';
import '../../providers/stats_provider.dart';
import 'widgets/supreme_title_badge.dart';

class ProfileDialog extends ConsumerStatefulWidget {
  const ProfileDialog({super.key});

  @override
  ConsumerState<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<ProfileDialog> {
  late TextEditingController _nameController;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isAvatarHovered = false;
  bool _isLinking = false;

  @override
  void initState() {
    super.initState();
    final profileState = ref.read(profileProvider);
    _nameController =
        TextEditingController(text: profileState.customNickname ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveNickname() async {
    setState(() {
      _isLoading = true;
    });

    final error = await ref
        .read(profileProvider.notifier)
        .updateNickname(_nameController.text);

    if (mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
        ));
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTitlesSection(BuildContext context, WidgetRef ref,
      ProfileState profile, bool isDark, Color accentColor) {
    final statsState = ref.watch(statsProvider);
    final calculated = StatsUtils.calculate(statsState);
    
    final totalMinutes = calculated.totalMinutes > (profile.cloudTotalMinutes ?? 0) 
        ? calculated.totalMinutes 
        : (profile.cloudTotalMinutes ?? 0);
    
    final userRank = profile.cloudRank ?? 0;

    final isAutomatic = profile.selectedTitle == null || profile.selectedTitle!.trim().isEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          AppLocalizations.of(context)!.title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            SupremeTitleBadge.fromDefinition(
              StatsUtils.resolveTitleDefinition(profile.selectedTitle, totalMinutes, userRank: userRank),
              width: 260,
              height: 44,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAutomatic 
                    ? AppLocalizations.of(context)!.automaticTitleLabel(StatsUtils.getAutomaticTitle(totalMinutes, userRank: userRank)) 
                    : AppLocalizations.of(context)!.customSelected,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showTitlePicker(context, ref),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: Text(AppLocalizations.of(context)!.change, style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: accentColor.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ]);
  }

  void _showTitlePicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const TitlePickerDialog(),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "?";
    final names = name.trim().split(' ');
    if (names.length > 1) {
      return "${names[0][0]}${names[names.length - 1][0]}".toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return FocusScope(
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.profileSettings,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      splashRadius: 24,
                    ),
                  ],
                ),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) =>
                              setState(() => _isAvatarHovered = true),
                          onExit: (_) =>
                              setState(() => _isAvatarHovered = false),
                          child: Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const AvatarPickerDialog(),
                                  );
                                },
                                child: Hero(
                                  tag: 'profile_avatar',
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: accentColor.withValues(alpha: 0.2),
                                      border: Border.all(
                                          color: accentColor, width: 2),
                                      image: profileState.avatarUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                  profileState.avatarUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (profileState.avatarUrl == null)
                                          Center(
                                            child: Text(
                                              _getInitials(
                                                  profileState.displayName),
                                              style: TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                              ),
                                            ),
                                          ),
                                        AnimatedOpacity(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          opacity: _isAvatarHovered ? 1.0 : 0.0,
                                          child: Container(
                                            color: Colors.black
                                                .withValues(alpha: 0.4),
                                            child: Center(
                                              child: Text(
                                                AppLocalizations.of(context)!
                                                    .changeLabel,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: IgnorePointer(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Theme.of(context).cardColor,
                                          width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Name Display / Edit
                        if (!_isEditing) ...[
                          Text(
                            profileState.displayName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if (profileState.customNickname != null)
                            Text(
                              AppLocalizations.of(context)!.deviceNameLabel(
                                  profileState.defaultDeviceName),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _nameController.text =
                                    profileState.customNickname ?? '';
                                _isEditing = true;
                              });
                            },
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: Text(
                                AppLocalizations.of(context)!.editNickname),
                            style: TextButton.styleFrom(
                              foregroundColor: accentColor,
                            ),
                          ),
                        ] else ...[
                          TextField(
                            controller: _nameController,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText:
                                  AppLocalizations.of(context)!.nicknameLabel,
                              hintText:
                                  AppLocalizations.of(context)!.nicknameHint,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 20),
                                onPressed: () => _nameController.clear(),
                              ),
                            ),
                            onSubmitted: (_) => _saveNickname(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = false;
                                  });
                                },
                                child:
                                    Text(AppLocalizations.of(context)!.cancel),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _saveNickname,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Text(AppLocalizations.of(context)!.save),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Musical Titles Section
                        _buildTitlesSection(
                            context, ref, profileState, isDark, accentColor),

                        const SizedBox(height: 32),

                        // 🔗 Link Account Section
                        _buildLinkAccountSection(
                            context, ref, profileState, isDark, accentColor),

                        const SizedBox(height: 32),

                        // Leaderboard Card Link
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              final state = ref.read(profileProvider);
                              if (state.customNickname == null ||
                                  state.customNickname!.trim().isEmpty) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(AppLocalizations.of(context)!
                                      .nicknameHint), // Or a "Please set nickname" message
                                  behavior: SnackBarBehavior.floating,
                                ));
                                return;
                              }
                              Navigator.of(context).pop();
                              ref
                                  .read(libraryPresentationProvider.notifier)
                                  .setView(LibraryView.leaderboard);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[900]?.withValues(alpha: 0.5)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.amber.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.emoji_events_rounded,
                                        color: Colors.amber,
                                        size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!
                                              .globalRankings,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppLocalizations.of(context)!
                                              .globalRankingsDesc,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded,
                                      color: isDark
                                          ? Colors.grey[600]
                                          : Colors.grey[400]),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkAccountSection(BuildContext context, WidgetRef ref,
      ProfileState profile, bool isDark, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: profile.isLinked
          ? Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.accountLinked,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          profile.linkedEmail ?? AppLocalizations.of(context)!.googleAccount,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(AppLocalizations.of(context)!.unlinkAccountQuestion),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(AppLocalizations.of(context)!.unlinkAccountDesc),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        "Your local device stats will be wiped so you can start fresh. Don't worry, your progress is safely saved to your cloud account!",
                                        style: TextStyle(fontSize: 12, color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(AppLocalizations.of(context)!.cancel)),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(AppLocalizations.of(context)!.unlink,
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref.read(profileProvider.notifier).unlinkAccount();
                      }
                    },
                    icon: const Icon(Icons.link_off_rounded, size: 16),
                    label: Text(AppLocalizations.of(context)!.unlinkAccount,
                        style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[400],
                      side: BorderSide(
                          color: Colors.red.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.link_rounded,
                          color: accentColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.linkAccount,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocalizations.of(context)!.linkAccountDesc,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLinking
                        ? null
                        : () async {
                            setState(() => _isLinking = true);
                            
                            final result = await ref
                                .read(profileProvider.notifier)
                                .linkAccount();

                            if (!mounted) return;

                            if (result != null && result.startsWith("CONFLICT:")) {
                              setState(() => _isLinking = false);
                              final cloudName = result.split(":").last;
                              await _showSyncConflictDialog(context, cloudName);
                              return;
                            }

                            setState(() => _isLinking = false);
                            if (result != null) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(result),
                                backgroundColor:
                                    Colors.red.withValues(alpha: 0.8),
                                behavior: SnackBarBehavior.floating,
                              ));
                            } else {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content:
                                    Text(AppLocalizations.of(context)!.accountLinkedSuccessfully),
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          },
                    icon: _isLinking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.account_circle_rounded, size: 18),
                    label: Text(
                      _isLinking ? AppLocalizations.of(context)!.connecting : AppLocalizations.of(context)!.signInWithGoogle,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _showSyncConflictDialog(BuildContext context, String cloudName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Icon(Icons.sync_problem_rounded, color: accentColor),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.mergeAccountData),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.foundExistingAccount(cloudName),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "By syncing, your profile name and avatar will be updated to match '$cloudName', but your current device's listening minutes will be successfully merged into the account total.",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.localPlayHistorySaved,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLinking = true);
              final error = await ref.read(profileProvider.notifier).linkAccount(force: true);
              if (!mounted) return;
              setState(() => _isLinking = false);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(error),
                  backgroundColor: Colors.red.withValues(alpha: 0.8),
                  behavior: SnackBarBehavior.floating,
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("✅ Account merged successfully!"),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Confirm Sync"),
          ),
        ],
      ),
    );
  }
}
