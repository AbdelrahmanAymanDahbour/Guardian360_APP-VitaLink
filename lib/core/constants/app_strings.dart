/// Centralized localization keys used by Guardian 360.
///
/// This class intentionally stores keys only. User-facing text must live in
/// assets/langs/ar.json and assets/langs/en.json, then be rendered with .tr().
class AppStrings {
  // Trip
  static const String tripStarted = 'trip.started';
  static const String tripEnded = 'trip.ended';
  static const String tripActive = 'trip.active';
  static const String tripInactive = 'trip.inactive';
  static const String tripCancelled = 'trip.cancelled';
  static const String tripEmergency = 'trip.emergency';

  // Accident detection
  static const String accidentDetected = 'accident.detected';
  static const String accidentAnalyzing = 'accident.analyzing';
  static const String accidentCritical = 'accident.critical';
  static const String accidentModerate = 'accident.moderate';
  static const String accidentIgnored = 'accident.ignored';
  static const String accidentFalsePositive = 'accident.false_positive';

  // SOS and emergency
  static const String sosTriggered = 'sos.triggered';
  static const String sosCancelled = 'sos.cancelled';
  static const String sosCountdown = 'sos.countdown';
  static const String sosAlertSent = 'sos.alert_sent';
  static const String sosAlertFailed = 'sos.alert_failed';
  static const String sosUserSafe = 'sos.user_safe';
  static const String sosAreYouOk = 'sos.are_you_ok';
  static const String sosNoResponse = 'sos.no_response';

  // Location
  static const String locationFetching = 'location.fetching';
  static const String locationSuccess = 'location.success';
  static const String locationFailed = 'location.failed';
  static const String locationServiceDisabled = 'location.service_disabled';
  static const String locationPermissionDenied = 'location.permission_denied';
  static const String locationPermissionDeniedForever =
      'location.permission_denied_forever';

  // Medical profile
  static const String medicalProfileIncomplete = 'medical.profile.incomplete';
  static const String medicalProfileComplete = 'medical.profile.complete';
  static const String medicalProfileSaved = 'medical.profile.saved';
  static const String medicalProfileFailed = 'medical.profile.failed';
  static const String medicalAuthRequired = 'medical.profile.auth_required';
  static const String medicalAuthFailed = 'medical.profile.auth_failed';

  // Emergency contacts
  static const String contactAdded = 'contacts.messages.added';
  static const String contactDeleted = 'contacts.messages.deleted';
  static const String contactUpdated = 'contacts.messages.updated';
  static const String contactEmpty = 'contacts.empty';
  static const String contactPrimary = 'contacts.primary';
  static const String contactBackup = 'contacts.backup';

  // Authentication
  static const String authLoginSuccess = 'auth.login_success';
  static const String authLoginFailed = 'auth.login_failed';
  static const String authSignupSuccess = 'auth.signup_success';
  static const String authSignupFailed = 'auth.signup_failed';
  static const String authLogoutSuccess = 'auth.logout_success';
  static const String authEmailInvalid = 'auth.email_invalid';
  static const String authPasswordWeak = 'auth.password_weak';
  static const String authUserNotFound = 'auth.user_not_found';
  static const String authWrongPassword = 'auth.wrong_password';
  static const String authEmailAlreadyInUse = 'auth.email_already_in_use';

  // System status
  static const String systemReady = 'system.ready';
  static const String systemActive = 'system.active';
  static const String systemInitializing = 'system.initializing';
  static const String systemHealthy = 'system.healthy';
  static const String systemMonitoring = 'system.monitoring';
  static const String systemProtectionEnabled = 'system.protection_enabled';
  static const String systemProtectionDisabled = 'system.protection_disabled';

  // Settings
  static const String settingsSaved = 'settings.messages.saved';
  static const String settingsFailed = 'settings.messages.failed';
  static const String settingsSensitivityLow = 'settings.sensitivity.low';
  static const String settingsSensitivityMedium = 'settings.sensitivity.medium';
  static const String settingsSensitivityHigh = 'settings.sensitivity.high';

  // Notifications
  static const String notificationTitle = 'notifications.app_title';
  static const String notificationAccidentDetected =
      'notifications.accident_detected';
  static const String notificationSOSTriggered = 'notifications.sos_triggered';
  static const String notificationTripStarted = 'notifications.trip_started';
  static const String notificationTripEnded = 'notifications.trip_ended';

  // Safe arrival
  static const String safeArrivalConfirmed = 'safe_arrival.confirmed';
  static const String safeArrivalNotificationSent =
      'safe_arrival.notification_sent';
  static const String safeArrivalTimeout = 'safe_arrival.timeout';

  // Errors
  static const String errorGeneric = 'errors.unknown';
  static const String errorNetwork = 'errors.network_error';
  static const String errorFirebase = 'errors.firebase';
  static const String errorPermission = 'errors.permission_denied';
  static const String errorTimeout = 'errors.timeout';
  static const String errorUserNotLoggedIn = 'errors.user_not_logged_in';

  // Actions
  static const String actionStartTrip = 'actions.start_trip';
  static const String actionEndTrip = 'actions.end_trip';
  static const String actionCancel = 'common.cancel';
  static const String actionConfirm = 'common.confirm';
  static const String actionSave = 'common.save';
  static const String actionEdit = 'common.edit';
  static const String actionDelete = 'common.delete';
  static const String actionRetry = 'common.retry';
  static const String actionImSafe = 'actions.im_safe';
  static const String actionNeedHelp = 'actions.need_help';
  static const String actionCallEmergency = 'actions.call_emergency';

