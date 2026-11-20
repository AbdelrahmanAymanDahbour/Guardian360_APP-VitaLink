/// ==========================================
/// 🗺️ App Routes - Guardian 360
/// ==========================================
/// جميع مسارات التنقل في التطبيق.
///
/// القاعدة الحالية:
/// - السجل الطبي الرسمي هو: AppRoutes.medicalRecord
/// - AppRoutes.medicalProfile مسار قديم Legacy فقط للتوافق المؤقت.
/// - يمنع فتح شاشة auth/medical_profile_screen لأنها حُذفت وأصبحت غير رسمية.
class AppRoutes {
  // ==========================================
  // 🔐 Authentication Routes
  // ==========================================
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String otp = '/otp';
  static const String forgotPassword = '/forgot-password';

  // ==========================================
  // 🏠 Main App Routes
  // ==========================================
  static const String home = '/home';
  static const String dashboard = '/dashboard';

  // ==========================================
  // 🚗 Trip & Monitoring Routes
  // ==========================================
  static const String tripStart = '/trip/start';
  static const String tripActive = '/trip/active';
  static const String tripHistory = '/trip/history';
  static const String tripDetails = '/trip/details';

  // ==========================================
  // 🚨 Emergency & SOS Routes
  // ==========================================
  static const String sosCountdown = '/sos/countdown';
  static const String sosActive = '/sos/active';
  static const String sosHistory = '/sos/history';
  static const String alertDetails = '/alert/details';

  // ==========================================
  // 🏥 Medical Routes
  // ==========================================

  /// Legacy route kept only to avoid breaking old references.
  ///
  /// Any usage of this route must be normalized to [medicalRecord].
  /// Do not create or navigate to auth/medical_profile_screen.
  @Deprecated('Use AppRoutes.medicalRecord instead.')
  static const String medicalProfile = '/medical-profile';

  /// Official medical record route.
  static const String medicalRecord = '/medical/record';
  static const String medicalEdit = '/medical/edit';
  static const String medicalView = '/medical/view';

  // ==========================================
  // 📞 Contacts Routes
  // ==========================================
  static const String contacts = '/contacts';
  static const String contactAdd = '/contacts/add';
  static const String contactEdit = '/contacts/edit';
  static const String contactDetails = '/contacts/details';

  // ==========================================
  // 🗺️ Map & Location Routes
  // ==========================================
  static const String map = '/map';
  static const String mapLive = '/map/live';
  static const String mapHistory = '/map/history';

  // ==========================================
  // 👤 Profile Routes
  // ==========================================
  static const String profile = '/profile';
  static const String profileEdit = '/profile/edit';
  static const String profileView = '/profile/view';

  // ==========================================
  // ⚙️ Settings Routes
  // ==========================================
  static const String settings = '/settings';
  static const String settingsGeneral = '/settings/general';
  static const String settingsSensitivity = '/settings/sensitivity';
  static const String settingsNotifications = '/settings/notifications';
  static const String settingsPrivacy = '/settings/privacy';
  static const String settingsAbout = '/settings/about';

  // ==========================================
  // ✅ Safe Arrival Routes
  // ==========================================
  static const String safeArrival = '/safe-arrival';
  static const String safeArrivalSetup = '/safe-arrival/setup';
  static const String safeArrivalTracking = '/safe-arrival/tracking';
  static const String safeArrivalConfirmed = '/safe-arrival/confirmed';

  // ==========================================
  // 🤖 AI & Chat Routes
  // ==========================================
  static const String aiChat = '/ai/chat';
  static const String aiAssistant = '/ai/assistant';

  // ==========================================
  // 🚙 Kroka Routes
  // ==========================================
  static const String kroka = '/kroka';
  static const String krokaReport = '/kroka/report';
  static const String krokaHistory = '/kroka/history';

  // ==========================================
  // 🔌 IoT Routes
  // ==========================================
  static const String iot = '/iot';
  static const String iotDevices = '/iot/devices';
  static const String iotConnection = '/iot/connection';

  // ==========================================
  // 📊 Analytics & Reports Routes
  // ==========================================
  static const String analytics = '/analytics';
  static const String reports = '/reports';
  static const String statistics = '/statistics';

  // ==========================================
  // ℹ️ Info & Help Routes
  // ==========================================
  static const String help = '/help';
  static const String faq = '/faq';
  static const String tutorial = '/tutorial';
  static const String about = '/about';
  static const String terms = '/terms';
  static const String privacy = '/privacy';

  // ==========================================
  // 🎯 Helper Methods
  // ==========================================

  /// Normalize legacy routes into the current official routes.
  static String normalizeRoute(String route) {
    final cleanRoute = route.trim();

    switch (cleanRoute) {
      case medicalProfile:
        return medicalRecord;
      default:
        return cleanRoute;
    }
  }

  /// التحقق من أن المسار يتطلب مصادقة.
  static bool requiresAuth(String route) {
    final normalizedRoute = normalizeRoute(route);

    const unauthenticatedRoutes = [
      splash,
      onboarding,
      login,
      signup,
      otp,
      forgotPassword,
    ];

    return !unauthenticatedRoutes.contains(normalizedRoute);
  }

  /// التحقق من أن المسار هو مسار رئيسي.
  static bool isMainRoute(String route) {
    final normalizedRoute = normalizeRoute(route);

    const mainRoutes = [home, dashboard, map, profile, settings];

    return mainRoutes.contains(normalizedRoute);
  }

