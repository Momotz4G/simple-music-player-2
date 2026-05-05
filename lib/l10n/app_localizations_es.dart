// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get aboutEducationalPurpose =>
      'Esta aplicación ha sido desarrollada únicamente con fines individuales y educativos.';

  @override
  String get aboutLicenses => 'Acerca de y Licencias';

  @override
  String get aboutNotForCommercial => 'No apto para uso comercial.';

  @override
  String get accentColor => 'Color de acento';

  @override
  String get access => 'Acceso';

  @override
  String get accessCode => 'Código de acceso';

  @override
  String get accountDataMergeDesc =>
      'Al sincronizar, tu nombre de perfil y avatar se actualizarán, pero los minutos de escucha de tu dispositivo actual se fusionarán con éxito en el total de la cuenta.';

  @override
  String get accountLinked => 'Cuenta vinculada';

  @override
  String get accountLinkedSuccessfully => '¡Cuenta vinculada con éxito!';

  @override
  String get achievementsUnlocked => 'Logros desbloqueados';

  @override
  String get activeNoResampling => 'Activo (No es necesario resamplear)';

  @override
  String get add => 'Añadir';

  @override
  String get addFiles => 'Añadir archivos';

  @override
  String get addFolder => 'Añadir carpeta';

  @override
  String get addFoldersScan => 'Añadir carpetas para escanear';

  @override
  String get addToFavorite => 'Añadir a favoritos';

  @override
  String get addToPlaylist => 'Añadir a lista de reproducción';

  @override
  String get addToQueue => 'Añadir a la cola';

  @override
  String addedFolder(Object folder) {
    return 'Carpeta añadida: $folder';
  }

  @override
  String get addedToLikedSongs => 'Añadido a canciones que te gustan';

  @override
  String get addedToPlaylistSuccess => 'Añadido a la lista de reproducción';

  @override
  String get addedToQueue => 'Añadido a la cola';

  @override
  String get album => 'Álbum';

  @override
  String get albumAddedToPlaylists => 'Álbum añadido a listas de reproducción';

  @override
  String get albumLabel => 'Álbum';

  @override
  String get albumRemovedFromPlaylists =>
      'Álbum eliminado de listas de reproducción';

  @override
  String get albums => 'Álbumes';

  @override
  String get allDownloadsRemoved => 'Todas las descargas eliminadas';

  @override
  String get allRightsReserved => 'Todos los derechos reservados.';

  @override
  String get allTime => 'Todo el tiempo';

  @override
  String get alreadyInLikedSongs => 'Ya está en canciones que te gustan';

  @override
  String get android14BitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidAudioEffectsNote =>
      'Nota: Los efectos de audio solo están disponibles en dispositivos Android.';

  @override
  String get androidAudioTrack => 'Android AudioTrack';

  @override
  String get androidBitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidMixer => 'Mezclador de Android';

  @override
  String get appearance => 'Apariencia';

  @override
  String get applyOnRestart => 'Los cambios se aplicarán al reiniciar.';

  @override
  String get arabic => 'Árabe';

  @override
  String get artist => 'Artista';

  @override
  String get artistLabel => 'Artista';

  @override
  String get artists => 'Artistas';

  @override
  String get atmospheres => 'Atmósferas';

  @override
  String get audioFormat => 'Formato de audio';

  @override
  String get audioOutput => 'Salida de audio';

  @override
  String get audioOutputDevice => 'Dispositivo de salida de audio';

  @override
  String get audioQuality => 'Calidad de audio';

  @override
  String get audioSource => 'Origen del audio';

  @override
  String get audiophileDAC =>
      'Activar cuando se reproduzca en DACs audiófilos (requiere reinicio)';

  @override
  String get autoAddSimilar =>
      'Añadir canciones similares automáticamente cuando la cola esté terminando';

  @override
  String get autoClearAfter24h => 'Después de 24 horas';

  @override
  String get autoClearAfter7d => 'Después de 7 días';

  @override
  String get autoClearCache => 'Limpiar caché automáticamente';

  @override
  String get autoClearDisabled => 'Desactivado';

  @override
  String get autoClearEvery30m => 'Cada 30 min (Solo al escuchar)';

  @override
  String get autoClearOnClose => 'Al cerrar la app';

  @override
  String get autoFixComingSoon => 'Auto-corrección (Próximamente)';

  @override
  String get autoRestartNotSupported =>
      'El reinicio automático no es compatible. Por favor, reinicia manualmente.';

  @override
  String autoTagContent(int count, String sourceName) {
    return 'Esto buscará todas las $count canciones de \"$sourceName\" en Spotify y sobrescribirá las etiquetas automáticamente.\\n\\nEsta acción no se puede deshacer.';
  }

  @override
  String autoTagTitle(String sourceName) {
    return '⚠️ ¿Auto-etiquetar $sourceName?';
  }

  @override
  String get automatic => 'Automático';

  @override
  String automaticTitleLabel(String title) {
    return 'Automático: $title';
  }

  @override
  String get autumn => 'Otoño';

  @override
  String get avatarPickerDesc =>
      'Selecciona una plantilla o importa tu propia foto';

  @override
  String get beFirstToClaim => '¡Sé el primero en reclamar el primer puesto!';

  @override
  String get behavioralHeader => 'LOGROS DE COMPORTAMIENTO';

  @override
  String get behavioralTitles => 'DE COMPORTAMIENTO';

  @override
  String get binariesUpdateRequired => 'Actualización de binarios requerida';

  @override
  String get bitDepthLabel => 'Profundidad de bits';

  @override
  String get bitPerfectEnabled =>
      'Modo bit-perfect activado. El control de volumen puede no funcionar.';

  @override
  String get bitPerfectWindows =>
      'Audio bit-perfect con frecuencia de muestreo automática (requiere reinicio)';

  @override
  String get bitrateLabel => 'Tasa de bits';

  @override
  String get bitsLabel => 'Bits';

  @override
  String get brazil => 'Brasil';

  @override
  String get browse => 'Explorar';

  @override
  String get bypassSystemMixer =>
      'Omitir el mezclador del sistema para USB DAC';

  @override
  String get bypassedBitPerfect => 'Omitido (Bit-Perfect)';

  @override
  String get cacheCleared => '¡Caché borrada con éxito!';

  @override
  String get cached => 'En caché';

  @override
  String get cancel => 'Cancelar';

  @override
  String get championChampionTooltip =>
      'Logra el Top 1 Global por 5 semanas diferentes';

  @override
  String get change => 'Cambiar';

  @override
  String get changeFolder => 'Cambiar carpeta';

  @override
  String get changeFormatInSettings =>
      'Por favor cambia el formato de salida en ajustes';

  @override
  String get changeLabel => 'CAMBIAR';

  @override
  String get changeLanguage => 'Cambiar idioma de la aplicación';

  @override
  String get changesApplyRestart => 'Los cambios se aplicarán al reiniciar.';

  @override
  String get changingAudioDeviceRestart =>
      'Se requiere reiniciar la aplicación para aplicar los cambios del dispositivo de salida de audio.\\n\\n¿Reiniciar ahora?';

  @override
  String get channelsLabel => 'Canales';

  @override
  String get checkAgain => 'Comprobar de nuevo';

  @override
  String get checkInternetConnection => 'Verifica tu conexión a internet';

  @override
  String get checkNetworkTryAgain => 'Comprueba tu red e inténtalo de nuevo';

  @override
  String get chinese => 'Chino';

  @override
  String get chooseAccentColor => 'Elige tu color estático favorito';

  @override
  String get chooseAnimationType => 'Elige el tipo de animación';

  @override
  String get chooseArtist => 'ELEGIR ARTISTA';

  @override
  String get chooseAvatar => 'Elegir avatar';

  @override
  String get chooseYourTitle => 'Elige tu título';

  @override
  String get circularPulse => 'Pulso circular';

  @override
  String get clearAll => 'Borrar todo';

  @override
  String get clearHistory => 'Borrar historial';

  @override
  String get clearImported => 'Borrar importados';

  @override
  String get clearMetadataCache => 'Borrar caché de metadatos y arte';

  @override
  String get clearPlayHistory =>
      'Borrar historial de reproducción y tiempo de escucha';

  @override
  String get clearStreamingCache => 'Borrar caché de streaming';

  @override
  String get close => 'Cerrar';

  @override
  String get cloud => 'Nube';

  @override
  String get codeCopied => '¡Código copiado al portapapeles!';

  @override
  String get codeMust6Digits => 'El código debe tener 6 dígitos';

  @override
  String get codecLabel => 'Códec';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get community => 'Comunidad';

  @override
  String get competitiveTitles => 'COMPETITIVO';

  @override
  String get confirm => 'Confirmar';

  @override
  String get connect => 'Conectar';

  @override
  String get connectToADevice => 'Conectar a un dispositivo';

  @override
  String get connected => 'Conectado';

  @override
  String connectedToDac(String deviceName) {
    return 'Conectado a $deviceName - Omisión USB activada';
  }

  @override
  String get connectedUsbDacs => 'DACs USB conectados:';

  @override
  String get connecting => 'Conectando...';

  @override
  String get connectionLostLeaderboard => 'Conexión perdida';

  @override
  String get connectionLostLeaderboardDesc =>
      'La Clasificación Global requiere una conexión activa para sincronizar tus estadísticas y obtener los rankings mundiaux.';

  @override
  String consecutivePlaysTooltip(int count) {
    return 'Escucha la misma canción $count veces seguidas';
  }

  @override
  String get contentRegion => 'Región de contenido';

  @override
  String get copyCode => 'Copiar código';

  @override
  String get couldNotDownloadFlac => 'No se pudo descargar FLAC.';

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return '$_temp0';
  }

  @override
  String get createPlaylist => 'Crear lista de reproducción';

  @override
  String creatingPlaylistWithTracks(int count) {
    return 'Creando lista de reproducción con $count pistas...';
  }

  @override
  String get crossfade => 'Crossfade';

  @override
  String crossfadeDesc(String seconds) {
    return 'Fundido entre pistas ($seconds s)';
  }

  @override
  String get crownedChampionTitlesHeader => 'TÍTULOS DE CAMPEÓN CORONADO';

  @override
  String get customDevice => 'Dispositivo personalizado';

  @override
  String get customSelected => 'Selección personalizada';

  @override
  String get customTime => 'Tiempo personalizado';

  @override
  String get cyberpunk => 'Cyberpunk';

  @override
  String get daily => 'Diario';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get dataCleanup => 'Datos y limpieza';

  @override
  String get dataUsage => 'Uso de datos';

  @override
  String get daysShort => 'D';

  @override
  String get debugging => 'Depuración';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleteDownloadsConfirm =>
      'Esto eliminará todas las canciones descargadas en este dispositivo para esta lista de reproducción.';

  @override
  String get deleteDownloadsTitle => '¿Eliminar descargas?';

  @override
  String deleteFileContent(String filename) {
    return '¿Estás seguro de que quieres eliminar \"$filename\"?\\nEsta acción no se puede deshacer.';
  }

  @override
  String get deleteFileTitle => '¿Eliminar archivo?';

  @override
  String get deletePlaylist => 'Eliminar lista de reproducción';

  @override
  String deletePlaylistConfirm(String name) {
    return '¿Estás seguro de que quieres eliminar \"$name\"?';
  }

  @override
  String get deletePlaylistPermanentConfirm =>
      '¿Estás seguro de que quieres eliminar esta lista de reproducción? (Esta acción no se puede deshacer)';

  @override
  String get deletePlaylistTitle => '¿Eliminar lista de reproducción?';

  @override
  String get deletePreset => 'Eliminar ajuste';

  @override
  String get desertMirage => 'Espejismo del desierto';

  @override
  String get developerExclusiveTooltip =>
      'Exclusivo para los desarrolladores de esta aplicación';

  @override
  String deviceNameLabel(String deviceName) {
    return 'Dispositivo: $deviceName';
  }

  @override
  String get disableCanvas => 'Desactivar Canvas';

  @override
  String get disableRomanization => 'Desactivar romanización';

  @override
  String get disablingSharingWarning =>
      'Al desactivar el uso compartido se eliminarán permanentemente el código y los datos del servidor para ahorrar espacio.';

  @override
  String get discNumber => 'Número de disco';

  @override
  String get discography => 'Discografía';

  @override
  String get discordRPC => 'Discord Rich Presence';

  @override
  String get doYouRemember => '¿Recuerdas esto?';

  @override
  String get donate => 'Donar';

  @override
  String get download => 'Descargar';

  @override
  String get downloadAll => 'Descargar todo';

  @override
  String get downloadComplete => 'Descarga completada';

  @override
  String get downloadCompleteNotification => 'Descarga completada';

  @override
  String get downloadError => 'Error de descarga';

  @override
  String get downloadFailed => 'Descarga fallida';

  @override
  String get downloadLocation => 'Ubicación de descarga';

  @override
  String get downloadPathReset =>
      'Ruta de descarga restablecida al valor por defecto.';

  @override
  String downloadPathUpdated(Object path) {
    return 'Ruta de descarga actualizada: $path';
  }

  @override
  String get downloadSong => 'Descargar canción';

  @override
  String get downloadStarted => 'Descarga iniciada';

  @override
  String downloadedTo(String path) {
    return 'Descargado en: $path';
  }

  @override
  String get downloading => 'Descargando';

  @override
  String get downloadingFlac => 'Descargando FLAC';

  @override
  String downloadingFormat(String format) {
    return 'Descargando $format';
  }

  @override
  String get downloadingUpdate => 'Descargando actualización';

  @override
  String get downloads => 'Descargas';

  @override
  String get dspLabel => 'DSP';

  @override
  String get editMetadata => 'Editar metadatos';

  @override
  String get editNickname => 'Editar apodo';

  @override
  String get editor => 'Editor';

  @override
  String get emptyMailbox => 'Vaciar buzón';

  @override
  String get emptyMailboxDesc =>
      'Esto eliminará todos los mensajes permanentemente.';

  @override
  String get emptyMailboxTitle => '¿Vaciar buzón?';

  @override
  String get emptyPlaylist => 'Lista vacía';

  @override
  String get emptyPlaylistSubtitle => 'Crear una nueva lista vacía';

  @override
  String get enableAlphabetIndexer =>
      'Activar indexador de desplazamiento alfabético';

  @override
  String get enableAlphabetIndexerSubtitle =>
      'Mostrar indexación de barra lateral A-Z en la vista de lista móvil';

  @override
  String get enableBarVisualizer => 'Activar visualizador de barras';

  @override
  String get endlessQueue => 'Cola interminable';

  @override
  String get engineLabel => 'Motor';

  @override
  String get english => 'Inglés';

  @override
  String get enterAdminAccessCode =>
      'Por favor ingresa el código de acceso de administrador';

  @override
  String get enterAdminCode =>
      'Por favor ingresa el código de acceso de administrador';

  @override
  String get enterDuration => 'Introduce la duración...';

  @override
  String get enterPresetName => 'Introduce nombre de ajuste (ej: Mis Bajos)';

  @override
  String get enterShareCode =>
      'Introduzca el código de uso compartido de 6 dígitos';

  @override
  String get eqLabel => 'EQ';

  @override
  String get equalizer => 'Ecualizador';

  @override
  String get equipTitle => 'EQUIPAR TÍTULO';

  @override
  String get equipped => 'EQUIPADO';

  @override
  String get error => 'Error';

  @override
  String get errorCouldNotCreateSession => 'Error: No se pudo crear la sesión.';

  @override
  String errorDeleting(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String get errorSearchingStream => 'Error al buscar streaming.';

  @override
  String get exclusiveMode => 'Exclusivo';

  @override
  String get exclusiveModeWarning =>
      'Advertencia: El modo exclusivo funciona mejor si seleccionas un dispositivo específico arriba en lugar de usar el predeterminado.';

  @override
  String get exclusiveTitles => 'EXCLUSIVO';

  @override
  String get exclusiveTitlesHeader => 'TÍTULOS EXCLUSIVOS';

  @override
  String get exclusiveWarning =>
      'Advertencia: El modo exclusivo funciona mejor si seleccionas un dispositivo específico arriba en lugar de usar el predeterminado.';

  @override
  String get exitApp => 'Salir';

  @override
  String get expand => 'Expandir';

  @override
  String get externalFiles => 'Archivos externos';

  @override
  String get fadingAtEnd =>
      'Temporizador de sueño: Desvaneciéndose al final de la pista...';

  @override
  String get failedDisableSharing => 'Error al desactivar el uso compartido.';

  @override
  String get failedEnableSharing =>
      'Error al activar el uso compartido. Compruebe la conexión.';

  @override
  String get failedFetchPlaylistInfo =>
      'No se pudo obtener la información de la lista de reproducción';

  @override
  String get failedToConnectDac =>
      'Error al conectar con el DAC. Comprueba los permisos USB.';

  @override
  String get failedToGenerateCode =>
      'Error al generar el código de uso compartido. Compruebe la conexión.';

  @override
  String get failedToSetAvatar => 'Error al establecer la plantilla de avatar';

  @override
  String get failedToUpdateMetadata => 'Error al actualizar metadatos';

  @override
  String get favoriteTrack => 'Canción favorita';

  @override
  String get fetchingCanvas => 'Obteniendo Canvas...';

  @override
  String get fetchingLossless => 'Obteniendo sin pérdida...';

  @override
  String get fetchingLosslessAudio => 'Obteniendo audio sin pérdida...';

  @override
  String get fetchingMetadataSpotify => 'Obteniendo metadatos de Spotify...';

  @override
  String get fetchingPlaylist => 'Obteniendo lista de reproducción...';

  @override
  String get fetchingPlaylistInfo =>
      'Obteniendo información de la lista de reproducción...';

  @override
  String get fetchingSharedPlaylist =>
      'Obteniendo lista de reproducción compartida...';

  @override
  String fetchingTracksFrom(String name) {
    return 'Obteniendo pistas de \"$name\"...';
  }

  @override
  String get fileLocation => 'Ubicación del archivo';

  @override
  String get fileMissingHistory =>
      'Falta el archivo y no está en el historial.';

  @override
  String get fileName => 'Nombre de archivo';

  @override
  String get fileSizeLabel => 'Tamaño del archivo';

  @override
  String get files => 'Archivos';

  @override
  String get filters => 'Filtros';

  @override
  String get findingBestMatchYoutube =>
      'Buscando la mejor coincidencia en YouTube...';

  @override
  String get findingStream => 'Buscando origen de streaming...';

  @override
  String get finishUpdate => 'Finalizar actualización';

  @override
  String get finishes => 'Posiciones';

  @override
  String get fixAll => 'Corregir todos';

  @override
  String get flacError => 'Error FLAC';

  @override
  String get flacNote =>
      'Nota: FLAC solo está disponible para descargas de pistas individuales. Las descargas masivas de listas de reproducción usarán formato M4A.';

  @override
  String get flacSavedToDownloads => 'FLAC guardado en la carpeta de descargas';

  @override
  String get flacUnavailable => 'FLAC no disponible';

  @override
  String get flacUnavailableDesc =>
      'FLAC no está disponible, falló la descarga. Intenta cambiar los ajustes.';

  @override
  String get flacUnavailableNotification => 'FLAC no disponible';

  @override
  String get fluidWave => 'Onda fluida';

  @override
  String folderPath(String path) {
    return 'Carpeta: $path';
  }

  @override
  String get folders => 'Carpetas';

  @override
  String get formatLabel => 'Formato';

  @override
  String get formatSaved => '¡Formato guardado!';

  @override
  String foundExistingAccount(String name) {
    return 'Encontramos una cuenta existente para \'$name\'.';
  }

  @override
  String foundResults(int songCount, int albumCount, int artistCount) {
    return 'Encontradas $songCount canciones, $albumCount álbumes y $artistCount artistas.';
  }

  @override
  String foundYoutubeResults(int count) {
    return 'Se encontraron $count resultados en YouTube';
  }

  @override
  String freeUpSpace(String size) {
    return 'Liberar espacio (Actual: $size)';
  }

  @override
  String get french => 'Francés';

  @override
  String fromLibraryCount(int count) {
    return 'De la biblioteca ($count)';
  }

  @override
  String get fromLibrarySection => 'De la biblioteca';

  @override
  String get fullScreenPlayerTooltip => 'Reproductor a pantalla completa';

  @override
  String get galacticSpace => 'Espacio galáctico';

  @override
  String get gaplessPlayback => 'Reproducción sin Pausas';

  @override
  String get gaplessPlaybackDesc => 'Elimina el silencio entre las pistas';

  @override
  String get general => 'General';

  @override
  String get generatingShareCode => 'Generando código de uso compartido...';

  @override
  String get genre => 'Género';

  @override
  String get german => 'Alemán';

  @override
  String get globalLeaderboard => 'Clasificación Global';

  @override
  String get globalMailbox => 'Buzón global';

  @override
  String get globalRank => 'Rango Global';

  @override
  String get globalRankings => 'Clasificaciones globales';

  @override
  String get globalRankingsDesc =>
      '¡Mira los mejores oyentes diarios, semanales y de todos los tiempos!';

  @override
  String get goToArtist => 'Ir al artista';

  @override
  String get goToLocalLibraryToSelect =>
      'Ve a \"Biblioteca local\" para seleccionar una carpeta de música.';

  @override
  String get goodAfternoon => 'Buenas tardes';

  @override
  String get goodEvening => 'Buenas noches';

  @override
  String get goodMorning => 'Buenos días';

  @override
  String get googleAccount => 'Cuenta de Google';

  @override
  String get grantAccess => 'Otorgar acceso';

  @override
  String get grantPermission => 'Otorgar permiso';

  @override
  String get hallOfFameHeader => 'LOGROS DEL SALÓN DE LA FAMA';

  @override
  String get hallOfFameTitles => 'SALÓN DE LA FAMA';

  @override
  String get hideCanvas =>
      'No mostrar videos de Spotify Canvas, mostrar portada en su lugar';

  @override
  String get hideRomajiPinyin =>
      'No mostrar Romaji/Pinyin debajo de letras en coreano, japonés o chino';

  @override
  String get hideTranslation => 'Ocultar traducción';

  @override
  String get highDesc => 'M4A - Mejor audio, rendimiento equilibrado';

  @override
  String get highQuality => 'Alta calidad (M4A)';

  @override
  String get hindi => 'Hindi';

  @override
  String get history => 'Historial';

  @override
  String get historySection => 'Historial';

  @override
  String get home => 'Inicio';

  @override
  String get hourShort => 'h';

  @override
  String hoursDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '1 hora',
    );
    return '$_temp0';
  }

  @override
  String get hoursShort => 'H';

  @override
  String get ignoreSubfolderScan => 'Ignorar escaneo de subcarpetas';

  @override
  String get importAdditionalPaths => 'Importar rutas adicionales';

  @override
  String get importChoice => 'Importar';

  @override
  String importFailed(String error) {
    return 'Error de importación: $error';
  }

  @override
  String get importFromGallery => 'Importar de la galería';

  @override
  String get importFromSpotify => 'Importar de Spotify';

  @override
  String get importFromSpotifySubtitle => 'Pega un enlace de lista de Spotify';

  @override
  String get importFromYoutubeMusic => 'Importar de YouTube Music';

  @override
  String get importFromYoutubeMusicSubtitle =>
      'Pega un enlace de lista de YouTube Music';

  @override
  String get importLabel => 'Importar';

  @override
  String get importLyricsFile => 'Importar archivo de letras';

  @override
  String get importLyricsTooltip => 'Importar letras';

  @override
  String get importSpotifyPlaylist => 'Importar lista de Spotify';

  @override
  String get importViaCode => 'Importar mediante código';

  @override
  String get importViaCodeSubtitle =>
      'Importar una lista de reproducción compartida por un amigo';

  @override
  String get importYoutubeMusicPlaylist => 'Importar lista de YouTube Music';

  @override
  String importedPlaylistName(String name) {
    return '¡\"$name\" importada correctamente!';
  }

  @override
  String importedTracks(int count) {
    return '¡$count pistas importadas correctamente!';
  }

  @override
  String get indonesia => 'Indonesia';

  @override
  String get indonesian => 'Indonesio';

  @override
  String get inputLabel => 'Entrada';

  @override
  String get installNow => 'Instalar ahora';

  @override
  String get integration => 'Integración';

  @override
  String get invalidAccessCode => 'Código de acceso inválido';

  @override
  String get invalidCode => 'Código de acceso inválido';

  @override
  String get invalidSpotifyUrl =>
      'URL de lista de reproducción de Spotify no válida';

  @override
  String get invalidYoutubeMusicUrl =>
      'URL de lista de reproducción de YouTube Music no válida';

  @override
  String get japan => 'Japón';

  @override
  String get japanese => 'Japonés';

  @override
  String get joinUs => 'Únete a nosotros';

  @override
  String get jumpBackIn => 'Vuelve a escuchar';

  @override
  String get justEnjoyVibes => 'Solo disfruta de la música.';

  @override
  String get korean => 'Coreano';

  @override
  String get language => 'Idioma';

  @override
  String last30DaysLabel(String size) {
    return 'Últimos 30 días: $size';
  }

  @override
  String last7DaysLabel(String size) {
    return 'Últimos 7 días: $size';
  }

  @override
  String get later => 'Más tarde';

  @override
  String get library => 'Biblioteca';

  @override
  String get libraryData => 'Datos de la biblioteca';

  @override
  String get libraryNotLoaded => 'Biblioteca no cargada.';

  @override
  String get libraryPathReset => 'Ruta de la biblioteca restablecida.';

  @override
  String get likedSongs => 'Canciones que te gustan';

  @override
  String get linkAccount => 'Vincular cuenta';

  @override
  String get linkAccountDesc => 'Sincroniza y restaura tu progreso con Google';

  @override
  String listenMinutesTooltip(String minutes) {
    return 'Escucha $minutes minutos de música';
  }

  @override
  String get listeningParty => 'Fiesta de escucha';

  @override
  String get listeningStats => 'Estadísticas de escucha';

  @override
  String get loadingCanvas => 'Cargando Canvas...';

  @override
  String get loadingDevices => 'Cargando dispositivos...';

  @override
  String get loadingError =>
      'Error al cargar los detalles. Por favor, inténtelo de nuevo.';

  @override
  String get loadingLyrics => 'Cargando letras...';

  @override
  String get localPlayHistorySaved =>
      'Tu historial de reproducción local no se borrará.';

  @override
  String get local_library => 'Biblioteca local';

  @override
  String get lockedAtmosphere => 'Bloqueado mientras una atmósfera está activa';

  @override
  String get losslessDesc => 'FLAC - Calidad sin pérdida de Deezer/Tidal';

  @override
  String get losslessNote =>
      'Transmitirá FLAC sin pérdida de Deezer/Tidal si está disponible. Recurrirá a M4A si no es así.';

  @override
  String get losslessQuality => 'Sin pérdida (Auto)';

  @override
  String get lunarNewYear => 'Año Nuevo Lunar';

  @override
  String get lyricsByLRCLIB => 'Letras por LRCLIB';

  @override
  String get lyricsSaveError => 'Error al guardar las letras';

  @override
  String get lyricsSavedSuccess => 'Letras guardadas en archivo .lrc';

  @override
  String get lyricsTooltip => 'Letras';

  @override
  String get madeForYou => 'Hecho para ti';

  @override
  String get manualSearch => 'Búsqueda manual';

  @override
  String get mergeAccountData => '¿Fusionar datos de la cuenta?';

  @override
  String get metadataCacheCleared =>
      'Caché de metadatos borrada y reescaneo de biblioteca iniciado';

  @override
  String get metadataEditorInfo =>
      'Puedes buscar y corregir rápidamente en el Editor de Metadatos.';

  @override
  String get metadataEditorNote =>
      'Nota: Después de que el estado indique \"Guardado con éxito\", el arte del álbum puede cambiar. Esto no significa que no se haya guardado, sino que es un problema de caché dentro de la aplicación que estamos corrigiendo. Puedes confirmarlo en un explorador de archivos.';

  @override
  String get metadataUpdated => 'Metadatos actualizados';

  @override
  String get metadata_editor => 'Editor de metadatos';

  @override
  String get min => 'min';

  @override
  String get minShortLabel => 'min';

  @override
  String get miniPlayer => 'Mini reproductor';

  @override
  String get minimizeToTray => 'Minimizar a la bandeja';

  @override
  String get minimizeToTrayDescription =>
      'Cerrar la app a la bandeja del sistema en lugar de salir';

  @override
  String get minsShort => 'M';

  @override
  String get minsShortLabel => 'min';

  @override
  String get minuteShort => 'min';

  @override
  String get minutes => 'minutos';

  @override
  String minutesDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutos',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get moreOptionsTooltip => 'Más opciones';

  @override
  String get mostListened => 'Más escuchado';

  @override
  String get mostListenedArtist => 'Artista más escuchado';

  @override
  String get musicFolderLocation => 'Ubicación de la carpeta de música';

  @override
  String get musicSearch => 'Búsqueda de música';

  @override
  String musicWillStopIn(String label) {
    return 'La música se detendrá en $label';
  }

  @override
  String get muteTooltip => 'Silenciar';

  @override
  String myTopTrackOn(String header) {
    return '¡Mi $header en Simple Player! 🎵';
  }

  @override
  String get nativeRate => 'Freq. nativa';

  @override
  String get navigation => 'Navegación';

  @override
  String get newPlaylist => 'Nueva lista de reproducción';

  @override
  String get nextTrack => 'Siguiente pista';

  @override
  String get nicknameHint => 'Introduce tu apodo';

  @override
  String get nicknameLabel => 'Apodo';

  @override
  String get nicknameRequired => 'Apodo Requerido';

  @override
  String get nicknameRequiredDesc =>
      '¡Debes establecer un apodo personalizado primero para ver la clasificación global!';

  @override
  String get nicknameTakenDesc =>
      'Este apodo ya está en uso globalmente. Por favor, elige otro.';

  @override
  String get nicknameTakenTitle => 'Apodo ocupado';

  @override
  String get noAlbumsFound => 'No se encontraron álbumes';

  @override
  String get noArtistStatsYet => 'Aún no hay estadísticas de artistas.';

  @override
  String get noArtistsFound => 'No se encontraron artistas.';

  @override
  String get noDownloadsFound => 'No se encontraron descargas';

  @override
  String get noFolderSelected => 'Ninguna carpeta seleccionada';

  @override
  String get noHistoryYet => 'Aún no hay historial';

  @override
  String get noInternetConnection => 'Sin conexión a internet';

  @override
  String get noLyricsAvailable => 'No hay letras disponibles';

  @override
  String get noMessages => 'No hay mensajes en tu buzón';

  @override
  String get noMusicPlaying => 'No hay música sonando';

  @override
  String get noPlaylistsFound => 'No se encontraron listas de reproducción';

  @override
  String get noPlaylistsYet => 'Aún no hay listas de reproducción';

  @override
  String get noRankingsYet =>
      'Todavía no hay clasificaciones para este período de tiempo.';

  @override
  String get noResultsFound => 'No se encontraron resultados';

  @override
  String get noSongPlaying => 'No hay canción sonando';

  @override
  String get noSongsAdded => 'No se han añadido canciones aún';

  @override
  String get noSongsInFolder => 'No se encontraron canciones en esta carpeta.';

  @override
  String get noSpotifyResults => 'No se encontraron resultados en Spotify.';

  @override
  String get noStatsYet => 'Aún no hay estadísticas.';

  @override
  String get noStreamMatch =>
      'No se encontró ninguna coincidencia en streaming.';

  @override
  String get noSuggestionsFound => 'No se encontraron sugerencias.';

  @override
  String get noSyncedLyricsFound => 'No se encontraron letras sincronizadas';

  @override
  String get noTracksFound =>
      'No se encontraron pistas en la lista de reproducción';

  @override
  String get noUsbDacDetected =>
      'No se detectó ningún USB DAC. Conecta un dispositivo de audio USB y toca Escanear.';

  @override
  String get noUsersFound => 'No se encontraron usuarios';

  @override
  String get noYoutubeResults => 'No se encontraron resultados en YouTube';

  @override
  String get none => 'Ninguna';

  @override
  String get nordicAurora => 'Aurora nórdica';

  @override
  String notRank(int rank) {
    return 'No es rango $rank';
  }

  @override
  String get notRanked => 'Sin rango';

  @override
  String get notRankedTop3 => 'FUERA DEL TOP 3';

  @override
  String get nowPlaying => 'Reproduciendo ahora';

  @override
  String get nowPlayingHeader => 'Sonando ahora';

  @override
  String get nowPlayingSection => 'Sonando ahora';

  @override
  String get offline => 'Desconectado';

  @override
  String get offlineStatus => 'Fuera de línea';

  @override
  String get ok => 'OK';

  @override
  String get online => 'En línea';

  @override
  String get onlyScanSelected =>
      'Solo escanear carpetas seleccionadas (por defecto encendido)';

  @override
  String get opacity => 'Opacidad';

  @override
  String opacityLabel(int percent) {
    return 'Opacidad: $percent%';
  }

  @override
  String get openProfile => 'Abrir Perfil';

  @override
  String get openSourceLicenses => 'Licencias de código abierto';

  @override
  String get outputLabel => 'Salida';

  @override
  String get overwrite => 'Sobrescribir';

  @override
  String get overwriteLrcWarning =>
      'Ya existe un archivo .lrc local para esta canción.\\n¿Quieres sobrescribirlo?';

  @override
  String get parsingPlaylistData =>
      'Analizando datos de la lista de reproducción...';

  @override
  String get pathLabel => 'Ruta';

  @override
  String get permissionRequired => 'Permiso requerido';

  @override
  String get permissionRequiredDesc =>
      'Se requiere el permiso de \"Acceso a todos los archivos\" para editar etiquetas. Esto permitirá modificar tus archivos de música directamente.';

  @override
  String get play => 'Reproducir';

  @override
  String playCountLabel(int count) {
    return '$count reproducciones';
  }

  @override
  String get playNext => 'Reproducir siguiente';

  @override
  String get playPause => 'Reproducir / Pausa';

  @override
  String get playQueue => 'Cola de reproducción';

  @override
  String get playback => 'Reproducción';

  @override
  String get playbackError => 'Error de reproducción';

  @override
  String get player => 'Jugador';

  @override
  String get playingFromAlbum => 'Reproduciendo desde el álbum';

  @override
  String get playingNext => 'Reproduciendo a continuación';

  @override
  String get playingTrack => 'Reproduciendo pista';

  @override
  String get playlistAlbumTracks => 'Pistas de lista de reproducción / álbum';

  @override
  String get playlistNameHint => 'Nombre de la lista';

  @override
  String get playlistNotFound => 'Lista de reproducción no encontrada';

  @override
  String get playlistNotFoundOrError =>
      'Lista de reproducción no encontrada o error del servidor';

  @override
  String get playlistReadyShare =>
      '¡Tu lista de reproducción está lista para compartir!';

  @override
  String get playlists => 'Listas de reproducción';

  @override
  String get plays => 'reproducciones';

  @override
  String get popularOnSpotify => 'Popular en Spotify';

  @override
  String get portuguese => 'Portugués';

  @override
  String get preferredOutputFormat =>
      'Formato de salida preferido para descargas';

  @override
  String get preparingDownload => 'Preparando descarga';

  @override
  String preparingDownloadFormat(String format) {
    return 'Preparando descarga ($format)...';
  }

  @override
  String get preparingDownloadNotification => 'Preparando descarga';

  @override
  String get presetSaved => '¡Ajuste guardado!';

  @override
  String get preview => 'VISTA PREVIA';

  @override
  String get previousTrack => 'Pista anterior';

  @override
  String get profileSettings => 'Ajustes de perfil';

  @override
  String get profileStats => 'Estadísticas del perfil';

  @override
  String get progress => 'Progreso';

  @override
  String get publicSharing => 'Compartir públicamente';

  @override
  String get publicSharingDesc =>
      'Cualquiera con el código puede importar esta lista de reproducción.';

  @override
  String get publicSharingDisabledDesc =>
      'Desactivado. Actívalo para compartir con otros.';

  @override
  String get queueIsEmpty => 'La cola está vacía';

  @override
  String get queueTooltip => 'Cola';

  @override
  String get queueUpdated => 'Cola actualizada';

  @override
  String get quickMix => 'Mix rápido';

  @override
  String get rainbowMode => 'Modo arcoíris';

  @override
  String get rainyCity => 'Ciudad lluviosa';

  @override
  String get rank => 'Rango';

  @override
  String rankActive(int rank) {
    return 'Rango $rank (Activo)';
  }

  @override
  String rankLabel(int rank) {
    return 'RANGO $rank';
  }

  @override
  String get reBuffering => 'Almacenando en búfer...';

  @override
  String reachDailyPlaysTooltip(int count) {
    return 'Logra $count reproducciones en un día';
  }

  @override
  String reachSpecificArtistTooltip(String minutes) {
    return 'Logra $minutes minutos con un artista específico';
  }

  @override
  String reachWeeklyPlaysTooltip(int count) {
    return 'Logra $count reproducciones en una semana';
  }

  @override
  String get readySearchSong => 'Listo. Busca una canción.';

  @override
  String get rebufferingFromCloud => 'Almacenando en búfer desde la nube...';

  @override
  String get recentlyPlayed => 'Reproducidas recientemente';

  @override
  String recommendationsCount(int count) {
    return 'Recomendaciones ($count)';
  }

  @override
  String get recommendationsSection => 'Recomendaciones';

  @override
  String get rediscover => 'Redescubrir';

  @override
  String get refreshLabel => 'Refrescar';

  @override
  String get refreshLibrary => 'Refrescar biblioteca';

  @override
  String get refreshList => 'Refrescar lista';

  @override
  String get refreshLyricsTooltip => 'Refrescar letras';

  @override
  String get removeAvatar => 'Eliminar avatar actual';

  @override
  String get removeFromPlaylist => 'Eliminar de la lista';

  @override
  String removedFolder(Object folder) {
    return 'Carpeta eliminada: $folder';
  }

  @override
  String get rename => 'Renombrar';

  @override
  String get renamePlaylist => 'Renombrar lista de reproducción';

  @override
  String get repeats => 'repeticiones';

  @override
  String get requiresAndroid14 => 'Requiere Android 14+ y un USB DAC';

  @override
  String get resamplingLabel => 'Resampleo';

  @override
  String get reset => 'Restablecer';

  @override
  String get resetDataUsage => 'Restablecer uso de datos';

  @override
  String get resetDataUsageContent =>
      '¿Está seguro de que desea restablecer el uso de datos? Esto no afecta a la música descargada.';

  @override
  String get resetEverything => 'Restablecer todo';

  @override
  String get resetLibraryContent =>
      'Esto eliminará la carpeta actual del reproductor. Tus archivos reales no se borrarán.';

  @override
  String get resetLibraryPath => 'Restablecer ruta de la biblioteca';

  @override
  String get resetLibraryTitle => '¿Restablecer biblioteca?';

  @override
  String get resetPath => 'Restablecer ruta';

  @override
  String get resetStatistics => 'Restablecer estadísticas';

  @override
  String get resetStatsContent =>
      'Esta acción no se puede deshacer.\\nTodos los conteos de reproducción y tiempo de escucha se perderán para siempre.';

  @override
  String get resetStatsTitle => '¿Restablecer estadísticas?';

  @override
  String get resetToAutomatic => 'RESTABLECER A AUTOMÁTICO';

  @override
  String get resetToDefault => 'Restablecer por defecto';

  @override
  String get resetUsage => 'Restablecer uso';

  @override
  String get resetsIn => 'SE REINICIA EN';

  @override
  String get restartContent =>
      'Se requiere reiniciar la aplicación para aplicar los cambios del dispositivo de salida de audio.\\n\\n¿Reiniciar ahora?';

  @override
  String get restartNow => 'Reiniciar ahora';

  @override
  String get restartRequired => 'Reinicio necesario';

  @override
  String get restoring => 'Restaurando';

  @override
  String get retryConnection => 'Reintentar conexión';

  @override
  String get revert => 'Revertir';

  @override
  String get russian => 'Ruso';

  @override
  String get sakura => 'Sakura';

  @override
  String get sampleRateLabel => 'Freq. de muestreo';

  @override
  String get samplingRateLabel => 'Tasa de muestreo';

  @override
  String get save => 'Guardar';

  @override
  String get saveAsNewPreset => 'Guardar como nuevo ajuste';

  @override
  String get saveChangesToFile => 'Guardar cambios en el archivo';

  @override
  String get saveLabel => 'Guardar';

  @override
  String get saveLrcPrompt =>
      '¿Quieres guardar la letra actual como un archivo .lrc junto al audio?';

  @override
  String get saveLyricsTooltip => 'Guardar letras';

  @override
  String get savePlaylistContent =>
      'Esto creará una nueva lista de reproducción basada en estas canciones.';

  @override
  String savePlaylistTitle(String title) {
    return '¿Guardar \"$title\"?';
  }

  @override
  String get savePreset => 'Guardar ajuste';

  @override
  String savedAs(String name) {
    return '¡Guardado como \"$name\"!';
  }

  @override
  String savedAsFormat(String format) {
    return 'Guardado como $format';
  }

  @override
  String savedTo(String path) {
    return 'Guardado en \"$path\"';
  }

  @override
  String get saving => 'Guardando...';

  @override
  String get scan => 'Escanear';

  @override
  String get scanToControlPlayback =>
      'Escanea para controlar la reproducción con tu teléfono.';

  @override
  String get scanning => 'Escaneando...';

  @override
  String get scrollForLyrics => 'Desliza para ver las letras';

  @override
  String get search => 'Buscar';

  @override
  String get searchEngine => 'Motor de búsqueda';

  @override
  String searchFailedStatus(String error) {
    return 'Fallo de búsqueda: $error';
  }

  @override
  String get searchHint => 'Buscar...';

  @override
  String get searchSongs => 'Buscar canciones...';

  @override
  String get searchSongsOrAlbumsAndArtistsHint =>
      'Busca canciones, álbumes o artistas...';

  @override
  String get searchSpotify => 'Buscar en Spotify';

  @override
  String get searchSpotifyHint => 'Buscar en Spotify...';

  @override
  String get searchUsers => 'Buscar usuarios...';

  @override
  String get searchYoutubeHint => 'Buscar en YouTube...';

  @override
  String get searching => 'Buscando...';

  @override
  String searchingEngine(String engine, String keyword) {
    return 'Buscando en $engine por \'$keyword\'...';
  }

  @override
  String get searchingSpotify => 'Buscando en Spotify...';

  @override
  String searchingSpotifyFor(String keyword) {
    return 'Buscando \"$keyword\" en Spotify...';
  }

  @override
  String get searchingStatus => 'Buscando';

  @override
  String get secondShort => 'seg';

  @override
  String get secsShort => 'S';

  @override
  String get seeAll => 'Ver todo';

  @override
  String get selectDifferentFolder => 'Seleccionar otra carpeta';

  @override
  String get selectFolder => 'Seleccionar carpeta';

  @override
  String get selectMatch => 'Seleccionar coincidencia';

  @override
  String get selectSongToEdit =>
      'Selecciona una canción de la lista para editar';

  @override
  String get selectStreamingQuality => 'Seleccionar calidad de streaming';

  @override
  String get selectTrackToStart => 'Selecciona una pista para empezar';

  @override
  String get selectVersion => 'Seleccionar versión';

  @override
  String session(String id) {
    return 'Sesión: $id';
  }

  @override
  String get setCountryReleases => 'Establecer país para lanzamientos y listas';

  @override
  String get setCustomTimer => 'Establecer temporizador personalizado';

  @override
  String get settings => 'Ajustes';

  @override
  String get share => 'Compartir';

  @override
  String get shareCodeUsage =>
      'Dale este código de 6 dígitos a un amigo para que importe esta lista de reproducción.';

  @override
  String get sharePlaylist => 'Compartir lista de reproducción';

  @override
  String sharePlaylistTitle(String name) {
    return 'Compartir \"$name\"';
  }

  @override
  String get sharedMode => 'Compartido';

  @override
  String showAllTitles(int count) {
    return 'Mostrar todos los $count títulos';
  }

  @override
  String get showAnimatedWaves =>
      'Mostrar ondas animadas en la barra del reproductor';

  @override
  String get showDebugButton => 'Mostrar botón de depuración flotante';

  @override
  String get showInFolder => 'Mostrar en carpeta';

  @override
  String get showLess => 'Mostrar menos';

  @override
  String get showMore => 'Mostrar más';

  @override
  String get showStatusDiscord => 'Mostrar estado en Discord';

  @override
  String get showUnlockedOnly => 'Mostrar solo desbloqueados';

  @override
  String get shuffle => 'Aleatorio';

  @override
  String get shuffleAll => 'Aleatorio todo';

  @override
  String shufflingArtist(String artistName) {
    return 'Modo aleatorio para $artistName...';
  }

  @override
  String get signInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get signalOutput => 'Salida de señal';

  @override
  String get singleTracks => 'Pistas individuales';

  @override
  String get sleepTimer => 'Temporizador de apagado';

  @override
  String get songAlreadyInPlaylist =>
      'La canción ya está en la lista de reproducción';

  @override
  String get songInformation => 'Información de la canción';

  @override
  String get songLabelUpper => 'CANCIÓN';

  @override
  String get songTitleKeyword => 'Título de canción o palabra clave';

  @override
  String get songs => 'canciones';

  @override
  String songsCount(int count) {
    return '$count canciones';
  }

  @override
  String songsInLibrary(int count) {
    return '$count canciones en la biblioteca';
  }

  @override
  String songsLoadedCount(int count) {
    return 'Cargadas $count canciones...';
  }

  @override
  String get southKorea => 'Corea del Sur';

  @override
  String get spanish => 'Español';

  @override
  String get spectrumBars => 'Barras de espectro';

  @override
  String get spotify => 'Spotify';

  @override
  String get standardDesc =>
      'MP3 - Archivo más pequeño, almacenamiento en búfer más rápido';

  @override
  String get standardQuality => 'Estándar (MP3)';

  @override
  String get start => 'Empezar';

  @override
  String get startBulkProcess => 'Iniciar proceso por lotes';

  @override
  String get startedDownloadingAll =>
      'Se inició la descarga de todas las canciones...';

  @override
  String get stateDisabled => 'Desactivado';

  @override
  String get stateEnabled => 'Activado';

  @override
  String get statisticsReset => 'Estadísticas restablecidas.';

  @override
  String get stats => 'Estadísticas';

  @override
  String get statusLabel => 'Estado';

  @override
  String statusWithText(String status) {
    return 'Estado: $status';
  }

  @override
  String stopTimer(String time) {
    return 'Parar temporizador ($time)';
  }

  @override
  String get streaming => 'Streaming';

  @override
  String get streamingQuality => 'Calidad de streaming';

  @override
  String get success => 'Éxito';

  @override
  String get superfanHeader => 'LOGROS DE SUPERFAN';

  @override
  String get superfanTitles => 'SUPERFAN';

  @override
  String get supportDeveloperTooltip =>
      'Apoya al desarrollador para obtener el título exclusivo';

  @override
  String get switchToGridView => 'Cambiar a vista de cuadrícula';

  @override
  String get switchToListView => 'Cambiar a vista de lista';

  @override
  String switchingTo(String title) {
    return 'Cambiando a';
  }

  @override
  String get syncThemeAlbumArt => 'Sincronizar tema con portada';

  @override
  String get system => 'Sistema';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get targetLanguageLyrics =>
      'Idioma de destino para la traducción de letras';

  @override
  String get thai => 'Tailandés';

  @override
  String get tidalApiStatus => 'Tidal API';

  @override
  String get timeBasedTitles => 'BASADO EN EL TIEMPO';

  @override
  String get timeListened => 'Tiempo escuchado';

  @override
  String get timeOverlordsHeader => 'SOBERANOS DEL TIEMPO';

  @override
  String timerSetForHours(int count) {
    return 'Temporizador establecido para dentro de $count horas';
  }

  @override
  String timerSetForMinutes(int count) {
    return 'Temporizador establecido para dentro de $count minutos';
  }

  @override
  String timerSetForSeconds(int count) {
    return 'Temporizador establecido para dentro de $count segundos';
  }

  @override
  String get tintBackground =>
      'Tiñe el fondo y el visualizador con el color de la canción';

  @override
  String get title => 'Título';

  @override
  String get titleLabel => 'Título';

  @override
  String todayLabel(String size) {
    return 'Hoy: $size';
  }

  @override
  String get toggleDebugButton => 'Alternar consola de depuración flotante';

  @override
  String get toggleDebugConsole => 'Alternar consola de depuración flotante';

  @override
  String get toggleLyrics => 'Alternar Letras';

  @override
  String top3GlobalTooltip(int weeks) {
    return 'Logra el Top 3 Global por $weeks semanas';
  }

  @override
  String get topArtist => 'Artista top';

  @override
  String get topArtistAndTrack => 'Mejor artista y pista';

  @override
  String get topArtists => 'Top Artistas';

  @override
  String topGlobalTooltip(int rank) {
    return 'Logra el top $rank global';
  }

  @override
  String get topListeners => 'Top Oyentes';

  @override
  String get totalMinutesStat => 'Minutos totales';

  @override
  String get totalPlays => 'Reproducciones totales';

  @override
  String get trackDetails => 'Detalles de la pista';

  @override
  String get trackNumber => 'Número de pista';

  @override
  String get tracks => 'pistas';

  @override
  String get translateLabel => 'Traducir';

  @override
  String get translateLyrics => 'Traducir letras';

  @override
  String get translateLyricsTooltip => 'Traducir letras';

  @override
  String get translationLanguage => 'Idioma de traducción';

  @override
  String get turnOffTimer => 'Apagar temporizador';

  @override
  String get unauthorize => 'No autorizado';

  @override
  String get underDevelopment => 'Esta función está en desarrollo';

  @override
  String get underwater => 'Bajo el agua';

  @override
  String get unitedKingdom => 'Reino Unido';

  @override
  String get unitedStates => 'Estados Unidos';

  @override
  String get unknown => 'Desconocido';

  @override
  String get unknownArtist => 'Artista desconocido';

  @override
  String get unknownDevice => 'Dispositivo desconocido';

  @override
  String get unlink => 'Desvincular';

  @override
  String get unlinkAccount => 'Desvincular cuenta';

  @override
  String get unlinkAccountDesc =>
      'Tus estadísticas permanecerán en este dispositivo pero ya no se sincronizarán entre dispositivos.';

  @override
  String get unlinkAccountQuestion => '¿Desvincular cuenta?';

  @override
  String get unlinkFolder => 'Desvincular carpeta y borrar lista de canciones';

  @override
  String get unlinkFolderClear =>
      'Desvincular carpeta y borrar lista de canciones';

  @override
  String unlockedCountLabel(int unlocked, int total) {
    return '$unlocked / $total Desbloqueado';
  }

  @override
  String get unmuteTooltip => 'Desactivar silencio';

  @override
  String get unsavedChanges => 'Cambios sin guardar';

  @override
  String get upNext => 'Siguiente canción';

  @override
  String upNextCount(int count) {
    return 'A continuación ($count)';
  }

  @override
  String get upNextSection => 'A continuación';

  @override
  String get updateAvailableTitle => 'Actualización disponible';

  @override
  String updateAvailableVersion(String version) {
    return 'Una nueva versión ($version) está disponible.';
  }

  @override
  String updateFailed(String error) {
    return 'Error al actualizar: $error';
  }

  @override
  String get updateNow => 'Actualizar ahora';

  @override
  String get updatePrompt => '¿Quieres descargarla e instalarla ahora?';

  @override
  String get updatingYtDlp => 'Actualizando yt-dlp';

  @override
  String get usbAudioBypass =>
      'USB Audio Bypass (Beta) - Salida directa DAC para Android 13 y versiones anteriores';

  @override
  String get usbAudioBypassBeta =>
      'USB Audio Bypass (Beta) - Salida directa DAC para Android 13 y versiones anteriores';

  @override
  String get useDarkTheme => 'Usar tema oscuro';

  @override
  String get useMixedColors =>
      'Usar colores mezclados (prioridad a la sincronización)';

  @override
  String get verifiedDeveloper => 'Desarrollador verificado';

  @override
  String get version => 'Versión';

  @override
  String versionLabel(String version) {
    return 'Versión $version';
  }

  @override
  String get vietnamese => 'Vietnamita';

  @override
  String get viewQueue => 'Ver cola';

  @override
  String get visualizer => 'Visualizador';

  @override
  String get visualizerStyle => 'Estilo del visualizador';

  @override
  String get wasapiExclusive => 'Modo exclusivo WASAPI';

  @override
  String get weekly => 'Semanal';

  @override
  String get weeks => 'Semanas';

  @override
  String get winter => 'Invierno';

  @override
  String get worldRanking => 'Clasificación mundial';

  @override
  String get worldTopArtists => 'Top Artistas Mundiales';

  @override
  String get year => 'Año';

  @override
  String get youMayLike => 'Te puede gustar';

  @override
  String get yourPlaylists => 'Tus listas de reproducción';

  @override
  String get yourTopMix => 'Tu mix top';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytDlpUpdateAvailable =>
      'Una nueva versión de yt-dlp está disponible.';

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
  String get offlineModeHeader => 'MODO SIN CONEXIÓN';

  @override
  String get offlineModeTitle => 'Modo sin conexión';

  @override
  String get offlineModeActive => 'ACTIVO';

  @override
  String get offlineModeEnabledStatus => 'Modo sin conexión activado';

  @override
  String offlineModeDisabledStatus(int count) {
    return 'Desactivado ($count)';
  }

  @override
  String get offlineModeAllEnabledStatus => 'Todo activado';

  @override
  String get offlineModeLockdownDesc =>
      'Bloqueo de red activo. Las estadísticas se guardan localmente.';

  @override
  String get offlineModeMainDesc =>
      'Desactiva todos los servicios de red y reproduce solo la biblioteca local.';

  @override
  String get enableOfflineModeQuestion => '¿Activar modo sin conexión?';

  @override
  String get offlineModeConfirmationDesc =>
      'Esto desactivará completamente toda comunicación de red. Se apagarán las siguientes funciones:';

  @override
  String get offlineModeSyncRestoreNote =>
      'Tus estadísticas se sincronizarán automáticamente cuando desactives esto.';

  @override
  String get enableOfflineModeBtn => 'Activar modo sin conexión';

  @override
  String get onlineModeRestored =>
      'Modo en línea restaurado. Sincronizando estadísticas...';

  @override
  String get disableServicesTitle => 'Desactivar servicios';

  @override
  String get manageIndividualFeatures =>
      'Administrar funciones en línea individuales';

  @override
  String get featureCloudSync => 'Sincronización de estadísticas en la nube';

  @override
  String get featureCloudSyncDesc =>
      'Estadísticas de escucha guardadas solo localmente';

  @override
  String get featureCloudSyncLongDesc =>
      'Sincronizar métricas de escucha con PocketBase';

  @override
  String get featureLeaderboard => 'Tabla de clasificación global';

  @override
  String get featureLeaderboardDesc => 'Actualizaciones de rango en pausa';

  @override
  String get featureLeaderboardLongDesc =>
      'Mostrar y actualizar tu rango públicamente';

  @override
  String get featureOnlineLyrics => 'Búsqueda de letras en línea';

  @override
  String get featureOnlineLyricsDesc => 'Solo archivos .lrc/.ttml locales';

  @override
  String get featureOnlineLyricsLongDesc => 'Obtener letras de LRCLIB/Spotify';

  @override
  String get featureAiLyrics => 'Generador de letras por IA';

  @override
  String get featureAiLyricsDesc =>
      'Letras sincronizadas automáticamente desactivadas';

  @override
  String get featureAiLyricsLongDesc =>
      'Generar letras sincronizadas mediante IA';

  @override
  String get featureSpotifyCanvas => 'Spotify Canvas';

  @override
  String get featureSpotifyCanvasDesc => 'Vídeos de fondo desactivados';

  @override
  String get featureSpotifyCanvasLongDesc => 'Vídeos de fondo para pistas';

  @override
  String get featureOnlineSearch => 'Búsqueda en línea';

  @override
  String get featureOnlineSearchDesc =>
      'Búsqueda de Spotify/YouTube desactivada';

  @override
  String get featureOnlineSearchLongDesc =>
      'Búsqueda remota de Spotify y YouTube';

  @override
  String get featureConnectDevice => 'Conectar a un dispositivo';

  @override
  String get featureConnectDeviceDesc =>
      'Control remoto y sesiones grupales desactivados';

  @override
  String get featureConnectDeviceLongDesc =>
      'Control remoto y sesiones grupales';

  @override
  String get lyricsEditorTitle => 'Editor de Letras';

  @override
  String get clearAllQuestion => '¿Borrar todo?';

  @override
  String get clearAllDesc =>
      'Esto borrará el estado actual del editor. NO eliminará sus archivos locales a menos que guarde después.';

  @override
  String get clearBtn => 'Borrar';

  @override
  String get lyricsApplied => '¡Letras aplicadas al panel!';

  @override
  String get chooseFormat => 'Elija su formato preferido:';

  @override
  String get lrcFormat => 'LRC (Sincronizado estándar)';

  @override
  String get lrcFormatDesc => 'Formato universal, funciona en todas partes.';

  @override
  String get ttmlFormat => 'TTML (Alta precisión)';

  @override
  String get ttmlFormatDesc =>
      'Mejor para generación por IA y sincronización detallada.';

  @override
  String savedSuccessfully(String extension) {
    return '¡Guardado exitosamente en el archivo $extension!';
  }

  @override
  String get failedToSave => 'Error al guardar el archivo de letras.';

  @override
  String get generationFailed => 'Generación fallida';

  @override
  String get aiLyricsGenerationTitle => 'Generación de Letras por IA';

  @override
  String get syncedMode => 'Sincronizado';

  @override
  String get plainMode => 'Texto plano';

  @override
  String get addLineToTop => 'Añadir al principio';

  @override
  String get addLineToEnd => 'Añadir al final';

  @override
  String get lyricTextHint => 'Texto de la letra...';

  @override
  String get insertAfter => 'Insertar después';

  @override
  String get removeLine => 'Eliminar línea';

  @override
  String get romajiHint => 'Romaji / Transliteración (Opcional)...';

  @override
  String get startLabel => 'Inicio: ';

  @override
  String get setStartTooltip => 'Establecer inicio en la posición actual';

  @override
  String get endLabel => 'Fin: ';

  @override
  String get setEndTooltip => 'Establecer fin en la posición actual';

  @override
  String get playFromLine => 'Reproducir desde esta línea';

  @override
  String get pasteLyricsHint => 'Pegue sus letras aquí...';

  @override
  String get applyBtn => 'Aplicar';

  @override
  String get saveLocallyBtn => 'Guardar localmente';

  @override
  String get editLyricsTooltip => 'Editar letras';

  @override
  String get saveLyricsTitle => 'Guardar letras';

  @override
  String get aiGenerate => 'Generar con IA';

  @override
  String get aiLyricsInitializing => 'Inicializando...';

  @override
  String get aiLyricsUploading => 'Subiendo canción al servidor...';

  @override
  String get aiLyricsUploadFailed => 'Error: Fallo al subir.';

  @override
  String get aiLyricsUploadSuccess => '¡Subida completada!';

  @override
  String get aiLyricsVerifying => 'Verificando estado del servidor...';

  @override
  String get aiLyricsStatusOk => '¡Código de estado 200 OK!';

  @override
  String get aiLyricsPolling =>
      'Obteniendo letras... ¡Por favor, tenga paciencia!';

  @override
  String get aiLyricsReceiving => 'Letras recibidas';

  @override
  String get aiLyricsParsing => 'Analizando letras...';

  @override
  String get aiLyricsSuccess => '¡Letras generadas con éxito!';

  @override
  String get aiLyricsLocalFileMissing =>
      'Error: Archivo de audio local no encontrado.';

  @override
  String get aiLyricsComplete => '¡Completado!';
}
