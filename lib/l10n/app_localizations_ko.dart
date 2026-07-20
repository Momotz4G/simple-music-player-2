// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get aboutEducationalPurpose => '이 애플리케이션은 개인 및 교육 목적으로만 개발되었습니다.';

  @override
  String get aboutLicenses => '정보 및 라이선스';

  @override
  String get aboutNotForCommercial => '상업적 용도 아님.';

  @override
  String get accentColor => '강조 색상';

  @override
  String get access => '액세스';

  @override
  String get accessCode => '액세스 코드';

  @override
  String get accountDataMergeDesc =>
      '동기화하면 프로필 이름과 아바타가 업데이트되지만, 현재 기기의 청취 시간은 계정 총계에 성공적으로 통합됩니다.';

  @override
  String get accountLinked => '계정 연결됨';

  @override
  String get accountLinkedSuccessfully => '계정이 성공적으로 연결되었습니다!';

  @override
  String get accountTiers => '계정 등급';

  @override
  String get achievementsUnlocked => '해제된 업적';

  @override
  String get activeNoResampling => '활성 (리샘플링 필요 없음)';

  @override
  String get add => '추가';

  @override
  String get addFiles => '파일 추가';

  @override
  String get addFolder => '폴더 추가';

  @override
  String get addFoldersScan => '스캔할 폴더 추가';

  @override
  String get addLineToEnd => '맨 뒤에 추가';

  @override
  String get addLineToTop => '맨 위에 추가';

  @override
  String get addToFavorite => '즐겨찾기에 추가';

  @override
  String get addToPlaylist => '플레이리스트에 추가';

  @override
  String get addToQueue => '대기열에 추가';

  @override
  String addedFolder(Object folder) {
    return '폴더 추가됨: $folder';
  }

  @override
  String get addedToLikedSongs => '좋아요 표시한 곡에 추가됨';

  @override
  String get addedToPlaylistSuccess => '플레이리스트에 추가됨';

  @override
  String get addedToQueue => '대기열에 추가됨';

  @override
  String get aiGenerate => 'AI 생성';

  @override
  String get aiLyricsComplete => '완료!';

  @override
  String get aiLyricsError => 'Error generating AI lyrics.';

  @override
  String get aiLyricsFailed => 'Failed to generate AI lyrics.';

  @override
  String get aiLyricsGenerating => 'Generating AI Lyrics...';

  @override
  String get aiLyricsGenerationTitle => 'AI 가사 생성';

  @override
  String get aiLyricsInitializing => '초기화 중...';

  @override
  String get aiLyricsLocalFileMissing => '오류: 로컬 오디오 파일을 찾을 수 없습니다.';

  @override
  String get aiLyricsParsing => '가사 분석 중...';

  @override
  String get aiLyricsPolling => '가사 가져오는 중... 잠시만 기다려 주세요!';

  @override
  String get aiLyricsReceiving => '가사 수신됨';

  @override
  String get aiLyricsStatusOk => '상태 코드 200 OK!';

  @override
  String get aiLyricsSuccess => '가사 생성 성공!';

  @override
  String get aiLyricsUploadFailed => '오류: 업로드 실패.';

  @override
  String get aiLyricsUploadSuccess => '업로드 완료!';

  @override
  String get aiLyricsUploading => '노래를 서버에 업로드 중...';

  @override
  String get aiLyricsVerifying => '서버 상태 확인 중...';

  @override
  String alacDownloadsPerDay(int count) {
    return '하루 $count회 ALAC 다운로드';
  }

  @override
  String get alacHighResDownloads => 'ALAC 고음질 다운로드';

  @override
  String get album => '앨범';

  @override
  String get albumAddedToPlaylists => '플레이리스트에 앨범 추가됨';

  @override
  String get albumLabel => '앨범';

  @override
  String get albumRemovedFromPlaylists => '플레이리스트에서 앨범 제거됨';

  @override
  String get albums => '앨범';

  @override
  String get allDownloadsRemoved => '모든 다운로드 항목 제거됨';

  @override
  String get allRightsReserved => '판권 소유.';

  @override
  String get allTime => '전체 기간';

  @override
  String get alreadyInLikedSongs => '이미 좋아요 표시한 곡';

  @override
  String get alreadyPaidCheckStatus => '이미 결제하셨나요? 상태 확인';

  @override
  String get android14BitPerfect => 'Android 14+ 비트 퍼펙트';

  @override
  String get androidAudioEffectsNote => '참고: 오디오 효과는 Android 장치에서만 들을 수 있습니다.';

  @override
  String get androidAudioTrack => 'Android AudioTrack';

  @override
  String get androidBitPerfect => 'Android 14+ 비트 퍼펙트';

  @override
  String get androidMixer => 'Android 믹서';

  @override
  String get appearance => '테마 및 디자인';

  @override
  String get applyBtn => '적용';

  @override
  String get applyOnRestart => '변경 사항은 다음 재시작 시 적용됩니다.';

  @override
  String get arabic => '아랍어';

  @override
  String get artist => '아티스트';

  @override
  String get artistLabel => '아티스트';

  @override
  String get artists => '아티스트';

  @override
  String get atmospheres => '분위기';

  @override
  String get audioFormat => '오디오 형식';

  @override
  String get audioOutput => '오디오 출력';

  @override
  String get audioOutputDevice => '오디오 출력 장치';

  @override
  String get audioQuality => '오디오 품질';

  @override
  String get audioSource => '오디오 소스';

  @override
  String get audiophileDAC => '오디오필 DAC 재생 시 활성화 (재시작 필요)';

  @override
  String get autoAddSimilar => '대기열이 거의 비었을 때 비슷한 곡 자동 추가';

  @override
  String get autoClearAfter24h => '24시간 후';

  @override
  String get autoClearAfter7d => '7일 후';

  @override
  String get autoClearCache => '캐시 자동 지우기';

  @override
  String get autoClearDisabled => '비활성화됨';

  @override
  String get autoClearEvery30m => '30분마다 (청취 중일 때만)';

  @override
  String get autoClearOnClose => '앱 종료 시';

  @override
  String get autoFixComingSoon => '자동 수정 (출시 예정)';

  @override
  String get autoRestartNotSupported => '자동 재시작이 지원되지 않습니다. 수동으로 재시작해 주세요.';

  @override
  String autoTagContent(int count, String sourceName) {
    return 'Spotify에서 \'$sourceName\'의 모든 $count개 곡을 검색하고 태그를 자동으로 덮어씁니다.\\n\\n이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String autoTagTitle(String sourceName) {
    return '⚠️ $sourceName을(를) 자동 태그 하시겠습니까?';
  }

  @override
  String get automatic => '자동';

  @override
  String get automaticGainControl => '자동 게인 제어';

  @override
  String get automaticGainControlDesc =>
      '노래 간 볼륨을 균일하게 조절하여 소리가 너무 크거나 작지 않게 만듭니다.';

  @override
  String automaticTitleLabel(String title) {
    return '자동: $title';
  }

  @override
  String get autumn => '가을';

  @override
  String get avatarPickerDesc => '템플릿을 선택하거나 본인의 사진을 불러오세요';

  @override
  String get backgroundCacheFlacStreams => '백그라운드 FLAC 스트림 캐시';

  @override
  String get backgroundCacheFlacStreamsSubtitle =>
      '스트리밍된 무손실 트랙을 로컬 디스크에 자동으로 다운로드하여 재생이 즉각적이고 데이터를 사용하지 않습니다.';

  @override
  String get beFirstToClaim => '1위를 먼저 차지해 보세요!';

  @override
  String get behavioralHeader => '행동 업적';

  @override
  String get behavioralTitles => '행동 기반';

  @override
  String get binariesUpdateRequired => '바이너리 업데이트 필요';

  @override
  String get bitDepthLabel => '비트 깊이';

  @override
  String get bitPerfectBypassSub14 => 'Android 14+ 비트 퍼펙트 API를 사용하여 시스템 믹서 우회';

  @override
  String get bitPerfectBypassSubLegacy =>
      'C++ 오디오 엔진을 사용하여 시스템 믹서 우회 (Android 13 이하)';

  @override
  String get bitPerfectBypassSuccess => '비트 퍼펙트 재생이 활성화되었습니다.';

  @override
  String get bitPerfectBypassTitle => '비트 퍼펙트 / USB 오디오 우회';

  @override
  String get bitPerfectBypassWarning => '먼저 USB DAC를 연결해야 합니다.';

  @override
  String get bitPerfectEnabled => '비트 퍼펙트 모드 활성화됨. 볼륨 조절이 비활성화될 수 있습니다.';

  @override
  String get bitPerfectWindows => '자동 샘플링 레이트로 비트 퍼펙트 오디오 (재시작 필요)';

  @override
  String get bitrateLabel => '비트레이트';

  @override
  String get bitsLabel => '비트';

  @override
  String get brazil => '브라질';

  @override
  String get browse => '둘러보기';

  @override
  String get bypassSystemMixer => 'USB DAC에 대해 시스템 믹서 우회';

  @override
  String get bypassedBitPerfect => '우회됨 (비트 퍼펙트)';

  @override
  String get cacheCleared => '캐시가 성공적으로 지워졌습니다!';

  @override
  String get cached => '캐시됨';

  @override
  String get cancel => '취소';

  @override
  String get cancelAllBtn => '모두 취소';

  @override
  String get canvasSourcePreferenceSubtitle => '배경 루프 동영상을 불러올 소스를 선택합니다';

  @override
  String get canvasSourcePreferenceTitle => 'Canvas / 애니메이션 아트워크 소스';

  @override
  String get championChampionTooltip => '5주 동안 세계 1위 달성';

  @override
  String get change => '변경';

  @override
  String get changeFolder => '폴더 변경';

  @override
  String get changeFormatInSettings => '설정에서 출력 형식을 변경해 주세요';

  @override
  String get changeLabel => '변경';

  @override
  String get changeLanguage => '애플리케이션 언어 변경';

  @override
  String get changesApplyRestart => '변경 사항은 다음 재시작 시 적용됩니다.';

  @override
  String get changingAudioDeviceRestart =>
      '오디오 출력 장치를 변경하려면 애플리케이션을 재시작해야 적용됩니다.\\n\\n지금 재시작하시겠습니까?';

  @override
  String get channelsLabel => '채널';

  @override
  String get checkAgain => '다시 확인';

  @override
  String get checkInternetConnection => '인터넷 연결을 확인하세요';

  @override
  String get checkNetworkTryAgain => '네트워크 연결을 확인하고 다시 시도하세요';

  @override
  String get chinese => '중국어';

  @override
  String get chooseAccentColor => '선호하는 정적 색상 선택';

  @override
  String get chooseAnimationType => '애니메이션 유형 선택';

  @override
  String get chooseArtist => '아티스트 선택';

  @override
  String get chooseAvatar => '아바타 선택';

  @override
  String get chooseFormat => '선호하는 형식을 선택하세요:';

  @override
  String get chooseYourTitle => '타이틀 선택';

  @override
  String get circularPulse => '원형 펄스';

  @override
  String get clearAll => '모두 지우기';

  @override
  String get clearAllDesc => '현재 편집기 상태를 지웁니다. 나중에 저장하지 않는 한 로컬 파일은 삭제되지 않습니다.';

  @override
  String get clearAllQuestion => '모두 지우시겠습니까?';

  @override
  String get clearBtn => '지우기';

  @override
  String get clearHistory => '기록 지우기';

  @override
  String get clearImported => '가져온 항목 지우기';

  @override
  String get clearMetadataCache => '메타데이터 및 아트 캐시 지우기';

  @override
  String get clearPlayHistory => '재생 기록 및 감상 시간 지우기';

  @override
  String get clearStreamingCache => '스트리밍 캐시 지우기';

  @override
  String get close => '닫기';

  @override
  String get cloud => '클라우드';

  @override
  String get cloudStatsAndRankings => '클라우드 통계 및 순위';

  @override
  String get codeCopied => '코드가 클립보드에 복사되었습니다!';

  @override
  String get codeMust6Digits => '코드는 6자리여야 합니다';

  @override
  String get codecLabel => '코덱';

  @override
  String get comingSoon => '출시 예정';

  @override
  String get community => '커뮤니티';

  @override
  String get competitiveTitles => '경쟁적';

  @override
  String get confirm => '확인';

  @override
  String get connect => '연결';

  @override
  String get connectToADevice => '기기에 연결';

  @override
  String get connected => '연결됨';

  @override
  String connectedToDac(String deviceName) {
    return '$deviceName에 연결됨 - USB 우회 활성';
  }

  @override
  String get connectedUsbDacs => '연결된 USB DAC:';

  @override
  String get connecting => '연결 중...';

  @override
  String get connectionLostLeaderboard => '연결 끊김';

  @override
  String get connectionLostLeaderboardDesc =>
      '글로벌 리더보드는 통계를 동기화하고 전 세계 순위를 가져오기 위해 활성 연결이 필요합니다.';

  @override
  String consecutivePlaysTooltip(int count) {
    return '같은 곡을 $count회 연속 감상';
  }

  @override
  String get contentRegion => '콘텐츠 지역';

  @override
  String get continueToSociabuzz => 'Sociabuzz로 계속';

  @override
  String get copyCode => '코드 복사';

  @override
  String get copyLink => '링크 복사';

  @override
  String get couldNotDownloadFlac => 'FLAC을 다운로드할 수 없습니다.';

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count곡',
      one: '1곡',
    );
    return '$_temp0';
  }

  @override
  String get createPlaylist => '재생 목록 만들기';

  @override
  String creatingPlaylistWithTracks(int count) {
    return '$count개의 트랙으로 재생 목록을 생성하는 중...';
  }

  @override
  String get crossfade => '크로스페이드';

  @override
  String crossfadeDesc(String seconds) {
    return '곡 사이전환을 부드럽게 ($seconds 초)';
  }

  @override
  String get crownedChampionTitlesHeader => '왕관을 쓴 챔피언 타이틀';

  @override
  String get currentTierLabel => '현재';

  @override
  String get customDevice => '사용자 지정 장치';

  @override
  String get customSelected => '커스텀 선택됨';

  @override
  String get customTime => '사용자 지정 시간';

  @override
  String get cyberpunk => '사이버펑크';

  @override
  String get daily => '일간';

  @override
  String get darkMode => '다크 모드';

  @override
  String get dataCleanup => '데이터 및 정리';

  @override
  String get dataUsage => '데이터 사용량';

  @override
  String get daysShort => '일';

  @override
  String get debugging => '디버깅';

  @override
  String get delete => '삭제';

  @override
  String get deleteDownloadsConfirm => '이 플레이리스트의 모든 다운로드된 곡이 장치에서 제거됩니다.';

  @override
  String get deleteDownloadsTitle => '다운로드 항목 삭제?';

  @override
  String deleteFileContent(String filename) {
    return '\'$filename\'을(를) 삭제하시겠습니까?\\n이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String get deleteFileTitle => '파일 삭제?';

  @override
  String get deletePlaylist => '재생 목록 삭제';

  @override
  String deletePlaylistConfirm(String name) {
    return '\'$name\'을(를) 삭제하시겠습니까?';
  }

  @override
  String get deletePlaylistPermanentConfirm =>
      '이 재생 목록을 삭제하시겠습니까? (이 작업은 취소할 수 없습니다)';

  @override
  String get deletePlaylistTitle => '플레이리스트 삭제?';

  @override
  String get deletePreset => '프리셋 삭제';

  @override
  String get desertMirage => '사막의 신기루';

  @override
  String get developerExclusiveTooltip => '이 앱의 개발자 전용';

  @override
  String deviceNameLabel(String deviceName) {
    return '기기: $deviceName';
  }

  @override
  String get disableCanvas => 'Canvas 비활성화';

  @override
  String get disableRomanization => '로마자 표기 비활성화';

  @override
  String get disableServicesTitle => '서비스 비활성화';

  @override
  String get disabled => '비활성화됨';

  @override
  String get disablingSharingWarning =>
      '공유를 비활성화하면 공간을 절약하기 위해 서버에서 코드와 데이터가 영구적으로 삭제됩니다.';

  @override
  String get discNumber => '디스크 번호';

  @override
  String get discography => '디스코그래피';

  @override
  String get discordRPC => 'Discord Rich Presence';

  @override
  String get doYouRemember => '기억하시나요?';

  @override
  String get donate => '후원하기';

  @override
  String get donateMinToObtain => '최소 10,000 IDR 기부 시 획득 (영구)';

  @override
  String get download => '다운로드';

  @override
  String get downloadAll => '모두 다운로드';

  @override
  String get downloadComplete => '다운로드 완료';

  @override
  String get downloadCompleteNotification => '다운로드 완료';

  @override
  String get downloadError => '다운로드 오류';

  @override
  String get downloadFailed => '다운로드 실패';

  @override
  String get downloadLocation => '다운로드 위치';

  @override
  String get downloadPathReset => '다운로드 경로가 기본값으로 재설정되었습니다.';

  @override
  String downloadPathUpdated(Object path) {
    return '다운로드 경로 업데이트됨: $path';
  }

  @override
  String get downloadSong => '곡 다운로드';

  @override
  String get downloadStarted => '다운로드 시작됨';

  @override
  String downloadedTo(String path) {
    return '다운로드 위치: $path';
  }

  @override
  String get downloading => '다운로드 중';

  @override
  String get downloadingFlac => 'FLAC 다운로드 중';

  @override
  String downloadingFormat(String format) {
    return '$format 다운로드 중';
  }

  @override
  String get downloadingUpdate => '업데이트 다운로드 중';

  @override
  String get downloads => '다운로드';

  @override
  String get dspLabel => 'DSP';

  @override
  String get editLyricsTooltip => '가사 편집';

  @override
  String get editMetadata => '메타데이터 편집';

  @override
  String get editNickname => '닉네임 수정';

  @override
  String get editor => '편집기';

  @override
  String get emptyMailbox => '편지함 비우기';

  @override
  String get emptyMailboxDesc => '모든 메시지가 영구적으로 삭제됩니다.';

  @override
  String get emptyMailboxTitle => '편지함을 비울까요?';

  @override
  String get emptyPlaylist => '빈 재생 목록';

  @override
  String get emptyPlaylistSubtitle => '비어 있는 새 재생 목록 만들기';

  @override
  String get enableAlphabetIndexer => '알파벳 스크롤 인덱서 활성화';

  @override
  String get enableAlphabetIndexerSubtitle => '모바일 리스트 뷰에서 A-Z 사이드바 인덱스 표시';

  @override
  String get enableBarVisualizer => '바 비주얼라이저 활성화';

  @override
  String get enableOfflineModeBtn => '오프라인 모드 활성화';

  @override
  String get enableOfflineModeQuestion => '오프라인 모드를 활성화할까요?';

  @override
  String get endLabel => '종료: ';

  @override
  String get endlessQueue => '무한 대기열';

  @override
  String get engineLabel => '엔진';

  @override
  String get english => '영어';

  @override
  String get enterAdminAccessCode => '관리자 액세스 코드 입력';

  @override
  String get enterAdminCode => '관리자 액세스 코드 입력';

  @override
  String get enterDuration => '시간 입력...';

  @override
  String get enterPresetName => '프리셋 이름 입력 (예: 나의 베이스)';

  @override
  String get enterShareCode => '6자리 공유 코드를 입력하세요';

  @override
  String get eqLabel => 'EQ';

  @override
  String get equalizer => '이퀄라이저';

  @override
  String get equipTitle => '타이틀 장착';

  @override
  String get equipped => '장착됨';

  @override
  String get error => '오류';

  @override
  String get errorCouldNotCreateSession => '오류: 세션을 생성할 수 없습니다.';

  @override
  String errorDeleting(String error) {
    return '삭제 중 오류: $error';
  }

  @override
  String get errorSearchingStream => '스트림 검색 중 오류.';

  @override
  String get exclusiveMode => '독점';

  @override
  String get exclusiveModeWarning =>
      '주의: 독점 모드는 시스템 기본값이 아닌 특정 장치를 선택했을 때 가장 잘 작동합니다.';

  @override
  String get exclusiveSupporterTitle => '독점 서포터 칭호 및 Discord 역할';

  @override
  String get exclusiveTitles => '전용';

  @override
  String get exclusiveTitlesHeader => '전용 타이틀';

  @override
  String get exclusiveWarning =>
      '주의: 독점 모드는 시스템 기본값이 아닌 특정 장치를 선택했을 때 가장 잘 작동합니다.';

  @override
  String get exitApp => '종료';

  @override
  String get expand => '확장';

  @override
  String get exportToM3u => 'Export to M3U';

  @override
  String get externalFiles => '외부 파일';

  @override
  String get externalLinkDetected => '외부 링크 감지됨';

  @override
  String get fadingAtEnd => '취침 타이머: 트랙 끝에서 페이드 아웃 중...';

  @override
  String get failedDisableSharing => '공유를 비활성화하지 못했습니다.';

  @override
  String get failedEnableSharing => '공유를 활성화하지 못했습니다. 연결을 확인하세요.';

  @override
  String get failedFetchPlaylistInfo => '재생 목록 정보를 가져올 수 없습니다';

  @override
  String get failedToConnectDac => 'DAC 연결 실패. USB 권한을 확인하세요.';

  @override
  String get failedToGenerateCode => '공유 코드를 생성하지 못했습니다. 연결을 확인하세요.';

  @override
  String get failedToSave => '가사 파일 저장에 실패했습니다.';

  @override
  String get failedToSetAvatar => '아바타 템플릿 설정 실패';

  @override
  String get failedToUpdateMetadata => '메타데이터 업데이트 실패';

  @override
  String get favoriteTrack => '즐겨찾는 트랙';

  @override
  String get featureAiLyrics => 'AI 가사 생성기';

  @override
  String get featureAiLyricsDesc => '자동 동기화 가사 비활성화됨';

  @override
  String get featureAiLyricsLongDesc => 'AI를 통한 동기화 가사 생성';

  @override
  String get featureCloudSync => '클라우드 통계 동기화';

  @override
  String get featureCloudSyncDesc => '청취 통계가 로컬에만 저장됨';

  @override
  String get featureCloudSyncLongDesc => '청취 메트릭을 PocketBase와 동기화';

  @override
  String get featureConnectDevice => '기기에 연결';

  @override
  String get featureConnectDeviceDesc => '원격 제어 및 리스닝 파티 비활성화됨';

  @override
  String get featureConnectDeviceLongDesc => '원격 제어 및 리스닝 파티';

  @override
  String get featureLeaderboard => '글로벌 리더보드';

  @override
  String get featureLeaderboardDesc => '순위 업데이트 일시 중지됨';

  @override
  String get featureLeaderboardLongDesc => '순위를 공개적으로 표시 및 업데이트';

  @override
  String get featureOnlineLyrics => '온라인 가사 검색';

  @override
  String get featureOnlineLyricsDesc => '로컬 .lrc/.ttml 파일만 사용';

  @override
  String get featureOnlineLyricsLongDesc => 'LRCLIB/Spotify에서 가사 가져오기';

  @override
  String get featureOnlineSearch => '온라인 검색';

  @override
  String get featureOnlineSearchDesc => 'Spotify/YouTube 검색 비활성화됨';

  @override
  String get featureOnlineSearchLongDesc => 'Spotify 및 YouTube 원격 검색';

  @override
  String get featureSpotifyCanvas => 'Spotify Canvas';

  @override
  String get featureSpotifyCanvasDesc => '배경 동영상 비활성화됨';

  @override
  String get featureSpotifyCanvasLongDesc => '트랙 배경 동영상';

  @override
  String get fetchingAlacAppleMusic => 'Apple Music에서 ALAC Lossless 가져오는 중...';

  @override
  String get fetchingCanvas => 'Canvas 가져오는 중...';

  @override
  String get fetchingLossless => '무손실 음원 가져오는 중...';

  @override
  String get fetchingLosslessAudio => '무손실 오디오 가져오는 중...';

  @override
  String get fetchingMetadataSpotify => 'Spotify에서 메타데이터 가져오는 중...';

  @override
  String get fetchingPlaylist => '재생 목록을 가져오는 중...';

  @override
  String get fetchingPlaylistInfo => '재생 목록 정보를 가져오는 중...';

  @override
  String get fetchingSharedPlaylist => '공유 재생 목록을 가져오는 중...';

  @override
  String fetchingTracksFrom(String name) {
    return '\"$name\"에서 트랙을 가져오는 중...';
  }

  @override
  String get fileLocation => '파일 위치';

  @override
  String get fileMissingHistory => '파일이 누락되었으며 기록에서 찾을 수 없습니다.';

  @override
  String get fileName => '파일 이름';

  @override
  String get fileSizeLabel => '파일 크기';

  @override
  String get files => '파일';

  @override
  String get filters => '필터';

  @override
  String get findingBestMatchYoutube => 'YouTube에서 최적의 검색 결과 찾는 중...';

  @override
  String get findingStream => '스트림 소스 찾는 중...';

  @override
  String get finishUpdate => '업데이트 완료';

  @override
  String get finishes => '순위';

  @override
  String get fixAll => '모두 수정';

  @override
  String get flacError => 'FLAC 오류';

  @override
  String get flacNote =>
      '참고: FLAC은 개별 트랙 다운로드에만 사용할 수 있습니다. 일괄 플레이리스트 다운로드는 M4A 형식을 사용합니다.';

  @override
  String get flacSavedToDownloads => 'FLAC이 다운로드 폴더에 저장됨';

  @override
  String get flacUnavailable => 'FLAC 사용 불가';

  @override
  String get flacUnavailableDesc => 'FLAC을 사용할 수 없어 다운로드에 실패했습니다. 설정을 변경해 보세요.';

  @override
  String get flacUnavailableNotification => 'FLAC 사용 불가';

  @override
  String get fluidWave => '유체 파동';

  @override
  String folderPath(String path) {
    return '폴더: $path';
  }

  @override
  String get folders => '폴더';

  @override
  String get formatLabel => '형식';

  @override
  String get formatSaved => '형식이 저장되었습니다!';

  @override
  String foundExistingAccount(String name) {
    return '\'$name\'에 대한 기존 계정을 찾았습니다.';
  }

  @override
  String foundResults(int songCount, int albumCount, int artistCount) {
    return '$songCount개 곡, $albumCount개 앨범, $artistCount개 아티스트를 찾았습니다.';
  }

  @override
  String foundYoutubeResults(int count) {
    return 'YouTube에서 $count개의 결과를 찾았습니다';
  }

  @override
  String freeUpSpace(String size) {
    return '공간 확보 (현재: $size)';
  }

  @override
  String get french => '프랑스어';

  @override
  String fromLibraryCount(int count) {
    return '라이브러리에서 ($count)';
  }

  @override
  String get fromLibrarySection => '라이브러리에서';

  @override
  String get fullScreenPlayerTooltip => '전체 화면 플레이어';

  @override
  String get galacticSpace => '은하 우주';

  @override
  String get gaplessPlayback => '끊김 없는 재생';

  @override
  String get gaplessPlaybackDesc => '트랙 사이의 공백 제거';

  @override
  String get general => '일반';

  @override
  String get generateAiLyrics => 'Generate AI Lyrics';

  @override
  String get generatingShareCode => '공유 코드 생성 중...';

  @override
  String get generationFailed => '생성 실패';

  @override
  String get genre => '장르';

  @override
  String get german => '독일어';

  @override
  String get globalLeaderboard => '글로벌 리더보드';

  @override
  String get globalMailbox => '글로벌 편지함';

  @override
  String get globalRank => '글로벌 순위';

  @override
  String get globalRankings => '글로벌 랭킹';

  @override
  String get globalRankingsDesc => '일간, 주간, 전체 상위 청취자를 확인하세요!';

  @override
  String get goToArtist => '아티스트로 이동';

  @override
  String get goToLocalLibraryToSelect => '\'로컬 라이브러리\'로 이동하여 음악 폴더를 선택하세요.';

  @override
  String get gofileDownloadFailedPrompt =>
      '엄격한 네트워크 또는 서버 제한으로 인해 자동 다운로드에 실패했습니다.\\n\\n시스템 브라우저에서 Gofile 다운로드 페이지를 여시겠습니까, 아니면 링크를 복사하여 수동으로 다운로드하시겠습니까?';

  @override
  String get goodAfternoon => '좋은 오후입니다';

  @override
  String get goodEvening => '좋은 저녁입니다';

  @override
  String get goodMorning => '좋은 아침입니다';

  @override
  String get googleAccount => 'Google 계정';

  @override
  String get grantAccess => '액세스 허용';

  @override
  String get grantPermission => '권한 허용';

  @override
  String get guestTier => '게스트';

  @override
  String get hallOfFameHeader => '명예의 전당 업적';

  @override
  String get hallOfFameTitles => '명예의 전당';

  @override
  String get hideCanvas => 'Spotify Canvas 비디오 대신 앨범 아트 표시';

  @override
  String get hideRomajiPinyin => '한국어, 일본어, 중국어 가사 아래의 로마자/병음 숨기기';

  @override
  String get hideTranslation => '번역 숨기기';

  @override
  String get highDesc => 'M4A - 더 나은 품질, 균형 잡힌 선택';

  @override
  String get highQuality => '고품질 (M4A)';

  @override
  String get hindi => '힌디어';

  @override
  String get history => '기록';

  @override
  String get historySection => '기록';

  @override
  String get home => '홈';

  @override
  String get hourShort => '시간';

  @override
  String hoursDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count시간',
      one: '1시간',
    );
    return '$_temp0';
  }

  @override
  String get hoursShort => '시';

  @override
  String get ignoreSubfolderScan => '하위 폴더 스캔 무시';

  @override
  String get importAdditionalPaths => '추가 경로 가져오기';

  @override
  String get importChoice => '가져오기';

  @override
  String importFailed(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get importFromGallery => '갤러리에서 불러오기';

  @override
  String get importFromM3u => 'Import from M3U';

  @override
  String get importFromM3uSubtitle => 'Import an M3U playlist file';

  @override
  String get importFromSpotify => 'Spotify에서 가져오기';

  @override
  String get importFromSpotifySubtitle => 'Spotify 플레이리스트 URL 붙여넣기';

  @override
  String get importFromYoutubeMusic => 'YouTube Music에서 가져오기';

  @override
  String get importFromYoutubeMusicSubtitle => 'YouTube Music 재생목록 URL 붙여넣기';

  @override
  String get importLabel => '가져오기';

  @override
  String get importLyricsFile => '가사 파일 가져오기';

  @override
  String get importLyricsTooltip => '가사 가져오기';

  @override
  String get localFile => '로컬 파일';

  @override
  String get importLocalFileSubtitle => '.lrc, .ttml 또는 .txt 가져오기';

  @override
  String get searchFromAppleMusic => 'Apple Music에서 검색';

  @override
  String get searchAppleMusicSubtitle => 'LRC/TTML 자동 다운로드';

  @override
  String get searchFromSpotifyLyrics => 'Spotify에서 검색';

  @override
  String get searchSpotifyLyricsSubtitle => 'Spotify에서 동기화된 가사 다운로드';

  @override
  String get searchFromMusixmatch => 'Musixmatch에서 검색';

  @override
  String get searchMusixmatchSubtitle => 'Musixmatch에서 동기화된 가사 다운로드';

  @override
  String get searchingAppleMusic => 'Apple Music 검색 중...';

  @override
  String get findingMatches => '일치 항목 찾는 중...';

  @override
  String get noResultsAppleMusic => 'Apple Music에서 결과를 찾을 수 없습니다.';

  @override
  String get selectSong => '곡 선택';

  @override
  String get downloadingLyrics => '가사 다운로드 중...';

  @override
  String get fetchingLyricsFromServer => '서버에서 TTML/LRC 가져오는 중...';

  @override
  String get failedDownloadAppleMusic =>
      '가사를 다운로드하지 못했습니다. Apple Music에 존재하지 않을 수 있습니다.';

  @override
  String get lyricsImportedSuccess => '가사를 성공적으로 가져왔습니다! 저장하여 유지하세요.';

  @override
  String get receivedEmptyLyrics => '서버에서 빈 가사를 받았습니다.';

  @override
  String get downloadingFromSpotify => 'Spotify에서 다운로드 중...';

  @override
  String get fetchingLyrics => '가사 가져오는 중...';

  @override
  String get lyricsImportedSpotify => 'Spotify에서 가사를 가져왔습니다!';

  @override
  String get noLyricsSpotify => 'Spotify에서 가사를 찾을 수 없습니다.';

  @override
  String get downloadingFromMusixmatch => 'Musixmatch에서 다운로드 중...';

  @override
  String get lyricsImportedMusixmatch => 'Musixmatch에서 가사를 가져왔습니다!';

  @override
  String get noLyricsMusixmatch => 'Musixmatch에서 가사를 찾을 수 없습니다.';

  @override
  String get importSpotifyPlaylist => 'Spotify 플레이리스트 가져오기';

  @override
  String get importViaCode => '코드를 통해 가져오기';

  @override
  String get importViaCodeSubtitle => '친구가 공유한 재생 목록 가져오기';

  @override
  String get importYoutubeMusicPlaylist => 'YouTube Music 플레이리스트 가져오기';

  @override
  String importedPlaylistName(String name) {
    return '\"$name\"을(를) 성공적으로 가져왔습니다!';
  }

  @override
  String importedTracks(int count) {
    return '$count개의 트랙을 성공적으로 가져왔습니다!';
  }

  @override
  String get indonesia => '인도네시아';

  @override
  String get indonesian => '인도네시아어';

  @override
  String get inputLabel => '입력';

  @override
  String get insertAfter => '뒤에 삽입';

  @override
  String get installNow => '지금 설치';

  @override
  String get integration => '연동';

  @override
  String get invalidAccessCode => '잘못된 액세스 코드';

  @override
  String get invalidCode => '잘못된 액세스 코드';

  @override
  String get invalidM3uFile => 'Invalid M3U File';

  @override
  String get invalidSpotifyUrl => '유효하지 않은 Spotify 재생 목록 URL';

  @override
  String get invalidYoutubeMusicUrl => '유효하지 않은 YouTube Music 재생목록 URL입니다';

  @override
  String get japan => '일본';

  @override
  String get japanese => '일본어';

  @override
  String get joinUs => '함께하기';

  @override
  String get jumpBackIn => '다시 듣기';

  @override
  String get justEnjoyVibes => '분위기를 즐기세요.';

  @override
  String get korean => '한국어';

  @override
  String get language => '언어';

  @override
  String last30DaysLabel(String size) {
    return '지난 30일: $size';
  }

  @override
  String last7DaysLabel(String size) {
    return '지난 7일: $size';
  }

  @override
  String get later => '나중에';

  @override
  String get library => '라이브러리';

  @override
  String get libraryData => '라이브러리 데이터';

  @override
  String get libraryNotLoaded => '라이브러리가 로드되지 않았습니다.';

  @override
  String get libraryPathReset => '라이브러리 경로가 재설정되었습니다.';

  @override
  String get likedSongs => '좋아요 표시한 곡';

  @override
  String get linkAccount => '계정 연결';

  @override
  String get linkAccountDesc => 'Google로 진행 상황 동기화 및 복구';

  @override
  String get linkAccountToUpgrade =>
      '업그레이드하려면 먼저 계정을 연결해야 합니다. Sociabuzz와 동일한 이메일을 사용해 주세요!';

  @override
  String get linkCopied => '링크가 클보드에 복사되었습니다!';

  @override
  String listenMinutesTooltip(String minutes) {
    return '$minutes분 동안 음악 감상';
  }

  @override
  String get listeningParty => '리스닝 파티';

  @override
  String get listeningStats => '감상 통계';

  @override
  String get loadingCanvas => 'Canvas 로딩 중...';

  @override
  String get loadingDevices => '장치 로딩 중...';

  @override
  String get loadingError => '세부 정보를 불러오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get loadingLyrics => '가사 로딩 중...';

  @override
  String get localPlayHistorySaved => '로컬 재생 기록은 삭제되지 않습니다.';

  @override
  String get local_library => '로컬 라이브러리';

  @override
  String get lockedAtmosphere => '분위기가 활성화된 동안 잠김';

  @override
  String get losslessDesc => 'FLAC - Deezer/Tidal의 무손실 품질';

  @override
  String get losslessNote =>
      '가능한 경우 Deezer/Tidal에서 무손실 FLAC을 스트리밍합니다. 불가능한 경우 M4A로 대체됩니다.';

  @override
  String get losslessQuality => '무손실 (자동)';

  @override
  String get lrcFormat => 'LRC (표준 동기화)';

  @override
  String get lrcFormatDesc => '어디서나 작동하는 범용 형식입니다.';

  @override
  String get lunarNewYear => '설날';

  @override
  String get lyricTextHint => '가사 텍스트...';

  @override
  String get lyricsApplied => '가사가 패널에 적용되었습니다!';

  @override
  String get lyricsByLRCLIB => '가사: LRCLIB';

  @override
  String get lyricsEditorTitle => '가사 편집기';

  @override
  String get lyricsSaveError => '가사 저장 실패';

  @override
  String get lyricsSavedSuccess => '가사가 .lrc 파일로 저장됨';

  @override
  String get lyricsTooltip => '가사';

  @override
  String get madeForYou => '당신을 위한 추천';

  @override
  String get manageIndividualFeatures => '개별 온라인 기능 관리';

  @override
  String get manualSearch => '수동 검색';

  @override
  String get mergeAccountData => '계정 데이터를 통합할까요?';

  @override
  String get metadataCacheCleared => '메타데이터 캐시가 삭제되고 라이브러리 재검색이 시작되었습니다';

  @override
  String get metadataEditorInfo => '메타데이터 편집기로 간편하게 검색하고 수정하세요.';

  @override
  String get metadataEditorNote =>
      '참고: 앨범 아트는 \"성공적으로 저장됨\" 상태 이후에 변경됩니다. 저장되지 않은 것이 아니라 앱의 캐싱 문제이며 현재 수정 중입니다. 파일 관리자 등으로 확인할 수 있습니다.';

  @override
  String get metadataUpdated => '메타데이터가 업데이트되었습니다';

  @override
  String get metadata_editor => '메타데이터 편집기';

  @override
  String get min => '분';

  @override
  String get minShortLabel => '분';

  @override
  String get miniPlayer => '미니 플레이어';

  @override
  String get minimizeToTray => '트레이로 최소화';

  @override
  String get minimizeToTrayDescription => '종료 대신 시스템 트레이로 앱 닫기';

  @override
  String get minsShort => '분';

  @override
  String get minsShortLabel => '분';

  @override
  String get minuteShort => '분';

  @override
  String get minutes => '분';

  @override
  String minutesDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count분',
      one: '1분',
    );
    return '$_temp0';
  }

  @override
  String get moreOptions => '추가 옵션';

  @override
  String get moreOptionsTooltip => '추가 옵션';

  @override
  String get mostListened => '가장 많이 들은 곡';

  @override
  String get mostListenedArtist => '가장 많이 청취한 아티스트';

  @override
  String get musicFolderLocation => '음악 폴더 위치';

  @override
  String get musicSearch => '음악 검색';

  @override
  String musicWillStopIn(String label) {
    return '$label 후에 음악이 중지됩니다';
  }

  @override
  String get muteTooltip => '음소거';

  @override
  String myTopTrackOn(String header) {
    return 'Simple Player에서 나의 $header! 🎵';
  }

  @override
  String get nativeRate => '네이티브 레이트';

  @override
  String get navigation => '네비게이션';

  @override
  String get newPlaylist => '새 플레이리스트';

  @override
  String get nextTrack => '다음 트랙';

  @override
  String get nicknameHint => '닉네임을 입력하세요';

  @override
  String get nicknameLabel => '닉네임';

  @override
  String get nicknameRequired => '닉네임 필요';

  @override
  String get nicknameRequiredDesc => '글로벌 리더보드를 보려면 먼저 커스텀 닉네임을 설정해야 합니다!';

  @override
  String get nicknameTakenDesc => '이 닉네임은 이미 사용 중입니다. 다른 닉네임을 선택하세요.';

  @override
  String get nicknameTakenTitle => '이미 사용 중인 닉네임';

  @override
  String get noAlbumsFound => '앨범 없음';

  @override
  String get noArtistStatsYet => '아직 아티스트 통계가 없습니다.';

  @override
  String get noArtistsFound => '아티스트 없음.';

  @override
  String get noDownloadsFound => '다운로드 항목 없음';

  @override
  String get noFolderSelected => '폴더가 선택되지 않음';

  @override
  String get noHistoryYet => '아직 기록이 없습니다';

  @override
  String get noInternetConnection => '인터넷 연결 없음';

  @override
  String get noLyricsAvailable => '가사 없음';

  @override
  String get noMessages => '편지함에 메시지가 없습니다';

  @override
  String get noMusicPlaying => '재생 중인 음악 없음';

  @override
  String get noPlaylistsFound => '플레이리스트 없음';

  @override
  String get noPlaylistsYet => '아직 재생 목록이 없습니다';

  @override
  String get noRankingsYet => '이 기간 동안의 순위가 아직 없습니다.';

  @override
  String get noResultsFound => '결과 없음';

  @override
  String get noSongPlaying => '재생 중인 곡 없음';

  @override
  String get noSongsAdded => '아직 추가된 곡이 없음';

  @override
  String get noSongsInFolder => '이 폴더에서 곡을 찾을 수 없습니다.';

  @override
  String get noSpotifyResults => 'Spotify 검색 결과 없음.';

  @override
  String get noStatsYet => '아직 통계가 없습니다.';

  @override
  String get noStreamMatch => '일치하는 스트림을 찾을 수 없습니다.';

  @override
  String get noSuggestionsFound => '제안 없음.';

  @override
  String get noSyncedLyricsFound => '동기화된 가사를 찾을 수 없음';

  @override
  String get noTracksFound => '재생 목록에서 트랙을 찾을 수 없습니다';

  @override
  String get noUsbDacDetected =>
      'USB DAC가 감지되지 않았습니다. USB 오디오 장치를 연결하고 스캔을 누르세요.';

  @override
  String get noUsersFound => '사용자를 찾을 수 없음';

  @override
  String get noYoutubeResults => 'YouTube에서 결과를 찾을 수 없습니다';

  @override
  String get none => '없음';

  @override
  String get nordicAurora => '노르딕 오로라';

  @override
  String notRank(int rank) {
    return '순위 $rank 아님';
  }

  @override
  String get notRanked => '순위 없음';

  @override
  String get notRankedTop3 => '상위 3위 이내 아님';

  @override
  String get nowPlaying => '현재 재생 중';

  @override
  String get nowPlayingHeader => '현재 재생 중';

  @override
  String get nowPlayingSection => '현재 재생 중';

  @override
  String get offline => '오프라인';

  @override
  String get offlineModeActive => '활성';

  @override
  String get offlineModeAllEnabledStatus => '모두 활성화됨';

  @override
  String get offlineModeConfirmationDesc =>
      '모든 네트워크 통신이 완전히 중단됩니다. 다음 기능들이 종료됩니다:';

  @override
  String offlineModeDisabledStatus(int count) {
    return '비활성화됨 ($count)';
  }

  @override
  String get offlineModeEnabledStatus => '오프라인 모드 활성화됨';

  @override
  String get offlineModeHeader => '오프라인 모드';

  @override
  String get offlineModeLockdownDesc => '네트워크 차단 활성 상태입니다. 통계는 로컬에 저장됩니다.';

  @override
  String get offlineModeMainDesc => '모든 네트워크 서비스를 비활성화하고 로컬 라이브러리만 재생합니다.';

  @override
  String get offlineModeSyncRestoreNote => '이 기능을 끄면 통계가 자동으로 동기화됩니다.';

  @override
  String get offlineModeTitle => '오프라인 모드';

  @override
  String get offlineStatus => '오프라인';

  @override
  String get ok => '확인';

  @override
  String get online => '온라인';

  @override
  String get onlineModeRestored => '온라인 모드 복구됨. 통계 동기화 중...';

  @override
  String get onlyAppleMusic => 'Apple Music만';

  @override
  String get onlyScanSelected => '선택한 폴더만 스캔 (기본값: 켬)';

  @override
  String get onlySpotify => 'Spotify만';

  @override
  String get opacity => '불투명도';

  @override
  String opacityLabel(int percent) {
    return '불투명도: $percent%';
  }

  @override
  String get openBrowser => '브라우저 열기';

  @override
  String get openProfile => '프로필 열기';

  @override
  String get openSourceLicenses => '오픈 소스 라이선스';

  @override
  String get outputLabel => '출력';

  @override
  String get overwrite => '덮어쓰기';

  @override
  String get overwriteLrcWarning => '이미 로컬 .lrc 파일이 있습니다.\\n덮어쓰시겠습니까?';

  @override
  String get owned => '보유함';

  @override
  String get parsingPlaylistData => '재생 목록 데이터를 분석하는 중...';

  @override
  String get pasteLyricsHint => '여기에 가사를 붙여넣으세요...';

  @override
  String get pathLabel => '경로';

  @override
  String get permissionRequired => '권한 필요';

  @override
  String get permissionRequiredDesc =>
      '태그를 편집하려면 \'모든 파일 액세스\' 권한이 필요합니다. 이를 통해 음악 파일을 직접 수정할 수 있습니다.';

  @override
  String get plainMode => '일반 텍스트';

  @override
  String get play => '재생';

  @override
  String playCountLabel(int count) {
    return '$count회 재생';
  }

  @override
  String get playFromLine => '이 줄부터 재생';

  @override
  String get playNext => '다음에 재생';

  @override
  String get playPause => '재생 / 일시정지';

  @override
  String get playQueue => '재생 대기열';

  @override
  String get playback => '재생';

  @override
  String get playbackError => '재생 오류';

  @override
  String get player => '플레이어';

  @override
  String get playingFromAlbum => '앨범에서 재생 중';

  @override
  String get playingNext => '다음에 재생 중';

  @override
  String get playingTrack => '트랙 재생 중';

  @override
  String get playlistAlbumTracks => '플레이리스트 / 앨범 트랙';

  @override
  String get playlistNameHint => '플레이리스트 이름';

  @override
  String get playlistNotFound => '플레이리스트를 찾을 수 없음';

  @override
  String get playlistNotFoundOrError => '재생 목록을 찾을 수 없거나 서버 오류입니다';

  @override
  String get playlistReadyShare => '재생 목록을 공유할 준비가 되었습니다!';

  @override
  String get playlists => '플레이리스트';

  @override
  String get plays => '회 재생';

  @override
  String get popularOnSpotify => 'Spotify 인기 곡';

  @override
  String get portuguese => '포르투갈어';

  @override
  String get preferAppleMusic => 'Apple Music 선호';

  @override
  String get preferSpotify => 'Spotify 선호';

  @override
  String get preferredOutputFormat => '다운로드 기본 출력 형식';

  @override
  String get premiumMemberDesc => '무제한 ALAC 다운로드 및 우선 대기열 액세스 권한이 있습니다!';

  @override
  String get premiumMemberTitle => '프리미엄 회원';

  @override
  String get preparingDownload => '다운로드 준비 중';

  @override
  String preparingDownloadFormat(String format) {
    return '다운로드 준비 중 ($format)...';
  }

  @override
  String get preparingDownloadNotification => '다운로드 준비 중';

  @override
  String get presetSaved => '프리셋 저장됨!';

  @override
  String get preview => '미리보기';

  @override
  String get previousTrack => '이전 트랙';

  @override
  String get priorityVipServerQueue => '우선 VIP 서버 대기열';

  @override
  String get processingOnServer => '서버에서 처리 중...';

  @override
  String get profileSettings => '프로필 설정';

  @override
  String get profileStats => '프로필 통계';

  @override
  String get progress => '진행 상황';

  @override
  String get publicSharing => '공개 공유';

  @override
  String get publicSharingDesc => '코드를 아는 사람은 누구나 이 재생 목록을 가져올 수 있습니다.';

  @override
  String get publicSharingDisabledDesc => '비활성화됨. 다른 사람과 공유하려면 활성화하세요.';

  @override
  String get queueIsEmpty => '대기열이 비어 있습니다';

  @override
  String queuePositionPleaseWait(int position) {
    return '대기열 $position... 잠시 기다려주세요';
  }

  @override
  String get queueTooltip => '대기열';

  @override
  String get queueUpdated => '대기열 업데이트됨';

  @override
  String get quickMix => '빠른 믹스';

  @override
  String get rainbowMode => '레인보우 모드';

  @override
  String get rainyCity => '비 오는 도시';

  @override
  String get rank => '순위';

  @override
  String rankActive(int rank) {
    return '순위 $rank (활성)';
  }

  @override
  String rankLabel(int rank) {
    return '순위 $rank';
  }

  @override
  String get reBuffering => '다시 버퍼링 중...';

  @override
  String reachDailyPlaysTooltip(int count) {
    return '하루에 $count회 재생 달성';
  }

  @override
  String reachSpecificArtistTooltip(String minutes) {
    return '특정 아티스트와 $minutes분 달성';
  }

  @override
  String reachWeeklyPlaysTooltip(int count) {
    return '일주일에 $count회 재생 달성';
  }

  @override
  String get readySearchSong => '준비되었습니다. 곡을 검색하세요.';

  @override
  String get rebufferingFromCloud => '클라우드에서 다시 버퍼링 중...';

  @override
  String get recentlyPlayed => '최근 재생 항목';

  @override
  String recommendationsCount(int count) {
    return '추천 ($count)';
  }

  @override
  String get recommendationsSection => '추천';

  @override
  String get rediscover => '다시 발견하기';

  @override
  String get refreshLabel => '새로고침';

  @override
  String get refreshLibrary => '라이브러리 새로고침';

  @override
  String get refreshList => '목록 새로고침';

  @override
  String get refreshLyricsTooltip => '가사 새로고침';

  @override
  String get registeredLinkedTier => '등록됨 (연결됨)';

  @override
  String get removeAvatar => '현재 아바타 제거';

  @override
  String get removeFromPlaylist => '플레이리스트에서 제거';

  @override
  String get removeLine => '줄 삭제';

  @override
  String removedFolder(Object folder) {
    return '폴더 제거됨: $folder';
  }

  @override
  String get rename => '이름 변경';

  @override
  String get renamePlaylist => '플레이리스트 이름 변경';

  @override
  String get repeats => '반복';

  @override
  String get reportTrouble => '문제 신고';

  @override
  String get requiresAndroid14 => 'Android 14+ 및 USB DAC 필요';

  @override
  String get resamplingLabel => '리샘플링';

  @override
  String get reset => '초기화';

  @override
  String get resetDataUsage => '데이터 사용량 초기화';

  @override
  String get resetDataUsageContent =>
      '데이터 사용량을 초기화하시겠습니까? 다운로드한 음악에는 영향을 주지 않습니다.';

  @override
  String get resetEverything => '모든 항목 재설정';

  @override
  String get resetLibraryContent => '플레이어에서 현재 폴더를 제거합니다. 실제 파일은 삭제되지 않습니다.';

  @override
  String get resetLibraryPath => '라이브러리 경로 재설정';

  @override
  String get resetLibraryTitle => '라이브러리를 재설정할까요?';

  @override
  String get resetPath => '경로 재설정';

  @override
  String get resetStatistics => '통계 재설정';

  @override
  String get resetStatsContent =>
      '이 작업은 되돌릴 수 없습니다.\\n모든 재생 횟수와 감상 시간이 영구적으로 삭제됩니다.';

  @override
  String get resetStatsTitle => '통계를 재설정할까요?';

  @override
  String get resetToAutomatic => '자동으로 초기화';

  @override
  String get resetToDefault => '기본값으로 재설정';

  @override
  String get resetUsage => '사용량 초기화';

  @override
  String get resetsIn => '초기화까지';

  @override
  String get restartContent =>
      '오디오 출력 장치를 변경하려면 애플리케이션을 재시작해야 적용됩니다.\\n\\n지금 재시작하시겠습니까?';

  @override
  String get restartNow => '지금 재시작';

  @override
  String get restartRequired => '재시작 필요';

  @override
  String get restoring => '복원 중';

  @override
  String get retryConnection => '연결 재시도';

  @override
  String get revert => '되돌리기';

  @override
  String get romajiHint => '로마자 / 음역 (선택 사항)...';

  @override
  String get russian => '러시아어';

  @override
  String get sakura => '사쿠라';

  @override
  String get sampleRateLabel => '샘플링 레이트';

  @override
  String get samplingRateLabel => '샘플링 레이트';

  @override
  String get save => '저장';

  @override
  String get saveAsNewPreset => '새 프리셋으로 저장';

  @override
  String get saveChangesToFile => '변경 사항을 파일에 저장';

  @override
  String get saveLabel => '저장';

  @override
  String get saveLocallyBtn => '로컬에 저장';

  @override
  String get saveLrcPrompt => '현재 가사를 오디오 파일 옆에 저장하시겠습니까?';

  @override
  String get saveLyricsTitle => '가사 저장';

  @override
  String get saveLyricsTooltip => '가사 저장';

  @override
  String get savePlaylistContent => '이 곡들로 새 플레이리스트를 만듭니다.';

  @override
  String savePlaylistTitle(String title) {
    return '$title을(를) 저장할까요?';
  }

  @override
  String get savePreset => '프리셋 저장';

  @override
  String savedAs(String name) {
    return '\"$name\"(으)로 저장됨!';
  }

  @override
  String savedAsFormat(String format) {
    return '$format(으)로 저장됨';
  }

  @override
  String savedSuccessfully(String extension) {
    return '$extension 파일로 성공적으로 저장되었습니다!';
  }

  @override
  String savedTo(String path) {
    return '\"$path\"에 저장됨';
  }

  @override
  String get saving => '저장 중...';

  @override
  String get scan => '스캔';

  @override
  String get scanToControlPlayback => '휴대폰으로 스캔하여 재생을 제어하세요.';

  @override
  String get scanning => '스캔 중...';

  @override
  String get scrollForLyrics => '가사를 보려면 스크롤';

  @override
  String get search => '검색';

  @override
  String get searchEngine => '검색 엔진';

  @override
  String searchFailedStatus(String error) {
    return '검색 실패: $error';
  }

  @override
  String get searchHint => '검색...';

  @override
  String get searchSongs => '곡 검색...';

  @override
  String get searchSongsOrAlbumsAndArtistsHint => '곡, 앨범 또는 아티스트 검색...';

  @override
  String get searchSpotify => 'Spotify 검색';

  @override
  String get searchSpotifyHint => 'Spotify 검색...';

  @override
  String get searchUsers => '사용자 검색...';

  @override
  String get searchYoutubeHint => 'YouTube 검색...';

  @override
  String get searching => '검색 중...';

  @override
  String searchingEngine(String engine, String keyword) {
    return '$engine에서 \'$keyword\' 검색 중...';
  }

  @override
  String get searchingSpotify => 'Spotify 검색 중...';

  @override
  String searchingSpotifyFor(String keyword) {
    return '\"$keyword\" Spotify 검색 중...';
  }

  @override
  String get searchingStatus => '검색 중';

  @override
  String get secondShort => '초';

  @override
  String get secsShort => '초';

  @override
  String get seeAll => '모두 보기';

  @override
  String get seeBenefitsBtn => '혜택 보기';

  @override
  String get seePremiumBenefits => '프리미엄 혜택 보기';

  @override
  String get selectDifferentFolder => '다른 폴더 선택';

  @override
  String get selectFolder => '폴더 선택';

  @override
  String get selectMatch => '일치 항목 선택';

  @override
  String get selectSongToEdit => '목록에서 편집할 곡 선택';

  @override
  String get selectStreamingQuality => '스트리밍 품질 선택';

  @override
  String get selectTrackToStart => '재생할 트랙 선택';

  @override
  String get selectVersion => '버전 선택';

  @override
  String session(String id) {
    return '세션: $id';
  }

  @override
  String get setCountryReleases => '새 릴리스 및 차트 국가 설정';

  @override
  String get setCustomTimer => '사용자 지정 타이머 설정';

  @override
  String get setEndTooltip => '종료를 현재 위치로 설정';

  @override
  String get setStartTooltip => '시작을 현재 위치로 설정';

  @override
  String get settings => '설정';

  @override
  String get share => '공유';

  @override
  String get shareCodeUsage => '친구에게 이 6자리 코드를 알려주어 재생 목록을 가져오게 하세요.';

  @override
  String get sharePlaylist => '재생 목록 공유';

  @override
  String sharePlaylistTitle(String name) {
    return '\"$name\" 공유';
  }

  @override
  String get sharedMode => '공유';

  @override
  String showAllTitles(int count) {
    return '$count개 타이틀 모두 보기';
  }

  @override
  String get showAnimatedWaves => '플레이어 바에 애니메이션 파동 표시';

  @override
  String get showDebugButton => '부동 디버그 버튼 표시';

  @override
  String get showInFolder => '폴더에 표시';

  @override
  String get showLess => '간략히 보기';

  @override
  String get showMore => '더 보기';

  @override
  String get showStatusDiscord => 'Discord에 상태 표시';

  @override
  String get showUnlockedOnly => '잠금 해제된 항목만 보기';

  @override
  String get shuffle => '셔플';

  @override
  String get shuffleAll => '모두 셔플';

  @override
  String shufflingArtist(String artistName) {
    return '$artistName 셔플 중...';
  }

  @override
  String get signInWithGoogle => 'Google로 로그인';

  @override
  String get signalOutput => '신호 출력';

  @override
  String get singleTracks => '개별 트랙';

  @override
  String get sleepTimer => '취침 예약';

  @override
  String get songAlreadyInPlaylist => '이미 플레이리스트에 있는 곡';

  @override
  String get songInformation => '곡 정보';

  @override
  String get songLabelUpper => '곡';

  @override
  String get songQueueTitle => '노래 대기열';

  @override
  String get songTitleKeyword => '곡 제목 또는 키워드';

  @override
  String get songs => '곡';

  @override
  String songsCount(int count) {
    return '$count곡';
  }

  @override
  String songsInLibrary(int count) {
    return '라이브러리에 $count곡 포함';
  }

  @override
  String songsLoadedCount(int count) {
    return '$count개의 곡 로드됨...';
  }

  @override
  String get southKorea => '대한민국';

  @override
  String get spanish => '스페인어';

  @override
  String get spectrumBars => '스펙트럼 바';

  @override
  String get spotify => 'Spotify';

  @override
  String get standardDesc => 'MP3 - 작은 파일 크기, 빠른 버퍼링';

  @override
  String get standardDownloadQueue => '표준 다운로드 대기열';

  @override
  String get standardQuality => '표준 (MP3)';

  @override
  String get start => '시작';

  @override
  String get startBulkProcess => '일괄 작업 시작';

  @override
  String get startLabel => '시작: ';

  @override
  String get startedDownloadingAll => '모든 곡 다운로드 시작됨...';

  @override
  String get stateDisabled => '비활성화됨';

  @override
  String get stateEnabled => '활성화됨';

  @override
  String get statisticsReset => '통계가 재설정되었습니다.';

  @override
  String get stats => '통계';

  @override
  String get statusLabel => '상태';

  @override
  String statusWithText(String status) {
    return '상태: $status';
  }

  @override
  String stopTimer(String time) {
    return '타이머 중지 ($time)';
  }

  @override
  String get streaming => '스트리밍';

  @override
  String get streamingQuality => '스트리밍 품질';

  @override
  String get success => '성공';

  @override
  String get superfanHeader => '슈퍼팬 업적';

  @override
  String get superfanTitles => '슈퍼팬';

  @override
  String get supportDeveloperTooltip => '전용 타이틀을 획득하기 위해 개발자 지원';

  @override
  String get switchToGridView => '그리드 보기로 전환';

  @override
  String get switchToListView => '목록 보기로 전환';

  @override
  String switchingTo(String title) {
    return '전환 중';
  }

  @override
  String get syncThemeAlbumArt => '앨범 아트와 테마 동기화';

  @override
  String get syncedMode => '동기화됨';

  @override
  String get system => '시스템';

  @override
  String get systemDefault => '시스템 기본값';

  @override
  String get targetLanguageLyrics => '가사 번역 대상 언어';

  @override
  String get thai => '태국어';

  @override
  String get tidalApiStatus => 'Tidal API';

  @override
  String get timeBasedTitles => '시간 기반';

  @override
  String get timeListened => '감상 시간';

  @override
  String get timeOverlordsHeader => '시간의 지배자';

  @override
  String timerSetForHours(int count) {
    return '$count시간 후에 중지되도록 타이머가 설정되었습니다';
  }

  @override
  String timerSetForMinutes(int count) {
    return '$count분 후에 중지되도록 타이머가 설정되었습니다';
  }

  @override
  String timerSetForSeconds(int count) {
    return '$count초 후에 중지되도록 타이머가 설정되었습니다';
  }

  @override
  String get tintBackground => '곡 색상으로 배경 및 비주얼라이저 물들이기';

  @override
  String get title => '제목';

  @override
  String get titleLabel => '제목';

  @override
  String todayLabel(String size) {
    return '오늘: $size';
  }

  @override
  String get toggleDebugButton => '부동 디버그 콘솔 표시 여부 전환';

  @override
  String get toggleDebugConsole => '부동 디버그 콘솔 표시 여부 전환';

  @override
  String get toggleLyrics => '가사 켜기/끄기';

  @override
  String top3GlobalTooltip(int weeks) {
    return '$weeks주 동안 세계 상위 3위 달성';
  }

  @override
  String get topArtist => '최고의 아티스트';

  @override
  String get topArtistAndTrack => '최고 아티스트 및 트랙';

  @override
  String get topArtists => '최고 아티스트';

  @override
  String topGlobalTooltip(int rank) {
    return '세계 상위 $rank위 달성';
  }

  @override
  String get topListeners => '최고 청취자';

  @override
  String get totalMinutesStat => '총 시간(분)';

  @override
  String get totalPlays => '총 재생 횟수';

  @override
  String get trackDetails => '트랙 상세 정보';

  @override
  String get trackNumber => '트랙 번호';

  @override
  String get tracks => '트랙';

  @override
  String get translateLabel => '번역';

  @override
  String get translateLyrics => '가사 번역';

  @override
  String get translateLyricsTooltip => '가사 번역';

  @override
  String get translationLanguage => '번역 언어';

  @override
  String get ttmlFormat => 'TTML (고정밀)';

  @override
  String get ttmlFormatDesc => 'AI 생성 및 세부 동기화에 더 적합합니다.';

  @override
  String get turnOffTimer => '타이머 끄기';

  @override
  String get unauthorize => '승인되지 않음';

  @override
  String get underDevelopment => '이 기능은 개발 중입니다';

  @override
  String get underwater => '수중';

  @override
  String get unitedKingdom => '영국';

  @override
  String get unitedStates => '미국';

  @override
  String get unknown => '알 수 없음';

  @override
  String get unknownArtist => '알 수 없는 아티스트';

  @override
  String get unknownDevice => '알 수 없는 장치';

  @override
  String get unlimitedAlacDownloads => '무제한 ALAC 다운로드';

  @override
  String get unlink => '연결 해제';

  @override
  String get unlinkAccount => '계정 연결 해제';

  @override
  String get unlinkAccountDesc => '통계 데이터는 이 기기에 남지만 더 이상 기기 간에 동기화되지 않습니다.';

  @override
  String get unlinkAccountQuestion => '계정 연결을 해제할까요?';

  @override
  String get unlinkFolder => '폴더 연결 해제 및 곡 목록 지우기';

  @override
  String get unlinkFolderClear => '폴더 연결 해제 및 곡 목록 지우기';

  @override
  String get unlockUnlimitedPremium => '무제한 프리미엄 잠금 해제';

  @override
  String unlockedCountLabel(int unlocked, int total) {
    return '$unlocked / $total 잠금 해제됨';
  }

  @override
  String get unmuteTooltip => '음소거 해제';

  @override
  String get unsavedChanges => '저장되지 않은 변경 사항이 있습니다';

  @override
  String get upNext => '다음에 재생';

  @override
  String upNextCount(int count) {
    return '다음에 재생 ($count)';
  }

  @override
  String get upNextSection => '다음에 재생';

  @override
  String get updateAvailableTitle => '업데이트 가능';

  @override
  String updateAvailableVersion(String version) {
    return '새 버전($version)을 사용할 수 있습니다.';
  }

  @override
  String updateFailed(String error) {
    return '업데이트 실패: $error';
  }

  @override
  String get updateNow => '지금 업데이트';

  @override
  String get updatePrompt => '지금 다운로드하여 설치하시겠습니까?';

  @override
  String get updatingYtDlp => 'yt-dlp 업데이트 중';

  @override
  String get usbAudioBypass => 'USB 오디오 우회 (베타) - Android 13 이하용 직접 DAC 출력';

  @override
  String get usbAudioBypassBeta => 'USB 오디오 우회 (베타) - Android 13 이하용 직접 DAC 출력';

  @override
  String get useDarkTheme => '다크 테마 사용';

  @override
  String get useMixedColors => '혼합 색상 사용 (동기화 무시)';

  @override
  String get useSameEmailCheckStatus => '상태를 자동으로 확인하려면 앱 내와 동일한 이메일을 사용하세요.';

  @override
  String usedToday(int used, int max) {
    return '오늘 $used / $max 사용됨';
  }

  @override
  String get verifiedDeveloper => '인증된 개발자';

  @override
  String get version => '버전';

  @override
  String versionLabel(String version) {
    return '버전 $version';
  }

  @override
  String get vietnamese => '베트남어';

  @override
  String get viewQueue => '대기열 보기';

  @override
  String get visualizer => '비주얼라이저';

  @override
  String get visualizerStyle => '비주얼라이저 스타일';

  @override
  String get waitingForServerResponse => '서버 응답 대기 중...';

  @override
  String get wasapiExclusive => 'WASAPI 독점 모드';

  @override
  String get weekly => '주간';

  @override
  String get weeks => '주';

  @override
  String get winter => '겨울';

  @override
  String get worldRanking => '월드 랭킹';

  @override
  String get worldTopArtists => '세계 최고 아티스트';

  @override
  String get year => '연도';

  @override
  String get youMayLike => '추천 곡';

  @override
  String get yourPlaylists => '나의 플레이리스트';

  @override
  String get yourTopMix => '나의 믹스';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytDlpUpdateAvailable => 'yt-dlp의 새 버전을 사용할 수 있습니다.';
}
