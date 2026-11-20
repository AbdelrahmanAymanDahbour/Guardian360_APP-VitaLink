import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../sos/views/sos_countdown_screen.dart';
import '../models/ai_chat_message.dart';
import '../models/first_aid_instruction.dart';
import '../services/first_aid_content_service.dart';
import '../viewmodels/ai_chat_viewmodel.dart';

class AIChatScreen extends StatelessWidget {
  const AIChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AIChatViewModel(),
      child: const _AIChatContent(),
    );
  }
}

class _AIChatContent extends StatefulWidget {
  const _AIChatContent();

  @override
  State<_AIChatContent> createState() => _AIChatContentState();
}

class _AIChatContentState extends State<_AIChatContent> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const double _horizontalPadding = 16;
  static const double _dockRadius = 22;
  static const double _chipRadius = 17;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _handleSendMessage({String? text}) async {
    final userText = (text ?? _controller.text).trim();
    if (userText.isEmpty) return;

    _controller.clear();

    final viewModel = context.read<AIChatViewModel>();

    await viewModel.sendMessage(userText, locale: context.locale.languageCode);
    _scrollToBottom();

    if (!mounted) return;

    if (viewModel.consumeSosNavigationRequest()) {
      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SOSCountdownScreen()),
      );
    }
  }

  Future<void> _handleVoicePressed() async {
    final viewModel = context.read<AIChatViewModel>();

    if (!viewModel.canUseVoiceInput) return;

    FocusScope.of(context).unfocus();

    final recognizedText = await viewModel.startVoiceInput(
      locale: context.locale.languageCode,
    );

    if (!mounted) return;

    final pendingText = viewModel.consumePendingVoiceText();
    final voiceText = (recognizedText ?? pendingText)?.trim();

    if (voiceText == null || voiceText.isEmpty) {
      _scrollToBottom();
      return;
    }

    await _handleSendMessage(text: voiceText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Selector<AIChatViewModel, _AIContentState>(
              selector: (_, viewModel) => _AIContentState(
                messagesLength: viewModel.messages.length,
                isSpeaking: viewModel.isSpeaking,
              ),
              builder: (context, state, _) {
                final viewModel = context.read<AIChatViewModel>();

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: state.hasMessages
                      ? _buildMessagesList(viewModel)
                      : _buildEmptyState(),
                );
              },
            ),
          ),
          Selector<AIChatViewModel, bool>(
            selector: (_, viewModel) => viewModel.isLoading,
            builder: (context, isLoading, _) {
              return isLoading ? _buildThinkingIndicator() : const SizedBox();
            },
          ),
          Selector<AIChatViewModel, _AIInputState>(
            selector: (_, viewModel) => _AIInputState(
              isLoading: viewModel.isLoading,
              isListening: viewModel.isListening,
              currentVoiceText: viewModel.currentVoiceText,
              voiceStatusMessage: viewModel.voiceStatusMessage,
              currentSoundLevel: viewModel.currentSoundLevel,
              voiceToneSignal: viewModel.voiceToneSignal,
            ),
            builder: (context, state, _) {
              return _buildInputArea(context.read<AIChatViewModel>());
            },
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surfaceWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 70,
      leading: IconButton(
        icon: Transform.scale(
          scaleX: Directionality.of(context) == ui.TextDirection.rtl ? -1 : 1,
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textBlack,
            size: 21,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRobotAvatar(size: 38, iconSize: 21),
          const SizedBox(width: 9),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.aiTitle.tr(),
                style: GoogleFonts.cairo(
                  color: AppColors.textBlack,
                  fontWeight: FontWeight.w900,
                  fontSize: 19.5,
                  height: 1,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Selector<AIChatViewModel, _AIStatusState>(
                selector: (_, viewModel) => _AIStatusState(
                  isLoading: viewModel.isLoading,
                  isListening: viewModel.isListening,
                ),
                builder: (context, state, _) => _buildStatusBadge(state),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(_AIStatusState state) {
    final isThinking = state.isLoading;
    final isListening = state.isListening;

    final statusColor = isListening
        ? AppColors.primaryRed
        : isThinking
        ? AppColors.primaryRed
        : Colors.green.shade700;

    final statusText = isListening
        ? AppStrings.aiListening.tr()
        : isThinking
        ? AppStrings.aiStatusThinking.tr()
        : AppStrings.aiStatusReady.tr();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.24),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          statusText,
          style: GoogleFonts.cairo(
            color: statusColor,
            fontSize: 10.8,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildRobotAvatar({
    required double size,
    required double iconSize,
    bool elevated = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withValues(alpha: 0.075),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primaryDark.withValues(alpha: 0.095),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.smart_toy_rounded,
        color: AppColors.primaryDark,
        size: iconSize,
      ),
    );
  }

  Widget _buildMessagesList(AIChatViewModel viewModel) {
    return ListView.builder(
      key: const ValueKey('ai_messages'),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 10),
      physics: const BouncingScrollPhysics(),
      itemCount: viewModel.messages.length,
      itemBuilder: (context, index) {
        return _buildChatBubble(viewModel.messages[index], viewModel);
      },
    );
  }

  Widget _buildChatBubble(AiChatMessage message, AIChatViewModel viewModel) {
    final isUser = message.isUser;
    final isWarning = message.isWarning;
    final displayText = message.isLocalizationKey
        ? message.text.tr()
        : message.text;
    final isSpeakingThisMessage =
        message.isAi && viewModel.isSpeakingText(displayText);

    final bubbleColor = isWarning
        ? AppColors.primaryRed
        : isUser
        ? AppColors.primaryDark
        : AppColors.surfaceWhite;

    final textColor = isUser || isWarning ? Colors.white : AppColors.textBlack;

    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.88,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(20),
            topEnd: const Radius.circular(20),
            bottomStart: isUser
                ? const Radius.circular(20)
                : const Radius.circular(7),
            bottomEnd: isUser
                ? const Radius.circular(7)
                : const Radius.circular(20),
          ),
          border: isUser || isWarning
              ? null
              : Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.038),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              displayText,
              textAlign: TextAlign.start,
              style: GoogleFonts.cairo(
                color: textColor,
                fontSize: 13.7,
                height: 1.58,
                fontWeight: isWarning ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (message.isAi) ...[
              const SizedBox(height: 7),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _toggleSpeakMessage(viewModel, displayText),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      isSpeakingThisMessage
                          ? Icons.stop_circle_rounded
                          : Icons.volume_up_rounded,
                      size: 18,
                      color: isWarning
                          ? Colors.white70
                          : isSpeakingThisMessage
                          ? AppColors.primaryRed
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.035, end: 0),
    );
  }

  Future<void> _toggleSpeakMessage(
    AIChatViewModel viewModel,
    String text,
  ) async {
    await viewModel.toggleSpeakResponse(
      text,
      locale: context.locale.languageCode,
    );
  }

  String _voiceStatusText(String? status) {
    final safeStatus = status?.trim();
    if (safeStatus == null || safeStatus.isEmpty) {
      return AppStrings.aiListening.tr();
    }

    if (safeStatus == AppStrings.aiListening) {
      return AppStrings.aiListening.tr();
    }

    return safeStatus;
  }

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.aiStatusThinking.tr(),
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 160.ms),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      key: const ValueKey('ai_empty'),
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight < 0
            ? 0.0
            : constraints.maxHeight;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            _horizontalPadding,
            20,
            _horizontalPadding,
            14,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight - 34),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFreeHeroIntro(),
                Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: _buildFirstAidDock(),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 280.ms);
      },
    );
  }

  Widget _buildFreeHeroIntro() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        _buildPulsingHeroAvatar(),
        const SizedBox(height: 13),
        Text(
          AppStrings.aiTitle.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.textBlack,
            height: 1.08,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            AppStrings.aiEmptySubtitle.tr(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPulsingHeroAvatar() {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryDark.withValues(alpha: 0.045),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 0.92, end: 1.08, duration: 1450.ms)
              .fade(begin: 0.35, end: 0.78, duration: 1450.ms),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryDark.withValues(alpha: 0.055),
              border: Border.all(
                color: AppColors.primaryDark.withValues(alpha: 0.06),
              ),
            ),
          ),
          Icon(Icons.smart_toy_rounded, color: AppColors.primaryDark, size: 54)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.045, duration: 1200.ms),
        ],
      ),
    ).animate().fadeIn(duration: 260.ms).scaleXY(begin: 0.96, end: 1);
  }

  Widget _buildFirstAidDock() {
    const instructions = FirstAidContentService.quickActions;

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(_dockRadius),
        border: Border.all(
          color: AppColors.primaryRed.withValues(alpha: 0.050),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.010),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFirstAidDockHeader(),
          const SizedBox(height: 9),
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: instructions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return _buildFirstAidQuickChip(instructions[index], index);
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.018, end: 0);
  }

  Widget _buildFirstAidDockHeader() {
    return Row(
      children: [
        Container(
          width: 29,
          height: 29,
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withValues(alpha: 0.065),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.medical_services_rounded,
            color: AppColors.primaryRed,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppStrings.aiQuickFirstAidTitle.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 14.4,
              height: 1.25,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDark,
              letterSpacing: -0.1,
            ),
          ),
        ),
        Icon(
          Icons.swipe_rounded,
          size: 17,
          color: AppColors.primaryDark.withValues(alpha: 0.34),
        ),
      ],
    );
  }

  Widget _buildFirstAidQuickChip(FirstAidInstruction instruction, int index) {
    return SizedBox(
      width: 76,
      child:
          InkWell(
                onTap: () => _showFirstAidInstructions(instruction),
                borderRadius: BorderRadius.circular(_chipRadius),
                child: Ink(
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.018),
                    borderRadius: BorderRadius.circular(_chipRadius),
                    border: Border.all(
                      color: AppColors.primaryDark.withValues(alpha: 0.040),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _iconForFirstAid(instruction.id),
                          color: AppColors.primaryRed,
                          size: 21,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          instruction.shortTitle.tr(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 11.1,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate(delay: Duration(milliseconds: 28 * index))
              .fadeIn(duration: 200.ms)
              .slideX(begin: 0.035, end: 0),
    );
  }

  void _showFirstAidInstructions(FirstAidInstruction instruction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 15),
            _buildFirstAidSheetHeader(sheetContext, instruction),
            const SizedBox(height: 11),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(child: _buildFirstAidSteps(instruction)),
            _buildSheetEmergencyFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstAidSheetHeader(
    BuildContext sheetContext,
    FirstAidInstruction instruction,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconForFirstAid(instruction.id),
              color: AppColors.primaryRed,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction.title.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 18.5,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  instruction.summary.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.42,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textBlack),
            onPressed: () => Navigator.pop(sheetContext),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstAidSteps(FirstAidInstruction instruction) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      physics: const BouncingScrollPhysics(),
      itemCount: instruction.steps.length,
      itemBuilder: (context, index) {
        final step = instruction.steps[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title.tr(),
                        style: GoogleFonts.cairo(
                          fontSize: 14.6,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textBlack,
                          height: 1.33,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.description.tr(),
                        style: GoogleFonts.cairo(
                          fontSize: 12.7,
                          color: Colors.grey.shade700,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetEmergencyFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.055),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(
              Icons.emergency_rounded,
              color: AppColors.primaryRed,
              size: 21,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                AppStrings.aiSeriousEmergencyAdvice.tr(),
                style: GoogleFonts.cairo(
                  fontSize: 11.4,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                  height: 1.42,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(AIChatViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (viewModel.isListening) ...[
              _buildVoiceStatusLine(viewModel),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildVoiceButton(viewModel),
                const SizedBox(width: 8),
                Expanded(child: _buildMessageField(viewModel)),
                const SizedBox(width: 8),
                _buildSendButton(viewModel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceStatusLine(AIChatViewModel viewModel) {
    final spokenText = viewModel.currentVoiceText.trim();
    final statusText = spokenText.isNotEmpty
        ? spokenText
        : _voiceStatusText(viewModel.voiceStatusMessage);

    final normalizedLevel = (viewModel.currentSoundLevel.abs() / 18)
        .clamp(0.08, 1.0)
        .toDouble();

    final toneColor = viewModel.isVoiceSignalElevated
        ? AppColors.primaryRed
        : AppColors.primaryDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          const Icon(
                Icons.graphic_eq_rounded,
                color: AppColors.primaryRed,
                size: 19,
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 0.92, end: 1.08, duration: 650.ms),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: AppColors.primaryDark,
                    fontSize: 11.3,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  viewModel.voiceToneLabelKey.tr(),
                  style: GoogleFonts.cairo(
                    color: toneColor,
                    fontSize: 10.2,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: 38,
              height: 5,
              color: AppColors.primaryDark.withValues(alpha: 0.10),
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: normalizedLevel,
                child: Container(
                  decoration: BoxDecoration(
                    color: toneColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceButton(AIChatViewModel viewModel) {
    final enabled = viewModel.canUseVoiceInput;
    final isListening = viewModel.isListening;

    return InkWell(
      onTap: enabled ? _handleVoicePressed : null,
      borderRadius: BorderRadius.circular(23),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isListening
              ? AppColors.primaryRed.withValues(alpha: 0.10)
              : AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(
            color: isListening
                ? AppColors.primaryRed.withValues(alpha: 0.24)
                : Colors.grey.shade200,
          ),
          boxShadow: isListening
              ? [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.14),
                    blurRadius: 11,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child:
            Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                  color: isListening
                      ? AppColors.primaryRed
                      : Colors.grey.shade600,
                  size: isListening ? 24 : 23,
                )
                .animate(target: isListening ? 1 : 0)
                .scaleXY(begin: 1, end: 1.10, duration: 220.ms),
      ),
    );
  }

  Widget _buildMessageField(AIChatViewModel viewModel) {
    return TextField(
      controller: _controller,
      enabled: !viewModel.isLoading,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.send,
      textAlign: TextAlign.start,
      style: GoogleFonts.cairo(fontSize: 13.4, color: AppColors.textBlack),
      decoration: InputDecoration(
        hintText: viewModel.isListening
            ? AppStrings.aiInputListeningHint.tr()
            : AppStrings.aiInputHint.tr(),
        hintStyle: GoogleFonts.cairo(
          fontSize: 12.5,
          color: viewModel.isListening
              ? AppColors.primaryRed
              : Colors.grey.shade500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(23),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 11,
        ),
      ),
      onSubmitted: (_) => _handleSendMessage(),
    );
  }

  Widget _buildSendButton(AIChatViewModel viewModel) {
    final enabled = viewModel.canSendMessage;

    return InkWell(
      onTap: enabled ? () => _handleSendMessage() : null,
      borderRadius: BorderRadius.circular(23),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primaryDark : Colors.grey.shade300,
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.17),
                    blurRadius: 11,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 19),
      ),
    );
  }

  IconData _iconForFirstAid(String id) {
    switch (id) {
      case 'bleeding':
        return Icons.water_drop_rounded;
      case 'unconscious':
        return Icons.airline_seat_flat_rounded;
      case 'fracture':
        return Icons.healing_rounded;
      case 'burns':
        return Icons.local_fire_department_rounded;
      case 'cpr':
        return Icons.favorite_rounded;
      case 'choking':
        return Icons.record_voice_over_rounded;
      default:
        return Icons.medical_services_rounded;
    }
  }
}

class _AIContentState {
  const _AIContentState({
    required this.messagesLength,
    required this.isSpeaking,
  });

  final int messagesLength;
  final bool isSpeaking;

  bool get hasMessages => messagesLength > 0;

  @override
  bool operator ==(Object other) {
    return other is _AIContentState &&
        other.messagesLength == messagesLength &&
        other.isSpeaking == isSpeaking;
  }

  @override
  int get hashCode => Object.hash(messagesLength, isSpeaking);
}

class _AIStatusState {
  const _AIStatusState({required this.isLoading, required this.isListening});

  final bool isLoading;
  final bool isListening;

  @override
  bool operator ==(Object other) {
    return other is _AIStatusState &&
        other.isLoading == isLoading &&
        other.isListening == isListening;
  }

  @override
  int get hashCode => Object.hash(isLoading, isListening);
}

class _AIInputState {
  const _AIInputState({
    required this.isLoading,
    required this.isListening,
    required this.currentVoiceText,
    required this.voiceStatusMessage,
    required this.currentSoundLevel,
    required this.voiceToneSignal,
  });

  final bool isLoading;
  final bool isListening;
  final String currentVoiceText;
  final String? voiceStatusMessage;
  final double currentSoundLevel;
  final VoiceToneSignal voiceToneSignal;

  @override
  bool operator ==(Object other) {
    return other is _AIInputState &&
        other.isLoading == isLoading &&
        other.isListening == isListening &&
        other.currentVoiceText == currentVoiceText &&
        other.voiceStatusMessage == voiceStatusMessage &&
        other.currentSoundLevel == currentSoundLevel &&
        other.voiceToneSignal == voiceToneSignal;
  }

  @override
  int get hashCode {
    return Object.hash(
      isLoading,
      isListening,
      currentVoiceText,
      voiceStatusMessage,
      currentSoundLevel,
      voiceToneSignal,
    );
  }
}
