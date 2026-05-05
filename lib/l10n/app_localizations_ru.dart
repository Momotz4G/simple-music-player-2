// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get aboutEducationalPurpose =>
      'Это приложение разработано только для индивидуальных и образовательных целей.';

  @override
  String get aboutLicenses => 'О программе и Лицензии';

  @override
  String get aboutNotForCommercial => 'Не для коммерческого использования.';

  @override
  String get accentColor => 'Акцентный цвет';

  @override
  String get access => 'Доступ';

  @override
  String get accessCode => 'Код доступа';

  @override
  String get accountDataMergeDesc =>
      'При синхронизации ваше имя профиля и аватар будут обновлены, но минуты прослушивания на текущем устройстве будут успешно объединены с общим итогом аккаунта.';

  @override
  String get accountLinked => 'Аккаунт привязан';

  @override
  String get accountLinkedSuccessfully => 'Аккаунт успешно привязан!';

  @override
  String get achievementsUnlocked => 'Разблокированные достижения';

  @override
  String get activeNoResampling => 'Активен (Без ресемплинга)';

  @override
  String get add => 'Добавить';

  @override
  String get addFiles => 'Добавить файлы';

  @override
  String get addFolder => 'Добавить папку';

  @override
  String get addFoldersScan => 'Добавить папки для сканирования';

  @override
  String get addToFavorite => 'Добавить в избранное';

  @override
  String get addToPlaylist => 'Добавить в плейлист';

  @override
  String get addToQueue => 'Добавить в очередь';

  @override
  String addedFolder(Object folder) {
    return 'Добавлена папка: $folder';
  }

  @override
  String get addedToLikedSongs => 'Добавлено в любимые песни';

  @override
  String get addedToPlaylistSuccess => 'Добавлено в плейлист';

  @override
  String get addedToQueue => 'Добавлено в очередь';

  @override
  String get album => 'Альбом';

  @override
  String get albumAddedToPlaylists => 'Альбом добавлен в плейлисты';

  @override
  String get albumLabel => 'Альбом';

  @override
  String get albumRemovedFromPlaylists => 'Альбом удален из плейлистов';

  @override
  String get albums => 'Альбомы';

  @override
  String get allDownloadsRemoved => 'Все загрузки удалены';

  @override
  String get allRightsReserved => 'Все права защищены.';

  @override
  String get allTime => 'За все время';

  @override
  String get alreadyInLikedSongs => 'Уже в любимых песнях';

  @override
  String get android14BitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidAudioEffectsNote =>
      'Примечание: Аудиоэффекты доступны только на Android.';

  @override
  String get androidAudioTrack => 'Android AudioTrack';

  @override
  String get androidBitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidMixer => 'Android Mixer';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get applyOnRestart =>
      'Изменения будут применены при следующем запуске.';

  @override
  String get arabic => 'Арабский';

  @override
  String get artist => 'Исполнитель';

  @override
  String get artistLabel => 'Исполнитель';

  @override
  String get artists => 'Исполнители';

  @override
  String get atmospheres => 'Атмосферы';

  @override
  String get audioFormat => 'Аудио формат';

  @override
  String get audioOutput => 'Аудиовыход';

  @override
  String get audioOutputDevice => 'Устройство вывода звука';

  @override
  String get audioQuality => 'Качество звука';

  @override
  String get audioSource => 'Источник аудио';

  @override
  String get audiophileDAC =>
      'Включить при воспроизведении на аудиофильских ЦАП (требуется перезагрузка)';

  @override
  String get autoAddSimilar =>
      'Автоматически добавлять похожие песни в конец очереди';

  @override
  String get autoClearAfter24h => 'Через 24 часа';

  @override
  String get autoClearAfter7d => 'Через 7 дней';

  @override
  String get autoClearCache => 'Автоматическая очистка кэша';

  @override
  String get autoClearDisabled => 'Отключено';

  @override
  String get autoClearEvery30m => 'Каждые 30 мин (Только при прослушивании)';

  @override
  String get autoClearOnClose => 'При закрытии приложения';

  @override
  String get autoFixComingSoon => 'Авто-исправление (Скоро)';

  @override
  String get autoRestartNotSupported =>
      'Автоматическая перезагрузка не поддерживается. Пожалуйста, перезапустите вручную.';

  @override
  String autoTagContent(int count, String sourceName) {
    return 'Это приведет к поиску всех $count песен из «$sourceName» на Spotify и автоматической перезаписи тегов.\\n\\nЭто действие необратимо.';
  }

  @override
  String autoTagTitle(String sourceName) {
    return '⚠️ Авто-теги для $sourceName?';
  }

  @override
  String get automatic => 'Автоматически';

  @override
  String automaticTitleLabel(String title) {
    return 'Автоматически: $title';
  }

  @override
  String get autumn => 'Осень';

  @override
  String get avatarPickerDesc => 'Выберите шаблон или импортируйте свое фото';

  @override
  String get beFirstToClaim => 'Станьте первым, кто займет первое место!';

  @override
  String get behavioralHeader => 'ПОВЕДЕНЧЕСКИЕ ДОСТИЖЕНИЯ';

  @override
  String get behavioralTitles => 'ПОВЕДЕНЧЕСКИЙ';

  @override
  String get binariesUpdateRequired => 'Требуется обновление бинарных файлов';

  @override
  String get bitDepthLabel => 'Разрядность (бит)';

  @override
  String get bitPerfectEnabled =>
      'Режим Bit-perfect включен. Регулировка громкости может не работать.';

  @override
  String get bitPerfectWindows =>
      'Bit-perfect аудио с автоматической частотой дискретизации (требуется перезагрузка)';

  @override
  String get bitrateLabel => 'Битрейт';

  @override
  String get bitsLabel => 'Бит';

  @override
  String get brazil => 'Бразилия';

  @override
  String get browse => 'Обзор';

  @override
  String get bypassSystemMixer => 'Обходить системный микшер для USB ЦАП';

  @override
  String get bypassedBitPerfect => 'Обход (Bit-Perfect)';

  @override
  String get cacheCleared => 'Кэш успешно очищен!';

  @override
  String get cached => 'Кэшировано';

  @override
  String get cancel => 'Отмена';

  @override
  String get championChampionTooltip => 'Станьте Топ-1 мира в течение 5 недель';

  @override
  String get change => 'Изменить';

  @override
  String get changeFolder => 'Изменить папку';

  @override
  String get changeFormatInSettings =>
      'Пожалуйста, измените формат вывода в настройках';

  @override
  String get changeLabel => 'ИЗМЕНИТЬ';

  @override
  String get changeLanguage => 'Изменить язык приложения';

  @override
  String get changesApplyRestart =>
      'Изменения будут применены при следующем запуске.';

  @override
  String get changingAudioDeviceRestart =>
      'Для применения изменений аудиоустройства требуется перезагрузка приложения.\\n\\nПерезагрузить сейчас?';

  @override
  String get channelsLabel => 'Каналы';

  @override
  String get checkAgain => 'Проверить снова';

  @override
  String get checkInternetConnection => 'Проверьте интернет-соединение';

  @override
  String get checkNetworkTryAgain => 'Проверьте сеть и попробуйте снова';

  @override
  String get chinese => 'Китайский';

  @override
  String get chooseAccentColor => 'Выберите предпочитаемый статический цвет';

  @override
  String get chooseAnimationType => 'Выберите тип анимации';

  @override
  String get chooseArtist => 'ВЫБРАТЬ ИСПОЛНИТЕЛЯ';

  @override
  String get chooseAvatar => 'Выбрать аватар';

  @override
  String get chooseYourTitle => 'Выберите свой титул';

  @override
  String get circularPulse => 'Круговой импульс';

  @override
  String get clearAll => 'Очистить все';

  @override
  String get clearHistory => 'Очистить историю';

  @override
  String get clearImported => 'Очистить импортированные';

  @override
  String get clearMetadataCache => 'Очистить кэш метаданных и обложек';

  @override
  String get clearPlayHistory => 'Очистить историю и время прослушивания';

  @override
  String get clearStreamingCache => 'Очистить кэш стриминга';

  @override
  String get close => 'Закрыть';

  @override
  String get cloud => 'Облако';

  @override
  String get codeCopied => 'Код скопирован в буфер обмена!';

  @override
  String get codeMust6Digits => 'Код должен состоять из 6 цифр';

  @override
  String get codecLabel => 'Кодек';

  @override
  String get comingSoon => 'Скоро будет';

  @override
  String get community => 'Сообщество';

  @override
  String get competitiveTitles => 'КОНКУРЕНТНЫЙ';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get connect => 'Подключить';

  @override
  String get connectToADevice => 'Подключиться к устройству';

  @override
  String get connected => 'Подключено';

  @override
  String connectedToDac(String deviceName) {
    return 'Подключено к $deviceName - USB Bypass активен';
  }

  @override
  String get connectedUsbDacs => 'Подключенные USB ЦАП:';

  @override
  String get connecting => 'Подключение...';

  @override
  String get connectionLostLeaderboard => 'Соединение потеряно';

  @override
  String get connectionLostLeaderboardDesc =>
      'Для синхронизации статистики и получения мировых рейтингов требуется активное соединение с глобальным лидербордом.';

  @override
  String consecutivePlaysTooltip(int count) {
    return 'Слушайте одну песню $count раз подряд';
  }

  @override
  String get contentRegion => 'Регион контента';

  @override
  String get copyCode => 'Копировать код';

  @override
  String get couldNotDownloadFlac => 'Не удалось загрузить FLAC.';

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count песен',
      few: '$count песни',
      one: '1 песня',
    );
    return '$_temp0';
  }

  @override
  String get createPlaylist => 'Создать плейлист';

  @override
  String creatingPlaylistWithTracks(int count) {
    return 'Создание плейлиста с $count треками...';
  }

  @override
  String get crossfade => 'Crossfade';

  @override
  String crossfadeDesc(String seconds) {
    return 'Плавный переход между треками ($seconds с)';
  }

  @override
  String get crownedChampionTitlesHeader => 'ТИТУЛЫ КОРОНОВАННЫХ ЧЕМПИОНОВ';

  @override
  String get customDevice => 'Пользовательское устройство';

  @override
  String get customSelected => 'Выбрано вручную';

  @override
  String get customTime => 'Своё время';

  @override
  String get cyberpunk => 'Киберпанк';

  @override
  String get daily => 'Ежедневно';

  @override
  String get darkMode => 'Темный режим';

  @override
  String get dataCleanup => 'Данные и очистка';

  @override
  String get dataUsage => 'Использование данных';

  @override
  String get daysShort => 'Д';

  @override
  String get debugging => 'Отладка';

  @override
  String get delete => 'Удалить';

  @override
  String get deleteDownloadsConfirm =>
      'Это удалит все загруженные на это устройство песни для этого плейлиста.';

  @override
  String get deleteDownloadsTitle => 'Удалить загрузки?';

  @override
  String deleteFileContent(String filename) {
    return 'Удалить «$filename»?\\nЭту операцию нельзя отменить.';
  }

  @override
  String get deleteFileTitle => 'Удалить файл?';

  @override
  String get deletePlaylist => 'Удалить плейлист';

  @override
  String deletePlaylistConfirm(String name) {
    return 'Вы уверены, что хотите удалить «$name»?';
  }

  @override
  String get deletePlaylistPermanentConfirm =>
      'Вы уверены, что хотите удалить этот плейлист? (Это действие нельзя отменить)';

  @override
  String get deletePlaylistTitle => 'Удалить плейлист?';

  @override
  String get deletePreset => 'Удалить пресет';

  @override
  String get desertMirage => 'Пустынный мираж';

  @override
  String get developerExclusiveTooltip =>
      'Эксклюзивно для разработчиков этого приложения';

  @override
  String deviceNameLabel(String deviceName) {
    return 'Устройство: $deviceName';
  }

  @override
  String get disableCanvas => 'Отключить Canvas';

  @override
  String get disableRomanization => 'Отключить романизацию';

  @override
  String get disablingSharingWarning =>
      'При отключении общего доступа код и данные будут навсегда удалены с сервера для экономии места.';

  @override
  String get discNumber => '№ диска';

  @override
  String get discography => 'Дискография';

  @override
  String get discordRPC => 'Discord Presence';

  @override
  String get doYouRemember => 'Вы помните?';

  @override
  String get donate => 'Пожертвовать';

  @override
  String get download => 'Скачать';

  @override
  String get downloadAll => 'Скачать всё';

  @override
  String get downloadComplete => 'Загрузка завершена';

  @override
  String get downloadCompleteNotification => 'Загрузка завершена';

  @override
  String get downloadError => 'Ошибка загрузки';

  @override
  String get downloadFailed => 'Загрузка не удалась';

  @override
  String get downloadLocation => 'Место загрузки';

  @override
  String get downloadPathReset => 'Путь загрузки сброшен по умолчанию.';

  @override
  String downloadPathUpdated(Object path) {
    return 'Путь загрузки обновлен: $path';
  }

  @override
  String get downloadSong => 'Скачать песню';

  @override
  String get downloadStarted => 'Загрузка началась';

  @override
  String downloadedTo(String path) {
    return 'Загружено в: $path';
  }

  @override
  String get downloading => 'Загрузка';

  @override
  String get downloadingFlac => 'Загрузка FLAC';

  @override
  String downloadingFormat(String format) {
    return 'Загрузка $format';
  }

  @override
  String get downloadingUpdate => 'Скачивание обновления';

  @override
  String get downloads => 'Загрузки';

  @override
  String get dspLabel => 'DSP';

  @override
  String get editMetadata => 'Редактировать метаданные';

  @override
  String get editNickname => 'Изменить никнейм';

  @override
  String get editor => 'Редактор';

  @override
  String get emptyMailbox => 'Очистить почтовый ящик';

  @override
  String get emptyMailboxDesc => 'Это навсегда удалит все сообщения.';

  @override
  String get emptyMailboxTitle => 'Очистить почтовый ящик?';

  @override
  String get emptyPlaylist => 'Пустой плейлист';

  @override
  String get emptyPlaylistSubtitle => 'Создать новый пустой плейлист';

  @override
  String get enableAlphabetIndexer => 'Включить алфавитный указатель прокрутки';

  @override
  String get enableAlphabetIndexerSubtitle =>
      'Показывать индекс боковой панели A-Z в мобильном списке';

  @override
  String get enableBarVisualizer => 'Включить полосовой визуализатор';

  @override
  String get endlessQueue => 'Бесконечная очередь';

  @override
  String get engineLabel => 'Движок';

  @override
  String get english => 'Английский';

  @override
  String get enterAdminAccessCode =>
      'Пожалуйста, введите административный код доступа';

  @override
  String get enterAdminCode =>
      'Пожалуйста, введите административный код доступа';

  @override
  String get enterDuration => 'Введите длительность...';

  @override
  String get enterPresetName => 'Введите имя пресета (например, Мой Бас)';

  @override
  String get enterShareCode => 'Введите 6-значный код общего доступа';

  @override
  String get eqLabel => 'EQ';

  @override
  String get equalizer => 'Эквалайзер';

  @override
  String get equipTitle => 'ЭКИПИРОВАТЬ ТИТУЛ';

  @override
  String get equipped => 'ЭКИПИРОВАНО';

  @override
  String get error => 'Ошибка';

  @override
  String get errorCouldNotCreateSession => 'Ошибка: Не удалось создать сессию.';

  @override
  String errorDeleting(String error) {
    return 'Ошибка при удалении: $error';
  }

  @override
  String get errorSearchingStream => 'Ошибка при поиске стрима.';

  @override
  String get exclusiveMode => 'Эксклюзивный';

  @override
  String get exclusiveModeWarning =>
      'Предупреждение: Эксклюзивный режим работает лучше, если вы выберете конкретное устройство выше вместо системного по умолчанию.';

  @override
  String get exclusiveTitles => 'ЭКСКЛЮЗИВНЫЙ';

  @override
  String get exclusiveTitlesHeader => 'ЭКСКЛЮЗИВНЫЕ ТИТУЛЫ';

  @override
  String get exclusiveWarning =>
      'Предупреждение: Эксклюзивный режим работает лучше, если вы выберете конкретное устройство выше вместо системного по умолчанию.';

  @override
  String get exitApp => 'Выход';

  @override
  String get expand => 'Развернуть';

  @override
  String get externalFiles => 'Внешние файлы';

  @override
  String get fadingAtEnd => 'Таймер сна: Затухание в конце трека...';

  @override
  String get failedDisableSharing => 'Не удалось отключить общий доступ.';

  @override
  String get failedEnableSharing =>
      'Не удалось включить общий доступ. Проверьте соединение.';

  @override
  String get failedFetchPlaylistInfo =>
      'Не удалось получить информацию о плейлисте';

  @override
  String get failedToConnectDac =>
      'Не удалось подключиться к ЦАП. Проверьте разрешения USB.';

  @override
  String get failedToGenerateCode =>
      'Не удалось создать код общего доступа. Проверьте соединение.';

  @override
  String get failedToSetAvatar => 'Не удалось установить шаблон аватара';

  @override
  String get failedToUpdateMetadata => 'Не удалось обновить метаданные';

  @override
  String get favoriteTrack => 'Любимый трек';

  @override
  String get fetchingCanvas => 'Загрузка Canvas...';

  @override
  String get fetchingLossless => 'Получение качества без потерь...';

  @override
  String get fetchingLosslessAudio => 'Получение аудио без потерь...';

  @override
  String get fetchingMetadataSpotify => 'Получение метаданных из Spotify...';

  @override
  String get fetchingPlaylist => 'Получение плейлиста...';

  @override
  String get fetchingPlaylistInfo => 'Получение информации о плейлисте...';

  @override
  String get fetchingSharedPlaylist => 'Получение общего плейлиста...';

  @override
  String fetchingTracksFrom(String name) {
    return 'Получение треков из \"$name\"...';
  }

  @override
  String get fileLocation => 'Местоположение файла';

  @override
  String get fileMissingHistory => 'Файл отсутствует и не найден в истории.';

  @override
  String get fileName => 'Имя файла';

  @override
  String get fileSizeLabel => 'Размер файла';

  @override
  String get files => 'Файлы';

  @override
  String get filters => 'Фильтры';

  @override
  String get findingBestMatchYoutube =>
      'Поиск лучшего совпадения на YouTube...';

  @override
  String get findingStream => 'Поиск источника стриминга...';

  @override
  String get finishUpdate => 'Завершить обновление';

  @override
  String get finishes => 'Места';

  @override
  String get fixAll => 'Исправить всё';

  @override
  String get flacError => 'Ошибка FLAC';

  @override
  String get flacNote =>
      'Примечание: FLAC доступен только для загрузки отдельных треков. Загрузка плейлистов будет использовать формат M4A.';

  @override
  String get flacSavedToDownloads => 'FLAC сохранен в папку загрузок';

  @override
  String get flacUnavailable => 'FLAC недоступен';

  @override
  String get flacUnavailableDesc =>
      'FLAC недоступен, загрузка не удалась. Попробуйте изменить настройки.';

  @override
  String get flacUnavailableNotification => 'FLAC недоступен';

  @override
  String get fluidWave => 'Плавная волна';

  @override
  String folderPath(String path) {
    return 'Папка: $path';
  }

  @override
  String get folders => 'Папки';

  @override
  String get formatLabel => 'Формат';

  @override
  String get formatSaved => 'Формат сохранен!';

  @override
  String foundExistingAccount(String name) {
    return 'Мы нашли существующий аккаунт для \'$name\'.';
  }

  @override
  String foundResults(int songCount, int albumCount, int artistCount) {
    return 'Найдено: $songCount песен, $albumCount альбомов, $artistCount исполнителей.';
  }

  @override
  String foundYoutubeResults(int count) {
    return 'Найдено $count результатов на YouTube';
  }

  @override
  String freeUpSpace(String size) {
    return 'Освободить место (Текущее: $size)';
  }

  @override
  String get french => 'Французский';

  @override
  String fromLibraryCount(int count) {
    return 'Из библиотеки ($count)';
  }

  @override
  String get fromLibrarySection => 'Из библиотеки';

  @override
  String get fullScreenPlayerTooltip => 'Полноэкранный плеер';

  @override
  String get galacticSpace => 'Галактический космос';

  @override
  String get gaplessPlayback => 'Бесшовное Воспроизведение';

  @override
  String get gaplessPlaybackDesc => 'Устранить паузы между треками';

  @override
  String get general => 'Общие';

  @override
  String get generatingShareCode => 'Создание кода общего доступа...';

  @override
  String get genre => 'Жанр';

  @override
  String get german => 'Немецкий';

  @override
  String get globalLeaderboard => 'Глобальный список лидеров';

  @override
  String get globalMailbox => 'Глобальный почтовый ящик';

  @override
  String get globalRank => 'Глобальный ранг';

  @override
  String get globalRankings => 'Глобальный рейтинг';

  @override
  String get globalRankingsDesc =>
      'Посмотрите лучших слушателей за день, неделю и все время!';

  @override
  String get goToArtist => 'Перейти к исполнителю';

  @override
  String get goToLocalLibraryToSelect =>
      'Перейдите в локальную библиотеку, чтобы выбрать папку.';

  @override
  String get goodAfternoon => 'Добрый день';

  @override
  String get goodEvening => 'Добрый вечер';

  @override
  String get goodMorning => 'Доброе утро';

  @override
  String get googleAccount => 'Аккаунт Google';

  @override
  String get grantAccess => 'Предоставить доступ';

  @override
  String get grantPermission => 'Предоставить разрешение';

  @override
  String get hallOfFameHeader => 'ДОСТИЖЕНИЯ ЗАЛА СЛАВЫ';

  @override
  String get hallOfFameTitles => 'ЗАЛ СЛАВЫ';

  @override
  String get hideCanvas =>
      'Не показывать видео Spotify Canvas, показывать обложку альбома вместо этого';

  @override
  String get hideRomajiPinyin =>
      'Не показывать Romaji/Pinyin под корейскими, японскими или китайскими текстами';

  @override
  String get hideTranslation => 'Скрыть перевод';

  @override
  String get highDesc =>
      'M4A - лучший звук, сбалансированная производительность';

  @override
  String get highQuality => 'Высокое качество (M4A)';

  @override
  String get hindi => 'Хинди';

  @override
  String get history => 'История';

  @override
  String get historySection => 'История';

  @override
  String get home => 'Главная';

  @override
  String get hourShort => 'ч';

  @override
  String hoursDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count часов',
      few: '$count часа',
      one: '1 час',
    );
    return '$_temp0';
  }

  @override
  String get hoursShort => 'Ч';

  @override
  String get ignoreSubfolderScan => 'Игнорировать сканирование подпапок';

  @override
  String get importAdditionalPaths => 'Импорт дополнительных путей';

  @override
  String get importChoice => 'Импортировать';

  @override
  String importFailed(String error) {
    return 'Ошибка импорта: $error';
  }

  @override
  String get importFromGallery => 'Импортировать из галереи';

  @override
  String get importFromSpotify => 'Импорт из Spotify';

  @override
  String get importFromSpotifySubtitle => 'Вставьте ссылку на плейлист Spotify';

  @override
  String get importFromYoutubeMusic => 'Импорт из YouTube Music';

  @override
  String get importFromYoutubeMusicSubtitle =>
      'Вставьте ссылку на плейлист YouTube Music';

  @override
  String get importLabel => 'Импорт';

  @override
  String get importLyricsFile => 'Импортировать файл текста';

  @override
  String get importLyricsTooltip => 'Импортировать текст';

  @override
  String get importSpotifyPlaylist => 'Импортировать плейлист Spotify';

  @override
  String get importViaCode => 'Импорт по коду';

  @override
  String get importViaCodeSubtitle =>
      'Импорт плейлиста, которым поделился друг';

  @override
  String get importYoutubeMusicPlaylist =>
      'Импортировать плейлист YouTube Music';

  @override
  String importedPlaylistName(String name) {
    return 'Плейлист \"$name\" успешно импортирован!';
  }

  @override
  String importedTracks(int count) {
    return 'Успешно импортировано $count треков!';
  }

  @override
  String get indonesia => 'Индонезия';

  @override
  String get indonesian => 'Индонезийский';

  @override
  String get inputLabel => 'Вход';

  @override
  String get installNow => 'Установить сейчас';

  @override
  String get integration => 'Интеграция';

  @override
  String get invalidAccessCode => 'Неверный код доступа';

  @override
  String get invalidCode => 'Неверный код доступа';

  @override
  String get invalidSpotifyUrl => 'Неверный URL-адрес плейлиста Spotify';

  @override
  String get invalidYoutubeMusicUrl =>
      'Неверная ссылка на плейлист YouTube Music';

  @override
  String get japan => 'Япония';

  @override
  String get japanese => 'Японский';

  @override
  String get joinUs => 'Присоединяйтесь к нам';

  @override
  String get jumpBackIn => 'Продолжить прослушивание';

  @override
  String get justEnjoyVibes => 'Просто наслаждайтесь атмосферой.';

  @override
  String get korean => 'Корейский';

  @override
  String get language => 'Язык';

  @override
  String last30DaysLabel(String size) {
    return 'Последние 30 дней: $size';
  }

  @override
  String last7DaysLabel(String size) {
    return 'Последние 7 дней: $size';
  }

  @override
  String get later => 'Позже';

  @override
  String get library => 'Медиатека';

  @override
  String get libraryData => 'Данные библиотеки';

  @override
  String get libraryNotLoaded => 'Библиотека не загружена.';

  @override
  String get libraryPathReset => 'Путь к библиотеке сброшен.';

  @override
  String get likedSongs => 'Любимые песни';

  @override
  String get linkAccount => 'Привязать аккаунт';

  @override
  String get linkAccountDesc =>
      'Синхронизируйте и восстанавливайте свой прогресс с помощью Google';

  @override
  String listenMinutesTooltip(String minutes) {
    return 'Слушайте музыку $minutes минут';
  }

  @override
  String get listeningParty => 'Прослушивание в компании';

  @override
  String get listeningStats => 'Статистика прослушивания';

  @override
  String get loadingCanvas => 'Загрузка Canvas...';

  @override
  String get loadingDevices => 'Загрузка устройств...';

  @override
  String get loadingError =>
      'Не удалось загрузить данные. Пожалуйста, попробуйте еще раз.';

  @override
  String get loadingLyrics => 'Загрузка текста...';

  @override
  String get localPlayHistorySaved =>
      'Ваша локальная история прослушиваний не будет удалена.';

  @override
  String get local_library => 'Локальная библиотека';

  @override
  String get lockedAtmosphere => 'Заблокировано, когда активна атмосфера';

  @override
  String get losslessDesc => 'FLAC - качество без потерь от Deezer/Tidal';

  @override
  String get losslessNote =>
      'Будет использоваться FLAC без потерь, если доступно на Deezer/Tidal. В противном случае вернется к M4A.';

  @override
  String get losslessQuality => 'Без потерь (Авто)';

  @override
  String get lunarNewYear => 'Лунный Новый год';

  @override
  String get lyricsByLRCLIB => 'Текст от LRCLIB';

  @override
  String get lyricsSaveError => 'Ошибка при сохранении текста';

  @override
  String get lyricsSavedSuccess => 'Текст сохранен в файл .lrc';

  @override
  String get lyricsTooltip => 'Текст песни';

  @override
  String get madeForYou => 'Создано для вас';

  @override
  String get manualSearch => 'Поиск вручную';

  @override
  String get mergeAccountData => 'Объединить данные аккаунта?';

  @override
  String get metadataCacheCleared =>
      'Кэш метаданных очищен, начато сканирование библиотеки';

  @override
  String get metadataEditorInfo =>
      'Вы можете быстро найти и исправить данные в редакторе метаданных.';

  @override
  String get metadataEditorNote =>
      'Примечание: После появления статуса «Успешно сохранено» обложка альбома может измениться. Это не ошибка, а проблема с кэшем приложения, которую мы решаем. Проверьте в файловом менеджере.';

  @override
  String get metadataUpdated => 'Метаданные обновлены';

  @override
  String get metadata_editor => 'Редактор метаданных';

  @override
  String get min => 'мин';

  @override
  String get minShortLabel => 'мин';

  @override
  String get miniPlayer => 'Мини-плеер';

  @override
  String get minimizeToTray => 'Свернуть в трей';

  @override
  String get minimizeToTrayDescription =>
      'Закрыть приложение в системный трей вместо выхода';

  @override
  String get minsShort => 'М';

  @override
  String get minsShortLabel => 'мин';

  @override
  String get minuteShort => 'мин';

  @override
  String get minutes => 'минут';

  @override
  String minutesDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минут',
      few: '$count минуты',
      one: '1 минута',
    );
    return '$_temp0';
  }

  @override
  String get moreOptions => 'Дополнительные опции';

  @override
  String get moreOptionsTooltip => 'Дополнительные опции';

  @override
  String get mostListened => 'Самые прослушиваемые';

  @override
  String get mostListenedArtist => 'Самый прослушиваемый исполнитель';

  @override
  String get musicFolderLocation => 'Расположение папки с музыкой';

  @override
  String get musicSearch => 'Поиск музыки';

  @override
  String musicWillStopIn(String label) {
    return 'Музыка остановится через $label';
  }

  @override
  String get muteTooltip => 'Выключить звук';

  @override
  String myTopTrackOn(String header) {
    return 'Мой $header на Simple Player! 🎵';
  }

  @override
  String get nativeRate => 'Нативная частота';

  @override
  String get navigation => 'Навигация';

  @override
  String get newPlaylist => 'Новый плейлист';

  @override
  String get nextTrack => 'Следующий трек';

  @override
  String get nicknameHint => 'Введите никнейм';

  @override
  String get nicknameLabel => 'Никнейм';

  @override
  String get nicknameRequired => 'Требуется псевдоним';

  @override
  String get nicknameRequiredDesc =>
      'Вам нужно сначала установить свой псевдоним, чтобы просматривать глобальный список лидеров!';

  @override
  String get nicknameTakenDesc =>
      'Этот никнейм уже используется. Пожалуйста, выберите другой.';

  @override
  String get nicknameTakenTitle => 'Никнейм занят';

  @override
  String get noAlbumsFound => 'Альбомы не найдены';

  @override
  String get noArtistStatsYet => 'Статистики исполнителей пока нет.';

  @override
  String get noArtistsFound => 'Исполнители не найдены.';

  @override
  String get noDownloadsFound => 'Загрузки не найдены';

  @override
  String get noFolderSelected => 'Папка не выбрана';

  @override
  String get noHistoryYet => 'Истории пока нет';

  @override
  String get noInternetConnection => 'Нет подключения к интернету';

  @override
  String get noLyricsAvailable => 'Текст песни недоступен';

  @override
  String get noMessages => 'В вашем почтовом ящике нет сообщений';

  @override
  String get noMusicPlaying => 'Музыка не воспроизводится';

  @override
  String get noPlaylistsFound => 'Плейлисты не найдены';

  @override
  String get noPlaylistsYet => 'Плейлистов пока нет';

  @override
  String get noRankingsYet => 'Рейтингов за этот период еще нет.';

  @override
  String get noResultsFound => 'Результаты не найдены';

  @override
  String get noSongPlaying => 'Музыка не воспроизводится';

  @override
  String get noSongsAdded => 'Песни пока не добавлены';

  @override
  String get noSongsInFolder => 'В этой папке песен не найдено.';

  @override
  String get noSpotifyResults => 'Результатов в Spotify не найдено.';

  @override
  String get noStatsYet => 'Статистики пока нет.';

  @override
  String get noStreamMatch => 'Совпадений для стриминга не найдено.';

  @override
  String get noSuggestionsFound => 'Предложений не найдено.';

  @override
  String get noSyncedLyricsFound => 'Синхронизированный текст не найден';

  @override
  String get noTracksFound => 'Треки в плейлисте не найдены';

  @override
  String get noUsbDacDetected =>
      'USB ЦАП не обнаружен. Подключите аудиоустройство USB и нажмите «Сканировать».';

  @override
  String get noUsersFound => 'Пользователи не найдены';

  @override
  String get noYoutubeResults => 'Результатов на YouTube не найдено';

  @override
  String get none => 'Нет';

  @override
  String get nordicAurora => 'Северное сияние';

  @override
  String notRank(int rank) {
    return 'Не ранг $rank';
  }

  @override
  String get notRanked => 'Без ранга';

  @override
  String get notRankedTop3 => 'ВНЕ ТОП-3';

  @override
  String get nowPlaying => 'Сейчас играет';

  @override
  String get nowPlayingHeader => 'Сейчас играет';

  @override
  String get nowPlayingSection => 'Сейчас играет';

  @override
  String get offline => 'Оффлайн';

  @override
  String get offlineStatus => 'Не в сети';

  @override
  String get ok => 'OK';

  @override
  String get online => 'В сети';

  @override
  String get onlyScanSelected =>
      'Сканировать только выбранные папки (включено по умолчанию)';

  @override
  String get opacity => 'Прозрачность';

  @override
  String opacityLabel(int percent) {
    return 'Прозрачность: $percent%';
  }

  @override
  String get openProfile => 'Открыть профиль';

  @override
  String get openSourceLicenses => 'Лицензии с открытым исходным кодом';

  @override
  String get outputLabel => 'Выход';

  @override
  String get overwrite => 'Перезаписать';

  @override
  String get overwriteLrcWarning =>
      'Локальный файл .lrc для этой песни уже существует.\\nХотите перезаписать его?';

  @override
  String get parsingPlaylistData => 'Анализ данных плейлиста...';

  @override
  String get pathLabel => 'Путь';

  @override
  String get permissionRequired => 'Требуется разрешение';

  @override
  String get permissionRequiredDesc =>
      'Разрешение «Доступ ко всем файлам» необходимо для редактирования тегов. Это позволяет изменять ваши музыкальные файлы напрямую.';

  @override
  String get play => 'Играть';

  @override
  String playCountLabel(int count) {
    return '$count воспроизведений';
  }

  @override
  String get playNext => 'Играть следующим';

  @override
  String get playPause => 'Воспроизвести / Пауза';

  @override
  String get playQueue => 'Играть очередь';

  @override
  String get playback => 'Воспроизведение';

  @override
  String get playbackError => 'Ошибка воспроизведения';

  @override
  String get player => 'Игрок';

  @override
  String get playingFromAlbum => 'Воспроизведение из альбома';

  @override
  String get playingNext => 'Далее играет';

  @override
  String get playingTrack => 'Воспроизведение трека';

  @override
  String get playlistAlbumTracks => 'Треки плейлиста / альбома';

  @override
  String get playlistNameHint => 'Название плейлиста';

  @override
  String get playlistNotFound => 'Плейлист не найден';

  @override
  String get playlistNotFoundOrError => 'Плейлист не найден или ошибка сервера';

  @override
  String get playlistReadyShare => 'Ваш плейлист готов к отправке!';

  @override
  String get playlists => 'Плейлисты';

  @override
  String get plays => 'проигрываний';

  @override
  String get popularOnSpotify => 'Популярно в Spotify';

  @override
  String get portuguese => 'Португальский (Бразилия)';

  @override
  String get preferredOutputFormat =>
      'Предпочтительный формат вывода для загрузок';

  @override
  String get preparingDownload => 'Подготовка загрузки';

  @override
  String preparingDownloadFormat(String format) {
    return 'Подготовка загрузки ($format)...';
  }

  @override
  String get preparingDownloadNotification => 'Подготовка загрузки';

  @override
  String get presetSaved => 'Пресет сохранен!';

  @override
  String get preview => 'ПРЕДПРОСМОТР';

  @override
  String get previousTrack => 'Предыдущий трек';

  @override
  String get profileSettings => 'Настройки профиля';

  @override
  String get profileStats => 'Статистика профиля';

  @override
  String get progress => 'Прогресс';

  @override
  String get publicSharing => 'Публичный доступ';

  @override
  String get publicSharingDesc =>
      'Любой, у кого есть код, может импортировать этот плейлист.';

  @override
  String get publicSharingDisabledDesc =>
      'Отключено. Включите, чтобы поделиться с другими.';

  @override
  String get queueIsEmpty => 'Очередь пуста';

  @override
  String get queueTooltip => 'Очередь';

  @override
  String get queueUpdated => 'Очередь обновлена';

  @override
  String get quickMix => 'Быстрый микс';

  @override
  String get rainbowMode => 'Радужный режим';

  @override
  String get rainyCity => 'Дождливый город';

  @override
  String get rank => 'Ранг';

  @override
  String rankActive(int rank) {
    return 'Ранг $rank (Активен)';
  }

  @override
  String rankLabel(int rank) {
    return 'РАНГ $rank';
  }

  @override
  String get reBuffering => 'Буферизация...';

  @override
  String reachDailyPlaysTooltip(int count) {
    return 'Достигните $count воспроизведений за день';
  }

  @override
  String reachSpecificArtistTooltip(String minutes) {
    return 'Слушайте исполнителя $minutes минут';
  }

  @override
  String reachWeeklyPlaysTooltip(int count) {
    return 'Достигните $count воспроизведений за неделю';
  }

  @override
  String get readySearchSong => 'Готово. Найдите песню.';

  @override
  String get rebufferingFromCloud => 'Перезагрузка из облака...';

  @override
  String get recentlyPlayed => 'Недавно прослушанные';

  @override
  String recommendationsCount(int count) {
    return 'Рекомендации ($count)';
  }

  @override
  String get recommendationsSection => 'Рекомендации';

  @override
  String get rediscover => 'Откройте заново';

  @override
  String get refreshLabel => 'Обновить';

  @override
  String get refreshLibrary => 'Обновить библиотеку';

  @override
  String get refreshList => 'Обновить список';

  @override
  String get refreshLyricsTooltip => 'Обновить текст';

  @override
  String get removeAvatar => 'Удалить текущий аватар';

  @override
  String get removeFromPlaylist => 'Удалить из плейлиста';

  @override
  String removedFolder(Object folder) {
    return 'Удалена папка: $folder';
  }

  @override
  String get rename => 'Переименовать';

  @override
  String get renamePlaylist => 'Переименовать плейлист';

  @override
  String get repeats => 'повторов';

  @override
  String get requiresAndroid14 => 'Требуется Android 14+ и USB ЦАП';

  @override
  String get resamplingLabel => 'Ресемплинг';

  @override
  String get reset => 'Сбросить';

  @override
  String get resetDataUsage => 'Сбросить использование данных';

  @override
  String get resetDataUsageContent =>
      'Вы уверены, что хотите сбросить использование данных? Это не повлияет на скачанную музыку.';

  @override
  String get resetEverything => 'Сбросить всё';

  @override
  String get resetLibraryContent =>
      'Это удалит текущую папку из проигрывателя. Ваши файлы не будут удалены.';

  @override
  String get resetLibraryPath => 'Сбросить путь к библиотеке';

  @override
  String get resetLibraryTitle => 'Сбросить библиотеку?';

  @override
  String get resetPath => 'Сбросить путь';

  @override
  String get resetStatistics => 'Сбросить статистику';

  @override
  String get resetStatsContent =>
      'Это действие необратимо.\\nВсе данные о количестве проигрываний и времени будут утеряны навсегда.';

  @override
  String get resetStatsTitle => 'Сбросить статистику?';

  @override
  String get resetToAutomatic => 'СБРОСИТЬ НА АВТО';

  @override
  String get resetToDefault => 'Сбросить по умолчанию';

  @override
  String get resetUsage => 'Сбросить использование';

  @override
  String get resetsIn => 'СБРОС ЧЕРЕЗ';

  @override
  String get restartContent =>
      'Для применения изменений аудиоустройства требуется перезагрузка приложения.\\n\\nПерезагрузить сейчас?';

  @override
  String get restartNow => 'Перезагрузить сейчас';

  @override
  String get restartRequired => 'Требуется перезагрузка';

  @override
  String get restoring => 'Восстановление';

  @override
  String get retryConnection => 'Повторить попытку';

  @override
  String get revert => 'Вернуть';

  @override
  String get russian => 'Русский';

  @override
  String get sakura => 'Сакура';

  @override
  String get sampleRateLabel => 'Частота дискретизации';

  @override
  String get samplingRateLabel => 'Частота дискретизации';

  @override
  String get save => 'Сохранить';

  @override
  String get saveAsNewPreset => 'Сохранить как новый пресет';

  @override
  String get saveChangesToFile => 'Сохранить изменения в файл';

  @override
  String get saveLabel => 'Сохранить';

  @override
  String get saveLrcPrompt =>
      'Хотите сохранить текущий текст как файл .lrc рядом с аудиофайлом?';

  @override
  String get saveLyricsTooltip => 'Сохранить текст';

  @override
  String get savePlaylistContent =>
      'Это создаст новый плейлист на основе этих песен.';

  @override
  String savePlaylistTitle(String title) {
    return 'Сохранить «$title»?';
  }

  @override
  String get savePreset => 'Сохранить пресет';

  @override
  String savedAs(String name) {
    return 'Сохранено как «$name»!';
  }

  @override
  String savedAsFormat(String format) {
    return 'Сохранено как $format';
  }

  @override
  String savedTo(String path) {
    return 'Сохранено в «$path»';
  }

  @override
  String get saving => 'Сохранение...';

  @override
  String get scan => 'Сканировать';

  @override
  String get scanToControlPlayback =>
      'Отсканируйте, чтобы управлять воспроизведением с телефона.';

  @override
  String get scanning => 'Сканирование...';

  @override
  String get scrollForLyrics => 'Прокрутите для просмотра текста';

  @override
  String get search => 'Поиск';

  @override
  String get searchEngine => 'Поисковая система';

  @override
  String searchFailedStatus(String error) {
    return 'Ошибка поиска: $error';
  }

  @override
  String get searchHint => 'Поиск...';

  @override
  String get searchSongs => 'Поиск песен...';

  @override
  String get searchSongsOrAlbumsAndArtistsHint =>
      'Поиск песен, альбомов или исполнителей...';

  @override
  String get searchSpotify => 'Поиск в Spotify';

  @override
  String get searchSpotifyHint => 'Поиск в Spotify...';

  @override
  String get searchUsers => 'Поиск пользователей...';

  @override
  String get searchYoutubeHint => 'Поиск в YouTube...';

  @override
  String get searching => 'Поиск...';

  @override
  String searchingEngine(String engine, String keyword) {
    return 'Поиск в $engine по запросу \'$keyword\'...';
  }

  @override
  String get searchingSpotify => 'Поиск в Spotify...';

  @override
  String searchingSpotifyFor(String keyword) {
    return 'Поиск «$keyword» в Spotify...';
  }

  @override
  String get searchingStatus => 'Поиск';

  @override
  String get secondShort => 'с';

  @override
  String get secsShort => 'С';

  @override
  String get seeAll => 'Посмотреть все';

  @override
  String get selectDifferentFolder => 'Выбрать другую папку';

  @override
  String get selectFolder => 'Выбрать папку';

  @override
  String get selectMatch => 'Выберите совпадение';

  @override
  String get selectSongToEdit => 'Выберите песню из списка для редактирования';

  @override
  String get selectStreamingQuality => 'Выберите качество стриминга';

  @override
  String get selectTrackToStart => 'Выберите трек для начала';

  @override
  String get selectVersion => 'Выберите версию';

  @override
  String session(String id) {
    return 'Сессия: $id';
  }

  @override
  String get setCountryReleases => 'Установить страну для релизов и чартов';

  @override
  String get setCustomTimer => 'Установить свой таймер';

  @override
  String get settings => 'Настройки';

  @override
  String get share => 'Поделиться';

  @override
  String get shareCodeUsage =>
      'Передайте этот 6-значный код другу, чтобы он мог импортировать этот плейлист.';

  @override
  String get sharePlaylist => 'Поделиться плейлистом';

  @override
  String sharePlaylistTitle(String name) {
    return 'Поделиться \"$name\"';
  }

  @override
  String get sharedMode => 'Общий';

  @override
  String showAllTitles(int count) {
    return 'Показать все $count титулов';
  }

  @override
  String get showAnimatedWaves =>
      'Показывать анимированные волны в панели воспроизведения';

  @override
  String get showDebugButton => 'Показывать плавающую кнопку отладки';

  @override
  String get showInFolder => 'Показать в папке';

  @override
  String get showLess => 'Показать меньше';

  @override
  String get showMore => 'Показать больше';

  @override
  String get showStatusDiscord => 'Показывать статус в Discord';

  @override
  String get showUnlockedOnly => 'Показать только разблокированные';

  @override
  String get shuffle => 'Перемешать';

  @override
  String get shuffleAll => 'Перемешать всё';

  @override
  String shufflingArtist(String artistName) {
    return 'Перемешивание песен $artistName...';
  }

  @override
  String get signInWithGoogle => 'Войти через Google';

  @override
  String get signalOutput => 'Выходной сигнал';

  @override
  String get singleTracks => 'Отдельные треки';

  @override
  String get sleepTimer => 'Таймер сна';

  @override
  String get songAlreadyInPlaylist => 'Песня уже есть в плейлисте';

  @override
  String get songInformation => 'Информация о песне';

  @override
  String get songLabelUpper => 'ПЕСНЯ';

  @override
  String get songTitleKeyword => 'Название или ключевое слово';

  @override
  String get songs => 'песен';

  @override
  String songsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count песен',
      few: '$count песни',
      one: '1 песня',
    );
    return '$_temp0';
  }

  @override
  String songsInLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count песен',
      few: '$count песни',
      one: '1 песня',
    );
    return '$_temp0 в библиотеке';
  }

  @override
  String songsLoadedCount(int count) {
    return 'Загружено песен: $count...';
  }

  @override
  String get southKorea => 'Южная Корея';

  @override
  String get spanish => 'Испанский';

  @override
  String get spectrumBars => 'Спектральные полосы';

  @override
  String get spotify => 'Spotify';

  @override
  String get standardDesc => 'MP3 - меньший файл, более быстрая загрузка';

  @override
  String get standardQuality => 'Стандартное (MP3)';

  @override
  String get start => 'Начать';

  @override
  String get startBulkProcess => 'Начать пакетную обработку';

  @override
  String get startedDownloadingAll => 'Начата загрузка всех песен...';

  @override
  String get stateDisabled => 'Отключено';

  @override
  String get stateEnabled => 'Включено';

  @override
  String get statisticsReset => 'Статистика сброшена.';

  @override
  String get stats => 'Статистика';

  @override
  String get statusLabel => 'Статус';

  @override
  String statusWithText(String status) {
    return 'Статус: $status';
  }

  @override
  String stopTimer(String time) {
    return 'Остановить таймер ($time)';
  }

  @override
  String get streaming => 'Стриминг';

  @override
  String get streamingQuality => 'Качество стриминга';

  @override
  String get success => 'Успешно';

  @override
  String get superfanHeader => 'ДОСТИЖЕНИЯ СУПЕРФАНАТОВ';

  @override
  String get superfanTitles => 'СУПЕРФАНАТ';

  @override
  String get supportDeveloperTooltip =>
      'Поддержите разработчика для получения титула';

  @override
  String get switchToGridView => 'Переключить на сетку';

  @override
  String get switchToListView => 'Переключить на список';

  @override
  String switchingTo(String title) {
    return 'Переключение на';
  }

  @override
  String get syncThemeAlbumArt => 'Синхронизировать тему с обложкой альбома';

  @override
  String get system => 'Система';

  @override
  String get systemDefault => 'Системное по умолчанию';

  @override
  String get targetLanguageLyrics => 'Целевой язык для перевода текста песен';

  @override
  String get thai => 'Тайский';

  @override
  String get tidalApiStatus => 'Tidal API';

  @override
  String get timeBasedTitles => 'НА ОСНОВЕ ВРЕМЕНИ';

  @override
  String get timeListened => 'Время прослушивания';

  @override
  String get timeOverlordsHeader => 'ПОВЕЛИТЕЛИ ВРЕМЕНИ';

  @override
  String timerSetForHours(int count) {
    return 'Таймер установлен на $count ч.';
  }

  @override
  String timerSetForMinutes(int count) {
    return 'Таймер установлен на $count мин.';
  }

  @override
  String timerSetForSeconds(int count) {
    return 'Таймер установлен на $count с.';
  }

  @override
  String get tintBackground => 'Окрашивать фон и визуализатор в цвет песни';

  @override
  String get title => 'Название';

  @override
  String get titleLabel => 'Название';

  @override
  String todayLabel(String size) {
    return 'Сегодня: $size';
  }

  @override
  String get toggleDebugButton => 'Переключить плавающую консоль отладки';

  @override
  String get toggleDebugConsole => 'Переключить плавающую консоль отладки';

  @override
  String get toggleLyrics => 'Переключить текст';

  @override
  String top3GlobalTooltip(int weeks) {
    return 'Войдите в Топ-3 мира на $weeks нед.';
  }

  @override
  String get topArtist => 'Топ исполнителей';

  @override
  String get topArtistAndTrack => 'Топ исполнителей и треков';

  @override
  String get topArtists => 'Топ исполнителей';

  @override
  String topGlobalTooltip(int rank) {
    return 'Войдите в топ $rank мира';
  }

  @override
  String get topListeners => 'Топ слушателей';

  @override
  String get totalMinutesStat => 'Всего минут';

  @override
  String get totalPlays => 'Всего проигрываний';

  @override
  String get trackDetails => 'Детали трека';

  @override
  String get trackNumber => '№ трека';

  @override
  String get tracks => 'треков';

  @override
  String get translateLabel => 'Перевести';

  @override
  String get translateLyrics => 'Перевести текст';

  @override
  String get translateLyricsTooltip => 'Перевести текст';

  @override
  String get translationLanguage => 'Язык перевода';

  @override
  String get turnOffTimer => 'Выключить таймер';

  @override
  String get unauthorize => 'Не авторизован';

  @override
  String get underDevelopment => 'Эта функция находится в разработке';

  @override
  String get underwater => 'Под водой';

  @override
  String get unitedKingdom => 'Великобритания';

  @override
  String get unitedStates => 'США';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get unknownArtist => 'Неизвестный исполнитель';

  @override
  String get unknownDevice => 'Неизвестное устройство';

  @override
  String get unlink => 'Отвязать';

  @override
  String get unlinkAccount => 'Отвязать аккаунт';

  @override
  String get unlinkAccountDesc =>
      'Ваша статистика останется на этом устройстве, но больше не будет синхронизироваться между устройствами.';

  @override
  String get unlinkAccountQuestion => 'Отвязать аккаунт?';

  @override
  String get unlinkFolder => 'Отвязать папку и очистить список песен';

  @override
  String get unlinkFolderClear => 'Отвязать папку и очистить список песен';

  @override
  String unlockedCountLabel(int unlocked, int total) {
    return '$unlocked / $total Разблокировано';
  }

  @override
  String get unmuteTooltip => 'Включить звук';

  @override
  String get unsavedChanges => 'Несохраненные изменения';

  @override
  String get upNext => 'Далее';

  @override
  String upNextCount(int count) {
    return 'Далее ($count)';
  }

  @override
  String get upNextSection => 'Далее';

  @override
  String get updateAvailableTitle => 'Доступно обновление';

  @override
  String updateAvailableVersion(String version) {
    return 'Доступна новая версия ($version).';
  }

  @override
  String updateFailed(String error) {
    return 'Ошибка обновления: $error';
  }

  @override
  String get updateNow => 'Обновить сейчас';

  @override
  String get updatePrompt => 'Хотите скачать и установить её сейчас?';

  @override
  String get updatingYtDlp => 'Обновление yt-dlp';

  @override
  String get usbAudioBypass =>
      'USB Audio Bypass (Beta) - Прямой вывод ЦАП для Android 13 и ниже';

  @override
  String get usbAudioBypassBeta =>
      'USB Audio Bypass (Beta) - Прямой вывод ЦАП для Android 13 и ниже';

  @override
  String get useDarkTheme => 'Использовать темную тему';

  @override
  String get useMixedColors =>
      'Использовать смешанные цвета (приоритет синхронизации)';

  @override
  String get verifiedDeveloper => 'Верифицированный разработчик';

  @override
  String get version => 'Версия';

  @override
  String versionLabel(String version) {
    return 'Версия $version';
  }

  @override
  String get vietnamese => 'Вьетнамский';

  @override
  String get viewQueue => 'Просмотр очереди';

  @override
  String get visualizer => 'Визуализатор';

  @override
  String get visualizerStyle => 'Стиль визуализатора';

  @override
  String get wasapiExclusive => 'Эксклюзивный режим WASAPI';

  @override
  String get weekly => 'Еженедельно';

  @override
  String get weeks => 'Недели';

  @override
  String get winter => 'Зима';

  @override
  String get worldRanking => 'Мировой рейтинг';

  @override
  String get worldTopArtists => 'Топ исполнителей мира';

  @override
  String get year => 'Год';

  @override
  String get youMayLike => 'Вам может понравиться';

  @override
  String get yourPlaylists => 'Ваши плейлисты';

  @override
  String get yourTopMix => 'Ваш топ-микс';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytDlpUpdateAvailable => 'Доступна новая версия yt-dlp.';

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
  String get offlineModeHeader => 'ОФЛАЙН-РЕЖИМ';

  @override
  String get offlineModeTitle => 'Офлайн-режим';

  @override
  String get offlineModeActive => 'АКТИВНО';

  @override
  String get offlineModeEnabledStatus => 'Офлайн-режим включен';

  @override
  String offlineModeDisabledStatus(int count) {
    return 'Отключено ($count)';
  }

  @override
  String get offlineModeAllEnabledStatus => 'Все включено';

  @override
  String get offlineModeLockdownDesc =>
      'Сеть заблокирована. Статистика сохраняется локально.';

  @override
  String get offlineModeMainDesc =>
      'Отключить все сетевые службы и воспроизводить только локальную библиотеку.';

  @override
  String get enableOfflineModeQuestion => 'Включить офлайн-режим?';

  @override
  String get offlineModeConfirmationDesc =>
      'Это полностью отключит всю сетевую связь. Следующие функции будут отключены:';

  @override
  String get offlineModeSyncRestoreNote =>
      'Ваша статистика автоматически синхронизируется, когда вы это выключите.';

  @override
  String get enableOfflineModeBtn => 'Включить офлайн-режим';

  @override
  String get onlineModeRestored =>
      'Онлайн-режим восстановлен. Синхронизация статистики...';

  @override
  String get disableServicesTitle => 'Отключить службы';

  @override
  String get manageIndividualFeatures =>
      'Управление отдельными онлайн-функциями';

  @override
  String get featureCloudSync => 'Синхронизация статистики в облаке';

  @override
  String get featureCloudSyncDesc =>
      'Статистика прослушивания сохраняется только локально';

  @override
  String get featureCloudSyncLongDesc =>
      'Синхронизация метрик прослушивания с PocketBase';

  @override
  String get featureLeaderboard => 'Глобальная таблица лидеров';

  @override
  String get featureLeaderboardDesc => 'Обновление рейтинга приостановлено';

  @override
  String get featureLeaderboardLongDesc =>
      'Публичное отображение и обновление вашего рейтинга';

  @override
  String get featureOnlineLyrics => 'Поиск текстов песен онлайн';

  @override
  String get featureOnlineLyricsDesc => 'Только локальные файлы .lrc/.ttml';

  @override
  String get featureOnlineLyricsLongDesc =>
      'Загрузка текстов песен из LRCLIB/Spotify';

  @override
  String get featureAiLyrics => 'ИИ-генератор текстов песен';

  @override
  String get featureAiLyricsDesc =>
      'Автоматическая синхронизация текстов отключена';

  @override
  String get featureAiLyricsLongDesc =>
      'Генерация синхронизированных текстов через ИИ';

  @override
  String get featureSpotifyCanvas => 'Spotify Canvas';

  @override
  String get featureSpotifyCanvasDesc => 'Фоновое видео отключено';

  @override
  String get featureSpotifyCanvasLongDesc => 'Фоновые видео для треков';

  @override
  String get featureOnlineSearch => 'Онлайн-поиск';

  @override
  String get featureOnlineSearchDesc => 'Поиск в Spotify/YouTube отключен';

  @override
  String get featureOnlineSearchLongDesc =>
      'Удаленный поиск в Spotify и YouTube';

  @override
  String get featureConnectDevice => 'Подключиться к устройству';

  @override
  String get featureConnectDeviceDesc =>
      'Дистанционное управление и прослушивание в группах отключены';

  @override
  String get featureConnectDeviceLongDesc =>
      'Дистанционное управление и прослушивание в группах';

  @override
  String get lyricsEditorTitle => 'Редактор текста песен';

  @override
  String get clearAllQuestion => 'Очистить все?';

  @override
  String get clearAllDesc =>
      'Это очистит текущее состояние редактора. Ваши локальные файлы НЕ будут удалены, если вы не сохраните их позже.';

  @override
  String get clearBtn => 'Очистить';

  @override
  String get lyricsApplied => 'Текст песни применен к панели!';

  @override
  String get chooseFormat => 'Выберите предпочтительный формат:';

  @override
  String get lrcFormat => 'LRC (Стандартная синхронизация)';

  @override
  String get lrcFormatDesc => 'Универсальный формат, работает везде.';

  @override
  String get ttmlFormat => 'TTML (Высокая точность)';

  @override
  String get ttmlFormatDesc =>
      'Лучше для генерации ИИ и детальной синхронизации.';

  @override
  String savedSuccessfully(String extension) {
    return 'Успешно сохранено в файл $extension!';
  }

  @override
  String get failedToSave => 'Не удалось сохранить файл текста песни.';

  @override
  String get generationFailed => 'Генерация не удалась';

  @override
  String get aiLyricsGenerationTitle => 'Генерация текста песни ИИ';

  @override
  String get syncedMode => 'Синхронизировано';

  @override
  String get plainMode => 'Обычный текст';

  @override
  String get addLineToTop => 'Добавить в начало';

  @override
  String get addLineToEnd => 'Добавить в конец';

  @override
  String get lyricTextHint => 'Текст песни...';

  @override
  String get insertAfter => 'Вставить после';

  @override
  String get removeLine => 'Удалить строку';

  @override
  String get romajiHint => 'Ромаджи / Транслитерация (Опционально)...';

  @override
  String get startLabel => 'Начало: ';

  @override
  String get setStartTooltip => 'Установить начало на текущую позицию';

  @override
  String get endLabel => 'Конец: ';

  @override
  String get setEndTooltip => 'Установить конец на текущую позицию';

  @override
  String get playFromLine => 'Воспроизвести с этой строки';

  @override
  String get pasteLyricsHint => 'Вставьте текст песни здесь...';

  @override
  String get applyBtn => 'Применить';

  @override
  String get saveLocallyBtn => 'Сохранить локально';

  @override
  String get editLyricsTooltip => 'Редактировать текст песни';

  @override
  String get saveLyricsTitle => 'Сохранить текст песни';

  @override
  String get aiGenerate => 'Генерация ИИ';

  @override
  String get aiLyricsInitializing => 'Инициализация...';

  @override
  String get aiLyricsUploading => 'Загрузка песни на сервер...';

  @override
  String get aiLyricsUploadFailed => 'Ошибка: Загрузка не удалась.';

  @override
  String get aiLyricsUploadSuccess => 'Загрузка завершена!';

  @override
  String get aiLyricsVerifying => 'Проверка статуса сервера...';

  @override
  String get aiLyricsStatusOk => 'Статус-код 200 OK!';

  @override
  String get aiLyricsPolling =>
      'Получение текста песни... Пожалуйста, подождите!';

  @override
  String get aiLyricsReceiving => 'Текст песни получен';

  @override
  String get aiLyricsParsing => 'Анализ текста песни...';

  @override
  String get aiLyricsSuccess => 'Текст песни успешно сгенерирован!';

  @override
  String get aiLyricsLocalFileMissing =>
      'Ошибка: Локальный аудиофайл не найден.';

  @override
  String get aiLyricsComplete => 'Завершено!';
}
