
import 'package:flutter/material.dart';
import '../../providers/metadata_provider.dart';
import '../../services/hybrid_service.dart';

import 'smart_art.dart';
import '../../l10n/app_localizations.dart';
import 'music_notification.dart';

class MetadataEditorPanel extends StatefulWidget {
  final MetadataState state;
  final MetadataNotifier notifier;
  final Color textColor;
  final bool popOnSave;

  const MetadataEditorPanel({
    super.key,
    required this.state,
    required this.notifier,
    required this.textColor,
    this.popOnSave = false,
  });

  @override
  State<MetadataEditorPanel> createState() => _MetadataEditorPanelState();
}

class _MetadataEditorPanelState extends State<MetadataEditorPanel> {
  late TextEditingController _titleCtrl;
  late TextEditingController _artistCtrl;
  late TextEditingController _albumCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _trackCtrl;
  late TextEditingController _discCtrl;
  late TextEditingController _genreCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant MetadataEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      if (_titleCtrl.text != widget.state.title) _titleCtrl.text = widget.state.title;
      if (_artistCtrl.text != widget.state.artist) _artistCtrl.text = widget.state.artist;
      if (_albumCtrl.text != widget.state.album) _albumCtrl.text = widget.state.album;
      if (_yearCtrl.text != widget.state.year) _yearCtrl.text = widget.state.year;
      if (_trackCtrl.text != widget.state.trackNumber) _trackCtrl.text = widget.state.trackNumber;
      if (_discCtrl.text != widget.state.discNumber) _discCtrl.text = widget.state.discNumber;
      if (_genreCtrl.text != widget.state.genre) _genreCtrl.text = widget.state.genre;
      
