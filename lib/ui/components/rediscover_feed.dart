import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song_model.dart';
import '../../providers/player_provider.dart';
import 'smart_art.dart';

class RediscoverFeed extends ConsumerStatefulWidget {
  final List<SongModel> initialPool; // Your 21 Deep Cuts
  final List<SongModel> allLibrarySongs; // The rest of your library

  const RediscoverFeed({
    super.key,
    required this.initialPool,
    required this.allLibrarySongs,
  });

  @override
  ConsumerState<RediscoverFeed> createState() => _RediscoverFeedState();
}

class _RediscoverFeedState extends ConsumerState<RediscoverFeed> {
  late final PageController _controller;
  Timer? _timer;

  final List<SongModel> _feedQueue = [];
  final Set<String> _shownSongPaths = {};

  List<SongModel> _currentDeck = [];
  int _currentPage = 0;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _fillQueueBuffer();
    _controller =
        PageController(initialPage: _currentPage, viewportFraction: 0.85);
    _startTimer();
  }

  void _fillQueueBuffer() {
    while (_feedQueue.length < _currentPage + 10) {
      _addNextSongFromDeck();
    }
  }

  void _addNextSongFromDeck() {
    if (widget.allLibrarySongs.isEmpty) return;

    // REFILL DECK
    if (_currentDeck.isEmpty) {
      if (_feedQueue.isEmpty) {
        // Round 1: Priority Deep Cuts
        _currentDeck = List.from(widget.initialPool)..shuffle();
      } else {
        // Round 2+: Fresh Library Songs
        final freshSongs = widget.allLibrarySongs
            .where((s) => !_shownSongPaths.contains(s.filePath))
            .toList();

        if (freshSongs.isNotEmpty) {
          _currentDeck = freshSongs..shuffle();
        } else {
          // Round 3: Reset everything and start true loop
          _shownSongPaths.clear();
          _currentDeck = List.from(widget.allLibrarySongs)..shuffle();
        }
      }
    }

    // Deal Card
    if (_currentDeck.isNotEmpty) {
      final song = _currentDeck.removeAt(0);
      _feedQueue.add(song);
      _shownSongPaths.add(song.filePath);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isHovering && mounted && _controller.hasClients) {
        _fillQueueBuffer();

        setState(() {
          _currentPage++;
        });

        _controller.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutQuart,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialPool.isEmpty && widget.allLibrarySongs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: Text(
            "Rediscover",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(
          height: 280,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              // 1. DISABLE MANUAL SCROLLING
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                if (index >= _feedQueue.length - 2) {
                  _fillQueueBuffer();
                }
                if (index >= _feedQueue.length) return const SizedBox();

                return _buildSongCard(_feedQueue[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSongCard(SongModel song) {
    // 2. CHANGE CURSOR TO CLICKABLE LINK STYLE
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ref.read(playerProvider.notifier).playSong(song);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.grey[900],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Use SmartArt for the large background image
                // We use opacity + color blend to darken it for text readability
                ImageFiltered(
                  imageFilter:
                      ColorFilter.mode(Colors.black54, BlendMode.darken),
                  child: SmartArt(
                    path: song.filePath,
                    size: 400, // Load a reasonably large image
                    borderRadius: 0,
                    onlineArtUrl: song.onlineArtUrl,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 5,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          // Use SmartArt for the small thumbnail
                          child: SmartArt(
                            path: song.filePath,
                            size: 80,
                            borderRadius: 10,
                            onlineArtUrl: song.onlineArtUrl,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Do you remember?",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(Icons.play_arrow, color: Colors.white),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
