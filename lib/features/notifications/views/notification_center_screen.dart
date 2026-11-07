import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/notification_model.dart';
import '../viewmodels/notification_center_viewmodel.dart';

/// ==========================================
/// 🔔 Notification Center Screen - Guardian 360
/// ==========================================
/// User-facing in-app notification center.
///
/// Important:
/// - Does NOT create accidents.
/// - Does NOT create alerts.
/// - Does NOT modify SOS logic.
/// - Reads only from users/{uid}/notifications.
/// - Tapping a notification marks it as read and shows details.
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotificationCenterViewModel>(
      create: (_) => NotificationCenterViewModel(),
      child: const _NotificationCenterView(),
    );
  }
}

enum _NotificationFilter { all, unread, safeArrival, emergency, kroka, system }

class _NotificationCenterView extends StatefulWidget {
  const _NotificationCenterView();

  @override
  State<_NotificationCenterView> createState() =>
      _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<_NotificationCenterView> {
  _NotificationFilter _selectedFilter = _NotificationFilter.all;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode.toLowerCase().startsWith('ar');

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Consumer<NotificationCenterViewModel>(
            builder: (context, viewModel, _) {
              final allNotifications = _sortedNotifications(
                viewModel.notifications,
              );

              final filteredNotifications = _filterNotifications(
                allNotifications,
                _selectedFilter,
              );

              return Column(
                children: [
                  _Header(
                    isArabic: isArabic,
                    totalCount: allNotifications.length,
                    unreadCount: viewModel.unreadCount,
                    isActionLoading: viewModel.isActionLoading,
                    onBack: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).maybePop();
                    },
                    onMarkAllRead: viewModel.hasUnreadNotifications
                        ? () async {
                            HapticFeedback.mediumImpact();
                            await viewModel.markAllAsRead();
                          }
                        : null,
                  ),
                  if (allNotifications.isNotEmpty)
                    _FilterBar(
                      isArabic: isArabic,
                      selectedFilter: _selectedFilter,
                      notifications: allNotifications,
                      onChanged: (filter) {
                        if (_selectedFilter == filter) return;

                        HapticFeedback.selectionClick();
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  Expanded(
                    child: _Body(
                      isArabic: isArabic,
                      viewModel: viewModel,
                      allNotifications: allNotifications,
                      filteredNotifications: filteredNotifications,
                      selectedFilter: _selectedFilter,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isArabic,
    required this.totalCount,
    required this.unreadCount,
    required this.isActionLoading,
    required this.onBack,
    required this.onMarkAllRead,
  });

  final bool isArabic;
  final int totalCount;
  final int unreadCount;
  final bool isActionLoading;
  final VoidCallback onBack;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        children: [
          Row(
            children: [
              _SoftIconButton(
                icon: isArabic
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'notifications.title'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textBlack,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'notifications.subtitle'.tr(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textGrey,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _HeaderBellIcon(hasUnread: hasUnread),
            ],
          ),
          const SizedBox(height: 18),
          _SummaryCard(
            isArabic: isArabic,
            totalCount: totalCount,
            unreadCount: unreadCount,
            isActionLoading: isActionLoading,
            onMarkAllRead: onMarkAllRead,
          ),
        ],
      ),
    );
  }
}

class _HeaderBellIcon extends StatelessWidget {
  const _HeaderBellIcon({required this.hasUnread});

  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.primaryDark,
            size: 25,
          ),
          if (hasUnread)
            PositionedDirectional(
              top: 10,
              end: 10,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.primaryRed,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.isArabic,
    required this.totalCount,
    required this.unreadCount,
    required this.isActionLoading,
    required this.onMarkAllRead,
  });

  final bool isArabic;
  final int totalCount;
  final int unreadCount;
  final bool isActionLoading;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    final hasNotifications = totalCount > 0;

    final title = hasUnread
        ? (unreadCount == 1
                  ? 'notifications.summary.unread_one'
                  : 'notifications.summary.unread_many')
              .tr(namedArgs: {'count': '$unreadCount'})
        : hasNotifications
        ? 'notifications.summary.all_read'.tr()
        : 'notifications.summary.empty'.tr();

    final subtitle = hasNotifications
        ? 'notifications.summary.active_body'.tr()
        : 'notifications.summary.empty_body'.tr();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        final icon = Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(
            hasUnread
                ? Icons.mark_email_unread_rounded
                : hasNotifications
                ? Icons.mark_email_read_rounded
                : Icons.verified_rounded,
            color: Colors.white,
            size: 29,
          ),
        );

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.38,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  label: 'notifications.summary.total_chip'.tr(
                    namedArgs: {'count': '$totalCount'},
                  ),
                  icon: Icons.notifications_active_outlined,
                ),
                _SummaryChip(
                  label: 'notifications.summary.unread_chip'.tr(
                    namedArgs: {'count': '$unreadCount'},
                  ),
                  icon: Icons.circle_notifications_outlined,
                ),
              ],
            ),
          ],
        );

        final action = hasUnread
            ? _ReadAllButton(
                isArabic: isArabic,
                enabled: !isActionLoading,
                isLoading: isActionLoading,
                onTap: onMarkAllRead,
              )
            : _StatusPill(
                text: 'notifications.summary.synced'.tr(),
                icon: Icons.check_circle_rounded,
              );

        return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primaryRed],
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.20),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            icon,
                            const SizedBox(width: 14),
                            Expanded(child: content),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: action,
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        icon,
                        const SizedBox(width: 14),
                        Expanded(child: content),
                        const SizedBox(width: 12),
                        action,
                      ],
                    ),
            )
            .animate()
            .fadeIn(duration: 450.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic);
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadAllButton extends StatelessWidget {
  const _ReadAllButton({
    required this.isArabic,
    required this.enabled,
    required this.isLoading,
    required this.onTap,
  });

  final bool isArabic;
  final bool enabled;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1.0 : 0.55,
          child: Container(
            constraints: const BoxConstraints(minWidth: 82),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'notifications.actions.read_all'.tr(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.isArabic,
    required this.selectedFilter,
    required this.notifications,
    required this.onChanged,
  });

  final bool isArabic;
  final _NotificationFilter selectedFilter;
  final List<NotificationModel> notifications;
  final ValueChanged<_NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = _NotificationFilter.values;
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];

          return _FilterChipButton(
            isArabic: isArabic,
            filter: filter,
            count: _countForFilter(notifications, filter),
            selected: selectedFilter == filter,
            onTap: () => onChanged(filter),
          );
        },
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.isArabic,
    required this.filter,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final bool isArabic;
  final _NotificationFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDark : AppColors.surfaceWhite;
    final textColor = selected ? Colors.white : AppColors.textBlack;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primaryDark
                  : AppColors.textGrey.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppColors.primaryDark.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.035),
                blurRadius: selected ? 12 : 8,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_filterIcon(filter), color: textColor, size: 16),
              const SizedBox(width: 6),
              Text(
                _filterLabel(filter, isArabic),
                style: GoogleFonts.cairo(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.20)
                      : AppColors.primaryDark.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: GoogleFonts.cairo(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.isArabic,
    required this.viewModel,
    required this.allNotifications,
    required this.filteredNotifications,
    required this.selectedFilter,
  });

  final bool isArabic;
  final NotificationCenterViewModel viewModel;
  final List<NotificationModel> allNotifications;
  final List<NotificationModel> filteredNotifications;
  final _NotificationFilter selectedFilter;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading && allNotifications.isEmpty) {
      return const _LoadingState();
    }

    if (viewModel.hasError && allNotifications.isEmpty) {
      return _ErrorState(isArabic: isArabic, onRetry: viewModel.retry);
    }

    if (allNotifications.isEmpty) {
      return _EmptyState(isArabic: isArabic);
    }

    if (filteredNotifications.isEmpty) {
      return _FilteredEmptyState(
        isArabic: isArabic,
        selectedFilter: selectedFilter,
      );
    }

    final groups = _groupNotifications(filteredNotifications, isArabic);

    return RefreshIndicator(
      color: AppColors.primaryDark,
      onRefresh: () async {
        HapticFeedback.selectionClick();
        viewModel.retry();
        await Future<void>.delayed(const Duration(milliseconds: 350));
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: groups.length,
        itemBuilder: (context, groupIndex) {
          final group = groups[groupIndex];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title: group.label),
              ...List.generate(group.notifications.length, (index) {
                final notification = group.notifications[index];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == group.notifications.length - 1 ? 6 : 12,
                  ),
                  child:
                      _NotificationTile(
                            notification: notification,
                            isArabic: isArabic,
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              await viewModel.markAsRead(notification.id);

                              if (!context.mounted) return;

                              _showNotificationDetails(
                                context: context,
                                notification: notification,
                                isArabic: isArabic,
                              );
                            },
                            // ─────────────────────────────────────────────
                            // Optimistic delete: synchronous, no await.
                            // The Dismissible animation has already finished
                            // by the time onDismissed fires; this call removes
                            // the item from _notifications immediately so the
                            // Firestore stream rebuild cannot put it back.
                            // ─────────────────────────────────────────────
                            onDelete: () {
                              HapticFeedback.mediumImpact();
                              viewModel.optimisticDelete(notification.id);
                            },
                          )
                          .animate(delay: (35 * index).ms)
                          .fadeIn(duration: 300.ms)
                          .slideY(
                            begin: 0.06,
                            end: 0,
                            curve: Curves.easeOutCubic,
                          ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      child: Text(
        title,
        style: GoogleFonts.cairo(
          color: AppColors.textGrey,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isArabic,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationModel notification;
  final bool isArabic;
  final VoidCallback onTap;

  /// Synchronous delete callback.
  ///
  /// Must NOT be async — [Dismissible.onDismissed] is a plain [VoidCallback]
  /// and any [await] inside it creates a timing gap where the Firestore stream
  /// can rebuild the list with the dismissed item still present, causing the
  /// "A dismissed Dismissible widget is still part of the tree" crash.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(notification.type);
    final icon = _iconFor(notification.type);
    final title = notification.localizedTitle(isArabic ? 'ar' : 'en');
    final body = notification.localizedBody(isArabic ? 'ar' : 'en');
    final isUnread = !notification.isRead;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, isArabic),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: AppColors.primaryRed.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.primaryRed,
          size: 27,
        ),
      ),
      child: Material(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isUnread
                  ? AppColors.primaryRed.withValues(alpha: 0.025)
                  : AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isUnread
                    ? AppColors.primaryDark.withValues(alpha: 0.18)
                    : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.045),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NotificationIcon(
                  icon: icon,
                  color: accent,
                  isUnread: isUnread,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NotificationTitleRow(
                        isArabic: isArabic,
                        title: title,
                        isUnread: isUnread,
                      ),
                      if (body.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            color: AppColors.textGrey,
                            fontSize: 12.8,
                            fontWeight: FontWeight.w600,
                            height: 1.42,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MetaChip(
                            icon: Icons.access_time_rounded,
                            label: _formatRelativeTime(
                              notification.createdAt,
                              isArabic,
                            ),
                          ),
                          _MetaChip(
                            icon: _iconFor(notification.type),
                            label: _typeLabel(notification.type, isArabic),
                            color: accent,
                          ),
                          _PriorityBadge(
                            priority: notification.priority,
                            isArabic: isArabic,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTitleRow extends StatelessWidget {
  const _NotificationTitleRow({
    required this.isArabic,
    required this.title,
    required this.isUnread,
  });

  final bool isArabic;
  final String title;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title.trim().isEmpty ? 'notifications.fallback_title'.tr() : title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: AppColors.textBlack,
              fontSize: 15.5,
              fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
        if (isUnread) ...[
          const SizedBox(width: 8),
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: AppColors.primaryRed,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({
    required this.icon,
    required this.color,
    required this.isUnread,
  });

  final IconData icon;
  final Color color;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 49,
      height: 49,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isUnread ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textGrey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: effectiveColor.withValues(alpha: 0.90)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: effectiveColor.withValues(alpha: 0.95),
              fontSize: 10.8,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority, required this.isArabic});

  final String priority;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final value = priority.trim().toLowerCase();

    if (value.isEmpty || value == 'normal') {
      return const SizedBox.shrink();
    }

    final color = switch (value) {
      'critical' => AppColors.primaryRed,
      'high' => AppColors.primaryDark,
      'low' => Colors.blueGrey,
      _ => AppColors.textGrey,
    };

    final label = switch (value) {
      'critical' => 'notifications.priority.critical'.tr(),
      'high' => 'notifications.priority.high'.tr(),
      'low' => 'notifications.priority.low'.tr(),
      _ => value,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  const _SoftIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 19),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
              height: 92,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _SkeletonBox(width: 49, height: 49, radius: 18),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(
                          width: double.infinity,
                          height: 13,
                          radius: 8,
                        ),
                        const SizedBox(height: 10),
                        _SkeletonBox(width: 190, height: 10, radius: 8),
                        const Spacer(),
                        _SkeletonBox(width: 110, height: 10, radius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              duration: 1200.ms,
              color: AppColors.primaryRed.withValues(alpha: 0.08),
            );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primaryDark,
      onRefresh: () async {
        context.read<NotificationCenterViewModel>().retry();
        await Future<void>.delayed(const Duration(milliseconds: 350));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(30, 72, 30, 24),
        children: [
          ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primaryRed],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 92,
                  color: Colors.white,
                ),
              )
              .animate()
              .fadeIn(duration: 450.ms)
              .scale(begin: const Offset(0.94, 0.94), end: const Offset(1, 1)),
          const SizedBox(height: 22),
          Text(
            'notifications.empty.title'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: AppColors.textBlack,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'notifications.empty.body'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: AppColors.textGrey,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({
    required this.isArabic,
    required this.selectedFilter,
  });

  final bool isArabic;
  final _NotificationFilter selectedFilter;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(30, 90, 30, 24),
      children: [
        Icon(
          _filterIcon(selectedFilter),
          size: 72,
          color: AppColors.primaryDark.withValues(alpha: 0.45),
        ),
        const SizedBox(height: 18),
        Text(
          'notifications.filtered_empty.title'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: AppColors.textBlack,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'notifications.filtered_empty.body'.tr(),
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            color: AppColors.textGrey,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.isArabic, required this.onRetry});

  final bool isArabic;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.primaryRed,
              size: 64,
            ),
            const SizedBox(height: 18),
            Text(
              'notifications.error.title'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: AppColors.textBlack,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'notifications.error.body'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: AppColors.textGrey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'notifications.actions.retry'.tr(),
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationGroup {
  const _NotificationGroup({required this.label, required this.notifications});

  final String label;
  final List<NotificationModel> notifications;
}

List<NotificationModel> _sortedNotifications(
  List<NotificationModel> notifications,
) {
  final sorted = List<NotificationModel>.from(notifications);

  sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return sorted;
}

List<NotificationModel> _filterNotifications(
  List<NotificationModel> notifications,
  _NotificationFilter filter,
) {
  return notifications
      .where((notification) {
        return _matchesFilter(notification, filter);
      })
      .toList(growable: false);
}

bool _matchesFilter(
  NotificationModel notification,
  _NotificationFilter filter,
) {
  switch (filter) {
    case _NotificationFilter.all:
      return true;
    case _NotificationFilter.unread:
      return !notification.isRead;
    case _NotificationFilter.safeArrival:
      return notification.category == NotificationCategory.safeArrival;
    case _NotificationFilter.emergency:
      return notification.category == NotificationCategory.emergency ||
          _isEmergencyType(notification.type);
    case _NotificationFilter.kroka:
      return notification.category == NotificationCategory.kroka ||
          _isKrokaType(notification.type);
    case _NotificationFilter.system:
      return notification.category == NotificationCategory.system;
  }
}

int _countForFilter(
  List<NotificationModel> notifications,
  _NotificationFilter filter,
) {
  return notifications.where((notification) {
    return _matchesFilter(notification, filter);
  }).length;
}

List<_NotificationGroup> _groupNotifications(
  List<NotificationModel> notifications,
  bool isArabic,
) {
  final groups = <String, List<NotificationModel>>{};
  final labels = <String, String>{};

  for (final notification in notifications) {
    final date = notification.createdAt;
    final key = '${date.year}-${date.month}-${date.day}';

    groups.putIfAbsent(key, () => <NotificationModel>[]);
    labels[key] = _sectionLabel(date, isArabic);

    groups[key]!.add(notification);
  }

  return groups.entries
      .map((entry) {
        return _NotificationGroup(
          label: labels[entry.key] ?? entry.key,
          notifications: entry.value,
        );
      })
      .toList(growable: false);
}

String _sectionLabel(DateTime value, bool isArabic) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  final diff = today.difference(date).inDays;

  if (diff == 0) {
    return 'notifications.dates.today'.tr();
  }

  if (diff == 1) {
    return 'notifications.dates.yesterday'.tr();
  }

  final formatter = DateFormat(isArabic ? 'yyyy/MM/dd' : 'MMM d, yyyy');
  return formatter.format(value);
}

bool _isEmergencyType(String type) {
  final value = type.trim().toLowerCase();

  return value == 'emergency_report_sent' ||
      value == 'accident_pre_alert' ||
      value == 'manual_sos' ||
      value == 'auto_detection';
}

bool _isSafeArrivalType(String type) {
  return type.trim().toLowerCase().startsWith('safe_arrival_');
}

bool _isKrokaType(String type) {
  return type.trim().toLowerCase() == NotificationModel.typeKrokaReportSaved;
}

String _filterLabel(_NotificationFilter filter, bool isArabic) {
  switch (filter) {
    case _NotificationFilter.all:
      return 'notifications.filters.all'.tr();
    case _NotificationFilter.unread:
      return 'notifications.filters.unread'.tr();
    case _NotificationFilter.safeArrival:
      return 'notifications.filters.safe_arrival'.tr();
    case _NotificationFilter.emergency:
      return 'notifications.filters.emergency'.tr();
    case _NotificationFilter.kroka:
      return 'notifications.filters.kroka'.tr();
    case _NotificationFilter.system:
      return 'notifications.filters.system'.tr();
  }
}

IconData _filterIcon(_NotificationFilter filter) {
  switch (filter) {
    case _NotificationFilter.all:
      return Icons.notifications_active_outlined;
    case _NotificationFilter.unread:
      return Icons.mark_email_unread_outlined;
    case _NotificationFilter.safeArrival:
      return Icons.route_outlined;
    case _NotificationFilter.emergency:
      return Icons.local_hospital_outlined;
    case _NotificationFilter.kroka:
      return Icons.description_outlined;
    case _NotificationFilter.system:
      return Icons.settings_suggest_outlined;
  }
}

IconData _iconFor(String type) {
  switch (type.trim().toLowerCase()) {
    case 'offline_sync_success':
      return Icons.cloud_done_rounded;
    case 'battery_low':
      return Icons.battery_alert_rounded;
    case 'accident_pre_alert':
      return Icons.warning_amber_rounded;
    case 'emergency_report_sent':
      return Icons.local_hospital_rounded;
    case NotificationModel.typeKrokaReportSaved:
      return Icons.description_rounded;
    case 'system_notice':
      return Icons.info_outline_rounded;
    case 'status_change':
    case 'incident_status_change':
      return Icons.sync_alt_rounded;
    case 'safe_arrival_started':
      return Icons.route_rounded;
    case 'safe_arrival_paused':
      return Icons.pause_circle_filled_rounded;
    case 'safe_arrival_resumed':
      return Icons.play_circle_fill_rounded;
    case 'safe_arrival_near_destination':
      return Icons.near_me_rounded;
    case 'safe_arrival_arrived':
      return Icons.verified_rounded;
    case 'safe_arrival_cancelled':
      return Icons.cancel_rounded;
    case 'safe_arrival_danger':
      return Icons.report_problem_rounded;
    default:
      return Icons.notifications_none_rounded;
  }
}

Color _accentFor(String type) {
  switch (type.trim().toLowerCase()) {
    case 'offline_sync_success':
      return Colors.green;
    case 'battery_low':
      return Colors.orange;
    case 'accident_pre_alert':
    case 'emergency_report_sent':
    case 'safe_arrival_danger':
      return AppColors.primaryRed;
    case NotificationModel.typeKrokaReportSaved:
      return AppColors.primaryDark;
    case 'safe_arrival_started':
    case 'safe_arrival_resumed':
    case 'safe_arrival_near_destination':
      return AppColors.primaryDark;
    case 'safe_arrival_arrived':
      return Colors.green;
    case 'safe_arrival_paused':
      return Colors.amber.shade800;
    case 'safe_arrival_cancelled':
      return Colors.blueGrey;
    case 'system_notice':
    case 'status_change':
    case 'incident_status_change':
      return Colors.blueGrey;
    default:
      return _isSafeArrivalType(type)
          ? AppColors.primaryDark
          : AppColors.primaryDark;
  }
}

String _typeLabel(String type, bool isArabic) {
  switch (type.trim().toLowerCase()) {
    case 'offline_sync_success':
      return 'notifications.types.sync'.tr();
    case 'battery_low':
      return 'notifications.types.battery'.tr();
    case 'accident_pre_alert':
      return 'notifications.types.accident_alert'.tr();
    case 'emergency_report_sent':
      return 'notifications.types.emergency'.tr();
    case NotificationModel.typeKrokaReportSaved:
      return 'notifications.types.kroka_report_saved'.tr();
    case 'system_notice':
      return 'notifications.types.system'.tr();
    case 'status_change':
    case 'incident_status_change':
      return 'notifications.types.status_update'.tr();
    case 'safe_arrival_started':
      return 'notifications.types.safe_arrival_started'.tr();
    case 'safe_arrival_paused':
      return 'notifications.types.safe_arrival_paused'.tr();
    case 'safe_arrival_resumed':
      return 'notifications.types.safe_arrival_resumed'.tr();
    case 'safe_arrival_near_destination':
      return 'notifications.types.safe_arrival_near_destination'.tr();
    case 'safe_arrival_arrived':
      return 'notifications.types.safe_arrival_arrived'.tr();
    case 'safe_arrival_cancelled':
      return 'notifications.types.safe_arrival_cancelled'.tr();
    case 'safe_arrival_danger':
      return 'notifications.types.safe_arrival_danger'.tr();
    default:
      return _isSafeArrivalType(type)
          ? 'notifications.types.safe_arrival'.tr()
          : 'notifications.types.notification'.tr();
  }
}

Future<bool> _confirmDelete(BuildContext context, bool isArabic) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return Directionality(
        textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'notifications.delete_dialog.title'.tr(),
            style: GoogleFonts.cairo(
              color: AppColors.textBlack,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'notifications.delete_dialog.body'.tr(),
            style: GoogleFonts.cairo(
              color: AppColors.textGrey,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'notifications.actions.cancel'.tr(),
                style: GoogleFonts.cairo(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'notifications.actions.delete'.tr(),
                style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    },
  );

  return result ?? false;
}

void _showNotificationDetails({
  required BuildContext context,
  required NotificationModel notification,
  required bool isArabic,
}) {
  final title = notification.localizedTitle(isArabic ? 'ar' : 'en');
  final body = notification.localizedBody(isArabic ? 'ar' : 'en');
  final accent = _accentFor(notification.type);
  final relatedAccidentId = notification.relatedAccidentId?.trim();
  final safeArrivalTripId = notification.safeArrivalTripId?.trim();
  final destinationName = notification.destinationName?.trim();
  final krokaReportId = notification.krokaReportId?.trim();
  final krokaReferenceCode = notification.krokaReferenceCode?.trim();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Directionality(
        textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: Container(
          margin: const EdgeInsets.all(14),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textGrey.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: Icon(
                      _iconFor(notification.type),
                      color: accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title.trim().isEmpty
                        ? 'notifications.details.title'.tr()
                        : title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: AppColors.textBlack,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  if (body.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: AppColors.textGrey,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(
                        icon: _iconFor(notification.type),
                        label: _typeLabel(notification.type, isArabic),
                        color: accent,
                      ),
                      _MetaChip(
                        icon: Icons.access_time_rounded,
                        label: _formatRelativeTime(
                          notification.createdAt,
                          isArabic,
                        ),
                      ),
                      _PriorityBadge(
                        priority: notification.priority,
                        isArabic: isArabic,
                      ),
                    ],
                  ),
                  if (relatedAccidentId != null &&
                      relatedAccidentId.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.055),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'notifications.details.linked_accident'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: AppColors.primaryDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  if (safeArrivalTripId != null &&
                      safeArrivalTripId.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.055),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        destinationName != null && destinationName.isNotEmpty
                            ? 'notifications.details.linked_safe_arrival_destination'
                                  .tr(
                                    namedArgs: {'destination': destinationName},
                                  )
                            : 'notifications.details.linked_safe_arrival_saved'
                                  .tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: AppColors.primaryDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  if (krokaReportId != null && krokaReportId.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.055),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        krokaReferenceCode != null &&
                                krokaReferenceCode.isNotEmpty
                            ? 'notifications.details.linked_kroka_report_reference'
                                  .tr(
                                    namedArgs: {
                                      'reference': krokaReferenceCode,
                                    },
                                  )
                            : 'notifications.details.linked_kroka_report_saved'
                                  .tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: AppColors.primaryDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        'notifications.actions.done'.tr(),
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

String _formatRelativeTime(DateTime value, bool isArabic) {
  final now = DateTime.now();
  final difference = now.difference(value);

  if (difference.isNegative || difference.inSeconds < 60) {
    return 'notifications.relative.just_now'.tr();
  }

  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;

    return 'notifications.relative.minutes_ago'.tr(
      namedArgs: {'count': '$minutes'},
    );
  }

  if (difference.inHours < 24) {
    final hours = difference.inHours;

    return 'notifications.relative.hours_ago'.tr(
      namedArgs: {'count': '$hours'},
    );
  }

  if (difference.inDays < 7) {
    final days = difference.inDays;

    return (days == 1
            ? 'notifications.relative.days_ago_one'
            : 'notifications.relative.days_ago_many')
        .tr(namedArgs: {'count': '$days'});
  }

  final formatter = DateFormat(isArabic ? 'yyyy/MM/dd' : 'MMM d, yyyy');
  return formatter.format(value);
}
