// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get aboutEducationalPurpose =>
      'Esta aplicação foi desenvolvida apenas para fins individuais e educacionais.';

  @override
  String get aboutLicenses => 'Sobre e Licenças';

  @override
  String get aboutNotForCommercial => 'Não para uso comercial.';

  @override
  String get accentColor => 'Cor de destaque';

  @override
  String get access => 'Acessar';

  @override
  String get accessCode => 'Código de acesso';

  @override
  String get accountDataMergeDesc =>
      'Ao sincronizar, seu nome de perfil e avatar serão atualizados, mas os minutos de audição do seu dispositivo atual serão mesclados com sucesso ao total da conta.';

  @override
  String get accountLinked => 'Conta Vinculada';

  @override
  String get accountLinkedSuccessfully => 'Conta vinculada com sucesso!';

  @override
  String get achievementsUnlocked => 'Conquistas desbloqueadas';

  @override
  String get activeNoResampling => 'Ativo (Sem Reamostragem)';

  @override
  String get add => 'Adicionar';

  @override
  String get addFiles => 'Adicionar arquivos';

  @override
  String get addFolder => 'Adicionar pasta';

  @override
  String get addFoldersScan => 'Adicionar pastas para escanear';

  @override
  String get addToFavorite => 'Adicionar aos favoritos';

  @override
  String get addToPlaylist => 'Adicionar à playlist';

  @override
  String get addToQueue => 'Adicionar à fila';

  @override
  String addedFolder(Object folder) {
    return 'Pasta adicionada: $folder';
  }

  @override
  String get addedToLikedSongs => 'Adicionado às músicas curtidas';

  @override
  String get addedToPlaylistSuccess => 'Adicionado à playlist';

  @override
  String get addedToQueue => 'Adicionado à fila';

  @override
  String get album => 'Álbum';

  @override
  String get albumAddedToPlaylists => 'Álbum adicionado às playlists';

  @override
  String get albumLabel => 'Álbum';

  @override
  String get albumRemovedFromPlaylists => 'Álbum removido das playlists';

  @override
  String get albums => 'Álbuns';

  @override
  String get allDownloadsRemoved => 'Todos os downloads removidos';

  @override
  String get allRightsReserved => 'Todos os direitos reservados.';

  @override
  String get allTime => 'Todo o tempo';

  @override
  String get alreadyInLikedSongs => 'Já está nas músicas curtidas';

  @override
  String get android14BitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidAudioEffectsNote =>
      'Nota: Efeitos de áudio estão disponíveis apenas no Android.';

  @override
  String get androidAudioTrack => 'Android AudioTrack';

  @override
  String get androidBitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidMixer => 'Mixer Android';

  @override
  String get appearance => 'Aparência';

  @override
  String get applyOnRestart =>
      'As alterações serão aplicadas na próxima reinicialização.';

  @override
  String get arabic => 'Árabe';

  @override
  String get artist => 'Artista';

  @override
  String get artistLabel => 'Artista';

  @override
  String get artists => 'Artistas';

  @override
  String get atmospheres => 'Atmosferas';

  @override
  String get audioFormat => 'Formato de áudio';

  @override
  String get audioOutput => 'Saída de Áudio';

  @override
  String get audioOutputDevice => 'Dispositivo de saída de áudio';

  @override
  String get audioQuality => 'Qualidade de Áudio';

  @override
  String get audioSource => 'Fonte de áudio';

  @override
  String get audiophileDAC =>
      'Ativar ao reproduzir em DACs audiófilos (requer reinicialização)';

  @override
  String get autoAddSimilar =>
      'Adicionar automaticamente músicas similares ao fim da fila';

  @override
  String get autoClearAfter24h => 'Após 24 horas';

  @override
  String get autoClearAfter7d => 'Após 7 dias';

  @override
  String get autoClearCache => 'Limpar cache automaticamente';

  @override
  String get autoClearDisabled => 'Desativado';

  @override
  String get autoClearEvery30m => 'A cada 30 min (Apenas ao ouvir)';

  @override
  String get autoClearOnClose => 'Ao fechar o aplicativo';

  @override
  String get autoFixComingSoon => 'Auto-Fix (Em breve)';

  @override
  String get autoRestartNotSupported =>
      'Reinicialização automática não suportada. Por favor, reinicie manualmente.';

  @override
  String autoTagContent(int count, String sourceName) {
    return 'Isso buscará todas as $count músicas de \"$sourceName\" no Spotify e substituirá as tags automaticamente.\\n\\nEsta ação é irreversível.';
  }

  @override
  String autoTagTitle(String sourceName) {
    return '⚠️ Auto-taggear $sourceName?';
  }

  @override
  String get automatic => 'Automático';

  @override
  String automaticTitleLabel(String title) {
    return 'Automático: $title';
  }

  @override
  String get autumn => 'Outono';

  @override
  String get avatarPickerDesc =>
      'Selecione um modelo ou importe sua própria foto';

  @override
  String get beFirstToClaim =>
      'Seja o primeiro a reivindicar o primeiro lugar!';

  @override
  String get backgroundCacheFlacStreams =>
      'Cache de streams FLAC em segundo plano';

  @override
  String get backgroundCacheFlacStreamsSubtitle =>
      'Baixa silenciosamente faixas sem perdas transmitidas para o seu disco local para que a reprodução seja instantânea e não use dados.';

  @override
  String get behavioralHeader => 'CONQUISTAS DE COMPORTAMENTO';

  @override
  String get behavioralTitles => 'COMPORTAMENTAL';

  @override
  String get binariesUpdateRequired => 'Atualização de binários necessária';

  @override
  String get bitDepthLabel => 'Profundidade de bits';

  @override
  String get bitPerfectEnabled =>
      'Modo Bit-perfect ativado. O controle de volume pode não funcionar.';

  @override
  String get bitPerfectWindows =>
      'Áudio Bit-perfect com taxa de amostragem automática (requer reinicialização)';

  @override
  String get bitrateLabel => 'Taxa de bits';

  @override
  String get bitsLabel => 'Bits';

  @override
  String get brazil => 'Brasil';

  @override
  String get browse => 'Explorar';

  @override
  String get bypassSystemMixer => 'Ignorar mixer do sistema para USB DAC';

  @override
  String get bypassedBitPerfect => 'Ignorado (Bit-Perfect)';

  @override
  String get cacheCleared => 'Cache limpo com sucesso!';

  @override
  String get cached => 'Em cache';

  @override
  String get cancel => 'Cancelar';

  @override
  String get championChampionTooltip =>
      'Alcance o Top 1 Global por 5 semanas diferentes';

  @override
  String get change => 'Alterar';

  @override
  String get changeFolder => 'Alterar pasta';

  @override
  String get changeFormatInSettings =>
      'Por favor, altere o formato de saída nas configurações';

  @override
  String get changeLabel => 'ALTERAR';

  @override
  String get changeLanguage => 'Alterar idioma do app';

  @override
  String get changesApplyRestart =>
      'As alterações serão aplicadas na próxima reinicialização.';

  @override
  String get changingAudioDeviceRestart =>
      'Uma reinicialização do aplicativo é necessária para aplicar a alteração do dispositivo de áudio.\\n\\nReiniciar agora?';

  @override
  String get channelsLabel => 'Canais';

  @override
  String get checkAgain => 'Verificar Novamente';

  @override
  String get checkInternetConnection => 'Verifique sua conexão com a internet';

  @override
  String get checkNetworkTryAgain => 'Verifique sua rede e tente novamente';

  @override
  String get chinese => 'Chinês';

  @override
  String get chooseAccentColor => 'Escolha sua cor estática preferida';

  @override
  String get chooseAnimationType => 'Escolha o tipo de animação';

  @override
  String get chooseArtist => 'ESCOLHER ARTISTA';

  @override
  String get chooseAvatar => 'Escolher avatar';

  @override
  String get chooseYourTitle => 'Escolha seu título';

  @override
  String get circularPulse => 'Pulso circular';

  @override
  String get clearAll => 'Limpar tudo';

  @override
  String get clearHistory => 'Limpar Histórico';

  @override
  String get clearImported => 'Limpar importados';

  @override
  String get clearMetadataCache => 'Limpar cache de metadados e arte';

  @override
  String get clearPlayHistory => 'Limpar histórico e tempo de reprodução';

  @override
  String get clearStreamingCache => 'Limpar cache de streaming';

  @override
  String get close => 'Fechar';

  @override
  String get cloud => 'Nuvem';

  @override
  String get codeCopied => 'Código copiado para a área de transferência!';

  @override
  String get codeMust6Digits => 'O código deve ter 6 dígitos';

  @override
  String get codecLabel => 'Codec';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get community => 'Comunidade';

  @override
  String get competitiveTitles => 'COMPETITIVO';

  @override
  String get confirm => 'Confirmar';

  @override
  String get connect => 'Conectar';

  @override
  String get connectToADevice => 'Conectar a um dispositivo';

  @override
  String get connected => 'Conectado';

  @override
  String connectedToDac(String deviceName) {
    return 'Conectado a $deviceName - USB Bypass ativado';
  }

  @override
  String get connectedUsbDacs => 'DACs USB conectados:';

  @override
  String get connecting => 'Conectando...';

  @override
  String get connectionLostLeaderboard => 'Conexão Perdida';

  @override
  String get connectionLostLeaderboardDesc =>
      'A Classificação Global requer uma conexão ativa para sincronizar suas estatísticas e buscar rankings mundiais.';

  @override
  String consecutivePlaysTooltip(int count) {
    return 'Ouça a mesma música $count vezes consecutivas';
  }

  @override
  String get contentRegion => 'Região do conteúdo';

  @override
  String get copyCode => 'Copiar Código';

  @override
  String get couldNotDownloadFlac => 'Não foi possível baixar o FLAC.';

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return '$_temp0';
  }

  @override
  String get createPlaylist => 'Criar Playlist';

  @override
  String creatingPlaylistWithTracks(int count) {
    return 'Criando lista de reprodução com $count faixas...';
  }

  @override
  String get crossfade => 'Crossfade';

  @override
  String crossfadeDesc(String seconds) {
    return 'Transição entre faixas ($seconds s)';
  }

  @override
  String get crownedChampionTitlesHeader => 'TÍTULOS DE CAMPEÃO COROADO';

  @override
  String get customDevice => 'Dispositivo personalizado';

  @override
  String get customSelected => 'Seleção Personalizada';

  @override
  String get customTime => 'Tempo personalizado';

  @override
  String get cyberpunk => 'Cyberpunk';

  @override
  String get daily => 'Diário';

  @override
  String get darkMode => 'Modo Escuro';

  @override
  String get dataCleanup => 'Dados e Limpeza';

  @override
  String get dataUsage => 'Uso de dados';

  @override
  String get daysShort => 'D';

  @override
  String get debugging => 'Depuração';

  @override
  String get delete => 'Excluir';

  @override
  String get deleteDownloadsConfirm =>
      'Isso removerá todas as músicas baixadas para este dispositivo desta playlist.';

  @override
  String get deleteDownloadsTitle => 'Excluir downloads?';

  @override
  String deleteFileContent(String filename) {
    return 'Tem certeza que deseja excluir \"$filename\"?\\nEsta ação é irreversível.';
  }

  @override
  String get deleteFileTitle => 'Excluir arquivo?';

  @override
  String get deletePlaylist => 'Excluir Playlist';

  @override
  String deletePlaylistConfirm(String name) {
    return 'Tem certeza que deseja excluir \"$name\"?';
  }

  @override
  String get deletePlaylistPermanentConfirm =>
      'Tem certeza que deseja excluir esta playlist? (Esta ação não pode ser desfeita)';

  @override
  String get deletePlaylistTitle => 'Excluir Playlist?';

  @override
  String get deletePreset => 'Excluir Preset';

  @override
  String get desertMirage => 'Miragem do Deserto';

  @override
  String get developerExclusiveTooltip =>
      'Exclusivo para os desenvolvedores deste aplicativo';

  @override
  String deviceNameLabel(String deviceName) {
    return 'Dispositivo: $deviceName';
  }

  @override
  String get disableCanvas => 'Desativar Canvas';

  @override
  String get disableRomanization => 'Desativar romanização';

  @override
  String get disablingSharingWarning =>
      'Desativar o compartilhamento excluirá permanentemente o código e os dados do servidor para economizar espaço.';

  @override
  String get discNumber => 'Nº do disco';

  @override
  String get discography => 'Discografia';

  @override
  String get discordRPC => 'Presence do Discord';

  @override
  String get doYouRemember => 'Você se lembra?';

  @override
  String get donate => 'Doar';

  @override
  String get download => 'Baixar';

  @override
  String get downloadAll => 'Baixar tudo';

  @override
  String get downloadComplete => 'Download concluído';

  @override
  String get downloadCompleteNotification => 'Download concluído';

  @override
  String get downloadError => 'Erro no download';

  @override
  String get downloadFailed => 'Download falhou';

  @override
  String get downloadLocation => 'Local de download';

  @override
  String get downloadPathReset =>
      'Caminho de download redefinido para o padrão.';

  @override
  String downloadPathUpdated(Object path) {
    return 'Caminho de download atualizado: $path';
  }

  @override
  String get downloadSong => 'Baixar música';

  @override
  String get downloadStarted => 'Download iniciado';

  @override
  String downloadedTo(String path) {
    return 'Baixado para: $path';
  }

  @override
  String get downloading => 'Baixando';

  @override
  String get downloadingFlac => 'Baixando FLAC';

  @override
  String downloadingFormat(String format) {
    return 'Baixando $format';
  }

  @override
  String get downloadingUpdate => 'Baixando atualização';

  @override
  String get downloads => 'Downloads';

  @override
  String get dspLabel => 'DSP';

  @override
  String get editMetadata => 'Editar Metadados';

  @override
  String get editNickname => 'Editar apelido';

  @override
  String get editor => 'Editor';

  @override
  String get emptyMailbox => 'Esvaziar caixa de correio';

  @override
  String get emptyMailboxDesc =>
      'Isso excluirá todas as mensagens permanentemente.';

  @override
  String get emptyMailboxTitle => 'Esvaziar caixa de correio?';

  @override
  String get emptyPlaylist => 'Playlist vazia';

  @override
  String get emptyPlaylistSubtitle => 'Criar uma nova playlist vazia';

  @override
  String get enableAlphabetIndexer => 'Ativar indexador de rolagem alfabética';

  @override
  String get enableAlphabetIndexerSubtitle =>
      'Mostrar indexação da barra lateral de A a Z na visualização de lista móvel';

  @override
  String get enableBarVisualizer => 'Ativar visualizador de barras';

  @override
  String get endlessQueue => 'Fila sem fim';

  @override
  String get engineLabel => 'Motor';

  @override
  String get english => 'Inglês';

  @override
  String get enterAdminAccessCode =>
      'Por favor, insira o código de acesso administrativo';

  @override
  String get enterAdminCode =>
      'Por favor, insira o código de acesso administrativo';

  @override
  String get enterDuration => 'Insira a duração...';

  @override
  String get enterPresetName => 'Insira o nome do preset (ex: Meu Grave)';

  @override
  String get enterShareCode =>
      'Digite o código de compartilhamento de 6 dígitos';

  @override
  String get eqLabel => 'EQ';

  @override
  String get equalizer => 'Equalizador';

  @override
  String get equipTitle => 'EQUIPAR TÍTULO';

  @override
  String get equipped => 'EQUIPADO';

  @override
  String get error => 'Erro';

  @override
  String get errorCouldNotCreateSession =>
      'Erro: Não foi possível criar a sessão.';

  @override
  String errorDeleting(String error) {
    return 'Erro ao excluir: $error';
  }

  @override
  String get errorSearchingStream => 'Erro ao buscar streaming.';

  @override
  String get exclusiveMode => 'Exclusivo';

  @override
  String get exclusiveModeWarning =>
      'Aviso: O modo exclusivo funciona melhor se você selecionar um dispositivo específico acima, em vez do padrão do sistema.';

  @override
  String get exclusiveTitles => 'EXCLUSIVO';

  @override
  String get exclusiveTitlesHeader => 'TÍTULOS EXCLUSIVOS';

  @override
  String get exclusiveWarning =>
      'Aviso: O modo exclusivo funciona melhor se você selecionar um dispositivo específico acima, em vez do padrão do sistema.';

  @override
  String get exitApp => 'Sair';

  @override
  String get expand => 'Expandir';

  @override
  String get externalFiles => 'Arquivos externos';

  @override
  String get fadingAtEnd =>
      'Temporizador de sono: Desvanecendo no final da faixa...';

  @override
  String get failedDisableSharing => 'Falha ao desativar o compartilhamento.';

  @override
  String get failedEnableSharing =>
      'Falha ao ativar o compartilhamento. Verifique a conexão.';

  @override
  String get failedFetchPlaylistInfo =>
      'Não foi possível buscar as informações da lista de reprodução';

  @override
  String get failedToConnectDac =>
      'Falha ao conectar ao DAC. Verifique as permissões USB.';

  @override
  String get failedToGenerateCode =>
      'Falha ao gerar código de compartilhamento. Verifique a conexão.';

  @override
  String get failedToSetAvatar => 'Falha ao definir o modelo de avatar';

  @override
  String get failedToUpdateMetadata => 'Falha ao atualizar metadados';

  @override
  String get favoriteTrack => 'Faixa favorita';

  @override
  String get fetchingCanvas => 'Buscando Canvas...';

  @override
  String get fetchingLossless => 'Buscando sem perdas...';

  @override
  String get fetchingLosslessAudio => 'Buscando áudio sem perdas...';

  @override
  String get fetchingMetadataSpotify => 'Buscando metadados do Spotify...';

  @override
  String get fetchingPlaylist => 'Buscando lista de reprodução...';

  @override
  String get fetchingPlaylistInfo =>
      'Buscando informações da lista de reprodução...';

  @override
  String get fetchingSharedPlaylist =>
      'Buscando lista de reprodução compartilhada...';

  @override
  String fetchingTracksFrom(String name) {
    return 'Buscando faixas de \"$name\"...';
  }

  @override
  String get fileLocation => 'Local do arquivo';

  @override
  String get fileMissingHistory =>
      'Arquivo faltando e não presente no histórico.';

  @override
  String get fileName => 'Nome do arquivo';

  @override
  String get fileSizeLabel => 'Tamanho do arquivo';

  @override
  String get files => 'Arquivos';

  @override
  String get filters => 'Filtros';

  @override
  String get findingBestMatchYoutube =>
      'Encontrando melhor correspondência no YouTube...';

  @override
  String get findingStream => 'Encontrando fonte de streaming...';

  @override
  String get finishUpdate => 'Finalizar atualização';

  @override
  String get finishes => 'Posições';

  @override
  String get fixAll => 'Corrigir tudo';

  @override
  String get flacError => 'Erro FLAC';

  @override
  String get flacNote =>
      'Nota: FLAC está disponível apenas para downloads de faixas avulsas. Downloads de playlists usarão o formato M4A.';

  @override
  String get flacSavedToDownloads => 'FLAC salvo na pasta de downloads';

  @override
  String get flacUnavailable => 'FLAC indisponível';

  @override
  String get flacUnavailableDesc =>
      'FLAC não está disponível, falha no download. Tente alterar as configurações.';

  @override
  String get flacUnavailableNotification => 'FLAC indisponível';

  @override
  String get fluidWave => 'Onda fluida';

  @override
  String folderPath(String path) {
    return 'Pasta: $path';
  }

  @override
  String get folders => 'Pastas';

  @override
  String get formatLabel => 'Formato';

  @override
  String get formatSaved => 'Formato salvo!';

  @override
  String foundExistingAccount(String name) {
    return 'Encontramos uma conta existente para \'$name\'.';
  }

  @override
  String foundResults(int songCount, int albumCount, int artistCount) {
    return 'Encontradas $songCount músicas, $albumCount álbuns, $artistCount artistas.';
  }

  @override
  String foundYoutubeResults(int count) {
    return 'Encontrados $count resultados no YouTube';
  }

  @override
  String freeUpSpace(String size) {
    return 'Liberar espaço (Atual: $size)';
  }

  @override
  String get french => 'Francês';

  @override
  String fromLibraryCount(int count) {
    return 'Da biblioteca ($count)';
  }

  @override
  String get fromLibrarySection => 'Da biblioteca';

  @override
  String get fullScreenPlayerTooltip => 'Player em tela cheia';

  @override
  String get galacticSpace => 'Espaço Galáctico';

  @override
  String get gaplessPlayback => 'Reprodução Sem Intervalos';

  @override
  String get gaplessPlaybackDesc => 'Elimina o silêncio entre as faixas';

  @override
  String get general => 'Geral';

  @override
  String get generatingShareCode => 'Gerando código de compartilhamento...';

  @override
  String get genre => 'Gênero';

  @override
  String get german => 'Alemão';

  @override
  String get globalLeaderboard => 'Classificação Global';

  @override
  String get globalMailbox => 'Caixa de correio global';

  @override
  String get globalRank => 'Classificação Global';

  @override
  String get globalRankings => 'Rankings globais';

  @override
  String get globalRankingsDesc =>
      'Veja os principais ouvintes diários, semanais e de todos os tiempos!';

  @override
  String get goToArtist => 'Ir para o artista';

  @override
  String get goToLocalLibraryToSelect =>
      'Vá para a Biblioteca Local para selecionar uma pasta.';

  @override
  String get goodAfternoon => 'Boa tarde';

  @override
  String get goodEvening => 'Boa noite';

  @override
  String get goodMorning => 'Bom dia';

  @override
  String get googleAccount => 'Conta do Google';

  @override
  String get grantAccess => 'Conceder acesso';

  @override
  String get grantPermission => 'Conceder permissão';

  @override
  String get hallOfFameHeader => 'CONQUISTAS DO HALL DA FAMA';

  @override
  String get hallOfFameTitles => 'HALL DA FAMA';

  @override
  String get hideCanvas =>
      'Não mostrar vídeos Spotify Canvas, mostrar capa do álbum em vez disso';

  @override
  String get hideRomajiPinyin =>
      'Não mostrar Romaji/Pinyin sob letras em coreano, japonês ou chinês';

  @override
  String get hideTranslation => 'Ocultar Tradução';

  @override
  String get highDesc => 'M4A - Melhor som, desempenho equilibrado';

  @override
  String get highQuality => 'Alta Qualidade (M4A)';

  @override
  String get hindi => 'Híndi';

  @override
  String get history => 'Histórico';

  @override
  String get historySection => 'Histórico';

  @override
  String get home => 'Início';

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
  String get ignoreSubfolderScan => 'Ignorar varredura de subpastas';

  @override
  String get importAdditionalPaths => 'Importar caminhos adicionais';

  @override
  String get importChoice => 'Importar';

  @override
  String importFailed(String error) {
    return 'Falha na importação: $error';
  }

  @override
  String get importFromGallery => 'Importar da galeria';

  @override
  String get importFromSpotify => 'Importar do Spotify';

  @override
  String get importFromSpotifySubtitle => 'Cole um link de playlist do Spotify';

  @override
  String get importFromYoutubeMusic => 'Importar do YouTube Music';

  @override
  String get importFromYoutubeMusicSubtitle =>
      'Cole um link de playlist do YouTube Music';

  @override
  String get importLabel => 'Importar';

  @override
  String get importLyricsFile => 'Importar arquivo de letras';

  @override
  String get importLyricsTooltip => 'Importar Letras';

  @override
  String get importSpotifyPlaylist => 'Importar Playlist do Spotify';

  @override
  String get importViaCode => 'Importar via Código';

  @override
  String get importViaCodeSubtitle =>
      'Importar uma lista de reprodução compartilhada por um amigo';

  @override
  String get importYoutubeMusicPlaylist => 'Importar Playlist do YouTube Music';

  @override
  String importedPlaylistName(String name) {
    return '\"$name\" importada com sucesso!';
  }

  @override
  String importedTracks(int count) {
    return '$count faixas importadas com sucesso!';
  }

  @override
  String get indonesia => 'Indonésia';

  @override
  String get indonesian => 'Indonésio';

  @override
  String get inputLabel => 'Entrada';

  @override
  String get installNow => 'Instalar agora';

  @override
  String get integration => 'Integração';

  @override
  String get invalidAccessCode => 'Código de acesso inválido';

  @override
  String get invalidCode => 'Código de acesso inválido';

  @override
  String get invalidSpotifyUrl =>
      'URL da lista de reprodução do Spotify inválida';

  @override
  String get invalidYoutubeMusicUrl =>
      'URL de playlist do YouTube Music inválido';

  @override
  String get japan => 'Japão';

  @override
  String get japanese => 'Japonês';

  @override
  String get joinUs => 'Junte-se a nós';

  @override
  String get jumpBackIn => 'Ouça de novo';

  @override
  String get justEnjoyVibes => 'Apenas aproveite as vibrações.';

  @override
  String get korean => 'Coreano';

  @override
  String get language => 'Idioma';

  @override
  String last30DaysLabel(String size) {
    return 'Últimos 30 dias: $size';
  }

  @override
  String last7DaysLabel(String size) {
    return 'Últimos 7 dias: $size';
  }

  @override
  String get later => 'Depois';

  @override
  String get library => 'Biblioteca';

  @override
  String get libraryData => 'Dados da biblioteca';

  @override
  String get libraryNotLoaded => 'Biblioteca não carregada.';

  @override
  String get libraryPathReset => 'Caminho da biblioteca redefinido.';

  @override
  String get likedSongs => 'Músicas Curtidas';

  @override
  String get linkAccount => 'Vincular Conta';

  @override
  String get linkAccountDesc =>
      'Sincronize e restaure seu progresso com o Google';

  @override
  String listenMinutesTooltip(String minutes) {
    return 'Ouça $minutes minutos de música';
  }

  @override
  String get listeningParty => 'Festa de Audição';

  @override
  String get listeningStats => 'Estatísticas de Audição';

  @override
  String get loadingCanvas => 'Carregando Canvas...';

  @override
  String get loadingDevices => 'Carregando dispositivos...';

  @override
  String get loadingError =>
      'Falha ao carregar detalhes. Por favor, tente novamente.';

  @override
  String get loadingLyrics => 'Carregando letras...';

  @override
  String get localPlayHistorySaved =>
      'Seu histórico de reprodução local não será excluído.';

  @override
  String get local_library => 'Biblioteca local';

  @override
  String get lockedAtmosphere => 'Bloqueado enquanto uma atmosfera está ativa';

  @override
  String get losslessDesc => 'FLAC - Qualidade sem perdas do Deezer/Tidal';

  @override
  String get losslessNote =>
      'Usará FLAC sem perdas se disponível no Deezer/Tidal. Caso contrário, voltará para M4A.';

  @override
  String get losslessQuality => 'Sem perdas (Auto)';

  @override
  String get lunarNewYear => 'Ano Novo Lunar';

  @override
  String get lyricsByLRCLIB => 'Letras por LRCLIB';

  @override
  String get lyricsSaveError => 'Erro ao salvar letras';

  @override
  String get lyricsSavedSuccess => 'Letras salvas no arquivo .lrc';

  @override
  String get lyricsTooltip => 'Letras';

  @override
  String get madeForYou => 'Feito para você';

  @override
  String get manualSearch => 'Busca manual';

  @override
  String get mergeAccountData => 'Mesclar Dados da Conta?';

  @override
  String get metadataCacheCleared =>
      'Cache de metadados limpo e redigitalização da biblioteca iniciada';

  @override
  String get metadataEditorInfo =>
      'Você pode buscar e corrigir rapidamente no Editor de Metadados.';

  @override
  String get metadataEditorNote =>
      'Nota: Após o status mostrar \"Salvo com sucesso\", a imagem do álbum pode mudar. Isso não é erro, mas um problema de cache do app que estamos resolvendo. Verifique no gerenciador de arquivos.';

  @override
  String get metadataUpdated => 'Metadados Atualizados';

  @override
  String get metadata_editor => 'Editor de Metadados';

  @override
  String get min => 'min';

  @override
  String get minShortLabel => 'min';

  @override
  String get miniPlayer => 'Mini Player';

  @override
  String get minimizeToTray => 'Minimizar para a bandeja';

  @override
  String get minimizeToTrayDescription =>
      'Fechar o app na bandeja do sistema em vez de sair';

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
  String get moreOptions => 'Mais opções';

  @override
  String get moreOptionsTooltip => 'Mais opções';

  @override
  String get mostListened => 'Mais Ouvidas';

  @override
  String get mostListenedArtist => 'Artista mais ouvido';

  @override
  String get musicFolderLocation => 'Localização da pasta de música';

  @override
  String get musicSearch => 'Busca Musical';

  @override
  String musicWillStopIn(String label) {
    return 'A música parará em $label';
  }

  @override
  String get muteTooltip => 'Mudar para mudo';

  @override
  String myTopTrackOn(String header) {
    return 'Meu $header no Simple Player! 🎵';
  }

  @override
  String get nativeRate => 'Taxa Nativa';

  @override
  String get navigation => 'Navegação';

  @override
  String get newPlaylist => 'Nova Playlist';

  @override
  String get nextTrack => 'Próxima faixa';

  @override
  String get nicknameHint => 'Digite seu apelido';

  @override
  String get nicknameLabel => 'Apelido';

  @override
  String get nicknameRequired => 'Nome Requerido';

  @override
  String get nicknameRequiredDesc =>
      'Você precisa definir um nome personalizado primeiro para ver a classificação global!';

  @override
  String get nicknameTakenDesc =>
      'Este apelido já está em uso globalmente. Por favor, escolha outro.';

  @override
  String get nicknameTakenTitle => 'Apelido em uso';

  @override
  String get noAlbumsFound => 'Nenhum álbum encontrado';

  @override
  String get noArtistStatsYet => 'Nenhuma estatística de artista ainda.';

  @override
  String get noArtistsFound => 'Nenhum artista encontrado.';

  @override
  String get noDownloadsFound => 'Nenhum download encontrado';

  @override
  String get noFolderSelected => 'Nenhuma pasta selecionada';

  @override
  String get noHistoryYet => 'Nenhum histórico ainda';

  @override
  String get noInternetConnection => 'Sem conexão com a internet';

  @override
  String get noLyricsAvailable => 'Nenhuma letra disponível';

  @override
  String get noMessages => 'Não há mensagens na sua caixa de correio';

  @override
  String get noMusicPlaying => 'Nenhuma música tocando';

  @override
  String get noPlaylistsFound => 'Nenhuma playlist encontrada';

  @override
  String get noPlaylistsYet => 'Nenhuma playlist ainda';

  @override
  String get noRankingsYet => 'Ainda não há rankings para este período.';

  @override
  String get noResultsFound => 'Nenhum resultado encontrado';

  @override
  String get noSongPlaying => 'Nenhuma música tocando';

  @override
  String get noSongsAdded => 'Nenhuma música adicionada ainda';

  @override
  String get noSongsInFolder => 'Nenhuma música encontrada nesta pasta.';

  @override
  String get noSpotifyResults => 'Nenhum resultado do Spotify encontrado.';

  @override
  String get noStatsYet => 'Nenhuma estatística ainda.';

  @override
  String get noStreamMatch =>
      'Nenhuma correspondência de streaming encontrada.';

  @override
  String get noSuggestionsFound => 'Nenhuma sugestão encontrada.';

  @override
  String get noSyncedLyricsFound => 'Nenhuma letra sincronizada encontrada';

  @override
  String get noTracksFound => 'Nenhuma faixa encontrada na lista de reprodução';

  @override
  String get noUsbDacDetected =>
      'Nenhum DAC USB detectado. Conecte um dispositivo de áudio USB e toque em Escanear.';

  @override
  String get noUsersFound => 'Nenhum usuário encontrado';

  @override
  String get noYoutubeResults => 'Nenhum resultado encontrado no YouTube';

  @override
  String get none => 'Nenhuma';

  @override
  String get nordicAurora => 'Aurora Nórdica';

  @override
  String notRank(int rank) {
    return 'Não é Rank $rank';
  }

  @override
  String get notRanked => 'Sem Rank';

  @override
  String get notRankedTop3 => 'FORA DO TOP 3';

  @override
  String get nowPlaying => 'Tocando Agora';

  @override
  String get nowPlayingHeader => 'Tocando Agora';

  @override
  String get nowPlayingSection => 'Tocando agora';

  @override
  String get offline => 'Offline';

  @override
  String get offlineStatus => 'Offline';

  @override
  String get ok => 'OK';

  @override
  String get online => 'Online';

  @override
  String get onlyScanSelected =>
      'Escanear apenas pastas selecionadas (ativado por padrão)';

  @override
  String get opacity => 'Opacidade';

  @override
  String opacityLabel(int percent) {
    return 'Opacidade: $percent%';
  }

  @override
  String get openProfile => 'Abrir Perfil';

  @override
  String get openSourceLicenses => 'Licenças de código aberto';

  @override
  String get outputLabel => 'Saída';

  @override
  String get overwrite => 'Substituir';

  @override
  String get overwriteLrcWarning =>
      'Um arquivo .lrc local já existe para esta música.\\nDeseja substituir?';

  @override
  String get parsingPlaylistData =>
      'Analisando dados da lista de reprodução...';

  @override
  String get pathLabel => 'Caminho';

  @override
  String get permissionRequired => 'Permissão necessária';

  @override
  String get permissionRequiredDesc =>
      'A permissão \"Acesso a todos os arquivos\" é necessária para editar tags. Isso permite modificar seus arquivos de música diretamente.';

  @override
  String get play => 'Tocar';

  @override
  String playCountLabel(int count) {
    return '$count reproduções';
  }

  @override
  String get playNext => 'Tocar a seguir';

  @override
  String get playPause => 'Reproduzir / Pausar';

  @override
  String get playQueue => 'Tocar Fila';

  @override
  String get playback => 'Reprodução';

  @override
  String get playbackError => 'Erro de reprodução';

  @override
  String get player => 'Jogador';

  @override
  String get playingFromAlbum => 'Tocando do álbum';

  @override
  String get playingNext => 'Tocando a seguir';

  @override
  String get playingTrack => 'Tocando faixa';

  @override
  String get playlistAlbumTracks => 'Faixas de Playlist / Álbum';

  @override
  String get playlistNameHint => 'Nome da playlist';

  @override
  String get playlistNotFound => 'Playlist não encontrada';

  @override
  String get playlistNotFoundOrError =>
      'Lista de reprodução não encontrada ou erro no servidor';

  @override
  String get playlistReadyShare =>
      'Sua lista de reprodução está pronta para ser compartilhada!';

  @override
  String get playlists => 'Playlists';

  @override
  String get plays => 'reproduções';

  @override
  String get popularOnSpotify => 'Popular no Spotify';

  @override
  String get portuguese => 'Português (Brasil)';

  @override
  String get preferredOutputFormat =>
      'Formato de saída preferido para downloads';

  @override
  String get preparingDownload => 'Preparando download';

  @override
  String preparingDownloadFormat(String format) {
    return 'Preparando download ($format)...';
  }

  @override
  String get preparingDownloadNotification => 'Preparando download';

  @override
  String get presetSaved => 'Preset salvo!';

  @override
  String get preview => 'PRÉVIA';

  @override
  String get previousTrack => 'Faixa anterior';

  @override
  String get profileSettings => 'Configurações de perfil';

  @override
  String get profileStats => 'Estatísticas do Perfil';

  @override
  String get progress => 'Progresso';

  @override
  String get publicSharing => 'Compartilhamento Público';

  @override
  String get publicSharingDesc =>
      'Qualquer pessoa com o código pode importar esta lista de reprodução.';

  @override
  String get publicSharingDisabledDesc =>
      'Desativado. Ative para compartilhar com outras pessoas.';

  @override
  String get queueIsEmpty => 'A fila está vazia';

  @override
  String get queueTooltip => 'Fila';

  @override
  String get queueUpdated => 'Fila atualizada';

  @override
  String get quickMix => 'Mix Rápido';

  @override
  String get rainbowMode => 'Modo Arco-íris';

  @override
  String get rainyCity => 'Cidade Chuvosa';

  @override
  String get rank => 'Classificação';

  @override
  String rankActive(int rank) {
    return 'Rank $rank (Ativo)';
  }

  @override
  String rankLabel(int rank) {
    return 'RANK $rank';
  }

  @override
  String get reBuffering => 'Carregando...';

  @override
  String reachDailyPlaysTooltip(int count) {
    return 'Alcance $count reproduções em um único dia';
  }

  @override
  String reachSpecificArtistTooltip(String minutes) {
    return 'Alcance $minutes minutos com um artista específico';
  }

  @override
  String reachWeeklyPlaysTooltip(int count) {
    return 'Alcance $count reproduções em uma única semana';
  }

  @override
  String get readySearchSong => 'Pronto. Busque uma música.';

  @override
  String get rebufferingFromCloud => 'Recarregando da nuvem...';

  @override
  String get recentlyPlayed => 'Tocadas Recentemente';

  @override
  String recommendationsCount(int count) {
    return 'Recomendações ($count)';
  }

  @override
  String get recommendationsSection => 'Recomendações';

  @override
  String get rediscover => 'Redescobrir';

  @override
  String get refreshLabel => 'Atualizar';

  @override
  String get refreshLibrary => 'Atualizar biblioteca';

  @override
  String get refreshList => 'Atualizar lista';

  @override
  String get refreshLyricsTooltip => 'Atualizar Letras';

  @override
  String get removeAvatar => 'Remover avatar atual';

  @override
  String get removeFromPlaylist => 'Remover da playlist';

  @override
  String removedFolder(Object folder) {
    return 'Pasta removida: $folder';
  }

  @override
  String get rename => 'Renomear';

  @override
  String get renamePlaylist => 'Renomear Playlist';

  @override
  String get repeats => 'repetições';

  @override
  String get requiresAndroid14 => 'Requer Android 14+ e um USB DAC';

  @override
  String get resamplingLabel => 'Reamostragem';

  @override
  String get reset => 'Redefinir';

  @override
  String get resetDataUsage => 'Redefinir uso de dados';

  @override
  String get resetDataUsageContent =>
      'Tem certeza de que deseja redefinir o uso de dados? Isso não afeta a música baixada.';

  @override
  String get resetEverything => 'Redefinir tudo';

  @override
  String get resetLibraryContent =>
      'Isso removerá a pasta atual do player. Seus arquivos não serão excluídos.';

  @override
  String get resetLibraryPath => 'Redefinir caminho da biblioteca';

  @override
  String get resetLibraryTitle => 'Redefinir Biblioteca?';

  @override
  String get resetPath => 'Redefinir Caminho';

  @override
  String get resetStatistics => 'Redefinir estatísticas';

  @override
  String get resetStatsContent =>
      'Esta ação é irreversível.\\nTodas as contagens de reprodução e tempos serão perdidos permanentemente.';

  @override
  String get resetStatsTitle => 'Redefinir Estatísticas?';

  @override
  String get resetToAutomatic => 'REDEFINIR PARA AUTOMÁTICO';

  @override
  String get resetToDefault => 'Redefinir para o padrão';

  @override
  String get resetUsage => 'Redefinir uso';

  @override
  String get resetsIn => 'REDEFINE EM';

  @override
  String get restartContent =>
      'Uma reinicialização do aplicativo é necessária para aplicar as alterações do dispositivo de áudio.\\n\\nReiniciar agora?';

  @override
  String get restartNow => 'Reiniciar agora';

  @override
  String get restartRequired => 'Reinicialização necessária';

  @override
  String get restoring => 'Restaurando';

  @override
  String get retryConnection => 'Tentar Novamente';

  @override
  String get revert => 'Reverter';

  @override
  String get russian => 'Russo';

  @override
  String get sakura => 'Sakura';

  @override
  String get sampleRateLabel => 'Taxa de amostragem';

  @override
  String get samplingRateLabel => 'Taxa de amostragem';

  @override
  String get save => 'Salvar';

  @override
  String get saveAsNewPreset => 'Salvar como Novo Preset';

  @override
  String get saveChangesToFile => 'Salvar alterações no arquivo';

  @override
  String get saveLabel => 'Salvar';

  @override
  String get saveLrcPrompt =>
      'Deseja salvar as letras atuais como um arquivo .lrc ao lado do áudio?';

  @override
  String get saveLyricsTooltip => 'Salvar Letras';

  @override
  String get savePlaylistContent =>
      'Isso criará uma nova playlist baseada nestas músicas.';

  @override
  String savePlaylistTitle(String title) {
    return 'Salvar \"$title\"?';
  }

  @override
  String get savePreset => 'Salvar Preset';

  @override
  String savedAs(String name) {
    return 'Salvo como \"$name\"!';
  }

  @override
  String savedAsFormat(String format) {
    return 'Salvo como $format';
  }

  @override
  String savedTo(String path) {
    return 'Salvo em \"$path\"';
  }

  @override
  String get saving => 'Salvando...';

  @override
  String get scan => 'Escanear';

  @override
  String get scanToControlPlayback =>
      'Escaneie para controlar a reprodução com seu celular.';

  @override
  String get scanning => 'Escaneando...';

  @override
  String get scrollForLyrics => 'Role para ver as letras';

  @override
  String get search => 'Pesquisar';

  @override
  String get searchEngine => 'Motor de Busca';

  @override
  String searchFailedStatus(String error) {
    return 'Busca falhou: $error';
  }

  @override
  String get searchHint => 'Buscar...';

  @override
  String get searchSongs => 'Buscar músicas...';

  @override
  String get searchSongsOrAlbumsAndArtistsHint =>
      'Buscar músicas, álbuns ou artistas...';

  @override
  String get searchSpotify => 'Buscar no Spotify';

  @override
  String get searchSpotifyHint => 'Buscar no Spotify...';

  @override
  String get searchUsers => 'Pesquisar usuários...';

  @override
  String get searchYoutubeHint => 'Buscar no YouTube...';

  @override
  String get searching => 'Buscando...';

  @override
  String searchingEngine(String engine, String keyword) {
    return 'Buscando no $engine por \'$keyword\'...';
  }

  @override
  String get searchingSpotify => 'Buscando no Spotify...';

  @override
  String searchingSpotifyFor(String keyword) {
    return 'Buscando \"$keyword\" no Spotify...';
  }

  @override
  String get searchingStatus => 'Buscando';

  @override
  String get secondShort => 's';

  @override
  String get secsShort => 'S';

  @override
  String get seeAll => 'Ver tudo';

  @override
  String get selectDifferentFolder => 'Selecionar outra pasta';

  @override
  String get selectFolder => 'Selecionar pasta';

  @override
  String get selectMatch => 'Selecionar correspondência';

  @override
  String get selectSongToEdit => 'Selecione uma música da lista para editar';

  @override
  String get selectStreamingQuality => 'Selecionar qualidade do streaming';

  @override
  String get selectTrackToStart => 'Selecione uma faixa para começar';

  @override
  String get selectVersion => 'Selecionar Versão';

  @override
  String session(String id) {
    return 'Sessão: $id';
  }

  @override
  String get setCountryReleases => 'Definir país para lançamentos e rankings';

  @override
  String get setCustomTimer => 'Definir temporizador personalizado';

  @override
  String get settings => 'Definições';

  @override
  String get share => 'Compartilhar';

  @override
  String get shareCodeUsage =>
      'Dê este código de 6 dígitos a um amigo para que ele possa importar esta lista de reprodução.';

  @override
  String get sharePlaylist => 'Compartilhar Playlist';

  @override
  String sharePlaylistTitle(String name) {
    return 'Compartilhar \"$name\"';
  }

  @override
  String get sharedMode => 'Compartilhado';

  @override
  String showAllTitles(int count) {
    return 'Mostrar todos os $count títulos';
  }

  @override
  String get showAnimatedWaves =>
      'Mostrar ondas animadas na barra de reprodução';

  @override
  String get showDebugButton => 'Mostrar botão de depuração flutuante';

  @override
  String get showInFolder => 'Mostrar na pasta';

  @override
  String get showLess => 'Mostrar menos';

  @override
  String get showMore => 'Mostrar mais';

  @override
  String get showStatusDiscord => 'Mostrar status no Discord';

  @override
  String get showUnlockedOnly => 'Mostrar apenas desbloqueados';

  @override
  String get shuffle => 'Aleatório';

  @override
  String get shuffleAll => 'Aleatório tudo';

  @override
  String shufflingArtist(String artistName) {
    return 'Misturando músicas de $artistName...';
  }

  @override
  String get signInWithGoogle => 'Entrar com o Google';

  @override
  String get signalOutput => 'Saída de Sinal';

  @override
  String get singleTracks => 'Faixas avulsas';

  @override
  String get sleepTimer => 'Temporizador';

  @override
  String get songAlreadyInPlaylist => 'A música já está na playlist';

  @override
  String get songInformation => 'Informações da Música';

  @override
  String get songLabelUpper => 'MÚSICA';

  @override
  String get songTitleKeyword => 'Título ou palavra-chave';

  @override
  String get songs => 'músicas';

  @override
  String songsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return '$_temp0';
  }

  @override
  String songsInLibrary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return '$_temp0 na biblioteca';
  }

  @override
  String songsLoadedCount(int count) {
    return '$count músicas carregadas...';
  }

  @override
  String get southKorea => 'Coreia do Sul';

  @override
  String get spanish => 'Espanhol';

  @override
  String get spectrumBars => 'Barras de espectro';

  @override
  String get spotify => 'Spotify';

  @override
  String get standardDesc => 'MP3 - Arquivo menor, carregamento mais rápido';

  @override
  String get standardQuality => 'Padrão (MP3)';

  @override
  String get start => 'Iniciar';

  @override
  String get startBulkProcess => 'Iniciar processo em lote';

  @override
  String get startedDownloadingAll =>
      'Download de todas as músicas iniciado...';

  @override
  String get stateDisabled => 'Desativado';

  @override
  String get stateEnabled => 'Ativado';

  @override
  String get statisticsReset => 'Estatísticas redefinidas.';

  @override
  String get stats => 'Estatísticas';

  @override
  String get statusLabel => 'Status';

  @override
  String statusWithText(String status) {
    return 'Status: $status';
  }

  @override
  String stopTimer(String time) {
    return 'Parar temporizador ($time)';
  }

  @override
  String get streaming => 'Streaming';

  @override
  String get streamingQuality => 'Qualidade do streaming';

  @override
  String get success => 'Sucesso';

  @override
  String get superfanHeader => 'CONQUISTAS DE SUPERFÃ';

  @override
  String get superfanTitles => 'SUPERFÃ';

  @override
  String get supportDeveloperTooltip =>
      'Apoie o desenvolvedor para obter título exclusivo';

  @override
  String get switchToGridView => 'Alternar para exibição em grade';

  @override
  String get switchToListView => 'Alternar para exibição em lista';

  @override
  String switchingTo(String title) {
    return 'Alternando para';
  }

  @override
  String get syncThemeAlbumArt => 'Sincronizar tema com a capa do álbum';

  @override
  String get system => 'Sistema';

  @override
  String get systemDefault => 'Padrão do sistema';

  @override
  String get targetLanguageLyrics =>
      'Idioma de destino para tradução de letras';

  @override
  String get thai => 'Tailandês';

  @override
  String get tidalApiStatus => 'Tidal API';

  @override
  String get timeBasedTitles => 'BASEADO NO TEMPO';

  @override
  String get timeListened => 'Tempo Ouvido';

  @override
  String get timeOverlordsHeader => 'SOBERANOS DO TEMPO';

  @override
  String timerSetForHours(int count) {
    return 'Temporizador definido para $count horas';
  }

  @override
  String timerSetForMinutes(int count) {
    return 'Temporizador definido para $count minutos';
  }

  @override
  String timerSetForSeconds(int count) {
    return 'Temporizador definido para $count segundos';
  }

  @override
  String get tintBackground =>
      'Tingir fundo e visualizador com a cor da música';

  @override
  String get title => 'Título';

  @override
  String get titleLabel => 'Título';

  @override
  String todayLabel(String size) {
    return 'Hoje: $size';
  }

  @override
  String get toggleDebugButton => 'Alternar console de depuração flutuante';

  @override
  String get toggleDebugConsole => 'Alternar console de depuração flutuante';

  @override
  String get toggleLyrics => 'Alternar Letras';

  @override
  String top3GlobalTooltip(int weeks) {
    return 'Alcance o Top 3 Global por $weeks semanas';
  }

  @override
  String get topArtist => 'Melhor Artista';

  @override
  String get topArtistAndTrack => 'Melhor Artista e Faixa';

  @override
  String get topArtists => 'Top Artistas';

  @override
  String topGlobalTooltip(int rank) {
    return 'Alcance o top $rank global';
  }

  @override
  String get topListeners => 'Top Ouvintes';

  @override
  String get totalMinutesStat => 'Total de Minutos';

  @override
  String get totalPlays => 'Total de Reproduções';

  @override
  String get trackDetails => 'Detalhes da Faixa';

  @override
  String get trackNumber => 'Nº da faixa';

  @override
  String get tracks => 'faixas';

  @override
  String get translateLabel => 'Traduzir';

  @override
  String get translateLyrics => 'Traduzir Letras';

  @override
  String get translateLyricsTooltip => 'Traduzir Letras';

  @override
  String get translationLanguage => 'Idioma de tradução';

  @override
  String get turnOffTimer => 'Desligar temporizador';

  @override
  String get unauthorize => 'Não autorizado';

  @override
  String get underDevelopment => 'Esta funcionalidade está em desenvolvimento';

  @override
  String get underwater => 'Subaquático';

  @override
  String get unitedKingdom => 'Reino Unido';

  @override
  String get unitedStates => 'Estados Unidos';

  @override
  String get unknown => 'Desconhecido';

  @override
  String get unknownArtist => 'Artista desconhecido';

  @override
  String get unknownDevice => 'Dispositivo Desconhecido';

  @override
  String get unlink => 'Desvincular';

  @override
  String get unlinkAccount => 'Desvincular Conta';

  @override
  String get unlinkAccountDesc =>
      'Suas estatísticas permanecerão neste dispositivo, mas não serão mais sincronizadas entre dispositivos.';

  @override
  String get unlinkAccountQuestion => 'Desvincular Conta?';

  @override
  String get unlinkFolder => 'Desvincular pasta e limpar lista de músicas';

  @override
  String get unlinkFolderClear => 'Desvincular pasta e limpar lista de músicas';

  @override
  String unlockedCountLabel(int unlocked, int total) {
    return '$unlocked / $total Desbloqueado';
  }

  @override
  String get unmuteTooltip => 'Ativar som';

  @override
  String get unsavedChanges => 'Alterações não salvas';

  @override
  String get upNext => 'A seguir';

  @override
  String upNextCount(int count) {
    return 'A seguir ($count)';
  }

  @override
  String get upNextSection => 'A seguir';

  @override
  String get updateAvailableTitle => 'Atualização disponível';

  @override
  String updateAvailableVersion(String version) {
    return 'Uma nova versão ($version) está disponível.';
  }

  @override
  String updateFailed(String error) {
    return 'Falha na atualização: $error';
  }

  @override
  String get updateNow => 'Atualizar agora';

  @override
  String get updatePrompt => 'Deseja baixar e instalar agora?';

  @override
  String get updatingYtDlp => 'Atualizando yt-dlp';

  @override
  String get usbAudioBypass =>
      'USB Audio Bypass (Beta) - Saída direta de DAC para Android 13 e inferior';

  @override
  String get usbAudioBypassBeta =>
      'USB Audio Bypass (Beta) - Saída direta de DAC para Android 13 e inferior';

  @override
  String get useDarkTheme => 'Usar tema escuro';

  @override
  String get useMixedColors =>
      'Usar cores mistas (prioridade para sincronização)';

  @override
  String get verifiedDeveloper => 'Desenvolvedor Verificado';

  @override
  String get version => 'Versão';

  @override
  String versionLabel(String version) {
    return 'Versão $version';
  }

  @override
  String get vietnamese => 'Vietnamita';

  @override
  String get viewQueue => 'Ver Fila';

  @override
  String get visualizer => 'Visualizador';

  @override
  String get visualizerStyle => 'Estilo do visualizador';

  @override
  String get wasapiExclusive => 'Modo Exclusivo WASAPI';

  @override
  String get weekly => 'Semanal';

  @override
  String get weeks => 'Semanas';

  @override
  String get winter => 'Inverno';

  @override
  String get worldRanking => 'Ranking Mundial';

  @override
  String get worldTopArtists => 'Top Artistas Mundiais';

  @override
  String get year => 'Ano';

  @override
  String get youMayLike => 'Você pode gostar';

  @override
  String get yourPlaylists => 'Suas Playlists';

  @override
  String get yourTopMix => 'Seu Melhor Mix';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytDlpUpdateAvailable =>
      'Uma nova versão do yt-dlp está disponível.';

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
  String get offlineModeHeader => 'MODO OFFLINE';

  @override
  String get offlineModeTitle => 'Modo Offline';

  @override
  String get offlineModeActive => 'ATIVO';

  @override
  String get offlineModeEnabledStatus => 'Modo Offline Ativado';

  @override
  String offlineModeDisabledStatus(int count) {
    return 'Desativado ($count)';
  }

  @override
  String get offlineModeAllEnabledStatus => 'Tudo Ativado';

  @override
  String get offlineModeLockdownDesc =>
      'Bloqueio de rede ativo. As estatísticas são salvas localmente.';

  @override
  String get offlineModeMainDesc =>
      'Desativar todos os serviços de rede e reproduzir apenas a biblioteca local.';

  @override
  String get enableOfflineModeQuestion => 'Ativar Modo Offline?';

  @override
  String get offlineModeConfirmationDesc =>
      'Isso desativará completamente toda a comunicação de rede. Os seguintes recursos serão desligados:';

  @override
  String get offlineModeSyncRestoreNote =>
      'Suas estatísticas serão sincronizadas automaticamente quando você desativar isso.';

  @override
  String get enableOfflineModeBtn => 'Ativar Modo Offline';

  @override
  String get onlineModeRestored =>
      'Modo online restaurado. Sincronizando estatísticas...';

  @override
  String get disableServicesTitle => 'Desativar Serviços';

  @override
  String get manageIndividualFeatures =>
      'Gerenciar recursos online individuais';

  @override
  String get featureCloudSync => 'Sincronização de Estatísticas na Nuvem';

  @override
  String get featureCloudSyncDesc =>
      'Estatísticas de escuta salvas apenas localmente';

  @override
  String get featureCloudSyncLongDesc =>
      'Sincronizar métricas de escuta com o PocketBase';

  @override
  String get featureLeaderboard => 'Tabela de Classificação Global';

  @override
  String get featureLeaderboardDesc => 'Atualizações de classificação pausadas';

  @override
  String get featureLeaderboardLongDesc =>
      'Mostrar e atualizar sua classificação publicamente';

  @override
  String get featureOnlineLyrics => 'Busca de Letras Online';

  @override
  String get featureOnlineLyricsDesc => 'Apenas arquivos .lrc/.ttml locais';

  @override
  String get featureOnlineLyricsLongDesc => 'Buscar letras no LRCLIB/Spotify';

  @override
  String get featureAiLyrics => 'Gerador de Letras por IA';

  @override
  String get featureAiLyricsDesc =>
      'Letras sincronizadas automaticamente desativadas';

  @override
  String get featureAiLyricsLongDesc => 'Gerar letras sincronizadas via IA';

  @override
  String get featureSpotifyCanvas => 'Spotify Canvas';

  @override
  String get featureSpotifyCanvasDesc => 'Vídeos de fundo desativados';

  @override
  String get featureSpotifyCanvasLongDesc => 'Vídeos de fundo para as faixas';

  @override
  String get featureOnlineSearch => 'Busca Online';

  @override
  String get featureOnlineSearchDesc => 'Busca no Spotify/YouTube desativada';

  @override
  String get featureOnlineSearchLongDesc => 'Busca remota no Spotify e YouTube';

  @override
  String get featureConnectDevice => 'Conectar a um Dispositivo';

  @override
  String get featureConnectDeviceDesc =>
      'Controle remoto e sessões em grupo desativados';

  @override
  String get featureConnectDeviceLongDesc =>
      'Controle remoto e sessões em grupo';

  @override
  String get lyricsEditorTitle => 'Editor de Letras';

  @override
  String get clearAllQuestion => 'Limpar tudo?';

  @override
  String get clearAllDesc =>
      'Isso limpará o estado atual do editor. NÃO excluirá seus arquivos locais, a menos que você salve depois.';

  @override
  String get clearBtn => 'Limpar';

  @override
  String get lyricsApplied => 'Letras aplicadas ao painel!';

  @override
  String get chooseFormat => 'Escolha o seu formato preferido:';

  @override
  String get lrcFormat => 'LRC (Sincronizado Padrão)';

  @override
  String get lrcFormatDesc => 'Formato universal, funciona em qualquer lugar.';

  @override
  String get ttmlFormat => 'TTML (Alta Precisão)';

  @override
  String get ttmlFormatDesc =>
      'Melhor para geração de IA e sincronização detalhada.';

  @override
  String savedSuccessfully(String extension) {
    return 'Salvo no arquivo $extension com sucesso!';
  }

  @override
  String get failedToSave => 'Falha ao salvar o arquivo de letras.';

  @override
  String get generationFailed => 'Falha na geração';

  @override
  String get aiLyricsGenerationTitle => 'Geração de Letras por IA';

  @override
  String get syncedMode => 'Sincronizado';

  @override
  String get plainMode => 'Texto Simples';

  @override
  String get addLineToTop => 'Adicionar ao topo';

  @override
  String get addLineToEnd => 'Adicionar ao final';

  @override
  String get lyricTextHint => 'Texto da letra...';

  @override
  String get insertAfter => 'Inserir depois';

  @override
  String get removeLine => 'Remover linha';

  @override
  String get romajiHint => 'Romaji / Transliteração (Opcional)...';

  @override
  String get startLabel => 'Início: ';

  @override
  String get setStartTooltip => 'Definir início para a posição atual';

  @override
  String get endLabel => 'Fim: ';

  @override
  String get setEndTooltip => 'Definir fim para a posição atual';

  @override
  String get playFromLine => 'Reproduzir a partir desta linha';

  @override
  String get pasteLyricsHint => 'Cole suas letras aqui...';

  @override
  String get applyBtn => 'Aplicar';

  @override
  String get saveLocallyBtn => 'Salvar localmente';

  @override
  String get editLyricsTooltip => 'Editar letras';

  @override
  String get saveLyricsTitle => 'Salvar letras';

  @override
  String get aiGenerate => 'Gerar IA';

  @override
  String get aiLyricsInitializing => 'Inicializando...';

  @override
  String get aiLyricsUploading => 'Enviando música para o servidor...';

  @override
  String get aiLyricsUploadFailed => 'Erro: Falha no upload.';

  @override
  String get aiLyricsUploadSuccess => 'Upload concluído!';

  @override
  String get aiLyricsVerifying => 'Verificando status do servidor...';

  @override
  String get aiLyricsStatusOk => 'Código de status 200 OK!';

  @override
  String get aiLyricsPolling => 'Obtendo letras... Por favor, seja paciente!';

  @override
  String get aiLyricsReceiving => 'Letras recebidas';

  @override
  String get aiLyricsParsing => 'Analisando letras...';

  @override
  String get aiLyricsSuccess => 'Letras geradas com sucesso!';

  @override
  String get aiLyricsLocalFileMissing =>
      'Erro: Arquivo de áudio local não encontrado.';

  @override
  String get aiLyricsComplete => 'Concluído!';

  @override
  String get externalLinkDetected => 'Link Externo Detetado';

  @override
  String get gofileDownloadFailedPrompt =>
      'O download automático falhou devido a restrições estritas de rede ou servidor.\\n\\nGostaria de abrir a página de download do Gofile no seu navegador de sistema ou copiar o link para fazer o download manualmente?';

  @override
  String get copyLink => 'Copiar Link';

  @override
  String get openBrowser => 'Abrir Navegador';

  @override
  String get linkCopied => 'Link copiado para a área de transferência!';

  @override
  String get waitingForServerResponse => 'Aguardando resposta do servidor...';

  @override
  String queuePositionPleaseWait(int position) {
    return 'Fila $position... por favor, aguarde';
  }

  @override
  String get processingOnServer => 'Processando no servidor...';
}
