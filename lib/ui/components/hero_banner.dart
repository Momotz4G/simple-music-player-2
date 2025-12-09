import 'dart:async';
import 'package:flutter/material.dart';

class HeroBanner extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final Function(Map<String, dynamic>) onTap;

  const HeroBanner({
    super.key,
    required this.items,
    required this.onTap,
  });

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (widget.items.isEmpty) return;
      if (_controller.hasClients) {
        int nextPage = _currentPage + 1;
        if (nextPage >= widget.items.length) {
          nextPage = 0;
        }
        _controller.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _manualNav(int direction) {
    if (!_controller.hasClients) return;

    // Reset timer so it doesn't auto-scroll immediately after user clicks
    _startAutoScroll();

    int nextPage = _currentPage + direction;

    // Loop logic for manual clicks
    if (nextPage < 0) {
      nextPage = widget.items.length - 1; // Loop to end
      _controller.jumpToPage(nextPage); // Jump for infinite feel (optional)
    } else if (nextPage >= widget.items.length) {
      nextPage = 0; // Loop to start
      _controller.animateToPage(0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic);
    } else {
      _controller.animateToPage(nextPage,
          duration: const Duration(milliseconds: 600), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 350,
      child: Stack(
        children: [
          // 1. The PageView
          PageView.builder(
            controller: _controller,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => widget.onTap(item),
                  child: _buildBannerItem(context, item),
                ),
              );
            },
          ),

          // 2. Previous Button (Left)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _manualNav(-1),
              ),
            ),
          ),

          // 3. Next Button (Right)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _manualNav(1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withOpacity(0.3), // Semi-transparent dark background
      shape: const CircleBorder(),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        hoverColor: Colors.white.withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildBannerItem(BuildContext context, Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        image: DecorationImage(
          image: NetworkImage(item['image_url']),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0.3, 0.6, 1.0],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "NEW RELEASE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  item['artist'],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 5, color: Colors.black54)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
