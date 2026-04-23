import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/equalizer_provider.dart';
import '../../providers/player_provider.dart';
import '../../models/eq_preset.dart';
import '../../l10n/app_localizations.dart';
import '../../services/eq_engine.dart';

class EqualizerSheet extends ConsumerStatefulWidget {
  const EqualizerSheet({super.key});

  @override
  ConsumerState<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends ConsumerState<EqualizerSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final playerNotifier = ref.read(playerProvider.notifier);
      final eq = ref.read(equalizerProvider);
      
      if (playerNotifier.audioSessionId != null) {
        eq.setAudioSessionId(playerNotifier.audioSessionId);
      }
      eq.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final eq = ref.watch(equalizerProvider);
    final notifier = ref.read(equalizerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    // WMP-style colors
    const bgColor = Color(0xFF2D2D2D);
    const surfaceColor = Color(0xFF3A3A3A);
    const accentColor = Color(0xFFF28C28);
    const textColor = Colors.white;
    const dimText = Color(0xFF888888);
    const trackColor = Color(0xFF555555);

    final EqPreset? dropdownValue =
        eq.savedPresets.contains(eq.currentPreset) ? eq.currentPreset : null;

    final defaultPresetIds = [
      'flat', 'bass_boost', 'treble_boost', 'headphones', 'laptop', 'portable_speakers', 'home_stereo', 'tv', 'car'
    ];
    final isCustomPreset =
        dropdownValue != null && !defaultPresetIds.contains(dropdownValue.id);

    // dB scale labels
    const dbLabels = ['+12 dB', '+6 dB', '0 dB', '-6 dB', '-12 dB'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === HEADER: Title + On/Off Toggle ===
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Equalizer',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text(eq.isEnabled ? 'On' : 'Off',
                      style: const TextStyle(color: dimText, fontSize: 14)),
                  const SizedBox(width: 8),
                  Switch(
                    value: eq.isEnabled,
                    onChanged: (val) => notifier.toggleEnabled(val),
                    activeColor: accentColor,
                    activeTrackColor: accentColor.withValues(alpha: 0.4),
                    inactiveThumbColor: dimText,
                    inactiveTrackColor: trackColor,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // === PRESET DROPDOWN ===
          Row(
            children: [
              const Text('Preset',
                  style: TextStyle(color: dimText, fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: trackColor, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<EqPreset>(
                      value: dropdownValue,
                      hint: Text(eq.currentPreset?.name ?? "Custom",
                          style: const TextStyle(color: textColor, fontSize: 14)),
                      dropdownColor: surfaceColor,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: dimText, size: 20),
                      style: const TextStyle(color: textColor, fontSize: 14),
                      items: eq.savedPresets.map((preset) {
                        return DropdownMenuItem(
                          value: preset,
                          child: Text(preset.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) notifier.loadPreset(val);
                      },
                    ),
                  ),
                ),
              ),
              if (isCustomPreset) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  tooltip: l10n.deletePreset,
                  onPressed: () {
                    if (dropdownValue != null) {
                      notifier.deletePreset(dropdownValue.id);
                    }
                  },
                ),
              ]
            ],
          ),

          const SizedBox(height: 12),

