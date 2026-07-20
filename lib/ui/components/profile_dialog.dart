import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/profile_provider.dart';
import '../../providers/library_presentation_provider.dart';

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

class _ProfileDialogState extends ConsumerState<ProfileDialog>
    with WidgetsBindingObserver {
  late TextEditingController _nameController;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isAvatarHovered = false;
  bool _isLinking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Refresh quota silently when dialog opens just in case
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).refreshQuotaFromCloud();
    });

    final profileState = ref.read(profileProvider);
    _nameController =
        TextEditingController(text: profileState.customNickname ?? '');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-refresh quota when returning to the app (e.g., from Sociabuzz browser window)
      ref.read(profileProvider.notifier).refreshQuotaFromCloud();
    }
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

    final totalMinutes =
        calculated.totalMinutes > (profile.cloudTotalMinutes ?? 0)
            ? calculated.totalMinutes
            : (profile.cloudTotalMinutes ?? 0);

    final userRank = profile.cloudRank ?? 0;

    final isAutomatic =
        profile.selectedTitle == null || profile.selectedTitle!.trim().isEmpty;

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
              StatsUtils.resolveTitleDefinition(
                  profile.selectedTitle, totalMinutes,
                  userRank: userRank),
              width: 260,
              height: 44,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAutomatic
                      ? AppLocalizations.of(context)!.automaticTitleLabel(
                          StatsUtils.getAutomaticTitle(totalMinutes,
                              userRank: userRank))
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
                  label: Text(AppLocalizations.of(context)!.change,
                      style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor:
                        isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side:
                          BorderSide(color: accentColor.withValues(alpha: 0.2)),
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
                                                style: const TextStyle(
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

                        // 🌟 Quota & Premium Section
                        _buildQuotaSection(
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

  Widget _buildQuotaSection(BuildContext context, WidgetRef ref,
      ProfileState profile, bool isDark, Color accentColor) {
    final maxDownloads = profile.isLinked ? 20 : 10;
    final progress = (profile.dailyDownloads / maxDownloads).clamp(0.0, 1.0);

    if (profile.isPremium) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withValues(alpha: 0.15),
              Colors.orange.withValues(alpha: 0.05)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.premiumMemberTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.amber),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.premiumMemberDesc,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showBenefitsDialog(context, isDark, accentColor);
                      },
                      icon: const Icon(Icons.workspace_premium_rounded, size: 16),
                      label: Text(AppLocalizations.of(context)!.seeBenefitsBtn, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.grey[900], // Dark text on amber
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.high_quality_rounded,
                    color: Colors.blue, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.alacHighResDownloads,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.usedToday(profile.dailyDownloads, maxDownloads),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.red : Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _showBenefitsDialog(context, isDark, accentColor);
              },
              icon: Icon(
                  profile.isPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.star_rounded,
                  size: 18),
              label: Text(
                profile.isPremium
                    ? AppLocalizations.of(context)!.seePremiumBenefits
                    : AppLocalizations.of(context)!.unlockUnlimitedPremium,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    profile.isPremium ? Colors.grey[700] : Colors.amber[600],
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

  void _showBenefitsDialog(
      BuildContext context, bool isDark, Color accentColor) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final profile = ref.watch(profileProvider);
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.accountTiers,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Guest
                      _buildBenefitTier(
                        isDark: isDark,
                        title: AppLocalizations.of(context)!.guestTier,
                        color: Colors.grey,
                        icon: Icons.person_outline,
                        features: [
                          AppLocalizations.of(context)!.alacDownloadsPerDay(10),
                          AppLocalizations.of(context)!.standardDownloadQueue,
                        ],
                        isCurrentTier: !profile.isLinked && !profile.isPremium,
                        context: context,
                      ),
                      const SizedBox(height: 12),

                      // Registered
                      _buildBenefitTier(
                        isDark: isDark,
                        title: AppLocalizations.of(context)!.registeredLinkedTier,
                        color: Colors.blue,
                        icon: Icons.account_circle_rounded,
                        features: [
                          AppLocalizations.of(context)!.alacDownloadsPerDay(20),
                          AppLocalizations.of(context)!.standardDownloadQueue,
                          AppLocalizations.of(context)!.cloudStatsAndRankings,
                        ],
                        isCurrentTier: profile.isLinked && !profile.isPremium,
                        context: context,
                      ),
                      const SizedBox(height: 12),

                      // Premium
                      _buildBenefitTier(
                        isDark: isDark,
                        title: AppLocalizations.of(context)!.premiumMemberTitle,
                        color: Colors.amber,
                        icon: Icons.workspace_premium_rounded,
                        features: [
                          AppLocalizations.of(context)!.unlimitedAlacDownloads,
                          AppLocalizations.of(context)!.priorityVipServerQueue,
                          AppLocalizations.of(context)!.exclusiveSupporterTitle,
                          AppLocalizations.of(context)!.donateMinToObtain,
                        ],
                        isHighlighted: true,
                        isCurrentTier: profile.isPremium,
                        context: context,
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: profile.isPremium
                              ? null
                              : () async {
                                  if (!profile.isLinked) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            AppLocalizations.of(context)!.linkAccountToUpgrade),
                                        backgroundColor: Colors.redAccent
                                            .withValues(alpha: 0.9),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                    return;
                                  }

                                  final bool? confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                      title: Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded, color: Colors.amber),
                                          const SizedBox(width: 12),
                                          Text(
                                            AppLocalizations.of(dialogCtx)!.confirm,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppLocalizations.of(dialogCtx)!.useSameEmailCheckStatus,
                                            style: TextStyle(
                                              color: isDark ? Colors.grey[300] : Colors.grey[800],
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (profile.linkedEmail != null) ...[
                                            const SizedBox(height: 16),
                                            Text(
                                              "Your current app email:",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              profile.linkedEmail!,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(dialogCtx, false),
                                          child: Text(
                                            AppLocalizations.of(dialogCtx)!.cancel,
                                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(dialogCtx, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber[600],
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: Text(AppLocalizations.of(dialogCtx)!.continueToSociabuzz),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm != true) return;
                                  if (!ctx.mounted) return;

                                  Navigator.pop(ctx);
                                  final url = Uri.parse(
                                      'https://sociabuzz.com/momotz4g/tribe');
                                  bool launched = false;
                                  try {
                                    launched = await launchUrl(url,
                                        mode: LaunchMode.externalApplication);
                                  } catch (_) {}
                                  
                                  if (!launched) {
                                    try {
                                      await launchUrl(url);
                                    } catch (_) {}
                                  }
                                },
                          icon: Icon(
                              profile.isPremium
                                  ? Icons.check_circle_rounded
                                  : Icons.open_in_browser_rounded,
                              size: 18),
                          label: Text(
                            profile.isPremium
                                ? AppLocalizations.of(context)!.owned
                                : AppLocalizations.of(context)!.continueToSociabuzz,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: profile.isPremium
                                ? Colors.grey
                                : Colors.amber[600],
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                isDark ? Colors.grey[800] : Colors.grey[400],
                            disabledForegroundColor:
                                isDark ? Colors.white70 : Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      if (!profile.isPremium)
                        Center(
                          child: TextButton.icon(
                            onPressed: () async {
                              _checkStatusWithDialog(context, ref);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(AppLocalizations.of(context)!.alreadyPaidCheckStatus),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),

                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            final url =
                                Uri.parse('https://discord.gg/5Tt7PqBM6g');
                            bool launched = false;
                            try {
                              launched = await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            } catch (_) {}
                            
                            if (!launched) {
                              try {
                                await launchUrl(url);
                              } catch (_) {}
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor:
                                isDark ? Colors.white54 : Colors.black45,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.reportTrouble,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBenefitTier({
    required bool isDark,
    required String title,
    required Color color,
    required IconData icon,
    required List<String> features,
    bool isHighlighted = false,
    bool isCurrentTier = false,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? color.withValues(alpha: 0.1)
            : (isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? color.withValues(alpha: 0.3)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isHighlighted ? color : null,
                  ),
                ),
              ),
              if (isCurrentTier)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Current",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: isHighlighted ? color : Colors.green, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
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
                            profile.linkedEmail ??
                                AppLocalizations.of(context)!.googleAccount,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
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
                          title: Text(AppLocalizations.of(context)!
                              .unlinkAccountQuestion),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(AppLocalizations.of(context)!
                                  .unlinkAccountDesc),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        color: Colors.red, size: 24),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Your local device stats will be wiped so you can start fresh. Don't worry, your progress is safely saved to your cloud account!",
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.red),
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
                                child:
                                    Text(AppLocalizations.of(context)!.cancel)),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                    AppLocalizations.of(context)!.unlink,
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold))),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(profileProvider.notifier)
                            .unlinkAccount();
                      }
                    },
                    icon: const Icon(Icons.link_off_rounded, size: 16),
                    label: Text(AppLocalizations.of(context)!.unlinkAccount,
                        style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[400],
                      side:
                          BorderSide(color: Colors.red.withValues(alpha: 0.3)),
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
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
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

                            try {
                              final result = await ref
                                  .read(profileProvider.notifier)
                                  .linkAccount();

                              if (!context.mounted) return;

                              if (result != null &&
                                  result.startsWith("CONFLICT:")) {
                                final cloudName = result.split(":").last;
                                await _showSyncConflictDialog(context, cloudName);
                                return;
                              }

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
                                  content: Text(AppLocalizations.of(context)!
                                      .accountLinkedSuccessfully),
                                  behavior: SnackBarBehavior.floating,
                                ));
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isLinking = false);
                              }
                            }
                          },
                    icon: _isLinking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.account_circle_rounded, size: 18),
                    label: Text(
                      _isLinking
                          ? AppLocalizations.of(context)!.connecting
                          : AppLocalizations.of(context)!.signInWithGoogle,
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

  Future<void> _showSyncConflictDialog(
      BuildContext context, String cloudName) async {
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
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.localPlayHistorySaved,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
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
            child: Text(AppLocalizations.of(context)!.cancel,
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLinking = true);
              try {
                final error = await ref
                    .read(profileProvider.notifier)
                    .linkAccount(force: true);
                if (!context.mounted) return;
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
              } finally {
                if (mounted) {
                  setState(() => _isLinking = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Confirm Sync"),
          ),
        ],
      ),
    );
  }

  Future<void> _checkStatusWithDialog(
      BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(
                "Checking Status...",
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    // Fetch from cloud
    final resultMsg =
        await ref.read(profileProvider.notifier).refreshQuotaFromCloud();

    // Pop loading dialog
    if (context.mounted) {
      Navigator.pop(context);
    }

    if (!context.mounted) return;

    final isSuccess = resultMsg.contains("Active");

    // Show Result Dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
                isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                color: isSuccess ? Colors.green : Colors.amber),
            const SizedBox(width: 12),
            const Text("Status Result",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(resultMsg,
            style:
                TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800])),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuccess ? Colors.green : Colors.amber[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
