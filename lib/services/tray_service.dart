import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

// ─── Win32 FFI for taskbar control ───────────────────────────────────
// We use raw Win32 calls because both windowManager.setSkipTaskbar()
// and windowManager.hide() conflict with bitsdojo_window's native
// message loop and crash the process.

final _user32 = Platform.isWindows ? DynamicLibrary.open('user32.dll') : null;

// FindWindowW(lpClassName, lpWindowName) → HWND
typedef _FindWindowNative = IntPtr Function(Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);
typedef _FindWindowDart = int Function(Pointer<Utf16> lpClassName, Pointer<Utf16> lpWindowName);

// GetWindowLongPtrW(hWnd, nIndex) → LONG_PTR
typedef _GetWindowLongNative = IntPtr Function(IntPtr hWnd, Int32 nIndex);
typedef _GetWindowLongDart = int Function(int hWnd, int nIndex);

// SetWindowLongPtrW(hWnd, nIndex, dwNewLong) → LONG_PTR
typedef _SetWindowLongNative = IntPtr Function(IntPtr hWnd, Int32 nIndex, IntPtr dwNewLong);
typedef _SetWindowLongDart = int Function(int hWnd, int nIndex, int dwNewLong);

// SetWindowPos(hWnd, hWndInsertAfter, X, Y, cx, cy, uFlags) → BOOL
typedef _SetWindowPosNative = Int32 Function(IntPtr hWnd, IntPtr hWndInsertAfter, Int32 X, Int32 Y, Int32 cx, Int32 cy, Uint32 uFlags);
typedef _SetWindowPosDart = int Function(int hWnd, int hWndInsertAfter, int X, int Y, int cx, int cy, int uFlags);

// ShowWindow(hWnd, nCmdShow) → BOOL
typedef _ShowWindowNative = Int32 Function(IntPtr hWnd, Int32 nCmdShow);
typedef _ShowWindowDart = int Function(int hWnd, int nCmdShow);

const int _gwlExstyle = -20;
const int _wsExToolwindow = 0x00000080;
const int _wsExAppwindow = 0x00040000;
const int _swpNomove = 0x0002;
const int _swpNosize = 0x0001;
const int _swpNozorder = 0x0004;
const int _swpFramechanged = 0x0020;
const int _swHide = 0;
const int _swShow = 5;

