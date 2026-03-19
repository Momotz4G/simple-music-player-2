import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_th.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('th'),
    Locale('vi'),
    Locale('zh')
  ];

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @local_library.
  ///
  /// In en, this message translates to:
  /// **'Local Library'**
  String get local_library;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @metadata_editor.
  ///
  /// In en, this message translates to:
  /// **'Metadata Editor'**
  String get metadata_editor;

  /// No description provided for @editMetadata.
  ///
  /// In en, this message translates to:
  /// **'Edit Metadata'**
  String get editMetadata;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @enableAlphabetIndexer.
  ///
  /// In en, this message translates to:
  /// **'Enable Alphabet Scroll Indexer'**
  String get enableAlphabetIndexer;

  /// No description provided for @enableAlphabetIndexerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show A-Z sidebar indexing on mobile list view'**
  String get enableAlphabetIndexerSubtitle;

  /// No description provided for @metadataUpdated.
  ///
  /// In en, this message translates to:
  /// **'Metadata Updated'**
  String get metadataUpdated;

  /// No description provided for @failedToUpdateMetadata.
  ///
  /// In en, this message translates to:
  /// **'Failed to update metadata'**
  String get failedToUpdateMetadata;

  /// No description provided for @toggleLyrics.
  ///
  /// In en, this message translates to:
  /// **'Toggle Lyrics'**
  String get toggleLyrics;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @navigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @indonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get indonesian;

  /// No description provided for @korean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get korean;

  /// No description provided for @japanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get japanese;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get german;

  /// No description provided for @portuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get portuguese;

  /// No description provided for @thai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get thai;

  /// No description provided for @vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get vietnamese;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @atmospheres.
  ///
  /// In en, this message translates to:
  /// **'Atmospheres'**
  String get atmospheres;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @winter.
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get winter;

  /// No description provided for @autumn.
  ///
  /// In en, this message translates to:
  /// **'Autumn'**
  String get autumn;

  /// No description provided for @rainyCity.
  ///
  /// In en, this message translates to:
  /// **'Rainy City'**
  String get rainyCity;

  /// No description provided for @sakura.
  ///
  /// In en, this message translates to:
  /// **'Sakura'**
  String get sakura;

  /// No description provided for @lunarNewYear.
  ///
  /// In en, this message translates to:
  /// **'Lunar New Year'**
  String get lunarNewYear;

  /// No description provided for @cyberpunk.
  ///
  /// In en, this message translates to:
  /// **'Cyberpunk'**
  String get cyberpunk;

  /// No description provided for @underwater.
  ///
  /// In en, this message translates to:
  /// **'Underwater'**
  String get underwater;

  /// No description provided for @nordicAurora.
  ///
  /// In en, this message translates to:
  /// **'Nordic Aurora'**
  String get nordicAurora;

  /// No description provided for @galacticSpace.
  ///
  /// In en, this message translates to:
  /// **'Galactic Space'**
  String get galacticSpace;

  /// No description provided for @desertMirage.
  ///
  /// In en, this message translates to:
  /// **'Desert Mirage'**
  String get desertMirage;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @lockedAtmosphere.
  ///
  /// In en, this message translates to:
  /// **'Locked while an Atmosphere is active'**
  String get lockedAtmosphere;

  /// No description provided for @useDarkTheme.
  ///
  /// In en, this message translates to:
  /// **'Use dark theme'**
  String get useDarkTheme;

  /// No description provided for @syncThemeAlbumArt.
  ///
  /// In en, this message translates to:
  /// **'Sync Theme with Album Art'**
  String get syncThemeAlbumArt;

  /// No description provided for @tintBackground.
  ///
  /// In en, this message translates to:
  /// **'Tint background and visualizer with song color'**
  String get tintBackground;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get accentColor;

  /// No description provided for @chooseAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred static color'**
  String get chooseAccentColor;

  /// No description provided for @contentRegion.
  ///
  /// In en, this message translates to:
  /// **'Content Region'**
  String get contentRegion;

  /// No description provided for @setCountryReleases.
  ///
  /// In en, this message translates to:
  /// **'Set country for new releases & charts'**
  String get setCountryReleases;

  /// No description provided for @unitedStates.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get unitedStates;

  /// No description provided for @indonesia.
  ///
  /// In en, this message translates to:
  /// **'Indonesia'**
  String get indonesia;

  /// No description provided for @southKorea.
  ///
  /// In en, this message translates to:
  /// **'South Korea'**
  String get southKorea;

  /// No description provided for @japan.
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get japan;

  /// No description provided for @unitedKingdom.
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get unitedKingdom;

  /// No description provided for @brazil.
  ///
  /// In en, this message translates to:
  /// **'Brazil'**
  String get brazil;

  /// No description provided for @visualizer.
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get visualizer;

  /// No description provided for @enableBarVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Enable Bar Visualizer'**
  String get enableBarVisualizer;

  /// No description provided for @showAnimatedWaves.
  ///
  /// In en, this message translates to:
  /// **'Show animated waves in player bar'**
  String get showAnimatedWaves;

  /// No description provided for @opacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get opacity;

  /// No description provided for @visualizerStyle.
  ///
  /// In en, this message translates to:
  /// **'Visualizer Style'**
  String get visualizerStyle;

  /// No description provided for @chooseAnimationType.
  ///
  /// In en, this message translates to:
  /// **'Choose animation type'**
  String get chooseAnimationType;

  /// No description provided for @spectrumBars.
  ///
  /// In en, this message translates to:
  /// **'Spectrum Bars'**
  String get spectrumBars;

  /// No description provided for @fluidWave.
  ///
  /// In en, this message translates to:
  /// **'Fluid Wave'**
  String get fluidWave;

  /// No description provided for @circularPulse.
  ///
  /// In en, this message translates to:
  /// **'Circular Pulse'**
  String get circularPulse;

  /// No description provided for @rainbowMode.
  ///
  /// In en, this message translates to:
  /// **'Rainbow Mode'**
  String get rainbowMode;

  /// No description provided for @useMixedColors.
  ///
  /// In en, this message translates to:
  /// **'Use mixed colors (Overrides sync)'**
  String get useMixedColors;

  /// No description provided for @integration.
  ///
  /// In en, this message translates to:
  /// **'Integration'**
  String get integration;

  /// No description provided for @discordRPC.
  ///
  /// In en, this message translates to:
  /// **'Discord Rich Presence'**
  String get discordRPC;

  /// No description provided for @showStatusDiscord.
  ///
  /// In en, this message translates to:
  /// **'Show status on Discord'**
  String get showStatusDiscord;

  /// No description provided for @tidalApiStatus.
  ///
  /// In en, this message translates to:
  /// **'Tidal API'**
  String get tidalApiStatus;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @unauthorize.
  ///
  /// In en, this message translates to:
  /// **'Unauthorize'**
  String get unauthorize;

  /// No description provided for @offlineStatus.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineStatus;

  /// No description provided for @checkInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection'**
  String get checkInternetConnection;

  /// Auto clear cache setting section
  ///
  /// In en, this message translates to:
  /// **'Auto Clear Cache'**
  String get autoClearCache;

  /// Option to disable auto clear cache
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get autoClearDisabled;

  /// Option to clear cache when app closes
  ///
  /// In en, this message translates to:
  /// **'When app closed'**
  String get autoClearOnClose;

  /// Option to clear cache every 24 hours
  ///
  /// In en, this message translates to:
  /// **'After 24 hours'**
  String get autoClearAfter24h;

  /// Option to clear cache every 7 days
  ///
  /// In en, this message translates to:
  /// **'After 7 days'**
  String get autoClearAfter7d;

  /// No description provided for @autoClearEvery30m.
  ///
  /// In en, this message translates to:
  /// **'Every 30 mins (Listening)'**
  String get autoClearEvery30m;

  /// No description provided for @musicFolderLocation.
  ///
  /// In en, this message translates to:
  /// **'Music Folder Location'**
  String get musicFolderLocation;

  /// No description provided for @noFolderSelected.
  ///
  /// In en, this message translates to:
  /// **'No folder selected'**
  String get noFolderSelected;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @expand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// No description provided for @ignoreSubfolderScan.
  ///
  /// In en, this message translates to:
  /// **'Ignore Subfolder Scan'**
  String get ignoreSubfolderScan;

  /// No description provided for @onlyScanSelected.
  ///
  /// In en, this message translates to:
  /// **'Only scan selected folder (Default: On)'**
  String get onlyScanSelected;

  /// No description provided for @importAdditionalPaths.
  ///
  /// In en, this message translates to:
  /// **'Import Additional Paths'**
  String get importAdditionalPaths;

  /// No description provided for @addFoldersScan.
  ///
  /// In en, this message translates to:
  /// **'Add more folders to scan'**
  String get addFoldersScan;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @singleTracks.
  ///
  /// In en, this message translates to:
  /// **'Single Tracks'**
  String get singleTracks;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes'**
  String get unsavedChanges;

  /// No description provided for @playlistAlbumTracks.
  ///
  /// In en, this message translates to:
  /// **'Playlist / Album Tracks'**
  String get playlistAlbumTracks;

  /// No description provided for @audioFormat.
  ///
  /// In en, this message translates to:
  /// **'Audio Format'**
  String get audioFormat;

  /// No description provided for @preferredOutputFormat.
  ///
  /// In en, this message translates to:
  /// **'Preferred output format for downloads'**
  String get preferredOutputFormat;

  /// No description provided for @flacNote.
  ///
  /// In en, this message translates to:
  /// **'Note: FLAC is available for single track downloads only. Bulk playlist downloads use M4A format.'**
  String get flacNote;

  /// No description provided for @downloadLocation.
  ///
  /// In en, this message translates to:
  /// **'Download Location'**
  String get downloadLocation;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// No description provided for @changeFolder.
  ///
  /// In en, this message translates to:
  /// **'Change Folder'**
  String get changeFolder;

  /// No description provided for @streaming.
  ///
  /// In en, this message translates to:
  /// **'Streaming'**
  String get streaming;

  /// No description provided for @streamingQuality.
  ///
  /// In en, this message translates to:
  /// **'Streaming Quality'**
  String get streamingQuality;

  /// No description provided for @standardQuality.
  ///
  /// In en, this message translates to:
  /// **'Standard (MP3)'**
  String get standardQuality;

  /// No description provided for @highQuality.
  ///
  /// In en, this message translates to:
  /// **'High (M4A)'**
  String get highQuality;

  /// No description provided for @losslessQuality.
  ///
  /// In en, this message translates to:
  /// **'Lossless (Auto)'**
  String get losslessQuality;

  /// No description provided for @standardDesc.
  ///
  /// In en, this message translates to:
  /// **'MP3 - Smaller files, faster buffering'**
  String get standardDesc;

  /// No description provided for @highDesc.
  ///
  /// In en, this message translates to:
  /// **'M4A - Better quality, balanced'**
  String get highDesc;

  /// No description provided for @losslessDesc.
  ///
  /// In en, this message translates to:
  /// **'FLAC - Lossless quality from Deezer/Tidal'**
  String get losslessDesc;

  /// No description provided for @selectStreamingQuality.
  ///
  /// In en, this message translates to:
  /// **'Select streaming quality'**
  String get selectStreamingQuality;

  /// No description provided for @losslessNote.
  ///
  /// In en, this message translates to:
  /// **'Streams lossless FLAC from Deezer/Tidal when available. Falls back to M4A if unavailable.'**
  String get losslessNote;

  /// No description provided for @playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// No description provided for @endlessQueue.
  ///
  /// In en, this message translates to:
  /// **'Endless Queue'**
  String get endlessQueue;

  /// No description provided for @autoAddSimilar.
  ///
  /// In en, this message translates to:
  /// **'Auto-add similar songs when queue is nearly empty'**
  String get autoAddSimilar;

  /// No description provided for @gaplessPlayback.
  ///
  /// In en, this message translates to:
  /// **'Gapless Playback'**
  String get gaplessPlayback;

  /// No description provided for @gaplessPlaybackDesc.
  ///
  /// In en, this message translates to:
  /// **'Eliminate silence between tracks'**
  String get gaplessPlaybackDesc;

  /// No description provided for @crossfade.
  ///
  /// In en, this message translates to:
  /// **'Crossfade'**
  String get crossfade;

  /// No description provided for @crossfadeDesc.
  ///
  /// In en, this message translates to:
  /// **'Fade between tracks ({seconds}s)'**
  String crossfadeDesc(String seconds);

  /// No description provided for @disableRomanization.
  ///
  /// In en, this message translates to:
  /// **'Disable Romanization'**
  String get disableRomanization;

  /// No description provided for @hideRomajiPinyin.
  ///
  /// In en, this message translates to:
  /// **'Hide romaji/pinyin below Korean, Japanese, and Chinese lyrics'**
  String get hideRomajiPinyin;

  /// No description provided for @translationLanguage.
  ///
  /// In en, this message translates to:
  /// **'Translation Language'**
  String get translationLanguage;

  /// No description provided for @targetLanguageLyrics.
  ///
  /// In en, this message translates to:
  /// **'Target language for lyrics translation'**
  String get targetLanguageLyrics;

  /// No description provided for @disableCanvas.
  ///
  /// In en, this message translates to:
  /// **'Disable Canvas'**
  String get disableCanvas;

  /// No description provided for @hideCanvas.
  ///
  /// In en, this message translates to:
  /// **'Hide Spotify Canvas video, show album art instead'**
  String get hideCanvas;

  /// No description provided for @wasapiExclusive.
  ///
  /// In en, this message translates to:
  /// **'WASAPI Exclusive Mode'**
  String get wasapiExclusive;

  /// No description provided for @bitPerfectWindows.
  ///
  /// In en, this message translates to:
  /// **'Bit-perfect audio with auto sample rate (Restart required)'**
  String get bitPerfectWindows;

  /// No description provided for @audiophileDAC.
  ///
  /// In en, this message translates to:
  /// **'Enable for audiophile DAC playback (Restart required)'**
  String get audiophileDAC;

  /// No description provided for @android14BitPerfect.
  ///
  /// In en, this message translates to:
  /// **'Android 14+ Bit-Perfect'**
  String get android14BitPerfect;

  /// No description provided for @bypassSystemMixer.
  ///
  /// In en, this message translates to:
  /// **'Bypass system mixer for USB DACs'**
  String get bypassSystemMixer;

  /// No description provided for @requiresAndroid14.
  ///
  /// In en, this message translates to:
  /// **'Requires Android 14+ and USB DAC'**
  String get requiresAndroid14;

  /// No description provided for @bitPerfectEnabled.
  ///
  /// In en, this message translates to:
  /// **'Bit-Perfect Mode Enabled. Volume control may be disabled.'**
  String get bitPerfectEnabled;

  /// No description provided for @audioOutputDevice.
  ///
  /// In en, this message translates to:
  /// **'Audio Output Device'**
  String get audioOutputDevice;

  /// No description provided for @loadingDevices.
  ///
  /// In en, this message translates to:
  /// **'Loading devices...'**
  String get loadingDevices;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @exclusiveWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: Exclusive Mode works best when a specific device is selected above, rather than System Default.'**
  String get exclusiveWarning;

  /// No description provided for @dataCleanup.
  ///
  /// In en, this message translates to:
  /// **'Data & Cleanup'**
  String get dataCleanup;

  /// No description provided for @resetLibraryPath.
  ///
  /// In en, this message translates to:
  /// **'Reset Library Path'**
  String get resetLibraryPath;

  /// No description provided for @unlinkFolder.
  ///
  /// In en, this message translates to:
  /// **'Unlink folder and clear song list'**
  String get unlinkFolder;

  /// No description provided for @resetLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Library?'**
  String get resetLibraryTitle;

  /// No description provided for @resetLibraryContent.
  ///
  /// In en, this message translates to:
  /// **'This will remove the current folder from the player. Your actual files will NOT be deleted.'**
  String get resetLibraryContent;

  /// No description provided for @resetPath.
  ///
  /// In en, this message translates to:
  /// **'Reset Path'**
  String get resetPath;

  /// No description provided for @clearStreamingCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Streaming Cache'**
  String get clearStreamingCache;

  /// No description provided for @freeUpSpace.
  ///
  /// In en, this message translates to:
  /// **'Free up space (Current: {size})'**
  String freeUpSpace(String size);

  /// No description provided for @resetStatistics.
  ///
  /// In en, this message translates to:
  /// **'Reset Statistics'**
  String get resetStatistics;

  /// No description provided for @clearPlayHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear play history and listening time'**
  String get clearPlayHistory;

  /// No description provided for @resetStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Stats?'**
  String get resetStatsTitle;

  /// No description provided for @resetStatsContent.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.\nAll play counts and listening time will be lost forever.'**
  String get resetStatsContent;

  /// No description provided for @resetEverything.
  ///
  /// In en, this message translates to:
  /// **'Reset Everything'**
  String get resetEverything;

  /// No description provided for @debugging.
  ///
  /// In en, this message translates to:
  /// **'Debugging'**
  String get debugging;

  /// No description provided for @showDebugButton.
  ///
  /// In en, this message translates to:
  /// **'Show Floating Debug Button'**
  String get showDebugButton;

  /// No description provided for @toggleDebugButton.
  ///
  /// In en, this message translates to:
  /// **'Toggle visibility of the floating debug console'**
  String get toggleDebugButton;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @donate.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donate;

  /// No description provided for @joinUs.
  ///
  /// In en, this message translates to:
  /// **'Join Us'**
  String get joinUs;

  /// No description provided for @usbAudioBypass.
  ///
  /// In en, this message translates to:
  /// **'USB Audio Bypass (Beta) - Direct DAC output for Android 13 and below'**
  String get usbAudioBypass;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @underDevelopment.
  ///
  /// In en, this message translates to:
  /// **'This feature is under development'**
  String get underDevelopment;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @restartRequired.
  ///
  /// In en, this message translates to:
  /// **'Restart Required'**
  String get restartRequired;

  /// No description provided for @restartContent.
  ///
  /// In en, this message translates to:
  /// **'Changing the audio output device requires a restart application to take effect.\\n\\nWould you like to restart now?'**
  String get restartContent;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @restartNow.
  ///
  /// In en, this message translates to:
  /// **'Restart Now'**
  String get restartNow;

  /// No description provided for @applyOnRestart.
  ///
  /// In en, this message translates to:
  /// **'Changes will apply on next restart.'**
  String get applyOnRestart;

  /// No description provided for @autoRestartNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Auto-restart not supported. Please restart manually.'**
  String get autoRestartNotSupported;

  /// No description provided for @enterAdminCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Admin Access Code'**
  String get enterAdminCode;

  /// No description provided for @accessCode.
  ///
  /// In en, this message translates to:
  /// **'Access Code'**
  String get accessCode;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @access.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get access;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid Access Code'**
  String get invalidCode;

  /// No description provided for @formatSaved.
  ///
  /// In en, this message translates to:
  /// **'Format saved!'**
  String get formatSaved;

  /// No description provided for @addedFolder.
  ///
  /// In en, this message translates to:
  /// **'Added folder: {folder}'**
  String addedFolder(Object folder);

  /// No description provided for @removedFolder.
  ///
  /// In en, this message translates to:
  /// **'Removed folder: {folder}'**
  String removedFolder(Object folder);

  /// No description provided for @downloadPathUpdated.
  ///
  /// In en, this message translates to:
  /// **'Download path updated: {path}'**
  String downloadPathUpdated(Object path);

  /// No description provided for @downloadPathReset.
  ///
  /// In en, this message translates to:
  /// **'Download path reset to default.'**
  String get downloadPathReset;

  /// No description provided for @libraryPathReset.
  ///
  /// In en, this message translates to:
  /// **'Library path reset.'**
  String get libraryPathReset;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully!'**
  String get cacheCleared;

  /// No description provided for @changesApplyRestart.
  ///
  /// In en, this message translates to:
  /// **'Changes will apply on next restart.'**
  String get changesApplyRestart;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change application language'**
  String get changeLanguage;

  /// No description provided for @unlinkFolderClear.
  ///
  /// In en, this message translates to:
  /// **'Unlink folder and clear song list'**
  String get unlinkFolderClear;

  /// No description provided for @enterAdminAccessCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Admin Access Code'**
  String get enterAdminAccessCode;

  /// No description provided for @invalidAccessCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid Access Code'**
  String get invalidAccessCode;

  /// No description provided for @androidBitPerfect.
  ///
  /// In en, this message translates to:
  /// **'Android 14+ Bit-Perfect'**
  String get androidBitPerfect;

  /// No description provided for @customDevice.
  ///
  /// In en, this message translates to:
  /// **'Custom Device'**
  String get customDevice;

  /// No description provided for @exclusiveModeWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: Exclusive Mode works best when a specific device is selected above, rather than System Default.'**
  String get exclusiveModeWarning;

  /// No description provided for @statisticsReset.
  ///
  /// In en, this message translates to:
  /// **'Statistics have been reset.'**
  String get statisticsReset;

  /// No description provided for @toggleDebugConsole.
  ///
  /// In en, this message translates to:
  /// **'Toggle visibility of the floating debug console'**
  String get toggleDebugConsole;

  /// No description provided for @usbAudioBypassBeta.
  ///
  /// In en, this message translates to:
  /// **'USB Audio Bypass (Beta) - Direct DAC output for Android 13 and below'**
  String get usbAudioBypassBeta;

  /// No description provided for @connectedUsbDacs.
  ///
  /// In en, this message translates to:
  /// **'Connected USB DACs:'**
  String get connectedUsbDacs;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning...'**
  String get scanning;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @noUsbDacDetected.
  ///
  /// In en, this message translates to:
  /// **'No USB DAC detected. Connect a USB audio device and tap Scan.'**
  String get noUsbDacDetected;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @failedToConnectDac.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to DAC. Check USB permissions.'**
  String get failedToConnectDac;

  /// No description provided for @connectedToDac.
  ///
  /// In en, this message translates to:
  /// **'Connected to {deviceName} - USB Bypass Active'**
  String connectedToDac(String deviceName);

  /// No description provided for @changingAudioDeviceRestart.
  ///
  /// In en, this message translates to:
  /// **'Changing the audio output device requires a restart application to take effect.\n\nWould you like to restart now?'**
  String get changingAudioDeviceRestart;

  /// No description provided for @translateLyrics.
  ///
  /// In en, this message translates to:
  /// **'Translate Lyrics'**
  String get translateLyrics;

  /// No description provided for @viewQueue.
  ///
  /// In en, this message translates to:
  /// **'View Queue'**
  String get viewQueue;

  /// No description provided for @loadingLyrics.
  ///
  /// In en, this message translates to:
  /// **'Loading lyrics...'**
  String get loadingLyrics;

  /// No description provided for @noLyricsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No lyrics available'**
  String get noLyricsAvailable;

  /// No description provided for @noSyncedLyricsFound.
  ///
  /// In en, this message translates to:
  /// **'No Synced Lyrics Found'**
  String get noSyncedLyricsFound;

  /// No description provided for @justEnjoyVibes.
  ///
  /// In en, this message translates to:
  /// **'Just enjoy the vibes.'**
  String get justEnjoyVibes;

  /// No description provided for @scrollForLyrics.
  ///
  /// In en, this message translates to:
  /// **'Scroll for lyrics'**
  String get scrollForLyrics;

  /// No description provided for @switchingTo.
  ///
  /// In en, this message translates to:
  /// **'Switching to: {title}'**
  String switchingTo(String title);

  /// No description provided for @metadataEditorInfo.
  ///
  /// In en, this message translates to:
  /// **'Fix your metadata editor in a second and just search it.'**
  String get metadataEditorInfo;

  /// No description provided for @metadataEditorNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Album art is changing after state \"Saved Successfully\", you don\'t need to worries its not saved, it\'s just caching problem in app and I currently fix it. You can verify with file manager or else.'**
  String get metadataEditorNote;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permissionRequired;

  /// No description provided for @permissionRequiredDesc.
  ///
  /// In en, this message translates to:
  /// **'To edit tags, we need \'All Files Access\' permission. This allows us to modify your music files directly.'**
  String get permissionRequiredDesc;

  /// No description provided for @grantPermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get grantPermission;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @editor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editor;

  /// No description provided for @clearImported.
  ///
  /// In en, this message translates to:
  /// **'Clear Imported'**
  String get clearImported;

  /// No description provided for @libraryData.
  ///
  /// In en, this message translates to:
  /// **'Library Data'**
  String get libraryData;

  /// No description provided for @externalFiles.
  ///
  /// In en, this message translates to:
  /// **'External Files'**
  String get externalFiles;

  /// No description provided for @addFiles.
  ///
  /// In en, this message translates to:
  /// **'Add Files'**
  String get addFiles;

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add Folder'**
  String get addFolder;

  /// No description provided for @selectSongToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select a song from the list to edit'**
  String get selectSongToEdit;

  /// No description provided for @fixAll.
  ///
  /// In en, this message translates to:
  /// **'Fix All'**
  String get fixAll;

  /// No description provided for @autoTagTitle.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Auto-Tag {sourceName}?'**
  String autoTagTitle(String sourceName);

  /// No description provided for @autoTagContent.
  ///
  /// In en, this message translates to:
  /// **'This will search Spotify for all {count} songs in \'{sourceName}\' and overwrite their tags automatically.\n\nThis process cannot be undone.'**
  String autoTagContent(int count, String sourceName);

  /// No description provided for @startBulkProcess.
  ///
  /// In en, this message translates to:
  /// **'Start Bulk Process'**
  String get startBulkProcess;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @trackNumber.
  ///
  /// In en, this message translates to:
  /// **'Track #'**
  String get trackNumber;

  /// No description provided for @discNumber.
  ///
  /// In en, this message translates to:
  /// **'Disc #'**
  String get discNumber;

  /// No description provided for @autoFixComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Auto-Fix (Coming Soon)'**
  String get autoFixComingSoon;

  /// No description provided for @manualSearch.
  ///
  /// In en, this message translates to:
  /// **'Manual Search'**
  String get manualSearch;

  /// No description provided for @revert.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get revert;

  /// No description provided for @saveChangesToFile.
  ///
  /// In en, this message translates to:
  /// **'Save Changes to File'**
  String get saveChangesToFile;

  /// No description provided for @searchSpotify.
  ///
  /// In en, this message translates to:
  /// **'Search Spotify'**
  String get searchSpotify;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @selectMatch.
  ///
  /// In en, this message translates to:
  /// **'Select Match'**
  String get selectMatch;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'UP NEXT'**
  String get upNext;

  /// No description provided for @fetchingLossless.
  ///
  /// In en, this message translates to:
  /// **'FETCHING LOSSLESS...'**
  String get fetchingLossless;

  /// No description provided for @noMusicPlaying.
  ///
  /// In en, this message translates to:
  /// **'No music playing'**
  String get noMusicPlaying;

  /// No description provided for @refreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh List'**
  String get refreshList;

  /// No description provided for @noDownloadsFound.
  ///
  /// In en, this message translates to:
  /// **'No downloads found'**
  String get noDownloadsFound;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'play'**
  String get play;

  /// No description provided for @showInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in Folder'**
  String get showInFolder;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete File?'**
  String get deleteFileTitle;

  /// No description provided for @deleteFileContent.
  ///
  /// In en, this message translates to:
  /// **'Delete \'{filename}\'?\nThis cannot be undone.'**
  String deleteFileContent(String filename);

  /// No description provided for @downloadedTo.
  ///
  /// In en, this message translates to:
  /// **'Downloaded to: {path}'**
  String downloadedTo(String path);

  /// No description provided for @folderPath.
  ///
  /// In en, this message translates to:
  /// **'Folder: {path}'**
  String folderPath(String path);

  /// No description provided for @errorDeleting.
  ///
  /// In en, this message translates to:
  /// **'Error deleting: {error}'**
  String errorDeleting(String error);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @searchSongs.
  ///
  /// In en, this message translates to:
  /// **'Search songs...'**
  String get searchSongs;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @refreshLibrary.
  ///
  /// In en, this message translates to:
  /// **'Refresh Library'**
  String get refreshLibrary;

  /// No description provided for @shuffleAll.
  ///
  /// In en, this message translates to:
  /// **'Shuffle All'**
  String get shuffleAll;

  /// No description provided for @switchToListView.
  ///
  /// In en, this message translates to:
  /// **'Switch to List View'**
  String get switchToListView;

  /// No description provided for @switchToGridView.
  ///
  /// In en, this message translates to:
  /// **'Switch to Grid View'**
  String get switchToGridView;

  /// No description provided for @songsLoadedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs loaded...'**
  String songsLoadedCount(int count);

  /// No description provided for @grantAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant Access'**
  String get grantAccess;

  /// No description provided for @selectDifferentFolder.
  ///
  /// In en, this message translates to:
  /// **'Select Different Folder'**
  String get selectDifferentFolder;

  /// No description provided for @selectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select Folder'**
  String get selectFolder;

  /// No description provided for @noSongsInFolder.
  ///
  /// In en, this message translates to:
  /// **'No songs found in this folder.'**
  String get noSongsInFolder;

  /// No description provided for @queueUpdated.
  ///
  /// In en, this message translates to:
  /// **'QUEUE UPDATED'**
  String get queueUpdated;

  /// No description provided for @playingNext.
  ///
  /// In en, this message translates to:
  /// **'Playing Next'**
  String get playingNext;

  /// No description provided for @addedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to Queue'**
  String get addedToQueue;

  /// No description provided for @playingTrack.
  ///
  /// In en, this message translates to:
  /// **'PLAYING TRACK'**
  String get playingTrack;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'ERROR'**
  String get error;

  /// No description provided for @noPlaylistsFound.
  ///
  /// In en, this message translates to:
  /// **'No Playlists Found'**
  String get noPlaylistsFound;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get addToPlaylist;

  /// No description provided for @songAlreadyInPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Song Already in Playlist'**
  String get songAlreadyInPlaylist;

  /// No description provided for @addedToPlaylistSuccess.
  ///
  /// In en, this message translates to:
  /// **'ADDED TO PLAYLIST'**
  String get addedToPlaylistSuccess;

  /// No description provided for @alreadyInLikedSongs.
  ///
  /// In en, this message translates to:
  /// **'ALREADY IN LIKED SONGS'**
  String get alreadyInLikedSongs;

  /// No description provided for @addedToLikedSongs.
  ///
  /// In en, this message translates to:
  /// **'Added to Liked Songs'**
  String get addedToLikedSongs;

  /// No description provided for @likedSongs.
  ///
  /// In en, this message translates to:
  /// **'LIKED SONGS'**
  String get likedSongs;

  /// No description provided for @preparingDownload.
  ///
  /// In en, this message translates to:
  /// **'PREPARING DOWNLOAD'**
  String get preparingDownload;

  /// No description provided for @fetchingMetadataSpotify.
  ///
  /// In en, this message translates to:
  /// **'Fetching metadata from Spotify...'**
  String get fetchingMetadataSpotify;

  /// No description provided for @preparingDownloadNotification.
  ///
  /// In en, this message translates to:
  /// **'Preparing Download'**
  String get preparingDownloadNotification;

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD STARTED'**
  String get downloadStarted;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOADING'**
  String get downloading;

  /// No description provided for @preparingDownloadFormat.
  ///
  /// In en, this message translates to:
  /// **'Preparing download ({format})...'**
  String preparingDownloadFormat(String format);

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searching;

  /// No description provided for @findingBestMatchYoutube.
  ///
  /// In en, this message translates to:
  /// **'Finding best match on YouTube...'**
  String get findingBestMatchYoutube;

  /// No description provided for @downloadingFlac.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOADING FLAC'**
  String get downloadingFlac;

  /// No description provided for @fetchingLosslessAudio.
  ///
  /// In en, this message translates to:
  /// **'Fetching lossless audio...'**
  String get fetchingLosslessAudio;

  /// No description provided for @downloadComplete.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD COMPLETE'**
  String get downloadComplete;

  /// No description provided for @flacSavedToDownloads.
  ///
  /// In en, this message translates to:
  /// **'FLAC saved to Downloads'**
  String get flacSavedToDownloads;

  /// No description provided for @downloadCompleteNotification.
  ///
  /// In en, this message translates to:
  /// **'Download Complete'**
  String get downloadCompleteNotification;

  /// No description provided for @flacUnavailable.
  ///
  /// In en, this message translates to:
  /// **'FLAC UNAVAILABLE'**
  String get flacUnavailable;

  /// No description provided for @flacUnavailableDesc.
  ///
  /// In en, this message translates to:
  /// **'FLAC not available, download failed. Try changing settings.'**
  String get flacUnavailableDesc;

  /// No description provided for @flacUnavailableNotification.
  ///
  /// In en, this message translates to:
  /// **'FLAC Unavailable'**
  String get flacUnavailableNotification;

  /// No description provided for @changeFormatInSettings.
  ///
  /// In en, this message translates to:
  /// **'Please change output format in Settings'**
  String get changeFormatInSettings;

  /// No description provided for @flacError.
  ///
  /// In en, this message translates to:
  /// **'FLAC ERROR'**
  String get flacError;

  /// No description provided for @couldNotDownloadFlac.
  ///
  /// In en, this message translates to:
  /// **'Could not download FLAC.'**
  String get couldNotDownloadFlac;

  /// No description provided for @downloadingFormat.
  ///
  /// In en, this message translates to:
  /// **'Downloading {format}'**
  String downloadingFormat(String format);

  /// No description provided for @savedAsFormat.
  ///
  /// In en, this message translates to:
  /// **'Saved as {format}'**
  String savedAsFormat(String format);

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'DOWNLOAD FAILED'**
  String get downloadFailed;

  /// No description provided for @downloadError.
  ///
  /// In en, this message translates to:
  /// **'Download error'**
  String get downloadError;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get playNext;

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to Queue'**
  String get addToQueue;

  /// No description provided for @addToFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorite'**
  String get addToFavorite;

  /// No description provided for @goToArtist.
  ///
  /// In en, this message translates to:
  /// **'Go to Artist'**
  String get goToArtist;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @noAlbumsFound.
  ///
  /// In en, this message translates to:
  /// **'No albums found'**
  String get noAlbumsFound;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More Options'**
  String get moreOptions;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @artistLabel.
  ///
  /// In en, this message translates to:
  /// **'ARTIST'**
  String get artistLabel;

  /// No description provided for @albumLabel.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get albumLabel;

  /// No description provided for @downloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download All'**
  String get downloadAll;

  /// No description provided for @albumRemovedFromPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Album removed from playlists'**
  String get albumRemovedFromPlaylists;

  /// No description provided for @albumAddedToPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Album added to playlists'**
  String get albumAddedToPlaylists;

  /// No description provided for @startedDownloadingAll.
  ///
  /// In en, this message translates to:
  /// **'Started downloading all songs...'**
  String get startedDownloadingAll;

  /// No description provided for @playingFromAlbum.
  ///
  /// In en, this message translates to:
  /// **'PLAYING FROM ALBUM'**
  String get playingFromAlbum;

  /// No description provided for @unknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown Artist'**
  String get unknownArtist;

  /// No description provided for @songsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String songsCount(int count);

  /// No description provided for @libraryNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Library not loaded.'**
  String get libraryNotLoaded;

  /// No description provided for @noArtistsFound.
  ///
  /// In en, this message translates to:
  /// **'No artists found.'**
  String get noArtistsFound;

  /// No description provided for @goToLocalLibraryToSelect.
  ///
  /// In en, this message translates to:
  /// **'Go to \'Local Library\' to select your music folder.'**
  String get goToLocalLibraryToSelect;

  /// No description provided for @popularOnSpotify.
  ///
  /// In en, this message translates to:
  /// **'Popular on Spotify'**
  String get popularOnSpotify;

  /// No description provided for @songsInLibrary.
  ///
  /// In en, this message translates to:
  /// **'{count} songs in library'**
  String songsInLibrary(int count);

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @shufflingArtist.
  ///
  /// In en, this message translates to:
  /// **'Shuffling {artistName}...'**
  String shufflingArtist(String artistName);

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show More'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get showLess;

  /// No description provided for @discography.
  ///
  /// In en, this message translates to:
  /// **'Discography'**
  String get discography;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New Playlist'**
  String get newPlaylist;

  /// No description provided for @noPlaylistsYet.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get noPlaylistsYet;

  /// No description provided for @createPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get createPlaylist;

  /// No description provided for @emptyPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Empty Playlist'**
  String get emptyPlaylist;

  /// No description provided for @emptyPlaylistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new empty playlist'**
  String get emptyPlaylistSubtitle;

  /// No description provided for @importFromSpotify.
  ///
  /// In en, this message translates to:
  /// **'Import from Spotify'**
  String get importFromSpotify;

  /// No description provided for @importFromSpotifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a Spotify playlist URL'**
  String get importFromSpotifySubtitle;

  /// No description provided for @importFromYoutubeMusic.
  ///
  /// In en, this message translates to:
  /// **'Import from YouTube Music'**
  String get importFromYoutubeMusic;

  /// No description provided for @importFromYoutubeMusicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a YouTube Music playlist URL'**
  String get importFromYoutubeMusicSubtitle;

  /// No description provided for @playlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get playlistNameHint;

  /// No description provided for @importSpotifyPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Import Spotify Playlist'**
  String get importSpotifyPlaylist;

  /// No description provided for @importYoutubeMusicPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Import YouTube Music Playlist'**
  String get importYoutubeMusicPlaylist;

  /// No description provided for @deletePlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist?'**
  String get deletePlaylistTitle;

  /// No description provided for @deletePlaylistConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \'{name}\'?'**
  String deletePlaylistConfirm(String name);

  /// No description provided for @playlistNotFound.
  ///
  /// In en, this message translates to:
  /// **'Playlist not found'**
  String get playlistNotFound;

  /// No description provided for @noSongsAdded.
  ///
  /// In en, this message translates to:
  /// **'No songs added yet'**
  String get noSongsAdded;

  /// No description provided for @deleteDownloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Downloads?'**
  String get deleteDownloadsTitle;

  /// No description provided for @deleteDownloadsConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will remove all downloaded songs for this playlist from your device.'**
  String get deleteDownloadsConfirm;

  /// No description provided for @allDownloadsRemoved.
  ///
  /// In en, this message translates to:
  /// **'All downloads removed'**
  String get allDownloadsRemoved;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @removeFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove from Playlist'**
  String get removeFromPlaylist;

  /// No description provided for @renamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Rename Playlist'**
  String get renamePlaylist;

  /// No description provided for @deletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist'**
  String get deletePlaylist;

  /// No description provided for @deletePlaylistPermanentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure want to delete this playlist? (This action cannot be undone)'**
  String get deletePlaylistPermanentConfirm;

  /// No description provided for @publicSharing.
  ///
  /// In en, this message translates to:
  /// **'Public Sharing'**
  String get publicSharing;

  /// No description provided for @publicSharingDesc.
  ///
  /// In en, this message translates to:
  /// **'Anyone with the code can import this playlist.'**
  String get publicSharingDesc;

  /// No description provided for @publicSharingDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Disabled. Enable to share with others.'**
  String get publicSharingDisabledDesc;

  /// No description provided for @failedEnableSharing.
  ///
  /// In en, this message translates to:
  /// **'Failed to enable sharing. Check connection.'**
  String get failedEnableSharing;

  /// No description provided for @failedDisableSharing.
  ///
  /// In en, this message translates to:
  /// **'Failed to disable sharing.'**
  String get failedDisableSharing;

  /// No description provided for @disablingSharingWarning.
  ///
  /// In en, this message translates to:
  /// **'Disabling sharing will permanently delete the code and the data from the server to save space.'**
  String get disablingSharingWarning;

  /// No description provided for @invalidSpotifyUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid Spotify playlist URL'**
  String get invalidSpotifyUrl;

  /// No description provided for @invalidYoutubeMusicUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid YouTube Music playlist URL'**
  String get invalidYoutubeMusicUrl;

  /// No description provided for @fetchingPlaylistInfo.
  ///
  /// In en, this message translates to:
  /// **'Fetching playlist info...'**
  String get fetchingPlaylistInfo;

  /// No description provided for @failedFetchPlaylistInfo.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch playlist info'**
  String get failedFetchPlaylistInfo;

  /// No description provided for @fetchingTracksFrom.
  ///
  /// In en, this message translates to:
  /// **'Fetching tracks from \"{name}\"...'**
  String fetchingTracksFrom(String name);

  /// No description provided for @noTracksFound.
  ///
  /// In en, this message translates to:
  /// **'No tracks found in playlist'**
  String get noTracksFound;

  /// No description provided for @creatingPlaylistWithTracks.
  ///
  /// In en, this message translates to:
  /// **'Creating playlist with {count} tracks...'**
  String creatingPlaylistWithTracks(int count);

  /// No description provided for @importedTracks.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} tracks!'**
  String importedTracks(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @fetchingSharedPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Fetching shared playlist...'**
  String get fetchingSharedPlaylist;

  /// No description provided for @playlistNotFoundOrError.
  ///
  /// In en, this message translates to:
  /// **'Playlist not found or server error'**
  String get playlistNotFoundOrError;

  /// No description provided for @parsingPlaylistData.
  ///
  /// In en, this message translates to:
  /// **'Parsing playlist data...'**
  String get parsingPlaylistData;

  /// No description provided for @importedPlaylistName.
  ///
  /// In en, this message translates to:
  /// **'Imported \"{name}\"!'**
  String importedPlaylistName(String name);

  /// No description provided for @codeMust6Digits.
  ///
  /// In en, this message translates to:
  /// **'Code must be 6 digits'**
  String get codeMust6Digits;

  /// No description provided for @fetchingPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Fetching playlist...'**
  String get fetchingPlaylist;

  /// No description provided for @importViaCode.
  ///
  /// In en, this message translates to:
  /// **'Import via Code'**
  String get importViaCode;

  /// No description provided for @enterShareCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit share code'**
  String get enterShareCode;

  /// No description provided for @importChoice.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importChoice;

  /// No description provided for @listeningStats.
  ///
  /// In en, this message translates to:
  /// **'Listening Stats'**
  String get listeningStats;

  /// No description provided for @topArtist.
  ///
  /// In en, this message translates to:
  /// **'Top Artist'**
  String get topArtist;

  /// No description provided for @mostListened.
  ///
  /// In en, this message translates to:
  /// **'Most Listened'**
  String get mostListened;

  /// No description provided for @timeListened.
  ///
  /// In en, this message translates to:
  /// **'Time Listened'**
  String get timeListened;

  /// No description provided for @totalPlays.
  ///
  /// In en, this message translates to:
  /// **'Total Plays'**
  String get totalPlays;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracks;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @noStatsYet.
  ///
  /// In en, this message translates to:
  /// **'No stats yet.'**
  String get noStatsYet;

  /// No description provided for @noArtistStatsYet.
  ///
  /// In en, this message translates to:
  /// **'No artist stats yet.'**
  String get noArtistStatsYet;

  /// No description provided for @plays.
  ///
  /// In en, this message translates to:
  /// **'plays'**
  String get plays;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to \"{path}\"'**
  String savedTo(String path);

  /// No description provided for @myTopTrackOn.
  ///
  /// In en, this message translates to:
  /// **'My {header} on Simple Player! 🎵'**
  String myTopTrackOn(String header);

  /// No description provided for @fileMissingHistory.
  ///
  /// In en, this message translates to:
  /// **'File missing and not found in history.'**
  String get fileMissingHistory;

  /// No description provided for @restoring.
  ///
  /// In en, this message translates to:
  /// **'RESTORING'**
  String get restoring;

  /// No description provided for @reBuffering.
  ///
  /// In en, this message translates to:
  /// **'Re-buffering...'**
  String get reBuffering;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'NOW PLAYING'**
  String get nowPlaying;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get recentlyPlayed;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistoryYet;

  /// No description provided for @cloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloud;

  /// No description provided for @cached.
  ///
  /// In en, this message translates to:
  /// **'Cached'**
  String get cached;

  /// No description provided for @searchingStatus.
  ///
  /// In en, this message translates to:
  /// **'SEARCHING'**
  String get searchingStatus;

  /// No description provided for @findingStream.
  ///
  /// In en, this message translates to:
  /// **'Finding stream source...'**
  String get findingStream;

  /// No description provided for @noStreamMatch.
  ///
  /// In en, this message translates to:
  /// **'Could not find a matching stream.'**
  String get noStreamMatch;

  /// No description provided for @errorSearchingStream.
  ///
  /// In en, this message translates to:
  /// **'Error searching for stream.'**
  String get errorSearchingStream;

  /// No description provided for @rebufferingFromCloud.
  ///
  /// In en, this message translates to:
  /// **'Re-buffering from cloud...'**
  String get rebufferingFromCloud;

  /// No description provided for @musicSearch.
  ///
  /// In en, this message translates to:
  /// **'Music Search'**
  String get musicSearch;

  /// No description provided for @songTitleKeyword.
  ///
  /// In en, this message translates to:
  /// **'Song Title or Keyword'**
  String get songTitleKeyword;

  /// No description provided for @searchSpotifyHint.
  ///
  /// In en, this message translates to:
  /// **'Search Spotify...'**
  String get searchSpotifyHint;

  /// No description provided for @readySearchSong.
  ///
  /// In en, this message translates to:
  /// **'Ready. Search for a song.'**
  String get readySearchSong;

  /// No description provided for @searchingSpotifyFor.
  ///
  /// In en, this message translates to:
  /// **'Searching Spotify for \"{keyword}\"...'**
  String searchingSpotifyFor(String keyword);

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @foundResults.
  ///
  /// In en, this message translates to:
  /// **'Found {songCount} songs, {albumCount} albums, {artistCount} artists.'**
  String foundResults(int songCount, int albumCount, int artistCount);

  /// No description provided for @noSpotifyResults.
  ///
  /// In en, this message translates to:
  /// **'No Spotify results found.'**
  String get noSpotifyResults;

  /// No description provided for @searchFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Search failed: {error}'**
  String searchFailedStatus(String error);

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get noInternetConnection;

  /// No description provided for @checkNetworkTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please check your network and try again'**
  String get checkNetworkTryAgain;

  /// No description provided for @noSuggestionsFound.
  ///
  /// In en, this message translates to:
  /// **'No suggestions found.'**
  String get noSuggestionsFound;

  /// No description provided for @statusWithText.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusWithText(String status);

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get goodEvening;

  /// No description provided for @jumpBackIn.
  ///
  /// In en, this message translates to:
  /// **'Jump Back In'**
  String get jumpBackIn;

  /// No description provided for @yourTopMix.
  ///
  /// In en, this message translates to:
  /// **'Your Top Mix'**
  String get yourTopMix;

  /// No description provided for @youMayLike.
  ///
  /// In en, this message translates to:
  /// **'You May Like'**
  String get youMayLike;

  /// No description provided for @yourPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Your Playlists'**
  String get yourPlaylists;

  /// No description provided for @quickMix.
  ///
  /// In en, this message translates to:
  /// **'Quick Mix'**
  String get quickMix;

  /// No description provided for @madeForYou.
  ///
  /// In en, this message translates to:
  /// **'Made For You'**
  String get madeForYou;

  /// No description provided for @rediscover.
  ///
  /// In en, this message translates to:
  /// **'Rediscover'**
  String get rediscover;

  /// No description provided for @doYouRemember.
  ///
  /// In en, this message translates to:
  /// **'Do you remember?'**
  String get doYouRemember;

  /// No description provided for @countSongs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Song} other{{count} Songs}}'**
  String countSongs(int count);

  /// No description provided for @savePlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Save {title}?'**
  String savePlaylistTitle(String title);

  /// No description provided for @savePlaylistContent.
  ///
  /// In en, this message translates to:
  /// **'This will create a new playlist with these songs.'**
  String get savePlaylistContent;

  /// No description provided for @savedAs.
  ///
  /// In en, this message translates to:
  /// **'Saved as \"{name}\"!'**
  String savedAs(String name);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @searchSongsOrAlbumsAndArtistsHint.
  ///
  /// In en, this message translates to:
  /// **'Search Songs, Albums or Artists...'**
  String get searchSongsOrAlbumsAndArtistsHint;

  /// No description provided for @playQueue.
  ///
  /// In en, this message translates to:
  /// **'Play Queue'**
  String get playQueue;

  /// No description provided for @downloadSong.
  ///
  /// In en, this message translates to:
  /// **'Download Song'**
  String get downloadSong;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get sleepTimer;

  /// No description provided for @minutesDuration.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Minute} other{{count} Minutes}}'**
  String minutesDuration(int count);

  /// No description provided for @hoursDuration.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Hour} other{{count} Hours}}'**
  String hoursDuration(int count);

  /// No description provided for @customTime.
  ///
  /// In en, this message translates to:
  /// **'Custom Time'**
  String get customTime;

  /// No description provided for @turnOffTimer.
  ///
  /// In en, this message translates to:
  /// **'Turn Off Timer'**
  String get turnOffTimer;

  /// No description provided for @musicWillStopIn.
  ///
  /// In en, this message translates to:
  /// **'Music will stop in {label}'**
  String musicWillStopIn(String label);

  /// No description provided for @stopTimer.
  ///
  /// In en, this message translates to:
  /// **'Stop Timer ({time})'**
  String stopTimer(String time);

  /// No description provided for @setCustomTimer.
  ///
  /// In en, this message translates to:
  /// **'Set Custom Timer'**
  String get setCustomTimer;

  /// No description provided for @enterDuration.
  ///
  /// In en, this message translates to:
  /// **'Enter duration...'**
  String get enterDuration;

  /// No description provided for @hourShort.
  ///
  /// In en, this message translates to:
  /// **'Hr'**
  String get hourShort;

  /// No description provided for @minuteShort.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get minuteShort;

  /// No description provided for @secondShort.
  ///
  /// In en, this message translates to:
  /// **'Sec'**
  String get secondShort;

  /// No description provided for @timerSetForHours.
  ///
  /// In en, this message translates to:
  /// **'Timer set for {count} hours'**
  String timerSetForHours(int count);

  /// No description provided for @timerSetForMinutes.
  ///
  /// In en, this message translates to:
  /// **'Timer set for {count} minutes'**
  String timerSetForMinutes(int count);

  /// No description provided for @timerSetForSeconds.
  ///
  /// In en, this message translates to:
  /// **'Timer set for {count} seconds'**
  String timerSetForSeconds(int count);

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @errorCouldNotCreateSession.
  ///
  /// In en, this message translates to:
  /// **'Error: Could not create session.'**
  String get errorCouldNotCreateSession;

  /// No description provided for @scanToControlPlayback.
  ///
  /// In en, this message translates to:
  /// **'Scan with your phone to control playback.'**
  String get scanToControlPlayback;

  /// No description provided for @session.
  ///
  /// In en, this message translates to:
  /// **'Session: {id}'**
  String session(String id);

  /// No description provided for @loadingCanvas.
  ///
  /// In en, this message translates to:
  /// **'Loading canvas...'**
  String get loadingCanvas;

  /// No description provided for @searchingSpotify.
  ///
  /// In en, this message translates to:
  /// **'Searching Spotify...'**
  String get searchingSpotify;

  /// No description provided for @fetchingCanvas.
  ///
  /// In en, this message translates to:
  /// **'Fetching Canvas...'**
  String get fetchingCanvas;

  /// No description provided for @nowPlayingHeader.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlayingHeader;

  /// No description provided for @nowPlayingSection.
  ///
  /// In en, this message translates to:
  /// **'NOW PLAYING'**
  String get nowPlayingSection;

  /// No description provided for @upNextSection.
  ///
  /// In en, this message translates to:
  /// **'UP NEXT'**
  String get upNextSection;

  /// No description provided for @recommendationsSection.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDATIONS'**
  String get recommendationsSection;

  /// No description provided for @fromLibrarySection.
  ///
  /// In en, this message translates to:
  /// **'FROM LIBRARY'**
  String get fromLibrarySection;

  /// No description provided for @queueIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueIsEmpty;

  /// No description provided for @historySection.
  ///
  /// In en, this message translates to:
  /// **'HISTORY'**
  String get historySection;

  /// No description provided for @upNextCount.
  ///
  /// In en, this message translates to:
  /// **'UP NEXT ({count})'**
  String upNextCount(int count);

  /// No description provided for @fromLibraryCount.
  ///
  /// In en, this message translates to:
  /// **'FROM LIBRARY ({count})'**
  String fromLibraryCount(int count);

  /// No description provided for @recommendationsCount.
  ///
  /// In en, this message translates to:
  /// **'RECOMMENDATIONS ({count})'**
  String recommendationsCount(int count);

  /// No description provided for @noSongPlaying.
  ///
  /// In en, this message translates to:
  /// **'No Song Playing'**
  String get noSongPlaying;

  /// No description provided for @selectTrackToStart.
  ///
  /// In en, this message translates to:
  /// **'Select a track to start'**
  String get selectTrackToStart;

  /// No description provided for @importLabel.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importLabel;

  /// No description provided for @saveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveLabel;

  /// No description provided for @refreshLabel.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshLabel;

  /// No description provided for @hideTranslation.
  ///
  /// In en, this message translates to:
  /// **'Hide Translation'**
  String get hideTranslation;

  /// No description provided for @translateLabel.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translateLabel;

  /// No description provided for @lyricsByLRCLIB.
  ///
  /// In en, this message translates to:
  /// **'Lyrics by LRCLIB'**
  String get lyricsByLRCLIB;

  /// No description provided for @importLyricsFile.
  ///
  /// In en, this message translates to:
  /// **'Import Lyrics File'**
  String get importLyricsFile;

  /// No description provided for @overwriteLrcWarning.
  ///
  /// In en, this message translates to:
  /// **'This song already has a local .lrc file.\nDo you want to overwrite it?'**
  String get overwriteLrcWarning;

  /// No description provided for @saveLrcPrompt.
  ///
  /// In en, this message translates to:
  /// **'Save current lyrics next to the audio file?'**
  String get saveLrcPrompt;

  /// No description provided for @overwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get overwrite;

  /// No description provided for @lyricsSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Lyrics saved as .lrc file'**
  String get lyricsSavedSuccess;

  /// No description provided for @lyricsSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save lyrics'**
  String get lyricsSaveError;

  /// No description provided for @equalizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// No description provided for @trackDetails.
  ///
  /// In en, this message translates to:
  /// **'Track Details'**
  String get trackDetails;

  /// No description provided for @audioQuality.
  ///
  /// In en, this message translates to:
  /// **'Audio Quality'**
  String get audioQuality;

  /// No description provided for @formatLabel.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get formatLabel;

  /// No description provided for @codecLabel.
  ///
  /// In en, this message translates to:
  /// **'Codec'**
  String get codecLabel;

  /// No description provided for @bitrateLabel.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get bitrateLabel;

  /// No description provided for @sampleRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Sample Rate'**
  String get sampleRateLabel;

  /// No description provided for @bitDepthLabel.
  ///
  /// In en, this message translates to:
  /// **'Bit Depth'**
  String get bitDepthLabel;

  /// No description provided for @channelsLabel.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channelsLabel;

  /// No description provided for @fileSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'File Size'**
  String get fileSizeLabel;

  /// No description provided for @fileLocation.
  ///
  /// In en, this message translates to:
  /// **'File Location'**
  String get fileLocation;

  /// No description provided for @audioSource.
  ///
  /// In en, this message translates to:
  /// **'Audio Source'**
  String get audioSource;

  /// No description provided for @pathLabel.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get pathLabel;

  /// No description provided for @inputLabel.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get inputLabel;

  /// No description provided for @engineLabel.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get engineLabel;

  /// No description provided for @eqLabel.
  ///
  /// In en, this message translates to:
  /// **'EQ'**
  String get eqLabel;

  /// No description provided for @dspLabel.
  ///
  /// In en, this message translates to:
  /// **'DSP'**
  String get dspLabel;

  /// No description provided for @androidMixer.
  ///
  /// In en, this message translates to:
  /// **'Android Mixer'**
  String get androidMixer;

  /// No description provided for @bypassedBitPerfect.
  ///
  /// In en, this message translates to:
  /// **'Bypassed (Bit-Perfect)'**
  String get bypassedBitPerfect;

  /// No description provided for @resamplingLabel.
  ///
  /// In en, this message translates to:
  /// **'Resampling'**
  String get resamplingLabel;

  /// No description provided for @activeNoResampling.
  ///
  /// In en, this message translates to:
  /// **'Active (No resampling needed)'**
  String get activeNoResampling;

  /// No description provided for @nativeRate.
  ///
  /// In en, this message translates to:
  /// **'Native rate'**
  String get nativeRate;

  /// No description provided for @signalOutput.
  ///
  /// In en, this message translates to:
  /// **'Signal Output'**
  String get signalOutput;

  /// No description provided for @outputLabel.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get outputLabel;

  /// No description provided for @samplingRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Sampling Rate'**
  String get samplingRateLabel;

  /// No description provided for @bitsLabel.
  ///
  /// In en, this message translates to:
  /// **'Bits'**
  String get bitsLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get unknownDevice;

  /// No description provided for @sharedMode.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get sharedMode;

  /// No description provided for @exclusiveMode.
  ///
  /// In en, this message translates to:
  /// **'Exclusive'**
  String get exclusiveMode;

  /// No description provided for @androidAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'Android AudioTrack'**
  String get androidAudioTrack;

  /// No description provided for @songInformation.
  ///
  /// In en, this message translates to:
  /// **'Song Information'**
  String get songInformation;

  /// No description provided for @selectVersion.
  ///
  /// In en, this message translates to:
  /// **'Select Version'**
  String get selectVersion;

  /// No description provided for @searchYoutubeHint.
  ///
  /// In en, this message translates to:
  /// **'Search YouTube...'**
  String get searchYoutubeHint;

  /// No description provided for @androidAudioEffectsNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Audio effects are only audible on Android devices.'**
  String get androidAudioEffectsNote;

  /// No description provided for @deletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete Preset'**
  String get deletePreset;

  /// No description provided for @saveAsNewPreset.
  ///
  /// In en, this message translates to:
  /// **'Save as New Preset'**
  String get saveAsNewPreset;

  /// No description provided for @savePreset.
  ///
  /// In en, this message translates to:
  /// **'Save Preset'**
  String get savePreset;

  /// No description provided for @enterPresetName.
  ///
  /// In en, this message translates to:
  /// **'Enter preset name (e.g. My Bass)'**
  String get enterPresetName;

  /// No description provided for @presetSaved.
  ///
  /// In en, this message translates to:
  /// **'Preset saved!'**
  String get presetSaved;

  /// No description provided for @miniPlayer.
  ///
  /// In en, this message translates to:
  /// **'Mini Player'**
  String get miniPlayer;

  /// No description provided for @listeningParty.
  ///
  /// In en, this message translates to:
  /// **'Listening Party'**
  String get listeningParty;

  /// No description provided for @audioOutput.
  ///
  /// In en, this message translates to:
  /// **'Audio Output'**
  String get audioOutput;

  /// No description provided for @lyricsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyricsTooltip;

  /// No description provided for @queueTooltip.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queueTooltip;

  /// No description provided for @moreOptionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'More Options'**
  String get moreOptionsTooltip;

  /// No description provided for @muteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get muteTooltip;

  /// No description provided for @unmuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmuteTooltip;

  /// No description provided for @fullScreenPlayerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Full Screen Player'**
  String get fullScreenPlayerTooltip;

  /// No description provided for @importLyricsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import Lyrics'**
  String get importLyricsTooltip;

  /// No description provided for @saveLyricsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save Lyrics'**
  String get saveLyricsTooltip;

  /// No description provided for @refreshLyricsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh Lyrics'**
  String get refreshLyricsTooltip;

  /// No description provided for @translateLyricsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Translate Lyrics'**
  String get translateLyricsTooltip;

  /// No description provided for @sharePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Share Playlist'**
  String get sharePlaylist;

  /// No description provided for @importViaCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import a playlist shared by a friend'**
  String get importViaCodeSubtitle;

  /// No description provided for @sharePlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Share \"{name}\"'**
  String sharePlaylistTitle(String name);

  /// No description provided for @generatingShareCode.
  ///
  /// In en, this message translates to:
  /// **'Generating share code...'**
  String get generatingShareCode;

  /// No description provided for @failedToGenerateCode.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate share code. Check your connection.'**
  String get failedToGenerateCode;

  /// No description provided for @playlistReadyShare.
  ///
  /// In en, this message translates to:
  /// **'Your playlist is ready to share!'**
  String get playlistReadyShare;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied to clipboard!'**
  String get codeCopied;

  /// No description provided for @shareCodeUsage.
  ///
  /// In en, this message translates to:
  /// **'Give this 6-digit code to a friend for them to import this playlist.'**
  String get shareCodeUsage;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get fileName;

  /// No description provided for @dataUsage.
  ///
  /// In en, this message translates to:
  /// **'Data Usage'**
  String get dataUsage;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today: {size}'**
  String todayLabel(String size);

  /// No description provided for @last7DaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days: {size}'**
  String last7DaysLabel(String size);

  /// No description provided for @last30DaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days: {size}'**
  String last30DaysLabel(String size);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'de',
        'en',
        'es',
        'fr',
        'hi',
        'id',
        'ja',
        'ko',
        'pt',
        'ru',
        'th',
        'vi',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'th':
      return AppLocalizationsTh();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
