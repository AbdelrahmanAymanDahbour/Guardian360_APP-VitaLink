import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/emergency_contact_model.dart';
import '../viewmodels/contacts_viewmodel.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ContactsViewModel(),
      child: const _ContactsContent(),
    );
  }
}

// ─────────────────────────────────────────────
// MAIN CONTENT
// ─────────────────────────────────────────────

class _ContactsContent extends StatelessWidget {
  const _ContactsContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ContactsViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      // ── PART 1: Premium AppBar ──────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'contacts.title'.tr(),
          style: GoogleFonts.cairo(
            color: AppColors.textBlack,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          tooltip: 'common.back'.tr(),
          icon: Transform.scale(
            scaleX: Directionality.of(context) == ui.TextDirection.rtl ? -1 : 1,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textBlack,
            ),
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withAlpha(18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.contact_phone_rounded,
                    color: AppColors.primaryDark,
                    size: 21,
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 200.ms).scaleXY(
                begin: 0.92,
                end: 1,
                delay: 200.ms,
                duration: 200.ms,
              ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDark),
            )
          : RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: viewModel.refreshContacts,
              child: SafeArea(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      sliver: SliverToBoxAdapter(
                        child: _ReadinessHeader(viewModel: viewModel),
                      ),
                    ),
                    if (viewModel.errorMessage.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        sliver: SliverToBoxAdapter(
                          child: _MessageCard(
                            message: viewModel.errorMessage,
                            icon: Icons.error_outline_rounded,
                            color: AppColors.primaryRed,
                          ),
                        ),
                      ),
                    if (viewModel.successMessage.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        sliver: SliverToBoxAdapter(
                          child: _MessageCard(
                            message: viewModel.successMessage,
                            icon: Icons.check_circle_outline_rounded,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    if (viewModel.contacts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyContactsState(
                          onAddTap: viewModel.canAddMoreContacts
                              ? () {
                                  viewModel.prepareAddForm();
                                  _showAddContactBottomSheet(
                                      context, viewModel);
                                }
                              : null,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          MediaQuery.paddingOf(context).bottom + 110,
                        ),
                        sliver: SliverList.builder(
                          itemCount: viewModel.contacts.length,
                          itemBuilder: (context, index) {
                            final contact = viewModel.contacts[index];

                            return _EmergencyContactCard(
                                  key: ValueKey(contact.id),
                                  contact: contact,
                                  index: index,
                                  viewModel: viewModel,
                                )
                                .animate(delay: (80 * index).ms)
                                .fadeIn(duration: 260.ms)
                                .slideY(begin: 0.06, end: 0);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
      // ── PART 4: Premium FAB ────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: viewModel.isSaving || viewModel.isImportingFromPhone
            ? null
            : () {
                HapticFeedback.mediumImpact();

                if (!viewModel.canAddMoreContacts) {
                  _showMaxContactsDialog(context, viewModel);
                  return;
                }

                viewModel.prepareAddForm();
                _showAddContactBottomSheet(context, viewModel);
              },
        backgroundColor: AppColors.primaryDark,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        icon: viewModel.isSaving || viewModel.isImportingFromPhone
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : const Icon(Icons.add_moderator_rounded, color: Colors.white),
        label: Text(
          viewModel.isSaving || viewModel.isImportingFromPhone
              ? 'common.processing'.tr()
              : 'contacts.actions.add_rescuer'.tr(),
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
      )
          .animate()
          .fadeIn(delay: 320.ms, duration: 220.ms)
          .scaleXY(begin: 0.9, end: 1, delay: 320.ms, duration: 220.ms),
    );
  }

  void _showMaxContactsDialog(
    BuildContext context,
    ContactsViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'contacts.max_dialog.title'.tr(),
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w900,
            color: AppColors.textBlack,
          ),
        ),
        content: Text(
          'contacts.max_dialog.body'.tr(
            namedArgs: {'max': viewModel.maxContacts.toString()},
          ),
          style: GoogleFonts.cairo(
            height: 1.55,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'common.ok'.tr(),
              style: GoogleFonts.cairo(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddContactBottomSheet(
    BuildContext context,
    ContactsViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _AddContactSheet(viewModel: viewModel, parentContext: context);
      },
    );
  }
}

// ─────────────────────────────────────────────
// PART 2: READINESS HEADER
// ─────────────────────────────────────────────

class _ReadinessHeader extends StatelessWidget {
  const _ReadinessHeader({required this.viewModel});

  final ContactsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final color = viewModel.readinessColor;
    final progress = (viewModel.contactsCount / viewModel.maxContacts).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withAlpha(35)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Shield capsule — one-time entrance animation
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  viewModel.hasContacts
                      ? Icons.shield_rounded
                      : Icons.warning_amber_rounded,
                  color: color,
                  size: 26,
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .scaleXY(
                    begin: 0.86,
                    end: 1,
                    duration: 300.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      viewModel.readinessTitle.tr(),
                      style: GoogleFonts.cairo(
                        color: color,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      viewModel.readinessSubtitle.tr(),
                      style: GoogleFonts.cairo(
                        color: color == Colors.orange
                            ? Colors.orange.shade900
                            : AppColors.primaryDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Count pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withAlpha(14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withAlpha(30)),
                ),
                child: Text(
                  '${viewModel.contactsCount}/${viewModel.maxContacts}',
                  style: GoogleFonts.montserrat(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar based on contactsCount / maxContacts
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade100,
              color: color,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'contacts.count_label'.tr(
              namedArgs: {
                'count': viewModel.contactsCount.toString(),
                'max': viewModel.maxContacts.toString(),
              },
            ),
            style: GoogleFonts.cairo(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (viewModel.hasPendingCloudSync) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.sync_rounded, size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 5),
                Text(
                  'contacts.sync.pending'.tr(),
                  style: GoogleFonts.cairo(
                    color: Colors.orange.shade700,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.06, end: 0);
  }
}

// ─────────────────────────────────────────────
// PART 3: EMERGENCY CONTACT CARD
// ─────────────────────────────────────────────

class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard({
    super.key,
    required this.contact,
    required this.index,
    required this.viewModel,
  });

  final EmergencyContactModel contact;
  final int index;
  final ContactsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isPrimary = index == 0;

    return Dismissible(
      key: ValueKey('dismiss_${contact.id}_${contact.phone}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await _confirmDelete(context, contact);
        if (confirmed != true) return false;

        final deleted = await viewModel.deleteContact(index);

        if (!context.mounted) return false;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deleted
                  ? 'contacts.messages.deleted_named'.tr(
                      namedArgs: {'name': contact.name},
                    )
                  : viewModel.errorMessage.tr(),
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
            ),
            backgroundColor: deleted ? Colors.red : AppColors.primaryRed,
            behavior: SnackBarBehavior.floating,
          ),
        );

        return deleted;
      },
      onDismissed: (_) {},
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.red.shade200),
        ),
        alignment: AlignmentDirectional.centerEnd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.red.shade600, size: 28),
            const SizedBox(height: 4),
            Text(
              'common.delete'.tr(),
              style: GoogleFonts.cairo(
                color: Colors.red.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isPrimary
                ? AppColors.primaryDark.withAlpha(50)
                : Colors.grey.shade200,
            width: isPrimary ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? AppColors.primaryDark.withAlpha(14)
                  : Colors.black.withAlpha(5),
              blurRadius: isPrimary ? 20 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onLongPress: () => _showContactActions(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PriorityBadge(index: index, isPrimary: isPrimary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              contact.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.5,
                                color: AppColors.textBlack,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ContactTag(
                            label: isPrimary
                                ? 'contacts.primary'.tr()
                                : 'contacts.backup'.tr(),
                            color: isPrimary
                                ? AppColors.primaryDark
                                : Colors.grey.shade500,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        contact.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: ui.TextDirection.ltr,
                        style: GoogleFonts.montserrat(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _MiniInfoChip(
                        icon: Icons.family_restroom_rounded,
                        label: 'contacts.relations.${contact.relation}'.tr(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'contacts.actions.options'.tr(),
                  onPressed: () => _showContactActions(context),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.grey.shade400,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    EmergencyContactModel contact,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'contacts.delete_dialog.title'.tr(),
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w900,
            color: AppColors.textBlack,
          ),
        ),
        content: Text(
          'contacts.delete_dialog.body'.tr(namedArgs: {'name': contact.name}),
          style: GoogleFonts.cairo(
            color: Colors.grey.shade700,
            height: 1.55,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'common.cancel'.tr(),
              style: GoogleFonts.cairo(
                color: Colors.grey,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'common.delete'.tr(),
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PART 6: Contact actions bottom sheet ─────────────────────
  void _showContactActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                // Header: name + phone
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withAlpha(8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primaryDark.withAlpha(20)),
                  ),
                  child: Row(
                    children: [
                      _PriorityBadge(index: index, isPrimary: index == 0),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textBlack,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              contact.phone,
                              textDirection: ui.TextDirection.ltr,
                              style: GoogleFonts.montserrat(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Primary action (emphasized)
                if (index != 0) ...[
                  _ActionTile(
                    icon: Icons.workspace_premium_rounded,
                    color: AppColors.primaryDark,
                    title: 'contacts.actions.make_primary'.tr(),
                    isPrimary: true,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await viewModel.makePrimary(index);
                    },
                  ),
                  const SizedBox(height: 4),
                ],
                // Move actions (secondary)
                if (index > 0)
                  _ActionTile(
                    icon: Icons.keyboard_arrow_up_rounded,
                    color: Colors.blueGrey,
                    title: 'contacts.actions.move_up'.tr(),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await viewModel.moveContactUp(index);
                    },
                  ),
                if (index < viewModel.contacts.length - 1)
                  _ActionTile(
                    icon: Icons.keyboard_arrow_down_rounded,
                    color: Colors.blueGrey,
                    title: 'contacts.actions.move_down'.tr(),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await viewModel.moveContactDown(index);
                    },
                  ),
                // Separator
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Colors.grey.shade200, height: 1),
                ),
                // Delete (separated, red)
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.red.shade700,
                  title: 'contacts.actions.delete_contact'.tr(),
                  onTap: () async {
                    Navigator.pop(sheetContext);

                    final confirmed = await _confirmDelete(context, contact);
                    if (confirmed != true) return;

                    var deleteIndex = index;
                    if (deleteIndex < 0 ||
                        deleteIndex >= viewModel.contacts.length ||
                        viewModel.contacts[deleteIndex].id != contact.id) {
                      deleteIndex = viewModel.contacts
                          .indexWhere((c) => c.id == contact.id);
                    }
                    if (deleteIndex == -1) return;

                    final deleted = await viewModel.deleteContact(deleteIndex);

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          deleted
                              ? 'contacts.messages.deleted_named'.tr(
                                  namedArgs: {'name': contact.name},
                                )
                              : viewModel.errorMessage.tr(),
                          style:
                              GoogleFonts.cairo(fontWeight: FontWeight.w800),
                        ),
                        backgroundColor:
                            deleted ? Colors.red : AppColors.primaryRed,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// PRIORITY BADGE
// ─────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.index, required this.isPrimary});

  final int index;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final size = isPrimary ? 52.0 : 50.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primaryDark : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(13),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: AppColors.primaryDark.withAlpha(35),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: GoogleFonts.montserrat(
            color: isPrimary ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w900,
            fontSize: isPrimary ? 19 : 17,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONTACT TAG CHIP
// ─────────────────────────────────────────────

class _ContactTag extends StatelessWidget {
  const _ContactTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MINI INFO CHIP
// ─────────────────────────────────────────────

class _MiniInfoChip extends StatelessWidget {
  const _MiniInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACTION TILE  (PART 6)
// ─────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: isPrimary
            ? BoxDecoration(
                color: color.withAlpha(10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withAlpha(28)),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withAlpha(14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w800,
                fontSize: isPrimary ? 14.5 : 14,
                color: isPrimary ? color : AppColors.textBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PART 7: EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyContactsState extends StatelessWidget {
  const _EmptyContactsState({this.onAddTap});

  final VoidCallback? onAddTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 30, 32, 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withAlpha(12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primaryDark.withAlpha(25)),
              ),
              child: const Icon(
                Icons.contact_emergency_rounded,
                size: 44,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'contacts.empty_state.title'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'contacts.empty_state.body'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onAddTap != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                child: ElevatedButton.icon(
                  onPressed: onAddTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 4,
                    shadowColor: AppColors.primaryDark.withAlpha(50),
                  ),
                  icon: const Icon(Icons.add_moderator_rounded,
                      color: Colors.white, size: 20),
                  label: Text(
                    'contacts.actions.add_rescuer'.tr(),
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.06, end: 0, duration: 350.ms);
  }
}

// ─────────────────────────────────────────────
// MESSAGE CARD
// ─────────────────────────────────────────────

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.tr(),
              style: GoogleFonts.cairo(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PART 5: ADD CONTACT SHEET
// ─────────────────────────────────────────────

class _AddContactSheet extends StatelessWidget {
  const _AddContactSheet({
    required this.viewModel,
    required this.parentContext,
  });

  final ContactsViewModel viewModel;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        final height = MediaQuery.sizeOf(context).height;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height * 0.9),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle
                        const SizedBox(height: 12),
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark.withAlpha(16),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_moderator_rounded,
                                color: AppColors.primaryDark,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'contacts.sheet.title'.tr(),
                                    style: GoogleFonts.cairo(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  Text(
                                    'contacts.sheet.description'.tr(),
                                    style: GoogleFonts.cairo(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // Import from phone — clean card button
                        InkWell(
                          onTap: viewModel.isSaving ||
                                  viewModel.isImportingFromPhone
                              ? null
                              : () async {
                                  HapticFeedback.selectionClick();

                                  final imported = await viewModel
                                      .importContactFromPhone();

                                  if (!context.mounted) return;

                                  if (imported) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'contacts.messages.imported_review'
                                              .tr(),
                                          style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  if (viewModel.errorMessage.isNotEmpty) {
                                    ScaffoldMessenger.of(
                                      context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          viewModel.errorMessage.tr(),
                                          style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        backgroundColor: AppColors.primaryRed,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withAlpha(8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primaryDark.withAlpha(35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primaryDark.withAlpha(16),
                                    shape: BoxShape.circle,
                                  ),
                                  child: viewModel.isImportingFromPhone
                                      ? const Padding(
                                          padding: EdgeInsets.all(9),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: AppColors.primaryDark,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.contacts_rounded,
                                          color: AppColors.primaryDark,
                                          size: 18,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    viewModel.isImportingFromPhone
                                        ? 'contacts.actions.importing'.tr()
                                        : 'contacts.actions.import_from_phone'
                                            .tr(),
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color:
                                      AppColors.primaryDark.withAlpha(120),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Divider with "or"
                        Row(
                          children: [
                            Expanded(
                                child: Divider(color: Colors.grey.shade200)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'common.or'.tr(),
                                style: GoogleFonts.cairo(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(color: Colors.grey.shade200)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Fields
                        _AddContactTextField(
                          controller: viewModel.nameController,
                          label: 'contacts.fields.name.label'.tr(),
                          hint: 'contacts.fields.name.hint'.tr(),
                          helper: 'contacts.fields.name.helper'.tr(),
                          icon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        _AddContactTextField(
                          controller: viewModel.phoneController,
                          label: 'contacts.fields.phone.label'.tr(),
                          hint: 'contacts.fields.phone.hint'.tr(),
                          helper: 'contacts.fields.phone.helper'.tr(),
                          icon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                          forceLtr: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\s\-\(\)]'),
                            ),
                            LengthLimitingTextInputFormatter(18),
                          ],
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 12),
                        _RelationPicker(viewModel: viewModel),
                        if (viewModel.errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _SheetMessage(
                            message: viewModel.errorMessage,
                            color: AppColors.primaryRed,
                            icon: Icons.error_outline_rounded,
                          ),
                        ],
                        if (viewModel.successMessage.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _SheetMessage(
                            message: viewModel.successMessage,
                            color: Colors.green,
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ],
                        const SizedBox(height: 22),
                        // Save button — full-width, primaryDark, radius 18
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: viewModel.isSaving ||
                                    viewModel.isImportingFromPhone
                                ? null
                                : () async {
                                    final success = await viewModel
                                        .addContactFromForm();

                                    if (!context.mounted) return;

                                    if (!success) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            viewModel
                                                    .errorMessage.isNotEmpty
                                                ? viewModel.errorMessage.tr()
                                                : 'contacts.errors.save_failed'
                                                    .tr(),
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          backgroundColor:
                                              AppColors.primaryRed,
                                          behavior:
                                              SnackBarBehavior.floating,
                                        ),
                                      );
                                      return;
                                    }

                                    Navigator.pop(context);

                                    if (parentContext.mounted) {
                                      ScaffoldMessenger.of(
                                        parentContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'contacts.messages.added_success'
                                                .tr(),
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          backgroundColor: Colors.green,
                                          behavior:
                                              SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              disabledBackgroundColor:
                                  AppColors.primaryDark.withAlpha(120),
                              elevation: 4,
                              shadowColor:
                                  AppColors.primaryDark.withAlpha(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: viewModel.isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : const Icon(
                                    Icons.save_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                            label: Text(
                              viewModel.isSaving
                                  ? 'contacts.actions.saving'.tr()
                                  : 'contacts.actions.save_rescuer'.tr(),
                              style: GoogleFonts.cairo(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// ADD CONTACT TEXT FIELD
// ─────────────────────────────────────────────

class _AddContactTextField extends StatelessWidget {
  const _AddContactTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.helper,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.forceLtr = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String helper;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final bool forceLtr;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      textDirection: forceLtr ? ui.TextDirection.ltr : null,
      style: GoogleFonts.cairo(
        color: AppColors.textBlack,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        prefixIcon: Icon(icon, color: AppColors.primaryDark.withAlpha(140), size: 20),
        labelStyle: GoogleFonts.cairo(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: GoogleFonts.cairo(
          color: Colors.grey.shade400,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        helperStyle: GoogleFonts.cairo(
          color: Colors.grey.shade500,
          fontSize: 10.5,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.primaryDark,
            width: 1.8,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RELATION PICKER
// ─────────────────────────────────────────────

class _RelationPicker extends StatelessWidget {
  const _RelationPicker({required this.viewModel});

  final ContactsViewModel viewModel;

  void _showRelationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                // Title
                Text(
                  'contacts.fields.relation.label'.tr(),
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // Relations List
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: viewModel.relations.length,
                      separatorBuilder: (context, index) => Divider(
                        color: Colors.grey.shade100,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final relation = viewModel.relations[index];
                        final isSelected = relation == viewModel.selectedRelation;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            viewModel.setRelation(relation);
                            Navigator.pop(sheetContext);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryDark.withAlpha(12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.family_restroom_rounded,
                                  color: isSelected
                                      ? AppColors.primaryDark
                                      : Colors.grey.shade400,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'contacts.relations.$relation'.tr(),
                                    style: GoogleFonts.cairo(
                                      color: isSelected
                                          ? AppColors.primaryDark
                                          : AppColors.textBlack,
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primaryDark,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: viewModel.isSaving || viewModel.isImportingFromPhone
          ? null
          : () => _showRelationBottomSheet(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.family_restroom_rounded,
              color: AppColors.primaryDark.withAlpha(140),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'contacts.relations.${viewModel.selectedRelation}'.tr(),
                style: GoogleFonts.cairo(
                  color: AppColors.textBlack,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHEET MESSAGE
// ─────────────────────────────────────────────

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message.tr(),
              style: GoogleFonts.cairo(
                color: color,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
