import 'package:itaaleem/features/center/presentation/providers/center_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:itaaleem/core/theme/app_palette.dart';
/// Shared "مغادرة السنتر" confirm dialog — used from both
/// `ContactCenterScreen` and the account screen's "السنتر" section, so the
/// copy and behavior (clear membership; `HomeScreen` reacts on its own,
/// falling back to the join-by-code view) only exist in one place.
Future<void> confirmLeaveCenter(
  BuildContext context,
  WidgetRef ref,
  String centerName,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('مغادرة السنتر'),
      content: Text(
        'هل أنت متأكد إنك عايز تغادر $centerName؟ هتحتاج تنضم لسنتر تاني.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: context.palette.error),
          child: const Text('مغادرة'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(centerMembershipProvider.notifier).leave();
  }
}