          // === PRE-AMP SLIDER ===
          Row(
            children: [
              const Text('Pre-amp',
                  style: TextStyle(color: dimText, fontSize: 12, fontWeight: FontWeight.w600)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: accentColor.withValues(alpha: 0.7),
                    inactiveTrackColor: trackColor,
                    thumbColor: accentColor,
                    disabledActiveTrackColor: trackColor,
                    disabledThumbColor: dimText,
                  ),
                  child: Slider(
                    value: eq.preampGain,
                    min: -12,
                    max: 12,
                    onChanged: eq.isEnabled
                        ? (val) => notifier.setPreamp(val)
                        : null,
                  ),
                ),
              ),
              SizedBox(
                width: 42,
                child: Text('${eq.preampGain.toStringAsFixed(0)} dB',
                    style: const TextStyle(color: dimText, fontSize: 11)),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // === 10-BAND EQ: dB scale + vertical sliders ===
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // dB scale labels (left column)
                SizedBox(
                  width: 44,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: dbLabels.map((label) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(label,
                          style: const TextStyle(color: dimText, fontSize: 10)),
                    )).toList(),
                  ),
                ),

                // Slider columns
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(EqEngine.bandCount, (index) {
                      final gain = (eq.currentPreset?.gains.length ?? 0) > index
                          ? eq.currentPreset!.gains[index]
                          : 0.0;

                      return Expanded(
                        child: Column(
                          children: [
                            // Vertical slider with Tick Marks
                            Expanded(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // --- TICK MARKS (Strips) ---
                                  Positioned.fill(
                                    top: 10,
                                    bottom: 10,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: List.generate(9, (i) {
                                        // 9 positions: +12, +9, +6, +3, 0, -3, -6, -9, -12
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('-', style: TextStyle(color: (i % 2 == 0) ? dimText : trackColor.withValues(alpha: 0.5), fontSize: 10)),
                                            Text('-', style: TextStyle(color: (i % 2 == 0) ? dimText : trackColor.withValues(alpha: 0.5), fontSize: 10)),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                  
                                  // --- ACTUAL SLIDER ---
                                  RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 2,
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 7),
                                        overlayShape: const RoundSliderOverlayShape(
                                            overlayRadius: 14),
                                        activeTrackColor: accentColor,
                                        inactiveTrackColor: trackColor,
                                        thumbColor: accentColor,
                                        overlayColor: accentColor.withValues(alpha: 0.2),
                                        showValueIndicator: ShowValueIndicator.always,
                                        valueIndicatorShape: const HorizontalValueIndicatorShape(),
                                        valueIndicatorColor: surfaceColor,
                                        valueIndicatorTextStyle: const TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                                        disabledActiveTrackColor: trackColor,
                                        disabledThumbColor: dimText,
                                      ),
                                      child: Slider(
                                        value: gain,
                                        min: -12.0,
                                        max: 12.0,
                                        label: '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)} dB',
                                        onChanged: eq.isEnabled
                                            ? (val) => notifier.updateBand(index, val)
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Frequency label
                            Text(
                              _formatFreq(EqEngine.bandFrequencies[index]),
                              style: const TextStyle(
                                  color: dimText, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // === SAVE BUTTON ===
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: eq.isEnabled
                  ? () => _showSaveDialog(context, notifier)
                  : null,
              child: Text(l10n.saveAsNewPreset,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          )
        ],
      ),
    );
  }

  String _formatFreq(int hz) {
    if (hz >= 1000) {
      return '${hz ~/ 1000} kHz';
    }
    return '$hz Hz';
  }

  void _showSaveDialog(BuildContext context, EqualizerProvider notifier) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3A3A3A),
        title: Text(l10n.savePreset,
            style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: l10n.enterPresetName,
            hintStyle: const TextStyle(color: Color(0xFF888888)),
            enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF555555))),
            focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFF28C28))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel,
                style: const TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF28C28),
            ),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                notifier.saveCurrentAsNew(controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.presetSaved)));
              }
            },
            child: Text(l10n.save,
                style: const TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}

class HorizontalValueIndicatorShape extends SliderComponentShape {
  const HorizontalValueIndicatorShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(48, 24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    if (activationAnimation.value == 0) return;

    final Canvas canvas = context.canvas;
    
    // The canvas is currently rotated 270 degrees (via RotatedBox 3 turns).
    // We need to move to the thumb center, rotate BACK 90 degrees, and draw.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(1.5708); // Rotate back 90 degrees (pi/2) to make it horizontal
    
    // Draw the rounded background box
    final double padding = 8.0;
    final Size labelSize = labelPainter.size;
    final double rectWidth = labelSize.width + padding * 2;
    final double rectHeight = labelSize.height + padding;
    final RRect rrect = RRect.fromLTRBR(
      -rectWidth / 2,
      -rectHeight - 20, // Offset above the thumb
      rectWidth / 2,
      -20,
      const Radius.circular(6),
    );

    final Paint paint = Paint()..color = sliderTheme.valueIndicatorColor ?? Colors.black;
    canvas.drawRRect(rrect, paint);

    // Draw the text
    labelPainter.paint(
      canvas,
      Offset(-labelSize.width / 2, -rectHeight - 20 + (padding / 2)),
    );

    canvas.restore();
  }
}
