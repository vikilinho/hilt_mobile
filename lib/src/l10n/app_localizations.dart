import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('de'),
    Locale('zh'),
  ];

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    final localization = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localization != null, 'AppLocalizations not found in context');
    return localization!;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'appTitle': 'Hilt King',
      'home': 'Home',
      'workouts': 'Workouts',
      'hydration': 'Hydration',
      'history': 'History',
      'workout': 'Workout',
      'sessions': 'Sessions',
      'walks': 'Walks',
      'noWorkoutsYet': 'No workouts yet',
      'noWalksRecorded': 'No walks recorded',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'thisWeek': 'This Week',
      'thisMonth': 'This Month',
      'older': 'Older',
      'lastWeek': 'Last Week',
      'weekOf': 'Week of',
      'total': 'Total',
      'steps': 'Steps',
      'dailySteps': 'Daily Steps',
      'totalStepsLabel': 'Total Steps',
      'workoutsLabel': 'Workouts',
      'bestGrade': 'Best Grade',
      'last': 'Last',
      'peakLabel': 'Peak',
      'inZone': 'In Zone',
      'miles': 'Miles',
      'calories': 'Calories',
      'dailyActivity': 'Daily Activity',
      'activeDays': 'Active Days',
      'avgActiveDay': 'Avg / Active Day',
      'tenKDays': '10K Days',
      'training': 'Training',
      'cycling': 'Cycling',
      'boxing': 'Boxing',
      'hydrationGarden': 'Hydration Garden',
      'growYourPlant': 'Grow your plant by logging every cup you finish today.',
      'consumed': 'Consumed',
      'remaining': 'Remaining',
      'streak': 'Streak',
      'smartReminders': 'Smart reminders',
      'nudgesEvery2Hours': 'Nudges every 2 hours',
      'smartRemindersOn': 'Smart reminders are on.',
      'smartRemindersOff': 'Smart reminders are off.',
      'notificationPermissionDenied':
          'Notification permission was not granted.',
      'exactAlarmDenied':
          'Exact alarm access was not granted, so timed reminders cannot run yet.',
      'notificationsUnavailable':
          'Android notifications are unavailable right now. Check app notification permission and try again.',
      'todaysIntake': 'Today\'s Intake',
      'deleteIntakeEntry': 'Delete intake entry',
      'firstCupWaiting': 'Your plant is waiting for its first cup today.',
      'seedling': 'Seedling',
      'seedlingSubtitle':
          'A calm start. Every sip helps new growth break through.',
      'sprouting': 'Sprouting',
      'sproutingSubtitle':
          'Your plant is waking up and reaching for more water.',
      'leafingUp': 'Leafing Up',
      'leafingUpSubtitle': 'Steady hydration is building a healthier rhythm.',
      'thriving': 'Thriving',
      'thrivingSubtitle':
          'You are close to today’s goal and the plant shows it.',
      'blooming': 'Blooming',
      'bloomingSubtitle':
          'Goal reached. Your garden is fully watered for today.',
      'coverLens': 'COVER LENS',
      'heartRate': 'HEART RATE',
      'cameraPermissionRequired': 'Camera permission required.',
      'placeFingerOverLens': 'Place finger over the camera lens and flash.',
      'heartRateReady': 'Heart rate ready',
      'flashRequired': 'Flash is required for this scan.',
      'finalizingReading': 'Finalizing your reading.',
      'repositionFingerAndTryAgain': 'Reposition finger and try again.',
      'coverLensAndFlashOn':
          'Cover the lens fully and make sure the torch is visibly on.',
      'stillNotStable':
          'Still not stable enough. Reposition your finger and try again.',
      'acquiringPulse': 'Acquiring pulse...',
      'waitingForFinger': 'Waiting for finger...',
      'selectTraining': 'Select Training',
      'cardio': 'Cardio',
      'cardioSubtitle': 'Bike, Running, Football',
      'strength': 'Strength',
      'strengthSubtitle': 'Weights, Power, Explosiveness',
      'stationaryBike': 'Stationary Bike',
      'stationaryBikeSubtitle': 'Match Sim, Box-to-Box',
      'treadmill': 'Treadmill',
      'treadmillSubtitle': 'Sprints, Intervals',
      'noEquipment': 'No-Equipment',
      'noEquipmentSubtitle': 'Squats, Lunges, Climbers',
      'barbell': 'Barbell',
      'barbellSubtitle': 'Squats, Cleans, Deadlifts',
      'dumbbell': 'Dumbbell',
      'dumbbellSubtitle': 'Squats, Lunges, Press',
      'bench': 'Bench',
      'benchSubtitle': 'Dips, Split Squats, Step-Ups',
      'comboQueue': 'Combo Queue',
      'equipment': 'Equipment',
      'none': 'None',
      'scanning': 'Scanning...',
      'start': 'Start',
      'bikeConnected': 'Bike Connected',
      'enableBluetooth': 'Enable Bluetooth',
      'grantPermissions': 'Grant Permissions',
      'connecting': 'Connecting...',
      'connectBike': 'Connect Bike',
      'stopWorkoutQuestion': 'Stop Workout?',
      'stopWorkoutPrompt': 'Do you want to stop this workout?',
      'cancel': 'Cancel',
      'stopWorkout': 'Stop Workout',
      'timeLeft': 'Time Left',
      'lapsLeft': 'Laps Left',
      'speed': 'Speed',
      'distance': 'Distance',
      'selectEquipment': 'Select Equipment',
      'endWorkoutQuestion': 'End Workout?',
      'saveSessionPrompt': 'Do you want to save this session to your history?',
      'discard': 'Discard',
      'saveAndEnd': 'Save & End',
      'startWorkout': 'Start Workout',
      'selectSession': 'Select Session',
      'stop': 'Stop',
      'logLoad': 'Log Load',
      'workoutSettings': 'Workout Settings',
      'browseWorkouts': 'Browse Workouts',
      'comboSession': 'Combo Session',
      'holdStillCapturePeakBpm': 'Hold still while we capture your Peak BPM',
      'matchReport': 'Match Report',
      'comboReport': 'Combo Report',
      'comboSequence': 'Combo Sequence',
      'peakBpm': 'Peak BPM',
      'target': 'Target',
      'done': 'Done',
      'avgBpm': 'AVG BPM',
      'zone': 'Zone',
      'duration': 'Duration',
      'comboTime': 'Combo Time',
      'cardioLoad': 'Cardio Load',
      'eliteEngine': 'Elite Engine',
      'elite': 'Elite',
      'active': 'Active',
      'warmup': 'Warmup',
      'editDistance': 'Edit Distance',
      'save': 'Save',
      'matchGrade': 'Match Grade',
      'output': 'Output',
      'milesCovered': 'Miles Covered',
      'treadmillStatsOptional': 'Treadmill Stats (Optional)',
      'incline': 'Incline',
      'volumeShort': 'Vol',
      'shareWorkoutResult': 'Check out my HILT workout session!',
      'startStrong': 'Start Strong',
      'matchFit': 'Match Fit',
      'eliteDrive': 'Elite Drive',
    },
    'fr': {
      'appTitle': 'Hilt King',
      'home': 'Accueil',
      'workouts': 'Entraînements',
      'hydration': 'Hydratation',
      'history': 'Historique',
      'workout': 'Entraînement',
      'sessions': 'Séances',
      'walks': 'Marches',
      'noWorkoutsYet': 'Aucun entraînement pour le moment',
      'noWalksRecorded': 'Aucune marche enregistrée',
      'today': 'Aujourd’hui',
      'yesterday': 'Hier',
      'thisWeek': 'Cette semaine',
      'thisMonth': 'Ce mois-ci',
      'older': 'Plus ancien',
      'lastWeek': 'Semaine dernière',
      'weekOf': 'Semaine du',
      'total': 'Total',
      'steps': 'Pas',
      'dailySteps': 'Pas quotidiens',
      'totalStepsLabel': 'Total des pas',
      'workoutsLabel': 'Entraînements',
      'bestGrade': 'Meilleure note',
      'last': 'Dernier',
      'peakLabel': 'Pic',
      'inZone': 'En zone',
      'miles': 'Miles',
      'calories': 'Calories',
      'dailyActivity': 'Activité quotidienne',
      'activeDays': 'Jours actifs',
      'avgActiveDay': 'Moy / jour actif',
      'tenKDays': 'Jours à 10K',
      'training': 'Entraînement',
      'cycling': 'Cyclisme',
      'boxing': 'Boxe',
      'hydrationGarden': 'Jardin d’hydratation',
      'growYourPlant':
          'Faites pousser votre plante en enregistrant chaque tasse bue aujourd’hui.',
      'consumed': 'Consommé',
      'remaining': 'Restant',
      'streak': 'Série',
      'smartReminders': 'Rappels intelligents',
      'nudgesEvery2Hours': 'Rappels toutes les 2 heures',
      'smartRemindersOn': 'Les rappels intelligents sont activés.',
      'smartRemindersOff': 'Les rappels intelligents sont désactivés.',
      'notificationPermissionDenied':
          'L’autorisation de notification n’a pas été accordée.',
      'exactAlarmDenied':
          'L’accès aux alarmes exactes n’a pas été accordé, les rappels programmés ne peuvent donc pas encore fonctionner.',
      'notificationsUnavailable':
          'Les notifications Android sont indisponibles pour le moment. Vérifiez l’autorisation des notifications de l’application et réessayez.',
      'todaysIntake': 'Consommation du jour',
      'deleteIntakeEntry': 'Supprimer l’entrée',
      'firstCupWaiting': 'Votre plante attend sa première tasse aujourd’hui.',
      'seedling': 'Jeune pousse',
      'seedlingSubtitle':
          'Un départ calme. Chaque gorgée aide une nouvelle croissance à éclore.',
      'sprouting': 'En germination',
      'sproutingSubtitle': 'Votre plante se réveille et demande plus d’eau.',
      'leafingUp': 'Feuillage',
      'leafingUpSubtitle':
          'Une hydratation régulière construit un rythme plus sain.',
      'thriving': 'Florissante',
      'thrivingSubtitle':
          'Vous êtes proche de l’objectif du jour et la plante le montre.',
      'blooming': 'En fleur',
      'bloomingSubtitle':
          'Objectif atteint. Votre jardin est complètement arrosé pour aujourd’hui.',
      'coverLens': 'COUVREZ L’OBJECTIF',
      'heartRate': 'FRÉQUENCE CARDIAQUE',
      'cameraPermissionRequired': 'Autorisation de la caméra requise.',
      'placeFingerOverLens': 'Placez votre doigt sur l’objectif et le flash.',
      'heartRateReady': 'Fréquence prête',
      'flashRequired': 'Le flash est requis pour ce scan.',
      'finalizingReading': 'Finalisation de la mesure.',
      'repositionFingerAndTryAgain': 'Repositionnez votre doigt et réessayez.',
      'coverLensAndFlashOn':
          'Couvrez complètement l’objectif et assurez-vous que le flash est bien allumé.',
      'stillNotStable':
          'Ce n’est toujours pas assez stable. Repositionnez votre doigt et réessayez.',
      'acquiringPulse': 'Acquisition du pouls...',
      'waitingForFinger': 'En attente du doigt...',
      'selectTraining': 'Choisir l’entraînement',
      'cardio': 'Cardio',
      'cardioSubtitle': 'Vélo, course, football',
      'strength': 'Force',
      'strengthSubtitle': 'Poids, puissance, explosivité',
      'stationaryBike': 'Vélo d’appartement',
      'stationaryBikeSubtitle': 'Simulation de match, box-to-box',
      'treadmill': 'Tapis de course',
      'treadmillSubtitle': 'Sprints, intervalles',
      'noEquipment': 'Sans équipement',
      'noEquipmentSubtitle': 'Squats, fentes, climbers',
      'barbell': 'Barre',
      'barbellSubtitle': 'Squats, épaulés, soulevés de terre',
      'dumbbell': 'Haltère',
      'dumbbellSubtitle': 'Squats, fentes, développé',
      'bench': 'Banc',
      'benchSubtitle': 'Dips, split squats, step-ups',
      'comboQueue': 'File combo',
      'equipment': 'Équipement',
      'none': 'Aucun',
      'scanning': 'Analyse...',
      'start': 'Démarrer',
      'bikeConnected': 'Vélo connecté',
      'enableBluetooth': 'Activer le Bluetooth',
      'grantPermissions': 'Accorder les autorisations',
      'connecting': 'Connexion...',
      'connectBike': 'Connecter le vélo',
      'stopWorkoutQuestion': 'Arrêter l’entraînement ?',
      'stopWorkoutPrompt': 'Voulez-vous arrêter cet entraînement ?',
      'cancel': 'Annuler',
      'stopWorkout': 'Arrêter l’entraînement',
      'timeLeft': 'Temps restant',
      'lapsLeft': 'Tours restants',
      'speed': 'Vitesse',
      'distance': 'Distance',
      'selectEquipment': 'Choisir l’équipement',
      'endWorkoutQuestion': 'Terminer l’entraînement ?',
      'saveSessionPrompt':
          'Voulez-vous enregistrer cette séance dans votre historique ?',
      'discard': 'Ignorer',
      'saveAndEnd': 'Enregistrer et terminer',
      'startWorkout': 'Commencer l’entraînement',
      'selectSession': 'Choisir la séance',
      'stop': 'Arrêter',
      'logLoad': 'Noter la charge',
      'workoutSettings': 'Paramètres d’entraînement',
      'browseWorkouts': 'Parcourir les entraînements',
      'comboSession': 'Séance combo',
      'holdStillCapturePeakBpm':
          'Restez immobile pendant que nous capturons votre BPM maximal',
      'matchReport': 'Rapport de match',
      'comboReport': 'Rapport combo',
      'comboSequence': 'Séquence combo',
      'peakBpm': 'BPM max',
      'target': 'Cible',
      'done': 'Terminé',
      'avgBpm': 'BPM MOY',
      'zone': 'Zone',
      'duration': 'Durée',
      'comboTime': 'Temps combo',
      'cardioLoad': 'Charge cardio',
      'eliteEngine': 'Moteur élite',
      'elite': 'Élite',
      'active': 'Actif',
      'warmup': 'Échauffement',
      'editDistance': 'Modifier la distance',
      'save': 'Enregistrer',
      'matchGrade': 'Note du match',
      'output': 'Production',
      'milesCovered': 'Miles parcourus',
      'treadmillStatsOptional': 'Statistiques tapis (optionnel)',
      'incline': 'Inclinaison',
      'volumeShort': 'Vol',
      'shareWorkoutResult': 'Découvrez ma séance HILT !',
      'startStrong': 'Bien démarrer',
      'matchFit': 'En forme',
      'eliteDrive': 'Élan élite',
    },
    'de': {
      'appTitle': 'Hilt King',
      'home': 'Start',
      'workouts': 'Workouts',
      'hydration': 'Hydration',
      'history': 'Verlauf',
      'workout': 'Workout',
      'sessions': 'Sitzungen',
      'walks': 'Spaziergänge',
      'noWorkoutsYet': 'Noch keine Workouts',
      'noWalksRecorded': 'Keine Spaziergänge aufgezeichnet',
      'today': 'Heute',
      'yesterday': 'Gestern',
      'thisWeek': 'Diese Woche',
      'thisMonth': 'Diesen Monat',
      'older': 'Älter',
      'lastWeek': 'Letzte Woche',
      'weekOf': 'Woche vom',
      'total': 'Gesamt',
      'steps': 'Schritte',
      'dailySteps': 'Tägliche Schritte',
      'totalStepsLabel': 'Schritte gesamt',
      'workoutsLabel': 'Workouts',
      'bestGrade': 'Beste Note',
      'last': 'Zuletzt',
      'peakLabel': 'Spitze',
      'inZone': 'In Zone',
      'miles': 'Meilen',
      'calories': 'Kalorien',
      'dailyActivity': 'Tagesaktivität',
      'activeDays': 'Aktive Tage',
      'avgActiveDay': 'Ø / aktiver Tag',
      'tenKDays': '10K-Tage',
      'training': 'Training',
      'cycling': 'Radfahren',
      'boxing': 'Boxen',
      'hydrationGarden': 'Hydration Garden',
      'growYourPlant':
          'Lass deine Pflanze wachsen, indem du heute jede getrunkene Tasse protokollierst.',
      'consumed': 'Getrunken',
      'remaining': 'Verbleibend',
      'streak': 'Serie',
      'smartReminders': 'Intelligente Erinnerungen',
      'nudgesEvery2Hours': 'Erinnerungen alle 2 Stunden',
      'smartRemindersOn': 'Intelligente Erinnerungen sind aktiviert.',
      'smartRemindersOff': 'Intelligente Erinnerungen sind deaktiviert.',
      'notificationPermissionDenied':
          'Benachrichtigungsberechtigung wurde nicht erteilt.',
      'exactAlarmDenied':
          'Der Zugriff auf exakte Alarme wurde nicht gewährt, daher können zeitgesteuerte Erinnerungen noch nicht ausgeführt werden.',
      'notificationsUnavailable':
          'Android-Benachrichtigungen sind derzeit nicht verfügbar. Prüfe die Benachrichtigungsberechtigung der App und versuche es erneut.',
      'todaysIntake': 'Heutige Aufnahme',
      'deleteIntakeEntry': 'Eintrag löschen',
      'firstCupWaiting': 'Deine Pflanze wartet heute auf ihre erste Tasse.',
      'seedling': 'Keimling',
      'seedlingSubtitle':
          'Ein ruhiger Start. Jeder Schluck hilft neuem Wachstum.',
      'sprouting': 'Am Sprießen',
      'sproutingSubtitle':
          'Deine Pflanze erwacht und verlangt nach mehr Wasser.',
      'leafingUp': 'Blätter wachsen',
      'leafingUpSubtitle':
          'Stetige Hydration baut einen gesünderen Rhythmus auf.',
      'thriving': 'Gedeihend',
      'thrivingSubtitle':
          'Du bist nahe am heutigen Ziel und die Pflanze zeigt es.',
      'blooming': 'Blühend',
      'bloomingSubtitle':
          'Ziel erreicht. Dein Garten ist für heute vollständig bewässert.',
      'coverLens': 'LINSE BEDECKEN',
      'heartRate': 'HERZFREQUENZ',
      'cameraPermissionRequired': 'Kameraberechtigung erforderlich.',
      'placeFingerOverLens':
          'Lege deinen Finger über Kameraobjektiv und Blitz.',
      'heartRateReady': 'Herzfrequenz bereit',
      'flashRequired': 'Für diesen Scan ist der Blitz erforderlich.',
      'finalizingReading': 'Messung wird abgeschlossen.',
      'repositionFingerAndTryAgain':
          'Finger neu positionieren und erneut versuchen.',
      'coverLensAndFlashOn':
          'Bedecke die Linse vollständig und stelle sicher, dass der Blitz sichtbar eingeschaltet ist.',
      'stillNotStable':
          'Noch nicht stabil genug. Finger neu positionieren und erneut versuchen.',
      'acquiringPulse': 'Puls wird erfasst...',
      'waitingForFinger': 'Warte auf Finger...',
      'selectTraining': 'Training auswählen',
      'cardio': 'Cardio',
      'cardioSubtitle': 'Rad, Laufen, Fußball',
      'strength': 'Kraft',
      'strengthSubtitle': 'Gewichte, Kraft, Explosivität',
      'stationaryBike': 'Heimtrainer',
      'stationaryBikeSubtitle': 'Match-Simulation, Box-to-Box',
      'treadmill': 'Laufband',
      'treadmillSubtitle': 'Sprints, Intervalle',
      'noEquipment': 'Ohne Geräte',
      'noEquipmentSubtitle': 'Kniebeugen, Ausfallschritte, Climbers',
      'barbell': 'Langhantel',
      'barbellSubtitle': 'Kniebeugen, Cleans, Kreuzheben',
      'dumbbell': 'Kurzhantel',
      'dumbbellSubtitle': 'Kniebeugen, Ausfallschritte, Drücken',
      'bench': 'Bank',
      'benchSubtitle': 'Dips, Split Squats, Step-Ups',
      'comboQueue': 'Combo-Warteschlange',
      'equipment': 'Ausrüstung',
      'none': 'Keine',
      'scanning': 'Suche...',
      'start': 'Start',
      'bikeConnected': 'Fahrrad verbunden',
      'enableBluetooth': 'Bluetooth aktivieren',
      'grantPermissions': 'Berechtigungen erteilen',
      'connecting': 'Verbinden...',
      'connectBike': 'Fahrrad verbinden',
      'stopWorkoutQuestion': 'Workout stoppen?',
      'stopWorkoutPrompt': 'Möchtest du dieses Workout stoppen?',
      'cancel': 'Abbrechen',
      'stopWorkout': 'Workout stoppen',
      'timeLeft': 'Verbleibende Zeit',
      'lapsLeft': 'Verbleibende Runden',
      'speed': 'Geschwindigkeit',
      'distance': 'Distanz',
      'selectEquipment': 'Ausrüstung wählen',
      'endWorkoutQuestion': 'Workout beenden?',
      'saveSessionPrompt':
          'Möchtest du diese Sitzung in deinem Verlauf speichern?',
      'discard': 'Verwerfen',
      'saveAndEnd': 'Speichern & beenden',
      'startWorkout': 'Workout starten',
      'selectSession': 'Sitzung auswählen',
      'stop': 'Stopp',
      'logLoad': 'Last erfassen',
      'workoutSettings': 'Workout-Einstellungen',
      'browseWorkouts': 'Workouts durchsuchen',
      'comboSession': 'Combo-Sitzung',
      'holdStillCapturePeakBpm':
          'Halte still, während wir deine Spitzen-BPM erfassen',
      'matchReport': 'Match-Bericht',
      'comboReport': 'Combo-Bericht',
      'comboSequence': 'Combo-Sequenz',
      'peakBpm': 'SPITZEN-BPM',
      'target': 'Ziel',
      'done': 'Fertig',
      'avgBpm': 'Ø BPM',
      'zone': 'Zone',
      'duration': 'Dauer',
      'comboTime': 'Combo-Zeit',
      'cardioLoad': 'Cardio-Belastung',
      'eliteEngine': 'Elite-Engine',
      'elite': 'Elite',
      'active': 'Aktiv',
      'warmup': 'Aufwärmen',
      'editDistance': 'Distanz bearbeiten',
      'save': 'Speichern',
      'matchGrade': 'Match-Note',
      'output': 'Leistung',
      'milesCovered': 'Zurückgelegte Meilen',
      'treadmillStatsOptional': 'Laufband-Statistiken (optional)',
      'incline': 'Steigung',
      'volumeShort': 'Vol',
      'shareWorkoutResult': 'Schau dir meine HILT-Trainingseinheit an!',
      'startStrong': 'Stark starten',
      'matchFit': 'Match-fit',
      'eliteDrive': 'Elite-Antrieb',
    },
    'zh': {
      'appTitle': 'Hilt King',
      'home': '首页',
      'workouts': '训练',
      'hydration': '补水',
      'history': '历史',
      'workout': '训练',
      'sessions': '记录',
      'walks': '步行',
      'noWorkoutsYet': '还没有训练记录',
      'noWalksRecorded': '还没有步行记录',
      'today': '今天',
      'yesterday': '昨天',
      'thisWeek': '本周',
      'thisMonth': '本月',
      'older': '更早',
      'lastWeek': '上周',
      'weekOf': '这一周',
      'total': '总计',
      'steps': '步数',
      'dailySteps': '每日步数',
      'totalStepsLabel': '总步数',
      'workoutsLabel': '训练',
      'bestGrade': '最佳评级',
      'last': '最近',
      'peakLabel': '峰值',
      'inZone': '区间内',
      'miles': '英里',
      'calories': '卡路里',
      'dailyActivity': '每日活动',
      'activeDays': '活跃天数',
      'avgActiveDay': '活跃日均值',
      'tenKDays': '1万步天数',
      'training': '训练',
      'cycling': '骑行',
      'boxing': '拳击',
      'hydrationGarden': '补水花园',
      'growYourPlant': '记录今天喝下的每一杯水，让你的植物成长。',
      'consumed': '已饮用',
      'remaining': '剩余',
      'streak': '连续天数',
      'smartReminders': '智能提醒',
      'nudgesEvery2Hours': '每 2 小时提醒一次',
      'smartRemindersOn': '智能提醒已开启。',
      'smartRemindersOff': '智能提醒已关闭。',
      'notificationPermissionDenied': '未授予通知权限。',
      'exactAlarmDenied': '未授予定时闹钟权限，因此定时提醒暂时无法运行。',
      'notificationsUnavailable': 'Android 通知当前不可用。请检查应用通知权限后重试。',
      'todaysIntake': '今日摄入',
      'deleteIntakeEntry': '删除饮水记录',
      'firstCupWaiting': '你的植物正在等待今天的第一杯水。',
      'seedling': '幼苗',
      'seedlingSubtitle': '平静地开始。每一口水都能带来新的生长。',
      'sprouting': '发芽中',
      'sproutingSubtitle': '你的植物正在苏醒，渴望更多水分。',
      'leafingUp': '长叶中',
      'leafingUpSubtitle': '稳定补水正在建立更健康的节奏。',
      'thriving': '茁壮成长',
      'thrivingSubtitle': '你已接近今日目标，植物已经显现出来了。',
      'blooming': '盛开',
      'bloomingSubtitle': '目标达成。你的花园今天已经浇灌完成。',
      'coverLens': '遮住镜头',
      'heartRate': '心率',
      'cameraPermissionRequired': '需要相机权限。',
      'placeFingerOverLens': '请用手指盖住摄像头镜头和闪光灯。',
      'heartRateReady': '心率已就绪',
      'flashRequired': '此次扫描需要闪光灯。',
      'finalizingReading': '正在完成读数。',
      'repositionFingerAndTryAgain': '请重新放置手指后重试。',
      'coverLensAndFlashOn': '请完全遮住镜头，并确保闪光灯已开启。',
      'stillNotStable': '仍然不够稳定。请重新放置手指后重试。',
      'acquiringPulse': '正在采集脉搏...',
      'waitingForFinger': '等待手指放置...',
      'selectTraining': '选择训练',
      'cardio': '有氧',
      'cardioSubtitle': '单车、跑步、足球',
      'strength': '力量',
      'strengthSubtitle': '重量、力量、爆发力',
      'stationaryBike': '动感单车',
      'stationaryBikeSubtitle': '比赛模拟、全场往返',
      'treadmill': '跑步机',
      'treadmillSubtitle': '冲刺、间歇',
      'noEquipment': '无器械',
      'noEquipmentSubtitle': '深蹲、弓步、登山跑',
      'barbell': '杠铃',
      'barbellSubtitle': '深蹲、翻举、硬拉',
      'dumbbell': '哑铃',
      'dumbbellSubtitle': '深蹲、弓步、推举',
      'bench': '长凳',
      'benchSubtitle': '双杠臂屈伸、分腿蹲、踏步',
      'comboQueue': '组合队列',
      'equipment': '器械',
      'none': '无',
      'scanning': '扫描中...',
      'start': '开始',
      'bikeConnected': '单车已连接',
      'enableBluetooth': '开启蓝牙',
      'grantPermissions': '授予权限',
      'connecting': '连接中...',
      'connectBike': '连接单车',
      'stopWorkoutQuestion': '停止训练？',
      'stopWorkoutPrompt': '你想停止本次训练吗？',
      'cancel': '取消',
      'stopWorkout': '停止训练',
      'timeLeft': '剩余时间',
      'lapsLeft': '剩余圈数',
      'speed': '速度',
      'distance': '距离',
      'selectEquipment': '选择器械',
      'endWorkoutQuestion': '结束训练？',
      'saveSessionPrompt': '你想将本次训练保存到历史记录吗？',
      'discard': '丢弃',
      'saveAndEnd': '保存并结束',
      'startWorkout': '开始训练',
      'selectSession': '选择课程',
      'stop': '停止',
      'logLoad': '记录负重',
      'workoutSettings': '训练设置',
      'browseWorkouts': '浏览训练',
      'comboSession': '组合训练',
      'holdStillCapturePeakBpm': '请保持静止，我们正在采集你的峰值 BPM',
      'matchReport': '训练报告',
      'comboReport': '组合报告',
      'comboSequence': '组合顺序',
      'peakBpm': '峰值 BPM',
      'target': '目标',
      'done': '完成',
      'avgBpm': '平均 BPM',
      'zone': '区间',
      'duration': '时长',
      'comboTime': '组合时长',
      'cardioLoad': '有氧负荷',
      'eliteEngine': '精英引擎',
      'elite': '精英',
      'active': '活跃',
      'warmup': '热身',
      'editDistance': '编辑距离',
      'save': '保存',
      'matchGrade': '训练评级',
      'output': '输出',
      'milesCovered': '完成英里数',
      'treadmillStatsOptional': '跑步机数据（可选）',
      'incline': '坡度',
      'volumeShort': '训练量',
      'shareWorkoutResult': '看看我的 HILT 训练成绩！',
      'startStrong': '强势开始',
      'matchFit': '比赛状态',
      'eliteDrive': '精英驱动',
    },
  };

  static const Map<String, Map<String, String>> _contentStrings = {
    'fr': {
      'Match Engine': 'Moteur de match',
      'Steady State': 'Rythme régulier',
      'Tempo Pitch': 'Tempo terrain',
      'Tempo Run': 'Course tempo',
      'Blitz Finish': 'Final éclair',
      'Max Effort': 'Effort maximal',
      'Clean Press (5m)': 'Épaulé-poussé (5 min)',
      'Clean Press': 'Épaulé-poussé',
      'Explosive Power (15m)': 'Puissance explosive (15 min)',
      'Strength Engine (30m)': 'Moteur de force (30 min)',
      'The Iron 90 (45m)': 'L’Iron 90 (45 min)',
      'Barbell Back Squat': 'Back squat à la barre',
      'Barbell Push Press': 'Push press à la barre',
      'Barbell Deadlift': 'Soulevé de terre à la barre',
      'Power Clean': 'Power clean',
      'Dumbbell Goblet Squat': 'Goblet squat avec haltère',
      'Dumbbell Lunges': 'Fentes avec haltères',
      'Dumbbell Overhead Press': 'Développé militaire avec haltères',
      'Dumbbell Romanian Deadlift': 'Soulevé de terre roumain avec haltères',
      'Bench Dips': 'Dips sur banc',
      'Bulgarian Split Squats': 'Split squats bulgares',
      'Bench Step-Ups': 'Montées sur banc',
      'Bench Leg Raises': 'Relevés de jambes sur banc',
      'Air Squats': 'Squats au poids du corps',
      'Walking Lunges': 'Fentes marchées',
      'Burpees': 'Burpees',
      'Mountain Climbers': 'Mountain climbers',
      'Impact Sub (10m)': 'Super remplaçant (10 min)',
      'Impact Sub': 'Super remplaçant',
      'Warmup (5m)': 'Échauffement (5 min)',
      'Warmup': 'Échauffement',
      'Box-to-Box (20m)': 'Box-to-box (20 min)',
      'Box-to-Box': 'Box-to-box',
      'Match Sim (45m)': 'Simulation de match (45 min)',
      'First Half': 'Première mi-temps',
      'Half Time': 'Mi-temps',
      'Second Half': 'Deuxième mi-temps',
      'Pre-Season (60m)': 'Pré-saison (60 min)',
      'Block 1 (Long)': 'Bloc 1 (long)',
      'Block 2 (Short)': 'Bloc 2 (court)',
      'Block 3 (Long)': 'Bloc 3 (long)',
      'Block 4 (Short)': 'Bloc 4 (court)',
      'Block 5 (Long)': 'Bloc 5 (long)',
      'Block 6 (Short)': 'Bloc 6 (court)',
    },
    'de': {
      'Match Engine': 'Match-Motor',
      'Steady State': 'Gleichmäßiges Tempo',
      'Tempo Pitch': 'Tempo-Platz',
      'Tempo Run': 'Tempolauf',
      'Blitz Finish': 'Blitz-Finish',
      'Max Effort': 'Maximale Belastung',
      'Clean Press (5m)': 'Clean Press (5 Min.)',
      'Clean Press': 'Clean Press',
      'Explosive Power (15m)': 'Explosive Kraft (15 Min.)',
      'Strength Engine (30m)': 'Kraft-Motor (30 Min.)',
      'The Iron 90 (45m)': 'The Iron 90 (45 Min.)',
      'Barbell Back Squat': 'Langhantel-Kniebeuge',
      'Barbell Push Press': 'Langhantel-Push-Press',
      'Barbell Deadlift': 'Langhantel-Kreuzheben',
      'Power Clean': 'Power Clean',
      'Dumbbell Goblet Squat': 'Goblet Squat mit Kurzhantel',
      'Dumbbell Lunges': 'Ausfallschritte mit Kurzhanteln',
      'Dumbbell Overhead Press': 'Überkopfdrücken mit Kurzhanteln',
      'Dumbbell Romanian Deadlift': 'Rumänisches Kreuzheben mit Kurzhanteln',
      'Bench Dips': 'Bank-Dips',
      'Bulgarian Split Squats': 'Bulgarische Split Squats',
      'Bench Step-Ups': 'Step-Ups auf der Bank',
      'Bench Leg Raises': 'Beinheben auf der Bank',
      'Air Squats': 'Kniebeugen ohne Gewicht',
      'Walking Lunges': 'Gehende Ausfallschritte',
      'Burpees': 'Burpees',
      'Mountain Climbers': 'Mountain Climbers',
      'Impact Sub (10m)': 'Joker-Einsatz (10 Min.)',
      'Impact Sub': 'Joker-Einsatz',
      'Warmup (5m)': 'Aufwärmen (5 Min.)',
      'Warmup': 'Aufwärmen',
      'Box-to-Box (20m)': 'Box-to-Box (20 Min.)',
      'Box-to-Box': 'Box-to-Box',
      'Match Sim (45m)': 'Match-Simulation (45 Min.)',
      'First Half': 'Erste Halbzeit',
      'Half Time': 'Halbzeit',
      'Second Half': 'Zweite Halbzeit',
      'Pre-Season (60m)': 'Vorbereitung (60 Min.)',
      'Block 1 (Long)': 'Block 1 (lang)',
      'Block 2 (Short)': 'Block 2 (kurz)',
      'Block 3 (Long)': 'Block 3 (lang)',
      'Block 4 (Short)': 'Block 4 (kurz)',
      'Block 5 (Long)': 'Block 5 (lang)',
      'Block 6 (Short)': 'Block 6 (kurz)',
    },
    'zh': {
      'Match Engine': '比赛引擎',
      'Steady State': '稳定节奏',
      'Tempo Pitch': '节奏球场',
      'Tempo Run': '节奏跑',
      'Blitz Finish': '冲刺收尾',
      'Max Effort': '最大强度',
      'Clean Press (5m)': '翻举推举（5分钟）',
      'Clean Press': '翻举推举',
      'Explosive Power (15m)': '爆发力（15分钟）',
      'Strength Engine (30m)': '力量引擎（30分钟）',
      'The Iron 90 (45m)': '钢铁90（45分钟）',
      'Barbell Back Squat': '杠铃背蹲',
      'Barbell Push Press': '杠铃推举',
      'Barbell Deadlift': '杠铃硬拉',
      'Power Clean': '高翻',
      'Dumbbell Goblet Squat': '哑铃高脚杯深蹲',
      'Dumbbell Lunges': '哑铃弓步',
      'Dumbbell Overhead Press': '哑铃过顶推举',
      'Dumbbell Romanian Deadlift': '哑铃罗马尼亚硬拉',
      'Bench Dips': '凳上臂屈伸',
      'Bulgarian Split Squats': '保加利亚分腿蹲',
      'Bench Step-Ups': '凳上踏步',
      'Bench Leg Raises': '凳上抬腿',
      'Air Squats': '徒手深蹲',
      'Walking Lunges': '行走弓步',
      'Burpees': '波比跳',
      'Mountain Climbers': '登山跑',
      'Impact Sub (10m)': '超级替补（10分钟）',
      'Impact Sub': '超级替补',
      'Warmup (5m)': '热身（5分钟）',
      'Warmup': '热身',
      'Box-to-Box (20m)': '全场往返（20分钟）',
      'Box-to-Box': '全场往返',
      'Match Sim (45m)': '比赛模拟（45分钟）',
      'First Half': '上半场',
      'Half Time': '中场休息',
      'Second Half': '下半场',
      'Pre-Season (60m)': '季前训练（60分钟）',
      'Block 1 (Long)': '第1组（长）',
      'Block 2 (Short)': '第2组（短）',
      'Block 3 (Long)': '第3组（长）',
      'Block 4 (Short)': '第4组（短）',
      'Block 5 (Long)': '第5组（长）',
      'Block 6 (Short)': '第6组（短）',
    },
  };

  String _resolve(String key) {
    final languageCode = _supportedLanguageCode(locale.languageCode);
    return _strings[languageCode]?[key] ?? _strings['en']![key] ?? key;
  }

  static String _supportedLanguageCode(String input) {
    const supported = {'en', 'fr', 'de', 'zh'};
    return supported.contains(input) ? input : 'en';
  }

  String get localeTag => _supportedLanguageCode(locale.languageCode);

  String text(String key) => _resolve(key);

  String content(String raw) {
    final languageCode = _supportedLanguageCode(locale.languageCode);
    return _contentStrings[languageCode]?[raw] ?? raw;
  }

  String daysAgo(int days) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
        return 'il y a $days jours';
      case 'de':
        return 'vor $days Tagen';
      case 'zh':
        return '$days 天前';
      case 'en':
      default:
        return '$days days ago';
    }
  }

  String dayStreak(int days) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
        return '$days jour${days == 1 ? '' : 's'}';
      case 'de':
        return '$days Tag${days == 1 ? '' : 'e'}';
      case 'zh':
        return '$days 天';
      case 'en':
      default:
        return '$days day${days == 1 ? '' : 's'}';
    }
  }

  String cupLabel(num cups) {
    final display =
        cups % 1 == 0 ? cups.toInt().toString() : cups.toStringAsFixed(1);
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
        return '$display tasse${cups == 1 ? '' : 's'}';
      case 'de':
        return '$display Tasse${cups == 1 ? '' : 'n'}';
      case 'zh':
        return '$display 杯';
      case 'en':
      default:
        return '$display cup${cups == 1 ? '' : 's'}';
    }
  }

  String cupsToday(num consumed, num goal) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
        return '${cupLabel(consumed)} sur ${cupLabel(goal)} aujourd’hui';
      case 'de':
        return '${cupLabel(consumed)} von ${cupLabel(goal)} heute';
      case 'zh':
        return '今天已喝 ${cupLabel(consumed)} / ${cupLabel(goal)}';
      case 'en':
      default:
        return '${cupLabel(consumed)} of ${cupLabel(goal)} today';
    }
  }

  String cupDrank(num cups) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
        return '${cupLabel(cups)} bue${cups == 1 ? '' : 's'}';
      case 'de':
        return '${cupLabel(cups)} getrunken';
      case 'zh':
        return '已喝 ${cupLabel(cups)}';
      case 'en':
      default:
        return '${cupLabel(cups)} drank';
    }
  }

  String keepFingerStill(int seconds) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
        return 'Gardez le doigt immobile pendant jusqu’à $seconds s.';
      case 'de':
        return 'Finger bis zu $seconds s ruhig halten.';
      case 'zh':
        return '请保持手指静止，最多 $seconds 秒。';
      case 'en':
      default:
        return 'Keep finger still for up to $seconds s.';
    }
  }

  String targetBpm(int bpm) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
        return 'BPM cible : $bpm';
      case 'de':
        return 'Ziel-BPM: $bpm';
      case 'zh':
        return '目标 BPM：$bpm';
      case 'en':
      default:
        return 'TARGET BPM: $bpm';
    }
  }

  String setProgress(int current, int total) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
      case 'de':
      case 'zh':
        return 'SET ${current + 1}/$total';
      case 'en':
      default:
        return 'SET ${current + 1}/$total';
    }
  }

  String weekOfLabel(String formattedDate) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'zh':
        return '${text('weekOf')} $formattedDate';
      default:
        return '${text('weekOf')} $formattedDate';
    }
  }

  String daysWithoutWalks(int days) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
        return '$days jour${days == 1 ? '' : 's'} sans marche';
      case 'de':
        return '$days Tag${days == 1 ? '' : 'e'} ohne Spaziergang';
      case 'zh':
        return '$days 天没有步行';
      case 'en':
      default:
        return '$days day${days == 1 ? '' : 's'} without walks';
    }
  }

  String daysRemainingThisWeek(int days) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
        return 'Il reste $days jour${days == 1 ? '' : 's'} cette semaine';
      case 'de':
        return '$days Tag${days == 1 ? '' : 'e'} verbleiben diese Woche';
      case 'zh':
        return '本周还剩 $days 天';
      case 'en':
      default:
        return '$days day${days == 1 ? '' : 's'} remaining this week';
    }
  }

  String setsLabel(int count) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
        return '$count série${count == 1 ? '' : 's'}';
      case 'de':
        return '$count Satz${count == 1 ? '' : 'e'}';
      case 'zh':
        return '$count 组';
      case 'en':
      default:
        return '$count Set${count == 1 ? '' : 's'}';
    }
  }

  String blocksLabel(int count) {
    switch (_supportedLanguageCode(locale.languageCode)) {
      case 'fr':
        return '$count bloc${count == 1 ? '' : 's'}';
      case 'de':
        return '$count Block${count == 1 ? '' : 'e'}';
      case 'zh':
        return '$count 组块';
      case 'en':
      default:
        return '$count Block${count == 1 ? '' : 's'}';
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
