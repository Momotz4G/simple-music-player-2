import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/library_provider.dart';
import '../../providers/metadata_provider.dart';
import '../../services/spotify_service.dart';
import '../../models/song_model.dart';
import '../components/smart_art.dart';

class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  @override
  ConsumerState<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends ConsumerState<ToolsPage> {
  bool _isLibraryExpanded = false;
  bool _isExternalExpanded = true;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final metadataState = ref.watch(metadataProvider);
    final metadataNotifier = ref.read(metadataProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final sectionColor = isDark ? Colors.grey[900] : Colors.grey[200];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // --- LEFT PANEL ---
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Metadata Editor",
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                      if (metadataState.importedSongs.isNotEmpty)
                        IconButton(
                          tooltip: "Clear Imported",
                          icon: const Icon(Icons.delete_sweep,
                              color: Colors.grey),
                          onPressed: metadataNotifier.clearImported,
                        )
                    ],
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildSectionHeader(
                          context,
                          "Library Data (${library.songs.length})",
                          sectionColor!,
                          textColor,
                          isExpanded: _isLibraryExpanded,
                          onToggle: () => setState(
                              () => _isLibraryExpanded = !_isLibraryExpanded),
                          onBulkTap: _isLibraryExpanded
                              ? () => _showBulkConfirmDialog(
                                  context, ref, library.songs, "Library")
                              : null,
                        ),
                      ),
                      if (_isLibraryExpanded)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildSongTile(
                                context,
                                library.songs[index],
                                metadataState.selectedSong,
                                metadataNotifier),
                            childCount: library.songs.length,
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: _buildSectionHeader(
                            context,
                            "External Files (${metadataState.importedSongs.length})",
                            sectionColor,
                            textColor,
                            isExpanded: _isExternalExpanded,
                            onToggle: () => setState(() =>
                                _isExternalExpanded = !_isExternalExpanded),
                            onBulkTap: metadataState.importedSongs.isNotEmpty
                                ? () => _showBulkConfirmDialog(
                                    context,
                                    ref,
                                    metadataState.importedSongs,
                                    "Imported Files")
                                : null,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => metadataNotifier
                                      .pickExternalFiles(folder: false),
                                  icon: const Icon(Icons.insert_drive_file),
                                  label: const Text("Add Files"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => metadataNotifier
                                      .pickExternalFiles(folder: true),
                                  icon: const Icon(Icons.create_new_folder),
                                  label: const Text("Add Folder"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isExternalExpanded)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildSongTile(
                                context,
                                metadataState.importedSongs[index],
                                metadataState.selectedSong,
                                metadataNotifier),
                            childCount: metadataState.importedSongs.length,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(width: 1, color: borderColor),

          // --- RIGHT PANEL ---
          Expanded(
            flex: 6,
            child: Column(
              children: [
                if (metadataState.isSaving ||
                    metadataState.statusMessage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: metadataState.isSaving
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: metadataState.isSaving
                              ? Colors.blue.withOpacity(0.3)
                              : Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (metadataState.isSaving)
                              const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                            else
                              const Icon(Icons.check_circle,
                                  size: 16, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(metadataState.statusMessage,
                                    style: TextStyle(color: textColor))),
                          ],
                        ),
                        if (metadataState.progressTotal > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: LinearProgressIndicator(
                              value: metadataState.progressCurrent /
                                  metadataState.progressTotal,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          )
                      ],
                    ),
                  ),
                Expanded(
                  child: metadataState.selectedSong == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_note,
                                  size: 64,
                                  color: Colors.grey.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              const Text("Select a song from the left to edit",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : metadataState.isLoadingMetadata
                          ? const Center(child: CircularProgressIndicator())
                          : _EditorPanel(
                              key: ValueKey(
                                  metadataState.selectedSong?.filePath),
                              state: metadataState,
                              notifier: metadataNotifier,
                              textColor: textColor,
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, Color bg, Color text,
      {required bool isExpanded,
      required VoidCallback onToggle,
      VoidCallback? onBulkTap}) {
    return Material(
      color: bg,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 18,
                      color: text.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Text(title,
                      style: TextStyle(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
              ),
              if (onBulkTap != null)
                SizedBox(
                  height: 24,
                  child: FilledButton.icon(
                    onPressed: null, // 🚀 DISABLED AS REQUESTED
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.grey,
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    icon: const Icon(Icons.auto_fix_high,
                        size: 14, color: Colors.white38),
                    label: const Text("Fix All",
                        style: TextStyle(fontSize: 10, color: Colors.white38)),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongTile(BuildContext context, SongModel song,
      SongModel? selected, MetadataNotifier notifier) {
    final isSelected = song.filePath == selected?.filePath;
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
    return ListTile(
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
      // ✅ FIX: Use SmartArt here
      leading: SmartArt(
        path: song.filePath,
        size: 40,
        borderRadius: 4,
        onlineArtUrl: song.onlineArtUrl,
      ),
      title: Text(song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: textColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(song.artist,
          maxLines: 1,
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
      onTap: () => notifier.selectSong(song),
    );
  }

  void _showBulkConfirmDialog(BuildContext context, WidgetRef ref,
      List<SongModel> songs, String sourceName) {
    if (songs.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("⚠️ Auto-Tag $sourceName?"),
        content: Text(
            "This will search Spotify for all ${songs.length} songs in '$sourceName' and overwrite their tags automatically.\n\nThis process cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(metadataProvider.notifier).autoMatchAll(songs);
            },
            child: const Text("Start Bulk Process"),
          ),
        ],
      ),
    );
  }
}

class _EditorPanel extends StatefulWidget {
  final MetadataState state;
  final MetadataNotifier notifier;
  final Color textColor;

  const _EditorPanel(
      {super.key,
      required this.state,
      required this.notifier,
      required this.textColor});

  @override
  State<_EditorPanel> createState() => _EditorPanelState();
}

class _EditorPanelState extends State<_EditorPanel> {
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
  void didUpdateWidget(covariant _EditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.title != _titleCtrl.text) {
      _initControllers();
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
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Art
            Container(
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
                // FIX: Logic to handle Network URL (New Art) OR File Path (Existing)
                child: widget.state.coverUrl != null
                    ? Image.network(widget.state.coverUrl!, fit: BoxFit.cover)
                    : (widget.state.selectedSong?.filePath != null
                        ? SmartArt(
                            path: widget.state.selectedSong!.filePath,
                            size: 140,
                            borderRadius: 8,
                            onlineArtUrl:
                                widget.state.selectedSong!.onlineArtUrl,
                          )
                        : const Icon(Icons.music_note,
                            size: 50, color: Colors.white24)),
              ),
            ),
            const SizedBox(width: 24),

            Expanded(
              child: Column(
                children: [
                  _buildField("Title", _titleCtrl,
                      (v) => widget.notifier.updateField(title: v)),
                  const SizedBox(height: 12),
                  _buildField("Artist", _artistCtrl,
                      (v) => widget.notifier.updateField(artist: v)),
                  const SizedBox(height: 12),
                  _buildField("Album", _albumCtrl,
                      (v) => widget.notifier.updateField(album: v)),
                  const SizedBox(height: 12),
                  _buildField("Genre", _genreCtrl,
                      (v) => widget.notifier.updateField(genre: v)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _buildField("Year", _yearCtrl,
                              (v) => widget.notifier.updateField(year: v))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildField("Track #", _trackCtrl,
                              (v) => widget.notifier.updateField(track: v))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildField("Disc #", _discCtrl,
                              (v) => widget.notifier.updateField(disc: v))),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome, color: Colors.white),
                label: const Text("Auto-Fix (Coming Soon)"),
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent.withOpacity(0.5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  disabledBackgroundColor: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text("Manual Search"),
                onPressed: () => _showSearchDialog(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
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
              child: const Text("Revert"),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed:
                  widget.state.isSaving ? null : widget.notifier.saveChanges,
              icon: const Icon(Icons.save),
              label: const Text("Save Changes to File"),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
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
        title: const Text("Search Spotify"),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Search...",
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () async {
                  final results =
                      await SpotifyService.searchMetadata(searchCtrl.text);
                  Navigator.pop(ctx);
                  _showResultsDialog(context, results);
                },
              ),
            ),
            onSubmitted: (val) async {
              final results = await SpotifyService.searchMetadata(val);
              Navigator.pop(ctx);
              _showResultsDialog(context, results);
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))
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
        title: const Text("Select Match"),
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
