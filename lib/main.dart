import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'core/services/background_service.dart';
import 'core/services/critical_alert_service.dart';
import 'core/services/dashboard_sync_service.dart';
import 'core/services/battery_monitoring_service.dart';
import 'core/services/firebase_messaging_service.dart';
import 'core/services/notification_service.dart';
import 'core/constants/app_colors.dart';

// ==========================================
// 🧠 App-Level ViewModels
// ==========================================
// ملاحظة معمارية مهمة:
// لا نضع هنا ViewModels الخاصة بشاشات محددة مثل:
// ProfileViewModel / MedicalRecordViewModel / ContactsViewModel
//
// السبب:
// هذه ViewModels تنشأ داخل شاشاتها فقط حتى لا يبدأ تحميل بيانات
// البروفايل أو السجل الطبي أو جهات الطوارئ من بداية تشغيل التطبيق.
// هذا يمنع التحميل المزدوج ويحافظ على أداء أفضل وتجربة أنظف.
import 'features/auth/viewmodels/splash_viewmodel.dart';
import 'features/auth/viewmodels/onboarding_viewmodel.dart';
import 'features/auth/viewmodels/login_viewmodel.dart';
import 'features/auth/viewmodels/signup_viewmodel.dart';
import 'features/home/viewmodels/home_viewmodel.dart';
import 'features/map/viewmodels/map_viewmodel.dart';
import 'features/ai/viewmodels/ai_chat_viewmodel.dart';
import 'features/settings/viewmodels/settings_viewmodel.dart';
import 'features/iot/viewmodels/device_connection_viewmodel.dart';
import 'features/kroka/viewmodels/kroka_viewmodel.dart';
import 'features/accident_detection/viewmodels/accident_monitor_viewmodel.dart';

// ==========================================
// 📱 Views
// ==========================================
import 'features/auth/views/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await _initializeFirebase();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await _initializeBackgroundServices();
  _configureCrashlytics();
  _configureSystemUI();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/langs',
      fallbackLocale: const Locale('ar'),
      child: MultiProvider(
        providers: [
          // ==========================================
          // 🔐 Auth / Startup Flow
          // ==========================================
          ChangeNotifierProvider(create: (_) => SplashViewModel()),
          ChangeNotifierProvider(create: (_) => OnboardingViewModel()),
          ChangeNotifierProvider(create: (_) => LoginViewModel()),
          ChangeNotifierProvider(create: (_) => SignupViewModel()),

          // ==========================================
          // 🚨 Shared Accident Core
          // ==========================================
          // هذا يبقى App-Level لأنه مرتبط بمراقبة الحوادث
          // وقد تحتاجه أكثر من شاشة أثناء عمل التطبيق.
          ChangeNotifierProvider(create: (_) => AccidentMonitorViewModel()),

          ChangeNotifierProxyProvider<AccidentMonitorViewModel, HomeViewModel>(
            create: (context) => HomeViewModel(
              accidentMonitor: context.read<AccidentMonitorViewModel>(),
            ),
            update: (context, accidentMonitor, previous) =>
                previous ?? HomeViewModel(accidentMonitor: accidentMonitor),
          ),

          // ==========================================
          // 🌍 Shared Feature ViewModels
          // ==========================================
          // تبقى هنا لأنها أخف أو قد تكون مشتركة بين أكثر من مكان.
          ChangeNotifierProvider(create: (_) => AIChatViewModel()),
          ChangeNotifierProvider(create: (_) => MapViewModel()),
          ChangeNotifierProvider(create: (_) => SettingsViewModel()),
          ChangeNotifierProvider(create: (_) => DeviceConnectionViewModel()),
          ChangeNotifierProvider(create: (_) => KrokaViewModel()),
        ],
        child: const GuardianApp(),
      ),
    ),
  );
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    debugPrint('🔥 System Log: Firebase initialized successfully.');
    debugPrint('💾 System Log: Firestore offline persistence enabled.');
  } catch (e, stackTrace) {
    debugPrint('❌ System Alert: Firebase initialization failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> _initializeBackgroundServices() async {
  try {
    await BackgroundServiceManager.initialize();
    debugPrint('✅ System Log: Background service initialized');

    await CriticalAlertService.initialize();
    debugPrint('✅ System Log: Critical alert service initialized');

    await NotificationService().initialize();
    debugPrint('✅ System Log: Notification service initialized');

    final performance = FirebasePerformance.instance;
    await performance.setPerformanceCollectionEnabled(true);
    debugPrint('✅ System Log: Firebase Performance initialized');

    await BatteryMonitoringService().initialize();
    debugPrint('✅ System Log: Battery monitoring initialized');

    final prefs = await SharedPreferences.getInstance();
    final isBatteryAlertEnabled =
        prefs.getBool('setting_battery_alert') ?? true;

    if (isBatteryAlertEnabled) {
      await BatteryMonitoringService().startMonitoring();
      debugPrint('✅ System Log: Battery monitoring started');
    }
  } catch (e, stackTrace) {
    debugPrint('❌ System Alert: Background services initialization failed: $e');
    debugPrintStack(stackTrace: stackTrace);

    FirebaseCrashlytics.instance.recordError(
      e,
      stackTrace,
      reason: 'Background services initialization failed',
      fatal: false,
    );
  }
}

void _configureCrashlytics() {
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    debugPrint('❌ Fatal Error: ${errorDetails.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    debugPrint('❌ Async Error: $error');
    return true;
  };

  debugPrint('✅ System Log: Crashlytics configured');
}

void _configureSystemUI() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
}

