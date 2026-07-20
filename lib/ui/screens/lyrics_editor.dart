
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/player_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class LyricsEditor extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  const LyricsEditor({super.key, required this.onBack});

  @override
  ConsumerState<LyricsEditor> createState() => _LyricsEditorState();
}

class _LyricsEditorState extends ConsumerState<LyricsEditor> {
  bool _isSyncedMode = true;
  bool _isGenerating = false;
  final TextEditingController _plainController = TextEditingController();
  List<LyricLine> _editedLines = [];

  // Cache controllers to avoid rebuild flicker
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, TextEditingController> _startControllers = {};
  final Map<String, TextEditingController> _endControllers = {};
  final Map<String, TextEditingController> _romanControllers = {};

  void _seekTo(double seconds) {
    ref.read(playerProvider.notifier).seek(seconds);
  }

  void _seekRelative(double offsetSeconds) {
    final current = ref.read(playerProvider).currentPosition; // This is a double (seconds)
    final target = current + offsetSeconds;
    ref.read(playerProvider.notifier).seek(target);
  }

  @override
  void dispose() {
    _plainController.dispose();
    for (var c in _textControllers.values) {
      c.dispose();
    }
    for (var c in _startControllers.values) {
      c.dispose();
    }
    for (var c in _endControllers.values) {
      c.dispose();
    }
    for (var c in _romanControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFromProvider();
  }

  void _loadFromProvider() {
    final state = ref.read(lyricsProvider);
    _plainController.text = state.rawLyrics;
    _editedLines = List.from(state.parsedLyrics);
    // If parsed lyrics is empty but raw is not, maybe default to plain mode
    if (_editedLines.isEmpty && _plainController.text.isNotEmpty) {
      _isSyncedMode = false;
    }
  }

  void _syncStart(int index) {
    final currentPos = ref.read(playerProvider).currentPosition;
    setState(() {
      _editedLines[index] = _editedLines[index].copyWith(time: currentPos);
    });
  }

  void _syncEnd(int index) {
    final currentPos = ref.read(playerProvider).currentPosition;
    setState(() {
      _editedLines[index] = _editedLines[index].copyWith(endTime: currentPos);
    });
  }

  double? _parseTimeString(String val) {
    try {
      if (val.contains(':')) {
        final parts = val.split(':');
        final minutes = double.parse(parts[0]);
        final seconds = double.parse(parts[1]);
        return (minutes * 60) + seconds;
      } else {
        return double.parse(val);
      }
    } catch (_) {
      return null;
    }
  }

  void _addLine({int? index}) {
    final newLine = LyricLine(
      time: index != null && index > 0 ? _editedLines[index - 1].time + 2.0 : 0.0,
      text: "",
    );
    setState(() {
      if (index == null) {
        _editedLines.add(newLine);
      } else {
        _editedLines.insert(index, newLine);
      }
    });
  }

  void _removeLine(int index) {
    setState(() {
      _editedLines.removeAt(index);
    });
  }

  Future<void> _clearAll() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.clearAllQuestion, style: const TextStyle(color: Colors.white)),
        content: Text(l10n.clearAllDesc, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clearBtn, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _editedLines = [];
        _plainController.clear();
      });
    }
  }

  Future<void> _generateAi() async {
    debugPrint("💎 Lyrics Editor: AI Generate Button Pressed");
    final currentSong = ref.read(playerProvider).currentSong;
    if (currentSong == null) {
      debugPrint("⚠️ Lyrics Editor: No song currently playing");
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final l10n = AppLocalizations.of(context)!;
      await ref.read(lyricsProvider.notifier).generateAiLyrics(
        currentSong.filePath,
        statusMessages: {
          'initializing': l10n.aiLyricsInitializing,
          'uploading': l10n.aiLyricsUploading,
          'uploadFailed': l10n.aiLyricsUploadFailed,
          'uploadSuccess': l10n.aiLyricsUploadSuccess,
          'verifying': l10n.aiLyricsVerifying,
          'statusOk': l10n.aiLyricsStatusOk,
          'polling': l10n.aiLyricsPolling,
          'receiving': l10n.aiLyricsReceiving,
          'parsing': l10n.aiLyricsParsing,
          'success': l10n.aiLyricsSuccess,
          'localFileMissing': l10n.aiLyricsLocalFileMissing,
          'complete': l10n.aiLyricsComplete,
        },
      );
      _loadFromProvider();
      setState(() => _isSyncedMode = true);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _applyChanges() {
    if (_isSyncedMode) {
      ref.read(lyricsProvider.notifier).updateFromEditor(
        parsed: _editedLines,
      );
    } else {
      ref.read(lyricsProvider.notifier).updateFromEditor(
        raw: _plainController.text,
        parsed: [], // Plain mode clears parsed lines
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.lyricsApplied)),
    );
  }

  Future<void> _saveToFile() async {
    final currentSong = ref.read(playerProvider).currentSong;
    if (currentSong == null) return;

    final l10n = AppLocalizations.of(context)!;
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.saveLyricsTitle, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.chooseFormat, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            _buildFormatOption(
              context,
              title: l10n.lrcFormat,
              subtitle: l10n.lrcFormatDesc,
              icon: Icons.description_outlined,
              value: "lrc",
            ),
            const SizedBox(height: 12),
            _buildFormatOption(
              context,
              title: l10n.ttmlFormat,
              subtitle: l10n.ttmlFormatDesc,
              icon: Icons.auto_awesome_outlined,
              value: "ttml",
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ],
      ),
    );

    if (format == null) return;

    // Second confirmation if file exists (Optional, but safe)
    _applyChanges(); // Apply first
    
    final String extension = '.$format';
    final String savePath = currentSong.filePath.replaceAll(RegExp(r'\.[^.]+$'), extension);
    
    final success = await ref.read(lyricsProvider.notifier).saveLyrics(
      savePath,
      asTtml: format == "ttml",
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.savedSuccessfully(extension)),
          backgroundColor: Colors.green.withValues(alpha: 0.8),
        ),
      );
    }
  }

  Widget _buildFormatOption(BuildContext context, {required String title, required String subtitle, required IconData icon, required String value}) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.03),
        ),
        child: Row(
          children: [
            Icon(icon, color: value == "ttml" ? Colors.amber : Colors.blueAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    // Listen for song changes to reload
    ref.listen(playerProvider.select((s) => s.currentSong), (prev, next) {
      if (next != prev) {
        _loadFromProvider();
      }
    });

    return Stack(
      children: [
        Container(
          color: Colors.transparent,
          child: Column(
            children: [
              _buildHeader(),
              _buildToolbar(),
              Expanded(
                child: _isSyncedMode ? _buildSyncedEditor() : _buildPlainEditor(),
              ),
              _buildBottomActions(),
            ],
          ),
        ),
        if (lyricsState.generationStatus != null)
          _buildGenerationOverlay(lyricsState),
      ],
    );
  }

  Widget _buildGenerationOverlay(LyricsState lyricsState) {
    final status = lyricsState.generationStatus!;
    final l10n = AppLocalizations.of(context)!;
    final isError = status.toLowerCase().contains("error");
    final isComplete = status.toLowerCase().contains("complete") || status.toLowerCase().contains("successful");
    
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 320,
            constraints: const BoxConstraints(minHeight: 200),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isError ? Colors.redAccent.withValues(alpha: 0.5) : Colors.amber.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: isError ? Colors.redAccent.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isError && !isComplete)
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(color: Colors.amber),
                  )
                else if (isComplete)
                  const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 48)
                else
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 24),
                Text(
                  isError ? l10n.generationFailed : (isComplete ? l10n.success : l10n.aiLyricsGenerationTitle),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: isError ? Colors.redAccent : (isComplete ? Colors.greenAccent : Colors.white70),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                // Mini Console
                Container(
                  height: 100,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: lyricsState.generationLogs.length,
                    reverse: true, // Show latest at bottom
                    itemBuilder: (context, i) {
                      final log = lyricsState.generationLogs[lyricsState.generationLogs.length - 1 - i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          "> $log",
                          style: GoogleFonts.firaCode(
                            color: Colors.white38,
                            fontSize: 9,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (isError) ...[
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => ref.read(lyricsProvider.notifier).state = ref.read(lyricsProvider).copyWith(generationStatus: ""),
                    child: Text(l10n.close, style: const TextStyle(color: Colors.white54)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: widget.onBack,
          ),
          Text(
            l10n.lyricsEditorTitle,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _isGenerating ? null : () {
              _generateAi();
            },
            icon: Icon(Icons.auto_awesome, color: _isGenerating ? Colors.white24 : Colors.amber),
            label: Text(l10n.aiGenerate, style: GoogleFonts.outfit(color: _isGenerating ? Colors.white24 : Colors.amber)),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(l10n.syncedMode),
            selected: _isSyncedMode,
            onSelected: (val) => setState(() => _isSyncedMode = true),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(l10n.plainMode),
            selected: !_isSyncedMode,
            onSelected: (val) => setState(() => _isSyncedMode = false),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: _clearAll,
            tooltip: l10n.clearAll,
          ),
          if (_isSyncedMode) ...[
            IconButton(
              icon: const Icon(Icons.vertical_align_top, color: Colors.white, size: 20),
              onPressed: () => _addLine(index: 0),
              tooltip: l10n.addLineToTop,
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _addLine(),
              tooltip: l10n.addLineToEnd,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncedEditor() {
    final l10n = AppLocalizations.of(context)!;
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _editedLines.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final line = _editedLines.removeAt(oldIndex);
          _editedLines.insert(newIndex, line);
        });
      },
      itemBuilder: (context, index) {
        final line = _editedLines[index];
        return Card(
          key: ValueKey("line_$index"),
          color: Colors.white.withValues(alpha: 0.05),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.drag_handle, color: Colors.white54),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textControllers.putIfAbsent("text_$index", () => TextEditingController(text: line.text)),
                        onChanged: (val) => _editedLines[index] = line.copyWith(text: val),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: l10n.lyricTextHint,
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 20),
                      onPressed: () => _addLine(index: index + 1),
                      tooltip: l10n.insertAfter,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      onPressed: () => _removeLine(index),
                      tooltip: l10n.removeLine,
                    ),
                  ],
                ),
                // Romanization Field
                Padding(
                  padding: const EdgeInsets.only(left: 32, right: 8, bottom: 8),
                  child: TextField(
                    controller: _romanControllers.putIfAbsent("roman_$index", () => TextEditingController(text: line.romanizedText ?? "")),
                    onChanged: (val) => _editedLines[index] = line.copyWith(romanizedText: val),
                    style: const TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
                    decoration: InputDecoration(
                      hintText: l10n.romajiHint,
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const Divider(color: Colors.white10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(l10n.startLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _startControllers.putIfAbsent("start_$index", () => TextEditingController(text: _formatTime(line.time))),
                            onChanged: (val) {
                              final parsed = _parseTimeString(val);
                              if (parsed != null) {
                                _editedLines[index] = line.copyWith(time: parsed);
                              }
                            },
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.timer, color: Colors.greenAccent, size: 20),
                          onPressed: () => _syncStart(index),
                          tooltip: l10n.setStartTooltip,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(l10n.endLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _endControllers.putIfAbsent("end_$index", () => TextEditingController(text: _formatTime(line.endTime ?? (index < _editedLines.length - 1 ? _editedLines[index+1].time : line.time + 5.0)))),
                            onChanged: (val) {
                              final parsed = _parseTimeString(val);
                              if (parsed != null) {
                                _editedLines[index] = line.copyWith(endTime: parsed);
                              }
                            },
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.timer_off, color: Colors.orangeAccent, size: 20),
                          onPressed: () => _syncEnd(index),
                          tooltip: l10n.setEndTooltip,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Mini Player Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_double_arrow_left, color: Colors.white54, size: 20),
                      onPressed: () => _seekRelative(-0.5),
                      tooltip: "-0.5s",
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        onPressed: () => _seekTo(line.time),
                        tooltip: l10n.playFromLine,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.keyboard_double_arrow_right, color: Colors.white54, size: 20),
                      onPressed: () => _seekRelative(0.5),
                      tooltip: "+0.5s",
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlainEditor() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _plainController,
        maxLines: null,
        expands: true,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: l10n.pasteLyricsHint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    final l10n = AppLocalizations.of(context)!;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: const Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyChanges,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
                    child: Text(l10n.applyBtn, style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveToFile,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent.withValues(alpha: 0.5)),
                    child: Text(l10n.saveLocallyBtn, style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(double seconds) {
    final m = (seconds / 60).floor();
    final s = (seconds % 60).floor();
    final ms = ((seconds % 1) * 100).floor();
    return "$m:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}";
  }
}
