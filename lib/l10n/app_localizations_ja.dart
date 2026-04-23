// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get aboutEducationalPurpose => 'このアプリケーションは、個人および教育目的のみに開発されています。';

  @override
  String get aboutLicenses => 'バージョン情報とライセンス';

  @override
  String get aboutNotForCommercial => '商用利用は不可。';

  @override
  String get accentColor => 'アクセントカラー';

  @override
  String get access => 'アクセス';

  @override
  String get accessCode => 'アクセスコード';

  @override
  String get accountDataMergeDesc =>
      '同期によりプロフィール名とアバターが更新されますが、現在のデバイスの聴取時間は正常にアカウントの合計に統合されます。';

  @override
  String get accountLinked => 'アカウント連携済み';

  @override
  String get accountLinkedSuccessfully => 'アカウントが正常にリンクされました！';

  @override
  String get achievementsUnlocked => 'アンロックされた実績';

  @override
  String get activeNoResampling => 'アクティブ（リサンプリング不要）';

  @override
  String get add => '追加';

  @override
  String get addFiles => 'ファイルを追加する';

  @override
  String get addFolder => 'フォルダを追加する';

  @override
  String get addFoldersScan => 'スキャンするフォルダを追加する';

  @override
  String get addToFavorite => 'お気に入りに追加する';

  @override
  String get addToPlaylist => 'プレイリストに追加する';

  @override
  String get addToQueue => 'キューに追加する';

  @override
  String addedFolder(Object folder) {
    return 'フォルダを追加しました: $folder';
  }

  @override
  String get addedToLikedSongs => 'お気に入りの曲に追加しました';

  @override
  String get addedToPlaylistSuccess => 'プレイリストに追加しました';

  @override
  String get addedToQueue => 'キューに追加しました';

  @override
  String get album => 'アルバム';

  @override
  String get albumAddedToPlaylists => 'アルバムをプレイリストに追加しました';

  @override
  String get albumLabel => 'アルバム';

  @override
  String get albumRemovedFromPlaylists => 'アルバムをプレイリストから削除しました';

  @override
  String get albums => 'アルバム';

  @override
  String get allDownloadsRemoved => 'すべてのダウンロードを削除しました';

  @override
  String get allRightsReserved => '著作権所有。';

  @override
  String get allTime => '全期間';

  @override
  String get alreadyInLikedSongs => '既にお気に入りの曲にあります';

  @override
  String get android14BitPerfect => 'Android 14+ ビットパーフェクト';

  @override
  String get androidAudioEffectsNote => '備考: オーディオエフェクトはAndroidデバイスのみ有効です。';

  @override
  String get androidAudioTrack => 'Android AudioTrack';

  @override
  String get androidBitPerfect => 'Android 14+ ビットパーフェクト';

  @override
  String get androidMixer => 'Androidミキサー';

  @override
  String get appearance => '外観';

  @override
  String get applyOnRestart => '変更は次回の再起動時に適用されます。';

  @override
  String get arabic => 'アラビア語';

  @override
  String get artist => 'アーティスト';

  @override
  String get artistLabel => 'アーティスト';

  @override
  String get artists => 'アーティスト';

  @override
  String get atmospheres => 'アトモスフィア';

  @override
  String get audioFormat => 'オーディオ形式';

  @override
  String get audioOutput => 'オーディオ出力';

  @override
  String get audioOutputDevice => 'オーディオ出力デバイス';

  @override
  String get audioQuality => 'オーディオ品質';

  @override
  String get audioSource => 'オーディオソース';

  @override
  String get audiophileDAC => 'オーディオフィルDACでの再生時に有効にする（再起動が必要）';

  @override
  String get autoAddSimilar => 'キューが空に近づいたときに似た曲を自動追加する';

  @override
  String get autoClearAfter24h => '24時間後';

  @override
  String get autoClearAfter7d => '7日後';

  @override
  String get autoClearCache => 'キャッシュの自動クリア';

  @override
  String get autoClearDisabled => '無効';

  @override
  String get autoClearEvery30m => '30分ごと（再生中のみ）';

  @override
  String get autoClearOnClose => 'アプリ終了時';

  @override
  String get autoFixComingSoon => '自動修正（近日公開）';

  @override
  String get autoRestartNotSupported => '自動再起動はサポートされていません。手動で再起動してください。';

  @override
  String autoTagContent(int count, String sourceName) {
    return 'Spotifyで「$sourceName」の全$count曲を検索し、タグを自動的に上書きします。\\n\\nこの操作は取り消せません。';
  }

  @override
  String autoTagTitle(String sourceName) {
    return '⚠️ $sourceName を自動タグ付けしますか？';
  }

  @override
  String get automatic => '自動';

  @override
  String automaticTitleLabel(String title) {
    return '自動: $title';
  }

  @override
  String get autumn => '秋';

  @override
  String get avatarPickerDesc => 'テンプレートを選択するか、自分の写真をインポートします';

  @override
  String get beFirstToClaim => '1位を誰よりも早く獲得しましょう！';

  @override
  String get behavioralHeader => '行動実績';

  @override
  String get behavioralTitles => '行動ベース';

  @override
  String get binariesUpdateRequired => 'バイナリの更新が必要です';

  @override
  String get bitDepthLabel => 'ビット深度';

  @override
  String get bitPerfectEnabled => 'ビットパーフェクトモードが有効です。音量調節が無効になる場合があります。';

  @override
  String get bitPerfectWindows => '自動サンプルレートによるビットパーフェクトオーディオ（再起動が必要）';

  @override
  String get bitrateLabel => 'ビットレート';

  @override
  String get bitsLabel => 'ビット';

  @override
  String get brazil => 'ブラジル';

  @override
  String get browse => '見つける';

  @override
  String get bypassSystemMixer => 'USB DACのためにシステムミキサーをバイパスする';

  @override
  String get bypassedBitPerfect => 'バイパス（ビットパーフェクト）';

  @override
  String get cacheCleared => 'キャッシュを正常にクリアしました！';

  @override
  String get cached => 'キャッシュ済み';

  @override
  String get cancel => 'キャンセル';

  @override
  String get championChampionTooltip => '5週間にわたって世界トップ1に到達';

  @override
  String get change => '変更';

  @override
  String get changeFolder => 'フォルダを変更する';

  @override
  String get changeFormatInSettings => '設定で出力形式を変更してください';

  @override
  String get changeLabel => '変更';

  @override
  String get changeLanguage => 'アプリの言語を変更する';

  @override
  String get changesApplyRestart => '変更は次回の再起動時に適用されます。';

  @override
  String get changingAudioDeviceRestart =>
      'オーディオ出力デバイスの変更を適用するには、アプリの再起動が必要です。\\n\\n今すぐ再起動しますか？';

  @override
  String get channelsLabel => 'チャンネル';

  @override
  String get checkAgain => 'もう一度確認';

  @override
  String get checkInternetConnection => 'インターネット接続を確認してください';

  @override
  String get checkNetworkTryAgain => 'ネットワークを確認してやり直してください';

  @override
  String get chinese => '中国語';

  @override
  String get chooseAccentColor => 'お好みの静的な色を選択してください';

  @override
  String get chooseAnimationType => 'アニメーションタイプを選択してください';

  @override
  String get chooseArtist => 'アーティストを選択';

  @override
  String get chooseAvatar => 'アバターを選択';

  @override
  String get chooseYourTitle => '称号を選択';

  @override
  String get circularPulse => 'サーキュラーパルス';

  @override
  String get clearAll => 'すべて消去';

  @override
  String get clearHistory => '履歴をクリアする';

  @override
  String get clearImported => 'インポート内容をクリアする';

  @override
  String get clearMetadataCache => 'メタデータとアートのキャッシュをクリア';

  @override
  String get clearPlayHistory => '再生履歴と聴取時間をクリアする';

  @override
  String get clearStreamingCache => 'ストリーミングキャッシュをクリアする';

  @override
  String get close => '閉じる';

  @override
  String get cloud => 'クラウド';

  @override
  String get codeCopied => 'コードがクリップボードにコピーされました！';

  @override
  String get codeMust6Digits => 'コードは6桁である必要があります';

  @override
  String get codecLabel => 'コーデック';

  @override
  String get comingSoon => '近日公開';

  @override
  String get community => 'コミュニティ';

  @override
  String get competitiveTitles => '競争的';

  @override
  String get confirm => '確認';

  @override
  String get connect => '接続';

  @override
  String get connectToADevice => 'デバイスに接続';

  @override
  String get connected => '接続済み';

  @override
  String connectedToDac(String deviceName) {
    return '$deviceName に接続済み - USBバイパス有効';
  }

  @override
  String get connectedUsbDacs => '接続されたUSB DAC:';

  @override
  String get connecting => '接続中...';

  @override
  String get connectionLostLeaderboard => '接続が切れました';

  @override
  String get connectionLostLeaderboardDesc =>
      'グローバルリーダーボードでは、統計を同期して世界ランキングを取得するためにアクティブな接続が必要です。';

  @override
  String consecutivePlaysTooltip(int count) {
    return '同じ曲を $count 回連続で聴く';
  }

  @override
  String get contentRegion => 'コンテンツ地域';

  @override
  String get copyCode => 'コードをコピー';

  @override
  String get couldNotDownloadFlac => 'FLACをダウンロードできませんでした。';

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count曲',
      one: '1曲',
    );
    return '$_temp0';
  }

  @override
  String get createPlaylist => 'プレイリストを作成する';

  @override
  String creatingPlaylistWithTracks(int count) {
    return '$count 個のトラックでプレイリストを作成中...';
  }

  @override
  String get crossfade => 'クロスフェード';

  @override
  String crossfadeDesc(String seconds) {
    return 'トラック間をフェードさせる ($seconds 秒)';
  }

  @override
  String get crownedChampionTitlesHeader => '戴冠したチャンピオン称号';

  @override
  String get customDevice => 'カスタムデバイス';

  @override
  String get customSelected => 'カスタム選択';

  @override
  String get customTime => 'カスタム時間';

  @override
  String get cyberpunk => 'サイバーパンク';

  @override
  String get daily => '日刊';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get dataCleanup => 'データとクリーンアップ';

  @override
  String get dataUsage => 'データ使用量';

  @override
  String get daysShort => '日';

  @override
  String get debugging => 'デバッグ';

  @override
  String get delete => '削除';

  @override
  String get deleteDownloadsConfirm =>
      'これにより、このプレイリストのためにダウンロードされたすべての曲がデバイスから削除されます。';

  @override
  String get deleteDownloadsTitle => 'ダウンロードを削除しますか？';

  @override
  String deleteFileContent(String filename) {
    return '「$filename」を削除しますか？\\nこの操作は取り消せません。';
  }

  @override
  String get deleteFileTitle => 'ファイルを削除しますか？';

  @override
  String get deletePlaylist => 'プレイリストを削除';

  @override
  String deletePlaylistConfirm(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get deletePlaylistPermanentConfirm =>
      'このプレイリストを削除してもよろしいですか？（この操作は取り消せません）';

  @override
  String get deletePlaylistTitle => 'プレイリストを削除しますか？';

  @override
  String get deletePreset => 'プリセットを削除する';

  @override
  String get desertMirage => '砂漠の蜃気楼';

  @override
  String get developerExclusiveTooltip => 'このアプリの開発者専用';

  @override
  String deviceNameLabel(String deviceName) {
    return 'デバイス: $deviceName';
  }

  @override
  String get disableCanvas => 'Canvasを無効にする';

  @override
  String get disableRomanization => 'ローマ字表記を無効にする';

  @override
  String get disablingSharingWarning =>
      '共有を無効にすると、容量を節約するためにサーバーからコードとデータが永久に削除されます。';

  @override
  String get discNumber => 'ディスク番号';

  @override
  String get discography => 'ディスコグラフィ';

  @override
  String get discordRPC => 'Discord Rich Presence';

  @override
  String get doYouRemember => '覚えていますか？';

  @override
  String get donate => '寄付する';

  @override
  String get download => 'ダウンロード';

  @override
  String get downloadAll => 'すべてダウンロード';

  @override
  String get downloadComplete => 'ダウンロード完了';

  @override
  String get downloadCompleteNotification => 'ダウンロード完了';

  @override
  String get downloadError => 'ダウンロードエラー';

  @override
  String get downloadFailed => 'ダウンロード失敗';

  @override
  String get downloadLocation => 'ダウンロード場所';

  @override
  String get downloadPathReset => 'ダウンロードパスをデフォルトにリセットしました。';

  @override
  String downloadPathUpdated(Object path) {
    return 'ダウンロードパスを更新しました: $path';
  }

  @override
  String get downloadSong => '曲をダウンロードする';

  @override
  String get downloadStarted => 'ダウンロードを開始しました';

  @override
  String downloadedTo(String path) {
    return 'ダウンロード先: $path';
  }

  @override
  String get downloading => 'ダウンロード中';

  @override
  String get downloadingFlac => 'FLACをダウンロード中';

  @override
  String downloadingFormat(String format) {
    return '$format をダウンロード中';
  }

  @override
  String get downloadingUpdate => '更新をダウンロード中';

  @override
  String get downloads => 'ダウンロード';

  @override
  String get dspLabel => 'DSP';

  @override
  String get editMetadata => 'メタデータを編集';

  @override
  String get editNickname => 'ニックネームを編集';

  @override
  String get editor => 'エディタ';

  @override
  String get emptyMailbox => 'メールボックスを空にする';

  @override
  String get emptyMailboxDesc => 'これにより、すべてのメッセージが永久に削除されます。';

  @override
  String get emptyMailboxTitle => 'メールボックスを空にしますか？';

  @override
  String get emptyPlaylist => '空のプレイリスト';

  @override
  String get emptyPlaylistSubtitle => '新しく空のプレイリストを作成する';

  @override
  String get enableAlphabetIndexer => 'アルファベットスクロールインデクサーを有効にする';

  @override
  String get enableAlphabetIndexerSubtitle =>
      'モバイルのリストビューで A-Z サイドバーのインデックスを表示する';

  @override
  String get enableBarVisualizer => 'バービジュアライザーを有効にする';

  @override
  String get endlessQueue => 'エンドレスキュー';

  @override
  String get engineLabel => 'エンジン';

  @override
  String get english => '英語';

  @override
  String get enterAdminAccessCode => '管理者アクセスコードを入力してください';

  @override
  String get enterAdminCode => '管理者アクセスコードを入力してください';

  @override
  String get enterDuration => '時間を入力...';

  @override
  String get enterPresetName => 'プリセット名を入力してください (例: 私のバス)';

  @override
  String get enterShareCode => '6桁の共有コードを入力してください';

  @override
  String get eqLabel => 'EQ';

  @override
  String get equalizer => 'イコライザー';

  @override
  String get equipTitle => '称号を装備';

  @override
  String get equipped => '装備中';

  @override
  String get error => 'エラー';

  @override
  String get errorCouldNotCreateSession => 'エラー: セッションを作成できませんでした。';

  @override
  String errorDeleting(String error) {
    return '削除エラー: $error';
  }

  @override
  String get errorSearchingStream => 'ストリームの検索中にエラーが発生しました。';

  @override
  String get exclusiveMode => '排他';

  @override
  String get exclusiveModeWarning =>
      '警告: 排他モードは、システムデフォルトではなく、特定のデバイスを上記で選択した場合に最適に動作します。';

  @override
  String get exclusiveTitles => '限定';

  @override
  String get exclusiveTitlesHeader => '限定称号';

  @override
  String get exclusiveWarning =>
      '警告: 排他モードは、システムデフォルトではなく、特定のデバイスを上記で選択した場合に最適に動作します。';

  @override
  String get exitApp => '終了';

  @override
  String get expand => '拡大';

  @override
  String get externalFiles => '外部ファイル';

  @override
  String get fadingAtEnd => 'スリープタイマー: トラックの最後にフェードアウト中...';

  @override
  String get failedDisableSharing => '共有を無効にできませんでした。';

  @override
  String get failedEnableSharing => '共有を有効にできませんでした。接続を確認してください。';

  @override
  String get failedFetchPlaylistInfo => 'プレイリスト情報を取得できませんでした';

  @override
  String get failedToConnectDac => 'DACへの接続に失敗しました。USBの権限を確認してください。';

  @override
  String get failedToGenerateCode => '共有コードの生成に失敗しました。接続を確認してください。';

  @override
  String get failedToSetAvatar => 'アバターテンプレートの設定に失敗しました';

  @override
  String get failedToUpdateMetadata => 'メタデータの更新に失敗しました';

  @override
  String get favoriteTrack => 'お気に入りの曲';

  @override
  String get fetchingCanvas => 'Canvasを取得中...';

  @override
  String get fetchingLossless => 'ロスレスを取得中...';

  @override
  String get fetchingLosslessAudio => 'ロスレスオーディオを取得中...';

  @override
  String get fetchingMetadataSpotify => 'Spotifyからメタデータを取得中...';

  @override
  String get fetchingPlaylist => 'プレイリストを取得中...';

  @override
  String get fetchingPlaylistInfo => 'プレイリスト情報を取得中...';

  @override
  String get fetchingSharedPlaylist => '共有プレイリストを取得中...';

  @override
  String fetchingTracksFrom(String name) {
    return '\"$name\" からトラックを取得中...';
  }

  @override
  String get fileLocation => 'ファイルの場所';

  @override
  String get fileMissingHistory => 'ファイルが見つからず、履歴にもありません。';

  @override
  String get fileName => 'ファイル名';

  @override
  String get fileSizeLabel => 'ファイルサイズ';

  @override
  String get files => 'ファイル';

  @override
  String get filters => 'フィルター';

  @override
  String get findingBestMatchYoutube => 'YouTubeで最適な一致を検索中...';

  @override
  String get findingStream => 'ストリームソースを検索中...';

  @override
  String get finishUpdate => '更新を完了する';

  @override
  String get finishes => '順位';

  @override
  String get fixAll => 'すべて修正する';

  @override
  String get flacError => 'FLACエラー';

  @override
  String get flacNote =>
      '備考: FLACはシングルトラックのダウンロードのみ可能です。プレイリストの一括ダウンロードにはM4A形式が使用されます。';

  @override
  String get flacSavedToDownloads => 'FLACをダウンロードフォルダに保存しました';

  @override
  String get flacUnavailable => 'FLAC利用不可';

  @override
  String get flacUnavailableDesc =>
      'FLACが利用できないため、ダウンロードに失敗しました。設定を変更してみてください。';

  @override
  String get flacUnavailableNotification => 'FLAC利用不可';

  @override
  String get fluidWave => 'フルイドウェーブ';

  @override
  String folderPath(String path) {
    return 'フォルダ: $path';
  }

  @override
  String get folders => 'フォルダー';

  @override
  String get formatLabel => '形式';

  @override
  String get formatSaved => '形式を保存しました！';

  @override
  String foundExistingAccount(String name) {
    return '\'$name\' の既存のアカウントが見つかりました。';
  }

  @override
  String foundResults(int songCount, int albumCount, int artistCount) {
    return '$songCount曲、$albumCountアルバム、$artistCountアーティストが見つかりました。';
  }

  @override
  String foundYoutubeResults(int count) {
    return 'YouTubeで $count 件の結果が見つかりました';
  }

  @override
  String freeUpSpace(String size) {
    return '空き容量を増やす (現在: $size)';
  }

  @override
  String get french => 'フランス語';

  @override
  String fromLibraryCount(int count) {
    return 'ライブラリから ($count)';
  }

  @override
  String get fromLibrarySection => 'ライブラリから';

  @override
  String get fullScreenPlayerTooltip => '全画面プレイヤー';

  @override
  String get galacticSpace => 'ギャラクシースペース';

  @override
  String get gaplessPlayback => 'ギャップレス再生';

  @override
  String get gaplessPlaybackDesc => 'トラック間の無音を解消します';

  @override
  String get general => '一般';

  @override
  String get generatingShareCode => '共有コードを生成中...';

  @override
  String get genre => 'ジャンル';

  @override
  String get german => 'ドイツ語';

  @override
  String get globalLeaderboard => 'グローバルリーダーボード';

  @override
  String get globalMailbox => 'グローバルメールボックス';

  @override
  String get globalRank => 'グローバルランク';

  @override
  String get globalRankings => 'グローバルランキング';

  @override
  String get globalRankingsDesc => '毎日、毎週、そして歴代のトップリスナーを見てみよう！';

  @override
  String get goToArtist => 'アーティストへ移動';

  @override
  String get goToLocalLibraryToSelect => '「ローカルライブラリ」から音楽フォルダを選択してください。';

  @override
  String get goodAfternoon => 'こんにちは';

  @override
  String get goodEvening => 'こんばんは';

  @override
  String get goodMorning => 'おはようございます';

  @override
  String get googleAccount => 'Google アカウント';

  @override
  String get grantAccess => 'アクセスを許可する';

  @override
  String get grantPermission => '権限を許可する';

  @override
  String get hallOfFameHeader => '殿堂入り実績';

  @override
  String get hallOfFameTitles => '殿堂入り';

  @override
  String get hideCanvas => 'Spotify Canvasビデオを表示せず、代わりにアルバムアートを表示する';

  @override
  String get hideRomajiPinyin => '韓国語、日本語、中国語の歌詞の下にローマ字/ピンインを表示しない';

  @override
  String get hideTranslation => '翻訳を隠す';

  @override
  String get highDesc => 'M4A - 音質が良く、バランスが取れている';

  @override
  String get highQuality => '高音質 (M4A)';

  @override
  String get hindi => 'ヒンディー語';

  @override
  String get history => '履歴';

  @override
  String get historySection => '履歴';

  @override
  String get home => 'ホーム';

  @override
  String get hourShort => '時間';

  @override
  String hoursDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count時間',
      one: '1時間',
    );
    return '$_temp0';
  }

  @override
  String get hoursShort => '時';

  @override
  String get ignoreSubfolderScan => 'サブフォルダのスキャンを無視する';

  @override
  String get importAdditionalPaths => '追加パスのインポート';

  @override
  String get importChoice => 'インポート';

  @override
  String importFailed(String error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String get importFromGallery => 'ギャラリーからインポート';

  @override
  String get importFromSpotify => 'Spotifyからインポート';

  @override
  String get importFromSpotifySubtitle => 'SpotifyプレイリストのURLを貼り付け';

  @override
  String get importFromYoutubeMusic => 'YouTube Music からインポート';

  @override
  String get importFromYoutubeMusicSubtitle => 'YouTube Music のプレイリストのURLを貼り付け';

  @override
  String get importLabel => 'インポート';

  @override
  String get importLyricsFile => '歌詞ファイルをインポートする';

  @override
  String get importLyricsTooltip => '歌詞をインポート';

  @override
  String get importSpotifyPlaylist => 'Spotifyプレイリストをインポートする';

  @override
  String get importViaCode => 'コードでインポート';

  @override
  String get importViaCodeSubtitle => '友達が共有したプレイリストをインポートします';

  @override
  String get importYoutubeMusicPlaylist => 'YouTube Musicプレイリストをインポートする';

  @override
  String importedPlaylistName(String name) {
    return '\"$name\" を正常にインポートしました！';
  }

  @override
  String importedTracks(int count) {
    return '$count 個のトラックを正常にインポートしました！';
  }

  @override
  String get indonesia => 'インドネシア';

  @override
  String get indonesian => 'インドネシア語';

  @override
  String get inputLabel => '入力';

  @override
  String get installNow => '今すぐインストール';

  @override
  String get integration => '統合';

  @override
  String get invalidAccessCode => '無効なアクセスコードです';

  @override
  String get invalidCode => '無効なアクセスコードです';

  @override
  String get invalidSpotifyUrl => '無効なSpotifyプレイリストURL';

  @override
  String get invalidYoutubeMusicUrl => 'YouTube MusicプレイリストのURLが無効です';

  @override
  String get japan => '日本';

  @override
  String get japanese => '日本語';

  @override
  String get joinUs => 'コミュニティに参加する';

  @override
  String get jumpBackIn => 'また聴く';

  @override
  String get justEnjoyVibes => 'ただ音楽を楽しみましょう。';

  @override
  String get korean => '韓国語';

  @override
  String get language => '言語';

  @override
  String last30DaysLabel(String size) {
    return '過去 30 日間: $size';
  }

  @override
  String last7DaysLabel(String size) {
    return '過去 7 日間: $size';
  }

  @override
  String get later => '後で';

  @override
  String get library => 'ライブラリ';

  @override
  String get libraryData => 'ライブラリデータ';

  @override
  String get libraryNotLoaded => 'ライブラリが読み込まれていません。';

  @override
  String get libraryPathReset => 'ライブラリパスをリセットしました。';

  @override
  String get likedSongs => 'お気に入りの曲';

  @override
  String get linkAccount => 'アカウントを連携';

  @override
  String get linkAccountDesc => 'Googleで進捗状況を同期・復元する';

  @override
  String listenMinutesTooltip(String minutes) {
    return '$minutes 分間音楽を聴く';
  }

  @override
  String get listeningParty => 'リスニングパーティー';

  @override
  String get listeningStats => '聴取統計';

  @override
  String get loadingCanvas => 'Canvasを読み込み中...';

  @override
  String get loadingDevices => 'デバイスを読み込み中...';

  @override
  String get loadingError => '詳細の読み込みに失敗しました。もう一度お試しください。';

  @override
  String get loadingLyrics => '歌詞を読み込み中...';

  @override
  String get localPlayHistorySaved => 'ローカルの再生履歴は削除されません。';

  @override
  String get local_library => 'ローカルライブラリ';

  @override
  String get lockedAtmosphere => 'アトモスフィアが有効な間はロックされます';

  @override
  String get losslessDesc => 'FLAC - Deezer/Tidalからのロスレス品質';

  @override
  String get losslessNote =>
      '利用可能な場合、Deezer/TidalからロスレスFLACをストリーミングします。利用できない場合はM4Aにフォールバックします。';

  @override
  String get losslessQuality => 'ロスレス (自動)';

  @override
  String get lunarNewYear => '旧正月';

  @override
  String get lyricsByLRCLIB => 'Lyrics by LRCLIB';

  @override
  String get lyricsSaveError => '歌詞の保存に失敗しました';

  @override
  String get lyricsSavedSuccess => '歌詞を.lrcファイルとして保存しました';

  @override
  String get lyricsTooltip => '歌詞';

  @override
  String get madeForYou => 'あなたにおすすめ';

  @override
  String get manualSearch => '手動検索';

  @override
  String get mergeAccountData => 'アカウントデータを統合しますか？';

  @override
  String get metadataCacheCleared => 'メタデータキャッシュがクリアされ、ライブラリの再スキャンが開始されました';

  @override
  String get metadataEditorInfo => 'メタデータエディタで検索してすぐに修正できます。';

  @override
  String get metadataEditorNote =>
      '備考: 「正常に保存されました」というステータスの後、アルバムアートが変わることがあります。これは保存されていないわけではなく、アプリ内のキャッシュの問題であり、現在修正中です。ファイルマネージャー等で確認できます。';

  @override
  String get metadataUpdated => 'メタデータが更新されました';

  @override
  String get metadata_editor => 'メタデータエディタ';

  @override
  String get min => '分';

  @override
  String get minShortLabel => '分';

  @override
  String get miniPlayer => 'ミニプレイヤー';

  @override
  String get minimizeToTray => 'トレイに最小化';

  @override
  String get minimizeToTrayDescription => '終了する代わりにアプリをシステムトレイに閉じる';

  @override
  String get minsShort => '分';

  @override
  String get minsShortLabel => '分';

  @override
  String get minuteShort => '分';

  @override
  String get minutes => '分';

  @override
  String minutesDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count分',
      one: '1分',
    );
    return '$_temp0';
  }

  @override
  String get moreOptions => 'その他のオプション';

  @override
  String get moreOptionsTooltip => 'その他のオプション';

  @override
  String get mostListened => '最も聴いた曲';

  @override
  String get mostListenedArtist => '最も聴かれたアーティスト';

  @override
  String get musicFolderLocation => '音楽フォルダの場所';

  @override
  String get musicSearch => '音楽検索';

  @override
  String musicWillStopIn(String label) {
    return '$label 後に音楽を停止します';
  }

  @override
  String get muteTooltip => 'ミュート';

  @override
  String myTopTrackOn(String header) {
    return 'Simple Playerでの私の$header！ 🎵';
  }

  @override
  String get nativeRate => 'ネイティブレート';

  @override
  String get navigation => 'ナビゲーション';

  @override
  String get newPlaylist => '新しいプレイリスト';

  @override
  String get nextTrack => '次のトラック';

  @override
  String get nicknameHint => 'ニックネームを入力';

  @override
  String get nicknameLabel => 'ニックネーム';

  @override
  String get nicknameRequired => 'ニックネームが必要です';

  @override
  String get nicknameRequiredDesc =>
      'グローバルリーダーボードを表示するには、まずカスタムニックネームを設定する必要があります！';

  @override
  String get nicknameTakenDesc => 'このニックネームはすでに世界中で使用されています。別のものを選択してください。';

  @override
  String get nicknameTakenTitle => 'ニックネームがすでに使われています';

  @override
  String get noAlbumsFound => 'アルバムが見つかりません';

  @override
  String get noArtistStatsYet => 'アーティスト統計がまだありません。';

  @override
  String get noArtistsFound => 'アーティストが見つかりません。';

  @override
  String get noDownloadsFound => 'ダウンロードが見つかりません';

  @override
  String get noFolderSelected => 'フォルダが選択されていません';

  @override
  String get noHistoryYet => '履歴がまだありません';

  @override
  String get noInternetConnection => 'インターネット接続がありません';

  @override
  String get noLyricsAvailable => '歌詞がありません';

  @override
  String get noMessages => 'メールボックスにメッセージはありません';

  @override
  String get noMusicPlaying => '音楽を再生していません';

  @override
  String get noPlaylistsFound => 'プレイリストが見つかりません';

  @override
  String get noPlaylistsYet => 'プレイリストがまだありません';

  @override
  String get noRankingsYet => 'この期間のランキングはまだありません。';

  @override
  String get noResultsFound => '結果が見つかりません';

  @override
  String get noSongPlaying => '再生中の曲はありません';

  @override
  String get noSongsAdded => '曲がまだ追加されていません';

  @override
  String get noSongsInFolder => 'このフォルダに曲は見つかりませんでした。';

  @override
  String get noSpotifyResults => 'Spotifyの結果が見つかりませんでした。';

  @override
  String get noStatsYet => '統計がまだありません。';

  @override
  String get noStreamMatch => '一致するストリームが見つかりませんでした。';

  @override
  String get noSuggestionsFound => '提案が見つかりませんでした。';

  @override
  String get noSyncedLyricsFound => '同期された歌詞が見つかりません';

  @override
  String get noTracksFound => 'プレイリストにトラックが見つかりませんでした';

  @override
  String get noUsbDacDetected =>
      'USB DACが検出されませんでした。USBオーディオデバイスを接続して「スキャン」をタップしてください。';

  @override
  String get noUsersFound => 'ユーザーが見つかりません';

  @override
  String get noYoutubeResults => 'YouTubeで結果が見つかりませんでした';

  @override
  String get none => 'なし';

  @override
  String get nordicAurora => 'オーロラ';

  @override
  String notRank(int rank) {
    return 'ランク $rank 以外';
  }

  @override
  String get notRanked => 'ランク外';

  @override
  String get notRankedTop3 => 'トップ3圏外';

  @override
  String get nowPlaying => '再生中';

  @override
  String get nowPlayingHeader => '再生中';

  @override
  String get nowPlayingSection => '再生中';

  @override
  String get offline => 'オフライン';

  @override
  String get offlineStatus => 'オフライン';

  @override
  String get ok => 'OK';

  @override
  String get online => 'オンライン';

  @override
  String get onlyScanSelected => '選択したフォルダのみをスキャンする（デフォルト：オン）';

  @override
  String get opacity => '不透明度';

  @override
  String opacityLabel(int percent) {
    return '不透明度: $percent%';
  }

  @override
  String get openProfile => 'プロフィールを開く';

  @override
  String get openSourceLicenses => 'オープンソースライセンス';

  @override
  String get outputLabel => '出力';

  @override
  String get overwrite => '上書きする';

  @override
  String get overwriteLrcWarning => 'この曲には既にローカルの.lrcファイルがあります。\\n上書きしますか？';

  @override
  String get parsingPlaylistData => 'プレイリストデータを解析中...';

  @override
  String get pathLabel => 'パス';

  @override
  String get permissionRequired => '権限が必要です';

  @override
  String get permissionRequiredDesc =>
      'タグを編集するには、「全ファイルへのアクセス」権限が必要です。これにより、音楽ファイルを直接修正できるようになります。';

  @override
  String get play => '再生';

  @override
  String playCountLabel(int count) {
    return '$count 回再生';
  }

  @override
  String get playNext => '次に再生';

  @override
  String get playPause => '再生 / 一時停止';

  @override
  String get playQueue => '再生キュー';

  @override
  String get playback => '再生';

  @override
  String get playbackError => '再生エラー';

  @override
  String get player => 'プレイヤー';

  @override
  String get playingFromAlbum => 'アルバムから再生中';

  @override
  String get playingNext => '次に再生';

  @override
  String get playingTrack => 'トラックを再生中';

  @override
  String get playlistAlbumTracks => 'プレイリスト / アルバムトラック';

  @override
  String get playlistNameHint => 'プレイリスト名';

  @override
  String get playlistNotFound => 'プレイリストが見つかりません';

  @override
  String get playlistNotFoundOrError => 'プレイリストが見つからないか、サーバーエラーです';

  @override
  String get playlistReadyShare => 'プレイリストの共有が可能になりました！';

  @override
  String get playlists => 'プレイリスト';

  @override
  String get plays => '回再生';

  @override
  String get popularOnSpotify => 'Spotifyで人気';

  @override
  String get portuguese => 'ポルトガル語';

  @override
  String get preferredOutputFormat => 'ダウンロードの優先出力形式';

  @override
  String get preparingDownload => 'ダウンロードを準備中';

  @override
  String preparingDownloadFormat(String format) {
    return 'ダウンロードを準備中 ($format)...';
  }

  @override
  String get preparingDownloadNotification => 'ダウンロード準備中';

  @override
  String get presetSaved => 'プリセットを保存しました！';

  @override
  String get preview => 'プレビュー';

  @override
  String get previousTrack => '前のトラック';

  @override
  String get profileSettings => 'プロフィール設定';

  @override
  String get profileStats => 'プロフィール統計';

  @override
  String get progress => '進捗';

  @override
  String get publicSharing => '公開共有';

  @override
  String get publicSharingDesc => 'コードを知っている人なら誰でもこのプレイリストをインポートできます。';

  @override
  String get publicSharingDisabledDesc => '無効。他のユーザーと共有するには有効にしてください。';

  @override
  String get queueIsEmpty => 'キューが空です';

  @override
  String get queueTooltip => 'キュー';

  @override
  String get queueUpdated => 'キューを更新しました';

  @override
  String get quickMix => 'クイックミックス';

  @override
  String get rainbowMode => 'レインボーモード';

  @override
  String get rainyCity => '雨の街';

  @override
  String get rank => 'ランク';

  @override
  String rankActive(int rank) {
    return 'ランク $rank (有効)';
  }

  @override
  String rankLabel(int rank) {
    return 'ランク $rank';
  }

  @override
  String get reBuffering => '再バッファリング中...';

  @override
  String reachDailyPlaysTooltip(int count) {
    return '1日で $count 回再生に到達';
  }

  @override
  String reachSpecificArtistTooltip(String minutes) {
    return '特定のアーティストで $minutes 分に到達';
  }

  @override
  String reachWeeklyPlaysTooltip(int count) {
    return '1週間で $count 回再生に到達';
  }

  @override
  String get readySearchSong => '準備完了。曲を検索してください。';

  @override
  String get rebufferingFromCloud => 'クラウドから再バッファリング中...';

  @override
  String get recentlyPlayed => '最近再生した曲';

  @override
  String recommendationsCount(int count) {
    return 'レコメンド ($count)';
  }

  @override
  String get recommendationsSection => 'レコメンド';

  @override
  String get rediscover => '再発見する';

  @override
  String get refreshLabel => '更新';

  @override
  String get refreshLibrary => 'ライブラリを更新する';

  @override
  String get refreshList => 'リストを更新する';

  @override
  String get refreshLyricsTooltip => '歌詞を更新';

  @override
  String get removeAvatar => '現在のアバターを削除';

  @override
  String get removeFromPlaylist => 'プレイリストから削除する';

  @override
  String removedFolder(Object folder) {
    return 'フォルダを削除しました: $folder';
  }

  @override
  String get rename => '名前を変更する';

  @override
  String get renamePlaylist => 'プレイリストの名前を変更する';

  @override
  String get repeats => '繰り返し';

  @override
  String get requiresAndroid14 => 'Android 14以降とUSB DACが必要です';

  @override
  String get resamplingLabel => 'リサンプリング';

  @override
  String get reset => 'リセット';

  @override
  String get resetDataUsage => 'データ使用量をリセット';

  @override
  String get resetDataUsageContent =>
      'データ使用量をリセットしてもよろしいですか？ダウンロード済みの音楽には影響しません。';

  @override
  String get resetEverything => 'すべてリセットする';

  @override
  String get resetLibraryContent =>
      'これにより、プレイヤーから現在のフォルダが削除されます。実際のファイルは削除されません。';

  @override
  String get resetLibraryPath => 'ライブラリパスをリセットする';

  @override
  String get resetLibraryTitle => 'ライブラリをリセットしますか？';

  @override
  String get resetPath => 'パスをリセットする';

  @override
  String get resetStatistics => '統計をリセットする';

  @override
  String get resetStatsContent => 'この操作は取り消せません。\\nすべての再生回数と聴取時間が永久に失われます。';

  @override
  String get resetStatsTitle => '統計をリセットしますか？';

  @override
  String get resetToAutomatic => '自動にリセット';

  @override
  String get resetToDefault => 'デフォルトに戻す';

  @override
  String get resetUsage => '使用量をリセット';

  @override
  String get resetsIn => 'リセットまで';

  @override
  String get restartContent =>
      'オーディオ出力デバイスの変更を適用するには、アプリの再起動が必要です。\\n\\n今すぐ再起動しますか？';

  @override
  String get restartNow => '今すぐ再起動';

  @override
  String get restartRequired => '再起動が必要';

  @override
  String get restoring => '復元中';

  @override
  String get retryConnection => '接続を再試行';

  @override
  String get revert => '元に戻す';

  @override
  String get russian => 'ロシア語';

  @override
  String get sakura => '桜';

  @override
  String get sampleRateLabel => 'サンプルレート';

  @override
  String get samplingRateLabel => 'サンプリングレート';

  @override
  String get save => '保存';

  @override
  String get saveAsNewPreset => '新しいプリセットとして保存する';

  @override
  String get saveChangesToFile => '変更をファイルに保存する';

  @override
  String get saveLabel => '保存';

  @override
  String get saveLrcPrompt => '現在の歌詞をオーディオファイルの隣に保存しますか？';

  @override
  String get saveLyricsTooltip => '歌詞を保存';

  @override
  String get savePlaylistContent => 'これらの曲で新しいプレイリストを作成します。';

  @override
  String savePlaylistTitle(String title) {
    return '「$title」を保存しますか？';
  }

  @override
  String get savePreset => 'プリセットを保存する';

  @override
  String savedAs(String name) {
    return '「$name」として保存しました！';
  }

  @override
  String savedAsFormat(String format) {
    return '$format として保存しました';
  }

  @override
  String savedTo(String path) {
    return '「$path」に保存しました';
  }

  @override
  String get saving => '保存中...';

  @override
  String get scan => 'スキャン';

  @override
  String get scanToControlPlayback => 'スマートフォンでスキャンして再生をコントロールします。';

  @override
  String get scanning => 'スキャン中...';

  @override
  String get scrollForLyrics => 'スクロールして歌詞を表示';

  @override
  String get search => '検索';

  @override
  String get searchEngine => '検索エンジン';

  @override
  String searchFailedStatus(String error) {
    return '検索失敗: $error';
  }

  @override
  String get searchHint => '検索...';

  @override
  String get searchSongs => '曲を検索...';

  @override
  String get searchSongsOrAlbumsAndArtistsHint => '曲、アルバム、またはアーティストを検索...';

  @override
  String get searchSpotify => 'Spotifyを検索';

  @override
  String get searchSpotifyHint => 'Spotifyを検索...';

  @override
  String get searchUsers => 'ユーザーを検索...';

  @override
  String get searchYoutubeHint => 'YouTubeを検索...';

  @override
  String get searching => '検索中...';

  @override
  String searchingEngine(String engine, String keyword) {
    return '$engineで「$keyword」を検索中...';
  }

  @override
  String get searchingSpotify => 'Spotifyを検索中...';

  @override
  String searchingSpotifyFor(String keyword) {
    return 'Spotifyで「$keyword」を検索中...';
  }

  @override
  String get searchingStatus => '検索中';

  @override
  String get secondShort => '秒';

  @override
  String get secsShort => '秒';

  @override
  String get seeAll => 'すべて表示';

  @override
  String get selectDifferentFolder => '別のフォルダを選択する';

  @override
  String get selectFolder => 'フォルダを選択する';

  @override
  String get selectMatch => '一致するものを選択';

  @override
  String get selectSongToEdit => 'リストから編集する曲を選択してください';

  @override
  String get selectStreamingQuality => 'ストリーミング音質を選択してください';

  @override
  String get selectTrackToStart => '再生するトラックを選択してください';

  @override
  String get selectVersion => 'バージョンを選択';

  @override
  String session(String id) {
    return 'セッション: $id';
  }

  @override
  String get setCountryReleases => '新譜とチャートの国を設定する';

  @override
  String get setCustomTimer => 'カスタムタイマーを設定する';

  @override
  String get settings => '設定';

  @override
  String get share => '共有する';

  @override
  String get shareCodeUsage => 'この6桁のコードを友達に教えて、プレイリストをインポートしてもらいます。';

  @override
  String get sharePlaylist => 'プレイリストを共有';

  @override
  String sharePlaylistTitle(String name) {
    return '\"$name\" を共有';
  }

  @override
  String get sharedMode => '共有';

  @override
  String showAllTitles(int count) {
    return '全 $count 称号を表示';
  }

  @override
  String get showAnimatedWaves => 'プレイヤーバーにアニメーションウェーブを表示する';

  @override
  String get showDebugButton => 'フローティングデバッグボタンを表示する';

  @override
  String get showInFolder => 'フォルダに表示する';

  @override
  String get showLess => '少なく表示';

  @override
  String get showMore => 'もっと見る';

  @override
  String get showStatusDiscord => 'Discordにステータスを表示する';

  @override
  String get showUnlockedOnly => '解除済みのみ表示';

  @override
  String get shuffle => 'シャッフル';

  @override
  String get shuffleAll => 'すべてシャッフル';

  @override
  String shufflingArtist(String artistName) {
    return '$artistName をシャッフル中...';
  }

  @override
  String get signInWithGoogle => 'Googleでサインイン';

  @override
  String get signalOutput => '信号出力';

  @override
  String get singleTracks => 'シングルトラック';

  @override
  String get sleepTimer => 'スリープタイマー';

  @override
  String get songAlreadyInPlaylist => 'この曲は既にプレイリストにあります';

  @override
  String get songInformation => '曲の情報';

  @override
  String get songLabelUpper => '曲';

  @override
  String get songTitleKeyword => '曲名またはキーワード';

  @override
  String get songs => '曲';

  @override
  String songsCount(int count) {
    return '$count曲';
  }

  @override
  String songsInLibrary(int count) {
    return 'ライブラリ内の$count曲';
  }

  @override
  String songsLoadedCount(int count) {
    return '$count曲を読み込みました...';
  }

  @override
  String get southKorea => '韓国';

  @override
  String get spanish => 'スペイン語';

  @override
  String get spectrumBars => 'スペクトラムバー';

  @override
  String get spotify => 'Spotify';

  @override
  String get standardDesc => 'MP3 - ファイルサイズが小さく、バッファリングが速い';

  @override
  String get standardQuality => '標準 (MP3)';

  @override
  String get start => '開始';

  @override
  String get startBulkProcess => '一括処理を開始する';

  @override
  String get startedDownloadingAll => 'すべての曲のダウンロードを開始しました...';

  @override
  String get stateDisabled => '無効';

  @override
  String get stateEnabled => '有効';

  @override
  String get statisticsReset => '統計をリセットしました。';

  @override
  String get stats => '統計';

  @override
  String get statusLabel => 'ステータス';

  @override
  String statusWithText(String status) {
    return 'ステータス: $status';
  }

  @override
  String stopTimer(String time) {
    return 'タイマーを停止 ($time)';
  }

  @override
  String get streaming => 'ストリーミング';

  @override
  String get streamingQuality => 'ストリーミング音質';

  @override
  String get success => '成功';

  @override
  String get superfanHeader => 'スーパーファン実績';

  @override
  String get superfanTitles => 'スーパーファン';

  @override
  String get supportDeveloperTooltip => '開発者をサポートして限定称号を獲得';

  @override
  String get switchToGridView => 'グリッド表示に切り替える';

  @override
  String get switchToListView => 'リスト表示に切り替える';

  @override
  String switchingTo(String title) {
    return '切り替え中';
  }

  @override
  String get syncThemeAlbumArt => 'アルバムアートとテーマを同期する';

  @override
  String get system => 'システム';

  @override
  String get systemDefault => 'システムデフォルト';

  @override
  String get targetLanguageLyrics => '歌詞翻訳のターゲット言語';

  @override
  String get thai => 'タイ語';

  @override
  String get tidalApiStatus => 'Tidal API';

  @override
  String get timeBasedTitles => '時間ベース';

  @override
  String get timeListened => '聴取時間';

  @override
  String get timeOverlordsHeader => 'タイム・オーバーロード';

  @override
  String timerSetForHours(int count) {
    return '$count時間後にタイマーを設定しました';
  }

  @override
  String timerSetForMinutes(int count) {
    return '$count分後にタイマーを設定しました';
  }

  @override
  String timerSetForSeconds(int count) {
    return '$count秒後にタイマーを設定しました';
  }

  @override
  String get tintBackground => '曲の色で背景とビジュアライザーを染める';

  @override
  String get title => 'タイトル';

  @override
  String get titleLabel => 'タイトル';

  @override
  String todayLabel(String size) {
    return '今日: $size';
  }

  @override
  String get toggleDebugButton => 'フローティングデバッグコンソールの表示を切り替える';

  @override
  String get toggleDebugConsole => 'フローティングデバッグコンソールの表示を切り替える';

  @override
  String get toggleLyrics => '歌詞を切り替える';

  @override
  String top3GlobalTooltip(int weeks) {
    return '$weeks 週間にわたって世界トップ3に到達';
  }

  @override
  String get topArtist => 'トップアーティスト';

  @override
  String get topArtistAndTrack => 'トップアーティストと曲';

  @override
  String get topArtists => 'トップアーティスト';

  @override
  String topGlobalTooltip(int rank) {
    return '世界トップ $rank に到達';
  }

  @override
  String get topListeners => 'トップリスナー';

  @override
  String get totalMinutesStat => '合計時間（分）';

  @override
  String get totalPlays => '総再生回数';

  @override
  String get trackDetails => 'トラックの詳細';

  @override
  String get trackNumber => 'トラック番号';

  @override
  String get tracks => 'トラック';

  @override
  String get translateLabel => '翻訳';

  @override
  String get translateLyrics => '歌詞を翻訳する';

  @override
  String get translateLyricsTooltip => '歌詞を翻訳';

  @override
  String get translationLanguage => '翻訳言語';

  @override
  String get turnOffTimer => 'タイマーをオフにする';

  @override
  String get unauthorize => '未承認';

  @override
  String get underDevelopment => 'この機能は開発中です';

  @override
  String get underwater => '水中';

  @override
  String get unitedKingdom => 'イギリス';

  @override
  String get unitedStates => 'アメリカ合衆国';

  @override
  String get unknown => '不明';

  @override
  String get unknownArtist => '不明なアーティスト';

  @override
  String get unknownDevice => '不明なデバイス';

  @override
  String get unlink => '解除する';

  @override
  String get unlinkAccount => '連携を解除';

  @override
  String get unlinkAccountDesc => '統計データはこのデバイスに残りますが、他のデバイスとの同期は行われなくなります。';

  @override
  String get unlinkAccountQuestion => 'アカウントの連携を解除しますか？';

  @override
  String get unlinkFolder => 'フォルダのリンクを解除し、曲リストをクリアする';

  @override
  String get unlinkFolderClear => 'フォルダのリンクを解除し、曲リストをクリアする';

  @override
  String unlockedCountLabel(int unlocked, int total) {
    return '$unlocked / $total 解除済み';
  }

  @override
  String get unmuteTooltip => 'ミュート解除';

  @override
  String get unsavedChanges => '保存されていない変更があります';

  @override
  String get upNext => '次の曲';

  @override
  String upNextCount(int count) {
    return '次の曲 ($count)';
  }

  @override
  String get upNextSection => '次の曲';

  @override
  String get updateAvailableTitle => '更新が利用可能';

  @override
  String updateAvailableVersion(String version) {
    return '新しいバージョン（$version）が利用可能です。';
  }

  @override
  String updateFailed(String error) {
    return '更新に失敗しました: $error';
  }

  @override
  String get updateNow => '今すぐ更新';

  @override
  String get updatePrompt => '今すぐダウンロードしてインストールしますか？';

  @override
  String get updatingYtDlp => 'yt-dlpを更新中';

  @override
  String get usbAudioBypass => 'USBオーディオバイパス (ベータ) - Android 13以下向け直接DAC出力';

  @override
  String get usbAudioBypassBeta => 'USBオーディオバイパス (ベータ) - Android 13以下向け直接DAC出力';

  @override
  String get useDarkTheme => 'ダークテーマを使用する';

  @override
  String get useMixedColors => 'ミックスカラーを使用する（同期を優先）';

  @override
  String get verifiedDeveloper => '認証済み開発者';

  @override
  String get version => 'バージョン';

  @override
  String versionLabel(String version) {
    return 'バージョン $version';
  }

  @override
  String get vietnamese => 'ベトナム語';

  @override
  String get viewQueue => 'キューを表示する';

  @override
  String get visualizer => 'ビジュアライザー';

  @override
  String get visualizerStyle => 'ビジュアライザースタイル';

  @override
  String get wasapiExclusive => 'WASAPI排他モード';

  @override
  String get weekly => '週間';

  @override
  String get weeks => '週間';

  @override
  String get winter => '冬';

  @override
  String get worldRanking => 'ワールドランキング';

  @override
  String get worldTopArtists => '世界のトップアーティスト';

  @override
  String get year => '年';

  @override
  String get youMayLike => 'おすすめの曲';

  @override
  String get yourPlaylists => 'あなたのプレイリスト';

  @override
  String get yourTopMix => 'あなたのトップミックス';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytDlpUpdateAvailable => 'yt-dlpの新しいバージョンが利用可能です。';
}
