import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../providers/equalizer_provider.dart';
import '../../providers/player_provider.dart';
import '../../models/eq_preset.dart';

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
        eq.init(playerNotifier.audioSessionId!);
        if (!eq.isEnabled) eq.toggleEnabled(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final eq = ref.watch(equalizerProvider);
    final notifier = ref.read(equalizerProvider.notifier);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black;

    final EqPreset? dropdownValue =
        eq.savedPresets.contains(eq.currentPreset) ? eq.currentPreset : null;

    final isCustomPreset = dropdownValue != null &&
        !['flat', 'bass', 'rock', 'pop', 'vocal'].contains(dropdownValue.id);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Equalizer",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: textColor)),
              Switch(
                value: eq.isEnabled,
                onChanged: (val) => notifier.toggleEnabled(val),
                activeColor: accentColor,
              )
            ],
          ),

          if (!Platform.isAndroid)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                  "Note: Audio effects are only audible on Android devices.",
                  style: TextStyle(color: Colors.orange, fontSize: 12)),
            ),

          const SizedBox(height: 16),

          // --- PRESET DROPDOWN & DELETE ---
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<EqPreset>(
                      value: dropdownValue,
                      hint: Text(eq.currentPreset?.name ?? "Custom",
                          style: TextStyle(color: textColor)),
                      dropdownColor: Theme.of(context).cardColor,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down_rounded,
                          color: accentColor),
                      style: TextStyle(color: textColor, fontSize: 16),
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
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: "Delete Preset",
                  onPressed: () {
                    if (dropdownValue != null) {
                      notifier.deletePreset(dropdownValue.id);
                    }
                  },
                ),
              ]
            ],
          ),

          const Spacer(),

          // --- FREQUENCY LABELS & SLIDERS ---
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (index) {
                // Ensure we have a label
                String label = "";
                if (index < eq.freqLabels.length) {
                  label = eq.freqLabels[index];
                }

                final gain = (eq.currentPreset?.gains.length ?? 0) > index
                    ? eq.currentPreset!.gains[index]
                    : 0.0;

                return Column(
                  children: [
                    // Frequency Label (Top)
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // Slider
                    Expanded(
                      child: SizedBox(
                        width: 30,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16),
                            ),
                            child: Slider(
                              value: gain,
                              min: -10,
                              max: 10,
                              activeColor: accentColor,
                              inactiveColor:
                                  isDark ? Colors.grey[800] : Colors.grey[300],
                              onChanged: eq.isEnabled
                                  ? (val) => notifier.updateBand(index, val)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // dB Label (Bottom)
                    Text("${gain.toInt()}dB",
                        style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.grey[600] : Colors.grey[400])),
                  ],
                );
              }),
            ),
          ),

          const Spacer(),

          // --- SAVE BUTTON ---
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: eq.isEnabled
                  ? () {
                      _showSaveDialog(context, notifier);
                    }
                  : null,
              child: const Text("Save as New Preset",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _showSaveDialog(BuildContext context, EqualizerProvider notifier) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text("Save Preset"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Enter preset name (e.g. My Bass)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                notifier.saveCurrentAsNew(controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Preset saved!")));
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }
}
