import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/audio_info_service.dart';
import '../../providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:just_audio_media_kit/just_audio_media_kit.dart'; // Import for listAudioDevices

class AudioOutputDialog extends ConsumerStatefulWidget {
  final AudioInfo? audioInfo;
  final String? filePath;

  const AudioOutputDialog({super.key, this.audioInfo, this.filePath});

  @override
  ConsumerState<AudioOutputDialog> createState() => _AudioOutputDialogState();
}

class _AudioOutputDialogState extends ConsumerState<AudioOutputDialog> {
  List<Map<String, String>> _devices = [];
  bool _loadingDevices = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    if (Platform.isWindows) {
      try {
        final devices = await JustAudioMediaKit.listAudioDevices();
        if (mounted) {
          setState(() {
            _devices = devices;
            _loadingDevices = false;
          });
        }
      } catch (e) {
        debugPrint("Error listing devices: $e");
        if (mounted) setState(() => _loadingDevices = false);
      }
    } else {
      if (mounted) setState(() => _loadingDevices = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Read Settings
    final settings = ref.watch(settingsProvider);
    final isExclusive = settings.wasapiExclusive;
    final String? currentDeviceId = settings.audioDeviceId;

    // Determine info to show (Source)
    final sampleRate = widget.audioInfo?.sampleRateDisplay ?? "Unknown";
    final bitDepth = widget.audioInfo?.bitDepthDisplay ?? "16-bit";
    final format = widget.audioInfo?.format ?? "PCM";

    // For output, we mimic the input for now
    final outputSampleRate = sampleRate;
    final outputBitDepth = bitDepth;

    // Logic for "Output" text
    String outputStatus = "System Default";
    if (Platform.isWindows) {
      if (currentDeviceId != null) {
        // Find name in devices list if possible
        final device = _devices.firstWhere((d) => d['name'] == currentDeviceId,
            orElse: () => {});
        if (device.isNotEmpty) {
          outputStatus = device['description'] ?? "Unknown Device";
        } else {
          outputStatus =
              "Custom Device (${currentDeviceId.substring(0, 5)}...)";
        }
      } else {
        outputStatus = "System Default (Shared)";
      }

      if (isExclusive) {
        outputStatus += " [Exclusive]";
      } else {
        outputStatus += " [Shared]";
      }
    } else if (Platform.isAndroid) {
      outputStatus = "Android AudioTrack";
    }

    return Dialog(
      backgroundColor: Colors.black, // Match screenshot dark aesthetic
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400, // Slightly wider for device names
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Audio output",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // CHAIN VISUALIZATION
            Stack(
              children: [
                // Vertical Line
                Positioned(
                  left: 24,
                  top: 20,
                  bottom: 20,
                  child: Container(
                    width: 2,
                    color: Colors.grey[800],
                  ),
                ),

                Column(
                  children: [
                    _buildNode(
                      icon: Icons.music_note,
                      iconColor: Colors.amber,
                      title: "Audio Source",
                      isActive: true,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Path: ${widget.filePath ?? 'Unknown'}",
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // New: Input Stats
                          Text(
                            "Input: $sampleRate / $bitDepth / $format",
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    _buildNode(
                      icon: Icons.speaker_group_outlined,
                      iconColor: Colors.grey,
                      title: "Engine",
                      isActive: false,
                      content: _buildStateText("Disabled (Bit-Perfect)"),
                    ),
                    _buildNode(
                      icon: Icons.tune,
                      iconColor: Colors.grey,
                      title: "EQ",
                      isActive: false,
                      content: _buildStateText("Disabled"),
                    ),
                    _buildNode(
                      icon: Icons.graphic_eq,
                      iconColor: Colors.grey,
                      title: "DSP",
                      isActive: false,
                      content: _buildStateText("Disabled"),
                    ),
                    _buildNode(
                      icon: Icons.output, // Signal Output
                      iconColor: Colors.amber,
                      title: "Signal Output",
                      isActive: true,
                      isLast: true,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Read-only Output Display
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Output: $outputStatus",
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 2),
                          if (_loadingDevices)
                            const Padding(
                              padding: EdgeInsets.only(top: 4, bottom: 4),
                              child: SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            ),

                          Text(
                            "Sampling Rate: $outputSampleRate",
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11),
                          ),
                          Text(
                            "Bits: $outputBitDepth",
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11),
                          ),
                          Text(
                            "Format: PCM",
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateText(String state) {
    return Text(
      "State: $state",
      style: TextStyle(color: Colors.grey[600], fontSize: 12),
    );
  }

  Widget _buildNode({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
    required bool isActive,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black, // Mask line behind
              // border: Border.all(color: Colors.grey[900]!),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 14), // Align with icon center roughly
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const SizedBox(height: 4),
                content,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
