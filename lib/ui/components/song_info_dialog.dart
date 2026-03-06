import 'package:flutter/material.dart';
import '../../models/song_model.dart';
import '../../services/audio_info_service.dart';
import '../../l10n/app_localizations.dart';

/// Dialog to display detailed song information including audio quality
class SongInfoDialog extends StatefulWidget {
  final SongModel song;

  const SongInfoDialog({super.key, required this.song});

  @override
  State<SongInfoDialog> createState() => _SongInfoDialogState();

  /// Show the dialog
  static Future<void> show(BuildContext context, SongModel song) {
    return showDialog(
      context: context,
      builder: (context) => SongInfoDialog(song: song),
    );
  }
}

class _SongInfoDialogState extends State<SongInfoDialog> {
  AudioInfo? _audioInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAudioInfo();
  }

  Future<void> _loadAudioInfo() async {
    try {
      final service = AudioInfoService();
      await service.initialize();
      final info = await service.getAudioInfoForSong(widget.song);
      if (mounted) {
        setState(() {
          _audioInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final accentColor = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Row(
        children: [
          Icon(Icons.info_outline, color: accentColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.songInformation,
              style: TextStyle(color: textColor, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            : _error != null
                ? Center(
                    child: Text('Error loading info: $_error',
                        style: TextStyle(color: Colors.red[400])),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Quality Badge
                        if (_audioInfo != null) _buildQualityBadge(accentColor),
                        const SizedBox(height: 16),

                        // Song Details Section
                        _buildSectionHeader(l10n.trackDetails, isDark),
                        _buildInfoRow(l10n.titleLabel, widget.song.title,
                            textColor, subtitleColor),
                        _buildInfoRow(l10n.artistLabel, widget.song.artist,
                            textColor, subtitleColor),
                        _buildInfoRow(l10n.albumLabel, widget.song.album,
                            textColor, subtitleColor),
                        if (widget.song.isrc != null &&
                            widget.song.isrc!.isNotEmpty)
                          _buildInfoRow('ISRC', widget.song.isrc!, textColor,
                              subtitleColor),

                        const SizedBox(height: 16),

                        // Audio Quality Section
                        if (_audioInfo != null) ...[
                          _buildSectionHeader(l10n.audioQuality, isDark),
                          _buildInfoRow(l10n.formatLabel, _audioInfo!.format,
                              textColor, subtitleColor),
                          _buildInfoRow(
                              l10n.codecLabel,
                              _audioInfo!.codec.toUpperCase(),
                              textColor,
                              subtitleColor),
                          _buildInfoRow(
                              l10n.bitrateLabel,
                              _audioInfo!.bitrateDisplay,
                              textColor,
                              subtitleColor),
                          _buildInfoRow(
                              l10n.sampleRateLabel,
                              _audioInfo!.sampleRateDisplay,
                              textColor,
                              subtitleColor),
                          if (_audioInfo!.bitDepth != null)
                            _buildInfoRow(
                                l10n.bitDepthLabel,
                                _audioInfo!.bitDepthDisplay,
                                textColor,
                                subtitleColor),
                          _buildInfoRow(
                              l10n.channelsLabel,
                              _audioInfo!.channelsDisplay,
                              textColor,
                              subtitleColor),
                          _buildInfoRow(
                              l10n.fileSizeLabel,
                              _audioInfo!.fileSizeDisplay,
                              textColor,
                              subtitleColor),

                          const SizedBox(height: 16),

                          // File Path Section
                          _buildSectionHeader(l10n.fileLocation, isDark),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: SelectableText(
                              widget.song.filePath,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close, style: TextStyle(color: accentColor)),
        ),
      ],
    );
  }

  Widget _buildQualityBadge(Color accentColor) {
    if (_audioInfo == null) return const SizedBox.shrink();

    final label = _audioInfo!.qualityLabel;
    final isHiRes = label.contains('Hi-Res');
    final isCdQuality = label.contains('CD');
    final isLossless = _audioInfo!.isLossless;

    Color badgeColor;
    IconData icon;

    if (isHiRes) {
      badgeColor = Colors.amber;
      icon = Icons.stars_rounded;
    } else if (isCdQuality) {
      badgeColor = Colors.cyan;
      icon = Icons.album_rounded; // CD icon
    } else if (isLossless) {
      badgeColor = Colors.blue;
      icon = Icons.high_quality_rounded;
    } else if (label == 'High Quality') {
      badgeColor = Colors.green;
      icon = Icons.verified_rounded;
    } else {
      badgeColor = Colors.grey;
      icon = Icons.music_note_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            badgeColor.withOpacity(0.2),
            badgeColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: badgeColor, size: 24),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (_audioInfo!.bitrate != null)
                Text(
                  '${_audioInfo!.bitrateDisplay} • ${_audioInfo!.sampleRateDisplay}',
                  style: TextStyle(
                    color: badgeColor.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[700],
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, Color textColor, Color? subtitleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: subtitleColor, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
