import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../accident_detection/viewmodels/accident_monitor_viewmodel.dart';
import '../viewmodels/sos_viewmodel.dart';

class SOSCountdownScreen extends StatelessWidget {
  final double? initialImpact;
  final double? initialRotation;
  final String triggerReason;

  const SOSCountdownScreen({
    super.key,
    this.initialImpact,
    this.initialRotation,
    this.triggerReason = 'manual_sos',
  });

  @override
  Widget build(BuildContext context) {
    final accidentMonitor = context.read<AccidentMonitorViewModel>();
    final isManualSOS = triggerReason.trim().toLowerCase() == 'manual_sos';

    return ChangeNotifierProvider<SOSViewModel>(
      create: (_) {
        final vm = SOSViewModel(
          accidentMonitor: accidentMonitor,
          bindToAccidentMonitor: !isManualSOS,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isManualSOS) {
            vm.startManualSOS(triggerReason: 'manual_sos');
            return;
          }

          vm.startSmartMonitoring();

          if (initialImpact != null && initialRotation != null) {
            vm.handleDetectedAccident(
              gForce: initialImpact!,
              rotation: initialRotation!,
              triggerReason: triggerReason,
            );
          }
        });

        return vm;
      },
      child: _SosVoiceLifecycle(
        isManualSOS: isManualSOS,
        child: const _SOSContent(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voice lifecycle wrapper
// ---------------------------------------------------------------------------

class _SosVoiceLifecycle extends StatefulWidget {
  const _SosVoiceLifecycle({required this.isManualSOS, required this.child});

  final bool isManualSOS;
  final Widget child;

  @override
  State<_SosVoiceLifecycle> createState() => _SosVoiceLifecycleState();
}

class _SosVoiceLifecycleState extends State<_SosVoiceLifecycle> {
  static const String _soundPreferenceKey = 'setting_sound';

  final FlutterTts _tts = FlutterTts();

  bool _hasSpokenOpeningAnnouncement = false;
  bool _hasStoppedForTerminalState = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_speakOpeningAnnouncement());
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentState = context.select<SOSViewModel, SOSState>(
      (viewModel) => viewModel.currentState,
    );

    if (_isTerminalState(currentState) && !_hasStoppedForTerminalState) {
      _hasStoppedForTerminalState = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_stopTts());
      });
    }

    return widget.child;
  }

  Future<void> _speakOpeningAnnouncement() async {
    if (_hasSpokenOpeningAnnouncement) return;

    _hasSpokenOpeningAnnouncement = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      if (!mounted) return;

      final soundEnabled = prefs.getBool(_soundPreferenceKey) ?? true;
      if (!soundEnabled) return;

      final languageCode = context.locale.languageCode.toLowerCase();
      final voiceLanguage = languageCode.startsWith('ar') ? 'ar' : 'en-US';
      final messageKey = widget.isManualSOS
          ? 'sos.voice.opening_manual'
          : 'sos.voice.opening_auto';

      await _tts.setLanguage(voiceLanguage);
      await _tts.setSpeechRate(0.45);
      await _tts.speak(messageKey.tr());
    } catch (_) {
      // Voice feedback is best-effort and must never affect SOS flow.
    }
  }

  Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Voice feedback is best-effort and must never affect SOS flow.
    }
  }

  bool _isTerminalState(SOSState state) {
    return state == SOSState.cancelled ||
        state == SOSState.alertSent ||
        state == SOSState.error;
  }

  @override
  void dispose() {
    unawaited(_stopTts());
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Main content widget
// ---------------------------------------------------------------------------

class _SOSContent extends StatelessWidget {
  const _SOSContent();

  static const Color _dangerRed = Color(0xFF990000);
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _successGreen = Color(0xFF0F3D2E);
  static const Color _cancelGreen = Color(0xFF1B5E20);
  static const Color _errorRed = Color(0xFF4A0D0D);

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SOSViewModel>();
    final bgColor = _resolveBackgroundColor(viewModel.currentState);

    return PopScope(
      canPop: !viewModel.isEmergencyFlowActive,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: double.infinity,
          color: bgColor,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_shouldShowRadar(viewModel.currentState))
                ...List.generate(4, (index) => _buildRadarCircle(index)),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final shortestSide = MediaQuery.sizeOf(
                      context,
                    ).shortestSide;
                    final centerSize = shortestSide < 360 ? 200.0 : 230.0;
                    final iconSize = shortestSide < 360 ? 120.0 : 150.0;

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: shortestSide < 360 ? 14 : 20,
                            vertical: 16,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildTopBar(context, viewModel),
                              const SizedBox(height: 20),
                              _buildAssistantBubble(viewModel),
                              const SizedBox(height: 16),
                              _buildEmergencyHint(viewModel),
                              const SizedBox(height: 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildCenterContent(
                                  viewModel,
                                  centerSize: centerSize,
                                  iconSize: iconSize,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildSeverityInfo(viewModel),
                              const SizedBox(height: 16),
                              _buildStatusMessage(viewModel),
                              if (viewModel.currentState ==
                                  SOSState.callingContact)
                                _buildCallingDetails(viewModel),
                              const SizedBox(height: 18),
                              if (kDebugMode &&
                                  (viewModel.currentState ==
                                          SOSState.monitoring ||
                                      viewModel.currentState ==
                                          SOSState.countingDown ||
                                      viewModel.currentState ==
                                          SOSState.callingContact))
                                _buildDebugVoiceControls(context, viewModel),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 450),
                                child: _buildBottomAction(context, viewModel),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  bool _shouldShowRadar(SOSState state) {
    return state == SOSState.countingDown || state == SOSState.listening;
  }

  Color _resolveBackgroundColor(SOSState state) {
    switch (state) {
      case SOSState.cancelled:
        return _cancelGreen;
      case SOSState.alertSent:
        return _successGreen;
      case SOSState.sendingAlert:
      case SOSState.callingContact:
        return _darkBackground;
      case SOSState.error:
        return _errorRed;
      case SOSState.monitoring:
      case SOSState.evaluating:
      case SOSState.countingDown:
      case SOSState.listening:
        return _dangerRed;
    }
  }

  // -------------------------------------------------------------------------
  // Radar circles
  // -------------------------------------------------------------------------

  Widget _buildRadarCircle(int index) {
    return IgnorePointer(
      child:
          Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(20),
                    width: 2,
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .scaleXY(
                begin: 0.2,
                end: 2.4,
                duration: 2200.ms,
                delay: (index * 350).ms,
              )
              .fadeOut(duration: 1500.ms),
    );
  }

  // -------------------------------------------------------------------------
  // Top bar
  // -------------------------------------------------------------------------

  Widget _buildTopBar(BuildContext context, SOSViewModel viewModel) {
    return Row(
      children: [
        _buildRoundIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () {
            if (viewModel.isEmergencyFlowActive) return;
            HapticFeedback.lightImpact();
            Navigator.maybePop(context);
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'sos.protocol_title'.tr(),
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const SizedBox(width: 48, height: 48),
      ],
    );
  }

  Widget _buildRoundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: 'sos.semantics_back'.tr(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Assistant bubble
  // -------------------------------------------------------------------------

  Widget _buildAssistantBubble(SOSViewModel viewModel) {
    final listening = viewModel.currentState == SOSState.listening;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: 1,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(80),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              listening ? Icons.warning_amber_rounded : Icons.smart_toy_rounded,
              color: listening ? Colors.amberAccent : Colors.white,
              size: 22,
            ).animate(target: listening ? 1 : 0).shimmer(duration: 500.ms),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                viewModel.aiVoiceText,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ).animate().slideY(begin: -0.3, end: 0).fadeIn(duration: 400.ms),
    );
  }

  // -------------------------------------------------------------------------
  // Emergency hint strip
  // -------------------------------------------------------------------------

  Widget _buildEmergencyHint(SOSViewModel viewModel) {
    final text = switch (viewModel.currentState) {
      SOSState.monitoring => 'sos.hint_monitoring'.tr(),
      SOSState.countingDown ||
      SOSState.listening => 'sos.hint_counting_down'.tr(),
      SOSState.sendingAlert => 'sos.hint_sending'.tr(),
      SOSState.alertSent => 'sos.hint_sent'.tr(),
      SOSState.cancelled => 'sos.hint_cancelled'.tr(),
      SOSState.error => 'sos.hint_error'.tr(),
      SOSState.evaluating => 'sos.hint_evaluating'.tr(),
      SOSState.callingContact => 'sos.hint_calling'.tr(),
    };

    final icon = switch (viewModel.currentState) {
      SOSState.monitoring => Icons.shield_outlined,
      SOSState.countingDown || SOSState.listening => Icons.touch_app_rounded,
      SOSState.sendingAlert => Icons.cloud_upload_rounded,
      SOSState.alertSent => Icons.verified_rounded,
      SOSState.cancelled => Icons.check_circle_outline_rounded,
      SOSState.error => Icons.error_outline_rounded,
      SOSState.evaluating => Icons.manage_search_rounded,
      SOSState.callingContact => Icons.call_rounded,
    };

    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.start,
              style: GoogleFonts.cairo(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  // -------------------------------------------------------------------------
  // Centre content (state-driven)
  // -------------------------------------------------------------------------

  Widget _buildCenterContent(
    SOSViewModel viewModel, {
    required double centerSize,
    required double iconSize,
  }) {
    switch (viewModel.currentState) {
      case SOSState.evaluating:
        return Container(
          key: const ValueKey('evaluating'),
          width: centerSize,
          height: centerSize,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 8,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );

      case SOSState.countingDown:
      case SOSState.listening:
        return SizedBox(
          key: const ValueKey('countdown'),
          width: centerSize,
          height: centerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: centerSize,
                height: centerSize,
                child: CircularProgressIndicator(
                  value: viewModel.progressValue,
                  strokeWidth: 12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  backgroundColor: Colors.white.withAlpha(35),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    child: Text(
                      viewModel.countdown.toString(),
                      style: GoogleFonts.montserrat(
                        fontSize: 90,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    viewModel.countdownLabel,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case SOSState.alertSent:
        return Icon(
          Icons.check_circle_rounded,
          key: const ValueKey('sent'),
          size: iconSize,
          color: Colors.white,
        ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack);

      case SOSState.cancelled:
        return Icon(
          Icons.shield_rounded,
          key: const ValueKey('cancelled'),
          size: iconSize,
          color: Colors.white,
        ).animate().scale(duration: 450.ms, curve: Curves.easeOutBack);

      case SOSState.error:
        return Icon(
          Icons.error_outline_rounded,
          key: const ValueKey('error'),
          size: iconSize,
          color: Colors.white,
        ).animate().shake(duration: 500.ms);

      case SOSState.callingContact:
        return SizedBox(
          key: const ValueKey('calling'),
          width: centerSize,
          height: centerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: centerSize,
                height: centerSize,
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                ),
              ),
              Container(
                width: centerSize * 0.85,
                height: centerSize * 0.85,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(30),
                    width: 2,
                  ),
                ),
                child: Center(
                  child:
                      Icon(
                            Icons.call_rounded,
                            size: iconSize * 0.85,
                            color: Colors.white,
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(begin: 1, end: 1.08, duration: 650.ms),
                ),
              ),
            ],
          ),
        );

      case SOSState.sendingAlert:
        return Icon(
              Icons.emergency_share_rounded,
              key: const ValueKey('sending'),
              size: iconSize,
              color: Colors.white,
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: -10, end: 10, duration: 900.ms);

      case SOSState.monitoring:
        return Container(
              key: const ValueKey('monitoring'),
              width: centerSize,
              height: centerSize,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(30), width: 2),
              ),
              child: Icon(
                Icons.health_and_safety_rounded,
                color: Colors.white,
                size: centerSize * 0.4,
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1, end: 1.04, duration: 1100.ms);
    }
  }

  // -------------------------------------------------------------------------
  // Severity info panel  (fully localised — no hardcoded Arabic strings)
  // -------------------------------------------------------------------------

  Widget _buildSeverityInfo(SOSViewModel viewModel) {
    // "hasData" is determined by whether there is a real severity score, not
    // by comparing against a language-specific string.
    final hasData =
        viewModel.currentState != SOSState.monitoring &&
        viewModel.severityScore > 0.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: hasData ? 1 : 0.75,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Column(
          children: [
            Text(
              hasData
                  ? 'sos.severity_analysis'.tr()
                  : 'sos.monitoring_mode'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildInfoChip(
                  label: 'sos.chip_severity'.tr(),
                  value: viewModel.detectedSeverity,
                ),
                _buildInfoChip(
                  label: 'sos.chip_score'.tr(),
                  value: viewModel.severityScoreText,
                ),
                _buildInfoChip(
                  label: 'sos.chip_impact'.tr(),
                  value: viewModel.impactText,
                ),
                _buildInfoChip(
                  label: 'sos.chip_rotation'.tr(),
                  value: viewModel.rotationText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required String label, required String value}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 88),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(45),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: GoogleFonts.cairo(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Status message
  // -------------------------------------------------------------------------

  Widget _buildStatusMessage(SOSViewModel viewModel) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Text(
        viewModel.statusMessage,
        key: ValueKey(viewModel.statusMessage),
        textAlign: TextAlign.center,
        style: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.5,
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.15, end: 0),
    );
  }

  // -------------------------------------------------------------------------
  // Calling Details
  // -------------------------------------------------------------------------

  Widget _buildCallingDetails(SOSViewModel viewModel) {
    final contactName =
        viewModel.activeCallContactName ?? 'sos.call_contact_fallback'.tr();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Text(
            'sos.call_opening_description'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${'sos.call_contact_label'.tr()}: $contactName',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Debug voice simulation (debug builds only)
  // -------------------------------------------------------------------------

  Widget _buildDebugVoiceControls(
    BuildContext context,
    SOSViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Text(
            'sos.debug_voice_simulation'.tr(),
            style: GoogleFonts.cairo(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSecretDevButton(
                label: 'أنا بخير',
                onTap: () {
                  HapticFeedback.lightImpact();
                  viewModel.simulateVoiceCommand('أنا بخير');
                },
              ),
              _buildSecretDevButton(
                label: 'حادث',
                onTap: () {
                  HapticFeedback.lightImpact();
                  viewModel.simulateVoiceCommand('حادث');
                },
              ),
              _buildSecretDevButton(
                label: 'اتصال',
                onTap: () {
                  HapticFeedback.lightImpact();
                  PrimaryScrollController.of(context).animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                  );
                  viewModel.initiateCallFlow();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Bottom action button
  // -------------------------------------------------------------------------

  Widget _buildBottomAction(BuildContext context, SOSViewModel viewModel) {
    if (viewModel.canCancel) {
      return Semantics(
        button: true,
        label: 'sos.semantics_cancel'.tr(),
        child: GestureDetector(
          key: const ValueKey('cancel_button'),
          onTap: () {
            HapticFeedback.heavyImpact();
            viewModel.cancelSOS();
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(45),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.close_rounded, color: _dangerRed, size: 28),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'sos.cancel_emergency'.tr(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _dangerRed,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().slideY(begin: 0.8, end: 0, curve: Curves.easeOutCubic);
    }

    final isFinished =
        viewModel.currentState == SOSState.alertSent ||
        viewModel.currentState == SOSState.cancelled ||
        viewModel.currentState == SOSState.error;

    return TextButton.icon(
      key: const ValueKey('back_button'),
      onPressed: isFinished
          ? () {
              HapticFeedback.lightImpact();
              Navigator.maybePop(context);
            }
          : null,
      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
      label: Text(
        viewModel.currentState == SOSState.alertSent
            ? 'sos.back_after_sent'.tr()
            : 'sos.back_to_previous'.tr(),
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  // -------------------------------------------------------------------------
  // Dev helper button
  // -------------------------------------------------------------------------

  Widget _buildSecretDevButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: 'Debug $label',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(12)),
          ),
          child: Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