  /// التحقق من أن المسار يتطلب رحلة نشطة.
  static bool requiresActiveTrip(String route) {
    final normalizedRoute = normalizeRoute(route);

    const tripRequiredRoutes = [tripActive, sosCountdown, sosActive, mapLive];

    return tripRequiredRoutes.contains(normalizedRoute);
  }

  /// التحقق من أن المسار طبي.
  static bool isMedicalRoute(String route) {
    final normalizedRoute = normalizeRoute(route);

    return normalizedRoute == medicalRecord ||
        normalizedRoute == medicalEdit ||
        normalizedRoute == medicalView;
  }

  /// الحصول على عنوان الصفحة بالعربي.
  static String getPageTitle(String route) {
    final normalizedRoute = normalizeRoute(route);

    switch (normalizedRoute) {
      case splash:
        return 'Guardian 360';
      case onboarding:
        return 'مرحباً بك';
      case login:
        return 'تسجيل الدخول';
      case signup:
        return 'إنشاء حساب';
      case otp:
        return 'التحقق من الرمز';
      case forgotPassword:
        return 'استعادة كلمة المرور';

      case home:
        return 'الرئيسية';
      case dashboard:
        return 'لوحة التحكم';

      case tripStart:
        return 'بدء رحلة';
      case tripActive:
        return 'رحلة نشطة';
      case tripHistory:
        return 'سجل الرحلات';
      case tripDetails:
        return 'تفاصيل الرحلة';

      case sosCountdown:
        return 'نظام الطوارئ';
      case sosActive:
        return 'طوارئ نشطة';
      case sosHistory:
        return 'سجل الطوارئ';
      case alertDetails:
        return 'تفاصيل البلاغ';

      case medicalRecord:
        return 'السجل الطبي';
      case medicalEdit:
        return 'تعديل السجل الطبي';
      case medicalView:
        return 'عرض السجل الطبي';

      case contacts:
        return 'جهات الاتصال الطارئة';
      case contactAdd:
        return 'إضافة جهة اتصال';
      case contactEdit:
        return 'تعديل جهة اتصال';
      case contactDetails:
        return 'تفاصيل جهة الاتصال';

      case map:
        return 'الخريطة';
      case mapLive:
        return 'الخريطة المباشرة';
      case mapHistory:
        return 'سجل المواقع';

      case profile:
        return 'الملف الشخصي';
      case profileEdit:
        return 'تعديل الملف الشخصي';
      case profileView:
        return 'عرض الملف الشخصي';

      case settings:
        return 'الإعدادات';
      case settingsGeneral:
        return 'الإعدادات العامة';
      case settingsSensitivity:
        return 'حساسية الاستشعار';
      case settingsNotifications:
        return 'إعدادات الإشعارات';
      case settingsPrivacy:
        return 'الخصوصية';
      case settingsAbout:
        return 'عن التطبيق';

      case safeArrival:
        return 'الوصول الآمن';
      case safeArrivalSetup:
        return 'إعداد الوصول الآمن';
      case safeArrivalTracking:
        return 'تتبع الوصول الآمن';
      case safeArrivalConfirmed:
        return 'تم تأكيد الوصول';

      case aiChat:
      case aiAssistant:
        return 'المساعد الذكي';

      case kroka:
        return 'كروكا';
      case krokaReport:
        return 'تقرير كروكا';
      case krokaHistory:
        return 'سجل كروكا';

      case iot:
        return 'الأجهزة الذكية';
      case iotDevices:
        return 'أجهزة IoT';
      case iotConnection:
        return 'اتصال الأجهزة';

      case analytics:
        return 'التحليلات';
      case reports:
        return 'التقارير';
      case statistics:
        return 'الإحصائيات';

      case help:
        return 'المساعدة';
      case faq:
        return 'الأسئلة الشائعة';
      case tutorial:
        return 'الدليل التعليمي';
      case about:
        return 'عن التطبيق';
      case terms:
        return 'الشروط والأحكام';
      case privacy:
        return 'سياسة الخصوصية';

      default:
        return 'Guardian 360';
    }
  }

  /// الحصول على المسار السابق المناسب.
  static String getPreviousRoute(String currentRoute) {
    final normalizedRoute = normalizeRoute(currentRoute);

    if (normalizedRoute.startsWith('/trip/')) {
      return home;
    }

    if (normalizedRoute.startsWith('/sos/')) {
      return home;
    }

    if (normalizedRoute.startsWith('/settings/')) {
      return settings;
    }

    if (normalizedRoute.startsWith('/medical/')) {
      return home;
    }

    if (normalizedRoute.startsWith('/contacts/')) {
      return contacts;
    }

    if (normalizedRoute.startsWith('/map/')) {
      return map;
    }

    if (normalizedRoute.startsWith('/profile/')) {
      return profile;
    }

    if (normalizedRoute.startsWith('/safe-arrival/')) {
      return safeArrival;
    }

    return home;
  }

  /// بناء مسار مع معاملات Query Parameters.
  static String buildRouteWithParams(String route, Map<String, String> params) {
    final normalizedRoute = normalizeRoute(route);

    if (params.isEmpty) {
      return normalizedRoute;
    }

    final uri = Uri(path: normalizedRoute, queryParameters: params);

    return uri.toString();
  }
}
