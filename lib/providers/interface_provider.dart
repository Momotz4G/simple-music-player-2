import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

class InterfaceState {
  final bool isMiniPlayer;
  final Rect? previousBounds;
  final Offset? lastMiniPosition;

  const InterfaceState({
    this.isMiniPlayer = false,
    this.previousBounds,
    this.lastMiniPosition,
  });

  InterfaceState copyWith({
    bool? isMiniPlayer,
    Rect? previousBounds,
    Offset? lastMiniPosition,
  }) {
    return InterfaceState(
      isMiniPlayer: isMiniPlayer ?? this.isMiniPlayer,
      previousBounds: previousBounds ?? this.previousBounds,
      lastMiniPosition: lastMiniPosition ?? this.lastMiniPosition,
    );
  }
}

class InterfaceNotifier extends StateNotifier<InterfaceState> {
  InterfaceNotifier() : super(const InterfaceState());

  Future<void> enterMiniPlayer() async {
    if (state.isMiniPlayer) return;
    // Mini player only works on desktop
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    // 1. Capture current bounds
    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();
    final bounds =
        Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

    // 2. Update State
    state = state.copyWith(isMiniPlayer: true, previousBounds: bounds);

    // 3. Resize Window
    // Update bitsdojo_window constraints too
    appWindow.minSize = const Size(300, 150);
    await windowManager.setMinimumSize(const Size(300, 150)); // Allow shrinking
    await windowManager.setSize(const Size(320, 160)); // Small banner size
    await windowManager.setResizable(false);

    // Restore Last Mini Position
    if (state.lastMiniPosition != null) {
      await windowManager.setPosition(state.lastMiniPosition!);
    }

    await windowManager.setAlwaysOnTop(true);
  }

  Future<void> exitMiniPlayer() async {
    if (!state.isMiniPlayer) return;
    // Mini player only works on desktop
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    // Capture Mini Position before resizing
    final miniPos = await windowManager.getPosition();

    final prev = state.previousBounds;

    // 1. Restore Window First (Avoid Full UI rendering in tiny window)
    await windowManager.setAlwaysOnTop(false);

    // Restore Constraints
    appWindow.minSize = const Size(800, 600);
    appWindow.minSize = const Size(800, 600);
    await windowManager.setMinimumSize(const Size(800, 600));
    await windowManager.setResizable(true);

    if (prev != null) {
      await windowManager.setSize(Size(prev.width, prev.height));
      await windowManager.setPosition(Offset(prev.left, prev.top));
    } else {
      // Fallback
      await windowManager.setSize(const Size(1280, 800));
      await windowManager.center();
    }

    // 2. Update State (Switch back to Full UI)
    // Small delay to ensure window resize has processed by OS
    await Future.delayed(const Duration(milliseconds: 100));
    state = state.copyWith(
      isMiniPlayer: false,
      lastMiniPosition: miniPos,
    );
  }

  void toggleMiniPlayer() {
    if (state.isMiniPlayer) {
      exitMiniPlayer();
    } else {
      enterMiniPlayer();
    }
  }
}

final interfaceProvider =
    StateNotifierProvider<InterfaceNotifier, InterfaceState>((ref) {
  return InterfaceNotifier();
});
