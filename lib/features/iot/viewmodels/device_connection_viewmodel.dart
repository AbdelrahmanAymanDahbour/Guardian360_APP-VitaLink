import 'package:flutter/material.dart';

class DeviceConnectionViewModel extends ChangeNotifier {
  bool isScanning = true;
  bool isConnected = false;

  // دالة لبدء عملية البحث
  void startScanning() {
    isScanning = true;
    isConnected = false;
    notifyListeners();

    // محاكاة لعملية البحث (4 ثواني)
    Future.delayed(const Duration(seconds: 4), () {
      isScanning = false;
      notifyListeners();
    });
  }

  // دالة للاتصال بالجهاز
  void connectToDevice() {
    isConnected = true;
    notifyListeners();
    // هون رح ينكتب كود البلوتوث الحقيقي لاحقاً
  }

  // دالة لفصل الجهاز
  void disconnectDevice() {
    isConnected = false;
    startScanning(); // نرجع نبحث من جديد
  }
}
