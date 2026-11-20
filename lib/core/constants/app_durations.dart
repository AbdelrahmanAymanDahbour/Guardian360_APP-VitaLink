/// ==========================================
/// ⏱️ App Durations - Guardian 360
/// ==========================================
/// جميع المدد الزمنية المستخدمة في المشروع
/// يمنع استخدام hardcoded durations في الكود
class AppDurations {
  // ==========================================
  // 🚨 Accident Detection & SOS
  // ==========================================

  /// فترة منع التكرار بعد اكتشاف حادث
  static const Duration detectionCooldown = Duration(seconds: 8);

  /// نافذة دمج الحساسات (الوقت بين التسارع والدوران)
  static const Duration fusionWindow = Duration(milliseconds: 900);

  /// نافذة الاحتفاظ بالعينات
  static const Duration historyWindow = Duration(milliseconds: 1400);

  /// مدة العد التنازلي للحوادث الحرجة
  static const Duration countdownCritical = Duration(seconds: 5);

  /// مدة العد التنازلي للحوادث المتوسطة/العالية
  static const Duration countdownModerate = Duration(seconds: 10);

  /// مدة العد التنازلي للحوادث المنخفضة
  static const Duration countdownLow = Duration(seconds: 15);

  /// مدة عرض رسالة الإلغاء الناجح
  static const Duration sosCancelledMessageDuration = Duration(seconds: 3);

  // ==========================================
  // 📍 Location Services
  // ==========================================

  /// مهلة انتظار الموقع
  static const Duration locationTimeout = Duration(seconds: 10);

  /// فترة تحديث الموقع أثناء الرحلة
  static const Duration locationUpdateInterval = Duration(seconds: 30);

  /// مهلة انتظار الموقع الأولي
  static const Duration initialLocationTimeout = Duration(seconds: 15);

  // ==========================================
  // 🔄 Network & Firebase
  // ==========================================

  /// مهلة انتظار الشبكة
  static const Duration networkTimeout = Duration(seconds: 30);

  /// مهلة انتظار Firebase
  static const Duration firebaseTimeout = Duration(seconds: 15);

  /// فترة إعادة المحاولة بعد فشل الاتصال
  static const Duration retryDelay = Duration(seconds: 3);

  /// فترة إعادة المحاولة الطويلة
  static const Duration retryDelayLong = Duration(seconds: 10);

  // ==========================================
  // 🎨 UI & Animations
  // ==========================================

  /// مدة الأنيميشن القصيرة
  static const Duration animationShort = Duration(milliseconds: 200);

  /// مدة الأنيميشن المتوسطة
  static const Duration animationMedium = Duration(milliseconds: 400);

  /// مدة الأنيميشن الطويلة
  static const Duration animationLong = Duration(milliseconds: 600);

  /// مدة الأنيميشن الطويلة جداً
  static const Duration animationExtraLong = Duration(milliseconds: 800);

  /// مدة عرض SnackBar
  static const Duration snackBarDuration = Duration(seconds: 3);

  /// مدة عرض SnackBar القصيرة
  static const Duration snackBarShort = Duration(seconds: 2);

  /// مدة عرض SnackBar الطويلة
  static const Duration snackBarLong = Duration(seconds: 5);

  /// مدة الانتقال بين الصفحات
  static const Duration pageTransition = Duration(milliseconds: 400);

  /// مدة Splash Screen
  static const Duration splashScreen = Duration(milliseconds: 3800);

  // ==========================================
  // 🔐 Authentication & OTP
  // ==========================================

  /// مدة صلاحية OTP
  static const Duration otpValidity = Duration(minutes: 5);

  /// مدة العد التنازلي لإعادة إرسال OTP
  static const Duration otpResendCountdown = Duration(seconds: 60);

  /// مهلة انتظار تسجيل الدخول
  static const Duration loginTimeout = Duration(seconds: 30);

  /// مدة الجلسة
  static const Duration sessionDuration = Duration(days: 30);

  // ==========================================
  // 🏥 Medical & Biometric
  // ==========================================

  /// مهلة انتظار البصمة
  static const Duration biometricTimeout = Duration(seconds: 30);

  /// مدة عرض رسالة نجاح حفظ الملف الطبي
  static const Duration medicalSaveSuccess = Duration(seconds: 2);

  // ==========================================
  // 🚗 Trip Management
  // ==========================================

  /// الحد الأقصى لمدة الرحلة
  static const Duration maxTripDuration = Duration(hours: 24);

  /// الحد الأدنى لمدة الرحلة
  static const Duration minTripDuration = Duration(minutes: 1);

  /// فترة تحديث حالة الرحلة
  static const Duration tripStatusUpdateInterval = Duration(seconds: 20);

  /// مدة الانتظار قبل إنهاء الرحلة تلقائياً (عند عدم الحركة)
  static const Duration autoEndTripDelay = Duration(minutes: 30);

