// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get aboutEducationalPurpose =>
      'Cette application est développée uniquement à des fins individuelles et pédagogiques.';

  @override
  String get aboutLicenses => 'À propos et licences';

  @override
  String get aboutNotForCommercial => 'Pas pour un usage commercial.';

  @override
  String get accentColor => 'Couleur d\'accentuation';

  @override
  String get access => 'Accéder';

  @override
  String get accessCode => 'Code d\'accès';

  @override
  String get accountDataMergeDesc =>
      'En synchronisant, votre nom de profil et votre avatar seront mis à jour, mais les minutes d\'écoute de votre appareil actuel seront fusionnées avec succès dans le total du compte.';

  @override
  String get accountLinked => 'Compte associé';

  @override
  String get accountLinkedSuccessfully => 'Compte lié avec succès !';

  @override
  String get accountTiers => 'Niveaux de compte';

  @override
  String get achievementsUnlocked => 'Succès déverrouillés';

  @override
  String get activeNoResampling => 'Actif (Pas de rééchantillonnage)';

  @override
  String get add => 'Ajouter';

  @override
  String get addFiles => 'Ajouter des fichiers';

  @override
  String get addFolder => 'Ajouter un dossier';

  @override
  String get addFoldersScan => 'Ajouter des dossiers à scanner';

  @override
  String get addLineToEnd => 'Ajouter à la fin';

  @override
  String get addLineToTop => 'Ajouter en haut';

  @override
  String get addToFavorite => 'Ajouter aux favoris';

  @override
  String get addToPlaylist => 'Ajouter à la playlist';

  @override
  String get addToQueue => 'Ajouter à la file';

  @override
  String addedFolder(Object folder) {
    return 'Dossier ajouté : $folder';
  }

  @override
  String get addedToLikedSongs => 'Ajouté aux chansons aimées';

  @override
  String get addedToPlaylistSuccess => 'Ajouté à la playlist';

  @override
  String get addedToQueue => 'Ajouté à la file';

  @override
  String get aiGenerate => 'Générer par IA';

  @override
  String get aiLyricsComplete => 'Terminé !';

  @override
  String get aiLyricsError => 'Error generating AI lyrics.';

  @override
  String get aiLyricsFailed => 'Failed to generate AI lyrics.';

  @override
  String get aiLyricsGenerating => 'Generating AI Lyrics...';

  @override
  String get aiLyricsGenerationTitle => 'Génération de Paroles par IA';

  @override
  String get aiLyricsInitializing => 'Initialisation...';

  @override
  String get aiLyricsLocalFileMissing =>
      'Erreur : Fichier audio local non trouvé.';

  @override
  String get aiLyricsParsing => 'Analyse des paroles...';

  @override
  String get aiLyricsPolling =>
      'Récupération des paroles... Veuillez patienter !';

  @override
  String get aiLyricsReceiving => 'Paroles reçues';

  @override
  String get aiLyricsStatusOk => 'Code de statut 200 OK !';

  @override
  String get aiLyricsSuccess => 'Paroles générées avec succès !';

  @override
  String get aiLyricsUploadFailed => 'Erreur : Échec du téléchargement.';

  @override
  String get aiLyricsUploadSuccess => 'Téléchargement terminé !';

  @override
  String get aiLyricsUploading =>
      'Téléchargement de la chanson sur le serveur...';

  @override
  String get aiLyricsVerifying => 'Vérification du statut du serveur...';

  @override
  String alacDownloadsPerDay(int count) {
    return '$count Téléchargements ALAC / jour';
  }

  @override
  String get alacHighResDownloads => 'Téléchargements ALAC Haute Résolution';

  @override
  String get album => 'Album';

  @override
  String get albumAddedToPlaylists => 'Album ajouté aux playlists';

  @override
  String get albumLabel => 'Album';

  @override
  String get albumRemovedFromPlaylists => 'Album retiré des playlists';

  @override
  String get albums => 'Albums';

  @override
  String get allDownloadsRemoved => 'Tous les téléchargements retirés';

  @override
  String get allRightsReserved => 'Tous droits réservés.';

  @override
  String get allTime => 'Depuis toujours';

  @override
  String get alreadyInLikedSongs => 'Déjà dans les chansons aimées';

  @override
  String get alreadyPaidCheckStatus => 'Déjà payé ? Vérifier le statut';

  @override
  String get android14BitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidAudioEffectsNote =>
      'Note : Les effets audio sont disponibles uniquement sur Android.';

  @override
  String get androidAudioTrack => 'Android AudioTrack';

  @override
  String get androidBitPerfect => 'Android 14+ Bit-Perfect';

  @override
  String get androidMixer => 'Mixeur Android';

  @override
  String get appearance => 'Apparence';

  @override
  String get applyBtn => 'Appliquer';

  @override
  String get applyOnRestart =>
      'Les modifications seront appliquées au prochain redémarrage.';

  @override
  String get arabic => 'Arabe';

  @override
  String get artist => 'Artiste';

  @override
  String get artistLabel => 'Artiste';

  @override
  String get artists => 'Artistes';

  @override
  String get atmospheres => 'Atmosphères';

  @override
  String get audioFormat => 'Format audio';

  @override
  String get audioOutput => 'Sortie Audio';

  @override
  String get audioOutputDevice => 'Périphérique de sortie audio';

  @override
  String get audioQuality => 'Qualité audio';

  @override
  String get audioSource => 'Source audio';

  @override
  String get audiophileDAC =>
      'Activer lors de la lecture sur des DAC audiophiles (nécessite un redémarrage)';

  @override
  String get autoAddSimilar =>
      'Ajouter automatiquement des chansons similaires à la fin de la file';

  @override
  String get autoClearAfter24h => 'Après 24 heures';

  @override
  String get autoClearAfter7d => 'Après 7 jours';

  @override
  String get autoClearCache => 'Vider le cache automatiquement';

  @override
  String get autoClearDisabled => 'Désactivé';

  @override
  String get autoClearEvery30m => 'Toutes les 30 min (Écoute seulement)';

  @override
  String get autoClearOnClose => 'À la fermeture de l\'application';

  @override
  String get autoFixComingSoon => 'Auto-Correction (Bientôt)';

  @override
  String get autoRestartNotSupported =>
      'Le redémarrage automatique n\'est pas supporté. Veuillez redémarrer manuellement.';

  @override
  String autoTagContent(int count, String sourceName) {
    return 'Cela recherchera toutes les $count chansons de \"$sourceName\" sur Spotify et écrasera les tags automatiquement.\\n\\nCette action est irréversible.';
  }

  @override
  String autoTagTitle(String sourceName) {
    return '⚠️ Auto-tagger $sourceName ?';
  }

  @override
  String get automatic => 'Automatique';

  @override
  String get automaticGainControl => 'Contrôle Automatique du Gain';

  @override
  String get automaticGainControlDesc =>
      'Normalise le volume entre les chansons pour que rien ne soit trop fort ou trop faible.';

  @override
  String automaticTitleLabel(String title) {
    return 'Automatique : $title';
  }

  @override
  String get autumn => 'Automne';

  @override
  String get avatarPickerDesc =>
      'Sélectionnez un modèle ou importez votre propre photo';

  @override
  String get backgroundCacheFlacStreams =>
      'Mise en cache des flux FLAC en arrière-plan';

  @override
  String get backgroundCacheFlacStreamsSubtitle =>
      'Télécharge silencieusement les pistes sans perte en streaming sur votre disque local pour une lecture instantanée sans consommation de données.';

  @override
  String get beFirstToClaim =>
      'Soyez le premier à revendiquer la première place !';

  @override
  String get behavioralHeader => 'SUCCÈS COMPORTEMENTAUX';

  @override
  String get behavioralTitles => 'COMPORTEMENTAL';

  @override
  String get binariesUpdateRequired => 'Mise à jour des binaires requise';

  @override
  String get bitDepthLabel => 'Profondeur de bits';

  @override
  String get bitPerfectBypassSub14 =>
      'Contourner le mixeur système via l\'API Bit-Perfect d\'Android 14+';

  @override
  String get bitPerfectBypassSubLegacy =>
      'Contourner le mixeur système via le moteur audio C++ (Android 13 et moins)';

  @override
  String get bitPerfectBypassSuccess => 'Lecture Bit-Perfect activée.';

  @override
  String get bitPerfectBypassTitle => 'Bit-Perfect / USB Audio Bypass';

  @override
  String get bitPerfectBypassWarning =>
      'Vous devez d\'abord brancher votre USB DAC.';

  @override
  String get bitPerfectEnabled =>
      'Mode Bit-perfect activé. Le contrôle du volume peut ne pas fonctionner.';

  @override
  String get bitPerfectWindows =>
      'Audio Bit-perfect avec taux d\'échantillonnage automatique (nécessite un redémarrage)';

  @override
  String get bitrateLabel => 'Débit binaire';

  @override
  String get bitsLabel => 'Bits';

  @override
  String get brazil => 'Brésil';

  @override
  String get browse => 'Explorer';

  @override
  String get bypassSystemMixer => 'Contourner le mixeur système pour USB DAC';

  @override
  String get bypassedBitPerfect => 'Contourné (Bit-Perfect)';

  @override
  String get cacheCleared => 'Cache effacé avec succès !';

  @override
  String get cached => 'En cache';

  @override
  String get cancel => 'Annuler';

  @override
  String get cancelAllBtn => 'Tout annuler';

  @override
  String get canvasSourcePreferenceSubtitle =>
      'Choisissez d\'où charger les boucles d\'arrière-plan animées';

  @override
  String get canvasSourcePreferenceTitle =>
      'Source du Canvas / pochette animée';

  @override
  String get championChampionTooltip =>
      'Atteignez le Top 1 mondial pendant 5 semaines';

  @override
  String get change => 'Modifier';

  @override
  String get changeFolder => 'Changer de dossier';

  @override
  String get changeFormatInSettings =>
      'Veuillez changer le format de sortie dans les paramètres';

  @override
  String get changeLabel => 'MODIFIER';

  @override
  String get changeLanguage => 'Changer la langue de l\'app';

  @override
  String get changesApplyRestart =>
      'Les modifications seront appliquées au prochain redémarrage.';

  @override
  String get changingAudioDeviceRestart =>
      'Un redémarrage est requis pour appliquer le changement de périphérique audio.\\n\\nRedémarrer maintenant ?';

  @override
  String get channelsLabel => 'Canaux';

  @override
  String get checkAgain => 'Vérifier à nouveau';

  @override
  String get checkInternetConnection => 'Vérifiez votre connexion internet';

  @override
  String get checkNetworkTryAgain => 'Vérifiez votre réseau et réessayez';

  @override
  String get chinese => 'Chinois';

  @override
  String get chooseAccentColor => 'Choisissez votre couleur statique préférée';

  @override
  String get chooseAnimationType => 'Choisir le type d\'animation';

  @override
  String get chooseArtist => 'CHOISIR L\'ARTISTE';

  @override
  String get chooseAvatar => 'Choisir un avatar';

  @override
  String get chooseFormat => 'Choisissez votre format préféré :';

  @override
  String get chooseYourTitle => 'Choisissez votre titre';

  @override
  String get circularPulse => 'Pulsation circulaire';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String get clearAllDesc =>
      'Cela effacera l\'état actuel de l\'éditeur. Cela ne supprimera PAS vos fichiers locaux sauf si vous enregistrez ensuite.';

  @override
  String get clearAllQuestion => 'Tout effacer ?';

  @override
  String get clearBtn => 'Effacer';

  @override
  String get clearHistory => 'Effacer l\'historique';

  @override
  String get clearImported => 'Effacer importés';

  @override
  String get clearMetadataCache =>
      'Effacer le cache des métadonnées et des illustrations';

  @override
  String get clearPlayHistory => 'Effacer l\'historique et le temps d\'écoute';

  @override
  String get clearStreamingCache => 'Effacer le cache de streaming';

  @override
  String get close => 'Fermer';

  @override
  String get cloud => 'Nuage';

  @override
  String get cloudStatsAndRankings => 'Statistiques Cloud et Classements';

  @override
  String get codeCopied => 'Code copié dans le presse-papier !';

  @override
  String get codeMust6Digits => 'Le code doit comporter 6 chiffres';

  @override
  String get codecLabel => 'Codec';

  @override
  String get comingSoon => 'À venir';

  @override
  String get community => 'Communauté';

  @override
  String get competitiveTitles => 'COMPÉTITIF';

  @override
  String get confirm => 'Confirmer';

  @override
  String get connect => 'Connecter';

  @override
  String get connectToADevice => 'Se connecter à un appareil';

  @override
  String get connected => 'Connecté';

  @override
  String connectedToDac(String deviceName) {
    return 'Connecté à $deviceName - USB Bypass activé';
  }

  @override
  String get connectedUsbDacs => 'USB DAC connectés :';

  @override
  String get connecting => 'Connexion...';

  @override
  String get connectionLostLeaderboard => 'Connexion perdue';

  @override
  String get connectionLostLeaderboardDesc =>
      'Le classement mondial nécessite une connexion active pour synchroniser vos statistiques et récupérer les classements mondiaux.';

  @override
  String consecutivePlaysTooltip(int count) {
    return 'Écoutez la même chanson $count fois de suite';
  }

  @override
  String get contentRegion => 'Région du contenu';

  @override
  String get continueToSociabuzz => 'Continuer vers Sociabuzz';

  @override
  String get copyCode => 'Copier le code';

  @override
  String get copyLink => 'Copier le Lien';

  @override
  String get couldNotDownloadFlac => 'Impossible de télécharger le FLAC.';

  @override
  String countSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chansons',
      one: '1 chanson',
    );
    return '$_temp0';
  }

  @override
  String get createPlaylist => 'Créer une playlist';

  @override
  String creatingPlaylistWithTracks(int count) {
    return 'Création d\'une liste de lecture avec $count pistes...';
  }

  @override
  String get crossfade => 'Crossfade';

  @override
  String crossfadeDesc(String seconds) {
    return 'Fondu entre les pistes ($seconds s)';
  }

  @override
  String get crownedChampionTitlesHeader => 'TITRES DE CHAMPION COURONNÉ';

  @override
  String get currentTierLabel => 'Actuel';

  @override
  String get customDevice => 'Périphérique personnalisé';

  @override
  String get customSelected => 'Sélection personnalisée';

  @override
  String get customTime => 'Temps personnalisé';

  @override
  String get cyberpunk => 'Cyberpunk';

  @override
  String get daily => 'Quotidien';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get dataCleanup => 'Données et nettoyage';

  @override
  String get dataUsage => 'Utilisation des données';

  @override
  String get daysShort => 'J';

  @override
  String get debugging => 'Débogage';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteDownloadsConfirm =>
      'Cela retirera toutes les chansons téléchargées sur cet appareil pour cette playlist.';

  @override
  String get deleteDownloadsTitle => 'Supprimer les téléchargements ?';

  @override
  String deleteFileContent(String filename) {
    return 'Êtes-vous sûr de vouloir supprimer \"$filename\" ?\\nCette action est irréversible.';
  }

  @override
  String get deleteFileTitle => 'Supprimer le fichier ?';

  @override
  String get deletePlaylist => 'Supprimer la liste de lecture';

  @override
  String deletePlaylistConfirm(String name) {
    return 'Êtes-vous sûr de vouloir supprimer \"$name\" ?';
  }

  @override
  String get deletePlaylistPermanentConfirm =>
      'Êtes-vous sûr de vouloir supprimer cette liste de lecture ? (Cette action est irréversible)';

  @override
  String get deletePlaylistTitle => 'Supprimer la playlist ?';

  @override
  String get deletePreset => 'Supprimer le préréglage';

  @override
  String get desertMirage => 'Mirage du Désert';

  @override
  String get developerExclusiveTooltip =>
      'Exclusivement pour les développeurs de cette application';

  @override
  String deviceNameLabel(String deviceName) {
    return 'Appareil : $deviceName';
  }

  @override
  String get disableCanvas => 'Désactiver le Canvas';

  @override
  String get disableRomanization => 'Désactiver la romanisation';

  @override
  String get disableServicesTitle => 'Désactiver les services';

  @override
  String get disabled => 'Désactivé';

  @override
  String get disablingSharingWarning =>
      'La désactivation du partage supprimera définitivement le code et les données du serveur pour gagner de l\'espace.';

  @override
  String get discNumber => 'N° de disque';

  @override
  String get discography => 'Discographie';

  @override
  String get discordRPC => 'Discord Rich Presence';

  @override
  String get doYouRemember => 'Vous souvenez-vous ?';

  @override
  String get donate => 'Faire un don';

  @override
  String get donateMinToObtain =>
      'Faites un don de 10 000 IDR minimum pour l\'obtenir (Permanent)';

  @override
  String get download => 'Télécharger';

  @override
  String get downloadAll => 'Tout télécharger';

  @override
  String get downloadComplete => 'Téléchargement terminé';

  @override
  String get downloadCompleteNotification => 'Téléchargement terminé';

  @override
  String get downloadError => 'Erreur de téléchargement';

  @override
  String get downloadFailed => 'Échec du téléchargement';

  @override
  String get downloadLocation => 'Emplacement de téléchargement';

  @override
  String get downloadPathReset =>
      'Chemin de téléchargement réinitialisé au défaut.';

  @override
  String downloadPathUpdated(Object path) {
    return 'Chemin de téléchargement mis à jour : $path';
  }

  @override
  String get downloadSong => 'Télécharger la chanson';

  @override
  String get downloadStarted => 'Téléchargement commencé';

  @override
  String downloadedTo(String path) {
    return 'Téléchargé dans : $path';
  }

  @override
  String get downloading => 'Téléchargement en cours';

  @override
  String get downloadingFlac => 'Téléchargement FLAC';

  @override
  String downloadingFormat(String format) {
    return 'Téléchargement $format';
  }

  @override
  String get downloadingUpdate => 'Téléchargement de la mise à jour';

  @override
  String get downloads => 'Téléchargements';

  @override
  String get dspLabel => 'DSP';

  @override
  String get editLyricsTooltip => 'Modifier les paroles';

  @override
  String get editMetadata => 'Modifier les métadonnées';

  @override
  String get editNickname => 'Modifier le pseudo';

  @override
  String get editor => 'Éditeur';

  @override
  String get emptyMailbox => 'Vider la boîte';

  @override
  String get emptyMailboxDesc =>
      'Cela supprimera tous les messages de façon permanente.';

  @override
  String get emptyMailboxTitle => 'Vider la boîte aux lettres ?';

  @override
  String get emptyPlaylist => 'Playlist vide';

  @override
  String get emptyPlaylistSubtitle => 'Créer une nouvelle playlist vide';

  @override
  String get enableAlphabetIndexer =>
      'Activer l\'indexeur de défilement alphabétique';

  @override
  String get enableAlphabetIndexerSubtitle =>
      'Afficher l\'indexation de la barre latérale A-Z sur la vue de liste mobile';

  @override
  String get enableBarVisualizer => 'Activer le visualiseur en barres';

  @override
  String get enableOfflineModeBtn => 'Activer le mode hors ligne';

  @override
  String get enableOfflineModeQuestion => 'Activer le mode hors ligne ?';

  @override
  String get endLabel => 'Fin : ';

  @override
  String get endlessQueue => 'File d\'attente infinie';

  @override
  String get engineLabel => 'Moteur';

  @override
  String get english => 'Anglais';

  @override
  String get enterAdminAccessCode =>
      'Veuillez entrer le code d\'accès administrateur';

  @override
  String get enterAdminCode =>
      'Veuillez entrer le code d\'accès administrateur';

  @override
  String get enterDuration => 'Entrez la durée...';

  @override
  String get enterPresetName => 'Entrez le nom du préréglage (ex: Mes Graves)';

  @override
  String get enterShareCode => 'Entrez le code de partage à 6 chiffres';

  @override
  String get eqLabel => 'EQ';

  @override
  String get equalizer => 'Égaliseur';

  @override
  String get equipTitle => 'ÉQUIPER LE TITRE';

  @override
  String get equipped => 'ÉQUIPÉ';

  @override
  String get error => 'Erreur';

  @override
  String get errorCouldNotCreateSession =>
      'Erreur : Impossible de créer la session.';

  @override
  String errorDeleting(String error) {
    return 'Erreur lors de la suppression : $error';
  }

  @override
  String get errorSearchingStream =>
      'Erreur lors de la recherche du streaming.';

  @override
  String get exclusiveMode => 'Exclusif';

  @override
  String get exclusiveModeWarning =>
      'Avertissement : Le mode exclusif fonctionne mieux si vous sélectionnez un périphérique spécifique plutôt que le défaut système.';

  @override
  String get exclusiveSupporterTitle =>
      'Titre de soutien exclusif et rôle Discord';

  @override
  String get exclusiveTitles => 'EXCLUSIF';

  @override
  String get exclusiveTitlesHeader => 'TITRES EXCLUSIFS';

  @override
  String get exclusiveWarning =>
      'Avertissement : Le mode exclusif fonctionne mieux si vous sélectionnez un périphérique spécifique plutôt que le défaut système.';

  @override
  String get exitApp => 'Quitter';

  @override
  String get expand => 'Agrandir';

  @override
  String get exportToM3u => 'Export to M3U';

  @override
  String get externalFiles => 'Fichiers externes';

  @override
  String get externalLinkDetected => 'Lien Externe Détecté';

  @override
  String get fadingAtEnd =>
      'Minuterie de sommeil : Fondu à la fin de la piste...';

  @override
  String get failedDisableSharing => 'Échec de la désactivation du partage.';

  @override
  String get failedEnableSharing =>
      'Échec de l\'activation du partage. Vérifiez la connexion.';

  @override
  String get failedFetchPlaylistInfo =>
      'Impossible de récupérer les informations de la liste de lecture';

  @override
  String get failedToConnectDac =>
      'Échec de connexion au DAC. Vérifiez les permissions USB.';

  @override
  String get failedToGenerateCode =>
      'Échec de la génération du code de partage. Vérifiez la connexion.';

  @override
  String get failedToSave =>
      'Échec de l\'enregistrement du fichier de paroles.';

  @override
  String get failedToSetAvatar => 'Échec de la définition du modèle d\'avatar';

  @override
  String get failedToUpdateMetadata =>
      'Échec de la mise à jour des métadonnées';

  @override
  String get favoriteTrack => 'Morceau préféré';

  @override
  String get featureAiLyrics => 'Générateur de paroles par IA';

  @override
  String get featureAiLyricsDesc =>
      'Paroles synchronisées automatiquement désactivées';

  @override
  String get featureAiLyricsLongDesc =>
      'Générer des paroles synchronisées via l\'IA';

  @override
  String get featureCloudSync => 'Synchro des stats cloud';

  @override
  String get featureCloudSyncDesc =>
      'Stats d\'écoute enregistrées localement uniquement';

  @override
  String get featureCloudSyncLongDesc =>
      'Synchroniser les mesures d\'écoute avec PocketBase';

  @override
  String get featureConnectDevice => 'Se connecter à un appareil';

  @override
  String get featureConnectDeviceDesc =>
      'Télécommande et sessions d\'écoute désactivées';

  @override
  String get featureConnectDeviceLongDesc =>
      'Télécommande et sessions d\'écoute';

  @override
  String get featureLeaderboard => 'Classement mondial';

  @override
  String get featureLeaderboardDesc => 'Mises à jour du classement suspendues';

  @override
  String get featureLeaderboardLongDesc =>
      'Afficher et mettre à jour votre classement publiquement';

  @override
  String get featureOnlineLyrics => 'Recherche de paroles en ligne';

  @override
  String get featureOnlineLyricsDesc => 'Uniquement fichiers .lrc/.ttml locaux';

  @override
  String get featureOnlineLyricsLongDesc =>
      'Récupérer les paroles depuis LRCLIB/Spotify';

  @override
  String get featureOnlineSearch => 'Recherche en ligne';

  @override
  String get featureOnlineSearchDesc => 'Recherche Spotify/YouTube désactivée';

  @override
  String get featureOnlineSearchLongDesc =>
      'Recherche à distance Spotify et YouTube';

  @override
  String get featureSpotifyCanvas => 'Spotify Canvas';

  @override
  String get featureSpotifyCanvasDesc => 'Vidéos d\'arrière-plan désactivées';

  @override
  String get featureSpotifyCanvasLongDesc =>
      'Vidéos d\'arrière-plan pour les pistes';

  @override
  String get fetchingAlacAppleMusic =>
      'Récupération d\'ALAC Lossless depuis Apple Music...';

  @override
  String get fetchingCanvas => 'Récupération du Canvas...';

  @override
  String get fetchingLossless => 'Récupération sans perte...';

  @override
  String get fetchingLosslessAudio => 'Récupération de l\'audio sans perte...';

  @override
  String get fetchingMetadataSpotify =>
      'Récupération des métadonnées Spotify...';

  @override
  String get fetchingPlaylist => 'Récupération de la liste de lecture...';

  @override
  String get fetchingPlaylistInfo =>
      'Récupération des informations de la liste de lecture...';

  @override
  String get fetchingSharedPlaylist =>
      'Récupération de la liste de lecture partagée...';

  @override
  String fetchingTracksFrom(String name) {
    return 'Récupération des pistes de \"$name\"...';
  }

  @override
  String get fileLocation => 'Emplacement du fichier';

  @override
  String get fileMissingHistory =>
      'Fichier manquant et non présent dans l\'historique.';

  @override
  String get fileName => 'Nom de fichier';

  @override
  String get fileSizeLabel => 'Taille du fichier';

  @override
  String get files => 'Fichiers';

  @override
  String get filters => 'Filtres';

  @override
  String get findingBestMatchYoutube =>
      'Recherche de la meilleure correspondance sur YouTube...';

  @override
  String get findingStream => 'Recherche de la source de streaming...';

  @override
  String get finishUpdate => 'Terminer la mise à jour';

  @override
  String get finishes => 'Finitions';

  @override
  String get fixAll => 'Tout corriger';

  @override
  String get flacError => 'Erreur FLAC';

  @override
  String get flacNote =>
      'Note : FLAC est disponible uniquement pour les téléchargements de pistes uniques. Les téléchargements de playlists utiliseront le format M4A.';

  @override
  String get flacSavedToDownloads =>
      'FLAC enregistré dans le dossier téléchargements';

  @override
  String get flacUnavailable => 'FLAC indisponible';

  @override
  String get flacUnavailableDesc =>
      'Le FLAC n\'est pas disponible, échec du téléchargement. Essayez de modifier les paramètres.';

  @override
  String get flacUnavailableNotification => 'FLAC indisponible';

  @override
  String get fluidWave => 'Onde fluide';

  @override
  String folderPath(String path) {
    return 'Dossier : $path';
  }

  @override
  String get folders => 'Dossiers';

  @override
  String get formatLabel => 'Format';

  @override
  String get formatSaved => 'Format enregistré !';

  @override
  String foundExistingAccount(String name) {
    return 'Nous avons trouvé un compte existant pour \'$name\'.';
  }

  @override
  String foundResults(int songCount, int albumCount, int artistCount) {
    return 'Trouvé $songCount chansons, $albumCount albums, $artistCount artistes.';
  }

  @override
  String foundYoutubeResults(int count) {
    return '$count résultats trouvés sur YouTube';
  }

  @override
  String freeUpSpace(String size) {
    return 'Libérer de l\'espace (Actuel : $size)';
  }

  @override
  String get french => 'Français';

  @override
  String fromLibraryCount(int count) {
    return 'De la bibliothèque ($count)';
  }

  @override
  String get fromLibrarySection => 'De la bibliothèque';

  @override
  String get fullScreenPlayerTooltip => 'Lecteur plein écran';

  @override
  String get galacticSpace => 'Espace Galactique';

  @override
  String get gaplessPlayback => 'Lecture sans Blanc';

  @override
  String get gaplessPlaybackDesc => 'Éliminer les silences entre les pistes';

  @override
  String get general => 'Général';

  @override
  String get generateAiLyrics => 'Generate AI Lyrics';

  @override
  String get generatingShareCode => 'Génération du code de partage...';

  @override
  String get generationFailed => 'Échec de la génération';

  @override
  String get genre => 'Genre';

  @override
  String get german => 'Allemand';

  @override
  String get globalLeaderboard => 'Classement Mondial';

  @override
  String get globalMailbox => 'Boîte aux lettres globale';

  @override
  String get globalRank => 'Rang mondial';

  @override
  String get globalRankings => 'Classements mondiaux';

  @override
  String get globalRankingsDesc =>
      'Consultez les meilleurs auditeurs quotidiens, hebdomadaires et de tous les temps !';

  @override
  String get goToArtist => 'Aller à l\'artiste';

  @override
  String get goToLocalLibraryToSelect =>
      'Allez dans la Bibliothèque locale pour sélectionner un dossier.';

  @override
  String get gofileDownloadFailedPrompt =>
      'Le téléchargement automatique a échoué en raison de restrictions réseau ou de serveur strictes.\\n\\nSouhaitez-vous ouvrir la page de téléchargement Gofile dans votre navigateur système, ou copier le lien pour le télécharger manuellement ?';

  @override
  String get goodAfternoon => 'Bon après-midi';

  @override
  String get goodEvening => 'Bonsoir';

  @override
  String get goodMorning => 'Bonjour';

  @override
  String get googleAccount => 'Compte Google';

  @override
  String get grantAccess => 'Accorder l\'accès';

  @override
  String get grantPermission => 'Accorder la permission';

  @override
  String get guestTier => 'Invité';

  @override
  String get hallOfFameHeader => 'SUCCÈS DU TEMPLE DE LA RENOMMÉE';

  @override
  String get hallOfFameTitles => 'TEMPLE DE LA RENOMMÉE';

  @override
  String get hideCanvas =>
      'Ne pas afficher les vidéos Spotify Canvas, afficher la pochette à la place';

  @override
  String get hideRomajiPinyin =>
      'Ne pas afficher Romaji/Pinyin sous les paroles coréennes, japonaises ou chinoises';

  @override
  String get hideTranslation => 'Masquer la traduction';

  @override
  String get highDesc => 'M4A - Meilleur son, performance équilibrée';

  @override
  String get highQuality => 'Haute Qualité (M4A)';

  @override
  String get hindi => 'Hindi';

  @override
  String get history => 'Historique';

  @override
  String get historySection => 'Historique';

  @override
  String get home => 'Accueil';

  @override
  String get hourShort => 'h';

  @override
  String hoursDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '1 heure',
    );
    return '$_temp0';
  }

  @override
  String get hoursShort => 'H';

  @override
  String get ignoreSubfolderScan => 'Ignorer le scan des sous-dossiers';

  @override
  String get importAdditionalPaths => 'Importer des chemins supplémentaires';

  @override
  String get importChoice => 'Importer';

  @override
  String importFailed(String error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get importFromGallery => 'Importer de la galerie';

  @override
  String get importFromM3u => 'Import from M3U';

  @override
  String get importFromM3uSubtitle => 'Import an M3U playlist file';

  @override
  String get importFromSpotify => 'Importer depuis Spotify';

  @override
  String get importFromSpotifySubtitle => 'Collez un lien de playlist Spotify';

  @override
  String get importFromYoutubeMusic => 'Importer depuis YouTube Music';

  @override
  String get importFromYoutubeMusicSubtitle =>
      'Coller un lien de playlist YouTube Music';

  @override
  String get importLabel => 'Importer';

  @override
  String get importLyricsFile => 'Importer un fichier de paroles';

  @override
  String get importLyricsTooltip => 'Importer des paroles';

  @override
  String get localFile => 'Fichier local';

  @override
  String get importLocalFileSubtitle => 'Importer .lrc, .ttml ou .txt';

  @override
  String get searchFromAppleMusic => 'Rechercher sur Apple Music';

  @override
  String get searchAppleMusicSubtitle => 'Télécharge automatiquement LRC/TTML';

  @override
  String get searchFromSpotifyLyrics => 'Rechercher sur Spotify';

  @override
  String get searchSpotifyLyricsSubtitle =>
      'Télécharge des paroles synchronisées depuis Spotify';

  @override
  String get searchFromMusixmatch => 'Rechercher sur Musixmatch';

  @override
  String get searchMusixmatchSubtitle =>
      'Télécharge des paroles synchronisées depuis Musixmatch';

  @override
  String get searchingAppleMusic => 'Recherche sur Apple Music...';

  @override
  String get findingMatches => 'Recherche de correspondances...';

  @override
  String get noResultsAppleMusic => 'Aucun résultat trouvé sur Apple Music.';

  @override
  String get selectSong => 'Sélectionner la chanson';

  @override
  String get downloadingLyrics => 'Téléchargement des paroles...';

  @override
  String get fetchingLyricsFromServer =>
      'Récupération de TTML/LRC depuis le serveur...';

  @override
  String get failedDownloadAppleMusic =>
      'Échec du téléchargement des paroles. Elles n\'existent peut-être pas sur Apple Music.';

  @override
  String get lyricsImportedSuccess =>
      'Paroles importées avec succès ! Appuyez sur Enregistrer pour les conserver.';

  @override
  String get receivedEmptyLyrics => 'Paroles vides reçues du serveur.';

  @override
  String get downloadingFromSpotify => 'Téléchargement depuis Spotify...';

  @override
  String get fetchingLyrics => 'Récupération des paroles...';

  @override
  String get lyricsImportedSpotify => 'Paroles importées depuis Spotify !';

  @override
  String get noLyricsSpotify => 'Aucune parole trouvée sur Spotify.';

  @override
  String get downloadingFromMusixmatch => 'Téléchargement depuis Musixmatch...';

  @override
  String get lyricsImportedMusixmatch =>
      'Paroles importées depuis Musixmatch !';

  @override
  String get noLyricsMusixmatch => 'Aucune parole trouvée sur Musixmatch.';

  @override
  String get importSpotifyPlaylist => 'Importer playlist Spotify';

  @override
  String get importViaCode => 'Importer via un code';

  @override
  String get importViaCodeSubtitle =>
      'Importer une liste de lecture partagée par un ami';

  @override
  String get importYoutubeMusicPlaylist => 'Importer playlist YouTube Music';

  @override
  String importedPlaylistName(String name) {
    return '\"$name\" importée avec succès !';
  }

  @override
  String importedTracks(int count) {
    return '$count pistes importées avec succès !';
  }

  @override
  String get indonesia => 'Indonésie';

  @override
  String get indonesian => 'Indonésien';

  @override
  String get inputLabel => 'Entrée';

  @override
  String get insertAfter => 'Insérer après';

  @override
  String get installNow => 'Installer maintenant';

  @override
  String get integration => 'Intégration';

  @override
  String get invalidAccessCode => 'Code d\'accès invalide';

  @override
  String get invalidCode => 'Code d\'accès invalide';

  @override
  String get invalidM3uFile => 'Invalid M3U File';

  @override
  String get invalidSpotifyUrl => 'URL de liste de lecture Spotify invalide';

  @override
  String get invalidYoutubeMusicUrl => 'URL de playlist YouTube Music invalide';

  @override
  String get japan => 'Japon';

  @override
  String get japanese => 'Japonais';

  @override
  String get joinUs => 'Rejoignez-nous';

  @override
  String get jumpBackIn => 'S\'y remettre';

  @override
  String get justEnjoyVibes => 'Profitez simplement de la musique.';

  @override
  String get korean => 'Coréen';

  @override
  String get language => 'Langue';

  @override
  String last30DaysLabel(String size) {
    return '30 derniers jours: $size';
  }

  @override
  String last7DaysLabel(String size) {
    return '7 derniers jours: $size';
  }

  @override
  String get later => 'Plus tard';

  @override
  String get library => 'Bibliothèque';

  @override
  String get libraryData => 'Données bibliothèque';

  @override
  String get libraryNotLoaded => 'Bibliothèque non chargée.';

  @override
  String get libraryPathReset => 'Chemin de la bibliothèque réinitialisé.';

  @override
  String get likedSongs => 'Chansons aimées';

  @override
  String get linkAccount => 'Associer un compte';

  @override
  String get linkAccountDesc =>
      'Synchronisez et restaurez votre progression avec Google';

  @override
  String get linkAccountToUpgrade =>
      'Vous devez d\'abord lier votre compte pour effectuer une mise à niveau. Veuillez utiliser la même adresse e-mail sur Sociabuzz !';

  @override
  String get linkCopied => 'Lien copié dans le presse-papiers !';

  @override
  String listenMinutesTooltip(String minutes) {
    return 'Écoutez $minutes minutes de musique';
  }

  @override
  String get listeningParty => 'Session d\'écoute';

  @override
  String get listeningStats => 'Statistiques d\'écoute';

  @override
  String get loadingCanvas => 'Chargement du Canvas...';

  @override
  String get loadingDevices => 'Chargement des périphériques...';

  @override
  String get loadingError =>
      'Échec du chargement des détails. Veuillez réessayer.';

  @override
  String get loadingLyrics => 'Chargement des paroles...';

  @override
  String get localPlayHistorySaved =>
      'Votre historique de lecture local ne sera pas supprimé.';

  @override
  String get local_library => 'Bibliothèque locale';

  @override
  String get lockedAtmosphere =>
      'Verrouillé tant qu\'une atmosphère est active';

  @override
  String get losslessDesc => 'FLAC - Qualité sans perte depuis Deezer/Tidal';

  @override
  String get losslessNote =>
      'Utilisera le FLAC sans perte si disponible sur Deezer/Tidal. Sinon, reviendra au M4A.';

  @override
  String get losslessQuality => 'Sans perte (Auto)';

  @override
  String get lrcFormat => 'LRC (Synchronisation standard)';

  @override
  String get lrcFormatDesc => 'Format universel, fonctionne partout.';

  @override
  String get lunarNewYear => 'Nouvel An Lunaire';

  @override
  String get lyricTextHint => 'Texte des paroles...';

  @override
  String get lyricsApplied => 'Paroles appliquées au panneau !';

  @override
  String get lyricsByLRCLIB => 'Paroles par LRCLIB';

  @override
  String get lyricsEditorTitle => 'Éditeur de Paroles';

  @override
  String get lyricsSaveError => 'Erreur lors de l\'enregistrement des paroles';

  @override
  String get lyricsSavedSuccess => 'Paroles enregistrées dans le fichier .lrc';

  @override
  String get lyricsTooltip => 'Paroles';

  @override
  String get madeForYou => 'Fait pour vous';

  @override
  String get manageIndividualFeatures =>
      'Gérer les fonctionnalités en ligne individuelles';

  @override
  String get manualSearch => 'Recherche manuelle';

  @override
  String get mergeAccountData => 'Fusionner les données du compte ?';

  @override
  String get metadataCacheCleared =>
      'Cache des métadonnées effacé et nouvelle analyse de la bibliothèque démarrée';

  @override
  String get metadataEditorInfo =>
      'Vous pouvez rechercher et corriger rapidement dans l\'Éditeur de métadonnées.';

  @override
  String get metadataEditorNote =>
      'Note : Après le statut \"Enregistré avec succès\", l\'image de l\'album peut changer. Ce n\'est pas une erreur, mais un problème de cache de l\'app que nous corrigeons. Vérifiez dans un gestionnaire de fichiers.';

  @override
  String get metadataUpdated => 'Métadonnées mises à jour';

  @override
  String get metadata_editor => 'Éditeur de Métadonnées';

  @override
  String get min => 'min';

  @override
  String get minShortLabel => 'min';

  @override
  String get miniPlayer => 'Mini Lecteur';

  @override
  String get minimizeToTray => 'Réduire dans la barre';

  @override
  String get minimizeToTrayDescription =>
      'Fermer l\'app dans la barre système au lieu de quitter';

  @override
  String get minsShort => 'M';

  @override
  String get minsShortLabel => 'min';

  @override
  String get minuteShort => 'min';

  @override
  String get minutes => 'minutes';

  @override
  String minutesDuration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get moreOptions => 'Plus d\'options';

  @override
  String get moreOptionsTooltip => 'Plus d\'options';

  @override
  String get mostListened => 'Plus écouté';

  @override
  String get mostListenedArtist => 'Artiste le plus écouté';

  @override
  String get musicFolderLocation => 'Emplacement du dossier musique';

  @override
  String get musicSearch => 'Recherche musicale';

  @override
  String musicWillStopIn(String label) {
    return 'La musique s\'arrêtera dans $label';
  }

  @override
  String get muteTooltip => 'Couper le son';

  @override
  String myTopTrackOn(String header) {
    return 'Mon $header sur Simple Player ! 🎵';
  }

  @override
  String get nativeRate => 'Taux natif';

  @override
  String get navigation => 'Navigation';

  @override
  String get newPlaylist => 'Nouvelle playlist';

  @override
  String get nextTrack => 'Piste suivante';

  @override
  String get nicknameHint => 'Entrez votre pseudo';

  @override
  String get nicknameLabel => 'Pseudo';

  @override
  String get nicknameRequired => 'Pseudo Requis';

  @override
  String get nicknameRequiredDesc =>
      'Vous devez d\'abord définir un pseudo personnalisé pour voir le classement mondial !';

  @override
  String get nicknameTakenDesc =>
      'Ce pseudo est déjà utilisé globalement. Veuillez en choisir un autre.';

  @override
  String get nicknameTakenTitle => 'Pseudo déjà pris';

  @override
  String get noAlbumsFound => 'Aucun album trouvé';

  @override
  String get noArtistStatsYet => 'Pas encore de statistiques d\'artistes.';

  @override
  String get noArtistsFound => 'Aucun artiste trouvé.';

  @override
  String get noDownloadsFound => 'Aucun téléchargement trouvé';

  @override
  String get noFolderSelected => 'Aucun dossier sélectionné';

  @override
  String get noHistoryYet => 'Pas encore d\'historique';

  @override
  String get noInternetConnection => 'Pas de connexion internet';

  @override
  String get noLyricsAvailable => 'Aucune parole disponible';

  @override
  String get noMessages => 'Pas de messages dans votre boîte';

  @override
  String get noMusicPlaying => 'Aucune musique en lecture';

  @override
  String get noPlaylistsFound => 'Aucune playlist trouvée';

  @override
  String get noPlaylistsYet => 'Pas encore de playlist';

  @override
  String get noRankingsYet => 'Pas encore de classement pour cette période.';

  @override
  String get noResultsFound => 'Aucun résultat trouvé';

  @override
  String get noSongPlaying => 'Aucune chanson en lecture';

  @override
  String get noSongsAdded => 'Pas encore de chanson ajoutée';

  @override
  String get noSongsInFolder => 'Aucune chanson trouvée dans ce dossier.';

  @override
  String get noSpotifyResults => 'Aucun résultat Spotify trouvé.';

  @override
  String get noStatsYet => 'Pas encore de statistiques.';

  @override
  String get noStreamMatch =>
      'Aucune correspondance trouvée pour le streaming.';

  @override
  String get noSuggestionsFound => 'Aucune suggestion trouvée.';

  @override
  String get noSyncedLyricsFound => 'Aucune parole synchronisée trouvée';

  @override
  String get noTracksFound => 'Aucune piste trouvée dans la liste de lecture';

  @override
  String get noUsbDacDetected =>
      'Aucun USB DAC détecté. Connectez un périphérique audio USB et appuyez sur Scan.';

  @override
  String get noUsersFound => 'Aucun utilisateur trouvé';

  @override
  String get noYoutubeResults => 'Aucun résultat trouvé sur YouTube';

  @override
  String get none => 'Aucune';

  @override
  String get nordicAurora => 'Aurore Nordique';

  @override
  String notRank(int rank) {
    return 'Pas au rang $rank';
  }

  @override
  String get notRanked => 'Non classé';

  @override
  String get notRankedTop3 => 'PAS DANS LE TOP 3';

  @override
  String get nowPlaying => 'Lecture en cours';

  @override
  String get nowPlayingHeader => 'En lecture';

  @override
  String get nowPlayingSection => 'En lecture';

  @override
  String get offline => 'Hors ligne';

  @override
  String get offlineModeActive => 'ACTIF';

  @override
  String get offlineModeAllEnabledStatus => 'Tout activé';

  @override
  String get offlineModeConfirmationDesc =>
      'Cela désactivéra complètement toute communication réseau. Les fonctionnalités suivantes seront désactivées :';

  @override
  String offlineModeDisabledStatus(int count) {
    return 'Désactivé ($count)';
  }

  @override
  String get offlineModeEnabledStatus => 'Mode hors ligne activé';

  @override
  String get offlineModeHeader => 'MODE HORS LIGNE';

  @override
  String get offlineModeLockdownDesc =>
      'Verrouillage réseau actif. Les statistiques sont enregistrées localement.';

  @override
  String get offlineModeMainDesc =>
      'Désactivez tous les services réseau et lisez uniquement la bibliothèque locale.';

  @override
  String get offlineModeSyncRestoreNote =>
      'Vos statistiques se synchroniseront automatiquement lorsque vous désactiverez cette option.';

  @override
  String get offlineModeTitle => 'Mode hors ligne';

  @override
  String get offlineStatus => 'Hors ligne';

  @override
  String get ok => 'OK';

  @override
  String get online => 'En ligne';

  @override
  String get onlineModeRestored =>
      'Mode en ligne restauré. Synchronisation des statistiques...';

  @override
  String get onlyAppleMusic => 'Uniquement Apple Music';

  @override
  String get onlyScanSelected =>
      'Scanner uniquement les dossiers sélectionnés (activé par défaut)';

  @override
  String get onlySpotify => 'Uniquement Spotify';

  @override
  String get opacity => 'Opacité';

  @override
  String opacityLabel(int percent) {
    return 'Opacité : $percent%';
  }

  @override
  String get openBrowser => 'Ouvrir le Navigateur';

  @override
  String get openProfile => 'Ouvrir le Profil';

  @override
  String get openSourceLicenses => 'Licences open source';

  @override
  String get outputLabel => 'Sortie';

  @override
  String get overwrite => 'Écraser';

  @override
  String get overwriteLrcWarning =>
      'Un fichier .lrc existe déjà pour cette chanson.\\nVoulez-vous l\'écraser ?';

  @override
  String get owned => 'Possédé';

  @override
  String get parsingPlaylistData =>
      'Analyse des données de la liste de lecture...';

  @override
  String get pasteLyricsHint => 'Collez vos paroles ici...';

  @override
  String get pathLabel => 'Chemin';

  @override
  String get permissionRequired => 'Permission requise';

  @override
  String get permissionRequiredDesc =>
      'La permission \"Accès à tous les fichiers\" est requise pour modifier les tags. Cela permet de modifier directement vos fichiers musicaux.';

  @override
  String get plainMode => 'Texte brut';

  @override
  String get play => 'Lire';

  @override
  String playCountLabel(int count) {
    return '$count lectures';
  }

  @override
  String get playFromLine => 'Lire à partir de cette ligne';

  @override
  String get playNext => 'Lire ensuite';

  @override
  String get playPause => 'Lecture / Pause';

  @override
  String get playQueue => 'File de lecture';

  @override
  String get playback => 'Lecture';

  @override
  String get playbackError => 'Erreur de lecture';

  @override
  String get player => 'Joueur';

  @override
  String get playingFromAlbum => 'Lecture depuis l\'album';

  @override
  String get playingNext => 'Lecture suivante';

  @override
  String get playingTrack => 'Lecture de la piste';

  @override
  String get playlistAlbumTracks => 'Pistes de playlist / album';

  @override
  String get playlistNameHint => 'Nom de la playlist';

  @override
  String get playlistNotFound => 'Playlist non trouvée';

  @override
  String get playlistNotFoundOrError =>
      'Liste de lecture introuvable ou erreur du serveur';

  @override
  String get playlistReadyShare =>
      'Votre liste de lecture est prête à être partagée !';

  @override
  String get playlists => 'Playlists';

  @override
  String get plays => 'lectures';

  @override
  String get popularOnSpotify => 'Populaire sur Spotify';

  @override
  String get portuguese => 'Portugais';

  @override
  String get preferAppleMusic => 'Préférer Apple Music';

  @override
  String get preferSpotify => 'Préférer Spotify';

  @override
  String get preferredOutputFormat =>
      'Format de sortie préféré pour les téléchargements';

  @override
  String get premiumMemberDesc =>
      'Vous avez des téléchargements ALAC illimités et un accès à la file d\'attente prioritaire !';

  @override
  String get premiumMemberTitle => 'Membre Premium';

  @override
  String get preparingDownload => 'Préparation du téléchargement';

  @override
  String preparingDownloadFormat(String format) {
    return 'Préparation du téléchargement ($format)...';
  }

  @override
  String get preparingDownloadNotification => 'Préparation du téléchargement';

  @override
  String get presetSaved => 'Préréglage enregistré !';

  @override
  String get preview => 'APERÇU';

  @override
  String get previousTrack => 'Piste précédente';

  @override
  String get priorityVipServerQueue =>
      'File d\'attente serveur VIP prioritaire';

  @override
  String get processingOnServer => 'Traitement sur le serveur...';

  @override
  String get profileSettings => 'Paramètres du profil';

  @override
  String get profileStats => 'Statistiques du profil';

  @override
  String get progress => 'Progression';

  @override
  String get publicSharing => 'Partage public';

  @override
  String get publicSharingDesc =>
      'Toute personne disposant du code peut importer cette liste de lecture.';

  @override
  String get publicSharingDisabledDesc =>
      'Désactivé. Activez-le pour partager avec d\'autres.';

  @override
  String get queueIsEmpty => 'La file est vide';

  @override
  String queuePositionPleaseWait(int position) {
    return 'File d\'attente $position... veuillez patienter';
  }

  @override
  String get queueTooltip => 'File d\'attente';

  @override
  String get queueUpdated => 'File d\'attente mise à jour';

  @override
  String get quickMix => 'Mix rapide';

  @override
  String get rainbowMode => 'Mode arc-en-ciel';

  @override
  String get rainyCity => 'Ville pluvieuse';

  @override
  String get rank => 'Rang';

  @override
  String rankActive(int rank) {
    return 'Rang $rank (Actif)';
  }

  @override
  String rankLabel(int rank) {
    return 'RANG $rank';
  }

  @override
  String get reBuffering => 'Mise en mémoire tampon...';

  @override
  String reachDailyPlaysTooltip(int count) {
    return 'Atteignez $count lectures en une journée';
  }

  @override
  String reachSpecificArtistTooltip(String minutes) {
    return 'Atteignez $minutes minutes avec un artiste spécifique';
  }

  @override
  String reachWeeklyPlaysTooltip(int count) {
    return 'Atteignez $count lectures en une semaine';
  }

  @override
  String get readySearchSong => 'Prêt. Cherchez une chanson.';

  @override
  String get rebufferingFromCloud =>
      'Re-mise en mémoire tampon depuis le nuage...';

  @override
  String get recentlyPlayed => 'Écoutés récemment';

  @override
  String recommendationsCount(int count) {
    return 'Recommandations ($count)';
  }

  @override
  String get recommendationsSection => 'Recommandations';

  @override
  String get rediscover => 'Redécouvrir';

  @override
  String get refreshLabel => 'Actualiser';

  @override
  String get refreshLibrary => 'Actualiser la bibliothèque';

  @override
  String get refreshList => 'Actualiser la liste';

  @override
  String get refreshLyricsTooltip => 'Actualiser les paroles';

  @override
  String get registeredLinkedTier => 'Inscrit (Lié)';

  @override
  String get removeAvatar => 'Supprimer l\'avatar actuel';

  @override
  String get removeFromPlaylist => 'Retirer de la playlist';

  @override
  String get removeLine => 'Supprimer la ligne';

  @override
  String removedFolder(Object folder) {
    return 'Dossier retiré : $folder';
  }

  @override
  String get rename => 'Renommer';

  @override
  String get renamePlaylist => 'Renommer la playlist';

  @override
  String get repeats => 'répétitions';

  @override
  String get reportTrouble => 'Signaler un problème';

  @override
  String get requiresAndroid14 => 'Nécessite Android 14+ et un USB DAC';

  @override
  String get resamplingLabel => 'Rééchantillonnage';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get resetDataUsage => 'Réinitialiser l\'utilisation des données';

  @override
  String get resetDataUsageContent =>
      'Êtes-vous sûr de vouloir réinitialiser l\'utilisation des données ? Cela n\'affecte pas la musique téléchargée.';

  @override
  String get resetEverything => 'Réinitialiser tout';

  @override
  String get resetLibraryContent =>
      'Cela retirera le dossier actuel du lecteur. Vos fichiers ne seront pas supprimés.';

  @override
  String get resetLibraryPath => 'Réinitialiser le chemin de la bibliothèque';

  @override
  String get resetLibraryTitle => 'Réinitialiser la bibliothèque ?';

  @override
  String get resetPath => 'Réinitialiser le chemin';

  @override
  String get resetStatistics => 'Réinitialiser les statistiques';

  @override
  String get resetStatsContent =>
      'Cette action est irréversible.\\nTous les comptes de lecture et temps d\'écoute seront définitivement perdus.';

  @override
  String get resetStatsTitle => 'Réinitialiser les statistiques ?';

  @override
  String get resetToAutomatic => 'RÉINITIALISER EN AUTOMATIQUE';

  @override
  String get resetToDefault => 'Réinitialiser par défaut';

  @override
  String get resetUsage => 'Réinitialiser l\'utilisation';

  @override
  String get resetsIn => 'RÉINITIALISATION DANS';

  @override
  String get restartContent =>
      'Un redémarrage de l\'application est requis pour appliquer les changements du périphérique audio.\\n\\nRedémarrer maintenant ?';

  @override
  String get restartNow => 'Redémarrer maintenant';

  @override
  String get restartRequired => 'Redémarrage requis';

  @override
  String get restoring => 'Restauration';

  @override
  String get retryConnection => 'Réessayer la connexion';

  @override
  String get revert => 'Rétablir';

  @override
  String get romajiHint => 'Romaji / Translittération (Optionnel)...';

  @override
  String get russian => 'Russe';

  @override
  String get sakura => 'Sakura';

  @override
  String get sampleRateLabel => 'Taux d\'échantillonnage';

  @override
  String get samplingRateLabel => 'Taux d\'échantillonnage';

  @override
  String get save => 'Enregistrer';

  @override
  String get saveAsNewPreset => 'Enregistrer comme nouveau préréglage';

  @override
  String get saveChangesToFile =>
      'Enregistrer les modifications dans le fichier';

  @override
  String get saveLabel => 'Enregistrer';

  @override
  String get saveLocallyBtn => 'Enregistrer localement';

  @override
  String get saveLrcPrompt =>
      'Voulez-vous enregistrer les paroles comme fichier .lrc à côté de l\'audio ?';

  @override
  String get saveLyricsTitle => 'Enregistrer les paroles';

  @override
  String get saveLyricsTooltip => 'Enregistrer les paroles';

  @override
  String get savePlaylistContent =>
      'Cela créera une nouvelle playlist basée sur ces chansons.';

  @override
  String savePlaylistTitle(String title) {
    return 'Enregistrer \"$title\" ?';
  }

  @override
  String get savePreset => 'Enregistrer le préréglage';

  @override
  String savedAs(String name) {
    return 'Enregistré sous \"$name\" !';
  }

  @override
  String savedAsFormat(String format) {
    return 'Enregistré sous $format';
  }

  @override
  String savedSuccessfully(String extension) {
    return 'Enregistré avec succès dans le fichier $extension !';
  }

  @override
  String savedTo(String path) {
    return 'Enregistré dans \"$path\"';
  }

  @override
  String get saving => 'Enregistrement...';

  @override
  String get scan => 'Scanner';

  @override
  String get scanToControlPlayback =>
      'Scannez pour contrôler la lecture avec votre téléphone.';

  @override
  String get scanning => 'Scan en cours...';

  @override
  String get scrollForLyrics => 'Faire défiler pour les paroles';

  @override
  String get search => 'Rechercher';

  @override
  String get searchEngine => 'Moteur de recherche';

  @override
  String searchFailedStatus(String error) {
    return 'Échec de la recherche : $error';
  }

  @override
  String get searchHint => 'Chercher...';

  @override
  String get searchSongs => 'Chercher des chansons...';

  @override
  String get searchSongsOrAlbumsAndArtistsHint =>
      'Chercher des chansons, albums ou artistes...';

  @override
  String get searchSpotify => 'Chercher sur Spotify';

  @override
  String get searchSpotifyHint => 'Chercher sur Spotify...';

  @override
  String get searchUsers => 'Rechercher des utilisateurs...';

  @override
  String get searchYoutubeHint => 'Chercher sur YouTube...';

  @override
  String get searching => 'Recherche en cours...';

  @override
  String searchingEngine(String engine, String keyword) {
    return 'Recherche sur $engine pour \'$keyword\'...';
  }

  @override
  String get searchingSpotify => 'Recherche sur Spotify...';

  @override
  String searchingSpotifyFor(String keyword) {
    return 'Recherche de \"$keyword\" sur Spotify...';
  }

  @override
  String get searchingStatus => 'Recherche';

  @override
  String get secondShort => 's';

  @override
  String get secsShort => 'S';

  @override
  String get seeAll => 'Voir tout';

  @override
  String get seeBenefitsBtn => 'Voir les avantages';

  @override
  String get seePremiumBenefits => 'Voir les avantages Premium';

  @override
  String get selectDifferentFolder => 'Sélectionner un autre dossier';

  @override
  String get selectFolder => 'Sélectionner un dossier';

  @override
  String get selectMatch => 'Sélectionner correspondance';

  @override
  String get selectSongToEdit =>
      'Sélectionnez une chanson dans la liste pour l\'éditer';

  @override
  String get selectStreamingQuality => 'Sélectionner la qualité du streaming';

  @override
  String get selectTrackToStart => 'Sélectionnez une piste pour démarrer';

  @override
  String get selectVersion => 'Sélectionner la version';

  @override
  String session(String id) {
    return 'Session : $id';
  }

  @override
  String get setCountryReleases =>
      'Définir le pays pour les nouveautés et les classements';

  @override
  String get setCustomTimer => 'Définir un minuteur personnalisé';

  @override
  String get setEndTooltip => 'Régler la fin sur la position actuelle';

  @override
  String get setStartTooltip => 'Régler le début sur la position actuelle';

  @override
  String get settings => 'Paramètres';

  @override
  String get share => 'Partager';

  @override
  String get shareCodeUsage =>
      'Donnez ce code à 6 chiffres à un ami pour qu\'il puisse importer cette liste de lecture.';

  @override
  String get sharePlaylist => 'Partager la liste de lecture';

  @override
  String sharePlaylistTitle(String name) {
    return 'Partager \"$name\"';
  }

  @override
  String get sharedMode => 'Partagé';

  @override
  String showAllTitles(int count) {
    return 'Afficher tous les $count titres';
  }

  @override
  String get showAnimatedWaves =>
      'Afficher des ondes animées dans la barre de lecture';

  @override
  String get showDebugButton => 'Afficher le bouton de débogage flottant';

  @override
  String get showInFolder => 'Afficher dans le dossier';

  @override
  String get showLess => 'Voir moins';

  @override
  String get showMore => 'Voir plus';

  @override
  String get showStatusDiscord => 'Afficher le statut sur Discord';

  @override
  String get showUnlockedOnly => 'Afficher uniquement les débloqués';

  @override
  String get shuffle => 'Mélanger';

  @override
  String get shuffleAll => 'Tout mélanger';

  @override
  String shufflingArtist(String artistName) {
    return 'Mélange des chansons de $artistName...';
  }

  @override
  String get signInWithGoogle => 'Se connecter avec Google';

  @override
  String get signalOutput => 'Sortie du signal';

  @override
  String get singleTracks => 'Pistes uniques';

  @override
  String get sleepTimer => 'Minuteur de veille';

  @override
  String get songAlreadyInPlaylist => 'Chanson déjà dans la playlist';

  @override
  String get songInformation => 'Informations sur la chanson';

  @override
  String get songLabelUpper => 'CHANSON';

  @override
  String get songQueueTitle => 'File d\'attente des chansons';

  @override
  String get songTitleKeyword => 'Titre ou mot-clé';

  @override
  String get songs => 'chansons';

  @override
  String songsCount(int count) {
    return '$count chansons';
  }

  @override
  String songsInLibrary(int count) {
    return '$count chansons dans la bibliothèque';
  }

  @override
  String songsLoadedCount(int count) {
    return '$count chansons chargées...';
  }

  @override
  String get southKorea => 'Corée du Sud';

  @override
  String get spanish => 'Espagnol';

  @override
  String get spectrumBars => 'Barres de spectre';

  @override
  String get spotify => 'Spotify';

  @override
  String get standardDesc =>
      'MP3 - Fichier plus petit, mise en mémoire tampon plus rapide';

  @override
  String get standardDownloadQueue =>
      'File d\'attente de téléchargement standard';

  @override
  String get standardQuality => 'Standard (MP3)';

  @override
  String get start => 'Démarrer';

  @override
  String get startBulkProcess => 'Démarrer processus en masse';

  @override
  String get startLabel => 'Début : ';

  @override
  String get startedDownloadingAll =>
      'Téléchargement de toutes les chansons commencé...';

  @override
  String get stateDisabled => 'Désactivé';

  @override
  String get stateEnabled => 'Activé';

  @override
  String get statisticsReset => 'Statistiques réinitialisées.';

  @override
  String get stats => 'Stats';

  @override
  String get statusLabel => 'Statut';

  @override
  String statusWithText(String status) {
    return 'Statut : $status';
  }

  @override
  String stopTimer(String time) {
    return 'Arrêter le minuteur ($time)';
  }

  @override
  String get streaming => 'Streaming';

  @override
  String get streamingQuality => 'Qualité du streaming';

  @override
  String get success => 'Succès';

  @override
  String get superfanHeader => 'SUCCÈS DE SUPERFAN';

  @override
  String get superfanTitles => 'SUPERFAN';

  @override
  String get supportDeveloperTooltip =>
      'Soutenez le développeur pour obtenir un titre exclusif';

  @override
  String get switchToGridView => 'Passer en vue grille';

  @override
  String get switchToListView => 'Passer en vue liste';

  @override
  String switchingTo(String title) {
    return 'Changement vers';
  }

  @override
  String get syncThemeAlbumArt => 'Synchroniser le thème avec la pochette';

  @override
  String get syncedMode => 'Synchronisé';

  @override
  String get system => 'Système';

  @override
  String get systemDefault => 'Défaut système';

  @override
  String get targetLanguageLyrics =>
      'Langue cible pour la traduction des paroles';

  @override
  String get thai => 'Thaï';

  @override
  String get tidalApiStatus => 'Tidal API';

  @override
  String get timeBasedTitles => 'BASÉ SUR LE TEMPS';

  @override
  String get timeListened => 'Temps d\'écoute';

  @override
  String get timeOverlordsHeader => 'SEIGNEURS DU TEMPS';

  @override
  String timerSetForHours(int count) {
    return 'Minuteur réglé pour dans $count heures';
  }

  @override
  String timerSetForMinutes(int count) {
    return 'Minuteur réglé pour dans $count minutes';
  }

  @override
  String timerSetForSeconds(int count) {
    return 'Minuteur réglé pour dans $count secondes';
  }

  @override
  String get tintBackground =>
      'Teinter le fond et le visualiseur avec la couleur de la chanson';

  @override
  String get title => 'Titre';

  @override
  String get titleLabel => 'Titre';

  @override
  String todayLabel(String size) {
    return 'Aujourd\'hui: $size';
  }

  @override
  String get toggleDebugButton => 'Basculer la console de débogage flottante';

  @override
  String get toggleDebugConsole => 'Basculer la console de débogage flottante';

  @override
  String get toggleLyrics => 'Afficher/Masquer les Paroles';

  @override
  String top3GlobalTooltip(int weeks) {
    return 'Atteignez le Top 3 mondial pendant $weeks semaines';
  }

  @override
  String get topArtist => 'Top Artiste';

  @override
  String get topArtistAndTrack => 'Meilleur artiste et piste';

  @override
  String get topArtists => 'Top artistes';

  @override
  String topGlobalTooltip(int rank) {
    return 'Atteignez le top $rank mondial';
  }

  @override
  String get topListeners => 'Top auditeurs';

  @override
  String get totalMinutesStat => 'Total des minutes';

  @override
  String get totalPlays => 'Lectures totales';

  @override
  String get trackDetails => 'Détails de la piste';

  @override
  String get trackNumber => 'N° de piste';

  @override
  String get tracks => 'pistes';

  @override
  String get translateLabel => 'Traduire';

  @override
  String get translateLyrics => 'Traduire les paroles';

  @override
  String get translateLyricsTooltip => 'Traduire les paroles';

  @override
  String get translationLanguage => 'Langue de traduction';

  @override
  String get ttmlFormat => 'TTML (Haute précision)';

  @override
  String get ttmlFormatDesc =>
      'Mieux pour la génération par IA et la synchronisation détaillée.';

  @override
  String get turnOffTimer => 'Éteindre le minuteur';

  @override
  String get unauthorize => 'Non autorisé';

  @override
  String get underDevelopment =>
      'Cette fonctionnalité est en cours de développement';

  @override
  String get underwater => 'Sous l\'eau';

  @override
  String get unitedKingdom => 'Royaume-Uni';

  @override
  String get unitedStates => 'États-Unis';

  @override
  String get unknown => 'Inconnu';

  @override
  String get unknownArtist => 'Artiste inconnu';

  @override
  String get unknownDevice => 'Périphérique inconnu';

  @override
  String get unlimitedAlacDownloads => 'Téléchargements ALAC illimités';

  @override
  String get unlink => 'Dissocier';

  @override
  String get unlinkAccount => 'Dissocier le compte';

  @override
  String get unlinkAccountDesc =>
      'Vos statistiques resteront sur cet appareil mais ne seront plus synchronisées sur d\'autres appareils.';

  @override
  String get unlinkAccountQuestion => 'Dissocier le compte ?';

  @override
  String get unlinkFolder =>
      'Délier le dossier et effacer la liste des chansons';

  @override
  String get unlinkFolderClear =>
      'Délier le dossier et effacer la liste des chansons';

  @override
  String get unlockUnlimitedPremium => 'Débloquer Premium Illimité';

  @override
  String unlockedCountLabel(int unlocked, int total) {
    return '$unlocked / $total Débloqué';
  }

  @override
  String get unmuteTooltip => 'Rétablir le son';

  @override
  String get unsavedChanges => 'Modifications non enregistrées';

  @override
  String get upNext => 'À suivre';

  @override
  String upNextCount(int count) {
    return 'À suivre ($count)';
  }

  @override
  String get upNextSection => 'À suivre';

  @override
  String get updateAvailableTitle => 'Mise à jour disponible';

  @override
  String updateAvailableVersion(String version) {
    return 'Une nouvelle version ($version) est disponible.';
  }

  @override
  String updateFailed(String error) {
    return 'Échec de la mise à jour : $error';
  }

  @override
  String get updateNow => 'Mettre à jour maintenant';

  @override
  String get updatePrompt =>
      'Voulez-vous la télécharger et l\'installer maintenant ?';

  @override
  String get updatingYtDlp => 'Mise à jour de yt-dlp';

  @override
  String get usbAudioBypass =>
      'USB Audio Bypass (Beta) - Sortie directe DAC pour Android 13 et moins';

  @override
  String get usbAudioBypassBeta =>
      'USB Audio Bypass (Beta) - Sortie directe DAC pour Android 13 et moins';

  @override
  String get useDarkTheme => 'Utiliser le thème sombre';

  @override
  String get useMixedColors =>
      'Utiliser des couleurs mixtes (priorité à la synchro)';

  @override
  String get useSameEmailCheckStatus =>
      'Utilisez la même adresse e-mail que dans l\'application pour vérifier automatiquement le statut.';

  @override
  String usedToday(int used, int max) {
    return '$used / $max utilisés aujourd\'hui';
  }

  @override
  String get verifiedDeveloper => 'Développeur vérifié';

  @override
  String get version => 'Version';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get vietnamese => 'Vietnamien';

  @override
  String get viewQueue => 'Voir la file';

  @override
  String get visualizer => 'Visualiseur';

  @override
  String get visualizerStyle => 'Style du visualiseur';

  @override
  String get waitingForServerResponse =>
      'En attente de la réponse du serveur...';

  @override
  String get wasapiExclusive => 'Mode exclusif WASAPI';

  @override
  String get weekly => 'Hebdomadaire';

  @override
  String get weeks => 'Semaines';

  @override
  String get winter => 'Hiver';

  @override
  String get worldRanking => 'Classement mondial';

  @override
  String get worldTopArtists => 'Top Artistes Mondiaux';

  @override
  String get year => 'Année';

  @override
  String get youMayLike => 'Vous pourriez aimer';

  @override
  String get yourPlaylists => 'Vos playlists';

  @override
  String get yourTopMix => 'Votre Top Mix';

  @override
  String get youtube => 'YouTube';

  @override
  String get ytDlpUpdateAvailable =>
      'Une nouvelle version de yt-dlp est disponible.';
}
