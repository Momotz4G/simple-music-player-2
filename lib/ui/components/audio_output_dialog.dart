import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/audio_info_service.dart';
import '../../services/android_audio_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/equalizer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

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

  // Android native output info
  int? _nativeSampleRate;
  String? _deviceName;
  String? _deviceType;
  bool _bitPerfectEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    if (Platform.isAndroid) {
      _loadNativeOutputInfo();
    }
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

  Future<void> _loadNativeOutputInfo() async {
    try {
      final info = await AndroidAudioService.getNativeOutputInfo();
      if (info != null && mounted) {
        setState(() {
          _nativeSampleRate = info['nativeSampleRate'] as int?;
          _deviceName = info['deviceName'] as String?;
          _deviceType = info['deviceType'] as String?;
          _bitPerfectEnabled = info['bitPerfectEnabled'] as bool? ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error getting native output info: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Read Settings
    final settings = ref.watch(settingsProvider);
    final eq = ref.watch(equalizerProvider);
    final l10n = AppLocalizations.of(context)!;
    final isExclusive = settings.wasapiExclusive;
    final String? currentDeviceId = settings.audioDeviceId;

    // Determine info to show (Source)
    final sampleRate = widget.audioInfo?.sampleRateDisplay ?? "Unknown";
    final bitDepth = widget.audioInfo?.bitDepthDisplay ?? "16-bit";
    final format = widget.audioInfo?.format ?? "PCM";

    // Check if source is DSD format
    final isDsdSource = format.toUpperCase() == 'DSF' ||
        format.toUpperCase() == 'DFF' ||
        (widget.audioInfo?.codec.toLowerCase().contains('dsd') ?? false);

    // Check if USB DAC bypass is active (from player provider)
    final isUsbBypassActive =
        ref.read(playerProvider.notifier).isUsbAudioBypassActive;

    // Determine actual output based on platform and USB DAC state
    String outputSampleRate;
    String outputBitDepth;
    String outputFormat;
    bool isResampled = false;

    if (Platform.isAndroid) {
      if (isUsbBypassActive) {
        // USB DAC: Bit-perfect passthrough — no conversion
        outputSampleRate = sampleRate;
        outputBitDepth = isDsdSource ? "1-bit" : bitDepth;
        outputFormat = isDsdSource ? "DSD" : "PCM";
      } else if (_bitPerfectEnabled) {
        // Android Bit-Perfect mode (API 34+): signal passes through as-is
        outputSampleRate = sampleRate;
        outputBitDepth = bitDepth;
        outputFormat =
            isDsdSource ? "PCM" : "PCM"; // ExoPlayer still converts DSD→PCM
      } else {
        // Non-exclusive: Android resamples to native rate
        outputFormat = "PCM";
        if (_nativeSampleRate != null) {
          final nativeKhz = _nativeSampleRate! / 1000.0;
          outputSampleRate = "${nativeKhz.toStringAsFixed(1)} kHz";
          outputBitDepth =
              "16-bit"; // Android mixer outputs 16-bit PCM by default
          // Check if resampling is happening
          final sourceRate = widget.audioInfo?.sampleRate;
          if (sourceRate != null && sourceRate != _nativeSampleRate) {
            isResampled = true;
          }
        } else {
          outputSampleRate = sampleRate;
          outputBitDepth = bitDepth;
        }
      }
    } else {
      // Desktop: mirror source (WASAPI handles it)
      outputSampleRate = sampleRate;
      outputBitDepth = bitDepth;
      outputFormat = isDsdSource && isExclusive ? "DSD" : "PCM";
    }

    // Logic for "Output" text
    String outputStatus = l10n.systemDefault;
    if (Platform.isWindows) {
      if (currentDeviceId != null) {
        final device = _devices.firstWhere((d) => d['name'] == currentDeviceId,
            orElse: () => {});
        if (device.isNotEmpty) {
          outputStatus = device['description'] ?? l10n.unknownDevice;
        } else {
          outputStatus =
              "${l10n.customDevice} (${currentDeviceId.substring(0, 5)}...)";
        }
      } else {
        outputStatus = "${l10n.systemDefault} (${l10n.sharedMode})";
      }

      if (isExclusive) {
        outputStatus += " [${l10n.exclusiveMode}]";
      } else {
        outputStatus += " [${l10n.sharedMode}]";
      }
    } else if (Platform.isAndroid) {
      if (_deviceType != null) {
        outputStatus = _deviceType!;
        if (_deviceName != null &&
            _deviceName!.isNotEmpty &&
            _deviceName != "Unknown") {
          outputStatus += " ($_deviceName)";
        }
      } else {
        outputStatus = l10n.androidAudioTrack;
      }
    }

    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.audioOutput,
              style: const TextStyle(
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
                      title: l10n.audioSource,
                      isActive: true,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${l10n.pathLabel}: ${widget.filePath?.startsWith('http') == true ? 'Tidal Server Stream' : (widget.filePath ?? l10n.unknown)}",
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${l10n.inputLabel}: $sampleRate / $bitDepth / $format",
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
                      title: l10n.engineLabel,
                      isActive: false,
                      content: _buildStateText(
                        (_bitPerfectEnabled || isExclusive) && !eq.isEnabled
                            ? "Disabled (Bit-Perfect)"
                            : "Disabled",
                        l10n,
                      ),
                    ),
                    _buildNode(
                      icon: Icons.tune,
                      iconColor: eq.isEnabled ? Colors.green : Colors.grey,
                      title: l10n.eqLabel,
                      isActive: eq.isEnabled,
                      content: _buildStateText(eq.isEnabled ? "Enabled" : "Disabled", l10n),
                    ),
                    _buildNode(
                      icon: Icons.graphic_eq,
                      iconColor: Colors.grey,
                      title: l10n.dspLabel,
                      isActive: false,
                      content: _buildStateText("Disabled", l10n),
                    ),

                    // Android Mixer node (only show on Android)
                    if (Platform.isAndroid)
                      _buildNode(
                        icon: Icons.merge_type_rounded,
                        iconColor: (isUsbBypassActive || _bitPerfectEnabled)
                            ? Colors.green
                            : (isResampled ? Colors.amber : Colors.green),
                        title: l10n.androidMixer,
                        isActive: true,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isUsbBypassActive)
                              Row(
                                children: [
                                  const Icon(Icons.usb_rounded,
                                      color: Colors.green, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "${l10n.bypassedBitPerfect} (USB DAC)",
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else if (_bitPerfectEnabled)
                              Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.bypassedBitPerfect,
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              Row(
                                children: [
                                  Icon(
                                    isResampled
                                        ? Icons.warning_amber_rounded
                                        : Icons.info_outline,
                                    color: isResampled
                                        ? Colors.amber
                                        : Colors.grey,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      isResampled
                                          ? "${l10n.resamplingLabel}: $sampleRate → $outputSampleRate"
                                          : l10n.activeNoResampling,
                                      style: TextStyle(
                                        color: isResampled
                                            ? Colors.amber
                                            : Colors.grey[400],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_nativeSampleRate != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  "${l10n.nativeRate}: ${(_nativeSampleRate! / 1000.0).toStringAsFixed(1)} kHz",
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 10),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),

                    _buildNode(
                      icon: Icons.output,
                      iconColor: Colors.amber,
                      title: l10n.signalOutput,
                      isActive: true,
                      isLast: true,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "${l10n.outputLabel}: $outputStatus",
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
                            "${l10n.samplingRateLabel}: $outputSampleRate",
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11),
                          ),
                          Text(
                            "${l10n.bitsLabel}: $outputBitDepth",
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 11),
                          ),
                          Text(
                            "${l10n.formatLabel}: $outputFormat",
                            style: TextStyle(
                                color: outputFormat == 'DSD'
                                    ? Colors.amber
                                    : Colors.grey[500],
                                fontSize: 11,
                                fontWeight: outputFormat == 'DSD'
                                    ? FontWeight.bold
                                    : FontWeight.normal),
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

  Widget _buildStateText(String state, AppLocalizations l10n) {
    return Text(
      "${l10n.statusLabel}: $state",
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
            decoration: const BoxDecoration(
              color: Colors.black,
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
                const SizedBox(height: 14),
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
