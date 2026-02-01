import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/library_provider.dart';
import '../../providers/metadata_provider.dart';
import '../../services/spotify_service.dart';
import '../../models/song_model.dart';
import '../components/smart_art.dart';

import 'package:permission_handler/permission_handler.dart';

import 'package:device_info_plus/device_info_plus.dart'; // 🚀 IMPORT

class ToolsPage extends ConsumerStatefulWidget {
  const ToolsPage({super.key});

  @override
  ConsumerState<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends ConsumerState<ToolsPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // 🚀 ADD MIXIN
  bool _isLibraryExpanded = false;
  bool _isExternalExpanded = true;
  bool _hasPermission = true;

  // Mobile Support
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🚀 REGISTER OBSERVER
    _tabController = TabController(length: 2, vsync: this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 🚀 REMOVE OBSERVER
    _tabController.dispose();
    super.dispose();
  }

  // 🚀 RE-CHECK ON RESUME
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      // Android 11+ (SDK 30+)
      if (androidInfo.version.sdkInt >= 30) {
        if (await Permission.manageExternalStorage.status.isGranted) {
          setState(() => _hasPermission = true);
        } else {
          setState(() => _hasPermission = false);
        }
      }
      // Android 10 or lower
      else {
        if (await Permission.storage.status.isGranted) {
          setState(() => _hasPermission = true);
        } else {
          setState(() => _hasPermission = false);
        }
      }
    }
  }

  Future<void> _requestPermission() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;

    if (androidInfo.version.sdkInt >= 30) {
      // Direct user to "All Files Access"
      if (await Permission.manageExternalStorage.request().isGranted) {
        setState(() => _hasPermission = true);
      } else {
        // If request() fails to open the specific screen or is denied,
        // we might try openAppSettings() as a fallback, but usually request() handles it.
      }
    } else {
      // Legacy Storage Permission
      if (await Permission.storage.request().isGranted) {
        setState(() => _hasPermission = true);
      } else {
        openAppSettings();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission && Platform.isAndroid) {
      return _buildPermissionRequest();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile Layout (< 800px width)
        if (constraints.maxWidth < 800) {
          return _buildMobileLayout(context);
        }
        // Desktop Layout
        return _buildDesktopLayout(context);
      },
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text("Metadata Editor"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                "Fix your metadata editor in a second and just search it."),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: const Text(
                "Note: Album art is changing after state \"Saved Successfully\", you don't need to worries its not saved, it's just caching problem in app and I currently fix it. You can verify with file manager or else.",
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            "Permission Required",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "To edit tags, we need 'All Files Access' permission. This allows us to modify your music files directly.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _requestPermission,
            icon: const Icon(Icons.check),
            label: const Text("Grant Permission"),
          )
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final metadataState = ref.watch(metadataProvider);

    // Auto-switch to editor tab if a song is selected AND we are on the files tab
    // Note: We need to be careful not to cycle endlessly.
    // Ideally, the selection tap should drive the tab switch.

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        // 🚀 Reserve space for the floating hamburger menu (MainShell)
        leading: const SizedBox(width: 56),
        title: const Text("Metadata Editor", style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Files"),
            Tab(text: "Editor"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showInfoDialog(context),
          ),
          if (metadataState.importedSongs.isNotEmpty)
            IconButton(
                tooltip: "Clear Imported",
                icon: const Icon(Icons.delete_sweep),
                onPressed: () {
                  ref.read(metadataProvider.notifier).clearImported();
                })
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: FILES LIST
          _buildLeftPanel(context, isMobile: true),

          // TAB 2: EDITOR
          _buildRightPanel(context),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final metadataState = ref.watch(metadataProvider);
    final borderColor = Theme.of(context).dividerColor;

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
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.color)),
                      Row(
                        children: [
                          IconButton(
                            tooltip: "Diagnostics",
                            icon: const Icon(Icons.help_outline),
                            onPressed: () => _showInfoDialog(context),
                          ),
                          if (metadataState.importedSongs.isNotEmpty)
                            IconButton(
                              tooltip: "Clear Imported",
                              icon: const Icon(Icons.delete_sweep,
                                  color: Colors.grey),
                              onPressed: ref
                                  .read(metadataProvider.notifier)
                                  .clearImported,
                            )
                        ],
                      )
                    ],
                  ),
                ),
                Expanded(child: _buildLeftPanel(context, isMobile: false)),
              ],
            ),
          ),

          Container(width: 1, color: borderColor),

          // --- RIGHT PANEL ---
          Expanded(
            flex: 6,
            child: _buildRightPanel(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context, {required bool isMobile}) {
    final library = ref.watch(libraryProvider);
    final metadataState = ref.watch(metadataProvider);
    final metadataNotifier = ref.read(metadataProvider.notifier);
    final sectionColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[900]
        : Colors.grey[200];
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildSectionHeader(
            context,
            "Library Data (${library.songs.length})",
            sectionColor!,
            textColor,
            isExpanded: _isLibraryExpanded,
            onToggle: () =>
                setState(() => _isLibraryExpanded = !_isLibraryExpanded),
            onBulkTap: _isLibraryExpanded
                ? () => _showBulkConfirmDialog(
                    context, ref, library.songs, "Library")
                : null,
          ),
        ),
        if (_isLibraryExpanded)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSongTile(context, library.songs[index],
                  metadataState.selectedSong, metadataNotifier,
                  isMobile: isMobile),
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
              onToggle: () =>
                  setState(() => _isExternalExpanded = !_isExternalExpanded),
              onBulkTap: metadataState.importedSongs.isNotEmpty
                  ? () => _showBulkConfirmDialog(context, ref,
                      metadataState.importedSongs, "Imported Files")
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
                    onPressed: () =>
                        metadataNotifier.pickExternalFiles(folder: false),
                    icon: const Icon(Icons.insert_drive_file),
                    label: const Text("Add Files"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        metadataNotifier.pickExternalFiles(folder: true),
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
                  metadataNotifier,
                  isMobile: isMobile),
              childCount: metadataState.importedSongs.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildRightPanel(BuildContext context) {
    // Extracted content of the original Right Panel
    final metadataState = ref.watch(metadataProvider);
    final metadataNotifier = ref.read(metadataProvider.notifier);
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Column(
      children: [
        if (metadataState.isSaving || metadataState.statusMessage.isNotEmpty)
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
                          child: CircularProgressIndicator(strokeWidth: 2))
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
                          size: 64, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text("Select a song from the list to edit",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : metadataState.isLoadingMetadata
                  ? const Center(child: CircularProgressIndicator())
                  : _EditorPanel(
                      // Key includes art bytes hash to force rebuild when art changes
                      key: ValueKey(
                          '${metadataState.selectedSong?.filePath}_${metadataState.selectedSong?.albumArtBytes?.hashCode ?? 0}'),
                      state: metadataState,
                      notifier: metadataNotifier,
                      textColor: textColor,
                    ),
        ),
      ],
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
      SongModel? selected, MetadataNotifier notifier,
      {bool isMobile = false}) {
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
      onTap: () {
        notifier.selectSong(song);
        if (isMobile) {
          _tabController.animateTo(1); // Switch to Editor tab
        }
      },
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
                // Priority: 1) Network URL (new Spotify art) 2) Bytes in memory 3) SmartArt from file
                child: widget.state.coverUrl != null
                    ? Image.network(widget.state.coverUrl!, fit: BoxFit.cover)
                    : (widget.state.selectedSong?.albumArtBytes != null
                        ? Image.memory(
                            widget.state.selectedSong!.albumArtBytes!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        : (widget.state.selectedSong?.filePath != null
                            ? SmartArt(
                                key: ValueKey(
                                    'art_${widget.state.selectedSong!.filePath}_${DateTime.now().millisecondsSinceEpoch}'),
                                path: widget.state.selectedSong!.filePath,
                                size: 140,
                                borderRadius: 8,
                                onlineArtUrl:
                                    widget.state.selectedSong!.onlineArtUrl,
                              )
                            : const Icon(Icons.music_note,
                                size: 50, color: Colors.white24))),
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