      // FORCE DIALOGUE ART REPAINT
      setState(() {});
    }
  }

  void _initControllers() {
    _titleCtrl = TextEditingController(text: widget.state.title);
    _artistCtrl = TextEditingController(text: widget.state.artist);
    _albumCtrl = TextEditingController(text: widget.state.album);
    _yearCtrl = TextEditingController(text: widget.state.year);
    _trackCtrl = TextEditingController(text: widget.state.trackNumber);
    _discCtrl = TextEditingController(text: widget.state.discNumber);
    _genreCtrl = TextEditingController(text: widget.state.genre);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final artWidget = Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: widget.state.coverUrl != null
            ? Image.network(
                widget.state.coverUrl!,
                key: ValueKey(widget.state.coverUrl), // Force refresh
                fit: BoxFit.cover,
              )
            : (widget.state.selectedSong?.albumArtBytes != null
                ? Image.memory(
                    widget.state.selectedSong!.albumArtBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : (widget.state.selectedSong?.filePath != null
                    ? SmartArt(
                        key: ValueKey('art_${widget.state.selectedSong!.filePath}'),
                        path: widget.state.selectedSong!.filePath,
                        size: 140,
                        borderRadius: 8,
                        onlineArtUrl: widget.state.coverUrl ?? widget.state.selectedSong!.onlineArtUrl, // Updated
                      )
                    : const Icon(Icons.music_note, size: 50, color: Colors.white24))),
      ),
    );

    final fieldsWidget = Column(
      children: [
        _buildField(AppLocalizations.of(context)!.title, _titleCtrl,
            (v) => widget.notifier.updateField(title: v)),
        const SizedBox(height: 12),
        _buildField(AppLocalizations.of(context)!.artist, _artistCtrl,
            (v) => widget.notifier.updateField(artist: v)),
        const SizedBox(height: 12),
        _buildField(AppLocalizations.of(context)!.album, _albumCtrl,
            (v) => widget.notifier.updateField(album: v)),
        const SizedBox(height: 12),
        _buildField(AppLocalizations.of(context)!.genre, _genreCtrl,
            (v) => widget.notifier.updateField(genre: v)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildField(
                    AppLocalizations.of(context)!.year,
                    _yearCtrl,
                    (v) => widget.notifier.updateField(year: v))),
            const SizedBox(width: 12),
            Expanded(
                child: _buildField(
                    AppLocalizations.of(context)!.trackNumber,
                    _trackCtrl,
                    (v) => widget.notifier.updateField(track: v))),
            const SizedBox(width: 12),
            Expanded(
                child: _buildField(
                    AppLocalizations.of(context)!.discNumber,
                    _discCtrl,
                    (v) => widget.notifier.updateField(disc: v))),
          ],
        )
      ],
    );

    final autoFixBtn = ElevatedButton.icon(
      icon: const Icon(Icons.auto_awesome, color: Colors.white),
      label: Text(AppLocalizations.of(context)!.autoFixComingSoon),
      onPressed: null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purpleAccent.withValues(alpha: 0.5),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        disabledBackgroundColor: Colors.grey[800],
      ),
    );

    final searchBtn = OutlinedButton.icon(
      icon: const Icon(Icons.search),
      label: Text(AppLocalizations.of(context)!.manualSearch),
      onPressed: () => _showSearchDialog(context),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );

    return ListView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      children: [
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              artWidget,
              const SizedBox(width: 24),
              Expanded(child: fieldsWidget),
            ],
          )
        else
          Column(
            children: [
              Center(child: artWidget),
              const SizedBox(height: 24),
              fieldsWidget,
            ],
          ),
        const SizedBox(height: 40),
        
        if (isDesktop)
          Row(
            children: [
              Expanded(child: autoFixBtn),
              const SizedBox(width: 16),
              Expanded(child: searchBtn),
            ],
          )
        else
          Column(
            children: [
              SizedBox(width: double.infinity, child: autoFixBtn),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: searchBtn),
            ],
          ),

        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () =>
                  widget.notifier.selectSong(widget.state.selectedSong!),
              child: Text(AppLocalizations.of(context)!.revert),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: widget.state.isSaving
                  ? null
                  : () async {
                      final success = await widget.notifier.saveChanges();
                      if (!context.mounted) return;

                      if (success) {
                        showCenterNotification(
                          context,
                          label: AppLocalizations.of(context)!.success,
                          title: AppLocalizations.of(context)!.metadataUpdated,
                          icon: Icons.check_circle_outline,
                          centered: true,
                        );
                        if (widget.popOnSave) {
                          Navigator.pop(context);
                        }
                      } else {
                        showCenterNotification(
                          context,
                          label: AppLocalizations.of(context)!.error,
                          title: widget.state.statusMessage.isNotEmpty
                              ? widget.state.statusMessage
                              : AppLocalizations.of(context)!.failedToUpdateMetadata,
                          icon: Icons.error_outline,
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                          centered: true,
                        );
                      }
                    },
              icon: const Icon(Icons.save),
              label: Text(AppLocalizations.of(context)!.saveChangesToFile),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildField(
      String label, TextEditingController ctrl, Function(String) onChanged) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      style: TextStyle(color: widget.textColor),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final searchCtrl = TextEditingController(
        text: "${widget.state.artist} ${widget.state.title}");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(AppLocalizations.of(context)!.searchSpotify),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchHint,
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () async {
                  try {
                    final results =
                        await HybridService.searchMetadata(searchCtrl.text);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    _showResultsDialog(context, results);
                  } catch (e) {
                    if (!context.mounted) return;
                    showCenterNotification(
                      context,
                      label: "Error",
                      title: "Search Failed",
                      subtitle: e.toString(),
                      icon: Icons.error_outline,
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                      centered: true,
                    );
                  }
                },
              ),
            ),
             onSubmitted: (val) async {
              try {
                final results = await HybridService.searchMetadata(val);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!context.mounted) return;
                _showResultsDialog(context, results);
              } catch (e) {
                if (!context.mounted) return;
                showCenterNotification(
                  context,
                  label: "Error",
                  title: "Search Failed",
                  subtitle: e.toString(),
                  icon: Icons.error_outline,
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                  centered: true,
                );
              }
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.cancel))
        ],
      ),
    );
  }

  void _showResultsDialog(
      BuildContext context, List<Map<String, dynamic>> results) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(AppLocalizations.of(context)!.selectMatch),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final r = results[i];
              return ListTile(
                leading: Image.network(r['image_url'] ?? "",
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.music_note)),
                title: Text(r['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${r['artist']} • ${r['album']} • ${r['year']}"),
                trailing: Text("Trk: ${r['track_number']}",
                    style: const TextStyle(fontSize: 10)),
                onTap: () {
                  widget.notifier.applySpotifyData(r);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
