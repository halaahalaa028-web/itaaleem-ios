import 'package:itaaleem/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum NotificationCategory { lecture, exam, announcement }

/// One dummy notification — stands in for a future `GET /notifications`
/// feed. Shared by [NotificationsScreen] (the full list, tab-filtered) and
/// the home header's badge dot (`.any((n) => n.unread)`), so both agree on
/// what counts as unread.
class DummyNotification {
  const DummyNotification({
    required this.title,
    required this.time,
    required this.icon,
    required this.iconBackground,
    required this.category,
    this.unread = false,
  });

  final String title;
  final String time;
  final IconData icon;
  final Color iconBackground;
  final NotificationCategory category;
  final bool unread;
}

final dummyNotifications = <DummyNotification>[
  DummyNotification(
    title: 'محاضرة جديدة: الدوائر الكهربائية — الحصة 5',
    time: 'منذ ساعة',
    icon: Icons.play_circle_fill_rounded,
    iconBackground: AppColors.primarySurface,
    category: NotificationCategory.lecture,
    unread: true,
  ),
  DummyNotification(
    title: 'امتحان جديد: رياضة — امتحان نص الترم',
    time: 'منذ 3 ساعات',
    icon: Icons.edit_note_rounded,
    iconBackground: AppColors.warningLight,
    category: NotificationCategory.exam,
    unread: true,
  ),
  DummyNotification(
    title: 'إعلان: الامتحانات النهائية تبدأ الأسبوع الجاي',
    time: 'منذ يوم',
    icon: Icons.campaign_rounded,
    iconBackground: AppColors.infoLight,
    category: NotificationCategory.announcement,
  ),
  DummyNotification(
    title: 'نتيجتك في امتحان الفيزيا: 85%',
    time: 'منذ يومين',
    icon: Icons.bar_chart_rounded,
    iconBackground: AppColors.successLight,
    category: NotificationCategory.exam,
  ),
  DummyNotification(
    title: 'محاضرة جديدة: أساسيات اللحام',
    time: 'منذ 3 أيام',
    icon: Icons.play_circle_fill_rounded,
    iconBackground: AppColors.primarySurface,
    category: NotificationCategory.lecture,
  ),
  DummyNotification(
    title: 'مرحباً بيك في سنتر الأستاذ عامر!',
    time: 'منذ أسبوع',
    icon: Icons.waving_hand_rounded,
    iconBackground: AppColors.primarySurface,
    category: NotificationCategory.announcement,
  ),
];
