import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';

class WhatsNewDialog extends StatefulWidget {
  final String version;
  final String changelog;
  const WhatsNewDialog({
    super.key,
    required this.version,
    required this.changelog,
  });

  @override
  State<WhatsNewDialog> createState() => _WhatsNewDialogState();
}

class _WhatsNewDialogState extends State<WhatsNewDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final List<WhatsNewSlide> _slides;

  String _cleanChangelog(String text) {
    if (text.isEmpty) {
      return 'No additional changelog details available for this version.';
    }

    // 1. Truncate at ---
    String cleaned = text.split('---').first.trim();

    // 2. Remove ### tags, *, and _
    cleaned =
        cleaned.replaceAll('### ', '').replaceAll('*', '').replaceAll('_', '');

    return cleaned;
  }

  @override
  void initState() {
    super.initState();
    _slides = [
      WhatsNewSlide(
        title: 'Changelog',
        description: _cleanChangelog(widget.changelog),
        icon: Icons.list_alt_rounded,
        color: Colors.orangeAccent,
        isScrollable: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width > 600 ? 550.0 : screenSize.width * 0.9;
    final dialogHeight =
        screenSize.height > 800 ? 650.0 : screenSize.height * 0.8;

    return Center(
      child: GlassmorphicContainer(
        width: dialogWidth,
        height: dialogHeight,
        borderRadius: 24,
        blur: 20,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
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
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(Icons.celebration_rounded, color: accentColor),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What\'s New',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Version ${widget.version}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),

              // Carousel
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: screenSize.width > 600 ? 40 : 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!slide.isScrollable) ...[
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    slide.color.withValues(alpha: 0.3),
                                    slide.color.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                              child: Icon(
                                slide.icon,
                                size: screenSize.width > 400 ? 100 : 70,
                                color: slide.color,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              slide.description,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                                height: 1.5,
                              ),
                            ),
                          ] else ...[
                            Text(
                              slide.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: SingleChildScrollView(
                                  child: Text(
                                    slide.description,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      height: 1.6,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Indicators (Only show if multiple slides)
                    if (_slides.length > 1)
                      Row(
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? accentColor
                                  : Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),

                    // Navigation Button
                    if (_currentPage == _slides.length - 1)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Awesome!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Next',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded,
                                color: accentColor),
                          ],
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

class WhatsNewSlide {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isScrollable;

  WhatsNewSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isScrollable = false,
  });
}