  // AI chat
  static const String aiTitle = 'ai.title';
  static const String aiWelcome = 'ai.welcome';
  static const String aiStatusReady = 'ai.status_ready';
  static const String aiStatusThinking = 'ai.status_thinking';
  static const String aiEmptyTitle = 'ai.empty_title';
  static const String aiEmptySubtitle = 'ai.empty_subtitle';
  static const String aiQuickFirstAidTitle = 'ai.quick_first_aid_title';
  static const String aiAskAnything = 'ai.ask_anything';
  static const String aiInputHint = 'ai.input_hint';
  static const String aiInputListeningHint = 'ai.input_listening_hint';
  static const String aiListening = 'ai.listening';
  static const String aiSpeaking = 'ai.speaking';
  static const String aiEmergencyDisclaimer = 'ai.emergency_disclaimer';
  static const String aiSeriousEmergencyAdvice = 'ai.serious_emergency_advice';
  static const String aiQuickUnconsciousQuestion =
      'ai.quick_questions.unconscious';
  static const String aiQuickBleedingQuestion = 'ai.quick_questions.bleeding';
  static const String aiQuickBurnQuestion = 'ai.quick_questions.burn';
  static const String aiQuickSosCommand = 'ai.quick_questions.sos';
  static const String aiWriteQuestion = 'ai.messages.write_question';
  static const String aiNoSuitableReply = 'ai.messages.no_suitable_reply';
  static const String aiLoginRequired = 'ai.messages.login_required';
  static const String aiInvalidQuestion = 'ai.messages.invalid_question';
  static const String aiTooManyRequests = 'ai.messages.too_many_requests';
  static const String aiServerNotReady = 'ai.messages.server_not_ready';
  static const String aiSecureServerError = 'ai.messages.secure_server_error';
  static const String aiUnexpectedError = 'ai.messages.unexpected_error';
  static const String aiError = 'ai.error';
  static const String aiEmergencyDetected = 'ai.emergency_detected';
  static const String aiEmergencyExplicitDetected =
      'ai.emergency_explicit_detected';

  // AI voice
  static const String aiVoiceUnavailable = 'ai.voice.unavailable';
  static const String aiVoiceMicrophonePermissionDenied =
      'ai.voice.microphone_permission_denied';
  static const String aiVoiceStartFailed = 'ai.voice.start_failed';
  static const String aiVoiceListeningError = 'ai.voice.listening_error';
  static const String aiVoiceNoClearSpeech = 'ai.voice.no_clear_speech';
  static const String aiVoiceToneElevated = 'ai.voice.tone_elevated';
  static const String aiVoiceToneClear = 'ai.voice.tone_clear';
  static const String aiVoiceToneLow = 'ai.voice.tone_low';
  static const String aiVoiceToneIdle = 'ai.voice.tone_idle';

  // Dashboard
  static const String dashboardTitle = 'dashboard.title';
  static const String dashboardNoData = 'dashboard.no_data';
  static const String dashboardLoading = 'dashboard.loading';

  // Greetings
  static const String greetingMorning = 'greetings.morning';
  static const String greetingAfternoon = 'greetings.afternoon';
  static const String greetingEvening = 'greetings.evening';
  static const String greetingNight = 'greetings.night';

  // Labels
  static const String labelName = 'labels.name';
  static const String labelPhone = 'labels.phone';
  static const String labelEmail = 'labels.email';
  static const String labelPassword = 'labels.password';
  static const String labelBloodType = 'labels.blood_type';
  static const String labelWeight = 'labels.weight';
  static const String labelHeight = 'labels.height';
  static const String labelDiseases = 'labels.diseases';
  static const String labelMedications = 'labels.medications';
  static const String labelAllergies = 'labels.allergies';
  static const String labelNotes = 'labels.notes';
  static const String labelDestination = 'labels.destination';
  static const String labelDuration = 'labels.duration';
  static const String labelRelation = 'labels.relation';

  // Placeholders
  static const String placeholderName = 'placeholders.name';
  static const String placeholderPhone = 'placeholders.phone';
  static const String placeholderEmail = 'placeholders.email';
  static const String placeholderPassword = 'placeholders.password';
  static const String placeholderSearch = 'placeholders.search';
  static const String placeholderMessage = 'placeholders.message';

  // Units
  static const String unitKilogram = 'units.kilogram';
  static const String unitCentimeter = 'units.centimeter';
  static const String unitMeter = 'units.meter';
  static const String unitKilometer = 'units.kilometer';
  static const String unitSecond = 'units.second';
  static const String unitMinute = 'units.minute';
  static const String unitHour = 'units.hour';

  // Status messages
  static const String statusLoading = 'status.loading';
  static const String statusProcessing = 'status.processing';
  static const String statusSuccess = 'status.success';
  static const String statusFailed = 'status.failed';
  static const String statusPending = 'status.pending';
  static const String statusCompleted = 'status.completed';
  static const String statusCancelled = 'status.cancelled';

  // Severity
  static const String severityLow = 'severity.low';
  static const String severityMedium = 'severity.medium';
  static const String severityHigh = 'severity.high';
  static const String severityCritical = 'severity.critical';

  // App info
  static const String appName = 'app_name';
  static const String appTagline = 'app.tagline';
  static const String appVersion = 'app.version';
  static const String appCopyright = 'app.copyright';
}