class TrayService with TrayListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  void Function(String action)? _onAction;
  
  /// Notifier to let the UI know if we are currently hidden in the tray.
  /// When true, the UI can suspend rendering (using Offstage) to save resources.
  final ValueNotifier<bool> minimizedNotifier = ValueNotifier<bool>(false);
  
  int _cachedHwnd = 0;

  bool get isMinimizedToTray => minimizedNotifier.value;

  Future<void> init(void Function(String action) onAction) async {
    if (_onAction != null && _onAction == onAction) return;
    _onAction = onAction;
    
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return;
    }

    await trayManager.setIcon(
      Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.ico',
    );
    
    // Initial menu update (will be overridden by updateLocalizedMenu once l10n is available)
    await _updateTrayMenu();
    
    trayManager.removeListener(this);
    trayManager.addListener(this);
  }

  String? _lastLocaleName;

  /// Updates the tray menu with localized labels.
  /// This should be called from the UI when the locale changes.
  Future<void> updateLocalizedMenu(dynamic l10n) async {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
    
    final localeName = l10n.localeName as String;
    if (_lastLocaleName == localeName) return;
    _lastLocaleName = localeName;
    
    // Note: l10n is passed as dynamic to avoid direct imports if needed, 
    // but we expect AppLocalizations.
    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: l10n.nowPlayingHeader,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'play_pause',
          label: l10n.playPause,
        ),
        MenuItem(
          key: 'next',
          label: l10n.nextTrack,
        ),
        MenuItem(
          key: 'previous',
          label: l10n.previousTrack,
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'minimize_tray',
          label: l10n.minimizeToTray,
        ),
        MenuItem(
          key: 'exit_app',
          label: l10n.exitApp,
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  Future<void> _updateTrayMenu() async {
    // Fallback menu in English
    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Show Player',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'play_pause',
          label: 'Play / Pause',
        ),
        MenuItem(
          key: 'next',
          label: 'Next Track',
        ),
        MenuItem(
          key: 'previous',
          label: 'Previous Track',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'minimize_tray',
          label: 'Minimize to Tray',
        ),
        MenuItem(
          key: 'exit_app',
          label: 'Quit',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  // ─── Win32 helpers ──────────────────────────────────────────────────

  /// Find the Flutter window HWND by its title.
  int _findFlutterHwnd() {
    if (_user32 == null) return 0;
    final findWindow = _user32!.lookupFunction<_FindWindowNative, _FindWindowDart>('FindWindowW');
    final title = 'Simple Music Player'.toNativeUtf16();
    try {
      final hwnd = findWindow(nullptr, title);
      return hwnd;
    } finally {
      malloc.free(title);
    }
  }

  /// Hide the window from the taskbar by setting WS_EX_TOOLWINDOW style.
  void _hideFromTaskbar(int hwnd) {
    if (_user32 == null || hwnd == 0) return;
    final getWindowLong = _user32!.lookupFunction<_GetWindowLongNative, _GetWindowLongDart>('GetWindowLongPtrW');
    final setWindowLong = _user32!.lookupFunction<_SetWindowLongNative, _SetWindowLongDart>('SetWindowLongPtrW');
    final setWindowPos = _user32!.lookupFunction<_SetWindowPosNative, _SetWindowPosDart>('SetWindowPos');

    final style = getWindowLong(hwnd, _gwlExstyle);
    setWindowLong(hwnd, _gwlExstyle, (style | _wsExToolwindow) & ~_wsExAppwindow);
    // Apply the style change
    setWindowPos(hwnd, 0, 0, 0, 0, 0, _swpNomove | _swpNosize | _swpNozorder | _swpFramechanged);
    debugPrint("🪟 [TrayService] Win32: Hidden from taskbar (WS_EX_TOOLWINDOW set)");
  }

  /// Show the window in the taskbar by restoring WS_EX_APPWINDOW style.
  void _showInTaskbar(int hwnd) {
    if (_user32 == null || hwnd == 0) return;
    final getWindowLong = _user32!.lookupFunction<_GetWindowLongNative, _GetWindowLongDart>('GetWindowLongPtrW');
    final setWindowLong = _user32!.lookupFunction<_SetWindowLongNative, _SetWindowLongDart>('SetWindowLongPtrW');
    final setWindowPos = _user32!.lookupFunction<_SetWindowPosNative, _SetWindowPosDart>('SetWindowPos');

    final style = getWindowLong(hwnd, _gwlExstyle);
    setWindowLong(hwnd, _gwlExstyle, (style & ~_wsExToolwindow) | _wsExAppwindow);
    // Apply the style change
    setWindowPos(hwnd, 0, 0, 0, 0, 0, _swpNomove | _swpNosize | _swpNozorder | _swpFramechanged);
    debugPrint("🪟 [TrayService] Win32: Shown in taskbar (WS_EX_APPWINDOW restored)");
  }

  /// Show or Hide the window using Win32 ShowWindow API.
  bool _setWindowVisibility(int hwnd, bool visible) {
    if (_user32 == null || hwnd == 0) return false;
    final showWindow = _user32!.lookupFunction<_ShowWindowNative, _ShowWindowDart>('ShowWindow');
    return showWindow(hwnd, visible ? _swShow : _swHide) != 0;
  }

  // ─── Public API ─────────────────────────────────────────────────────

  /// Minimize the window to tray:
  /// 1. Hide from taskbar via Win32 WS_EX_TOOLWINDOW
  /// 2. Hide the window completely (SW_HIDE) to suspend rendering.
  void minimizeToTray() {
    debugPrint("🔽 [TrayService] Minimizing to tray...");
    
    if (Platform.isWindows) {
      if (_cachedHwnd == 0) {
        _cachedHwnd = _findFlutterHwnd();
      }
      
      if (_cachedHwnd != 0) {
        // First hide from taskbar
        _hideFromTaskbar(_cachedHwnd);
        // Then hide the window entirely
        _setWindowVisibility(_cachedHwnd, false);
        
        minimizedNotifier.value = true;
        debugPrint("🔽 [TrayService] Window hidden via Win32 SW_HIDE");
      } else {
        debugPrint("⚠️ [TrayService] Could not find window HWND to hide");
        // Fallback to bitsdojo minimize if HWND search fails
        appWindow.minimize();
      }
    } else {
      // Non-windows behavior
      appWindow.minimize();
    }
    
    debugPrint("🔽 [TrayService] Window fully minimized to tray");
  }

  /// Restore the window from tray:
  /// 1. Show the window (SW_SHOW)
  /// 2. Show in taskbar via Win32 WS_EX_APPWINDOW
  /// 3. Restore + show via bitsdojo to ensure focus
  void restoreWindow() {
    debugPrint("🔼 [TrayService] Restoring window from tray...");
    
    if (Platform.isWindows && _cachedHwnd != 0) {
      // First show the window
      _setWindowVisibility(_cachedHwnd, true);
      // Then show in taskbar
      _showInTaskbar(_cachedHwnd);
      
      minimizedNotifier.value = false;
    }

    appWindow.restore();
    appWindow.show();
  }

  @override
  void onTrayIconMouseDown() {
    restoreWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (_onAction != null) {
      _onAction!(menuItem.key!);
    }
  }

  void dispose() {
    trayManager.removeListener(this);
    minimizedNotifier.dispose();
  }
}
