// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutEducationalPurpose =>
      'This application is developed for individual and educational purposes only.';

  @override
  String get aboutLicenses => 'About & Licenses';

  @override
  String get aboutNotForCommercial => 'Not for commercial use.';

  @override
  String get accentColor => 'Accent Color';

  @override
  String get access => 'Access';

  @override
  String get accessCode => 'Access Code';

  @override
  String get accountDataMergeDesc =>
      'By syncing, your profile name and avatar will be updated, but your current device\'s listening minutes will be successfully merged into the account total.';

  @override
  String get accountLinked => 'Account Linked';

  @override
  String get accountLinkedSuccessfully => 'Account linked successfully!';

  @override
  String get achievementsUnlocked => 'Achievements Unlocked';

  @override
  String get activeNoResampling => 'Active (No resampling needed)';

  @override
  String get add => 'Add';

  @override
  String get addFiles => 'Add Files';

  @override
  String get addFolder => 'Add Folder';

  @override
  String get addFoldersScan => 'Add more folders to scan';

  @override
  String get addToFavorite => 'Add to Favorite';

  @override
  String get addToPlaylist => 'Add to Playlist';

  @override
  String get addToQueue => 'Add to Queue';

  @override
  String addedFolder(Object folder) {
    return 'Added folder: $folder';
  }

  @override
  String get addedToLikedSongs => 'Added to Liked Songs';

  @override
  String get addedToPlaylistSuccess => 'ADDED TO PLAYLIST';

  @override
  String get addedToQueue => 'Added to Queue';

  @override
  String get album => 'Album';

  @override
  String get albumAddedToPlaylists => 'Album added to playlists';

  @override
  String get albumLabel => 'Album';

  @override
  String get albumRemovedFromPlaylists => 'Album removed from playlists';

  @override
  String get albums => 'Albums';

  @override
  String get allDownloadsRemoved => 'All downloads removed';

  @override
  String get allRightsReserved => 'All Rights Reserved.';

  @override
  String get allTime => 'All-Time';

  @override
  String get alreadyInLikedSongs => 'ALREADY IN LIKED SONGS';

  @override
  String get android14BitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidAudioEffectsNote =>
      'Note: Audio effects are only audible on Android devices.';

  @override
  String get androidAudioTrack => 'Android AudioTrack';

  @override
  String get androidBitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidMixer => 'Android Mixer';

  @override
  String get appearance => 'Appearance';

  @override
  String get applyOnRestart => 'Changes will apply on next restart.';

  @override
  String get arabic => 'Arabic';

  @override
  String get artist => 'Artist';

  @override
  String get artistLabel => 'ARTIST';

  @override
  String get artists => 'Artists';

  @override
  String get atmospheres => 'Atmospheres';

  @override
  String get audioFormat => 'Audio Format';

  @override
  String get audioOutput => 'Audio Output';

  @override
  String get audioOutputDevice => 'Audio Output Device';

  @override
  String get audioQuality => 'Audio Quality';

  @override
  String get audioSource => 'Audio Source';

  @override
  String get audiophileDAC =>
      'Enable for audiophile DAC playback (Restart required)';

  @override
  String get autoAddSimilar =>
      'Auto-add similar songs when queue is nearly empty';

  @override
  String get autoClearAfter24h => 'After 24 hours';

  @override
  String get autoClearAfter7d => 'After 7 days';

  @override
  String get autoClearCache => 'Auto Clear Cache';

  @override
  String get autoClearDisabled => 'Disabled';

  @override
  String get autoClearEvery30m => 'Every 30 mins (Listening)';

  @override
  String get autoClearOnClose => 'When app closed';

  @override
  String get autoFixComingSoon => 'Auto-Fix (Coming Soon)';

  @override
  String get autoRestartNotSupported =>
      'Auto-restart not supported. Please restart manually.';

  @override
  String autoTagContent(int count, String sourceName) {
    return 'This will search Spotify for all $count songs in \'$sourceName\' and overwrite their tags automatically.\n\nThis process cannot be undone.';
  }

  @override
  String autoTagTitle(String sourceName) {
    return '⚠️ Auto-Tag $sourceName?';
  }

  @override
  String get automatic => 'Automatic';

  @override
  String automaticTitleLabel(String title) {
    return 'Automatic: $title';
  }

  @override
  String get autumn => 'Autumn';

  @override
  String get avatarPickerDesc => 'Select a template or import your own photo';

  @override
  String get beFirstToClaim => 'Be the first to claim the top spot!';

  @override
  String get behavioralHeader => 'BEHAVIORAL ACHIEVEMENTS';

  @override
  String get behavioralTitles => 'BEHAVIORAL';

  @override
  String get binariesUpdateRequired => 'Binaries Update Required';

  @override
  String get bitDepthLabel => 'Bit Depth';

  @override
  String get bitPerfectEnabled =>
      'Bit-Perfect Mode Enabled. Volume control may be disabled.';

  @override
  String get bitPerfectWindows =>
      'Bit-perfect audio with auto sample rate (Restart required)';

  @override
  String get bitrateLabel => 'Bitrate';

  @override
  String get bitsLabel => 'Bits';

  @override
  String get brazil => 'Brazil';

  @override
  String get browse => 'Browse';

  @override
  String get bypassSystemMixer => 'Bypass system mixer for USB DACs';

  @override
  String get bypassedBitPerfect => 'Bypassed (Bit-Perfect)';

  @override
  String get cacheCleared => 'Cache cleared successfully!';

  @override
  String get cached => 'Cached';

  @override
  String get cancel => 'Cancel';

  @override
  String get championChampionTooltip =>
      'Reach Top 1 Global for 5 different weeks';

  @override
  String get change => 'Change';

  @override
  String get changeFolder => 'Change Folder';

  @override
  String get changeFormatInSettings =>
      'Please change output format in Settings';

  @override
  String get changeLabel => 'CHANGE';

  @override
  String get changeLanguage => 'Change application language';

  @override
  String get changesApplyRestart => 'Changes will apply on next restart.';

  @override
  String get changingAudioDeviceRestart =>
      'Changing the audio output device requires a restart application to take effect.\n\nWould you like to restart now?';

  @override
  String get channelsLabel => 'Channels';

  @override
  String get checkAgain => 'Check Again';

  @override
  String get checkInternetConnection => 'Check your internet connection';

  @override
  String get checkNetworkTryAgain => 'Please check your network and try again';

  @override
  String get chinese => 'Chinese';

  @override
  String get chooseAccentColor => 'Choose your preferred static color';

  @override
  String get chooseAnimationType => 'Choose animation type';

  @override
  String get chooseArtist => 'CHOOSE ARTIST';

  @override
  String get chooseAvatar => 'Choose Avatar';

  @override
  String get chooseYourTitle => 'Choose Your Title';

  @override
  String get circularPulse => 'Circular Pulse';

  @override
  String get clearAll => 'Clear All';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get clearImported => 'Clear Imported';

  @override
  String get clearMetadataCache => 'Clear Metadata & Art Cache';

  @override
  String get clearPlayHistory => 'Clear play history and listening time';

  @override
  String get clearStreamingCache => 'Clear Streaming Cache';

  @override
  String get close => 'Close';

  @override
  String get cloud => 'Cloud';

  @override
  String get codeCopied => 'Code copied to clipboard!';

  @override
  String get codeMust6Digits => 'Code must be 6 digits';

  @override
  String get codecLabel => 'Codec';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get community => 'Community';

  @override
  String get competitiveTitles => 'COMPETITIVE';

  @override
  String get confirm => 'Confirm';

  @override
  String get connect => 'Connect';

  @override
  String get connectToADevice => 'Connect to a Device';

  @override
  String get connected => 'Connected';

  @override
  String connectedToDac(String deviceName) {
    return 'Connected to $deviceName - USB Bypass Active';
  }

  @override
  String get connectedUsbDacs => 'Connected USB DACs:';

  @override
  String get connecting => 'Connecting...';

  @override
  String get connectionLostLeaderboard => 'Connection Lost';

  @override
  String get connectionLostLeaderboardDesc =>
      'The Global Leaderboard requires an active connection to sync your stats and fetch worldwide rankings.';

  @override
  String consecutivePlaysTooltip(int count) {
    return 'Listen to the same song $count times consecutively to obtain';
  }

  @override
  String get contentRegion => 'Content Region';

  @override
  String get copyCode => 'Copy Code';

  @override
  String get couldNotDownloadFlac => 'Could not download FLAC.';

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
    );
    return '$_temp0';
  }

  @override
  String get createPlaylist => 'Create Playlist';

  @override
  String creatingPlaylistWithTracks(int count) {
    return 'Creating playlist with $count tracks...';
  }

  @override
  String get crossfade => 'Crossfade';

  @override
  String crossfadeDesc(String seconds) {
    return 'Fade between tracks (${seconds}s)';
  }

  @override
  String get crownedChampionTitlesHeader => 'CROWNED CHAMPION TITLES';

  @override
  String get customDevice => 'Custom Device';

  @override
  String get customSelected => 'Custom Selected';

  @override
  String get customTime => 'Custom Time';

  @override
  String get cyberpunk => 'Cyberpunk';

  @override
  String get daily => 'Daily';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get dataCleanup => 'Data & Cleanup';

  @override
  String get dataUsage => 'Data Usage';

  @override
  String get daysShort => 'D';

  @override
  String get debugging => 'Debugging';

  @override
  String get delete => 'Delete';

  @override
  String get deleteDownloadsConfirm =>
      'This will remove all downloaded songs for this playlist from your device.';

  @override
  String get deleteDownloadsTitle => 'Delete Downloads?';

  @override
  String deleteFileContent(String filename) {
    return 'Delete \'$filename\'?\nThis cannot be undone.';
  }

  @override
  String get deleteFileTitle => 'Delete File?';

  @override
  String get deletePlaylist => 'Delete Playlist';

  @override
  String deletePlaylistConfirm(String name) {
    return 'Delete \'$name\'?';
  }

  @override
  String get deletePlaylistPermanentConfirm =>
      'Are you sure want to delete this playlist? (This action cannot be undone)';

  @override
  String get deletePlaylistTitle => 'Delete Playlist?';

  @override
  String get deletePreset => 'Delete Preset';

  @override
  String get desertMirage => 'Desert Mirage';

  @override
  String get developerExclusiveTooltip =>
      'Exclusively for the developers of this app';

  @override
  String deviceNameLabel(String deviceName) {
    return 'Device: $deviceName';
  }

  @override
  String get disableCanvas => 'Disable Canvas';

  @override
  String get disableRomanization => 'Disable Romanization';

  @override
  String get disablingSharingWarning =>
      'Disabling sharing will permanently delete the code and the data from the server to save space.';

  @override
  String get discNumber => 'Disc #';

  @override
  String get discography => 'Discography';

  @override
  String get discordRPC => 'Discord Rich Presence';

  @override
  String get doYouRemember => 'Do you remember?';

  @override
  String get donate => 'Donate';

  @override
  String get download => 'Download';

  @override
  String get downloadAll => 'Download All';

  @override
  String get downloadComplete => 'DOWNLOAD COMPLETE';

  @override
  String get downloadCompleteNotification => 'Download Complete';

  @override
  String get downloadError => 'Download error';

  @override
  String get downloadFailed => 'DOWNLOAD FAILED';

  @override
  String get downloadLocation => 'Download Location';

  @override
  String get downloadPathReset => 'Download path reset to default.';

  @override
  String downloadPathUpdated(Object path) {
    return 'Download path updated: $path';
  }

  @override
  String get downloadSong => 'Download Song';

  @override
  String get downloadStarted => 'DOWNLOAD STARTED';

  @override
  String downloadedTo(String path) {
    return 'Downloaded to: $path';
  }

  @override
  String get downloading => 'DOWNLOADING';

  @override
  String get downloadingFlac => 'DOWNLOADING FLAC';

  @override
  String downloadingFormat(String format) {
    return 'Downloading $format';
  }

  @override
  String get downloadingUpdate => 'Downloading Update';

  @override
  String get downloads => 'Downloads';

  @override
  String get dspLabel => 'DSP';

  @override
  String get editMetadata => 'Edit Metadata';

  @override
  String get editNickname => 'Edit Nickname';

  @override
  String get editor => 'Editor';

  @override
  String get emptyMailbox => 'Empty Mailbox';

  @override
  String get emptyMailboxDesc => 'This will delete all messages permanently.';

  @override
  String get emptyMailboxTitle => 'Empty Mailbox?';

  @override
  String get emptyPlaylist => 'Empty Playlist';

  @override
  String get emptyPlaylistSubtitle => 'Create a new empty playlist';

  @override
  String get enableAlphabetIndexer => 'Enable Alphabet Scroll Indexer';

  @override
  String get enableAlphabetIndexerSubtitle =>
      'Show A-Z sidebar indexing on mobile list view';

  @override
  String get enableBarVisualizer => 'Enable Bar Visualizer';

  @override
  String get endlessQueue => 'Endless Queue';

  @override
  String get engineLabel => 'Engine';

  @override
  String get english => 'English';

  @override
  String get enterAdminAccessCode => 'Enter Admin Access Code';

  @override
  String get enterAdminCode => 'Enter Admin Access Code';

  @override
  String get enterDuration => 'Enter duration...';

  @override
  String get enterPresetName => 'Enter preset name (e.g. My Bass)';

  @override
  String get enterShareCode => 'Enter the 6-digit share code';

  @override
  String get eqLabel => 'EQ';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get equipTitle => 'EQUIP TITLE';

  @override
  String get equipped => 'EQUIPPED';

  @override
  String get error => 'ERROR';

  @override
  String get errorCouldNotCreateSession => 'Error: Could not create session.';

  @override
  String errorDeleting(String error) {
    return 'Error deleting: $error';
  }

  @override
  String get errorSearchingStream => 'Error searching for stream.';

  @override
  String get exclusiveMode => 'Exclusive';

  @override
  String get exclusiveModeWarning =>
      'Warning: Exclusive Mode works best when a specific device is selected above, rather than System Default.';

  @override
  String get exclusiveTitles => 'EXCLUSIVE';

  @override
  String get exclusiveTitlesHeader => 'EXCLUSIVE TITLES';

  @override
  String get exclusiveWarning =>
      'Warning: Exclusive Mode works best when a specific device is selected above, rather than System Default.';

  @override
  String get exitApp => 'Quit';

  @override
  String get expand => 'Expand';

  @override
  String get externalFiles => 'External Files';

  @override
  String get fadingAtEnd => 'Sleep Timer: Fading out at end of track...';

  @override
  String get failedDisableSharing => 'Failed to disable sharing.';

  @override
  String get failedEnableSharing =>
      'Failed to enable sharing. Check connection.';

  @override
  String get failedFetchPlaylistInfo => 'Could not fetch playlist info';

  @override
  String get failedToConnectDac =>
      'Failed to connect to DAC. Check USB permissions.';

  @override
  String get failedToGenerateCode =>
      'Failed to generate share code. Check your connection.';

  @override
  String get failedToSetAvatar => 'Failed to set avatar template';

  @override
  String get failedToUpdateMetadata => 'Failed to update metadata';

  @override
  String get favoriteTrack => 'Favorite Track';

  @override
  String get fetchingCanvas => 'Fetching Canvas...';

  @override
  String get fetchingLossless => 'FETCHING LOSSLESS...';

  @override
  String get fetchingLosslessAudio => 'Fetching lossless audio...';

  @override
  String get fetchingMetadataSpotify => 'Fetching metadata from Spotify...';

  @override
  String get fetchingPlaylist => 'Fetching playlist...';

  @override
  String get fetchingPlaylistInfo => 'Fetching playlist info...';

  @override
  String get fetchingSharedPlaylist => 'Fetching shared playlist...';

  @override
  String fetchingTracksFrom(String name) {
    return 'Fetching tracks from \"$name\"...';
  }

  @override
  String get fileLocation => 'Audio Source';

  @override
  String get fileMissingHistory => 'File missing and not found in history.';

  @override
  String get fileName => 'File Name';

  @override
  String get fileSizeLabel => 'File Size';

  @override
  String get files => 'Files';

  @override
  String get filters => 'Filters';

  @override
  String get findingBestMatchYoutube => 'Finding best match on YouTube...';

  @override
  String get findingStream => 'Finding stream source...';

  @override
  String get finishUpdate => 'Finish Update';

  @override
  String get finishes => 'Finishes';

  @override
  String get fixAll => 'Fix All';

  @override
  String get flacError => 'FLAC ERROR';

  @override
  String get flacNote =>
      'Note: FLAC is available for single track downloads only. Bulk playlist downloads use M4A format.';

  @override
  String get flacSavedToDownloads => 'FLAC saved to Downloads';

  @override
  String get flacUnavailable => 'FLAC UNAVAILABLE';

  @override
  String get flacUnavailableDesc =>
      'FLAC not available, download failed. Try changing settings.';

  @override
  String get flacUnavailableNotification => 'FLAC Unavailable';

  @override
  String get fluidWave => 'Fluid Wave';

  @override
  String folderPath(String path) {
    return 'Folder: $path';
  }

  @override
  String get folders => 'Folders';

  @override
  String get formatLabel => 'Format';

  @override
  String get formatSaved => 'Format saved!';

  @override
  String foundExistingAccount(String name) {
    return 'We found an existing account for \'$name\'.';
  }

  @override
  String foundResults(int songCount, int albumCount, int artistCount) {
    return 'Found $songCount songs, $albumCount albums, $artistCount artists.';
  }

  @override
  String foundYoutubeResults(int count) {
    return 'Found $count results on YouTube';
  }

  @override
  String freeUpSpace(String size) {
    return 'Free up space (Current: $size)';
  }

  @override
  String get french => 'French';

  @override
  String fromLibraryCount(int count) {
    return 'FROM LIBRARY ($count)';
  }

  @override
  String get fromLibrarySection => 'FROM LIBRARY';

  @override
  String get fullScreenPlayerTooltip => 'Full Screen Player';

  @override
  String get galacticSpace => 'Galactic Space';

  @override
  String get gaplessPlayback => 'Gapless Playback';

  @override
  String get gaplessPlaybackDesc => 'Eliminate silence between tracks';

  @override
  String get general => 'General';

  @override
  String get generatingShareCode => 'Generating share code...';

  @override
  String get genre => 'Genre';

  @override
  String get german => 'German';

  @override
  String get globalLeaderboard => 'Global Leaderboard';

  @override
  String get globalMailbox => 'Global Mailbox';

  @override
  String get globalRank => 'Global Rank';

  @override
  String get globalRankings => 'Global Rankings';

  @override
  String get globalRankingsDesc =>
      'View daily, weekly, and all-time top listeners!';

  @override
  String get goToArtist => 'Go to Artist';

  @override
  String get goToLocalLibraryToSelect =>
      'Go to \'Local Library\' to select your music folder.';

  @override
  String get goodAfternoon => 'Good Afternoon';

  @override
  String get goodEvening => 'Good Evening';

  @override
  String get goodMorning => 'Good Morning';

  @override
  String get googleAccount => 'Google Account';

  @override
  String get grantAccess => 'Grant Access';

  @override
  String get grantPermission => 'Grant Permission';

  @override
  String get hallOfFameHeader => 'HALL OF FAME ACHIEVEMENTS';

  @override
  String get hallOfFameTitles => 'HALL OF FAME';

  @override
  String get hideCanvas => 'Hide Spotify Canvas video, show album art instead';

  @override
  String get hideRomajiPinyin =>
      'Hide romaji/pinyin below Korean, Japanese, and Chinese lyrics';

  @override
  String get hideTranslation => 'Hide Translation';

  @override
  String get highDesc => 'M4A - Better quality, balanced';

  @override
  String get highQuality => 'High (M4A)';

  @override
  String get hindi => 'Hindi';

  @override
  String get history => 'History';

  @override
  String get historySection => 'HISTORY';

  @override
  String get home => 'Home';

  @override
  String get hourShort => 'Hr';

  @override
  String hoursDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Hours',
      one: '1 Hour',
    );
    return '$_temp0';
  }

  @override
  String get hoursShort => 'H';

  @override
  String get ignoreSubfolderScan => 'Ignore Subfolder Scan';

  @override
  String get importAdditionalPaths => 'Import Additional Paths';

  @override
  String get importChoice => 'Import';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get importFromGallery => 'Import from Gallery';

  @override
  String get importFromSpotify => 'Import from Spotify';

  @override
  String get importFromSpotifySubtitle => 'Paste a Spotify playlist URL';

  @override
  String get importFromYoutubeMusic => 'Import from YouTube Music';

  @override
  String get importFromYoutubeMusicSubtitle =>
      'Paste a YouTube Music playlist URL';

  @override
  String get importLabel => 'Import';

  @override
  String get importLyricsFile => 'Import Lyrics File';

  @override
  String get importLyricsTooltip => 'Import Lyrics';

  @override
  String get importSpotifyPlaylist => 'Import Spotify Playlist';

  @override
  String get importViaCode => 'Import via Code';

  @override
  String get importViaCodeSubtitle => 'Import a playlist shared by a friend';

  @override
  String get importYoutubeMusicPlaylist => 'Import YouTube Music Playlist';

  @override
  String importedPlaylistName(String name) {
    return 'Imported \"$name\"!';
  }

  @override
  String importedTracks(int count) {
    return 'Imported $count tracks!';
  }

  @override
  String get indonesia => 'Indonesia';

  @override
  String get indonesian => 'Indonesian';

  @override
  String get inputLabel => 'Input';

  @override
  String get installNow => 'Install Now';

  @override
  String get integration => 'Integration';

  @override
  String get invalidAccessCode => 'Invalid Access Code';

  @override
  String get invalidCode => 'Invalid Access Code';

  @override
  String get invalidSpotifyUrl => 'Invalid Spotify playlist URL';

  @override
  String get invalidYoutubeMusicUrl => 'Invalid YouTube Music playlist URL';

  @override
  String get japan => 'Japan';

  @override
  String get japanese => 'Japanese';

  @override
  String get joinUs => 'Join Us';

  @override
  String get jumpBackIn => 'Jump Back In';

  @override
  String get justEnjoyVibes => 'Just enjoy the vibes.';

  @override
  String get korean => 'Korean';

  @override
  String get language => 'Language';

  @override
  String last30DaysLabel(String size) {
    return 'Last 30 days: $size';
  }

  @override
  String last7DaysLabel(String size) {
    return 'Last 7 days: $size';
  }

  @override
  String get later => 'Later';

  @override
  String get library => 'Library';

  @override
  String get libraryData => 'Library Data';

  @override
  String get libraryNotLoaded => 'Library not loaded.';

  @override
  String get libraryPathReset => 'Library path reset.';

  @override
  String get likedSongs => 'LIKED SONGS';

  @override
  String get linkAccount => 'Link Account';

  @override
  String get linkAccountDesc => 'Sync and restore your progress with Google';

  @override
  String listenMinutesTooltip(String minutes) {
    return 'Listen to $minutes minutes of music';
  }

  @override
  String get listeningParty => 'Listening Party';

  @override
  String get listeningStats => 'Listening Stats';

  @override
  String get loadingCanvas => 'Loading canvas...';

  @override
  String get loadingDevices => 'Loading devices...';

  @override
  String get loadingError => 'Failed to load details. Please try again.';

  @override
  String get loadingLyrics => 'Loading lyrics...';

  @override
  String get localPlayHistorySaved =>
      'Your local play history will not be deleted.';

  @override
  String get local_library => 'Local Library';

  @override
  String get lockedAtmosphere => 'Locked while an Atmosphere is active';

  @override
  String get losslessDesc => 'FLAC - Lossless quality from Deezer/Tidal';

  @override
  String get losslessNote =>
      'Streams lossless FLAC from Deezer/Tidal when available. Falls back to M4A if unavailable.';

  @override
  String get losslessQuality => 'Lossless (Auto)';

  @override
  String get lunarNewYear => 'Lunar New Year';

  @override
  String get lyricsByLRCLIB => 'Lyrics by LRCLIB';

  @override
  String get lyricsSaveError => 'Failed to save lyrics';

  @override
  String get lyricsSavedSuccess => 'Lyrics saved as .lrc file';

  @override
  String get lyricsTooltip => 'Lyrics';

  @override
  String get madeForYou => 'Made For You';

  @override
  String get manualSearch => 'Manual Search';

  @override
  String get mergeAccountData => 'Merge Account Data?';

  @override
  String get metadataCacheCleared =>
      'Metadata cache cleared & library rescan started';

  @override
  String get metadataEditorInfo =>
      'Fix your metadata editor in a second and just search it.';

  @override
  String get metadataEditorNote =>
      'Note: Album art is changing after state \"Saved Successfully\", you don\'t need to worries its not saved, it\'s just caching problem in app and I currently fix it. You can verify with file manager or else.';

  @override
  String get metadataUpdated => 'Metadata Updated';

  @override
  String get metadata_editor => 'Metadata Editor';

  @override
  String get min => 'min';

  @override
  String get minShortLabel => 'min';

  @override
  String get miniPlayer => 'Mini Player';

  @override
  String get minimizeToTray => 'Minimize to Tray';

  @override
  String get minimizeToTrayDescription =>
      'Close app to system tray instead of exiting';

  @override
  String get minsShort => 'M';

  @override
  String get minsShortLabel => 'mins';

  @override
  String get minuteShort => 'Min';

  @override
  String get minutes => 'Minutes';

  @override
  String minutesDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Minutes',
      one: '1 Minute',
    );
    return '$_temp0';
  }

  @override
  String get moreOptions => 'More Options';

  @override
  String get moreOptionsTooltip => 'More Options';

  @override
  String get mostListened => 'Most Listened';

  @override
  String get mostListenedArtist => 'Most Listened Artist';

  @override
  String get musicFolderLocation => 'Music Folder Location';

  @override
  String get musicSearch => 'Music Search';

  @override
  String musicWillStopIn(String label) {
    return 'Music will stop in $label';
  }

  @override
  String get muteTooltip => 'Mute';

  @override
  String myTopTrackOn(String header) {
    return 'My $header on Simple Player! 🎵';
  }

  @override
  String get nativeRate => 'Native rate';

  @override
  String get navigation => 'Navigation';

  @override
  String get newPlaylist => 'New Playlist';

  @override
  String get nextTrack => 'Next Track';

  @override
  String get nicknameHint => 'Enter your nickname';

  @override
  String get nicknameLabel => 'Nickname';

  @override
  String get nicknameRequired => 'Nickname Required';

  @override
  String get nicknameRequiredDesc =>
      'You need to set a custom nickname first to view the Global Leaderboard!';

  @override
  String get nicknameTakenDesc =>
      'This nickname is already in use globally. Please choose another one.';

  @override
  String get nicknameTakenTitle => 'Nickname Taken';

  @override
  String get noAlbumsFound => 'No albums found';

  @override
  String get noArtistStatsYet => 'No artist stats yet.';

  @override
  String get noArtistsFound => 'No artists found.';

  @override
  String get noDownloadsFound => 'No downloads found';

  @override
  String get noFolderSelected => 'No folder selected';

  @override
  String get noHistoryYet => 'No history yet';

  @override
  String get noInternetConnection => 'No Internet Connection';

  @override
  String get noLyricsAvailable => 'No lyrics available';

  @override
  String get noMessages => 'No messages in your mailbox';

  @override
  String get noMusicPlaying => 'No music playing';

  @override
  String get noPlaylistsFound => 'No Playlists Found';

  @override
  String get noPlaylistsYet => 'No playlists yet';

  @override
  String get noRankingsYet => 'No rankings yet for this timeframe.';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get noSongPlaying => 'No Song Playing';

  @override
  String get noSongsAdded => 'No songs added yet';

  @override
  String get noSongsInFolder => 'No songs found in this folder.';

  @override
  String get noSpotifyResults => 'No Spotify results found.';

  @override
  String get noStatsYet => 'No stats yet.';

  @override
  String get noStreamMatch => 'Could not find a matching stream.';

  @override
  String get noSuggestionsFound => 'No suggestions found.';

  @override
  String get noSyncedLyricsFound => 'No Synced Lyrics Found';

  @override
  String get noTracksFound => 'No tracks found in playlist';

  @override
  String get noUsbDacDetected =>
      'No USB DAC detected. Connect a USB audio device and tap Scan.';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get noYoutubeResults => 'No results found on YouTube';

  @override
  String get none => 'None';

  @override
  String get nordicAurora => 'Nordic Aurora';

  @override
  String notRank(int rank) {
    return 'Not Rank $rank';
  }

  @override
  String get notRanked => 'Not Ranked';

  @override
  String get notRankedTop3 => 'NOT RANKED Top 3';

  @override
  String get nowPlaying => 'NOW PLAYING';

  @override
  String get nowPlayingHeader => 'Now Playing';

  @override
  String get nowPlayingSection => 'NOW PLAYING';

  @override
  String get offline => 'Offline';

  @override
  String get offlineStatus => 'Offline';

  @override
  String get ok => 'OK';

  @override
  String get online => 'Online';

  @override
  String get onlyScanSelected => 'Only scan selected folder (Default: On)';

  @override
  String get opacity => 'Opacity';

  @override
  String opacityLabel(int percent) {
    return 'Opacity: $percent%';
  }

  @override
  String get openProfile => 'Open Profile';

  @override
  String get openSourceLicenses => 'Open Source Licenses';

  @override
  String get outputLabel => 'Output';

  @override
  String get overwrite => 'Overwrite';

  @override
  String get overwriteLrcWarning =>
      'This song already has a local .lrc file.\nDo you want to overwrite it?';

  @override
  String get parsingPlaylistData => 'Parsing playlist data...';

  @override
  String get pathLabel => 'Path';

  @override
  String get permissionRequired => 'Permission Required';

  @override
  String get permissionRequiredDesc =>
      'To edit tags, we need \'All Files Access\' permission. This allows us to modify your music files directly.';

  @override
  String get play => 'play';

  @override
  String playCountLabel(int count) {
    return '$count plays';
  }

  @override
  String get playNext => 'Play Next';

  @override
  String get playPause => 'Play / Pause';

  @override
  String get playQueue => 'Play Queue';

  @override
  String get playback => 'Playback';

  @override
  String get playbackError => 'Playback Error';

  @override
  String get player => 'Player';

  @override
  String get playingFromAlbum => 'PLAYING FROM ALBUM';

  @override
  String get playingNext => 'Playing Next';

  @override
  String get playingTrack => 'PLAYING TRACK';

  @override
  String get playlistAlbumTracks => 'Playlist / Album Tracks';

  @override
  String get playlistNameHint => 'Playlist Name';

  @override
  String get playlistNotFound => 'Playlist not found';

  @override
  String get playlistNotFoundOrError => 'Playlist not found or server error';

  @override
  String get playlistReadyShare => 'Your playlist is ready to share!';

  @override
  String get playlists => 'Playlists';

  @override
  String get plays => 'plays';

  @override
  String get popularOnSpotify => 'Popular on Spotify';

  @override
  String get portuguese => 'Portuguese';

  @override
  String get preferredOutputFormat => 'Preferred output format for downloads';

  @override
  String get preparingDownload => 'PREPARING DOWNLOAD';

  @override
  String preparingDownloadFormat(String format) {
    return 'Preparing download ($format)...';
  }

  @override
  String get preparingDownloadNotification => 'Preparing Download';

  @override
  String get presetSaved => 'Preset saved!';

  @override
  String get preview => 'PREVIEW';

  @override
  String get previousTrack => 'Previous Track';

  @override
  String get profileSettings => 'Profile Settings';

  @override
  String get profileStats => 'Profile Stats';

  @override
  String get progress => 'Progress';

  @override
  String get publicSharing => 'Public Sharing';

  @override
  String get publicSharingDesc =>
      'Anyone with the code can import this playlist.';

  @override
  String get publicSharingDisabledDesc =>
      'Disabled. Enable to share with others.';

  @override
  String get queueIsEmpty => 'Queue is empty';

  @override
  String get queueTooltip => 'Queue';

  @override
  String get queueUpdated => 'QUEUE UPDATED';

  @override
  String get quickMix => 'Quick Mix';

  @override
  String get rainbowMode => 'Rainbow Mode';

  @override
  String get rainyCity => 'Rainy City';

  @override
  String get rank => 'Rank';

  @override
  String rankActive(int rank) {
    return 'Rank $rank (Active)';
  }

  @override
  String rankLabel(int rank) {
    return 'RANK $rank';
  }

  @override
  String get reBuffering => 'Re-buffering...';

  @override
  String reachDailyPlaysTooltip(int count) {
    return 'Reach $count plays in a single day to obtain';
  }

  @override
  String reachSpecificArtistTooltip(String minutes) {
    return 'Reach $minutes minutes with a specific artist to obtain';
  }

  @override
  String reachWeeklyPlaysTooltip(int count) {
    return 'Reach $count plays in a single week to obtain';
  }

  @override
  String get readySearchSong => 'Ready. Search for a song.';

  @override
  String get rebufferingFromCloud => 'Re-buffering from cloud...';

  @override
  String get recentlyPlayed => 'Recently Played';

  @override
  String recommendationsCount(int count) {
    return 'RECOMMENDATIONS ($count)';
  }

  @override
  String get recommendationsSection => 'RECOMMENDATIONS';

  @override
  String get rediscover => 'Rediscover';

  @override
  String get refreshLabel => 'Refresh';

  @override
  String get refreshLibrary => 'Refresh Library';

  @override
  String get refreshList => 'Refresh List';

  @override
  String get refreshLyricsTooltip => 'Refresh Lyrics';

  @override
  String get removeAvatar => 'Remove Current Avatar';

  @override
  String get removeFromPlaylist => 'Remove from Playlist';

  @override
  String removedFolder(Object folder) {
    return 'Removed folder: $folder';
  }

  @override
  String get rename => 'Rename';

  @override
  String get renamePlaylist => 'Rename Playlist';

  @override
  String get repeats => 'repeats';

  @override
  String get requiresAndroid14 => 'Requires Android 14+ and USB DAC';

  @override
  String get resamplingLabel => 'Resampling';

  @override
  String get reset => 'Reset';

  @override
  String get resetDataUsage => 'Reset Data Usage';

  @override
  String get resetDataUsageContent =>
      'Are you sure you want to reset data usage? This does not affect downloaded music.';

  @override
  String get resetEverything => 'Reset Everything';

  @override
  String get resetLibraryContent =>
      'This will remove the current folder from the player. Your actual files will NOT be deleted.';

  @override
  String get resetLibraryPath => 'Reset Library Path';

  @override
  String get resetLibraryTitle => 'Reset Library?';

  @override
  String get resetPath => 'Reset Path';

  @override
  String get resetStatistics => 'Reset Statistics';

  @override
  String get resetStatsContent =>
      'This action cannot be undone.\nAll play counts and listening time will be lost forever.';

  @override
  String get resetStatsTitle => 'Reset Stats?';

  @override
  String get resetToAutomatic => 'RESET TO AUTOMATIC';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get resetUsage => 'Reset Usage';

  @override
  String get resetsIn => 'RESETS IN';

  @override
  String get restartContent =>
      'Changing the audio output device requires a restart application to take effect.\\n\\nWould you like to restart now?';

  @override
  String get restartNow => 'Restart Now';

  @override
  String get restartRequired => 'Restart Required';

  @override
  String get restoring => 'RESTORING';

  @override
  String get retryConnection => 'Retry Connection';

  @override
  String get revert => 'Revert';

  @override
  String get russian => 'Russian';

  @override
  String get sakura => 'Sakura';

  @override
  String get sampleRateLabel => 'Sample Rate';

  @override
  String get samplingRateLabel => 'Sampling Rate';

  @override
  String get save => 'Save';

  @override
  String get saveAsNewPreset => 'Save as New Preset';

  @override
  String get saveChangesToFile => 'Save Changes to File';

  @override
  String get saveLabel => 'Save';

  @override
  String get saveLrcPrompt => 'Save current lyrics next to the audio file?';

  @override
  String get saveLyricsTooltip => 'Save Lyrics';

  @override
  String get savePlaylistContent =>
      'This will create a new playlist with these songs.';

  @override
  String savePlaylistTitle(String title) {
    return 'Save $title?';
  }

  @override
  String get savePreset => 'Save Preset';

  @override
  String savedAs(String name) {
    return 'Saved as \"$name\"!';
  }

  @override
  String savedAsFormat(String format) {
    return 'Saved as $format';
  }

  @override
  String savedTo(String path) {
    return 'Saved to \"$path\"';
  }

  @override
  String get saving => 'Saving...';

  @override
  String get scan => 'Scan';

  @override
  String get scanToControlPlayback =>
      'Scan with your phone to control playback.';

  @override
  String get scanning => 'Scanning...';

  @override
  String get scrollForLyrics => 'Scroll for lyrics';

  @override
  String get search => 'Search';

  @override
  String get searchEngine => 'Search Engine';

  @override
  String searchFailedStatus(String error) {
    return 'Search failed: $error';
  }

  @override
  String get searchHint => 'Search...';

  @override
  String get searchSongs => 'Search songs...';

  @override
  String get searchSongsOrAlbumsAndArtistsHint =>
      'Search Songs, Albums or Artists...';

  @override
  String get searchSpotify => 'Search Spotify';

  @override
  String get searchSpotifyHint => 'Search Spotify...';

  @override
  String get searchUsers => 'Search users...';

  @override
  String get searchYoutubeHint => 'Search YouTube...';

  @override
  String get searching => 'Searching...';

  @override
  String searchingEngine(String engine, String keyword) {
    return 'Searching $engine for \'$keyword\'...';
  }

  @override
  String get searchingSpotify => 'Searching Spotify...';

  @override
  String searchingSpotifyFor(String keyword) {
    return 'Searching Spotify for \"$keyword\"...';
  }

  @override
  String get searchingStatus => 'SEARCHING';

  @override
  String get secondShort => 'Sec';

  @override
  String get secsShort => 'S';

  @override
  String get seeAll => 'See all';

  @override
  String get selectDifferentFolder => 'Select Different Folder';

  @override
  String get selectFolder => 'Select Folder';

  @override
  String get selectMatch => 'Select Match';

  @override
  String get selectSongToEdit => 'Select a song from the list to edit';

  @override
  String get selectStreamingQuality => 'Select streaming quality';

  @override
  String get selectTrackToStart => 'Select a track to start';

  @override
  String get selectVersion => 'Select Version';

  @override
  String session(String id) {
    return 'Session: $id';
  }

  @override
  String get setCountryReleases => 'Set country for new releases & charts';

  @override
  String get setCustomTimer => 'Set Custom Timer';

  @override
  String get settings => 'Settings';

  @override
  String get share => 'Share';

  @override
  String get shareCodeUsage =>
      'Give this 6-digit code to a friend for them to import this playlist.';

  @override
  String get sharePlaylist => 'Share Playlist';

  @override
  String sharePlaylistTitle(String name) {
    return 'Share \"$name\"';
  }

  @override
  String get sharedMode => 'Shared';

  @override
  String showAllTitles(int count) {
    return 'Show All $count Titles';
  }

  @override
  String get showAnimatedWaves => 'Show animated waves in player bar';

  @override
  String get showDebugButton => 'Show Floating Debug Button';

  @override
  String get showInFolder => 'Show in Folder';

  @override
  String get showLess => 'Show Less';

  @override
  String get showMore => 'Show More';

  @override
  String get showStatusDiscord => 'Show status on Discord';

  @override
  String get showUnlockedOnly => 'Show unlocked only';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get shuffleAll => 'Shuffle All';

  @override
  String shufflingArtist(String artistName) {
    return 'Shuffling $artistName...';
  }

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signalOutput => 'Signal Output';

  @override
  String get singleTracks => 'Single Tracks';

  @override
  String get sleepTimer => 'Sleep Timer';

  @override
  String get songAlreadyInPlaylist => 'Song Already in Playlist';

  @override
  String get songInformation => 'Song Information';

  @override
  String get songLabelUpper => 'SONG';

  @override
  String get songTitleKeyword => 'Song Title or Keyword';

  @override
  String get songs => 'Songs';

  @override
  String songsCount(int count) {
    return '$count songs';
  }

  @override
  String songsInLibrary(int count) {
    return '$count songs in library';
  }

  @override
  String songsLoadedCount(int count) {
    return '$count songs loaded...';
  }

  @override
  String get southKorea => 'South Korea';

  @override
  String get spanish => 'Spanish';

  @override
  String get spectrumBars => 'Spectrum Bars';

  @override
  String get spotify => 'Spotify';

  @override
  String get standardDesc => 'MP3 - Smaller files, faster buffering';

  @override
  String get standardQuality => 'Standard (MP3)';

  @override
  String get start => 'Start';

  @override
  String get startBulkProcess => 'Start Bulk Process';

  @override
  String get startedDownloadingAll => 'Started downloading all songs...';

  @override
  String get stateDisabled => 'Disabled';

  @override
  String get stateEnabled => 'Enabled';

  @override
  String get statisticsReset => 'Statistics have been reset.';

  @override
  String get stats => 'Stats';

  @override
  String get statusLabel => 'Status';

  @override
  String statusWithText(String status) {
    return 'Status: $status';
  }

  @override
  String stopTimer(String time) {
    return 'Stop Timer ($time)';
  }

  @override
  String get streaming => 'Streaming';

  @override
  String get streamingQuality => 'Streaming Quality';

  @override
  String get success => 'Success';

  @override
  String get superfanHeader => 'SUPERFAN ACHIEVEMENTS';

  @override
  String get superfanTitles => 'SUPERFAN';

  @override
  String get supportDeveloperTooltip =>
      'Support developer to obtain exclusive title';

  @override
  String get switchToGridView => 'Switch to Grid View';

  @override
  String get switchToListView => 'Switch to List View';

  @override
  String switchingTo(String title) {
    return 'Switching to: $title';
  }

  @override
  String get syncThemeAlbumArt => 'Sync Theme with Album Art';

  @override
  String get system => 'System';

  @override
  String get systemDefault => 'System Default';

  @override
  String get targetLanguageLyrics => 'Target language for lyrics translation';

  @override
  String get thai => 'Thai';

  @override
  String get tidalApiStatus => 'Tidal API';

  @override
  String get timeBasedTitles => 'TIME-BASED';

  @override
  String get timeListened => 'Time Listened';

  @override
  String get timeOverlordsHeader => 'TIME OVERLORDS';

  @override
  String timerSetForHours(int count) {
    return 'Timer set for $count hours';
  }

  @override
  String timerSetForMinutes(int count) {
    return 'Timer set for $count minutes';
  }

  @override
  String timerSetForSeconds(int count) {
    return 'Timer set for $count seconds';
  }

  @override
  String get tintBackground => 'Tint background and visualizer with song color';

  @override
  String get title => 'Title';

  @override
  String get titleLabel => 'Title';

  @override
  String todayLabel(String size) {
    return 'Today: $size';
  }

  @override
  String get toggleDebugButton =>
      'Toggle visibility of the floating debug console';

  @override
  String get toggleDebugConsole =>
      'Toggle visibility of the floating debug console';

  @override
  String get toggleLyrics => 'Toggle Lyrics';

  @override
  String top3GlobalTooltip(int weeks) {
    return 'Reach Top 3 Global for $weeks week(s)';
  }

  @override
  String get topArtist => 'Top Artist';

  @override
  String get topArtistAndTrack => 'Top Artist and Track';

  @override
  String get topArtists => 'Top Artists';

  @override
  String topGlobalTooltip(int rank) {
    return 'Reach top $rank global to obtain';
  }

  @override
  String get topListeners => 'Top Listeners';

  @override
  String get totalMinutesStat => 'Total Minutes';

  @override
  String get totalPlays => 'Total Plays';

  @override
  String get trackDetails => 'Track Details';

  @override
  String get trackNumber => 'Track #';

  @override
  String get tracks => 'Tracks';

  @override
  String get translateLabel => 'Translate';

  @override
  String get translateLyrics => 'Translate Lyrics';

  @override
  String get translateLyricsTooltip => 'Translate Lyrics';

  @override
  String get translationLanguage => 'Translation Language';

  @override
  String get turnOffTimer => 'Turn Off Timer';

  @override
  String get unauthorize => 'Unauthorize';

  @override
  String get underDevelopment => 'This feature is under development';

  @override
  String get underwater => 'Underwater';

  @override
  String get unitedKingdom => 'United Kingdom';

  @override
  String get unitedStates => 'United States';

  @override
  String get unknown => 'Unknown';

  @override
  String get unknownArtist => 'Unknown Artist';

  @override
  String get unknownDevice => 'Unknown Device';

  @override
  String get unlink => 'Unlink';

  @override
  String get unlinkAccount => 'Unlink Account';

  @override
  String get unlinkAccountDesc =>
      'Your stats will remain on this device but will no longer sync across devices.';

  @override
  String get unlinkAccountQuestion => 'Unlink Account?';

  @override
  String get unlinkFolder => 'Unlink folder and clear song list';

  @override
  String get unlinkFolderClear => 'Unlink folder and clear song list';

  @override
  String unlockedCountLabel(int unlocked, int total) {
    return '$unlocked / $total Unlocked';
  }

  @override
  String get unmuteTooltip => 'Unmute';

  @override
  String get unsavedChanges => 'You have unsaved changes';

  @override
  String get upNext => 'UP NEXT';

  @override
  String upNextCount(int count) {
    return 'UP NEXT ($count)';
  }

  @override
  String get upNextSection => 'UP NEXT';

  @override
  String get updateAvailableTitle => 'Update Available';

  @override
  String updateAvailableVersion(String version) {
    return 'A new version ($version) is available.';
  }

  @override
  String updateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get updateNow => 'Update Now';

  @override
  String get updatePrompt => 'Do you want to download and install it now?';

  @override
  String get updatingYtDlp => 'Updating yt-dlp';

  @override
  String get usbAudioBypass =>
      'USB Audio Bypass (Beta) - Direct DAC output for Android 13 and below';

  @override
  String get usbAudioBypassBeta =>
      'USB Audio Bypass (Beta) - Direct DAC output for Android 13 and below';

  @override
  String get useDarkTheme => 'Use dark theme';

  @override
  String get useMixedColors => 'Use mixed colors (Overrides sync)';

  @override
  String get verifiedDeveloper => 'Verified Developer';

  @override
  String get version => 'Version';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get vietnamese => 'Vietnamese';

  @override
  String get viewQueue => 'View Queue';

  @override
  String get visualizer => 'Visualizer';

  @override
  String get visualizerStyle => 'Visualizer Style';

  @override
  String get wasapiExclusive => 'WASAPI Exclusive Mode';

  @override
  String get weekly => 'Weekly';

  @override
  String get weeks => 'Weeks';

  @override
  String get winter => 'Winter';

  @override
  String get worldRanking => 'World Ranking';

  @override
  String get worldTopArtists => 'World Top Artists';

  @override
  String get year => 'Year';

  @override
  String get youMayLike => 'You May Like';

  @override
  String get yourPlaylists => 'Your Playlists';

  @override
  String get yourTopMix => 'Your Top Mix';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytDlpUpdateAvailable => 'A new version of yt-dlp is available.';

  @override
  String get importFromM3u => 'Import from M3U';

  @override
  String get importFromM3uSubtitle => 'Import an M3U playlist file';

  @override
  String get exportToM3u => 'Export to M3U';

  @override
  String get invalidM3uFile => 'Invalid M3U File';

  @override
  String get generateAiLyrics => 'Generate AI Lyrics';

  @override
  String get aiLyricsGenerating => 'Generating AI Lyrics...';

  @override
  String get aiLyricsFailed => 'Failed to generate AI lyrics.';

  @override
  String get aiLyricsError => 'Error generating AI lyrics.';

  @override
  String get offlineModeHeader => 'OFFLINE MODE';

  @override
  String get offlineModeTitle => 'Offline Mode';

  @override
  String get offlineModeActive => 'ACTIVE';

  @override
  String get offlineModeEnabledStatus => 'Offline Mode Enabled';

  @override
  String offlineModeDisabledStatus(int count) {
    return 'Disabled ($count)';
  }

  @override
  String get offlineModeAllEnabledStatus => 'All Enabled';

  @override
  String get offlineModeLockdownDesc =>
      'Network lockdown active. Stats are saved locally.';

  @override
  String get offlineModeMainDesc =>
      'Disable all network services and play local library only.';

  @override
  String get enableOfflineModeQuestion => 'Enable Offline Mode?';

  @override
  String get offlineModeConfirmationDesc =>
      'This will completely disable all network communication. The following features will be turned off:';

  @override
  String get offlineModeSyncRestoreNote =>
      'Your stats will sync automatically when you turn this off.';

  @override
  String get enableOfflineModeBtn => 'Enable Offline Mode';

  @override
  String get onlineModeRestored => 'Online mode restored. Syncing stats...';

  @override
  String get disableServicesTitle => 'Disable Services';

  @override
  String get manageIndividualFeatures => 'Manage individual online features';

  @override
  String get featureCloudSync => 'Cloud Stats Sync';

  @override
  String get featureCloudSyncDesc => 'Listening stats saved locally only';

  @override
  String get featureCloudSyncLongDesc =>
      'Sync listening metrics with PocketBase';

  @override
  String get featureLeaderboard => 'Global Leaderboard';

  @override
  String get featureLeaderboardDesc => 'Rank updates paused';

  @override
  String get featureLeaderboardLongDesc => 'Show and update your rank publicly';

  @override
  String get featureOnlineLyrics => 'Online Lyrics Search';

  @override
  String get featureOnlineLyricsDesc => 'Only local .lrc/.ttml files';

  @override
  String get featureOnlineLyricsLongDesc => 'Fetch lyrics from LRCLIB/Spotify';

  @override
  String get featureAiLyrics => 'AI Lyrics Generator';

  @override
  String get featureAiLyricsDesc => 'Automatic synchronized lyrics disabled';

  @override
  String get featureAiLyricsLongDesc => 'Generate synchronized lyrics via AI';

  @override
  String get featureSpotifyCanvas => 'Spotify Canvas';

  @override
  String get featureSpotifyCanvasDesc => 'Background videos disabled';

  @override
  String get featureSpotifyCanvasLongDesc => 'Background videos for tracks';

  @override
  String get featureOnlineSearch => 'Online Search';

  @override
  String get featureOnlineSearchDesc => 'Spotify/YouTube search disabled';

  @override
  String get featureOnlineSearchLongDesc => 'Spotify and YouTube remote search';

  @override
  String get featureConnectDevice => 'Connect to a Device';

  @override
  String get featureConnectDeviceDesc =>
      'Remote control & Listening parties disabled';

  @override
  String get featureConnectDeviceLongDesc =>
      'Remote control and listening parties';

  @override
  String get lyricsEditorTitle => 'Lyrics Editor';

  @override
  String get clearAllQuestion => 'Clear All?';

  @override
  String get clearAllDesc =>
      'This will clear the current editor state. It will NOT delete your local files unless you Save afterwards.';

  @override
  String get clearBtn => 'Clear';

  @override
  String get lyricsApplied => 'Lyrics applied to panel!';

  @override
  String get chooseFormat => 'Choose your preferred format:';

  @override
  String get lrcFormat => 'LRC (Standard Synced)';

  @override
  String get lrcFormatDesc => 'Universal format, works everywhere.';

  @override
  String get ttmlFormat => 'TTML (High Precision)';

  @override
  String get ttmlFormatDesc => 'Better for AI generation & detailed sync.';

  @override
  String savedSuccessfully(String extension) {
    return 'Saved to $extension file successfully!';
  }

  @override
  String get failedToSave => 'Failed to save lyrics file.';

  @override
  String get generationFailed => 'Generation Failed';

  @override
  String get aiLyricsGenerationTitle => 'AI Lyrics Generation';

  @override
  String get syncedMode => 'Synced';

  @override
  String get plainMode => 'Plain';

  @override
  String get addLineToTop => 'Add to Top';

  @override
  String get addLineToEnd => 'Add to End';

  @override
  String get lyricTextHint => 'Lyric text...';

  @override
  String get insertAfter => 'Insert After';

  @override
  String get removeLine => 'Remove Line';

  @override
  String get romajiHint => 'Romaji / Transliteration (Optional)...';

  @override
  String get startLabel => 'Start: ';

  @override
  String get setStartTooltip => 'Set Start to Current Position';

  @override
  String get endLabel => 'End: ';

  @override
  String get setEndTooltip => 'Set End to Current Position';

  @override
  String get playFromLine => 'Play from this line';

  @override
  String get pasteLyricsHint => 'Paste your lyrics here...';

  @override
  String get applyBtn => 'Apply';

  @override
  String get saveLocallyBtn => 'Save Locally';

  @override
  String get editLyricsTooltip => 'Edit Lyrics';

  @override
  String get saveLyricsTitle => 'Save Lyrics';

  @override
  String get aiGenerate => 'AI Generate';

  @override
  String get aiLyricsInitializing => 'Initializing...';

  @override
  String get aiLyricsUploading => 'Uploading song to server...';

  @override
  String get aiLyricsUploadFailed => 'Error: Upload failed.';

  @override
  String get aiLyricsUploadSuccess => 'Upload completed!';

  @override
  String get aiLyricsVerifying => 'Verify status server...';

  @override
  String get aiLyricsStatusOk => 'Status code 200 OK!';

  @override
  String get aiLyricsPolling => 'Getting Lyrics... Please be patient!';

  @override
  String get aiLyricsReceiving => 'Lyrics Received';

  @override
  String get aiLyricsParsing => 'Parsing Lyrics...';

  @override
  String get aiLyricsSuccess => 'Lyrics generated successful!';

  @override
  String get aiLyricsLocalFileMissing => 'Error: Local audio file not found.';

  @override
  String get aiLyricsComplete => 'Complete!';
}