  // ==========================================
  // ✅ Safe Arrival
  // ==========================================

  /// مدة الانتظار قبل تفعيل تنبيه عدم الوصول
  static const Duration safeArrivalGracePeriod = Duration(minutes: 5);

  /// فترة التحقق من الوصول
  static const Duration safeArrivalCheckInterval = Duration(seconds: 60);

  // ==========================================
  // 🔔 Notifications
  // ==========================================

  /// مدة عرض الإشعار
  static const Duration notificationDuration = Duration(seconds: 5);

  /// فترة التحقق من الإشعارات الجديدة
  static const Duration notificationCheckInterval = Duration(minutes: 5);

  // ==========================================
  // 💾 Data Sync & Cache
  // ==========================================

  /// فترة مزامنة البيانات مع Firestore
  static const Duration dataSyncInterval = Duration(minutes: 15);

  /// مدة صلاحية الكاش
  static const Duration cacheValidity = Duration(hours: 24);

  /// فترة تنظيف الكاش القديم
  static const Duration cacheCleanupInterval = Duration(days: 7);

  // ==========================================
  // 🔋 Battery & Performance
  // ==========================================

  /// فترة التحقق من البطارية
  static const Duration batteryCheckInterval = Duration(minutes: 10);

  /// فترة التحقق من الاتصال بالإنترنت
  static const Duration connectivityCheckInterval = Duration(seconds: 30);

  // ==========================================
  // 🎙️ AI & Voice
  // ==========================================

  /// مدة الاستماع للصوت
  static const Duration voiceListeningDuration = Duration(seconds: 3);

  /// مهلة انتظار استجابة AI
  static const Duration aiResponseTimeout = Duration(seconds: 30);

  /// تأخير قبل تفعيل SOS من AI
  static const Duration aiSOSTriggerDelay = Duration(seconds: 2);

  // ==========================================
  // 🎯 Debounce & Throttle
  // ==========================================

  /// فترة debounce للبحث
  static const Duration searchDebounce = Duration(milliseconds: 500);

  /// فترة debounce للإدخال
  static const Duration inputDebounce = Duration(milliseconds: 300);

  /// فترة throttle للأزرار
  static const Duration buttonThrottle = Duration(milliseconds: 500);

  /// فترة throttle لتحديث الموقع
  static const Duration locationThrottle = Duration(seconds: 5);

  // ==========================================
  // 🔄 Refresh & Reload
  // ==========================================

  /// فترة تحديث الشاشة الرئيسية
  static const Duration homeRefreshInterval = Duration(seconds: 20);

  /// فترة تحديث الخريطة
  static const Duration mapRefreshInterval = Duration(seconds: 10);

  /// مدة الانتظار قبل إعادة التحميل التلقائي
  static const Duration autoReloadDelay = Duration(seconds: 5);

  // ==========================================
  // 🎭 Loading & Processing
  // ==========================================

  /// الحد الأدنى لمدة عرض شاشة التحميل
  static const Duration minLoadingDuration = Duration(milliseconds: 500);

  /// الحد الأقصى لمدة عرض شاشة التحميل
  static const Duration maxLoadingDuration = Duration(seconds: 30);

  /// مدة معالجة البيانات
  static const Duration processingDuration = Duration(milliseconds: 1000);

  // ==========================================
  // 🎨 Haptic Feedback
  // ==========================================

  /// تأخير بسيط بعد Haptic Feedback
  static const Duration hapticDelay = Duration(milliseconds: 50);

  // ==========================================
  // 📊 Analytics & Logging
  // ==========================================

  /// فترة إرسال تقارير الأداء
  static const Duration analyticsReportInterval = Duration(hours: 1);

  /// فترة حفظ السجلات
  static const Duration logSaveInterval = Duration(minutes: 5);

  // ==========================================
  // 🎯 Helper Methods
  // ==========================================

  /// الحصول على مدة العد التنازلي حسب الخطورة
  static Duration getCountdownDuration(double severityScore) {
    if (severityScore >= 72.0) {
      return countdownCritical;
    } else if (severityScore >= 40.0) {
      return countdownModerate;
    } else {
      return countdownLow;
    }
  }

  /// تحويل Duration إلى نص عربي
  static String toArabicString(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} ${duration.inDays == 1 ? 'يوم' : 'أيام'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} ${duration.inHours == 1 ? 'ساعة' : 'ساعات'}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} ${duration.inMinutes == 1 ? 'دقيقة' : 'دقائق'}';
    } else {
      return '${duration.inSeconds} ${duration.inSeconds == 1 ? 'ثانية' : 'ثواني'}';
    }
  }

  /// تنسيق Duration كـ MM:SS
  static String formatMMSS(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// تنسيق Duration كـ HH:MM:SS
  static String formatHHMMSS(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
