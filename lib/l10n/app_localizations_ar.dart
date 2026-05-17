// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get aboutEducationalPurpose =>
      'تم تطوير هذا التطبيق للأغراض الفردية والتعليمية فقط.';

  @override
  String get aboutLicenses => 'حول والتراخيص';

  @override
  String get aboutNotForCommercial => 'ليس للاستخدام التجاري.';

  @override
  String get accentColor => 'لون التمييز';

  @override
  String get access => 'دخول';

  @override
  String get accessCode => 'رمز الوصول';

  @override
  String get accountDataMergeDesc =>
      'من خلال المزامنة، سيتم تحديث اسم ملفك الشخصي وصورتك الرمزية، ولكن سيتم دمج دقائق الاستماع الحالية لجهازك بنجاح في إجمالي الحساب.';

  @override
  String get accountLinked => 'الحساب مرتبط';

  @override
  String get accountLinkedSuccessfully => 'تم ربط الحساب بنجاح!';

  @override
  String get achievementsUnlocked => 'الإنجازات المفتوحة';

  @override
  String get activeNoResampling => 'نشط (بدون إعادة عينة)';

  @override
  String get add => 'إضافة';

  @override
  String get addFiles => 'إضافة ملفات';

  @override
  String get addFolder => 'إضافة مجلد';

  @override
  String get addFoldersScan => 'إضافة مجلدات للمسح';

  @override
  String get addToFavorite => 'إضافة إلى المفضلة';

  @override
  String get addToPlaylist => 'إضافة إلى قائمة التشغيل';

  @override
  String get addToQueue => 'إضافة إلى قائمة الانتظار';

  @override
  String addedFolder(Object folder) {
    return 'تم إضافة المجلد: $folder';
  }

  @override
  String get addedToLikedSongs => 'تمت الإضافة إلى الأغاني المعجب بها';

  @override
  String get addedToPlaylistSuccess => 'تمت الإضافة إلى قائمة التشغيل';

  @override
  String get addedToQueue => 'تمت الإضافة إلى قائمة الانتظار';

  @override
  String get album => 'الألبوم';

  @override
  String get albumAddedToPlaylists => 'تمت إضافة الألبوم إلى قوائم التشغيل';

  @override
  String get albumLabel => 'الألبوم';

  @override
  String get albumRemovedFromPlaylists => 'تمت إزالة الألبوم من قوائم التشغيل';

  @override
  String get albums => 'الألبومات';

  @override
  String get allDownloadsRemoved => 'تمت إزالة جميع التنزيلات';

  @override
  String get allRightsReserved => 'كل الحقوق محفوظة.';

  @override
  String get allTime => 'كل الوقت';

  @override
  String get alreadyInLikedSongs => 'موجودة بالفعل في الأغاني المعجب بها';

  @override
  String get android14BitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidAudioEffectsNote =>
      'ملاحظة: التأثيرات الصوتية متاحة فقط على أندرويد.';

  @override
  String get androidAudioTrack => 'Android AudioTrack';

  @override
  String get androidBitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidMixer => 'خلاط أندرويد';

  @override
  String get appearance => 'المظهر';

  @override
  String get applyOnRestart =>
      'سيتم تطبيق التغييرات في المرة القادمة التي يتم فيها تشغيل التطبيق.';

  @override
  String get arabic => 'العربية';

  @override
  String get artist => 'الفنان';

  @override
  String get artistLabel => 'الفنان';

  @override
  String get artists => 'الفنانون';

  @override
  String get atmospheres => 'الأجواء';

  @override
  String get audioFormat => 'تنسيق الصوت';

  @override
  String get audioOutput => 'إخراج الصوت';

  @override
  String get audioOutputDevice => 'جهاز إخراج الصوت';

  @override
  String get audioQuality => 'جودة الصوت';

  @override
  String get audioSource => 'مصدر الصوت';

  @override
  String get audiophileDAC =>
      'تفعيله عند التشغيل على DACs احترافية (يتطلب إعادة تشغيل)';

  @override
  String get autoAddSimilar => 'إضافة أغاني مشابهة تلقائياً في نهاية القائمة';

  @override
  String get autoClearAfter24h => 'بعد 24 ساعة';

  @override
  String get autoClearAfter7d => 'بعد 7 أيام';

  @override
  String get autoClearCache => 'مسح ذاكرة التخزين المؤقت تلقائيًا';

  @override
  String get autoClearDisabled => 'معطل';

  @override
  String get autoClearEvery30m => 'كل 30 دقيقة (أثناء الاستماع فقط)';

  @override
  String get autoClearOnClose => 'عند إغلاق التطبيق';

  @override
  String get autoFixComingSoon => 'إصلاح تلقائي (قريباً)';

  @override
  String get autoRestartNotSupported =>
      'إعادة التشغيل التلقائي غير مدعومة. يرجى إعادة التشغيل يدوياً.';

  @override
  String autoTagContent(int count, String sourceName) {
    return 'سيؤدي هذا إلى البحث عن جميع الـ $count أغنية من \"$sourceName\" على Spotify واستبدال الوسوم تلقائياً.\\n\\nهذا الإجراء لا يمكن التراجع عنه.';
  }

  @override
  String autoTagTitle(String sourceName) {
    return '⚠️ وسم تلقائي لـ $sourceName؟';
  }

  @override
  String get automatic => 'تلقائي';

  @override
  String automaticTitleLabel(String title) {
    return 'تلقائي: $title';
  }

  @override
  String get autumn => 'الخريف';

  @override
  String get avatarPickerDesc => 'اختر قالبًا أو استورد صورتك الخاصة';

  @override
  String get beFirstToClaim => 'كن الأول للمطالبة بالمركز الأول!';

  @override
  String get backgroundCacheFlacStreams => 'تخزين مؤقت لتدفقات FLAC في الخلفية';

  @override
  String get backgroundCacheFlacStreamsSubtitle =>
      'يقوم بتنزيل المسارات عالية الجودة المتدفقة بصمت إلى القرص المحلي لجعل إعادة التشغيل فورية دون استخدام البيانات.';

  @override
  String get behavioralHeader => 'إنجازات سلوكية';

  @override
  String get behavioralTitles => 'سلوكي';

  @override
  String get binariesUpdateRequired => 'تحديث الملفات الثنائية مطلوب';

  @override
  String get bitDepthLabel => 'عمق البت';

  @override
  String get bitPerfectEnabled =>
      'وضع Bit-perfect مفعل. قد لا يعمل التحكم في مستوى الصوت.';

  @override
  String get bitPerfectWindows =>
      'صوت Bit-perfect مع معدل عينة آلي (يتطلب إعادة تشغيل)';

  @override
  String get bitrateLabel => 'معدل البت';

  @override
  String get bitsLabel => 'Bits';

  @override
  String get brazil => 'البرازيل';

  @override
  String get browse => 'تصفح';

  @override
  String get bypassSystemMixer => 'تجاوز خلاط النظام لـ USB DAC';

  @override
  String get bypassedBitPerfect => 'تم التجاوز (Bit-Perfect)';

  @override
  String get cacheCleared => 'تم مسح الذاكرة المؤقتة بنجاح!';

  @override
  String get cached => 'مخزن مؤقتاً';

  @override
  String get cancel => 'إلغاء';

  @override
  String get championChampionTooltip =>
      'تصل للمركز الأول عالمياً لمدة 5 أسابيع مختلفة';

  @override
  String get change => 'تغيير';

  @override
  String get changeFolder => 'تغيير المجلد';

  @override
  String get changeFormatInSettings => 'يرجى تغيير تنسيق الإخراج في الإعدادات';

  @override
  String get changeLabel => 'تغيير';

  @override
  String get changeLanguage => 'تغيير لغة التطبيق';

  @override
  String get changesApplyRestart =>
      'سيتم تطبيق التغييرات في المرة القادمة التي يتم فيها تشغيل التطبيق.';

  @override
  String get changingAudioDeviceRestart =>
      'مطلوب إعادة تشغيل التطبيق لتطبيق تغيير جهاز الصوت.\\n\\nإعادة التشغيل الآن؟';

  @override
  String get channelsLabel => 'القنوات';

  @override
  String get checkAgain => 'تحقق مرة أخرى';

  @override
  String get checkInternetConnection => 'تحقق من اتصالك بالإنترنت';

  @override
  String get checkNetworkTryAgain => 'تحقق من الشبكة وحاول مرة أخرى';

  @override
  String get chinese => 'الصينية';

  @override
  String get chooseAccentColor => 'اختر لونك الثابت المفضل';

  @override
  String get chooseAnimationType => 'اختر نوع الرسوم المتحركة';

  @override
  String get chooseArtist => 'اختر الفنان';

  @override
  String get chooseAvatar => 'اختر الأفاتار';

  @override
  String get chooseYourTitle => 'اختر لقبك';

  @override
  String get circularPulse => 'نبض دائري';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String get clearHistory => 'مسح السجل';

  @override
  String get clearImported => 'مسح المستورد';

  @override
  String get clearMetadataCache =>
      'مسح ذاكرة التخزين المؤقت للبيانات الوصفية والصور';

  @override
  String get clearPlayHistory => 'مسح السجل ووقت الاستماع';

  @override
  String get clearStreamingCache => 'مسح ذاكرة البث المؤقتة';

  @override
  String get close => 'إغلاق';

  @override
  String get cloud => 'سحابي';

  @override
  String get codeCopied => 'تم نسخ الرمز إلى الحافظة!';

  @override
  String get codeMust6Digits => 'يجب أن يتكون الرمز من 6 أرقام';

  @override
  String get codecLabel => 'الترميز';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get community => 'المجتمع';

  @override
  String get competitiveTitles => 'تنافسي';

  @override
  String get confirm => 'تأكيد';

  @override
  String get connect => 'اتصال';

  @override
  String get connectToADevice => 'الاتصال بجهاز';

  @override
  String get connected => 'متصل';

  @override
  String connectedToDac(String deviceName) {
    return 'متصل بـ $deviceName - تم تفعيل تجاوز USB';
  }

  @override
  String get connectedUsbDacs => 'أجهزة USB DAC المتصلة:';

  @override
  String get connecting => 'جارٍ الاتصال...';

  @override
  String get connectionLostLeaderboard => 'انقطع الاتصال';

  @override
  String get connectionLostLeaderboardDesc =>
      'لوحة المتصدرين العالمية تتطلب اتصالاً نشطاً لمزامنة إحصائياتك وجلب التصنيفات العالمية.';

  @override
  String consecutivePlaysTooltip(int count) {
    return 'استمع لنفس الأغنية $count مرات متتالية للحصول عليه';
  }

  @override
  String get contentRegion => 'منطقة المحتوى';

  @override
  String get copyCode => 'نسخ الرمز';

  @override
  String get couldNotDownloadFlac => 'لم يتم تنزيل FLAC.';

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أغنيات',
      one: 'أغنية واحدة',
    );
    return '$_temp0';
  }

  @override
  String get createPlaylist => 'إنشاء قائمة تشغيل';

  @override
  String creatingPlaylistWithTracks(int count) {
    return 'جاري إنشاء قائمة تشغيل تضم $count من المقاطع...';
  }

  @override
  String get crossfade => 'الكروس فيد';

  @override
  String crossfadeDesc(String seconds) {
    return 'تلاشي بين المقاطع ($seconds ث)';
  }

  @override
  String get crownedChampionTitlesHeader => 'ألقاب البطل المتوج';

  @override
  String get customDevice => 'جهاز مخصص';

  @override
  String get customSelected => 'مخصص محدد';

  @override
  String get customTime => 'وقت مخصص';

  @override
  String get cyberpunk => 'سايبربانك';

  @override
  String get daily => 'يومي';

  @override
  String get darkMode => 'الوضع المظلم';

  @override
  String get dataCleanup => 'البيانات والتنظيف';

  @override
  String get dataUsage => 'استخدام البيانات';

  @override
  String get daysShort => 'يوم';

  @override
  String get debugging => 'التصحيح';

  @override
  String get delete => 'حذف';

  @override
  String get deleteDownloadsConfirm =>
      'سيؤدي هذا إلى إزالة جميع الأغاني المنزلة على هذا الجهاز لهذه القائمة.';

  @override
  String get deleteDownloadsTitle => 'حذف التنزيلات؟';

  @override
  String deleteFileContent(String filename) {
    return 'هل أنت متأكد أنك تريد حذف \"$filename\"؟\\nهذا الإجراء لا يمكن التراجع عنه.';
  }

  @override
  String get deleteFileTitle => 'حذف الملف؟';

  @override
  String get deletePlaylist => 'حذف قائمة التشغيل';

  @override
  String deletePlaylistConfirm(String name) {
    return 'هل أنت متأكد أنك تريد حذف \"$name\"؟';
  }

  @override
  String get deletePlaylistPermanentConfirm =>
      'هل أنت متأكد من رغبتك في حذف قائمة التشغيل هذه؟ (لا يمكن التراجع عن هذا الإجراء)';

  @override
  String get deletePlaylistTitle => 'حذف قائمة التشغيل؟';

  @override
  String get deletePreset => 'حذف الإعداد المسبق';

  @override
  String get desertMirage => 'سراب الصحراء';

  @override
  String get developerExclusiveTooltip => 'حصرياً لمطوري هذا التطبيق';

  @override
  String deviceNameLabel(String deviceName) {
    return 'الجهاز: $deviceName';
  }

  @override
  String get disableCanvas => 'تعطيل Canvas';

  @override
  String get disableRomanization => 'تعطيل الرومنة';

  @override
  String get disablingSharingWarning =>
      'سيعمل تعطيل المشاركة على حذف الرمز والبيانات نهائياً من الخادم لتوفير المساحة.';

  @override
  String get discNumber => 'رقم القرص';

  @override
  String get discography => 'قائمة الأعمال';

  @override
  String get discordRPC => 'حضور ديسكورد';

  @override
  String get doYouRemember => 'هل تتذكر؟';

  @override
  String get donate => 'تبرع';

  @override
  String get download => 'تنزيل';

  @override
  String get downloadAll => 'تنزيل الكل';

  @override
  String get downloadComplete => 'اكتمل التنزيل';

  @override
  String get downloadCompleteNotification => 'اكتمل التنزيل';

  @override
  String get downloadError => 'خطأ التنزيل';

  @override
  String get downloadFailed => 'فشل التنزيل';

  @override
  String get downloadLocation => 'موقع التنزيل';

  @override
  String get downloadPathReset => 'تم إعادة ضبط مسار التنزيل للافتراضي.';

  @override
  String downloadPathUpdated(Object path) {
    return 'تم تحديث مسار التنزيل: $path';
  }

  @override
  String get downloadSong => 'تنزيل الأغنية';

  @override
  String get downloadStarted => 'بدأ التنزيل';

  @override
  String downloadedTo(String path) {
    return 'تم التنزيل إلى: $path';
  }

  @override
  String get downloading => 'جاري التنزيل';

  @override
  String get downloadingFlac => 'جاري تنزيل FLAC';

  @override
  String downloadingFormat(String format) {
    return 'جاري تنزيل $format';
  }

  @override
  String get downloadingUpdate => 'جاري تنزيل التحديث';

  @override
  String get downloads => 'التنزيلات';

  @override
  String get dspLabel => 'DSP';

  @override
  String get editMetadata => 'تعديل البيانات الوصفية';

  @override
  String get editNickname => 'تعديل الاسم المستعار';

  @override
  String get editor => 'المحرر';

  @override
  String get emptyMailbox => 'صندوق بريد فارغ';

  @override
  String get emptyMailboxDesc => 'سيؤدي هذا إلى حذف جميع الرسائل بشكل دائم.';

  @override
  String get emptyMailboxTitle => 'إفراغ صندوق البريد؟';

  @override
  String get emptyPlaylist => 'قائمة تشغيل فارغة';

  @override
  String get emptyPlaylistSubtitle => 'إنشاء قائمة تشغيل فارغة جديدة';

  @override
  String get enableAlphabetIndexer => 'تمكين الفهرس الأبجدي للتمرير';

  @override
  String get enableAlphabetIndexerSubtitle =>
      'إظهار الفهرسة في الشريط الجانبي A-Z على عرض القائمة المحمولة';

  @override
  String get enableBarVisualizer => 'تفعيل المصور الشريطي';

  @override
  String get endlessQueue => 'قائمة انتظار لا نهائية';

  @override
  String get engineLabel => 'المحرك';

  @override
  String get english => 'الإنجليزية';

  @override
  String get enterAdminAccessCode => 'يرجى إدخال رمز الوصول الإداري';

  @override
  String get enterAdminCode => 'يرجى إدخال رمز الوصول الإداري';

  @override
  String get enterDuration => 'أدخل المدة...';

  @override
  String get enterPresetName =>
      'أدخل اسم الإعداد المسبق (مثال: الباس الخاص بي)';

  @override
  String get enterShareCode => 'أدخل رمز المشاركة المكون من 6 أرقام';

  @override
  String get eqLabel => 'EQ';

  @override
  String get equalizer => 'المعادل';

  @override
  String get equipTitle => 'تجهيز اللقب';

  @override
  String get equipped => 'مجهز';

  @override
  String get error => 'خطأ';

  @override
  String get errorCouldNotCreateSession => 'خطأ: تعذر إنشاء الجلسة.';

  @override
  String errorDeleting(String error) {
    return 'خطأ أثناء الحذف: $error';
  }

  @override
  String get errorSearchingStream => 'خطأ أثناء البحث عن البث.';

  @override
  String get exclusiveMode => 'حصري';

  @override
  String get exclusiveModeWarning =>
      'تحذير: الوضع الحصري يعمل بشكل أفضل إذا اخترت جهازاً محدداً أعلاه بدلاً من افتراضي النظام.';

  @override
  String get exclusiveTitles => 'حصري';

  @override
  String get exclusiveTitlesHeader => 'ألقاب حصرية';

  @override
  String get exclusiveWarning =>
      'تحذير: الوضع الحصري يعمل بشكل أفضل إذا اخترت جهازاً محدداً أعلاه بدلاً من افتراضي النظام.';

  @override
  String get exitApp => 'إنهاء';

  @override
  String get expand => 'توسيع';

  @override
  String get externalFiles => 'ملفات خارجية';

  @override
  String get fadingAtEnd => 'مؤقت النوم: يتلاشى في نهاية المقطع...';

  @override
  String get failedDisableSharing => 'فشل تعطيل المشاركة.';

  @override
  String get failedEnableSharing => 'فشل تفعيل المشاركة. تحقق من الاتصال.';

  @override
  String get failedFetchPlaylistInfo => 'تعذر جلب معلومات قائمة التشغيل';

  @override
  String get failedToConnectDac => 'فشل الاتصال بـ DAC. تحقق من أذونات USB.';

  @override
  String get failedToGenerateCode => 'فشل إنشاء رمز المشاركة. تحقق من الاتصال.';

  @override
  String get failedToSetAvatar => 'فشل في تعيين قالب الصورة الرمزية';

  @override
  String get failedToUpdateMetadata => 'فشل تحديث البيانات الوصفية';

  @override
  String get favoriteTrack => 'الأغنية المفضلة';

  @override
  String get fetchingCanvas => 'جاري جلب Canvas...';

  @override
  String get fetchingLossless => 'جاري جلب جودة بدون فقدان...';

  @override
  String get fetchingLosslessAudio => 'جاري جلب صوت بدون فقدان...';

  @override
  String get fetchingMetadataSpotify => 'جاري جلب البيانات من Spotify...';

  @override
  String get fetchingPlaylist => 'جاري جلب قائمة التشغيل...';

  @override
  String get fetchingPlaylistInfo => 'جاري جلب معلومات قائمة التشغيل...';

  @override
  String get fetchingSharedPlaylist => 'جاري جلب قائمة التشغيل المشتركة...';

  @override
  String fetchingTracksFrom(String name) {
    return 'جاري جلب المقاطع من \"$name\"...';
  }

  @override
  String get fileLocation => 'موقع الملف';

  @override
  String get fileMissingHistory => 'الملف مفقود وغير موجود في السجل.';

  @override
  String get fileName => 'اسم الملف';

  @override
  String get fileSizeLabel => 'حجم الملف';

  @override
  String get files => 'الملفات';

  @override
  String get filters => 'مرشحات';

  @override
  String get findingBestMatchYoutube =>
      'جاري البحث عن أفضل مطابقة على YouTube...';

  @override
  String get findingStream => 'جاري البحث عن مصدر البث...';

  @override
  String get finishUpdate => 'إنهاء التحديث';

  @override
  String get finishes => 'المراكز';

  @override
  String get fixAll => 'إصلاح الكل';

  @override
  String get flacError => 'خطأ في FLAC';

  @override
  String get flacNote =>
      'ملاحظة: FLAC متاح فقط لتنزيلات المقاطع الفردية. تنزيلات قوائم التشغيل ستستخدم تنسيق M4A.';

  @override
  String get flacSavedToDownloads => 'تم حفظ FLAC في مجلد التنزيلات';

  @override
  String get flacUnavailable => 'FLAC غير متاح';

  @override
  String get flacUnavailableDesc =>
      'FLAC غير متاح، فشل التنزيل. حاول تغيير الإعدادات.';

  @override
  String get flacUnavailableNotification => 'FLAC غير متاح';

  @override
  String get fluidWave => 'موجة سائلة';

  @override
  String folderPath(String path) {
    return 'المجلد: $path';
  }

  @override
  String get folders => 'المجلدات';

  @override
  String get formatLabel => 'التنسيق';

  @override
  String get formatSaved => 'تم حفظ التنسيق!';

  @override
  String foundExistingAccount(String name) {
    return 'وجدنا حساباً موجوداً لـ \'$name\'.';
  }

  @override
  String foundResults(int songCount, int albumCount, int artistCount) {
    return 'تم العثور على $songCount أغاني، $albumCount ألبومات، $artistCount فنانين.';
  }

  @override
  String foundYoutubeResults(int count) {
    return 'تم العثور على $count نتيجة على YouTube';
  }

  @override
  String freeUpSpace(String size) {
    return 'توفير مساحة (الحالي: $size)';
  }

  @override
  String get french => 'الفرنسية';

  @override
  String fromLibraryCount(int count) {
    return 'من المكتبة ($count)';
  }

  @override
  String get fromLibrarySection => 'من المكتبة';

  @override
  String get fullScreenPlayerTooltip => 'المشغل بملء الشاشة';

  @override
  String get galacticSpace => 'الفضاء المجري';

  @override
  String get gaplessPlayback => 'تشغيل بدون فواصل';

  @override
  String get gaplessPlaybackDesc => 'إزالة الصمت بين المقاطع';

  @override
  String get general => 'عام';

  @override
  String get generatingShareCode => 'جاري إنشاء رمز المشاركة...';

  @override
  String get genre => 'النوع';

  @override
  String get german => 'الألمانية';

  @override
  String get globalLeaderboard => 'لوحة المتصدرين العالمية';

  @override
  String get globalMailbox => 'صندوق البريد العالمي';

  @override
  String get globalRank => 'التصنيف العالمي';

  @override
  String get globalRankings => 'الترتيب العالمي';

  @override
  String get globalRankingsDesc =>
      'شاهد أفضل المستمعين يوميًا وأسبوعيًا وطوال الوقت!';

  @override
  String get goToArtist => 'الذهاب إلى الفنان';

  @override
  String get goToLocalLibraryToSelect =>
      'اذهب إلى المكتبة المحلية لاختيار مجلد.';

  @override
  String get goodAfternoon => 'مساء الخير';

  @override
  String get goodEvening => 'مساء الخير';

  @override
  String get goodMorning => 'صباح الخير';

  @override
  String get googleAccount => 'حساب Google';

  @override
  String get grantAccess => 'منح حق الوصول';

  @override
  String get grantPermission => 'منح الإذن';

  @override
  String get hallOfFameHeader => 'إنجازات قاعة المشاهير';

  @override
  String get hallOfFameTitles => 'قاعة المشاهير';

  @override
  String get hideCanvas =>
      'عدم إظهار فيديوهات Spotify Canvas، إظهار غلاف الألبوم بدلاً منها';

  @override
  String get hideRomajiPinyin =>
      'عدم إظهار Romaji/Pinyin تحت الكلمات الكورية أو اليابانية أو الصينية';

  @override
  String get hideTranslation => 'إخفاء الترجمة';

  @override
  String get highDesc => 'M4A - صوت أفضل، أداء متوازن';

  @override
  String get highQuality => 'جودة عالية (M4A)';

  @override
  String get hindi => 'الهندية';

  @override
  String get history => 'السجل';

  @override
  String get historySection => 'السجل';

  @override
  String get home => 'الرئيسية';

  @override
  String get hourShort => 'ساعة';

  @override
  String hoursDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعات',
      one: 'ساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get hoursShort => 'ساعة';

  @override
  String get ignoreSubfolderScan => 'تجاهل مسح المجلدات الفرعية';

  @override
  String get importAdditionalPaths => 'استيراد مسارات إضافية';

  @override
  String get importChoice => 'استيراد';

  @override
  String importFailed(String error) {
    return 'فشل الاستيراد: $error';
  }

  @override
  String get importFromGallery => 'استيراد من المعرض';

  @override
  String get importFromSpotify => 'استيراد من Spotify';

  @override
  String get importFromSpotifySubtitle => 'الصق رابط قائمة تشغيل Spotify';

  @override
  String get importFromYoutubeMusic => 'استيراد من YouTube Music';

  @override
  String get importFromYoutubeMusicSubtitle =>
      'الصق رابط قائمة تشغيل YouTube Music';

  @override
  String get importLabel => 'استيراد';

  @override
  String get importLyricsFile => 'استيراد ملف كلمات';

  @override
  String get importLyricsTooltip => 'استيراد كلمات';

  @override
  String get importSpotifyPlaylist => 'استيراد قائمة تشغيل Spotify';

  @override
  String get importViaCode => 'استيراد عبر الرمز';

  @override
  String get importViaCodeSubtitle => 'استيراد قائمة تشغيل مشتركة بواسطة صديق';

  @override
  String get importYoutubeMusicPlaylist => 'استيراد قائمة تشغيل YouTube Music';

  @override
  String importedPlaylistName(String name) {
    return 'تم استيراد \"$name\" بنجاح!';
  }

  @override
  String importedTracks(int count) {
    return 'تم استيراد $count من المقاطع بنجاح!';
  }

  @override
  String get indonesia => 'إندونيسيا';

  @override
  String get indonesian => 'الإندونيسية';

  @override
  String get inputLabel => 'المدخلات';

  @override
  String get installNow => 'تثبيت الآن';

  @override
  String get integration => 'التكامل';

  @override
  String get invalidAccessCode => 'رمز وصول غير صحيح';

  @override
  String get invalidCode => 'رمز وصول غير صحيح';

  @override
  String get invalidSpotifyUrl => 'رابط قائمة تشغيل Spotify غير صالح';

  @override
  String get invalidYoutubeMusicUrl =>
      'رابط قائمة تشغيل YouTube Music غير صالح';

  @override
  String get japan => 'اليابان';

  @override
  String get japanese => 'اليابانية';

  @override
  String get joinUs => 'انضم إلينا';

  @override
  String get jumpBackIn => 'العودة للاستماع';

  @override
  String get justEnjoyVibes => 'فقط استمتع بالأجواء.';

  @override
  String get korean => 'الكورية';

  @override
  String get language => 'اللغة';

  @override
  String last30DaysLabel(String size) {
    return 'آخر 30 يومًا: $size';
  }

  @override
  String last7DaysLabel(String size) {
    return 'آخر 7 أيام: $size';
  }

  @override
  String get later => 'لاحقاً';

  @override
  String get library => 'المكتبة';

  @override
  String get libraryData => 'بيانات المكتبة';

  @override
  String get libraryNotLoaded => 'لم يتم تحميل المكتبة.';

  @override
  String get libraryPathReset => 'تم إعادة ضبط مسار المكتبة.';

  @override
  String get likedSongs => 'الأغاني المعجب بها';

  @override
  String get linkAccount => 'ربط الحساب';

  @override
  String get linkAccountDesc => 'مزامنة واستعادة تقدمك باستخدام Google';

  @override
  String listenMinutesTooltip(String minutes) {
    return 'استمع لـ $minutes دقيقة من الموسيقى';
  }

  @override
  String get listeningParty => 'حفلة استماع';

  @override
  String get listeningStats => 'إحصائيات الاستماع';

  @override
  String get loadingCanvas => 'جاري تحميل Canvas...';

  @override
  String get loadingDevices => 'جاري تحميل الأجهزة...';

  @override
  String get loadingError => 'فشل تحميل التفاصيل. يرجى المحاولة مرة أخرى.';

  @override
  String get loadingLyrics => 'جاري تحميل الكلمات...';

  @override
  String get localPlayHistorySaved => 'لن يتم حذف سجل التشغيل المحلي الخاص بك.';

  @override
  String get local_library => 'المكتبة المحلية';

  @override
  String get lockedAtmosphere => 'مغلق عندما تكون الأجواء نشطة';

  @override
  String get losslessDesc => 'FLAC - جودة بدون فقدان من Deezer/Tidal';

  @override
  String get losslessNote =>
      'سيستخدم FLAC إذا توفر في Deezer/Tidal. وإلا، سيعود إلى M4A.';

  @override
  String get losslessQuality => 'بدون فقدان (آلي)';

  @override
  String get lunarNewYear => 'رأس السنة القمرية';

  @override
  String get lyricsByLRCLIB => 'الكلمات بواسطة LRCLIB';

  @override
  String get lyricsSaveError => 'خطأ أثناء حفظ الكلمات';

  @override
  String get lyricsSavedSuccess => 'تم حفظ الكلمات في ملف .lrc';

  @override
  String get lyricsTooltip => 'كلمات الأغاني';

  @override
  String get madeForYou => 'صنع لك';

  @override
  String get manualSearch => 'بحث يدوي';

  @override
  String get mergeAccountData => 'دمج بيانات الحساب؟';

  @override
  String get metadataCacheCleared =>
      'تم مسح ذاكرة التخزين المؤقت للبيانات الوصفية وبدأ إعادة فحص المكتبة';

  @override
  String get metadataEditorInfo =>
      'يمكنك البحث والتصحيح بسرعة في محرر البيانات الوصفية.';

  @override
  String get metadataEditorNote =>
      'ملاحظة: بعد ظهور الحالة \"تم الحفظ بنجاح\"، قد تتغير صورة الألبوم. هذا ليس خطأ ولكنه مشكلة في ذاكرة التطبيق المؤقتة نعمل على حلها. تحقق من مدير الملفات.';

  @override
  String get metadataUpdated => 'تم تحديث البيانات الوصفية';

  @override
  String get metadata_editor => 'محرر البيانات الوصفية';

  @override
  String get min => 'دقيقة';

  @override
  String get minShortLabel => 'دقيقة';

  @override
  String get miniPlayer => 'المشغل المصغر';

  @override
  String get minimizeToTray => 'تصغير إلى شريط النظام';

  @override
  String get minimizeToTrayDescription =>
      'إغلاق التطبيق إلى شريط النظام بدلاً من الخروج';

  @override
  String get minsShort => 'د';

  @override
  String get minsShortLabel => 'دقائق';

  @override
  String get minuteShort => 'دقيقة';

  @override
  String get minutes => 'دقائق';

  @override
  String minutesDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقائق',
      one: 'دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get moreOptions => 'خيارات إضافية';

  @override
  String get moreOptionsTooltip => 'خيارات إضافية';

  @override
  String get mostListened => 'الأكثر استماعاً';

  @override
  String get mostListenedArtist => 'الفنان الأكثر استماعاً';

  @override
  String get musicFolderLocation => 'موقع مجلد الموسيقى';

  @override
  String get musicSearch => 'البحث عن الموسيقى';

  @override
  String musicWillStopIn(String label) {
    return 'ستتوقف الموسيقى خلال $label';
  }

  @override
  String get muteTooltip => 'كتم الصوت';

  @override
  String myTopTrackOn(String header) {
    return 'أغنيتي المفضلة على Simple Player! 🎵';
  }

  @override
  String get nativeRate => 'المعدل الأصلي';

  @override
  String get navigation => 'التنقل';

  @override
  String get newPlaylist => 'قائمة تشغيل جديدة';

  @override
  String get nextTrack => 'المسار التالي';

  @override
  String get nicknameHint => 'أدخل اسمك المستعار';

  @override
  String get nicknameLabel => 'الاسم المستعار';

  @override
  String get nicknameRequired => 'الاسم المستعار مطلوب';

  @override
  String get nicknameRequiredDesc =>
      'يجب عليك تعيين اسم مستعار مخصص أولاً لعرض لوحة المتصدرين العالمية!';

  @override
  String get nicknameTakenDesc =>
      'هذا الاسم المستعار مستخدم بالفعل عالميًا. يرجى اختيار اسم آخر.';

  @override
  String get nicknameTakenTitle => 'الاسم المستعار مأخوذ';

  @override
  String get noAlbumsFound => 'لم يتم العثور على ألبومات';

  @override
  String get noArtistStatsYet => 'لا توجد إحصائيات للفنانين بعد.';

  @override
  String get noArtistsFound => 'لم يتم العثور على فنانين.';

  @override
  String get noDownloadsFound => 'لم يتم العثور على تنزيلات';

  @override
  String get noFolderSelected => 'لم يتم اختيار مجلد';

  @override
  String get noHistoryYet => 'لا يوجد سجل بعد';

  @override
  String get noInternetConnection => 'لا يوجد اتصال بالإنترنت';

  @override
  String get noLyricsAvailable => 'لا توجد كلمات متاحة';

  @override
  String get noMessages => 'لا توجد رسائل في صندوق بريدك';

  @override
  String get noMusicPlaying => 'لا توجد موسيقى مشغلة';

  @override
  String get noPlaylistsFound => 'لم يتم العثور على قوائم تشغيل';

  @override
  String get noPlaylistsYet => 'لا توجد قوائم تشغيل بعد';

  @override
  String get noRankingsYet => 'لا توجد تصنيفات بعد لهذه الفترة الزمنية.';

  @override
  String get noResultsFound => 'لم يتم العثور على نتائج';

  @override
  String get noSongPlaying => 'لا توجد أغنية مشغلة';

  @override
  String get noSongsAdded => 'لم تتم إضافة أي أغاني بعد';

  @override
  String get noSongsInFolder => 'لم يتم العثور على أغاني في هذا المجلد.';

  @override
  String get noSpotifyResults => 'لم يتم العثور على نتائج من Spotify.';

  @override
  String get noStatsYet => 'لا توجد إحصائيات بعد.';

  @override
  String get noStreamMatch => 'لم يتم العثور على مطابقة للبث.';

  @override
  String get noSuggestionsFound => 'لم يتم العثور على اقتراحات.';

  @override
  String get noSyncedLyricsFound => 'لم يتم العثور على كلمات متزامنة';

  @override
  String get noTracksFound => 'لم يتم العثور على مقاطع في قائمة التشغيل';

  @override
  String get noUsbDacDetected =>
      'لم يتم اكتشاف USB DAC. قم بتوصيل جهاز صوت USB واضغط على مسح.';

  @override
  String get noUsersFound => 'لم يتم العثور على مستخدم';

  @override
  String get noYoutubeResults => 'لم يتم العثور على نتائج على YouTube';

  @override
  String get none => 'بلا';

  @override
  String get nordicAurora => 'الشفق القطبي';

  @override
  String notRank(int rank) {
    return 'ليس في الرتبة $rank';
  }

  @override
  String get notRanked => 'غير مصنف';

  @override
  String get notRankedTop3 => 'ليس في المراكز الثلاثة الأولى';

  @override
  String get nowPlaying => 'مشغل الآن';

  @override
  String get nowPlayingHeader => 'مشغل الآن';

  @override
  String get nowPlayingSection => 'مشغل الآن';

  @override
  String get offline => 'بدون اتصال';

  @override
  String get offlineStatus => 'غير متصل';

  @override
  String get ok => 'موافق';

  @override
  String get online => 'متصل';

  @override
  String get onlyScanSelected => 'مسح المجلدات المختارة فقط (مفعل افتراضياً)';

  @override
  String get opacity => 'الشفافية';

  @override
  String opacityLabel(int percent) {
    return 'الشفافية: $percent%';
  }

  @override
  String get openProfile => 'فتح الملف الشخصي';

  @override
  String get openSourceLicenses => 'تراخيص المصدر المفتوح';

  @override
  String get outputLabel => 'المخرجات';

  @override
  String get overwrite => 'استبدال';

  @override
  String get overwriteLrcWarning =>
      'يوجد ملف .lrc محلي للأغنية بالفعل.\\nهل تريد الاستبدال؟';

  @override
  String get parsingPlaylistData => 'جاري تحليل بيانات قائمة التشغيل...';

  @override
  String get pathLabel => 'المسار';

  @override
  String get permissionRequired => 'الإذن مطلوب';

  @override
  String get permissionRequiredDesc =>
      'إذن \"الدخول إلى جميع الملفات\" مطلوب لتعديل البيانات الوصفية. هذا يسمح بتعديل ملفات الموسيقى الخاصة بك مباشرة.';

  @override
  String get play => 'تشغيل';

  @override
  String playCountLabel(int count) {
    return '$count تشغيل';
  }

  @override
  String get playNext => 'تشغيل تالياً';

  @override
  String get playPause => 'تشغيل / إيقاف';

  @override
  String get playQueue => 'تشغيل القائمة';

  @override
  String get playback => 'التشغيل';

  @override
  String get playbackError => 'خطأ في التشغيل';

  @override
  String get player => 'اللاعب';

  @override
  String get playingFromAlbum => 'التشغيل من الألبوم';

  @override
  String get playingNext => 'سيتم التشغيل تالياً';

  @override
  String get playingTrack => 'تشغيل المقطع';

  @override
  String get playlistAlbumTracks => 'مقاطع القائمة / الألبوم';

  @override
  String get playlistNameHint => 'اسم قائمة التشغيل';

  @override
  String get playlistNotFound => 'قائمة التشغيل غير موجودة';

  @override
  String get playlistNotFoundOrError =>
      'قائمة التشغيل غير موجودة أو حدث خطأ في الخادم';

  @override
  String get playlistReadyShare => 'قائمة التشغيل الخاصة بك جاهزة للمشاركة!';

  @override
  String get playlists => 'قوائم التشغيل';

  @override
  String get plays => 'مرات تشغيل';

  @override
  String get popularOnSpotify => 'شائع على Spotify';

  @override
  String get portuguese => 'البرتغالية (البرازيل)';

  @override
  String get preferredOutputFormat => 'تنسيق الإخراج المفضل للتنزيلات';

  @override
  String get preparingDownload => 'جاري تحضير التنزيل';

  @override
  String preparingDownloadFormat(String format) {
    return 'جاري تحضير التنزيل ($format)...';
  }

  @override
  String get preparingDownloadNotification => 'جاري تحضير التنزيل';

  @override
  String get presetSaved => 'تم حفظ الإعداد المسبق!';

  @override
  String get preview => 'معاينة';

  @override
  String get previousTrack => 'المسار السابق';

  @override
  String get profileSettings => 'إعدادات الملف الشخصي';

  @override
  String get profileStats => 'إحصائيات الملف الشخصي';

  @override
  String get progress => 'التقدم';

  @override
  String get publicSharing => 'المشاركة العلنية';

  @override
  String get publicSharingDesc =>
      'يمكن لأي شخص لديه الرمز استيراد قائمة التشغيل هذه.';

  @override
  String get publicSharingDisabledDesc =>
      'معطلة. قم بتفعيلها للمشاركة مع الآخرين.';

  @override
  String get queueIsEmpty => 'قائمة الانتظار فارغة';

  @override
  String get queueTooltip => 'قائمة الانتظار';

  @override
  String get queueUpdated => 'تم تحديث قائمة الانتظار';

  @override
  String get quickMix => 'ميكس سريع';

  @override
  String get rainbowMode => 'وضع قوس قزح';

  @override
  String get rainyCity => 'مدينة ممطرة';

  @override
  String get rank => 'الرتبة';

  @override
  String rankActive(int rank) {
    return 'الرتبة $rank (نشط)';
  }

  @override
  String rankLabel(int rank) {
    return 'الرتبة $rank';
  }

  @override
  String get reBuffering => 'جاري التحميل...';

  @override
  String reachDailyPlaysTooltip(int count) {
    return 'تصل لـ $count تشغيل في يوم واحد للحصول عليه';
  }

  @override
  String reachSpecificArtistTooltip(String minutes) {
    return 'تصل لـ $minutes دقيقة مع فنان معين للحصول عليه';
  }

  @override
  String reachWeeklyPlaysTooltip(int count) {
    return 'تصل لـ $count تشغيل في أسبوع واحد للحصول عليه';
  }

  @override
  String get readySearchSong => 'جاهز. ابحث عن أغنية.';

  @override
  String get rebufferingFromCloud => 'إعادة التحميل من السحابة...';

  @override
  String get recentlyPlayed => 'تم تشغيلها مؤخراً';

  @override
  String recommendationsCount(int count) {
    return 'توصيات ($count)';
  }

  @override
  String get recommendationsSection => 'توصيات';

  @override
  String get rediscover => 'إعادة اكتشاف';

  @override
  String get refreshLabel => 'تحديث';

  @override
  String get refreshLibrary => 'تحديث المكتبة';

  @override
  String get refreshList => 'تحديث القائمة';

  @override
  String get refreshLyricsTooltip => 'تحديث كلمات';

  @override
  String get removeAvatar => 'إزالة الأفاتار الحالي';

  @override
  String get removeFromPlaylist => 'إزالة من قائمة التشغيل';

  @override
  String removedFolder(Object folder) {
    return 'تم إزالة المجلد: $folder';
  }

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get renamePlaylist => 'إعادة تسمية قائمة التشغيل';

  @override
  String get repeats => 'تكرارات';

  @override
  String get requiresAndroid14 => 'يتطلب Android 14+ و USB DAC';

  @override
  String get resamplingLabel => 'إعادة العينة';

  @override
  String get reset => 'إعادة تعيين';

  @override
  String get resetDataUsage => 'إعادة تعيين استخدام البيانات';

  @override
  String get resetDataUsageContent =>
      'هل أنت متأكد من رغبتك في إعادة تعيين استخدام البيانات؟ لن يؤثر ذلك على الموسيقى التي تم تنزيلها.';

  @override
  String get resetEverything => 'إعادة ضبط كل شيء';

  @override
  String get resetLibraryContent =>
      'سيؤدي هذا إلى إزالة المجلد الحالي من المشغل. لن يتم حذف ملفاتك.';

  @override
  String get resetLibraryPath => 'إعادة ضبط مسار المكتبة';

  @override
  String get resetLibraryTitle => 'إعادة ضبط المكتبة؟';

  @override
  String get resetPath => 'إعادة ضبط المسار';

  @override
  String get resetStatistics => 'إعادة ضبط الإحصائيات';

  @override
  String get resetStatsContent =>
      'هذا الإجراء لا يمكن التراجع عنه.\\nستفقد جميع أعداد مرات التشغيل والأوقات بشكل دائم.';

  @override
  String get resetStatsTitle => 'إعادة ضبط الإحصائيات؟';

  @override
  String get resetToAutomatic => 'إعادة تعيين إلى تلقائي';

  @override
  String get resetToDefault => 'إعادة الضبط للافتراضي';

  @override
  String get resetUsage => 'إعادة تعيين الاستخدام';

  @override
  String get resetsIn => 'يعاد الضبط خلال';

  @override
  String get restartContent =>
      'مطلوب إعادة تشغيل التطبيق لتطبيق تغييرات جهاز الصوت.\\n\\nإعادة التشغيل الآن؟';

  @override
  String get restartNow => 'إعادة التشغيل الآن';

  @override
  String get restartRequired => 'إعادة التشغيل مطلوبة';

  @override
  String get restoring => 'جاري الاستعادة';

  @override
  String get retryConnection => 'إعادة محاولة الاتصال';

  @override
  String get revert => 'رجوع';

  @override
  String get russian => 'الروسية';

  @override
  String get sakura => 'ساكورا';

  @override
  String get sampleRateLabel => 'معدل العينة';

  @override
  String get samplingRateLabel => 'معدل العينة';

  @override
  String get save => 'حفظ';

  @override
  String get saveAsNewPreset => 'حفظ كإعداد مسبق جديد';

  @override
  String get saveChangesToFile => 'حفظ التغييرات في الملف';

  @override
  String get saveLabel => 'حفظ';

  @override
  String get saveLrcPrompt =>
      'هل تريد حفظ الكلمات الحالية كملف .lrc بجانب الملف الصوتي؟';

  @override
  String get saveLyricsTooltip => 'حفظ كلمات';

  @override
  String get savePlaylistContent =>
      'سيؤدي هذا إلى إنشاء قائمة تشغيل جديدة بناءً على هذه الأغاني.';

  @override
  String savePlaylistTitle(String title) {
    return 'حفظ \"$title\"؟';
  }

  @override
  String get savePreset => 'حفظ الإعداد المسبق';

  @override
  String savedAs(String name) {
    return 'تم الحفظ باسم \"$name\"!';
  }

  @override
  String savedAsFormat(String format) {
    return 'تم الحفظ بصيغة $format';
  }

  @override
  String savedTo(String path) {
    return 'تم الحفظ في \"$path\"';
  }

  @override
  String get saving => 'جاري الحفظ...';

  @override
  String get scan => 'مسح';

  @override
  String get scanToControlPlayback => 'امسح للتحكم في التشغيل بهاتفك.';

  @override
  String get scanning => 'جاري المسح...';

  @override
  String get scrollForLyrics => 'قم بالتمرير لمشاهدة الكلمات';

  @override
  String get search => 'بحث';

  @override
  String get searchEngine => 'محرك البحث';

  @override
  String searchFailedStatus(String error) {
    return 'فشل البحث: $error';
  }

  @override
  String get searchHint => 'بحث...';

  @override
  String get searchSongs => 'بحث عن أغاني...';

  @override
  String get searchSongsOrAlbumsAndArtistsHint =>
      'بحث عن أغاني، ألبومات أو فنانين...';

  @override
  String get searchSpotify => 'بحث في Spotify';

  @override
  String get searchSpotifyHint => 'بحث في Spotify...';

  @override
  String get searchUsers => 'البحث عن المستخدمين...';

  @override
  String get searchYoutubeHint => 'بحث في YouTube...';

  @override
  String get searching => 'جاري البحث...';

  @override
  String searchingEngine(String engine, String keyword) {
    return 'جاري البحث في $engine عن \'$keyword\'...';
  }

  @override
  String get searchingSpotify => 'جاري البحث في Spotify...';

  @override
  String searchingSpotifyFor(String keyword) {
    return 'جاري البحث عن \"$keyword\" في Spotify...';
  }

  @override
  String get searchingStatus => 'بحث';

  @override
  String get secondShort => 'ثانية';

  @override
  String get secsShort => 'ث';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get selectDifferentFolder => 'اختر مجلداً مختلفاً';

  @override
  String get selectFolder => 'اختر مجلداً';

  @override
  String get selectMatch => 'اختر المطابقة';

  @override
  String get selectSongToEdit => 'اختر أغنية من القائمة لتعديلها';

  @override
  String get selectStreamingQuality => 'اختر جودة البث';

  @override
  String get selectTrackToStart => 'اختر مقطعاً للبدء';

  @override
  String get selectVersion => 'اختر الإصدار';

  @override
  String session(String id) {
    return 'الجلسة: $id';
  }

  @override
  String get setCountryReleases => 'تعيين الدولة للإصدارات والتصنيفات';

  @override
  String get setCustomTimer => 'ضبط مؤقت مخصص';

  @override
  String get settings => 'الإعدادات';

  @override
  String get share => 'مشاركة';

  @override
  String get shareCodeUsage =>
      'أعط هذا الرمز المكون من 6 أرقام لصديق لتمكينه من استيراد قائمة التشغيل هذه.';

  @override
  String get sharePlaylist => 'مشاركة قائمة التشغيل';

  @override
  String sharePlaylistTitle(String name) {
    return 'مشاركة \"$name\"';
  }

  @override
  String get sharedMode => 'مشترك';

  @override
  String showAllTitles(int count) {
    return 'إظهار كافة الألقاب $count';
  }

  @override
  String get showAnimatedWaves => 'إظهار أمواج متحركة في شريط التشغيل';

  @override
  String get showDebugButton => 'إظهار زر التصحيح العائم';

  @override
  String get showInFolder => 'إظهار في المجلد';

  @override
  String get showLess => 'عرض أقل';

  @override
  String get showMore => 'إظهار المزيد';

  @override
  String get showStatusDiscord => 'إظهار الحالة على ديسكورد';

  @override
  String get showUnlockedOnly => 'إظهار المفتوح فقط';

  @override
  String get shuffle => 'عشوائي';

  @override
  String get shuffleAll => 'تشغيل الكل عشوائياً';

  @override
  String shufflingArtist(String artistName) {
    return 'تشغيل أغاني $artistName عشوائياً...';
  }

  @override
  String get signInWithGoogle => 'تسجيل الدخول باستخدام جوجل';

  @override
  String get signalOutput => 'إخراج الإشارة';

  @override
  String get singleTracks => 'مقاطع فردية';

  @override
  String get sleepTimer => 'مؤقت النوم';

  @override
  String get songAlreadyInPlaylist => 'الأغنية موجودة بالفعل في قائمة التشغيل';

  @override
  String get songInformation => 'معلومات الأغنية';

  @override
  String get songLabelUpper => 'أغنية';

  @override
  String get songTitleKeyword => 'العنوان أو كلمة مفتاحية';

  @override
  String get songs => 'أغاني';

  @override
  String songsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أغنيات',
      one: 'أغنية واحدة',
    );
    return '$_temp0';
  }

  @override
  String songsInLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أغنيات',
      one: 'أغنية واحدة',
    );
    return '$_temp0 في المكتبة';
  }

  @override
  String songsLoadedCount(int count) {
    return 'تم تحميل $count أغنية...';
  }

  @override
  String get southKorea => 'كوريا الجنوبية';

  @override
  String get spanish => 'الإسبانية';

  @override
  String get spectrumBars => 'أعمدة الطيف';

  @override
  String get spotify => 'سبوتيفاي';

  @override
  String get standardDesc => 'MP3 - حجم أصغر، تحميل أسرع';

  @override
  String get standardQuality => 'قياسية (MP3)';

  @override
  String get start => 'بدء';

  @override
  String get startBulkProcess => 'بدء عملية جماعية';

  @override
  String get startedDownloadingAll => 'بدأ تنزيل جميع الأغاني...';

  @override
  String get stateDisabled => 'معطل';

  @override
  String get stateEnabled => 'مفعل';

  @override
  String get statisticsReset => 'تم إعادة ضبط الإحصائيات.';

  @override
  String get stats => 'الإحصائيات';

  @override
  String get statusLabel => 'الحالة';

  @override
  String statusWithText(String status) {
    return 'الحالة: $status';
  }

  @override
  String stopTimer(String time) {
    return 'إيقاف المؤقت ($time)';
  }

  @override
  String get streaming => 'البث';

  @override
  String get streamingQuality => 'جودة البث';

  @override
  String get success => 'نجاح';

  @override
  String get superfanHeader => 'إنجازات المعجبين الخارقين';

  @override
  String get superfanTitles => 'معجب خارق';

  @override
  String get supportDeveloperTooltip => 'دعم المطور للحصول على لقب حصري';

  @override
  String get switchToGridView => 'التبديل إلى عرض الشبكة';

  @override
  String get switchToListView => 'التبديل إلى عرض القائمة';

  @override
  String switchingTo(String title) {
    return 'التبديل إلى';
  }

  @override
  String get syncThemeAlbumArt => 'مزامنة المظهر مع صورة الألبوم';

  @override
  String get system => 'النظام';

  @override
  String get systemDefault => 'افتراضي النظام';

  @override
  String get targetLanguageLyrics => 'اللغة المستهدفة لترجمة الكلمات';

  @override
  String get thai => 'التايلاندية';

  @override
  String get tidalApiStatus => 'Tidal API';

  @override
  String get timeBasedTitles => 'القائمة على الوقت';

  @override
  String get timeListened => 'وقت الاستماع';

  @override
  String get timeOverlordsHeader => 'أسياد الوقت';

  @override
  String timerSetForHours(int count) {
    return 'تم ضبط المؤقت لمدة $count ساعات';
  }

  @override
  String timerSetForMinutes(int count) {
    return 'تم ضبط المؤقت لمدة $count دقائق';
  }

  @override
  String timerSetForSeconds(int count) {
    return 'تم ضبط المؤقت لمدة $count ثواني';
  }

  @override
  String get tintBackground => 'تلوين الخلفية والمصور بلون الأغنية';

  @override
  String get title => 'العنوان';

  @override
  String get titleLabel => 'العنوان';

  @override
  String todayLabel(String size) {
    return 'اليوم: $size';
  }

  @override
  String get toggleDebugButton => 'تبديل وحدة تحكم التصحيح العائمة';

  @override
  String get toggleDebugConsole => 'تبديل وحدة تحكم التصحيح العائمة';

  @override
  String get toggleLyrics => 'تبديل الكلمات';

  @override
  String top3GlobalTooltip(int weeks) {
    return 'تصل لأفضل 3 عالمياً لمدة $weeks أسابيع';
  }

  @override
  String get topArtist => 'أفضل فنان';

  @override
  String get topArtistAndTrack => 'أفضل فنان ومسار';

  @override
  String get topArtists => 'أفضل الفنانين';

  @override
  String topGlobalTooltip(int rank) {
    return 'تصل لأفضل $rank عالمياً للحصول عليه';
  }

  @override
  String get topListeners => 'أفضل المستمعين';

  @override
  String get totalMinutesStat => 'إجمالي الدقائق';

  @override
  String get totalPlays => 'إجمالي مرات التشغيل';

  @override
  String get trackDetails => 'تفاصيل المقطع';

  @override
  String get trackNumber => 'رقم المقطع';

  @override
  String get tracks => 'مقاطع';

  @override
  String get translateLabel => 'ترجمة';

  @override
  String get translateLyrics => 'ترجمة الكلمات';

  @override
  String get translateLyricsTooltip => 'ترجمة كلمات';

  @override
  String get translationLanguage => 'لغة الترجمة';

  @override
  String get turnOffTimer => 'إيقاف المؤقت';

  @override
  String get unauthorize => 'غير مصرح';

  @override
  String get underDevelopment => 'هذه الميزة قيد التطوير';

  @override
  String get underwater => 'تحت الماء';

  @override
  String get unitedKingdom => 'المملكة المتحدة';

  @override
  String get unitedStates => 'الولايات المتحدة';

  @override
  String get unknown => 'غير معروف';

  @override
  String get unknownArtist => 'فنان غير معروف';

  @override
  String get unknownDevice => 'جهاز غير معروف';

  @override
  String get unlink => 'إلغاء الربط';

  @override
  String get unlinkAccount => 'إلغاء ربط الحساب';

  @override
  String get unlinkAccountDesc =>
      'ستبقى إحصائياتك على هذا الجهاز ولكن لن يتم مزامنتها عبر الأجهزة بعد الآن.';

  @override
  String get unlinkAccountQuestion => 'إلغاء ربط الحساب؟';

  @override
  String get unlinkFolder => 'إلغاء ربط المجلد وتنظيف قائمة الأغاني';

  @override
  String get unlinkFolderClear => 'إلغاء ربط المجلد وتنظيف قائمة الأغاني';

  @override
  String unlockedCountLabel(int unlocked, int total) {
    return '$unlocked / $total تم إلغاء القفل';
  }

  @override
  String get unmuteTooltip => 'إلغاء الكتم';

  @override
  String get unsavedChanges => 'تغييرات غير محفوظة';

  @override
  String get upNext => 'التالي';

  @override
  String upNextCount(int count) {
    return 'التالي ($count)';
  }

  @override
  String get upNextSection => 'التالي';

  @override
  String get updateAvailableTitle => 'التحديث متاح';

  @override
  String updateAvailableVersion(String version) {
    return 'إصدار جديد ($version) متاح.';
  }

  @override
  String updateFailed(String error) {
    return 'فشل التحديث: $error';
  }

  @override
  String get updateNow => 'تحديث الآن';

  @override
  String get updatePrompt => 'هل تريد تنزيله وتثبيته الآن؟';

  @override
  String get updatingYtDlp => 'جاري تحديث yt-dlp';

  @override
  String get usbAudioBypass =>
      'تجاوز صوت USB (بيتا) - إخراج DAC مباشر لـ Android 13 وما قبله';

  @override
  String get usbAudioBypassBeta =>
      'تجاوز صوت USB (بيتا) - إخراج DAC مباشر لـ Android 13 وما قبله';

  @override
  String get useDarkTheme => 'استخدام المظهر المظلم';

  @override
  String get useMixedColors => 'استخدام ألوان مختلطة (الأولوية للمزامنة)';

  @override
  String get verifiedDeveloper => 'مطور معتمد';

  @override
  String get version => 'الإصدار';

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get vietnamese => 'الفيتنامية';

  @override
  String get viewQueue => 'عرض القائمة';

  @override
  String get visualizer => 'المصور';

  @override
  String get visualizerStyle => 'نمط المصور';

  @override
  String get wasapiExclusive => 'وضع WASAPI الحصري';

  @override
  String get weekly => 'أسبوعي';

  @override
  String get weeks => 'أسابيع';

  @override
  String get winter => 'الشتاء';

  @override
  String get worldRanking => 'التصنيف العالمي';

  @override
  String get worldTopArtists => 'أفضل الفنانين عالمياً';

  @override
  String get year => 'السنة';

  @override
  String get youMayLike => 'قد يعجبك';

  @override
  String get yourPlaylists => 'قوائم التشغيل الخاصة بك';

  @override
  String get yourTopMix => 'أفضل ميكس لك';

  @override
  String get youtube => 'يوتيوب';

  @override
  String get ytDlpUpdateAvailable => 'تحديث yt-dlp متاح.';

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
  String get offlineModeHeader => 'وضع عدم الاتصال';

  @override
  String get offlineModeTitle => 'وضع عدم الاتصال';

  @override
  String get offlineModeActive => 'نشط';

  @override
  String get offlineModeEnabledStatus => 'تم تمكين وضع عدم الاتصال';

  @override
  String offlineModeDisabledStatus(int count) {
    return 'معطل ($count)';
  }

  @override
  String get offlineModeAllEnabledStatus => 'الكل مُمكّن';

  @override
  String get offlineModeLockdownDesc =>
      'إغلاق الشبكة نشط. يتم حفظ الإحصائيات محليًا.';

  @override
  String get offlineModeMainDesc =>
      'تعطيل جميع خدمات الشبكة وتشغيل المكتبة المحلية فقط.';

  @override
  String get enableOfflineModeQuestion => 'هل تريد تمكين وضع عدم الاتصال؟';

  @override
  String get offlineModeConfirmationDesc =>
      'سيؤدي هذا إلى تعطيل جميع اتصالات الشبكة تمامًا. سيتم إيقاف الميزات التالية:';

  @override
  String get offlineModeSyncRestoreNote =>
      'ستتم مزامنة إحصائياتك تلقائيًا عند إيقاف تشغيل هذا.';

  @override
  String get enableOfflineModeBtn => 'تمكين وضع عدم الاتصال';

  @override
  String get onlineModeRestored =>
      'تم استعادة الوضع عبر الإنترنت. جاري مزامنة الإحصائيات...';

  @override
  String get disableServicesTitle => 'تعطيل الخدمات';

  @override
  String get manageIndividualFeatures => 'إدارة ميزات الإنترنت الفردية';

  @override
  String get featureCloudSync => 'مزامنة إحصائيات السحابة';

  @override
  String get featureCloudSyncDesc => 'يتم حفظ إحصائيات الاستماع محليًا فقط';

  @override
  String get featureCloudSyncLongDesc => 'مزامنة مقاييس الاستماع مع PocketBase';

  @override
  String get featureLeaderboard => 'قائمة المتصدرين العالمية';

  @override
  String get featureLeaderboardDesc => 'توقفت تحديثات الترتيب';

  @override
  String get featureLeaderboardLongDesc => 'إظهار وتحديث ترتيبك علنًا';

  @override
  String get featureOnlineLyrics => 'البحث عن كلمات الأغاني عبر الإنترنت';

  @override
  String get featureOnlineLyricsDesc => 'ملفات .lrc/.ttml المحلية فقط';

  @override
  String get featureOnlineLyricsLongDesc =>
      'جلب كلمات الأغاني من LRCLIB/Spotify';

  @override
  String get featureAiLyrics => 'مولد كلمات الأغاني بالذكاء الاصطناعي';

  @override
  String get featureAiLyricsDesc => 'تم تعطيل كلمات الأغاني المتزامنة تلقائيًا';

  @override
  String get featureAiLyricsLongDesc =>
      'إنشاء كلمات أغاني متزامنة عبر الذاء الاصطناعي';

  @override
  String get featureSpotifyCanvas => 'Spotify Canvas';

  @override
  String get featureSpotifyCanvasDesc => 'تم تعطيل مقاطع الفيديو في الخلفية';

  @override
  String get featureSpotifyCanvasLongDesc => 'مقاطع فيديو الخلفية للمسارات';

  @override
  String get featureOnlineSearch => 'البحث عبر الإنترنت';

  @override
  String get featureOnlineSearchDesc => 'تم تعطيل بحث Spotify/YouTube';

  @override
  String get featureOnlineSearchLongDesc => 'بحث Spotify و YouTube عن بعد';

  @override
  String get featureConnectDevice => 'الاتصال بجهاز';

  @override
  String get featureConnectDeviceDesc =>
      'تم تعطيل التحكم عن بعد وحفلات الاستماع';

  @override
  String get featureConnectDeviceLongDesc => 'التحكم عن بعد وحفلات الاستماع';

  @override
  String get lyricsEditorTitle => 'محرر الكلمات';

  @override
  String get clearAllQuestion => 'مسح الكل؟';

  @override
  String get clearAllDesc =>
      'سيؤدي هذا إلى مسح حالة المحرر الحالية. لن يتم حذف ملفاتك المحلية إلا إذا قمت بالحفظ لاحقاً.';

  @override
  String get clearBtn => 'مسح';

  @override
  String get lyricsApplied => 'تم تطبيق الكلمات على اللوحة!';

  @override
  String get chooseFormat => 'اختر التنسيق المفضل لديك:';

  @override
  String get lrcFormat => 'LRC (مزامنة قياسية)';

  @override
  String get lrcFormatDesc => 'تنسيق عالمي، يعمل في كل مكان.';

  @override
  String get ttmlFormat => 'TTML (دقة عالية)';

  @override
  String get ttmlFormatDesc =>
      'أفضل لإنشاء الذكاء الاصطناعي والمزامنة التفصيلية.';

  @override
  String savedSuccessfully(String extension) {
    return 'تم الحفظ في ملف $extension بنجاح!';
  }

  @override
  String get failedToSave => 'فشل في حفظ ملف الكلمات.';

  @override
  String get generationFailed => 'فشل الإنشاء';

  @override
  String get aiLyricsGenerationTitle => 'إنشاء الكلمات بالذكاء الاصطناعي';

  @override
  String get syncedMode => 'متزامن';

  @override
  String get plainMode => 'نص عادي';

  @override
  String get addLineToTop => 'إضافة إلى الأعلى';

  @override
  String get addLineToEnd => 'إضافة إلى النهاية';

  @override
  String get lyricTextHint => 'نص الكلمات...';

  @override
  String get insertAfter => 'إدراج بعد';

  @override
  String get removeLine => 'إزالة السطر';

  @override
  String get romajiHint => 'روماجي / ترجمة صوتية (اختياري)...';

  @override
  String get startLabel => 'البداية: ';

  @override
  String get setStartTooltip => 'تعيين البداية عند الموضع الحالي';

  @override
  String get endLabel => 'النهاية: ';

  @override
  String get setEndTooltip => 'تعيين النهاية عند الموضع الحالي';

  @override
  String get playFromLine => 'تشغيل من هذا السطر';

  @override
  String get pasteLyricsHint => 'الصق كلماتك هنا...';

  @override
  String get applyBtn => 'تطبيق';

  @override
  String get saveLocallyBtn => 'حفظ محلياً';

  @override
  String get editLyricsTooltip => 'تعديل الكلمات';

  @override
  String get saveLyricsTitle => 'حفظ الكلمات';

  @override
  String get aiGenerate => 'إنشاء بالذكاء الاصطناعي';

  @override
  String get aiLyricsInitializing => 'جاري التهيئة...';

  @override
  String get aiLyricsUploading => 'جاري رفع الأغنية إلى الخادم...';

  @override
  String get aiLyricsUploadFailed => 'خطأ: فشل الرفع.';

  @override
  String get aiLyricsUploadSuccess => 'اكتمل الرفع!';

  @override
  String get aiLyricsVerifying => 'جاري التحقق من حالة الخادم...';

  @override
  String get aiLyricsStatusOk => 'رمز الحالة 200 OK!';

  @override
  String get aiLyricsPolling => 'جاري الحصول على الكلمات... يرجى الصبر!';

  @override
  String get aiLyricsReceiving => 'تم استلام الكلمات';

  @override
  String get aiLyricsParsing => 'جاري تحليل الكلمات...';

  @override
  String get aiLyricsSuccess => 'تم إنشاء الكلمات بنجاح!';

  @override
  String get aiLyricsLocalFileMissing => 'خطأ: ملف الصوت المحلي غير موجود.';

  @override
  String get aiLyricsComplete => 'اكتمل!';

  @override
  String get externalLinkDetected => 'تم اكتشاف رابط خارجي';

  @override
  String get gofileDownloadFailedPrompt =>
      'فشل التنزيل التلقائي بسبب قيود الشبكة أو الخادم الصارمة.\\n\\nهل ترغب في فتح صفحة تنزيل Gofile في متصفح النظام، أم نسخ الرابط للتنزيل يدويًا؟';

  @override
  String get copyLink => 'نسخ الرابط';

  @override
  String get openBrowser => 'فتح المتصفح';

  @override
  String get linkCopied => 'تم نسخ الرابط إلى الحافظة!';

  @override
  String get waitingForServerResponse => 'في انتظار استجابة الخادم...';

  @override
  String queuePositionPleaseWait(int position) {
    return 'طابور $position... يرجى الانتظار';
  }

  @override
  String get processingOnServer => 'جاري المعالجة على الخادم...';
}
