import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/place_model.dart';
import '../../../core/constants/app_colors.dart';

/// ==========================================
/// 🎨 Canvas Marker Engine (Super Ultra Pro Final)
/// ==========================================
/// محرك رسم ذكي يقوم بتحويل الـ Icons الخاصة بفلاتر إلى
/// علامات (Markers) عالية الدقة على الخريطة برمجياً.
class MarkerConfig {
  // 🧠 ذاكرة التخزين المؤقت للأيقونات المرسومة (لتسريع الخريطة ومنع التقطيع)
  static final Map<PlaceType, BitmapDescriptor> _canvasIconsCache = {};
  static BitmapDescriptor? _userLocationIcon;

  // 🛡️ حماية التهيئة من التكرار:
  // - تمنع إعادة رسم الأيقونات إذا كانت جاهزة.
  // - تمنع تشغيل أكثر من عملية رسم بنفس الوقت.
  // - تسمح بإعادة المحاولة إذا فشلت التهيئة.
  static bool _isInitialized = false;
  static Future<void>? _initializationFuture;

  /// 🚀 دالة التهيئة: ترسم كل الأيقونات وتحفظها بالذاكرة قبل فتح الخريطة.
  ///
  /// هذه الدالة idempotent:
  /// - إذا الأيقونات جاهزة، لا تعيد الرسم.
  /// - إذا التهيئة شغالة حاليًا، ترجع نفس الـ Future.
  /// - إذا فشلت التهيئة، تسمح بمحاولة لاحقة.
  static Future<void> initCustomMarkers() {
    if (_isInitialized) {
      return Future<void>.value();
    }

    final existingFuture = _initializationFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    _initializationFuture = _initCustomMarkersInternal();
    return _initializationFuture!;
  }

  static Future<void> _initCustomMarkersInternal() async {
    try {
      // رسم أيقونات الأماكن
      _canvasIconsCache[PlaceType.hospital] = await _createCanvasMarker(
        Icons.local_hospital_rounded,
        const Color(0xFFD32F2F),
        Colors.white,
      );

      _canvasIconsCache[PlaceType.clinic] = await _createCanvasMarker(
        Icons.medical_services_rounded,
        const Color(0xFF00796B),
        Colors.white,
      );

      _canvasIconsCache[PlaceType.pharmacy] = await _createCanvasMarker(
        Icons.local_pharmacy_rounded,
        const Color(0xFF388E3C),
        Colors.white,
      );

      _canvasIconsCache[PlaceType.security] = await _createCanvasMarker(
        Icons.local_police_rounded,
        const Color(0xFF1976D2),
        Colors.white,
      );

      _canvasIconsCache[PlaceType.fireStation] = await _createCanvasMarker(
        Icons.local_fire_department_rounded,
        const Color(0xFFF57C00),
        Colors.white,
      );

      _canvasIconsCache[PlaceType.other] = await _createCanvasMarker(
        Icons.place_rounded,
        Colors.grey.shade700,
        Colors.white,
      );

      // رسم أيقونة المستخدم (نقطة حمراء دموية/خمرية فخمة)
      _userLocationIcon = await _createCanvasMarker(
        Icons.my_location_rounded,
        const Color(0xFF6B0000),
        Colors.white,
        size: 140,
      );

      _isInitialized = true;
      debugPrint('✅ Canvas Markers Initialized Successfully');
    } catch (e) {
      _isInitialized = false;
      debugPrint('❌ Failed to draw canvas markers: $e');
    } finally {
      _initializationFuture = null;
    }
  }

  /// 🖌️ السحر: رسم الأيقونة باستخدام Canvas وتحويلها لـ BitmapDescriptor
  static Future<BitmapDescriptor> _createCanvasMarker(
    IconData icon,
    Color bgColor,
    Color iconColor, {
    int size = 120,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // 1. رسم الظل الفخم (Shadow)
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawCircle(Offset(size / 2, size / 2 + 6), size / 2.6, shadowPaint);

    // 2. رسم الدائرة الخلفية الملونة
    final Paint bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.6, bgPaint);

    // 3. رسم إطار أبيض أنيق (Border)
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.6, borderPaint);

    // 4. رسم الأيقونة (Icon) في المنتصف
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size / 2.1,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: iconColor,
      ),
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    // تحويل الرسمة إلى صورة رقمية
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size,
      size,
    );

    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }

    return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
  }

  /// 🎯 الحصول على العلامة المرسومة (من الكاش)
  static BitmapDescriptor getMarkerIcon(PlaceType type) {
    if (_canvasIconsCache.containsKey(type)) {
      return _canvasIconsCache[type]!;
    }

    // خطة بديلة لو صار خطأ بالرسم
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  }

  /// 🎨 ألوان الكروت (UI Cards)
  static Color getCardIconColor(PlaceType type) {
    switch (type) {
      case PlaceType.hospital:
        return const Color(0xFFD32F2F);
      case PlaceType.clinic:
        return const Color(0xFF00796B);
      case PlaceType.security:
        return const Color(0xFF1976D2);
      case PlaceType.pharmacy:
        return const Color(0xFF388E3C);
      case PlaceType.fireStation:
        return const Color(0xFFF57C00);
      case PlaceType.other:
        return AppColors.textGrey;
    }
  }

  static Color getCardIconBackgroundColor(PlaceType type) {
    return getCardIconColor(type).withOpacity(0.12);
  }

  static IconData getIcon(PlaceType type) {
    switch (type) {
      case PlaceType.hospital:
        return Icons.local_hospital_rounded;
      case PlaceType.clinic:
        return Icons.medical_services_rounded;
      case PlaceType.security:
        return Icons.local_police_rounded;
      case PlaceType.pharmacy:
        return Icons.local_pharmacy_rounded;
      case PlaceType.fireStation:
        return Icons.local_fire_department_rounded;
      case PlaceType.other:
        return Icons.place_rounded;
    }
  }

  /// 🏗️ البناء الهندسي للماركر (مع الأولوية Z-Index)
  static Marker createMarker({
    required PlaceModel place,
    required String snippet,
    required VoidCallback onTap,
  }) {
    final double markerZIndex =
        (place.type == PlaceType.hospital || place.type == PlaceType.security)
        ? 10.0
        : 1.0;

    return Marker(
      markerId: MarkerId(place.id),
      position: place.location,
      zIndex: markerZIndex,
      infoWindow: InfoWindow.noText,
      icon: getMarkerIcon(place.type),
      onTap: onTap,
    );
  }

  /// 📍 بناء ماركر المستخدم (نقطة الارتكاز)
  static Marker createUserLocationMarker(LatLng position) {
    return Marker(
      markerId: const MarkerId('user_current_location'),
      position: position,
      zIndex: 99.0,
      icon:
          _userLocationIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
  }
}
