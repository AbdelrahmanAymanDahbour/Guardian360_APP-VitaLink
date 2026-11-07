import 'package:flutter/material.dart';

class OnboardingPage {
  final IconData icon;
  final String titleKey;
  final String descriptionKey;

  const OnboardingPage({
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
  });
}

class OnboardingViewModel extends ChangeNotifier {
  final PageController pageController = PageController();
  int currentIndex = 0;

  final List<OnboardingPage> pages = const [
    OnboardingPage(
      icon: Icons.security_rounded,
      titleKey: 'onboarding.slides.smart_guardian.title',
      descriptionKey: 'onboarding.slides.smart_guardian.description',
    ),
    OnboardingPage(
      icon: Icons.emergency_share_outlined,
      titleKey: 'onboarding.slides.emergency_response.title',
      descriptionKey: 'onboarding.slides.emergency_response.description',
    ),
    OnboardingPage(
      icon: Icons.monitor_heart_outlined,
      titleKey: 'onboarding.slides.health_awareness.title',
      descriptionKey: 'onboarding.slides.health_awareness.description',
    ),
  ];

  bool get isLastPage => currentIndex == pages.length - 1;

  void onPageChanged(int index) {
    currentIndex = index;
    notifyListeners();
  }

  void goNext() {
    if (currentIndex < pages.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
