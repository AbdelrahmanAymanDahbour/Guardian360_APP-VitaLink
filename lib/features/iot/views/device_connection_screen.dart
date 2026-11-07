import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodels/device_connection_viewmodel.dart';

class DeviceConnectionScreen extends StatelessWidget {
  const DeviceConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeviceConnectionViewModel()..startScanning(),
      child: const _DeviceConnectionContent(),
    );
  }
}

class _DeviceConnectionContent extends StatelessWidget {
  const _DeviceConnectionContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DeviceConnectionViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "إدارة الأجهزة",
          style: GoogleFonts.cairo(
            color: AppColors.textBlack,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textBlack,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // زر إعادة البحث
          if (!viewModel.isScanning && !viewModel.isConnected)
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.primaryDark,
              ),
              onPressed: () => viewModel.startScanning(),
            ).animate().fadeIn(),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),

            // 1. منطقة الرادار (Scanning Area) 📡
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // دوائر الرادار الخلفية
                    for (int i = 0; i < 4; i++)
                      Container(
                        width: 100 + (i * 60.0),
                        height: 100 + (i * 60.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryDark.withOpacity(0.08),
                            width: 1,
                          ),
                        ),
                      ),

                    // الدائرة الملونة المتحركة
                    Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: viewModel.isConnected
                                ? Colors.green.withOpacity(0.1)
                                : AppColors.primaryDark.withOpacity(0.05),
                          ),
                          child: Icon(
                            viewModel.isConnected
                                ? Icons.check_circle_rounded
                                : Icons.bluetooth_searching_rounded,
                            size: 60,
                            color: viewModel.isConnected
                                ? Colors.green
                                : AppColors.primaryDark,
                          ),
                        )
                        .animate(target: viewModel.isScanning ? 1 : 0)
                        .shimmer(
                          duration: 1500.ms,
                          color: AppColors.primaryDark.withOpacity(0.5),
                        )
                        .scaleXY(
                          begin: 0.9,
                          end: 1.1,
                          duration: 1000.ms,
                          curve: Curves.easeInOut,
                        )
                        .then()
                        .scaleXY(begin: 1.1, end: 0.9),

                    // تأثير الموجات عند البحث
                    if (viewModel.isScanning)
                      Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.primaryDark.withOpacity(0.0),
                                  AppColors.primaryDark.withOpacity(0.15),
                                ],
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .rotate(duration: 3000.ms),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 2. حالة النظام النصية
            Text(
              viewModel.isConnected
                  ? "تم الاتصال بنجاح"
                  : (viewModel.isScanning
                        ? "جارِ البحث عن أجهزة..."
                        : "تم العثور على جهاز!"),
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textBlack,
              ),
            ).animate(key: ValueKey(viewModel.isScanning)).fadeIn(),

            Text(
              viewModel.isConnected
                  ? "جهازك محمي ومتصل بالنظام"
                  : "تأكد من تشغيل جهاز Guardian-X1",
              style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textGrey),
            ),

            const SizedBox(height: 40),

            // 3. قائمة الأجهزة المكتشفة (تظهر بعد البحث)
            if (!viewModel.isScanning)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "الأجهزة القريبة",
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // كرت الجهاز
                      GestureDetector(
                        onTap: () {
                          if (!viewModel.isConnected) {
                            viewModel.connectToDevice();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "تم ربط Guardian-X1 بنجاح! 📟✅",
                                      style: GoogleFonts.cairo(),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            // خيار لفك الارتباط
                            _showDisconnectDialog(context, viewModel);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: viewModel.isConnected
                                ? Colors.green.withOpacity(0.05)
                                : AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: viewModel.isConnected
                                  ? Colors.green
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              // أيقونة الجهاز بدل الصورة المؤقتة
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: viewModel.isConnected
                                      ? Colors.green.withOpacity(0.1)
                                      : AppColors.primaryDark.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.developer_board_rounded,
                                  color: viewModel.isConnected
                                      ? Colors.green
                                      : AppColors.primaryDark,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Guardian-X1",
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textBlack,
                                    ),
                                  ),
                                  Text(
                                    viewModel.isConnected
                                        ? "Connected"
                                        : "Ready to pair",
                                    style: GoogleFonts.cairo(
                                      color: viewModel.isConnected
                                          ? Colors.green
                                          : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (viewModel.isConnected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryDark,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "اتصال",
                                    style: GoogleFonts.cairo(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ).animate().slideY(begin: 0.2, end: 0),
                      ),
                    ],
                  ),
                ).animate().slideY(begin: 1, end: 0, duration: 500.ms),
              ),
          ],
        ),
      ),
    );
  }

  // ديالوج فك الارتباط
  void _showDisconnectDialog(
    BuildContext context,
    DeviceConnectionViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "فك ارتباط الجهاز؟",
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: AppColors.textBlack,
          ),
        ),
        content: Text(
          "هل أنت متأكد أنك تريد فصل جهاز Guardian-X1؟ ستفقد ميزات التتبع الحي.",
          style: GoogleFonts.cairo(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr(), style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
            ),
            onPressed: () {
              viewModel.disconnectDevice();
              Navigator.pop(context);
            },
            child: Text(
              "فك الارتباط",
              style: GoogleFonts.cairo(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