class GuardianApp extends StatefulWidget {
  const GuardianApp({super.key});

  @override
  State<GuardianApp> createState() => _GuardianAppState();
}

class _GuardianAppState extends State<GuardianApp> with WidgetsBindingObserver {
  final DashboardSyncService _dashboardSyncService = DashboardSyncService();

  bool _backgroundMonitoringActive = false;
  bool _isLifecycleSwitching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFCMTokenRefreshListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _handleLifecycleChange(state);
  }

  void _initializeFCMTokenRefreshListener() {
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) {
          _handleTokenRefresh(newToken);
        },
        onError: (error) {
          debugPrint('⚠️ FCM Token Refresh: Listener error - $error');
        },
      );

      debugPrint('✅ FCM Token Refresh: Listener initialized');
    } catch (e) {
      debugPrint('⚠️ FCM Token Refresh: Failed to initialize listener - $e');
    }
  }

  Future<void> _handleTokenRefresh(String newToken) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('⚠️ FCM Token Refresh: No user logged in, skipping update');
        return;
      }

      debugPrint(
        '🔄 FCM Token Refresh: New token received, updating Firestore',
      );

      final result = await _dashboardSyncService.saveFCMToken(
        user.uid,
        newToken,
      );

      if (result.isFailure) {
        debugPrint(
          '⚠️ FCM Token Refresh: Failed to save token - ${result.error}',
        );
      } else {
        debugPrint('✅ FCM Token Refresh: Token updated successfully');
      }
    } catch (e) {
      debugPrint('⚠️ FCM Token Refresh: Error handling token - $e');
    }
  }

  // ==========================================
  // 🔧 TEMPORARY DIAGNOSTIC FREEZE
  // ==========================================
  // نوقف background handoff مؤقتًا حتى نختبر
  // foreground detection فقط بدون أي تداخل.
  bool _shouldUseBackgroundMonitoring(HomeViewModel homeViewModel) {
    return false;
  }

  Future<void> _handleLifecycleChange(AppLifecycleState state) async {
    if (!mounted) return;
    if (_isLifecycleSwitching) return;

    _isLifecycleSwitching = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final homeViewModel = context.read<HomeViewModel>();

      switch (state) {
        case AppLifecycleState.resumed:
          debugPrint('📱 App Lifecycle: resumed');

          if (_backgroundMonitoringActive) {
            await BackgroundServiceManager.stopMonitoring();
            _backgroundMonitoringActive = false;
            debugPrint('✅ App Lifecycle: Background monitoring stopped');
          }

          await homeViewModel.resumeForegroundMonitoringIfNeeded();

          debugPrint(
            '✅ App Lifecycle: Foreground monitoring resumed if needed',
          );

          if (user != null) {
            final onlineResult = await _dashboardSyncService.setUserOnline(
              user.uid,
            );

            if (onlineResult.isFailure) {
              debugPrint(
                '⚠️ App Lifecycle: Failed to set user online - ${onlineResult.error}',
              );
            }
          }
          break;

        case AppLifecycleState.inactive:
          debugPrint('📱 App Lifecycle: inactive (ignored)');
          break;

        case AppLifecycleState.paused:
        case AppLifecycleState.hidden:
        case AppLifecycleState.detached:
          debugPrint('📱 App Lifecycle: ${state.name}');

          final shouldUseBackground = _shouldUseBackgroundMonitoring(
            homeViewModel,
          );

          if (shouldUseBackground) {
            await homeViewModel.suspendForegroundMonitoring();
            debugPrint('✅ App Lifecycle: Foreground monitoring suspended');

            await BackgroundServiceManager.startService();
            await BackgroundServiceManager.startMonitoring(
              sensitivity: homeViewModel.selectedSensitivity,
            );

            _backgroundMonitoringActive = true;

            debugPrint(
              '✅ App Lifecycle: Background monitoring started '
              '(sensitivity=${homeViewModel.selectedSensitivity})',
            );
          } else {
            await BackgroundServiceManager.stopMonitoring();
            _backgroundMonitoringActive = false;

            debugPrint(
              'ℹ️ App Lifecycle: Background monitoring disabled temporarily for foreground diagnostics',
            );
          }

          if (user != null) {
            final offlineResult = await _dashboardSyncService.setUserOffline(
              user.uid,
            );

            if (offlineResult.isFailure) {
              debugPrint(
                '⚠️ App Lifecycle: Failed to set user offline - ${offlineResult.error}',
              );
            }
          }
          break;
      }
    } catch (e, stackTrace) {
      debugPrint('⚠️ App Lifecycle: Switch error - $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isLifecycleSwitching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Guardian 360',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryRed,
        fontFamily: GoogleFonts.cairo().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryRed,
          primary: AppColors.primaryRed,
          secondary: AppColors.primaryDark,
          surface: AppColors.background,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            //TargetPlatform.iOS
          },
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
